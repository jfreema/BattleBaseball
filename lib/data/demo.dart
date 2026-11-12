// Sample data for looking at the app before real showcases exist. Opening the
// app with ?demo=1 swaps this in for the Firestore repo: every read answers
// from the lists below and every write fails with StateError('Sample data.').
// Nothing here is shown in the real app. Ids start with "demo-".
import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/sample.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

typedef _Kid = ({
  String id,
  String name,
  int year,
  List<String> pos,
  String bats,
  String throws,
  int? jersey,
  List<double> fastballs,
  double? pop,
  double? dash,
});

class DemoRepo extends Repo {
  DemoRepo();

  static const fallId = 'demo-fall';
  static const springId = 'demo-spring';
  static const summerId = 'demo-summer';
  static const masonId = 'demo-mason';
  static const parentUid = 'demo-parent';

  @override
  bool get demo => true;

  @override
  FirebaseFirestore get db => throw StateError('Sample data.');

  static Future<T> _no<T>() => Future<T>.error(StateError('Sample data.'));

  // ---------- The sample world ----------

  static final List<BBEvent> _events = [
    BBEvent(
      id: fallId,
      name: 'Fall Showcase',
      status: 'final',
      venue: 'BREC Central Sports Park',
      address: 'Baton Rouge, LA',
      start: DateTime(2026, 10, 17, 9),
      ageGroups: '9U to 14U',
      price: 85,
      skillsContest: true,
      resultsPublished: true,
    ),
    BBEvent(
      id: springId,
      name: 'Spring Showcase',
      status: 'open',
      venue: 'BREC Central Sports Park',
      address: 'Baton Rouge, LA',
      start: DateTime(2027, 3, 13, 9),
      ageGroups: '9U to 14U',
      price: 85,
      skillsContest: true,
      hostTeam: 'Red Stick Renegades 12U',
      raisingFor: 'new catching gear',
      description: 'Check-in opens at 8:15. Bring a glove, a bat and water.',
    ),
    BBEvent(
      id: summerId,
      name: 'Summer Showcase',
      status: 'open',
      venue: 'BREC Central Sports Park',
      address: 'Baton Rouge, LA',
      start: DateTime(2027, 6, 5, 9),
      ageGroups: '9U to 14U',
      price: 85,
    ),
  ];

  static final _draft = BBEvent(id: 'demo-winter', name: 'Winter Showcase', status: 'draft');

  static final List<Division> _divisions = [
    Division(id: '$springId-10u', eventId: springId, name: '10U', capacity: 20, taken: 14, order: 0),
    Division(id: '$springId-12u', eventId: springId, name: '12U', capacity: 24, taken: 24, order: 1),
    Division(id: '$springId-14u', eventId: springId, name: '14U', capacity: 20, taken: 15, order: 2),
    Division(id: '$summerId-10u', eventId: summerId, name: '10U', capacity: 20, taken: 6, order: 0),
    Division(id: '$summerId-12u', eventId: summerId, name: '12U', capacity: 24, taken: 10, order: 1),
    Division(id: '$summerId-14u', eventId: summerId, name: '14U', capacity: 20, taken: 8, order: 2),
    Division(id: '$fallId-10u', eventId: fallId, name: '10U', capacity: 20, taken: 18, order: 0),
    Division(id: '$fallId-12u', eventId: fallId, name: '12U', capacity: 24, taken: 24, order: 1),
    Division(id: '$fallId-14u', eventId: fallId, name: '14U', capacity: 20, taken: 20, order: 2),
  ];

