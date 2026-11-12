// The player card and its relatives: the card front, award seals, the mini
// card and ruled rows that lists are made of, and the kraft card back with
// its captions, ruled tables and fastball chart.
import 'dart:math' as math;

import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:material_ui/material_ui.dart';

/// The mark that draws a small ink star on a seal (MVP).
const starMark = '*';

/// What a seal carries when it is too small for words: a star for MVP, the
/// award's initials otherwise ("TP").
String sealMark(String type) {
  if (type == 'mvp') return starMark;
  final label = awardTypes[type] ?? type;
  return label
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.substring(0, 1).toUpperCase())
      .take(3)
      .join();
}

String _number(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

double _textWidth(InlineSpan span) {
  final painter = TextPainter(text: span, textDirection: TextDirection.ltr, maxLines: 1)..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

/// The front of a player's card. Everything inside is sized in twentieths of
/// [width], so the same card prints at any size; small type stops at 11 px.
class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.profile,
    this.topFastball,
    this.awards = const [],
    this.width = 320,
    this.rotation = 0,
    this.sample = false,
    this.onTap,
  });

  final PublicProfile profile;

  /// The best fastball on record. Without one this is a rookie card: the
  /// window shows the jersey number, or the player's initials.
  final double? topFastball;
  final List<Award> awards;
  final double width;

  /// Tilt in degrees.
  final double rotation;

  /// Marks the built-in example for screen readers. Callers put a
  /// `Stamp('SAMPLE')` beside the card; nothing is drawn on it.
  final bool sample;
  final VoidCallback? onTap;

  static double _type(double u, double em) => math.max(em * u, 11);

  /// The height of a card of this width, lip included.
  static double heightFor(double width) {
    final u = width / 20;
    // Borders and padding, window, name, chips, rule, foot line, lip.
    return 1.42 * u + 17.4 * u + 2.89 * u + 0.48 * u + 1.46 * _type(u, 0.74) + 0.44 * u +
        _rule(u) + 0.527 * u + _type(u, 0.62) + 0.36 * u;
  }

  static double _rule(double u) => math.max(0.062 * u, 1);

  /// Awards in the order they are honored: MVP first.
  List<Award> get _ranked {
    final order = awardTypes.keys.toList();
    int rank(Award a) {
      final i = order.indexOf(a.type);
      return i < 0 ? order.length : i;
    }

    return [...awards]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  @override
  Widget build(BuildContext context) {
    final label = _semantics();
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: MediaQuery.withNoTextScaling(
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: onTap == null
                ? Semantics(
                    label: label,
                    container: true,
                    child: ExcludeSemantics(child: _card(false, false)),
                  )
                : Pressable(
                    onTap: onTap,
                    label: label,
                    builder: (context, down, focused) => _card(down, focused),
                  ),
          ),
        ),
      ),
    );
  }

  String _semantics() {
    final velo = topFastball;
    return [
      if (sample) 'Sample player card' else 'Player card',
      profile.name,
      if (velo != null) 'top fastball ${_number(velo)} miles per hour',
      for (final a in _ranked) a.label,
    ].join(', ');
  }

  Widget _card(bool down, bool focused) {
    final u = width / 20;
    final lip = 0.36 * u;
    final seals = _ranked;
    final shown = seals.take(2).toList();
    final velo = topFastball;
    final rookie = velo == null;
    final numeral = rookie ? (profile.jersey?.toString() ?? profile.initials) : _number(velo);
    final codes = profile.positionCodes.take(shown.isEmpty ? 5 : 3).toList();
    final chip = _type(u, 0.74);
    final caption = _type(u, 0.68);
    final roomBesideSeals = shown.length == 2 ? 9.7 * u : shown.length == 1 ? 13.2 * u : 17.48 * u;

    final window = Container(
      height: 17.4 * u,
      decoration: BoxDecoration(
        color: BB.coral,
        borderRadius: BorderRadius.circular(0.68 * u),
        border: Border.all(color: BB.ink, width: 0.14 * u),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0.54 * u),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BallPainter(u))),
            // Placed so the caps of BATTLE top out 0.77 of a twentieth down.
            Positioned(
              left: 0.85 * u,
              top: 0.77 * u - 0.115 * _MakersMark.emFor(u),
              child: _MakersMark(u: u),
            ),
            if (profile.jersey != null)
              Positioned(right: 0.7 * u, top: 0.7 * u, child: _Patch(number: profile.jersey!, u: u)),
            Positioned(
              left: 0.8 * u,
              right: 0.8 * u,
              bottom: 2.14 * u,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      OutlinedText(
                        numeral,
                        size: 10.4 * u,
                        stroke: 0.374 * u,
                        drop: 0.52 * u,
                        height: 0.76,
                        letterSpacing: -0.125 * u,
                      ),
                      if (!rookie) ...[
                        SizedBox(width: 0.5 * u),
                        Padding(
                          padding: EdgeInsets.only(bottom: 0.12 * u),
                          child: Text('MPH', style: BB.lilita(2 * u, height: 1)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0.68 * u,
              bottom: 0.73 * u - 0.045 * caption,
              child: Text(
                rookie ? 'ROOKIE CARD' : 'TOP FASTBALL',
                style: BB.caps(caption, color: BB.ink, tracking: 0.13),
              ),
            ),
          ],
        ),
      ),
    );

    final id = Padding(
      padding: EdgeInsets.fromLTRB(0.55 * u, 0.54 * u, 0.55 * u, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 2.35 * u,
            width: roomBesideSeals,
            // A long name shrinks to fit one line; it never wraps.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                profile.name,
                maxLines: 1,
                softWrap: false,
                style: BB.lilita(2.35 * u, height: 1).copyWith(letterSpacing: 0.012 * u),
              ),
            ),
          ),
          SizedBox(height: 0.48 * u),
          SizedBox(
            height: 1.46 * chip,
            width: shown.length == 2 ? 10.4 * u : 17.48 * u,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (final (i, code) in codes.indexed)
                    Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 0.333 * u),
                      padding: EdgeInsets.fromLTRB(0.5 * chip, 0.26 * chip, 0.5 * chip, 0.2 * chip),
                      decoration: BoxDecoration(
                        color: BB.ink,
                        borderRadius: BorderRadius.circular(0.38 * chip),
                      ),
                      child: Text(code, style: BB.caps(chip, color: BB.cream, tracking: 0.09)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final foot = Container(
      margin: EdgeInsets.fromLTRB(0.34 * u, 0.44 * u, 0.34 * u, 0),
      padding: EdgeInsets.only(top: 0.341 * u, bottom: 0.186 * u),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: BB.ink, width: _rule(u)))),
      child: _foot(u),
    );

    final face = Container(
      width: width,
      padding: EdgeInsets.all(0.55 * u),
      decoration: BoxDecoration(
        color: BB.cream,
        borderRadius: BorderRadius.circular(1.15 * u),
        border: Border.all(color: BB.ink, width: 0.16 * u),
        boxShadow: [
          if (focused) BoxShadow(color: BB.cream, spreadRadius: 0.2 * u),
          if (!down) BoxShadow(color: BB.ink, offset: Offset(0, lip)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [window, id, foot],
      ),
    );

    // Seals are pressed on over the bottom edge of the window, biting into
    // it: the first by about half its height, the second by its points.
    final windowBottom = 18.11 * u;
    final sealSize = 4.6 * u;
    Widget seal(Award a, double left, double top, double degrees) => Positioned(
          left: left,
          top: top,
          child: Transform.rotate(
            angle: degrees * math.pi / 180,
            child: AwardSeal(label: a.label, mark: sealMark(a.type), size: sealSize),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(top: down ? lip : 0, bottom: down ? 0 : lip),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          face,
          if (shown.length == 2) seal(shown[1], 11.64 * u, windowBottom - 0.85 * u, 9),
          if (shown.isNotEmpty) seal(shown[0], 14.74 * u, windowBottom - 2.2 * u, -11),
          if (seals.length > 2)
            Positioned(
              right: 0.95 * u,
              top: 21.1 * u,
              child: Container(
                height: math.max(1.4 * u, 17),
                padding: EdgeInsets.symmetric(horizontal: 0.4 * u),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BB.ink,
                  borderRadius: BorderRadius.circular(0.4 * u),
                ),
                child: Text(
                  '+${seals.length - 2}',
                  style: BB.lilita(_type(u, 0.85), color: BB.cream, height: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The line under the rule. It carries as much as fits at 11 px: the
  /// state spelled out on a wide card, its code on a narrower one, and
  /// bats and throws folded together on the smallest.
  Widget _foot(double u) {
    final size = _type(u, 0.62);
    final soft = BB.caps(size, color: BB.ink2, tracking: 0.09, weight: FontWeight.w600);
    final strong = BB.caps(size, color: BB.ink, tracking: 0.09);
    TextSpan pair(String label, String value) => TextSpan(children: [
          TextSpan(text: '$label ', style: soft),
          TextSpan(text: value, style: strong),
        ]);
    final p = profile;
    final year = p.gradYear == null ? null : pair('CLASS OF', '${p.gradYear}');
    final code = p.state.trim().toUpperCase();
    final state = _stateNames[code];
    final variants = <List<InlineSpan>>[
      if (state != null)
        [?year, pair('BATS', p.bats), pair('THROWS', p.throws), TextSpan(text: state, style: soft)],
      [
        ?year,
        pair('BATS', p.bats),
        pair('THROWS', p.throws),
        if (code.isNotEmpty) TextSpan(text: code, style: soft),
      ],
      [
        ?year,
        pair('B/T', '${p.bats}/${p.throws}'),
        if (code.isNotEmpty) TextSpan(text: code, style: soft),
      ],
    ];
    final room = 17.9 * u;
    final gap = 0.5 * u;
    double need(List<InlineSpan> v) =>
        v.fold<double>(0, (w, s) => w + _textWidth(s)) + (v.length - 1) * gap;
    final parts = variants.firstWhere((v) => need(v) <= room, orElse: () => variants.last);
    final texts = [for (final s in parts) Text.rich(s, maxLines: 1, softWrap: false)];
    return SizedBox(
      height: size,
      width: room,
      child: need(parts) <= room
          ? Row(
              mainAxisAlignment:
                  parts.length > 1 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
              children: texts,
            )
          // Nothing fits at 11 px on a card this small: shrink the shortest line.
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (final (i, t) in texts.indexed) ...[if (i > 0) SizedBox(width: gap), t],
                ],
              ),
            ),
    );
  }
}

/// BATTLE over BASEBALL in ink, the maker's mark in the window's corner.
class _MakersMark extends StatelessWidget {
  const _MakersMark({required this.u});
  final double u;

  /// Drawn 1 over 0.5 of a twentieth, but never with BASEBALL under 11 px.
  static double emFor(double u) => math.max(u, 22);

  @override
  Widget build(BuildContext context) {
    final em = emFor(u);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BATTLE', style: BB.lilita(em, height: 0.9).copyWith(letterSpacing: em * 0.035)),
        SizedBox(height: 0.3 * em * 0.5),
        Text('BASEBALL', style: BB.stencilStyle(em * 0.5, tracking: 0.1)),
      ],
    );
  }
}

/// The jersey number as a stitched patch.
class _Patch extends StatelessWidget {
  const _Patch({required this.number, required this.u});
  final int number;
  final double u;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 3.5 * u,
        child: CustomPaint(
          painter: _PatchPainter(u),
          child: Center(
            child: SizedBox(
              width: 2.5 * u,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$number', style: BB.lilita(1.7 * u, color: BB.cream, height: 1)),
              ),
            ),
          ),
        ),
      );
}

