// Account: who is signed in, the few places only they go, and the links to
// the static pages.
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
        _Row(
          'Host a Showcase',
          sub: 'Help run one to raise money for your team',
          onTap: () => context.go('/host'),
        ),
        _Row(
          'Battleplan',
          sub: 'Free team chat and schedules',
          trailing: BBIcon(BBGlyph.external, size: 20, color: BB.ink),
          onTap: openBattleplan,
        ),
        _Row(
          'Merch',
          sub: 'Battle Baseball tees',
          trailing: const Pill('Coming soon'),
          onTap: () => context.go('/merch'),
        ),
        const _Row(
          'Battle Paddle',
          sub: 'Swing training tool for elite mechanics',
          trailing: Pill('Coming soon'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 22,
          children: [
            for (final (label, path) in const [
              ('Support', '/support'),
              ('Privacy', '/privacy'),
              ('Terms', '/terms'),
              ('Waiver', '/waiver'),
            ])
              TextLink(label, size: 15, onTap: () => openSitePage(path)),
            // Signed in, the account is deleted right here (the App Store
            // requires it). Signed out, the page says how.
            TextLink(
              'Delete account',
              size: 15,
              onTap: signedIn
                  ? () => showDialog<void>(context: context, builder: (_) => const _DeleteAccount())
                  : () => openSitePage('/delete-account'),
            ),
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
                trailing ?? BBIcon(BBGlyph.forward, size: 22, color: BB.ink),
              ],
            ),
          ),
        ),
      );
}

/// Deletes the signed-in account: its players, their private details and
/// public cards, its profile, and the sign-in itself. An email account
/// confirms with its password first, since Firebase only deletes a sign-in
/// that was used recently.
class _DeleteAccount extends StatefulWidget {
  const _DeleteAccount();
  @override
  State<_DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<_DeleteAccount> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _usesPassword => _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _reauthenticate(User user) async {
    if (_usesPassword) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email ?? '', password: _password.text),
      );
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (Repo.isDemo) {
      setState(() => _error = 'This is sample data. Nothing was deleted.');
      return;
    }
    final user = _user;
    if (user == null) return;
    if (_usesPassword && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _reauthenticate(user);
      if (!mounted) return;
      // The password checks out, so close this dialog now: deleting the
      // profile sends the app to another screen, which would take an open
      // dialog with it (and a later pop would take the page underneath).
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      String done = 'Your account was deleted.';
      try {
        await Repo.instance.deleteMyData();
        await user.delete();
      } catch (e) {
        debugPrint('Deleting the account failed: $e');
        done = "Couldn't finish deleting your account. Sign in and try Delete account again.";
      }
      await FirebaseAuth.instance.signOut();
      router.go('/');
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on FirebaseAuthException catch (e) {
      debugPrint('Deleting the account failed: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() => _error = switch (e.code) {
            'wrong-password' || 'invalid-credential' => "That password isn't right.",
            'too-many-requests' => 'Too many tries. Wait a minute and try again.',
            _ => "Couldn't delete the account. Try again.",
          });
    } catch (e) {
      debugPrint('Deleting the account failed: $e');
      if (mounted) setState(() => _error = "Couldn't delete the account. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This deletes your account, your players, their private details, and their '
                "player cards. It can't be undone. Results already published stay on past "
                "showcases without your player's name.",
              ),
              if (_usesPassword) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Your password'),
                  onSubmitted: (_) => _delete(),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: BB.labelStyle(15, color: BB.coral, height: 1.3)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          BBButton.paper('Cancel', small: true, onPressed: () => Navigator.of(context).pop()),
          BBButton.primary('Delete account', small: true, busy: _busy, onPressed: _delete),
        ],
      );
}
