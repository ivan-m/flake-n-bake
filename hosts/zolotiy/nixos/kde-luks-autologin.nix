# https://wiki.nixos.org/wiki/KDE#Unlock_KDE_Wallet_with_LUKS_password

{
  config-variables,
  pkgs,
  ...
}:

{
  # NixOS 26.05+ uses the systemd initrd by default; the enable option was removed.

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = config-variables.username;
    };

    plasma-login-manager.enable = true;
  };

  systemd.services.plasmalogin.serviceConfig.KeyringMode = "inherit";

  security.pam.services.plasmalogin-autologin.rules.auth = {
    systemd_loadkey = {
      order = 0;
      control = "optional";
      modulePath = "${pkgs.systemd}/lib/security/pam_systemd_loadkey.so";
    };
    plasmalogin = {
      order = 1;
      control = "include";
      modulePath = "plasmalogin";
    };
  };
}
