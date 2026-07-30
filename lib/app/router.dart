import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../features/clipboard_history/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

GoRouter createRouter({required bool hasCompletedOnboarding}) {
  return GoRouter(
    initialLocation: hasCompletedOnboarding ? '/' : '/onboarding',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) {
          final pageParam = state.uri.queryParameters['page'];
          final initialPage = switch (pageParam) {
            'about' => SettingsPage.about,
            'clipboard' => SettingsPage.clipboard,
            'sharing' => SettingsPage.sharing,
            'privacy' => SettingsPage.privacy,
            'storage' => SettingsPage.storage,
            'shortcuts' => SettingsPage.shortcuts,
            'ai' => SettingsPage.ai,
            _ => null,
          };
          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: true,
            barrierColor: const Color(0x8A000000),
            transitionsBuilder: (context, animation, secondary, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: ScaleTransition(
                  scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: SettingsScreen(initialPage: initialPage),
          );
        },
      ),
    ],
  );
}
