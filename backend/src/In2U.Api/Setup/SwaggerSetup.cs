using Microsoft.OpenApi.Models;

namespace In2U.Api.Setup;

public static class SwaggerSetup
{
    public static IServiceCollection AddAppSwagger(this IServiceCollection services)
    {
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(c =>
        {
            c.SwaggerDoc("v1", new OpenApiInfo { Title = "In2U API", Version = "v1" });

            var bearer = new OpenApiSecurityScheme
            {
                Name = "Authorization",
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                In = ParameterLocation.Header,
                Description = "JWT Bearer token. Example: \"Bearer {token}\"",
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" },
            };

            c.AddSecurityDefinition("Bearer", bearer);
            c.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                [bearer] = Array.Empty<string>(),
            });
        });

        return services;
    }

    public static IApplicationBuilder UseAppSwagger(this IApplicationBuilder app, IWebHostEnvironment env)
    {
        if (!env.IsDevelopment()) return app;
        app.UseSwagger();
        app.UseSwaggerUI();
        return app;
    }
}
