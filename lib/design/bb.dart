// Battle Baseball's look, "The Card": a colored field, cream card stock, ink
// outlines on hard ink lips, and one accent. The colors come from the scheme
// in use (schemes.dart). The tokens, the theme and the small primitives every
// screen is built from.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:battle_baseball/design/schemes.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:battle_baseball/design/schemes.dart';

abstract final class BB {
  /// The scheme every color below comes from. Set by [SchemeController];
  /// screens read it fresh on each build.
  static BBScheme scheme = BBSchemes.fallback;

  // The field.
  static Color get field => scheme.field;
  static Color get fieldDeep => scheme.fieldDeep;
  static Color get fieldRaised => scheme.fieldRaised;

  // Paper and ink.
  static Color get cream => scheme.cream;
  static Color get creamSoft => scheme.cream.withAlpha(scheme.softAlpha);
  static Color get hairline => scheme.cream.withAlpha(0x29);
  static Color get dashed => scheme.cream.withAlpha(0x6B);
  static Color get kraft => scheme.kraft;
  static Color get ink => scheme.ink;
  static Color get ink2 => scheme.ink2;

  /// A faint rule on paper (ink at 16%).
  static Color get inkRule => scheme.ink.withAlpha(0x29);

  // One accent (named coral after the original scheme), and two colors with
  // one job each.
  static Color get coral => scheme.accent;
  static Color get coralDeep => scheme.accentDeep;
  static Color get seam => scheme.seam;

  /// Honors only: award seals and first place.
  static Color get lemon => scheme.honors;

  /// Spots open only.
  static Color get mint => scheme.mint;

  /// Phone layout below this width, desktop at or above it.
  static const breakpoint = 960.0;

  /// The widest a page's content gets on desktop.
  static const contentWidth = 1120.0;

  /// Where the static pages (privacy, terms, waiver, support) live.
  static const site = 'https://showcase.getbattleplan.app';

  /// Battleplan, the team chat app coaches use with parents.
  static const battleplan = 'https://getbattleplan.app';

  static const display = 'Lilita One';
  static const stencil = 'Black Ops One';
  static const label = 'Fredoka';
  static const body = 'Nunito';

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= breakpoint;

  /// Side padding for page content: 16 on phones, 40 on desktop.
  static double gutter(BuildContext context) => isWide(context) ? 40 : 16;

  /// The only shadow in the app: a hard ink copy straight down.
  static List<BoxShadow> lip(double depth) =>
      [BoxShadow(color: ink, offset: Offset(0, depth))];

  /// Lilita One on the field: cream on a hard ink drop.
  static TextStyle title(double size, {Color? color, double? drop}) => TextStyle(
        fontFamily: display,
        // Lilita has one weight; inheriting a bolder one would fake-embolden it.
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1.05,
        letterSpacing: size * 0.005,
        color: color ?? cream,
        leadingDistribution: TextLeadingDistribution.even,
        shadows: [
          Shadow(
            color: ink,
            offset: Offset(0, drop ?? (size < 27 ? 2 : size < 32 ? 3 : size < 60 ? 4 : 6)),
          ),
        ],
      );

