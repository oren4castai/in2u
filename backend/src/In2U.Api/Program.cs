using System.Text.Json;
using System.Threading.RateLimiting;
using In2U.Api.BackgroundServices;
using In2U.Api.Common;
using In2U.Api.Hubs;
using In2U.Api.Middleware;
using In2U.Api.Services;
using In2U.Api.Setup;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);

// Options binding.
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
builder.Services.Configure<AdminOptions>(builder.Configuration.GetSection("Admin"));
builder.Services.Configure<GeoOptions>(builder.Configuration.GetSection("Geo"));
builder.Services.Configure<OwnerOptions>(builder.Configuration.GetSection("Owner"));
builder.Services.Configure<CleanupOptions>(builder.Configuration.GetSection("Cleanup"));
builder.Services.Configure<In2U.Api.Common.SessionOptions>(builder.Configuration.GetSection("Session"));
builder.Services.Configure<AmbientOptions>(builder.Configuration.GetSection("Ambient"));

// Startup-validate JwtOptions.SigningKey and ConnectionStrings:Default.
var jwtSection = builder.Configuration.GetSection("Jwt");
var signingKey = jwtSection.GetValue<string>("SigningKey") ?? string.Empty;
if (signingKey.Length < 32)
{
    throw new InvalidOperationException(
        "Jwt:SigningKey must be at least 32 characters. " +
        "Set it via configuration (appsettings, environment variable, or user-secrets).");
}

var defaultConnString = builder.Configuration.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(defaultConnString))
{
    throw new InvalidOperationException("ConnectionStrings:Default must be set.");
}

// Forwarded headers.
builder.Services.Configure<ForwardedHeadersOptions>(opts =>
{
    opts.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    opts.KnownNetworks.Clear();
    opts.KnownProxies.Clear();
});

// CORS dev policy.
builder.Services.AddCors(o => o.AddPolicy("DevOpen", p =>
    p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

// App services.
builder.Services.AddAppDb(builder.Configuration);
builder.Services.AddAppAuth(builder.Configuration);
builder.Services.AddAppSwagger();

builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IAuthService, AuthService>();

// Phase 2: Venues + Presence.
builder.Services.AddSingleton<IUserIdProvider, UserGuidProvider>();
builder.Services.AddSignalR();
builder.Services.AddSingleton<IGeoMembershipTracker, GeoMembershipTracker>();
builder.Services.AddScoped<IPresenceService, PresenceService>();
builder.Services.AddScoped<ILocationValidationService, LocationValidationService>();
builder.Services.AddScoped<IVenueService, VenueService>();
builder.Services.AddScoped<IVenueOwnershipService, VenueOwnershipService>();
builder.Services.AddScoped<IAdminModerationService, AdminModerationService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IMatchService, MatchService>();
builder.Services.AddScoped<ISwipeService, SwipeService>();
builder.Services.AddScoped<IAmbientProfileService, AmbientProfileService>();
builder.Services.AddScoped<ISessionPurgeService, SessionPurgeService>();
builder.Services.AddScoped<IEventResumeService, EventResumeService>();
builder.Services.AddHostedService<CleanupHostedService>();
builder.Services.AddHostedService<AmbientRotationHostedService>();
builder.Services.AddScoped<IPushService, PushService>();

builder.Services
    .AddControllers()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        o.JsonSerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.CamelCase;
    });

builder.Services.AddResponseCaching();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.ContentType = "application/problem+json";
        await ctx.HttpContext.Response.WriteAsJsonAsync(new
        {
            type = "https://tools.ietf.org/html/rfc6585#section-4",
            title = "Too many requests",
            status = 429,
            detail = "Rate limit exceeded. Please slow down.",
        }, ct);
    };

    // IP-based for unauthenticated auth endpoints.
    options.AddPolicy("auth-ip", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));

    static string UserKey(HttpContext ctx) =>
        ctx.User?.FindFirst("sub")?.Value ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    options.AddPolicy("location-user", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: UserKey(httpContext),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 12,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));

    options.AddPolicy("swipes-user", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: UserKey(httpContext),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));

    options.AddPolicy("messages-user", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: UserKey(httpContext),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));
});

var app = builder.Build();

// Pipeline.
app.UseMiddleware<ExceptionMiddleware>();
app.UseForwardedHeaders();

if (app.Environment.IsDevelopment())
{
    app.UseAppSwagger(app.Environment);
    app.UseCors("DevOpen");
}

app.UseAuthentication();
app.UseAuthorization();

app.UseRateLimiter();
app.UseResponseCaching();

app.UseStaticFiles();

app.MapControllers();
app.MapHub<VenueHub>("/hubs/venue");

await app.EnsureDatabaseAsync();

app.Run();

public partial class Program { }
