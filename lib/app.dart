import 'dart:ui' show PointerDeviceKind;

import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/account.dart';
import 'package:battle_baseball/screens/admin.dart';
import 'package:battle_baseball/screens/auth.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:battle_baseball/screens/events.dart';
import 'package:battle_baseball/screens/gallery.dart';
import 'package:battle_baseball/screens/home.dart';
import 'package:battle_baseball/screens/host.dart';
import 'package:battle_baseball/screens/leaderboards.dart';
import 'package:battle_baseball/screens/players.dart';
import 'package:battle_baseball/screens/staff.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Everything is public except the screens that act for a signed-in family
/// or for staff.
bool _needsSignIn(String path) =>
    path.startsWith('/admin') ||
    path == '/welcome' ||
    path == '/players/new' ||
    path.startsWith('/players/') && path.endsWith('/edit') ||
    path.startsWith('/events/') && path.endsWith('/reserve');

final router = GoRouter(
  refreshListenable: Session.instance,
  redirect: (context, state) {
    final s = Session.instance;
    final path = state.uri.path;
    if (!s.ready) return null;
    if (!s.signedIn && _needsSignIn(path)) {
      return Uri(path: '/sign-in', queryParameters: {'from': state.uri.toString()}).toString();
    }
    if (s.signedIn && s.profileChecked && !s.hasProfile) {
      return path == '/welcome' ? null : '/welcome';
    }
    if (path == '/welcome') return s.signedIn ? '/' : '/sign-in';
    if (s.signedIn && (path == '/sign-in' || path == '/sign-up')) {
      return state.uri.queryParameters['from'] ?? '/';
    }
    if (path.startsWith('/admin') && !s.hasStaffTools) return '/';
    return null;
  },
  errorBuilder: (context, state) =>
      AppShell(location: state.uri.path, child: const NotFoundScreen()),
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/events',
          builder: (_, _) => const EventsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, s) => EventDetailScreen(eventId: s.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'reserve',
                  builder: (_, s) => ReserveScreen(
                    eventId: s.pathParameters['id']!,
                    divisionId: s.uri.queryParameters['division'],
                  ),
                ),
                GoRoute(
                  path: 'results',
                  builder: (_, s) => EventResultsScreen(eventId: s.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/players',
          builder: (_, _) => const PlayersScreen(),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const PlayerFormScreen()),
            // The sample profile; PlayerProfileScreen knows the id "sample".
            GoRoute(
              path: 'sample',
              builder: (_, _) => const PlayerProfileScreen(playerId: 'sample'),
            ),
            GoRoute(
              path: ':id',
              builder: (_, s) => PlayerProfileScreen(playerId: s.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, s) => PlayerFormScreen(playerId: s.pathParameters['id']),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/leaders', builder: (_, _) => const LeaderboardsScreen()),
        GoRoute(path: '/leaderboards', redirect: (_, _) => '/leaders'),
        GoRoute(path: '/host', builder: (_, _) => const HostScreen()),
        GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        GoRoute(path: '/more', redirect: (_, _) => '/account'),
        GoRoute(
          path: '/admin',
          builder: (_, _) => const AdminScreen(),
          routes: [
            GoRoute(path: 'events/new', builder: (_, _) => const EventFormScreen()),
            GoRoute(
              path: 'events/:id',
              builder: (_, s) => EventFormScreen(eventId: s.pathParameters['id']),
            ),
            GoRoute(
              path: 'events/:id/staff',
              builder: (_, s) => EventStaffScreen(eventId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'events/:id/run',
              builder: (_, s) => RunEventScreen(eventId: s.pathParameters['id']!),
            ),
            GoRoute(path: 'payments', builder: (_, _) => const PaymentsScreen()),
            GoRoute(path: 'payment-check', builder: (_, _) => const PaymentCheckScreen()),
            GoRoute(path: 'admins', builder: (_, _) => const AdminsScreen()),
            GoRoute(path: 'settings', builder: (_, _) => const PaymentSettingsScreen()),
          ],
        ),
        // Every shared component in its variants, for design review.
        if (Repo.isDemo) GoRoute(path: '/dev/gallery', builder: (_, _) => const GalleryScreen()),
      ],
    ),
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/sign-up', builder: (_, _) => const SignInScreen(signUp: true)),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
  ],
);

class BattleBaseballApp extends StatelessWidget {
  const BattleBaseballApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Battle Baseball',
        debugShowCheckedModeBanner: false,
        theme: BB.theme(),
        // Rows of cards and chips scroll sideways; let a mouse drag them too.
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        routerConfig: router,
      );
}