class _PatchPainter extends CustomPainter {
  const _PatchPainter(this.u);
  final double u;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = BB.ink);
    final stitch = Paint()
      ..color = BB.cream.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.075 * u;
    final ring = r - 0.24 * u - 0.0375 * u;
    const dashes = 22;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: ring), i * sweep, sweep * 0.58, false, stitch);
    }
  }

  @override
  bool shouldRepaint(_PatchPainter old) => old.u != u;
}

/// The tone-on-tone baseball in the window's corner, with its stitched seam.
class _BallPainter extends CustomPainter {
  const _BallPainter(this.u);
  final double u;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on the mock's 293 by 274 art board, pinned to the bottom right.
    final k = u / 16;
    canvas.translate(size.width - 293 * k, size.height - 274 * k);
    canvas.scale(k);
    canvas.drawCircle(const Offset(318, 262), 128, Paint()..color = BB.coralDeep);
    const center = Offset(200, 150);
    const radius = 95.0;
    const start = -10.0 * math.pi / 180;
    const sweep = 105.0 * math.pi / 180;
    final seam = Paint()
      ..color = BB.seam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, seam);
    final stitch = Paint()
      ..color = BB.seam
      ..strokeWidth = 2.5;
    for (var d = 1.25; d < radius * sweep; d += 11.5) {
      final a = start + d / radius;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * (radius - 6.5), center + dir * (radius + 6.5), stitch);
    }
  }

  @override
  bool shouldRepaint(_BallPainter old) => old.u != u;
}

