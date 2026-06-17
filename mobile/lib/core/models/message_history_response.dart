import 'chat_message.dart';

class MessageHistoryResponse {
  final List<ChatMessage> items;
  final int? nextBeforeId;

  const MessageHistoryResponse({
    required this.items,
    required this.nextBeforeId,
  });

  factory MessageHistoryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .map((e) => ChatMessage.fromJson(
                  (e as Map).map((k, v) => MapEntry(k.toString(), v)),
                ))
            .toList(growable: false)
        : const <ChatMessage>[];
    return MessageHistoryResponse(
      items: items,
      nextBeforeId: (json['nextBeforeId'] as num?)?.toInt(),
    );
  }
}
