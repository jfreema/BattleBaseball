import 'package:battle_baseball/app.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Session.instance; // starts listening for sign-in
  runApp(const BattleBaseballApp());
}
