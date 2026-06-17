import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/chat_message.dart';
import '../models/message_history_response.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<MessageHistoryResponse> getHistory(
    String matchGuid, {
    int? beforeId,
    int limit = 50,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.matchMessages(matchGuid),
        queryParameters: <String, dynamic>{
          if (beforeId != null) 'beforeId': beforeId,
          'limit': limit,
        },
      );
      return MessageHistoryResponse.fromJson(resp.data ?? const {});
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<ChatMessage?> send(
    String matchGuid, {
    required String body,
    String? clientMsgId,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.matchMessages(matchGuid),
        data: <String, dynamic>{
          'body': body,
          if (clientMsgId != null) 'clientMsgId': clientMsgId,
        },
      );
      // 204 No Content -> match gone (hard-deleted).
      if (resp.statusCode == 204 || resp.data == null) return null;
      return ChatMessage.fromJson(resp.data!);
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
