import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/matches/match_repository.dart';
import '../../core/models/match.dart';
import '../../core/models/venue.dart';
import '../../core/matches/match_celebration_provider.dart';
import '../../core/signalr/hub_events.dart';
import '../../core/signalr/venue_hub_client.dart';
import '../../core/ui/global_messenger.dart';
import '../venues/active_venue_controller.dart';

final matchesControllerProvider =
    StateNotifierProvider<MatchesController, AsyncValue<List<Match>>>(
  (ref) => MatchesController(ref),
);

class MatchesController extends StateNotifier<AsyncValue<List<Match>>> {
  MatchesController(this._ref) : super(const AsyncValue.loading()) {
    _hubSub = _ref.read(venueHubClientProvider).events.listen(_onHubEvent);

    _ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is AuthUnauthenticated) {
        state = const AsyncValue.data([]);
      } else if (next is AuthAuthenticated && prev is! AuthAuthenticated) {
        Future.microtask(refresh);
      }
    });

    _ref.listen<AsyncValue<Venue?>>(activeVenueProvider, (prev, next) {
      final prevGuid = prev?.valueOrNull?.venueGuid;
      final nextGuid = next.valueOrNull?.venueGuid;
      if (prevGuid != nextGuid) {
        Future.microtask(refresh);
      }
    });

    final auth = _ref.read(authControllerProvider);
    if (auth.isAuthenticated) {
      Future.microtask(refresh);
    } else {
      state = const AsyncValue.data([]);
    }
  }

  final Ref _ref;
  StreamSubscription<HubEvent>? _hubSub;

  Future<void> refresh() async {
    try {
      final list = await _ref.read(matchRepositoryProvider).list();
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unmatch(String matchGuid) async {
    final current = state.value ?? const <Match>[];
    final without =
        current.where((m) => m.matchGuid != matchGuid).toList(growable: false);
    state = AsyncValue.data(without);
    try {
      await _ref.read(matchRepositoryProvider).unmatch(matchGuid);
    } catch (_) {
      showAppSnackBarFromRef(_ref, 'Could not unmatch. Please try again.');
      await refresh();
    }
  }

  void _onHubEvent(HubEvent e) {
    if (e is MatchCreatedEvent) {
      final current = state.value ?? const <Match>[];
      if (current.any((m) => m.matchGuid == e.match.matchGuid)) return;
      final next = [e.match, ...current];
      Future.microtask(() {
        if (!mounted) return;
        state = AsyncValue.data(next);
        _ref.read(matchCelebrationProvider.notifier).state = e.match;
      });
    } else if (e is MatchEndedEvent) {
      final current = state.value ?? const <Match>[];
      final without = current
          .where((m) => m.matchGuid != e.matchGuid)
          .toList(growable: false);
      if (without.length == current.length) return;
      Future.microtask(() {
        if (!mounted) return;
        state = AsyncValue.data(without);
      });
    }
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    super.dispose();
  }
}
