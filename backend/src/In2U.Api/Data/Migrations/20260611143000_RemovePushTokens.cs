using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace In2U.Api.Data.Migrations;

public partial class RemovePushTokens : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "PushTokens");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "PushTokens",
            columns: table => new
            {
                Id = table.Column<long>(type: "bigint", nullable: false)
                    .Annotation("Npgsql:ValueGenerationStrategy", Npgsql.EntityFrameworkCore.PostgreSQL.Metadata.NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
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

        migrationBuilder.CreateIndex(
            name: "IX_PushTokens_Token",
            table: "PushTokens",
            column: "Token",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_PushTokens_UserId",
            table: "PushTokens",
            column: "UserId");
    }
}
