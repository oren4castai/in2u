namespace In2U.Api.Entities;

public enum AuthProvider { Email = 0, Google = 1, Apple = 2 }
public enum Gender { Male = 0, Female = 1, Other = 2, Unspecified = 3 }
public enum GenderPreference { Everyone = 0, OnlyMale = 1, OnlyFemale = 2 }
public enum UserRole { User = 0, Admin = 1 }
public enum Platform { Ios = 0, Android = 1 }
public enum VenueType { Event = 0, Global = 1 }
public enum VenueStatus { Draft = 0, Active = 1, Closed = 2 }
public enum SwipeDirection { Left = 0, Right = 1 }
public enum TargetKind { RealUser = 0, Ambient = 1 }
public enum MatchEndReason { Unmatched = 0, UserLeft = 1, VenueClosed = 2 }
public enum AmbientBlurLevel { Low = 0, High = 1 }
public enum VenueEventType { Public = 0, Private = 1 }
public enum ClaimStatus { Pending = 0, Approved = 1, Rejected = 2 }
public enum EventCategory
{
    Party = 1,
    Music = 2,
    Sports = 3,
    Food = 4,
    Networking = 5,
    Fitness = 6,
    Art = 7,
    Gaming = 8,
    Outdoor = 9,
    Dating = 10,
    Community = 11,
    Festival = 12,
    Workshop = 13,
    Cinema = 14,
    Other = 99
}