  /// Lilita One printed on paper: flat ink, no drop.
  static TextStyle lilita(double size, {Color? color, double height = 1.05}) => TextStyle(
        fontFamily: display,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: height,
        color: color ?? ink,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// Fredoka: buttons, chips, tab labels, names in rows.
  static TextStyle labelStyle(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) =>
      TextStyle(
        fontFamily: label,
        fontSize: size,
        height: height,
        color: color ?? cream,
        fontWeight: weight,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// Fredoka small caps, tracked. Pass the text already in upper case.
  static TextStyle caps(
    double size, {
    Color? color,
    double tracking = 0.1,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: label,
        fontSize: size,
        height: 1,
        color: color ?? creamSoft,
        fontWeight: weight,
        letterSpacing: size * tracking,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// Nunito: the rare sentence.
  static TextStyle bodyStyle(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w700,
    double height = 1.4,
  }) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        height: height,
        color: color ?? creamSoft,
        fontWeight: weight,
      );

  /// Black Ops One: only for things stamped on paper.
  static TextStyle stencilStyle(double size, {Color? color, double tracking = 0.16}) =>
      TextStyle(
        fontFamily: stencil,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1,
        color: color ?? ink,
        letterSpacing: size * tracking,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static ThemeData theme() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: coral,
      onPrimary: ink,
      primaryContainer: coral,
      onPrimaryContainer: ink,
      secondary: cream,
      onSecondary: ink,
      secondaryContainer: fieldRaised,
      onSecondaryContainer: cream,
      tertiary: lemon,
      onTertiary: ink,
      error: coral,
      onError: ink,
      surface: field,
      onSurface: cream,
      onSurfaceVariant: creamSoft,
      surfaceContainerLowest: fieldDeep,
      surfaceContainerLow: fieldDeep,
      surfaceContainer: fieldDeep,
      surfaceContainerHigh: fieldDeep,
      surfaceContainerHighest: fieldRaised,
      outline: dashed,
      outlineVariant: hairline,
      inverseSurface: cream,
      onInverseSurface: ink,
      surfaceTint: Colors.transparent,
      shadow: ink,
      scrim: ink,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: field,
      // Chips sit on a canvas-colored Material, so this has to be the field
      // for an unselected chip to read as an outline.
      canvasColor: field,
      fontFamily: body,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: hairline,
      focusColor: hairline,
    );
    OutlineInputBorder border(Color c, [double w = 2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    final panel = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: ink, width: 2.5),
    );
    final pillButton = ButtonStyle(
      textStyle: WidgetStatePropertyAll(labelStyle(16)),
      minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
    );
    // Material tracks its type scale (body text by a quarter pixel a letter).
    // These faces are set as drawn, which also keeps the app's lines breaking
    // where the static shell in web/index.html breaks them.
    TextStyle? flat(TextStyle? s) => s?.copyWith(letterSpacing: 0);
    final m = base.textTheme.apply(bodyColor: cream, displayColor: cream, fontFamily: body);
    final text = TextTheme(
      displayLarge: flat(m.displayLarge),
      displayMedium: flat(m.displayMedium),
      displaySmall: flat(m.displaySmall),
      headlineLarge: flat(m.headlineLarge),
      headlineMedium: flat(m.headlineMedium),
      headlineSmall: flat(m.headlineSmall),
      titleLarge: flat(m.titleLarge),
      titleMedium: flat(m.titleMedium),
      titleSmall: flat(m.titleSmall),
      bodyLarge: flat(m.bodyLarge),
      bodyMedium: flat(m.bodyMedium),
      bodySmall: flat(m.bodySmall),
      labelLarge: flat(m.labelLarge),
      labelMedium: flat(m.labelMedium),
      labelSmall: flat(m.labelSmall),
    );
    return base.copyWith(
      textTheme: text.copyWith(
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.45),
        bodySmall: text.bodySmall?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: creamSoft),
        titleMedium: text.titleMedium?.copyWith(fontFamily: label, fontSize: 17, fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontFamily: label, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: field,
        foregroundColor: cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: title(24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldRaised,
        labelStyle: labelStyle(15.5, color: creamSoft, weight: FontWeight.w500),
        floatingLabelStyle: labelStyle(15.5, color: cream),
        hintStyle: bodyStyle(16, color: dashed),
        helperStyle: bodyStyle(13, color: creamSoft),
        errorStyle: labelStyle(13, color: coral),
        prefixIconColor: creamSoft,
        suffixIconColor: creamSoft,
        border: border(ink),
        enabledBorder: border(ink),
        disabledBorder: border(ink),
        focusedBorder: border(cream),
        errorBorder: border(coral),
        focusedErrorBorder: border(coral),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cream,
        selectionColor: coral.withValues(alpha: 0.45),
        selectionHandleColor: coral,
      ),
      dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cream,
        contentTextStyle: labelStyle(15.5, color: ink),
        actionTextColor: ink,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ink, width: 2.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        color: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? coral : Colors.transparent,
        ),
        labelStyle: labelStyle(15).copyWith(
          color: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? ink : cream,
          ),
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? ink : dashed, width: 2),
        ),
        shape: WidgetStateOutlinedBorder.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? LipShape(const StadiumBorder(), lip: 3)
              : const StadiumBorder(),
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 7),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        deleteIconColor: cream,
        iconTheme: IconThemeData(color: cream, size: 18),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: fieldDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: title(26),
        contentTextStyle: bodyStyle(16),
        shape: panel,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: fieldDeep,
        modalBackgroundColor: fieldDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: ink.withAlpha(0x99),
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          side: BorderSide(color: ink, width: 2.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: fieldDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: labelStyle(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ink, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ink : creamSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? coral : fieldRaised,
        ),
        trackOutlineColor: WidgetStatePropertyAll(ink),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? coral : fieldRaised,
        ),
        checkColor: WidgetStatePropertyAll(ink),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? ink : creamSoft, width: 2),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? coral : creamSoft,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: pillButton.copyWith(foregroundColor: WidgetStatePropertyAll(cream)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: pillButton.copyWith(
          backgroundColor: WidgetStatePropertyAll(coral),
          foregroundColor: WidgetStatePropertyAll(ink),
          side: WidgetStatePropertyAll(BorderSide(color: ink, width: 2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: pillButton.copyWith(
          backgroundColor: WidgetStatePropertyAll(cream),
          foregroundColor: WidgetStatePropertyAll(ink),
          side: WidgetStatePropertyAll(BorderSide(color: ink, width: 2)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: pillButton.copyWith(
          foregroundColor: WidgetStatePropertyAll(cream),
          side: WidgetStatePropertyAll(BorderSide(color: dashed, width: 2)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(cream)),
      ),
      iconTheme: IconThemeData(color: cream),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: coral,
        foregroundColor: ink,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(side: BorderSide(color: ink, width: 2.5)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cream,
        unselectedLabelColor: creamSoft,
        indicatorColor: coral,
        dividerColor: hairline,
        labelStyle: labelStyle(15.5),
        unselectedLabelStyle: labelStyle(15.5),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cream,
        textColor: cream,
        titleTextStyle: labelStyle(17),
        subtitleTextStyle: bodyStyle(14.5),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ink, width: 2),
        ),
        textStyle: labelStyle(13, color: ink),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cream),
    );
  }
}

/// Opens one of the static pages ("/privacy", "/terms", "/waiver",
/// "/support", "/delete-account"). On the web it stays on this origin.
Future<void> openSitePage(String path) {
  final uri = kIsWeb ? Uri.base.resolve(path) : Uri.parse('${BB.site}$path');
  return launchUrl(uri);
}

Future<void> openBattleplan() => launchUrl(Uri.parse(BB.battleplan));

/// "Powered by Battleplan", for the bottom of a page.
class PoweredBy extends StatelessWidget {
  const PoweredBy({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Powered by', style: BB.bodyStyle(size - 0.5, height: 1)),
          TextLink('Battleplan', size: size, onTap: openBattleplan),
        ],
      );
}

/// Wraps a shape and paints a hard ink lip under it, for Material widgets
/// that take a shape but can't take a hard shadow (chips, snackbars).
class LipShape extends OutlinedBorder {
  LipShape(this.shape, {this.lip = 3}) : super(side: shape.side);

  final OutlinedBorder shape;
  final double lip;

  @override
  ShapeBorder scale(double t) => LipShape(shape.scale(t) as OutlinedBorder, lip: lip * t);

  @override
  LipShape copyWith({BorderSide? side}) => LipShape(shape.copyWith(side: side), lip: lip);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (lip > 0) {
      final outer = shape.getOuterPath(rect, textDirection: textDirection);
      final under = Path.combine(PathOperation.difference, outer.shift(Offset(0, lip)), outer);
      canvas.drawPath(under, Paint()..color = BB.ink);
    }
    shape.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is LipShape) {
      final s = ShapeBorder.lerp(a.shape, shape, t);
      return LipShape(s is OutlinedBorder ? s : shape, lip: lerpDouble(a.lip, lip, t)!);
    }
    if (a is OutlinedBorder) {
      final s = ShapeBorder.lerp(a, shape, t);
      return LipShape(s is OutlinedBorder ? s : shape, lip: lip * t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is OutlinedBorder && b is! LipShape) {
      final s = ShapeBorder.lerp(shape, b, t);
      return LipShape(s is OutlinedBorder ? s : b, lip: lip * (1 - t));
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is LipShape && other.shape == shape && other.lip == lip;

  @override
  int get hashCode => Object.hash(shape, lip);
}

/// Something tappable drawn by hand: reports pressed and keyboard focus to
/// its builder, shows the click cursor, and answers Enter and Space.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.builder, this.label});

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool down, bool focused) builder;

  /// Read by screen readers in place of what's inside.
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  void _set(bool down) {
    if (mounted && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final labelled = widget.label != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      // With a label this node stands in for everything inside it; without
      // one the gesture below supplies the tap and the contents are read.
      excludeSemantics: labelled,
      onTap: labelled ? widget.onTap : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: enabled ? () => _set(false) : null,
          onTap: widget.onTap,
          child: widget.builder(context, _down && enabled, _focused && enabled),
        ),
      ),
    );
  }
}

