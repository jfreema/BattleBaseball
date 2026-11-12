import 'package:battle_baseball/data/session.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/admin.dart';
import 'package:battle_baseball/screens/auth.dart';
import 'package:battle_baseball/screens/events.dart';
import 'package:battle_baseball/screens/home.dart';
import 'package:battle_baseball/screens/leaderboards.dart';
import 'package:battle_baseball/screens/more.dart';
import 'package:battle_baseball/screens/players.dart';
import 'package:battle_baseball/screens/staff.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Screens anyone can open without signing in.
bool _isPublic(String path) =>
    path == '/' ||
    path.startsWith('/events') && !path.endsWith('/reserve') ||
    path.startsWith('/leaderboards') ||
    path.startsWith('/more') ||
    path.startsWith('/sign-in') ||
    path.startsWith('/sign-up');

final router = GoRouter(
  refreshListenable: Session.instance,
  redirect: (context, state) {
    final s = Session.instance;
    final path = state.uri.path;
    if (!s.ready) return null;
    if (!s.signedIn && !_isPublic(path)) {
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
            GoRoute(
              path: ':id',
              builder: (_, s) => PlayerDetailScreen(playerId: s.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, s) => PlayerFormScreen(playerId: s.pathParameters['id']),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/leaderboards', builder: (_, _) => const LeaderboardsScreen()),
        GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
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
        routerConfig: router,
      );
}

class _Tab {
  const _Tab(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('/', 'Home', Icons.home_outlined, Icons.home),
  _Tab('/events', 'Events', Icons.event_outlined, Icons.event),
  _Tab('/players', 'Players', Icons.sports_baseball_outlined, Icons.sports_baseball),
  _Tab('/leaderboards', 'Leaders', Icons.leaderboard_outlined, Icons.leaderboard),
  _Tab('/more', 'More', Icons.menu, Icons.menu),
];

/// Five tabs: a bottom bar on phones, a side rail on tablets and the web.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _index {
    if (location.startsWith('/admin')) return 4;
    for (var i = _tabs.length - 1; i > 0; i--) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    void go(int i) => context.go(_tabs[i].path);
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: const Wordmark(width: 84),
                ),
              ),
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: BB.hairline),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: go,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
