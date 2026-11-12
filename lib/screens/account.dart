// Account: who is signed in, the few places only they go, and the links to
// the static pages.
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => _AccountView(
        signedIn: s.signedIn,
        name: s.displayName,
        email: s.email,
        role: s.isOwner
            ? 'Owner'
            : s.isAdmin
                ? 'Admin'
                : null,
        staff: s.hasStaffTools,
        onSignOut: () => _signOut(context),
      ),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView({
    required this.signedIn,
    required this.name,
    required this.email,
    required this.role,
    required this.staff,
    required this.onSignOut,
  });

  final bool signedIn;
  final String name;
  final String email;

  /// "Owner" or "Admin", when it applies.
  final String? role;
  final bool staff;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    return PageFrame(
      column: 560,
      children: [
        const TabHeader(),
        if (signedIn) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(
              header: true,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BB.title(wide ? 44 : 34, drop: 4),
              ),
            ),
          ),
          // An account with no name saved shows its email as the name.
          if (email.isNotEmpty && email != name)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BB.bodyStyle(16, height: 1.2),
              ),
            ),
          if (role != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Pill(role!, color: BB.lemon),
            ),
          const SizedBox(height: 24),
        ] else ...[
          const SizedBox(height: 8),
          if (wide)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                BBButton.primary('Sign in', onPressed: () => context.go('/sign-in')),
                BBButton.paper('Create an account', onPressed: () => context.go('/sign-up')),
              ],
            )
          else ...[
            BBButton.primary('Sign in', expand: true, onPressed: () => context.go('/sign-in')),
            const SizedBox(height: 12),
            BBButton.paper('Create an account', expand: true, onPressed: () => context.go('/sign-up')),
          ],
          const SizedBox(height: 28),
        ],
        if (signedIn) _Row('Your players', onTap: () => context.go('/players')),
        if (staff) _Row('Staff tools', onTap: () => context.go('/admin')),
        _Row('Host a Showcase', onTap: () => context.go('/host')),
        _Row(
          'Battleplan',
          sub: 'Free team chat and schedules',
          trailing: const BBIcon(BBGlyph.external, size: 20, color: BB.ink),
          onTap: () => launchUrl(Uri.parse('https://getbattleplan.app')),
        ),
        const _Row('Battle Paddle', trailing: Pill('Coming soon')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 22,
          children: [
            for (final (label, path) in const [
              ('Support', '/support'),
              ('Privacy', '/privacy'),
              ('Terms', '/terms'),
              ('Waiver', '/waiver'),
              ('Delete account', '/delete-account'),
            ])
              TextLink(label, size: 15, onTap: () => openSitePage(path)),
          ],
        ),
        if (signedIn) ...[
          const SizedBox(height: 22),
          BBButton.quiet('Sign out', onPressed: onSignOut),
        ],
      ],
    );
  }
}

/// A paper row. With [onTap] it ends in a chevron (or [trailing]); without,
/// it sits on kraft and goes nowhere.
class _Row extends StatelessWidget {
  const _Row(this.label, {this.sub, this.trailing, this.onTap});

  final String label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Paper(
          onTap: onTap,
          color: onTap == null ? BB.kraft : BB.cream,
          radius: 14,
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BB.labelStyle(19, color: BB.ink, height: 1.1),
                      ),
                      if (sub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(sub!, style: BB.bodyStyle(14, color: BB.ink2, height: 1.25)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ?? const BBIcon(BBGlyph.forward, size: 22, color: BB.ink),
              ],
            ),
          ),
        ),
      );
}
