// The shop's sample data, for ?demo=1: the first three shirts as they were
// listed on Shopify in November 2026, with the same options the print shop
// gives them. Nothing here can be bought.
import 'package:battle_baseball/data/shop.dart';

class SampleShop implements ShopBackend {
  @override
  Future<({List<ShopCollection> collections, List<ShopProduct> products})> catalog() async => (
        collections: const [
          ShopCollection(
            handle: 'battle-baseball',
            title: 'Battle Baseball',
            description: 'The standard Battle Baseball tees, in adult and youth sizes.',
            productHandles: ['battle-baseball-tee-true-royal', 'battle-baseball-tee-tropic-blue'],
          ),
          ShopCollection(
            handle: 'special-edition',
            title: 'Special Edition',
            description:
                "Limited-run Battle Baseball shirts in colors and fabrics you won't find in the standard line.",
            productHandles: ['battle-baseball-tank-tee-coral'],
          ),
        ],
        products: _products,
      );

  @override
  Future<ShopProduct?> product(String handle) async {
    for (final p in _products) {
      if (p.handle == handle) return p;
    }
    return null;
  }

  @override
  Future<({String cartId, Uri url, Map<String, int> accepted})> startCheckout(List<CartLine> lines) =>
      throw const ShopIsSample();

  @override
  Future<bool> cartOpen(String cartId) async => true;

  @override
  Future<Map<String, ({bool available, double price})>> variants(List<String> ids) async => {
        for (final p in _products)
          for (final v in p.variants)
            if (ids.contains(v.id)) v.id: (available: v.available, price: v.price),
      };
}

const _adult = 'Sport-Tek ST350 Sport-Tek ® PosiCharge ® Competitor™ Tee. ST350';
const _youth = 'Sport-Tek YST350 Sport-Tek ® Youth PosiCharge ® Competitor™ Tee. YST350';

double _plusSize(String size, double base) => switch (size) {
      '2XL' => base + 2,
      '3XL' => base + 3,
      '4XL' => base + 4,
      _ => base,
    };

/// A standard-line tee: adult XS-4XL and youth YXS-YXL in one listing.
ShopProduct _standard(String handle, String color, String image) {
  const adult = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'];
  const youth = ['YXS', 'YS', 'YM', 'YL', 'YXL'];
  return ShopProduct(
    handle: handle,
    title: 'Battle Baseball Tee - $color',
    minPrice: 25,
    maxPrice: 29,
    images: [ShopImage(image, width: 900, height: 815)],
    descriptionHtml: '<p>The Battle Baseball tank logo on a $color Sport-Tek PosiCharge Competitor '
        'tee, in adult XS-4XL and youth XS-XL. Light, moisture-wicking, and built for game days. '
        'Printed on demand and ships in 2-4 business days, with free shipping.</p>',
    options: [
      ShopOption('Color', [color]),
      // Out of order on purpose: that's how Shopify hands them over.
      const ShopOption('Size', ['S', 'M', 'L', 'XL', '2XL', '3XL', '4XL', ...youth, 'XS']),
      const ShopOption('Product', [_youth, _adult]),
    ],
    variants: [
      for (final (sizes, product) in [(adult, _adult), (youth, _youth)])
        for (final size in sizes)
          ShopVariant(
            id: 'sample/$handle/$size',
            price: _plusSize(size, 25),
            options: {'Color': color, 'Size': size, 'Product': product},
          ),
    ],
  );
}

final _products = <ShopProduct>[
  ShopProduct(
    handle: 'battle-baseball-tank-tee-coral',
    title: 'Battle Baseball Special Edition Tee - Coral (Adult)',
    minPrice: 26,
    maxPrice: 30,
    images: const [ShopImage('assets/merch/sample-coral.jpg', width: 900, height: 815)],
    descriptionHtml: '<p>Special Edition. The Battle Baseball tank logo on a coral A4 '
        'moisture-wicking performance tee, in adult sizes S-4XL. Light, breathable, and built for '
        'game days. Printed on demand and ships in 5-7 business days, with free shipping.</p><hr>'
        "<p><strong>A4 N3142 Men's Short-Sleeve Cooling Performance Crew</strong></p>"
        '<ul><li>4 oz, 100% polyester</li></ul>'
        '<ul><li>Moisture wicking fabric great for sports and exercise</li></ul>'
        '<ul><li>44+ UPF for UV sun protection</li></ul>'
        '<ul><li>Reinforced shoulder seams</li></ul>'
        '<table><tbody>'
        '<tr><th>Size</th><th>Body length</th><th>Body width</th><th>Sleeve length</th></tr>'
        '<tr><td>S</td><td>27.5"</td><td>20.5"</td><td>18.5"</td></tr>'
        '<tr><td>M</td><td>28.5"</td><td>21.5"</td><td>19.25"</td></tr>'
        '<tr><td>L</td><td>29.5"</td><td>23.0"</td><td>20"</td></tr>'
        '<tr><td>XL</td><td>30.5"</td><td>24.5"</td><td>20.75"</td></tr>'
        '<tr><td>2XL</td><td>31.5"</td><td>26.0"</td><td>21.5"</td></tr>'
        '<tr><td>3XL</td><td>32.5"</td><td>27.5"</td><td>22.25"</td></tr>'
        '<tr><td>4XL</td><td>33.5"</td><td>29.0"</td><td>23"</td></tr>'
        '</tbody></table>',
    options: const [
      ShopOption('Color', ['Coral']),
      ShopOption('Size', ['M', 'L', 'XL', '2XL', '3XL', '4XL', 'S']),
    ],
    variants: [
      for (final size in const ['S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'])
        ShopVariant(
          id: 'sample/coral/$size',
          price: _plusSize(size, 26),
          options: {'Color': 'Coral', 'Size': size},
        ),
    ],
  ),
  _standard('battle-baseball-tee-tropic-blue', 'Tropic Blue', 'assets/merch/sample-tropic-blue.jpg'),
  _standard('battle-baseball-tee-true-royal', 'True Royal', 'assets/merch/sample-true-royal.jpg'),
];
