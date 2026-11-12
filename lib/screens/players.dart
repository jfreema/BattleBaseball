import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your players')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: BB.coral,
          foregroundColor: BB.ink,
          onPressed: () => context.go('/players/new'),
          icon: const Icon(Icons.add),
          label: Text('Add player', style: BB.labelStyle(16, color: BB.ink)),
        ),
        body: StreamBuilder<List<Player>>(
          stream: Repo.instance.myPlayers(),
          builder: (context, s) {
            final w = streamState(s);
            if (w != null) return w;
            return PageBody(children: [
              if (s.data!.isEmpty)
                const EmptyNote(
                  "Add each of your kids once. Their details carry over to every showcase, and "
                  'you decide what the public sees.',
                ),
              for (final (i, p) in s.data!.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GumCard(
                    edge: BB.candies[i % BB.candies.length],
                    onTap: () => context.go('/players/${p.id}'),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: BB.candies[i % BB.candies.length],
                        child: Text(p.firstName.isEmpty ? '?' : p.firstName[0],
                            style: BB.title(22, color: BB.ink)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: BB.title(20)),
                          Text(
                            [
                              if (p.gradYear != null) 'Class of ${p.gradYear}',
                              if (p.positions.isNotEmpty) p.positions.join(', '),
                              p.publicProfile ? 'Public profile' : 'Private',
                            ].join(' · '),
                            style: const TextStyle(color: BB.cardMuted),
                          ),
                        ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                ),
              const SizedBox(height: 70),
            ]);
          },
        ),
      );
}

class PlayerFormScreen extends StatefulWidget {
  const PlayerFormScreen({super.key, this.playerId});
  final String? playerId;
  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _grad = TextEditingController();
  final _velo = TextEditingController();
  final _state = TextEditingController(text: 'LA');
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
  List<String> _guardians = const [];

  @override
  void initState() {
    super.initState();
    if (widget.playerId == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repo = Repo.instance;
    final p = await repo.player(widget.playerId!).first;
    final priv = await repo.playerPrivate(widget.playerId!).first;
    if (p == null || !mounted) return;
    setState(() {
      _first.text = p.firstName;
      _last.text = p.lastName;
      _grad.text = p.gradYear?.toString() ?? '';
      _velo.text = p.reportedVelo?.toString() ?? '';
      _state.text = p.state;
      _bats = p.bats;
      _throws = p.throws;
      _level = p.level;
      _positions.addAll(p.positions);
      _public = p.publicProfile;
      _fullName = p.fullName;
      _guardians = p.guardianUids;
      _birth.text = priv?['birthDate'] as String? ?? '';
      _school.text = priv?['school'] as String? ?? '';
      _emName.text = priv?['emergencyName'] as String? ?? '';
      _emPhone.text = priv?['emergencyPhone'] as String? ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _grad, _velo, _state, _birth, _school, _emName, _emPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final uid = Session.instance.user!.uid;
    final p = Player(
      id: widget.playerId ?? '',
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      guardianUids: _guardians.isEmpty ? [uid] : _guardians,
      gradYear: int.tryParse(_grad.text.trim()),
      bats: _bats,
      throws: _throws,
      positions: positionsList.where(_positions.contains).toList(),
      state: _state.text.trim().toUpperCase(),
      level: _level,
      reportedVelo: double.tryParse(_velo.text.trim()),
      publicProfile: _public,
      fullName: _fullName,
    );
    try {
      final id = await Repo.instance.savePlayer(widget.playerId, p.toJson(), {
        'birthDate': _birth.text.trim(),
        'school': _school.text.trim(),
        'emergencyName': _emName.text.trim(),
        'emergencyPhone': _emPhone.text.trim(),
      });
      if (mounted) context.go('/players/$id');
    } catch (e) {
      if (mounted) toast(context, "Couldn't save: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choice(String label, List<String> options, String value, ValueChanged<String> onPick) =>
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: BB.labelStyle(15, color: BB.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options)
              ChoiceChip(label: Text(o), selected: value == o, onSelected: (_) => onPick(o)),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.playerId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit player' : 'Add a player')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: PageBody(children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(labelText: 'First name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grad,
                      decoration: const InputDecoration(labelText: 'High school grad year'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final y = int.tryParse((v ?? '').trim());
                        return y == null || y < 2025 || y > 2045 ? 'e.g. 2031' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _state,
                      decoration: const InputDecoration(labelText: 'State'),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                    ),
                  ),
                ]),
                _choice('Bats', const ['R', 'L', 'S'], _bats, (v) => setState(() => _bats = v)),
                _choice('Throws', const ['R', 'L'], _throws, (v) => setState(() => _throws = v)),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Positions', style: BB.labelStyle(15, color: BB.muted)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final pos in positionsList)
                        FilterChip(
                          label: Text(pos),
                          selected: _positions.contains(pos),
                          onSelected: (on) =>
                              setState(() => on ? _positions.add(pos) : _positions.remove(pos)),
                        ),
                    ]),
                  ]),
                ),
                const SectionLabel('Playing level'),
                const Text(
                  "Used to place your player with kids at their level. We'll even out the teams "
                  'by hand on the day.',
                  style: TextStyle(color: BB.muted),
                ),
                _choice('Current level', playingLevels, _level, (v) => setState(() => _level = v)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _velo,
                  decoration: const InputDecoration(
                    labelText: 'Fastball velocity, if you know it (MPH)',
                    helperText: 'Only used for placement. Never shown publicly.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SectionLabel('Public profile'),
                GumCard(
                  edge: BB.blue,
                  child: Column(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _public,
                      onChanged: (v) => setState(() => _public = v),
                      title: const Text('Show on leaderboards and results'),
                      subtitle: const Text(
                          'Shows grad year, positions, state, velocities, and awards. '
                          'Birth date, school, and contacts are never public.'),
                    ),
                    if (_public)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _fullName,
                        onChanged: (v) => setState(() => _fullName = v),
                        title: const Text('Show full last name'),
                        subtitle: Text(_fullName
                            ? 'Shown as ${_first.text} ${_last.text}'
                            : 'Shown as ${_first.text} ${_last.text.isEmpty ? '' : '${_last.text[0]}.'}'),
                      ),
                  ]),
                ),
                const SectionLabel('Private details'),
                const Text('Only you and staff at your player\'s event can see these.',
                    style: TextStyle(color: BB.muted)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birth,
                  decoration: const InputDecoration(labelText: 'Birth date (MM/DD/YYYY)'),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 14),
                TextFormField(controller: _school, decoration: const InputDecoration(labelText: 'School')),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emName,
                  decoration: const InputDecoration(labelText: 'Emergency contact name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emPhone,
                  decoration: const InputDecoration(labelText: 'Emergency contact phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                CandyButton(
                  expand: true,
                  busy: _busy,
                  label: editing ? 'Save' : 'Add player',
                  onPressed: _save,
                ),
              ]),
            ),
    );
  }
}

