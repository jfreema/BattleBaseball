import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

const site = 'https://showcase.getbattleplan.app';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    void open(String url) => launchUrl(Uri.parse(url));
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: PageBody(children: [
          if (s.signedIn)
            GumCard(
              edge: BB.blue,
              child: Row(children: [
                const Icon(Icons.account_circle, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.displayName, style: BB.labelStyle(18)),
                    Text(
                      [
                        s.user?.email ?? '',
                        if (s.isOwner) 'Owner' else if (s.isAdmin) 'Battle Baseball admin',
                      ].where((x) => x.isNotEmpty).join(' · '),
                      style: const TextStyle(color: BB.cardMuted),
                    ),
                  ]),
                ),
              ]),
            )
          else
            GumCard(
              edge: BB.coral,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sign in to register players', style: BB.title(20)),
                const SizedBox(height: 12),
                CandyButton(label: 'Sign in', onPressed: () => context.go('/sign-in')),
              ]),
            ),
          if (s.hasStaffTools) ...[
            const SectionLabel('Run events'),
            _Row(Icons.admin_panel_settings, 'Admin tools', () => context.go('/admin')),
          ],
          const SectionLabel('Shop'),
          GumCard(
            edge: BB.grape,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Coming soon', color: BB.lemon),
              Text('The Battle Paddle', style: BB.title(22)),
              const SizedBox(height: 4),
              const Text('A new training tool from Battle Baseball. Details soon.',
                  style: TextStyle(color: BB.cardMuted)),
            ]),
          ),
          const SizedBox(height: 10),
          GumCard(
            edge: BB.mint,
            onTap: () => open('https://getbattleplan.app'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Free for every team', color: BB.going),
              Text('Battleplan', style: BB.title(22)),
              const SizedBox(height: 4),
              const Text('Team chat, schedules, RSVPs, and dues, made by the people behind '
                  'Battle Baseball. Free, no ads.',
                  style: TextStyle(color: BB.cardMuted)),
            ]),
          ),
          const SectionLabel('Battle Baseball'),
          _Row(Icons.volunteer_activism, 'Host a showcase for your team', () => open('$site/host')),
          _Row(Icons.help_outline, 'How it works', () => open('$site/how-it-works')),
          _Row(Icons.support_agent, 'Support', () => open('$site/support')),
          _Row(Icons.privacy_tip_outlined, 'Privacy Policy', () => open('$site/privacy')),
          _Row(Icons.description_outlined, 'Terms', () => open('$site/terms')),
          if (s.signedIn) ...[
            _Row(Icons.delete_outline, 'Delete your account', () => open('$site/delete-account')),
            const SizedBox(height: 20),
            CandyButton.secondary(
              label: 'Sign out',
              icon: Icons.logout,
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/');
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GumCard(
          edge: null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: onTap,
          child: Row(children: [
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: BB.labelStyle(16))),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
}
