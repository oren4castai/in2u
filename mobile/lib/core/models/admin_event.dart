class AdminEvent {
  final String venueGuid;
  final String name;
  final String status;
  final String eventType;
  final bool isPaused;
  final bool hasPhoto;
  final String? creatorName;
  final String? ownerName;
  final DateTime? startsAt;
  final DateTime createdAt;

  const AdminEvent({
    required this.venueGuid,
    required this.name,
    required this.status,
    required this.eventType,
    required this.isPaused,
    required this.hasPhoto,
    required this.creatorName,
    required this.ownerName,
    required this.startsAt,
    required this.createdAt,
  });

  factory AdminEvent.fromJson(Map<String, dynamic> json) {
    return AdminEvent(
      venueGuid: json['venueGuid'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      eventType: json['eventType'] as String,
      isPaused: json['isPaused'] as bool? ?? false,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      creatorName: json['creatorName'] as String?,
      ownerName: json['ownerName'] as String?,
      startsAt: json['startsAt'] != null
          ? DateTime.tryParse(json['startsAt'] as String)?.toLocal()
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
