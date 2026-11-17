// The shop's data: Shopify products and their choices, prices, the Storefront client, and the Shop.
import 'dart:convert';

import 'package:battle_baseball/data/shop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Products as the Storefront API sends them (the live store, November 2026)
// ---------------------------------------------------------------------------

const _adult = 'Sport-Tek ST350 Sport-Tek ® PosiCharge ® Competitor™ Tee. ST350';
const _youth = 'Sport-Tek YST350 Sport-Tek ® Youth PosiCharge ® Competitor™ Tee. YST350';
const _cdn = 'https://cdn.shopify.com/s/files/1/0915/2286/3878/files';
const _tropic = 'battle-baseball-tee-tropic-blue';
const _royal = 'battle-baseball-tee-true-royal';
const _coral = 'battle-baseball-tank-tee-coral';

/// The standard tees' Size option, in the order Shopify lists it.
const _shopifySizes = ['S', 'M', 'L', 'XL', '2XL', '3XL', '4XL', 'YXS', 'YS', 'YM', 'YL', 'YXL', 'XS'];

/// The standard tees' variants: adult XS-4XL, then youth YXS-YXL.
const _adultSizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'];
const _youthSizes = ['YXS', 'YS', 'YM', 'YL', 'YXL'];

/// The coral tee's Size option and variants, S listed last as Shopify has it.
const _coralSizes = ['M', 'L', 'XL', '2XL', '3XL', '4XL', 'S'];

Map<String, Object?> _money(num amount) => {'amount': amount.toStringAsFixed(1), 'currencyCode': 'USD'};

Map<String, Object?> _photo(String file, int width, int height) =>
    {'url': '$_cdn/$file?v=1762297361', 'width': width, 'height': height};

num _priced(String size, num base) => switch (size) {
      '2XL' => base + 2,
      '3XL' => base + 3,
      '4XL' => base + 4,
      _ => base,
    };

/// A Tropic Blue tee variant's id: 01-08 for adult XS-4XL, 09-13 for youth.
String _id(String size) {
  final n = [..._adultSizes, ..._youthSizes].indexOf(size) + 1;
  return 'gid://shopify/ProductVariant/680358143590${'$n'.padLeft(2, '0')}';
}

String _coralId(String size) {
  final n = _coralSizes.indexOf(size) + 1;
  return 'gid://shopify/ProductVariant/680412377012${'$n'.padLeft(2, '0')}';
}

/// The Tropic Blue tee as the Product query returns it.
Map<String, Object?> _tropicJson({
  Set<String> soldOut = const {},
  Set<String> dropped = const {},
  Map<String, num> prices = const {},
}) {
  final mockup = _photo('tropic-blue-mockup.png', 2000, 1812);
  return {
    'handle': _tropic,
    'title': 'Battle Baseball Tee - Tropic Blue',
    'availableForSale': true,
    'descriptionHtml': '<p>The Battle Baseball tank logo on a Tropic Blue Sport-Tek PosiCharge Competitor tee.</p>',
    'options': [
      {
        'name': 'Color',
        'optionValues': [
          {'name': 'Tropic Blue'},
        ],
      },
      {
        'name': 'Size',
        'optionValues': [for (final s in _shopifySizes) {'name': s}],
      },
      {
        'name': 'Product',
        'optionValues': [
          {'name': _youth},
          {'name': _adult},
        ],
      },
    ],
    'featuredImage': mockup,
    'images': {
      'nodes': [mockup, _photo('tropic-blue-front.jpg', 3200, 3200), _photo('tropic-blue-back.jpg', 3200, 3200)],
    },
    'priceRange': {'minVariantPrice': _money(25), 'maxVariantPrice': _money(29)},
    'variants': {
      'nodes': [
        for (final size in [..._adultSizes, ..._youthSizes])
          if (!dropped.contains(size))
            {
              'id': _id(size),
              'availableForSale': !soldOut.contains(size),
              'price': _money(prices[size] ?? _priced(size, 25)),
              'compareAtPrice': null,
              'selectedOptions': [
                {'name': 'Color', 'value': 'Tropic Blue'},
                {'name': 'Size', 'value': size},
                {'name': 'Product', 'value': size.startsWith('Y') ? _youth : _adult},
              ],
              'image': mockup,
            },
      ],
    },
  };
}

/// The coral Special Edition tee as the Product query returns it.
Map<String, Object?> _coralJson({bool available = true, Map<String, num> compareAt = const {}}) {
  final mockup = _photo('coral-mockup.png', 2000, 1812);
  return {
    'handle': _coral,
    'title': 'Battle Baseball Special Edition Tee - Coral (Adult)',
    'availableForSale': available,
    'descriptionHtml': '<p>Special Edition.</p><hr><p><strong>A4 N3142</strong></p>',
    'options': [
      {
        'name': 'Color',
        'optionValues': [
          {'name': 'Coral'},
        ],
      },
      {
        'name': 'Size',
        'optionValues': [for (final s in _coralSizes) {'name': s}],
      },
    ],
    'featuredImage': mockup,
    'images': {
      'nodes': [mockup, _photo('coral-front.jpg', 3200, 3200)],
    },
    'priceRange': {'minVariantPrice': _money(26), 'maxVariantPrice': _money(30)},
    'variants': {
      'nodes': [
        for (final size in _coralSizes)
          {
            'id': _coralId(size),
            'availableForSale': available,
            'price': _money(_priced(size, 26)),
            'compareAtPrice': compareAt[size] == null ? null : _money(compareAt[size]!),
            'selectedOptions': [
              {'name': 'Color', 'value': 'Coral'},
              {'name': 'Size', 'value': size},
            ],
            'image': null,
          },
      ],
    },
  };
}

/// A product with no options, as Shopify sends one: "Title: Default Title".
Map<String, Object?> _stickerJson() => {
      'handle': 'battle-baseball-sticker',
      'title': 'Battle Baseball Sticker',
      'availableForSale': true,
      'descriptionHtml': '',
      'options': [
        {
          'name': 'Title',
          'optionValues': [
            {'name': 'Default Title'},
          ],
        },
      ],
      'featuredImage': null,
      'images': {'nodes': <Object?>[]},
      'priceRange': {'minVariantPrice': _money(5), 'maxVariantPrice': _money(5)},
      'variants': {
        'nodes': [
          {
            'id': 'gid://shopify/ProductVariant/68050000000101',
            'availableForSale': true,
            'price': _money(5),
            'compareAtPrice': null,
            'selectedOptions': [
              {'name': 'Title', 'value': 'Default Title'},
            ],
            'image': null,
          },
        ],
      },
    };

/// A product as the Catalog query lists it: no description, options or variants.
Map<String, Object?> _listing(Map<String, Object?> full) => {
      for (final key in ['handle', 'title', 'availableForSale', 'featuredImage', 'priceRange']) key: full[key],
    };

/// Through JSON and back, so the types are the ones a real response has.
ShopProduct _parse(Map<String, Object?> json) =>
    ShopProduct.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

ShopVariant _size(ShopProduct p, String size) => p.variants.firstWhere((v) => v.options['Size'] == size);

/// A Color x Size grid, where neither option follows from the other.
ShopProduct _hoodie({Set<String> soldOut = const {}}) => ShopProduct(
      handle: 'battle-baseball-hoodie',
      title: 'Battle Baseball Hoodie',
      minPrice: 45,
      maxPrice: 45,
      options: const [
        ShopOption('Color', ['Black', 'Royal']),
        ShopOption('Size', ['L', 'S', 'M']),
      ],
      variants: [
        for (final color in ['Black', 'Royal'])
          for (final size in ['S', 'M', 'L'])
            ShopVariant(
              id: 'gid://shopify/ProductVariant/hoodie-$color-$size',
              price: 45,
              available: !soldOut.contains('$color $size'),
              options: {'Color': color, 'Size': size},
            ),
      ],
    );

