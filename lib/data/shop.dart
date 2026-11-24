// The merch shop. Products, collections and prices come from the Shopify
// store through its Storefront API, so a shirt added or repriced in Shopify
// shows up here by itself. The cart lives on this device, and paying happens
// on Shopify's own checkout page. None of it needs a sign-in.
import 'dart:async';
import 'dart:convert';

import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/shop_sample.dart';
import 'package:battle_baseball/data/shop_store.dart'
    if (dart.library.js_interop) 'package:battle_baseball/data/shop_store_web.dart' as store;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Which Shopify store the shop reads.
abstract final class ShopConfig {
  static const domain = 't03zrq-mv.myshopify.com';
  static const apiVersion = '2026-10';

  /// Optional. Without one the Storefront API still answers for products,
  /// collections and carts once the store's password page is off. A public
  /// token from Shopify's Headless channel (safe to ship in the app) can be
  /// passed with --dart-define=SHOPIFY_STOREFRONT_TOKEN=... if that changes.
  static const token = String.fromEnvironment('SHOPIFY_STOREFRONT_TOKEN');
}

// ---------------------------------------------------------------------------
// What the shop sells
// ---------------------------------------------------------------------------

class ShopImage {
  const ShopImage(this.url, {this.width, this.height});

  /// A Shopify CDN address, or a bundled asset for the sample shirts.
  final String url;
  final int? width;
  final int? height;

  bool get isAsset => url.startsWith('assets/');

  /// The address of a copy about [width] px wide; Shopify's image server
  /// resizes on request.
  String sized(int width) {
    if (isAsset) return url;
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {...uri.queryParameters, 'width': '$width'}).toString();
  }

  static ShopImage? fromJson(Object? j) {
    if (j is! Map<String, dynamic> || j['url'] is! String) return null;
    return ShopImage(j['url'] as String, width: j['width'] as int?, height: j['height'] as int?);
  }
}

/// One thing a shopper chooses between, as Shopify lists it: "Size" with
/// its values.
class ShopOption {
  const ShopOption(this.name, this.values);
  final String name;
  final List<String> values;
}

/// One buyable version of a product: a shirt in one size.
class ShopVariant {
  const ShopVariant({
    required this.id,
    required this.price,
    required this.options,
    this.available = true,
    this.compareAt,
    this.image,
  });

  /// Shopify's id, "gid://shopify/ProductVariant/123". Checkout needs it.
  final String id;
  final double price;

  /// The value this variant has for each of the product's options.
  final Map<String, String> options;
  final bool available;

  /// The price it's marked down from, when it's on sale.
  final double? compareAt;
  final ShopImage? image;
}

class ShopProduct {
  const ShopProduct({
    required this.handle,
    required this.title,
    required this.minPrice,
    required this.maxPrice,
    this.currency = 'USD',
    this.available = true,
    this.images = const [],
    this.descriptionHtml = '',
    this.options = const [],
    this.variants = const [],
  });

  /// The product's name in its Shopify address, and in ours (`/merch/<handle>`).
  final String handle;
  final String title;
  final double minPrice;
  final double maxPrice;
  final String currency;
  final bool available;
  final List<ShopImage> images;

  /// The listing's description as Shopify stores it. Empty on a product read
  /// as part of the catalog, like [options] and [variants].
  final String descriptionHtml;
  final List<ShopOption> options;
  final List<ShopVariant> variants;

  ShopImage? get image => images.isEmpty ? null : images.first;

  /// "$25", or "From $25" when sizes are priced differently.
  String get priceLabel =>
      minPrice == maxPrice ? shopPrice(minPrice, currency) : 'From ${shopPrice(minPrice, currency)}';

  /// The choices a shopper makes to land on one variant.
  List<Choice> get choices => _choiceCache[this] ??= _choices(this);

  /// The variant that matches what's been picked, once every choice is made.
  ShopVariant? variantFor(Map<String, String> picked) {
    final names = [for (final c in choices) c.name];
    if (names.any((n) => picked[n] == null)) return null;
    for (final v in variants) {
      if (names.every((n) => v.options[n] == picked[n])) return v;
    }
    return null;
  }

