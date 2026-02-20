# matrix-server-nix

NixOS flake that declaratively deploys a Matrix homeserver stack to `ohana-matrix.xyz`.

## Stack

| Service | Port | Description |
|---|---|---|
| [tuwunel](https://github.com/continuwuity/tuwunel) | 6167 | Matrix homeserver (conduwuit fork) |
| [registration-proxy](https://github.com/feline-dis/ohana-matrix-server-registration) | 8008 | Invite-gated registration frontend |
| [Caddy](https://caddyserver.com/) | 80, 443, 8448 | Reverse proxy, TLS, static files |
| [LiveKit](https://livekit.io/) | 7880, 7881, 50000-50200/udp | WebRTC SFU for calls |
| [lk-jwt-service](https://github.com/element-hq/lk-jwt-service) | 8080 | LiveKit JWT token service |
| [Element Web](https://element.io/) | via Caddy | Web client at `chat.ohana-matrix.xyz` |
| [matrix-claude-bot](https://github.com/feline-dis/matrix-claude-bot) | -- | Claude AI bot |

## Request flow

```
Internet -> Caddy (443/8448)
  ohana-matrix.xyz/*                -> registration-proxy (8008) -> tuwunel (6167)
  ohana-matrix.xyz/.well-known/*    -> inline JSON responses
  ohana-matrix.xyz/livekit/jwt*     -> lk-jwt-service (8080)
  ohana-matrix.xyz/livekit/sfu*     -> livekit (7880)
  ohana-matrix.xyz:8448             -> tuwunel (6167)  [federation]
  chat.ohana-matrix.xyz             -> Element Web static files
```

## Secrets

Managed by [sops-nix](https://github.com/Mic92/sops-nix) with age encryption. Edit with `sops secrets/ohana.yaml`.

| Secret | Used by |
|---|---|
| `invite_code` | tuwunel registration token, registration-proxy |
| `livekit_keyfile` | livekit, lk-jwt-service |
| `bot/matrix_access_token` | claude-bot |
| `bot/anthropic_api_key` | claude-bot |
| `bot/crypto_pickle_key` | claude-bot |

## Deploy

Pushes to `master` trigger a GitHub Actions workflow that SSHes into the server and runs `nixos-rebuild switch`.

To deploy manually:

```bash
nix develop -c deploy .#ohana
```

To deploy with local changes to a companion repo:

```bash
nix develop -c deploy .#ohana --override-input feline-matrix path:../ohana-matrix-server-registration
```

## Verify deployment

```bash
ssh root@ohana-matrix.xyz nixos-version --configuration-revision
```

The output is the git commit hash of the deployed configuration.