class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({super.key, required this.playerId});
  final String playerId;
  @override
  Widget build(BuildContext context) {
    final repo = Repo.instance;
    return StreamBuilder<Player?>(
      stream: repo.player(playerId),
      builder: (context, s) {
        final p = s.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(p?.name ?? 'Player'),
            actions: [
              if (p != null)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go('/players/$playerId/edit'),
                ),
            ],
          ),
          body: p == null
              ? streamState(s) ?? const Center(child: Text('Player not found.'))
              : PageBody(children: [
                  _PlayerCard(p: p),
                  const SectionLabel('Awards'),
                  StreamBuilder<List<Award>>(
                    stream: repo.playerAwards(playerId),
                    builder: (context, as) {
                      final list = as.data ?? const <Award>[];
                      if (list.isEmpty) return const EmptyNote('Awards from showcases show up here.');
                      return Wrap(spacing: 8, runSpacing: 10, children: [
                        for (final a in list) AwardBadge(a),
                      ]);
                    },
                  ),
                  const SectionLabel('Velocity history'),
                  StreamBuilder<List<Measurement>>(
                    stream: repo.playerMeasurements(playerId),
                    builder: (context, ms) {
                      final list = ms.data ?? const <Measurement>[];
                      if (list.isEmpty) {
                        return const EmptyNote(
                            'Every reading taken by staff at a showcase is kept here.');
                      }
                      return Column(children: [
                        for (final m in list.reversed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GumCard(
                              edge: BB.lemon,
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    '${measurementTypes[m.type]?.label ?? m.type}\n${m.eventName} · ${fmtDate(m.recordedAt)}',
                                    style: BB.labelStyle(15),
                                  ),
                                ),
                                Readout(value: fmtValue(m.value, m.type), unit: m.unit, size: 28),
                              ]),
                            ),
                          ),
                      ]);
                    },
                  ),
                ]),
        );
      },
    );
  }
}

/// The player card: name, grad year, positions, and the top fastball.
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.p});
  final Player p;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Measurement>>(
        stream: Repo.instance.playerMeasurements(p.id),
        builder: (context, s) {
          final fast = (s.data ?? const <Measurement>[]).where((m) => m.type == 'fastball').toList();
          fast.sort((a, b) => b.value.compareTo(a.value));
          final top = fast.firstOrNull;
          return GumCard(
            edge: BB.coral,
            padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow([
                if (p.gradYear != null) 'Class of ${p.gradYear}',
                if (p.positions.isNotEmpty) p.positions.join(' · '),
              ].join(' · ')),
              Text(p.publicProfile ? p.publicName : p.name, style: BB.title(30)),
              const SizedBox(height: 4),
              Text('Bats ${p.bats} · Throws ${p.throws} · ${p.state}',
                  style: const TextStyle(color: BB.cardMuted)),
              const SizedBox(height: 14),
              if (top != null) ...[
                Readout(value: fmtValue(top.value, 'fastball'), unit: 'MPH', size: 52),
                Text('Top fastball · ${top.eventName}', style: const TextStyle(color: BB.cardMuted)),
              ] else
                const Text('Top fastball shows here after a showcase.',
                    style: TextStyle(color: BB.cardMuted)),
              const SizedBox(height: 10),
              StatusChip(p.publicProfile ? 'Public profile' : 'Private profile',
                  color: p.publicProfile ? BB.mint : BB.rim, fg: p.publicProfile ? BB.ink : BB.text),
            ]),
          );
        },
      );
}
