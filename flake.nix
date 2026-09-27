{
  description = "Ivan's attempt at bringing order to his computer chaos";

  inputs = {
    # One thing I don't like about Flakes is that I can't parametrise
    # the NixOS version here with a variable.

    # Using unstable here for now for hardware compatibility.
    #
    # Switch to being based on nixos-25.11 once that's available (and
    # if it works).
    #
    # Or nevermind, just use unstable since it's pinned?
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    # Not currently used.
    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    # Home manager
    #
    # Is this going to work where I always use live home-manager even
    # if I have a versioned nixpkgs?
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable"; # Defaults to unstable
        nixpkgs-stable.follows = "nixpkgs"; # In case we ever use an actual version.
      };
    };

    emacs-config = {
      url = "github:ivan-m/emacs-regolith";
      flake = false; # Just get the files, not a full flake output
    };
  };

  # Use the Nix community Cachix cache for faster builds. This is
  # especially useful for Emacs packages, which can take a long time
  # to build.
  #
  # This is used for build-time of any evaluation of this flake.
  #
  # May need to keep in sync with `sharedNixSettings` below.
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      emacs-overlay,
      ...
    }:
    let
      inherit (self) outputs;

      # Can we somehow map over a list of system configurations to get
      # this?
      systems = [
        "x86_64-linux"
      ];

      # Not sure what this is for, but seems recommended.
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # This defines a function that takes in a config-variables block
      # to do common scaffolding for multiple systems.
      #
      # It's a little disconcerting that we never seem to actually
      # define what the config-variables record data structure
      # actually is...
      configuration =
        config-variables:
        let
          resolveEmacsConfig =
            configName:
            if !(builtins.hasAttr configName config-variables) then
              null
            else
              let
                source = builtins.getAttr configName config-variables;
              in
              if source == null then
                null
              else
                {
                  inherit source;
                  isPath = builtins.isString source;
                };

          emacsConfig = resolveEmacsConfig "emacsConfig";
          emacsWorkConfig = resolveEmacsConfig "emacsWorkConfig";

          commonSpecialArgs = {
            inherit
              inputs
              outputs
              config-variables
              emacs-overlay
              emacsConfig
              emacsWorkConfig
              ;
          };

          # This allows re-use of this cache for any additional flake builds
          # within those systems.
          sharedNixSettings = {
            nix = {
              package = nixpkgs.legacyPackages.${config-variables.system}.nix;
              settings = {
                extra-substituters = [ "https://nix-community.cachix.org" ];
                extra-trusted-public-keys = [
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
              };
            };
          };
          pkgs = nixpkgs.legacyPackages.${config-variables.system};
        in
        {
          nixosConfiguration = nixpkgs.lib.nixosSystem {
            specialArgs = commonSpecialArgs;
            modules = [
              sharedNixSettings
              ./hosts/${config-variables.hostId}/nixos/configuration.nix
            ];
          };

          homeConfiguration = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = commonSpecialArgs;
            modules = [
              sharedNixSettings
              ./hosts/${config-variables.hostId}/home-manager/home.nix
            ];
          };

          standaloneConfiguration = import ./hosts/${config-variables.hostId}/standalone/configuration.nix (
            commonSpecialArgs
            // {
              inherit pkgs;
            }
          );
        };

      hostDefinitions = {
        zolotiy = {
          # Don't change the original stateVersion; it tracks the
          # version of the configuration.
          stateVersion = "25.05";

          username = "ivan";
          userDesc = "Ivan Lazar Miljenovic";
          system = "x86_64-linux";

          # Path to the root of the flake repository, relative to $HOME.
          repoRoot = "code/flakes";

          # Can be either:
          # - A string: "code/emacs"
          # - A flake input: inputs.emacs-config
          # - Omitted entirely.
          emacsConfig = inputs.emacs-config;

          # Optional. If omitted, lib/emacs.nix uses:
          # ${emacsConfig}/work
          #
          # Can be either:
          # - A string: "code/emacs-private"
          # - A flake input: inputs.emacs-work-config
          # - Omitted entirely.
          #
          # emacsWorkConfig = "code/emacs-private";
        };
      };

      nixosHosts = [
        "zolotiy"
      ];

      homeHosts = [
        "zolotiy"
      ];

      # These are dedicated package derivation specifications for use
      # in standalone single-user Nix installs.
      standaloneHosts = [
        # "laptop"
      ];

      hostConfig =
        hostId:
        hostDefinitions.${hostId}
        // {
          inherit hostId;
        };

      mkConfiguration = hostId: configuration (hostConfig hostId);

      mkHomeConfigurationName = hostId: "${hostDefinitions.${hostId}.username}@${hostId}";
    in
    {

      nixosConfigurations = nixpkgs.lib.genAttrs nixosHosts (
        hostId: (mkConfiguration hostId).nixosConfiguration
      );

      homeConfigurations = builtins.listToAttrs (
        map (hostId: {
          name = mkHomeConfigurationName hostId;
          value = (mkConfiguration hostId).homeConfiguration;
        }) homeHosts
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          standalonePackages = builtins.listToAttrs (
            map (hostId: {
              name = hostId;
              value = (mkConfiguration hostId).standaloneConfiguration;
            }) (builtins.filter (hostId: hostDefinitions.${hostId}.system == system) standaloneHosts)
          );
        in
        {
          nixfmt = pkgs.nixfmt;
        }
        // standalonePackages
      );

      # Optional: runnable app target
      apps = forAllSystems (system: {
        nixfmt = {
          type = "app";
          program = "${self.packages.${system}.nixfmt}/bin/nixfmt";
          meta = {
            description = "Format Nix files with nixfmt";
          };
        };
      });
    };
}
