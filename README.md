# Allwin Codex Skills

Reusable Codex skills maintained for Allwin, Tony, Lifto, and LocalEnhance projects.

Canonical repo: <https://github.com/allwinpower/skills>

## Available Skills

### Allwin Project Skills

Path: `allwin-project-skills`

Routes Allwin/Tony/Lifto/LocalEnhance work to the right installed skill and requires skill-update pull requests when a reusable gap is discovered.

### Local SSH Setup

Path: `local-ssh-setup`

Configures and verifies local SSH aliases, identity files, SSH agent loading, agent forwarding, and multiplexing-safe checks.

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
Use $skill-installer to install from https://github.com/allwinpower/skills/tree/main/allwin-project-skills
```

For an SSH-authenticated or private-repo install, ask Codex to use the installer with the repo and paths:

```text
Use $skill-installer to install --repo allwinpower/skills --path allwin-project-skills local-ssh-setup debian-rootless-docker-bootstrap --method git
```

Restart Codex after installing new skills.

## Usage

For Allwin, Tony, Lifto, or LocalEnhance work, start with:

```text
Use $allwin-project-skills for this task.
```

Then use the specific skill it routes to, such as `$local-ssh-setup` or `$debian-rootless-docker-bootstrap`.

## Skill Maintenance

If a skill fails, is incomplete, or is OS-incompatible, the task is not complete until a skill-update pull request is opened, or the exact blocker is reported.

When repo access works:

1. Pull latest from `git@github.com:allwinpower/skills.git`.
2. Create `skill-update/<short-topic>` from `main`.
3. Commit the skill update.
4. Push the branch to `origin`.
5. Open a PR against `main`.

Do not push directly to `main` unless explicitly requested.

## Notes

- The Debian bootstrap script is intended for Debian 13 `trixie`.
- Keep provider console or rescue access available before removing bootstrap users.
- No license is granted unless one is added to this repository.
