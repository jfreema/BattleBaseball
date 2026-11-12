// Firestore documents as plain Dart classes. Collections are flat and linked
// by ID fields, one per future SQL table, as in BattlePlan.
import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;
List<String> _strings(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];

/// Award types, in display order.
const awardTypes = <String, String>{
  'mvp': 'MVP',
  'topPitcher': 'Top Pitcher',
  'topHitter': 'Top Hitter',
  'eliteDefender': 'Elite Defender',
  'hustle': 'Hustle Award',
};

/// Measurement types: fastball velocity at every event, the rest at events
/// with an opt-in skills contest.
const measurementTypes = <String, ({String label, String unit, bool lowerIsBetter})>{
  'fastball': (label: 'Fastball velocity', unit: 'MPH', lowerIsBetter: false),
  'popTime': (label: 'Pop time', unit: 'sec', lowerIsBetter: true),
  'dash40': (label: '40-yard dash', unit: 'sec', lowerIsBetter: true),
};

const playingLevels = ['Rec', 'All-Star', 'Travel', 'Elite travel'];
const positionsList = ['P', 'C', '1B', '2B', '3B', 'SS', 'LF', 'CF', 'RF', 'UT'];

class Player {
  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.guardianUids,
    this.gradYear,
    this.bats = 'R',
    this.throws = 'R',
    this.positions = const [],
    this.state = 'LA',
    this.level = 'Travel',
    this.reportedVelo,
    this.publicProfile = false,
    this.fullName = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final List<String> guardianUids;
  final int? gradYear;
  final String bats;
  final String throws;
  final List<String> positions;
  final String state;
  final String level;
  final double? reportedVelo;
  final bool publicProfile;
  final bool fullName;

  String get name => '$firstName $lastName'.trim();

  /// The name the public sees, within the guardian's choice.
  String get publicName => fullName || lastName.isEmpty
      ? name
      : '$firstName ${lastName.substring(0, 1)}.';

  static Player fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return Player(
      id: d.id,
      firstName: m['firstName'] as String? ?? '',
      lastName: m['lastName'] as String? ?? '',
      guardianUids: _strings(m['guardianUids']),
      gradYear: (m['gradYear'] as num?)?.toInt(),
      bats: m['bats'] as String? ?? 'R',
      throws: m['throws'] as String? ?? 'R',
      positions: _strings(m['positions']),
      state: m['state'] as String? ?? 'LA',
      level: m['level'] as String? ?? 'Travel',
      reportedVelo: (m['reportedVelo'] as num?)?.toDouble(),
      publicProfile: m['publicProfile'] as bool? ?? false,
      fullName: m['fullName'] as bool? ?? false,
    );
  }

  Json toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'guardianUids': guardianUids,
        'gradYear': gradYear,
        'bats': bats,
        'throws': throws,
        'positions': positions,
        'state': state,
        'level': level,
        'reportedVelo': reportedVelo,
        'publicProfile': publicProfile,
        'fullName': fullName,
        'publicName': publicName,
      };
}

class BBEvent {
  BBEvent({
    required this.id,
    required this.name,
    required this.status,
    this.city = 'Baton Rouge, LA',
    this.venue = '',
    this.address = '',
    this.start,
    this.ageGroups = '',
    this.price,
    this.skillsContest = false,
    this.hostTeam = '',
    this.raisingFor = '',
    this.description = '',
    this.resultsPublished = false,
  });

  final String id;
  final String name;

  /// draft, open, closed, live, final, rainedOut
  final String status;
  final String city;
  final String venue;
  final String address;
  final DateTime? start;
  final String ageGroups;

  /// Null while the price is still being decided.
  final num? price;
  final bool skillsContest;
  final String hostTeam;
  final String raisingFor;
  final String description;
  final bool resultsPublished;

  bool get isOpen => status == 'open';

  /// The last day a family can cancel for a refund: a week before.
  DateTime? get refundCutoff => start?.subtract(const Duration(days: 7));

