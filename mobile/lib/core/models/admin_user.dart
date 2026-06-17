class AdminUser {
  final String userGuid;
  final String displayName;
  final String email;
  final String role;
  final bool isVenueOwner;
  final bool hasActiveEvent;
  final bool hasPhoto;
  final DateTime lastSeenAt;

  const AdminUser({
    required this.userGuid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isVenueOwner,
    required this.hasActiveEvent,
    required this.hasPhoto,
    required this.lastSeenAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      userGuid: json['userGuid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isVenueOwner: json['isVenueOwner'] as bool? ?? false,
      hasActiveEvent: json['hasActiveEvent'] as bool? ?? false,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      lastSeenAt: DateTime.tryParse(json['lastSeenAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
