{ config, ... }:

{
  services.livekit = {
    enable = true;
    openFirewall = false; # Handled by firewall.nix
    keyFile = config.sops.secrets."livekit_keyfile".path;
    settings = {
      port = 7880;
      rtc = {
        tcp_port = 7881;
        port_range_start = 50000;
        port_range_end = 50200;
        use_external_ip = true;
      };
      room = {
        auto_create = true;
      };
      turn = {
        enabled = false;
      };
    };
  };

  services.lk-jwt-service = {
    enable = true;
    livekitUrl = "wss://ohana-matrix.xyz/livekit/sfu";
    port = 8080;
    keyFile = config.sops.secrets."livekit_keyfile".path;
  };

  # Not exposed as a module option
  systemd.services.lk-jwt-service.environment = {
    LIVEKIT_FULL_ACCESS_HOMESERVERS = "ohana-matrix.xyz";
  };

  sops.secrets."livekit_keyfile" = {
    mode = "0440";
  };
}
