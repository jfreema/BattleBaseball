// Home. Signed out it is the landing page: the headline, one line and the
// sample card. A family with players sees their own cards and spots instead.
import 'dart:math' as math;

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/sample.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/design/ticket.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:battle_baseball/screens/merch.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Reads everything Home shows and hands it to [_HomeView].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _session = Session.instance;
  late final Stream<List<BBEvent>> _events = Repo.instance.publicEvents();
  late final Stream<List<Measurement>> _leaders = Repo.instance.leaderboard('fastball');
  String? _uid;
  Stream<List<Player>>? _players;
  Stream<List<Registration>>? _registrations;

  @override
  void initState() {
    super.initState();
    _bind();
    _session.addListener(_onSession);
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    super.dispose();
  }

  void _bind() {
    _uid = _session.uid;
    _players = _uid == null ? null : Repo.instance.myPlayers();
    _registrations = _uid == null ? null : Repo.instance.myRegistrations();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {
      if (_session.uid != _uid) _bind();
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _uid != null;
    return StreamBuilder<List<BBEvent>>(
      stream: _events,
      builder: (context, events) => StreamBuilder<List<Measurement>>(
        stream: _leaders,
        builder: (context, leaders) => StreamBuilder<List<Player>>(
          // Keyed so one family's players never linger for the next sign-in.
          key: ValueKey('players $_uid'),
          stream: _players,
          builder: (context, players) => StreamBuilder<List<Registration>>(
            key: ValueKey('registrations $_uid'),
            stream: _registrations,
            builder: (context, registrations) => _HomeView(
              ready: _session.ready,
              signedIn: signedIn,
              // A failed read shows the same as nothing listed.
              events: events.data ?? (events.hasError ? const [] : null),
              leaders: leaders.data ?? const [],
              players: signedIn ? players.data ?? (players.hasError ? const [] : null) : const [],
              registrations: registrations.data ?? const [],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.ready,
    required this.signedIn,
    required this.events,
    required this.leaders,
    required this.players,
    required this.registrations,
  });

  /// False until the app knows whether anyone is signed in.
  final bool ready;
  final bool signedIn;

  /// Null while the showcases are still loading.
  final List<BBEvent>? events;

  /// Best public fastballs, fastest first.
  final List<Measurement> leaders;

  /// The family's players. Null while they are still loading.
  final List<Player>? players;
  final List<Registration> registrations;

  /// The family's spots at showcases that have not been played yet.
  List<Registration> get _upcoming {
    final listed = {for (final e in events ?? const <BBEvent>[]) e.id: e};
    final far = DateTime(2100);
    DateTime when(Registration r) => listed[r.eventId]?.start ?? far;
    return registrations
        .where((r) =>
            r.status != 'released' && r.status != 'cancelled' && listed[r.eventId]?.status != 'final')
        .toList()
      ..sort((a, b) {
        final byDate = when(a).compareTo(when(b));
        return byDate != 0 ? byDate : a.playerName.compareTo(b.playerName);
      });
  }

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final family = players?.isNotEmpty ?? false;
    final open = events?.where((e) => e.isOpen).firstOrNull;
    final next = open ?? events?.where((e) => e.status == 'live' || e.status == 'closed').firstOrNull;

    Widget ticket(BBEvent e) => _NextTicket(key: ValueKey(e.id), event: e);

    // A visitor with an open showcase already has its ticket in the hero.
    final Widget? nextSection = events == null || (!family && open != null)
        ? null
        : _Section(title: 'Next Showcase', child: next == null ? const TbaTicket() : ticket(next));
    final top = leaders.where((m) => m.publicName.isNotEmpty).take(3).toList();
    final Widget? leadersSection =
        top.isEmpty ? null : _Leaders(top: top, own: {for (final p in players ?? const <Player>[]) p.id});
    final lower = [?nextSection, ?leadersSection];
    final spots = family ? _upcoming : const <Registration>[];

    // What the hero offers: the open showcase's ticket, or the one next step.
    // Until that is known it holds a button's height, so less moves.
    final Widget action = events == null || !ready
        ? SizedBox(height: wide ? 67 : 59)
        : open != null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 524 : double.infinity),
                child: ticket(open),
              )
            : signedIn
                ? BBButton.primary('Add your player', large: wide, onPressed: () => context.go('/players/new'))
                : BBButton.primary('Create an account', large: wide, onPressed: () => context.go('/sign-up'));

    return PageFrame(
      // Phone layouts stay a phone's width on a tablet.
      maxWidth: wide ? BB.contentWidth : 560,
      children: [
        if (!wide) const _Header(),
        if (players == null)
          const LoadingField()
        else if (family) ...[
          SizedBox(height: wide ? 26 : 2),
          _CardRow(players: players!),
          if (spots.isNotEmpty) ...[
            const SizedBox(height: 26),
            _Grid(
              columns: wide ? 2 : 1,
              gap: 20,
              runGap: 10,
              children: [for (final r in spots) RegistrationRow(r)],
            ),
            const SizedBox(height: 4),
            TextLink('The fine print', onTap: () => showFinePrint(context)),
          ],
        ] else
          _Hero(action: action),
        if (players != null && lower.isNotEmpty) ...[
          SizedBox(height: wide ? 64 : (family ? 40 : 52)),
          if (wide)
            _Grid(columns: 2, gap: 72, runGap: 0, children: lower)
          else
            for (final (i, section) in lower.indexed) ...[if (i > 0) const SizedBox(height: 48), section],
        ],
        if (players != null) ...[
          SizedBox(height: wide ? 64 : 48),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 524 : double.infinity),
            child: const MerchSection(),
          ),
          SizedBox(height: wide ? 64 : 44),
          const _HostLine(),
          if (wide) const _Footer() else const PoweredBy(),
        ],
      ],
    );
  }
}

