// Merch: the Battle Baseball shop. A section on Home, the shop itself
// (/merch), a page for each shirt (/merch/<handle>) and the cart
// (/merch/cart). The shirts, prices and sizes are read from the Shopify
// store (data/shop.dart), and paying happens on Shopify's checkout page.
// Until the Shopify store opens to the public this is a "Coming soon" page.
//
// Battle Shop is the same shop on a site of its own (data/site.dart), at
// that site's front page, with a shirt at /<handle> and the cart at /cart:
// these screens under their own name, with no way into the rest of the app.
// There it is dressed as a storefront: a band across the top with its mark
// and the Cart, a ticker and a headline over the shirts, prices on gold
// tags, and a footer. ShopSite says which of the two a screen is showing in.
import 'dart:async';
import 'dart:math' as math;

import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/shop.dart';
import 'package:battle_baseball/data/shop_html.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The shirts shown while the shop is still coming soon, each a photo and a
/// name.
const merchItems = <({String name, String image})>[
  (name: 'Military Green Tee', image: 'assets/merch/military-green-tee.jpg'),
  (name: 'Royal Blue Tee', image: 'assets/merch/royal-blue-tee.jpg'),
];

/// Where the shop is showing: in the Battle Baseball app as Merch, or on
/// its own as Battle Shop. The screens ask it for their addresses and names.
class ShopSite {
  const ShopSite._({required this.root, required this.title, required this.back, required this.standalone});

  /// Merch, a part of the Battle Baseball app.
  static const merch = ShopSite._(root: '/merch', title: 'Merch', back: 'Merch', standalone: false);

  /// Battle Shop: a site of its own, with nothing of the Battle Baseball
  /// app around it and no link into it. The shop is its front page.
  static const battleShop = ShopSite._(root: '', title: 'Battle Shop', back: 'Shop', standalone: true);

  /// Where the shop's addresses start; a shirt is at `<root>/<handle>` and
  /// the cart at `<root>/cart`.
  final String root;

  /// The shop's first page.
  String get home => root.isEmpty ? '/' : root;
  final String title;

  /// What the back link on a shirt's page and the cart says.
  final String back;
  final bool standalone;

  /// Merch, unless a [BattleShopShell] is above.
  static ShopSite of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShopSiteScope>()?.site ?? merch;
}

class _ShopSiteScope extends InheritedWidget {
  const _ShopSiteScope({required this.site, required super.child});

  final ShopSite site;

  @override
  bool updateShouldNotify(_ShopSiteScope old) => old.site != site;
}

/// The frame around Battle Shop's screens, in place of the app's shell: no
/// tabs, no sign-in and no way Home. A band across the top carries the Battle
/// Shop mark and the Cart on every screen, at every width.
class BattleShopShell extends StatelessWidget {
  const BattleShopShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _ShopSiteScope(
        site: ShopSite.battleShop,
        child: Scaffold(
          body: Column(
            children: [
              // Like the app's top bar, its words only grow so far.
              MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15, child: const _BattleShopBar()),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The field, mown: it stays put while a page scrolls over it.
                    ExcludeSemantics(
                      child: RepaintBoundary(child: CustomPaint(painter: _MownPainter(BB.cream.withAlpha(0x0A)))),
                    ),
                    MediaQuery.removePadding(context: context, removeTop: true, child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// A ballpark's mowing: wide bands leaning to the right, every other one a
/// touch lighter than the field.
class _MownPainter extends CustomPainter {
  const _MownPainter(this.color);

  final Color color;

  static const _band = 150.0;

  @override
  void paint(Canvas canvas, Size size) {
    final lean = size.height * 0.36;
    final paint = Paint()..color = color;
    canvas.clipRect(Offset.zero & size);
    for (var x = -lean - _band; x < size.width + _band; x += _band * 2) {
      canvas.drawPath(
        Path()
          ..moveTo(x + lean, 0)
          ..lineTo(x + lean + _band, 0)
          ..lineTo(x + _band, size.height)
          ..lineTo(x, size.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MownPainter old) => old.color != color;
}

/// The darker blue of Battle Shop's band and footer: the field with ink over
/// it, so it follows whatever scheme is in use. tools/build_hosting.mjs
/// mixes the same color for the loading screen.
Color _bandColor() => Color.alphaBlend(BB.ink.withAlpha(0x4D), BB.field);

/// Battle Shop's name as its band shows it: the baseball tank off the shirts,
/// then BATTLE over SHOP. [height] is the wordmark's.
class ShopMark extends StatelessWidget {
  const ShopMark({super.key, this.height = 48});

  final double height;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'assets/brand/tank.png',
              height: height * 0.9,
              filterQuality: FilterQuality.medium,
            ),
          ),
          SizedBox(width: height * 0.24),
          Wordmark(height: height, second: 'Shop'),
        ],
      );
}

/// Battle Shop's band: the mark, which leads to the shop's first page, and
/// the Cart, over a gold stripe. 116 tall on desktop and 76 on phones, on a
/// 3 px ink edge. tools/build_hosting.mjs draws the same band while the app
/// loads, so keep the two in step.
class _BattleShopBar extends StatelessWidget {
  const _BattleShopBar();

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final safe = MediaQuery.paddingOf(context);
    return Container(
      decoration: BoxDecoration(
        color: _bandColor(),
        border: Border(bottom: BorderSide(color: BB.ink, width: 3)),
      ),
      padding: EdgeInsets.only(top: safe.top),
      child: SizedBox(
        height: wide ? 116 : 76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: safe.left, right: safe.right),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16),
                      child: Row(
                        children: [
                          // The mark gives way on a narrow phone, so the Cart always fits.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Pressable(
                                    onTap: () => context.go(ShopSite.battleShop.home),
                                    label: 'Battle Shop, all shirts',
                                    builder: (context, down, focused) => Opacity(
                                      opacity: down ? 0.75 : 1,
                                      child: ShopMark(height: wide ? 70 : 46),
                                    ),
                                  ),
                                  if (Repo.stampDemo) ...[
                                    SizedBox(width: wide ? 24 : 12),
                                    Stamp(wide ? 'SAMPLE DATA' : 'SAMPLE'),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CartButton(band: true, small: !wide),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The stripe runs the window's whole width, between two ink lines:
            // this one and the band's edge.
            ColoredBox(color: BB.ink, child: const SizedBox(height: 3)),
            ColoredBox(color: BB.coral, child: SizedBox(height: wide ? 6 : 5)),
          ],
        ),
      ),
    );
  }
}

/// Battle Shop's footer, across the bottom of every page: the band's gold
/// stripe, the mark, a line on how the shirts are made and paid for, and
/// whose they are. Nothing in it leads off the shop.
class _ShopFooter extends StatelessWidget {
  const _ShopFooter();

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final safe = MediaQuery.paddingOf(context);
    final side = wide ? 40.0 : 16.0;
    final note = Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        Text('Shirts are printed to order and shipped to you.', style: BB.bodyStyle(14.5)),
        Text('Checkout is secure.', style: BB.bodyStyle(14.5)),
      ],
    );
    final rights = Text('© ${DateTime.now().year} Battle Baseball', style: BB.bodyStyle(13.5, height: 1.2));
    final mark = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/tank.png', height: 30, filterQuality: FilterQuality.medium),
          const SizedBox(width: 9),
          const Wordmark(height: 34, second: 'Shop'),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(color: BB.ink, child: const SizedBox(height: 3)),
        ColoredBox(color: BB.coral, child: SizedBox(height: wide ? 6 : 5)),
        Container(
          decoration: BoxDecoration(
            color: _bandColor(),
            border: Border(top: BorderSide(color: BB.ink, width: 3)),
          ),
          padding:
              EdgeInsets.fromLTRB(side + safe.left, wide ? 28 : 22, side + safe.right, (wide ? 30 : 24) + safe.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: BB.contentWidth),
              child: wide
                  ? Row(
                      children: [
                        mark,
                        const SizedBox(width: 32),
                        Expanded(child: note),
                        const SizedBox(width: 24),
                        rights,
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [mark, const SizedBox(height: 14), note, const SizedBox(height: 8), rights],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What an address in the shop that leads nowhere shows. Battle Shop's way
/// out is its own first page.
class ShopNotFound extends StatelessWidget {
  const ShopNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final site = ShopSite.of(context);
    if (!site.standalone) return const NotFoundScreen();
    // NotFoundScreen's words, over Battle Shop's footer.
    return _ShopPage(
      top: true,
      cart: false,
      children: [
        const SizedBox(height: 56),
        Text('Nothing here.', style: BB.title(BB.isWide(context) ? 44 : 34, drop: 4)),
        const SizedBox(height: 6),
        TextLink(site.title, onTap: () => context.go(site.home)),
      ],
    );
  }
}

/// Home's Merch section: two shirts from the shop and a way in, or the
/// coming-soon shirts until the shop opens.
class MerchSection extends StatefulWidget {
  const MerchSection({super.key});

  @override
  State<MerchSection> createState() => _MerchSectionState();
}

class _MerchSectionState extends State<MerchSection> {
  @override
  void initState() {
    super.initState();
    Shop.instance.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          if (shop.open) {
            final first = [for (final s in shop.sections) ...s.products].take(2).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('Merch', trailing: shop.count > 0 ? const CartButton() : null),
                _ProductGrid(first, columns: 2),
                const SizedBox(height: 4),
                TextLink('Shop all merch', onTap: () => context.go('/merch')),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle('Merch', trailing: shop.comingSoon ? const Pill('Coming soon') : null),
              if (shop.status == ShopStatus.loading)
                const LoadingField()
              else if (shop.status == ShopStatus.failed) ...[
                const Quiet("The shop didn't load."),
                const SizedBox(height: 4),
                TextLink('Try again', onTap: () => shop.load(force: true)),
              ] else
                _ShirtRow(onTap: () => context.go('/merch')),
            ],
          );
        },
      );
}

