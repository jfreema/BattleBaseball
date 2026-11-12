// Event day on a phone: check-in, radar, the scorebook, awards and
// publishing. It runs on jersey numbers: a volunteer types 23, then 68.
import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/screens/admin.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:material_ui/material_ui.dart';

class RunEventScreen extends StatefulWidget {
  const RunEventScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<RunEventScreen> createState() => _RunEventScreenState();
}

class _RunEventScreenState extends State<RunEventScreen> {
  late Stream<BBEvent?> _event;
  late Stream<List<Registration>> _regs;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(RunEventScreen old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) {
      _listen();
      _tab = 0;
    }
  }

  void _listen() {
    _event = Repo.instance.event(widget.eventId);
    _regs = Repo.instance.registrationsFor(widget.eventId);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) => StreamBuilder<BBEvent?>(
          stream: _event,
          builder: (context, es) {
            if (es.hasError) {
              return const StaffPage(title: 'Showcase', children: [Quiet("Couldn't load this.")]);
            }
            if (es.connectionState == ConnectionState.waiting) return const LoadingField();
            final e = es.data;
            if (e == null) return const NotFoundScreen();
            return StreamBuilder<List<Registration>>(
              stream: _regs,
              builder: (context, rs) => _RunEventView(
                key: ValueKey(e.id),
                event: e,
                // Everyone with a spot: paid, checked in, or still held.
                regs: rs.data?.where((r) => r.isConfirmed || r.isHeld).toList(),
                failed: rs.hasError,
                canPublish: Session.instance.isEventAdmin(e.id),
                tab: _tab,
                onTab: (i) => setState(() => _tab = i),
              ),
            );
          },
        ),
      );
}

class _RunEventView extends StatelessWidget {
  const _RunEventView({
    super.key,
    required this.event,
    required this.regs,
    required this.failed,
    required this.canPublish,
    required this.tab,
    required this.onTab,
  });

  final BBEvent event;

  /// Null until the first answer.
  final List<Registration>? regs;
  final bool failed;
  final bool canPublish;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final labels = ['Check-in', 'Measure', 'Stats', 'Awards', if (canPublish) 'Publish'];
    final shown = tab.clamp(0, labels.length - 1);
    final r = regs;
    return StaffPage(
      title: event.name,
      children: [
        _TabStrip(labels: labels, index: shown, onChanged: onTab),
        const SizedBox(height: 22),
        if (failed)
          const Quiet("Couldn't load this.")
        else if (r == null)
          const LoadingField()
        else
          // Every tab stays alive, so a half-typed reading survives a look at
          // the check-in list.
          for (final (i, body) in [
            _CheckIn(regs: r),
            _Measure(e: event, regs: r),
            _Stats(e: event, regs: r),
            _Awards(e: event, regs: r),
            if (canPublish) _Publish(e: event),
          ].indexed)
            Offstage(
              offstage: i != shown,
              child: ExcludeFocus(excluding: i != shown, child: body),
            ),
      ],
    );
  }
}

