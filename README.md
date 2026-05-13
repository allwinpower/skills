# Allwin Codex Skills

Reusable Codex skills maintained for Allwin projects.

## Available Skills

### Debian Rootless Docker Bootstrap

Path: `debian-rootless-docker-bootstrap`

Prepares a fresh Debian 13 server with:

- `admin` as the only SSH-login user
- root SSH disabled
- password SSH disabled
- sudo authorized through forwarded SSH-agent key proof
- Docker Engine and Compose installed from Docker's official Debian repository
- Docker running rootless under `admin`

## Install

In Codex, ask:

```text
Use $skill-installer to install from https://github.com/allwinpower/skills/tree/main/debian-rootless-docker-bootstrap
```

For an SSH-authenticated or private-repo install, ask Codex to use the installer with the repo and path:

```text
Use $skill-installer to install --repo allwinpower/skills --path debian-rootless-docker-bootstrap --method git
```

Restart Codex after installing new skills.

## Usage

After install, ask Codex:

```text
Use $debian-rootless-docker-bootstrap to prepare a Debian 13 server with admin-only SSH and rootless Docker.
```

The skill includes a guarded bootstrap script and an operations reference. It is designed for a two-phase flow: first create and verify `admin`, then remove the provider bootstrap user only after a separate `admin` SSH session is proven.

## Notes

- The bootstrap script is intended for Debian 13 `trixie`.
- Keep provider console or rescue access available before removing the bootstrap user.
- No license is granted unless one is added to this repository.
