class AdminStats {
  final int usersTotal;
  final int usersOnline;
  final int venuesTotal;
  final int eventsTotal;
  final int eventsActive;
  final int publicEventsTotal;
  final int privateEventsTotal;
  final int publicEventsActive;
  final int privateEventsActive;

  const AdminStats({
    required this.usersTotal,
    required this.usersOnline,
    required this.venuesTotal,
    required this.eventsTotal,
    required this.eventsActive,
    required this.publicEventsTotal,
    required this.privateEventsTotal,
    required this.publicEventsActive,
    required this.privateEventsActive,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      usersTotal: json['usersTotal'] as int? ?? 0,
      usersOnline: json['usersOnline'] as int? ?? 0,
      venuesTotal: json['venuesTotal'] as int? ?? 0,
      eventsTotal: json['eventsTotal'] as int? ?? 0,
      eventsActive: json['eventsActive'] as int? ?? 0,
      publicEventsTotal: json['publicEventsTotal'] as int? ?? 0,
      privateEventsTotal: json['privateEventsTotal'] as int? ?? 0,
      publicEventsActive: json['publicEventsActive'] as int? ?? 0,
      privateEventsActive: json['privateEventsActive'] as int? ?? 0,
    );
  }
}