/// The tabs as one strip with every tab in view; the current one is coral.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: BB.fieldDeep,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: BB.ink, width: 2),
              ),
              child: Row(
                children: [
                  for (final (i, label) in labels.indexed)
                    Expanded(
                      // Longer labels get more of the strip, so five fit a small phone.
                      flex: label.length + 4,
                      child: Semantics(
                        selected: i == index,
                        child: Pressable(
                          onTap: () => onChanged(i),
                          label: label,
                          builder: (context, down, focused) => _tab(label, i == index, focused),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _tab(String label, bool selected, bool focused) => Padding(
        // Room for the lip whether or not it's showing.
        padding: const EdgeInsets.only(bottom: 3),
        child: Container(
          height: 41,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BB.coral : null,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? BB.ink
                  : focused
                      ? BB.cream
                      : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected ? BB.lip(3) : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: BB.labelStyle(15, color: selected ? BB.ink : BB.cream, height: 1),
            ),
          ),
        ),
      );
}

Widget _stack(List<Widget> children) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

/// By jersey number, then by name; players without a number come last.
int _byNumber(Registration a, Registration b) {
  final x = a.jersey, y = b.jersey;
  if (x != y) {
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }
  return a.playerName.compareTo(b.playerName);
}

/// A jersey number as the card's patch, or an empty ring until there is one.
class _Number extends StatelessWidget {
  const _Number(this.number, {this.onPaper = true});

  final int? number;

  /// Ink on paper; cream on the field and on sheets.
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final n = number;
    final face = onPaper ? BB.ink : BB.cream;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: n == null ? null : face,
        border: n == null ? Border.all(color: onPaper ? BB.ink2 : BB.dashed, width: 2) : null,
      ),
      child: n == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$n',
                textScaler: TextScaler.noScaling,
                style: BB.lilita(21, color: onPaper ? BB.cream : BB.ink, height: 1),
              ),
            ),
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
    final answer = await showPrompt(
      context,
      title: r.playerName,
      fields: [
        PromptField(
          'Jersey number',
          initial: r.jersey?.toString() ?? '',
          keyboard: TextInputType.number,
          big: true,
        ),
      ],
      // Only a paid player is checked in; anyone else just gets the number.
      action: r.status == 'paid' ? 'Check in' : 'Save',
    );
    if (answer == null || !mounted) return;
    final n = int.tryParse(answer.first.trim());
    if (n != null && widget.regs.any((x) => x.id != r.id && x.jersey == n)) {
      toast(context, 'Number $n is taken.');
      return;
    }
    await attempt(
      context,
      () => Repo.instance.setRegistration(r.id, {
        'jersey': n,
        if (r.status == 'paid') 'status': 'checkedIn',
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regs = widget.regs;
    final q = _q.toLowerCase();
    final list = regs
        .where((r) => q.isEmpty || r.playerName.toLowerCase().contains(q) || '${r.jersey}' == q)
        .toList();
    final checked = regs.where((r) => r.status == 'checkedIn').length;
    return _stack([
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$checked of ${regs.length}', style: BB.title(28, drop: 3)),
          const SizedBox(width: 10),
          Text('CHECKED IN', style: BB.caps(12.5)),
        ],
      ),
      const SizedBox(height: 14),
      TextField(
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Name or number',
          prefixIcon: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: BBIcon(BBGlyph.search, size: 20, color: BB.creamSoft)),
          ),
        ),
        onChanged: (v) => setState(() => _q = v.trim()),
      ),
      const SizedBox(height: 14),
      if (list.isEmpty) Quiet(regs.isEmpty ? 'No players yet.' : 'No match.'),
      for (final r in list)
        StaffRow(
          r.playerName,
          sub: r.divisionName,
          leading: _Number(r.jersey),
          // Checked in is filed away on kraft; cream is still to do.
          color: r.status == 'checkedIn' ? BB.kraft : BB.cream,
          onTap: () => _checkIn(r),
          trailing: r.status == 'checkedIn'
              ? const _Check()
              : r.isHeld
                  ? const Pill('Not paid')
                  : null,
        ),
    ]);
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: BB.ink, shape: BoxShape.circle),
        child: const BBIcon(BBGlyph.check, size: 18, color: BB.cream, semanticLabel: 'Checked in'),
      );
}