/// The phone's top row. On desktop the shell's top bar carries both.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => TabHeader(
        trailing: Text(
          'BATON ROUGE, LA',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: BB.caps(12.5, weight: FontWeight.w600),
        ),
      );
}

/// The landing hero: copy, then the sample card under it on phones or at its
/// right on desktop. web/index.html draws the same headline and line in the
/// same place while the app loads, so keep the two in step.
class _Hero extends StatelessWidget {
  const _Hero({required this.action});

  final Widget action;

  static const _line = 'Youth players sign up solo and every fastball gets clocked on radar.';

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    Widget copy(double top) => Padding(
          padding: EdgeInsets.only(top: top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Headline(),
              SizedBox(height: wide ? 26 : 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 462 : 357),
                child: Text(_line, style: BB.bodyStyle(wide ? 21 : 17)),
              ),
              SizedBox(height: wide ? 30 : 20),
              action,
            ],
          ),
        );
    return LayoutBuilder(
      builder: (context, box) {
        if (!wide) {
          // 320 wide in a 358 column, and narrower in step on small phones.
          final card = math.min(320.0, box.maxWidth * 320 / 358);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy(12),
              const SizedBox(height: 44),
              Center(child: _SampleCard(width: card, wide: false)),
            ],
          );
        }
        final card = (box.maxWidth * 0.375).clamp(340.0, 420.0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(top: 30, bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Set down from the top by a share of the card, so the copy
              // sits level with the card's middle whatever the action is.
              Expanded(child: copy(card * 0.18)),
              const SizedBox(width: 24),
              SizedBox(width: card + 60, child: Center(child: _SampleCard(width: card, wide: true))),
            ],
          ),
        );
      },
    );
  }
}

