// Showcases: the list of tickets, one showcase, reserving a spot, and a
// finished showcase's results.
import 'dart:async';

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/design/ticket.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The latest value from a stream, held for a State so a rebuild never
/// subscribes again. An error counts as nothing there: a read the rules
/// refuse looks the same as an empty one.
class _Feed<T> {
  StreamSubscription<T>? _sub;
  T? value;
  bool ready = false;
  bool failed = false;

  void listen(Stream<T> stream, VoidCallback changed) {
    cancel();
    _sub = stream.listen(
      (v) {
        value = v;
        ready = true;
        failed = false;
        changed();
      },
      onError: (Object _) {
        ready = true;
        failed = true;
        changed();
      },
    );
  }

  void cancel() {
    _sub?.cancel();
    _sub = null;
    value = null;
    ready = false;
    failed = false;
  }
}

List<Widget> _spaced(Iterable<Widget> items, double gap) => [
      for (final (i, w) in items.indexed) ...[if (i > 0) SizedBox(height: gap), w],
    ];

/// Open spots across a showcase's age groups, or null before any are posted.
int? _spotsLeft(List<Division>? divisions) => divisions == null || divisions.isEmpty
    ? null
    : divisions.fold<int>(0, (n, d) => n + d.open);

/// What "The fine print" says on these screens.
List<FinePrintItem> _finePrint(BBEvent e) => [
      const FinePrintItem('Spots are held for $holdHours hours while we match your payment.'),
      const FinePrintItem("If we can't match a payment in that time, the spot opens to the waitlist."),
      const FinePrintItem('On the waitlist, you pay only when a spot opens.'),
      FinePrintItem(e.start == null
          ? 'Cancel a week or more ahead for a full refund.'
          : 'Cancel by ${fmtDate(e.refundCutoff)} for a full refund.'),
      const FinePrintItem('Rained out? Pick a refund or a credit toward the next showcase.'),
      const FinePrintItem('A parent or guardian signs the waiver and medical release for each player.'),
    ];

/// Tiles in one column, or two side by side when there is room.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          const across = 28.0;
          final two = box.maxWidth >= 720;
          final w = two ? ((box.maxWidth - across) / 2).floorToDouble() : box.maxWidth;
          return Wrap(
            spacing: across,
            runSpacing: 14,
            children: [for (final c in children) SizedBox(width: w, child: c)],
          );
        },
      );
}

// ---------- Showcases ----------

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _events = _Feed<List<BBEvent>>();

  @override
  void initState() {
    super.initState();
    _events.listen(Repo.instance.publicEvents(), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _EventsView(events: _events.ready ? _events.value ?? const [] : null);
}

class _EventsView extends StatelessWidget {
  const _EventsView({required this.events});

  /// Null while the list loads.
  final List<BBEvent>? events;

  @override
  Widget build(BuildContext context) {
    final all = events;
    final upcoming = [...?all?.where((e) => e.status != 'final')];
    final past = [...?all?.where((e) => e.status == 'final')].reversed.toList();
    return PageFrame(
      children: [
        const TabHeader(),
        const PageTitle('Showcases'),
        const _ParentsLine(),
        if (all == null)
          const LoadingField()
        else ...[
          _Tiles(children: [
            if (upcoming.isEmpty) const TbaTicket(),
            for (final e in upcoming) _ListedTicket(event: e),
          ]),
          if (past.isNotEmpty) ...[
            const SectionTitle('Final', padding: EdgeInsets.only(top: 36, bottom: 16)),
            _Tiles(children: [for (final e in past) _ListedTicket(event: e)]),
          ],
        ],
      ],
    );
  }
}

/// Under the title: where parents hear from coaches once teams are set.
class _ParentsLine extends StatefulWidget {
  const _ParentsLine();

  @override
  State<_ParentsLine> createState() => _ParentsLineState();
}

class _ParentsLineState extends State<_ParentsLine> {
  final _tap = TapGestureRecognizer()..onTap = openBattleplan;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Once teams are assigned, coaches talk with parents on '),
            TextSpan(
              text: 'Battleplan',
              recognizer: _tap,
              mouseCursor: SystemMouseCursors.click,
              style: BB.labelStyle(16, height: 1.45).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: BB.coral,
                decorationThickness: 2.5,
              ),
            ),
            const TextSpan(text: '.'),
          ]),
          style: BB.bodyStyle(16, height: 1.45),
        ),
      );
}