  /// Everyone with a public card. Fastballs are oldest first; the last one
  /// was thrown at the Fall Showcase. The last two are rookies.
  static const List<_Kid> _kids = [
    (id: 'demo-tyler', name: 'Tyler B.', year: 2029, pos: ['P', '1B'], bats: 'R', throws: 'R', jersey: 22, fastballs: [72, 75, 78], pop: null, dash: 4.98),
    (id: 'demo-jace', name: 'Jace M.', year: 2029, pos: ['P', 'CF'], bats: 'L', throws: 'L', jersey: 7, fastballs: [73, 76], pop: null, dash: 5.05),
    (id: 'demo-cooper', name: 'Cooper L.', year: 2030, pos: ['C', '3B'], bats: 'R', throws: 'R', jersey: 27, fastballs: [71, 75], pop: 2.04, dash: 5.31),
    (id: 'demo-wyatt', name: 'Wyatt S.', year: 2029, pos: ['SS', 'P'], bats: 'R', throws: 'R', jersey: 2, fastballs: [74], pop: null, dash: 5.12),
    (id: 'demo-beau', name: 'Beau D.', year: 2030, pos: ['P', 'LF'], bats: 'R', throws: 'R', jersey: 15, fastballs: [70, 73], pop: null, dash: null),
    (id: masonId, name: 'Mason R.', year: 2031, pos: ['P', 'SS'], bats: 'R', throws: 'R', jersey: 12, fastballs: [], pop: null, dash: null),
    (id: 'demo-hayes', name: 'Hayes W.', year: 2030, pos: ['C'], bats: 'S', throws: 'R', jersey: 9, fastballs: [70], pop: 2.11, dash: 5.44),
    (id: 'demo-eli', name: 'Eli T.', year: 2031, pos: ['P', '2B'], bats: 'L', throws: 'L', jersey: 4, fastballs: [66, 69], pop: null, dash: 5.38),
    (id: 'demo-landry', name: 'Landry H.', year: 2031, pos: ['P', 'RF'], bats: 'R', throws: 'R', jersey: 31, fastballs: [68], pop: null, dash: null),
    (id: 'demo-max', name: 'Maximiliano Q.', year: 2030, pos: ['3B', 'P'], bats: 'R', throws: 'R', jersey: 18, fastballs: [67], pop: null, dash: 5.71),
    (id: 'demo-brooks', name: 'Brooks A.', year: 2032, pos: ['C', '1B'], bats: 'R', throws: 'R', jersey: 5, fastballs: [63, 66], pop: 2.26, dash: 5.9),
    (id: 'demo-jude', name: 'Jude P.', year: 2032, pos: ['2B', 'SS'], bats: 'R', throws: 'R', jersey: null, fastballs: [64], pop: null, dash: 5.66),
    (id: 'demo-rhett', name: 'Rhett C.', year: 2033, pos: ['P', 'CF'], bats: 'L', throws: 'L', jersey: 1, fastballs: [61], pop: null, dash: null),
    (id: 'demo-knox', name: 'Knox F.', year: 2033, pos: ['LF', 'UT'], bats: 'R', throws: 'R', jersey: 44, fastballs: [58], pop: null, dash: 6.02),
    (id: 'demo-sawyer', name: 'Sawyer N.', year: 2032, pos: ['UT'], bats: 'R', throws: 'R', jersey: 7, fastballs: [], pop: null, dash: null),
    (id: 'demo-owen', name: 'Owen B.', year: 2033, pos: ['1B'], bats: 'L', throws: 'L', jersey: null, fastballs: [], pop: null, dash: null),
  ];

  static String _division(int gradYear) => '${43 - (gradYear - 2000)}U';

