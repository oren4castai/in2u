import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/signalr/hub_events.dart';
import '../../../core/signalr/venue_hub_client.dart';
import 'discovery_providers.dart';

/// Tracks whether the Discover list has pending changes from the server
/// that have not yet been reflected on screen. Decides whether to silently
/// auto-refresh (user idle) or show a "new events available" pill (user engaged).
final discoveryRefreshControllerProvider =
    StateNotifierProvider<DiscoveryRefreshController, bool>(
  (ref) => DiscoveryRefreshController(ref),
);

class DiscoveryRefreshController extends StateNotifier<bool> {
  DiscoveryRefreshController(this._ref) : super(false) {
    _sub = _ref.read(venueHubClientProvider).events.listen(_onHubEvent);
  }

  final Ref _ref;
  StreamSubscription? _sub;

  /// Set by the Discover screen so we can decide whether to auto-refresh.
  bool _isOnDiscover = false;
  bool _isEngaged = false;
  Timer? _autoDismissTimer;
  Timer? _debounceTimer;

  void setOnDiscover(bool value) {
    _isOnDiscover = value;
  }

  void setEngaged(bool value) {
    _isEngaged = value;
  }

  /// Called by the screen's manual refresh / pull-to-refresh / pill tap.
  void clear() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (mounted && state) state = false;
  }

  void _onHubEvent(HubEvent e) {
    if (e is! EventListChangedEvent) return;
    if (!mounted) return;

    // Debounce: wait 2 seconds of quiet before acting
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      // If the user is on Discover AND idle, refresh silently.
      if (_isOnDiscover && !_isEngaged) {
        _ref.invalidate(nearbyVenuesProvider);
        // No pill needed.
        return;
      }

      // Otherwise queue a pending refresh.
      if (!state) {
        state = true;
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(seconds: 30), () {
          if (mounted && state) state = false;
          _autoDismissTimer = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _autoDismissTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