/// A ticket in the list. While registration is open it counts the spots
/// left across the showcase's age groups.
class _ListedTicket extends StatefulWidget {
  const _ListedTicket({required this.event});

  final BBEvent event;

  @override
  State<_ListedTicket> createState() => _ListedTicketState();
}

class _ListedTicketState extends State<_ListedTicket> {
  final _divisions = _Feed<List<Division>>();

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(_ListedTicket old) {
    super.didUpdateWidget(old);
    if (old.event.id != widget.event.id || old.event.isOpen != widget.event.isOpen) _watch();
  }

  void _watch() {
    if (!widget.event.isOpen) return _divisions.cancel();
    _divisions.listen(Repo.instance.divisionsFor(widget.event.id), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _divisions.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final done = e.status == 'final';
    return ShowcaseTicket(
      event: e,
      spotsLeft: _spotsLeft(_divisions.value),
      onTap: () => context.go(done ? '/events/${e.id}/results' : '/events/${e.id}'),
      onReserve: e.isOpen ? () => context.go('/events/${e.id}/reserve') : null,
    );
  }
}

// ---------- One showcase ----------

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _event = _Feed<BBEvent?>();
  final _divisions = _Feed<List<Division>>();
  final _mine = _Feed<List<Registration>>();
  String? _uid;

  @override
  void initState() {
    super.initState();
    _watch();
    Session.instance.addListener(_onSession);
  }

  @override
  void didUpdateWidget(EventDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) _watch();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _watch() {
    _event.listen(Repo.instance.event(widget.eventId), _changed);
    _divisions.listen(Repo.instance.divisionsFor(widget.eventId), _changed);
    _watchMine();
  }

  void _watchMine() {
    _uid = Session.instance.uid;
    _mine.listen(Repo.instance.myRegistrations(), _changed);
  }

  // Someone signed in or out while this was open.
  void _onSession() {
    if (Session.instance.uid != _uid) _watchMine();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    _event.cancel();
    _divisions.cancel();
    _mine.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _event.value;
    if (e == null) return _event.ready ? const NotFoundScreen() : const LoadingField();
    return _EventDetailView(
      event: e,
      divisions: _divisions.value ?? const [],
      mine: [
        for (final r in _mine.value ?? const <Registration>[])
          if (r.eventId == e.id && r.status != 'released' && r.status != 'cancelled') r,
      ],
    );
  }
}

class _EventDetailView extends StatelessWidget {
  const _EventDetailView({required this.event, required this.divisions, required this.mine});

  final BBEvent event;
  final List<Division> divisions;
  final List<Registration> mine;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final wide = BB.isWide(context);
    final done = e.status == 'final';

    final ticket = ShowcaseTicket(
      event: e,
      spotsLeft: e.isOpen ? _spotsLeft(divisions) : null,
      // The large ticket needs a phone at least this wide to keep its name
      // on one line.
      large: wide || MediaQuery.sizeOf(context).width >= 380,
    );
    final Widget? action = e.resultsPublished
        ? BBButton.primary(
            'Results',
            expand: !wide,
            onPressed: () => context.go('/events/${e.id}/results'),
          )
        : e.isOpen
            ? BBButton.primary(
                'Reserve a spot',
                expand: !wide,
                // Signed out, the router sends them to sign in and back here.
                onPressed: () => context.go('/events/${e.id}/reserve'),
              )
            : null;
    final finePrint = TextLink(
      'The fine print',
      onTap: () => showFinePrint(context, items: _finePrint(e)),
    );
    final about = <Widget>[
      ticket,
      const SizedBox(height: 20),
      _Facts(event: e),
      if (e.description.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(e.description.trim(), style: BB.bodyStyle(16, height: 1.5)),
      ],
    ];
    final groups = <Widget>[
      if (divisions.isNotEmpty && !done) ...[
        const SectionTitle('Age groups', padding: EdgeInsets.only(bottom: 14)),
        ..._spaced([
          for (final d in divisions)
            _DivisionRow(
              division: d,
              open: e.isOpen,
              onTap: e.isOpen ? () => context.go('/events/${e.id}/reserve?division=${d.id}') : null,
            ),
        ], 10),
      ],
    ];
    final registrations = <Widget>[
      if (mine.isNotEmpty) ..._spaced([for (final r in mine) RegistrationRow(r, showEvent: false)], 10),
    ];

