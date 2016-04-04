// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using BasicApi.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.PlatformAbstractions;
using Microsoft.IdentityModel.Tokens;
using Newtonsoft.Json.Serialization;

namespace BasicApi
{
    public class Startup
    {
        public Startup(IHostingEnvironment hosting, IApplicationEnvironment applicationEnvironment)
        {
            Configuration =
                new ConfigurationBuilder()
                .SetBasePath(applicationEnvironment.ApplicationBasePath)
                .AddJsonFile("appsettings.json")
                .Build();
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            var rsa = new RSACryptoServiceProvider(2048);
            var key = new RsaSecurityKey(rsa.ExportParameters(true));

            services.AddSingleton(new SigningCredentials(
                key,
                SecurityAlgorithms.RsaSha256Signature));

            services.Configure<JwtBearerOptions>(options =>
            {
                options.AutomaticAuthenticate = false;
                options.AutomaticChallenge = false;
                options.TokenValidationParameters.IssuerSigningKey = key;
                options.TokenValidationParameters.ValidAudience = "Myself";
                options.TokenValidationParameters.ValidIssuer = "BasicApi";
            });

            services.AddEntityFrameworkSqlServer().AddDbContext<BasicApiContext>(options =>
            {
                var connectionString = Configuration["Data:DefaultConnection:ConnectionString"];
                options.UseSqlServer(connectionString);
            });

            services.AddAuthorization(options =>
            {
                options.AddPolicy(
                    "pet-store-reader", 
                    builder => builder
                        .AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme‌​)
                        .RequireAuthenticatedUser()
                        .RequireClaim("scope", "pet-store-reader"));

                options.AddPolicy(
                    "pet-store-writer",
                    builder => builder
                        .AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme‌​)
                        .RequireAuthenticatedUser()
                        .RequireClaim("scope", "pet-store-writer"));
            });

            services
                .AddMvcCore()
                .AddAuthorization()
                .AddJsonFormatters(json => json.ContractResolver = new CamelCasePropertyNamesContractResolver())
                .AddDataAnnotations();
            
            services.AddSingleton<PetRepository>(new PetRepository());
        }

        public void Configure(IApplicationBuilder app, IApplicationEnvironment applicationEnvironment)
        {
            CreateDatabase(app.ApplicationServices, applicationEnvironment);

            app.Use(next => async context =>
            {
                try
                {
                    await next(context);
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex);
                    throw;
                }
            });

            app.UseJwtBearerAuthentication();

            app.UseMvc();
        }

        private void CreateDatabase(IServiceProvider services, IApplicationEnvironment applicationEnvironment)
        {
            using (var serviceScope = services.GetRequiredService<IServiceScopeFactory>().CreateScope())
            {
                var dbContext = services.GetRequiredService<BasicApiContext>();
                dbContext.Database.EnsureDeleted();
                dbContext.Database.EnsureCreated();

                using (var connection = dbContext.Database.GetDbConnection())
                {
                    connection.Open();

                    var command = connection.CreateCommand();
                    command.CommandText = File.ReadAllText(Path.Combine(applicationEnvironment.ApplicationBasePath, "seed.sql"));
                    command.ExecuteNonQuery();
                }
            }
        }

        public static void Main(string[] args)
        {
            var application = new WebHostBuilder()
                .UseKestrel()
                .UseUrls("http://+:5000")
                .UseDefaultHostingConfiguration(args)
                .UseStartup<Startup>()
                .Build();

            application.Run();
        }
    }
}

