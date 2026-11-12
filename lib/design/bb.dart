// Battle Baseball's look: BattlePlan's Open Field design in its Navy scheme.
// Lilita One titles on a hard drop, Black Ops One stencil eyebrows, Fredoka
// labels and buttons, Nunito body text; rimmed cards on a lip with a candy
// stripe down the left edge; coral pill buttons on a hard lip.
import 'package:material_ui/material_ui.dart';

abstract final class BB {
  // Navy scheme roles.
  static const page = Color(0xFF0B1531);
  static const band = Color(0xFF07102A);
  static const text = Color(0xFFF2F6FF);
  static const muted = Color(0xFFB2BFE0);
  static const hairline = Color(0x1FF2F6FF);
  static const outline = Color(0x4DF2F6FF);
  static const field = Color(0xFF07102A);
  static const card = Color(0xFF18284C);
  static const rim = Color(0xFF35466D);
  static const cardMuted = Color(0xFFC2CCE8);
  static const drop = Color(0xFF2A63C9);
  static const accent = Color(0xFFF78C8C);
  static const going = Color(0xFF79CD8F);
  static const maybe = Color(0xFFF8D84A);
  static const game = Color(0xFFF19A5A);
  static const ink = Color(0xFF050C1F);
  static const lip = Color(0xFFC0262F);

  // Candy faces, the same in every scheme.
  static const coral = Color(0xFFF45B5B);
  static const mint = Color(0xFF58C173);
  static const lemon = Color(0xFFF8D84A);
  static const tangerine = Color(0xFFEE8131);
  static const grape = Color(0xFFA57CF5);
  static const gum = Color(0xFFEB50A2);
  static const blue = Color(0xFF79BBFF);
  static const cream = Color(0xFFF4EAD0);

  static const candies = [coral, tangerine, grape, gum, mint, lemon, blue];

  static const display = 'Lilita One';
  static const stencil = 'Black Ops One';
  static const label = 'Fredoka';
  static const body = 'Nunito';

  static TextStyle title(double size, {Color color = text}) => TextStyle(
        fontFamily: display,
        fontSize: size,
        height: 1.05,
        color: color,
        shadows: [Shadow(color: drop, offset: Offset(0, size >= 30 ? 4 : 2))],
      );

  static TextStyle labelStyle(double size,
          {Color color = text, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: label, fontSize: size, color: color, fontWeight: weight);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: Brightness.dark,
    ).copyWith(
      primary: coral,
      onPrimary: ink,
      secondary: blue,
      surface: page,
      onSurface: text,
      surfaceContainerHighest: card,
      outline: outline,
      error: accent,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      fontFamily: body,
      brightness: Brightness.dark,
    );
    OutlineInputBorder border(Color c, [double w = 2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: title(24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        labelStyle: labelStyle(15, color: muted, weight: FontWeight.w500),
        floatingLabelStyle: labelStyle(15, color: text),
        hintStyle: const TextStyle(color: muted),
        border: border(rim),
        enabledBorder: border(rim),
        focusedBorder: border(blue, 2.5),
        errorBorder: border(accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(color: hairline, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: labelStyle(15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: rim, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: page,
        selectedColor: coral,
        labelStyle: labelStyle(14),
        secondaryLabelStyle: labelStyle(14, color: ink),
        side: const BorderSide(color: rim, width: 1.5),
        shape: const StadiumBorder(),
        checkmarkColor: ink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: band,
        indicatorColor: coral,
        labelTextStyle: WidgetStatePropertyAll(labelStyle(12)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? ink : text),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: band,
        indicatorColor: coral,
        selectedIconTheme: const IconThemeData(color: ink),
        unselectedIconTheme: const IconThemeData(color: text),
        selectedLabelTextStyle: labelStyle(13),
        unselectedLabelTextStyle: labelStyle(13, color: muted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        titleTextStyle: title(22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: rim, width: 2),
        ),
      ),
      listTileTheme: const ListTileThemeData(iconColor: text, textColor: text),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: coral),
    );
  }
}

/// The small stencil line over a title ("12U · SPRING SHOWCASE").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = BB.accent});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: BB.stencil,
            fontSize: 13,
            letterSpacing: 2.2,
            color: color,
          ),
        ),
      );
}

