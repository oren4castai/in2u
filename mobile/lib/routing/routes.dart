abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const admin = '/admin';
  static const discover = '/discover';
  static const me = '/me';
  static const venueDetails = '/venue/:venueGuid';
  static String venueDetailsFor(String guid) => '/venue/$guid';
  static const swipe = '/swipe';
  static const matches = '/matches';
  static const chat = '/matches/:matchGuid/chat';
  static String chatFor(String matchGuid) => '/matches/$matchGuid/chat';

  static const myEvents = '/events';
  static const createEvent = '/events/new';
  static const eventManage = '/events/:venueGuid/manage';
  static String eventManageFor(String guid) => '/events/$guid/manage';
  static const eventEdit = '/events/:venueGuid/edit';
  static String eventEditFor(String guid) => '/events/$guid/edit';

  static const venueDashboard = '/owner/venues';
  static const claimVenue = '/owner/claim';
  static const ownerVenueDetail = '/owner/venues/:ownerGuid';
  static String ownerVenueDetailFor(String ownerGuid) =>
      '/owner/venues/$ownerGuid';
  static const ownerCreateEvent = '/owner/venues/:ownerGuid/events/new';
  static String ownerCreateEventFor(String ownerGuid) =>
      '/owner/venues/$ownerGuid/events/new';

  static String venueDetailsWithCode(String guid) =>
      '/venue/$guid?fromCode=true';
}
