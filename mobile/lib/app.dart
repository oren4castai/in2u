import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/auth/auth_state.dart';
import 'core/chats/in_app_message_notifier.dart';
import 'core/lifecycle/app_lifecycle_observer.dart';
import 'core/matches/match_celebration_provider.dart';
import 'core/ui/global_messenger.dart';
import 'features/matches/matches_controller.dart';
import 'features/venues/active_venue_controller.dart';
import 'routing/app_router.dart';

class In2UApp extends ConsumerWidget {
  const In2UApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final messengerKey = ref.watch(globalMessengerKeyProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is AuthAuthenticated && prev is! AuthAuthenticated) {
        final isAdmin = next.user.role.toLowerCase() == 'admin';
        // Fresh login: clear any stale state from a prior session.
        ref.read(matchCelebrationProvider.notifier).state = null;
        if (!isAdmin) {
          ref.invalidate(activeVenueProvider);
          ref.read(activeVenueProvider.notifier).initialize();
          ref.read(matchesControllerProvider.notifier);
          ref.read(inAppMessageNotifierProvider);
        }
      } else if (next is AuthUnauthenticated && prev is! AuthUnauthenticated) {
        // Tear down hub/location stream cleanly, then invalidate so the
        // provider is rebuilt from scratch on the next login.
        ref.read(matchCelebrationProvider.notifier).state = null;
        ref.read(activeVenueProvider.notifier).reset();
        ref.invalidate(activeVenueProvider);
        ref.invalidate(inAppMessageNotifierProvider);
      }
    });

    return MaterialApp.router(
      title: 'in2u',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE91E63),
      ),
      routerConfig: router,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          AppLifecycleObserver(child: child ?? const SizedBox.shrink()),
    );
  }
}