const _stateNames = <String, String>{
  'AL': 'ALABAMA', 'AK': 'ALASKA', 'AZ': 'ARIZONA', 'AR': 'ARKANSAS', 'CA': 'CALIFORNIA',
  'CO': 'COLORADO', 'CT': 'CONNECTICUT', 'DE': 'DELAWARE', 'FL': 'FLORIDA', 'GA': 'GEORGIA',
  'HI': 'HAWAII', 'ID': 'IDAHO', 'IL': 'ILLINOIS', 'IN': 'INDIANA', 'IA': 'IOWA',
  'KS': 'KANSAS', 'KY': 'KENTUCKY', 'LA': 'LOUISIANA', 'ME': 'MAINE', 'MD': 'MARYLAND',
  'MA': 'MASSACHUSETTS', 'MI': 'MICHIGAN', 'MN': 'MINNESOTA', 'MS': 'MISSISSIPPI', 'MO': 'MISSOURI',
  'MT': 'MONTANA', 'NE': 'NEBRASKA', 'NV': 'NEVADA', 'NH': 'NEW HAMPSHIRE', 'NJ': 'NEW JERSEY',
  'NM': 'NEW MEXICO', 'NY': 'NEW YORK', 'NC': 'NORTH CAROLINA', 'ND': 'NORTH DAKOTA', 'OH': 'OHIO',
  'OK': 'OKLAHOMA', 'OR': 'OREGON', 'PA': 'PENNSYLVANIA', 'RI': 'RHODE ISLAND', 'SC': 'SOUTH CAROLINA',
  'SD': 'SOUTH DAKOTA', 'TN': 'TENNESSEE', 'TX': 'TEXAS', 'UT': 'UTAH', 'VT': 'VERMONT',
  'VA': 'VIRGINIA', 'WA': 'WASHINGTON', 'WV': 'WEST VIRGINIA', 'WI': 'WISCONSIN', 'WY': 'WYOMING',
  'DC': 'WASHINGTON DC',
};

