// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using System.IO;
using System.Reflection;
using System.Runtime.Versioning;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Internal;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.PlatformAbstractions;

namespace MvcBenchmarks.InMemory
{
    public static class HostingStartup
    {
        private static readonly string _testAppRelativeFolder = Path.Combine("..", "..", "..", "..", "testapp");
        public static string GetProjectDirectoryOf<TStartup>()
        {
            return GetProjectDirectoryOf(typeof(TStartup).GetTypeInfo().Assembly);
        }
        public static string GetProjectDirectoryOf(Assembly assembly)
        {
            var applicationName = assembly.GetName().Name;
            return Path.GetFullPath(Path.Combine(
               PlatformServices.Default.Application.ApplicationBasePath,
               _testAppRelativeFolder,
               applicationName
            ));
        }

        public static WebHostBuilder UseProjectOf<TStartup>(this WebHostBuilder builder)
        {
            var startupAssembly = typeof(TStartup).GetTypeInfo().Assembly;
            var applicationName = startupAssembly.GetName().Name;
            var webRoot = GetProjectDirectoryOf(startupAssembly);

            builder.ConfigureServices(services =>
            {
                var applicationEnvironment = new TestApplicationEnvironment(
                    PlatformServices.Default.Application,
                    applicationName,
                    webRoot);
                services.AddSingleton<IApplicationEnvironment>(applicationEnvironment);

                var hostingEnvironment = new HostingEnvironment();
                hostingEnvironment.Initialize(
                    applicationName,
                    webRoot,
                    new WebHostOptions
                    {
                        Environment = "Production"
                    });
                services.AddSingleton<IHostingEnvironment>(hostingEnvironment);

                var manager = new ApplicationPartManager();
                manager.ApplicationParts.Add(new AssemblyPart(startupAssembly));
                services.AddSingleton(manager);
            });

            return builder;
        }

        private class TestApplicationEnvironment : IApplicationEnvironment
        {
            private readonly IApplicationEnvironment _original;

            public TestApplicationEnvironment(IApplicationEnvironment original, string name, string path)
            {
                _original = original;
                ApplicationName = name;
                ApplicationBasePath = path;
            }

            public string ApplicationBasePath { get; }

            public string ApplicationName { get; }

            public string ApplicationVersion => _original.ApplicationVersion;

            public FrameworkName RuntimeFramework => _original.RuntimeFramework;
        }
    }
}
