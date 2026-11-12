// On the web the scheme's colors are kept in localStorage under bb.scheme.
import 'package:web/web.dart' as web;

const _key = 'bb.scheme';

String? read() => web.window.localStorage.getItem(_key);

void write(String value) => web.window.localStorage.setItem(_key, value);