    if (wide) {
      final side = [
        ...groups,
        if (groups.isNotEmpty && registrations.isNotEmpty) const SizedBox(height: 40),
        ...registrations,
      ];
      return PageFrame(
        children: [
          const BackHeader('Showcases'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 115,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...about,
                    if (action != null) ...[const SizedBox(height: 28), action],
                    const SizedBox(height: 14),
                    finePrint,
                  ],
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                flex: 100,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side),
              ),
            ],
          ),
        ],
      );
    }
    return PageFrame(
      column: 600,
      children: [
        const BackHeader('Showcases'),
        const SizedBox(height: 2),
        ...about,
        if (groups.isNotEmpty) ...[const SizedBox(height: 36), ...groups],
        if (action != null) ...[const SizedBox(height: 26), action],
        if (registrations.isNotEmpty) ...[const SizedBox(height: 36), ...registrations],
        const SizedBox(height: 16),
        finePrint,
      ],
    );
  }
}

/// When, where, how much and who is hosting, as plain lines on the field.
class _Facts extends StatelessWidget {
  const _Facts({required this.event});

  final BBEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final when = fmtDateTime(e.start);
    // An address usually ends with the city already.
    final city = e.address.toLowerCase().contains(e.city.trim().toLowerCase()) ? '' : e.city;
    final street = [e.address, city].map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
    final venue = e.venue.trim();
    final place = [venue, street].where((s) => s.isNotEmpty).join(', ');
    final host = e.hostTeam.trim();
    final cause = e.raisingFor.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (when.isNotEmpty) _Fact(BBGlyph.calendar, when),
        if (place.isNotEmpty)
          _Fact(
            BBGlyph.pin,
            venue.isNotEmpty ? venue : street,
            sub: venue.isNotEmpty && street.isNotEmpty ? street : null,
            semanticLabel: 'Map, $place',
            onTap: () => launchUrl(
              Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': place}),
              mode: LaunchMode.externalApplication,
            ),
          ),
        if (e.price != null) _Fact(BBGlyph.tag, '${fmtPrice(e.price)} per player'),
        if (host.isNotEmpty)
          _Fact(BBGlyph.pennant, 'Hosted by $host${cause.isEmpty ? '' : ' for $cause'}'),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.glyph, this.text, {this.sub, this.onTap, this.semanticLabel});

  final BBGlyph glyph;
  final String text;
  final String? sub;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBIcon(glyph, size: 21, color: BB.creamSoft),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: BB.labelStyle(17, height: 1.25)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub!, style: BB.bodyStyle(15, height: 1.3)),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: BBIcon(BBGlyph.external, size: 17, color: BB.creamSoft),
            ),
        ],
      ),
    );
    if (onTap == null) return line;
    return Pressable(
      onTap: onTap,
      label: semanticLabel,
      builder: (context, down, focused) => Opacity(
        opacity: down ? 0.7 : 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(alignment: Alignment.centerLeft, heightFactor: 1, child: line),
        ),
      ),
    );
  }
}

/// One age group: its name and, while registration is open, what's left.
class _DivisionRow extends StatelessWidget {
  const _DivisionRow({required this.division, required this.open, this.onTap});