/// A sixteen-point lemon seal with an ink outline on an ink drop. It prints
/// [label] when the words fit at 11 px or more, and falls back to [mark]
/// (a star for [starMark], otherwise a couple of letters) when they don't.
class AwardSeal extends StatelessWidget {
  const AwardSeal({super.key, this.label, this.size = 74, this.mark, this.drop = 0.07});

  final String? label;
  final double size;
  final String? mark;

  /// How far the ink copy sits below the seal, as a share of [size].
  final double drop;

  Widget? _inside() {
    final words = (label ?? '').toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length == 1 && words.first.length <= 4) {
      final style = BB.lilita(math.max(0.3 * size, 11), height: 1).copyWith(letterSpacing: 0.006 * size);
      if (_textWidth(TextSpan(text: words.first, style: style)) <= 0.76 * size) {
        return Text(words.first, style: style);
      }
    } else if (words.isNotEmpty) {
      final fs = math.max(0.13 * size, 11.0);
      final style = BB.caps(fs, color: BB.ink, tracking: 0.04).copyWith(height: 1.02);
      final lines = [words.first, if (words.length > 1) words.skip(1).join(' ')];
      final widest = lines
          .map((l) => _textWidth(TextSpan(text: l, style: style)))
          .fold<double>(0, (a, b) => math.max(a, b));
      // The widest chord a two-line block can use inside the foil.
      final r = 0.4 * size;
      final reach = lines.length * fs * 0.5;
      if (reach < r && widest <= 2 * math.sqrt(r * r - reach * reach)) {
        return Text(lines.join('\n'), textAlign: TextAlign.center, style: style);
      }
    }
    final m = mark;
    if (m == null || m.isEmpty) return null;
    if (m == starMark) {
      return CustomPaint(size: Size.square(0.5 * size), painter: const _StarPainter());
    }
    return Text(m, style: BB.lilita(math.max(0.34 * size, 11), height: 1));
  }

  @override
  Widget build(BuildContext context) {
    final inside = _inside();
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: MediaQuery.withNoTextScaling(
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _SealPainter(drop * size),
              child: inside == null ? null : Center(child: inside),
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter(this.drop);
  final double drop;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width;
    final path = Path();
    for (var i = 0; i < 32; i++) {
      final a = i * math.pi / 16 - math.pi / 2;
      final r = (i.isEven ? 0.47 : 0.415) * s;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    final outline = Paint()
      ..color = BB.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * s
      ..strokeJoin = StrokeJoin.round;
    if (drop > 0) {
      final under = path.shift(Offset(0, drop));
      canvas.drawPath(under, Paint()..color = BB.ink);
      canvas.drawPath(under, outline);
    }
    canvas.drawPath(path, Paint()..color = BB.lemon);
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.drop != drop;
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2;
      final r = (i.isEven ? 0.5 : 0.21) * size.width;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = BB.ink
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = BB.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

/// The big card, shrunk to a row: rank, name, and the coral window with the
/// outlined numeral. Leaderboards use it for the top three, the Players
/// directory for every tile.
class MiniCard extends StatelessWidget {
  const MiniCard({
    super.key,
    this.rank,
    required this.name,
    this.sub,
    this.value,
    this.unit,
    this.first = false,
    this.dot = false,
    this.onTap,
  });

  /// Leave out for a directory tile.
  final int? rank;
  final String name;

  /// The small caps line under the name ("CLASS OF 2031").
  final String? sub;

  /// What the window shows: a reading, or a rookie's number or initials.
  final String? value;

  /// "MPH" or "SEC", set small beside the numeral.
  final String? unit;

  /// First place: taller, with the lemon seal behind the rank.
  final bool first;

  /// A small coral dot before the name, for the family's own player.
  final bool dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final h = first ? 80.0 : wide ? 66.0 : 62.0;
    final v = value;
    // Two digits print at full size; "67.5" and "2.04" step down so the
    // unit beside them keeps its size.
    final long = (v?.length ?? 0) - 2;
    final numeral = first
        ? (long <= 0 ? 48.0 : long == 1 ? 40.0 : 32.0)
        : (long <= 0 ? 35.0 : long == 1 ? 31.0 : 27.0);
    final row = SizedBox(
      height: h - 5,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rank != null)
            SizedBox(
              width: wide ? 58 : 50,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (first) const AwardSeal(size: 44, drop: 0),
                    Text('$rank', textScaler: TextScaler.noScaling, style: BB.lilita(first ? 26 : 25, height: 1)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (dot) const _Dot(),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: BB.labelStyle(first ? 22 : wide ? 20 : 19, color: BB.ink, height: 1.05),
                        ),
                      ),
                    ],
                  ),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      sub!.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: BB.caps(11.5, color: BB.ink2, tracking: 0.11, weight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (v != null && v.isNotEmpty)
            Container(
              width: wide ? 128 : 112,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
              decoration: const BoxDecoration(
                color: BB.coral,
                border: Border(left: BorderSide(color: BB.ink, width: 2.5)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedText(v, size: numeral, stroke: first ? 5 : 4, drop: first ? 3 : 2.5),
                    if (unit != null && unit!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(left: 6, top: numeral * (first ? 0.417 : 0.343)),
                        child: Text(
                          unit!.toUpperCase(),
                          textScaler: TextScaler.noScaling,
                          style: BB.caps(11, color: BB.ink),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return LipBox(
      radius: 14,
      onTap: onTap,
      semanticLabel: [
        if (rank != null) 'Number $rank',
        name,
        if (sub != null && sub!.isNotEmpty) sub!,
        if (v != null && v.isNotEmpty) '$v ${unit ?? ''}'.trim(),
      ].join(', '),
      child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.25, child: row),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(
          color: BB.coral,
          shape: BoxShape.circle,
          border: Border.all(color: BB.ink, width: 1.5),
        ),
      );
}

/// The cream panel that holds ruled rows: rank four and below on a
/// leaderboard, or a stat table when [columns] names its cells.
class RuledPanel extends StatelessWidget {
  const RuledPanel({super.key, required this.children, this.columns = const []});

  final List<Widget> children;

  /// Small caps headers over each row's cells, right aligned to match.
  final List<String> columns;

  @override
  Widget build(BuildContext context) => LipBox(
        radius: 14,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (columns.isNotEmpty)
                Container(
                  height: 34,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: BB.ink, width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      for (final (i, c) in columns.indexed)
                        SizedBox(
                          width: RuledRow.cellWidth(i, columns.length),
                          child: Text(
                            c.toUpperCase(),
                            textAlign: TextAlign.center,
                            textScaler: TextScaler.noScaling,
                            style: BB.caps(11, color: BB.ink, tracking: 0.12),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final (i, child) in children.indexed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0 ? null : const Border(top: BorderSide(color: BB.inkRule, width: 1.5)),
                  ),
                  child: child,
                ),
            ],
          ),
        ),
      );
}

/// One 60 px row on a [RuledPanel]: an ink rank, the name with the class
/// year set small after it, and the reading in Lilita at the right, or a
/// run of [cells] under the panel's column headers.
class RuledRow extends StatelessWidget {
  const RuledRow({
    super.key,
    this.rank,
    required this.name,
    this.sub,
    this.value,
    this.unit,
    this.cells = const [],
    this.dot = false,
    this.onTap,
  });

  final int? rank;
  final String name;

  /// Set small after the name ("2031").
  final String? sub;
  final String? value;
  final String? unit;

  /// Stat cells, used instead of [value] when not empty.
  final List<String> cells;

  /// A small coral dot before the name, for the family's own player.
  final bool dot;
  final VoidCallback? onTap;

  /// Cells are 40 wide; the last of several is wider, for an average.
  static double cellWidth(int index, int count) => count > 1 && index == count - 1 ? 58 : 40;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 60,
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 36,
              child: Text('$rank', textScaler: TextScaler.noScaling, style: BB.lilita(23, height: 1)),
            ),
          if (dot) const _Dot(),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: name, style: BB.labelStyle(19, color: BB.ink, height: 1.1)),
                if (sub != null && sub!.isNotEmpty)
                  TextSpan(
                    text: '  ${sub!}',
                    style: BB.bodyStyle(13.5, color: BB.ink2, height: 1.1),
                  ),
              ]),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (cells.isNotEmpty)
            for (final (i, c) in cells.indexed)
              SizedBox(
                width: cellWidth(i, cells.length),
                child: Text(
                  c,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: BB.lilita(i == cells.length - 1 && cells.length > 1 ? 20 : 19, height: 1),
                ),
              )
          else if (value != null) ...[
            const SizedBox(width: 10),
            Text(value!, textScaler: TextScaler.noScaling, style: BB.lilita(30, height: 1)),
            if (unit != null && unit!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 9),
                child: Text(
                  unit!.toUpperCase(),
                  textScaler: TextScaler.noScaling,
                  style: BB.caps(11, color: BB.ink2),
                ),
              ),
          ],
        ],
      ),
    );
    final clamped = MediaQuery.withClampedTextScaling(maxScaleFactor: 1.25, child: row);
    if (onTap == null) return clamped;
    return Pressable(
      onTap: onTap,
      builder: (context, down, focused) => Opacity(opacity: down ? 0.6 : 1, child: clamped),
    );
  }
}

