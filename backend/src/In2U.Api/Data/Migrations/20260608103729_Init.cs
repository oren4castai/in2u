using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace In2U.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class Init : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AmbientProfiles",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    AmbientProfileGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    PictureUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Gender = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    StyleTags = table.Column<string>(type: "jsonb", nullable: false),
                    AgeRange = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    BlurLevel = table.Column<int>(type: "integer", nullable: false),
                    Active = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AmbientProfiles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AmbientSwipes",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    FromUserId = table.Column<long>(type: "bigint", nullable: false),
                    AmbientProfileId = table.Column<long>(type: "bigint", nullable: false),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    Direction = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AmbientSwipes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ChatMessages",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    MessageGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    MatchId = table.Column<long>(type: "bigint", nullable: false),
                    FromUserId = table.Column<long>(type: "bigint", nullable: false),
                    Body = table.Column<string>(type: "text", nullable: false),
                    SentAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReadAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ClientMsgId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatMessages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Matches",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    MatchGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    UserAId = table.Column<long>(type: "bigint", nullable: false),
                    UserBId = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    EndedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    EndReason = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Matches", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PushTokens",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<long>(type: "bigint", nullable: false),
                    Token = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Platform = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastUsedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PushTokens", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Swipes",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    FromUserId = table.Column<long>(type: "bigint", nullable: false),
                    ToUserId = table.Column<long>(type: "bigint", nullable: false),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    Direction = table.Column<int>(type: "integer", nullable: false),
                    TargetKind = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Swipes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserPhotos",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserId = table.Column<long>(type: "bigint", nullable: false),
                    Data = table.Column<byte[]>(type: "bytea", nullable: false),
                    ContentType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserPhotos", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    UserGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    PasswordHash = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    AuthProvider = table.Column<int>(type: "integer", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    DisplayName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Bio = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    HasPhoto = table.Column<bool>(type: "boolean", nullable: false),
                    BirthYear = table.Column<int>(type: "integer", nullable: true),
                    Gender = table.Column<int>(type: "integer", nullable: true),
                    PreferGender = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastSeenAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false),
                    Role = table.Column<int>(type: "integer", nullable: false),
                    RefreshTokenHash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    RefreshTokenExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueMemberships",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    MembershipGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<long>(type: "bigint", nullable: false),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    CheckedInAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastLocationAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastLat = table.Column<double>(type: "double precision", nullable: false),
                    LastLng = table.Column<double>(type: "double precision", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueMemberships", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueOwnerEventLogs",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    VenueOwnerId = table.Column<long>(type: "bigint", nullable: false),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    StartsAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DurationHours = table.Column<int>(type: "integer", nullable: true),
                    EventType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    JoinedCount = table.Column<int>(type: "integer", nullable: false),
                    MatchesCount = table.Column<int>(type: "integer", nullable: false),
                    ViewsCount = table.Column<long>(type: "bigint", nullable: false),
                    CreateUserName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ClosedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueOwnerEventLogs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueOwnerPhotos",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    VenueOwnerId = table.Column<long>(type: "bigint", nullable: false),
                    Data = table.Column<byte[]>(type: "bytea", nullable: false),
                    ContentType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueOwnerPhotos", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueOwners",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    VenueOwnerGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    CreateUserId = table.Column<long>(type: "bigint", nullable: false),
                    Lat = table.Column<double>(type: "double precision", nullable: false),
                    Lng = table.Column<double>(type: "double precision", nullable: false),
                    RadiusM = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    AllowPublicEventsCount = table.Column<int>(type: "integer", nullable: false),
                    HasPhoto = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueOwners", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueOwnershipClaims",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ClaimGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestUserId = table.Column<long>(type: "bigint", nullable: false),
                    Lat = table.Column<double>(type: "double precision", nullable: false),
                    Lng = table.Column<double>(type: "double precision", nullable: false),
                    RadiusM = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    PhotoData = table.Column<byte[]>(type: "bytea", nullable: false),
                    PhotoContentType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    AdminNote = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedVenueOwnerId = table.Column<long>(type: "bigint", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueOwnershipClaims", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenuePhotos",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    Data = table.Column<byte[]>(type: "bytea", nullable: false),
                    ContentType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenuePhotos", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueStats",
                columns: table => new
                {
                    VenueId = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    JoinedCount = table.Column<int>(type: "integer", nullable: false),
                    MatchesCount = table.Column<int>(type: "integer", nullable: false),
                    ViewsCount = table.Column<long>(type: "bigint", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueStats", x => x.VenueId);
                });

            migrationBuilder.CreateTable(
                name: "Venues",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    VenueGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    Type = table.Column<int>(type: "integer", nullable: false),
                    EventType = table.Column<int>(type: "integer", nullable: false),
                    Lat = table.Column<double>(type: "double precision", nullable: false),
                    Lng = table.Column<double>(type: "double precision", nullable: false),
                    RadiusM = table.Column<int>(type: "integer", nullable: false),
                    StartsAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DurationHours = table.Column<int>(type: "integer", nullable: true),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    Category = table.Column<int>(type: "integer", nullable: true),
                    CreateUserId = table.Column<long>(type: "bigint", nullable: false),
                    OwnerId = table.Column<long>(type: "bigint", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    HasPhoto = table.Column<bool>(type: "boolean", nullable: false),
                    IsPaused = table.Column<bool>(type: "boolean", nullable: false),
                    ShareCode = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Venues", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VenueAmbientAssignments",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    AssignmentGuid = table.Column<Guid>(type: "uuid", nullable: false),
                    VenueId = table.Column<long>(type: "bigint", nullable: false),
                    AmbientProfileId = table.Column<long>(type: "bigint", nullable: false),
                    AssignedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VenueAmbientAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VenueAmbientAssignments_AmbientProfiles_AmbientProfileId",
                        column: x => x.AmbientProfileId,
                        principalTable: "AmbientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_VenueAmbientAssignments_Venues_VenueId",
                        column: x => x.VenueId,
                        principalTable: "Venues",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AmbientProfiles_Active",
                table: "AmbientProfiles",
                column: "Active");

            migrationBuilder.CreateIndex(
                name: "IX_AmbientProfiles_AmbientProfileGuid",
                table: "AmbientProfiles",
                column: "AmbientProfileGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AmbientSwipes_FromUserId_AmbientProfileId_VenueId",
                table: "AmbientSwipes",
                columns: new[] { "FromUserId", "AmbientProfileId", "VenueId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AmbientSwipes_VenueId_FromUserId",
                table: "AmbientSwipes",
                columns: new[] { "VenueId", "FromUserId" });

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_MatchId_ClientMsgId",
                table: "ChatMessages",
                columns: new[] { "MatchId", "ClientMsgId" },
                unique: true,
                filter: "\"ClientMsgId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_MatchId_SentAt",
                table: "ChatMessages",
                columns: new[] { "MatchId", "SentAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_MessageGuid",
                table: "ChatMessages",
                column: "MessageGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Matches_MatchGuid",
                table: "Matches",
                column: "MatchGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Matches_UserAId_EndedAt",
                table: "Matches",
                columns: new[] { "UserAId", "EndedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Matches_UserBId_EndedAt",
                table: "Matches",
                columns: new[] { "UserBId", "EndedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Matches_VenueId_EndedAt",
                table: "Matches",
                columns: new[] { "VenueId", "EndedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Matches_VenueId_UserAId_UserBId",
                table: "Matches",
                columns: new[] { "VenueId", "UserAId", "UserBId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PushTokens_Token",
                table: "PushTokens",
                column: "Token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PushTokens_UserId",
                table: "PushTokens",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Swipes_FromUserId_ToUserId_VenueId",
                table: "Swipes",
                columns: new[] { "FromUserId", "ToUserId", "VenueId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Swipes_FromUserId_VenueId",
                table: "Swipes",
                columns: new[] { "FromUserId", "VenueId" });

            migrationBuilder.CreateIndex(
                name: "IX_Swipes_ToUserId_Direction",
                table: "Swipes",
                columns: new[] { "ToUserId", "Direction" });

            migrationBuilder.CreateIndex(
                name: "IX_Swipes_VenueId_FromUserId",
                table: "Swipes",
                columns: new[] { "VenueId", "FromUserId" });

            migrationBuilder.CreateIndex(
                name: "IX_UserPhotos_UserId",
                table: "UserPhotos",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                table: "Users",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_UserGuid",
                table: "Users",
                column: "UserGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueAmbientAssignments_AmbientProfileId",
                table: "VenueAmbientAssignments",
                column: "AmbientProfileId");

            migrationBuilder.CreateIndex(
                name: "IX_VenueAmbientAssignments_AssignmentGuid",
                table: "VenueAmbientAssignments",
                column: "AssignmentGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueAmbientAssignments_VenueId_Active",
                table: "VenueAmbientAssignments",
                columns: new[] { "VenueId", "Active" });

            migrationBuilder.CreateIndex(
                name: "IX_VenueAmbientAssignments_Venue_Profile_ActiveUnique",
                table: "VenueAmbientAssignments",
                columns: new[] { "VenueId", "AmbientProfileId" },
                unique: true,
                filter: "\"Active\"");

            migrationBuilder.CreateIndex(
                name: "IX_VenueMemberships_MembershipGuid",
                table: "VenueMemberships",
                column: "MembershipGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueMemberships_UserId_Unique",
                table: "VenueMemberships",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueMemberships_VenueId_UserId",
                table: "VenueMemberships",
                columns: new[] { "VenueId", "UserId" });

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwnerEventLogs_ClosedAt",
                table: "VenueOwnerEventLogs",
                column: "ClosedAt");

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwnerEventLogs_VenueOwnerId",
                table: "VenueOwnerEventLogs",
                column: "VenueOwnerId");

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwnerPhotos_VenueOwnerId",
                table: "VenueOwnerPhotos",
                column: "VenueOwnerId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwners_CreateUserId",
                table: "VenueOwners",
                column: "CreateUserId");

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwners_VenueOwnerGuid",
                table: "VenueOwners",
                column: "VenueOwnerGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwnershipClaims_ClaimGuid",
                table: "VenueOwnershipClaims",
                column: "ClaimGuid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwnershipClaims_RequestUserId",
                table: "VenueOwnershipClaims",
                column: "RequestUserId");

            migrationBuilder.CreateIndex(
                name: "IX_VenueOwnershipClaims_Status",
                table: "VenueOwnershipClaims",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_VenuePhotos_VenueId",
                table: "VenuePhotos",
                column: "VenueId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Venues_Lat_Lng",
                table: "Venues",
                columns: new[] { "Lat", "Lng" });

            migrationBuilder.CreateIndex(
                name: "IX_Venues_OwnerId",
                table: "Venues",
                column: "OwnerId");

            migrationBuilder.CreateIndex(
                name: "IX_Venues_ShareCode",
                table: "Venues",
                column: "ShareCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Venues_Type_Status",
                table: "Venues",
                columns: new[] { "Type", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Venues_VenueGuid",
                table: "Venues",
                column: "VenueGuid",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AmbientSwipes");

            migrationBuilder.DropTable(
                name: "ChatMessages");

            migrationBuilder.DropTable(
                name: "Matches");

            migrationBuilder.DropTable(
                name: "PushTokens");

            migrationBuilder.DropTable(
                name: "Swipes");

            migrationBuilder.DropTable(
                name: "UserPhotos");

            migrationBuilder.DropTable(
                name: "Users");

            migrationBuilder.DropTable(
                name: "VenueAmbientAssignments");

            migrationBuilder.DropTable(
                name: "VenueMemberships");

            migrationBuilder.DropTable(
                name: "VenueOwnerEventLogs");

            migrationBuilder.DropTable(
                name: "VenueOwnerPhotos");

            migrationBuilder.DropTable(
                name: "VenueOwners");

            migrationBuilder.DropTable(
                name: "VenueOwnershipClaims");

            migrationBuilder.DropTable(
                name: "VenuePhotos");

            migrationBuilder.DropTable(
                name: "VenueStats");

            migrationBuilder.DropTable(
                name: "AmbientProfiles");

            migrationBuilder.DropTable(
                name: "Venues");
        }
    }
}
