import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/models/feed_item.dart';
import '../../core/models/venue.dart';
import '../../core/signalr/venue_hub_client.dart';
import '../../core/swipes/swipe_repository.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/venues/venue_repository.dart';
import '../venues/active_venue_controller.dart';

final swipeFeedControllerProvider = StateNotifierProvider.autoDispose<
    SwipeFeedController, AsyncValue<List<FeedItem>>>(
  (ref) => SwipeFeedController(ref),
);

class SwipeFeedController extends StateNotifier<AsyncValue<List<FeedItem>>> {
  SwipeFeedController(this._ref) : super(const AsyncValue.loading()) {
    final venue = _ref.read(activeVenueProvider).valueOrNull;
    if (venue == null) {
      state = const AsyncValue.data([]);
    } else {
      _venueGuid = venue.venueGuid;
      Future.microtask(_loadInitial);
    }

    _ref.listen<AsyncValue<Venue?>>(activeVenueProvider, (prev, next) {
      final nextGuid = next.valueOrNull?.venueGuid;
      if (nextGuid == _venueGuid) return;
      _venueGuid = nextGuid;
      _cursor = null;
      _hasMore = true;
      _items = [];
      _swipeCount = 0; // Reset swipe count for new venue
      _swipedGuids.clear(); // Reset swiped tracking for new venue
      _didLocationRefresh = false;
      if (nextGuid == null) {
        state = const AsyncValue.data([]);
      } else {
        _cancelAutoRefresh();
        state = const AsyncValue.loading();
        Future.microtask(_loadInitial);
      }
    });
  }

  final Ref _ref;
  String? _venueGuid;
  String? _cursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _didLocationRefresh = false;
  int _swipeCount = 0; // Track how many items user has swiped through
  List<FeedItem> _items = [];
  final Set<String> _swipedGuids =
      {}; // Track locally swiped users to filter race conditions

  /// Check if a user has been swiped locally (may not be synced to server yet)
  bool isUserSwiped(String userGuid) => _swipedGuids.contains(userGuid);

  Timer? _autoRefreshTimer;
  int _autoRefreshAttempts = 0;
  static const _autoRefreshInterval = Duration(seconds: 15);
  static const _maxAutoRefreshAttempts = 20; // Stop after ~5 minutes

  /// True if auto-refresh gave up after max attempts - UI should show manual refresh
  bool get autoRefreshExhausted =>
      _autoRefreshAttempts >= _maxAutoRefreshAttempts;