/// The top of a shop screen in the app: back, the sample stamp, and the
/// cart. On Battle Shop's own site the band above carries the mark, the
/// stamp and the Cart, so only the way back is left, and its first page has
/// nowhere to go back to.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader({this.top = false, this.cart = true});

  /// The shop's first page, not a shirt or the cart.
  final bool top;
  final bool cart;

  @override
  Widget build(BuildContext context) {
    final site = ShopSite.of(context);
    final wide = BB.isWide(context);
    if (site.standalone) {
      if (top) return SizedBox(height: wide ? 12 : 6);
      return BackHeader(site.back, height: wide ? 52 : 50, trailing: const SizedBox.shrink());
    }
    return BackHeader(
      top ? 'Home' : site.back,
      beside: Repo.stampDemo && !wide ? const Stamp('SAMPLE') : null,
      // An empty box keeps BackHeader from putting its own stamp there.
      trailing: cart ? const CartButton() : const SizedBox.shrink(),
    );
  }
}

/// A shop screen whose header stays put while the rest scrolls under it,
/// so the way back and the Cart are always in reach.
class _ShopFrame extends StatelessWidget {
  const _ShopFrame({required this.header, required this.children, this.maxWidth = BB.contentWidth});

  final Widget header;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final side = BB.isWide(context) ? 40.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PageFrame's sides and width, so the header sits where it always has.
        Padding(
          padding: EdgeInsets.fromLTRB(side + safe.left, safe.top, side + safe.right, 0),
          child: Center(
            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: header),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: PageFrame(maxWidth: maxWidth, children: children),
          ),
        ),
      ],
    );
  }
}

/// One screen of the shop: its header, then [children] in a scrolling
/// column. In the app that is a [PageFrame], or with [pinned] a
/// [_ShopFrame]. On Battle Shop's own site the way back always stays put,
/// and the page is at least as tall as the window, so the footer sits at
/// the bottom of a short page and after the last shirt of a long one.
class _ShopPage extends StatelessWidget {
  const _ShopPage({
    required this.children,
    this.top = false,
    this.cart = true,
    this.pinned = false,
    this.maxWidth = BB.contentWidth,
    this.column,
    this.lead,
  });

  final List<Widget> children;

  /// On Battle Shop's own site, what opens the page across the window's
  /// whole width, under the band and scrolling with the rest.
  final Widget? lead;

  /// The shop's first page, not a shirt or the cart.
  final bool top;

  /// Whether the app's header shows the Cart.
  final bool cart;

  /// In the app, keep the header in place while the page scrolls.
  final bool pinned;
  final double maxWidth;

  /// As [PageFrame.column]: a narrow screen's width.
  final double? column;

