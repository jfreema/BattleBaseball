import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:material_ui/material_ui.dart';

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});
  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  String _type = 'fastball';
  int? _grad;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Leaderboards')),
        body: StreamBuilder<List<Measurement>>(
          stream: Repo.instance.leaderboard(_type),
          builder: (context, s) {
            final all = s.data ?? const <Measurement>[];
            final years = {for (final m in all) if (m.gradYear != null) m.gradYear!}.toList()..sort();
            final list = all.where((m) => _grad == null || m.gradYear == _grad).toList();
            final t = measurementTypes[_type]!;
            return PageBody(children: [
              const Text(
                'Every number here was measured by staff at a Battle Baseball Showcase. '
                'Players appear only if their parents turned on a public profile.',
                style: TextStyle(color: BB.muted),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in measurementTypes.entries)
                  ChoiceChip(
                    label: Text(e.value.label),
                    selected: _type == e.key,
                    onSelected: (_) => setState(() => _type = e.key),
                  ),
              ]),
              if (years.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: const Text('All classes'),
                    selected: _grad == null,
                    onSelected: (_) => setState(() => _grad = null),
                  ),
                  for (final y in years)
                    ChoiceChip(
                      label: Text('Class of $y'),
                      selected: _grad == y,
                      onSelected: (_) => setState(() => _grad = y),
                    ),
                ]),
              ],
              const SizedBox(height: 16),
              if (streamState(s) case final w?)
                w
              else if (list.isEmpty)
                const EmptyNote('Leaders post here after the first showcase.')
              else
                for (final (i, m) in list.take(50).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GumCard(
                      edge: i == 0 ? BB.lemon : i < 3 ? BB.tangerine : BB.blue,
                      child: Row(children: [
                        SizedBox(width: 38, child: Text('${i + 1}', style: BB.title(22))),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.publicName, style: BB.labelStyle(17)),
                            Text(
                              [if (m.gradYear != null) 'Class of ${m.gradYear}', m.eventName].join(' · '),
                              style: const TextStyle(color: BB.cardMuted, fontSize: 14),
                            ),
                          ]),
                        ),
                        Readout(value: fmtValue(m.value, m.type), unit: t.unit, size: 30),
                      ]),
                    ),
                  ),
            ]);
          },
        ),
      );
}
