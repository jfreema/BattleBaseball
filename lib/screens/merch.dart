// Merch: the Battle Baseball shop. A section on Home, the shop itself
// (/merch), a page for each shirt (/merch/<handle>) and the cart
// (/merch/cart). The shirts, prices and sizes are read from the Shopify
// store (data/shop.dart), and paying happens on Shopify's checkout page.
// Until the Shopify store opens to the public this is a "Coming soon" page.
//
// Battle Shop (/shop, /shop/<handle>, /shop/cart) is the same shop on its
// own: these screens under their own name and header, with no way into the
// rest of the app. ShopSite says which of the two a screen is showing in.
import 'dart:async';

import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/shop.dart';
import 'package:battle_baseball/data/shop_html.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:flutter/foundation.dart';
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

  /// Battle Shop: nothing of the Battle Baseball app around it, and no
  /// link into it.
  static const battleShop = ShopSite._(root: '/shop', title: 'Battle Shop', back: 'Shop', standalone: true);

  /// The shop's own address; a shirt is at `<root>/<handle>` and the cart
  /// at `<root>/cart`.
  final String root;
  final String title;

  /// What the back link on a shirt's page and the cart says.
  final String back;
  final bool standalone;

  /// Whether [path] is one of this shop's addresses.
  bool holds(String path) => path == root || path.startsWith('$root/');

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
/// tabs, no sign-in and no way Home. On desktop a bar with the Battle Shop
/// mark and the Cart; on phones each screen's own header carries them.
class BattleShopShell extends StatelessWidget {
  const BattleShopShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _ShopSiteScope(
        site: ShopSite.battleShop,
        child: Scaffold(
          body: BB.isWide(context)
              ? Column(
                  children: [
                    // Like the app's top bar, its words only grow so far.
                    MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15, child: const _BattleShopBar()),
                    Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
                  ],
                )
              : child,
        ),
      );
}

/// Battle Shop's desktop bar, the size and place of the app's top bar: the
/// mark, which leads to the shop's first page, and the Cart.
class _BattleShopBar extends StatelessWidget {
  const _BattleShopBar();

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: SizedBox(
          height: 84,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => context.go(ShopSite.battleShop.root),
                      label: 'Battle Shop, all shirts',
                      builder: (context, down, focused) => const Wordmark(height: 46.4, second: 'Shop'),
                    ),
                    if (Repo.stampDemo) ...[const SizedBox(width: 22), const Stamp('SAMPLE DATA')],
                    const Spacer(),
                    const CartButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// What an address in the shop that leads nowhere shows. Battle Shop's way
/// out is its own first page.
class ShopNotFound extends StatelessWidget {
  const ShopNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final site = ShopSite.of(context);
    return site.standalone ? NotFoundScreen(label: site.title, path: site.root) : const NotFoundScreen();
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

/// The top of a shop screen: back, the sample stamp, and the cart. Battle
/// Shop's first page has nowhere to go back to, so its mark stands there.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader({this.top = false, this.cart = true});

  /// The shop's first page, not a shirt or the cart.
  final bool top;
  final bool cart;

