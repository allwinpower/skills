# Skill Repo Agent Instructions

- This directory is the source repo for reusable Codex skills.
- For normal work, do not run `git` commands unless the user explicitly asks for a `git` operation.
- Exception: for reusable skill maintenance in this directory, `git` operations are authorized by default when needed to publish the skill fix. If an agent discovers and fixes a reusable skill gap here, it should update the local skill source, sync the installed copy under `~/.codex/skills`, verify the sync, then create a branch, commit, push, and open a pull request unless a higher-priority instruction or missing credential blocks it.
- Do not push directly to `main` unless the user explicitly asks for a direct main push.
- For Docker Compose projects deployed with the user's deploy tool from `/home/user/workspace/deploy`, keep project env files such as `visireach.env` as deploy-tool inputs only. Do not add them under a service `env_file:` in `docker-compose.yml`.
- In those Compose files, pass runtime variables explicitly through the service `environment:` block using interpolation, for example `KEY: ${KEY}`. The deploy tool provides values through `docker compose --env-file <env>`.
- Compose files for that deploy tool should use top-level `name: ${PROJECT}` and the selected env file must define `PROJECT`. `SSH_URI` is optional and controls remote deployment selection.