  final Division division;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = division;
    return Paper(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Row(
          children: [
            Expanded(
              child: Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BB.labelStyle(19, color: BB.ink, height: 1.1),
              ),
            ),
            if (open) ...[
              const SizedBox(width: 10),
              d.full ? const Pill('Waitlist') : Pill('${d.open} open', color: BB.mint),
            ],
            if (onTap != null)
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: BBIcon(BBGlyph.forward, size: 20, color: BB.ink),
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

// ---------- Reserve ----------

/// Pay by Venmo or Cash App with a code in the note, then tap Reserve.
class ReserveScreen extends StatefulWidget {
  const ReserveScreen({super.key, required this.eventId, this.divisionId});

  final String eventId;
  final String? divisionId;

  @override
  State<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends State<ReserveScreen> {
  final _code = Repo.newPaymentCode();
  final _payer = TextEditingController();
  final _event = _Feed<BBEvent?>();
  final _divisions = _Feed<List<Division>>();
  final _players = _Feed<List<Player>>();
  final _pay = _Feed<PaymentSettings>();
  late final TapGestureRecognizer _waiverLink;
  String? _uid;
  String? _playerId;
  String? _divisionId;
  String _via = 'venmo';
  bool _waiver = false;
  bool _skills = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _divisionId = widget.divisionId;
    _waiverLink = TapGestureRecognizer()..onTap = () => openSitePage('/waiver');
    _watch();
    Session.instance.addListener(_onSession);
  }

  @override
  void didUpdateWidget(ReserveScreen old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) {
      _divisionId = widget.divisionId;
      _watch();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _watch() {
    final repo = Repo.instance;
    _event.listen(repo.event(widget.eventId), _changed);
    _divisions.listen(repo.divisionsFor(widget.eventId), _changed);
    _pay.listen(repo.paymentSettings(), _changed);
    _watchPlayers();
  }

  void _watchPlayers() {
    _uid = Session.instance.uid;
    _players.listen(Repo.instance.myPlayers(), _changed);
  }

  // This screen can open before the sign-in is known; read again once it is.
  void _onSession() {
    if (Session.instance.uid != _uid) _watchPlayers();
    _changed();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    _event.cancel();
    _divisions.cancel();
    _players.cancel();
    _pay.cancel();
    _waiverLink.dispose();
    _payer.dispose();
    super.dispose();
  }

  bool get _canOpenApps => kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, message);
  }

  Future<void> _submit(BBEvent e, List<Player> players, List<Division> divisions) async {
    final player = players.where((p) => p.id == _playerId).firstOrNull;
    final division = divisions.where((d) => d.id == _divisionId).firstOrNull;
    if (player == null || division == null) {
      toast(context, 'Pick a player and an age group.');
      return;
    }
    if (!division.full && _payer.text.trim().isEmpty) {
      toast(context, 'Add the name on the account.');
      return;
    }
    if (!_waiver) {
      toast(context, 'Check the box to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Repo.instance.reserve(
        event: e,
        division: division,
        player: player,
        paymentCode: _code,
        paidVia: _via,
        payerName: _payer.text.trim(),
        skillsOptIn: _skills,
      );
      if (!mounted) return;
      final waitlisted = r.status == 'waitlisted';
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(waitlisted ? "You're on the list." : "You're in."),
          content: Text(
            waitlisted ? "We'll reach out when a spot opens." : "We'll confirm your payment shortly.",
          ),
          actions: [BBButton.paper('Done', small: true, onPressed: () => Navigator.pop(c))],
        ),
      );
      if (mounted) context.go('/events/${e.id}');
    } catch (err) {
      if (mounted) toast(context, err is StateError ? err.message : "Couldn't reserve. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _event.value;
    if (e == null) return _event.ready ? const NotFoundScreen() : const LoadingField();
    if (!Session.instance.ready || !_divisions.ready || !_players.ready) return const LoadingField();
    final divisions = _divisions.value ?? const <Division>[];
    final players = _players.value ?? const <Player>[];
    final pay = _pay.value ?? const PaymentSettings();

    if (players.isEmpty) {
      return PageFrame(
        column: 560,
        children: [
          BackHeader(e.name),
          const PageTitle('Reserve a spot'),
          const Quiet('Add your player first.'),
          const SizedBox(height: 18),
          BBButton.primary('Add your player', onPressed: () => context.go('/players/new')),
        ],
      );
    }

    _playerId ??= players.first.id;
    final full = divisions.where((d) => d.id == _divisionId).firstOrNull?.full ?? false;
    final payTo = pay.payTo.isNotEmpty ? pay.payTo : 'Battle Baseball';
    return PageFrame(
      column: 560,
      children: [
        BackHeader(e.name),
        const PageTitle('Reserve a spot'),
        const _Label('Player', top: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in players)
              BBChip(
                p.name,
                selected: _playerId == p.id,
                onTap: () => setState(() => _playerId = p.id),
              ),
            BBChip('Add player', onTap: () => context.go('/players/new')),
          ],
        ),
        if (divisions.isNotEmpty) ...[
          const _Label('Age group'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final d in divisions)
                BBChip(
                  d.full ? '${d.name} · waitlist' : d.name,
                  selected: _divisionId == d.id,
                  onTap: () => setState(() => _divisionId = d.id),
                ),
            ],
          ),
        ],
        if (!full) ...[
          const _Label('Pay'),
          if (pay.configured)
            _PayPanel(
              amount: e.price == null ? payTo : '${fmtPrice(e.price)} to $payTo',
              code: _code,
              pay: pay,
              canOpen: _canOpenApps,
              onCopy: _copy,
            )
          else
            const Quiet('Payment details are coming soon.'),
          const _Label('Paid with'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              BBChip('Venmo', selected: _via == 'venmo', onTap: () => setState(() => _via = 'venmo')),
              BBChip(
                'Cash App',
                selected: _via == 'cashapp',
                onTap: () => setState(() => _via = 'cashapp'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payer,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name on the account'),
          ),
        ],
        const SizedBox(height: 14),
        if (e.skillsContest)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _skills,
            onChanged: (v) => setState(() => _skills = v),
            title: const Text('Skills contest'),
          ),
        _Consent(
          value: _waiver,
          link: _waiverLink,
          onChanged: (v) => setState(() => _waiver = v),
        ),
        const SizedBox(height: 18),
        BBButton.primary(
          full ? 'Join the waitlist' : 'Reserve',
          expand: true,
          busy: _busy,
          onPressed: () => _submit(e, players, divisions),
        ),
        const SizedBox(height: 10),
        TextLink('The fine print', onTap: () => showFinePrint(context, items: _finePrint(e))),
      ],
    );
  }
}

