import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:battle_baseball/screens/home.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Showcases')),
        body: StreamBuilder<List<BBEvent>>(
          stream: Repo.instance.publicEvents(),
          builder: (context, s) {
            final w = streamState(s);
            if (w != null) return w;
            final upcoming = s.data!.where((e) => e.status != 'final').toList();
            final past = s.data!.where((e) => e.status == 'final').toList().reversed.toList();
            return PageBody(
              children: [
                const Text(
                  'Individual player showcases: sign up on your own, play on an even team '
                  'with kids at your level, and leave with a clocked fastball and stats '
                  'to share.',
                  style: TextStyle(color: BB.muted, fontSize: 16),
                ),
                const SectionLabel('Upcoming'),
                if (upcoming.isEmpty)
                  const EmptyNote(
                      'No showcases are open yet. The first one is coming to Baton Rouge; '
                      'check back soon or follow Battle Baseball on Facebook.'),
                for (final e in upcoming) EventCard(event: e),
                if (past.isNotEmpty) ...[
                  const SectionLabel('Past showcases'),
                  for (final e in past)
                    EventCard(event: e, onTap: () => context.go('/events/${e.id}/results')),
                ],
              ],
            );
          },
        ),
      );
}

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final repo = Repo.instance;
    return StreamBuilder<BBEvent?>(
      stream: repo.event(eventId),
      builder: (context, es) {
        final e = es.data;
        return Scaffold(
          appBar: AppBar(title: Text(e?.name ?? 'Showcase')),
          body: es.hasError
              ? streamState(es)
              : e == null
                  ? (es.connectionState == ConnectionState.waiting
                      ? streamState(es)
                      : const Center(child: Text('This showcase is no longer listed.')))
                  : _EventBody(e: e),
        );
      },
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.e});
  final BBEvent e;

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    return PageBody(
      children: [
        Eyebrow([if (e.ageGroups.isNotEmpty) e.ageGroups, 'Player showcase'].join(' · ')),
        Headline(e.name, size: 32),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          StatusChip(statusLabel(e.status), color: statusColor(e.status)),
          if (e.skillsContest) const StatusChip('Skills contest', color: BB.grape),
        ]),
        const SizedBox(height: 16),
        GumCard(
          edge: BB.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Fact(Icons.event, fmtDateTime(e.start).isEmpty ? 'Date coming soon' : fmtDateTime(e.start)),
              _Fact(Icons.place, [e.venue, e.address, e.city].where((x) => x.isNotEmpty).join(', ')),
              _Fact(Icons.payments_outlined, '${fmtPrice(e.price)} per player'),
              if (e.hostTeam.isNotEmpty)
                _Fact(Icons.volunteer_activism,
                    'Hosted by ${e.hostTeam}${e.raisingFor.isNotEmpty ? ', raising money for ${e.raisingFor}' : ''}'),
            ],
          ),
        ),
        if (e.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(e.description, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
        if (e.resultsPublished) ...[
          const SizedBox(height: 16),
          CandyButton(
            label: 'See results',
            icon: Icons.emoji_events,
            face: BB.lemon,
            edge: BB.ink,
            onPressed: () => context.go('/events/${e.id}/results'),
          ),
        ],
        if (session.signedIn)
          StreamBuilder<List<Registration>>(
            stream: Repo.instance.myRegistrations(),
            builder: (context, s) {
              final mine = (s.data ?? const <Registration>[])
                  .where((r) => r.eventId == e.id && r.status != 'released' && r.status != 'cancelled')
                  .toList();
              if (mine.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Your players'),
                  for (final r in mine) RegistrationCard(r: r),
                ],
              );
            },
          ),
        const SectionLabel('Age groups and spots'),
        StreamBuilder<List<Division>>(
          stream: Repo.instance.divisionsFor(e.id),
          builder: (context, s) {
            final w = streamState(s);
            if (w != null) return w;
            if (s.data!.isEmpty) {
              return const EmptyNote('Age groups and skill levels will be posted soon.');
            }
            return Column(
              children: [
                for (final (i, d) in s.data!.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GumCard(
                      edge: BB.candies[i % BB.candies.length],
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.name, style: BB.labelStyle(18)),
                                Text(
                                  d.full ? 'Full: join the waitlist' : '${d.open} of ${d.capacity} spots open',
                                  style: const TextStyle(color: BB.cardMuted),
                                ),
                              ],
                            ),
                          ),
                          if (e.isOpen)
                            CandyButton(
                              small: true,
                              label: d.full ? 'Waitlist' : 'Reserve',
                              onPressed: () => context.go('/events/${e.id}/reserve?division=${d.id}'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        GumCard(
          edge: BB.lemon,
          child: Text(
            'Spots are limited so every player gets plenty of reps. Send your payment, tap '
            "Reserve, and we'll hold the spot while we confirm it. If we can't match a payment "
            'within 24 hours, the spot goes to the next family on the waitlist. '
            'Plans change? Cancel by ${fmtDate(e.refundCutoff)} for a full refund. '
            'If rain cancels the showcase, pick a refund or a credit toward the next one.',
            style: const TextStyle(color: BB.cardMuted, fontSize: 15, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: BB.blue),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            ],
          ),
        );
}

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
  }

  @override
  void dispose() {
    _payer.dispose();
    super.dispose();
  }

  bool get _canOpenApps => kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, 'Copied $what');
  }

  Future<void> _submit(BBEvent e, List<Player> players, List<Division> divisions) async {
    final player = players.where((p) => p.id == _playerId).firstOrNull;
    final division = divisions.where((d) => d.id == _divisionId).firstOrNull;
    if (player == null || division == null) {
      toast(context, 'Pick a player and an age group.');
      return;
    }
    if (!division.full && _payer.text.trim().isEmpty) {
      toast(context, 'Tell us the name on the account you paid from.');
      return;
    }
    if (!_waiver) {
      toast(context, 'Please agree to the waiver to reserve.');
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
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(r.status == 'waitlisted' ? "You're on the waitlist" : "You're in!"),
          content: Text(r.status == 'waitlisted'
              ? "${player.firstName} is on the waitlist for ${division.name}. We'll let you know "
                  'as soon as a spot opens up. No need to pay until then.'
              : "${player.firstName}'s spot is held while we confirm your payment, usually within "
                  "a few hours. We'll let you know as soon as it's done."),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        ),
      );
      if (mounted) context.go('/events/${e.id}');
    } catch (err) {
      if (mounted) toast(context, err is StateError ? err.message : "Couldn't reserve: $err");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Repo.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Reserve a spot')),
      body: StreamBuilder<BBEvent?>(
        stream: repo.event(widget.eventId),
        builder: (context, es) {
          final e = es.data;
          if (e == null) return streamState(es) ?? const SizedBox.shrink();
          return StreamBuilder<List<Division>>(
            stream: repo.divisionsFor(e.id),
            builder: (context, ds) => StreamBuilder<List<Player>>(
              stream: repo.myPlayers(),
              builder: (context, ps) => StreamBuilder<PaymentSettings>(
                stream: repo.paymentSettings(),
                builder: (context, pays) {
                  final wait = streamState(ds) ?? streamState(ps);
                  if (wait != null) return wait;
                  return _form(e, ds.data!, ps.data!, pays.data ?? const PaymentSettings());
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _form(BBEvent e, List<Division> divisions, List<Player> players, PaymentSettings pay) {
    if (players.isEmpty) {
      return PageBody(children: [
        EmptyNote(
          'Add your player first. It takes a minute, and their details carry over to every showcase.',
          action: CandyButton(label: 'Add a player', onPressed: () => context.go('/players/new')),
        ),
      ]);
    }
    _playerId ??= players.first.id;
    final division = divisions.where((d) => d.id == _divisionId).firstOrNull;
    final full = division?.full ?? false;
    return PageBody(
      children: [
        Eyebrow(e.name),
        const Headline('Who is playing?', size: 26),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in players)
            ChoiceChip(
              label: Text(p.name),
              selected: _playerId == p.id,
              onSelected: (_) => setState(() => _playerId = p.id),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add player'),
            onPressed: () => context.go('/players/new'),
          ),
        ]),
        const SectionLabel('Age group and level'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in divisions)
            ChoiceChip(
              label: Text(d.full ? '${d.name} (waitlist)' : d.name),
              selected: _divisionId == d.id,
              onSelected: (_) => setState(() => _divisionId = d.id),
            ),
        ]),
        if (!full) ...[
          const SectionLabel('Send your payment'),
          GumCard(
            edge: BB.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmtPrice(e.price)} to ${pay.payTo.isNotEmpty ? pay.payTo : 'Battle Baseball'}',
                    style: BB.title(22)),
                const SizedBox(height: 8),
                const Text('Put this code in the payment note instead of your player\'s name:',
                    style: TextStyle(color: BB.cardMuted)),
                const SizedBox(height: 6),
                Row(children: [
                  Text(_code, style: BB.title(28, color: BB.lemon)),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Copy code',
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copy(_code, 'the payment note'),
                  ),
                ]),
                const SizedBox(height: 4),
                if (!pay.configured)
                  const Text('Payment details are being set up. Check back shortly.',
                      style: TextStyle(color: BB.accent)),
                if (pay.venmo.isNotEmpty)
                  _PayRow(
                    app: 'Venmo',
                    handle: '@${pay.venmo.replaceAll('@', '')}',
                    url: _canOpenApps ? 'https://venmo.com/u/${pay.venmo.replaceAll('@', '')}' : null,
                    onCopy: () => _copy('@${pay.venmo.replaceAll('@', '')}', 'the Venmo handle'),
                  ),
                if (pay.cashtag.isNotEmpty)
                  _PayRow(
                    app: 'Cash App',
                    handle: '\$${pay.cashtag.replaceAll('\$', '')}',
                    url: _canOpenApps ? 'https://cash.app/\$${pay.cashtag.replaceAll('\$', '')}' : null,
                    onCopy: () => _copy('\$${pay.cashtag.replaceAll('\$', '')}', 'the \$cashtag'),
                  ),
              ],
            ),
          ),
          const SectionLabel('Which app did you pay from?'),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('Venmo'),
              selected: _via == 'venmo',
              onSelected: (_) => setState(() => _via = 'venmo'),
            ),
            ChoiceChip(
              label: const Text('Cash App'),
              selected: _via == 'cashapp',
              onSelected: (_) => setState(() => _via = 'cashapp'),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _payer,
            decoration: const InputDecoration(
              labelText: 'Name on the account you paid from',
              helperText: 'So we can match your payment quickly.',
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          const EmptyNote(
              "This group is full right now. Join the waitlist and we'll offer you the next "
              'open spot. No need to pay until then.'),
        ],
        if (e.skillsContest)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _skills,
            onChanged: (v) => setState(() => _skills = v),
            title: const Text('Join the skills contest (pop time, 40-yard dash)'),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _waiver,
          onChanged: (v) => setState(() => _waiver = v ?? false),
          title: const Text(
            "I'm this player's parent or guardian. I agree to the event waiver and medical "
            'release, and I understand the refund policy: a full refund for cancellations more '
            'than a week before, and a refund or credit if rain cancels the showcase.',
            style: TextStyle(fontSize: 14.5),
          ),
        ),
        TextButton(
          onPressed: () => launchUrl(Uri.parse('https://showcase.getbattleplan.app/waiver')),
          child: const Text('Read the waiver'),
        ),
        const SizedBox(height: 10),
        CandyButton(
          expand: true,
          busy: _busy,
          label: full ? 'Join the waitlist' : "Reserve, I've paid",
          onPressed: () => _submit(e, players, divisions),
        ),
      ],
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(width: 86, child: Text(app, style: BB.labelStyle(16))),
            Expanded(child: Text(handle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy, size: 20), onPressed: onCopy),
            if (url != null)
              IconButton(
                tooltip: 'Open $app',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
              ),
          ],
        ),
      );
}