  /// Whether [value] of the choice [name] can be bought, given what's picked
  /// for the choices listed before it. Later picks don't count, so the first
  /// choice can always be changed and each one after it narrows to what goes
  /// with the picks above it.
  bool offers(String name, String value, Map<String, String> picked) {
    final before = <String>{};
    for (final c in choices) {
      if (c.name == name) break;
      before.add(c.name);
    }
    return variants.any((v) =>
        v.available &&
        v.options[name] == value &&
        before.every((n) => picked[n] == null || v.options[n] == picked[n]));
  }

  /// Where in [images] the photo for what's been picked is: when every
  /// variant that fits the picks has the same photo (a color's own mockup),
  /// its place. The adult and youth shirts of one color can each have their
  /// own photo; picking just the color shows the first of them, since the
  /// size, not a separate pick, says which shirt it is. Null when the photos
  /// differ by anything else still to pick (picking a size on a shirt with
  /// two colors), or none of them has one.
  int? photoFor(Map<String, String> picked) {
    // The options the shopper doesn't pick: their value follows from the
    // size ("Product": the adult or the youth shirt).
    final picks = {for (final c in choices) c.name};
    final headings = [for (final o in options) if (o.values.length > 1 && !picks.contains(o.name)) o.name];
    String? first;
    final byShirt = <String, String>{};
    for (final v in variants) {
      if (!picked.entries.every((e) => v.options[e.key] == e.value)) continue;
      final url = v.image?.url;
      if (url == null) continue;
      final at = _photoPath(url);
      first ??= at;
      final shirt = [for (final h in headings) v.options[h]].join('\u0000');
      if ((byShirt[shirt] ??= at) != at) return null;
    }
    if (first == null) return null;
    final i = images.indexWhere((im) => _photoPath(im.url) == first);
    return i < 0 ? null : i;
  }

  /// A photo's address without its version, so the same file matches.
  static String _photoPath(String url) => url.split('?').first;

  /// A variant in a few words, for a cart line: "Size YM".
  String describe(ShopVariant v) => [
        for (final c in choices) '${c.name} ${c.label(v.options[c.name] ?? '')}'.trim(),
      ].join(' · ');

  static ShopProduct fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(Object? o) => o is Map<String, dynamic> ? o : const {};
    List<Object?> nodes(Object? o) => (map(o)['nodes'] as List?) ?? const [];
    final range = map(j['priceRange']);
    final min = map(range['minVariantPrice']);
    final images = [
      for (final n in nodes(j['images'])) ?ShopImage.fromJson(n),
    ];
    final featured = ShopImage.fromJson(j['featuredImage']);
    return ShopProduct(
      handle: j['handle'] as String,
      title: (j['title'] as String?) ?? '',
      minPrice: _amount(min),
      maxPrice: _amount(range['maxVariantPrice']),
      currency: (min['currencyCode'] as String?) ?? 'USD',
      available: (j['availableForSale'] as bool?) ?? true,
      images: images.isEmpty && featured != null ? [featured] : images,
      descriptionHtml: (j['descriptionHtml'] as String?) ?? '',
      options: [
        for (final o in (j['options'] as List?) ?? const [])
          ShopOption(
            map(o)['name'] as String,
            [for (final v in (map(o)['optionValues'] as List?) ?? const []) map(v)['name'] as String],
          ),
      ],
      variants: [
        for (final n in nodes(j['variants']))
          ShopVariant(
            id: map(n)['id'] as String,
            price: _amount(map(n)['price']),
            compareAt: map(n)['compareAtPrice'] == null ? null : _amount(map(n)['compareAtPrice']),
            available: (map(n)['availableForSale'] as bool?) ?? true,
            image: ShopImage.fromJson(map(n)['image']),
            options: {
              for (final o in (map(n)['selectedOptions'] as List?) ?? const [])
                map(o)['name'] as String: map(o)['value'] as String,
            },
          ),
      ],
    );
  }
}

double _amount(Object? money) =>
    money is Map<String, dynamic> ? double.tryParse('${money['amount']}') ?? 0 : 0;

/// Each product's choices, worked out once.
final _choiceCache = Expando<List<Choice>>('choices');

