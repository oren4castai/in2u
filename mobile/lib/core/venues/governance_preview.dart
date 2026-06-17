class GovernancePreview {
  final bool governed;
  final String? ownerName;
  final bool privateAllowed;
  final int? publicSlotsRemaining;

  const GovernancePreview({
    required this.governed,
    required this.ownerName,
    required this.privateAllowed,
    required this.publicSlotsRemaining,
  });

  factory GovernancePreview.fromJson(Map<String, dynamic> json) {
    return GovernancePreview(
      governed: json['governed'] as bool? ?? false,
      ownerName: json['ownerName'] as String?,
      privateAllowed: json['privateAllowed'] as bool? ?? true,
      publicSlotsRemaining: json['publicSlotsRemaining'] as int?,
    );
  }
}
