import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/my_claim.dart';
import '../models/owner_venue_detail.dart';
import '../models/owner_venue_summary.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => OwnerRepository(ref.watch(apiClientProvider)),
);

class OwnerRepository {
  OwnerRepository(this._dio);

  final Dio _dio;

  Future<List<OwnerVenueSummary>> listVenues() async {
    try {
      final resp = await _dio.get<List<dynamic>>(ApiEndpoints.ownerVenues);
      final data = resp.data ?? const [];
      return data
          .map((e) => OwnerVenueSummary.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<OwnerVenueDetail> getVenueDetail(String ownerGuid) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerVenueDetail(ownerGuid),
      );
      return OwnerVenueDetail.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<List<MyClaim>> listMyClaims() async {
    try {
      final resp = await _dio.get<List<dynamic>>(ApiEndpoints.venueClaimsMine);
      final data = resp.data ?? const [];
      return data
          .map((e) => MyClaim.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<String> submitClaim({
    required String name,
    required String contactName,
    required String contactPhone,
    required double lat,
    required double lng,
    required int radiusM,
    required List<int> photoBytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'file': MultipartFile.fromBytes(
          photoBytes,
          filename: 'claim.jpg',
          contentType: DioMediaType.parse(contentType),
        ),
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.venueClaims,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return resp.data!['claimGuid'] as String;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> closeEvent(String venueGuid) async {
    try {
      await _dio.post<void>(ApiEndpoints.ownerEventClose(venueGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> rescheduleEvent(String venueGuid, DateTime startsAt) async {
    try {
      await _dio.patch<void>(
        ApiEndpoints.ownerEventReschedule(venueGuid),
        data: {'startsAt': startsAt.toUtc().toIso8601String()},
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> sendEventAnnouncement(String venueGuid, String message) async {
    try {
      await _dio.post<void>(
        ApiEndpoints.ownerEventAnnouncement(venueGuid),
        data: {'message': message},
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deleteEvent(String venueGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.ownerEventDelete(venueGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deletePastEvent(String ownerGuid, int logId) async {
    try {
      await _dio
          .delete<void>(ApiEndpoints.ownerPastEventDelete(ownerGuid, logId));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deleteVenue(String ownerGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.ownerVenueDelete(ownerGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return NetworkException(e.message ?? 'Request failed');
  }
}
