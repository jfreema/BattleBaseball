// Players: the directory of public cards, a player's profile (the card,
// opened up), and the form a parent fills in once for each kid.
import 'dart:async';
import 'dart:math' as math;

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/sample.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

double? _topFastball(Iterable<Measurement> readings) {
  double? top;
  for (final m in readings) {
    if (m.type == 'fastball' && (top == null || m.value > top)) top = m.value;
  }
  return top;
}

/// What a card's window carries before the first reading.
String _rookieMark(PublicProfile p) => p.jersey?.toString() ?? p.initials;

String? _signedInUid() {
  final s = Session.instance;
  return s.signedIn ? s.uid : null;
}

// ---------- Players ----------

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  late final Stream<List<PublicProfile>> _all = Repo.instance.allPublicProfiles();
  late final Stream<List<Measurement>> _board = Repo.instance.leaderboard('fastball');
  Stream<List<Player>>? _mine;
  String? _uid;

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
    _bind();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  void _bind() {
    _uid = _signedInUid();
    _mine = _uid == null ? null : Repo.instance.myPlayers();
  }

  void _onSession() {
    if (mounted && _signedInUid() != _uid) setState(_bind);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Player>>(
        stream: _mine,
        builder: (context, mine) => StreamBuilder<List<PublicProfile>>(
          stream: _all,
          builder: (context, all) => StreamBuilder<List<Measurement>>(
            stream: _board,
            builder: (context, board) => _PlayersView(
              loading: !(all.hasData || all.hasError) ||
                  (_mine != null && !(mine.hasData || mine.hasError)),
              mine: _mine == null ? null : (mine.data ?? const []),
              // A directory that can't be read yet is an empty directory.
              profiles: all.data ?? const [],
              tops: {for (final m in board.data ?? const <Measurement>[]) m.playerId: m.value},
            ),
          ),
        ),
      );
}

class _PlayersView extends StatefulWidget {
  const _PlayersView({
    required this.loading,
    required this.mine,
    required this.profiles,
    required this.tops,
  });

  final bool loading;

  /// The signed-in family's players; null when nobody is signed in.
  final List<Player>? mine;
  final List<PublicProfile> profiles;

  /// The best published fastball, by player id.
  final Map<String, double> tops;

  @override
  State<_PlayersView> createState() => _PlayersViewState();
}

class _PlayersViewState extends State<_PlayersView> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _searchField() => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search players',
              prefixIcon: SizedBox(
                width: 48,
                height: 48,
                child: Center(child: BBIcon(BBGlyph.search, size: 20, color: BB.creamSoft)),
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : Pressable(
                      onTap: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      label: 'Clear search',
                      builder: (context, down, focused) => SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: BBIcon(BBGlyph.close, size: 18, color: BB.creamSoft)),
                      ),
                    ),
            ),
          ),
        ),
      );

  Widget _tile(PublicProfile p) {
    final top = widget.tops[p.id];
    // No window until there is a reading to put in it.
    return MiniCard(
      name: p.name,
      sub: playerLine(p),
      value: top == null ? null : fmtValue(top, 'fastball'),
      unit: top == null ? null : 'MPH',
      onTap: () => context.go('/players/${p.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 3 : width >= 720 ? 2 : 1;
    final mine = widget.mine;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.profiles
        : widget.profiles.where((p) => p.name.toLowerCase().contains(q)).toList();
    return PageFrame(
      children: [
        const TabHeader(),
        const PageTitle('Players'),
        if (widget.loading)
          const LoadingField()
        else ...[
          if (mine != null) ...[
            if (mine.isNotEmpty) ...[
              const SectionTitle('Your players'),
              _Grid(columns: columns, children: [for (final p in mine) _OwnTile(player: p)]),
              const SizedBox(height: 16),
            ],
            BBButton.paper(
              'Add player',
              icon: const BBIcon(BBGlyph.plus),
              onPressed: () => context.go('/players/new'),
            ),
            const SizedBox(height: 36),
          ],
          if (widget.profiles.isEmpty)
            const _SampleCard()
          else ...[
            if (mine != null) const SectionTitle('All players'),
            _searchField(),
            const SizedBox(height: 16),
            _Grid(columns: columns, children: [for (final p in shown) _tile(p)]),
          ],
        ],
      ],
    );
  }
}

/// Tiles in equal columns. The page scrolls, so rows are laid out by hand.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final n = math.max(columns, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += n) ...[
          if (i > 0) const SizedBox(height: 10),
          if (n == 1)
            children[i]
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < n; j++) ...[
                  if (j > 0) const SizedBox(width: 16),
                  Expanded(
                    child: i + j < children.length ? children[i + j] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }
}

