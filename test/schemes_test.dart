import 'dart:io';

import 'package:battle_baseball/design/bb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => BB.scheme = BBSchemes.fallback);

  test('Royal Blue is the default', () {
    expect(BBSchemes.fallback.id, 'royal');
    expect(BB.field, BBSchemes.royal.field);
  });

  test('every color follows the scheme in use', () {
    BB.scheme = BBSchemes.christmas;
    expect(BB.field, BBSchemes.christmas.field);
    expect(BB.coral, BBSchemes.christmas.accent);
    expect(BB.lemon, BBSchemes.christmas.honors);
    expect(BB.creamSoft.toARGB32() & 0xFFFFFF, BBSchemes.christmas.cream.toARGB32() & 0xFFFFFF);
  });

  test('ids are unique and found by byId', () {
    final ids = BBSchemes.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final s in BBSchemes.all) {
      expect(BBSchemes.byId(s.id), same(s));
    }
    expect(BBSchemes.byId('nope'), isNull);
    expect(BBSchemes.byId(null), isNull);
  });

  test('the Firestore rules accept every scheme', () {
    final rules = File('firestore.rules').readAsStringSync();
    final start = rules.indexOf('match /config/theme');
    final block = rules.substring(start, rules.indexOf('}', start));
    for (final s in BBSchemes.all) {
      expect(block, contains("'${s.id}'"), reason: '${s.id} is missing from config/theme in firestore.rules');
    }
  });
}
