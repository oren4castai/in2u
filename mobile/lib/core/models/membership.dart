class Membership {
  final String membershipGuid;
  final String venueGuid;
  final DateTime checkedInAt;

  const Membership({
    required this.membershipGuid,
    required this.venueGuid,
    required this.checkedInAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        membershipGuid: json['membershipGuid'] as String,
        venueGuid: json['venueGuid'] as String,
        checkedInAt: DateTime.parse(json['checkedInAt'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'membershipGuid': membershipGuid,
        'venueGuid': venueGuid,
        'checkedInAt': checkedInAt.toUtc().toIso8601String(),
      };
}
