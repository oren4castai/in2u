import '../models/chat_message.dart';
import '../models/match.dart';

sealed class HubEvent {
  const HubEvent();
}

class VenueJoinedEvent extends HubEvent {
  final String venueGuid;
  final String membershipGuid;
  const VenueJoinedEvent(this.venueGuid, this.membershipGuid);
}

class PresenceUpdatedEvent extends HubEvent {
  final String venueGuid;
  final String densityBucket;
  const PresenceUpdatedEvent(this.venueGuid, this.densityBucket);
}

class VenueLeftEvent extends HubEvent {
  final String venueGuid;
  final String reason;
  const VenueLeftEvent(this.venueGuid, this.reason);
}

class ForceCheckoutEvent extends HubEvent {
  final String venueGuid;
  final String reason;
  const ForceCheckoutEvent(this.venueGuid, this.reason);
}

class ReconnectedEvent extends HubEvent {
  const ReconnectedEvent();
}

class MatchCreatedEvent extends HubEvent {
  final Match match;
  const MatchCreatedEvent(this.match);
}

class MatchEndedEvent extends HubEvent {
  final String matchGuid;
  final String reason;
  const MatchEndedEvent(this.matchGuid, this.reason);
}

class MessageReceivedEvent extends HubEvent {
  final ChatMessage message;
  const MessageReceivedEvent(this.message);
}

class TypingChangedEvent extends HubEvent {
  final String matchGuid;
  final String fromUserGuid;
  final bool isTyping;
  const TypingChangedEvent(this.matchGuid, this.fromUserGuid, this.isTyping);
}

class MessageReadEvent extends HubEvent {
  final String matchGuid;
  final String messageGuid;
  final DateTime readAt;
  const MessageReadEvent(this.matchGuid, this.messageGuid, this.readAt);
}

class EventListChangedEvent extends HubEvent {
  final String venueGuid;
  final String kind; // "created" | "closed" | "deleted"
  const EventListChangedEvent(this.venueGuid, this.kind);
}

class VenueAnnouncementEvent extends HubEvent {
  final String venueGuid;
  final String title;
  final String body;

  const VenueAnnouncementEvent(this.venueGuid, this.title, this.body);
}
