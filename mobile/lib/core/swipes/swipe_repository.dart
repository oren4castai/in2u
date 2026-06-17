import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/feed_response.dart';
import '../models/swipe_result.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>(
  (ref) => SwipeRepository(ref.watch(apiClientProvider)),
);

class SwipeRepository {
  SwipeRepository(this._dio);

  final Dio _dio;

  Future<FeedResponse> getFeed(
    String venueGuid, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final qp = <String, dynamic>{'limit': limit};
      if (cursor != null && cursor.isNotEmpty) qp['cursor'] = cursor;
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.venueFeed(venueGuid),
        queryParameters: qp,
      );
      return FeedResponse.fromJson(resp.data ?? const {});
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<SwipeResult> swipe(
    String venueGuid,
    String toUserGuid, {
    required bool right,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.venueSwipe(venueGuid, toUserGuid),
        data: {'direction': right ? 'right' : 'left'},
      );
      return SwipeResult.fromJson(resp.data ?? const {});
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