const _typeNames = {'fastball': 'Fastball', 'popTime': 'Pop time', 'dash40': '40 yard'};

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
  final _jerseyFocus = FocusNode();
  final _valueFocus = FocusNode();

  @override
  void dispose() {
    _jersey.dispose();
    _value.dispose();
    _jerseyFocus.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  List<String> get _types => widget.e.skillsContest ? measurementTypes.keys.toList() : const ['fastball'];

  Registration? get _player {
    final n = int.tryParse(_jersey.text.trim());
    return widget.regs.where((r) => r.jersey == n && n != null).firstOrNull;
  }

  Future<void> _save() async {
    final r = _player;
    final v = double.tryParse(_value.text.trim());
    if (r == null || v == null) {
      toast(context, 'Enter a jersey number and a reading.');
      return;
    }
    final type = _types.contains(_type) ? _type : 'fastball';
    final ok = await attempt(
      context,
      () => Repo.instance.addMeasurement(r, widget.e, type, v),
      done: '${r.playerName}: ${fmtValue(v, type)} ${measurementTypes[type]!.unit}',
    );
    if (!ok || !mounted) return;
    _value.clear();
    _jersey.clear();
    // Back to the number, ready for the next player.
    _jerseyFocus.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;
    final type = types.contains(_type) ? _type : 'fastball';
    final typed = _jersey.text.trim();
    final p = _player;
    final big = BB.lilita(34, color: BB.cream, height: 1.15);
    return _stack([
      if (types.length > 1) ...[
        ChipRow(
          children: [
            for (final t in types)
              BBChip(
                _typeNames[t] ?? measurementTypes[t]!.label,
                selected: type == t,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: TextField(
              controller: _jersey,
              focusNode: _jerseyFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              style: big,
              decoration: const InputDecoration(labelText: 'Jersey'),
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
              textInputAction: TextInputAction.done,
              style: big,
              decoration: InputDecoration(labelText: measurementTypes[type]!.unit.toUpperCase()),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // Who that number belongs to, held to one line's height so nothing jumps.
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 26),
        child: Align(
          alignment: Alignment.centerLeft,
          child: p != null
              ? Text(
                  [p.playerName, p.divisionName].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BB.labelStyle(18, height: 1.2),
                )
              : typed.isEmpty
                  ? null
                  : Text('No player wears $typed.', style: BB.bodyStyle(15.5, height: 1.2)),
        ),
      ),
      const SizedBox(height: 12),
      BBButton.primary('Save', expand: true, onPressed: _save),
      const SizedBox(height: 34),
      const SectionTitle('Readings'),
      LiveData<List<Measurement>>(
        stream: () => Repo.instance.eventMeasurements(widget.e.id),
        builder: (context, list) {
          if (list.isEmpty) return const Quiet('No readings yet.');
          final names = {for (final r in widget.regs) r.playerId: r.playerName};
          return RuledPanel(
            children: [
              for (final m in list.take(40))
                _ReadingRow(m: m, name: names[m.playerId] ?? m.publicName),
            ],
          );
        },
      ),
    ]);
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.m, required this.name});

  final Measurement m;
  final String name;

  @override
  Widget build(BuildContext context) {
    // Pop time and the 40 share a unit, so those rows name the drill.
    final sub = [
      if (m.type != 'fastball') _typeNames[m.type] ?? m.type,
      fmtTime(m.recordedAt),
    ].where((s) => s.isNotEmpty).join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: name, style: BB.labelStyle(19, color: BB.ink, height: 1.1)),
                if (sub.isNotEmpty)
                  TextSpan(text: '  $sub', style: BB.bodyStyle(13.5, color: BB.ink2, height: 1.1)),
              ]),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(fmtValue(m.value, m.type), textScaler: TextScaler.noScaling, style: BB.lilita(27, height: 1)),
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 8),
            child: Text(
              m.unit.toUpperCase(),
              textScaler: TextScaler.noScaling,
              style: BB.caps(11, color: BB.ink2),
            ),
          ),
          IconTap(
            BBGlyph.close,
            label: 'Delete reading',
            onTap: () => attempt(context, () => Repo.instance.deleteMeasurement(m.id)),
          ),
        ],
      ),
    );
  }
}

/// A line as a scorebook reads it: "2-3, HR · 2.0 IP 3 K".
String _lineText(StatLine l) => [
      if (l.hasBatting)
        [
          '${l.h}-${l.ab}',
          if (l.hr == 1) 'HR' else if (l.hr > 1) '${l.hr} HR',
        ].join(', '),
      if (l.hasPitching) '${l.ip} IP ${l.k} K',
    ].join(' · ');

/// Opens [builder] as a bottom sheet on phones and a dialog on desktop.
Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (BB.isWide(context)) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(child: builder(context)),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    // Over the bottom bar, not under it.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(child: builder(context)),
    ),
  );
}

/// The scorebook: everyone confirmed for the showcase and their line so far.
class _Stats extends StatelessWidget {
  const _Stats({required this.e, required this.regs});
  final BBEvent e;
  final List<Registration> regs;

  Future<void> _open(BuildContext context, Registration r, StatLine? line) async {
    final saved = await _showSheet<bool>(context, (_) => _StatSheet(reg: r, event: e, line: line));
    // Said from the page: a toast would sit behind the sheet.
    if (saved == true && context.mounted) toast(context, 'Saved');
  }