/// The frame around every screen: a bottom bar with home plate in the
/// middle on phones, a top bar on desktop.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _paths = ['/events', '/players', '/', '/leaders', '/account'];

  /// Which of the five tabs the current screen belongs to, or -1.
  int get _tab {
    bool under(String root) => location == root || location.startsWith('$root/');
    if (location == '/' || under('/host')) return 2;
    if (under('/events')) return 0;
    if (under('/players')) return 1;
    if (under('/leaders')) return 3;
    if (under('/account') || under('/admin')) return 4;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    if (wide) {
      return Scaffold(
        body: Column(
          children: [
            _TopBar(tab: _tab, location: location),
            Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
          ],
        ),
      );
    }
    // On phones each screen's own header carries the sample-data stamp.
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _BottomBar(tab: _tab, onTap: (i) => context.go(_paths[i])),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tab, required this.location});
  final int tab;
  final String location;

  @override
  Widget build(BuildContext context) {
    Widget link(String label, int index, String path) => Pressable(
          onTap: () => context.go(path),
          label: label,
          builder: (context, down, focused) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              // As much above as the underline takes below, so the label
              // sits on the bar's centre line.
              padding: const EdgeInsets.only(top: 8, bottom: 5),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: tab == index
                        ? BB.coral
                        : focused
                            ? BB.cream
                            : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(label, style: BB.labelStyle(18, height: 1)),
            ),
          ),
        );
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 84,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => context.go('/'),
                    label: 'Battle Baseball, home',
                    builder: (context, down, focused) => const Wordmark(height: 46.4),
                  ),
                  Container(
                    width: 1.5,
                    height: 34,
                    margin: const EdgeInsets.only(left: 26, right: 18),
                    color: BB.hairline,
                  ),
                  Text('BATON ROUGE, LA', style: BB.caps(13)),
                  if (Repo.isDemo) ...[const SizedBox(width: 22), const Stamp('SAMPLE DATA')],
                  const Spacer(),
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: Row(
                      children: [
                        link('Showcases', 0, '/events'),
                        const SizedBox(width: 4),
                        link('Players', 1, '/players'),
                        const SizedBox(width: 4),
                        link('Leaders', 3, '/leaders'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  ListenableBuilder(
                    listenable: Session.instance,
                    builder: (context, _) {
                      final s = Session.instance;
                      return BBButton.quiet(
                        s.signedIn ? s.firstName : 'Sign in',
                        small: true,
                        onPressed: () => context.go(
                          s.signedIn
                              ? '/account'
                              : location == '/'
                                  ? '/sign-in'
                                  : Uri(path: '/sign-in', queryParameters: {'from': location}).toString(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far home plate stands above the bar's top edge.
const _plateRise = 20.0;

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab, required this.onTap});
  final int tab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    Widget item(int index, String label, BBGlyph glyph) => Expanded(
          child: _TabItem(
            label: label,
            glyph: glyph,
            selected: tab == index,
            onTap: () => onTap(index),
          ),
        );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: 74 + _plateRise + inset,
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: _plateRise,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BB.fieldDeep,
                  border: Border(top: BorderSide(color: BB.ink, width: 2.5)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _plateRise + 2.5,
              height: 67.5,
              child: Row(
                children: [
                  item(0, 'Showcases', BBGlyph.pennant),
                  item(1, 'Players', BBGlyph.card),
                  const SizedBox(width: 78),
                  item(3, 'Leaders', BBGlyph.bars),
                  item(4, 'Account', BBGlyph.jersey),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 74 + _plateRise,
              child: Center(
                child: SizedBox(
                  width: 78,
                  child: _HomeTab(selected: tab == 2, onTap: () => onTap(2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.glyph, required this.selected, required this.onTap});
  final String label;
  final BBGlyph glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: Pressable(
          onTap: onTap,
          label: label,
          builder: (context, down, focused) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? BB.coral : null,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? BB.ink
                        : focused
                            ? BB.cream
                            : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: selected ? BB.lip(2) : null,
                ),
                child: BBIcon(glyph, size: 22, color: selected ? BB.ink : BB.creamSoft),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: BB.labelStyle(11.5, color: selected ? BB.cream : BB.creamSoft, height: 1)
                    .copyWith(letterSpacing: 0.23),
              ),
            ],
          ),
        ),
      );
}

/// Home is home plate: raised above the bar, coral when you're on Home.
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: Pressable(
          onTap: onTap,
          label: 'Home',
          builder: (context, down, focused) => Column(
            children: [
              const SizedBox(height: 3.5),
              CustomPaint(
                size: const Size(60, 62),
                painter: _PlatePainter(selected: selected, down: down, focused: focused),
              ),
              const SizedBox(height: 2),
              Text(
                'Home',
                style: BB.labelStyle(11.5, color: selected ? BB.cream : BB.creamSoft, height: 1)
                    .copyWith(letterSpacing: 0.23),
              ),
            ],
          ),
        ),
      );
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.selected, required this.down, required this.focused});
  final bool selected;
  final bool down;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    Path plate(double dy) => Path()
      ..moveTo(6, 4 + dy)
      ..lineTo(54, 4 + dy)
      ..lineTo(54, 31 + dy)
      ..lineTo(30, 53 + dy)
      ..lineTo(6, 31 + dy)
      ..close();
    final outline = Paint()
      ..color = BB.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final lip = plate(5);
    canvas.drawPath(lip, Paint()..color = BB.ink);
    canvas.drawPath(lip, outline);
    // Pressed, the face sinks most of the way onto its lip.
    final dy = down ? 3.0 : 0.0;
    final face = plate(dy);
    canvas.drawPath(face, Paint()..color = selected ? BB.coral : BB.cream);
    canvas.drawPath(face, outline);
    if (focused) {
      canvas.drawPath(
        plate(dy),
        Paint()
          ..color = BB.cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final b = TextPainter(
      text: TextSpan(text: 'B', style: BB.lilita(21, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = b.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    b.paint(canvas, Offset(30 - b.width / 2, 29 + dy - ascent));
    b.dispose();
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.selected != selected || old.down != down || old.focused != focused;
}
