// The sample player. Mason R. is the one made-up player the real app shows:
// on Home and at /players/sample, always beside a SAMPLE stamp.
import 'package:battle_baseball/data/models.dart';

abstract final class Sample {
  static const id = 'sample';

  static const profile = PublicProfile(
    id: id,
    name: 'Mason R.',
    gradYear: 2031,
    positions: ['P', 'SS'],
    bats: 'R',
    throws: 'R',
    state: 'LA',
    jersey: 12,
    sample: true,
  );

  static const topFastball = 71.0;

  /// The four showcases he has played, oldest first.
  static final _showcases = [
    (id: 'sample-1', name: 'Fall Showcase', division: '11U', date: DateTime(2025, 10, 18)),
    (id: 'sample-2', name: 'Spring Showcase', division: '11U', date: DateTime(2026, 3, 14)),
    (id: 'sample-3', name: 'Summer Showcase', division: '11U', date: DateTime(2026, 6, 6)),
    (id: 'sample-4', name: 'Fall Showcase', division: '12U', date: DateTime(2026, 10, 17)),
  ];

  static Measurement _reading(int at, String type, double value, {String? playerId}) {
    final s = _showcases[at];
    return Measurement(
      id: 'sample-$type-$at',
      eventId: s.id,
      eventName: s.name,
      playerId: playerId ?? id,
      publicName: profile.name,
      divisionName: s.division,
      gradYear: profile.gradYear,
      type: type,
      value: value,
      recordedAt: s.date,
      published: true,
    );
  }

  /// Fastball at each showcase, then pop time and the 40, oldest first.
  static List<Measurement> measurements({String? playerId}) => [
        _reading(0, 'fastball', 64, playerId: playerId),
        _reading(1, 'fastball', 67, playerId: playerId),
        _reading(2, 'fastball', 68, playerId: playerId),
        _reading(3, 'fastball', 71, playerId: playerId),
        _reading(3, 'popTime', 2.18, playerId: playerId),
        _reading(3, 'dash40', 5.62, playerId: playerId),
      ];

  static List<Measurement> get fastballs =>
      measurements().where((m) => m.type == 'fastball').toList();

  /// Game stats at each showcase. They total 17 AB, 7 H, 1 HR, 5 RBI, 4 R,
  /// 3 BB at the plate and 6.0 IP, 9 K, 2 BB on the mound.
  static List<StatLine> statLines({String? playerId}) {
    const lines = [
      (ab: 4, h: 1, hr: 0, rbi: 1, r: 1, bb: 1, outs: 3, k: 1, pbb: 1),
      (ab: 4, h: 2, hr: 0, rbi: 1, r: 1, bb: 1, outs: 6, k: 3, pbb: 0),
      (ab: 4, h: 2, hr: 1, rbi: 2, r: 1, bb: 0, outs: 3, k: 2, pbb: 1),
      (ab: 5, h: 2, hr: 0, rbi: 1, r: 1, bb: 1, outs: 6, k: 3, pbb: 0),
    ];
    return [
      for (final (i, l) in lines.indexed)
        StatLine(
          id: 'sample-line-$i',
          eventId: _showcases[i].id,
          eventName: _showcases[i].name,
          playerId: playerId ?? id,
          publicName: profile.name,
          divisionName: _showcases[i].division,
          gradYear: profile.gradYear,
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
          recordedAt: _showcases[i].date,
        ),
    ];
  }

  static List<Award> awards({String? playerId}) => [
        Award(
          id: 'sample-award-mvp',
          eventId: 'sample-2',
          eventName: 'Spring Showcase',
          playerId: playerId ?? id,
          publicName: profile.name,
          divisionName: '12U',
          type: 'mvp',
          published: true,
        ),
        Award(
          id: 'sample-award-pitcher',
          eventId: 'sample-1',
          eventName: 'Fall Showcase',
          playerId: playerId ?? id,
          publicName: profile.name,
          divisionName: '11U',
          type: 'topPitcher',
          published: true,
        ),
      ];

  /// How many showcases the sample player has been to.
  static int get showcases => _showcases.length;
}
