class OwnerVenueSummary {
  final String ownerGuid;
  final String name;
  final int activeEventCount;
  final int liveCount;
  final bool hasPhoto;

  const OwnerVenueSummary({
    required this.ownerGuid,
    required this.name,
    required this.activeEventCount,
    required this.liveCount,
    required this.hasPhoto,
  });

  factory OwnerVenueSummary.fromJson(Map<String, dynamic> json) {
    return OwnerVenueSummary(
      ownerGuid: json['ownerGuid'] as String,
      name: json['name'] as String,
      activeEventCount: (json['activeEventCount'] as num?)?.toInt() ?? 0,
      liveCount: (json['liveCount'] as num?)?.toInt() ?? 0,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
    );
  }
}