/// A group of products as Shopify groups them: "Battle Baseball", "Special
/// Edition", a team.
class ShopCollection {
  const ShopCollection({
    required this.handle,
    required this.title,
    this.description = '',
    this.productHandles = const [],
  });
  final String handle;
  final String title;
  final String description;
  final List<String> productHandles;

  /// A participating team's collection: its handle starts with "team-"
  /// ("team-cyclones"). Set it in Shopify under the collection's search
  /// engine listing, "URL handle".
  bool get isTeam => handle.startsWith(teamPrefix);

  static const teamPrefix = 'team-';
}

/// One section of the shop: a collection's products under its title.
/// [team] marks a participating team's collection.
typedef ShopSection = ({String title, String description, List<ShopProduct> products, bool team});

/// "$25" or "$25.50".
String shopPrice(double amount, [String currency = 'USD']) {
  final whole = amount == amount.roundToDouble();
  final digits = amount.abs().toStringAsFixed(whole ? 0 : 2);
  final sign = amount < 0 ? '-' : '';
  return currency == 'USD' ? '$sign\$$digits' : '$sign$digits $currency';
}

// ---------------------------------------------------------------------------
// Choices: turning Shopify's options into what a shopper actually picks
// ---------------------------------------------------------------------------

/// One thing the shopper picks ("Size"), with its values in the order to
/// show them, split into groups when another option sorts them ("Adult",
/// "Youth").
class Choice {
  const Choice(this.name, this.groups, {this.labels = const {}});
  final String name;
  final List<ChoiceGroup> groups;

  /// What to show for a value that reads badly as it is: the print shop's
  /// long shirt names show as "Youth" and "Adult".
  final Map<String, String> labels;

  Iterable<String> get values => groups.expand((g) => g.values);

  String label(String value) => labels[value] ?? value;
}

class ChoiceGroup {
  const ChoiceGroup(this.values, {this.label});

  /// Null when the choice has a single unnamed group.
  final String? label;
  final List<String> values;
}

/// Sizes from small to large, youth before adult.
const _sizes = [
  'YXS', 'YS', 'YM', 'YL', 'YXL',
  'XXS', 'XS', 'S', 'M', 'L', 'XL',
  '2XL', 'XXL', '3XL', 'XXXL', '4XL', '5XL', '6XL',
];