/// The back of the card: kraft stock, ink outline and lip. Children are the
/// sections, spaced [gap] apart.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.children, this.padding, this.gap = 20, this.large = false});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double gap;

  /// The desktop panel: a heavier outline, rounder corners, more room.
  final bool large;

  @override
  Widget build(BuildContext context) => LipBox(
        color: BB.kraft,
        radius: large ? 22 : 18,
        border: large ? 3 : 2.5,
        lip: large ? 6 : 5,
        child: Padding(
          padding: padding ?? EdgeInsets.all(large ? 22 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) SizedBox(height: gap),
                child,
              ],
            ],
          ),
        ),
      );
}

/// A stencil caption over a section of the card back ("FASTBALL"), with an
/// optional outlined tag at the right ("+7 MPH").
class BackCaption extends StatelessWidget {
  const BackCaption(this.text, {super.key, this.tag});

  final String text;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 10 : 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), style: BB.stencilStyle(wide ? 15 : 13.5)),
            ),
          ),
          if (tag != null)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: BB.ink, width: 1.5),
              ),
              child: Text(tag!.toUpperCase(), style: BB.caps(11.5, color: BB.ink)),
            ),
        ],
      ),
    );
  }
}

/// One award in a list: a small seal carrying [mark], the award's name, and
/// a line under it ("Spring Showcase 12U"). Ink on paper by default; pass
/// [onPaper] false to set it in cream on the field.
class AwardLine extends StatelessWidget {
  const AwardLine({
    super.key,
    required this.title,
    this.sub,
    this.mark,
    this.tilt = -8,
    this.onPaper = true,
  });

