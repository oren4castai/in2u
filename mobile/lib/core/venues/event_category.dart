enum EventCategory {
  party,
  music,
  sports,
  food,
  networking,
  fitness,
  art,
  gaming,
  outdoor,
  dating,
  community,
  festival,
  workshop,
  cinema,
  other;

  String get displayName {
    switch (this) {
      case EventCategory.party:
        return 'Party';
      case EventCategory.music:
        return 'Music';
      case EventCategory.sports:
        return 'Sports';
      case EventCategory.food:
        return 'Food';
      case EventCategory.networking:
        return 'Networking';
      case EventCategory.fitness:
        return 'Fitness';
      case EventCategory.art:
        return 'Art';
      case EventCategory.gaming:
        return 'Gaming';
      case EventCategory.outdoor:
        return 'Outdoor';
      case EventCategory.dating:
        return 'Dating';
      case EventCategory.community:
        return 'Community';
      case EventCategory.festival:
        return 'Festival';
      case EventCategory.workshop:
        return 'Workshop';
      case EventCategory.cinema:
        return 'Cinema';
      case EventCategory.other:
        return 'Other';
    }
  }

  String get apiValue => name[0].toUpperCase() + name.substring(1);

  static EventCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return EventCategory.values.firstWhere(
        (e) => e.apiValue == value,
        orElse: () => EventCategory.other,
      );
    } catch (_) {
      return EventCategory.other;
    }
  }
}
