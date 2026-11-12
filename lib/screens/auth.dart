import 'package:battle_baseball/design/bb.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The first stop for an account with no profile yet (a new Google sign-in):
/// confirm 18+ and the terms, or back out and delete the account.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final _name = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  bool _adult = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_name.text.trim().isEmpty) {
      toast(context, 'Add your name.');
      return;
    }
    if (!_adult) {
      toast(context, 'Check the box to continue.');
      return;
    }
    setState(() => _busy = true);
    final db = FirebaseFirestore.instance;
    final email = (user.email ?? '').toLowerCase();
    final name = _name.text.trim();
    try {
      final batch = db.batch()
        ..set(db.doc('users/${user.uid}'), {
          'name': name,
          'email': email,
          'adultConfirmed': true,
          'termsAcceptedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      if (email.isNotEmpty) {
        batch.set(db.doc('userEmails/$email'), {'uid': user.uid, 'name': name});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Saving the profile failed: $e');
      if (mounted) toast(context, "Couldn't save. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await user?.delete();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        children: [
          const PageTitle('One more thing', padding: _titlePadding),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 6),
          _Consent(value: _adult, onChanged: (v) => setState(() => _adult = v)),
          const SizedBox(height: 16),
          BBButton.primary('Continue', expand: true, busy: _busy, onPressed: _save),
          const SizedBox(height: 10),
          TextLink('Cancel', onTap: _cancel),
        ],
      );
}

/// Email sign-in and sign-up. Accounts are for adults: parents, guardians,
/// volunteers, and admins. Players are records their parents manage.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.signUp = false});
  final bool signUp;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late bool _signUp = widget.signUp;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _adult = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          "That email and password don't match.",
        'email-already-in-use' => 'That email already has an account.',
        'weak-password' => 'Use at least 8 characters.',
        'invalid-email' => "That email doesn't look right.",
        'too-many-requests' => 'Too many tries. Wait a minute.',
        _ => e.message ?? 'Something went wrong. Try again.',
      };

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    if (_signUp && !_adult) {
      setState(() => _error = 'Check the box to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    final email = _email.text.trim().toLowerCase();
    try {
      if (_signUp) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: email, password: _password.text);
        final name = _name.text.trim();
        await cred.user!.updateDisplayName(name);
        final db = FirebaseFirestore.instance;
        final batch = db.batch()
          ..set(db.doc('users/${cred.user!.uid}'), {
            'name': name,
            'email': email,
            'adultConfirmed': true,
            'termsAcceptedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(db.doc('userEmails/$email'), {'uid': cred.user!.uid, 'name': name});
        await batch.commit();
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Continue with Google. A first-time Google account confirms it's an
  /// adult and accepts the terms before its profile is saved.
  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
      final cred = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
      // A first-time account goes to WelcomeScreen (the router sends it there).
      debugPrint('Signed in with Google: ${cred.user?.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') {
        if (mounted) setState(() => _error = _message(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Google sign-in didn't finish. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) toast(context, 'Reset link sent to $email.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _switch() => setState(() {
        _signUp = !_signUp;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final title = _signUp ? 'Create an account' : 'Sign in';
    return _AuthFrame(
      onClose: () => context.canPop() ? context.pop() : context.go('/'),
      children: [
        PageTitle(title, padding: _titlePadding),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_signUp) ...[
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v ?? '').length < (_signUp ? 8 : 1)
                      ? (_signUp ? 'At least 8 characters' : 'Enter your password')
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (_signUp) ...[
          const SizedBox(height: 6),
          _Consent(value: _adult, onChanged: (v) => setState(() => _adult = v)),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: BB.labelStyle(15, color: BB.coral, height: 1.3)),
            ),
          ),
        const SizedBox(height: 16),
        BBButton.primary(title, expand: true, busy: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        BBButton.paper('Continue with Google', expand: true, onPressed: _google),
        const SizedBox(height: 12),
        Wrap(
          spacing: 22,
          children: [
            TextLink(_signUp ? 'Sign in' : 'Create an account', onTap: _switch),
            if (!_signUp) TextLink('Forgot password', onTap: _reset),
          ],
        ),
      ],
    );
  }
}

const _titlePadding = EdgeInsets.only(top: 6, bottom: 18);

/// The frame the account screens share: the wordmark on top, an optional
/// close button, and one narrow column. These screens sit outside the app's
/// bars.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.children, this.onClose});

  final List<Widget> children;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    return Scaffold(
      body: PageFrame(
        maxWidth: 420,
        children: [
          if (wide) const SizedBox(height: 24),
          SizedBox(
            height: wide ? 84 : 62,
            child: Row(
              children: [
                Wordmark(height: wide ? 46.4 : 38),
                const Spacer(),
                if (onClose != null)
                  // Nudged so the X itself sits on the column's edge.
                  Transform.translate(
                    offset: const Offset(11, 0),
                    child: Pressable(
                      onTap: onClose,
                      label: 'Close',
                      builder: (context, down, focused) => Opacity(
                        opacity: down ? 0.7 : 1,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: focused ? Border.all(color: BB.cream, width: 2) : null,
                          ),
                          child: Center(child: BBIcon(BBGlyph.close, size: 22, color: BB.cream)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// The one consent line: a checkbox, and the Terms and Privacy Policy as
/// links inside the sentence.
class _Consent extends StatefulWidget {
  const _Consent({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_Consent> createState() => _ConsentState();
}

class _ConsentState extends State<_Consent> {
  late final _terms = TapGestureRecognizer()..onTap = () => openSitePage('/terms');
  late final _privacy = TapGestureRecognizer()..onTap = () => openSitePage('/privacy');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.value;
    final link = TextStyle(
      color: BB.cream,
      decoration: TextDecoration.underline,
      decorationColor: BB.coral,
      decorationThickness: 2,
    );
    return Semantics(
      checked: on,
      child: Pressable(
        onTap: () => widget.onChanged(!on),
        builder: (context, down, focused) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: on ? BB.coral : BB.fieldRaised,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: focused ? BB.cream : BB.ink, width: 2),
                  boxShadow: BB.lip(2),
                ),
                child: on ? Center(child: BBIcon(BBGlyph.check, size: 16, color: BB.ink)) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: "I'm 18 or older and agree to the "),
                    TextSpan(text: 'Terms', style: link, recognizer: _terms),
                    const TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
                    const TextSpan(text: '.'),
                  ]),
                  style: BB.bodyStyle(15.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