  static final List<PublicProfile> _profiles = [
    for (final k in _kids)
      PublicProfile(
        id: k.id,
        name: k.name,
        gradYear: k.year,
        positions: k.pos,
        bats: k.bats,
        throws: k.throws,
        state: 'LA',
        jersey: k.jersey,
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// The showcases a reading can come from, newest first.
  static final _past = [
    (id: fallId, name: 'Fall Showcase', date: DateTime(2026, 10, 17)),
    (id: 'demo-summer-26', name: 'Summer Showcase', date: DateTime(2026, 6, 6)),
    (id: 'demo-spring-26', name: 'Spring Showcase', date: DateTime(2026, 3, 14)),
  ];

  static Measurement _moved(Measurement m) => Measurement(
        id: 'demo-${m.id}',
        eventId: m.eventId == 'sample-4' ? fallId : m.eventId,
        eventName: m.eventName,
        playerId: m.playerId,
        publicName: m.publicName,
        divisionName: m.divisionName,
        gradYear: m.gradYear,
        type: m.type,
        value: m.value,
        recordedAt: m.recordedAt,
        published: true,
      );

  static final List<Measurement> _measurements = () {
    Measurement reading(_Kid k, String type, double value, int ago) => Measurement(
          id: '${k.id}-$type-$ago',
          eventId: _past[ago].id,
          eventName: _past[ago].name,
          playerId: k.id,
          publicName: k.name,
          divisionName: _division(k.year),
          gradYear: k.year,
          type: type,
          value: value,
          recordedAt: _past[ago].date,
          published: true,
        );
    return [
      for (final k in _kids) ...[
        for (final (i, v) in k.fastballs.indexed)
          reading(k, 'fastball', v, k.fastballs.length - 1 - i),
        if (k.pop != null) reading(k, 'popTime', k.pop!, 0),
        if (k.dash != null) reading(k, 'dash40', k.dash!, 0),
      ],
      ...Sample.measurements(playerId: masonId).map(_moved),
      // A player whose family keeps the card private still counts in results.
      Measurement(
        id: 'demo-private-fastball',
        eventId: fallId,
        eventName: 'Fall Showcase',
        playerId: 'demo-private',
        divisionName: '13U',
        gradYear: 2030,
        type: 'fastball',
        value: 72,
        recordedAt: DateTime(2026, 10, 17),
        published: true,
      ),
    ];
  }();

  static Award _award(String playerId, String name, String type, int ago, String division) => Award(
        id: 'demo-award-$playerId-$type',
        eventId: _past[ago].id,
        eventName: _past[ago].name,
        playerId: playerId,
        publicName: name,
        divisionName: division,
        type: type,
        published: true,
      );

  static final List<Award> _awards = [
    _award('demo-tyler', 'Tyler B.', 'mvp', 0, '14U'),
    _award('demo-jace', 'Jace M.', 'topPitcher', 0, '14U'),
    _award('demo-cooper', 'Cooper L.', 'topHitter', 0, '13U'),
    _award('demo-eli', 'Eli T.', 'eliteDefender', 0, '12U'),
    _award('demo-private', '', 'hustle', 0, '11U'),
    _award('demo-tyler', 'Tyler B.', 'topPitcher', 1, '14U'),
    _award('demo-tyler', 'Tyler B.', 'topHitter', 2, '13U'),
    ...Sample.awards(playerId: masonId),
  ];

  static final List<StatLine> _statLines = () {
    const lines = <String, List<int>>{
      // ab, h, hr, rbi, r, bb, outs, k, pbb
      'demo-tyler': [4, 3, 1, 4, 2, 0, 6, 5, 1],
      'demo-jace': [3, 1, 0, 0, 1, 1, 9, 7, 2],
      'demo-cooper': [4, 3, 0, 2, 2, 0, 0, 0, 0],
      'demo-wyatt': [4, 2, 0, 1, 1, 0, 3, 2, 0],
      'demo-beau': [3, 1, 0, 1, 0, 1, 6, 4, 1],
      'demo-hayes': [4, 2, 1, 3, 1, 0, 0, 0, 0],
      'demo-eli': [3, 1, 0, 0, 1, 1, 6, 3, 2],
      'demo-landry': [3, 0, 0, 0, 0, 1, 3, 1, 1],
      'demo-max': [4, 2, 0, 2, 1, 0, 0, 0, 0],
      'demo-brooks': [3, 2, 0, 1, 1, 0, 0, 0, 0],
    };
    return [
      for (final k in _kids)
        if (lines[k.id] case final n?)
          StatLine(
            id: '${fallId}_${k.id}',
            eventId: fallId,
            eventName: 'Fall Showcase',
            playerId: k.id,
            publicName: k.name,
            divisionName: _division(k.year),
            gradYear: k.year,
            published: true,
            ab: n[0],
            h: n[1],
            hr: n[2],
            rbi: n[3],
            r: n[4],
            bb: n[5],
            outs: n[6],
            k: n[7],
            pbb: n[8],
            recordedAt: DateTime(2026, 10, 17),
          ),
      for (final l in Sample.statLines(playerId: masonId))
        StatLine(
          id: 'demo-${l.id}',
          eventId: l.eventId == 'sample-4' ? fallId : l.eventId,
          eventName: l.eventName,
          playerId: l.playerId,
          publicName: l.publicName,
          divisionName: l.divisionName,
          gradYear: l.gradYear,
          published: true,
          ab: l.ab,
          h: l.h,
          hr: l.hr,
          rbi: l.rbi,
          r: l.r,
          bb: l.bb,
          outs: l.outs,
          k: l.k,
          pbb: l.pbb,
          recordedAt: l.recordedAt,
        ),
    ];
  }();

  /// The pretend family (?demo=family): one public player, one private.
  static final List<Player> _family = [
    Player(
      id: 'demo-cole',
      firstName: 'Cole',
      lastName: 'Reed',
      guardianUids: const [parentUid],
      gradYear: 2034,
      positions: const ['2B'],
      level: 'Rec',
    ),
    Player(
      id: masonId,
      firstName: 'Mason',
      lastName: 'Reed',
      guardianUids: const [parentUid],
      gradYear: 2031,
      positions: const ['P', 'SS'],
      jersey: 12,
      publicProfile: true,
    ),
  ];

  static Registration _reg(
    String eventId,
    String division,
    String playerId,
    String playerName,
    String status, {
    String publicName = '',
    int? gradYear,
    int? jersey,
    DateTime? holdEndsAt,
    String guardianName = 'Jamie Reed',
    String guardianUid = parentUid,
  }) =>
      Registration(
        id: Repo.regId(eventId, playerId),
        eventId: eventId,
        eventName: _events.firstWhere((e) => e.id == eventId).name,
        divisionId: '$eventId-${division.toLowerCase()}',
        divisionName: division,
        playerId: playerId,
        playerName: playerName,
        publicName: publicName,
        playerPublic: publicName.isNotEmpty,
        gradYear: gradYear,
        guardianUid: guardianUid,
        guardianName: guardianName,
        status: status,
        paymentCode:
            'BB-${playerId.replaceFirst('demo-', '').toUpperCase().padRight(4, 'X').substring(0, 4)}',
        paidVia: status == 'waitlisted' ? null : 'venmo',
        payerName: status == 'waitlisted' ? '' : guardianName,
        amount: 85,
        holdEndsAt: holdEndsAt,
        createdAt: DateTime(2026, 11, 2),
        jersey: jersey,
      );

  static List<Registration> get _familyRegs => [
        _reg(springId, '12U', masonId, 'Mason Reed', 'paid',
            publicName: 'Mason R.', gradYear: 2031, jersey: 12),
        _reg(springId, '10U', 'demo-cole', 'Cole Reed', 'held',
            gradYear: 2034, holdEndsAt: DateTime.now().add(const Duration(hours: 20))),
        _reg(summerId, '12U', masonId, 'Mason Reed', 'waitlisted',
            publicName: 'Mason R.', gradYear: 2031),
        _reg(summerId, '10U', 'demo-cole', 'Cole Reed', 'held',
            gradYear: 2034, holdEndsAt: DateTime.now().subtract(const Duration(hours: 3))),
      ];

  /// Who is signed up for an event, for the staff screens (?demo=staff).
  static List<Registration> _roster(String eventId) {
    const statuses = ['paid', 'checkedIn', 'paid', 'held', 'paid', 'waitlisted', 'checkedIn', 'offered'];
    final past = eventId == fallId;
    return [
      for (final (i, k) in _kids.indexed)
        if (!past || k.fastballs.isNotEmpty || k.id == masonId)
          _reg(
            eventId,
            _division(k.year),
            k.id,
            k.name,
            past ? 'checkedIn' : statuses[i % statuses.length],
            publicName: k.name,
            gradYear: k.year,
            jersey: k.jersey,
            holdEndsAt: DateTime.now().add(Duration(hours: i.isEven ? 9 : -2)),
            guardianName: 'Parent of ${k.name.split(' ').first}',
            guardianUid: 'demo-guardian-$i',
          ),
    ]..sort((a, b) => a.playerName.compareTo(b.playerName));
  }

  bool get _signedIn => session.signedIn && session.uid == parentUid;

  // ---------- Reads ----------

  @override
  Stream<List<BBEvent>> publicEvents() => Stream.value(List.of(_events));

  @override
  Stream<List<BBEvent>> allEvents() => Stream.value([..._events, _draft]);

  @override
  Stream<BBEvent?> event(String id) =>
      Stream.value([..._events, _draft].where((e) => e.id == id).firstOrNull);

  @override
  Stream<List<Division>> divisionsFor(String eventId) =>
      Stream.value(_divisions.where((d) => d.eventId == eventId).toList());

  @override
  Stream<List<Player>> myPlayers() => Stream.value(_signedIn ? List.of(_family) : const []);

  @override
  Stream<Player?> player(String id) =>
      Stream.value(_signedIn ? _family.where((p) => p.id == id).firstOrNull : null);

  @override
  Stream<Json?> playerPrivate(String id) => Stream.value(const {
        'birthDate': '04/12/2013',
        'school': 'Sample Middle School',
        'emergencyName': 'Jamie Reed',
        'emergencyPhone': '225-555-0100',
      });

  @override
  Stream<PublicProfile?> publicProfile(String id) => Stream.value(
      id == Sample.id ? Sample.profile : _profiles.where((p) => p.id == id).firstOrNull);

  @override
  Stream<List<PublicProfile>> allPublicProfiles() => Stream.value(List.of(_profiles));

  @override
  Stream<List<Registration>> myRegistrations() =>
      Stream.value(_signedIn ? _familyRegs : const []);

  @override
  Stream<List<Registration>> registrationsFor(String eventId) => Stream.value(_roster(eventId));

  @override
  Stream<List<Registration>> heldRegistrations() => Stream.value([
        for (final id in [springId, summerId])
          ..._roster(id).where((r) => r.isHeld || r.status == 'waitlisted'),
      ]);

  @override
  Stream<List<StatLine>> eventStatLines(String eventId) =>
      Stream.value(_statLines.where((l) => l.eventId == eventId).toList());

  @override
  Stream<List<StatLine>> publishedStatLines(String eventId) => eventStatLines(eventId);

  @override
  Stream<List<StatLine>> playerStatLines(String playerId) =>
      Stream.value(_statLines.where((l) => l.playerId == playerId).toList()
        ..sort((a, b) => a.recordedAt!.compareTo(b.recordedAt!)));

  @override
  Stream<List<Measurement>> eventMeasurements(String eventId) =>
      Stream.value(_measurements.where((m) => m.eventId == eventId).toList());

  @override
  Stream<List<Measurement>> publishedMeasurements(String eventId) => eventMeasurements(eventId);

  @override
  Stream<List<Award>> eventAwards(String eventId) =>
      Stream.value(_awards.where((a) => a.eventId == eventId).toList());

  @override
  Stream<List<Award>> publishedAwards(String eventId) => eventAwards(eventId);

  @override
  Stream<List<Measurement>> leaderboard(String type) {
    final lower = measurementTypes[type]?.lowerIsBetter ?? false;
    final best = <String, Measurement>{};
    for (final m in _measurements.where((m) => m.type == type && m.publicName.isNotEmpty)) {
      final cur = best[m.playerId];
      if (cur == null || (lower ? m.value < cur.value : m.value > cur.value)) {
        best[m.playerId] = m;
      }
    }
    return Stream.value(best.values.toList()
      ..sort((a, b) => lower ? a.value.compareTo(b.value) : b.value.compareTo(a.value)));
  }

  @override
  Stream<List<Measurement>> playerMeasurements(String playerId) => Stream.value(
      (playerId == Sample.id
              ? Sample.measurements()
              : _measurements.where((m) => m.playerId == playerId).toList())
        ..sort((a, b) => a.recordedAt!.compareTo(b.recordedAt!)));

  @override
  Stream<List<Award>> playerAwards(String playerId) => Stream.value(playerId == Sample.id
      ? Sample.awards()
      : _awards.where((a) => a.playerId == playerId).toList());

  @override
  Stream<PaymentSettings> paymentSettings() => Stream.value(
      const PaymentSettings(venmo: 'Sample-Showcase', cashtag: 'SampleShowcase', payTo: 'Battle Baseball'));

  @override
  Stream<List<(String uid, String role, String name, String email)>> admins() => Stream.value(const [
        (parentUid, 'owner', 'Jamie Reed', 'jamie@example.com'),
        ('demo-admin', 'admin', 'Casey Brooks', 'casey@example.com'),
      ]);

  @override
  Stream<List<StaffAssignment>> staffFor(String eventId) => Stream.value([
        StaffAssignment(
          id: '${eventId}_demo-admin',
          eventId: eventId,
          uid: 'demo-admin',
          role: 'eventAdmin',
          name: 'Casey Brooks',
          email: 'casey@example.com',
        ),
        StaffAssignment(
          id: '${eventId}_demo-volunteer',
          eventId: eventId,
          uid: 'demo-volunteer',
          role: 'staff',
          name: 'Drew Landry',
          email: 'drew@example.com',
        ),
      ]);

  @override
  Future<AppUser?> userByEmail(String email) => Future.value();

  // ---------- Writes ----------

  @override
  Future<void> ensurePublicProfile(Player p) async {}

  @override
  Future<String> saveEvent(String? id, Json data) => _no();
  @override
  Future<void> addDivision(String eventId, String name, int capacity, int order) => _no();
  @override
  Future<void> updateDivision(String id, Json data) => _no();
  @override
  Future<void> deleteDivision(String id) => _no();
  @override
  Future<String> savePlayer(String? id, Json data, Json private) => _no();
  @override
  Future<Registration> reserve({
    required BBEvent event,
    required Division division,
    required Player player,
    required String paymentCode,
    required String paidVia,
    required String payerName,
    required bool skillsOptIn,
  }) =>
      _no();
  @override
  Future<void> flagAlreadyPaid(Registration r) => _no();
  @override
  Future<void> markPaid(Registration r) => _no();
  @override
  Future<void> release(Registration r) => _no();
  @override
  Future<void> offerSpot(Registration r) => _no();
  @override
  Future<void> setRegistration(String id, Json data) => _no();
  @override
  Future<void> addMeasurement(Registration r, BBEvent e, String type, double value) => _no();
  @override
  Future<void> deleteMeasurement(String id) => _no();
  @override
  Future<void> addAward(Registration r, BBEvent e, String type) => _no();
  @override
  Future<void> deleteAward(String id) => _no();
  @override
  Future<void> saveStatLine(Registration r, BBEvent e, StatLine line) => _no();
  @override
  Future<void> deleteStatLine(String id) => _no();
  @override
  Future<void> publishResults(String eventId) => _no();
  @override
  Future<void> sendHostInquiry({
    required String team,
    required String contact,
    required String email,
    String city = '',
    String phone = '',
    String message = '',
  }) =>
      _no();
  @override
  Future<void> savePaymentSettings(PaymentSettings p) => _no();
  @override
  Future<void> setAdmin(AppUser u) => _no();
  @override
  Future<void> removeAdmin(String uid) => _no();
  @override
  Future<void> assignStaff(String eventId, AppUser u, String role) => _no();
  @override
  Future<void> removeStaff(String id) => _no();
}
