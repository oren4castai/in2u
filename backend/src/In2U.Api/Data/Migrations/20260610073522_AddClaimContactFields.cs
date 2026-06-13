using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace In2U.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddClaimContactFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ContactName",
                table: "VenueOwnershipClaims",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ContactPhone",
                table: "VenueOwnershipClaims",
                type: "text",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ContactName",
                table: "VenueOwnershipClaims");

            migrationBuilder.DropColumn(
                name: "ContactPhone",
                table: "VenueOwnershipClaims");
        }
    }
}
