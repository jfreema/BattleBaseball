// Reads and writes, in one place.
import 'dart:math';

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const waiverVersion = '2026-11-v1';
const holdHours = 24;

class Repo {
  Repo();

  /// The one repo the app reads and writes through. main() swaps in the
  /// sample-data repo when the app is opened with ?demo=1.
  static Repo instance = Repo();

  /// True while the app is showing sample data instead of Firestore.
  static bool get isDemo => instance.demo;
  bool get demo => false;

  FirebaseFirestore get db => FirebaseFirestore.instance;
  Session get session => Session.instance;

  CollectionReference<Json> get events => db.collection('events');
  CollectionReference<Json> get divisions => db.collection('divisions');
  CollectionReference<Json> get players => db.collection('players');
  CollectionReference<Json> get registrations => db.collection('registrations');
  CollectionReference<Json> get measurements => db.collection('measurements');
  CollectionReference<Json> get awards => db.collection('awards');
  CollectionReference<Json> get staff => db.collection('staffAssignments');
  CollectionReference<Json> get publicProfiles => db.collection('publicProfiles');
  CollectionReference<Json> get statLines => db.collection('statLines');

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

  /// Saves a player. The public profile document is written in the same
  /// batch when the guardian has it switched on and removed when it's off,
  /// and the choice is then copied onto the player's registrations and
  /// published results so it takes effect everywhere at once.
  Future<String> savePlayer(String? id, Json data, Json private) async {
    final ref = id == null ? players.doc() : players.doc(id);
    final public = data['publicProfile'] == true;
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
    if (public) {
      batch.set(publicProfiles.doc(ref.id), _publicJson(data));
    } else if (id != null) {
      batch.delete(publicProfiles.doc(ref.id));
    }
    await batch.commit();
    if (id != null) {
      await _syncVisibility(ref.id, data['publicName'] as String? ?? '', public);
    }
    return ref.id;
  }

  Json _publicJson(Json player) => {
        'name': player['publicName'],
        'gradYear': player['gradYear'],
        'positions': player['positions'],
        'bats': player['bats'],
        'throws': player['throws'],
        'state': player['state'],
        if (player['jersey'] != null) 'jersey': player['jersey'],
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Makes sure a player whose profile is switched on has its public
  /// document (players saved before public profiles had their own).
  Future<void> ensurePublicProfile(Player p) async {
    if (!p.publicProfile) return;
    try {
      final d = await publicProfiles.doc(p.id).get();
      if (!d.exists) await publicProfiles.doc(p.id).set(_publicJson(p.toJson()));
    } catch (_) {
      // Not this guardian's to write, or offline: nothing to fix here.
    }
  }

  /// Copies a guardian's public-or-private choice onto the player's
  /// registrations and published results. Results that aren't published yet
  /// pick it up from the registration when the event is published.
  Future<void> _syncVisibility(String playerId, String publicName, bool public) async {
    final uid = session.user?.uid;
    if (uid == null) return;
    try {
      final shown = public ? publicName : '';
      final regs = await registrations
          .where('guardianUid', isEqualTo: uid)
          .where('playerId', isEqualTo: playerId)
          .get();
      final results = await Future.wait([
        for (final c in [measurements, awards, statLines])
          c.where('playerId', isEqualTo: playerId).where('published', isEqualTo: true).get(),
      ]);
      final writes = <(DocumentReference<Json>, Json)>[
        for (final d in regs.docs)
          if (d.data()['publicName'] != publicName || d.data()['playerPublic'] != public)
            (d.reference, {'publicName': publicName, 'playerPublic': public}),
        for (final q in results)
          for (final d in q.docs)
            if (d.data()['publicName'] != shown || d.data()['playerPublic'] != public)
              (d.reference, {'publicName': shown, 'playerPublic': public}),
      ];
      for (var i = 0; i < writes.length; i += 400) {
        final batch = db.batch();
        for (final (ref, data) in writes.skip(i).take(400)) {
          batch.update(ref, data);
        }
        await batch.commit();
      }
    } catch (_) {
      // The player itself saved; a later save or the next publish catches up.
    }
  }

  // ---------- Public profiles ----------

  /// A player's public profile, or null when it's private or doesn't exist.
  Stream<PublicProfile?> publicProfile(String id) => publicProfiles
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? PublicProfile.fromDoc(d) : null);

  /// Every public profile, by name.
  Stream<List<PublicProfile>> allPublicProfiles() => publicProfiles.limit(500).snapshots().map(
      (s) => s.docs.map(PublicProfile.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

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

  /// Saves a player's game stats for one showcase (one line per player).
  Future<void> saveStatLine(Registration r, BBEvent e, StatLine line) =>
      statLines.doc(regId(e.id, r.playerId)).set({
        'eventId': e.id,
        'eventName': e.name,
        'playerId': r.playerId,
        'publicName': r.playerPublic ? r.publicName : '',
        'playerPublic': r.playerPublic,
        'divisionName': r.divisionName,
        'gradYear': r.gradYear,
        ...line.numbers(),
        'recordedBy': session.user!.uid,
        'recordedAt': FieldValue.serverTimestamp(),
        'published': e.resultsPublished,
      });

  Future<void> deleteStatLine(String id) => statLines.doc(id).delete();

  /// Every stat line at an event, drafts included (staff).
  Stream<List<StatLine>> eventStatLines(String eventId) => statLines
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(StatLine.fromDoc).toList());

  /// Published stat lines for one event (anyone).
  Stream<List<StatLine>> publishedStatLines(String eventId) => statLines
      .where('eventId', isEqualTo: eventId)
      .where('published', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(StatLine.fromDoc).toList());

  /// A player's published stat lines, oldest first.
  Stream<List<StatLine>> playerStatLines(String playerId) => statLines
      .where('playerId', isEqualTo: playerId)
      .where('published', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(StatLine.fromDoc).toList()
        ..sort((a, b) => (a.recordedAt ?? DateTime(2000)).compareTo(b.recordedAt ?? DateTime(2000))));

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

  /// Publishing is what makes an event's results public. Each result takes
  /// the public-or-private choice from the player's registration as it
  /// stands now, so a family that changed its mind since sign-up is honored.
  Future<void> publishResults(String eventId) async {
    final regs = await registrations.where('eventId', isEqualTo: eventId).get();
    final byPlayer = {
      for (final r in regs.docs.map(Registration.fromDoc)) r.playerId: r,
    };
    final ms = await measurements.where('eventId', isEqualTo: eventId).get();
    final as = await awards.where('eventId', isEqualTo: eventId).get();
    final ss = await statLines.where('eventId', isEqualTo: eventId).get();
    final docs = [...ms.docs, ...as.docs, ...ss.docs];
    for (var i = 0; i < docs.length; i += 400) {
      final batch = db.batch();
      for (final d in docs.skip(i).take(400)) {
        final r = byPlayer[d.data()['playerId']];
        batch.update(d.reference, {
          'published': true,
          if (r != null) 'publicName': r.playerPublic ? r.publicName : '',
          if (r != null) 'playerPublic': r.playerPublic,
        });
      }
      await batch.commit();
    }
    await events.doc(eventId).update({'resultsPublished': true, 'status': 'final'});
  }

  // ---------- Hosting a showcase ----------

  /// A team asking to host a showcase. Anyone can send one; admins read them.
  Future<void> sendHostInquiry({
    required String team,
    required String contact,
    required String email,
    String city = '',
    String phone = '',
    String message = '',
  }) =>
      db.collection('hostInquiries').add({
        'team': team,
        'city': city,
        'contact': contact,
        'email': email,
        'phone': phone,
        'message': message,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

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
