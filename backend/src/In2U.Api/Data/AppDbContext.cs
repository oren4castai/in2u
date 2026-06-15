using System.Text.Json;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace In2U.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserPhoto> UserPhotos => Set<UserPhoto>();
    public DbSet<Venue> Venues => Set<Venue>();
    public DbSet<VenueMembership> VenueMemberships => Set<VenueMembership>();
    public DbSet<VenueOwner> VenueOwners => Set<VenueOwner>();
    public DbSet<VenueOwnershipClaim> VenueOwnershipClaims => Set<VenueOwnershipClaim>();
    public DbSet<VenuePhoto> VenuePhotos => Set<VenuePhoto>();
    public DbSet<VenueOwnerPhoto> VenueOwnerPhotos => Set<VenueOwnerPhoto>();
    public DbSet<VenueStats> VenueStats => Set<VenueStats>();
    public DbSet<VenueOwnerEventLog> VenueOwnerEventLogs => Set<VenueOwnerEventLog>();
    public DbSet<Swipe> Swipes => Set<Swipe>();
    public DbSet<Match> Matches => Set<Match>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<AmbientProfile> AmbientProfiles => Set<AmbientProfile>();
    public DbSet<VenueAmbientAssignment> VenueAmbientAssignments => Set<VenueAmbientAssignment>();
    public DbSet<AmbientSwipe> AmbientSwipes => Set<AmbientSwipe>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        var stringListConverter = new ValueConverter<List<string>, string>(
            v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null),
            v => string.IsNullOrEmpty(v)
                ? new List<string>()
                : (JsonSerializer.Deserialize<List<string>>(v, (JsonSerializerOptions?)null) ?? new List<string>()));

        var stringListComparer = new ValueComparer<List<string>>(
            (a, b) => (a == null && b == null) || (a != null && b != null && a.SequenceEqual(b)),
            v => v == null ? 0 : v.Aggregate(0, (h, s) => HashCode.Combine(h, s.GetHashCode())),
            v => v == null ? new List<string>() : v.ToList());

        modelBuilder.Entity<User>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.UserGuid).IsUnique();
            b.HasIndex(x => x.Email).IsUnique();
            b.Property(x => x.Email).IsRequired().HasMaxLength(320);
            b.Property(x => x.DisplayName).IsRequired().HasMaxLength(100);
            b.Property(x => x.Bio).HasMaxLength(1000);
            b.Property(x => x.PasswordHash).HasMaxLength(200);
            b.Property(x => x.ExternalId).HasMaxLength(200);
            b.Property(x => x.RefreshTokenHash).HasMaxLength(128);
        });

        modelBuilder.Entity<UserPhoto>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.UserId).IsUnique();
            b.Property(x => x.ContentType).IsRequired().HasMaxLength(50);
        });

        modelBuilder.Entity<Venue>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.VenueGuid).IsUnique();
            b.Property(x => x.Name).IsRequired().HasMaxLength(200);
            b.Property(x => x.Description).HasMaxLength(2000);
            b.HasIndex(x => new { x.Lat, x.Lng });
            b.HasIndex(x => new { x.Type, x.Status });
            b.HasIndex(x => x.OwnerId);
            b.HasIndex(x => x.ShareCode).IsUnique();
            b.Property(x => x.ShareCode).IsRequired().HasMaxLength(8);
            b.Property(x => x.StartsAt).HasConversion(
                v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : (DateTime?)null,
                v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : (DateTime?)null);
        });

        modelBuilder.Entity<VenueOwner>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.VenueOwnerGuid).IsUnique();
            b.Property(x => x.Name).IsRequired().HasMaxLength(200);
            b.HasIndex(x => x.CreateUserId);
        });

        modelBuilder.Entity<VenueOwnershipClaim>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.ClaimGuid).IsUnique();
            b.Property(x => x.Name).IsRequired().HasMaxLength(200);
            b.Property(x => x.PhotoContentType).IsRequired().HasMaxLength(50);
            b.Property(x => x.AdminNote).HasMaxLength(500);
            b.HasIndex(x => x.RequestUserId);
            b.HasIndex(x => x.Status);
        });

        modelBuilder.Entity<VenuePhoto>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.VenueId).IsUnique();
            b.Property(x => x.ContentType).IsRequired().HasMaxLength(50);
        });

        modelBuilder.Entity<VenueOwnerPhoto>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.VenueOwnerId).IsUnique();
            b.Property(x => x.ContentType).IsRequired().HasMaxLength(50);
        });

        modelBuilder.Entity<VenueStats>(b =>
        {
            b.HasKey(x => x.VenueId);
        });

        // VenueOwnerEventLog
        modelBuilder.Entity<VenueOwnerEventLog>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasMaxLength(200);
            e.Property(x => x.Description).HasMaxLength(2000);
            e.Property(x => x.EventType).HasMaxLength(20);
            e.Property(x => x.CreateUserName).HasMaxLength(100);
            e.HasIndex(x => x.VenueOwnerId);
            e.HasIndex(x => x.ClosedAt);
        });

        modelBuilder.Entity<VenueMembership>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.MembershipGuid).IsUnique();
            b.HasIndex(x => new { x.VenueId, x.UserId });
            // At most one membership per user (hard-delete on checkout means no stale rows).
            b.HasIndex(x => x.UserId)
                .IsUnique()
                .HasDatabaseName("IX_VenueMemberships_UserId_Unique");
        });

        modelBuilder.Entity<Swipe>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => new { x.FromUserId, x.ToUserId, x.VenueId }).IsUnique();
            b.HasIndex(x => new { x.VenueId, x.FromUserId });
            b.HasIndex(x => new { x.FromUserId, x.VenueId }); // For loading swiped IDs
            b.HasIndex(x => new { x.ToUserId, x.Direction });
        });

        modelBuilder.Entity<Match>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.MatchGuid).IsUnique();
            b.HasIndex(x => new { x.VenueId, x.UserAId, x.UserBId }).IsUnique();
            b.HasIndex(x => new { x.UserAId, x.EndedAt });
            b.HasIndex(x => new { x.UserBId, x.EndedAt });
            b.HasIndex(x => new { x.VenueId, x.EndedAt });
        });

        modelBuilder.Entity<ChatMessage>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.MessageGuid).IsUnique();
            b.Property(x => x.Body).IsRequired().HasColumnType("text");
            b.Property(x => x.ClientMsgId).HasMaxLength(100);
            b.HasIndex(x => new { x.MatchId, x.SentAt });
            b.HasIndex(x => new { x.MatchId, x.ClientMsgId })
                .IsUnique()
                .HasFilter("\"ClientMsgId\" IS NOT NULL");
        });

        modelBuilder.Entity<AmbientProfile>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.AmbientProfileGuid).IsUnique();
            b.Property(x => x.DisplayName).IsRequired().HasMaxLength(60);
            b.Property(x => x.PictureUrl).IsRequired().HasMaxLength(500);
            b.Property(x => x.Gender).HasMaxLength(40);
            b.Property(x => x.AgeRange).HasMaxLength(20);
            b.Property(x => x.StyleTags)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            b.Property(x => x.StyleTags).HasColumnType("jsonb");
            b.HasIndex(x => x.Active);
        });

        modelBuilder.Entity<VenueAmbientAssignment>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.AssignmentGuid).IsUnique();
            b.HasOne(x => x.Venue)
                .WithMany()
                .HasForeignKey(x => x.VenueId)
                .OnDelete(DeleteBehavior.Restrict);
            b.HasOne(x => x.AmbientProfile)
                .WithMany()
                .HasForeignKey(x => x.AmbientProfileId)
                .OnDelete(DeleteBehavior.Restrict);
            b.HasIndex(x => new { x.VenueId, x.Active });
            // Partial unique: only one Active assignment per (VenueId, AmbientProfileId).
            b.HasIndex(x => new { x.VenueId, x.AmbientProfileId })
                .IsUnique()
                .HasFilter("\"Active\"")
                .HasDatabaseName("IX_VenueAmbientAssignments_Venue_Profile_ActiveUnique");
        });

        modelBuilder.Entity<AmbientSwipe>(b =>
        {
            b.HasKey(x => x.Id);
            b.HasIndex(x => new { x.FromUserId, x.AmbientProfileId, x.VenueId }).IsUnique();
            b.HasIndex(x => new { x.VenueId, x.FromUserId });
        });
    }
}