/// A face with an ink outline on a hard ink lip. With [onTap] it sinks onto
/// the lip while pressed. The box is [lip] taller than its face.
class LipBox extends StatelessWidget {
  const LipBox({
    super.key,
    required this.child,
    this.color,
    this.radius = 16,
    this.border = 2.5,
    this.lip = 4,
    this.onTap,
    this.sink = true,
    this.semanticLabel,
  });

  final Widget child;
  final Color? color;
  Color get _color => color ?? BB.cream;
  final double radius;
  final double border;
  final double lip;
  final VoidCallback? onTap;

  /// Off for boxes that hold their own buttons, so pressing one of those
  /// doesn't move the whole box.
  final bool sink;
  final String? semanticLabel;

  Widget _face(bool down, bool focused) {
    final r = BorderRadius.circular(radius);
    return Padding(
      padding: EdgeInsets.only(top: down ? lip : 0, bottom: down ? 0 : lip),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _color,
          borderRadius: r,
          boxShadow: [
            if (focused) BoxShadow(color: BB.cream, spreadRadius: 3),
            if (!down) BoxShadow(color: BB.ink, offset: Offset(0, lip)),
          ],
        ),
        // The outline is painted over the content, so a colored child that
        // runs to the edge meets it without a seam.
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: BB.ink, width: border),
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Padding(padding: EdgeInsets.all(border), child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      final box = _face(false, false);
      return semanticLabel == null
          ? box
          : Semantics(label: semanticLabel, container: true, child: box);
    }
    return Pressable(
      onTap: onTap,
      label: semanticLabel,
      builder: (context, down, focused) => _face(down && sink, focused),
    );
  }
}

