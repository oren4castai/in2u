import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/location/location_service.dart';
import '../../core/location/permission_service.dart';
import '../../core/models/venue.dart';
import '../../core/signalr/hub_events.dart';
import '../../core/signalr/venue_hub_client.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/venues/venue_repository.dart';

final activeVenueProvider =
    StateNotifierProvider<ActiveVenueController, AsyncValue<Venue?>>(
  (ref) => ActiveVenueController(ref),
);

class ActiveVenueController extends StateNotifier<AsyncValue<Venue?>> {
  ActiveVenueController(this._ref) : super(const AsyncValue.data(null)) {
    _hubSub = _ref.read(venueHubClientProvider).events.listen(_onHubEvent);
    _ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is AuthUnauthenticated) {
        reset();
      }
    });
  }

  final Ref _ref;
  StreamSubscription<HubEvent>? _hubSub;
  StreamSubscription? _locationSub;
  DateTime? _lastSentAt;
  Timer? _reconnectTimer;

  Future<void> initialize() async {
    if (!mounted) return; // Guard at start
    final hub = _ref.read(venueHubClientProvider);
    state = const AsyncValue.loading();
    try {
      if (!hub.isConnected) {
        await hub.connect();
      }
      final membership =
          await _ref.read(venueRepositoryProvider).getActiveMembership();
      if (!mounted) return;
      if (membership != null) {
        final venue = await _ref
            .read(venueRepositoryProvider)
            .getDetails(membership.venueGuid);
        if (!mounted) return;
        state = AsyncValue.data(venue);
        _startLocationStream(venue);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Venue> checkIn(Venue venue) async {
    if (!mounted) throw StateError('Controller disposed');
    final pos = await _ref.read(permissionServiceProvider).currentPosition();
    if (pos == null) throw StateError('Unable to get location');
    if (!mounted) throw StateError('Controller disposed');
    final repo = _ref.read(venueRepositoryProvider);
    await repo.checkIn(
      venue.venueGuid,
      lat: pos.latitude,
      lng: pos.longitude,
    );
    if (!mounted) throw StateError('Controller disposed');
    final hub = _ref.read(venueHubClientProvider);
    if (!hub.isConnected) {
      await hub.connect();
    }
    if (!mounted) throw StateError('Controller disposed');
    try {
      await hub.joinVenue(venue.venueGuid);
    } catch (_) {
      // hub may sync via OnConnectedAsync; ignore
    }
    if (!mounted) return venue; // Return without state update
    state = AsyncValue.data(venue);
    _startLocationStream(venue);
    return venue;
  }

  Future<void> leave() async {
    if (!mounted) return;
    final current = state.value;
    if (current == null) return;
    final hub = _ref.read(venueHubClientProvider);
    try {
      await _ref.read(venueRepositoryProvider).leave(current.venueGuid);
    } catch (_) {
      return; // API failed — server still has user checked in, do not clear local state
    }
    if (!mounted) return;
    try {
      await hub.leaveVenueGroup(current.venueGuid);
    } catch (_) {
      // ignore
    }
    await _stopLocationStream();
    if (!mounted) return;
    state = const AsyncValue.data(null);
  }

  void reset() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopLocationStream();
    _ref.read(venueHubClientProvider).disconnect();
    if (!mounted) return;
    state = const AsyncValue.data(null);
  }

  void _onHubEvent(HubEvent e) {
    if (!mounted) return; // Guard against events after dispose
    try {
      final current = state.value;
      if (e is ForceCheckoutEvent) {
        if (current != null && current.venueGuid == e.venueGuid) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          _stopLocationStream();
          // showAppSnackBarFromRef(_ref, 'This event has been closed.');
          Future.microtask(() {
            if (!mounted) return;
            state = const AsyncValue.data(null);
          });
        }
      } else if (e is PresenceUpdatedEvent) {
        if (current != null && current.venueGuid == e.venueGuid) {
          final updated = current.copyWith(densityBucket: e.densityBucket);
          Future.microtask(() {
            if (!mounted) return;
            state = AsyncValue.data(updated);
          });
        }
      } else if (e is VenueJoinedEvent) {
        // Cancel any pending reconnect-expiry timer — the server confirmed
        // the membership is still active.
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        if (current?.venueGuid == e.venueGuid) {
          // Same venue after reconnect — just restart the location stream.
          _startLocationStream(current!);
          return;
        }
        unawaited(_loadJoinedVenue(e.venueGuid));
      } else if (e is ReconnectedEvent) {
        // Stop sending location but keep current state while we verify with server.
        _stopLocationStream();
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        unawaited(_verifyMembershipAfterReconnect());
      }
    } catch (_) {
      // Ignore errors during hub event processing
    }
  }

  Future<void> _loadJoinedVenue(String venueGuid) async {
    if (!mounted) return; // Guard at start
    try {
      final venue =
          await _ref.read(venueRepositoryProvider).getDetails(venueGuid);
      if (!mounted) return;
      state = AsyncValue.data(venue);
      _startLocationStream(venue);
    } catch (_) {
      // Leave state as-is; a subsequent event or manual refresh will recover.
    }
  }

  Future<void> _verifyMembershipAfterReconnect() async {
    if (!mounted) return; // Guard at start
    try {
      final membership =
          await _ref.read(venueRepositoryProvider).getActiveMembership();
      if (!mounted) return;
      if (membership != null) {
        final current = state.value;
        if (current?.venueGuid != membership.venueGuid) {
          unawaited(_loadJoinedVenue(membership.venueGuid));
        } else {
          _startLocationStream(current!);
        }
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (_) {
      // Network error during verify — keep current state.
      // The next location update will fail and surface the issue.
    }
  }

  void _startLocationStream(Venue venue) {
    _stopLocationStream();
    // Event venues do not need GPS streaming.
    if (venue.isEvent) return;
    final svc = _ref.read(locationServiceProvider);
    _locationSub = svc.watch().listen((pos) async {
      if (!mounted) return; // Guard against events after dispose
      final now = DateTime.now();
      final last = _lastSentAt;
      if (last != null && now.difference(last) < const Duration(seconds: 5)) {
        return;
      }
      _lastSentAt = now;
      try {
        await _ref.read(venueHubClientProvider).sendLocation(
              venue.venueGuid,
              pos.latitude,
              pos.longitude,
            );
      } catch (_) {
        // ignore transient errors
      }
    });
  }

  Future<void> _stopLocationStream() async {
    await _locationSub?.cancel();
    _locationSub = null;
    _lastSentAt = null;
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _hubSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }
}
