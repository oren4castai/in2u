using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Entities;
using In2U.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace In2U.Api.Setup;

public static class DbSetup
{
    public static IServiceCollection AddAppDb(this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default");
        services.AddDbContext<AppDbContext>(opts => opts.UseNpgsql(cs));
        return services;
    }

    public static async Task EnsureDatabaseAsync(this IApplicationBuilder app)
    {
        using var scope = app.ApplicationServices.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<AppDbContext>();
        var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger("DbSetup");

        var applied = (await db.Database.GetAppliedMigrationsAsync()).ToList();
        var pending = (await db.Database.GetPendingMigrationsAsync()).ToList();

        if (pending.Any() || applied.Any())
        {
            logger.LogInformation("Applying EF Core migrations (applied={Applied}, pending={Pending}).",
                applied.Count, pending.Count);
            await db.Database.MigrateAsync();
        }
        else
        {
            logger.LogWarning("No EF Core migrations found. Falling back to EnsureCreated(). " +
                              "Create initial migration with: dotnet ef migrations add Init -o Data/Migrations");
            await db.Database.EnsureCreatedAsync();
        }

        // Clear transient session data from previous run
        await ClearSessionDataAsync(db, logger);

        var adminOpts = sp.GetRequiredService<IOptions<AdminOptions>>().Value;
        await SeedAdminAsync(db, adminOpts, logger);
        await SeedGlobalVenueAsync(db, logger);

        var ambientOpts = sp.GetRequiredService<IOptions<AmbientOptions>>().Value;
        if (ambientOpts.SeedDefaults)
        {
            var ambientSvc = sp.GetRequiredService<IAmbientProfileService>();
            await ambientSvc.SeedDefaultsIfEmptyAsync();
        }
    }

    private static async Task SeedAdminAsync(AppDbContext db, AdminOptions admin, ILogger logger)
    {
        if (string.IsNullOrWhiteSpace(admin.SeedEmail) || string.IsNullOrWhiteSpace(admin.SeedPassword))
            return;

        var hasAdmin = await db.Users.AnyAsync(u => u.Role == UserRole.Admin);
        if (hasAdmin) return;

        var email = admin.SeedEmail.Trim().ToLowerInvariant();
        var user = new User
        {
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(admin.SeedPassword),
            AuthProvider = AuthProvider.Email,
            DisplayName = "Admin",
            CreatedAt = DateTime.UtcNow,
            LastSeenAt = DateTime.UtcNow,
            Role = UserRole.Admin,
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        logger.LogInformation("Seeded admin user {Email}.", email);
    }

    private static async Task ClearSessionDataAsync(AppDbContext db, ILogger logger)
    {
        logger.LogInformation("Clearing session data from previous run...");

        // Clear in order to respect FK constraints
        var messagesDeleted = await db.ChatMessages.ExecuteDeleteAsync();
        var matchesDeleted = await db.Matches.ExecuteDeleteAsync();
        var swipesDeleted = await db.Swipes.ExecuteDeleteAsync();
        var ambientSwipesDeleted = await db.AmbientSwipes.ExecuteDeleteAsync();
        var ambientAssignmentsDeleted = await db.VenueAmbientAssignments.ExecuteDeleteAsync();
        var membershipsDeleted = await db.VenueMemberships.ExecuteDeleteAsync();

        logger.LogInformation(
            "Cleared session data: {Messages} messages, {Matches} matches, {Swipes} swipes, {AmbientSwipes} ambient swipes, {AmbientAssignments} ambient assignments, {Memberships} memberships",
            messagesDeleted, matchesDeleted, swipesDeleted, ambientSwipesDeleted, ambientAssignmentsDeleted, membershipsDeleted);
    }

    private static async Task SeedGlobalVenueAsync(AppDbContext db, ILogger logger)
    {
        var hasGlobal = await db.Venues.AnyAsync(v => v.Type == VenueType.Global);
        if (hasGlobal) return;

        var admin = await db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Admin);
        if (admin is null)
        {
            logger.LogWarning("No admin user found; skipping global venue seed.");
            return;
        }

        var venue = new Venue
        {
            Name = "Global",
            Type = VenueType.Global,
            EventType = VenueEventType.Public,
            Lat = 0,
            Lng = 0,
            RadiusM = 0,
            Status = VenueStatus.Active,
            HasPhoto = true, // Uses default Earth image
            CreateUserId = admin.Id,
            CreatedAt = DateTime.UtcNow,
            ShareCode = new string(
                new byte[8].Select(_ => { var b = new byte[1]; System.Security.Cryptography.RandomNumberGenerator.Fill(b); return (char)('A' + b[0] % 26); }).ToArray()),
        };
        db.Venues.Add(venue);
        await db.SaveChangesAsync();
        db.VenueStats.Add(new VenueStats { VenueId = venue.Id });
        await db.SaveChangesAsync();
        logger.LogInformation("Seeded default global venue.");
    }
}