// ---------------------------------------------------------------------------
// A cart as it's saved
// ---------------------------------------------------------------------------

/// A saved Tropic Blue tee cart line.
Map<String, Object?> _line(String size, {int qty = 1, bool available = true, num? price}) => {
      'variantId': _id(size),
      'handle': _tropic,
      'title': 'Battle Baseball Tee - Tropic Blue',
      'detail': 'Size $size',
      'price': price ?? _priced(size, 25),
      'currency': 'USD',
      'image': '$_cdn/tropic-blue-mockup.png?v=1762297361',
      'qty': qty,
      if (!available) 'available': false,
    };

String _cart(List<Map<String, Object?>> lines, {Map<String, Object?>? pending}) =>
    jsonEncode({'lines': lines, 'pending': ?pending});

Map<String, dynamic> _decoded(String? saved) => jsonDecode(saved!) as Map<String, dynamic>;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// What the Storefront API answers while the store's password page is on.
http.Response _locked() => _json({
      'errors': [
        {
          'message': 'Online Store channel is locked.',
          'extensions': {'code': 'BAD_REQUEST'},
        },
      ],
    }, 400);

/// A Storefront talking to a Shopify that answers every request with
/// [answer], keeping each request in [sent].
Storefront _storefront(List<http.Request> sent, http.Response Function() answer, {String token = ''}) =>
    Storefront(
      token: token,
      client: MockClient((req) async {
        sent.add(req);
        return answer();
      }),
    );

Map<String, dynamic> _body(http.Request req) => jsonDecode(req.body) as Map<String, dynamic>;

CartLine _cartLine(String size, int qty) => CartLine.fromJson(jsonDecode(jsonEncode(_line(size, qty: qty))));

/// A Shopify that answers from memory and remembers what it was asked.
class _Shopify implements ShopBackend {
  var collections = <ShopCollection>[];
  var products = <ShopProduct>[];
  final details = <String, ShopProduct?>{};
  Object? catalogError, productError, checkoutError, cartError, variantsError;
  var cartIsOpen = true;

  /// What a checkout takes from each line; everything that was sent if null.
  Map<String, int>? accept;
  var made = (
    cartId: 'gid://shopify/Cart/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d',
    url: Uri.parse('https://t03zrq-mv.myshopify.com/cart/c/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d'),
  );

  var catalogCalls = 0;
  final productCalls = <String>[];
  final checkouts = <Map<String, int>>[];
  final cartChecks = <String>[];
  final variantCalls = <List<String>>[];

  @override
  Future<({List<ShopCollection> collections, List<ShopProduct> products})> catalog() async {
    catalogCalls++;
    if (catalogError case final e?) throw e;
    return (collections: collections, products: products);
  }

  @override
  Future<ShopProduct?> product(String handle) async {
    productCalls.add(handle);
    if (productError case final e?) throw e;
    return details[handle];
  }

  @override
  Future<({String cartId, Uri url, Map<String, int> accepted})> startCheckout(List<CartLine> lines) async {
    final sent = {for (final l in lines) l.variantId: l.qty};
    checkouts.add(sent);
    if (checkoutError case final e?) throw e;
    return (cartId: made.cartId, url: made.url, accepted: accept ?? sent);
  }

  /// Answers from [details]: a variant of a shirt there, or nothing.
  @override
  Future<Map<String, ({bool available, double price})>> variants(List<String> ids) async {
    variantCalls.add(ids);
    if (variantsError case final e?) throw e;
    return {
      for (final p in details.values.nonNulls)
        for (final v in p.variants)
          if (ids.contains(v.id)) v.id: (available: v.available, price: v.price),
    };
  }

  @override
  Future<bool> cartOpen(String cartId) async {
    cartChecks.add(cartId);
    if (cartError case final e?) throw e;
    return cartIsOpen;
  }
}

ShopProduct _listed(String handle) => ShopProduct(handle: handle, title: handle, minPrice: 25, maxPrice: 29);