/// A Lilita One title on a hard drop.
class Headline extends StatelessWidget {
  const Headline(this.text, {super.key, this.size = 30, this.color = BB.text});
  final String text;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text, style: BB.title(size, color: color));
}

/// A rimmed card on a 4 px lip, with a candy stripe down the left edge.
class GumCard extends StatelessWidget {
  const GumCard({
    super.key,
    required this.child,
    this.edge = BB.coral,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 16, 16),
    this.color = BB.card,
  });
  final Widget child;
  final Color? edge;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: BB.rim, width: 2),
        boxShadow: const [BoxShadow(color: BB.rim, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                if (edge != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 6, color: edge),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A candy pill button on a hard lip that sinks when pressed.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.face = BB.coral,
    this.fg = BB.ink,
    this.edge = BB.lip,
    this.expand = false,
    this.small = false,
    this.busy = false,
  });

  const CandyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.small = false,
    this.busy = false,
  })  : face = BB.card,
        fg = BB.text,
        edge = BB.rim;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color face;
  final Color fg;
  final Color edge;
  final bool expand;
  final bool small;
  final bool busy;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final lip = widget.small ? 3.0 : 4.0;
    final h = widget.small ? 40.0 : 50.0;
    final face = enabled ? widget.face : widget.face.withValues(alpha: 0.5);
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: widget.small ? 18 : 20, color: widget.fg),
        if (widget.icon != null || widget.busy) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: BB.labelStyle(widget.small ? 15 : 17, color: widget.fg),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Padding(
            padding: EdgeInsets.only(bottom: _down ? 0 : lip, top: _down ? lip : 0),
            child: Container(
              height: h,
              padding: EdgeInsets.symmetric(horizontal: widget.small ? 16 : 22),
              decoration: BoxDecoration(
                color: face,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: widget.edge, width: 2),
                boxShadow: _down ? null : [BoxShadow(color: widget.edge, offset: Offset(0, lip))],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded status chip.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = BB.blue, this.fg = BB.ink});
  final String label;
  final Color color;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: BB.ink, width: 1.5),
        ),
        child: Text(label, style: BB.labelStyle(12.5, color: fg)),
      );
}

/// The BATTLE / BASEBALL wordmark, drawn with text so it stays crisp.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.width = 200});
  final double width;
  @override
  Widget build(BuildContext context) {
    final s = width / 300;
    Widget layer(String t, String font, double size, Color fill, double stroke) => Stack(
          children: [
            Transform.translate(
              offset: Offset(5 * s, 5 * s),
              child: Text(t,
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: size * s,
                    height: 1,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = stroke * s
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xFF1A1A18),
                  )),
            ),
            Text(t,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: size * s,
                  height: 1,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = stroke * s
                    ..strokeJoin = StrokeJoin.round
                    ..color = const Color(0xFF1A1A18),
                )),
            Text(t,
                style: TextStyle(
                    fontFamily: font, fontSize: size * s, height: 1, color: fill)),
          ],
        );
    return Semantics(
      label: 'Battle Baseball',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            layer('BATTLE', BB.display, 72, BB.cream, 9),
            SizedBox(height: 2 * s),
            layer('BASEBALL', BB.stencil, 40, const Color(0xFFF25C5C), 8),
          ],
        ),
      ),
    );
  }
}

/// Centers content and caps its width on tablets and the web.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 760, this.padding});
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: children,
          ),
        ),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text, style: BB.title(22)),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => GumCard(
        edge: BB.blue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(color: BB.cardMuted, fontSize: 16)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
