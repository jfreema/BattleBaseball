// Host a Showcase: a team asks to run one as a fundraiser. One short form
// that lands in the owner's inbox.
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:material_ui/material_ui.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final _form = GlobalKey<FormState>();
  final _team = TextEditingController();
  // Someone signed in doesn't retype what we already know.
  final _name = TextEditingController(text: Session.instance.name);
  final _email = TextEditingController(text: Session.instance.email);
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _more = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    for (final c in [_team, _name, _email, _phone, _city, _more]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Repo.instance.sendHostInquiry(
        team: _team.text.trim(),
        contact: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        city: _city.text.trim(),
        message: _more.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (!mounted) return;
      if (Repo.isDemo) {
        // Sample data can't be written; show what sending looks like.
        setState(() => _sent = true);
      } else {
        toast(context, "Couldn't send. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _HostView(
        form: _form,
        team: _team,
        name: _name,
        email: _email,
        phone: _phone,
        city: _city,
        more: _more,
        busy: _busy,
        sent: _sent,
        onSend: _send,
      );
}

class _HostView extends StatelessWidget {
  const _HostView({
    required this.form,
    required this.team,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.more,
    required this.busy,
    required this.sent,
    required this.onSend,
  });

  final GlobalKey<FormState> form;
  final TextEditingController team;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController city;
  final TextEditingController more;
  final bool busy;
  final bool sent;
  final VoidCallback onSend;

  static String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator = _required,
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
    TextCapitalization caps = TextCapitalization.none,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          minLines: lines,
          maxLines: lines,
          keyboardType: keyboard ?? (lines > 1 ? TextInputType.multiline : null),
          textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
          textCapitalization: caps,
          autofillHints: hint == null ? null : [hint],
          decoration: InputDecoration(labelText: label, alignLabelWithHint: lines > 1),
          validator: validator,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final pitch = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Host a Showcase.', style: BB.title(wide ? 64 : 40, drop: wide ? 5 : 4)),
        ),
        if (!sent)
          Padding(
            padding: EdgeInsets.only(top: wide ? 20 : 12),
            // One sentence to a line.
            child: Text(
              'Your volunteers run the day.\nYour team keeps a share.',
              style: BB.bodyStyle(wide ? 20 : 17),
            ),
          ),
      ],
    );
    final Widget body = sent
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text('Got it.', style: BB.title(wide ? 34 : 28, drop: 3)),
              ),
              const SizedBox(height: 8),
              const Quiet("We'll be in touch."),
            ],
          )
        : Form(
            key: form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(team, 'Team', caps: TextCapitalization.words),
                  _field(name, 'Your name', caps: TextCapitalization.words, hint: AutofillHints.name),
                  _field(
                    email,
                    'Email',
                    keyboard: TextInputType.emailAddress,
                    hint: AutofillHints.email,
                    validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email',
                  ),
                  _field(
                    phone,
                    'Phone (optional)',
                    keyboard: TextInputType.phone,
                    hint: AutofillHints.telephoneNumber,
                    validator: null,
                  ),
                  _field(city, 'City', caps: TextCapitalization.words, hint: AutofillHints.addressCity),
                  _field(
                    more,
                    'Anything else (optional)',
                    lines: 4,
                    caps: TextCapitalization.sentences,
                    validator: null,
                  ),
                  const SizedBox(height: 6),
                  BBButton.primary('Send', busy: busy, expand: !wide, onPressed: onSend),
                ],
              ),
            ),
          );
    return PageFrame(
      column: wide ? null : 560,
      children: [
        if (wide) const SizedBox(height: 36) else const BackHeader('Home'),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: pitch),
              const SizedBox(width: 72),
              // Dropped a little so the first field lines up with the headline.
              Expanded(flex: 5, child: Padding(padding: const EdgeInsets.only(top: 8), child: body)),
            ],
          )
        else ...[
          Padding(padding: const EdgeInsets.only(top: 6), child: pitch),
          SizedBox(height: sent ? 18 : 22),
          body,
        ],
      ],
    );
  }
}
