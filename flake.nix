{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Pinned nixpkgs for the kernel (terrorblade builds a patched kernel).
    # `nix flake update` will NOT move this since the rev is exact —
    # bump it manually when you want a newer kernel.
    nixpkgs-kernel.url = "github:nixos/nixpkgs/241313f4e8e508cb9b13278c2b0fa25b9ca27163";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";

    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # Noctalia desktop shell (used with niri on terrorblade).
    # The `cachix` branch always points to the latest commit built and
    # pushed to the Noctalia binary cache, so this input won't trigger
    # local builds. NOTE: nixpkgs deliberately does NOT follow our
    # nixpkgs — the binary cache only has builds against Noctalia's own
    # pinned nixpkgs.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    agenix,
    microvm,
    nixvim,
    noctalia,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "x86_64-linux"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    formatter = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.writeShellApplication {
        name = "alejandra-format";
        runtimeInputs = [pkgs.alejandra];
        text = ''
          if [ "$#" -eq 0 ]; then
            set -- .
          fi

          exec alejandra "$@"
        '';
      });

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    nixosModules = import ./modules/nixos;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      phoenix = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./nixos/configuration.nix
          ./nixos/machines/phoenix/phoenix.nix
          agenix.nixosModules.default
        ];
      };

      antimage = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./nixos/configuration.nix
          ./nixos/machines/antimage/antimage.nix
        ];
      };

      terrorblade = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs microvm;};
        modules = [
          ./nixos/configuration.nix
          ./nixos/machines/terrorblade/terrorblade.nix
          microvm.nixosModules.host
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs outputs;};
            home-manager.users.adam.imports = [
              nixvim.homeModules.nixvim
              ./home-manager/home.nix
              ./home-manager/niri.nix
              ./home-manager/neovim.nix
              noctalia.homeModules.default
            ];
          }
        ];
      };
    };

    homeConfigurations = {
      "adam@phoenix" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home-manager/home.nix
          ./home-manager/terminal.nix
          ./home-manager/beets.nix
        ];
      };

      "adam@antimage" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          ./home-manager/home.nix
          ./home-manager/i3.nix
        ];
      };
    };
  };
}