  @override
  Widget build(BuildContext context) {
    final header = _ShopHeader(top: top, cart: cart);
    if (!ShopSite.of(context).standalone) {
      return pinned
          ? _ShopFrame(header: header, maxWidth: maxWidth, children: children)
          : PageFrame(maxWidth: maxWidth, column: column, children: [header, ...children]);
    }
    final wide = BB.isWide(context);
    final safe = MediaQuery.paddingOf(context);
    final sides = EdgeInsets.only(left: (wide ? 40.0 : 16.0) + safe.left, right: (wide ? 40.0 : 16.0) + safe.right);
    Widget framed(Widget child) => Padding(
          padding: sides,
          child: Center(
            child: ConstrainedBox(
              // PageFrame's widths: a narrow screen is centered on a tablet
              // and starts at the frame's left edge on desktop.
              constraints: BoxConstraints(maxWidth: wide ? maxWidth : column ?? maxWidth),
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: column ?? double.infinity),
                  child: child,
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A lead starts right under the band.
        if (lead == null) framed(SizedBox(width: double.infinity, child: header)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ?lead,
                        Padding(
                          padding: EdgeInsets.only(bottom: wide ? 80 : 44),
                          child: framed(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
                        ),
                      ],
                    ),
                    const _ShopFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Cart · 2": the way to the cart from anywhere in the shop.
class CartButton extends StatelessWidget {
  const CartButton({super.key, this.compact = false, this.band = false, this.small = true});

  /// Just the bag and the count, for the desktop top bar.
  final bool compact;

  /// On Battle Shop's band: a cream face, which stands out on its darker blue.
  final bool band;

  /// 40 tall. Battle Shop's desktop band has room for the full 54.
  final bool small;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final n = Shop.instance.count;
          return BBButton(
            compact ? '$n' : (n == 0 ? 'Cart' : 'Cart · $n'),
            kind: band ? BBButtonKind.paper : BBButtonKind.quiet,
            semanticLabel: n == 0 ? 'Cart' : 'Cart, $n ${n == 1 ? 'item' : 'items'}',
            small: small,
            icon: const BBIcon(BBGlyph.bag),
            onPressed: () => context.go('${ShopSite.of(context).root}/cart'),
          );
        },
      );
}

class MerchScreen extends StatefulWidget {
  const MerchScreen({super.key});

  @override
  State<MerchScreen> createState() => _MerchScreenState();
}

class _MerchScreenState extends State<MerchScreen> {
  @override
  void initState() {
    super.initState();
    Shop.instance.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final wide = BB.isWide(context);
          final standalone = ShopSite.of(context).standalone;
          // Battle Shop's mark is its title; Merch says where in the app you are.
          final title = standalone ? const SizedBox(height: 8) : const PageTitle('Merch');
          return switch (shop.status) {
            ShopStatus.loading => _ShopPage(top: true, cart: false, children: [title, const LoadingField()]),
            ShopStatus.failed => _DidNotLoad(onRetry: () => shop.load(force: true), top: true),
            ShopStatus.ready when shop.products.isNotEmpty => _ShopPage(
                top: true,
                pinned: true,
                lead: standalone ? _ShopFront([for (final s in shop.sections) ...s.products]) : null,
                children: [
                  if (!standalone) title,
                  ..._sections(shop.sections, wide: wide, standalone: standalone),
                  // Battle Shop's footer says so on every page.
                  if (!standalone) ...[
                    const SizedBox(height: 28),
                    Text('Checkout runs on Shopify.', style: BB.bodyStyle(14.5)),
                  ],
                ],
              ),
            _ => const _ComingSoon(top: true),
          };
        },
      );
}

/// The shop's sections in order. The participating teams come last, under
/// their own heading, each team titled a size down. On Battle Shop's own
/// site ([standalone]) each heading is underlined in gold and a team flies
/// a pennant.
List<Widget> _sections(List<ShopSection> sections, {required bool wide, bool standalone = false}) {
  Widget about(String text) {
    final words = Text(text, style: BB.bodyStyle(16, height: 1.45));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // On Battle Shop's wide page a long description keeps to a readable line.
      child: standalone
          ? Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: words),
            )
          : words,
    );
  }

  Widget head(String text, {required double bottom}) => standalone
      ? _ShopHeading(text, padding: EdgeInsets.only(bottom: bottom + 6))
      : SectionTitle(text, padding: EdgeInsets.only(bottom: bottom));
  Widget team(String text, {required double bottom}) {
    final name = Semantics(header: true, child: Text(text, style: BB.title(wide ? 26 : 22)));
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: standalone
          ? Row(
              children: [
                BBIcon(BBGlyph.pennant, size: wide ? 24 : 21, color: BB.coral),
                const SizedBox(width: 8),
                Expanded(child: name),
              ],
            )
          : name,
    );
  }

  final gap = standalone ? (wide ? 64.0 : 44.0) : (wide ? 48.0 : 36.0);
  return [
    for (final (i, s) in sections.indexed) ...[
      if (s.team && (i == 0 || !sections[i - 1].team)) ...[
        if (i > 0) SizedBox(height: gap),
        // Battle Shop lets the heading speak for itself.
        head('Participating teams', bottom: standalone ? 14 : 6),
        if (!standalone) about('Gear for the teams that play in Battle Baseball showcases.'),
        const SizedBox(height: 4),
      ] else if (i > 0)
        SizedBox(height: s.team ? (wide ? 36 : 28) : gap),
      if (s.title.isNotEmpty)
        if (s.team)
          team(s.title, bottom: s.description.isEmpty ? 14 : 6)
        else
          head(s.title, bottom: s.description.isEmpty ? 16 : 6),
      if (s.description.isNotEmpty) about(s.description),
      _ProductGrid(s.products),
    ],
  ];
}

/// A section's title on Battle Shop's own site: [SectionTitle]'s words a
/// size up, on a stroke of gold marker as wide as they are.
class _ShopHeading extends StatelessWidget {
  const _ShopHeading(this.text, {this.padding = const EdgeInsets.only(bottom: 22)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text(text, style: BB.title(wide ? 36 : 29, drop: 3))),
              SizedBox(height: wide ? 5 : 4),
              ExcludeSemantics(
                child: CustomPaint(
                  size: Size(double.infinity, wide ? 11 : 9),
                  painter: _MarkerPainter(color: BB.coral, ink: BB.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pass of a marker under a heading: a gold stroke that lifts a little
/// toward its right end, outlined in ink like everything on the field.
class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.color, required this.ink});

  final Color color, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    final t = h * 0.48;
    final stroke = Path()
      ..moveTo(t, h * 0.62)
      ..cubicTo(w * 0.3, h * 0.36, w * 0.68, h * 0.34, w - t, h * 0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        stroke,
        paint
          ..color = ink
          ..strokeWidth = t * 2,
      )
      ..drawPath(
        stroke,
        paint
          ..color = color
          ..strokeWidth = t * 2 - 4.5,
      );
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.color != color || old.ink != ink;
}

/// A star with [points] points, [inner] of the way in between them: five
/// for the ticker's stars, four thin ones for a sparkle. Outlined in ink
/// when [stroke] is set.
class _Star extends StatelessWidget {
  const _Star({required this.size, required this.color, this.points = 5, this.inner = 0.46, this.stroke = 0});

  final double size;
  final Color color;
  final int points;
  final double inner;
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _SpikesPainter(points: points, inner: inner, fill: color, ink: BB.ink, stroke: stroke),
      );
}

/// A star or a starburst: [points] spikes around a circle, turning with
/// [turn] (in whole turns), on an ink lip [lip] deep.
class _SpikesPainter extends CustomPainter {
  _SpikesPainter({
    required this.points,
    required this.inner,
    required this.fill,
    required this.ink,
    this.stroke = 0,
    this.lip = 0,
    this.turn,
    this.turns = 1,
  }) : super(repaint: turn);

  final int points;
  final double inner;
  final Color fill, ink;
  final double stroke, lip;
  final Animation<double>? turn;

  /// How many times the shape goes round for one of [turn]'s.
  final int turns;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - stroke / 2;
    final c = Offset(size.width / 2, size.width / 2);
    final start = -math.pi / 2 + (turn?.value ?? 0) * turns * 2 * math.pi;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = start + i * math.pi / points;
      final at = c + Offset(math.cos(a), math.sin(a)) * (i.isEven ? r : r * inner);
      i == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    path.close();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke
      ..color = ink;
    if (lip > 0) {
      final under = path.shift(Offset(0, lip));
      canvas.drawPath(under, Paint()..color = ink);
      if (stroke > 0) canvas.drawPath(under, line);
    }
    canvas.drawPath(path, Paint()..color = fill);
    if (stroke > 0) canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_SpikesPainter old) =>
      old.points != points ||
      old.inner != inner ||
      old.fill != fill ||
      old.ink != ink ||
      old.stroke != stroke ||
      old.lip != lip ||
      old.turn != turn;
}

/// What opens Battle Shop's first page, across the window's whole width:
/// the ticker, then the headline and the shirts on their rays.
class _ShopFront extends StatelessWidget {
  const _ShopFront(this.products);

  /// The shop's shirts in the order it lists them.
  final List<ShopProduct> products;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [const ShopTicker(), _ShopHero(products)],
      );
}

/// What a shopper can count on, running right to left across an ink strip
/// under the band the way a scoreboard's ribbon does. It stands still for
/// anyone who has asked their device for less motion.
class ShopTicker extends StatefulWidget {
  const ShopTicker({super.key});

  /// The first three are the shop's promises, which a shirt's page lists too.
  static const lines = ['Printed to order', 'Shipped to you', 'Secure checkout', 'Gear up for game day'];

  @override
  State<ShopTicker> createState() => _ShopTickerState();
}

