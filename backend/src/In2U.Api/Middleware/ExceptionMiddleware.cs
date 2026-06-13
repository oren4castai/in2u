using System.Text.Json;
using In2U.Api.Common;
using Microsoft.AspNetCore.Mvc;

namespace In2U.Api.Middleware;

public sealed class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;
    private readonly IHostEnvironment _env;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger, IHostEnvironment env)
    {
        _next = next;
        _logger = logger;
        _env = env;
    }

    public async Task Invoke(HttpContext ctx)
    {
        try
        {
            await _next(ctx);
        }
        catch (Exception ex)
        {
            await WriteProblemAsync(ctx, ex);
        }
    }

    private async Task WriteProblemAsync(HttpContext ctx, Exception ex)
    {
        int status;
        string title;

        switch (ex)
        {
            case UnauthorizedAccessException:
                status = StatusCodes.Status401Unauthorized;
                title = "Unauthorized";
                break;
            case InactiveTimeoutException:
                status = StatusCodes.Status409Conflict;
                title = "Inactive Timeout";
                break;
            case ArgumentException:
            case InvalidOperationException:
                status = StatusCodes.Status400BadRequest;
                title = "Bad Request";
                break;
            case NotImplementedException:
                status = StatusCodes.Status501NotImplemented;
                title = "Not Implemented";
                break;
            default:
                status = StatusCodes.Status500InternalServerError;
                title = "Internal Server Error";
                _logger.LogError(ex, "Unhandled exception");
                break;
        }

        if (status != StatusCodes.Status500InternalServerError)
            _logger.LogWarning(ex, "{Title}: {Message}", title, ex.Message);

        var problem = new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = (_env.IsDevelopment() || status != StatusCodes.Status500InternalServerError)
                ? ex.Message
                : "An unexpected error occurred.",
            Instance = ctx.Request.Path,
        };

        if (ctx.Response.HasStarted) return;

        ctx.Response.Clear();
        ctx.Response.StatusCode = status;
        ctx.Response.ContentType = "application/problem+json";
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(problem));
    }
}