  @override
  Widget build(BuildContext context) => LiveData<List<StatLine>>(
        stream: () => Repo.instance.eventStatLines(e.id),
        builder: (context, lines) {
          final byPlayer = {for (final l in lines) l.playerId: l};
          final players = regs.where((r) => r.isConfirmed).toList()..sort(_byNumber);
          if (players.isEmpty) return const Quiet('No players yet.');
          return _stack([
            for (final r in players)
              _StatRow(
                reg: r,
                line: byPlayer[r.playerId],
                onTap: () => _open(context, r, byPlayer[r.playerId]),
              ),
          ]);
        },
      );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.reg, required this.line, required this.onTap});

  final Registration reg;
  final StatLine? line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = line == null ? '' : _lineText(line!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Paper(
        onTap: onTap,
        radius: 14,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          children: [
            _Number(reg.jersey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reg.playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BB.labelStyle(19, color: BB.ink, height: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.isEmpty ? 'No line yet' : text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.isEmpty
                        ? BB.bodyStyle(14, color: BB.ink2, height: 1.2)
                        : BB.labelStyle(15.5, color: BB.ink, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One player's line, counted up with steppers.
class _StatSheet extends StatefulWidget {
  const _StatSheet({required this.reg, required this.event, required this.line});

  final Registration reg;
  final BBEvent event;

  /// What's on file, if anything.
  final StatLine? line;

  @override
  State<_StatSheet> createState() => _StatSheetState();
}

class _StatSheetState extends State<_StatSheet> {
  late final Map<String, int> _n = widget.line?.numbers().map((k, v) => MapEntry(k, v as int)) ??
      {'ab': 0, 'h': 0, 'hr': 0, 'rbi': 0, 'r': 0, 'bb': 0, 'outs': 0, 'k': 0, 'pbb': 0};
  bool _busy = false;
  bool _failed = false;

  StatLine get _line => StatLine(
        id: Repo.regId(widget.event.id, widget.reg.playerId),
        eventId: widget.event.id,
        playerId: widget.reg.playerId,
        ab: _n['ab']!,
        h: _n['h']!,
        hr: _n['hr']!,
        rbi: _n['rbi']!,
        r: _n['r']!,
        bb: _n['bb']!,
        outs: _n['outs']!,
        k: _n['k']!,
        pbb: _n['pbb']!,
      );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final line = _line;
    try {
      if (line.hasBatting || line.hasPitching) {
        await Repo.instance.saveStatLine(widget.reg, widget.event, line);
      } else if (widget.line != null) {
        // Counted back down to nothing: no line is truer than a line of zeros.
        await Repo.instance.deleteStatLine(widget.line!.id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Widget _step(String label, String key) => _Stepper(
        label: label,
        value: _n[key]!,
        onChanged: _busy ? null : (v) => setState(() => _n[key] = v),
      );

  static Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = _lineText(_line);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Number(widget.reg.jersey, onPaper: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.reg.playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BB.title(24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text.isEmpty ? 'No line yet' : text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BB.labelStyle(15.5, color: BB.creamSoft, height: 1.2),
                    ),
                  ],
                ),
              ),
              IconTap(
                BBGlyph.close,
                label: 'Close',
                color: BB.cream,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _pair(_step('AB', 'ab'), _step('H', 'h')),
          _pair(_step('HR', 'hr'), _step('RBI', 'rbi')),
          _pair(_step('R', 'r'), _step('BB', 'bb')),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: BB.hairline, width: 1.5))),
            child: Text('PITCHING', style: BB.caps(13, color: BB.cream, tracking: 0.16)),
          ),
          _pair(_step('OUTS', 'outs'), _step('K', 'k')),
          _pair(_step('BB', 'pbb'), _Innings(inningsPitched(_n['outs']!))),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text("Couldn't save. Try again.", style: BB.labelStyle(15.5, color: BB.coral)),
            ),
          const SizedBox(height: 4),
          BBButton.primary('Save', expand: true, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

/// A count between a minus and a plus, each big enough for a thumb.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, textAlign: TextAlign.center, style: BB.caps(12.5)),
        const SizedBox(height: 7),
        Row(
          children: [
            _RoundButton(
              plus: false,
              label: '$label minus',
              onTap: change == null || value <= 0 ? null : () => change(value - 1),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('$value', textScaler: TextScaler.noScaling, style: BB.title(32, drop: 3)),
                  ),
                ),
              ),
            ),
            _RoundButton(
              plus: true,
              label: '$label plus',
              onTap: change == null || value >= 99 ? null : () => change(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.plus, required this.label, required this.onTap});

  final bool plus;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: LipBox(
          radius: 999,
          lip: 3,
          onTap: onTap,
          semanticLabel: label,
          // 52 across with its outline.
          child: SizedBox.square(
            dimension: 47,
            child: Center(
              child: BBIcon(plus ? BBGlyph.plus : BBGlyph.minus, size: 22, color: BB.ink),
            ),
          ),
        ),
      );
}

/// Innings so far, worked out from the outs.
class _Innings extends StatelessWidget {
  const _Innings(this.ip);

  final String ip;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IP', textAlign: TextAlign.center, style: BB.caps(12.5)),
          const SizedBox(height: 7),
          SizedBox(
            height: 55,
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Text(ip, textScaler: TextScaler.noScaling, style: BB.title(32, drop: 3)),
              ),
            ),
          ),
        ],
      );
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

  Future<void> _pick() async {
    final players = [...widget.regs]..sort(_byNumber);
    final id = await _showSheet<String>(context, (_) => _PlayerPicker(regs: players));
    if (id != null && mounted) setState(() => _regId = id);
  }

  Future<void> _give() async {
    final r = widget.regs.where((x) => x.id == _regId).firstOrNull;
    if (r == null) {
      toast(context, 'Pick a player.');
      return;
    }
    final type = _type;
    final ok = await attempt(
      context,
      () => Repo.instance.addAward(r, widget.e, type),
      done: '${awardTypes[type]}: ${r.playerName}',
    );
    // Cleared so a second tap can't give the same award twice.
    if (ok && mounted) setState(() => _regId = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.regs.where((x) => x.id == _regId).firstOrNull;
    return _stack([
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final a in awardTypes.entries)
            BBChip(a.value, selected: _type == a.key, onTap: () => setState(() => _type = a.key)),
        ],
      ),
      const SizedBox(height: 12),
      StaffRow(
        r?.playerName ?? 'Pick a player',
        sub: r?.divisionName,
        leading: r == null ? null : _Number(r.jersey),
        chevron: true,
        onTap: _pick,
      ),
      const SizedBox(height: 4),
      BBButton.primary('Give award', expand: true, onPressed: _give),
      const SizedBox(height: 34),
      const SectionTitle('Awards'),
      LiveData<List<Award>>(
        stream: () => Repo.instance.eventAwards(widget.e.id),
        builder: (context, list) {
          if (list.isEmpty) return const Quiet('No awards yet.');
          final names = {for (final r in widget.regs) r.playerId: r.playerName};
          return _stack([
            for (final (i, a) in list.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AwardLine(
                        title: a.label,
                        sub: [names[a.playerId] ?? a.publicName, a.divisionName]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        mark: awardMark(a.type),
                        tilt: i.isEven ? -8 : 7,
                        onPaper: false,
                      ),
                    ),
                    IconTap(
                      BBGlyph.close,
                      label: 'Remove ${a.label}',
                      color: BB.cream,
                      onTap: () => attempt(context, () => Repo.instance.deleteAward(a.id)),
                    ),
                  ],
                ),
              ),
          ]);
        },
      ),
    ]);
  }
}

