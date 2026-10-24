# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: _prev: {
    # Slack with the default "Knock Brush" new-message notification sound
    # replaced by the classic Skype new-message sound.
    slack = _prev.callPackage ../pkgs/slack {slack = _prev.slack;};

    # TODO: drop once nixpkgs' pyopenjtalk-plus tests pass again.
    # One test (test_run_njd_from_mecab_invalid_input_should_not_break_next_call)
    # asserts an old error message ("must be str" vs "Expected str, got int")
    # and fails the build of pyopenjtalk-plus -> piper-tts -> calibre ->
    # calibre-web. The test only checks an exception's wording, so skip checks.
    pythonPackagesExtensions =
      _prev.pythonPackagesExtensions
      ++ [
        (_pyFinal: pyPrev: {
          pyopenjtalk-plus = pyPrev.pyopenjtalk-plus.overridePythonAttrs {doCheck = false;};
        })
      ];

    # TODO: drop once nixpkgs' calibre passes its own install checks again.
    # calibre 9.16.0's installCheck fails only on test_speech_dispatcher
    # ("No module named 'speechd'"); the other 672 tests pass.
    calibre = _prev.calibre.overrideAttrs {doInstallCheck = false;};

    # TODO: drop this override block once nixos-unstable builds these again.
    #
    # Both fail to build from the main nixpkgs (nixos-unstable) since the
    # 2025-10 flake update:
    #
    # - gdbuspp: GCC '-Werror=maybe-uninitialized' false positive in
    #   proxy.cpp. Pin it to the (same-version) build from nixpkgs-stable
    #   (GCC 14), which is fetched from the binary cache.
    gdbuspp =
      (import inputs.nixpkgs-stable {
        system = final.system;
        config.allowUnfree = true;
      }).gdbuspp;

    # - openvpn3: abseil-cpp-20260817 needs C++20 while openvpn3 builds
    #   with -std=c++17. Build with C++20 and silence the resulting
    #   -Wdeprecated-enum-enum-conversion warnings (-Werror is on).
    openvpn3 = _prev.openvpn3.overrideAttrs (old: {
      mesonFlags =
        (old.mesonFlags or [])
        ++ [
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