/// The cream (or kraft) panel with an ink outline and lip.
class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.color,
    this.radius = 16,
    this.lip = 4,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.sink = true,
    this.semanticLabel,
  });

  final Widget child;
  final Color? color;
  Color get _color => color ?? BB.cream;
  final double radius;
  final double lip;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Turn off when the panel holds a button of its own.
  final bool sink;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => LipBox(
        color: _color,
        radius: radius,
        lip: lip,
        onTap: onTap,
        sink: sink,
        semanticLabel: semanticLabel,
        child: DefaultTextStyle.merge(
          style: BB.labelStyle(17, color: BB.ink),
          child: IconTheme.merge(
            data: IconThemeData(color: BB.ink),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

enum BBButtonKind { primary, paper, quiet }

/// The pill button on a hard lip. One coral [BBButton.primary] per screen.
class BBButton extends StatelessWidget {
  const BBButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = BBButtonKind.primary,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.small = false,
    this.large = false,
  });

  /// Coral face, ink label.
  const BBButton.primary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.small = false,
    this.large = false,
  }) : kind = BBButtonKind.primary;

  /// Cream face, ink label.
  const BBButton.paper(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.small = false,
    this.large = false,
  }) : kind = BBButtonKind.paper;

  /// Raised-field face, cream label.
  const BBButton.quiet(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.small = false,
    this.large = false,
  }) : kind = BBButtonKind.quiet;

  final String label;
  final VoidCallback? onPressed;
  final BBButtonKind kind;

  /// Shown before the label, tinted to match it (an [Icon] or a [BBIcon]).
  final Widget? icon;

  /// Fill the width on offer.
  final bool expand;

  /// Shows a spinner and ignores taps.
  final bool busy;

  /// 40 tall with a 3 px lip.
  final bool small;

  /// 62 tall, for the desktop hero.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final off = onPressed == null && !busy;
    final (face, fg) = switch (kind) {
      // Switched off, every kind is the same quiet shape with a faint label.
      _ when off => (BB.fieldRaised, BB.dashed),
      BBButtonKind.primary => (BB.coral, BB.ink),
      BBButtonKind.paper => (BB.cream, BB.ink),
      BBButtonKind.quiet => (BB.fieldRaised, BB.cream),
    };
    final h = small ? 40.0 : large ? 62.0 : 54.0;
    final lip = small ? 3.0 : 5.0;
    final pad = small ? 18.0 : large ? 36.0 : 28.0;
    final size = small ? 15.5 : large ? 22.0 : 19.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        else if (icon != null)
          IconTheme(data: IconThemeData(color: fg, size: small ? 18 : 21), child: icon!),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: BB.labelStyle(size, color: fg, height: 1),
          ),
        ),
      ],
    );
    final Widget pressable = Pressable(
      onTap: enabled ? onPressed : null,
      label: label,
      builder: (context, down, focused) => Padding(
        padding: EdgeInsets.only(top: down ? lip : 0, bottom: down ? 0 : lip),
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: pad),
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: BB.ink, width: small ? 2 : 2.5),
            boxShadow: [
              if (focused) BoxShadow(color: BB.cream, spreadRadius: 3),
              if (!down) BoxShadow(color: BB.ink, offset: Offset(0, lip)),
            ],
          ),
          child: content,
        ),
      ),
    );
    final button = MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: pressable);
    return expand
        ? SizedBox(width: double.infinity, child: button)
        : Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: button,
          );
  }
}

