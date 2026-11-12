import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The admin hub. What shows depends on the role: you (owner) see
/// everything; Battle Baseball admins see every event; event admins and
/// staff see only the events they're named on.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Admin tools')),
        body: PageBody(children: [
          Eyebrow(s.isOwner
              ? 'Owner'
              : s.isAdmin
                  ? 'Battle Baseball admin'
                  : 'Event staff'),
          if (s.hasStaffTools && !s.isAdmin)
            const Text('You can run the events you were added to.', style: TextStyle(color: BB.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (s.isAdmin)
              CandyButton(
                small: true,
                icon: Icons.add,
                label: 'New event',
                onPressed: () => context.go('/admin/events/new'),
              ),
            CandyButton.secondary(
              small: true,
              icon: Icons.payments_outlined,
              label: 'Payments',
              onPressed: () => context.go('/admin/payments'),
            ),
            if (s.isOwner) ...[
              CandyButton.secondary(
                small: true,
                icon: Icons.fact_check_outlined,
                label: 'Payment check',
                onPressed: () => context.go('/admin/payment-check'),
              ),
              CandyButton.secondary(
                small: true,
                icon: Icons.group_outlined,
                label: 'Admins',
                onPressed: () => context.go('/admin/admins'),
              ),
              CandyButton.secondary(
                small: true,
                icon: Icons.settings_outlined,
                label: 'Payment settings',
                onPressed: () => context.go('/admin/settings'),
              ),
            ],
          ]),
          const SectionLabel('Events'),
          StreamBuilder<List<BBEvent>>(
            stream: s.isAdmin ? Repo.instance.allEvents() : Repo.instance.publicEvents(),
            builder: (context, es) {
              final w = streamState(es);
              if (w != null) return w;
              final list = es.data!.where((e) => s.isEventStaff(e.id)).toList();
              if (list.isEmpty) return const EmptyNote('No events yet.');
              return Column(children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GumCard(
                      edge: statusColor(e.status),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(e.name, style: BB.title(20))),
                          StatusChip(statusLabel(e.status), color: statusColor(e.status)),
                        ]),
                        Text('${fmtDate(e.start)} · ${e.city}', style: const TextStyle(color: BB.cardMuted)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          CandyButton(
                            small: true,
                            label: 'Run event',
                            icon: Icons.sports_baseball,
                            onPressed: () => context.go('/admin/events/${e.id}/run'),
                          ),
                          if (s.isEventAdmin(e.id)) ...[
                            CandyButton.secondary(
                              small: true,
                              label: 'Edit',
                              icon: Icons.edit,
                              onPressed: () => context.go('/admin/events/${e.id}'),
                            ),
                            CandyButton.secondary(
                              small: true,
                              label: 'Staff',
                              icon: Icons.badge_outlined,
                              onPressed: () => context.go('/admin/events/${e.id}/staff'),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ]),
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventId == null) {
      _loaded = true;
    } else {
      Repo.instance.event(widget.eventId!).first.then((e) {
        if (e == null || !mounted) return;
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
    } catch (err) {
      if (mounted) toast(context, "Couldn't save: $err");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.eventId != null;
    Widget field(TextEditingController c, String label, {int lines = 1, TextInputType? type, bool required = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: c,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 4,
            keyboardType: type,
            decoration: InputDecoration(labelText: label),
            validator: required ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null : null,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit event' : 'New event')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: PageBody(children: [
                field(_name, 'Event name', required: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GumCard(
                    edge: BB.blue,
                    onTap: _pickDate,
                    child: Row(children: [
                      const Icon(Icons.event),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_start == null ? 'Pick the date and start time' : fmtDateTime(_start),
                            style: BB.labelStyle(16)),
                      ),
                      if (_start != null)
                        IconButton(
                          tooltip: 'Clear date',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _start = null),
                        ),
                    ]),
                  ),
                ),
                field(_city, 'City'),
                field(_venue, 'Venue (field complex)'),
                field(_address, 'Address'),
                field(_ages, 'Age groups (e.g. 10U, 12U, 14U)'),
                field(_price, 'Price per player (\$), blank if not set yet',
                    type: const TextInputType.numberWithOptions(decimal: true)),
                field(_host, 'Host team'),
                field(_raising, 'What the host team is raising money for'),
                field(_desc, 'Description, schedule, and what to bring', lines: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _skills,
                  onChanged: (v) => setState(() => _skills = v),
                  title: const Text('Opt-in skills contest (pop time, 40-yard dash)'),
                ),
                const SizedBox(height: 8),
                Text('Status', style: BB.labelStyle(15, color: BB.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final st in ['draft', 'open', 'closed', 'live', 'final', 'rainedOut'])
                    ChoiceChip(
                      label: Text(statusLabel(st)),
                      selected: _status == st,
                      onSelected: (_) => setState(() => _status = st),
                    ),
                ]),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Drafts are hidden from families. Open takes registrations.',
                      style: TextStyle(color: BB.muted, fontSize: 14)),
                ),
                const SizedBox(height: 18),
                CandyButton(expand: true, busy: _busy, label: editing ? 'Save event' : 'Create event', onPressed: _save),
                if (editing) _Divisions(eventId: widget.eventId!),
              ]),
            ),
    );
  }
}