  static BBEvent fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return BBEvent(
      id: d.id,
      name: m['name'] as String? ?? 'Battle Baseball Showcase',
      status: m['status'] as String? ?? 'draft',
      city: m['city'] as String? ?? 'Baton Rouge, LA',
      venue: m['venue'] as String? ?? '',
      address: m['address'] as String? ?? '',
      start: _date(m['start']),
      ageGroups: m['ageGroups'] as String? ?? '',
      price: m['price'] as num?,
      skillsContest: m['skillsContest'] as bool? ?? false,
      hostTeam: m['hostTeam'] as String? ?? '',
      raisingFor: m['raisingFor'] as String? ?? '',
      description: m['description'] as String? ?? '',
      resultsPublished: m['resultsPublished'] as bool? ?? false,
    );
  }

  Json toJson() => {
        'name': name,
        'status': status,
        'city': city,
        'venue': venue,
        'address': address,
        'start': start == null ? null : Timestamp.fromDate(start!),
        'ageGroups': ageGroups,
        'price': price,
        'skillsContest': skillsContest,
        'hostTeam': hostTeam,
        'raisingFor': raisingFor,
        'description': description,
        'resultsPublished': resultsPublished,
      };
}

class Division {
  Division({
    required this.id,
    required this.eventId,
    required this.name,
    this.capacity = 24,
    this.taken = 0,
    this.order = 0,
  });
  final String id;
  final String eventId;
  final String name;
  final int capacity;
  final int taken;
  final int order;

  int get open => (capacity - taken).clamp(0, capacity);
  bool get full => taken >= capacity;

  static Division fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return Division(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      name: m['name'] as String? ?? '',
      capacity: (m['capacity'] as num?)?.toInt() ?? 24,
      taken: (m['taken'] as num?)?.toInt() ?? 0,
      order: (m['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class Registration {
  Registration({
    required this.id,
    required this.eventId,
    required this.divisionId,
    required this.divisionName,
    required this.playerId,
    required this.playerName,
    required this.guardianUid,
    required this.guardianName,
    required this.status,
    required this.paymentCode,
    this.eventName = '',
    this.paidVia,
    this.payerName = '',
    this.amount,
    this.holdEndsAt,
    this.createdAt,
    this.markedPaidByName,
    this.markedPaidAt,
    this.alreadyPaid = false,
    this.jersey,
    this.skillsOptIn = false,
    this.publicName = '',
    this.playerPublic = false,
    this.gradYear,
  });

  final String id;
  final String eventId;
  final String eventName;
  final String divisionId;
  final String divisionName;
  final String playerId;
  final String playerName;
  final String publicName;
  final bool playerPublic;
  final int? gradYear;
  final String guardianUid;
  final String guardianName;

  /// held, paid, waitlisted, offered, released, cancelled, checkedIn,
  /// refundDue, refunded, credited
  final String status;
  final String paymentCode;
  final String? paidVia;
  final String payerName;
  final num? amount;
  final DateTime? holdEndsAt;
  final DateTime? createdAt;
  final String? markedPaidByName;
  final DateTime? markedPaidAt;
  final bool alreadyPaid;
  final int? jersey;
  final bool skillsOptIn;

  bool get isHeld => status == 'held' || status == 'offered';
  bool get holdEnded => isHeld && holdEndsAt != null && holdEndsAt!.isBefore(DateTime.now());
  bool get isConfirmed => status == 'paid' || status == 'checkedIn';

  static Registration fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return Registration(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      eventName: m['eventName'] as String? ?? '',
      divisionId: m['divisionId'] as String? ?? '',
      divisionName: m['divisionName'] as String? ?? '',
      playerId: m['playerId'] as String? ?? '',
      playerName: m['playerName'] as String? ?? '',
      publicName: m['publicName'] as String? ?? '',
      playerPublic: m['playerPublic'] as bool? ?? false,
      gradYear: (m['gradYear'] as num?)?.toInt(),
      guardianUid: m['guardianUid'] as String? ?? '',
      guardianName: m['guardianName'] as String? ?? '',
      status: m['status'] as String? ?? 'held',
      paymentCode: m['paymentCode'] as String? ?? '',
      paidVia: m['paidVia'] as String?,
      payerName: m['payerName'] as String? ?? '',
      amount: m['amount'] as num?,
      holdEndsAt: _date(m['holdEndsAt']),
      createdAt: _date(m['createdAt']),
      markedPaidByName: m['markedPaidByName'] as String?,
      markedPaidAt: _date(m['markedPaidAt']),
      alreadyPaid: m['alreadyPaid'] as bool? ?? false,
      jersey: (m['jersey'] as num?)?.toInt(),
      skillsOptIn: m['skillsOptIn'] as bool? ?? false,
    );
  }
}

class Measurement {
  Measurement({
    required this.id,
    required this.eventId,
    required this.playerId,
    required this.type,
    required this.value,
    this.publicName = '',
    this.eventName = '',
    this.divisionName = '',
    this.gradYear,
    this.recordedAt,
    this.published = false,
  });
  final String id;
  final String eventId;
  final String eventName;
  final String playerId;
  final String publicName;
  final String divisionName;
  final int? gradYear;
  final String type;
  final double value;
  final DateTime? recordedAt;
  final bool published;

  String get unit => measurementTypes[type]?.unit ?? '';

  static Measurement fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return Measurement(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      eventName: m['eventName'] as String? ?? '',
      playerId: m['playerId'] as String? ?? '',
      publicName: m['publicName'] as String? ?? '',
      divisionName: m['divisionName'] as String? ?? '',
      gradYear: (m['gradYear'] as num?)?.toInt(),
      type: m['type'] as String? ?? 'fastball',
      value: (m['value'] as num?)?.toDouble() ?? 0,
      recordedAt: _date(m['recordedAt']),
      published: m['published'] as bool? ?? false,
    );
  }
}

class Award {
  Award({
    required this.id,
    required this.eventId,
    required this.playerId,
    required this.type,
    this.publicName = '',
    this.eventName = '',
    this.divisionName = '',
    this.published = false,
  });
  final String id;
  final String eventId;
  final String eventName;
  final String playerId;
  final String publicName;
  final String divisionName;
  final String type;
  final bool published;

