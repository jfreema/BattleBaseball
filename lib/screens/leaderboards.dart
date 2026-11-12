// Leaders: each player's best reading on a board. The top three are mini
// cards, the rest sit on one ruled panel.
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
  'popTime': 'Pop time',
  'dash40': '40 yard',
};

/// How many places a board lists.
const _places = 50;

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  // All three boards are read up front: the board chips only show when more
  // than one of them has readings.
  final _readings = <String, List<Measurement>>{};
  final _subs = <StreamSubscription<List<Measurement>>>[];
  StreamSubscription<List<Player>>? _familySub;
  String? _uid;
  Set<String> _mine = const {};
  String _type = _boards.keys.first;
  int? _grad;

  @override
  void initState() {
    super.initState();
    for (final type in _boards.keys) {
      _subs.add(Repo.instance.leaderboard(type).listen(
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
        grad: _grad,
        onType: (t) => setState(() => _type = t),
        onGrad: (g) => setState(() => _grad = g),
      );
}

class _LeadersView extends StatelessWidget {
  const _LeadersView({
    required this.loading,
    required this.readings,
    required this.mine,
    required this.type,
    required this.grad,
    required this.onType,
    required this.onGrad,
  });

  final bool loading;

  /// Each board's readings, best first, one per player.
  final Map<String, List<Measurement>> readings;

  /// Ids of the signed-in family's own players.
  final Set<String> mine;
  final String type;
  final int? grad;
  final ValueChanged<String> onType;
  final ValueChanged<int?> onGrad;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final live = [
      for (final t in _boards.keys)
        if (readings[t]?.isNotEmpty ?? false) t,
    ];
    // The chosen board, unless it is empty and another one isn't.
    final board = live.isEmpty || live.contains(type) ? type : live.first;
    final all = readings[board] ?? const <Measurement>[];
    final years = {for (final m in all) ?m.gradYear}.toList()..sort();
    // A class year picked on one board may not be on the next.
    final year = years.contains(grad) ? grad : null;
    final list = [
      for (final m in all)
        if (year == null || m.gradYear == year) m,
    ].take(_places).toList();
    final unit = measurementTypes[board]?.unit ?? '';
    void open(Measurement m) => context.go('/players/${m.playerId}');

    return PageFrame(
      // On desktop the list is one column under its title, as wide as the mock's.
      column: wide ? 560 : 640,
      children: [
        const TabHeader(),
        PageTitle('${_boards[board]} leaders', padding: const EdgeInsets.only(top: 6, bottom: 13)),
        if (loading)
          const LoadingField()
        else if (all.isEmpty)
          const Quiet('No readings yet.')
        else ...[
          if (live.length > 1) ...[
            Semantics(
              container: true,
              label: 'Board',
              child: ChipRow(children: [
                for (final t in live)
                  BBChip(_boards[t]!, selected: t == board, onTap: () => onType(t)),
              ]),
            ),
            const SizedBox(height: 4),
          ],
          if (years.isNotEmpty)
            Semantics(
              container: true,
              label: 'Class year',
              child: ChipRow(children: [
                BBChip('All', selected: year == null, onTap: () => onGrad(null)),
                for (final y in years)
                  BBChip('$y', selected: year == y, onTap: () => onGrad(y)),
              ]),
            ),
          SizedBox(height: wide ? 17 : 15),
          for (final (i, m) in list.take(3).indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            MiniCard(
              rank: i + 1,
              name: m.publicName,
              sub: m.gradYear == null ? null : 'Class of ${m.gradYear}',
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
                  sub: m.gradYear?.toString(),
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
