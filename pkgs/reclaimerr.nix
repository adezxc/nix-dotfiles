{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  python313Packages,
}: let
  pname = "reclaimerr";
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "jessielw";
    repo = "Reclaimerr";
    rev = version;
    hash = "sha256-EXl4BW981bDTuVG++aWwr3uWe0AdsMCE9ZdAvZNPZuI=";
  };

  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";
    npmDepsHash = "sha256-2pvvJvc4+RtSwIHda11b+hSPmrr8MpSIDfs4Ilgy56s=";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/. "$out"
      runHook postInstall
    '';
  };

  dependencies = with python313Packages; [
    aiosqlite
    alembic
    apprise
    apscheduler
    argon2-cffi
    authlib
    cryptography
    email-validator
    fastapi
    granian
    httpx
    python-multipart
    itsdangerous
    niquests
    pillow
    pydantic-settings
    pyjwt
    python-iso639
    python-dotenv
    semver
    slowapi
    sqlalchemy
    tenacity
  ];
in
  python313Packages.buildPythonApplication {
    inherit pname version src;
    pyproject = true;

    build-system = with python313Packages; [hatchling];
    inherit dependencies;

    # Reclaimerr 0.3.5 is newer than this flake's nixpkgs snapshot. Its Python
    # dependencies are available here, but several lower bounds are newer than
    # the packaged versions.
    pythonRelaxDeps = true;

    nativeBuildInputs = [makeWrapper];

    postInstall = ''
      # Hatch installs the backend subdirectories as top-level packages. Keep
      # their source layout instead: the application imports backend.* and its
      # migrations are loaded relative to backend.database at runtime.
      install -d "$out/${python313Packages.python.sitePackages}/backend"
      cp -r backend/. "$out/${python313Packages.python.sitePackages}/backend/"
      install -Dm644 CHANGELOG.md "$out/${python313Packages.python.sitePackages}/CHANGELOG.md"
      install -d "$out/share/${pname}"
      cp -r ${frontend}/. "$out/share/${pname}/frontend"

      makeWrapper ${python313Packages.python.interpreter} "$out/bin/${pname}" \
        --prefix PYTHONPATH : "$out/${python313Packages.python.sitePackages}:${python313Packages.makePythonPath dependencies}" \
        --add-flags "-m granian --interface asgi --workers 1 backend.api.main:app"
    '';

    doCheck = false;

    meta = {
      description = "Automatically reclaim space in media libraries using customizable rules";
      homepage = "https://github.com/jessielw/Reclaimerr";
      license = lib.licenses.gpl3Only;
      mainProgram = pname;
      platforms = lib.platforms.linux;
    };
  }
