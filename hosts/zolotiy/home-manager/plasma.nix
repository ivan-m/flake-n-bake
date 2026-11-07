{ options, pkgs, ... }:
{
  programs.plasma = {
    enable = true;
    overrideConfig = true;
    resetFilesExclude = [
      "kdeconnect"
      "kwalletrc"
    ];
    # These settings files are not included in Plasma Manager's default reset list.
    resetFiles = options.programs.plasma.resetFiles.default ++ [ "plasmaparc" ];

    # Reference only: the current hardware-specific audio state. Leave disabled
    # so Plasma can recreate it for the active audio devices.
    # configFile.plasmaparc.General.GlobalMuteSinks = true;
    # configFile.plasmaparc.General.GlobalMuteSinksMutedDevices =
    #   "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink.0,alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__HDMI1__sink.0,alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__HDMI2__sink.0,alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__HDMI3__sink.0";

    workspace.wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/EveningGlow/contents/images/2560x1600.jpg";

    panels = [
      {
        location = "bottom";
        floating = false;
        widgets = [
          {
            kickoff = {
              icon = "nix-snowflake";
              sortAlphabetically = true;
            };
          }
          {
            iconTasks = {
              iconsOnly = false;
              launchers = [ ]; # No launchers
            };
          }
          "org.kde.plasma.marginsseparator"
          {
            systemTray = {
              items = {
                extra = [
                  "org.kde.plasma.manage-inputmethod"
                  "org.kde.plasma.clipboard"
                  "org.kde.plasma.cameraindicator"
                  "org.kde.kdeconnect"
                  "org.kde.plasma.bluetooth"
                  "org.kde.plasma.keyboardlayout"
                  "org.kde.plasma.mediacontroller"
                  "org.kde.plasma.notifications"
                  "org.kde.plasma.devicenotifier"
                  "org.kde.plasma.printmanager"
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.brightness"
                  "org.kde.plasma.volume"
                  "org.kde.plasma.keyboardindicator"
                  "org.kde.kscreen"
                  "org.kde.plasma.battery"
                ];
                shown = [
                  "org.kde.plasma.battery"
                ];
                hidden = [
                  "org.kde.plasma.clipboard"
                  "org.kde.plasma.brightness"
                ];
              };
            };
          }
          "org.kde.plasma.digitalclock"
        ];
      }
    ];

    kscreenlocker = {
      timeout = 15;
      passwordRequiredDelay = 900;
    };

    input = {
      keyboard = {
        layouts = [
          { layout = "us"; }
          {
            layout = "ua";
            variant = "homophonic";
          }
        ];
        options = [
          "grp:shifts_toggle"
          "caps:ctrl_modifier"
        ];
      };
      touchpads = [
        {
          name = "VEN_0488:00 0488:1083 Touchpad";
          vendorId = "0488";
          productId = "1083";
          rightClickMethod = "twoFingers";
          tapToClick = true;
          # LRM mapping: two-finger tap right-clicks; three-finger tap middle-clicks.
          twoFingerTap = "rightClick";
        }
      ];
    };

    powerdevil.AC = {
      autoSuspend.action = "nothing";
      whenLaptopLidClosed = "doNothing";
    };

    kwin = {
      virtualDesktops = {
        number = 1;
        rows = 1;
      };
      effects.zoom.zoomFactor = 1.05;
      tiling = {
        padding = 4;
        layout = {
          id = "0dd9195a-af3f-4521-9fb5-3cc2af256fbe";
          tiles = {
            layoutDirection = "horizontal";
            tiles = [
              { width = 0.25; }
              { width = 0.5; }
              { width = 0.25; }
            ];
          };
        };
      };
    };

    shortcuts = {
      "KDE Keyboard Layout Switcher" = {
        "Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
        "Switch to Next Keyboard Layout" = "Meta+Alt+K";
      };
      kwin = {
        "Edit Tiles" = "Meta+T";
        Overview = "Meta+W";
        "Show Desktop" = "Meta+D";
        "Window Quick Tile Left" = "Meta+Left";
        "Window Quick Tile Right" = "Meta+Right";
        "Window Quick Tile Top" = "Meta+Up";
        "Window Quick Tile Bottom" = "Meta+Down";
      };
    };

    configFile = {
      # Keep KDED's device automounter disabled.
      kded5rc.Module-device_automounter.autoload = false;
      dolphinrc.MainWindow.MenuBar = "Disabled";
      kdeglobals.General.UseSystemBell = true;
    };
  };
}
