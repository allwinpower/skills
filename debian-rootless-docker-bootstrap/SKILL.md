---
name: debian-rootless-docker-bootstrap
description: Prepare and harden a Debian 13 server over SSH with admin-only key login, root SSH disabled, SSH-agent-backed sudo without passwords, official Docker Engine packages, and Docker running rootless under admin. Use when Codex is asked to bootstrap a fresh Debian host, replace a temporary provider user such as debian, install rootless Docker/Compose from official sources, or produce/execute a safe remote setup plan for this server pattern.
---

# Debian Rootless Docker Bootstrap

## Workflow

Use this skill for Debian 13 `trixie` hosts that should end with exactly one SSH administrator named `admin`, no root SSH access, no password SSH, and Docker rootless under `admin`.

Before changing a host, read `references/operations.md`. Keep the current bootstrap SSH session open until `admin` login, sudo, and rootless Docker are verified from a second session.

## Preferred Automation

Use `scripts/bootstrap_debian13_rootless_docker.sh` on the remote host when the request allows execution. It is intentionally guarded and requires:

```bash
ADMIN_SSH_PUBKEY='ssh-ed25519 ...' \
sudo -E bash bootstrap_debian13_rootless_docker.sh
```

Optional environment variables:

```bash
ADMIN_USER=admin
BOOTSTRAP_USER=debian
SUDO_AUTHORIZED_PUBKEY="$ADMIN_SSH_PUBKEY"
REMOVE_BOOTSTRAP_USER=no
DELETE_BOOTSTRAP_HOME=yes
ALLOW_LOW_PORTS=yes
```

Prefer `SUDO_AUTHORIZED_PUBKEY` only when the key used for sudo should differ from the SSH login key.

## Non-Negotiables

- Install Docker only from Docker's official Debian apt repository.
- Do not leave rootful Docker enabled after rootless Docker is verified.
- Do not use root SSH, root OTP, or root passwords for normal operations.
- Do not remove the bootstrap user until `admin` SSH, `admin` sudo, and rootless Docker all pass verification from a separate SSH session.
- Do not rely on `SSH_CONNECTION` or similar environment variables as sudo authorization; use SSH-agent key proof or choose another explicit sudo model.
- For Compose deploy tools that pass `--env-file` themselves, keep env files as deploy inputs and pass service variables through `environment:` interpolation rather than adding service `env_file:`.

## Verification Commands

Run the checks from a separate local terminal while keeping the original bootstrap session open:

```bash
ssh -A admin@HOST 'whoami'
ssh -A admin@HOST 'sudo -k && sudo -n true && sudo whoami'
ssh -A admin@HOST 'docker info --format "{{json .SecurityOptions}}"'
ssh -A admin@HOST 'docker compose version'
ssh root@HOST 'true'
ssh BOOTSTRAP_USER@HOST 'true'
```

Expected results:

- `admin` login succeeds with key auth and a forwarded agent.
- `sudo whoami` prints `root`.
- Docker security options include rootless mode.
- Docker Compose prints a version.
- Root SSH fails.
- Bootstrap-user SSH fails after cleanup.

After those checks pass, run the script again with `REMOVE_BOOTSTRAP_USER=yes BOOTSTRAP_USER=<initial-user>` to delete the temporary provider account and its home directory.