class _ShopTickerState extends State<ShopTicker> with SingleTickerProviderStateMixin {
  // One pass of the lines takes this long, however wide the window.
  late final _run = AnimationController(vsync: this, duration: const Duration(seconds: 26));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _run.stop();
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    // Its words grow with the reader's text, a little.
    final grow = (MediaQuery.textScalerOf(context).scale(100) / 100).clamp(1.0, 1.3);
    final style = BB.lilita((wide ? 16 : 14.5) * grow, color: BB.cream).copyWith(letterSpacing: 1.1);
    final pass = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in ShopTicker.lines) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 15),
            child: Text(
              line.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: style,
            ),
          ),
          _Star(size: (wide ? 14 : 12.5) * grow, color: BB.coral),
        ],
      ],
    );
    // Enough passes side by side to cover the window and one more, so
    // sliding left by one pass lands on the same picture.
    final passes = (MediaQuery.sizeOf(context).width / 640).ceil() + 1;
    return Semantics(
      label: '${ShopTicker.lines.take(3).join('. ')}.',
      child: ExcludeSemantics(
        child: ColoredBox(
          color: BB.ink,
          child: ClipRect(
            child: SizedBox(
              height: (wide ? 40 : 34) * grow,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _run,
                    builder: (context, child) =>
                        FractionalTranslation(translation: Offset(-_run.value / passes, 0), child: child),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < passes; i++) pass]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Battle Shop's headline with a line under it, on rays that turn slowly
/// behind it. On desktop two shirts from the shop sit beside it, laid out
/// like cards as on its link preview (web/og-shop.png), under a starburst
/// with the shop's lowest price; on a phone the starburst sits by the
/// headline and the shirts themselves come right after.
class _ShopHero extends StatefulWidget {
  const _ShopHero(this.products);

  /// The shop's shirts in the order it lists them; the first two with a
  /// photo are the ones shown.
  final List<ShopProduct> products;

  static const _line = 'Battle Baseball tees, and gear for the teams that play in its showcases.';

  @override
  State<_ShopHero> createState() => _ShopHeroState();
}

class _ShopHeroState extends State<_ShopHero> with TickerProviderStateMixin {
  /// One slow turn of the rays; the starburst goes round several times in it.
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 180));

  /// The shirts and the starburst arriving, once.
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
      _enter.value = 1;
    } else {
      if (!_spin.isAnimating) _spin.repeat();
      if (_enter.status == AnimationStatus.dismissed) _enter.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _enter.dispose();
    super.dispose();
  }

  /// The lowest price in the shop among what can be bought, as "$25".
  String? get _from {
    final priced = [for (final p in widget.products) if (p.available) p];
    if (priced.isEmpty) return null;
    final low = priced.reduce((a, b) => a.minPrice <= b.minPrice ? a : b);
    return shopPrice(low.minPrice, low.currency);
  }

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final safe = MediaQuery.paddingOf(context);
    final side = wide ? 40.0 : 16.0;
    final shown = [for (final p in widget.products) if (p.image != null) p].take(2).toList();
    final from = _from;
    final pop = _enter.drive(CurveTween(curve: const Interval(0.45, 1, curve: Curves.easeOutBack)));
    final words = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 470 : 420),
      child: Text(_ShopHero._line, style: BB.bodyStyle(wide ? 20 : 16.5, color: BB.cream.withAlpha(0xE0))),
    );
    return LayoutBuilder(
      builder: (context, box) {
        // The page's frame, which the rays aim into.
        final frame = math.min(box.maxWidth - safe.horizontal - side * 2, BB.contentWidth);
        final left = safe.left + side + (box.maxWidth - safe.horizontal - side * 2 - frame) / 2;
        final right = left + frame;
        final beside = wide && shown.isNotEmpty;
        final Widget content;
        if (wide) {
          content = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [const _ShopHeadline(), const SizedBox(height: 24), words],
                ),
              ),
              if (beside) ...[
                const SizedBox(width: 24),
                _HeroShirts(shown, from: from, enter: _enter, spin: _spin),
              ] else if (from != null)
                ScaleTransition(scale: pop, child: _PriceBurst(from, size: 150, spin: _spin)),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(child: _ShopHeadline()),
                  if (from != null) ...[
                    const SizedBox(width: 12),
                    ScaleTransition(scale: pop, child: _PriceBurst(from, size: 98, spin: _spin)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              words,
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RaysPainter(
                      // From behind the shirts, or the starburst: beside the
                      // phone's headline (about 232 wide), or at the frame's
                      // right edge when the headline has shrunk to make room.
                      focal: beside
                          ? right - 215
                          : wide
                              ? right - 75
                              : math.min(left + 293, right - 49),
                      rise: wide ? 0.5 : 0.36,
                      color: BB.cream.withAlpha(0x1C),
                      turn: _spin,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(left, wide ? 44 : 22, box.maxWidth - right, wide ? 60 : 34),
              child: content,
            ),
          ],
        );
      },
    );
  }
}

/// Rays out of one point, every other wedge a little lighter than the
/// field, fading with distance and toward the bottom so the page below
/// starts on plain field. The point is [focal] pixels from the left and
/// [rise] of the way down the box.
class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.focal, required this.rise, required this.color, required this.turn})
      : super(repaint: turn);

  final double focal, rise;
  final Color color;
  final Animation<double> turn;

  static const _rays = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = Offset(focal, size.height * rise);
    final reach = math.max(size.width, size.height) * 1.2;
    final wedges = Path();
    final start = turn.value * 2 * math.pi;
    for (var i = 0; i < _rays; i++) {
      final a = start + i * 2 * math.pi / _rays, b = a + math.pi / _rays;
      wedges
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a) * reach, c.dy + math.sin(a) * reach)
        ..lineTo(c.dx + math.cos(b) * reach, c.dy + math.sin(b) * reach)
        ..close();
    }
    canvas
      ..saveLayer(rect, Paint())
      ..clipRect(rect)
      ..drawPath(
        wedges,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withAlpha(0)],
            stops: const [0.12, 1],
          ).createShader(Rect.fromCircle(center: c, radius: math.max(size.width * 0.62, 520))),
      )
      ..drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.62, 1],
          ).createShader(rect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.focal != focal || old.rise != rise || old.color != color || old.turn != turn;
}

/// "Shirts and team gear." on two lines, the second on the coral slab, as
/// Home's headline is set. It shrinks as one piece when the column is too
/// narrow.
class _ShopHeadline extends StatelessWidget {
  const _ShopHeadline();

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final size = wide ? 84.0 : 46.0;
    final onField = BB.title(size, drop: wide ? 6 : 4).copyWith(height: 1);
    final onSlab = BB.lilita(size, height: 1).copyWith(letterSpacing: size * 0.005);
    Widget line(String text, TextStyle style) =>
        Text(text, maxLines: 1, softWrap: false, textScaler: TextScaler.noScaling, style: style);
    return Semantics(
      header: true,
      label: 'Shirts and team gear.',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('Shirts and', onField),
              Padding(
                padding: EdgeInsets.only(top: 0.12 * size, bottom: 0.12 * size),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(-0.03 * size, 0, 0)..rotateZ(-2.5 * math.pi / 180),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(0.2 * size, 0, 0.2 * size, 0.06 * size),
                    decoration: BoxDecoration(
                      color: BB.coral,
                      borderRadius: BorderRadius.circular(0.24 * size),
                      border: Border.all(color: BB.ink, width: wide ? 4 : 3),
                      boxShadow: BB.lip(wide ? 7 : 5),
                    ),
                    child: line('team gear.', onSlab),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a shopper can count on, each behind a check, under Add to cart:
/// how the shirts are made, how they arrive and where the paying happens.
class _Promises extends StatelessWidget {
  const _Promises();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, text) in ShopTicker.lines.take(3).indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: BB.coral,
                      shape: BoxShape.circle,
                      border: Border.all(color: BB.ink, width: 2),
                    ),
                    child: Center(child: BBIcon(BBGlyph.check, size: 13, color: BB.ink)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(text, style: BB.labelStyle(15.5, height: 1.2))),
                ],
              ),
            ),
        ],
      );
}

