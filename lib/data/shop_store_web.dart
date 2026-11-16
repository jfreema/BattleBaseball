// On the web the cart is kept in localStorage under bb.cart, so it's still
// there after a reload or a trip to Shopify's checkout and back.
import 'package:web/web.dart' as web;

const _key = 'bb.cart';

String? read() => web.window.localStorage.getItem(_key);

void write(String value) => web.window.localStorage.setItem(_key, value);
