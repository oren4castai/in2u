class VenueStats {
  final int joinedCount;
  final int matchesCount;
  final int viewsCount;
  final String shareCode;
  final List<int> joinedSparkline;
  final List<int> matchesSparkline;
  final List<int> viewsSparkline;

  const VenueStats({
    required this.joinedCount,
    required this.matchesCount,
    required this.viewsCount,
    required this.shareCode,
    required this.joinedSparkline,
    required this.matchesSparkline,
    required this.viewsSparkline,
  });

  factory VenueStats.fromJson(Map<String, dynamic> json) {
    List<int> parseIntList(dynamic v) {
      if (v is List) return v.map((e) => (e as num).toInt()).toList();
      return [];
    }

    return VenueStats(
      joinedCount: (json['joinedCount'] as num).toInt(),
      matchesCount: (json['matchesCount'] as num).toInt(),
      viewsCount: (json['viewsCount'] as num).toInt(),
      shareCode: json['shareCode'] as String? ?? '',
      joinedSparkline: parseIntList(json['joinedSparkline']),
      matchesSparkline: parseIntList(json['matchesSparkline']),
      viewsSparkline: parseIntList(json['viewsSparkline']),
    );
  }
}
