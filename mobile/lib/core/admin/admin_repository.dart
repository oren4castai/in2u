import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/admin_claim.dart';
import '../models/admin_event.dart';
import '../models/admin_stats.dart';
import '../models/admin_user.dart';
import '../models/admin_venue.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<AdminStats> getStats() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>(ApiEndpoints.adminStats);
      return AdminStats.fromJson(resp.data ?? const {});
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<List<AdminUser>> listUsers({String? search}) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        ApiEndpoints.adminUsers,
        queryParameters: _q(search),
      );
      return (resp.data ?? const [])
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deleteUser(String userGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.adminUserDelete(userGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<List<AdminVenue>> listVenues({String? search}) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        ApiEndpoints.adminVenues,
        queryParameters: _q(search),
      );
      return (resp.data ?? const [])
          .map((e) => AdminVenue.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deleteVenue(String venueGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.adminVenueDelete(venueGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<List<AdminEvent>> listEvents({String? search}) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        ApiEndpoints.adminEvents,
        queryParameters: _q(search),
      );
      return (resp.data ?? const [])
          .map((e) => AdminEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deleteEvent(String venueGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.adminEventDelete(venueGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<List<AdminClaim>> listClaims({String? search}) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      final resp = await _dio.get<List<dynamic>>(
        ApiEndpoints.adminVenueClaimsAll,
        queryParameters: params,
      );
      return (resp.data ?? const [])
          .map((e) => AdminClaim.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> approveClaim(String claimGuid) async {
    try {
      await _dio.post<void>(ApiEndpoints.adminClaimApprove(claimGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> deleteClaim(String claimGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.adminClaimDelete(claimGuid));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Map<String, dynamic>? _q(String? search) {
    if (search == null || search.trim().isEmpty) return null;
    return {'search': search.trim()};
  }

  ApiException _unwrap(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return NetworkException(e.message ?? 'Request failed');
  }
}
