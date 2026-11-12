// Staff tools: the hub, showcase setup, staff, payments and the owner's
// screens, and the few widgets these share with the event-day screen.
// Volunteers use them on a phone, so every screen is a short list of big
// rows and says very little.
import 'dart:async';

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/scheme.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Staff screens are forms and lists; they read best in a narrow column.
const staffWidth = 680.0;

/// The frame of a staff screen: back to the hub, a title, then the content.
class StaffPage extends StatelessWidget {
  const StaffPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.back = 'Staff tools',
    this.backTo = '/admin',
  });

  final String title;
  final List<Widget> children;

  /// Sits at the right of the title.
  final Widget? trailing;
  final String back;

  /// Staff paths don't nest the way their screens do, so back is spelled out.
  final String backTo;

  @override
  Widget build(BuildContext context) => PageFrame(
        column: staffWidth,
        children: [
          BackHeader(back, onBack: () => context.go(backTo)),
          PageTitle(title, trailing: trailing),
          ...children,
        ],
      );
}

/// Listens to a stream made once, so a rebuild never resubscribes, and shows
/// the spinner or a quiet line until there is something to build from.
class LiveData<T extends Object> extends StatefulWidget {
  const LiveData({super.key, required this.stream, required this.builder});

  final Stream<T> Function() stream;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<LiveData<T>> createState() => _LiveDataState<T>();
}

class _LiveDataState<T extends Object> extends State<LiveData<T>> {
  late final Stream<T> _stream = widget.stream();

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return const Quiet("Couldn't load this.");
          final data = snap.data;
          if (data == null) return const LoadingField();
          return widget.builder(context, data);
        },
      );
}

/// A paper row: a name, a small line under it, and room at either end.
class StaffRow extends StatelessWidget {
  const StaffRow(
    this.title, {
    super.key,
    this.sub,
    this.leading,
    this.trailing,
    this.onTap,
    this.color,
    this.chevron = false,
    this.sink = true,
  });

  final String title;
  final String? sub;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  Color get _color => color ?? BB.cream;

  /// Ends the row in a chevron, for a row that leads somewhere.
  final bool chevron;

  /// Turn off when [trailing] is a button of its own.
  final bool sink;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Paper(
          onTap: onTap,
          sink: sink,
          color: _color,
          radius: 14,
          padding: EdgeInsets.fromLTRB(leading == null ? 16 : 10, 8, 12, 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BB.labelStyle(19, color: BB.ink, height: 1.1),
                      ),
                      if (sub != null && sub!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            sub!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BB.bodyStyle(14, color: BB.ink2, height: 1.25),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                if (chevron) ...[
                  const SizedBox(width: 8),
                  BBIcon(BBGlyph.forward, size: 22, color: BB.ink),
                ],
              ],
            ),
          ),
        ),
      );
}

/// The quiet link that keeps a first-timer's instructions off the screen.
class HowThisWorks extends StatelessWidget {
  const HowThisWorks(this.items, {super.key});

  final List<FinePrintItem> items;

  @override
  Widget build(BuildContext context) =>
      TextLink('How this works', onTap: () => showFinePrint(context, items: items, title: 'How this works', legal: false));
}

/// Runs a write and says so if it fails, so a dropped connection at the
/// field never passes for a saved change. True when it went through.
Future<bool> attempt(BuildContext context, Future<void> Function() write, {String? done}) async {
  try {
    await write();
    if (done != null && context.mounted) toast(context, done);
    return true;
  } catch (_) {
    if (context.mounted) toast(context, "Couldn't save. Try again.");
    return false;
  }
}

/// One field of a [showPrompt] dialog.
class PromptField {
  const PromptField(this.label, {this.initial = '', this.hint, this.keyboard, this.big = false});

  final String label;
  final String initial;
  final String? hint;
  final TextInputType? keyboard;

  /// Sets what's typed in large numerals, for a jersey number.
  final bool big;
}

/// A small dialog: a title, a few fields, and two buttons. Answers with what
/// was typed in each field, or null when it was cancelled.
Future<List<String>?> showPrompt(
  BuildContext context, {
  required String title,
  String? note,
  List<PromptField> fields = const [],
  required String action,
  String cancel = 'Cancel',
}) =>
    showDialog<List<String>>(
      context: context,
      builder: (_) => _Prompt(title: title, note: note, fields: fields, action: action, cancel: cancel),
    );