class _Divisions extends StatelessWidget {
  const _Divisions({required this.eventId});
  final String eventId;

  Future<void> _edit(BuildContext context, {Division? d, int order = 0}) async {
    final name = TextEditingController(text: d?.name ?? '');
    final cap = TextEditingController(text: '${d?.capacity ?? 24}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(d == null ? 'Add age group' : 'Edit age group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name (e.g. 12U Gold)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cap,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Spots'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final capacity = int.tryParse(cap.text.trim()) ?? 24;
    if (d == null) {
      await Repo.instance.addDivision(eventId, name.text.trim(), capacity, order);
    } else {
      await Repo.instance.updateDivision(d.id, {'name': name.text.trim(), 'capacity': capacity});
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Division>>(
        stream: Repo.instance.divisionsFor(eventId),
        builder: (context, s) {
          final list = s.data ?? const <Division>[];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Age groups and skill levels'),
            for (final d in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GumCard(
                  edge: BB.grape,
                  onTap: () => _edit(context, d: d),
                  child: Row(children: [
                    Expanded(
                      child: Text('${d.name}\n${d.taken} of ${d.capacity} spots taken', style: BB.labelStyle(16)),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: d.taken > 0 ? null : () => Repo.instance.deleteDivision(d.id),
                    ),
                  ]),
                ),
              ),
            CandyButton.secondary(
              small: true,
              icon: Icons.add,
              label: 'Add age group',
              onPressed: () => _edit(context, order: list.length),
            ),
          ]);
        },
      );
}

/// Choose the event's admins (owner and BB admins) and volunteers (any admin
/// of the event).
class EventStaffScreen extends StatelessWidget {
  const EventStaffScreen({super.key, required this.eventId});
  final String eventId;

