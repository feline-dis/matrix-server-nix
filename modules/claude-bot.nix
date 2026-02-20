{ config, matrix-claude-bot, ... }:

let
  botPackage = matrix-claude-bot.packages.x86_64-linux.default;
  configPath = config.sops.templates."claude-bot-config.json".path;
in
{
  users.users.matrix-claude-bot = {
    isSystemUser = true;
    group = "matrix-claude-bot";
    home = "/var/lib/matrix-claude-bot";
  };
  users.groups.matrix-claude-bot = { };

  systemd.services.matrix-claude-bot = {
    description = "Matrix Claude bot";
    after = [ "network-online.target" "tuwunel.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${botPackage}/bin/claude-bot -config ${configPath}";
      User = "matrix-claude-bot";
      Group = "matrix-claude-bot";
      StateDirectory = "matrix-claude-bot";
      WorkingDirectory = "/var/lib/matrix-claude-bot";
      Restart = "on-failure";
      RestartSec = 10;

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      ReadWritePaths = [ "/var/lib/matrix-claude-bot" ];
    };
  };

  sops.templates."claude-bot-config.json" = {
    owner = "matrix-claude-bot";
    content = builtins.toJSON {
      matrix = {
        homeserver_url = "https://ohana-matrix.xyz";
        user_id = "@claude:ohana-matrix.xyz";
        access_token = config.sops.placeholder."bot/matrix_access_token";
      };
      anthropic = {
        api_key = config.sops.placeholder."bot/anthropic_api_key";
      };
      claude = {
        model = "claude-sonnet-4-20250514";
        max_tokens = 4096;
        system_prompt = "You are a helpful assistant in a Matrix chat room.";
      };
      tools = {
        web_search_enabled = true;
        sandbox_dir = "/var/lib/matrix-claude-bot/sandbox";
        max_iterations = 10;
        timeout_seconds = 30;
      };
      crypto = {
        pickle_key = config.sops.placeholder."bot/crypto_pickle_key";
        database_path = "/var/lib/matrix-claude-bot/matrix-claude-bot.db";
      };
    };
  };

  sops.secrets."bot/matrix_access_token" = { };
  sops.secrets."bot/anthropic_api_key" = { };
  sops.secrets."bot/crypto_pickle_key" = { };
}
