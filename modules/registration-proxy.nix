{ config, feline-matrix, ... }:

let
  registrationProxy = feline-matrix.packages.x86_64-linux.registration-proxy;
in
{
  users.users.registration-proxy = {
    isSystemUser = true;
    group = "registration-proxy";
  };
  users.groups.registration-proxy = { };

  systemd.services.registration-proxy = {
    description = "Matrix registration proxy";
    after = [ "network.target" "tuwunel.service" ];
    requires = [ "tuwunel.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HOMESERVER_URL = "http://127.0.0.1:6167";
    };

    serviceConfig = {
      ExecStart = "${registrationProxy}/bin/registration-proxy";
      EnvironmentFile = config.sops.templates."registration-proxy-env".path;
      User = "registration-proxy";
      Group = "registration-proxy";
      Restart = "on-failure";
      RestartSec = 5;

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
    };
  };

  sops.templates."registration-proxy-env" = {
    content = ''
      INVITE_CODE=${config.sops.placeholder."invite_code"}
    '';
  };
}
