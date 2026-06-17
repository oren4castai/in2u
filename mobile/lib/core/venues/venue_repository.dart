import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/membership.dart';
import '../models/my_event.dart';
import '../models/venue.dart';
import '../models/venue_participant.dart';
import 'event_category.dart';
import 'governance_preview.dart';
import '../models/venue_stats.dart';

final venueRepositoryProvider = Provider<VenueRepository>(
  (ref) => VenueRepository(ref.watch(apiClientProvider)),
);

class VenueRepository {
  VenueRepository(this._dio);

  final Dio _dio;

  Future<List<Venue>> discover({
    required double lat,
    required double lng,
    int radiusM = 5000,
    EventCategory? category,
  }) async {
    try {
      final qp = <String, dynamic>{'lat': lat, 'lng': lng, 'radiusM': radiusM};
      if (category != null) qp['category'] = category.apiValue;
      final resp = await _dio.get<List<dynamic>>(
        ApiEndpoints.venuesDiscover,
        queryParameters: qp,
      );
      final data = resp.data ?? const [];
      return data
          .map((e) => Venue.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Venue> getDetails(
    String venueGuid, {
    double? lat,
    double? lng,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (lat != null) qp['lat'] = lat;
      if (lng != null) qp['lng'] = lng;
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.venueDetails(venueGuid),
        queryParameters: qp.isEmpty ? null : qp,
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return Venue.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Venue> getByShareCode(String code, {double? lat, double? lng}) async {
    try {
      final qp = <String, dynamic>{};
      if (lat != null) qp['lat'] = lat;
      if (lng != null) qp['lng'] = lng;
      final resp = await _dio.get<Map<String, dynamic>>(
        '/venues/by-code/$code',
        queryParameters: qp.isEmpty ? null : qp,
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return Venue.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Membership> checkIn(
    String venueGuid, {
    required double lat,
    required double lng,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.venueCheckin(venueGuid),
        data: {'lat': lat, 'lng': lng},
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return Membership.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> leave(String venueGuid) async {
    try {
      await _dio.post<void>(ApiEndpoints.venueLeave(venueGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Membership?> getActiveMembership() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(ApiEndpoints.venuesMe);
      if (resp.statusCode == 204 || resp.data == null) return null;
      return Membership.fromJson(resp.data!);
    } on DioException catch (e) {
      final wrapped = _unwrap(e);
      throw wrapped;
    }
  }

  Future<void> updateLocation(
    String venueGuid, {
    required double lat,
    required double lng,
  }) async {
    try {
      await _dio.post<void>(
        ApiEndpoints.venueLocation(venueGuid),
        data: {'lat': lat, 'lng': lng},
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return NetworkException(e.message ?? 'Request failed');
  }

  Future<List<MyEvent>> getMyEvents() async {
    try {
      final resp = await _dio.get<List<dynamic>>(ApiEndpoints.eventsMine);
      final data = resp.data ?? const [];
      return data
          .map((e) => MyEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Map<String, dynamic>> createEvent({
    required String name,
    String? description,
    required String eventType,
    required double lat,
    required double lng,
    required int radiusM,
    required DateTime startsAt,
    required int durationHours,
    EventCategory? category,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.eventsCreate,
        data: {
          'name': name,
          'description': description,
          'eventType': eventType,
          'lat': lat,
          'lng': lng,
          'radiusM': radiusM,
          'startsAt': startsAt.toUtc().toIso8601String(),
          'durationHours': durationHours,
          if (category != null) 'category': category.apiValue,
        },
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return resp.data!;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<GovernancePreview> previewGovernance({
    required double lat,
    required double lng,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.eventsGovernance,
        queryParameters: {'lat': lat, 'lng': lng},
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return GovernancePreview.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<MyEvent> patchEvent(
    String venueGuid, {
    String? name,
    String? description,
    int? durationHours,
  }) async {
    try {
      final resp = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.eventPatch(venueGuid),
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (durationHours != null) 'durationHours': durationHours,
        },
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return MyEvent.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<MyEvent> getEvent(String venueGuid) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.eventPatch(venueGuid),
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return MyEvent.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<VenueStats> getVenueStats(String venueGuid) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.venueManageStats(venueGuid),
      );
      if (resp.data == null) throw NetworkException('Empty response');
      return VenueStats.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<List<VenueParticipant>> getParticipants(
    String venueGuid, {
    String? search,
  }) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        ApiEndpoints.venueManageParticipants(venueGuid),
        queryParameters:
            search != null && search.isNotEmpty ? {'search': search} : null,
      );
      final data = resp.data ?? const [];
      return data
          .map((e) => VenueParticipant.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> forceCheckout(String venueGuid, String targetUserGuid) async {
    try {
      await _dio.delete<void>(
        ApiEndpoints.venueManageForceCheckout(venueGuid, targetUserGuid),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> uploadEventPhoto(
      String venueGuid, List<int> bytes, String contentType) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'photo.jpg',
          contentType: DioMediaType.parse(contentType),
        ),
      });
      await _dio.post<void>(
        ApiEndpoints.eventPhoto(venueGuid),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Uint8List?> getEventPhotoBytes(String venueGuid) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final resp = await _dio.get<List<int>>(
        '${ApiEndpoints.venuePhotoServe(venueGuid)}?t=$ts',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _unwrap(e);
    }
  }

  Future<void> closeEvent(String venueGuid) async {
    try {
      await _dio.post<void>(ApiEndpoints.eventClose(venueGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }
}
