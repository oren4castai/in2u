class FeedItem {
  final String userGuid;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final int? birthYear;
  final String? gender;
  final String kind;
  final int? blur;
  final List<String>? styleTags;

  const FeedItem({
    required this.userGuid,
    required this.displayName,
    this.bio,
    this.photoUrl,
    this.birthYear,
    this.gender,
    this.kind = 'user',
    this.blur,
    this.styleTags,
  });

  bool get isAmbient => kind == 'ambient';

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['styleTags'];
    final tags =
        rawTags is List ? rawTags.map((e) => e.toString()).toList() : null;
    return FeedItem(
      userGuid: json['userGuid'].toString(),
      displayName: json['displayName'].toString(),
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      birthYear: (json['birthYear'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      kind: (json['kind'] as String?) ?? 'user',
      blur: (json['blur'] as num?)?.toInt(),
      styleTags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'userGuid': userGuid,
        'displayName': displayName,
        'bio': bio,
        'photoUrl': photoUrl,
        'birthYear': birthYear,
        'gender': gender,
        'kind': kind,
        'blur': blur,
        'styleTags': styleTags,
      };
}
