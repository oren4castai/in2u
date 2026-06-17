import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/my_event.dart';
import '../../core/models/venue_participant.dart';
import '../../core/models/venue_stats.dart';
import '../../core/venues/venue_repository.dart';

final myEventsProvider = FutureProvider.autoDispose<List<MyEvent>>((ref) {
  return ref.watch(venueRepositoryProvider).getMyEvents();
});

final eventStatsProvider =
    FutureProvider.autoDispose.family<VenueStats, String>((ref, venueGuid) {
  return ref.watch(venueRepositoryProvider).getVenueStats(venueGuid);
});

final eventParticipantsProvider = FutureProvider.autoDispose
    .family<List<VenueParticipant>, String>((ref, venueGuid) {
  return ref.watch(venueRepositoryProvider).getParticipants(venueGuid);
});
