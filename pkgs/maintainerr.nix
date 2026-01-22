{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_24,
  yarn-berry,
  makeWrapper,
  cacert,
  python3,
  esbuild,
  pkg-config,
  sqlite,
  node-gyp,
}: let
  pname = "maintainerr";
  version = "2.25.0";

  esbuild_pinned = esbuild.overrideAttrs (oldAttrs: rec {
    version = "0.25.12";
    src = fetchFromGitHub {
      owner = "evanw";
      repo = "esbuild";
      rev = "v${version}";
      hash = "sha256-iyQP6q/nX4KEo3DZ6H6okgvGiiqatJPPp+mMDOFKu8c="; # Verify hash if build fails here
    };
  });

  src = fetchFromGitHub {
    owner = "Maintainerr";
    repo = "Maintainerr";
    rev = "v${version}";
    hash = "sha256-99bsP7GtMt/er+p7fmCj9aJEUxmyeT+FHhrUF+dcGiY=";
  };

  yarnCache = stdenv.mkDerivation {
    name = "${pname}-${version}-yarn-cache";
    inherit src;
    nativeBuildInputs = [yarn-berry cacert];
    buildPhase = ''
      export HOME=$(mktemp -d)
      yarn config set enableGlobalCache false
      yarn config set cacheFolder $out
      yarn install --immutable --mode=skip-build
    '';
    installPhase = "true";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-KGixJvNTyHEvC7zgnMdDaikyFiEvtA60D4lwZAI69cE=";
  };
in
  stdenv.mkDerivation rec {
    inherit pname version src;

    nativeBuildInputs = [
      nodejs_24
      yarn-berry
      makeWrapper
      python3
      pkg-config
      node-gyp
      esbuild_pinned
    ];

    buildInputs = [
      sqlite
    ];

    # These environment variables help node-gyp find what it needs without network
    # and force esbuild to use the Nix-provided binary.
    env = {
      ESBUILD_BINARY_PATH = "${esbuild_pinned}/bin/esbuild";
      PYTHON = "${python3}/bin/python3";
      NODE_JS_LIBS = "${nodejs_24}/lib";
    };

    configurePhase = ''
      runHook preConfigure

      export HOME=$(mktemp -d)

      # Prepare writable yarn cache
      mkdir -p $HOME/.yarn_cache
      cp -r ${yarnCache}/* $HOME/.yarn_cache/
      chmod -R +w $HOME/.yarn_cache

      yarn config set enableGlobalCache false
      yarn config set cacheFolder $HOME/.yarn_cache

      chmod -R u+w .

      # Force yarn to use the system node-gyp for native builds
      # and link against the system sqlite library
      export npm_config_nodedir="${nodejs_24}"
      export npm_config_sqlite="${sqlite.dev}"

      yarn install --immutable

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      mkdir -p  ./apps/ui
      echo "VITE_BASE_PATH=/__PATH_PREFIX__" >> ./apps/ui/.env

      # Use the local turbo if it exists, otherwise the one in path
      yarn turbo build

      # Prune devDependencies
      yarn workspaces focus --all --production
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Create the output directories
      mkdir -p $out/lib/maintainerr
      mkdir -p $out/bin

      # 1. Copy the root node_modules
      # Use -pr to preserve permissions and recurse
      cp -pr node_modules $out/lib/maintainerr/

      # 2. Setup the Server (from root /server)
      mkdir -p $out/lib/maintainerr/server
      if [ -d "server/dist" ]; then
        cp -r server/dist $out/lib/maintainerr/server/
      else
        echo "ERROR: server/dist not found!"
        exit 1
      fi
      cp server/package.json $out/lib/maintainerr/server/

      # 3. Copy the UI (from root /ui) into the Server's static directory
      # Docker expectation: server/dist/ui
      mkdir -p $out/lib/maintainerr/server/dist/ui
      if [ -d "ui/dist" ]; then
        cp -r ui/dist/* $out/lib/maintainerr/server/dist/ui/
        echo "VITE_BASE_PATH=/__PATH_PREFIX__" >> $out/lib/maintainerr/server/dist/ui/.env
      else
        echo "ERROR: ui/dist not found!"
        exit 1
      fi

      # 4. Setup Packages/Contracts (Check if this is also at root or in /packages)
      if [ -d "packages/contracts" ]; then
          mkdir -p $out/lib/maintainerr/packages/contracts
          cp -r packages/contracts/dist $out/lib/maintainerr/packages/contracts/ 2>/dev/null || true
          cp packages/contracts/package.json $out/lib/maintainerr/packages/contracts/
      elif [ -d "contracts" ]; then
          mkdir -p $out/lib/maintainerr/contracts
          cp -r contracts/dist $out/lib/maintainerr/contracts/ 2>/dev/null || true
          cp contracts/package.json $out/lib/maintainerr/contracts/
      fi

      # 5. Create the wrapper script
      # Note: chdir to the new server location
      makeWrapper ${nodejs_24}/bin/node $out/bin/maintainerr \
        --chdir $out/lib/maintainerr \
        --add-flags "server/dist/main.js" \
        --set NODE_ENV production \
        --set UV_USE_IO_URING 0 \
        --set DATA_DIR "/var/lib/maintainerr" \
        --prefix PATH : ${lib.makeBinPath [nodejs_24]}

      runHook postInstall
    '';
  }
