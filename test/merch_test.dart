// The shop's screens with the sample shirts: the shop, a shirt's page and the cart, on phones and a desktop.
import 'dart:convert';

import 'package:battle_baseball/app.dart';
import 'package:battle_baseball/data/demo.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/data/shop.dart';
import 'package:battle_baseball/data/shop_sample.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:battle_baseball/screens/merch.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

const _phone = Size(390, 844);
const _narrow = Size(320, 640);
const _desktop = Size(1440, 900);

const _tropic = 'battle-baseball-tee-tropic-blue';
const _coral = 'battle-baseball-tank-tee-coral';

/// What a screen reader calls the coral line in the cart.
const _coralLine = 'Battle Baseball Special Edition Tee - Coral (Adult), Size 2XL';

/// The app's own fonts. Without them every letter is drawn a full square
/// wide, and text takes far more room than it does in the app.
Future<void> _loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// The shop's routes as lib/app.dart has them, with Home's Merch section at
/// the root, inside a Scaffold as AppShell puts them.
GoRouter _router(String location) => GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const PageFrame(children: [MerchSection()])),
            GoRoute(
              path: '/merch',
              builder: (_, _) => const MerchScreen(),
              routes: [
                GoRoute(path: 'cart', builder: (_, _) => const CartScreen()),
                GoRoute(path: ':handle', builder: (_, s) => ProductScreen(handle: s.pathParameters['handle']!)),
              ],
            ),
          ],
        ),
      ],
    );

/// The address the app opened by [_open] is showing now.
String _location(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(PageFrame).first)).routerDelegate.currentConfiguration.uri.path;

Finder _mark(String second) => find.byWidgetPredicate((w) => w is Wordmark && w.second == second);

/// Opens the app at [location] in a window [size] logical pixels big, with
/// text scaled by [text].
Future<void> _open(WidgetTester t, String location, {Size size = _phone, double text = 1}) =>
    _openWith(t, _router(location), size: size, text: text);

/// Opens Battle Shop's own site at [location], with the routes it has there.
Future<void> _openShop(WidgetTester t, String location, {Size size = _phone, double text = 1}) =>
    _openWith(t, battleShopRouter(initialLocation: location), size: size, text: text);

Future<void> _openWith(WidgetTester t, GoRouter router, {required Size size, required double text}) async {
  t.view
    ..devicePixelRatio = 3
    ..physicalSize = size * 3;
  addTearDown(t.view.reset);
  addTearDown(router.dispose);
  await t.pumpWidget(MaterialApp.router(
    theme: BB.theme(),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(text)),
      child: child!,
    ),
  ));
  await _settle(t);
}

/// Lets loads finish and pages slide in. Not pumpAndSettle: the cart keeps
/// a timer running.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t);
}

/// Unmounts the app, which stops the cart's timer.
Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

Finder _pressable(String label) => find.byWidgetPredicate((w) => w is Pressable && w.label == label);

BBButton _primary(WidgetTester t) =>
    t.widget<BBButton>(find.byWidgetPredicate((w) => w is BBButton && w.kind == BBButtonKind.primary));

/// Two YM Tropic Blue tees and a 2XL coral tee.
Future<void> _fillCart() async {
  final shop = Shop.instance;
  final tee = (await shop.product(_tropic))!, coral = (await shop.product(_coral))!;
  shop
    ..add(tee, tee.variantFor({'Size': 'YM'})!, 2)
    ..add(coral, coral.variantFor({'Size': '2XL'})!);
}

void _expectReadingOrder(WidgetTester t, List<String> labels) {
  for (var i = 1; i < labels.length; i++) {
    final a = t.getTopLeft(find.text(labels[i - 1])), b = t.getTopLeft(find.text(labels[i]));
    expect(b.dy > a.dy + 1 || ((b.dy - a.dy).abs() <= 1 && b.dx > a.dx), isTrue,
        reason: '${labels[i]} comes after ${labels[i - 1]}');
  }
}

/// The sample shirts behind a store that can be locked or offline, or out
/// of some sizes.
class _Store extends SampleShop {
  Object? error;
  Set<String> soldOut = const {};

  @override
  Future<({List<ShopCollection> collections, List<ShopProduct> products})> catalog() async {
    if (error case final e?) throw e;
    return super.catalog();
  }

