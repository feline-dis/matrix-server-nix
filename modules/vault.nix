{ config, lib, pkgs, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "vault" ];

  services.vault = {
    enable = true;
    package = pkgs.vault;
    storageBackend = "raft";
    address = "127.0.0.1:8200";

    storageConfig = ''
      node_id = "ohana"
    '';

    listenerExtraConfig = ''
      tls_min_version = "tls12"
      x_forwarded_for_authorized_addrs = "127.0.0.1"
      x_forwarded_for_hop_skips = "0"
      x_forwarded_for_reject_not_authorized = "false"
      x_forwarded_for_reject_not_present = "false"
    '';

    extraConfig = ''
      ui = true
      disable_mlock = true
      api_addr = "https://vault.felinedev.xyz"
      cluster_addr = "http://127.0.0.1:8201"
    '';
  };

  systemd.services.vault-unseal = {
    description = "Vault auto-unseal";
    after = [ "vault.service" ];
    requires = [ "vault.service" ];
    wantedBy = [ "vault.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.sops.templates."vault-unseal-env".path;
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "${pkgs.vault}/bin/vault operator unseal $VAULT_UNSEAL_KEY";
      Environment = "VAULT_ADDR=http://127.0.0.1:8200";
    };
  };

  sops.templates."vault-unseal-env" = {
    content = ''
      VAULT_UNSEAL_KEY=${config.sops.placeholder."vault/unseal_key"}
    '';
  };

  sops.secrets."vault/unseal_key" = { };
}
