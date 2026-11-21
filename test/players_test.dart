// Who sees Players: the directory of every player is for Battle Baseball
// admins. A family sees only its own players there, and the bars give
// everyone else Merch where Players was.
import 'dart:convert';

import 'package:battle_baseball/app.dart';
import 'package:battle_baseball/data/demo.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _phone = Size(390, 844);

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

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// The app's frame alone, around an empty screen, in a window [size] big.
Future<void> _shell(WidgetTester t, Size size) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  await t.pumpWidget(const SizedBox()); // a fresh tree, reading the role anew
  await t.pumpWidget(MaterialApp(
    theme: BB.theme(),
    home: const AppShell(location: '/events', child: SizedBox()),
  ));
  await t.pump();
}

/// The whole app at [location], on a phone.
Future<void> _app(WidgetTester t, String location) async {
  t.view
    ..devicePixelRatio = 3
    ..physicalSize = _phone * 3;
  router.go(location);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(const BattleBaseballApp());
  await _settle(t);
}

Finder _back(String label) => find.byWidgetPredicate((w) => w is BackHeader && w.label == label);

void main() {
  setUpAll(() async {
    await _loadAppFonts();
    Session.demoAs = 'family'; // signed in as Jamie, with nothing read from Firebase
  });

  setUp(() => Repo.instance = DemoRepo());

  tearDown(() {
    Session.instance.role = null;
    Repo.instance = Repo();
  });

  testWidgets("on a phone a family's bar has Merch where an admin's has Players", (t) async {
    addTearDown(t.view.reset);
    await _shell(t, _phone);
    expect(t.takeException(), isNull);
    expect(find.text('Players'), findsNothing);
    expect(find.text('Merch'), findsOneWidget);
    expect(find.text('Showcases'), findsOneWidget);
    expect(find.text('Leaders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    for (final role in ['admin', 'owner']) {
      Session.instance.role = role;
      await _shell(t, _phone);
      expect(t.takeException(), isNull, reason: role);
      expect(find.text('Players'), findsOneWidget, reason: role);
      expect(find.text('Merch'), findsNothing, reason: role);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("on desktop only an admin's top bar links to Players", (t) async {
    addTearDown(t.view.reset);
    await _shell(t, const Size(1440, 900));
    expect(t.takeException(), isNull);
    expect(find.text('Players'), findsNothing);
    expect(find.text('Showcases'), findsOneWidget);

    Session.instance.role = 'admin';
    await _shell(t, const Size(1440, 900));
    expect(find.text('Players'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("an admin's top bar, Players and all, still fits from 960 px with larger text", (t) async {
    addTearDown(t.view.reset);
    Session.instance.role = 'owner';
    for (final width in [960.0, 1100.0]) {
      t.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(width, 800);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(MaterialApp(
        theme: BB.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const AppShell(location: '/players', child: SizedBox()),
      ));
      await t.pump();
      expect(t.takeException(), isNull, reason: '$width wide');
      expect(t.getRect(find.text('Jamie')).right, lessThanOrEqualTo(width), reason: '$width wide');
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("a family's /players is only its own players, with no directory", (t) async {
    addTearDown(t.view.reset);
    addTearDown(() => router.go('/'));
    await _app(t, '/players');
    expect(t.takeException(), isNull);
    expect(find.text('Your players'), findsOneWidget);
    expect(find.text('All players'), findsNothing);
    expect(find.text('Search players'), findsNothing);
    expect(find.text('Add player'), findsOneWidget);
    // Someone else's public card isn't listed.
    expect(find.text('Jace M.'), findsNothing);
    // It's a page under Account, not a tab.
    expect(_back('Account'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("an admin's /players is the directory of every public card", (t) async {
    addTearDown(t.view.reset);
    addTearDown(() => router.go('/'));
    Session.instance.role = 'admin';
    await _app(t, '/players');
    expect(t.takeException(), isNull);
    expect(find.text('All players'), findsOneWidget);
    expect(find.text('Search players'), findsOneWidget);
    expect(find.text('Jace M.'), findsOneWidget);
    expect(_back('Account'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("a top performer's card still opens from a link, and leads back to Leaders", (t) async {
    addTearDown(t.view.reset);
    addTearDown(() => router.go('/'));
    await _app(t, '/players/demo-jace');
    expect(t.takeException(), isNull);
    expect(find.text('Nothing here.'), findsNothing);
    expect(_back('Leaders'), findsOneWidget);
    await t.tap(find.byWidgetPredicate((w) => w is Pressable && w.label == 'Back to Leaders'));
    await _settle(t);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/leaders');
    await t.pumpWidget(const SizedBox());
  });
}
