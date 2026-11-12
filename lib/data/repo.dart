// Reads and writes, in one place.
import 'dart:math';

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const waiverVersion = '2026-11-v1';
const holdHours = 24;

class Repo {
  Repo._();
  static final Repo instance = Repo._();

  FirebaseFirestore get db => FirebaseFirestore.instance;
  Session get session => Session.instance;

  CollectionReference<Json> get events => db.collection('events');
  CollectionReference<Json> get divisions => db.collection('divisions');
  CollectionReference<Json> get players => db.collection('players');
  CollectionReference<Json> get registrations => db.collection('registrations');
  CollectionReference<Json> get measurements => db.collection('measurements');
  CollectionReference<Json> get awards => db.collection('awards');
  CollectionReference<Json> get staff => db.collection('staffAssignments');

  // ---------- Events ----------

  /// Events the public can see, soonest first.
  Stream<List<BBEvent>> publicEvents() => events
      .where('status', whereIn: ['open', 'closed', 'live', 'final', 'rainedOut'])
      .snapshots()
      .map((s) => _sortEvents(s.docs.map(BBEvent.fromDoc).toList()));

  /// Every event, drafts included (admins).
  Stream<List<BBEvent>> allEvents() =>
      events.snapshots().map((s) => _sortEvents(s.docs.map(BBEvent.fromDoc).toList()));

  List<BBEvent> _sortEvents(List<BBEvent> list) {
    final far = DateTime(2100);
    list.sort((a, b) => (a.start ?? far).compareTo(b.start ?? far));
    return list;
  }

  Stream<BBEvent?> event(String id) =>
      events.doc(id).snapshots().map((d) => d.exists ? BBEvent.fromDoc(d) : null);

