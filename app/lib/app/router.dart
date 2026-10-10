import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_screen.dart';
import '../features/ask_earth/ask_earth_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/home_screen.dart';
import '../features/impact/impact_screen.dart';
import '../features/risk_analysis/risk_analysis_screen.dart';
import 'app_shell.dart';

/// Route paths. Use these instead of string literals.
class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String explore = '/explore';
  static const String risk = '/risk';
  static const String impact = '/impact';
  static const String ask = '/ask';
  static const String about = '/about';
}

/// Builds a router. A fresh instance per [ProviderScope] keeps tests isolated.
GoRouter createRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
            StatefulNavigationShell shell) {
          return AppShell(navigationShell: shell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (c, s) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.explore,
              name: 'explore',
              builder: (c, s) => const ExploreScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.risk,
              name: 'risk',
              builder: (c, s) => const RiskAnalysisScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.impact,
              name: 'impact',
              builder: (c, s) => const ImpactScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.ask,
              name: 'ask',
              builder: (c, s) => const AskEarthScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.about,
        name: 'about',
        builder: (c, s) => const AboutScreen(),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
