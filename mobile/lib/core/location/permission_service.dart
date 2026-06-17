import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(),
);

class PermissionService {
  Position? _lastKnown;
  DateTime? _lastKnownAt;

  Future<bool> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position?> currentPosition() async {
    final now = DateTime.now();
    final cached = _lastKnown;
    final cachedAt = _lastKnownAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < const Duration(seconds: 5)) {
      return cached;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastKnown = pos;
      _lastKnownAt = now;
      return pos;
    } catch (_) {
      try {
        final fallback = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _lastKnown = fallback;
        _lastKnownAt = now;
        return fallback;
      } catch (_) {
        return null;
      }
    }
  }
}