/// The shop's lowest price on a gold starburst that turns slowly under its
/// words: "FROM" over "$25".
class _PriceBurst extends StatelessWidget {
  const _PriceBurst(this.price, {required this.size, required this.spin});

  final String price;
  final double size;
  final Animation<double> spin;

  @override
  Widget build(BuildContext context) {
    final lip = size * 0.05;
    return Semantics(
      label: 'From $price',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size + lip,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SpikesPainter(
                      points: 16,
                      inner: 0.86,
                      fill: BB.coral,
                      ink: BB.ink,
                      stroke: size > 120 ? 3.5 : 3,
                      lip: lip,
                      turn: spin,
                      turns: 6,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: size,
                child: Center(
                  child: Transform.rotate(
                    angle: -10 * math.pi / 180,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FROM',
                          textScaler: TextScaler.noScaling,
                          style: BB.caps(size * 0.125, color: BB.ink, tracking: 0.16),
                        ),
                        SizedBox(height: size * 0.015),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: size * 0.62),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              price,
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: BB.lilita(size * 0.32, height: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Its child a little bigger while the mouse is over it.
class _Grow extends StatefulWidget {
  const _Grow({required this.child});

  final Widget child;

  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> {
  bool _over = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _over = true),
        onExit: (_) => setState(() => _over = false),
        child: AnimatedScale(
          scale: _over ? 1.04 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Two shirts from the shop as the link preview lays them out: one on kraft
/// tipped back to the left, one on cream tipped forward over it, with the
/// price starburst on their corner and a few sparkles around them. They
/// drop into place when the page opens. Each shirt opens its page.
class _HeroShirts extends StatelessWidget {
  const _HeroShirts(this.products, {required this.from, required this.enter, required this.spin});

  final List<ShopProduct> products;

  /// The shop's lowest price, if anything is for sale.
  final String? from;
  final Animation<double> enter, spin;

  @override
  Widget build(BuildContext context) {
    Animation<double> part(double begin, double end) =>
        enter.drive(CurveTween(curve: Interval(begin, end, curve: Curves.easeOutBack)));
    Widget card(
      ShopProduct p, {
      required double width,
      required Color color,
      required double degrees,
      required Animation<double> at,
    }) =>
        AnimatedBuilder(
          animation: at,
          builder: (context, child) => Opacity(
            opacity: at.value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - at.value)),
              child: Transform.rotate(angle: degrees * at.value * math.pi / 180, child: child),
            ),
          ),
          child: _Grow(
            child: Pressable(
              onTap: () => context.go('${ShopSite.of(context).root}/${p.handle}'),
              label: p.title,
              builder: (context, down, focused) => Container(
                width: width,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BB.ink, width: 3.5),
                  boxShadow: [
                    if (focused) BoxShadow(color: BB.cream, spreadRadius: 3),
                    BoxShadow(color: BB.ink, offset: const Offset(0, 7)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: AspectRatio(aspectRatio: 1, child: ShopPhoto(p.image?.url, width: 720)),
                ),
              ),
            ),
          ),
        );
    Widget sparkle(double size, Color color, Animation<double> at) => ExcludeSemantics(
          child: ScaleTransition(
            scale: at,
            child: _Star(size: size, color: color, points: 4, inner: 0.34, stroke: 2.5),
          ),
        );
    final one = products.length == 1;
    final last = part(0.45, 1);
    return SizedBox(
      width: one ? 330 : 478,
      height: 356,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!one)
            Positioned(
              left: 36,
              top: 4,
              child: card(products[1], width: 252, color: BB.kraft, degrees: -6, at: part(0, 0.75)),
            ),
          Positioned(
            right: 6,
            top: one ? 14 : 44,
            child: card(products[0], width: 272, color: BB.cream, degrees: 4, at: part(0.15, 0.9)),
          ),
          Positioned(left: one ? 4 : 10, top: one ? 2 : -14, child: sparkle(34, BB.coral, last)),
          Positioned(right: -12, top: one ? -6 : 8, child: sparkle(24, BB.cream, last)),
          Positioned(right: one ? -18 : -22, bottom: 30, child: sparkle(30, BB.coral, last)),
          if (from != null)
            Positioned(
              left: 0,
              bottom: 0,
              child: ScaleTransition(scale: last, child: _PriceBurst(from!, size: 132, spin: spin)),
            ),
        ],
      ),
    );
  }
}

/// What the shop shows before the Shopify store is open.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({this.top = false});

  final bool top;

  @override
  Widget build(BuildContext context) => _ShopPage(
        top: top,
        cart: false,
        column: 640,
        children: [
          PageTitle(ShopSite.of(context).title, trailing: const Pill('Coming soon')),
          Text(
            "Battle Baseball tees are on the way. They aren't for sale yet; check back soon.",
            style: BB.bodyStyle(16, height: 1.45),
          ),
          const SizedBox(height: 18),
          const _ShirtRow(),
        ],
      );
}

class _DidNotLoad extends StatelessWidget {
  const _DidNotLoad({required this.onRetry, this.top = false});

  final VoidCallback onRetry;
  final bool top;

  @override
  Widget build(BuildContext context) => _ShopPage(
        top: top,
        cart: false,
        column: 640,
        children: [
          PageTitle(ShopSite.of(context).title),
          const Quiet("The shop didn't load. Check your connection and try again."),
          const SizedBox(height: 18),
          BBButton.paper('Try again', onPressed: onRetry),
        ],
      );
}

/// A product photo from Shopify (or a bundled sample), filling the space
/// it's given. Kraft paper stands in while it loads or if it can't.
class ShopPhoto extends StatelessWidget {
  const ShopPhoto(this.url, {super.key, this.width = 640, this.label});

  final String? url;

  /// How wide a copy to ask Shopify for, in real pixels.
  final int width;

  /// For screen readers; without one the photo is decoration.
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget blank() => SizedBox.expand(
          key: const ValueKey('blank'),
          child: ColoredBox(
            color: BB.kraft,
            child: Center(child: BBIcon(BBGlyph.jersey, size: 36, color: BB.inkRule)),
          ),
        );
    final u = url;
    if (u == null || u.isEmpty) return blank();
    final image = ShopImage(u);
    if (image.isAsset) {
      return Image.asset(
        u,
        fit: BoxFit.cover,
        semanticLabel: label,
        excludeFromSemantics: label == null,
      );
    }
    return Image.network(
      image.sized(width),
      // Shopify's image server sends WebP, a tenth the size, when asked.
      headers: const {'Accept': 'image/webp,image/*;q=0.8'},
      fit: BoxFit.cover,
      semanticLabel: label,
      excludeFromSemantics: label == null,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: frame == null ? blank() : SizedBox.expand(child: child),
            ),
      errorBuilder: (context, _, _) => blank(),
    );
  }
}