/// One of the family's own players. It reads its own results, so a player
/// whose card is private still shows a top fastball here.
class _OwnTile extends StatefulWidget {
  const _OwnTile({required this.player});

  final Player player;

  @override
  State<_OwnTile> createState() => _OwnTileState();
}

class _OwnTileState extends State<_OwnTile> {
  late Stream<List<Measurement>> _readings = Repo.instance.playerMeasurements(widget.player.id);

  @override
  void didUpdateWidget(_OwnTile old) {
    super.didUpdateWidget(old);
    if (old.player.id != widget.player.id) {
      _readings = Repo.instance.playerMeasurements(widget.player.id);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Measurement>>(
        stream: _readings,
        builder: (context, s) {
          final p = widget.player;
          final card = p.toPublic();
          final top = _topFastball(s.data ?? const []);
          return MiniCard(
            name: p.name,
            sub: playerLine(card),
            value: top == null ? _rookieMark(card) : fmtValue(top, 'fastball'),
            unit: top == null ? null : 'MPH',
            onTap: () => context.go('/players/${p.id}'),
          );
        },
      );
}

/// What the directory shows before anyone has a public card.
class _SampleCard extends StatelessWidget {
  const _SampleCard();

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    return Align(
      alignment: wide ? Alignment.centerLeft : Alignment.center,
      child: Padding(
        // Room for the tilted corners.
        padding: EdgeInsets.only(left: wide ? 12 : 0, top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerCard(
              profile: Sample.profile,
              topFastball: Sample.topFastball,
              awards: Sample.awards(),
              width: 280,
              rotation: -3,
              sample: true,
              onTap: () => context.go('/players/${Sample.id}'),
            ),
            const SizedBox(height: 22),
            const Stamp('SAMPLE'),
          ],
        ),
      ),
    );
  }
}

// ---------- Profile ----------

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key, required this.playerId});

  final String playerId;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

