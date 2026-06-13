using In2U.Api.Common;
using In2U.Api.Services;
using Microsoft.Extensions.Options;

namespace In2U.Api.BackgroundServices;

public sealed class AmbientRotationHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<AmbientRotationHostedService> _logger;
    private readonly AmbientOptions _opts;

    public AmbientRotationHostedService(
        IServiceScopeFactory scopeFactory,
        ILogger<AmbientRotationHostedService> logger,
        IOptions<AmbientOptions> opts)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _opts = opts.Value;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            // Initial delay lets migrations and seeding settle.
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
        catch (OperationCanceledException) { return; }

        var interval = TimeSpan.FromSeconds(Math.Max(5, _opts.RotationIntervalSeconds));
        var timer = new PeriodicTimer(interval);

        try
        {
            do
            {
                try
                {
                    using var scope = _scopeFactory.CreateScope();
                    var svc = scope.ServiceProvider.GetRequiredService<IAmbientProfileService>();
                    await svc.RotateAllAsync(stoppingToken);
                }
                catch (OperationCanceledException) { throw; }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Ambient rotation tick failed.");
                }
            } while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException) { }
    }
}
