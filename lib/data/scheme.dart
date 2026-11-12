// Which color scheme the app wears. An admin picks one for everyone in Staff
// tools > Color scheme (saved in config/theme); until then it's Royal Blue.
// An admin can also preview a scheme on their own screen before saving it,
// and ?scheme=<id> in the address shows one without saving anything.
import 'dart:async';
import 'dart:convert';

import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/scheme_store.dart'
    if (dart.library.js_interop) 'package:battle_baseball/data/scheme_store_web.dart' as store;
import 'package:battle_baseball/design/bb.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

class SchemeController extends ChangeNotifier {
  SchemeController._();
  static final instance = SchemeController._();

  /// The scheme everyone sees.
  BBScheme saved = BBSchemes.fallback;

  /// A scheme this admin is trying on, seen only on this screen.
  BBScheme? get preview => _preview;
  BBScheme? _preview;

  /// A scheme named in the address with ?scheme=.
  BBScheme? _fromAddress;

  BBScheme get current => _preview ?? _fromAddress ?? saved;

  StreamSubscription<String?>? _sub;

  /// Starts following the saved scheme. Waits briefly for it the first time
  /// on a device, so the first frame isn't painted in the wrong colors.
  Future<void> start() async {
    _fromAddress = BBSchemes.byId(Uri.base.queryParameters['scheme']);
    final remembered = BBSchemes.byId(_rememberedId());
    if (remembered != null) saved = remembered;
    BB.scheme = current;

    final first = Completer<void>();
    _sub?.cancel();
    _sub = Repo.instance.colorScheme().listen(
      (id) {
        saved = BBSchemes.byId(id) ?? BBSchemes.fallback;
        _remember(saved);
        _apply();
        if (!first.isCompleted) first.complete();
      },
      onError: (Object _) {
        if (!first.isCompleted) first.complete();
      },
    );
    if (remembered == null) {
      await first.future.timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    }
  }

  /// Shows [scheme] on this screen only. Pass null to go back to the saved one.
  void tryOn(BBScheme? scheme) {
    _preview = scheme;
    _apply();
  }

  /// Makes [scheme] the one everyone sees.
  Future<void> save(BBScheme scheme) async {
    await Repo.instance.saveColorScheme(scheme.id);
    saved = scheme;
    _preview = null;
    _remember(scheme);
    _apply();
  }

  void _apply() {
    if (identical(BB.scheme, current)) return;
    BB.scheme = current;
    notifyListeners();
    // Every screen reads its colors from BB as it builds, so build and paint
    // everything again, keeping each screen's state and scroll position.
    SchedulerBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    SchedulerBinding.instance.scheduleFrame();
  }

  static void _rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      if (e is RenderObjectElement) e.renderObject.markNeedsPaint();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  // The web loading screen and the plain pages read the colors from here
  // before the app starts (web/index.html, website/_layout.html).
  static String? _rememberedId() {
    try {
      final raw = store.read();
      if (raw == null) return null;
      return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static void _remember(BBScheme s) {
    // Sample data never touches what the real site remembers.
    if (Repo.isDemo) return;
    try {
      store.write(jsonEncode({'id': s.id, ...s.css}));
    } catch (_) {}
  }
}
