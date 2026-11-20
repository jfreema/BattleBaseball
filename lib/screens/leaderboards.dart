// Leaders: one board per stat and age group (10U, 12U, 14U), each player's
// best from every showcase. The top three are mini cards, the rest sit on one
// ruled panel.
import 'dart:async';

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The boards in the order their chips appear, and what each is called.
const _boards = <String, String>{
  'fastball': 'Fastball',
  'dash40': '40 yard',
  'homeRuns': 'Home run',
  'popTime': 'Pop time',
};

/// How many places a board lists.
const _places = 50;

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  // Every board is read up front: the board chips only show when more than
  // one of them has readings.
  final _readings = <String, List<Measurement>>{};
  final _subs = <StreamSubscription<List<Measurement>>>[];
  StreamSubscription<List<Player>>? _familySub;
  String? _uid;
  Set<String> _mine = const {};
  String _type = _boards.keys.first;
  String? _group;

  @override
  void initState() {
    super.initState();
    for (final type in _boards.keys) {
      final board = type == 'homeRuns' ? Repo.instance.homeRunReadings() : Repo.instance.readings(type);
      _subs.add(board.listen(
            (list) => _put(type, list),
            // A board that can't be read is an empty board.
            onError: (Object _) => _put(type, _readings[type] ?? const []),
          ));
    }
    Session.instance.addListener(_watchFamily);
    _watchFamily();
  }

  void _put(String type, List<Measurement> list) {
    if (mounted) setState(() => _readings[type] = list);
  }

  /// Follows the signed-in family's players, whose rows get a coral dot.
  void _watchFamily() {
    final uid = Session.instance.uid;
    if (uid == _uid) return;
    _uid = uid;
    _familySub?.cancel();
    _familySub = null;
    if (uid == null) {
      if (mounted && _mine.isNotEmpty) setState(() => _mine = const {});
      return;
    }
    _familySub = Repo.instance.myPlayers().listen(
      (players) {
        if (mounted) setState(() => _mine = {for (final p in players) p.id});
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    Session.instance.removeListener(_watchFamily);
    _familySub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _LeadersView(
        loading: !_boards.keys.every(_readings.containsKey),
        readings: _readings,
        mine: _mine,
        type: _type,
        group: _group,
        onType: (t) => setState(() => _type = t),
        onGroup: (g) => setState(() => _group = g),
      );
}

class _LeadersView extends StatelessWidget {
  const _LeadersView({
    required this.loading,
    required this.readings,
    required this.mine,
    required this.type,
    required this.group,
    required this.onType,
    required this.onGroup,
  });

  final bool loading;

  /// Each board's published readings, every showcase's.
  final Map<String, List<Measurement>> readings;

  /// Ids of the signed-in family's own players.
  final Set<String> mine;
  final String type;
  /// The age group picked, or null for the first one with readings.
  final String? group;
  final ValueChanged<String> onType;
  final ValueChanged<String> onGroup;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final live = [
      for (final t in _boards.keys)
        if (bestReadings(readings[t] ?? const [], t).isNotEmpty) t,
    ];
    // The chosen board, unless it is empty and another one isn't.
    final board = live.isEmpty || live.contains(type) ? type : live.first;
    final all = readings[board] ?? const <Measurement>[];
    // The age group picked, or else the youngest with readings on this board.
    final filled = [
      for (final g in ageGroups)
        if (bestReadings(all, board, ageGroup: g).isNotEmpty) g,
    ];
    final age = group ?? filled.firstOrNull ?? ageGroups.first;
    final list = bestReadings(all, board, ageGroup: age).take(_places).toList();
    final unit = board == 'homeRuns' ? 'HR' : measurementTypes[board]?.unit ?? '';
    void open(Measurement m) => context.go('/players/${m.playerId}');

    return PageFrame(
      // On desktop the list is one column under its title, as wide as the mock's.
      column: wide ? 560 : 640,
      children: [
        const TabHeader(),
        PageTitle('$age ${_boards[board]} leaders', padding: const EdgeInsets.only(top: 6, bottom: 13)),
        if (loading)
          const LoadingField()
        else if (live.isEmpty)
          const Quiet('No readings yet.')
        else ...[
          if (live.length > 1) ...[
            Semantics(
              container: true,
              label: 'Board',
              child: ChipRow(children: [
                for (final t in live)
                  BBChip(t == 'homeRuns' ? 'Home runs' : _boards[t]!, selected: t == board, onTap: () => onType(t)),
              ]),
            ),
            const SizedBox(height: 4),
          ],
          Semantics(
            container: true,
            label: 'Age group',
            child: ChipRow(children: [
              for (final g in ageGroups) BBChip(g, selected: age == g, onTap: () => onGroup(g)),
            ]),
          ),
          SizedBox(height: wide ? 17 : 15),
          if (list.isEmpty) Quiet('No $age readings on this board yet.'),
          for (final (i, m) in list.take(3).indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            MiniCard(
              rank: i + 1,
              name: m.publicName,
              sub: m.eventName.isEmpty ? null : m.eventName,
              value: fmtValue(m.value, board),
              unit: unit,
              first: i == 0,
              dot: mine.contains(m.playerId),
              onTap: () => open(m),
            ),
          ],
          if (list.length > 3) ...[
            const SizedBox(height: 14),
            RuledPanel(children: [
              for (final (i, m) in list.skip(3).indexed)
                RuledRow(
                  rank: i + 4,
                  name: m.publicName,
                  sub: m.eventName.isEmpty ? null : m.eventName,
                  value: fmtValue(m.value, board),
                  unit: unit,
                  dot: mine.contains(m.playerId),
                  onTap: () => open(m),
                ),
            ]),
          ],
        ],
      ],
    );
  }
}
