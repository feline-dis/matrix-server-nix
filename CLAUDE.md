# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

NixOS flake that deploys a Matrix homeserver stack to `ohana-matrix.xyz`. Uses deploy-rs for deployment and sops-nix for secrets management.

## Commands

```bash
# Enter dev shell (provides deploy-rs, sops, age, ssh-to-age)
nix develop

# Evaluate the NixOS configuration (catches syntax/type errors without building)
nix eval .#nixosConfigurations.ohana.config.system.build.toplevel --no-build 2>&1 | head

# Build the full system closure locally
nix build .#nixosConfigurations.ohana.config.system.build.toplevel

# Deploy to the server
deploy .#ohana

# Deploy with local input overrides (for testing changes to companion repos)
deploy .#ohana --override-input feline-matrix path:/home/felinedis/develop/feline-matrix

# Edit encrypted secrets
sops secrets/ohana.yaml
```

## Architecture

### Flake Inputs
- **nixpkgs** (unstable): Base packages and NixOS modules
- **feline-matrix**: Registration proxy (Go binary, separate repo)
- **matrix-claude-bot**: Claude AI bot for Matrix (Go binary, separate repo)
- **sops-nix**: Secret decryption at activation time
- **deploy-rs**: Push-based deployment with magic rollback

### Host: ohana
Single host (`hosts/ohana/`) importing all modules. Domain: `ohana-matrix.xyz`.

### Module Responsibilities
Each module in `modules/` is self-contained with its own service config and secrets:

- **tuwunel.nix** -- Matrix homeserver (port 6167). Registration token injected via `CONDUWUIT_REGISTRATION_TOKEN` env var from sops template. Systemd unit: `tuwunel.service`.
- **registration-proxy.nix** -- Invite-gated registration (port 8008). Custom systemd service using the `feline-matrix` flake input. Shares `invite_code` secret with tuwunel.
- **caddy.nix** -- Reverse proxy and static file server. Routes: well-known Matrix endpoints, LiveKit JWT/SFU paths, Element Web on `chat.ohana-matrix.xyz`, federation on `:8448`.
- **livekit.nix** -- LiveKit SFU (port 7880) and lk-jwt-service (port 8080). Both share `livekit_keyfile` secret.
- **element-web.nix** -- Builds Element Web with baked-in config via `pkgs.element-web.override`. Exposes the package as `pkgs.element-web-ohana` through an overlay so caddy.nix can reference it.
- **claude-bot.nix** -- Matrix Claude bot. Config JSON assembled from sops placeholders via `sops.templates`. Needs three secrets under `bot/`.
- **firewall.nix** -- TCP: 22, 80, 443, 8448, 7881. UDP: 443 (QUIC), 50000-50200 (WebRTC).
- **base.nix** -- Nix settings, SSH hardening, system packages.

### Secrets
Managed by sops-nix with age encryption. Two age keys in `.sops.yaml`: local workstation and server. Secrets file: `secrets/ohana.yaml`.

Secrets are consumed via two patterns:
1. **`sops.templates`** -- Generates files from sops placeholders (used by tuwunel, registration-proxy, claude-bot)
2. **`sops.secrets.*.path`** -- Direct file path reference (used by livekit, lk-jwt-service)

### Routing Overview
```
Internet -> Caddy (443/8448)
  ohana-matrix.xyz/* -> registration-proxy (8008) -> tuwunel (6167)
  ohana-matrix.xyz/.well-known/matrix/* -> inline JSON responses
  ohana-matrix.xyz/livekit/jwt* -> lk-jwt-service (8080)
  ohana-matrix.xyz/livekit/sfu* -> livekit (7880)
  ohana-matrix.xyz:8448 -> tuwunel (6167)  [federation]
  chat.ohana-matrix.xyz -> element-web-ohana static files
```

## Nix-Specific Notes

- Flakes only see git-tracked files. Run `git add` on new files before `nix build` or `nix eval`.
- The `services.matrix-tuwunel` option `address` takes a **list** of strings, not a single string.
- nixpkgs Go version constrains what companion repos can require in their `go.mod`.
