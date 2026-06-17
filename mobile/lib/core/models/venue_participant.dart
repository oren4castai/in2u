class VenueParticipant {
  final String userGuid;
  final String displayName;
  final bool hasPhoto;
  final int? birthYear;
  final DateTime checkedInAt;

  const VenueParticipant({
    required this.userGuid,
    required this.displayName,
    required this.hasPhoto,
    required this.checkedInAt,
    this.birthYear,
  });

  int? get age {
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear!;
  }

  factory VenueParticipant.fromJson(Map<String, dynamic> json) {
    return VenueParticipant(
      userGuid: json['userGuid'] as String,
      displayName: json['displayName'] as String,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      birthYear: json['birthYear'] as int?,
      checkedInAt: DateTime.parse(json['checkedInAt'] as String).toUtc(),
    );
  }
}
