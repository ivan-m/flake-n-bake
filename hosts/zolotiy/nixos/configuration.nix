# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, config-variables, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;


    # kernelPackages =  pkgs.linuxPackagesFor (pkgs.linux_6_17.override {
	  #   argsOverride = rec {
		#     src = pkgs.fetchurl {
    #       url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
    #       sha256 = "sha256-3fLqDUQ54dVxNr42IxAq+UWPYB9bHLd+gyRuiK6gnQ4=";
	  #     };
	  #     version = "6.17.7";
	  #     modDirVersion = "6.17.7";
	  #   };
    # });

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 50;
        editor = false;
      };
      efi = {
        canTouchEfiVariables = true;
      };
    };

    initrd = {
      enable = true;
     # verbose = false;
      systemd = {
        enable = true;
      };
      includeDefaultModules = true;
      availableKernelModules = [
        "evdev"
        "dell_laptop"
        "hid_generic"
        "usbhid"
      ];
      kernelModules = [
        "xe"
      ];
      luks = {
        devices = {
          NixOS = {
            device = "/dev/disk/by-uuid/c940fd8d-919b-4cf0-9f1f-88ec3b5e48cf";
            # Has some security implications
            allowDiscards = true;
            bypassWorkqueues = true;
            preLVM = true;
          };
        };
      };
    };

    tmp = {
      useTmpfs = true;
    };

    plymouth = {
      enable = true;
      theme = "hud_space";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "hud_space" ];
        })
      ];
    };

    # Enable "Silent boot"
    consoleLogLevel = 3;
    kernelParams = [
     "quiet"
     "splash"
     "boot.shell_on_fail"
     "udev.log_priority=3"
     "rd.systemd.show_status=auto"
    ];
    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
  };

  # https://wiki.nixos.org/wiki/Full_Disk_Encryption
  services.displayManager.autoLogin.user = "ivan";
  systemd.services.display-manager.serviceConfig.KeyringMode = "inherit";
  security.pam.services.sddm-autologin.text = pkgs.lib.mkBefore ''
    auth optional ${pkgs.systemd}/lib/security/pam_systemd_loadkey.so
    auth include sddm
  '';

  fonts = {
    enableDefaultPackages = true;
    packages = [ pkgs.dejavu_fonts ];
  };

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;

    bluetooth = {
      enable = true;
    };

    cpu = {
      intel = {
        updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };
    };

    firmware = [
      pkgs.sof-firmware # Intel sound DSP firmware
      pkgs.linux-firmware # includes cs35l56-* & friends
      pkgs.alsa-firmware
    ];

    graphics = {
      enable = true;

      enable32Bit = true;

      extraPackages = [
        pkgs.intel-media-driver
        pkgs.mesa
      ];
    };

    intel-gpu-tools = {
      #enable = true;
    };

    ipu6 = {
      #enable = true;
      platform = "ipu6epmtl"; # Actually for Meteor Lake, no Lunar Lake option as yet.
    };

    # seems to require using the nixos-hardware repo, but it's already working so no need?
    # intelgpu = {
    #   driver = "xe";
    #   vaapiDriver = "intel-media-driver";
    # };

    logitech = {
      wireless = {
        enable = true;
        enableGraphical = true;
      };
    };

    printers = {
      ensurePrinters = [
      ];
    };

    sane = {
      enable = true;
      # brscan4 = {
      #   enable = true;
      # };
    };
  };


  i18n = {
    defaultLocale = "en_AU.UTF-8";
    extraLocales = [
    ];

    inputMethod = {
      ibus = {
        engines = with pkgs.ibus-engines; [
          uniemoji
        ];
      };
    };
  };


  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  location = {
    provider = "geoclue2";
  };

  networking = {
    hostName = config-variables.hostname;

    enableIPv6 = true;

    # useDHCP = true; # Doesn't work with networkmanager.

    networkmanager = {
      enable = true;

      # appendNameservers to force a good one?
    };

    interfaces = {
      # Should not use this, setting it more to track the auto-detected interface.
      wlp0s20f3 = {
      };
    };
  };

  powerManagement = {
    enable = true;

    cpuFreqGovernor = "ondemand";

    powertop = {
      #enable = true;
    };
  };

  programs = {
    atop = {
      #enable = true; doesn't work with WiFi 7 use nl80211 instead
    };

    bash = {
      enableLsColors = true;

      completion = {
        enable = true;
      };

      undistractMe = {
        enable = false; # xprop warnings when sudo to root
      };
    };

    command-not-found = {
      enable = true;
    };

    corefreq = {
      enable = false; # not building?
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
    };

    firefox = {
      enable = true;
    };

    git = {
      enable = true;

      package = pkgs.gitFull;
    };

    htop = {
      enable = true;
    };

    iotop = {
      enable = true;
    };

    kdeconnect = {
      enable = true;
    };

    less = {
      enable = true;
    };

    nano = {
      enable = true;
      #nanorc
    };

    screen = {
      enable = true;
    };

    steam = {
      enable = true;

      localNetworkGameTransfers = {
        openFirewall = true;
      };

      remotePlay = {
        openFirewall = true;
      };

      protontricks = {
        enable = true;
      };
    };

    # thefuck = {
    #   enable = true;
    #   alias = "wtf";
    # };

    xwayland = {
      enable = true;
    };
  };

  qt = {
    enable = true;
  };

  security = {
    rtkit = {
      enable = true;
      # Required for pipewire to work
    };
  };

  services = {
    acpid = {
      enable = false; # I think this is handled by the DE
    };

    auto-cpufreq = {
      enable = false; # also by DE?
    };

    ayatana-indicators = {
      enable = true;
    };

    blueman = {
      enable = false;
    };

    desktopManager = {
      cosmic = {
        enable = true;

        xwayland = {
          enable = true;
        };
      };

      plasma6 = {
        enable = true;
      };
    };

    displayManager = {
      enable = true;

      cosmic-greeter = {
        enable = false;
      };

      sddm = {
        enable = true;

        wayland = {
          enable = true;
        };
      };

      defaultSession = "plasma";
    };

    fstrim = {
      enable = true;
    };

    openssh = {
      enable = true;
    };

    printing = {
      enable = true;
    };

    pipewire = {
      enable = true;
      audio = {
        enable = true;
      };
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack = {
        enable = true;
      };
      pulse = {
        enable = true;
      };
      wireplumber = {
        enable = true;
      };
    };

    libinput = {
      enable = true;
    };

    thermald = {
      enable = true;
    };

    uvcvideo = {
      dynctrl = {
        enable = true;

        packages = [ pkgs.tiscamera ];
      };
    };

    xserver = {
      enable = false;
    };

  };

  users = {
    users = {
      ${config-variables.username} = {
        enable = true;
        isNormalUser = true;
        description = config-variables.userDesc;
        extraGroups = [
          "audio"
          "video"
          "networkmanager"
          "input"
          "wheel"
        ];
        packages = with pkgs; [
          guvcview
          dell-command-configure
          emacs-pgtk
          libreoffice-qt
          hunspell
          hunspellDicts.en_AU
          home-manager
        ];
      };
    };
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = config-variables.stateVersion; # Did you read the comment?

  # Set your time zone.
  time.timeZone = "Asia/Singapore";

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
}
