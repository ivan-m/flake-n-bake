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
  };
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, ... }:
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
      configuration = config-variables: {
        nixosConfiguration = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs config-variables;
          };
          modules = [./hosts/${config-variables.hostname}/nixos/configuration.nix];
        };
        homeConfiguration = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${config-variables.system};
          extraSpecialArgs = {inherit inputs outputs config-variables;};
          modules = [./hosts/${config-variables.hostname}/home-manager/home.nix];
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
      };
    in {
      nixosConfigurations = {
        zolotiy = zolotiy.nixosConfiguration;
      };

      homeConfigurations = {
        # Can we somehow get this to be based upon the username?
        "ivan@zolotiy" = zolotiy.homeConfiguration;
      };
    };
}