  String get label => awardTypes[type] ?? type;

  static Award fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return Award(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      eventName: m['eventName'] as String? ?? '',
      playerId: m['playerId'] as String? ?? '',
      publicName: m['publicName'] as String? ?? '',
      divisionName: m['divisionName'] as String? ?? '',
      type: m['type'] as String? ?? 'mvp',
      published: m['published'] as bool? ?? false,
    );
  }
}

class PaymentSettings {
  const PaymentSettings({this.venmo = '', this.cashtag = '', this.payTo = ''});
  final String venmo;
  final String cashtag;
  final String payTo;
  bool get configured => venmo.isNotEmpty || cashtag.isNotEmpty;

  static PaymentSettings fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return PaymentSettings(
      venmo: m['venmo'] as String? ?? '',
      cashtag: m['cashtag'] as String? ?? '',
      payTo: m['payTo'] as String? ?? '',
    );
  }
}

class StaffAssignment {
  StaffAssignment({
    required this.id,
    required this.eventId,
    required this.uid,
    required this.role,
    this.name = '',
    this.email = '',
  });
  final String id;
  final String eventId;
  final String uid;

  /// eventAdmin or staff
  final String role;
  final String name;
  final String email;

  static StaffAssignment fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return StaffAssignment(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      uid: m['uid'] as String? ?? '',
      role: m['role'] as String? ?? 'staff',
      name: m['name'] as String? ?? '',
      email: m['email'] as String? ?? '',
    );
  }
}

class AppUser {
  AppUser({required this.uid, this.name = '', this.email = ''});
  final String uid;
  final String name;
  final String email;
  static AppUser fromDoc(DocumentSnapshot<Json> d) {
    final m = d.data() ?? const {};
    return AppUser(
      uid: d.id,
      name: m['name'] as String? ?? '',
      email: m['email'] as String? ?? '',
    );
  }
}
