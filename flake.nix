{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixarr.url = "github:rasmus-kirk/nixarr";

    agenix.url = "github:ryantm/agenix";

    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixarr,
    agenix,
    microvm,
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
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    nixosModules = import ./modules/nixos;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      phoenix = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ({pkgs, ...}: {
            nixpkgs.overlays = [
              outputs.overlays.additions
            ];
          })
          ./nixos/configuration.nix
          ./nixos/machines/phoenix/phoenix.nix
          nixarr.nixosModules.default
          outputs.nixosModules.jellystat
          outputs.nixosModules.maintainerr
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
              ./home-manager/home.nix
              ./home-manager/sway.nix
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
