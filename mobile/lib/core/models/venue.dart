import 'ambient_preview.dart';

class Venue {
  final String venueGuid;
  final String name;
  final String? description;
  final String type;
  final String eventType;
  final double lat;
  final double lng;
  final int radiusM;
  final double distanceM;
  final String densityBucket;
  final DateTime? startsAt;
  final int? durationHours;
  final String status;
  final bool hasPhoto;
  final String shareCode;
  final List<String> previewAvatars;
  final List<AmbientPreview> ambientPreview;
  final String? category;
  final String? ownerName;

  const Venue({
    required this.venueGuid,
    required this.name,
    required this.type,
    required this.eventType,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.distanceM,
    required this.densityBucket,
    required this.status,
    required this.hasPhoto,
    required this.shareCode,
    required this.previewAvatars,
    this.ambientPreview = const <AmbientPreview>[],
    this.description,
    this.startsAt,
    this.durationHours,
    this.category,
    this.ownerName,
  });

  bool get isEvent => type == 'Event';
  bool get isActive => status == 'Active';

  DateTime? get endsAt => (startsAt != null && durationHours != null)
      ? startsAt!.add(Duration(hours: durationHours!))
      : null;

  factory Venue.fromJson(Map<String, dynamic> json) {
    final rawAvatars = json['previewAvatars'];
    final avatars = rawAvatars is List
        ? rawAvatars.map((e) => e.toString()).toList()
        : <String>[];
    final rawAmbient = json['ambientPreview'];
    final ambient = rawAmbient is List
        ? rawAmbient
            .whereType<Map>()
            .map((e) => AmbientPreview.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList()
        : <AmbientPreview>[];
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      return DateTime.parse(s).toUtc();
    }

    return Venue(
      venueGuid: json['venueGuid'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String,
      eventType: json['eventType'] as String? ?? 'Public',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['radiusM'] as num).toInt(),
      distanceM: (json['distanceM'] as num? ?? 0).toDouble(),
      densityBucket: json['densityBucket'] as String? ?? 'Empty',
      startsAt: parseDate(json['startsAt']),
      durationHours: json['durationHours'] as int?,
      status: json['status'] as String,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      shareCode: json['shareCode'] as String? ?? '',
      previewAvatars: avatars,
      ambientPreview: ambient,
      category: json['category'] as String?,
      ownerName: json['ownerName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'venueGuid': venueGuid,
        'name': name,
        'description': description,
        'type': type,
        'eventType': eventType,
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'distanceM': distanceM,
        'densityBucket': densityBucket,
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'durationHours': durationHours,
        'status': status,
        'hasPhoto': hasPhoto,
        'shareCode': shareCode,
        'previewAvatars': previewAvatars,
        'ambientPreview': ambientPreview.map((e) => e.toJson()).toList(),
        'category': category,
      };

  Venue copyWith({
    String? densityBucket,
    double? distanceM,
    String? status,
    String? category,
  }) =>
      Venue(
        venueGuid: venueGuid,
        name: name,
        description: description,
        type: type,
        eventType: eventType,
        lat: lat,
        lng: lng,
        radiusM: radiusM,
        distanceM: distanceM ?? this.distanceM,
        densityBucket: densityBucket ?? this.densityBucket,
        startsAt: startsAt,
        durationHours: durationHours,
        status: status ?? this.status,
        hasPhoto: hasPhoto,
        shareCode: shareCode,
        previewAvatars: previewAvatars,
        ambientPreview: ambientPreview,
        category: category ?? this.category,
      );
}
