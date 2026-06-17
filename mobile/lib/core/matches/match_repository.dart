import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/match.dart';

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref.watch(apiClientProvider)),
);

class MatchRepository {
  MatchRepository(this._dio);

  final Dio _dio;

  Future<List<Match>> list() async {
    try {
      final resp = await _dio.get<List<dynamic>>(ApiEndpoints.matches);
      final data = resp.data ?? const [];
      return data
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> unmatch(String matchGuid) async {
    try {
      await _dio.delete<void>(ApiEndpoints.matchDelete(matchGuid));
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