/// Product cards in rows of [columns], or as many as fit.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid(this.all, {this.columns, this.rows});

  final List<ShopProduct> all;
  final int? columns;

  /// Show no more than this many rows.
  final int? rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final n = columns ?? (box.maxWidth / 300).floor().clamp(2, 4);
          final gap = BB.isWide(context) ? 20.0 : 12.0;
          final products = rows == null ? all : all.take(n * rows!).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < products.length; i += n)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
                  // Cards in a row stand the same height, however long a name runs.
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < n; c++) ...[
                          if (c > 0) SizedBox(width: gap),
                          Expanded(
                            child: i + c < products.length
                                ? _ProductCard(products[i + c])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

/// One product on paper: its photo, name and price. Tapping opens it. On
/// Battle Shop's own site the price is a gold tag stuck on the photo's
/// corner, an arrow on the other corner says the card leads somewhere, and
/// under the mouse the card rises on its lip and tips a little.
class _ProductCard extends StatefulWidget {
  const _ProductCard(this.product);

  final ShopProduct product;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final site = ShopSite.of(context);
    final label = '${p.title}, ${p.priceLabel}${p.available ? '' : ', sold out'}';
    void open() => context.go('${site.root}/${p.handle}');
    if (!site.standalone) {
      return Paper(
        onTap: open,
        padding: const EdgeInsets.all(8),
        semanticLabel: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(aspectRatio: 1.1, child: ShopPhoto(p.image?.url)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              // The whole name: the color that tells two tees apart comes last.
              child: Text(p.title, style: BB.labelStyle(15.5, color: BB.ink, height: 1.2)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              // On a narrow card Sold out goes under the price, not over it.
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(p.priceLabel, style: BB.lilita(19)),
                  if (!p.available) Pill('Sold out', color: BB.kraft),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final wide = BB.isWide(context);
    // The price, and Sold out beside it, on the photo's bottom left corner.
    // They shrink together to stay on a narrow card.
    final tags = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PriceTag(p.priceLabel, size: wide ? 20 : 17.5),
          if (!p.available) ...[
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 3), child: Pill('Sold out', color: BB.kraft)),
          ],
        ],
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _over ? 1 : 0),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        // Up on a taller lip under the mouse; the room it rises into is kept
        // free above, so nothing around it moves.
        builder: (context, lift, _) => Padding(
          padding: EdgeInsets.only(top: 5 * (1 - lift)),
          child: Transform.rotate(
            angle: -0.8 * lift * math.pi / 180,
            child: Paper(
              onTap: open,
              padding: const EdgeInsets.all(8),
              lip: 4 + 5 * lift,
              semanticLabel: label,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(aspectRatio: 1.1, child: ShopPhoto(p.image?.url)),
                      ),
                      Positioned(left: 8, right: wide ? 50 : 44, bottom: 9, child: tags),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: wide ? 34 : 30,
                          height: wide ? 34 : 30,
                          decoration: BoxDecoration(
                            color: Color.lerp(BB.ink, BB.coral, lift),
                            shape: BoxShape.circle,
                            border: Border.all(color: BB.ink, width: 2.5),
                          ),
                          child: Center(
                            child: BBIcon(
                              BBGlyph.forward,
                              size: wide ? 16 : 14,
                              color: Color.lerp(BB.cream, BB.ink, lift),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 11, 4, 5),
                    // The whole name: the color that tells two tees apart comes last.
                    child: Text(p.title, style: BB.labelStyle(wide ? 17 : 15.5, color: BB.ink, height: 1.2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A price on Battle Shop's own site: a gold tag with an ink edge, stuck on
/// a little crooked.
class _PriceTag extends StatelessWidget {
  const _PriceTag(this.label, {required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -3 * math.pi / 180,
        child: Container(
          padding: EdgeInsets.fromLTRB(size * 0.55, size * 0.15, size * 0.55, size * 0.25),
          decoration: BoxDecoration(
            color: BB.coral,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: BB.ink, width: size > 22 ? 3 : 2.5),
            boxShadow: BB.lip(size > 22 ? 4 : 3),
          ),
          child: Text(label, maxLines: 1, softWrap: false, style: BB.lilita(size, height: 1.1)),
        ),
      );
}

/// One shirt: photos, the price, sizes to pick, and Add to cart.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.handle});

  final String handle;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

enum _Load { loading, ready, missing, locked, failed }

class _ProductScreenState extends State<ProductScreen> {
  _Load _state = _Load.loading;
  ShopProduct? _product;
  List<Choice> _choices = const [];
  List<DescBlock> _description = const [];
  final _picked = <String, String>{};
  int _qty = 1;
  int _photo = 0;

  /// The jersey number to print, on a shirt that takes one.
  final _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductScreen old) {
    super.didUpdateWidget(old);
    if (old.handle != widget.handle) _load();
  }

  Future<void> _load() async {
    final handle = widget.handle;
    setState(() {
      _state = _Load.loading;
      _picked.clear();
      _qty = 1;
      _photo = 0;
      _number.clear();
    });
    _Load state;
    ShopProduct? p;
    try {
      p = await Shop.instance.product(handle);
      state = p == null ? _Load.missing : _Load.ready;
    } on ShopLocked {
      state = _Load.locked;
    } catch (_) {
      state = _Load.failed;
    }
    if (!mounted || handle != widget.handle) return;
    setState(() {
      _state = state;
      _product = p;
      _choices = p?.choices ?? const [];
      _description = p == null ? const [] : parseDescription(p.descriptionHtml);
    });
  }

  /// Picks [value] for [name]. Later picks the new one rules out are let go,
  /// so the button never asks for something that can't be had.
  void _pick(ShopProduct p, String name, String value) => setState(() {
        _picked[name] = value;
        var later = false;
        for (final c in _choices) {
          final v = _picked[c.name];
          if (later && v != null && !p.offers(c.name, v, _picked)) _picked.remove(c.name);
          if (c.name == name) later = true;
        }
        // Show the picked color's own photo, when it has one.
        _photo = p.photoFor(_picked) ?? _photo;
      });

  void _add(ShopProduct p, ShopVariant v) {
    final number = _number.text.trim();
    if (p.takesNumber && number.isEmpty) {
      toast(context, 'Add your jersey number.');
      return;
    }
    // The number stays filled in: a second shirt is usually for the same
    // player.
    Shop.instance.add(p, v, _qty, p.takesNumber ? number : null);
    toast(context, _qty == 1 ? 'Added to your cart.' : '$_qty added to your cart.');
    setState(() => _qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    switch (_state) {
      case _Load.loading:
        return const _ShopPage(children: [LoadingField()]);
      case _Load.locked:
        // A shared link to a shirt: back goes up to the shop, so say so.
        return const _ComingSoon();
      case _Load.failed:
        return _DidNotLoad(onRetry: _load);
      case _Load.missing:
        return const ShopNotFound();
      case _Load.ready:
    }
    if (p == null) return const ShopNotFound();

    final wide = BB.isWide(context);
    final standalone = ShopSite.of(context).standalone;
    final variant = p.variantFor(_picked);
    final unpicked = [for (final c in _choices) if (_picked[c.name] == null) c.name];
    final action = variant == null
        ? (unpicked.isEmpty ? 'Not available' : 'Add to cart')
        : (variant.available ? 'Add to cart' : 'Sold out');
    // Like Reserve, the button stays live until something's missing, and
    // then says what.
    final VoidCallback? onAdd = variant != null
        ? (variant.available ? () => _add(p, variant) : null)
        : (unpicked.isEmpty ? null : () => toast(context, 'Pick a ${unpicked.first.toLowerCase()}.'));
    final was = variant?.compareAt;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(p.title, style: BB.title(wide ? 38 : 28, drop: 3)),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              liveRegion: true,
              // Battle Shop tags its prices; Merch prints them on the field.
              child: standalone
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: _PriceTag(
                        variant == null ? p.priceLabel : shopPrice(variant.price, p.currency),
                        size: wide ? 27 : 24,
                      ),
                    )
                  : Text(
                      variant == null ? p.priceLabel : shopPrice(variant.price, p.currency),
                      style: BB.title(wide ? 30 : 26, drop: 3),
                    ),
            ),
            if (was != null && variant != null && was > variant.price) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Semantics(
                  label: 'Was ${shopPrice(was, p.currency)}',
                  excludeSemantics: true,
                  child: Text(
                    shopPrice(was, p.currency),
                    style: BB.labelStyle(17, color: BB.creamSoft)
                        .copyWith(decoration: TextDecoration.lineThrough, decorationColor: BB.creamSoft),
                  ),
                ),
              ),
            ],
          ],
        ),
        for (final c in _choices) ...[
          const SizedBox(height: 20),
          Text(c.name.toUpperCase(), style: BB.caps(13)),
          for (final g in c.groups) ...[
            if (g.label != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(g.label!, style: BB.labelStyle(15.5, height: 1)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in g.values)
                  if (p.offers(c.name, value, _picked))
                    BBChip(
                      c.label(value),
                      selected: _picked[c.name] == value,
                      onTap: () => _pick(p, c.name, value),
                    )
                  else
                    Semantics(
                      label: '${c.label(value)}, sold out',
                      excludeSemantics: true,
                      child: Opacity(opacity: 0.4, child: BBChip(c.label(value))),
                    ),
              ],
            ),
          ],
        ],
        if (p.takesNumber) ...[
          const SizedBox(height: 20),
          Text('JERSEY NUMBER', style: BB.caps(13)),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 2,
              style: BB.lilita(26, color: BB.cream, height: 1.15),
              decoration: const InputDecoration(
                hintText: '23',
                semanticCounterText: '',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('1 or 2 digits, printed on the back.', style: BB.labelStyle(14, color: BB.creamSoft)),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            final qty = _Qty(value: _qty, onChanged: (q) => setState(() => _qty = q));
            final button = BBButton.primary(action, expand: true, onPressed: onAdd);
            // Side by side, the button's words get cut off on the narrowest
            // phones, so there the quantity sits on top.
            if (box.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Align(alignment: Alignment.centerLeft, child: qty), const SizedBox(height: 12), button],
              );
            }
            return Row(children: [qty, const SizedBox(width: 12), Expanded(child: button)]);
          },
        ),
        if (standalone) ...[
          const SizedBox(height: 22),
          const _Promises(),
        ],
        if (_description.isNotEmpty) ...[
          const SizedBox(height: 28),
          _Description(_description),
        ],
      ],
    );
    final gallery = _Gallery(
      images: p.images,
      index: _photo.clamp(0, p.images.isEmpty ? 0 : p.images.length - 1),
      onPick: (i) => setState(() => _photo = i),
      label: p.title,
    );

    return _ShopPage(
      pinned: true,
      // Phone layouts stay a phone's width on a tablet.
      maxWidth: wide ? BB.contentWidth : 560,
      children: [
        if (wide)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: gallery),
                const SizedBox(width: 56),
                Expanded(flex: 6, child: details),
              ],
            ),
          )
        else ...[
          gallery,
          const SizedBox(height: 20),
          details,
        ],
        if (standalone) _MoreFromShop(except: p.handle),
      ],
    );
  }
}

