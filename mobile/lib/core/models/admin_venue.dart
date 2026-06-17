class AdminVenue {
  final String venueGuid;
  final String name;
  final String type;
  final String status;
  final String eventType;
  final bool hasPhoto;
  final String? creatorName;
  final String? ownerName;
  final DateTime createdAt;

  const AdminVenue({
    required this.venueGuid,
    required this.name,
    required this.type,
    required this.status,
    required this.eventType,
    required this.hasPhoto,
    required this.creatorName,
    required this.ownerName,
    required this.createdAt,
  });

  factory AdminVenue.fromJson(Map<String, dynamic> json) {
    return AdminVenue(
      venueGuid: json['venueGuid'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      eventType: json['eventType'] as String,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      creatorName: json['creatorName'] as String?,
      ownerName: json['ownerName'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
