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
        in
        {
          nixosConfiguration = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit
                inputs
                outputs
                config-variables
                emacs-overlay
                ;
            };
            modules = [ ./hosts/${config-variables.hostname}/nixos/configuration.nix ];
          };
          homeConfiguration = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.${config-variables.system};
            extraSpecialArgs = {
              inherit
                inputs
                outputs
                config-variables
                emacs-overlay
                ;
              emacsConfigSource = emacsConfigResolved.source;
              emacsConfigIsPath = emacsConfigResolved.isPath;
            };
            modules = [ ./hosts/${config-variables.hostname}/home-manager/home.nix ];
          };
        };

      zolotiy = configuration {
        # Don't change the original stateVersion, it's used to track the version of the configuration.
        stateVersion = "25.05";
        # Would be cool if we could get some kind of self-reflection going on here to pick this up from the variable name...
        hostname = "zolotiy";
        username = "ivan";
        userDesc = "Ivan Lazar Miljenovic";
        system = "x86_64-linux";
        # This is the path to the root of the flake repository, relative to the home directory.
        repoRoot = "code/flakes";
        # Can be either:
        # - A string (local path): "code/emacs"
        # - A flake input reference: inputs.emacs-config
        # - Not specified at all.
        emacsConfig = "code/emacs";
      };
    in
    {
      nixosConfigurations = {
        zolotiy = zolotiy.nixosConfiguration;
      };

      homeConfigurations = {
        # Can we somehow get this to be based upon the username?
        "ivan@zolotiy" = zolotiy.homeConfiguration;
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Optional but handy: direct package exposure
      packages = forAllSystems (system: {
        nixfmt = nixpkgs.legacyPackages.${system}.nixfmt;
      });

      # Optional: runnable app target
      apps = forAllSystems (system: {
        nixfmt = {
          type = "app";
          program = "${self.packages.${system}.nixfmt}/bin/nixfmt";
        };
      });
    };
}
