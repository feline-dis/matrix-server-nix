{ pkgs, ... }:

let
  wellKnownClient = builtins.toJSON {
    "m.homeserver" = {
      base_url = "https://ohana-matrix.xyz";
    };
    "org.matrix.msc4143.rtc_foci" = [
      {
        type = "livekit";
        livekit_service_url = "https://ohana-matrix.xyz/livekit/jwt";
      }
    ];
  };

  wellKnownServer = builtins.toJSON {
    "m.server" = "ohana-matrix.xyz:8448";
  };
in
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "ohana-matrix.xyz" = {
        extraConfig = ''
          handle /.well-known/matrix/client {
            header Content-Type application/json
            header Access-Control-Allow-Origin *
            respond `${wellKnownClient}`
          }

          handle /.well-known/matrix/server {
            header Content-Type application/json
            respond `${wellKnownServer}`
          }

          handle_path /livekit/jwt* {
            reverse_proxy localhost:8080
          }

          handle_path /livekit/sfu* {
            reverse_proxy localhost:7880
          }

          handle_path /sfu/get* {
            reverse_proxy localhost:8080
          }

          handle {
            reverse_proxy localhost:8008
          }
        '';
      };

      "chat.ohana-matrix.xyz" = {
        extraConfig = ''
          root * ${pkgs.element-web-ohana}
          encode gzip
          file_server
        '';
      };

      "jelly.felinedev.xyz" = {
        extraConfig = ''
          reverse_proxy 100.75.8.52:8096
        '';
      };

      "ohana-matrix.xyz:8448" = {
        extraConfig = ''
          reverse_proxy localhost:6167
        '';
      };
    };
  };
}