void main() {
  group('ShopProduct.fromJson', () {
    test('reads a standard tee as the Product query returns it', () {
      final p = _parse(_tropicJson());
      expect(p.handle, _tropic);
      expect(p.title, 'Battle Baseball Tee - Tropic Blue');
      expect(p.available, isTrue);
      expect(p.currency, 'USD');
      expect(p.minPrice, 25);
      expect(p.maxPrice, 29);
      expect(p.priceLabel, r'From $25');
      expect(p.descriptionHtml, startsWith('<p>The Battle Baseball tank logo'));
      expect(p.images.map((i) => (i.width, i.height)), [(2000, 1812), (3200, 3200), (3200, 3200)]);
      expect(p.image!.url, '$_cdn/tropic-blue-mockup.png?v=1762297361');
      expect(p.options.map((o) => o.name), ['Color', 'Size', 'Product']);
      expect(p.options[0].values, ['Tropic Blue']);
      expect(p.options[1].values, _shopifySizes);
      expect(p.options[2].values, [_youth, _adult]);

      expect(p.variants, hasLength(13));
      final xs = p.variants.first;
      expect(xs.id, 'gid://shopify/ProductVariant/68035814359001');
      expect(xs.options, {'Color': 'Tropic Blue', 'Size': 'XS', 'Product': _adult});
      expect(xs.available, isTrue);
      expect(xs.compareAt, isNull);
      expect(xs.image!.width, 2000);
      expect(p.variants.last.id, 'gid://shopify/ProductVariant/68035814359013');
      expect(p.variants.last.options, {'Color': 'Tropic Blue', 'Size': 'YXL', 'Product': _youth});
      expect({for (final v in p.variants) v.options['Size']: v.price}, {
        'XS': 25, 'S': 25, 'M': 25, 'L': 25, 'XL': 25, '2XL': 27, '3XL': 28, '4XL': 29, //
        'YXS': 25, 'YS': 25, 'YM': 25, 'YL': 25, 'YXL': 25,
      });
    });

    test('reads the coral tee: seven sizes, no variant photos', () {
      final p = _parse(_coralJson());
      expect(p.options.map((o) => o.name), ['Color', 'Size']);
      expect(p.options[1].values, _coralSizes);
      expect(p.variants.map((v) => v.options['Size']), _coralSizes);
      expect(p.variants.map((v) => v.image), everyElement(isNull));
      expect(p.images, hasLength(2));
      expect(p.minPrice, 26);
      expect(p.maxPrice, 30);
      expect(p.priceLabel, r'From $26');
    });

    test('reads sale prices and what is not for sale', () {
      final p = _parse(_coralJson(available: false, compareAt: {'M': 32}));
      expect(p.available, isFalse);
      expect(p.variants.every((v) => !v.available), isTrue);
      expect(_size(p, 'M').compareAt, 32);
      expect(_size(p, 'L').compareAt, isNull);
    });

    test('a product from the catalog has its featured photo and nothing to pick yet', () {
      final p = _parse(_listing(_tropicJson()));
      expect(p.images.single.url, '$_cdn/tropic-blue-mockup.png?v=1762297361');
      expect(p.descriptionHtml, '');
      expect(p.options, isEmpty);
      expect(p.variants, isEmpty);
      expect(p.choices, isEmpty);
      expect(p.priceLabel, r'From $25');
    });

    test('a photo needs a url', () {
      expect(ShopImage.fromJson(null), isNull);
      expect(ShopImage.fromJson('$_cdn/tee.png'), isNull);
      expect(ShopImage.fromJson({'width': 2000}), isNull);
      final photo = ShopImage.fromJson({'url': '$_cdn/tee.png', 'width': 2000, 'height': 1812})!;
      expect((photo.url, photo.width, photo.height), ('$_cdn/tee.png', 2000, 1812));
    });
  });

  group('choices', () {
    test('a standard tee is one Size choice, Adult XS-4XL then Youth YXS-YXL', () {
      final choices = _parse(_tropicJson()).choices;
      expect(choices, hasLength(1));
      final size = choices.single;
      expect(size.name, 'Size');
      expect([for (final g in size.groups) g.label], ['Adult', 'Youth']);
      expect(size.groups[0].values, ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL']);
      expect(size.groups[1].values, ['YXS', 'YS', 'YM', 'YL', 'YXL']);
      expect(size.values, hasLength(13));
    });

    test('the coral tee is one Size choice from S to 4XL', () {
      final size = _parse(_coralJson()).choices.single;
      expect(size.name, 'Size');
      expect(size.groups.single.label, isNull);
      expect(size.values, ['S', 'M', 'L', 'XL', '2XL', '3XL', '4XL']);
    });

    test('a product with no options has nothing to pick and its one variant to buy', () {
      final p = _parse(_stickerJson());
      expect(p.choices, isEmpty);
      expect(p.variantFor({})?.id, 'gid://shopify/ProductVariant/68050000000101');
      expect(p.describe(p.variants.single), '');
      expect(p.priceLabel, r'$5');
      expect(p.image, isNull);
    });

    test('a color and size grid is two choices, each picked on its own', () {
      final p = _hoodie();
      expect(p.choices.map((c) => c.name), ['Color', 'Size']);
      expect(p.choices[0].values, ['Black', 'Royal']);
      expect(p.choices[1].values, ['S', 'M', 'L']);
      expect([for (final c in p.choices) c.groups.single.label], [null, null]);
    });

    test('offers() leaves out sizes that are sold out', () {
      final tee = _parse(_tropicJson(soldOut: {'YM', '4XL'}));
      expect([for (final s in tee.choices.single.values) if (!tee.offers('Size', s, {})) s], ['4XL', 'YM']);
      expect(tee.offers('Size', 'YS', {'Size': 'YL'}), isTrue, reason: 'a size already picked hides no other size');

      final hoodie = _hoodie(soldOut: {'Black M'});
      expect(hoodie.offers('Size', 'M', {}), isTrue);
      expect(hoodie.offers('Size', 'M', {'Color': 'Black'}), isFalse);
      expect(hoodie.offers('Size', 'M', {'Color': 'Royal'}), isTrue);
      expect(hoodie.offers('Color', 'Black', {'Size': 'M'}), isTrue,
          reason: 'a later pick never hides an earlier choice, so there is always a way out');
      expect(hoodie.offers('Color', 'Black', {'Size': 'L'}), isTrue);
    });

    test('with two choices, one picked leaves every other value of it on offer', () {
      // Royal S, Royal M and Black L are sold out: after Black and S, Royal L
      // can still be reached by picking Royal.
      final hoodie = _hoodie(soldOut: {'Royal S', 'Royal M', 'Black L'});
      final picked = {'Color': 'Black', 'Size': 'S'};
      expect(hoodie.offers('Color', 'Royal', picked), isTrue);
      expect(hoodie.offers('Size', 'L', picked), isFalse, reason: 'Black L is sold out');
      expect(hoodie.offers('Size', 'L', {'Color': 'Royal'}), isTrue);
      expect(hoodie.offers('Size', 'S', {'Color': 'Royal'}), isFalse);
    });

    test("a Youth and Adult option that sizes don't decide is a choice labelled Youth and Adult", () {
      const p = ShopProduct(
        handle: 'battle-baseball-tee-heather',
        title: 'Battle Baseball Tee - Heather',
        minPrice: 25,
        maxPrice: 25,
        options: [
          ShopOption('Size', ['S', 'M']),
          ShopOption('Product', [_youth, _adult]),
        ],
        variants: [
          ShopVariant(id: 'y-s', price: 25, options: {'Size': 'S', 'Product': _youth}),
          ShopVariant(id: 'y-m', price: 25, options: {'Size': 'M', 'Product': _youth}),
          ShopVariant(id: 'a-s', price: 25, options: {'Size': 'S', 'Product': _adult}),
          ShopVariant(id: 'a-m', price: 25, options: {'Size': 'M', 'Product': _adult}),
        ],
      );
      final product = p.choices.last;
      expect(product.name, 'Product');
      expect([for (final v in product.values) product.label(v)], ['Youth', 'Adult']);
      expect(p.describe(p.variants.first), 'Size S · Product Youth');
    });

    test('group headings say Youth and Adult only for a youth and adult pair', () {
      const p = ShopProduct(
        handle: 'battle-baseball-tee-fits',
        title: 'Battle Baseball Tee - Fits',
        minPrice: 25,
        maxPrice: 25,
        options: [
          ShopOption('Size', ['YS', 'YM', 'WS', 'S']),
          ShopOption('Fit', ['Youth tee', 'Women\'s tee', 'Unisex tee']),
        ],
        variants: [
          ShopVariant(id: 'ys', price: 25, options: {'Size': 'YS', 'Fit': 'Youth tee'}),
          ShopVariant(id: 'ym', price: 25, options: {'Size': 'YM', 'Fit': 'Youth tee'}),
          ShopVariant(id: 'ws', price: 25, options: {'Size': 'WS', 'Fit': 'Women\'s tee'}),
          ShopVariant(id: 's', price: 25, options: {'Size': 'S', 'Fit': 'Unisex tee'}),
        ],
      );
      expect([for (final g in p.choices.single.groups) g.label], ['Youth tee', "Women's tee", 'Unisex tee'],
          reason: "three fits aren't Youth and Adult, so each keeps its own name");
    });

    test("an adult and a kids' hoodie in two colors: pick a color, then a size under Adult or Youth", () {
      const adult = 'Gildan G185 Gildan Heavy Blend Hoodie. G185';
      const kids = "Gildan G185B Gildan Heavy Blend Kids' Hoodie. G185B";
      final p = ShopProduct(
        handle: 'cyclones-hoodie',
        title: 'Cyclones Hoodie',
        minPrice: 30,
        maxPrice: 32,
        options: const [
          ShopOption('Color', ['White', 'Graphite Heather']),
          ShopOption('Size', ['S', 'XL', '4XL', 'YS', 'YL']),
          ShopOption('Product', [adult, kids]),
        ],
        variants: [
          for (final color in ['White', 'Graphite Heather'])
            for (final size in ['S', 'XL', '4XL', 'YS', 'YL'])
              ShopVariant(
                id: '$color/$size',
                price: size == '4XL' ? 32 : 30,
                options: {'Color': color, 'Size': size, 'Product': size.startsWith('Y') ? kids : adult},
              ),
        ],
      );
      expect([for (final c in p.choices) c.name], ['Color', 'Size']);
      final size = p.choices.last;
      expect([for (final g in size.groups) g.label], ['Adult', 'Youth']);
      expect([for (final g in size.groups) g.values], [
        ['S', 'XL', '4XL'],
        ['YS', 'YL'],
      ]);
      expect(p.describe(p.variants.first), 'Color White · Size S');
    });

    test('variantFor waits until every choice is picked', () {
      final tee = _parse(_tropicJson());
      expect(tee.variantFor({}), isNull);
      expect(tee.variantFor({'Size': 'YM'})!.id, 'gid://shopify/ProductVariant/68035814359011');
      expect(tee.variantFor({'Size': 'YM'})!.options['Product'], _youth);
      expect(tee.variantFor({'Size': 'XS'})!.options['Product'], _adult);
      expect(tee.variantFor({'Size': '5XL'}), isNull);

      final hoodie = _hoodie();
      expect(hoodie.variantFor({'Color': 'Royal'}), isNull);
      expect(hoodie.variantFor({'Size': 'M'}), isNull);
      expect(hoodie.variantFor({'Color': 'Royal', 'Size': 'M'})!.id, 'gid://shopify/ProductVariant/hoodie-Royal-M');
    });

    test('describe() says the size for a cart line', () {
      final tee = _parse(_tropicJson());
      expect(tee.describe(_size(tee, 'YM')), 'Size YM');
      final hoodie = _hoodie();
      expect(hoodie.describe(hoodie.variantFor({'Color': 'Royal', 'Size': 'M'})!), 'Color Royal · Size M');
    });
  });

  group('prices and photos', () {
    test('shopPrice writes whole dollars, cents and refunds', () {
      expect(shopPrice(25), r'$25');
      expect(shopPrice(25.5), r'$25.50');
      expect(shopPrice(0), r'$0');
      expect(shopPrice(-5), r'-$5');
      expect(shopPrice(-2.5), r'-$2.50');
      expect(shopPrice(30, 'CAD'), '30 CAD');
    });

    test('priceLabel says From only when sizes cost different amounts', () {
      expect(const ShopProduct(handle: 'a', title: 'A', minPrice: 25, maxPrice: 29).priceLabel, r'From $25');
      expect(const ShopProduct(handle: 'a', title: 'A', minPrice: 25, maxPrice: 25).priceLabel, r'$25');
      expect(const ShopProduct(handle: 'a', title: 'A', minPrice: 25.5, maxPrice: 25.5).priceLabel, r'$25.50');
    });

    test('a Shopify photo asks for a width and keeps its version', () {
      const photo = ShopImage('$_cdn/tropic-blue-mockup.png?v=1762297361');
      final sized = Uri.parse(photo.sized(640));
      expect('${sized.origin}${sized.path}', '$_cdn/tropic-blue-mockup.png');
      expect(sized.queryParameters, {'v': '1762297361', 'width': '640'});
      expect(Uri.parse(ShopImage(photo.sized(640)).sized(1200)).queryParametersAll['width'], ['1200']);
      expect(const ShopImage('https://cdn.shopify.com/s/files/tee.jpg').sized(240),
          'https://cdn.shopify.com/s/files/tee.jpg?width=240');
    });

    test('a bundled photo is used as it is', () {
      const photo = ShopImage('assets/merch/sample-coral.jpg');
      expect(photo.isAsset, isTrue);
      expect(photo.sized(640), 'assets/merch/sample-coral.jpg');
      expect(const ShopImage('$_cdn/tee.png').isAsset, isFalse);
    });
  });

  group('Storefront', () {
    test('requests are JSON posted to the store with no token header', () async {
      final sent = <http.Request>[];
      final api = Storefront(
        client: MockClient((req) async {
          sent.add(req);
          return _json({
            'data': {'product': null},
          });
        }),
      );
      await api.product(_tropic);
      final req = sent.single;
      expect(req.method, 'POST');
      expect(req.url, Uri.parse('https://t03zrq-mv.myshopify.com/api/2026-10/graphql.json'));
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(req.headers['accept'], 'application/json');
      expect(req.headers.keys.map((k) => k.toLowerCase()), isNot(contains('x-shopify-storefront-access-token')));
      final body = _body(req);
      expect(body.keys, unorderedEquals(['query', 'variables']));
      expect(body['query'], contains(r'product(handle: $handle)'));
      expect(body['variables'], {'handle': _tropic});
    });

    test('a token from the Headless channel goes in its header', () async {
      final sent = <http.Request>[];
      final api = _storefront(
          sent,
          () => _json({
                'data': {'product': null},
              }),
          token: 'public-storefront-token');
      await api.product(_tropic);
      expect(sent.single.headers['X-Shopify-Storefront-Access-Token'], 'public-storefront-token');
    });

    test('the catalog comes back as collections and products', () async {
      final sent = <http.Request>[];
      Map<String, Object?> collection(String handle, String title, List<String> products, [String about = '']) => {
            'handle': handle,
            'title': title,
            'description': about,
            'products': {
              'nodes': [
                for (final p in products) {'handle': p},
              ],
            },
          };
      final royal = {..._listing(_tropicJson()), 'handle': _royal, 'title': 'Battle Baseball Tee - True Royal'};
      final api = _storefront(
        sent,
        () => _json({
          'data': {
            'collections': {
              'nodes': [
                collection('battle-baseball', 'Battle Baseball', [_tropic, _royal]),
                collection('frontpage', 'Home page', [_coral, _tropic, _royal]),
                collection('special-edition', 'Special Edition', [_coral], 'Limited-run shirts.'),
              ],
            },
            'products': {
              'nodes': [_listing(_coralJson()), _listing(_tropicJson()), royal],
            },
          },
        }),
      );

      final c = await api.catalog();
      expect(c.collections.map((x) => x.handle), ['battle-baseball', 'frontpage', 'special-edition']);
      expect(c.collections.map((x) => x.title), ['Battle Baseball', 'Home page', 'Special Edition']);
      expect(c.collections[0].productHandles, [_tropic, _royal]);
      expect(c.collections[2].description, 'Limited-run shirts.');
      expect(c.products.map((p) => p.handle), [_coral, _tropic, _royal]);
      expect(c.products.map((p) => p.priceLabel), [r'From $26', r'From $25', r'From $25']);
      expect(c.products.first.images.single.url, '$_cdn/coral-mockup.png?v=1762297361');
      expect(c.products.first.variants, isEmpty);

      final body = _body(sent.single);
      expect(body['query'], allOf(contains('collections(first: 25'), contains('products(first: 60)')));
      expect(body.containsKey('variables'), isFalse);

      // The shop the screens see: Home page left out, the rest in Shopify's order.
      final shop = Shop(api);
      await shop.load();
      expect(shop.sections.map((s) => s.title), ['Battle Baseball', 'Special Edition']);
    });

    test('a product comes back whole, and a missing one is null', () async {
      final sent = <http.Request>[];
      Map<String, Object?>? product = _tropicJson();
      final api = _storefront(
          sent,
          () => _json({
                'data': {'product': product},
              }));
      final p = (await api.product(_tropic))!;
      expect(p.variants, hasLength(13));
      expect(p.choices.single.groups.map((g) => g.label), ['Adult', 'Youth']);
      product = null;
      expect(await api.product('battle-baseball-hoodie'), isNull);
      expect(_body(sent.last)['variables'], {'handle': 'battle-baseball-hoodie'});
    });

    test("the store's password page is ShopLocked", () async {
      final api = _storefront([], _locked);
      await expectLater(api.catalog(), throwsA(isA<ShopLocked>()));
      await expectLater(api.product(_tropic), throwsA(isA<ShopLocked>()));
      await expectLater(api.startCheckout([_cartLine('YM', 1)]), throwsA(isA<ShopLocked>()));
      await expectLater(api.cartOpen('gid://shopify/Cart/abc?key=k'), throwsA(isA<ShopLocked>()));
    });

    test('a server error, a page that is not JSON, a GraphQL error or no network is a ShopFailure', () async {
      Future<void> fails(http.Response Function() answer, Matcher message) => expectLater(
            _storefront([], answer).catalog(),
            throwsA(isA<ShopFailure>().having((e) => e.message, 'message', message)),
          );
      await fails(() => http.Response('Internal Server Error', 500), equals('HTTP 500'));
      await fails(() => http.Response('<!doctype html><title>Shop</title>', 200, headers: {'content-type': 'text/html'}),
          equals('HTTP 200'));
      await fails(
        () => _json({
          'errors': [
            {
              'message': 'Throttled',
              'extensions': {'code': 'THROTTLED'},
            },
          ],
        }),
        equals('Throttled'),
      );
      await fails(() => throw http.ClientException('Failed host lookup'), contains('Failed host lookup'));
    });

    test('a checkout comes back as a cart id and the page to pay on', () async {
      final sent = <http.Request>[];
      const id = 'gid://shopify/Cart/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d';
      const page = 'https://t03zrq-mv.myshopify.com/cart/c/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d';
      final api = _storefront(
        sent,
        () => _json({
          'data': {
            'cartCreate': {
              'cart': {'id': id, 'checkoutUrl': page},
              'userErrors': <Object?>[],
            },
          },
        }),
      );
      final made = await api.startCheckout([_cartLine('YM', 2), _cartLine('2XL', 1)]);
      expect(made.cartId, id);
      expect(made.url, Uri.parse(page));
      final body = _body(sent.single);
      expect(body['query'], contains('cartCreate'));
      expect(body['variables'], {
        'lines': [
          {'merchandiseId': _id('YM'), 'quantity': 2},
          {'merchandiseId': _id('2XL'), 'quantity': 1},
        ],
      });
    });

    test("a user error on one line names that line's variant", () async {
      final api = _storefront(
        [],
        () => _json({
          'data': {
            'cartCreate': {
              'cart': null,
              'userErrors': [
                {
                  'field': ['input', 'lines', '1', 'merchandiseId'],
                  'message': 'The merchandise with id ${_id('2XL')} does not exist.',
                  'code': 'INVALID',
                },
              ],
            },
          },
        }),
      );
      await expectLater(
        api.startCheckout([_cartLine('YM', 2), _cartLine('2XL', 1)]),
        throwsA(isA<ShopLinesUnavailable>().having((e) => e.variantIds, 'variantIds', [_id('2XL')])),
      );
    });

    test('any other user error, or no cart at all, is a ShopFailure', () async {
      Future<void> fails(List<Map<String, Object?>> errors, String message) => expectLater(
            _storefront(
              [],
              () => _json({
                'data': {
                  'cartCreate': {'cart': null, 'userErrors': errors},
                },
              }),
            ).startCheckout([_cartLine('YM', 1)]),
            throwsA(isA<ShopFailure>().having((e) => e.message, 'message', message)),
          );
      await fails([
        {
          'field': ['input', 'buyerIdentity', 'countryCode'],
          'message': 'Country is not supported.',
        },
      ], 'Country is not supported.');
      await fails([
        {'field': null, 'message': 'Something went wrong.'},
      ], 'Something went wrong.');
      await fails([
        {
          'field': ['input', 'lines', '7', 'merchandiseId'],
          'message': 'The merchandise does not exist.',
        },
      ], 'The merchandise does not exist.');
      await fails([], 'No checkout came back');
    });

    test("cartOpen is true while Shopify has the cart and false once it's gone", () async {
      final sent = <http.Request>[];
      const id = 'gid://shopify/Cart/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d';
      Map<String, Object?>? cart = {'id': id};
      final api = _storefront(
          sent,
          () => _json({
                'data': {'cart': cart},
              }));
      expect(await api.cartOpen(id), isTrue);
      cart = null;
      expect(await api.cartOpen(id), isFalse);
      expect(_body(sent.first)['variables'], {'id': id});
    });

    test("an answer with errors is a ShopFailure, so a cart Shopify couldn't look up isn't taken as bought", () async {
      final api = _storefront(
        [],
        () => _json({
          'data': {'cart': null},
          'errors': [
            {
              'message': 'Internal error. Looks like something went wrong on our end.',
              'path': ['cart'],
            },
          ],
        }),
      );
      await expectLater(api.cartOpen('gid://shopify/Cart/abc?key=k'), throwsA(isA<ShopFailure>()));
    });

    test('a paused store (402) is ShopLocked too', () async {
      final api = _storefront([], () => http.Response('Unavailable Shop', 402));
      await expectLater(api.catalog(), throwsA(isA<ShopLocked>()));
    });

    test('a line Shopify put in the cart short is ShopLinesUnavailable, with what it did take', () async {
      const id = 'gid://shopify/Cart/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d';
      final api = _storefront(
        [],
        () => _json({
          'data': {
            'cartCreate': {
              'cart': {
                'id': id,
                'checkoutUrl': 'https://t03zrq-mv.myshopify.com/cart/c/hWN6ZJ1kvvzQN0ElBqdkbZ0Y?key=8b0b2f0a5d',
                'lines': {
                  'nodes': [
                    {
                      'quantity': 1,
                      'merchandise': {'id': _id('YM')},
                    },
                    {
                      'quantity': 0,
                      'merchandise': {'id': _id('2XL')},
                    },
                  ],
                },
              },
              'userErrors': <Object?>[],
              'warnings': [
                {'code': 'MERCHANDISE_NOT_ENOUGH_STOCK', 'target': 'gid://shopify/CartLine/1', 'message': 'Only 1 left.'},
                {'code': 'MERCHANDISE_OUT_OF_STOCK', 'target': 'gid://shopify/CartLine/2', 'message': 'Sold out.'},
              ],
            },
          },
        }),
      );
      await expectLater(
        api.startCheckout([_cartLine('YM', 2), _cartLine('2XL', 1)]),
        throwsA(isA<ShopLinesUnavailable>()
            .having((e) => e.variantIds, 'variantIds', [_id('YM'), _id('2XL')])
            .having((e) => e.accepted, 'accepted', {_id('YM'): 1, _id('2XL'): 0})),
      );
    });

    test('a checkout that took every line says so', () async {
      final api = _storefront(
        [],
        () => _json({
          'data': {
            'cartCreate': {
              'cart': {
                'id': 'gid://shopify/Cart/c1?key=k',
                'checkoutUrl': 'https://t03zrq-mv.myshopify.com/cart/c/c1?key=k',
                'lines': {
                  'nodes': [
                    {
                      'quantity': 2,
                      'merchandise': {'id': _id('YM')},
                    },
                  ],
                },
              },
              'userErrors': <Object?>[],
              'warnings': <Object?>[],
            },
          },
        }),
      );
      final made = await api.startCheckout([_cartLine('YM', 2)]);
      expect(made.accepted, {_id('YM'): 2});
    });

    test('variants() asks for every id at once and reads what is for sale and its price', () async {
      final sent = <http.Request>[];
      final api = _storefront(
        sent,
        () => _json({
          'data': {
            'nodes': [
              {'id': _id('YM'), 'availableForSale': true, 'price': _money(26)},
              {'id': _id('YS'), 'availableForSale': false, 'price': _money(25)},
              null,
            ],
          },
        }),
      );
      final now = await api.variants([_id('YM'), _id('YS'), _id('4XL')]);
      expect(_body(sent.single)['variables'], {
        'ids': [_id('YM'), _id('YS'), _id('4XL')],
      });
      expect(now, {
        _id('YM'): (available: true, price: 26.0),
        _id('YS'): (available: false, price: 25.0),
      });
      expect(await api.variants([]), isEmpty);
      expect(sent, hasLength(1), reason: 'nothing to ask, so nothing asked');
    });
  });

  group('Shop catalog', () {
    test('load makes the shop ready with what Shopify sells', () async {
      final b = _Shopify()..products = [_listed(_tropic), _listed(_coral)];
      var told = 0;
      final shop = Shop(b)..addListener(() => told++);
      expect(shop.status, ShopStatus.loading);
      expect(shop.open, isFalse);
      await shop.load();
      expect(shop.status, ShopStatus.ready);
      expect(shop.open, isTrue);
      expect(shop.comingSoon, isFalse);
      expect(shop.products.map((p) => p.handle), [_tropic, _coral]);
      expect(told, greaterThan(0));
    });

    test('a locked store is coming soon, and so is an open one with nothing listed', () async {
      final locked = Shop(_Shopify()..catalogError = const ShopLocked());
      await locked.load();
      expect(locked.status, ShopStatus.comingSoon);
      expect(locked.comingSoon, isTrue);
      expect(locked.open, isFalse);

      final empty = Shop(_Shopify());
      await empty.load();
      expect(empty.status, ShopStatus.ready);
      expect(empty.comingSoon, isTrue);
      expect(empty.open, isFalse);
    });

    test('any other error is failed, and loading again can recover', () async {
      final b = _Shopify()
        ..catalogError = const ShopFailure('offline')
        ..products = [_listed(_tropic)];
      final shop = Shop(b);
      await shop.load();
      expect(shop.status, ShopStatus.failed);
      expect(shop.open, isFalse);
      expect(shop.comingSoon, isFalse);

      b.catalogError = null;
      await shop.load();
      expect(b.catalogCalls, 2);
      expect(shop.status, ShopStatus.ready);
    });

    test('a refresh that fails keeps what was already loaded', () async {
      final b = _Shopify()..products = [_listed(_tropic), _listed(_coral)];
      final shop = Shop(b);
      await shop.load();
      b.catalogError = const ShopFailure('offline');
      await shop.load(force: true);
      expect(b.catalogCalls, 2);
      expect(shop.status, ShopStatus.ready);
      expect(shop.products, hasLength(2));
    });

    test("a second load within five minutes doesn't ask Shopify again; force does", () async {
      final b = _Shopify()..products = [_listed(_tropic)];
      final shop = Shop(b);
      await shop.load();
      await shop.load();
      expect(b.catalogCalls, 1);
      await shop.load(force: true);
      expect(b.catalogCalls, 2);
    });

    test('loads asked for at the same time share one request', () async {
      final b = _Shopify()..products = [_listed(_tropic)];
      final shop = Shop(b);
      await Future.wait([shop.load(), shop.load(), shop.load(force: true)]);
      expect(b.catalogCalls, 1);
      expect(shop.status, ShopStatus.ready);
    });

    test("sections leave out Home page, keep Shopify's order and put the rest under More", () async {
      final b = _Shopify()
        ..products = [_listed(_coral), _listed(_tropic), _listed(_royal), _listed('battle-baseball-hoodie')]
        ..collections = const [
          ShopCollection(handle: 'battle-baseball', title: 'Battle Baseball', productHandles: [_tropic, _royal]),
          ShopCollection(
            handle: 'frontpage',
            title: 'Home page',
            productHandles: [_coral, _tropic, _royal, 'battle-baseball-hoodie'],
          ),
          ShopCollection(
            handle: 'special-edition',
            title: 'Special Edition',
            description: 'Limited-run shirts.',
            productHandles: [_coral],
          ),
          ShopCollection(handle: 'team-store', title: 'Team Store', productHandles: ['not-listed-yet']),
        ];
      final shop = Shop(b);
      await shop.load();
      final sections = shop.sections;
      expect(sections.map((s) => s.title), ['Battle Baseball', 'Special Edition', 'More']);
      expect(sections.map((s) => [for (final p in s.products) p.handle]), [
        [_tropic, _royal],
        [_coral],
        ['battle-baseball-hoodie'],
      ]);
      expect(sections[1].description, 'Limited-run shirts.');
      expect(sections[2].description, '');
    });

    test("participating teams' collections come last, after More, and are marked as teams", () async {
      final b = _Shopify()
        ..products = [_listed(_coral), _listed(_tropic), _listed('cyclones-hoodie'), _listed('loose-cap')]
        ..collections = const [
          ShopCollection(handle: 'battle-baseball', title: 'Battle Baseball', productHandles: [_tropic]),
          ShopCollection(handle: 'team-cyclones', title: 'Cyclones', productHandles: ['cyclones-hoodie']),
          ShopCollection(handle: 'special-edition', title: 'Special Edition', productHandles: [_coral]),
        ];
      final shop = Shop(b);
      await shop.load();
      final sections = shop.sections;
      expect(sections.map((s) => s.title), ['Battle Baseball', 'Special Edition', 'More', 'Cyclones']);
      expect(sections.map((s) => s.team), [false, false, false, true]);
      expect(sections.last.products.single.handle, 'cyclones-hoodie');
    });

    test('a team collection alone keeps its title', () async {
      final shop = Shop(_Shopify()
        ..products = [_listed('cyclones-hoodie')]
        ..collections = const [
          ShopCollection(handle: 'team-cyclones', title: 'Cyclones', productHandles: ['cyclones-hoodie']),
        ]);
      await shop.load();
      expect(shop.sections.single.title, 'Cyclones');
      expect(shop.sections.single.team, isTrue);
    });

    test('with no collections but Home page everything is one untitled section', () async {
      for (final collections in [
        <ShopCollection>[],
        const [ShopCollection(handle: 'frontpage', title: 'Home page', productHandles: [_coral])],
      ]) {
        final shop = Shop(_Shopify()
          ..products = [_listed(_coral), _listed(_tropic)]
          ..collections = collections);
        await shop.load();
        expect(shop.sections.single.title, '');
        expect(shop.sections.single.products.map((p) => p.handle), [_coral, _tropic]);
      }
    });

    test("product() asks Shopify once per shirt, and again for one that wasn't there", () async {
      final tee = _parse(_tropicJson());
      final b = _Shopify()..details[_tropic] = tee;
      final shop = Shop(b);
      expect(await shop.product(_tropic), same(tee));
      expect(await shop.product(_tropic), same(tee));
      expect(await shop.product('battle-baseball-hoodie'), isNull);
      expect(await shop.product('battle-baseball-hoodie'), isNull);
      expect(b.productCalls, [_tropic, 'battle-baseball-hoodie', 'battle-baseball-hoodie']);

      b.productError = const ShopFailure('offline');
      await expectLater(shop.product(_coral), throwsA(isA<ShopFailure>()));
    });

    test('a fresh catalog forgets the shirts read before it', () async {
      final b = _Shopify()
        ..products = [_listed(_tropic)]
        ..details[_tropic] = _parse(_tropicJson());
      final shop = Shop(b);
      await shop.product(_tropic);
      await shop.load();
      await shop.product(_tropic);
      expect(b.productCalls, [_tropic, _tropic]);
    });
  });

  group('Shop cart', () {
    test('add puts in a line with what the cart shows', () {
      final shop = Shop(_Shopify());
      final tee = _parse(_tropicJson());
      shop.add(tee, _size(tee, 'YM'));
      final line = shop.lines.single;
      expect(line.variantId, _id('YM'));
      expect(line.handle, _tropic);
      expect(line.title, 'Battle Baseball Tee - Tropic Blue');
      expect(line.detail, 'Size YM');
      expect(line.price, 25);
      expect(line.currency, 'USD');
      expect(line.image, '$_cdn/tropic-blue-mockup.png?v=1762297361');
      expect(line.qty, 1);
      expect(line.available, isTrue);
      expect(shop.count, 1);
      expect(shop.subtotal, 25);
      expect(shop.currency, 'USD');
    });

    test('adding a size already in the cart adds to its line, up to maxQty', () {
      final shop = Shop(_Shopify());
      final tee = _parse(_tropicJson());
      shop
        ..add(tee, _size(tee, 'YM'), 2)
        ..add(tee, _size(tee, 'YM'), 3);
      expect(shop.lines.single.qty, 5);
      shop.add(tee, _size(tee, 'YM'), 120);
      expect(shop.lines.single.qty, Shop.maxQty);
      shop.add(tee, _size(tee, '2XL'), 500);
      expect([for (final l in shop.lines) (l.detail, l.qty)], [('Size YM', 99), ('Size 2XL', 99)]);
      shop.add(tee, _size(tee, 'S'), 0);
      expect(shop.lines.last.qty, 1, reason: 'a line holds at least one');
    });

    test('setQty changes a line within limits, and 0 or remove takes it out', () {
      final shop = Shop(_Shopify());
      final tee = _parse(_tropicJson());
      shop
        ..add(tee, _size(tee, 'YM'))
        ..add(tee, _size(tee, 'L'));
      shop.setQty(_id('YM'), 4);
      expect(shop.lines.first.qty, 4);
      shop.setQty(_id('YM'), 250);
      expect(shop.lines.first.qty, Shop.maxQty);
      shop.setQty(_id('YM'), 0);
      expect(shop.lines.map((l) => l.detail), ['Size L']);
      shop.setQty('gid://shopify/ProductVariant/1', 3);
      expect(shop.lines.map((l) => l.detail), ['Size L']);
      shop.remove(_id('L'));
      expect(shop.lines, isEmpty);
      expect(shop.count, 0);
      expect(shop.subtotal, 0);
    });

    test('count adds up every line; subtotal and buyable leave out sold-out lines', () {
      final shop = Shop(_Shopify(),
          read: () => _cart([_line('YM', qty: 2), _line('2XL', available: false), _line('4XL', qty: 3)]));
      expect(shop.count, 6);
      expect(shop.buyable.map((l) => l.detail), ['Size YM', 'Size 4XL']);
      expect(shop.subtotal, 2 * 25 + 3 * 29);
    });

    test('every change to the cart is saved and told to listeners', () {
      String? saved;
      var told = 0;
      final shop = Shop(_Shopify(), read: () => saved, write: (v) => saved = v)..addListener(() => told++);
      final tee = _parse(_tropicJson());
      shop.add(tee, _size(tee, 'YM'));
      expect(told, 1);
      expect(_decoded(saved)['lines'], [
        {
          'variantId': _id('YM'),
          'handle': _tropic,
          'title': 'Battle Baseball Tee - Tropic Blue',
          'detail': 'Size YM',
          'price': 25,
          'currency': 'USD',
          'image': '$_cdn/tropic-blue-mockup.png?v=1762297361',
          'qty': 1,
        },
      ]);
      shop.setQty(_id('YM'), 4);
      expect(told, 2);
      expect((_decoded(saved)['lines'] as List).single['qty'], 4);
      shop.remove(_id('YM'));
      expect(told, 3);
      expect(_decoded(saved), {'lines': <Object?>[]});
    });

    test('the cart and a pending checkout are there after a reload', () async {
      String? saved;
      final b = _Shopify();
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      final tee = _parse(_tropicJson()), coral = _parse(_coralJson());
      shop
        ..add(tee, _size(tee, 'YM'), 2)
        ..add(coral, _size(coral, 'M'));
      await shop.checkout();

      final reloaded = Shop(b, read: () => saved, write: (v) => saved = v);
      expect([for (final l in reloaded.lines) l.toJson()], [for (final l in shop.lines) l.toJson()]);
      expect(reloaded.checkoutPending, isTrue);
      expect(reloaded.checkoutStartedAt!.isAtSameMomentAs(shop.checkoutStartedAt!), isTrue);

      // The reloaded cart still knows what went to Shopify.
      b.cartIsOpen = false;
      await reloaded.settle();
      expect(b.cartChecks, [b.made.cartId]);
      expect(reloaded.lines, isEmpty);
      expect(reloaded.checkoutPending, isFalse);
    });

    test("a saved cart this version can't read starts empty", () {
      for (final raw in [
        'not json',
        '[]',
        '{"lines": "nope"}',
        '{"lines": [{"variantId": "x"}]}',
        _cart([_line('YM'), {'variantId': _id('S')}]),
        _cart([_line('YM')], pending: {
          'id': 'gid://shopify/Cart/c?key=k',
          'qty': {_id('YM'): 'two'},
        }),
      ]) {
        final shop = Shop(_Shopify(), read: () => raw);
        expect(shop.lines, isEmpty, reason: raw);
        expect(shop.checkoutPending, isFalse, reason: raw);
      }
      final noPending = Shop(_Shopify(), read: () => _cart([_line('YM')], pending: {'id': 5}));
      expect(noPending.lines, hasLength(1));
      expect(noPending.checkoutPending, isFalse);
    });

    test("storage that throws doesn't break the cart", () {
      final shop = Shop(
        _Shopify(),
        read: () => throw StateError('storage is off'),
        write: (_) => throw StateError('storage is full'),
      );
      final tee = _parse(_tropicJson());
      shop.add(tee, _size(tee, 'YM'));
      expect(shop.count, 1);
    });
  });

  group('Shop checkout', () {
    test('checkout sends only what can be bought and remembers the Shopify cart', () async {
      var saved = _cart([_line('YM', qty: 2), _line('S', available: false), _line('2XL')]);
      final b = _Shopify();
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      expect(shop.checkoutPending, isFalse);

      final url = await shop.checkout();
      expect(url, b.made.url);
      expect(b.checkouts, [
        {_id('YM'): 2, _id('2XL'): 1},
      ]);
      expect(shop.checkoutPending, isTrue);
      expect(DateTime.now().difference(shop.checkoutStartedAt!), lessThan(const Duration(minutes: 1)));
      expect(shop.lines, hasLength(3), reason: 'nothing leaves the cart until the order goes through');

      final pending = _decoded(saved)['pending'] as Map<String, dynamic>;
      expect(pending['id'], b.made.cartId);
      expect(pending['qty'], {_id('YM'): 2, _id('2XL'): 1});
      expect(DateTime.parse(pending['at'] as String).isUtc, isTrue);
    });

    test('checkout with nothing to buy fails without asking Shopify', () async {
      final b = _Shopify();
      await expectLater(Shop(b).checkout(), throwsA(isA<ShopFailure>()));
      final soldOut = Shop(b, read: () => _cart([_line('YM', available: false)]));
      await expectLater(soldOut.checkout(), throwsA(isA<ShopFailure>()));
      expect(b.checkouts, isEmpty);
      expect(soldOut.checkoutPending, isFalse);
    });

    test('lines Shopify turns down are marked sold out and the error is passed on', () async {
      var saved = _cart([_line('YM', qty: 2), _line('2XL')]);
      final b = _Shopify()..checkoutError = ShopLinesUnavailable([_id('2XL')]);
      var told = 0;
      final shop = Shop(b, read: () => saved, write: (v) => saved = v)..addListener(() => told++);
      await expectLater(
        shop.checkout(),
        throwsA(isA<ShopLinesUnavailable>().having((e) => e.variantIds, 'variantIds', [_id('2XL')])),
      );
      expect([for (final l in shop.lines) l.available], [true, false]);
      expect(shop.buyable.single.variantId, _id('YM'));
      expect(shop.subtotal, 50);
      expect(shop.checkoutPending, isFalse);
      expect(told, 1);
      expect((_decoded(saved)['lines'] as List).last['available'], isFalse);
    });

    test('a line Shopify has fewer of comes down to what it has, and stays for sale', () async {
      var saved = _cart([_line('YM', qty: 3), _line('2XL')]);
      final b = _Shopify()..checkoutError = ShopLinesUnavailable([_id('YM')], accepted: {_id('YM'): 1, _id('2XL'): 1});
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      await expectLater(shop.checkout(), throwsA(isA<ShopLinesUnavailable>()));
      expect([for (final l in shop.lines) (l.qty, l.available)], [(1, true), (1, true)]);
      expect(shop.checkoutPending, isFalse);
      expect((_decoded(saved)['lines'] as List).first['qty'], 1);
    });

    test('the pending checkout is what Shopify took, not what was asked for', () async {
      var saved = _cart([_line('YM', qty: 2), _line('2XL')]);
      final b = _Shopify()..accept = {_id('YM'): 2};
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      await shop.checkout();
      expect((_decoded(saved)['pending'] as Map<String, dynamic>)['qty'], {_id('YM'): 2});
      b.cartIsOpen = false;
      await shop.settle();
      expect(shop.lines.map((l) => l.detail), ['Size 2XL'], reason: "the 2XL never went to Shopify, so it wasn't bought");
    });

    test('any other checkout error changes nothing', () async {
      final saved = _cart([_line('YM', qty: 2), _line('2XL')]);
      final b = _Shopify()..checkoutError = const ShopFailure('offline');
      final shop = Shop(b, read: () => saved);
      await expectLater(shop.checkout(), throwsA(isA<ShopFailure>()));
      expect(shop.buyable, hasLength(2));
      expect(shop.checkoutPending, isFalse);
    });

    test('settle does nothing when no checkout was started', () async {
      final b = _Shopify()..cartIsOpen = false;
      final shop = Shop(b, read: () => _cart([_line('YM', qty: 2)]));
      await shop.settle();
      expect(b.cartChecks, isEmpty);
      expect(shop.lines.single.qty, 2);
    });

    test('while the Shopify cart is still open, settle changes nothing', () async {
      final b = _Shopify();
      var told = 0;
      final shop = Shop(b, read: () => _cart([_line('YM', qty: 2)]))..addListener(() => told++);
      await shop.checkout();
      await shop.settle();
      expect(b.cartChecks, [b.made.cartId]);
      expect(shop.lines.single.qty, 2);
      expect(shop.checkoutPending, isTrue);
      expect(told, 0);
    });

    test('once the Shopify cart is gone, what was checked out comes out and later additions stay', () async {
      String? saved;
      final b = _Shopify();
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      final tee = _parse(_tropicJson());
      shop
        ..add(tee, _size(tee, 'YM'), 2)
        ..add(tee, _size(tee, 'L'));
      await shop.checkout();
      // While Shopify's checkout page was open, one more YM and a 2XL went in.
      shop
        ..add(tee, _size(tee, 'YM'))
        ..add(tee, _size(tee, '2XL'));

      b.cartIsOpen = false;
      var told = 0;
      shop.addListener(() => told++);
      await shop.settle();
      expect({for (final l in shop.lines) l.detail: l.qty}, {'Size YM': 1, 'Size 2XL': 1});
      expect(shop.checkoutPending, isFalse);
      expect(told, 1);
      expect(_decoded(saved).containsKey('pending'), isFalse);
      expect((_decoded(saved)['lines'] as List).map((l) => l['qty']), [1, 1]);
    });

    test('a Shopify cart gone within cartLifetime was bought, even after a reload', () async {
      final at = DateTime.now().subtract(Shop.cartLifetime - const Duration(days: 1));
      final b = _Shopify()..cartIsOpen = false;
      final shop = Shop(b,
          read: () => _cart([_line('YM', qty: 2), _line('L')], pending: {
                'id': 'gid://shopify/Cart/recent?key=k',
                'qty': {_id('YM'): 2},
                'at': at.toUtc().toIso8601String(),
              }));
      await shop.settle();
      expect(shop.lines.map((l) => l.detail), ['Size L']);
      expect(shop.checkoutPending, isFalse);
    });

    test('a Shopify cart gone after more than cartLifetime only expired, so the shirts stay', () async {
      final at = DateTime.now().subtract(Shop.cartLifetime + const Duration(days: 1));
      var saved = _cart([_line('YM', qty: 2)], pending: {
        'id': 'gid://shopify/Cart/old?key=k',
        'qty': {_id('YM'): 2},
        'at': at.toUtc().toIso8601String(),
      });
      final b = _Shopify()..cartIsOpen = false;
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      expect(shop.checkoutPending, isTrue);
      expect(shop.checkoutStartedAt!.isAtSameMomentAs(at), isTrue);

      await shop.settle();
      expect(b.cartChecks, ['gid://shopify/Cart/old?key=k']);
      expect(shop.lines.single.qty, 2);
      expect(shop.checkoutPending, isFalse);
      expect(_decoded(saved).containsKey('pending'), isFalse);
    });

    test("settle keeps the checkout pending when Shopify can't be reached", () async {
      final b = _Shopify();
      final shop = Shop(b, read: () => _cart([_line('YM', qty: 2)]));
      await shop.checkout();
      b.cartError = const ShopFailure('offline');
      await shop.settle();
      expect(shop.lines.single.qty, 2);
      expect(shop.checkoutPending, isTrue);
      b
        ..cartError = null
        ..cartIsOpen = false;
      await shop.settle();
      expect(shop.lines, isEmpty);
    });

    test('a fresh catalog settles a checkout that went through', () async {
      final b = _Shopify()
        ..products = [_listed(_tropic)]
        ..cartIsOpen = false;
      final shop = Shop(b,
          read: () => _cart([_line('YM', qty: 2)], pending: {
                'id': 'gid://shopify/Cart/recent?key=k',
                'qty': {_id('YM'): 2},
                'at': DateTime.now().toUtc().toIso8601String(),
              }));
      await shop.load();
      await pumpEventQueue();
      expect(b.cartChecks, ['gid://shopify/Cart/recent?key=k']);
      expect(shop.lines, isEmpty);
    });

    test('refreshCart updates prices and marks shirts Shopify stopped selling', () async {
      String? saved;
      final b = _Shopify();
      final shop = Shop(b, read: () => saved, write: (v) => saved = v);
      final tee = _parse(_tropicJson()), coral = _parse(_coralJson());
      shop
        ..add(tee, _size(tee, 'YM'), 2)
        ..add(tee, _size(tee, 'YS'))
        ..add(tee, _size(tee, '4XL'))
        ..add(coral, _size(coral, 'M'));
      var told = 0;
      shop.addListener(() => told++);
      b.details[_tropic] = _parse(_tropicJson(prices: {'YM': 26}, soldOut: {'YS'}, dropped: {'4XL'}));
      b.details[_coral] = null; // taken down

      await shop.refreshCart();
      final byId = {for (final l in shop.lines) l.variantId: l};
      expect(byId[_id('YM')]!.price, 26);
      expect(byId[_id('YM')]!.available, isTrue);
      expect(byId[_id('YS')]!.available, isFalse, reason: 'listed, but not for sale');
      expect(byId[_id('4XL')]!.available, isFalse, reason: 'the size was dropped');
      expect(byId[_coralId('M')]!.available, isFalse, reason: 'the shirt was taken down');
      expect(shop.subtotal, 52);
      expect(told, 1);
      expect(b.variantCalls.single.toSet(), {_id('YM'), _id('YS'), _id('4XL'), _coralId('M')},
          reason: 'one request for every line');
      expect(b.productCalls, isEmpty);
      expect((_decoded(saved)['lines'] as List).first['price'], 26);
    });

    test('a size back in stock is for sale again', () async {
      final b = _Shopify()..details[_tropic] = _parse(_tropicJson());
      final shop = Shop(b, read: () => _cart([_line('YM', qty: 2, available: false)]));
      expect(shop.subtotal, 0);
      await shop.refreshCart();
      expect(shop.lines.single.available, isTrue);
      expect(shop.subtotal, 50);
    });

    test("refreshCart leaves the cart as it was when Shopify can't be reached", () async {
      final b = _Shopify()
        ..details[_tropic] = _parse(_tropicJson(prices: {'YM': 26}, soldOut: {'L'}))
        ..variantsError = const ShopFailure('offline');
      var told = 0;
      final shop = Shop(b, read: () => _cart([_line('YM', qty: 2), _line('L')]))..addListener(() => told++);
      await shop.refreshCart();
      expect([for (final l in shop.lines) (l.price, l.available)], [(25, true), (25, true)]);
      expect(told, 0);
    });
  });
}