  Future<void> _add(BuildContext context, String role) async {
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(role == 'eventAdmin' ? 'Add an event admin' : 'Add a volunteer'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('They need a Battle Baseball account first. Enter the email they signed up with.'),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final u = await Repo.instance.userByEmail(email.text);
    if (!context.mounted) return;
    if (u == null) {
      toast(context, 'No account with that email yet. Ask them to sign up in the app first.');
      return;
    }
    await Repo.instance.assignStaff(eventId, u, role);
    if (context.mounted) toast(context, 'Added ${u.name.isEmpty ? u.email : u.name}');
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Event staff')),
      body: StreamBuilder<List<StaffAssignment>>(
        stream: Repo.instance.staffFor(eventId),
        builder: (context, snap) {
          final w = streamState(snap);
          if (w != null) return w;
          final list = snap.data!;
          return PageBody(children: [
            const Text(
              'Event admins manage registrations, mark payments, add volunteers, and publish results '
              'for this event only. Volunteers check players in and record velocities and awards, '
              'with no access to payments.',
              style: TextStyle(color: BB.muted),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              if (s.isAdmin)
                CandyButton(small: true, label: 'Add event admin', onPressed: () => _add(context, 'eventAdmin')),
              CandyButton.secondary(small: true, label: 'Add volunteer', onPressed: () => _add(context, 'staff')),
            ]),
            const SizedBox(height: 16),
            if (list.isEmpty) const EmptyNote('No one added yet.'),
            for (final a in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GumCard(
                  edge: a.role == 'eventAdmin' ? BB.coral : BB.blue,
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${a.name.isEmpty ? a.email : a.name}\n${a.role == 'eventAdmin' ? 'Event admin' : 'Volunteer'} · ${a.email}',
                        style: BB.labelStyle(15),
                      ),
                    ),
                    if (s.isAdmin || a.role == 'staff')
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => Repo.instance.removeStaff(a.id),
                      ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Spots waiting on payment, holds ending soonest at the top.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: StreamBuilder<List<Registration>>(
        stream: s.isAdmin ? Repo.instance.heldRegistrations() : _forMyEvents(),
        builder: (context, snap) {
          final w = streamState(snap);
          if (w != null) return w;
          final list = snap.data!.where((r) => s.isEventAdmin(r.eventId)).toList();
          final held = list.where((r) => r.isHeld).toList()
            ..sort((a, b) {
              if (a.alreadyPaid != b.alreadyPaid) return a.alreadyPaid ? -1 : 1;
              return (a.holdEndsAt ?? DateTime(2100)).compareTo(b.holdEndsAt ?? DateTime(2100));
            });
          final waitlist = list.where((r) => r.status == 'waitlisted').toList()
            ..sort((a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
          return PageBody(children: [
            const Text(
              'Tap Mark paid once the payment checks out: you see it arrive in Venmo or Cash App, '
              'or the family shows you the receipt. Every Mark paid records who tapped it.',
              style: TextStyle(color: BB.muted),
            ),
            const SectionLabel('Waiting on payment'),
            if (held.isEmpty) const EmptyNote('Nothing waiting. Nice.'),
            for (final r in held) _HeldCard(r: r),
            const SectionLabel('Waitlist'),
            if (waitlist.isEmpty) const EmptyNote('No one on a waitlist.'),
            for (final r in waitlist)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GumCard(
                  edge: BB.grape,
                  child: Row(children: [
                    Expanded(
                      child: Text('${r.playerName} · ${r.divisionName}\n${r.eventName} · ${r.guardianName}',
                          style: BB.labelStyle(15)),
                    ),
                    CandyButton(small: true, label: 'Offer spot', onPressed: () => Repo.instance.offerSpot(r)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  /// Event admins who aren't global admins see their own events' holds.
  Stream<List<Registration>> _forMyEvents() {
    final events = Session.instance.assignments.where((a) => a.role == 'eventAdmin').map((a) => a.eventId).toList();
    if (events.isEmpty) return Stream.value(const []);
    return Repo.instance.registrationsFor(events.first);
  }
}

class _HeldCard extends StatelessWidget {
  const _HeldCard({required this.r});
  final Registration r;
  @override
  Widget build(BuildContext context) {
    final app = r.paidVia == 'cashapp' ? 'Cash App' : 'Venmo';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GumCard(
        edge: r.alreadyPaid ? BB.coral : r.holdEnded ? BB.tangerine : BB.lemon,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.playerName, style: BB.title(19))),
            Text(r.paymentCode, style: BB.title(18, color: BB.lemon)),
          ]),
          Text('${r.eventName} · ${r.divisionName}', style: const TextStyle(color: BB.cardMuted)),
          const SizedBox(height: 6),
          Text('${fmtPrice(r.amount)} by $app from "${r.payerName}" · ${r.guardianName}',
              style: BB.labelStyle(15, weight: FontWeight.w500)),
          Text(
            r.alreadyPaid
                ? 'Family says they already paid. Look for this one first.'
                : r.holdEnded
                    ? 'Hold ended ${fmtDateTime(r.holdEndsAt)}. Release it to the waitlist if no payment turns up.'
                    : 'Held ${holdUntil(r.holdEndsAt)}',
            style: TextStyle(color: r.alreadyPaid || r.holdEnded ? BB.accent : BB.cardMuted, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            CandyButton(
              small: true,
              icon: Icons.check,
              label: 'Mark paid',
              face: BB.mint,
              edge: BB.ink,
              onPressed: () async {
                await Repo.instance.markPaid(r);
                if (context.mounted) toast(context, '${r.playerName} marked paid');
              },
            ),
            CandyButton.secondary(
              small: true,
              label: 'Release spot',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Release this spot?'),
                    content: Text("${r.playerName}'s spot opens up for the next family on the waitlist."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep holding')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Release')),
                    ],
                  ),
                );
                if (ok == true) await Repo.instance.release(r);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Owner only: every Mark paid, who tapped it, and totals by app and week,
/// to tick off against your Venmo and Cash App history.
class PaymentCheckScreen extends StatelessWidget {
  const PaymentCheckScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment check')),
        body: StreamBuilder(
          stream: Repo.instance.registrations.where('status', whereIn: ['paid', 'checkedIn']).snapshots(),
          builder: (context, snap) {
            final w = streamState(snap);
            if (w != null) return w;
            final list = snap.data!.docs.map(Registration.fromDoc).toList()
              ..sort((a, b) => (b.markedPaidAt ?? DateTime(2000)).compareTo(a.markedPaidAt ?? DateTime(2000)));
            final totals = <String, num>{};
            for (final r in list) {
              final d = r.markedPaidAt ?? DateTime(2000);
              final week = DateFormat('MMM d').format(d.subtract(Duration(days: d.weekday - 1)));
              final key = '${r.paidVia == 'cashapp' ? 'Cash App' : 'Venmo'} · week of $week';
              totals[key] = (totals[key] ?? 0) + (r.amount ?? 0);
            }
            return PageBody(children: [
              const SectionLabel('Totals'),
              if (totals.isEmpty) const EmptyNote('No payments marked yet.'),
              for (final t in totals.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.key, style: BB.labelStyle(16)),
                  trailing: Text(fmtPrice(t.value), style: BB.title(18)),
                ),
              const SectionLabel('Every Mark paid'),
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GumCard(
                    edge: BB.mint,
                    child: Text(
                      '${r.paymentCode} · ${fmtPrice(r.amount)} · ${r.paidVia == 'cashapp' ? 'Cash App' : 'Venmo'} from "${r.payerName}"\n'
                      '${r.playerName} · ${r.eventName}\n'
                      'Marked by ${r.markedPaidByName ?? '?'} ${fmtDateTime(r.markedPaidAt)}',
                      style: const TextStyle(fontSize: 14.5),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}

/// Owner only: add and remove Battle Baseball admins.
class AdminsScreen extends StatelessWidget {
  const AdminsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a Battle Baseball admin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Admins run every event: create events, approve hosts, mark payments, and publish results.'),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Their account email'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final u = await Repo.instance.userByEmail(email.text);
    if (!context.mounted) return;
    if (u == null) {
      toast(context, 'No account with that email yet. Ask them to sign up in the app first.');
      return;
    }
    await Repo.instance.setAdmin(u);
    if (context.mounted) toast(context, '${u.name.isEmpty ? u.email : u.name} is now an admin');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admins')),
        body: StreamBuilder(
          stream: Repo.instance.admins(),
          builder: (context, snap) {
            final w = streamState(snap);
            if (w != null) return w;
            return PageBody(children: [
              CandyButton(small: true, icon: Icons.add, label: 'Add admin', onPressed: () => _add(context)),
              const SizedBox(height: 14),
              for (final (uid, role, name, email) in snap.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GumCard(
                    edge: role == 'owner' ? BB.lemon : BB.coral,
                    child: Row(children: [
                      Expanded(
                        child: Text('${name.isEmpty ? email : name}\n${role == 'owner' ? 'Owner' : 'Battle Baseball admin'}',
                            style: BB.labelStyle(15)),
                      ),
                      if (role != 'owner')
                        IconButton(
                          tooltip: 'Remove admin',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => Repo.instance.removeAdmin(uid),
                        ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

/// Owner only: the Venmo and Cash App handles parents pay to. Each change is
/// logged, since a changed handle would send families' money somewhere else.
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
    });
  }

  @override
  void dispose() {
    _venmo.dispose();
    _cash.dispose();
    _payTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment settings')),
        body: !Session.instance.isOwner
            ? const Center(child: Text('Only the owner can change payment settings.'))
            : !_loaded
                ? const Center(child: CircularProgressIndicator())
                : PageBody(children: [
                    const Text(
                      'Families see these on every event when they reserve a spot. Every change is '
                      'logged with who made it.',
                      style: TextStyle(color: BB.muted),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _payTo,
                      decoration: const InputDecoration(
                        labelText: 'Name families see',
                        helperText: 'e.g. Jared Freeman (Battle Baseball)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _venmo,
                      decoration: const InputDecoration(labelText: 'Venmo handle', prefixText: '@'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _cash,
                      decoration: const InputDecoration(labelText: 'Cash App \$cashtag', prefixText: '\$'),
                    ),
                    const SizedBox(height: 20),
                    CandyButton(
                      expand: true,
                      busy: _busy,
                      label: 'Save payment settings',
                      onPressed: () async {
                        setState(() => _busy = true);
                        try {
                          await Repo.instance.savePaymentSettings(PaymentSettings(
                            venmo: _venmo.text.trim().replaceAll('@', ''),
                            cashtag: _cash.text.trim().replaceAll('\$', ''),
                            payTo: _payTo.text.trim(),
                          ));
                          if (context.mounted) toast(context, 'Saved');
                        } catch (e) {
                          if (context.mounted) toast(context, "Couldn't save: $e");
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                    ),
                  ]),
      );
}