/// A text link: Fredoka with a 3 px coral underline. Use [color] `BB.ink`
/// on paper.
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap, this.color, this.size = 16});

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  Color get _color => color ?? BB.cream;
  final double size;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: Pressable(
          onTap: onTap,
          label: label,
          builder: (context, down, focused) => ConstrainedBox(
            // A 44 px target around a one-line link.
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Opacity(
                opacity: down ? 0.7 : 1,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: focused ? _color : BB.coral, width: 3),
                    ),
                  ),
                  child: Text(label, style: BB.labelStyle(size, color: _color, height: 1.15)),
                ),
              ),
            ),
          ),
        ),
      );
}

/// A 26 px status pill. Mint for spots open, lemon for honors, cream for
/// everything else.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color});

  final String label;
  final Color? color;
  Color get _color => color ?? BB.cream;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: const EdgeInsets.fromLTRB(10, 3, 10, 4),
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: BB.ink, width: 2),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: BB.labelStyle(13, color: BB.ink, height: 1.15),
          ),
        ),
      );
}

/// The stencil stamp ("SAMPLE"), set at a slight angle.
class Stamp extends StatelessWidget {
  const Stamp(this.text, {super.key, this.color, this.fill});

  final String text;
  final Color? color;
  Color get _color => color ?? BB.cream;

  /// A backing color, for a stamp that floats over other things.
  final Color? fill;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: Transform.rotate(
          angle: -5 * math.pi / 180,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _color, width: 2),
            ),
            child: Text(
              text.toUpperCase(),
              textScaler: TextScaler.noScaling,
              style: BB.stencilStyle(12, color: _color),
            ),
          ),
        ),
      );
}

/// A filter or choice chip: a 38 px outlined pill, coral on a lip when
/// selected. Material's ChoiceChip and FilterChip are themed to match.
class BBChip extends StatelessWidget {
  const BBChip(this.label, {super.key, this.selected = false, this.onTap, this.small = false});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 30 tall, for a chip that only labels something.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final h = small ? 30.0 : 38.0;
    final face = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: small ? 12 : 15),
      decoration: BoxDecoration(
        color: selected ? BB.coral : null,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? BB.ink : BB.dashed, width: 2),
        boxShadow: selected ? BB.lip(3) : null,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: BB.labelStyle(small ? 13 : 15, color: selected ? BB.ink : BB.cream, height: 1),
        ),
      ),
    );
    final chip = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      // Room for the lip whether or not it's showing, so rows don't jump.
      child: Padding(padding: const EdgeInsets.only(bottom: 3), child: face),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: onTap == null
          ? chip
          : Semantics(
              selected: selected,
              child: Pressable(
                onTap: onTap,
                builder: (context, down, focused) => Padding(
                  // Chips are 38 tall; the padding makes the target 44.
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: chip,
                ),
              ),
            ),
    );
  }
}

/// Chips in one row that scrolls sideways when it runs out of room.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: 8), c],
          ],
        ),
      );
}

/// Lilita One numerals with an ink outline and an ink drop, as in the card's
/// window. [stroke] is the full stroke width; half of it shows outside the
/// glyph.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.size,
    this.fill,
    this.stroke = 4,
    this.drop = 2.5,
    this.height = 1,
    this.letterSpacing,
  });

  final String text;
  final double size;
  final Color? fill;
  Color get _fill => fill ?? BB.cream;
  final double stroke;
  final double drop;
  final double height;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: BB.display,
      fontWeight: FontWeight.w400,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final outline = base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..color = BB.ink,
    );
    Widget layer(TextStyle style) =>
        Text(text, maxLines: 1, softWrap: false, textScaler: TextScaler.noScaling, style: style);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The drop is a copy of the glyphs alone, as a text shadow is.
        if (drop > 0)
          Transform.translate(
            offset: Offset(0, drop),
            child: ExcludeSemantics(child: layer(base.copyWith(color: BB.ink))),
          ),
        ExcludeSemantics(child: layer(outline)),
        layer(base.copyWith(color: _fill)),
      ],
    );
  }
}

