import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/venues/event_category.dart';
import '../../../core/location/permission_service.dart';
import '../../../core/models/venue.dart';
import '../../../core/venues/venue_repository.dart';

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final perm = ref.read(permissionServiceProvider);
  final ok = await perm.ensureLocationPermission();
  if (!ok) return null;
  try {
    return await perm.currentPosition();
  } catch (_) {
    return null;
  }
});

/// Selected category filter (null = ALL categories)
final selectedCategoryProvider = StateProvider<EventCategory?>((ref) => null);

/// Discovery radius in meters (default 300km)
final discoveryRadiusProvider = StateProvider<int>((ref) => 300000);

final nearbyVenuesProvider =
    FutureProvider.autoDispose<List<Venue>>((ref) async {
  final pos = await ref.watch(currentPositionProvider.future);
  if (pos == null) return [];

  final category = ref.watch(selectedCategoryProvider);
  final radiusM = ref.watch(discoveryRadiusProvider);

  return ref.read(venueRepositoryProvider).discover(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusM: radiusM,
        category: category,
      );
});
