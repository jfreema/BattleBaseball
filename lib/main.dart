import 'package:battle_baseball/app.dart';
import 'package:battle_baseball/data/demo.dart';
import 'package:battle_baseball/data/repo.dart';
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
  final demo = Uri.base.queryParameters['demo'];
  if (demo == '1' || demo == 'family' || demo == 'staff') {
    Repo.instance = DemoRepo();
    if (demo != '1') Session.demoAs = demo;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Session.instance; // starts listening for sign-in
  runApp(const BattleBaseballApp());
}