/// BATTLE over BASEBALL, stacked. [height] is the height of the whole mark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 38});

  final double height;

  @override
  Widget build(BuildContext context) {
    // Drawn at 25 px over 12 px, 38.5 tall and about 84 wide.
    final s = height / 38.5;
    return Semantics(
      label: 'Battle Baseball',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BATTLE',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: BB.display,
                fontWeight: FontWeight.w400,
                fontSize: 25 * s,
                height: 0.9,
                letterSpacing: 25 * s * 0.035,
                color: BB.cream,
                leadingDistribution: TextLeadingDistribution.even,
                shadows: [Shadow(color: BB.ink, offset: Offset(0, 2 * s))],
              ),
            ),
            SizedBox(height: 4 * s),
            Text(
              'BASEBALL',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: BB.stencil,
                fontWeight: FontWeight.w400,
                fontSize: 12 * s,
                height: 1,
                letterSpacing: 12 * s * 0.115,
                color: BB.coral,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A drawn icon on its own as a 44 px button.
class IconTap extends StatelessWidget {
  const IconTap(this.glyph, {super.key, required this.label, required this.onTap, this.color});

  final BBGlyph glyph;

  /// What a screen reader says: "Copy code".
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  Color get _color => color ?? BB.ink;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: label,
        builder: (context, down, focused) => SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: focused ? _color : Colors.transparent, width: 2),
              ),
              child: Opacity(opacity: down ? 0.5 : 1, child: BBIcon(glyph, size: 21, color: _color)),
            ),
          ),
        ),
      );
}

/// A screen's title: Lilita 34 on phones, 44 on desktop.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.only(top: 6, bottom: 14)});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => _TitleRow(
        text: text,
        style: BB.title(BB.isWide(context) ? 44 : 34, drop: 4),
        trailing: trailing,
        padding: padding,
      );
}

/// A section's title: Lilita 28 on phones, 34 on desktop, on a 3 px drop.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.only(bottom: 16)});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => _TitleRow(
        text: text,
        style: BB.title(BB.isWide(context) ? 34 : 28, drop: 3),
        trailing: trailing,
        padding: padding,
      );
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.text, required this.style, required this.padding, this.trailing});

  final String text;
  final TextStyle style;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: Semantics(header: true, child: Text(text, style: style))),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      );
}

/// A screen's body: one scrolling column, centered and capped at [maxWidth],
/// with 16 px sides on phones and 40 on desktop. Children are stretched to
/// the column's width. It pads for the status bar and clears the bottom bar.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.maxWidth = BB.contentWidth,
    this.column,
    this.padding,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;

  /// For a narrow screen (a form, a list): the children keep to a column
  /// this wide. On desktop it sits at the frame's left edge, so the screen
  /// starts where every other screen does; below that it is centered.
  final double? column;

  /// Replaces the default padding around the content. Safe areas and the
  /// bottom bar are added on top of it.
  final EdgeInsets? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final safe = MediaQuery.paddingOf(context);
    final side = wide ? 40.0 : 16.0;
    final pad = padding ?? EdgeInsets.fromLTRB(side, 0, side, wide ? 72 : 30);
    return SingleChildScrollView(
      controller: controller,
      padding: pad + EdgeInsets.fromLTRB(safe.left, safe.top, safe.right, safe.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? maxWidth : column ?? maxWidth),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: column ?? double.infinity),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet spinner, centered, while something loads.
class LoadingField extends StatelessWidget {
  const LoadingField({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Semantics(
            label: 'Loading',
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: BB.creamSoft),
            ),
          ),
        ),
      );
}

/// One soft line for an empty state. No card around it.
class Quiet extends StatelessWidget {
  const Quiet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: BB.bodyStyle(16));
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      // Full width on a phone; a short slip at the bottom of a wide screen.
      width: BB.isWide(context) ? 420 : null,
      // The lip sits outside the snackbar's own box.
      clipBehavior: Clip.none,
      shape: LipShape(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: BB.ink, width: 2.5),
        ),
        lip: 4,
      ),
    ));
}

/// One line of the fine print.
class FinePrintItem {
  const FinePrintItem(this.text, {this.title});

  final String? title;
  final String text;
}

/// What the sheet says when a screen has nothing more specific.
const finePrint = <FinePrintItem>[
  FinePrintItem('A reserved spot is held for 24 hours while we confirm your payment.'),
  FinePrintItem("If we can't match a payment in that time, the spot opens to the waitlist."),
  FinePrintItem('Cancel at least 7 days before a showcase for a full refund.'),
  FinePrintItem('If rain cancels a showcase, pick a refund or a credit toward the next one.'),
  FinePrintItem('A parent or guardian signs the waiver for each player.'),
];