  final String title;
  final String? sub;

  /// See [sealMark].
  final String? mark;

  /// The seal's tilt in degrees; alternate it down a list.
  final double tilt;
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final size = BB.isWide(context) ? 39.6 : 36.8;
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Transform.rotate(
            angle: tilt * math.pi / 180,
            child: ExcludeSemantics(child: AwardSeal(mark: mark, size: size, drop: 0.05)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BB.lilita(20, color: onPaper ? BB.ink : BB.cream, height: 1)),
              if (sub != null && sub!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    sub!,
                    style: BB.labelStyle(13.5, color: onPaper ? BB.ink2 : BB.creamSoft, height: 1.2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The foot of the card back: a rule, a small caps note at the left and the
/// stencil maker's mark at the right.
class BackFoot extends StatelessWidget {
  const BackFoot({super.key, this.note});

  /// For example "4 SHOWCASES". Leave out when there is nothing to count.
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: BB.ink, width: 1.5))),
        child: Row(
          children: [
            Expanded(
              child: note == null
                  ? const SizedBox.shrink()
                  : Text(note!.toUpperCase(), style: BB.caps(11, color: BB.ink2, tracking: 0.09, weight: FontWeight.w600)),
            ),
            Text('BATTLE BASEBALL', style: BB.stencilStyle(11, tracking: 0.1)),
          ],
        ),
      );
}