  @override
  Future<ShopProduct?> product(String handle) async {
    if (error case final e?) throw e;
    final p = await super.product(handle);
    if (p == null || soldOut.isEmpty) return p;
    return ShopProduct(
      handle: p.handle,
      title: p.title,
      minPrice: p.minPrice,
      maxPrice: p.maxPrice,
      images: p.images,
      descriptionHtml: p.descriptionHtml,
      options: p.options,
      variants: [
        for (final v in p.variants)
          ShopVariant(id: v.id, price: v.price, options: v.options, available: !soldOut.contains(v.options['Size'])),
      ],
    );
  }
}

/// The sample shirts plus a hoodie in Black and Royal, S and L, out of Royal S.
class _Hoodies extends SampleShop {
  static final hoodie = ShopProduct(
    handle: 'battle-baseball-hoodie',
    title: 'Battle Baseball Hoodie',
    minPrice: 45,
    maxPrice: 45,
    options: const [
      ShopOption('Color', ['Black', 'Royal']),
      ShopOption('Size', ['S', 'L']),
    ],
    variants: [
      for (final color in ['Black', 'Royal'])
        for (final size in ['S', 'L'])
          ShopVariant(
            id: 'sample/hoodie/$color/$size',
            price: 45,
            available: !(color == 'Royal' && size == 'S'),
            options: {'Color': color, 'Size': size},
          ),
    ],
  );

  @override
  Future<ShopProduct?> product(String handle) async => handle == hoodie.handle ? hoodie : super.product(handle);
}

/// The sample shirts plus a participating team's collection, the Cyclones,
/// with one hoodie.
class _Teams extends SampleShop {
  static const hoodie = ShopProduct(handle: 'cyclones-hoodie', title: 'Cyclones Hoodie', minPrice: 30, maxPrice: 32);

  @override
  Future<({List<ShopCollection> collections, List<ShopProduct> products})> catalog() async {
    final c = await super.catalog();
    return (
      collections: [
        const ShopCollection(handle: 'team-cyclones', title: 'Cyclones', productHandles: ['cyclones-hoodie']),
        ...c.collections,
      ],
      products: [...c.products, hoodie],
    );
  }
}

