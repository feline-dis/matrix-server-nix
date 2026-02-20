# Migration Plan: Ubuntu/Docker -> NixOS on Hetzner Cloud

## Context

The Matrix homeserver stack for `ohana-matrix.xyz` currently runs on a Hetzner Cloud cpx11 VPS (Ubuntu 24.04) using Docker Compose (feline-matrix repo). This migration replaces Ubuntu+Docker with a NixOS system managed declaratively by the `matrix-server-nix` flake, deployed via deploy-rs.

The server keeps its IP (5.78.70.99), so no DNS changes are needed. Conduwuit data (33MB RocksDB) and bot crypto state (176KB SQLite) will be preserved.

---

## Pre-flight (local, no downtime)

### 1. Push companion flake.nix files

The matrix-server-nix flake depends on two GitHub inputs that need working `flake.nix` files:

- **feline-matrix** (`/home/felinedis/develop/feline-matrix/`): Has unpushed commit `572f602` adding flake.nix. Run `git push` in that repo.
- **matrix-claude-bot** (`/home/felinedis/develop/matrix-claude-bot/`): Already pushed. Verify with `git status` -- should be clean.

### 2. Generate server age keypair

The sops `&server` key needs a fresh private key since the old one is lost.

```bash
age-keygen -o /tmp/server-age-key.txt
# Note the public key from output
```

### 3. Update .sops.yaml with new server public key

Replace the `&server` line in `.sops.yaml` with the new public key from step 2.

**File:** `.sops.yaml`

### 4. Re-encrypt secrets with new key

```bash
sops updatekeys secrets/ohana.yaml
```

This re-encrypts the file so both the local key and the new server key can decrypt it.

### 5. Add disko to flake.nix

Add disko as a flake input and its NixOS module to the system config:

**File:** `flake.nix`
- Add input: `disko = { url = "github:nix-community/disko"; inputs.nixpkgs.follows = "nixpkgs"; };`
- Pass `disko` through to `specialArgs`
- Add `disko.nixosModules.disko` to the modules list

### 6. Create disk-config.nix

**New file:** `hosts/ohana/disk-config.nix`

GPT partition table on `/dev/sda`:
- 1MB BIOS boot partition (EF02)
- 512MB ESP (vfat, mounted at `/boot`)
- Remainder as ext4 root

### 7. Import disk-config.nix from the host

**File:** `hosts/ohana/default.nix` -- add `./disk-config.nix` to imports.

### 8. Fix base.nix SSH key

**File:** `modules/base.nix` -- replace the placeholder SSH public key with the actual key from `~/.ssh/hetzner-deploy.pub` (or the key fingerprinted `72:d9:80:...` in hcloud).

### 9. Verify the config evaluates

```bash
git add -A
nix flake check  # or nix eval .#nixosConfigurations.ohana.config.system.build.toplevel
```

---

## Backup (on server, brief read-only window)

### 10. Backup conduwuit data and bot state

SSH into the server and copy data locally before wiping:

```bash
ssh -i ~/.ssh/hetzner-deploy root@5.78.70.99

# On server:
docker compose -f ~/feline-matrix/docker-compose.yml stop conduwuit
tar czf /tmp/conduwuit-backup.tar.gz -C /var/lib/docker/volumes/feline-matrix_conduwuit_data/_data .
tar czf /tmp/bot-backup.tar.gz -C /opt/matrix-claude-bot matrix-claude-bot.db matrix-claude-bot.db-shm matrix-claude-bot.db-wal
```

Then pull backups locally:

```bash
scp -i ~/.ssh/hetzner-deploy root@5.78.70.99:/tmp/conduwuit-backup.tar.gz /tmp/
scp -i ~/.ssh/hetzner-deploy root@5.78.70.99:/tmp/bot-backup.tar.gz /tmp/
```

---

## Install NixOS (destructive, downtime starts)

### 11. Run nixos-anywhere

nixos-anywhere will kexec into a NixOS installer, run disko to partition the disk, install the NixOS configuration, and reboot. The `--extra-files` flag provisions the server age key so sops-nix can decrypt secrets on first boot.

Prepare extra files:

```bash
mkdir -p /tmp/ohana-extra/var/lib/sops-nix
cp /tmp/server-age-key.txt /tmp/ohana-extra/var/lib/sops-nix/key.txt
chmod 600 /tmp/ohana-extra/var/lib/sops-nix/key.txt
```

Run the install:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --extra-files /tmp/ohana-extra \
  --generate-hardware-config nixos-generate-config \
  ./hosts/ohana/hardware-configuration.nix \
  --flake .#ohana \
  --ssh-option "-i" --ssh-option "$HOME/.ssh/hetzner-deploy" \
  root@5.78.70.99
