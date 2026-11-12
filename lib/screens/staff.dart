import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:material_ui/material_ui.dart';

/// Event day: check-in, measurements, awards, and publishing. Runs on
/// jersey numbers: a radar volunteer types "23", then "68".
class RunEventScreen extends StatelessWidget {
  const RunEventScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final repo = Repo.instance;
    final canPublish = Session.instance.isEventAdmin(eventId);
    return StreamBuilder<BBEvent?>(
      stream: repo.event(eventId),
      builder: (context, es) {
        final e = es.data;
        if (e == null) return Scaffold(appBar: AppBar(), body: streamState(es));
        return StreamBuilder<List<Registration>>(
          stream: repo.registrationsFor(eventId),
          builder: (context, rs) {
            final regs = (rs.data ?? const <Registration>[])
                .where((r) => r.isConfirmed || r.isHeld)
                .toList();
            return DefaultTabController(
              length: canPublish ? 4 : 3,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(e.name),
                  bottom: TabBar(
                    isScrollable: true,
                    labelStyle: BB.labelStyle(15),
                    indicatorColor: BB.coral,
                    tabs: [
                      const Tab(text: 'Check-in'),
                      const Tab(text: 'Measure'),
                      const Tab(text: 'Awards'),
                      if (canPublish) const Tab(text: 'Publish'),
                    ],
                  ),
                ),
                body: rs.hasError
                    ? streamState(rs)
                    : TabBarView(children: [
                        _CheckIn(regs: regs),
                        _Measure(e: e, regs: regs),
                        _Awards(e: e, regs: regs),
                        if (canPublish) _Publish(e: e),
                      ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _CheckIn extends StatefulWidget {
  const _CheckIn({required this.regs});
  final List<Registration> regs;
  @override
  State<_CheckIn> createState() => _CheckInState();
}

class _CheckInState extends State<_CheckIn> {
  String _q = '';

  Future<void> _checkIn(Registration r) async {
    final jersey = TextEditingController(text: r.jersey?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Check in ${r.playerName}'),
        content: TextField(
          controller: jersey,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Jersey number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Check in')),
        ],
      ),
    );
    if (ok != true) return;
    final n = int.tryParse(jersey.text.trim());
    final taken = widget.regs.any((x) => x.id != r.id && x.jersey == n && n != null);
    if (taken && mounted) {
      toast(context, 'Number $n is already taken at this event.');
      return;
    }
    await Repo.instance.setRegistration(r.id, {
      'jersey': n,
      if (r.status == 'paid') 'status': 'checkedIn',
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = widget.regs
        .where((r) => q.isEmpty || r.playerName.toLowerCase().contains(q) || '${r.jersey}' == q)
        .toList();
    final checked = widget.regs.where((r) => r.status == 'checkedIn').length;
    return PageBody(children: [
      Text('$checked of ${widget.regs.length} checked in', style: BB.labelStyle(16, color: BB.muted)),
      const SizedBox(height: 10),
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search name or number'),
        onChanged: (v) => setState(() => _q = v.trim()),
      ),
      const SizedBox(height: 12),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GumCard(
            edge: r.status == 'checkedIn' ? BB.mint : r.isHeld ? BB.lemon : BB.blue,
            onTap: () => _checkIn(r),
            child: Row(children: [
              SizedBox(
                width: 48,
                child: Text(r.jersey == null ? '–' : '#${r.jersey}', style: BB.title(20)),
              ),
              Expanded(child: Text('${r.playerName}\n${r.divisionName}', style: BB.labelStyle(15))),
              if (r.status == 'checkedIn')
                const StatusChip('Checked in', color: BB.mint)
              else if (r.isHeld)
                const StatusChip('Payment pending', color: BB.lemon),
            ]),
          ),
        ),
    ]);
  }
}

class _Measure extends StatefulWidget {
  const _Measure({required this.e, required this.regs});
  final BBEvent e;
  final List<Registration> regs;
  @override
  State<_Measure> createState() => _MeasureState();
}

class _MeasureState extends State<_Measure> {
  String _type = 'fastball';
  final _jersey = TextEditingController();
  final _value = TextEditingController();
  final _valueFocus = FocusNode();

  @override
  void dispose() {
    _jersey.dispose();
    _value.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  Registration? get _player {
    final n = int.tryParse(_jersey.text.trim());
    return widget.regs.where((r) => r.jersey == n && n != null).firstOrNull;
  }

  Future<void> _save() async {
    final r = _player;
    final v = double.tryParse(_value.text.trim());
    if (r == null || v == null) {
      toast(context, 'Enter a jersey number from check-in and a reading.');
      return;
    }
    await Repo.instance.addMeasurement(r, widget.e, _type, v);
    if (!mounted) return;
    toast(context, '${r.playerName}: ${fmtValue(v, _type)} ${measurementTypes[_type]!.unit}');
    _value.clear();
    _jersey.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.e.skillsContest ? measurementTypes.keys.toList() : ['fastball'];
    final p = _player;
    return PageBody(children: [
      Wrap(spacing: 8, children: [
        for (final t in types)
          ChoiceChip(
            label: Text(measurementTypes[t]!.label),
            selected: _type == t,
            onSelected: (_) => setState(() => _type = t),
          ),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        SizedBox(
          width: 130,
          child: TextField(
            controller: _jersey,
            keyboardType: TextInputType.number,
            style: BB.title(28),
            decoration: const InputDecoration(labelText: 'Jersey #'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _valueFocus.requestFocus(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _value,
            focusNode: _valueFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: BB.title(28),
            decoration: InputDecoration(labelText: measurementTypes[_type]!.unit),
            onSubmitted: (_) => _save(),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        p == null
            ? (_jersey.text.isEmpty ? 'Type a jersey number' : 'No player has that number yet')
            : '${p.playerName} · ${p.divisionName}',
        style: BB.labelStyle(16, color: p == null ? BB.muted : BB.going),
      ),
      const SizedBox(height: 14),
      CandyButton(expand: true, label: 'Save reading', onPressed: _save),
      const SectionLabel('Recent readings'),
      StreamBuilder<List<Measurement>>(
        stream: Repo.instance.eventMeasurements(widget.e.id),
        builder: (context, s) {
          final list = s.data ?? const <Measurement>[];
          final names = {for (final r in widget.regs) r.playerId: r.playerName};
          if (list.isEmpty) return const EmptyNote('Readings show here as they come in.');
          return Column(children: [
            for (final m in list.take(40))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(names[m.playerId] ?? m.publicName, style: BB.labelStyle(15)),
                subtitle: Text('${measurementTypes[m.type]?.label} · ${fmtTime(m.recordedAt)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${fmtValue(m.value, m.type)} ${m.unit}', style: BB.title(18)),
                  IconButton(
                    tooltip: 'Delete reading',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => Repo.instance.deleteMeasurement(m.id),
                  ),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }
}

class _Awards extends StatefulWidget {
  const _Awards({required this.e, required this.regs});
  final BBEvent e;
  final List<Registration> regs;
  @override
  State<_Awards> createState() => _AwardsState();
}

class _AwardsState extends State<_Awards> {
  String _type = 'mvp';
  String? _regId;

  @override
  Widget build(BuildContext context) => PageBody(children: [
        Text('Award', style: BB.labelStyle(15, color: BB.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in awardTypes.entries)
            ChoiceChip(
              label: Text(a.value),
              selected: _type == a.key,
              onSelected: (_) => setState(() => _type = a.key),
            ),
        ]),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _regId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Player'),
          dropdownColor: BB.card,
          items: [
            for (final r in widget.regs)
              DropdownMenuItem(
                value: r.id,
                child: Text('${r.jersey == null ? '' : '#${r.jersey} '}${r.playerName} · ${r.divisionName}'),
              ),
          ],
          onChanged: (v) => setState(() => _regId = v),
        ),
        const SizedBox(height: 14),
        CandyButton(
          expand: true,
          label: 'Give award',
          onPressed: () async {
            final r = widget.regs.where((x) => x.id == _regId).firstOrNull;
            if (r == null) return toast(context, 'Pick a player.');
            await Repo.instance.addAward(r, widget.e, _type);
            if (context.mounted) toast(context, '${awardTypes[_type]}: ${r.playerName}');
          },
        ),
        const SectionLabel('Awards so far'),
        StreamBuilder<List<Award>>(
          stream: Repo.instance.eventAwards(widget.e.id),
          builder: (context, s) {
            final list = s.data ?? const <Award>[];
            final names = {for (final r in widget.regs) r.playerId: r.playerName};
            if (list.isEmpty) return const EmptyNote('No awards yet.');
            return Column(children: [
              for (final a in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AwardBadge(a),
                  title: Text(names[a.playerId] ?? a.publicName),
                  subtitle: Text(a.divisionName),
                  trailing: IconButton(
                    tooltip: 'Remove award',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => Repo.instance.deleteAward(a.id),
                  ),
                ),
            ]);
          },
        ),
      ]);
}

class _Publish extends StatefulWidget {
  const _Publish({required this.e});
  final BBEvent e;
  @override
  State<_Publish> createState() => _PublishState();
}

class _PublishState extends State<_Publish> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => PageBody(children: [
        GumCard(
          edge: BB.lemon,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.e.resultsPublished ? 'Results are public' : 'Results are drafts', style: BB.title(22)),
            const SizedBox(height: 6),
            Text(
              widget.e.resultsPublished
                  ? 'Velocities and awards from this event show on results, leaderboards, and player '
                      'profiles. Readings added from now on go public right away.'
                  : 'Nothing from this event is public until you publish. Publishing puts velocities '
                      'and awards on the results page, leaderboards, and player profiles (only for '
                      'players with public profiles), and marks the event Final.',
              style: const TextStyle(color: BB.cardMuted),
            ),
            const SizedBox(height: 14),
            CandyButton(
              busy: _busy,
              label: widget.e.resultsPublished ? 'Publish again' : 'Publish results',
              icon: Icons.campaign,
              onPressed: () async {
                setState(() => _busy = true);
                try {
                  await Repo.instance.publishResults(widget.e.id);
                  if (context.mounted) toast(context, 'Results published');
                } catch (err) {
                  if (context.mounted) toast(context, "Couldn't publish: $err");
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
            ),
          ]),
        ),
      ]);
}