/// A ruled table of stats: small caps labels on an ink bar over Lilita
/// numbers, with ink rules between columns.
class RuledTable extends StatelessWidget {
  const RuledTable({
    super.key,
    required this.headers,
    required this.values,
    this.units = const [],
    this.highlightLast = false,
    this.vertical = false,
    this.large,
  });

  final List<String> headers;
  final List<String> values;

  /// A small caps unit after each value ("SEC"); may be shorter than [values].
  final List<String?> units;

  /// Sets the last cell wider and on cream, for AVG.
  final bool highlightLast;

  /// Stacks the cells instead of setting them side by side.
  final bool vertical;

  /// Desktop sizes. Follows the breakpoint when left out.
  final bool? large;

  @override
  Widget build(BuildContext context) {
    final big = large ?? BB.isWide(context);
    final n = math.min(headers.length, values.length);
    Widget cell(int i) {
      final key = highlightLast && i == n - 1;
      final unit = i < units.length ? units[i] : null;
      final size = vertical ? 34.0 : big ? 28.0 : 23.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: BB.ink,
            padding: big ? const EdgeInsets.fromLTRB(2, 6, 2, 5) : const EdgeInsets.fromLTRB(2, 5, 2, 4),
            child: SizedBox(
              height: big ? 11.5 : 11,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  headers[i].toUpperCase(),
                  style: BB.caps(big ? 11.5 : 11, color: BB.kraft, tracking: 0.12),
                ),
              ),
            ),
          ),
          Container(
            color: key ? BB.cream : null,
            padding: vertical
                ? const EdgeInsets.fromLTRB(4, 15, 4, 14)
                : big
                    ? const EdgeInsets.fromLTRB(4, 11, 4, 10)
                    : const EdgeInsets.fromLTRB(3, 8, 3, 7),
            child: SizedBox(
              height: size,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(values[i], style: BB.lilita(size, height: 1)),
                    if (unit != null && unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(unit.toUpperCase(), style: BB.caps(11, color: BB.ink)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    const rule = BorderSide(color: BB.ink, width: 1.5);
    return MediaQuery.withNoTextScaling(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BB.ink, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < n; i++)
                      DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(border: i == 0 ? null : const Border(top: rule)),
                        child: cell(i),
                      ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        flex: highlightLast && i == n - 1 ? 155 : 100,
                        child: DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(border: i == 0 ? null : const Border(left: rule)),
                          child: cell(i),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Fastball by showcase, oldest first: a coral area under an ink line, the
/// reading over each dot and a tick label under it. With a single reading
/// there is no line to draw, so it prints the number alone.
class VeloChart extends StatelessWidget {
  const VeloChart({super.key, required this.values, this.labels = const [], this.unit = 'MPH'});

  final List<double> values;

  /// One short label per value ("SPR 11U").
  final List<String> labels;
  final String unit;

  /// "+7 MPH" when the latest reading beats the first, otherwise null.
  static String? gain(List<double> values, {String unit = 'MPH'}) {
    if (values.length < 2) return null;
    final up = values.last - values.first;
    return up > 0 ? '+${_number(up)} $unit' : null;
  }

  @override
  Widget build(BuildContext context) {
    // The last six fit on a phone without the ticks touching.
    final from = math.max(0, values.length - 6);
    final shown = values.sublist(from);
    final ticks = [
      for (var i = from; i < values.length; i++) i < labels.length ? labels[i].toUpperCase() : '',
    ];
    final panel = BoxDecoration(
      color: BB.cream,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: BB.ink, width: 2),
    );
    if (shown.isEmpty) return const SizedBox.shrink();
    if (shown.length == 1) {
      return MediaQuery.withNoTextScaling(
        child: Container(
          decoration: panel,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_number(shown.first), style: BB.lilita(60, height: 1)),
                  const SizedBox(width: 8),
                  Text(unit, style: BB.lilita(22, height: 1)),
                ],
              ),
              if (ticks.first.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(ticks.first, style: BB.caps(11, color: BB.ink, tracking: 0.12)),
              ],
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: 'Fastball at ${shown.length} showcases: ${shown.map(_number).join(', ')} $unit',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = (w * 178 / 330).clamp(170.0, 236.0);
            return Container(
              decoration: panel,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(size: Size(w - 4, h), painter: _ChartPainter(shown, ticks)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.ticks);

  final List<double> values;
  final List<String> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    // Laid out on the mock's 330 by 178 board and stretched to fit; type
    // keeps its own size.
    final sx = size.width / 330, sy = size.height / 178;
    final n = values.length;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final left = 50 * sx, right = size.width - 49 * sx;
    final base = 151 * sy;
    Offset at(int i) => Offset(
          left + (right - left) * i / (n - 1),
          (hi == lo ? 86 : 111.2 - (values[i] - lo) / (hi - lo) * 50.4) * sy,
        );
    final points = [for (var i = 0; i < n; i++) at(i)];
    final peak = values.lastIndexOf(hi);

    final grid = Paint()
      ..color = BB.inkRule
      ..strokeWidth = 1.5;
    for (final y in const [32.0, 68.0, 104.0, 140.0]) {
      canvas.drawLine(Offset(0, y * sy), Offset(size.width, y * sy), grid);
    }
    final area = Path()..moveTo(points.first.dx, base);
    for (final p in points) {
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(points.last.dx, base)
      ..close();
    canvas.drawPath(area, Paint()..color = BB.coral);
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = BB.ink
        ..strokeWidth = 2,
    );
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = BB.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final ring = Paint()
      ..color = BB.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var i = 0; i < n; i++) {
      if (i == peak) {
        canvas.drawCircle(points[i], 8, Paint()..color = BB.ink);
      } else {
        canvas.drawCircle(points[i], 6.5, Paint()..color = BB.cream);
        canvas.drawCircle(points[i], 6.5, ring);
      }
    }

    void text(String s, TextStyle style, Offset center, {required double baseline}) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final ascent = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      painter.paint(canvas, Offset(center.dx - painter.width / 2, baseline - ascent));
      painter.dispose();
    }

    for (var i = 0; i < n; i++) {
      final isPeak = i == peak;
      text(
        _number(values[i]),
        BB.lilita(isPeak ? 30 : 21, height: 1),
        points[i],
        baseline: points[i].dy - (isPeak ? 17.8 : 15.2),
      );
    }

    final tick = BB.caps(11, color: BB.ink, tracking: 0.12);
    final gap = (right - left) / (n - 1);
    double widest(List<String> list) => list
        .map((s) => _textWidth(TextSpan(text: s, style: tick)))
        .fold<double>(0, (a, b) => math.max(a, b));
    var labels = ticks;
    if (widest(labels) > gap - 6) {
      // Keep the season, drop the age group.
      labels = [for (final t in ticks) t.split(' ').first];
    }
    final crowded = widest(labels) > gap - 6;
    for (var i = 0; i < n; i++) {
      if (labels[i].isEmpty || (crowded && i != 0 && i != n - 1)) continue;
      text(labels[i], tick, points[i], baseline: 168 * sy);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values || old.ticks != ticks;
}