class _Prompt extends StatefulWidget {
  const _Prompt({
    required this.title,
    required this.note,
    required this.fields,
    required this.action,
    required this.cancel,
  });

  final String title;
  final String? note;
  final List<PromptField> fields;
  final String action;
  final String cancel;

  @override
  State<_Prompt> createState() => _PromptState();
}

class _PromptState extends State<_Prompt> {
  late final _controllers = [for (final f in widget.fields) TextEditingController(text: f.initial)];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() => Navigator.of(context).pop([for (final c in _controllers) c.text]);

  @override
  Widget build(BuildContext context) {
    final last = widget.fields.length - 1;
    return Dialog(
      // Wider than the default on a small phone, so the buttons fit side by side.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(widget.title, style: BB.title(26))),
              if (widget.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(widget.note!, style: BB.bodyStyle(16)),
                ),
              for (final (i, f) in widget.fields.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 16 : 12),
                  child: TextField(
                    controller: _controllers[i],
                    autofocus: i == 0,
                    keyboardType: f.keyboard,
                    textInputAction: i == last ? TextInputAction.done : TextInputAction.next,
                    style: f.big ? BB.lilita(30, color: BB.cream, height: 1.2) : null,
                    decoration: InputDecoration(labelText: f.label, hintText: f.hint),
                    onSubmitted: i == last ? (_) => _done() : null,
                  ),
                ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  BBButton.quiet(widget.cancel, onPressed: () => Navigator.of(context).pop()),
                  BBButton.primary(widget.action, onPressed: _done),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _stack(List<Widget> children) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

String _shortStatus(String status) => switch (status) {
      'draft' => 'Draft',
      'open' => 'Open',
      'closed' => 'Closed',
      'live' => 'Live',
      'final' => 'Final',
      'rainedOut' => 'Rained out',
      _ => status,
    };

String _payApp(Registration r) => r.paidVia == 'cashapp' ? 'Cash App' : 'Venmo';

String _joined(Iterable<String?> parts) =>
    parts.where((p) => p != null && p.trim().isNotEmpty).join(' · ');

/// The hub. What shows depends on the role: the owner sees everything,
/// Battle Baseball admins see every showcase, and event admins and
/// volunteers see only the showcases they're named on.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        // Volunteers have nothing to do with payments, so they aren't shown the door.
        final payments = s.isAdmin || s.assignments.any((a) => a.role == 'eventAdmin');
        return StaffPage(
          title: 'Staff tools',
          back: 'Account',
          backTo: '/account',
          trailing: s.isAdmin
              ? Pill(s.isOwner ? 'Owner' : 'Admin', color: BB.lemon)
              : const Pill('Event staff'),
          children: [
            if (payments)
              StaffRow('Payments', chevron: true, onTap: () => context.go('/admin/payments')),
            if (s.isOwner) ...[
              StaffRow('Payment check', chevron: true, onTap: () => context.go('/admin/payment-check')),
              StaffRow('Admins', chevron: true, onTap: () => context.go('/admin/admins')),
              StaffRow('Payment settings', chevron: true, onTap: () => context.go('/admin/settings')),
            ],
            if (s.isAdmin)
              StaffRow('Color scheme', chevron: true, onTap: () => context.go('/admin/colors')),
            if (payments) const SizedBox(height: 22),
            SectionTitle(
              'Showcases',
              trailing: s.isAdmin
                  ? BBButton.paper(
                      'New',
                      small: true,
                      icon: const BBIcon(BBGlyph.plus),
                      onPressed: () => context.go('/admin/events/new'),
                    )
                  : null,
            ),
            LiveData<List<BBEvent>>(
              // Drafts are an admin's to read; ask again if the role changes.
              key: ValueKey(s.isAdmin),
              stream: () => s.isAdmin ? Repo.instance.allEvents() : Repo.instance.publicEvents(),
              builder: (context, events) {
                final mine = events.where((e) => s.isEventStaff(e.id));
                // What's coming first, then what's done, newest first.
                final list = [
                  ...mine.where((e) => e.status != 'final'),
                  ...mine.where((e) => e.status == 'final').toList().reversed,
                ];
                if (list.isEmpty) return const Quiet('No showcases yet.');
                return _stack([
                  for (final e in list) _EventRow(event: e, canEdit: s.isEventAdmin(e.id)),
                ]);
              },
            ),
          ],
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.canEdit});

  final BBEvent event;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Paper(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(e.name, style: BB.lilita(22))),
                const SizedBox(width: 10),
                Pill(_shortStatus(e.status), color: e.isOpen ? BB.mint : BB.cream),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _joined([e.start == null ? 'No date' : fmtDate(e.start), e.city]),
                style: BB.bodyStyle(14, color: BB.ink2, height: 1.25),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BBButton.primary(
                  'Run',
                  small: true,
                  onPressed: () => context.go('/admin/events/${e.id}/run'),
                ),
                if (canEdit) ...[
                  BBButton.paper(
                    'Edit',
                    small: true,
                    onPressed: () => context.go('/admin/events/${e.id}'),
                  ),
                  BBButton.paper(
                    'Staff',
                    small: true,
                    onPressed: () => context.go('/admin/events/${e.id}/staff'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.eventId});
  final String? eventId;
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Battle Baseball Showcase');
  final _city = TextEditingController(text: 'Baton Rouge, LA');
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _ages = TextEditingController();
  final _price = TextEditingController();
  final _host = TextEditingController();
  final _raising = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _start;
  String _status = 'draft';
  bool _skills = false;
  bool _resultsPublished = false;
  bool _loaded = false;
  bool _missing = false;
  bool _busy = false;

  static const _statuses = ['draft', 'open', 'closed', 'live', 'final', 'rainedOut'];

  static const _help = [
    FinePrintItem('Hidden from families.', title: 'Draft'),
    FinePrintItem('Listed and taking sign-ups.', title: 'Open'),
    FinePrintItem('Listed, sign-ups off.', title: 'Closed'),
    FinePrintItem('Shows as today.', title: 'Live'),
    FinePrintItem('Set for you when results are published.', title: 'Final'),
    FinePrintItem(
      'Each one has its own spots and waitlist. Add them after you create the showcase.',
      title: 'Age groups',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.eventId == null) {
      _loaded = true;
    } else {
      Repo.instance.event(widget.eventId!).first.then((e) {
        if (!mounted) return;
        if (e == null) {
          setState(() => _missing = true);
          return;
        }
        setState(() {
          _name.text = e.name;
          _city.text = e.city;
          _venue.text = e.venue;
          _address.text = e.address;
          _ages.text = e.ageGroups;
          _price.text = e.price?.toString() ?? '';
          _host.text = e.hostTeam;
          _raising.text = e.raisingFor;
          _desc.text = e.description;
          _start = e.start;
          _status = e.status;
          _skills = e.skillsContest;
          _resultsPublished = e.resultsPublished;
          _loaded = true;
        });
      }, onError: (Object _) {
        if (mounted) setState(() => _missing = true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _venue, _address, _ages, _price, _host, _raising, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _start ?? now.add(const Duration(days: 30)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start ?? DateTime(2026, 1, 1, 8)),
    );
    if (!mounted) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t?.hour ?? 8, t?.minute ?? 0));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final e = BBEvent(
      id: widget.eventId ?? '',
      name: _name.text.trim(),
      status: _status,
      city: _city.text.trim(),
      venue: _venue.text.trim(),
      address: _address.text.trim(),
      start: _start,
      ageGroups: _ages.text.trim(),
      price: num.tryParse(_price.text.trim()),
      skillsContest: _skills,
      hostTeam: _host.text.trim(),
      raisingFor: _raising.text.trim(),
      description: _desc.text.trim(),
      resultsPublished: _resultsPublished,
    );
    try {
      final id = await Repo.instance.saveEvent(widget.eventId, e.toJson());
      if (!mounted) return;
      toast(context, 'Saved');
      if (widget.eventId == null) context.go('/admin/events/$id');
    } catch (_) {
      if (mounted) toast(context, "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
    TextInputType? type,
    String? hint,
    String? prefix,
    bool required = false,
    TextCapitalization caps = TextCapitalization.sentences,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 4,
          keyboardType: type,
          textCapitalization: caps,
          decoration: InputDecoration(labelText: label, hintText: hint, prefixText: prefix),
          validator: required ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null : null,
        ),
      );

  /// Looks like the fields around it; tapping it opens the pickers.
  Widget _dateField() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: _pickDate,
                builder: (context, down, focused) => InputDecorator(
                  isEmpty: _start == null,
                  isFocused: focused,
                  decoration: const InputDecoration(labelText: 'Date and time'),
                  child: Text(
                    _start == null ? '' : fmtDateTime(_start),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            if (_start != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconTap(
                  BBGlyph.close,
                  label: 'Clear date',
                  color: BB.cream,
                  onTap: () => setState(() => _start = null),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.eventId != null;
    if (_missing) return const NotFoundScreen();
    if (!_loaded) return const LoadingField();
    return Form(
      key: _form,
      child: StaffPage(
        title: editing ? 'Edit showcase' : 'New showcase',
        children: [
          _field(_name, 'Name', required: true, caps: TextCapitalization.words),
          _dateField(),
          _field(_city, 'City', caps: TextCapitalization.words),
          _field(_venue, 'Venue', caps: TextCapitalization.words),
          _field(_address, 'Address', caps: TextCapitalization.words),
          _field(_ages, 'Ages', hint: '9U to 14U'),
          _field(
            _price,
            'Price',
            prefix: '\$',
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(_host, 'Host team', caps: TextCapitalization.words),
          _field(_raising, 'Raising money for'),
          _field(_desc, 'Details', lines: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _skills,
            onChanged: (v) => setState(() => _skills = v),
            title: const Text('Skills contest'),
          ),
          const SizedBox(height: 10),
          Text('STATUS', style: BB.caps(12.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final st in _statuses)
                BBChip(
                  _shortStatus(st),
                  selected: _status == st,
                  onTap: () => setState(() => _status = st),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const HowThisWorks(_help),
          const SizedBox(height: 16),
          BBButton.primary(editing ? 'Save' : 'Create', expand: true, busy: _busy, onPressed: _save),
          if (editing) ...[
            const SizedBox(height: 36),
            _Divisions(eventId: widget.eventId!),
          ],
        ],
      ),
    );
  }
}

/// A showcase's age groups, each with its own count of spots.
class _Divisions extends StatelessWidget {
  const _Divisions({required this.eventId});
  final String eventId;

  Future<void> _edit(BuildContext context, {Division? d, int order = 0}) async {
    final answer = await showPrompt(
      context,
      title: d == null ? 'Add age group' : 'Edit age group',
      fields: [
        PromptField('Name', initial: d?.name ?? '', hint: '12U Gold'),
        PromptField('Spots', initial: '${d?.capacity ?? 24}', keyboard: TextInputType.number),
      ],
      action: 'Save',
    );
    if (answer == null || !context.mounted) return;
    final name = answer[0].trim();
    if (name.isEmpty) return;
    final capacity = int.tryParse(answer[1].trim()) ?? 24;
    await attempt(
      context,
      () => d == null
          ? Repo.instance.addDivision(eventId, name, capacity, order)
          : Repo.instance.updateDivision(d.id, {'name': name, 'capacity': capacity}),
    );
  }

  @override
  Widget build(BuildContext context) => LiveData<List<Division>>(
        key: ValueKey(eventId),
        stream: () => Repo.instance.divisionsFor(eventId),
        builder: (context, list) => _stack([
          SectionTitle(
            'Age groups',
            trailing: BBButton.paper(
              'Add',
              small: true,
              icon: const BBIcon(BBGlyph.plus),
              onPressed: () => _edit(context, order: list.length),
            ),
          ),
          if (list.isEmpty) const Quiet('None yet.'),
          for (final d in list)
            StaffRow(
              d.name,
              sink: false,
              onTap: () => _edit(context, d: d),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pill('${d.taken} of ${d.capacity}'),
                  // Only an empty age group can go.
                  if (d.taken == 0)
                    IconTap(
                      BBGlyph.close,
                      label: 'Delete ${d.name}',
                      onTap: () => attempt(context, () => Repo.instance.deleteDivision(d.id)),
                    ),
                ],
              ),
            ),
        ]),
      );
}

/// Asks for an email and finds the account behind it.
Future<AppUser?> _findAccount(BuildContext context, String title) async {
  final answer = await showPrompt(
    context,
    title: title,
    fields: const [PromptField('Email', keyboard: TextInputType.emailAddress)],
    action: 'Add',
  );
  if (answer == null || answer.first.trim().isEmpty) return null;
  AppUser? user;
  try {
    user = await Repo.instance.userByEmail(answer.first);
  } catch (_) {
    if (context.mounted) toast(context, "Couldn't look that up. Try again.");
    return null;
  }
  if (user == null && context.mounted) toast(context, 'No account with that email.');
  return user;
}

String _person(String name, String email) => name.isEmpty ? email : name;

/// A showcase's admins (chosen by the owner and Battle Baseball admins) and
/// its volunteers (chosen by any admin of the showcase).
class EventStaffScreen extends StatelessWidget {
  const EventStaffScreen({super.key, required this.eventId});
  final String eventId;

  static const _help = [
    FinePrintItem(
      'Runs this showcase: payments, volunteers and publishing results.',
      title: 'Admin',
    ),
    FinePrintItem('Check-in, radar, stats and awards. No payments.', title: 'Volunteer'),
    FinePrintItem('They need an account first. Add them by the email they signed up with.'),
  ];

  Future<void> _add(BuildContext context, String role) async {
    final u = await _findAccount(context, role == 'eventAdmin' ? 'Add an admin' : 'Add a volunteer');
    if (u == null || !context.mounted) return;
    await attempt(
      context,
      () => Repo.instance.assignStaff(eventId, u, role),
      done: 'Added ${_person(u.name, u.email)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => StaffPage(
        title: 'Staff',
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              BBButton.primary(
                'Add volunteer',
                small: true,
                icon: const BBIcon(BBGlyph.plus),
                onPressed: () => _add(context, 'staff'),
              ),
              if (s.isAdmin)
                BBButton.paper(
                  'Add admin',
                  small: true,
                  icon: const BBIcon(BBGlyph.plus),
                  onPressed: () => _add(context, 'eventAdmin'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          LiveData<List<StaffAssignment>>(
            key: ValueKey(eventId),
            stream: () => Repo.instance.staffFor(eventId),
            builder: (context, staff) {
              final list = [...staff]..sort((a, b) {
                  if (a.role != b.role) return a.role == 'eventAdmin' ? -1 : 1;
                  return _person(a.name, a.email)
                      .toLowerCase()
                      .compareTo(_person(b.name, b.email).toLowerCase());
                });
              return _stack([
                if (list.isEmpty) const Quiet('No one yet.'),
                for (final a in list)
                  StaffRow(
                    _person(a.name, a.email),
                    sub: a.name.isEmpty ? null : a.email,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pill(a.role == 'eventAdmin' ? 'Admin' : 'Volunteer'),
                        if (s.isAdmin || a.role == 'staff')
                          IconTap(
                            BBGlyph.close,
                            label: 'Remove ${_person(a.name, a.email)}',
                            onTap: () => attempt(context, () => Repo.instance.removeStaff(a.id)),
                          ),
                      ],
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 4),
          const HowThisWorks(_help),
        ],
      ),
    );
  }
}

/// Every listed showcase's registrations as one list, for an event admin who
/// can't read them all at once the way a Battle Baseball admin can.
Stream<List<Registration>> _registrationsAcross(List<String> eventIds) {
  if (eventIds.isEmpty) return Stream.value(const []);
  final latest = <String, List<Registration>>{};
  final subs = <StreamSubscription<List<Registration>>>[];
  late final StreamController<List<Registration>> out;
  out = StreamController<List<Registration>>(
    onListen: () {
      for (final id in eventIds) {
        subs.add(Repo.instance.registrationsFor(id).listen(
          (list) {
            latest[id] = list;
            // Wait until every showcase has answered once.
            if (latest.length == eventIds.length) {
              out.add([for (final l in latest.values) ...l]);
            }
          },
          onError: out.addError,
        ));
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return out.stream;
}

/// Spots waiting on payment, and the waitlist behind them.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final mine = {
          for (final a in s.assignments)
            if (a.role == 'eventAdmin') a.eventId,
        }.toList()
          ..sort();
        return StaffPage(
          title: 'Payments',
          children: [
            LiveData<List<Registration>>(
              // A new subscription when the role or the showcases change.
              key: ValueKey('${s.isAdmin}/${mine.join(',')}'),
              stream: () => s.isAdmin ? Repo.instance.heldRegistrations() : _registrationsAcross(mine),
              builder: (context, all) => _PaymentsView(
                regs: all.where((r) => s.isEventAdmin(r.eventId)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentsView extends StatelessWidget {
  const _PaymentsView({required this.regs});

  final List<Registration> regs;

  static const _help = [
    FinePrintItem(
      'Tap Mark paid when the payment shows up in Venmo or Cash App, or the family shows you the receipt.',
    ),
    FinePrintItem('The code is what the family put in the payment note.'),
    FinePrintItem('Every Mark paid records who tapped it.'),
    FinePrintItem('Release opens a held spot. Offer spot holds one for 24 hours.'),
  ];

  @override
  Widget build(BuildContext context) {
    // Families who say they paid come first, then the holds ending soonest.
    final held = regs.where((r) => r.isHeld).toList()
      ..sort((a, b) {
        if (a.alreadyPaid != b.alreadyPaid) return a.alreadyPaid ? -1 : 1;
        return (a.holdEndsAt ?? DateTime(2100)).compareTo(b.holdEndsAt ?? DateTime(2100));
      });
    final waitlist = regs.where((r) => r.status == 'waitlisted').toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
    return _stack([
      const SectionTitle('Waiting'),
      if (held.isEmpty) const Quiet('Nothing waiting.'),
      for (final r in held) _HeldCard(r: r),
      const SizedBox(height: 26),
      const SectionTitle('Waitlist'),
      if (waitlist.isEmpty) const Quiet('No one waiting.'),
      for (final r in waitlist)
        StaffRow(
          r.playerName,
          sub: _joined([r.eventName, r.divisionName, r.guardianName]),
          sink: false,
          trailing: BBButton.paper(
            'Offer spot',
            small: true,
            onPressed: () => attempt(context, () => Repo.instance.offerSpot(r)),
          ),
        ),
      const SizedBox(height: 8),
      const HowThisWorks(_help),
    ]);
  }
}

class _HeldCard extends StatelessWidget {
  const _HeldCard({required this.r});
  final Registration r;

  Future<void> _release(BuildContext context) async {
    final ok = await showPrompt(
      context,
      title: 'Release this spot?',
      note: _joined([r.playerName, r.divisionName]),
      action: 'Release',
      cancel: 'Keep',
    );
    if (ok == null || !context.mounted) return;
    await attempt(context, () => Repo.instance.release(r));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Paper(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(r.playerName, style: BB.lilita(22))),
                  const SizedBox(width: 10),
                  // The code is what gets matched against the payment note.
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BB.ink, width: 2),
                    ),
                    child: Text(r.paymentCode, style: BB.lilita(19, height: 1.1)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _joined([r.eventName, r.divisionName, r.guardianName]),
                  style: BB.bodyStyle(14, color: BB.ink2, height: 1.25),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _joined([
                    if (r.amount != null) fmtPrice(r.amount),
                    _payApp(r),
                    r.payerName,
                  ]),
                  style: BB.labelStyle(17, color: BB.ink, height: 1.2),
                ),
              ),
              const SizedBox(height: 10),
              if (r.alreadyPaid)
                Pill('Says paid', color: BB.coral)
              else if (r.holdEnded)
                const Pill('Hold ended')
              else if (r.holdEndsAt != null)
                Pill('Held ${holdUntil(r.holdEndsAt)}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BBButton.primary(
                    'Mark paid',
                    small: true,
                    icon: const BBIcon(BBGlyph.check),
                    onPressed: () => attempt(
                      context,
                      () => Repo.instance.markPaid(r),
                      done: '${r.playerName} marked paid',
                    ),
                  ),
                  BBButton.paper('Release', small: true, onPressed: () => _release(context)),
                ],
              ),
            ],
          ),
        ),
      );
}

/// Owner only: every Mark paid, who tapped it, and totals by app and week,
/// to tick off against the Venmo and Cash App history.
class PaymentCheckScreen extends StatelessWidget {
  const PaymentCheckScreen({super.key});

  static Stream<List<Registration>> _paid() {
    final repo = Repo.instance;
    if (repo.demo) {
      // Sample data has no collection to query, so gather it by showcase.
      return repo.allEvents().asyncMap((events) async => [
            for (final e in events)
              ...(await repo.registrationsFor(e.id).first).where((r) => r.isConfirmed),
          ]);
    }
    return repo.registrations
        .where('status', whereIn: ['paid', 'checkedIn'])
        .snapshots()
        .map((s) => s.docs.map(Registration.fromDoc).toList());
  }

  @override
  Widget build(BuildContext context) => StaffPage(
        title: 'Payment check',
        children: [
          LiveData<List<Registration>>(
            stream: _paid,
            builder: (context, regs) => _PaymentCheckView(regs: regs),
          ),
        ],
      );
}

class _PaymentCheckView extends StatelessWidget {
  const _PaymentCheckView({required this.regs});

  final List<Registration> regs;

  @override
  Widget build(BuildContext context) {
    final list = [...regs]
      ..sort((a, b) => (b.markedPaidAt ?? DateTime(2000)).compareTo(a.markedPaidAt ?? DateTime(2000)));
    if (list.isEmpty) return const Quiet('Nothing marked paid yet.');
    // One total per app per week, newest week first.
    final totals = <(String, String), num>{};
    for (final r in list) {
      final d = r.markedPaidAt ?? DateTime(2000);
      final week = DateFormat('MMM d').format(d.subtract(Duration(days: d.weekday - 1)));
      final key = (_payApp(r), week);
      totals[key] = (totals[key] ?? 0) + (r.amount ?? 0);
    }
    return _stack([
      const SectionTitle('Totals'),
      RuledPanel(
        children: [
          for (final t in totals.entries)
            RuledRow(name: t.key.$1, sub: 'week of ${t.key.$2}', value: fmtPrice(t.value)),
        ],
      ),
      const SizedBox(height: 30),
      const SectionTitle('Marked paid'),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Paper(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BB.labelStyle(19, color: BB.ink, height: 1.1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (r.amount != null) Text(fmtPrice(r.amount), style: BB.lilita(21, height: 1)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    _joined([r.paymentCode, _payApp(r), r.payerName]),
                    style: BB.labelStyle(15, color: BB.ink, height: 1.25),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _joined([r.eventName, r.markedPaidByName, fmtDateTime(r.markedPaidAt)]),
                    style: BB.bodyStyle(13.5, color: BB.ink2, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

/// Owner only: add and remove Battle Baseball admins.
class AdminsScreen extends StatelessWidget {
  const AdminsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final u = await _findAccount(context, 'Add an admin');
    if (u == null || !context.mounted) return;
    await attempt(
      context,
      () => Repo.instance.setAdmin(u),
      done: '${_person(u.name, u.email)} is an admin',
    );
  }

  @override
  Widget build(BuildContext context) => StaffPage(
        title: 'Admins',
        trailing: BBButton.primary(
          'Add',
          small: true,
          icon: const BBIcon(BBGlyph.plus),
          onPressed: () => _add(context),
        ),
        children: [
          LiveData<List<(String, String, String, String)>>(
            stream: () => Repo.instance.admins(),
            builder: (context, admins) => _stack([
              for (final (uid, role, name, email) in admins)
                StaffRow(
                  _person(name, email),
                  sub: name.isEmpty ? null : email,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Pill(role == 'owner' ? 'Owner' : 'Admin', color: BB.lemon),
                      if (role != 'owner')
                        IconTap(
                          BBGlyph.close,
                          label: 'Remove ${_person(name, email)}',
                          onTap: () => attempt(context, () => Repo.instance.removeAdmin(uid)),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
        ],
      );
}

/// Owner only: the Venmo and Cash App handles families pay to.
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});
  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _venmo = TextEditingController();
  final _cash = TextEditingController();
  final _payTo = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  static const _help = [
    FinePrintItem('Families see these when they reserve a spot.'),
    FinePrintItem('Every change is logged with who made it.'),
  ];

  @override
  void initState() {
    super.initState();
    Repo.instance.paymentSettings().first.then((p) {
      if (!mounted) return;
      setState(() {
        _venmo.text = p.venmo;
        _cash.text = p.cashtag;
        _payTo.text = p.payTo;
        _loaded = true;
      });
    }, onError: (Object _) {
      // Nothing saved yet reads the same as blank fields.
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _venmo.dispose();
    _cash.dispose();
    _payTo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Repo.instance.savePaymentSettings(PaymentSettings(
        venmo: _venmo.text.trim().replaceAll('@', ''),
        cashtag: _cash.text.trim().replaceAll('\$', ''),
        payTo: _payTo.text.trim(),
      ));
      if (mounted) toast(context, 'Saved');
    } catch (_) {
      if (mounted) toast(context, "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) => StaffPage(
          title: 'Payment settings',
          children: !Session.instance.isOwner
              ? const [Quiet('Owner only.')]
              : !_loaded
                  ? const [LoadingField()]
                  : [
                      TextField(
                        controller: _payTo,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name families see'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _venmo,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Venmo', prefixText: '@'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _cash,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Cash App', prefixText: '\$'),
                      ),
                      const SizedBox(height: 4),
                      const HowThisWorks(_help),
                      const SizedBox(height: 16),
                      BBButton.primary('Save', expand: true, busy: _busy, onPressed: _save),
                    ],
        ),
      );
}

/// Admins: the colors the whole app wears. Tapping a scheme tries it on this
/// screen only; Use for everyone saves it to config/theme for every visitor.
class ColorSchemeScreen extends StatefulWidget {
  const ColorSchemeScreen({super.key});
  @override
  State<ColorSchemeScreen> createState() => _ColorSchemeScreenState();
}

class _ColorSchemeScreenState extends State<ColorSchemeScreen> {
  final _schemes = SchemeController.instance;
  bool _busy = false;

  static const _help = [
    FinePrintItem('Tap a scheme to try it on. Only you see it until you press Use for everyone.'),
    FinePrintItem('Use for everyone changes the app and site for every visitor right away.'),
    FinePrintItem('Every change is logged with who made it.'),
  ];

  @override
  void dispose() {
    // Leaving without saving puts back the scheme everyone sees.
    _schemes.tryOn(null);
    super.dispose();
  }

  Future<void> _use(BBScheme s) async {
    setState(() => _busy = true);
    final ok = await attempt(context, () => _schemes.save(s), done: 'Everyone now sees ${s.name}');
    if (mounted) setState(() => _busy = false);
    if (!ok) return;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Session.instance, _schemes]),
        builder: (context, _) {
          final trying = _schemes.preview;
          final saved = _schemes.saved;
          return StaffPage(
            title: 'Color scheme',
            children: !Session.instance.isAdmin
                ? const [Quiet('Admins only.')]
                : [
                    for (final s in BBSchemes.all)
                      StaffRow(
                        s.name,
                        sub: s.blurb,
                        leading: _SchemeChip(s),
                        trailing: s == saved
                            ? const Pill('Everyone')
                            : s == trying
                                ? Pill('Trying', color: BB.coral)
                                : null,
                        onTap: _busy ? null : () => _schemes.tryOn(s == saved ? null : s),
                      ),
                    const SizedBox(height: 6),
                    if (trying != null && trying != saved) ...[
                      Text(
                        'Only you see ${trying.name} right now.',
                        style: BB.bodyStyle(16),
                      ),
                      const SizedBox(height: 14),
                      BBButton.primary(
                        'Use ${trying.name} for everyone',
                        expand: true,
                        busy: _busy,
                        onPressed: () => _use(trying),
                      ),
                      const SizedBox(height: 12),
                      BBButton.quiet(
                        'Go back to ${saved.name}',
                        expand: true,
                        onPressed: _busy ? null : () => _schemes.tryOn(null),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const HowThisWorks(_help),
                  ],
          );
        },
      );
}

/// A scheme in miniature: a card in its accent on its field.
class _SchemeChip extends StatelessWidget {
  const _SchemeChip(this.s);
  final BBScheme s;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 58,
          height: 44,
          decoration: BoxDecoration(
            color: s.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BB.ink, width: 2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.08,
                child: Container(
                  width: 22,
                  height: 30,
                  decoration: BoxDecoration(
                    color: s.cream,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: s.ink, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(2),
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: s.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: s.honors,
                  shape: BoxShape.circle,
                  border: Border.all(color: s.ink, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}