void main() {
  setUpAll(_loadAppFonts);
  setUp(() => Shop.instance = Shop(SampleShop()));
  tearDown(() => Shop.instance = null);

  testWidgets('the shop lists the sample shirts under their collection titles', (t) async {
    await _open(t, '/merch');
    expect(t.takeException(), isNull);
    double top(String text) {
      expect(find.text(text), findsOneWidget, reason: text);
      return t.getTopLeft(find.text(text)).dy;
    }

    final standard = top('Battle Baseball'), special = top('Special Edition');
    final royal = top('Battle Baseball Tee - True Royal'), blue = top('Battle Baseball Tee - Tropic Blue');
    final coral = top('Battle Baseball Special Edition Tee - Coral (Adult)');
    expect(royal, greaterThan(standard));
    expect(blue, greaterThan(standard));
    expect(special, greaterThan(royal));
    expect(special, greaterThan(blue));
    expect(coral, greaterThan(special));
    expect(find.text(r'From $25'), findsNWidgets(2));
    expect(find.text(r'From $26'), findsOneWidget);
    await _close(t);
  });

  testWidgets("participating teams come after the Battle Baseball shirts, under their own heading", (t) async {
    Shop.instance = Shop(_Teams());
    for (final size in [_phone, _desktop]) {
      await _open(t, '/merch', size: size);
      expect(t.takeException(), isNull);
      _expectReadingOrder(t, [
        'Battle Baseball',
        'Battle Baseball Tee - True Royal',
        'Special Edition',
        'Battle Baseball Special Edition Tee - Coral (Adult)',
        'Participating teams',
        'Cyclones',
        'Cyclones Hoodie',
      ]);
      expect(find.text(r'From $30'), findsOneWidget);
      await _close(t);
    }
  });

  testWidgets('the back link and Cart stay at the top while the shop or a shirt scrolls', (t) async {
    // A laptop window short enough that a shirt's page scrolls too.
    for (final size in [_phone, const Size(1280, 400)]) {
      for (final location in ['/merch', '/merch/$_tropic']) {
        Shop.instance = Shop(_Teams());
        await _fillCart();
        await _open(t, location, size: size);
        final at = '$location at ${size.width.round()} wide';
        final cart = find.text('Cart · 3'), back = find.byType(BackHeader);
        final cartAt = t.getRect(cart), backAt = t.getRect(back);

        await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
        await _settle(t);
        final page = t.state<ScrollableState>(find.byType(Scrollable).first).position;
        expect(page.pixels, greaterThan(50), reason: 'the page scrolled, $at');
        expect(t.getRect(cart), cartAt, reason: 'the Cart button, $at');
        expect(t.getRect(back), backAt, reason: 'the back link, $at');
        expect(t.takeException(), isNull, reason: at);

        await t.tap(cart);
        await _settle(t);
        expect(find.text('Your cart'), findsOneWidget, reason: at);
        await _close(t);
      }
    }
  });

  testWidgets("Home's two shirts are Battle Baseball shirts, not a team's", (t) async {
    Shop.instance = Shop(_Teams());
    await _open(t, '/');
    expect(find.text('Shop all merch'), findsOneWidget);
    expect(find.text('Battle Baseball Tee - True Royal'), findsOneWidget);
    expect(find.text('Cyclones Hoodie'), findsNothing);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('tapping a shirt opens its page', (t) async {
    await _open(t, '/merch');
    await _tap(t, find.text('Battle Baseball Tee - Tropic Blue'));
    expect(find.text('Adult'), findsOneWidget);
    expect(find.text('Add to cart'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a standard tee shows its sizes under Adult and Youth, smallest first', (t) async {
    await _open(t, '/merch/$_tropic');
    const adult = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'], youth = ['YXS', 'YS', 'YM', 'YL', 'YXL'];
    final adultTop = t.getTopLeft(find.text('Adult')).dy, youthTop = t.getTopLeft(find.text('Youth')).dy;
    expect(youthTop, greaterThan(adultTop));
    for (final s in adult) {
      expect(t.getTopLeft(find.text(s)).dy, inExclusiveRange(adultTop, youthTop), reason: '$s is an adult size');
    }
    for (final s in youth) {
      expect(t.getTopLeft(find.text(s)).dy, greaterThan(youthTop), reason: '$s is a youth size');
    }
    _expectReadingOrder(t, adult);
    _expectReadingOrder(t, youth);
    expect(find.textContaining('ST350'), findsNothing, reason: "the print shop's long names stay out of sight");
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('Add to cart asks for a size until one is picked, then adds that size', (t) async {
    await _open(t, '/merch/$_tropic');
    expect(_primary(t).label, 'Add to cart');
    await _tap(t, find.text('Add to cart'));
    expect(find.text('Pick a size.'), findsOneWidget);
    expect(Shop.instance.lines, isEmpty);
    await t.pump(const Duration(seconds: 5)); // the note goes away

    await _tap(t, find.text('YM'));
    expect(_primary(t).label, 'Add to cart');
    expect(_primary(t).onPressed, isNotNull);

    await _tap(t, _pressable('One more'));
    await _tap(t, _pressable('One more'));
    await _tap(t, find.text('Add to cart'));
    final line = Shop.instance.lines.single;
    expect(line.variantId, 'sample/$_tropic/YM');
    expect(line.detail, 'Size YM');
    expect(line.qty, 3);
    expect(Shop.instance.count, 3);
    expect(find.text('3 added to your cart.'), findsOneWidget);
    expect(find.text('Cart · 3'), findsOneWidget);

    await _tap(t, find.text('Add to cart'));
    expect(Shop.instance.lines.single.qty, 4, reason: 'the quantity went back to one after adding');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets("the button's label isn't cut off with large text or on a narrow phone", (t) async {
    for (final (size, text) in [(_phone, 1.5), (_narrow, 1.0), (_narrow, 1.5)]) {
      Shop.instance = Shop(SampleShop());
      await _open(t, '/merch/$_tropic', size: size, text: text);
      for (final picked in [false, true]) {
        if (picked) await _tap(t, find.text('YM'));
        final paragraph = t.renderObject<RenderParagraph>(find.text('Add to cart'));
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '"Add to cart" at ${size.width.round()} wide, text x$text${picked ? ', size picked' : ''}');
      }
      expect(t.takeException(), isNull);
      await _close(t);
    }
  });

  testWidgets("a sold-out size is faded and can't be picked", (t) async {
    Shop.instance = Shop(_Store()..soldOut = {'YM'});
    await _open(t, '/merch/$_tropic');
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'YM, sold out'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'YL, sold out'), findsNothing);
    await _tap(t, find.text('YM'));
    await _tap(t, find.text('Add to cart'));
    expect(find.text('Pick a size.'), findsOneWidget, reason: "YM couldn't be picked");
    expect(Shop.instance.lines, isEmpty);
    await t.pump(const Duration(seconds: 5));
    await _tap(t, find.text('YL'));
    await _tap(t, find.text('Add to cart'));
    expect(Shop.instance.lines.single.detail, 'Size YL');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('picking another color lets go of a size that color is out of', (t) async {
    Shop.instance = Shop(_Hoodies());
    await _open(t, '/merch/battle-baseball-hoodie');
    await _tap(t, find.text('Black'));
    await _tap(t, find.text('S'));
    await _tap(t, find.text('Royal'));
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'S, sold out'), findsOneWidget);
    await _tap(t, find.text('Add to cart'));
    expect(find.text('Pick a size.'), findsOneWidget, reason: 'Royal S is sold out, so S was let go');
    expect(Shop.instance.lines, isEmpty);
    await t.pump(const Duration(seconds: 5));

    await _tap(t, find.text('L'));
    await _tap(t, find.text('Add to cart'));
    expect(Shop.instance.lines.single.detail, 'Color Royal · Size L');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets("a shirt that isn't in the shop is Nothing here", (t) async {
    await _open(t, '/merch/battle-baseball-hoodie');
    expect(find.text('Nothing here.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets("Home's Merch section shows two shirts and the way into the shop", (t) async {
    await _fillCart();
    await _open(t, '/');
    expect(find.text('Merch'), findsOneWidget);
    expect(find.text('Battle Baseball Tee - True Royal'), findsOneWidget);
    expect(find.text('Battle Baseball Tee - Tropic Blue'), findsOneWidget);
    expect(find.text('Battle Baseball Special Edition Tee - Coral (Adult)'), findsNothing);
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text('Cart · 3'), findsOneWidget);
    await _tap(t, find.text('Shop all merch'));
    expect(find.text('Special Edition'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('the cart shows its lines and subtotal, and the remove button takes a line out', (t) async {
    await _fillCart();
    await _open(t, '/merch/cart');
    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('Battle Baseball Tee - Tropic Blue'), findsOneWidget);
    expect(find.text('Size YM'), findsOneWidget);
    expect(find.text(r'$50'), findsOneWidget);
    expect(find.text('Battle Baseball Special Edition Tee - Coral (Adult)'), findsOneWidget);
    expect(find.text('Size 2XL'), findsOneWidget);
    expect(find.text(r'$28'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(r'$78'), findsOneWidget);

    // The coral line's own quantity buttons, which say which shirt they're for.
    await _tap(t, _pressable('One more, $_coralLine'));
    expect(Shop.instance.lines.last.qty, 2);
    expect(find.text(r'$56'), findsOneWidget);
    expect(find.text(r'$106'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Quantity 2, $_coralLine'),
        findsOneWidget);
    await _tap(t, _pressable('One fewer, $_coralLine'));
    await _tap(t, _pressable('One fewer, $_coralLine'));
    expect(Shop.instance.lines.last.qty, 1, reason: 'the minus stops at one; the remove button takes a line out');

    await _tap(
      t,
      find.byWidgetPredicate(
          (w) => w is IconTap && w.label == 'Remove $_coralLine'),
    );
    expect(Shop.instance.lines.map((l) => l.variantId), ['sample/$_tropic/YM']);
    expect(find.text('Size 2XL'), findsNothing);
    expect(find.text(r'$50'), findsNWidgets(2), reason: 'the line, and the subtotal');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a shirt Shopify stopped selling shows Sold out and stays out of the subtotal', (t) async {
    final shop = Shop.instance;
    final tee = (await shop.product(_tropic))!;
    shop.add(tee, tee.variantFor({'Size': 'M'})!);
    // A shirt the shop no longer lists: the cart's check with the shop marks it.
    const retired = ShopProduct(
      handle: 'battle-baseball-tee-heather',
      title: 'Battle Baseball Tee - Heather',
      minPrice: 24,
      maxPrice: 24,
      options: [
        ShopOption('Size', ['L']),
      ],
      variants: [
        ShopVariant(id: 'sample/battle-baseball-tee-heather/L', price: 24, options: {'Size': 'L'}),
      ],
    );
    shop.add(retired, retired.variants.single);

    await _open(t, '/merch/cart');
    expect(shop.lines.last.available, isFalse);
    expect(find.text('Battle Baseball Tee - Heather'), findsOneWidget);
    expect(find.text('Sold out'), findsOneWidget);
    expect(find.text(r'$24'), findsNothing);
    expect(find.text(r'$25'), findsNWidgets(2), reason: "the tee's line, and the subtotal without the sold-out shirt");
    expect(find.textContaining('Sold-out shirts stay out of your order.'), findsOneWidget);
    expect(_primary(t).onPressed, isNotNull);

    shop.remove(tee.variantFor({'Size': 'M'})!.id);
    await _settle(t);
    expect(find.text(r'$0'), findsOneWidget);
    expect(_primary(t).onPressed, isNull, reason: 'nothing left to check out');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets("sample shirts can't be checked out, and the cart says so", (t) async {
    await _fillCart();
    await _open(t, '/merch/cart');
    await _tap(t, find.text('Check out'));
    expect(find.text('These are sample shirts, so checkout is switched off.'), findsOneWidget);
    expect(Shop.instance.checkoutPending, isFalse);
    expect(Shop.instance.count, 3);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('while the store is locked the shop and its pages say Coming soon', (t) async {
    Shop.instance = Shop(_Store()..error = const ShopLocked());
    await _open(t, '/');
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Military Green Tee'), findsOneWidget);
    await _close(t);

    await _open(t, '/merch');
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.textContaining('Battle Baseball tees are on the way.'), findsOneWidget);
    expect(find.text('Military Green Tee'), findsOneWidget);
    await _close(t);

    await _open(t, '/merch/$_tropic');
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Add to cart'), findsNothing);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('the shop and shirt pages lay out on a phone, a narrow phone and a desktop, at 1x and 1.5x text',
      (t) async {
    for (final size in [_phone, _narrow, _desktop]) {
      for (final text in [1.0, 1.5]) {
        for (final location in ['/merch', '/merch/$_tropic', '/merch/$_coral']) {
          Shop.instance = Shop(SampleShop());
          await _open(t, location, size: size, text: text);
          expect(t.takeException(), isNull, reason: '$location at ${size.width.round()} wide, text x$text');
          expect(find.text(location == '/merch' ? 'Battle Baseball' : 'Add to cart'), findsOneWidget);
          await _close(t);
        }
      }
    }
  });

  testWidgets('the cart lays out on a phone and a desktop, at 1x and 1.5x text', (t) async {
    for (final size in [_phone, _desktop]) {
      for (final text in [1.0, 1.5]) {
        Shop.instance = Shop(SampleShop());
        await _fillCart();
        await _open(t, '/merch/cart', size: size, text: text);
        expect(t.takeException(), isNull, reason: 'the cart at ${size.width.round()} wide, text x$text');
        expect(find.text(r'$78'), findsOneWidget);
        await _close(t);
      }
    }
  });

  testWidgets('the cart fits a narrow phone', (t) async {
    for (final text in [1.0, 1.5]) {
      Shop.instance = Shop(SampleShop());
      await _fillCart();
      await _open(t, '/merch/cart', size: _narrow, text: text);
      expect(t.takeException(), isNull, reason: 'the cart at 320 wide, text x$text');
      await _close(t);
    }
  });

  testWidgets('after a failed load, Home says so, and opening the shop loads it again without errors', (t) async {
    final store = _Store()..error = const ShopFailure('offline');
    Shop.instance = Shop(store);
    await _open(t, '/');
    expect(Shop.instance.status, ShopStatus.failed);
    expect(find.text("The shop didn't load."), findsOneWidget);
    expect(find.text('Military Green Tee'), findsNothing, reason: "the coming-soon shirts aren't what failed to load");

    store.error = null;
    GoRouter.of(t.element(find.byType(MerchSection))).go('/merch');
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(Shop.instance.status, ShopStatus.ready);
    expect(find.text('Battle Baseball Tee - Tropic Blue'), findsOneWidget);
    await _close(t);
  });

  testWidgets("Try again in Home's Merch section loads the shop", (t) async {
    final store = _Store()..error = const ShopFailure('offline');
    Shop.instance = Shop(store);
    await _open(t, '/');
    store.error = null;
    await _tap(t, find.text('Try again'));
    expect(t.takeException(), isNull);
    expect(find.text('Battle Baseball Tee - Tropic Blue'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a shirt link opened while the store is locked goes back to Merch', (t) async {
    Shop.instance = Shop(_Store()..error = const ShopLocked());
    await _open(t, '/merch/$_tropic');
    expect(find.byWidgetPredicate((w) => w is BackHeader && w.label == 'Merch'), findsOneWidget);
    await _close(t);
  });

  // --- Battle Shop: the same shop on a site of its own ---

  testWidgets('Battle Shop lists the same shirts under its own mark, with no way Home', (t) async {
    for (final size in [_phone, _desktop]) {
      Shop.instance = Shop(_Teams());
      await _fillCart();
      await _openShop(t, '/', size: size);
      final at = '${size.width.round()} wide';
      expect(t.takeException(), isNull, reason: at);
      expect(_mark('Shop'), findsOneWidget, reason: at);
      expect(_mark('Baseball'), findsNothing, reason: at);
      expect(find.byType(BackHeader), findsNothing, reason: 'nothing to go back to, $at');
      expect(find.text('Home'), findsNothing, reason: at);
      expect(find.text('Merch'), findsNothing, reason: at);
      expect(find.text('Cart · 3'), findsOneWidget, reason: at);
      _expectReadingOrder(t, [
        'Battle Baseball',
        'Battle Baseball Tee - True Royal',
        'Special Edition',
        'Battle Baseball Special Edition Tee - Coral (Adult)',
        'Participating teams',
        'Cyclones',
        'Cyclones Hoodie',
      ]);
      expect(find.text('Checkout runs on Shopify.'), findsOneWidget, reason: at);
      await _close(t);
    }
  });

  testWidgets("Battle Shop's shirts are at /<handle>, its cart at /cart, and back links lead to its front page",
      (t) async {
    for (final size in [_phone, _desktop]) {
      Shop.instance = Shop(SampleShop());
      final at = '${size.width.round()} wide';
      await _openShop(t, '/', size: size);
      await _tap(t, find.text('Battle Baseball Tee - Tropic Blue'));
      expect(_location(t), '/$_tropic', reason: at);
      expect(find.text('Add to cart'), findsOneWidget, reason: at);
      expect(find.byWidgetPredicate((w) => w is BackHeader && w.label == 'Shop'), findsOneWidget, reason: at);

      await _tap(t, find.text('YM'));
      await _tap(t, find.text('Add to cart'));
      await _tap(t, find.text('Cart · 1'));
      expect(_location(t), '/cart', reason: at);
      expect(find.text('Your cart'), findsOneWidget, reason: at);
      expect(find.text('Size YM'), findsOneWidget, reason: at);

      // The line's photo leads back to the shirt, and its back link to the shop.
      await _tap(t, _pressable('Battle Baseball Tee - Tropic Blue'));
      expect(_location(t), '/$_tropic', reason: at);
      await _tap(t, _pressable('Back to Shop'));
      expect(_location(t), '/', reason: at);
      expect(find.text('Special Edition'), findsOneWidget, reason: at);
      expect(t.takeException(), isNull, reason: at);
      await _close(t);
    }
  });

  testWidgets("Battle Shop's empty cart and missing shirts lead back to the shop, not Home", (t) async {
    await _openShop(t, '/cart');
    expect(find.text('Nothing in your cart yet.'), findsOneWidget);
    expect(find.text('Shop merch'), findsNothing);
    await _tap(t, find.text('Back to the shop'));
    expect(_location(t), '/');
    await _close(t);

    await _openShop(t, '/no-such-shirt');
    expect(find.text('Nothing here.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    await _tap(t, find.text('Battle Shop'));
    expect(_location(t), '/');
    expect(find.text('Battle Baseball Tee - Tropic Blue'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets("none of the app's screens has an address on Battle Shop's site", (t) async {
    for (final location in ['/events', '/players', '/leaders', '/account', '/sign-in', '/merch', '/admin/colors']) {
      await _openShop(t, location);
      expect(t.takeException(), isNull, reason: location);
      expect(find.byType(BattleShopShell), findsOneWidget, reason: location);
      expect(find.byType(AppShell), findsNothing, reason: location);
      expect(find.text('Nothing here.'), findsOneWidget, reason: location);
      expect(find.text('Home'), findsNothing, reason: location);
      await _tap(t, find.text('Battle Shop'));
      expect(find.text('Battle Baseball Tee - Tropic Blue'), findsOneWidget, reason: location);
      await _close(t);
    }
  });

  testWidgets("on a phone Battle Shop's mark and Cart stay at the top while the shop scrolls", (t) async {
    Shop.instance = Shop(_Teams());
    await _fillCart();
    await _openShop(t, '/');
    final cart = find.text('Cart · 3'), mark = _mark('Shop');
    final cartAt = t.getRect(cart), markAt = t.getRect(mark);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
    await _settle(t);
    expect(t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, greaterThan(50));
    expect(t.getRect(cart), cartAt);
    expect(t.getRect(mark), markAt);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('while the store is locked Battle Shop says Coming soon under its own name', (t) async {
    for (final location in ['/', '/$_tropic']) {
      Shop.instance = Shop(_Store()..error = const ShopLocked());
      await _openShop(t, location);
      expect(find.text('Battle Shop'), findsOneWidget, reason: location);
      expect(find.text('Coming soon'), findsOneWidget, reason: location);
      expect(find.text('Merch'), findsNothing, reason: location);
      expect(find.text('Home'), findsNothing, reason: location);
      expect(t.takeException(), isNull, reason: location);
      await _close(t);
    }
  });

  testWidgets('Battle Shop lays out on a phone, a narrow phone and a desktop, at 1x and 1.5x text, with sample data too',
      (t) async {
    addTearDown(() => Repo.instance = Repo());
    for (final demo in [false, true]) {
      Repo.instance = demo ? DemoRepo() : Repo();
      for (final size in [_phone, _narrow, const Size(960, 700), _desktop]) {
        for (final text in [1.0, 1.5]) {
          for (final location in ['/', '/$_tropic', '/cart']) {
            Shop.instance = Shop(SampleShop());
            await _fillCart();
            await _openShop(t, location, size: size, text: text);
            final at = '$location at ${size.width.round()} wide, text x$text${demo ? ', demo' : ''}';
            expect(t.takeException(), isNull, reason: at);
            if (location != '/cart') {
              final cart = t.getRect(find.text('Cart · 3'));
              expect(cart.right, lessThanOrEqualTo(size.width), reason: 'the Cart button, $at');
              expect(cart.left, greaterThan(0), reason: 'the Cart button, $at');
            }
            await _close(t);
          }
        }
      }
    }
  });

  testWidgets('in the app itself /shop is Merch, inside the app', (t) async {
    Session.demoAs = 'family'; // signed in as Jamie, with nothing read from Firebase
    t.view
      ..devicePixelRatio = 3
      ..physicalSize = _phone * 3;
    addTearDown(t.view.reset);
    addTearDown(() => router.go('/'));

    router.go('/shop');
    await t.pumpWidget(const BattleBaseballApp());
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/merch');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(BattleShopShell), findsNothing);
    expect(find.byWidgetPredicate((w) => w is BackHeader && w.label == 'Home'), findsOneWidget);
    await _close(t);
  });

  testWidgets('the desktop top bar fits from 960 px with the cart, the sample stamp and larger text', (t) async {
    Session.demoAs = 'family'; // signed in as Jamie, with nothing read from Firebase
    addTearDown(() => Repo.instance = Repo());
    addTearDown(t.view.reset);
    for (final demo in [false, true]) {
      Repo.instance = demo ? DemoRepo() : Repo();
      for (final width in [960.0, 1000.0, 1100.0, 1440.0]) {
        for (final text in [1.0, 1.5]) {
          for (final cart in [false, true]) {
            Shop.instance = Shop(SampleShop());
            if (cart) await _fillCart();
            t.view
              ..devicePixelRatio = 1
              ..physicalSize = Size(width, 800);
            await t.pumpWidget(const SizedBox()); // a fresh tree, listening to this Shop
            await t.pumpWidget(MaterialApp(
              theme: BB.theme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(text)),
                child: child!,
              ),
              home: const AppShell(location: '/events', child: SizedBox()),
            ));
            await t.pump();
            final at = '${width.round()} wide, text x$text${cart ? ', with a cart' : ''}${demo ? ', demo' : ''}';
            expect(t.takeException(), isNull, reason: at);
            expect(t.getRect(find.text('Jamie')).right, lessThanOrEqualTo(width), reason: 'the account button at $at');
            expect(find.text('3'), cart ? findsOneWidget : findsNothing, reason: 'the cart at $at');
          }
        }
      }
    }
    await t.pumpWidget(const SizedBox());
  });
}