/// Under a shirt on Battle Shop's own site: a row of the shop's other
/// shirts, so its page isn't a dead end. Nothing until the catalog is read,
/// and nothing if this is the only shirt.
class _MoreFromShop extends StatefulWidget {
  const _MoreFromShop({required this.except});

  /// The shirt whose page this is on.
  final String except;

  @override
  State<_MoreFromShop> createState() => _MoreFromShopState();
}

class _MoreFromShopState extends State<_MoreFromShop> {
  @override
  void initState() {
    super.initState();
    // A shared link lands here without the shop's first page having read it.
    Shop.instance.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          if (!shop.open) return const SizedBox.shrink();
          // The shirts beside this one in its section first, then the rest.
          final sections = shop.sections;
          final near = [
            for (final s in sections)
              if (s.products.any((p) => p.handle == widget.except)) ...s.products,
          ];
          final others = <ShopProduct>[
            ...near,
            for (final s in sections) ...s.products,
          ].where((p) => p.handle != widget.except).toList();
          final seen = <String>{};
          others.retainWhere((p) => seen.add(p.handle));
          if (others.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(top: BB.isWide(context) ? 64 : 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ShopHeading('More from the shop'),
                _ProductGrid(others, rows: 1),
              ],
            ),
          );
        },
      );
}

/// A product's photos: the one in view, and the rest to tap through.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.images, required this.index, required this.onPick, required this.label});

  final List<ShopImage> images;
  final int index;
  final ValueChanged<int> onPick;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LipBox(
            radius: 18,
            child: AspectRatio(
              aspectRatio: 1.1,
              child: ShopPhoto(
                images.isEmpty ? null : images[index].url,
                key: ValueKey(index),
                width: 1200,
                label: label,
              ),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, image) in images.indexed)
                  Semantics(
                    selected: i == index,
                    child: Pressable(
                      onTap: () => onPick(i),
                      label: 'Photo ${i + 1} of ${images.length}',
                      builder: (context, down, focused) => Container(
                        width: 64,
                        height: 64,
                        clipBehavior: Clip.antiAlias,
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: i == index ? BB.coral : BB.ink, width: i == index ? 3.5 : 2),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [if (focused) BoxShadow(color: BB.cream, spreadRadius: 3)],
                        ),
                        child: Opacity(opacity: down ? 0.7 : 1, child: ShopPhoto(image.url, width: 240)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
}

/// How many: a cream pill with a minus and a plus.
class _Qty extends StatelessWidget {
  const _Qty({required this.value, required this.onChanged, this.small = false, this.what});

  final int value;
  final ValueChanged<int> onChanged;

  /// A lighter pill, for a cart line.
  final bool small;

  /// Which shirt, for screen readers, when there's more than one on screen.
  final String? what;

  @override
  Widget build(BuildContext context) {
    final inner = small ? 44.0 : 49.0;
    Widget tap(BBGlyph glyph, String label, VoidCallback? onTap) => Pressable(
          onTap: onTap,
          label: what == null ? label : '$label, $what',
          builder: (context, down, focused) => SizedBox(
            width: small ? 44 : 46,
            height: inner,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: focused ? BB.ink : Colors.transparent, width: 2),
                ),
                child: Center(
                  child: Opacity(
                    opacity: onTap == null ? 0.3 : (down ? 0.5 : 1),
                    child: BBIcon(glyph, size: small ? 16 : 19, color: BB.ink),
                  ),
                ),
              ),
            ),
          ),
        );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: LipBox(
        radius: 999,
        border: small ? 2 : 2.5,
        lip: small ? 3 : 5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            tap(BBGlyph.minus, 'One fewer', value > 1 ? () => onChanged(value - 1) : null),
            Semantics(
              label: what == null ? 'Quantity $value' : 'Quantity $value, $what',
              liveRegion: true,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 22),
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: BB.labelStyle(small ? 16 : 19, color: BB.ink, height: 1),
                ),
              ),
            ),
            tap(BBGlyph.plus, 'One more', value < Shop.maxQty ? () => onChanged(value + 1) : null),
          ],
        ),
      ),
    );
  }
}

/// The listing's description in the app's type: sentences on the field, and
/// a size chart on paper.
class _Description extends StatelessWidget {
  const _Description(this.blocks);

