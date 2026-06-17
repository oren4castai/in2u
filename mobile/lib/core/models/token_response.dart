import 'user.dart';

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final User user;
  final bool resumed;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.user,
    required this.resumed,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessExpiresAt: DateTime.parse(json['accessExpiresAt'] as String),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      resumed: json['resumed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessExpiresAt': accessExpiresAt.toIso8601String(),
        'user': user.toJson(),
        'resumed': resumed,
      };
}