/// A form section's name.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = 26});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 10),
        child: Semantics(header: true, child: Text(text, style: BB.title(22))),
      );
}

/// What to pay, the code for the note, and where to send it, printed like a
/// ticket.
class _PayPanel extends StatelessWidget {
  const _PayPanel({
    required this.amount,
    required this.code,
    required this.pay,
    required this.canOpen,
    required this.onCopy,
  });

  /// "$85 to Battle Baseball"
  final String amount;
  final String code;
  final PaymentSettings pay;

  /// Whether the Venmo and Cash App rows may open those apps.
  final bool canOpen;
  final void Function(String text, String message) onCopy;

  @override
  Widget build(BuildContext context) {
    final venmo = pay.venmo.replaceAll('@', '');
    final cash = pay.cashtag.replaceAll('\$', '');
    return Paper(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            child: Text(amount, style: BB.lilita(22)),
          ),
          const DashedRule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PUT THIS IN THE NOTE',
                        style: BB.caps(11.5, color: BB.ink2, tracking: 0.11),
                      ),
                      const SizedBox(height: 7),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          code,
                          maxLines: 1,
                          softWrap: false,
                          style: BB.lilita(38, height: 1).copyWith(letterSpacing: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconTap(BBGlyph.copy, label: 'Copy code', onTap: () => onCopy(code, 'Code copied')),
              ],
            ),
          ),
          if (venmo.isNotEmpty)
            _PayRow(
              app: 'Venmo',
              handle: '@$venmo',
              onCopy: () => onCopy('@$venmo', 'Copied'),
              url: canOpen ? 'https://venmo.com/u/$venmo' : null,
            ),
          if (cash.isNotEmpty)
            _PayRow(
              app: 'Cash App',
              handle: '\$$cash',
              onCopy: () => onCopy('\$$cash', 'Copied'),
              url: canOpen ? 'https://cash.app/\$$cash' : null,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.app, required this.handle, required this.onCopy, this.url});

  final String app;
  final String handle;
  final String? url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(height: 1.5, child: ColoredBox(color: BB.inkRule)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 6, 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.toUpperCase(), style: BB.caps(11.5, color: BB.ink2, tracking: 0.11)),
                      const SizedBox(height: 5),
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BB.labelStyle(18, color: BB.ink, height: 1.1),
                      ),
                    ],
                  ),
                ),
                IconTap(BBGlyph.copy, label: 'Copy $app', onTap: onCopy),
                if (url != null)
                  IconTap(
                    BBGlyph.external,
                    label: 'Open $app',
                    onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
          ),
        ],
      );
}

