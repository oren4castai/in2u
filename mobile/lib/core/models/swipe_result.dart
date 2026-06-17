class SwipeResult {
  final bool matched;
  final String? matchGuid;

  const SwipeResult({required this.matched, this.matchGuid});

  factory SwipeResult.fromJson(Map<String, dynamic> json) {
    return SwipeResult(
      matched: json['matched'] == true,
      matchGuid: json['matchGuid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'matched': matched,
        'matchGuid': matchGuid,
      };
}
