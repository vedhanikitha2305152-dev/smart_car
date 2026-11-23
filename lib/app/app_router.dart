import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_shell.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/digital_key/digital_key_screen.dart';
import '../features/discovery/discovery_modal.dart';
import '../features/garage/garage_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/map',
              builder: (_, __) => const MapScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/garage',
        builder: (_, __) => const GarageScreen(),
      ),
      GoRoute(
        path: '/digital-key',
        builder: (_, __) => const DigitalKeyScreen(),
      ),
      GoRoute(
        path: '/discovery',
        builder: (_, __) => const DiscoveryModal(),
      ),
    ],
  );
});
