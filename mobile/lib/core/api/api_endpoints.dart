abstract final class ApiEndpoints {
  static const authEmailRegister = '/auth/email/register';
  static const authEmailLogin = '/auth/email/login';
  static const authOAuthGoogle = '/auth/oauth/google';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const authSessionStart = '/auth/session-start';
  static const me = '/me';

  static const venuesDiscover = '/venues/discover';
  static const venuesMe = '/venues/me';
  static String venueDetails(String guid) => '/venues/$guid';
  static String venueCheckin(String guid) => '/venues/$guid/checkin';
  static String venueLeave(String guid) => '/venues/$guid/leave';
  static String venueLocation(String guid) => '/venues/$guid/location';

  static String venueFeed(String guid) => '/venues/$guid/feed';
  static String venueSwipe(String venueGuid, String toUserGuid) =>
      '/venues/$venueGuid/swipes/$toUserGuid';
  static const matches = '/matches';
  static String matchDelete(String matchGuid) => '/matches/$matchGuid';

  static String matchMessages(String matchGuid) =>
      '/matches/$matchGuid/messages';

  static const mePhoto = '/me/photo';
  static String photo(String userGuid) => '/photos/$userGuid';

  // Events (user-created)
  static const eventsMine = '/events/mine';
  static const eventsCreate = '/events';
  static const eventsGovernance = '/events/governance';
  static String eventPatch(String venueGuid) => '/events/$venueGuid';
  static String eventPhoto(String venueGuid) => '/events/$venueGuid/photo';
  static String eventClose(String venueGuid) => '/events/$venueGuid/close';
  static String venuePhotoServe(String venueGuid) => '/photos/venue/$venueGuid';
  static String ownerPhotoServe(String ownerGuid) => '/photos/owner/$ownerGuid';
  // Venue manage (stats + participants)
  static String venueManageStats(String venueGuid) =>
      '/venues/$venueGuid/manage/stats';
  static String venueManageParticipants(String venueGuid) =>
      '/venues/$venueGuid/manage/participants';
  static String venueManageForceCheckout(
          String venueGuid, String targetUserGuid) =>
      '/venues/$venueGuid/manage/participants/$targetUserGuid';

  // Venue ownership (owner dashboard + claims)
  static const ownerVenues = '/owner/venues';
  static String ownerVenueDetail(String ownerGuid) =>
      '/owner/venues/$ownerGuid';
  static String ownerEventClose(String venueGuid) =>
      '/owner/events/$venueGuid/close';
  static String ownerEventReschedule(String venueGuid) =>
      '/owner/events/$venueGuid/start-at';
  static String ownerEventAnnouncement(String venueGuid) =>
      '/owner/events/$venueGuid/announcement';
  static String ownerEventDelete(String venueGuid) =>
      '/owner/events/$venueGuid';
  static const venueClaims = '/venue-claims';
  static const venueClaimsMine = '/venue-claims/mine';
  static String ownerPastEventDelete(String ownerGuid, int logId) =>
      '/owner/venues/$ownerGuid/past-events/$logId';
  static String ownerVenueDelete(String ownerGuid) =>
      '/owner/venues/$ownerGuid';

  // Admin
  static const adminStats = '/admin/stats';
  static const adminUsers = '/admin/users';
  static String adminUserDelete(String userGuid) => '/admin/users/$userGuid';
  static const adminVenues = '/admin/venues';
  static String adminVenueDelete(String venueGuid) =>
      '/admin/venues/$venueGuid';
  static const adminEvents = '/admin/events';
  static String adminEventDelete(String venueGuid) =>
      '/admin/events/$venueGuid';
  static const adminVenueClaimsAll = '/admin/venue-claims';
  static const adminVenueClaimsPending = '/admin/venue-claims/pending';
  static String adminClaimApprove(String claimGuid) =>
      '/admin/venue-claims/$claimGuid/approve';
  static String adminClaimDelete(String claimGuid) =>
      '/admin/venue-claims/$claimGuid';
}
