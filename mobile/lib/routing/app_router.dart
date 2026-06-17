import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../core/push/pending_deep_link.dart';
import '../core/ui/global_messenger.dart';
import '../features/admin/admin_screen.dart';
import '../features/auth/login/login_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/swipe/swipe_screen.dart';
import '../features/events/create_event_screen.dart';
import '../features/events/edit_event_screen.dart';
import '../features/events/event_manage_screen.dart';
import '../features/events/my_events_screen.dart';
import '../features/owner/claim_venue_screen.dart';
import '../features/owner/venue_dashboard_screen.dart';
import '../features/owner/venue_detail_screen.dart';
import '../features/venues/active_venue_controller.dart';
import '../features/venues/details/venue_details_screen.dart';
import '../features/venues/discovery/discovery_screen.dart';
import 'routes.dart';

class _AuthListenable extends ValueNotifier<int> {
  _AuthListenable() : super(0);
  void tick() => value = value + 1;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable();
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    listenable.tick();
  });
  ref.listen(activeVenueProvider, (prev, next) {
    listenable.tick();
  });
  ref.listen<String?>(pendingDeepLinkProvider, (prev, next) {
    if (next != null) listenable.tick();
  });
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: ref.watch(globalNavigatorKeyProvider),
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final user = auth.userOrNull;
      final isAdmin = user?.role.toLowerCase() == 'admin';
      final active = auth.isAuthenticated
          ? ref.read(activeVenueProvider).valueOrNull
          : null;

      if ((auth.isInitial || auth.isLoading) && loc != AppRoutes.splash) {
        return AppRoutes.splash;
      }
      if (auth.isUnauthenticated && loc != AppRoutes.login) {
        return AppRoutes.login;
      }
      if (auth.isAuthenticated &&
          (loc == AppRoutes.login || loc == AppRoutes.splash)) {
        if (isAdmin) return AppRoutes.admin;
        return active == null ? AppRoutes.discover : AppRoutes.swipe;
      }

      if (auth.isAuthenticated && isAdmin && loc != AppRoutes.admin) {
        return AppRoutes.admin;
      }

      if (auth.isAuthenticated && !isAdmin && loc == AppRoutes.admin) {
        return active == null ? AppRoutes.discover : AppRoutes.swipe;
      }

      if (auth.isAuthenticated) {
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null && pending != loc) {
          Future.microtask(() {
            ref.read(pendingDeepLinkProvider.notifier).state = null;
          });
          return pending;
        }
      }

      if (auth.isAuthenticated && active != null) {
        if (loc == AppRoutes.discover || loc.startsWith('/venue/')) {
          return AppRoutes.swipe;
        }
      }

      if (auth.isAuthenticated && loc == AppRoutes.swipe) {
        if (active == null) return AppRoutes.discover;
      }
      if (auth.isAuthenticated && loc == AppRoutes.matches) {
        if (active == null) return AppRoutes.discover;
      }
      if (auth.isAuthenticated && loc.startsWith('/matches/')) {
        if (active == null) return AppRoutes.discover;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.discover,
        builder: (context, state) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: AppRoutes.me,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.venueDetails,
        builder: (context, state) {
          final venueGuid = state.pathParameters['venueGuid'];
          if (venueGuid == null) return const SizedBox();
          return VenueDetailsScreen(
            venueGuid: venueGuid,
            fromShareCode: state.uri.queryParameters['fromCode'] == 'true',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.swipe,
        builder: (context, state) => const SwipeScreen(),
      ),
      GoRoute(
        path: AppRoutes.matches,
        builder: (context, state) => const MatchesScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final matchGuid = state.pathParameters['matchGuid'];
          if (matchGuid == null) return const SizedBox();
          return ChatScreen(matchGuid: matchGuid);
        },
      ),
      GoRoute(
        path: AppRoutes.myEvents,
        builder: (context, state) => const MyEventsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createEvent,
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventManage,
        builder: (context, state) {
          final venueGuid = state.pathParameters['venueGuid'];
          if (venueGuid == null) return const SizedBox();
          return EventManageScreen(venueGuid: venueGuid);
        },
      ),
      GoRoute(
        path: AppRoutes.eventEdit,
        builder: (context, state) {
          final venueGuid = state.pathParameters['venueGuid'];
          if (venueGuid == null) return const SizedBox();
          return EditEventScreen(venueGuid: venueGuid);
        },
      ),
      GoRoute(
        path: AppRoutes.venueDashboard,
        builder: (context, state) => const VenueDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.claimVenue,
        builder: (context, state) => const ClaimVenueScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueDetail,
        builder: (context, state) {
          final ownerGuid = state.pathParameters['ownerGuid'];
          if (ownerGuid == null) return const SizedBox();
          return VenueDetailScreen(ownerGuid: ownerGuid);
        },
      ),
      GoRoute(
        path: AppRoutes.ownerCreateEvent,
        builder: (context, state) {
          final ownerGuid = state.pathParameters['ownerGuid'];
          if (ownerGuid == null) return const SizedBox();
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          double? venueLat;
          double? venueLng;
          int? venueRadiusM;
          try {
            if (extra['lat'] is double) venueLat = extra['lat'] as double;
            if (extra['lng'] is double) venueLng = extra['lng'] as double;
            if (extra['radiusM'] is int) venueRadiusM = extra['radiusM'] as int;
          } catch (_) {}
          return CreateEventScreen(
            ownerGuid: ownerGuid,
            venueLat: venueLat,
            venueLng: venueLng,
            venueRadiusM: venueRadiusM,
          );
        },
      ),
    ],
  );
});