class EventResultsScreen extends StatelessWidget {
  const EventResultsScreen({super.key, required this.eventId});
  final String eventId;
  @override
  Widget build(BuildContext context) {
    final repo = Repo.instance;
    return StreamBuilder<BBEvent?>(
      stream: repo.event(eventId),
      builder: (context, es) => Scaffold(
        appBar: AppBar(title: Text(es.data == null ? 'Results' : '${es.data!.name} results')),
        body: PageBody(children: [
          const SectionLabel('Award winners'),
          StreamBuilder<List<Award>>(
            stream: repo.publishedAwards(eventId),
            builder: (context, s) {
              final w = streamState(s);
              if (w != null) return w;
              if (s.data!.isEmpty) return const EmptyNote('Awards post here once results are published.');
              return Column(children: [
                for (final a in s.data!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GumCard(
                      edge: awardColor(a.type),
                      child: Row(children: [
                        AwardBadge(a),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${a.publicName.isEmpty ? 'Private player' : a.publicName} · ${a.divisionName}',
                            style: BB.labelStyle(16),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          const SectionLabel('Fastest fastballs'),
          StreamBuilder<List<Measurement>>(
            stream: repo.publishedMeasurements(eventId),
            builder: (context, s) {
              final w = streamState(s);
              if (w != null) return w;
              final best = <String, Measurement>{};
              for (final m in s.data!.where((m) => m.type == 'fastball')) {
                if ((best[m.playerId]?.value ?? 0) < m.value) best[m.playerId] = m;
              }
              final list = best.values.toList()..sort((a, b) => b.value.compareTo(a.value));
              if (list.isEmpty) return const EmptyNote('Velocities post here once results are published.');
              return Column(children: [
                for (final (i, m) in list.take(25).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GumCard(
                      edge: i < 3 ? BB.lemon : BB.blue,
                      child: Row(children: [
                        SizedBox(width: 34, child: Text('${i + 1}', style: BB.title(20))),
                        Expanded(
                          child: Text(
                            '${m.publicName.isEmpty ? 'Private player' : m.publicName}\n${m.divisionName}',
                            style: BB.labelStyle(15),
                          ),
                        ),
                        Readout(value: fmtValue(m.value, m.type), unit: 'MPH', size: 30),
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
