import 'package:battle_baseball/design/bb.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

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
    if (!_adult || _name.text.trim().isEmpty) {
      toast(context, 'Add your name and confirm you are 18 or older.');
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
      if (mounted) toast(context, "Couldn't save: $e");
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
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              children: [
                const Center(child: Wordmark(width: 200)),
                const SizedBox(height: 24),
                const Eyebrow('Welcome'),
                const Headline('One more thing', size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Battle Baseball accounts are for parents, guardians, and volunteers. '
                  'Players never need their own.',
                  style: TextStyle(color: BB.muted, fontSize: 16),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _adult,
                  onChanged: (v) => setState(() => _adult = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    "I'm 18 or older and agree to the Terms and Privacy Policy.",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 14),
                CandyButton(label: 'Continue', expand: true, busy: _busy, onPressed: _save),
                const SizedBox(height: 8),
                TextButton(onPressed: _cancel, child: const Text("Cancel, I'm not 18")),
              ],
            ),
          ),
        ),
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
          "That email and password don't match an account.",
        'email-already-in-use' => 'There is already an account with that email. Try signing in.',
        'weak-password' => 'Pick a password with at least 8 characters.',
        'invalid-email' => "That email address doesn't look right.",
        'too-many-requests' => 'Too many tries. Wait a minute and try again.',
        _ => e.message ?? 'Something went wrong. Try again.',
      };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_signUp && !_adult) {
      setState(() => _error = 'Accounts are for adults 18 and over.');
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
      setState(() => _error = _message(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Continue with Google. A first-time Google account confirms it's an
  /// adult and accepts the terms before its profile is saved.
  Future<void> _google() async {
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
        setState(() => _error = _message(e));
      }
    } catch (e) {
      setState(() => _error = 'Google sign-in did not finish. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email above, then tap Forgot password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) toast(context, 'Check $email for a link to reset your password.');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            shrinkWrap: true,
            children: [
              const Center(child: Wordmark(width: 200)),
              const SizedBox(height: 24),
              Eyebrow(_signUp ? 'Parents and volunteers' : 'Welcome back'),
              Headline(_signUp ? 'Create your account' : 'Sign in', size: 32),
              const SizedBox(height: 8),
              Text(
                _signUp
                    ? 'One account covers all your players. Kids never need their own.'
                    : 'Register players, reserve spots, and follow results.',
                style: const TextStyle(color: BB.muted, fontSize: 16),
              ),
              const SizedBox(height: 20),
              CandyButton(
                label: 'Continue with Google',
                icon: Icons.account_circle,
                face: Colors.white,
                fg: const Color(0xFF1F1F1F),
                edge: BB.ink,
                expand: true,
                onPressed: _busy ? null : _google,
              ),
              const SizedBox(height: 18),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or use email', style: TextStyle(color: BB.muted)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 18),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      if (_signUp) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Your name'),
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) =>
                            (v ?? '').contains('@') ? null : 'Enter your email',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        autofillHints: [
                          _signUp ? AutofillHints.newPassword : AutofillHints.password
                        ],
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
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _adult,
                  onChanged: (v) => setState(() => _adult = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    "I'm 18 or older and agree to the Terms and Privacy Policy.",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Wrap(
                  spacing: 16,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse('https://showcase.getbattleplan.app/terms')),
                      child: const Text('Terms'),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse('https://showcase.getbattleplan.app/privacy')),
                      child: const Text('Privacy Policy'),
                    ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: BB.accent, fontSize: 15)),
                ),
              const SizedBox(height: 18),
              CandyButton(
                label: _signUp ? 'Create account' : 'Sign in',
                onPressed: _submit,
                busy: _busy,
                expand: true,
              ),
              const SizedBox(height: 10),
              if (!_signUp)
                TextButton(onPressed: _reset, child: const Text('Forgot password?')),
              TextButton(
                onPressed: () => setState(() {
                  _signUp = !_signUp;
                  _error = null;
                }),
                child: Text(_signUp
                    ? 'Already have an account? Sign in'
                    : 'New to Battle Baseball? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
