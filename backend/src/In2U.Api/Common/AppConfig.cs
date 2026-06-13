namespace In2U.Api.Common;

public sealed class JwtOptions
{
    public string Issuer { get; set; } = "in2u";
    public string Audience { get; set; } = "in2u-app";
    public string SigningKey { get; set; } = string.Empty;
    public int AccessMinutes { get; set; } = 30;
    public int RefreshDays { get; set; } = 30;
}

public sealed class AdminOptions
{
    public string? SeedEmail { get; set; }
    public string? SeedPassword { get; set; }
}

public sealed class GeoOptions
{
    public int MeetupRadiusM { get; set; } = 500;
    public int GlobalInactiveTimeoutMinutes { get; set; } = 15;
}

public sealed class OwnerOptions
{
    public int ConflictThresholdM { get; set; } = 25;
    public int DefaultAllowPublicEventsCount { get; set; } = 5;
    public int OwnerMaxActiveEvents { get; set; } = 3;
}

public sealed class CleanupOptions
{
    public int SweepIntervalS { get; set; } = 30;
}

public sealed class SessionOptions
{
    public int ResumeWindowMinutes { get; set; } = 60;
}

public sealed class AmbientOptions
{
    public int AssignmentTtlMinutes { get; set; } = 10;
    public int RotationIntervalSeconds { get; set; } = 60;
    public int MinPerVenue { get; set; } = 2;
    public int MaxPerVenue { get; set; } = 8;

    // Density-based ambient ratios in the SWIPE FEED:
    // <= 2 real candidates -> ambient fills most of the feed;
    // 3..14 real candidates -> moderate ambient mix;
    // >= 15 real candidates -> small ambient accent.
    public double LowDensityAmbientRatio { get; set; } = 0.80;
    public double MedDensityAmbientRatio { get; set; } = 0.30;
    public double HighDensityAmbientRatio { get; set; } = 0.10;

    // Venue preview (discover card + details).
    public int PreviewAvatarCount { get; set; } = 4;

    // Dev-only seeding switch.
    public bool SeedDefaults { get; set; } = false;
}
