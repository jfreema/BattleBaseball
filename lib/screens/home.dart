import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: PageBody(
            children: [
              const SizedBox(height: 8),
              const _Hero(),
              if (session.signedIn) const _MySpots(),
              const SectionLabel('Upcoming showcases'),
              StreamBuilder<List<BBEvent>>(
                stream: Repo.instance.publicEvents(),
                builder: (context, s) {
                  final w = streamState(s);
                  if (w != null) return w;
                  final upcoming = s.data!.where((e) => e.status != 'final').take(3).toList();
                  if (upcoming.isEmpty) {
                    return const EmptyNote(
                      'The first Battle Baseball Showcase is coming to Baton Rouge. '
                      'Dates and age groups post here first.',
                    );
                  }
                  return Column(children: [for (final e in upcoming) EventCard(event: e)]);
                },
              ),
              const SectionLabel('How a Showcase works'),
              const _Steps(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final signedIn = Session.instance.signedIn;
    return GumCard(
      edge: BB.coral,
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wordmark(width: 180),
          const SizedBox(height: 16),
          const Eyebrow('Player showcase · Baton Rouge'),
          Text('Show what you can do.', style: BB.title(30)),
          const SizedBox(height: 8),
          const Text(
            'Players sign up on their own and play with kids at their level. '
            'Every fastball is clocked, every stat is tracked, and the results '
            'post for families to share.',
            style: TextStyle(color: BB.cardMuted, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              CandyButton(label: 'Find a Showcase', onPressed: () => context.go('/events')),
              if (!signedIn)
                CandyButton.secondary(
                  label: 'Create account',
                  onPressed: () => context.go('/sign-up'),
                )
              else
                CandyButton.secondary(
                  label: 'Add a player',
                  onPressed: () => context.go('/players/new'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MySpots extends StatelessWidget {
  const _MySpots();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Registration>>(
        stream: Repo.instance.myRegistrations(),
        builder: (context, s) {
          final regs = (s.data ?? const <Registration>[])
              .where((r) => r.status != 'released' && r.status != 'cancelled')
              .toList();
          if (regs.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Your players'),
              for (final r in regs) RegistrationCard(r: r),
            ],
          );
        },
      );
}

/// A family's view of one registration, with gentle wording for holds.
class RegistrationCard extends StatelessWidget {
  const RegistrationCard({super.key, required this.r});
  final Registration r;

  @override
  Widget build(BuildContext context) {
    final (label, color) = registrationLabel(r);
    final first = r.playerName.split(' ').first;
    final String line;
    if (r.holdEnded && r.alreadyPaid) {
      line = "Thanks! We've flagged $first's payment and an admin will look for it first.";
    } else if (r.holdEnded) {
      line = "We couldn't match a payment to $first's spot yet. Already paid? "
          "Tap I already paid and we'll sort it out first thing.";
    } else if (r.isHeld) {
      line = "$first's spot is held ${holdUntil(r.holdEndsAt)} while we confirm your "
          'payment, usually within a few hours. Payment note: ${r.paymentCode}';
    } else if (r.status == 'waitlisted') {
      line = "$first is on the waitlist. We'll let you know as soon as a spot opens.";
    } else if (r.isConfirmed) {
      line = 'Payment received. $first is all set!';
    } else {
      line = '';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GumCard(
        edge: color,
        onTap: () => context.go('/events/${r.eventId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.playerName, style: BB.title(20))),
                StatusChip(label, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text('${r.eventName} · ${r.divisionName}',
                style: BB.labelStyle(15, color: BB.cardMuted, weight: FontWeight.w500)),
            if (line.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(line, style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
            if (r.holdEnded && !r.alreadyPaid) ...[
              const SizedBox(height: 12),
              CandyButton(
                small: true,
                label: 'I already paid',
                onPressed: () async {
                  await Repo.instance.flagAlreadyPaid(r);
                  if (context.mounted) toast(context, "Thanks! We'll look for it first.");
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();
  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Register', 'Add your player and pick an age group and skill level.', BB.coral),
      ('Reserve', 'Send your payment by Venmo or Cash App and tap Reserve.', BB.tangerine),
      ('Play', 'Players are placed on even teams and every fastball is clocked.', BB.grape),
      ('Share', 'Velocities, stats, and awards post for families to share.', BB.mint),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GumCard(
              edge: steps[i].$3,
              child: Row(
                children: [
                  Text('${i + 1}', style: BB.title(32, color: steps[i].$3)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: BB.labelStyle(18)),
                        Text(steps[i].$2, style: const TextStyle(color: BB.cardMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
