# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: _prev: {
    # TODO: drop this override block once nixos-unstable builds these again.
    #
    # Both fail to build from the main nixpkgs (nixos-unstable) since the
    # 2025-10 flake update:
    #
    # - gdbuspp: GCC '-Werror=maybe-uninitialized' false positive in
    #   proxy.cpp. Pin it to the (same-version) build from nixpkgs-stable
    #   (GCC 14), which is fetched from the binary cache.
    gdbuspp = (import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    }).gdbuspp;

    # - openvpn3: abseil-cpp-20260817 needs C++20 while openvpn3 builds
    #   with -std=c++17. Build with C++20 and silence the resulting
    #   -Wdeprecated-enum-enum-conversion warnings (-Werror is on).
    openvpn3 = _prev.openvpn3.overrideAttrs (old: {
      mesonFlags = (old.mesonFlags or [ ]) ++ [
        "-Dcpp_std=c++20"
        "-Dcpp_args=-Wno-error=deprecated-enum-enum-conversion"
      ];
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