/// Everyone at the showcase, by jersey number. Answers with a registration id.
class _PlayerPicker extends StatelessWidget {
  const _PlayerPicker({required this.regs});

  final List<Registration> regs;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text('Player', style: BB.title(26))),
                ),
                IconTap(
                  BBGlyph.close,
                  label: 'Close',
                  color: BB.cream,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (regs.isEmpty) const Quiet('No players yet.'),
            for (final r in regs)
              Pressable(
                onTap: () => Navigator.of(context).pop(r.id),
                builder: (context, down, focused) => Opacity(
                  opacity: down ? 0.6 : 1,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: focused ? BB.cream : BB.hairline, width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _Number(r.jersey, onPaper: false),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            r.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BB.labelStyle(18, height: 1.1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(r.divisionName.toUpperCase(), style: BB.caps(12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Publish extends StatefulWidget {
  const _Publish({required this.e});
  final BBEvent e;
  @override
  State<_Publish> createState() => _PublishState();
}

class _PublishState extends State<_Publish> {
  bool _busy = false;

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await Repo.instance.publishResults(widget.e.id);
      if (mounted) toast(context, 'Results published');
    } catch (_) {
      if (mounted) toast(context, "Couldn't publish. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final public = widget.e.resultsPublished;
    return _stack([
      SectionTitle(public ? 'Results are public' : 'Results are private'),
      BBButton.primary(
        public ? 'Publish again' : 'Publish results',
        expand: true,
        busy: _busy,
        onPressed: _publish,
      ),
    ]);
  }
}
