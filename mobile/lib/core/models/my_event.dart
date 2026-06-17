class MyEvent {
  final String venueGuid;
  final String name;
  final String? description;
  final String? photoUrl;
  final String eventType;
  final double lat;
  final double lng;
  final int radiusM;
  final DateTime? startsAt;
  final int? durationHours;
  final String status;
  final bool hasPhoto;
  final String shareCode;

  const MyEvent({
    required this.venueGuid,
    required this.name,
    this.photoUrl,
    required this.eventType,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.status,
    required this.hasPhoto,
    required this.shareCode,
    this.description,
    this.startsAt,
    this.durationHours,
  });

  bool get isActive => status == 'Active';
  bool get isPublic => eventType == 'Public';

  DateTime? get endsAt => (startsAt != null && durationHours != null)
      ? startsAt!.add(Duration(hours: durationHours!))
      : null;

  factory MyEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      // Parse as UTC and convert to local
      return DateTime.parse(s).toLocal();
    }

    return MyEvent(
      venueGuid: json['venueGuid'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      photoUrl: json['photoUrl'] as String?,
      eventType: json['eventType'] as String? ?? 'Public',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['radiusM'] as num).toInt(),
      startsAt: parseDate(json['startsAt']),
      durationHours: json['durationHours'] as int?,
      status: json['status'] as String,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      shareCode: json['shareCode'] as String? ?? '',
    );
  }
}