  Future<void> _loadInitial() async {
    final guid = _venueGuid;
    if (guid == null) return;
    try {
      final resp =
          await _ref.read(swipeRepositoryProvider).getFeed(guid, limit: 20);
      if (!mounted) return;
      _cursor = resp.nextCursor;
      _hasMore = resp.nextCursor != null;
      // Filter out locally-swiped users to avoid race conditions
      _items =
          resp.items.where((e) => !_swipedGuids.contains(e.userGuid)).toList();
      _swipeCount = 0; // Reset swipe count for fresh load
      state = AsyncValue.data(List.unmodifiable(_items));
      if (_items.isEmpty) _startAutoRefresh();

      if (resp.items.isEmpty && !_didLocationRefresh) {
        _didLocationRefresh = true;
        await _refreshLocationAndRetry(guid);
      }
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _refreshLocationAndRetry(String guid) async {
    try {
      final pos = await _ref.read(locationServiceProvider).getOnce();
      await _ref.read(venueRepositoryProvider).updateLocation(
            guid,
            lat: pos.latitude,
            lng: pos.longitude,
          );
      if (!mounted || _venueGuid != guid) return;
      final resp =
          await _ref.read(swipeRepositoryProvider).getFeed(guid, limit: 20);
      if (!mounted || _venueGuid != guid) return;
      _cursor = resp.nextCursor;
      _hasMore = resp.nextCursor != null;
      // Filter out locally-swiped users to avoid race conditions
      _items =
          resp.items.where((e) => !_swipedGuids.contains(e.userGuid)).toList();
      _swipeCount = 0; // Reset swipe count
      state = AsyncValue.data(List.unmodifiable(_items));
      if (_items.isEmpty) _startAutoRefresh();
    } catch (_) {
      // Silent: leave existing empty state in place.
    }
  }

  Future<void> loadMoreIfNeeded() async {
    if (_loadingMore || !_hasMore) return;
    // Load more when user has swiped through most items
    final remaining = _items.length - _swipeCount;
    if (remaining >= 5) return;
    final guid = _venueGuid;
    if (guid == null) return;
    _loadingMore = true;
    try {
      final resp = await _ref
          .read(swipeRepositoryProvider)
          .getFeed(guid, cursor: _cursor, limit: 20);
      final existingIds = _items.map((e) => e.userGuid).toSet();
      // Filter out locally-swiped users AND existing items
      final additions = resp.items
          .where((e) =>
              !existingIds.contains(e.userGuid) &&
              !_swipedGuids.contains(e.userGuid))
          .toList();
      _items = [..._items, ...additions];
      _cursor = resp.nextCursor;
      _hasMore = resp.nextCursor != null;
      if (mounted) {
        state = AsyncValue.data(List.unmodifiable(_items));
      }
    } catch (_) {
      // silent — deck still has items; surface only via primary load failure
    } finally {
      _loadingMore = false;
    }
  }

  /// Mark user as swiped immediately (synchronous) - call this BEFORE async swipe()
  void markSwiped(String userGuid) {
    _swipedGuids.add(userGuid);
    _swipeCount++;
  }

  Future<bool> swipe(FeedItem item, bool right) async {
    final guid = _venueGuid;
    if (guid == null) return false;

    // Ensure marked (may already be marked by markSwiped)
    _swipedGuids.add(item.userGuid);

    // DON'T modify _items or state here - let CardSwiper handle its internal index
    // Call commitSwipe() after animation completes to update state

    try {
      _didLocationRefresh = false;
      final result = await _ref
          .read(swipeRepositoryProvider)
          .swipe(guid, item.userGuid, right: right);
      // Ambient targets never produce real matches; suppress any toast
      // defensively in case a race produced matched=true.
      if (result.matched && !item.isAmbient) {
        final hub = _ref.read(venueHubClientProvider);
        if (!hub.isConnected) {
          showAppSnackBarFromRef(
            _ref,
            "It's a match with ${item.displayName}!",
          );
        }
      }
      return result.matched && !item.isAmbient;
    } catch (_) {
      // On error, remove from swiped set so user can try again
      _swipedGuids.remove(item.userGuid);
      _swipeCount--;
      showAppSnackBarFromRef(_ref, 'Swipe failed. Please try again.');
      return false;
    }
  }

  /// Call after swipe animation completes to remove item from state.
  /// This prevents rebuilds during animation while ensuring the item
  /// is removed from the list before the next rebuild.
  void commitSwipe(String userGuid) {
    if (!mounted) return;
    _items = _items.where((e) => e.userGuid != userGuid).toList();
    state = AsyncValue.data(List.unmodifiable(_items));
    if (_items.isEmpty) {
      _startAutoRefresh();
      unawaited(_silentRefresh());
    }
  }

  /// Called when deck animation reaches end. Starts non-destructive
  /// polling for new users without clearing this session's swiped memory.
  void onDeckExhausted() {
    if (!mounted) return;
    _startAutoRefresh();
    unawaited(_silentRefresh());
  }

  void _startAutoRefresh() {
    if (_autoRefreshTimer?.isActive == true) return;
    if (_autoRefreshAttempts >= _maxAutoRefreshAttempts)
      return; // Already exhausted
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      unawaited(_silentRefresh());
    });
  }

  void _cancelAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _silentRefresh() async {
    final guid = _venueGuid;
    if (guid == null) {
      _cancelAutoRefresh();
      return;
    }

    _autoRefreshAttempts++;
    if (_autoRefreshAttempts >= _maxAutoRefreshAttempts) {
      _cancelAutoRefresh();
      // Re-emit state to trigger UI update showing "try again later"
      if (mounted) {
        state = AsyncValue.data(List.unmodifiable(_items));
      }
      return;
    }

    try {
      final resp =
          await _ref.read(swipeRepositoryProvider).getFeed(guid, limit: 20);
      if (!mounted) return;
      _cursor = resp.nextCursor;
      _hasMore = resp.nextCursor != null;
      // Filter out locally-swiped users to avoid race conditions
      _items =
          resp.items.where((e) => !_swipedGuids.contains(e.userGuid)).toList();
      _swipeCount = 0; // Reset swipe count after refresh
      if (_items.isNotEmpty) {
        _cancelAutoRefresh();
        _autoRefreshAttempts = 0; // Reset counter when users found
      }
      state = AsyncValue.data(List.unmodifiable(_items));
    } on DioException catch (e) {
      // Stop retrying on 400/401 (not checked in, unauthorized)
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        _cancelAutoRefresh();
      }
      // Otherwise silent — leave empty state in place, try again next tick
    } catch (_) {
      // silent — leave empty state in place, try again next tick
    }
  }

  Future<void> refresh() async {
    _cancelAutoRefresh();
    _autoRefreshAttempts = 0; // Reset counter on manual refresh
    _cursor = null;
    _hasMore = true;
    _items = [];
    _swipeCount = 0; // Reset swipe count
    state = const AsyncValue.loading();
    await _loadInitial();
  }

  @override
  void dispose() {
    _cancelAutoRefresh();
    super.dispose();
  }
}