/// "Play the Showcase. Earn your card." on three lines, the middle one on
/// the coral slab. It shrinks as one piece when the column is too narrow.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final size = wide ? 88.0 : 47.0;
    final leading = wide ? 1.0 : 1.03;
    final onField = BB.title(size, drop: wide ? 6 : 4).copyWith(height: leading);
    final onSlab = BB.lilita(size, height: leading).copyWith(letterSpacing: size * 0.005);
    Widget line(String text, TextStyle style) =>
        Text(text, maxLines: 1, softWrap: false, textScaler: TextScaler.noScaling, style: style);
    return Semantics(
      header: true,
      label: 'Play the Showcase. Earn your card.',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('Play the', onField),
              Padding(
                padding: EdgeInsets.only(top: 0.1 * size, bottom: 0.2 * size),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(-0.06 * size, 0, 0)..rotateZ(-2.5 * math.pi / 180),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(0.2 * size, 0, 0.2 * size, 0.06 * size),
                    decoration: BoxDecoration(
                      color: BB.coral,
                      borderRadius: BorderRadius.circular(0.24 * size),
                      border: Border.all(color: BB.ink, width: wide ? 4 : 3),
                      boxShadow: BB.lip(wide ? 7 : 5),
                    ),
                    child: line('Showcase.', onSlab),
                  ),
                ),
              ),
              line('Earn your card.', onField),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mason R.'s card with a second card's kraft edge showing behind it, and
