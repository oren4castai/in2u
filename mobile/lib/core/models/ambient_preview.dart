class AmbientPreview {
  final String ambientProfileGuid;
  final String pictureUrl;
  final int blurLevel; // 0 = low, 1 = high
  final String displayName;

  const AmbientPreview({
    required this.ambientProfileGuid,
    required this.pictureUrl,
    required this.blurLevel,
    required this.displayName,
  });

  factory AmbientPreview.fromJson(Map<String, dynamic> json) {
    return AmbientPreview(
      ambientProfileGuid: json['ambientProfileGuid'].toString(),
      pictureUrl: (json['pictureUrl'] ?? '').toString(),
      blurLevel: (json['blurLevel'] as num?)?.toInt() ?? 1,
      displayName: (json['displayName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ambientProfileGuid': ambientProfileGuid,
        'pictureUrl': pictureUrl,
        'blurLevel': blurLevel,
        'displayName': displayName,
      };
}
