class AdminClaim {
  final String claimGuid;
  final String name;
  final String contactName;
  final String contactPhone;
  final String status;
  final String? adminNote;
  final DateTime createdAt;

  const AdminClaim({
    required this.claimGuid,
    required this.name,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    required this.adminNote,
    required this.createdAt,
  });

  factory AdminClaim.fromJson(Map<String, dynamic> json) {
    try {
      return AdminClaim(
        claimGuid: (json['claimGuid'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        contactName: (json['contactName'] ?? '') as String,
        contactPhone: (json['contactPhone'] ?? '') as String,
        status: (json['status'] ?? '') as String,
        adminNote: json['adminNote'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } catch (_) {
      return AdminClaim(
        claimGuid: '',
        name: '',
        contactName: '',
        contactPhone: '',
        status: '',
        adminNote: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
  }
}
