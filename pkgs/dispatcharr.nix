{
  lib,
  buildNpmPackage,
  python313Packages,
  fetchFromGitHub,
  fetchPypi,
}:
# NOTE: Dispatcharr hardcodes its data tree (/data/logos, /data/recordings,
# ...) in Python *and* a couple of frontend string checks. The paths are not
# env-configurable upstream, so the prefix is baked in at build time via a
# sed on the sources. Call this file with the machine's state dir:
#   pkgs.callPackage ./pkgs/dispatcharr.nix { dataDir = "/var/lib/dispatcharr"; }
# The default below matches upstream's Docker layout.
{
  dataDir ? "/data",
}:
let
  pname = "dispatcharr";
  version = "0.31.0";

  py = python313Packages;

  src = fetchFromGitHub {
    owner = "Dispatcharr";
    repo = "Dispatcharr";
    tag = "v${version}";
    hash = "sha256-k2Xk08II3aq2rkV7yF2/NtyfECuZU5ibB/dUq6DFLDM=";
  };

  # Rewrite the hardcoded /data prefix everywhere (Python string literals and
  # the two frontend startsWith checks). Applied to both the frontend and the
  # backend build so they agree on the same prefix.
  dataDirPatch = ''
    for d in apps core dispatcharr frontend/src; do
      [ -d "$d" ] || continue
      find "$d" -type f \( -name '*.py' -o -name '*.jsx' -o -name '*.js' \) \
        -exec sed -i -e 's|"/data|"${dataDir}|g' -e "s|'/data|'${dataDir}|g" {} +
    done
  '';

  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";

    # upstream's own build instructions install with --legacy-peer-deps
    npmFlags = [ "--legacy-peer-deps" ];
    # video.js pulls in a git dependency (webworkify-webpack) without a
    # lockfile entry; upstream installs from the same lockfile in CI.
    forceGitDeps = true;
    makeCacheWritable = true;
    npmDepsHash = "sha256-e2FcAf3rw/U1Vsa9qJ8koUr6b/SIbj7rWD+gln05fUk=";

    postPatch = dataDirPatch;

    installPhase = ''
      runHook preInstall
      cp -r dist/. "$out"
      runHook postInstall
    '';
  };

  # Not in nixpkgs; pure-python and only depends on Django. Dispatcharr's
  # psycopg3 backend imports django_db_geventpool.backends.{base,pool}.
  django-db-geventpool = py.buildPythonPackage rec {
    pname = "django-db-geventpool";
    version = "4.0.8";
    pyproject = true;

    src = fetchPypi {
      pname = "django_db_geventpool";
      inherit version;
      hash = "sha256-jqEA5IFRUnL3bHf03zuzQBzoOMl1SXgtDTD6+ZDQy/Q=";
    };

    build-system = [ py.hatchling ];
    dependencies = [ py.django ];

    # upstream has no tests packaged
    doCheck = false;

    pythonImportsCheck = [ "django_db_geventpool" ];
  };

  dependencies = with py; [
    celery
    channels
    channels-redis
    daphne
    django
    django-celery-beat
    django-cors-headers
    django-db-geventpool
    django-filter
    django-redis
    djangorestframework
    djangorestframework-simplejwt
    drf-spectacular
    gevent
    gunicorn
    lxml
    m3u8
    packaging
    pillow
    psutil
    psycopg
    pytz
    rapidfuzz
    redis
    regex
    requests
    tzlocal
  ];

  # Wrappers for the service entry points (the NixOS units pass their own
  # arguments: worker/beat/queues, bind addresses).
  serviceWrappers =
    lib.concatMapStringsSep "\n"
      (cmd: ''
        makeWrapper ${py.${cmd}}/bin/${cmd} "$out/bin/dispatcharr-${cmd}" \
          --prefix PYTHONPATH : "$out/${py.python.sitePackages}:${py.makePythonPath dependencies}"
      '')
      [
        "celery"
        "daphne"
        "gunicorn"
      ];