  Stream<List<Division>> divisionsFor(String eventId) => divisions
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(Division.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order)));

  Future<String> saveEvent(String? id, Json data) async {
    if (id == null) {
      final ref = await events.add({...data, 'createdAt': FieldValue.serverTimestamp()});
      return ref.id;
    }
    await events.doc(id).update(data);
    return id;
  }

  Future<void> addDivision(String eventId, String name, int capacity, int order) =>
      divisions.add({
        'eventId': eventId,
        'name': name,
        'capacity': capacity,
        'taken': 0,
        'order': order,
      });

  Future<void> updateDivision(String id, Json data) => divisions.doc(id).update(data);
  Future<void> deleteDivision(String id) => divisions.doc(id).delete();

  // ---------- Players ----------

  Stream<List<Player>> myPlayers() {
    final uid = session.user?.uid;
    if (uid == null) return Stream.value(const []);
    return players
        .where('guardianUids', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.map(Player.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));
  }

  Stream<Player?> player(String id) =>
      players.doc(id).snapshots().map((d) => d.exists ? Player.fromDoc(d) : null);

  Stream<Json?> playerPrivate(String id) =>
      db.doc('playerPrivate/$id').snapshots().map((d) => d.data());

  Future<String> savePlayer(String? id, Json data, Json private) async {
    final ref = id == null ? players.doc() : players.doc(id);
    final batch = db.batch();
    if (id == null) {
      batch.set(ref, {...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      batch.update(ref, data);
    }
    batch.set(db.doc('playerPrivate/${ref.id}'), {
      ...private,
      'guardianUids': data['guardianUids'],
    });
    await batch.commit();
    return ref.id;
  }

  // ---------- Registrations ----------

  static String regId(String eventId, String playerId) => '${eventId}_$playerId';

  /// A short code for the Venmo or Cash App note that stands in for the
  /// player's name, since a payment note can be visible to others.
  static String newPaymentCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return 'BB-${List.generate(4, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  Stream<List<Registration>> myRegistrations() {
    final uid = session.user?.uid;
    if (uid == null) return Stream.value(const []);
    return registrations
        .where('guardianUid', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(Registration.fromDoc).toList());
  }

  Stream<List<Registration>> registrationsFor(String eventId) => registrations
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(Registration.fromDoc).toList()
        ..sort((a, b) => a.playerName.compareTo(b.playerName)));

  /// Every registration waiting on payment, across events (admins).
  Stream<List<Registration>> heldRegistrations() => registrations
      .where('status', whereIn: ['held', 'offered', 'waitlisted'])
      .snapshots()
      .map((s) => s.docs.map(Registration.fromDoc).toList());

  /// Reserves a spot: holds it for 24 hours while an admin confirms payment,
  /// or joins the waitlist when the division is full.
  Future<Registration> reserve({
    required BBEvent event,
    required Division division,
    required Player player,
    required String paymentCode,
    required String paidVia,
    required String payerName,
    required bool skillsOptIn,
  }) async {
    final user = session.user!;
    final regRef = registrations.doc(regId(event.id, player.id));
    final divRef = divisions.doc(division.id);
    await db.runTransaction<void>((tx) async {
      final existing = await tx.get(regRef);
      if (existing.exists) {
        final r = Registration.fromDoc(existing);
        if (r.status != 'released' && r.status != 'cancelled') {
          throw StateError('${player.firstName} is already registered for this event.');
        }
      }
      final div = Division.fromDoc(await tx.get(divRef));
      final waitlisted = div.full;
      final data = <String, dynamic>{
        'eventId': event.id,
        'eventName': event.name,
        'divisionId': division.id,
        'divisionName': division.name,
        'playerId': player.id,
        'playerName': player.name,
        'publicName': player.publicName,
        'playerPublic': player.publicProfile,
        'gradYear': player.gradYear,
        'guardianUid': user.uid,
        'guardianName': session.displayName,
        'guardianEmail': user.email,
        'status': waitlisted ? 'waitlisted' : 'held',
        'paymentCode': paymentCode,
        'paidVia': waitlisted ? null : paidVia,
        'payerName': waitlisted ? '' : payerName,
        'amount': event.price,
        'holdEndsAt': waitlisted
            ? null
            : Timestamp.fromDate(DateTime.now().add(const Duration(hours: holdHours))),
        'createdAt': FieldValue.serverTimestamp(),
        'waiverVersion': waiverVersion,
        'waiverAcceptedAt': FieldValue.serverTimestamp(),
        'skillsOptIn': skillsOptIn,
        'alreadyPaid': false,
      };
      tx.set(regRef, data);
      if (!waitlisted) {
        // lastReg lets the rules check this spot belongs to this registration.
        tx.update(divRef, {'taken': div.taken + 1, 'lastReg': regRef.id});
      }
    });
    return Registration.fromDoc(await regRef.get());
  }

  /// The family says they already paid after a hold ended: back to the front
  /// of the line, flagged for an admin to look for.
  Future<void> flagAlreadyPaid(Registration r) =>
      registrations.doc(r.id).update({'alreadyPaid': true});

  Future<void> markPaid(Registration r) => registrations.doc(r.id).update({
        'status': 'paid',
        'markedPaidBy': session.user!.uid,
        'markedPaidByName': session.displayName,
        'markedPaidAt': FieldValue.serverTimestamp(),
        'alreadyPaid': false,
      });

  /// Opens a held spot back up for the waitlist.
  Future<void> release(Registration r) async {
    final batch = db.batch();
    batch.update(registrations.doc(r.id), {'status': 'released'});
    if (r.isHeld || r.isConfirmed) {
      batch.update(divisions.doc(r.divisionId), {'taken': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  /// Offers a waitlisted family the next open spot, held for 24 hours.
  Future<void> offerSpot(Registration r) async {
    final batch = db.batch();
    batch.update(registrations.doc(r.id), {
      'status': 'offered',
      'holdEndsAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: holdHours))),
    });
    batch.update(divisions.doc(r.divisionId), {'taken': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> setRegistration(String id, Json data) => registrations.doc(id).update(data);

  // ---------- Results ----------

  Future<void> addMeasurement(Registration r, BBEvent e, String type, double value) =>
      measurements.add({
        'eventId': e.id,
        'eventName': e.name,
        'playerId': r.playerId,
        'publicName': r.playerPublic ? r.publicName : '',
        'playerPublic': r.playerPublic,
        'divisionName': r.divisionName,
        'gradYear': r.gradYear,
        'type': type,
        'value': value,
        'recordedBy': session.user!.uid,
        'recordedAt': FieldValue.serverTimestamp(),
        'published': e.resultsPublished,
      });

  Future<void> deleteMeasurement(String id) => measurements.doc(id).delete();

  Future<void> addAward(Registration r, BBEvent e, String type) => awards.add({
        'eventId': e.id,
        'eventName': e.name,
        'playerId': r.playerId,
        'publicName': r.playerPublic ? r.publicName : '',
        'playerPublic': r.playerPublic,
        'divisionName': r.divisionName,
        'type': type,
        'recordedBy': session.user!.uid,
        'published': e.resultsPublished,
      });

  Future<void> deleteAward(String id) => awards.doc(id).delete();

  Stream<List<Measurement>> eventMeasurements(String eventId) => measurements
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(Measurement.fromDoc).toList()
        ..sort((a, b) => (b.recordedAt ?? DateTime(2100)).compareTo(a.recordedAt ?? DateTime(2100))));

  Stream<List<Award>> eventAwards(String eventId) => awards
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(Award.fromDoc).toList());

  /// Published results for one event (anyone).
  Stream<List<Measurement>> publishedMeasurements(String eventId) => measurements
      .where('eventId', isEqualTo: eventId)
      .where('published', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Measurement.fromDoc).toList());

  Stream<List<Award>> publishedAwards(String eventId) => awards
      .where('eventId', isEqualTo: eventId)
      .where('published', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Award.fromDoc).toList());

  /// The public leaderboard for one measurement type.
  Stream<List<Measurement>> leaderboard(String type) => measurements
      .where('published', isEqualTo: true)
      .where('playerPublic', isEqualTo: true)
      .where('type', isEqualTo: type)
      .snapshots()
      .map((s) {
        final best = <String, Measurement>{};
        final lower = measurementTypes[type]?.lowerIsBetter ?? false;
        for (final m in s.docs.map(Measurement.fromDoc)) {
          final cur = best[m.playerId];
          if (cur == null || (lower ? m.value < cur.value : m.value > cur.value)) {
            best[m.playerId] = m;
          }
        }
        final list = best.values.toList()
          ..sort((a, b) => lower ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
        return list;
      });

  /// A player's own results (guardians and staff).
  Stream<List<Measurement>> playerMeasurements(String playerId) => measurements
      .where('playerId', isEqualTo: playerId)
      .where('published', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Measurement.fromDoc).toList()
        ..sort((a, b) => (a.recordedAt ?? DateTime(2000)).compareTo(b.recordedAt ?? DateTime(2000))));

  Stream<List<Award>> playerAwards(String playerId) => awards
      .where('playerId', isEqualTo: playerId)
      .where('published', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Award.fromDoc).toList());

  /// Publishing is what makes an event's results public.
  Future<void> publishResults(String eventId) async {
    final ms = await measurements.where('eventId', isEqualTo: eventId).get();
    final as = await awards.where('eventId', isEqualTo: eventId).get();
    final docs = [...ms.docs, ...as.docs];
    for (var i = 0; i < docs.length; i += 400) {
      final batch = db.batch();
      for (final d in docs.skip(i).take(400)) {
        batch.update(d.reference, {'published': true});
      }
      await batch.commit();
    }
    await events.doc(eventId).update({'resultsPublished': true, 'status': 'final'});
  }

  // ---------- Payment settings and people ----------

  Stream<PaymentSettings> paymentSettings() => db
      .doc('config/payments')
      .snapshots()
      .map(PaymentSettings.fromDoc);

  Future<void> savePaymentSettings(PaymentSettings p) async {
    final batch = db.batch();
    batch.set(db.doc('config/payments'), {
      'venmo': p.venmo,
      'cashtag': p.cashtag,
      'payTo': p.payTo,
      'updatedBy': session.user!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('auditLogs').doc(), {
      'action': 'paymentSettings.update',
      'by': session.user!.uid,
      'byName': session.displayName,
      'venmo': p.venmo,
      'cashtag': p.cashtag,
      'payTo': p.payTo,
      'at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Finds an account by the exact email it signed up with.
  Future<AppUser?> userByEmail(String email) async {
    final e = email.trim().toLowerCase();
    final d = await db.doc('userEmails/$e').get();
    if (!d.exists) return null;
    final m = d.data()!;
    return AppUser(uid: m['uid'] as String, name: m['name'] as String? ?? '', email: e);
  }

  Stream<List<(String uid, String role, String name, String email)>> admins() =>
      db.collection('roles').snapshots().map((s) => s.docs
          .map((d) => (
                d.id,
                d.data()['role'] as String? ?? '',
                d.data()['name'] as String? ?? '',
                d.data()['email'] as String? ?? '',
              ))
          .toList());

  Future<void> setAdmin(AppUser u) => db.doc('roles/${u.uid}').set({
        'role': 'admin',
        'name': u.name,
        'email': u.email,
        'grantedBy': session.user!.uid,
        'grantedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeAdmin(String uid) => db.doc('roles/$uid').delete();

  Stream<List<StaffAssignment>> staffFor(String eventId) => staff
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(StaffAssignment.fromDoc).toList());

  Future<void> assignStaff(String eventId, AppUser u, String role) =>
      staff.doc('${eventId}_${u.uid}').set({
        'eventId': eventId,
        'uid': u.uid,
        'role': role,
        'name': u.name,
        'email': u.email,
        'addedBy': session.user!.uid,
      });

  Future<void> removeStaff(String id) => staff.doc(id).delete();
}
