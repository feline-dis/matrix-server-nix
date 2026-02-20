{ flakeRevision, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/base.nix
    ../../modules/firewall.nix
    ../../modules/tuwunel.nix
    ../../modules/registration-proxy.nix
    ../../modules/caddy.nix
    ../../modules/livekit.nix
    ../../modules/element-web.nix
    ../../modules/claude-bot.nix
    ../../modules/alloy.nix
    ../../modules/fail2ban.nix
  ];

  networking.hostName = "ohana";
  networking.domain = "ohana-matrix.xyz";

  sops = {
    defaultSopsFile = ../../secrets/ohana.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };

  system.configurationRevision = flakeRevision;
  system.stateVersion = "25.05";
}
