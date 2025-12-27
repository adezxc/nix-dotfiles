{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "jellystat";
  version = "1.1.7"; # Update to the current version

  src = pkgs.fetchFromGitHub {
    owner = "CyferShepard"; # Verify the correct owner
    repo = "jellystat";
    rev = "${version}";
    hash = "sha256-q3QOHRVUvJVtytvarNb2/0Cbl4o7RBFw4ocGIOUwu3Q=";
  };

  npmDepsHash = "sha256-y97d8fVG0rflSZypBSEBOgPbKnqHXTWF6Qfw5GAbzjs=";

  # This corresponds to 'npm run build' in your screenshot
  npmBuildScript = "build";

  # Define what gets installed to the Nix store
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/jellystat
    cp -r . $out/lib/node_modules/jellystat

    # The package.json says the start command is "cd backend && node server.js"
    # So we point our wrapper to that specific file.
    mkdir -p $out/bin
    makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/jellystat \
      --add-flags "$out/lib/node_modules/jellystat/backend/server.js" \
      --set NODE_ENV production \
      --run "cd $out/lib/node_modules/jellystat"

    runHook postInstall
  '';

  nativeBuildInputs = [pkgs.makeWrapper];
}
