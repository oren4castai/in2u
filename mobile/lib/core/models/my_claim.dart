class MyClaim {
  final String claimGuid;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final String status;
  final String? adminNote;
  final DateTime createdAt;

  const MyClaim({
    required this.claimGuid,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.status,
    required this.createdAt,
    this.adminNote,
  });

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';

  factory MyClaim.fromJson(Map<String, dynamic> json) {
    return MyClaim(
      claimGuid: json['claimGuid'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['radiusM'] as num).toInt(),
      status: json['status'] as String,
      adminNote: json['adminNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'].toString()).toUtc(),
    );
  }
}
