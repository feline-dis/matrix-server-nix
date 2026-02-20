{ config, ... }:

{
  services.matrix-tuwunel = {
    enable = true;
    settings.global = {
      server_name = "ohana-matrix.xyz";
      address = [ "127.0.0.1" ];
      port = [ 6167 ];
      max_request_size = 20000000;
      allow_registration = true;
      allow_federation = true;
      trusted_servers = [ "matrix.org" ];
    };
  };

  # Inject the registration token from sops at runtime
  systemd.services.tuwunel.serviceConfig.EnvironmentFile = [
    config.sops.templates."tuwunel-env".path
  ];

  sops.templates."tuwunel-env" = {
    content = ''
      CONDUWUIT_REGISTRATION_TOKEN=${config.sops.placeholder."invite_code"}
    '';
  };

  sops.secrets."invite_code" = { };
}
