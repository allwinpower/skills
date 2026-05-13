---
name: allwin-deploy-compose
description: Build or audit Docker Compose stacks for the Allwin deploy CLI at /home/user/workspace/deploy, including deploy-tool env files, remote SSH deployment, Compose secrets, external networks, and reusable templates. Use when work mentions allwinpower/deploy, deploy-tool Compose layouts, LocalEnhance deployment templates, or preparing services for this deploy workflow.
---

# Allwin Deploy Compose

## Workflow

Use this skill when creating or reviewing Docker Compose projects that will be managed by the Allwin `deploy` CLI from `/home/user/workspace/deploy`.

When starting a new stack, copy `assets/compose-template/` into the service directory and adapt names, ports, build context, environment variables, volumes, networks, and secrets. Keep the template rules below intact unless the deploy tool itself changes.

For Allwin, Tony, Lifto, or LocalEnhance work, also use `$allwin-project-skills`. Before using or modifying this skill, check the canonical repo for updates and sync the local installed copy when git is authorized. If this skill is incomplete, wrong, ambiguous, environment-incompatible, or a reusable improvement is learned, the task is not complete until a skill-update PR is opened or the exact blocker is reported.

## Required Compose Shape

- Set top-level `name: ${PROJECT}`.
- Do not add a top-level `version:` key.
- Do not use service-level `env_file:` for deploy-tool env files.
- Pass runtime variables explicitly through each service `environment:` block, for example `KEY: ${KEY}`.
- Use `${VAR:?message}` for variables that must fail validation when missing.
- Prefer `restart: unless-stopped` for long-running services.
- Use named volumes for persistent data.
- For shared networks, declare them as external and interpolate their real names.

## Env File Rules

The selected env file is a deploy-tool input. It must be plain dotenv syntax:

```dotenv
PROJECT=my-service
SSH_URI=ssh://admin@example.com
APP_PORT=3000
```

`PROJECT` is required and must match the resolved Compose `name`. `SSH_URI` is optional; when present it enables remote Docker deployment selection. Do not use shell syntax such as `export`, command substitution, chained commands, or semicolons.

The deploy CLI sanitizes env values into a temporary literal dotenv file before passing them to Docker Compose with `--env-file`, so Compose interpolation should be explicit in `docker-compose.yml`.

## Remote Deploy Notes

- Direct actions with `SSH_URI` require `--local` or `--remote`, for example:

```bash
deploy -e service.env -f docker-compose.yml --deploy-all --remote
```

- File-based Compose secrets are copied from the local machine to `/home/<ssh-user>/.deploy_secrets/<project>/` during remote deploys, then referenced through a temporary override file.
- Secret source paths are resolved relative to the Compose file unless absolute.
- Keep real secret files out of git; commit only placeholders such as `.gitkeep` or `.example` files.

## Validation

Before deploying a stack, run:

```bash
docker compose --env-file service.env -f docker-compose.yml config --quiet
```

Then deploy through the tool:

```bash
deploy -e service.env -f docker-compose.yml
deploy -e service.env -f docker-compose.yml --deploy-all --local
deploy -e service.env -f docker-compose.yml --deploy-all --remote
```

Use `--no-cache` only when source-build services must ignore Docker build cache for that run.