  final List<DescBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final body = BB.bodyStyle(16, height: 1.5);
    TextSpan spans(List<DescRun> runs) => TextSpan(
          children: [
            for (final r in runs)
              TextSpan(
                text: r.text,
                style: TextStyle(
                  color: r.bold ? BB.cream : null,
                  fontWeight: r.bold ? FontWeight.w900 : null,
                  fontStyle: r.italic ? FontStyle.italic : null,
                ),
              ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in blocks.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
            child: switch (b) {
              // A line that's all bold is a heading in everything but name.
              DescText(:final runs, :final heading) when heading || runs.every((r) => r.bold) =>
                Semantics(header: true, child: Text(b.text, style: BB.labelStyle(17.5, height: 1.25))),
              DescText(:final runs) => Text.rich(spans(runs), style: body),
              DescList(:final items, :final numbered) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (n, item) in items.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: n == 0 ? 0 : 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(minWidth: numbered ? 26 : 20),
                              child: ExcludeSemantics(
                                excluding: !numbered,
                                child: Text(numbered ? '${n + 1}. ' : '•', style: body),
                              ),
                            ),
                            Expanded(child: Text.rich(spans(item), style: body)),
                          ],
                        ),
                      ),
                  ],
                ),
              DescTable(:final rows, :final headed) => Paper(
                  radius: 14,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  // Past 1.5x text a phone can't fit a four-column chart.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.5,
                    child: Table(
                      // Each column as wide as its words, with the room left
                      // shared out, so "Sleeve length" doesn't break mid-word.
                      defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: TableBorder(horizontalInside: BorderSide(color: BB.inkRule, width: 1.5)),
                      children: [
                        for (final (r, row) in rows.indexed)
                          TableRow(
                            children: [
                              // Every row as wide as the widest.
                              for (var c = 0; c < rows.fold(0, (n, x) => x.length > n ? x.length : n); c++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
                                  child: Text(
                                    c < row.length ? (headed && r == 0 ? row[c].toUpperCase() : row[c]) : '',
                                    style: headed && r == 0
                                        ? BB.caps(11.5, color: BB.ink2, tracking: 0.06).copyWith(height: 1.25)
                                        : BB.labelStyle(15, color: BB.ink, height: 1.2),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              DescRule() => Container(height: 1.5, color: BB.hairline),
            },
          ),
      ],
    );
  }
}

/// The cart: what's in it, how many of each, and the way to Shopify's
/// checkout.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _busy = false;
  late final AppLifecycleListener _lifecycle;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Back from Shopify's checkout: if the order went through, the cart
    // empties itself. And prices or sizes may have changed since a shirt
    // went in.
    Shop.instance.settle();
    Shop.instance.refreshCart();
    _lifecycle = AppLifecycleListener(onResume: Shop.instance.settle);
    // The checkout page can sit over the app without pausing it, so for
    // half an hour after one starts, keep an eye on it.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      final at = Shop.instance.checkoutStartedAt;
      if (at != null && DateTime.now().difference(at) < const Duration(minutes: 30)) {
        Shop.instance.settle();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    setState(() => _busy = true);
    String? trouble;
    try {
      final url = await Shop.instance.checkout();
      final opened = await launchUrl(
        url,
        // In the app the checkout page slides over it; on the web it takes
        // this tab, so nothing gets caught by a pop-up blocker.
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
        webOnlyWindowName: '_self',
      );
      if (!opened) trouble = "Couldn't open checkout. Try again.";
    } on ShopIsSample {
      trouble = 'These are sample shirts, so checkout is switched off.';
    } on ShopLinesUnavailable catch (e) {
      final lowered = e.variantIds.any((id) => (e.accepted[id] ?? 0) > 0);
      trouble = Shop.instance.buyable.isEmpty
          ? "That just sold out, so there's nothing left to check out."
          : lowered
              ? "There weren't enough of a shirt, so we lowered how many. Take a look, then check out."
              : 'Some of your cart just sold out. Tap Check out for the rest.';
    } on ShopLocked {
      trouble = "The shop isn't open yet. Check back soon.";
    } catch (_) {
      trouble = "Couldn't open checkout. Check your connection and try again.";
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (trouble != null) toast(context, trouble);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final site = ShopSite.of(context);
          final lines = shop.lines;
          final soldOut = lines.length - shop.buyable.length;
          return _ShopPage(
            cart: false,
            column: 640,
            children: [
              const PageTitle('Your cart'),
              if (lines.isEmpty) ...[
                const Quiet('Nothing in your cart yet.'),
                const SizedBox(height: 6),
                TextLink(site.standalone ? 'Back to the shop' : 'Shop merch', onTap: () => context.go(site.home)),
              ] else ...[
                for (final l in lines)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: _CartRow(l)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: Text('Subtotal', style: BB.labelStyle(19, height: 1.3))),
                    Text(shopPrice(shop.subtotal, shop.currency), style: BB.title(28, drop: 3)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (soldOut > 0) 'Sold-out shirts stay out of your order.',
                    'Shipping, tax and any discounts are worked out at checkout.',
                  ].join(' '),
                  style: BB.bodyStyle(15),
                ),
                const SizedBox(height: 20),
                BBButton.primary(
                  'Check out',
                  expand: true,
                  busy: _busy,
                  onPressed: shop.buyable.isEmpty ? null : _checkout,
                ),
                const SizedBox(height: 12),
                // Battle Shop doesn't name the checkout's maker to its shoppers.
                Text(
                  ShopSite.of(context).standalone
                      ? 'You pay on a secure checkout page.'
                      : 'You pay on our Shopify checkout page.',
                  style: BB.bodyStyle(14.5),
                ),
              ],
            ],
          );
        },
      );
}

/// One cart line on paper: the shirt, its size, how many, and what they
/// come to.
class _CartRow extends StatelessWidget {
  const _CartRow(this.line);

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final l = line;
    return Paper(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: () => context.go('${ShopSite.of(context).root}/${l.handle}'),
            label: l.title,
            builder: (context, down, focused) => Container(
              width: 76,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: focused ? BB.coral : BB.ink, width: focused ? 3.5 : 2),
              ),
              child: ShopPhoto(l.image, width: 240),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BB.labelStyle(16.5, color: BB.ink, height: 1.2),
                ),
                if (l.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(l.detail, style: BB.bodyStyle(14, color: BB.ink2, height: 1.25)),
                  ),
                const SizedBox(height: 10),
                if (l.available)
                  // The total sits at the right, or under the quantity on a
                  // narrow phone.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Qty(
                          value: l.qty,
                          small: true,
                          what: [l.title, if (l.detail.isNotEmpty) l.detail].join(', '),
                          onChanged: (q) => Shop.instance.setQty(l.key, q),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(shopPrice(l.total, l.currency), style: BB.lilita(20)),
                        ),
                      ],
                    ),
                  )
                else
                  Pill('Sold out', color: BB.kraft),
              ],
            ),
          ),
          IconTap(
            BBGlyph.close,
            label: 'Remove ${l.title}${l.detail.isEmpty ? '' : ', ${l.detail}'}',
            onTap: () => Shop.instance.remove(l.key),
          ),
        ],
      ),
    );
  }
}

/// The coming-soon shirts side by side, each on paper with its name.
class _ShirtRow extends StatelessWidget {
  const _ShirtRow({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, item) in merchItems.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Paper(
                onTap: onTap,
                padding: const EdgeInsets.all(8),
                semanticLabel: '${item.name}, coming soon',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(item.image, fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                      child: Text(
                        item.name,
                        maxLines: 2,
                        style: BB.labelStyle(15, color: BB.ink, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
}
