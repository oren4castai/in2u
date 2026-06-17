class OwnerAccumulatedTotals {
  final int joined;
  final int matches;
  final int views;

  const OwnerAccumulatedTotals({
    required this.joined,
    required this.matches,
    required this.views,
  });

  factory OwnerAccumulatedTotals.fromJson(Map<String, dynamic> json) {
    return OwnerAccumulatedTotals(
      joined: (json['joined'] as num?)?.toInt() ?? 0,
      matches: (json['matches'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }
}

class OwnerActiveEvent {
  final String venueGuid;
  final String name;
  final String status;
  final bool isPaused;
  final bool isMine;
  final DateTime? startsAt;
  final int? durationHours;
  final int liveCount;
  final int joinedCount;
  final int matchesCount;
  final int viewsCount;
  final bool hasPhoto;

  const OwnerActiveEvent({
    required this.venueGuid,
    required this.name,
    required this.status,
    required this.isPaused,
    required this.isMine,
    required this.liveCount,
    required this.joinedCount,
    required this.matchesCount,
    required this.viewsCount,
    this.startsAt,
    this.durationHours,
    this.hasPhoto = false,
  });

  factory OwnerActiveEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      return DateTime.parse(s).toUtc();
    }

    return OwnerActiveEvent(
      venueGuid: json['venueGuid'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'Active',
      isPaused: json['isPaused'] as bool? ?? false,
      isMine: json['isMine'] as bool? ?? false,
      startsAt: parseDate(json['startsAt']),
      durationHours: (json['durationHours'] as num?)?.toInt(),
      liveCount: (json['liveCount'] as num?)?.toInt() ?? 0,
      joinedCount: (json['joinedCount'] as num?)?.toInt() ?? 0,
      matchesCount: (json['matchesCount'] as num?)?.toInt() ?? 0,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
    );
  }
}

class OwnerClosedEvent {
  final String venueGuid;
  final String name;
  final DateTime? startsAt;
  final int? durationHours;
  final bool hasPhoto;

  const OwnerClosedEvent({
    required this.venueGuid,
    required this.name,
    this.startsAt,
    this.durationHours,
    this.hasPhoto = false,
  });

  factory OwnerClosedEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      return DateTime.parse(s).toUtc();
    }

    return OwnerClosedEvent(
      venueGuid: json['venueGuid'] as String,
      name: json['name'] as String,
      startsAt: parseDate(json['startsAt']),
      durationHours: (json['durationHours'] as num?)?.toInt(),
      hasPhoto: json['hasPhoto'] as bool? ?? false,
    );
  }
}

class OwnerPastEvent {
  final int id;
  final String name;
  final DateTime closedAt;
  final int joinedCount;
  final int matchesCount;
  final int viewsCount;

  const OwnerPastEvent({
    required this.id,
    required this.name,
    required this.closedAt,
    required this.joinedCount,
    required this.matchesCount,
    required this.viewsCount,
  });

  factory OwnerPastEvent.fromJson(Map<String, dynamic> json) {
    return OwnerPastEvent(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      closedAt: DateTime.parse(json['closedAt'].toString()).toUtc(),
      joinedCount: (json['joinedCount'] as num?)?.toInt() ?? 0,
      matchesCount: (json['matchesCount'] as num?)?.toInt() ?? 0,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OwnerVenueDetail {
  final String ownerGuid;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final int allowPublicEventsCount;
  final bool hasPhoto;
  final OwnerAccumulatedTotals totals;
  final List<OwnerActiveEvent> activeEvents;
  final List<OwnerClosedEvent> closedEvents;
  final List<OwnerPastEvent> pastEvents;

  const OwnerVenueDetail({
    required this.ownerGuid,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.allowPublicEventsCount,
    required this.hasPhoto,
    required this.totals,
    required this.activeEvents,
    required this.closedEvents,
    required this.pastEvents,
  });

  factory OwnerVenueDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        ((v as List<dynamic>?) ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList(growable: false);

    return OwnerVenueDetail(
      ownerGuid: json['ownerGuid'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['radiusM'] as num).toInt(),
      allowPublicEventsCount:
          (json['allowPublicEventsCount'] as num?)?.toInt() ?? 0,
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      totals: OwnerAccumulatedTotals.fromJson(
          json['totals'] as Map<String, dynamic>),
      activeEvents: list(json['activeEvents'], OwnerActiveEvent.fromJson),
      closedEvents: list(json['closedEvents'], OwnerClosedEvent.fromJson),
      pastEvents: list(json['pastEvents'], OwnerPastEvent.fromJson),
    );
  }
}