/// Finds the card a viewer may see. Anyone gets the public profile. Someone
/// signed in also asks for the player record, which only answers for the
/// player's guardian or an admin; nothing from it is shown but its public
/// side.
class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  StreamSubscription<PublicProfile?>? _profileSub;
  StreamSubscription<Player?>? _playerSub;
  final _resultSubs = <StreamSubscription<Object?>>[];

  PublicProfile? _profile;
  Player? _player;
  bool _profileKnown = false;
  bool _playerKnown = false;
  String? _uid;
  bool _ensured = false;

  List<Measurement>? _readings;
  List<Award>? _awards;
  List<StatLine>? _lines;

  bool get _isSample => widget.playerId == Sample.id;

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
    _start();
  }

  @override
  void didUpdateWidget(PlayerProfileScreen old) {
    super.didUpdateWidget(old);
    if (old.playerId == widget.playerId) return;
    _stop();
    _profile = null;
    _player = null;
    _profileKnown = false;
    _playerKnown = false;
    _ensured = false;
    _readings = null;
    _awards = null;
    _lines = null;
    _start();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    _stop();
    super.dispose();
  }

  void _start() {
    if (_isSample) return;
    _profileSub = Repo.instance
        .publicProfile(widget.playerId)
        .listen(_onProfile, onError: (Object _) => _onProfile(null));
    _bindPlayer();
  }

  void _stop() {
    _profileSub?.cancel();
    _playerSub?.cancel();
    _profileSub = null;
    _playerSub = null;
    for (final s in _resultSubs) {
      s.cancel();
    }
    _resultSubs.clear();
  }

  void _bindPlayer() {
    _uid = _signedInUid();
    _playerSub?.cancel();
    _playerSub = null;
    _player = null;
    _playerKnown = _uid == null;
    if (_uid == null) return;
    // A refusal means this isn't the viewer's player.
    _playerSub = Repo.instance
        .player(widget.playerId)
        .listen(_onPlayer, onError: (Object _) => _onPlayer(null));
  }

  void _onSession() {
    if (!mounted || _isSample) return;
    // Rebuild either way: the session may only now be ready.
    setState(() {
      if (_signedInUid() != _uid) _bindPlayer();
    });
  }

  void _onProfile(PublicProfile? p) {
    if (!mounted) return;
    setState(() {
      _profile = p;
      _profileKnown = true;
    });
    _watchResults();
  }

  void _onPlayer(Player? p) {
    if (!mounted) return;
    setState(() {
      _player = p;
      _playerKnown = true;
    });
    if (p != null && _owns(p) && !_ensured) {
      _ensured = true;
      unawaited(Repo.instance.ensurePublicProfile(p));
    }
    _watchResults();
  }

  bool _owns(Player p) => _uid != null && p.guardianUids.contains(_uid);

  PublicProfile? get _card {
    final p = _player;
    if (p != null && _owns(p)) return p.toPublic();
    return _profile ?? p?.toPublic();
  }

  /// Results are only asked for once there is a card to put them on.
  void _watchResults() {
    if (_resultSubs.isNotEmpty || _card == null) return;
    final repo = Repo.instance;
    final id = widget.playerId;
    void set(VoidCallback change) {
      if (mounted) setState(change);
    }

    _resultSubs.addAll([
      repo.playerMeasurements(id).listen(
            (v) => set(() => _readings = v),
            onError: (Object _) => set(() => _readings ??= const []),
          ),
      repo.playerAwards(id).listen(
            (v) => set(() => _awards = v),
            onError: (Object _) => set(() => _awards ??= const []),
          ),
      repo.playerStatLines(id).listen(
            (v) => set(() => _lines = v),
            onError: (Object _) => set(() => _lines ??= const []),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSample) {
      return _ProfileView(
        profile: Sample.profile,
        readings: Sample.measurements(),
        awards: Sample.awards(),
        statLines: Sample.statLines(),
        sample: true,
      );
    }
    final card = _card;
    if (card == null) {
      final settled = _profileKnown && _playerKnown && Session.instance.ready;
      return settled ? const NotFoundScreen() : const _ProfileLoading();
    }
    final readings = _readings, awards = _awards, lines = _lines;
    if (readings == null || awards == null || lines == null) return const _ProfileLoading();
    final p = _player;
    return _ProfileView(
      profile: card,
      readings: readings,
      awards: awards,
      statLines: lines,
      own: p != null && _owns(p),
      private: p != null && !p.publicProfile,
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) =>
      const PageFrame(children: [BackHeader('Players'), LoadingField()]);
}

/// A player's results, worked into what the card prints.
class _Results {
  const _Results._({
    required this.topFastball,
    required this.chart,
    required this.ticks,
    required this.pop,
    required this.dash,
    required this.total,
    required this.awards,
    required this.showcases,
  });

  factory _Results(List<Measurement> readings, List<Award> awards, List<StatLine> lines) {
    final byShowcase = <String, ({double value, DateTime at, String tick, int order})>{};
    double? pop, dash;
    for (final (i, m) in readings.indexed) {
      switch (m.type) {
        case 'fastball':
          final key = m.eventId.isEmpty ? m.id : m.eventId;
          final at = m.recordedAt ?? DateTime(2000);
          final seen = byShowcase[key];
          byShowcase[key] = seen == null
              ? (value: m.value, at: at, tick: tickLabel(m.eventName, m.divisionName), order: i)
              : (
                  value: math.max(seen.value, m.value),
                  at: at.isBefore(seen.at) ? at : seen.at,
                  tick: seen.tick,
                  order: seen.order,
                );
        case 'popTime':
          pop = pop == null ? m.value : math.min(pop, m.value);
        case 'dash40':
          dash = dash == null ? m.value : math.min(dash, m.value);
      }
    }
    final shows = byShowcase.values.toList()
      ..sort((a, b) {
        final c = a.at.compareTo(b.at);
        return c != 0 ? c : a.order.compareTo(b.order);
      });
    final honors = awardTypes.keys.toList();
    int rank(Award a) {
      final i = honors.indexOf(a.type);
      return i < 0 ? honors.length : i;
    }

    final chart = [for (final s in shows) s.value];
    return _Results._(
      topFastball: chart.isEmpty ? null : chart.reduce(math.max),
      chart: chart,
      ticks: [for (final s in shows) s.tick],
      pop: pop,
      dash: dash,
      total: StatLine.total(lines),
      awards: [...awards]..sort((a, b) => rank(a).compareTo(rank(b))),
      showcases: {
        for (final m in readings) m.eventId,
        for (final a in awards) a.eventId,
        for (final l in lines) l.eventId,
      }.where((id) => id.isNotEmpty).length,
    );
  }

  final double? topFastball;

  /// Each showcase's best fastball, oldest first, and its tick label.
  final List<double> chart;
  final List<String> ticks;
  final double? pop;
  final double? dash;
  final StatLine total;

  /// MVP first.
  final List<Award> awards;
  final int showcases;

  bool get hasSkills => pop != null || dash != null;

  /// A rookie: nothing to print on the back yet.
  bool get isEmpty =>
      chart.isEmpty && !hasSkills && !total.hasBatting && !total.hasPitching && awards.isEmpty;
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.profile,
    required this.readings,
    required this.awards,
    required this.statLines,
    this.sample = false,
    this.own = false,
    this.private = false,
  });

  final PublicProfile profile;
  final List<Measurement> readings;
  final List<Award> awards;
  final List<StatLine> statLines;

  /// The built-in example at /players/sample.
  final bool sample;

  /// The viewer is this player's guardian.
  final bool own;

  /// The card isn't public; only the guardian and admins get this far.
  final bool private;

  Future<void> _share(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: '${BB.site}/players/${profile.id}'));
    } catch (_) {
      return;
    }
    if (context.mounted) toast(context, 'Link copied');
  }

  Widget _actions(BuildContext context, {required bool wide}) {
    final edit = own
        ? BBButton.quiet('Edit', onPressed: () => context.go('/players/${profile.id}/edit'))
        : null;
    if (private) {
      return Row(
        mainAxisAlignment: wide ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        children: [
          const Pill('Private'),
          if (edit != null) ...[const SizedBox(width: 16), edit],
        ],
      );
    }
    final share = BBButton.primary('Share card', expand: !wide, onPressed: () => _share(context));
    if (wide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          share,
          if (edit != null) ...[const SizedBox(width: 16), edit],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: share),
        if (edit != null) ...[const SizedBox(width: 10), edit],
      ],
    );
  }

  static Widget _section(String caption, Widget child, {String? tag}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [BackCaption(caption, tag: tag), child],
      );

  /// The back of the card. On desktop with room it is set as a landscape
  /// panel ([grid]); otherwise the sections stack.
  Widget _back(_Results r, {required bool large, required bool grid}) {
    final fastball = r.chart.isEmpty
        ? null
        : _section(
            'Fastball',
            VeloChart(values: r.chart, labels: r.ticks),
            tag: VeloChart.gain(r.chart),
          );
    Widget? skills({required bool vertical}) => r.hasSkills
        ? _section(
            'Skills',
            RuledTable(
              headers: [if (r.pop != null) 'Pop time', if (r.dash != null) '40 yard'],
              values: [
                if (r.pop != null) fmtValue(r.pop!, 'popTime'),
                if (r.dash != null) fmtValue(r.dash!, 'dash40'),
              ],
              units: [if (r.pop != null) 'sec', if (r.dash != null) 'sec'],
              vertical: vertical,
            ),
          )
        : null;
    final t = r.total;
    final batting = t.hasBatting
        ? _section(
            'Batting',
            RuledTable(
              headers: const ['AB', 'H', 'HR', 'RBI', 'R', 'BB', 'AVG'],
              values: ['${t.ab}', '${t.h}', '${t.hr}', '${t.rbi}', '${t.r}', '${t.bb}', t.avg],
              highlightLast: true,
            ),
          )
        : null;
    final pitching = t.hasPitching
        ? _section(
            'Pitching',
            RuledTable(headers: const ['IP', 'K', 'BB'], values: [t.ip, '${t.k}', '${t.pbb}']),
          )
        : null;
    final honors = r.awards.isEmpty
        ? null
        : _section(
            'Awards',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, a) in r.awards.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : large ? 14 : 12),
                    child: AwardLine(
                      title: a.label,
                      sub: '${a.eventName} ${a.divisionName}'.trim(),
                      mark: awardMark(a.type),
                      tilt: i.isEven ? -8 : 7,
                    ),
                  ),
              ],
            ),
          );
    final foot = BackFoot(
      note: r.showcases == 0
          ? null
          : r.showcases == 1
              ? '1 SHOWCASE'
              : '${r.showcases} SHOWCASES',
    );
    if (!grid) {
      final stackedSkills = skills(vertical: false);
      return CardBack(
        large: large,
        children: [?fastball, ?stackedSkills, ?batting, ?pitching, ?honors, foot],
      );
    }
    final sideSkills = fastball == null ? null : skills(vertical: true);
    final wideSkills = fastball == null ? skills(vertical: false) : null;
    return CardBack(
      large: true,
      gap: 24,
      children: [
        if (fastball != null && sideSkills != null)
          _Split(left: fastball, right: sideSkills, leftSpan: 2)
        else
          ?fastball,
        ?wideSkills,
        ?batting,
        if (pitching != null && honors != null)
          _Split(left: pitching, right: honors, leftSpan: 1)
        else ...[?pitching, ?honors],
        foot,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final r = _Results(readings, awards, statLines);
    final header = BackHeader('Players', beside: sample ? const Stamp('SAMPLE') : null);
    Widget front(double width) => PlayerCard(
          profile: profile,
          topFastball: r.topFastball,
          awards: r.awards,
          width: width,
          rotation: wide ? -2.5 : -1.6,
          sample: sample,
        );

    if (wide) {
      return PageFrame(
        children: [
          header,
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 430,
                  child: Column(
                    children: [
                      front(400),
                      const SizedBox(height: 40),
                      _actions(context, wide: true),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
                Expanded(
                  child: r.isEmpty
                      ? const SizedBox.shrink()
                      : LayoutBuilder(
                          // Three columns need the room; a narrow window stacks.
                          builder: (context, box) =>
                              _back(r, large: true, grid: box.maxWidth >= 520),
                        ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final cardWidth = math.min(354.0, MediaQuery.sizeOf(context).width - 36);
    return PageFrame(
      children: [
        header,
        const SizedBox(height: 4),
        Center(child: front(cardWidth)),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(width: cardWidth, child: _actions(context, wide: false)),
        ),
        if (!r.isEmpty) ...[
          const SizedBox(height: 26),
          _back(r, large: false, grid: false),
        ],
      ],
    );
  }
}

/// Two sections side by side on the desktop back's three-column grid.
class _Split extends StatelessWidget {
  const _Split({required this.left, required this.right, required this.leftSpan});

  final Widget left;
  final Widget right;

  /// How many of the three columns [left] takes.
  final int leftSpan;

  static const _gap = 22.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final column = (box.maxWidth - 2 * _gap) / 3;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: leftSpan * column + (leftSpan - 1) * _gap, child: left),
              const SizedBox(width: _gap),
              Expanded(child: right),
            ],
          );
        },
      );
}

// ---------- Add or edit a player ----------

class PlayerFormScreen extends StatefulWidget {
  const PlayerFormScreen({super.key, this.playerId});

  final String? playerId;

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _grad = TextEditingController();
  final _state = TextEditingController(text: 'LA');
  final _jersey = TextEditingController();
  final _velo = TextEditingController();
  final _birth = TextEditingController();
  final _school = TextEditingController();
  final _emName = TextEditingController();
  final _emPhone = TextEditingController();
  String _bats = 'R';
  String _throws = 'R';
  String _level = 'Travel';
  final Set<String> _positions = {};
  bool _public = false;
  bool _fullName = false;
  bool _busy = false;
  bool _loaded = false;
  bool _missing = false;
  List<String> _guardians = const [];
  String _savedName = '';

  // What the player's real card carries, so the preview matches it.
  double? _top;
  List<Award> _awards = const [];

  List<TextEditingController> get _controllers =>
      [_first, _last, _grad, _state, _jersey, _velo, _birth, _school, _emName, _emPhone];

  @override
  void initState() {
    super.initState();
    // These print on the card, so the preview follows them.
    for (final c in [_first, _last, _grad, _state, _jersey]) {
      c.addListener(_refresh);
    }
    if (widget.playerId == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final repo = Repo.instance;
    final id = widget.playerId!;
    Player? p;
    Json? priv;
    try {
      p = await repo.player(id).first;
      if (p != null) priv = await repo.playerPrivate(id).first;
    } catch (_) {
      // Not this person's player.
      p = null;
    }
    if (!mounted) return;
    if (p == null) {
      setState(() => _missing = true);
      return;
    }
    _first.text = p.firstName;
    _last.text = p.lastName;
    _grad.text = p.gradYear?.toString() ?? '';
    _state.text = p.state;
    _jersey.text = p.jersey?.toString() ?? '';
    _velo.text = p.reportedVelo?.toString() ?? '';
    _birth.text = priv?['birthDate'] as String? ?? '';
    _school.text = priv?['school'] as String? ?? '';
    _emName.text = priv?['emergencyName'] as String? ?? '';
    _emPhone.text = priv?['emergencyPhone'] as String? ?? '';
    final player = p;
    setState(() {
      _bats = player.bats;
      _throws = player.throws;
      _level = player.level;
      _positions.addAll(player.positions);
      _public = player.publicProfile;
      _fullName = player.fullName;
      _guardians = player.guardianUids;
      _savedName = player.name;
      _loaded = true;
    });
    unawaited(_loadCard(id));
  }

  Future<void> _loadCard(String id) async {
    try {
      final top = _topFastball(await Repo.instance.playerMeasurements(id).first);
      final awards = await Repo.instance.playerAwards(id).first;
      if (mounted) {
        setState(() {
          _top = top;
          _awards = awards;
        });
      }
    } catch (_) {
      // The preview goes without them.
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Player _draft([String? uid]) => Player(
        id: widget.playerId ?? '',
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        guardianUids: _guardians.isEmpty ? [?uid] : _guardians,
        gradYear: int.tryParse(_grad.text.trim()),
        bats: _bats,
        throws: _throws,
        positions: positionsList.where(_positions.contains).toList(),
        state: _state.text.trim().toUpperCase(),
        level: _level,
        reportedVelo: double.tryParse(_velo.text.trim()),
        publicProfile: _public,
        fullName: _fullName,
        jersey: int.tryParse(_jersey.text.trim()),
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      // The fields that can be wrong are at the top.
      if (_scroll.hasClients) {
        unawaited(_scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ));
      }
      return;
    }
    final uid = Session.instance.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final id = await Repo.instance.savePlayer(widget.playerId, _draft(uid).toJson(), {
        'birthDate': _birth.text.trim(),
        'school': _school.text.trim(),
        'emergencyName': _emName.text.trim(),
        'emergencyPhone': _emPhone.text.trim(),
      });
      if (mounted) context.go('/players/$id');
    } catch (_) {
      if (mounted) toast(context, "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  static String? _gradYear(String? v) {
    final y = int.tryParse((v ?? '').trim());
    return y == null || y < 2025 || y > 2045 ? 'e.g. 2031' : null;
  }

  static final _digits = FilteringTextInputFormatter.digitsOnly;

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? hint,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        inputFormatters: formatters,
      );

  /// A labelled run of chips.
  Widget _group(String label, List<Widget> chips, {bool wrap = true}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BB.labelStyle(15.5, color: BB.creamSoft, weight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (wrap)
            Wrap(spacing: 8, runSpacing: 4, children: chips)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, c) in chips.indexed) ...[if (i > 0) const SizedBox(width: 8), c],
              ],
            ),
        ],
      );

  List<Widget> _choices(List<String> options, String value, ValueChanged<String> onPick) => [
        for (final o in options) BBChip(o, selected: value == o, onTap: () => onPick(o)),
      ];

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    if (_missing) return const NotFoundScreen();
    final editing = widget.playerId != null;
    final back = BackHeader(editing ? 'Card' : 'Players');
    if (!_loaded) {
      return PageFrame(column: 560, children: [back, const LoadingField()]);
    }
    const gap = SizedBox(height: 14);
    const across = SizedBox(width: 12);

    final gradYear = _field(
      _grad,
      'Grad year',
      validator: _gradYear,
      keyboard: TextInputType.number,
      formatters: [_digits, LengthLimitingTextInputFormatter(4)],
    );
    final state = SizedBox(
      width: 92,
      child: _field(
        _state,
        'State',
        capitalization: TextCapitalization.characters,
        formatters: [LengthLimitingTextInputFormatter(2)],
      ),
    );
    final jersey = _field(
      _jersey,
      'Jersey number (optional)',
      keyboard: TextInputType.number,
      formatters: [_digits, LengthLimitingTextInputFormatter(2)],
    );

    final preview = PlayerCard(
      profile: _draft().toPublic(),
      topFastball: _top,
      awards: _awards,
      width: 240,
    );
    final switches = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _switch('Public card', _public, (v) => setState(() => _public = v)),
        if (_public)
          _switch('Show full last name', _fullName, (v) => setState(() => _fullName = v)),
      ],
    );

    return Form(
      key: _form,
      child: PageFrame(
        column: 560,
        controller: _scroll,
        children: [
          back,
          PageTitle(editing ? _savedName : 'Add a player'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  _first,
                  'First name',
                  validator: _required,
                  capitalization: TextCapitalization.words,
                ),
              ),
              across,
              Expanded(
                child: _field(
                  _last,
                  'Last name',
                  validator: _required,
                  capitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          gap,
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 460
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: gradYear),
                      across,
                      state,
                      across,
                      Expanded(flex: 7, child: jersey),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: gradYear), across, state],
                      ),
                      gap,
                      jersey,
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _group(
                'Bats',
                _choices(const ['R', 'L', 'S'], _bats, (v) => setState(() => _bats = v)),
                wrap: false,
              ),
              _group(
                'Throws',
                _choices(const ['R', 'L'], _throws, (v) => setState(() => _throws = v)),
                wrap: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _group('Positions', [
            for (final pos in positionsList)
              BBChip(
                pos,
                selected: _positions.contains(pos),
                onTap: () => setState(
                  () => _positions.contains(pos) ? _positions.remove(pos) : _positions.add(pos),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          _group('Level', _choices(playingLevels, _level, (v) => setState(() => _level = v))),
          const SizedBox(height: 16),
          _field(
            _velo,
            'Fastball (MPH, optional)',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Card'),
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 500
                ? Row(
                    children: [
                      preview,
                      const SizedBox(width: 28),
                      Expanded(child: switches),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: preview),
                      const SizedBox(height: 12),
                      switches,
                    ],
                  ),
          ),
          const SizedBox(height: 32),
          SectionTitle('Private', trailing: Text('STAFF ONLY', style: BB.caps(12))),
          _field(_birth, 'Birth date', keyboard: TextInputType.datetime, hint: 'MM/DD/YYYY'),
          gap,
          _field(_school, 'School', capitalization: TextCapitalization.words),
          gap,
          _field(_emName, 'Emergency contact', capitalization: TextCapitalization.words),
          gap,
          _field(_emPhone, 'Emergency phone', keyboard: TextInputType.phone),
          const SizedBox(height: 28),
          BBButton.primary('Save', expand: true, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
