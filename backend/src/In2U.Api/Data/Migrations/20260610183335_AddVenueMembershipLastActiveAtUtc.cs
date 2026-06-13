using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace In2U.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddVenueMembershipLastActiveAtUtc : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "LastActiveAtUtc",
                table: "VenueMemberships",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.Sql(
                "UPDATE \"VenueMemberships\" SET \"LastActiveAtUtc\" = \"CheckedInAt\" WHERE \"LastActiveAtUtc\" IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LastActiveAtUtc",
                table: "VenueMemberships");
        }
    }
}
