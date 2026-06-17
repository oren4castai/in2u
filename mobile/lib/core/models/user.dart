class User {
  final String userGuid;
  final String email;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final int? birthYear;
  final String? gender;
  final String preferGender;
  final String role;

  const User({
    required this.userGuid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.preferGender,
    this.bio,
    this.photoUrl,
    this.birthYear,
    this.gender,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userGuid: json['userGuid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String? ??
          (json['photoUrls'] is List && (json['photoUrls'] as List).isNotEmpty
              ? (json['photoUrls'] as List).first as String?
              : null),
      birthYear: json['birthYear'] as int?,
      gender: json['gender'] as String?,
      preferGender: (json['preferGender'] as String?) ?? 'Everyone',
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'userGuid': userGuid,
        'email': email,
        'displayName': displayName,
        'bio': bio,
        'photoUrl': photoUrl,
        'birthYear': birthYear,
        'gender': gender,
        'preferGender': preferGender,
        'role': role,
      };
}
