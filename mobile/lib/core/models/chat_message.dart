class ChatMessage {
  final String messageGuid;
  final String matchGuid;
  final String fromUserGuid;
  final String fromDisplayName;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? clientMsgId;
  final bool pending;
  final bool failed;

  const ChatMessage({
    required this.messageGuid,
    required this.matchGuid,
    required this.fromUserGuid,
    this.fromDisplayName = '',
    required this.body,
    required this.sentAt,
    this.readAt,
    this.clientMsgId,
    this.pending = false,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageGuid: json['messageGuid'].toString(),
      matchGuid: json['matchGuid'].toString(),
      fromUserGuid: json['fromUserGuid'].toString(),
      fromDisplayName: json['fromDisplayName']?.toString() ?? '',
      body: json['body'].toString(),
      sentAt: DateTime.parse(json['sentAt'].toString()),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'].toString()),
      clientMsgId: json['clientMsgId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'messageGuid': messageGuid,
        'matchGuid': matchGuid,
        'fromUserGuid': fromUserGuid,
        'fromDisplayName': fromDisplayName,
        'body': body,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'readAt': readAt?.toUtc().toIso8601String(),
        'clientMsgId': clientMsgId,
      };

  ChatMessage copyWith({
    String? messageGuid,
    DateTime? readAt,
    bool clearReadAt = false,
    bool? pending,
    bool? failed,
  }) {
    return ChatMessage(
      messageGuid: messageGuid ?? this.messageGuid,
      matchGuid: matchGuid,
      fromUserGuid: fromUserGuid,
      fromDisplayName: fromDisplayName,
      body: body,
      sentAt: sentAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      clientMsgId: clientMsgId,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
    );
  }
}