/// "The fine print": holds, refunds, rain and the waiver, kept off the main
/// screens. A bottom sheet on phones, a dialog on desktop.
Future<void> showFinePrint(
  BuildContext context, {
  List<FinePrintItem> items = finePrint,
  String title = 'The fine print',
  bool legal = true,
}) {
  Widget content(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: BB.title(26))),
                Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  label: 'Close',
                  builder: (context, down, focused) => SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: BBIcon(BBGlyph.close, size: 22, color: BB.cream)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.title != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(item.title!, style: BB.labelStyle(16)),
                      ),
                    Text(item.text, style: BB.bodyStyle(15.5, height: 1.45)),
                  ],
                ),
              ),
            if (legal)
              Wrap(
                spacing: 22,
                children: [
                  TextLink('Waiver', onTap: () => openSitePage('/waiver')),
                  TextLink('Terms', onTap: () => openSitePage('/terms')),
                  TextLink('Privacy', onTap: () => openSitePage('/privacy')),
                ],
              ),
          ],
        ),
      );
  if (BB.isWide(context)) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(child: content(context)),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    // Over the bottom bar, not under it.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(child: content(context)),
    ),
  );
}

/// The small drawn icons. Each is a few strokes on a 24 px grid.
enum BBGlyph {
  pennant,
  card,
  bars,
  jersey,
  back,
  forward,
  plus,
  minus,
  close,
  check,
  copy,
  share,
  edit,
  search,
  calendar,
  pin,
  tag,
  external,
}

class BBIcon extends StatelessWidget {
  const BBIcon(this.glyph, {super.key, this.size, this.color, this.semanticLabel});

  final BBGlyph glyph;