List<String> _inSizeOrder(List<String> values) {
  int rank(String v) => _sizes.indexOf(v.trim().toUpperCase());
  if (values.any((v) => rank(v) < 0)) return values;
  return [...values]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// An option with one value is nothing to pick (Color: Coral). An option
/// whose value always follows from another's is nothing to pick either: the
/// print shop lists the adult and youth shirt as a "Product" option, and the
/// size already says which one it is. That option becomes the headings the
/// sizes sit under.
List<Choice> _choices(ShopProduct p) {
  final multi = [for (final o in p.options) if (o.values.length > 1) o];

  /// For each value of [a], the one value of [b] it comes with; null when
  /// some value of [a] comes with more than one.
  Map<String, String>? follows(ShopOption a, ShopOption b) {
    final map = <String, String>{};
    for (final v in p.variants) {
      final av = v.options[a.name], bv = v.options[b.name];
      if (av == null || bv == null) return null;
      if ((map[av] ??= bv) != bv) return null;
    }
    return map;
  }

  final grouping = <ShopOption, (ShopOption, Map<String, String>)>{};
  for (final a in multi) {
    for (final b in multi) {
      if (identical(a, b) || b.values.length >= a.values.length) continue;
      final map = follows(a, b);
      if (map != null) {
        grouping[a] = (b, map);
        break;
      }
    }
  }
  final headings = {for (final g in grouping.values) g.$1};

  return [
    for (final o in multi)
      if (!headings.contains(o))
        if (grouping[o] case (final by, final map))
          Choice(o.name, [
            // Groups in the order their first variant appears.
            for (final g in {for (final v in p.variants) ?v.options[by.name]})
              ChoiceGroup(
                _inSizeOrder([for (final v in o.values) if (map[v] == g) v]),
                label: _youthAdult(by.values)?[g] ?? g,
              ),
          ])
        else
          Choice(o.name, [ChoiceGroup(_inSizeOrder(o.values))], labels: _youthAdult(o.values) ?? const {}),
  ];
}

/// The print shop's product names are long ("Sport-Tek YST350 ... Youth ...
/// Tee", "Gildan ... Kids' Hoodie"). When there are two and just one is a
/// youth shirt, they read "Youth" and "Adult" instead.
Map<String, String>? _youthAdult(List<String> values) {
  bool youth(String s) => RegExp(r'\byouth\b|\bkids?\b', caseSensitive: false).hasMatch(s);
  if (values.length != 2 || values.where(youth).length != 1) return null;
  return {for (final v in values) v: youth(v) ? 'Youth' : 'Adult'};
}

// ---------------------------------------------------------------------------
// Where the shop's data comes from
// ---------------------------------------------------------------------------

sealed class ShopException implements Exception {
  const ShopException();
}

/// The Shopify store still has its password page on, so it isn't selling to
/// the public yet. The app shows "Coming soon".
class ShopLocked extends ShopException {
  const ShopLocked();
}

/// Sample data can't be checked out.
class ShopIsSample extends ShopException {
  const ShopIsSample();
}

class ShopFailure extends ShopException {
  const ShopFailure(this.message);
  final String message;
  @override
  String toString() => 'ShopFailure: $message';
}

/// Shopify left some of the cart out of a checkout: taken down, sold out,
/// or not enough left. [accepted] says how many of each variant it did take.
class ShopLinesUnavailable extends ShopException {
  const ShopLinesUnavailable(this.variantIds, {this.accepted = const {}});
  final List<String> variantIds;
  final Map<String, int> accepted;
}

abstract class ShopBackend {
  Future<({List<ShopCollection> collections, List<ShopProduct> products})> catalog();

  /// One product with its description, options and variants, or null when
  /// no product has that handle.
  Future<ShopProduct?> product(String handle);

  /// Makes a Shopify cart holding [lines] and returns it with the page to
  /// pay on and how many of each variant it took. Throws
  /// [ShopLinesUnavailable] when Shopify left any of them out or short.
  Future<({String cartId, Uri url, Map<String, int> accepted})> startCheckout(List<CartLine> lines);

  /// False once the cart is gone, which is what happens when its order is
  /// placed.
  Future<bool> cartOpen(String cartId);

  /// Whether each variant is for sale now, and its price. A variant Shopify
  /// no longer has is left out.
  Future<Map<String, ({bool available, double price})>> variants(List<String> ids);
}

/// Shopify's Storefront API (GraphQL).
class Storefront implements ShopBackend {
  Storefront({http.Client? client, Uri? endpoint, this.token = ShopConfig.token})
      : _client = client ?? http.Client(),
        endpoint = endpoint ??
            Uri.https(ShopConfig.domain, '/api/${ShopConfig.apiVersion}/graphql.json');

  final http.Client _client;
  final Uri endpoint;
  final String token;

  static const _money = '{ amount currencyCode }';
  static const _image = '{ url width height }';

  // Products come 60 at a time; a bigger catalog will want a second page.
  static const _catalog = '''
query Catalog {
  collections(first: 25, sortKey: TITLE) {
    nodes { handle title description products(first: 60) { nodes { handle } } }
  }
  products(first: 60) {
    nodes {
      handle title availableForSale
      featuredImage $_image
      priceRange { minVariantPrice $_money maxVariantPrice $_money }
    }
  }
}''';

  static const _product = '''
query Product(\$handle: String!) {
  product(handle: \$handle) {
    handle title availableForSale descriptionHtml
    options { name optionValues { name } }
    featuredImage $_image
    images(first: 12) { nodes $_image }
    priceRange { minVariantPrice $_money maxVariantPrice $_money }
    variants(first: 100) {
      nodes {
        id availableForSale
        price $_money
        compareAtPrice $_money
        selectedOptions { name value }
        image $_image
      }
    }
  }
}''';

  static const _checkout = '''
mutation Checkout(\$lines: [CartLineInput!]!) {
  cartCreate(input: { lines: \$lines }) {
    cart {
      id checkoutUrl
      lines(first: 100) { nodes { quantity merchandise { ... on ProductVariant { id } } } }
    }
    userErrors { field message }
    warnings { code target message }
  }
}''';

  static const _cart = 'query Cart(\$id: ID!) { cart(id: \$id) { id } }';

  static const _variants = '''
query Variants(\$ids: [ID!]!) {
  nodes(ids: \$ids) { ... on ProductVariant { id availableForSale price $_money } }
}''';

  Future<Map<String, dynamic>> _run(String query, [Map<String, dynamic>? variables]) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token.isNotEmpty) 'X-Shopify-Storefront-Access-Token': token,
            },
            body: jsonEncode({'query': query, 'variables': ?variables}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ShopFailure('$e');
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {}
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final errors = map['errors'];
    final said = switch (errors) {
      final List<Object?> list => [for (final e in list) e is Map ? '${e['message']}' : '$e'].join(' '),
      null => '',
      _ => '$errors',
    };
    // "Online Store channel is locked." while the store's password page is
    // on; 402 "Unavailable Shop" while it's paused.
    if (said.toLowerCase().contains('locked') || res.statusCode == 402) throw const ShopLocked();
    final data = map['data'];
    // Data that comes with errors is partial: a field Shopify couldn't
    // answer reads as null, which would look like "no such cart".
    if (res.statusCode != 200 || data is! Map<String, dynamic> || said.isNotEmpty) {
      throw ShopFailure(said.isEmpty ? 'HTTP ${res.statusCode}' : said);
    }
    return data;
  }

  @override
  Future<({List<ShopCollection> collections, List<ShopProduct> products})> catalog() async {
    final data = await _run(_catalog);
    List<Object?> nodes(Object? o) => o is Map<String, dynamic> ? (o['nodes'] as List?) ?? const [] : const [];
    return (
      collections: [
        for (final n in nodes(data['collections']).cast<Map<String, dynamic>>())
          ShopCollection(
            handle: n['handle'] as String,
            title: (n['title'] as String?) ?? '',
            description: (n['description'] as String?) ?? '',
            productHandles: [
              for (final p in nodes(n['products']).cast<Map<String, dynamic>>()) p['handle'] as String,
            ],
          ),
      ],
      products: [
        for (final n in nodes(data['products']).cast<Map<String, dynamic>>()) ShopProduct.fromJson(n),
      ],
    );
  }

  @override
  Future<ShopProduct?> product(String handle) async {
    final data = await _run(_product, {'handle': handle});
    final p = data['product'];
    return p is Map<String, dynamic> ? ShopProduct.fromJson(p) : null;
  }

  @override
  Future<({String cartId, Uri url, Map<String, int> accepted})> startCheckout(List<CartLine> lines) async {
    // What's sent, read now: the cart can change while Shopify answers.
    final sent = <String, int>{};
    for (final l in lines) {
      sent[l.variantId] = (sent[l.variantId] ?? 0) + l.qty;
    }
    final data = await _run(_checkout, {
      'lines': [
        for (final e in sent.entries) {'merchandiseId': e.key, 'quantity': e.value},
      ],
    });
    final made = data['cartCreate'];
    final cart = made is Map<String, dynamic> ? made['cart'] : null;
    if (cart is! Map<String, dynamic> || cart['checkoutUrl'] is! String) {
      final errors = [
        for (final e in made is Map<String, dynamic> ? (made['userErrors'] as List?) ?? const [] : const [])
          if (e is Map<String, dynamic>) e,
      ];
      // An error about one line names it: ["input", "lines", "0", "merchandiseId"].
      final ids = sent.keys.toList();
      final gone = <String>{
        for (final e in errors)
          if (e['field'] case ['input', 'lines', final Object i, ...])
            if (int.tryParse('$i') case final n? when n >= 0 && n < ids.length) ids[n],
      };
      if (gone.isNotEmpty) throw ShopLinesUnavailable(gone.toList());
      throw ShopFailure(errors.isEmpty ? 'No checkout came back' : '${errors.first['message']}');
    }
    // Shopify makes the cart even when something is sold out or short; it
    // keeps that line at the quantity it has (maybe 0) and says so in
    // warnings. Compare what came back with what was sent.
    // Without the lines there's nothing to compare, so take it all as sent.
    final accepted = cart['lines'] is Map<String, dynamic> ? <String, int>{} : {...sent};
    for (final n in cart['lines'] is Map<String, dynamic> ? (cart['lines']['nodes'] as List?) ?? const [] : const []) {
      if (n case {'quantity': final num q, 'merchandise': {'id': final String id}}) {
        accepted[id] = (accepted[id] ?? 0) + q.toInt();
      }
    }
    final short = [for (final e in sent.entries) if ((accepted[e.key] ?? 0) < e.value) e.key];
    if (short.isNotEmpty) throw ShopLinesUnavailable(short, accepted: accepted);
    return (cartId: cart['id'] as String, url: Uri.parse(cart['checkoutUrl'] as String), accepted: accepted);
  }

  @override
  Future<bool> cartOpen(String cartId) async => (await _run(_cart, {'id': cartId}))['cart'] != null;

  @override
  Future<Map<String, ({bool available, double price})>> variants(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final data = await _run(_variants, {'ids': ids});
    return {
      for (final n in (data['nodes'] as List?) ?? const [])
        if (n case {'id': final String id}) id: (available: n['availableForSale'] == true, price: _amount(n['price'])),
    };
  }
}