/// The one required box: a parent or guardian agreeing to the waiver.
class _Consent extends StatelessWidget {
  const _Consent({required this.value, required this.onChanged, required this.link});

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Opens the waiver from the word "waiver".
  final TapGestureRecognizer link;

  @override
  Widget build(BuildContext context) {
    final text = BB.bodyStyle(16, color: BB.cream, height: 1.35);
    return Row(
      children: [
        Semantics(
          checked: value,
          child: Pressable(
            onTap: () => onChanged(!value),
            label: 'I agree to the waiver',
            builder: (context, down, focused) => SizedBox(
              width: 44,
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: value ? BB.coral : BB.fieldRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: focused ? BB.cream : BB.ink, width: 2),
                    boxShadow: BB.lip(2),
                  ),
                  child: value ? Center(child: BBIcon(BBGlyph.check, size: 18, color: BB.ink)) : null,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text.rich(
                TextSpan(
                  style: text,
                  children: [
                    const TextSpan(text: "I'm the parent or guardian and I agree to the "),
                    TextSpan(
                      text: 'waiver',
                      recognizer: link,
                      mouseCursor: SystemMouseCursors.click,
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        decorationColor: BB.coral,
                        decorationThickness: 2.4,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Results ----------

class EventResultsScreen extends StatefulWidget {
  const EventResultsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventResultsScreen> createState() => _EventResultsScreenState();
}

class _EventResultsScreenState extends State<EventResultsScreen> {
  final _event = _Feed<BBEvent?>();
  final _awards = _Feed<List<Award>>();
  final _readings = _Feed<List<Measurement>>();
  final _lines = _Feed<List<StatLine>>();

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(EventResultsScreen old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) _watch();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _watch() {
    final repo = Repo.instance;
    final id = widget.eventId;
    _event.listen(repo.event(id), _changed);
    _awards.listen(repo.publishedAwards(id), _changed);
    _readings.listen(repo.publishedMeasurements(id), _changed);
    _lines.listen(repo.publishedStatLines(id), _changed);
  }

  @override
  void dispose() {
    _event.cancel();
    _awards.cancel();
    _readings.cancel();
    _lines.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _event.value;
    if (e == null) return _event.ready ? const NotFoundScreen() : const LoadingField();
    return _ResultsView(
      event: e,
      loading: !(_awards.ready && _readings.ready && _lines.ready),
      awards: _awards.value ?? const [],
      readings: _readings.value ?? const [],
      lines: _lines.value ?? const [],
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.event,
    required this.loading,
    required this.awards,
    required this.readings,
    required this.lines,
  });

  final BBEvent event;
  final bool loading;
  final List<Award> awards;
  final List<Measurement> readings;
  final List<StatLine> lines;

  static String _name(String publicName) => publicName.isEmpty ? 'Private player' : publicName;

  /// Each player's best fastball of the day, fastest first.
  List<Measurement> get _fastballs {
    final best = <String, Measurement>{};
    for (final m in readings.where((m) => m.type == 'fastball')) {
      if ((best[m.playerId]?.value ?? 0) < m.value) best[m.playerId] = m;
    }
    return (best.values.toList()..sort((a, b) => b.value.compareTo(a.value))).take(25).toList();
  }

  List<Award> get _ranked {
    final order = awardTypes.keys.toList();
    int rank(Award a) {
      final i = order.indexOf(a.type);
      return i < 0 ? order.length : i;
    }

    return [...awards]..sort((a, b) {
        final byType = rank(a).compareTo(rank(b));
        return byType != 0 ? byType : a.divisionName.compareTo(b.divisionName);
      });
  }

  List<StatLine> get _batting => lines.where((l) => l.hasBatting).toList()
    ..sort((a, b) {
      if (a.h != b.h) return b.h.compareTo(a.h);
      if (a.hr != b.hr) return b.hr.compareTo(a.hr);
      return a.ab.compareTo(b.ab);
    });

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final fastballs = _fastballs;
    final ranked = _ranked;
    final batting = _batting;
    VoidCallback? profile(String playerId, String publicName) =>
        publicName.isEmpty ? null : () => context.go('/players/$playerId');
    String division(String name, int? gradYear) =>
        name.isNotEmpty ? name : (gradYear == null ? '' : 'Class of $gradYear');

    final Widget? awardsSection = ranked.isEmpty
        ? null
        : _Section('Awards', children: _spaced([
            for (final (i, a) in ranked.indexed)
              AwardLine(
                title: a.label,
                sub: [_name(a.publicName), a.divisionName].where((s) => s.isNotEmpty).join(' · '),
                mark: awardMark(a.type),
                tilt: i.isEven ? -8 : 7,
                onPaper: false,
              ),
          ], 14));

    final Widget? fastballSection = fastballs.isEmpty
        ? null
        : _Section('Fastball', children: [
            ..._spaced([
              for (final (i, m) in fastballs.take(3).indexed)
                MiniCard(
                  rank: i + 1,
                  first: i == 0,
                  name: _name(m.publicName),
                  sub: division(m.divisionName, m.gradYear),
                  value: fmtValue(m.value, m.type),
                  unit: 'MPH',
                  onTap: profile(m.playerId, m.publicName),
                ),
            ], 9),
            if (fastballs.length > 3) ...[
              const SizedBox(height: 12),
              RuledPanel(children: [
                for (final (i, m) in fastballs.indexed.skip(3))
                  RuledRow(
                    rank: i + 1,
                    name: _name(m.publicName),
                    sub: m.divisionName,
                    value: fmtValue(m.value, m.type),
                    unit: 'MPH',
                    onTap: profile(m.playerId, m.publicName),
                  ),
              ]),
            ],
          ]);

    final Widget? battingSection = batting.isEmpty
        ? null
        : _Section('Batting', children: [
            LayoutBuilder(
              builder: (context, box) {
                // The name needs room first: every column on a wide panel,
                // the five that matter on a phone, four on a small one.
                final all = box.maxWidth >= 470;
                final rbi = box.maxWidth >= 320;
                return RuledPanel(
                  columns: ['AB', 'H', 'HR', if (rbi) 'RBI', if (all) ...['R', 'BB'], 'AVG'],
                  children: [
                    for (final l in batting)
                      RuledRow(
                        name: l.publicName.isEmpty ? (all ? 'Private player' : 'Private') : l.publicName,
                        sub: all ? l.divisionName : null,
                        cells: [
                          '${l.ab}',
                          '${l.h}',
                          '${l.hr}',
                          if (rbi) '${l.rbi}',
                          if (all) ...['${l.r}', '${l.bb}'],
                          l.avg,
                        ],
                        onTap: profile(l.playerId, l.publicName),
                      ),
                  ],
                );
              },
            ),
          ]);

    final sections = [?awardsSection, ?fastballSection, ?battingSection];
    final head = [BackHeader(event.name), const PageTitle('Results')];
    if (loading || sections.isEmpty) {
      return PageFrame(
        column: wide ? null : 640,
        children: [
          ...head,
          if (loading) const LoadingField() else const Quiet('Results post after the showcase.'),
        ],
      );
    }
    if (!wide) {
      return PageFrame(column: 640, children: [...head, ..._spaced(sections, 40)]);
    }
    // Desktop: the board at the left, honors and the box score beside it.
    final left = [fastballSection ?? battingSection ?? awardsSection!];
    final right = [for (final s in sections) if (!left.contains(s)) s];
    return PageFrame(
      children: [
        ...head,
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 115,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
            ),
            const SizedBox(width: 72),
            Expanded(
              flex: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spaced(right, 44),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionTitle(title), ...children],
      );
}
