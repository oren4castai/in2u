import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

class LocationService {
  static const String _fakeLatRaw =
      String.fromEnvironment('DEV_FAKE_LAT', defaultValue: '');
  static const String _fakeLngRaw =
      String.fromEnvironment('DEV_FAKE_LNG', defaultValue: '');
  static final double? _fakeLat =
      _fakeLatRaw.isEmpty ? null : double.tryParse(_fakeLatRaw);
  static final double? _fakeLng =
      _fakeLngRaw.isEmpty ? null : double.tryParse(_fakeLngRaw);

  bool get _useFake =>
      kDebugMode && kIsWeb && _fakeLat != null && _fakeLng != null;

  Position _fakePosition() => Position(
        latitude: _fakeLat!,
        longitude: _fakeLng!,
        timestamp: DateTime.now().toUtc(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: true,
        floor: null,
      );

  Stream<Position> watch({
    Duration interval = const Duration(seconds: 7),
    double distanceFilter = 5,
  }) {
    if (_useFake) {
      return _fakeStream(interval);
    }
    return Geolocator.getPositionStream(
      locationSettings: _settings(interval, distanceFilter),
    );
  }

  Stream<Position> _fakeStream(Duration interval) async* {
    yield _fakePosition();
    while (true) {
      await Future.delayed(interval);
      yield _fakePosition();
    }
  }

  Future<Position> getOnce() {
    if (_useFake) {
      return Future.value(_fakePosition());
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
  }

  LocationSettings _settings(Duration interval, double distanceFilter) {
    if (kIsWeb) {
      return LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: interval,
        distanceFilter: distanceFilter.toInt(),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter.toInt(),
    );
  }
}