  @override
  Widget build(BuildContext context) {
    final site = ShopSite.of(context);
    final wide = BB.isWide(context);
    final stamp = Repo.stampDemo && !wide ? const Stamp('SAMPLE') : null;
    // On desktop Battle Shop's bar already has the Cart.
    final withCart = cart && !(site.standalone && wide);
    if (site.standalone && top) {
      // The bar above carries the mark; this is the little air under it.
      if (wide) return const SizedBox(height: 12);
      return SizedBox(
        height: 62,
        child: Row(
          children: [
            const Wordmark(second: 'Shop'),
            // The stamp gives way on a narrow phone, so the Cart always fits.
            Expanded(
              child: stamp == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: stamp),
                    ),
            ),
            if (withCart) const CartButton(),
          ],
        ),
      );
    }
    return BackHeader(
      top ? 'Home' : site.back,
      beside: stamp,
      // An empty box keeps BackHeader from putting its own stamp there.
      trailing: withCart ? const CartButton() : const SizedBox.shrink(),
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

/// "Cart · 2": the way to the cart from anywhere in the shop.
class CartButton extends StatelessWidget {
  const CartButton({super.key, this.compact = false});

  /// Just the bag and the count, for the desktop top bar.
  final bool compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final n = Shop.instance.count;
          return BBButton.quiet(
            compact ? '$n' : (n == 0 ? 'Cart' : 'Cart · $n'),
            semanticLabel: n == 0 ? 'Cart' : 'Cart, $n ${n == 1 ? 'item' : 'items'}',
            small: true,
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
          // Battle Shop's mark is its title; Merch says where in the app you are.
          final title = ShopSite.of(context).standalone ? const SizedBox(height: 8) : const PageTitle('Merch');
          return switch (shop.status) {
            ShopStatus.loading => PageFrame(
                children: [const _ShopHeader(top: true, cart: false), title, const LoadingField()],
              ),
            ShopStatus.failed => _DidNotLoad(onRetry: () => shop.load(force: true), top: true),
            ShopStatus.ready when shop.products.isNotEmpty => _ShopFrame(
                header: const _ShopHeader(top: true),
                children: [
                  title,
                  ..._sections(shop.sections, wide: wide),
                  const SizedBox(height: 28),
                  Text('Checkout runs on Shopify.', style: BB.bodyStyle(14.5)),
                ],
              ),
            _ => const _ComingSoon(top: true),
          };
        },
      );
}

/// The shop's sections in order. The participating teams come last, under
/// their own heading, each team titled a size down.
List<Widget> _sections(List<ShopSection> sections, {required bool wide}) {
  Widget about(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text, style: BB.bodyStyle(16, height: 1.45)),
      );
  return [
    for (final (i, s) in sections.indexed) ...[
      if (s.team && (i == 0 || !sections[i - 1].team)) ...[
        if (i > 0) SizedBox(height: wide ? 48 : 36),
        const SectionTitle('Participating teams', padding: EdgeInsets.only(bottom: 6)),
        about('Gear for the teams that play in Battle Baseball showcases.'),
        const SizedBox(height: 4),
      ] else if (i > 0)
        SizedBox(height: s.team ? (wide ? 36 : 28) : (wide ? 48 : 36)),
      if (s.title.isNotEmpty)
        if (s.team)
          Padding(
            padding: EdgeInsets.only(bottom: s.description.isEmpty ? 14 : 6),
            child: Semantics(header: true, child: Text(s.title, style: BB.title(wide ? 26 : 22))),
          )
        else
          SectionTitle(s.title, padding: EdgeInsets.only(bottom: s.description.isEmpty ? 16 : 6)),
      if (s.description.isNotEmpty) about(s.description),
      _ProductGrid(s.products),
    ],
  ];
}

/// What the shop shows before the Shopify store is open.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({this.top = false});

  final bool top;

  @override
  Widget build(BuildContext context) => PageFrame(
        column: 640,
        children: [
          _ShopHeader(top: top, cart: false),
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
  Widget build(BuildContext context) => PageFrame(
        column: 640,
        children: [
          _ShopHeader(top: top, cart: false),
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
  const _ProductGrid(this.products, {this.columns});

  final List<ShopProduct> products;
  final int? columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final n = columns ?? (box.maxWidth / 300).floor().clamp(2, 4);
          final gap = BB.isWide(context) ? 20.0 : 12.0;
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

/// One product on paper: its photo, name and price. Tapping opens it.
class _ProductCard extends StatelessWidget {
  const _ProductCard(this.product);

  final ShopProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Paper(
      onTap: () => context.go('${ShopSite.of(context).root}/${p.handle}'),
      padding: const EdgeInsets.all(8),
      semanticLabel: '${p.title}, ${p.priceLabel}${p.available ? '' : ', sold out'}',
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

  @override
  void initState() {
    super.initState();
    _load();
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
      });

  void _add(ShopProduct p, ShopVariant v) {
    Shop.instance.add(p, v, _qty);
    toast(context, _qty == 1 ? 'Added to your cart.' : '$_qty added to your cart.');
    setState(() => _qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    switch (_state) {
      case _Load.loading:
        return const PageFrame(children: [_ShopHeader(), LoadingField()]);
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
              child: Text(
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

    return _ShopFrame(
      // Phone layouts stay a phone's width on a tablet.
      maxWidth: wide ? BB.contentWidth : 560,
      header: const _ShopHeader(),
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
      ],
    );
  }
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
          return PageFrame(
            column: 640,
            children: [
              const _ShopHeader(cart: false),
              const PageTitle('Your cart'),
              if (lines.isEmpty) ...[
                const Quiet('Nothing in your cart yet.'),
                const SizedBox(height: 6),
                TextLink(site.standalone ? 'Back to the shop' : 'Shop merch', onTap: () => context.go(site.root)),
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
                Text('You pay on our Shopify checkout page.', style: BB.bodyStyle(14.5)),
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
                          onChanged: (q) => Shop.instance.setQty(l.variantId, q),
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
            onTap: () => Shop.instance.remove(l.variantId),
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
