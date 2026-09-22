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

    # Optional Emacs config flake input (can be overridden per system)
    # emacs-config = {
    #   url = "github:yourusername/emacs-config";
    #   flake = false;  # Just get the files, not a full flake output
    # };
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
          # Intelligently determine the Emacs config source and type
          emacsConfigResolved =
            if config-variables ? emacsConfig then
              let
                cfg = config-variables.emacsConfig;
                # If it's a string, treat it as a path; otherwise it's a flake input
                isPath = builtins.isString cfg;
                source = if isPath then cfg else cfg; # Already resolved flake input
              in
              {
                source = source;
                isPath = isPath;
              }
            else
              {
                source = null;
                isPath = false;
              };
          commonSpecialArgs = {
            inherit
              inputs
              outputs
              config-variables
              emacs-overlay
              ;

            emacsConfigSource = emacsConfigResolved.source;
            emacsConfigIsPath = emacsConfigResolved.isPath;
          };

          pkgs = nixpkgs.legacyPackages.${config-variables.system};
        in
        {
          nixosConfiguration = nixpkgs.lib.nixosSystem {
            specialArgs = commonSpecialArgs;
            modules = [ ./hosts/${config-variables.hostId}/nixos/configuration.nix ];
          };
          homeConfiguration = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = commonSpecialArgs;
            modules = [ ./hosts/${config-variables.hostId}/home-manager/home.nix ];
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
          emacsConfig = "code/emacs";
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
        };
      });
    };
}