```

The `--generate-hardware-config` flag auto-populates `hardware-configuration.nix` with real hardware detection, replacing the placeholder. **Commit this generated file afterward.**

If it fails due to RAM pressure (2GB is tight), retry with `--no-disko-deps`.

### 12. Verify SSH access to new NixOS system

```bash
ssh -i ~/.ssh/hetzner-deploy root@5.78.70.99 'nixos-version'
```

---

## Restore Data (on NixOS, downtime continues)

### 13. Restore conduwuit database

Tuwunel's NixOS module stores data at `/var/lib/conduwuit/` (the `DynamicUser` or service user's state directory). Upload and extract:

```bash
scp -i ~/.ssh/hetzner-deploy /tmp/conduwuit-backup.tar.gz root@5.78.70.99:/tmp/
ssh -i ~/.ssh/hetzner-deploy root@5.78.70.99 '
  systemctl stop tuwunel
  mkdir -p /var/lib/conduwuit
  tar xzf /tmp/conduwuit-backup.tar.gz -C /var/lib/conduwuit/
  chown -R conduwuit:conduwuit /var/lib/conduwuit/ 2>/dev/null || true
  systemctl start tuwunel
'
```

Note: The exact user/group ownership depends on how `services.matrix-tuwunel` creates the service user. We will verify after the first boot and adjust accordingly.

### 14. Restore bot crypto database

```bash
scp -i ~/.ssh/hetzner-deploy /tmp/bot-backup.tar.gz root@5.78.70.99:/tmp/
ssh -i ~/.ssh/hetzner-deploy root@5.78.70.99 '
  systemctl stop matrix-claude-bot
  mkdir -p /var/lib/matrix-claude-bot
  tar xzf /tmp/bot-backup.tar.gz -C /var/lib/matrix-claude-bot/
  chown -R matrix-claude-bot:matrix-claude-bot /var/lib/matrix-claude-bot/
  systemctl start matrix-claude-bot
'
```

---

## Verify (downtime ends)

### 15. Check all services are running

```bash
ssh -i ~/.ssh/hetzner-deploy root@5.78.70.99 '
  systemctl status tuwunel caddy livekit lk-jwt-service registration-proxy matrix-claude-bot
'
```

### 16. Test endpoints

```bash
# Well-known endpoints
curl -s https://ohana-matrix.xyz/.well-known/matrix/client | jq .
curl -s https://ohana-matrix.xyz/.well-known/matrix/server | jq .

# Federation (port 8448)
curl -sk https://ohana-matrix.xyz:8448/_matrix/federation/v1/version | jq .

# Homeserver version
curl -s https://ohana-matrix.xyz/_matrix/client/versions | jq .

# Registration page
curl -s -o /dev/null -w '%{http_code}' https://ohana-matrix.xyz/register/

# Element Web
curl -s -o /dev/null -w '%{http_code}' https://chat.ohana-matrix.xyz/
```

### 17. Test Matrix federation

Use the [Matrix Federation Tester](https://federationtester.matrix.org/) to verify `ohana-matrix.xyz` passes all checks.

---

## Cleanup

### 18. Commit generated hardware-configuration.nix

nixos-anywhere will have written the real hardware config. Commit it.

### 19. Remove old Docker deployment from server

The old Ubuntu system is gone (wiped by nixos-anywhere), so the Docker Compose stack, bot binary at `/opt/matrix-claude-bot/`, and systemd unit are all already removed. Nothing to clean up on the server side.

### 20. Delete local temporary files

```bash
rm /tmp/server-age-key.txt /tmp/conduwuit-backup.tar.gz /tmp/bot-backup.tar.gz
rm -rf /tmp/ohana-extra
```

### 21. First deploy-rs deployment

After everything is verified, do a standard deploy-rs cycle to confirm the ongoing workflow works:

```bash
deploy .#ohana
```

---

## Files Modified/Created

| File | Action |
|------|--------|
| `flake.nix` | Add disko input and module |
| `.sops.yaml` | Replace server age public key |
| `secrets/ohana.yaml` | Re-encrypt with new server key |
| `hosts/ohana/default.nix` | Add disk-config.nix import |
| `hosts/ohana/disk-config.nix` | **New** -- disko partition layout |
| `hosts/ohana/hardware-configuration.nix` | Auto-generated by nixos-anywhere |
| `modules/base.nix` | Replace placeholder SSH public key |

## Estimated Downtime

~15-20 minutes: from stopping conduwuit for backup (step 10) through verification (step 16). The nixos-anywhere install itself takes ~5-10 minutes on a cpx11.
