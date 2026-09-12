{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  sqlite,
  fetchYarnDeps,
  yarn,
  fixup-yarn-lock,
  nodejs,
  applyPatches,
  prefetch-yarn-deps,
}: let
  # Lidarr *nightly* (develop branch). Plugin support (needed for
  # Lidarr.Plugin.Slskd — Soulseek via slskd as indexer + download client)
  # is not in the stable channel, only in nightly.
  # To update: pick the latest prerelease tag from
  #   https://github.com/Lidarr/Lidarr/releases (vX.Y.Z.BBBBB "develop")
  # then update `version`, `hash` (nix-prefetch-url --unpack the tarball),
  # `yarnOfflineCache` hash (prefetch-yarn-deps on its yarn.lock) and
  # regenerate deps:
  #   nix build .#lidarr-nightly.passthru.fetch-deps
  #   ./result/bin/fetch-deps
  version = "3.1.5.5066";
  src = applyPatches {
    src = fetchFromGitHub {
      owner = "Lidarr";
      repo = "Lidarr";
      tag = "v${version}";
      hash = "sha256-DXJlUpfJQz0Sp9L4+74joRJeILedCUBlQvJ63S/ld9E=";
    };
    postPatch = ''
      mv src/NuGet.config NuGet.Config
    '';
  };
  rid = dotnetCorePackages.systemToDotnetRid stdenvNoCC.hostPlatform.system;
in
  buildDotnetModule {
    pname = "lidarr";
    inherit version src;

    strictDeps = true;
    nativeBuildInputs = [
      nodejs
      yarn
      prefetch-yarn-deps
      fixup-yarn-lock
    ];

    yarnOfflineCache = fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-Jq2O7gvB+PKcz6uDBMg7ox6/Bu+pikXH6JGuLfKG5fI=";
    };

    postConfigure = ''
      yarn config --offline set yarn-offline-mirror "$yarnOfflineCache"
      fixup-yarn-lock yarn.lock
      yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
      patchShebangs --build node_modules
    '';
    postBuild = ''
      yarn --offline run build --env production
    '';
    postInstall = ''
      cp -a -- _output/UI "$out/lib/lidarr/UI"
    '';

    nugetDeps = ./lidarr-nightly-deps.json;

    runtimeDeps = [sqlite];

    dotnet-sdk = dotnetCorePackages.sdk_8_0;
    dotnet-runtime = dotnetCorePackages.aspnetcore_8_0;

    # Nightly: skip the (long, network-sensitive) test suite.
    doCheck = false;

    __structuredAttrs = true; # for Copyright property that contains spaces

    executables = ["Lidarr"];

    projectFile = [
      "src/NzbDrone.Console/Lidarr.Console.csproj"
      "src/NzbDrone.Mono/Lidarr.Mono.csproj"
    ];

    dotnetFlags = [
      "--property:TargetFramework=net8.0"
      "--property:EnableAnalyzers=false"
      "--property:SentryUploadSymbols=false" # Fix Sentry upload failed warnings
      # Override defaults in src/Directory.Build.props that use current time.
      "--property:Copyright=Copyright 2014-2026 lidarr.audio (GNU General Public v3)"
      "--property:AssemblyVersion=${version}"
      "--property:AssemblyConfiguration=develop"
      "--property:RuntimeIdentifier=${rid}"
    ];

    meta = {
      description = "Usenet/BitTorrent music downloader (nightly, plugin support)";
      homepage = "https://lidarr.audio";
      changelog = "https://github.com/Lidarr/Lidarr/releases/tag/v${version}";
      license = lib.licenses.gpl3Only;
      mainProgram = "Lidarr";
    };
  }
