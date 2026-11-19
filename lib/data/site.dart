// One build of the app is served as two sites. Battle Baseball
// (showcase.getbattleplan.app) is the whole app. Battle Shop
// (shop.getbattleplan.app) is the Merch shop and nothing else, with no way
// into the rest. Battle Shop's index.html says which it is with
// <meta name="bb-site" content="shop">, written by tools/build_hosting.mjs.
import 'package:battle_baseball/data/site_mark.dart'
    if (dart.library.js_interop) 'package:battle_baseball/data/site_mark_web.dart' as mark;

abstract final class Site {
  /// Whether this is Battle Shop's own site. Never true in the phone apps.
  /// `--dart-define=SITE=shop` says so too, for `flutter run`.
  static final bool isShop = const String.fromEnvironment('SITE') == 'shop' || mark.read() == 'shop';
}