/// the stamp that says what it is.
class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.width, required this.wide});

  final double width;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // The mock's offsets are for a 320 card on phones and a 420 on desktop.
    final k = width / (wide ? 420 : 320);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 4,
              left: 0,
              width: width,
              height: width * 1.34,
              child: ExcludeSemantics(
                child: Transform.rotate(
                  angle: (wide ? -5 : 5) * math.pi / 180,
                  child: Transform.translate(
                    offset: wide ? Offset(-22 * k, 6 * k) : Offset(14 * k, 4 * k),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: BB.kraft,
                        borderRadius: BorderRadius.circular(width * (wide ? 22 / 420 : 18 / 320)),
                        border: Border.all(color: BB.ink, width: wide ? 3.5 : 3),
                        boxShadow: BB.lip(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PlayerCard(
              profile: Sample.profile,
              topFastball: Sample.topFastball,
              awards: Sample.awards(),
              width: width,
              rotation: wide ? 4 : -3.5,
              sample: true,
              onTap: () => context.go('/players/sample'),
            ),
          ],
        ),
        // The card's own height already includes its lip.
        SizedBox(height: (wide ? 84 : 54) * k - 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Stamp('SAMPLE'),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Every player gets one.',
                style: BB.labelStyle(wide ? 17 : 15.5, height: 1.35),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A showcase's ticket with its open spots added up across age groups.
class _NextTicket extends StatefulWidget {
  const _NextTicket({super.key, required this.event});

  final BBEvent event;

  @override
  State<_NextTicket> createState() => _NextTicketState();
}

class _NextTicketState extends State<_NextTicket> {
  late final Stream<List<Division>> _divisions = Repo.instance.divisionsFor(widget.event.id);

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return StreamBuilder<List<Division>>(
      stream: _divisions,
      builder: (context, s) {
        final groups = s.data ?? const <Division>[];
        return ShowcaseTicket(
          event: e,
          // No age groups yet says nothing about spots.
          spotsLeft: groups.isEmpty ? null : groups.fold<int>(0, (n, d) => n + d.open),
          onTap: () => context.go('/events/${e.id}'),
          onReserve: e.isOpen ? () => context.go('/events/${e.id}/reserve') : null,
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionTitle(title), child],
      );
}

/// The three fastest public fastballs.
class _Leaders extends StatelessWidget {
  const _Leaders({required this.top, required this.own});

  final List<Measurement> top;

  /// Ids of the signed-in family's players, marked with the coral dot.
  final Set<String> own;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Fastball leaders'),
          for (final (i, m) in top.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 9),
              child: MiniCard(
                rank: i + 1,
                name: m.publicName,
                sub: m.gradYear == null ? null : 'CLASS OF ${m.gradYear}',
                value: fmtValue(m.value, 'fastball'),
                unit: 'MPH',
                first: i == 0,
                dot: own.contains(m.playerId),
                onTap: () => context.go('/players/${m.playerId}'),
              ),
            ),
          const SizedBox(height: 7),
          TextLink('All leaders', onTap: () => context.go('/leaders')),
        ],
      );
}

/// The family's cards in a row that scrolls sideways, ending in a blank
/// card for adding another player.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    // 300 wide, less on a small phone so the next card still shows its edge.
    final width = math.min(300.0, MediaQuery.sizeOf(context).width - 76);
    final u = width / 20;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Cards slide out under the page's side padding, not into a hard edge.
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, p) in players.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: _OwnCard(key: ValueKey(p.id), player: p, width: width, rotation: i == 0 ? -1.5 : 0),
            ),
          SizedBox(
            width: 150,
            height: PlayerCard.heightFor(width),
            child: Paper(
              color: BB.kraft,
              radius: 1.15 * u,
              lip: 0.36 * u,
              padding: EdgeInsets.zero,
              onTap: () => context.go('/players/new'),
              semanticLabel: 'Add player',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BB.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: BB.ink, width: 2.5),
                      boxShadow: BB.lip(3),
                    ),
                    child: BBIcon(BBGlyph.plus, size: 24, color: BB.ink),
                  ),
                  const SizedBox(height: 15),
                  Text('Add player', textAlign: TextAlign.center, style: BB.labelStyle(17, color: BB.ink, height: 1.1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the family's players as a card, with the player's own top
/// fastball and awards.
class _OwnCard extends StatefulWidget {
  const _OwnCard({super.key, required this.player, required this.width, this.rotation = 0});

  final Player player;
  final double width;
  final double rotation;

  @override
  State<_OwnCard> createState() => _OwnCardState();
}

class _OwnCardState extends State<_OwnCard> {
  late final Stream<List<Measurement>> _readings = Repo.instance.playerMeasurements(widget.player.id);
  late final Stream<List<Award>> _awards = Repo.instance.playerAwards(widget.player.id);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Measurement>>(
        stream: _readings,
        builder: (context, readings) => StreamBuilder<List<Award>>(
          stream: _awards,
          builder: (context, awards) {
            final fastballs = (readings.data ?? const <Measurement>[])
                .where((m) => m.type == 'fastball')
                .map((m) => m.value);
            return PlayerCard(
              profile: widget.player.toPublic(),
              topFastball: fastballs.isEmpty ? null : fastballs.reduce(math.max),
              awards: awards.data ?? const [],
              width: widget.width,
              rotation: widget.rotation,
              onTap: () => context.go('/players/${widget.player.id}'),
            );
          },
        ),
      );
}

/// Children set out in equal columns, a row at a time.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.gap, required this.runGap, required this.children});

  final int columns;
  final double gap;
  final double runGap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i += columns)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : runGap),
              child: columns == 1
                  ? children[i]
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < columns; c++) ...[
                          if (c > 0) SizedBox(width: gap),
                          Expanded(
                            child: i + c < children.length ? children[i + c] : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      );
}

class _HostLine extends StatelessWidget {
  const _HostLine();

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    return Container(
      // The link's own 44 px target supplies the rest of the breathing room.
      padding: const EdgeInsets.only(top: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: BB.hairline))),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Raising money for your team?', style: BB.bodyStyle(wide ? 17 : 15.5, height: 1.45)),
          TextLink('Host a Showcase', size: wide ? 17.5 : 16, onTap: () => context.go('/host')),
        ],
      ),
    );
  }
}

/// Desktop only: the links a website keeps at the bottom.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: BB.hairline))),
        child: Row(
          children: [
            TextLink('Privacy', size: 14, onTap: () => openSitePage('/privacy')),
            const SizedBox(width: 24),
            TextLink('Terms', size: 14, onTap: () => openSitePage('/terms')),
            const SizedBox(width: 24),
            TextLink('Support', size: 14, onTap: () => openSitePage('/support')),
            const Spacer(),
            const PoweredBy(),
            const SizedBox(width: 24),
            Text('© 2026 Battle Baseball', style: BB.bodyStyle(13.5, height: 1)),
          ],
        ),
      );
}
