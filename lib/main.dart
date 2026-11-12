import 'package:battle_baseball/app.dart';
import 'package:battle_baseball/data/demo.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/scheme.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // ?demo=1 shows the app filled with sample data, for design review.
  // ?demo=family and ?demo=staff add a pretend sign-in on top of it.
  // The iOS and Android apps have no URL, so screenshot builds pass
  // --dart-define=DEMO=1 (or family, or staff) instead.
  const demoDefine = String.fromEnvironment('DEMO');
  final demo = Uri.base.queryParameters['demo'] ?? (demoDefine.isEmpty ? null : demoDefine);
  if (demo == '1' || demo == 'family' || demo == 'staff') {
    Repo.instance = DemoRepo();
    if (demo != '1') Session.demoAs = demo;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Session.instance; // starts listening for sign-in
  await SchemeController.instance.start(); // the colors an admin picked
  runApp(const BattleBaseballApp());
}