in
py.buildPythonApplication {
  inherit pname version src;
  pyproject = true;

  build-system = [ py.hatchling ];
  inherit dependencies;

  # Dispatcharr pins exact versions (Django==6.0.8, torch==2.14.0+cpu, ...)
  # that don't match this flake's nixpkgs snapshot. Use the nixpkgs versions
  # instead (Django 5.2 LTS works fine with 0.31.0).
  pythonRelaxDeps = true;
  # Heavy / CLI-only deps that are intentionally not in the Python env:
  #  - torch + sentence-transformers: optional ML-based EPG matching; the
  #    code degrades gracefully to rapidfuzz when the import fails
  #  - uwsgi: replaced by gunicorn (worker-class gevent)
  #  - streamlink / yt-dlp / python-vlc: stream profiles exec them as
  #    binaries; they are put on PATH by the NixOS service instead
  pythonRemoveDeps = [
    "uwsgi"
    "torch"
    "sentence-transformers"
    "streamlink"
    "python-vlc"
    "yt-dlp"
  ];

  postPatch = dataDirPatch + ''
    # STATIC_ROOT/MEDIA_ROOT are derived from the read-only site-packages at
    # runtime otherwise; make them overridable so collectstatic can run at
    # build time and the service can point MEDIA_ROOT at its state dir.
    substituteInPlace dispatcharr/settings.py \
      --replace-fail 'STATIC_ROOT = BASE_DIR / "static"  # Directory where static files will be collected' \
                     'STATIC_ROOT = os.environ.get("DISPATCHARR_STATIC_ROOT", str(BASE_DIR / "static"))' \
      --replace-fail 'MEDIA_ROOT = BASE_DIR / "media"' \
                     'MEDIA_ROOT = os.environ.get("DISPATCHARR_MEDIA_ROOT", str(BASE_DIR / "media"))'
  '';

  # settings.py makedirs()es the (sandbox-inaccessible) log dir on import,
  # but tolerates the failure — good enough for the build-time
  # collectstatic below.
  env.DJANGO_SECRET_KEY = "nix-build";

  postInstall = ''
    # Hatch only installs the wheel packages (dispatcharr, apps, core);
    # version.py (imported as a top-level module by core) and the
    # management entrypoint are not part of them.
    install -Dm644 version.py "$out/${py.python.sitePackages}/version.py"
    install -Dm644 manage.py "$out/share/${pname}/manage.py"

    # The Django settings expect the React build at BASE_DIR/frontend/dist
    # (templates + STATICFILES_DIRS); ship it inside site-packages so
    # build-time collectstatic and runtime template rendering see it.
    install -d "$out/${py.python.sitePackages}/frontend/dist"
    cp -r ${frontend}/. "$out/${py.python.sitePackages}/frontend/dist/"

    # Collect static files (admin CSS/JS, DRF, spectacular, React assets)
    # into the output at build time — nothing writes static files at
    # runtime, so the service never has to run collectstatic.
    export DISPATCHARR_STATIC_ROOT="$out/share/${pname}/static"
    export PYTHONPATH="$out/${py.python.sitePackages}:$PYTHONPATH"
    # Run from the install share dir: the build's source tree also contains
    # apps/, which would shadow/conflict with the installed packages
    # ("multiple filesystem locations" for the app modules).
    (cd "$out/share/${pname}" && ${py.python.interpreter} manage.py collectstatic --noinput)

    # Drop-in management wrapper (migrate, createsuperuser, shell, ...).
    # makePythonPath: buildPythonApplication's own wrappers get dependency
    # paths via propagatedBuildInputs, but these hand-rolled ones have to add
    # them explicitly.
    makeWrapper ${py.python.interpreter} "$out/bin/dispatcharr-manage" \
      --run "cd $out/share/${pname}" \
      --prefix PYTHONPATH : "$out/${py.python.sitePackages}:${py.makePythonPath dependencies}" \
      --add-flags "$out/share/${pname}/manage.py"

    # Service entry points. The NixOS units pass their own arguments
    # (worker/beat/queues, bind addresses).
    ${serviceWrappers}
  '';

  doCheck = false;

  meta = {
    description = "IPTV stream dispatching and management (Django + React)";
    homepage = "https://github.com/Dispatcharr/Dispatcharr";
    license = lib.licenses.agpl3Only;
    mainProgram = "dispatcharr-manage";
    platforms = lib.platforms.linux;
  };
}
