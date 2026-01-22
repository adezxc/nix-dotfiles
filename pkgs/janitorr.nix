{
  lib,
  stdenv,
  fetchFromGitHub,
  gradle_9,
  jdk25,
  makeWrapper,
}: let
  pname = "janitorr";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "Schaka";
    repo = "janitorr";
    rev = "v${version}";
    hash = "sha256-JHk1+pYSdnkm0KUSThhyNvNYjGXaWGX7VM/aQGtSlII=";
  };

  # Shared patching logic to ensure buildSrc has network access to plugins
  # # Create an init script to force repositories during the fetch phase
  initScript = ''
    settingsEvaluated { settings ->
        settings.pluginManagement {
            repositories {
                mavenCentral()
                gradlePluginPortal()
                google()
            }
        }
    }
  '';

  patchPhase = ''
    # Disable foojay (standard Nix-Gradle practice)
    find . -name "*.gradle.kts" -exec sed -i '/id("org.gradle.toolchains.foojay-resolver-convention")/s/^/\/\//' {} +

    # Write the init script to a file
    echo '${initScript}' > fetch-repos.init.gradle.kts
  '';

  gradleDeps = stdenv.mkDerivation {
    name = "${pname}-gradle-deps";
    inherit src;
    nativeBuildInputs = [gradle_9 jdk25];
    postPatch = patchPhase;

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d)

      # 1. Force resolve buildSrc plugins specifically using the init script
      # We use '--init-script' to inject the repos without touching the source
      gradle --no-daemon -Dorg.gradle.java.home=${jdk25} \
        --init-script fetch-repos.init.gradle.kts \
        :buildSrc:dependencies --stacktrace

      # 2. Fetch the rest of the project
      gradle --no-daemon -Dorg.gradle.java.home=${jdk25} \
        --init-script fetch-repos.init.gradle.kts \
        assemble -x test
    '';

    installPhase = ''
      mkdir -p $out
      cp -r $GRADLE_USER_HOME/caches $out/
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = lib.fakeHash; # Update this once it fails with the new hash
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [gradle_9 jdk25 makeWrapper];

    postPatch = patchPhase;

    buildPhase = ''
      runHook preBuild
      export GRADLE_USER_HOME=$(mktemp -d)

      # Link the pre-fetched dependencies
      rm -rf $GRADLE_USER_HOME/caches
      ln -s ${gradleDeps}/caches $GRADLE_USER_HOME/caches

      # Build the bootJar offline
      gradle bootJar \
        --offline \
        --no-daemon \
        -Dorg.gradle.java.home=${jdk25} \
        -x test

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p $out/share/${pname} $out/bin
      cp build/libs/*.jar $out/share/${pname}/janitorr.jar

      makeWrapper ${jdk25}/bin/java $out/bin/janitorr \
        --add-flags "-jar $out/share/${pname}/janitorr.jar"
    '';
  }