  /// Falls back to the surrounding [IconTheme], then 22.
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 22;
    final icon = CustomPaint(
      size: Size.square(s),
      painter: _GlyphPainter(glyph, color ?? theme.color ?? BB.cream),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: icon)
        : Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final BBGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final fill = Paint()..color = color;
    Paint line(double w) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
    switch (glyph) {
      case BBGlyph.pennant:
        final flag = Path()
          ..moveTo(5, 4.5)
          ..lineTo(20.5, 9.5)
          ..lineTo(5, 14.5)
          ..close();
        canvas.drawPath(flag, fill);
        canvas.drawPath(flag, line(1.6));
        canvas.drawLine(const Offset(5, 3), const Offset(5, 21), line(2.4));
      case BBGlyph.card:
        canvas.drawRRect(rr(5, 2.8, 14, 18.4, 2.6), line(2.2));
        canvas.drawRRect(rr(8, 6, 8, 6.2, 1), fill);
        canvas.drawLine(const Offset(8.5, 16.2), const Offset(15.5, 16.2), line(2));
      case BBGlyph.bars:
        canvas.drawRRect(rr(3.5, 13, 4.6, 8, 1.2), fill);
        canvas.drawRRect(rr(9.7, 8, 4.6, 13, 1.2), fill);
        canvas.drawRRect(rr(15.9, 3, 4.6, 18, 1.2), fill);
      case BBGlyph.jersey:
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 3.4)
            ..lineTo(4, 5.8)
            ..lineTo(2.6, 10.3)
            ..lineTo(6.3, 11.4)
            ..lineTo(6.3, 20.6)
            ..lineTo(17.7, 20.6)
            ..lineTo(17.7, 11.4)
            ..lineTo(21.4, 10.3)
            ..lineTo(20, 5.8)
            ..lineTo(15.5, 3.4)
            ..cubicTo(14.7, 5.6, 9.3, 5.6, 8.5, 3.4)
            ..close(),
          line(2.1),
        );
      case BBGlyph.back:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 5)
            ..lineTo(8, 12)
            ..lineTo(14.5, 19),
          line(2.6),
        );
      case BBGlyph.forward:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 5)
            ..lineTo(16, 12)
            ..lineTo(9.5, 19),
          line(2.6),
        );
      case BBGlyph.plus:
        canvas.drawLine(const Offset(12, 4.5), const Offset(12, 19.5), line(2.8));
        canvas.drawLine(const Offset(4.5, 12), const Offset(19.5, 12), line(2.8));
      case BBGlyph.minus:
        canvas.drawLine(const Offset(4.5, 12), const Offset(19.5, 12), line(2.8));
      case BBGlyph.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), line(2.6));
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), line(2.6));
      case BBGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 12.5)
            ..lineTo(9.8, 17.5)
            ..lineTo(19.5, 6.5),
          line(2.8),
        );
      case BBGlyph.copy:
        canvas.drawRRect(rr(8.5, 8.5, 11.5, 12, 2.4), line(2.2));
        canvas.drawPath(
          Path()
            ..moveTo(15.5, 5)
            ..lineTo(15.5, 4.6)
            ..quadraticBezierTo(15.5, 3, 13.9, 3)
            ..lineTo(5.6, 3)
            ..quadraticBezierTo(4, 3, 4, 4.6)
            ..lineTo(4, 13.4)
            ..quadraticBezierTo(4, 15, 5.4, 15),
          line(2.2),
        );
      case BBGlyph.share:
        canvas.drawLine(const Offset(12, 3.5), const Offset(12, 14.5), line(2.4));
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 7.5)
            ..lineTo(12, 3.2)
            ..lineTo(16.5, 7.5),
          line(2.4),
        );
        canvas.drawPath(
          Path()
            ..moveTo(5, 12)
            ..lineTo(5, 18.4)
            ..quadraticBezierTo(5, 20.5, 7.1, 20.5)
            ..lineTo(16.9, 20.5)
            ..quadraticBezierTo(19, 20.5, 19, 18.4)
            ..lineTo(19, 12),
          line(2.4),
        );
      case BBGlyph.edit:
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 19.5)
            ..lineTo(5.4, 15.2)
            ..lineTo(15.8, 4.8)
            ..lineTo(19.2, 8.2)
            ..lineTo(8.8, 18.6)
            ..close(),
          line(2.2),
        );
        canvas.drawLine(const Offset(13.6, 7), const Offset(17, 10.4), line(2.2));
      case BBGlyph.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6.2, line(2.4));
        canvas.drawLine(const Offset(15.2, 15.2), const Offset(20, 20), line(2.6));
      case BBGlyph.calendar:
        canvas.drawRRect(rr(3.5, 5.5, 17, 15, 2.6), line(2.2));
        canvas.drawLine(const Offset(3.8, 10.2), const Offset(20.2, 10.2), line(2.2));
        canvas.drawLine(const Offset(8, 3), const Offset(8, 7), line(2.4));
        canvas.drawLine(const Offset(16, 3), const Offset(16, 7), line(2.4));
      case BBGlyph.pin:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(7.5, 16, 5.5, 13, 5.5, 9.8)
            ..cubicTo(5.5, 6, 8.4, 3.2, 12, 3.2)
            ..cubicTo(15.6, 3.2, 18.5, 6, 18.5, 9.8)
            ..cubicTo(18.5, 13, 16.5, 16, 12, 21)
            ..close(),
          line(2.2),
        );
        canvas.drawCircle(const Offset(12, 9.8), 2.3, fill);
      case BBGlyph.tag:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 4.8)
            ..lineTo(3.5, 11.6)
            ..lineTo(12.6, 20.6)
            ..lineTo(20.6, 12.6)
            ..lineTo(11.6, 3.5)
            ..lineTo(4.8, 3.5)
            ..close(),
          line(2.2),
        );
        canvas.drawCircle(const Offset(8.2, 8.2), 1.7, fill);
      case BBGlyph.external:
        canvas.drawLine(const Offset(10, 14), const Offset(19.5, 4.5), line(2.4));
        canvas.drawPath(
          Path()
            ..moveTo(13, 4.2)
            ..lineTo(19.8, 4.2)
            ..lineTo(19.8, 11),
          line(2.4),
        );
        canvas.drawPath(
          Path()
            ..moveTo(9, 6.5)
            ..lineTo(6.6, 6.5)
            ..quadraticBezierTo(4.5, 6.5, 4.5, 8.6)
            ..lineTo(4.5, 17.4)
            ..quadraticBezierTo(4.5, 19.5, 6.6, 19.5)
            ..lineTo(15.4, 19.5)
            ..quadraticBezierTo(17.5, 19.5, 17.5, 17.4)
            ..lineTo(17.5, 15),
          line(2.4),
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}

/// Draws a dashed line from [a] to [b].
void paintDashes(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double dash = 7,
  double gap = 5,
}) {
  final total = (b - a).distance;
  if (total <= 0) return;
  final step = (b - a) / total;
  for (var d = 0.0; d < total; d += dash + gap) {
    canvas.drawLine(a + step * d, a + step * math.min(d + dash, total), paint);
  }
}

/// A dashed ink rule, the perforation on a ticket.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.axis = Axis.horizontal, this.color, this.thickness = 2});

  final Axis axis;
  final Color? color;
  Color get _color => color ?? BB.ink;
  final double thickness;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: axis == Axis.horizontal
            ? Size(double.infinity, thickness)
            : Size(thickness, double.infinity),
        painter: _DashPainter(axis, _color, thickness),
      );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.axis, this.color, this.thickness);

  final Axis axis;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    if (axis == Axis.horizontal) {
      paintDashes(canvas, Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      paintDashes(canvas, Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.axis != axis || old.color != color || old.thickness != thickness;
}
