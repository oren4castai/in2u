class MatchPeer {
  final String userGuid;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final int? birthYear;
  final String? gender;

  const MatchPeer({
    required this.userGuid,
    required this.displayName,
    this.bio,
    this.photoUrl,
    this.birthYear,
    this.gender,
  });

  factory MatchPeer.fromJson(Map<String, dynamic> json) {
    return MatchPeer(
      userGuid: json['userGuid'].toString(),
      displayName: json['displayName'].toString(),
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
      birthYear: (json['birthYear'] as num?)?.toInt(),
      gender: json['gender'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userGuid': userGuid,
        'displayName': displayName,
        'bio': bio,
        'photoUrl': photoUrl,
        'birthYear': birthYear,
        'gender': gender,
      };
}

class Match {
  final String matchGuid;
  final String venueGuid;
  final String venueName;
  final DateTime createdAt;
  final MatchPeer peer;

  const Match({
    required this.matchGuid,
    required this.venueGuid,
    required this.venueName,
    required this.createdAt,
    required this.peer,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      matchGuid: json['matchGuid'].toString(),
      venueGuid: json['venueGuid'].toString(),
      venueName: json['venueName'].toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      peer: MatchPeer.fromJson(
        (json['peer'] as Map).map((k, v) => MapEntry(k.toString(), v)),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'matchGuid': matchGuid,
        'venueGuid': venueGuid,
        'venueName': venueName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'peer': peer.toJson(),
      };
}