// ---------------------------------------------------------------------------
// The shop as the screens see it: the catalog and the cart
// ---------------------------------------------------------------------------

enum ShopStatus {
  loading,

  /// Products are in hand.
  ready,

  /// The Shopify store isn't open to the public yet.
  comingSoon,

  /// It didn't load; trying again might.
  failed,
}

/// One shirt in one size in the cart, with enough kept to show it without
/// asking Shopify again.
class CartLine {
  CartLine({
    required this.variantId,
    required this.handle,
    required this.title,
    required this.price,
    this.detail = '',
    this.currency = 'USD',
    this.image,
    this.qty = 1,
    this.available = true,
  });

  final String variantId;
  final String handle;
  final String title;

  /// "Size YM".
  final String detail;

  /// What it cost when last checked with Shopify.
  double price;
  final String currency;
  final String? image;
  int qty;

  /// False once Shopify stops selling this shirt in this size. It stays in
  /// the cart, marked, and is left out of checkout.
  bool available;

  double get total => price * qty;

  Map<String, dynamic> toJson() => {
        'variantId': variantId,
        'handle': handle,
        'title': title,
        'detail': detail,
        'price': price,
        'currency': currency,
        'image': image,
        'qty': qty,
        if (!available) 'available': false,
      };

  static CartLine fromJson(Map<String, dynamic> j) => CartLine(
        variantId: j['variantId'] as String,
        handle: j['handle'] as String,
        title: j['title'] as String,
        detail: (j['detail'] as String?) ?? '',
        price: (j['price'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'USD',
        image: j['image'] as String?,
        qty: (j['qty'] as num).toInt(),
        available: (j['available'] as bool?) ?? true,
      );
}

class Shop extends ChangeNotifier {
  /// [read] and [write] keep the cart between visits; leave them out for a
  /// cart that lasts as long as the app is open.
  Shop(this._backend, {String? Function()? read, this._write}) {
    _restore(read);
  }

  /// The real store, or the sample shirts when the app shows sample data
  /// (which never touches a real cart).
  static Shop get instance => _instance ??= Repo.isDemo
      ? Shop(SampleShop())
      : Shop(Storefront(), read: store.read, write: store.write);
  static Shop? _instance;

  @visibleForTesting
  static set instance(Shop? shop) => _instance = shop;

  final ShopBackend _backend;
  final void Function(String)? _write;

  /// The most of one shirt in one size a cart takes.
  static const maxQty = 99;

  // --- The catalog ---

  ShopStatus status = ShopStatus.loading;
  List<ShopProduct> products = const [];
  List<ShopCollection> collections = const [];

  /// Selling right now: loaded, with something to sell.
  bool get open => status == ShopStatus.ready && products.isNotEmpty;

  /// Not selling yet: the Shopify store is still behind its password page,
  /// or open with nothing listed.
  bool get comingSoon =>
      status == ShopStatus.comingSoon || (status == ShopStatus.ready && products.isEmpty);

  final _details = <String, ShopProduct>{};
  DateTime? _loadedAt;
  Future<void>? _loading;

  /// Reads the catalog. Asking again within five minutes of a good answer
  /// does nothing unless [force] is set.
  Future<void> load({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5);
    if (fresh && !force) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    if (status == ShopStatus.failed) {
      status = ShopStatus.loading;
      // load() is called from initState; tell the other listeners after the
      // build in progress.
      scheduleMicrotask(notifyListeners);
    }
    try {
      final c = await _backend.catalog();
      products = c.products;
      collections = c.collections;
      _details.clear();
      _loadedAt = DateTime.now();
      status = ShopStatus.ready;
      // A checkout finished on Shopify's page last visit empties the cart.
      unawaited(settle());
    } on ShopLocked {
      status = ShopStatus.comingSoon;
    } catch (_) {
      // A refresh that fails keeps showing what's already here.
      if (status != ShopStatus.ready) status = ShopStatus.failed;
    }
    notifyListeners();
  }

  /// The catalog as sections: each Battle Baseball collection that has
  /// products, by title, then anything in no collection, then the
  /// participating teams' collections ([ShopCollection.isTeam]), by title.
  /// Shopify's built-in "Home page" collection is left out.
  List<ShopSection> get sections {
    final byHandle = {for (final p in products) p.handle: p};
    final placed = <String>{};
    final ours = <ShopSection>[], teams = <ShopSection>[];
    for (final c in collections) {
      if (c.handle == 'frontpage') continue;
      final list = [for (final h in c.productHandles) ?byHandle[h]];
      if (list.isEmpty) continue;
      placed.addAll(list.map((p) => p.handle));
      (c.isTeam ? teams : ours).add((title: c.title, description: c.description, products: list, team: c.isTeam));
    }
    final rest = [for (final p in products) if (!placed.contains(p.handle)) p];
    if (rest.isNotEmpty) {
      final alone = ours.isEmpty && teams.isEmpty;
      ours.add((title: alone ? '' : 'More', description: '', products: rest, team: false));
    }
    return [...ours, ...teams];
  }

  /// One product in full. Null when there's no such product; throws
  /// [ShopException] when it couldn't be read.
  Future<ShopProduct?> product(String handle) async {
    final have = _details[handle];
    if (have != null) return have;
    final p = await _backend.product(handle);
    if (p != null) _details[handle] = p;
    return p;
  }

  // --- The cart ---

  final _lines = <CartLine>[];
  List<CartLine> get lines => List.unmodifiable(_lines);
  int get count => _lines.fold(0, (n, l) => n + l.qty);

  /// The lines that can be bought: everything but what's sold out.
  List<CartLine> get buyable => [for (final l in _lines) if (l.available) l];
  double get subtotal => buyable.fold(0, (n, l) => n + l.total);
  String get currency => _lines.isEmpty ? 'USD' : _lines.first.currency;

  /// The Shopify cart the last checkout was started with, how many of each
  /// variant went into it, and when.
  ({String id, Map<String, int> qty, DateTime at})? _pending;
  bool get checkoutPending => _pending != null;

  /// When the last checkout was started, while it's still unsettled.
  DateTime? get checkoutStartedAt => _pending?.at;

  /// Shopify deletes a cart when its checkout is completed, and lets an
  /// abandoned one go 30 days after its last change. So a cart gone sooner
  /// than this was turned into an order; gone later, it may only have
  /// expired, and its shirts stay in this cart.
  static const cartLifetime = Duration(days: 28);

  void add(ShopProduct p, ShopVariant v, [int qty = 1]) {
    final i = _lines.indexWhere((l) => l.variantId == v.id);
    if (i >= 0) {
      _lines[i]
        ..qty = (_lines[i].qty + qty).clamp(1, maxQty)
        ..price = v.price
        ..available = true;
    } else {
      _lines.add(CartLine(
        variantId: v.id,
        handle: p.handle,
        title: p.title,
        detail: p.describe(v),
        price: v.price,
        currency: p.currency,
        image: (v.image ?? p.image)?.url,
        qty: qty.clamp(1, maxQty),
      ));
    }
    _changed();
  }

  void setQty(String variantId, int qty) {
    final i = _lines.indexWhere((l) => l.variantId == variantId);
    if (i < 0) return;
    if (qty <= 0) {
      _lines.removeAt(i);
    } else {
      _lines[i].qty = qty.clamp(1, maxQty);
    }
    _changed();
  }

  void remove(String variantId) => setQty(variantId, 0);

  /// Hands what can be bought to Shopify and returns the page to pay on.
  /// Lines Shopify turns down are marked sold out, and the
  /// [ShopLinesUnavailable] is passed on so the screen can say so.
  Future<Uri> checkout() async {
    final buying = buyable;
    if (buying.isEmpty) throw const ShopFailure('Nothing in the cart can be bought');
    final ({String cartId, Uri url, Map<String, int> accepted}) made;
    try {
      made = await _backend.startCheckout(buying);
    } on ShopLinesUnavailable catch (e) {
      // Down to what Shopify has; sold out if it has none.
      for (final l in _lines) {
        if (!e.variantIds.contains(l.variantId)) continue;
        final left = e.accepted[l.variantId] ?? 0;
        if (left > 0) {
          l.qty = left;
        } else {
          l.available = false;
        }
      }
      _changed();
      rethrow;
    }
    _pending = (id: made.cartId, qty: made.accepted, at: DateTime.now());
    _save();
    return made.url;
  }

  bool _refreshing = false;

  /// Checks each cart line with Shopify: brings its price up to date, and
  /// marks it sold out if Shopify no longer sells it (or for sale again if
  /// it's back).
  Future<void> refreshCart() async {
    if (_lines.isEmpty || _refreshing) return;
    _refreshing = true;
    try {
      final now = await _backend.variants([for (final l in _lines) l.variantId]);
      var changed = false;
      for (final l in _lines) {
        final v = now[l.variantId];
        final available = v != null && v.available;
        if (l.available != available) {
          l.available = available;
          changed = true;
        }
        if (v != null && v.price != l.price) {
          l.price = v.price;
          changed = true;
        }
      }
      if (changed) _changed();
    } catch (_) {
      // Offline, or the store didn't answer: the cart shows what it last knew.
    } finally {
      _refreshing = false;
    }
  }

  bool _settling = false;

  /// After a checkout was started: if Shopify's cart is gone, the order went
  /// through, so what was sent to it comes out of this cart. Anything added
  /// since stays.
  Future<void> settle() async {
    final pending = _pending;
    if (pending == null || _settling) return;
    _settling = true;
    try {
      if (await _backend.cartOpen(pending.id)) return;
      if (_pending?.id != pending.id) return;
      _pending = null;
      if (DateTime.now().difference(pending.at) > cartLifetime) {
        // Expired, not bought: keep the shirts.
        _changed();
        return;
      }
      for (final e in pending.qty.entries) {
        final i = _lines.indexWhere((l) => l.variantId == e.key);
        if (i < 0) continue;
        _lines[i].qty -= e.value;
        if (_lines[i].qty <= 0) _lines.removeAt(i);
      }
      _changed();
    } catch (_) {
      // Offline or the store didn't answer: ask again next time.
    } finally {
      _settling = false;
    }
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  void _save() {
    try {
      _write?.call(jsonEncode({
        'lines': [for (final l in _lines) l.toJson()],
        if (_pending case final p?)
          'pending': {'id': p.id, 'qty': p.qty, 'at': p.at.toUtc().toIso8601String()},
      }));
    } catch (_) {}
  }

  void _restore(String? Function()? read) {
    try {
      final raw = read?.call();
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _lines.addAll([
        for (final l in (j['lines'] as List?) ?? const []) CartLine.fromJson(l as Map<String, dynamic>),
      ]);
      if (j['pending'] case {'id': final String id, 'qty': final Map<String, dynamic> qty}) {
        _pending = (
          id: id,
          qty: {for (final e in qty.entries) e.key: (e.value as num).toInt()},
          at: DateTime.tryParse('${j['pending']['at']}')?.toLocal() ?? DateTime.now(),
        );
      }
    } catch (_) {
      // A cart saved by some other version of the app: start empty.
      _lines.clear();
      _pending = null;
    }
  }
}
