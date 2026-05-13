---
name: allwin-project-skills
description: Route and maintain Allwin project skills. Use whenever work mentions Allwin, Tony, Lifto, LocalEnhance, localenhance-app, lifto, server setup, deployment setup, SSH setup, Docker setup, or Codex skills maintained at allwinpower/skills. Ensures agents use the right installed skill and open skill-update pull requests when a skill fails, is incomplete, or is OS-incompatible.
---

# Allwin Project Skills

## Workflow

Use this skill as the entry point for Allwin, Tony, Lifto, and LocalEnhance work. Before using or modifying Allwin skills, check the canonical skills repo for updates and sync the local installed skill copy so all agents work from the latest guidance. First choose the most specific installed skill for the task, then use that skill's workflow. Combine skills when the task crosses boundaries, such as local SSH setup plus Debian server bootstrap.

Canonical repo: `https://github.com/allwinpower/skills`

Before skill maintenance or sync work, read `references/maintenance.md`. If local or higher-priority instructions block git operations, clearly report that repo-update or PR work is blocked until the user authorizes git.

## Skill Routing

- Use `$local-ssh-setup` for local SSH config, host aliases, identity selection, SSH agent, and forwarding verification.
- Use `$debian-rootless-docker-bootstrap` for Debian 13 server hardening and rootless Docker setup.
- Use `$allwin-deploy-compose` for deploy-tool Docker Compose layouts, env files, secrets, and reusable templates.
- Use `$allwin-localhost-ssh-access` for private localhost-only service exposure through SSH tunnels.
- If no existing skill fits, complete the task with the best available workflow and open a skill-update PR when the missing capability should be reusable.

## Required Improvement Loop

If this skill or any Allwin skill was used and a gap was discovered, the task is not complete until a skill-update PR is opened, or the agent clearly reports the exact blocker that prevented opening one.

A gap includes:

- the skill failed in a real environment;
- the skill was incomplete or ambiguous;
- the skill was incompatible with Linux, macOS, Windows, WSL, a shell, SSH implementation, package manager, or deployment environment;
- the agent learned a reusable fix, verification step, or safety rule that future agents need.

When repo access works and git is authorized, pull latest, create a branch, commit the skill update, push the branch, and open a PR. Do not push directly to `main` unless the user explicitly asks for a direct main push.

After source changes, sync affected skills into `~/.codex/skills/<skill>/` and verify with `diff -qr` so all local agents stay in sync.

## Completion Standard

For Allwin/Tony/Lifto/LocalEnhance tasks that use these skills, final answers must mention any skill gap found and either link/name the opened PR or state why the PR could not be opened.
