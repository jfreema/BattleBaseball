// On the web the page that loaded the app says which site it is.
import 'package:web/web.dart' as web;

String? read() => web.document.querySelector('meta[name="bb-site"]')?.getAttribute('content');
