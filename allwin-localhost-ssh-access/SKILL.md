---
name: allwin-localhost-ssh-access
description: Expose private Docker Compose services only on a remote host's localhost and access them from a developer machine through SSH local port forwarding. Use for Allwin, LocalEnhance, or deploy-tool services that must not be exposed through edge gateways, Cloudflare, public ports, or 0.0.0.0 bindings.
---

# Allwin Localhost SSH Access

## Workflow

Use this skill when a service should remain private on the remote host and be reached from a developer machine through an SSH tunnel.

For deploy-tool Compose rules such as `name: ${PROJECT}`, dotenv syntax, and explicit service `environment:` interpolation, also use `$allwin-deploy-compose`.

For Allwin, Tony, Lifto, or LocalEnhance work, also use `$allwin-project-skills`. Before using or modifying this skill, check the canonical repo for updates and sync the local installed copy when git is authorized. If this skill is incomplete, wrong, ambiguous, environment-incompatible, or a reusable improvement is learned, the task is not complete until a skill-update PR is opened or the exact blocker is reported.

## Compose Access Pattern

- Bind host ports only to remote loopback:

```yaml
ports:
  - "127.0.0.1:${REMOTE_ACCESS_PORT}:${SERVICE_PORT}"
```

- Do not publish access ports as `0.0.0.0:${PORT}:${PORT}` or `${PORT}:${PORT}`.
- Do not add edge labels, Cloudflare tunnels, public gateway services, nginx edge exposure, or public networks for this access pattern.
- Prefer high, non-privileged remote ports for rootless Docker.
- Use a separate access Compose project only when it is actually starting or recreating the service with a loopback-only port binding. A second Compose project cannot add host port publishing to an already-running container without recreating/proxying something.

## Port Selection

Check the remote host before assigning `REMOTE_ACCESS_PORT`:

```bash
ssh user@host 'ss -ltn'
```

Choose a local developer port that is free on the local machine:

```bash
ss -ltn
```

If local `ss` is unavailable, use the platform's equivalent port listing command.

## Tunnel Command

Start the tunnel from the developer machine:

```bash
ssh -N -L 127.0.0.1:${LOCAL_TUNNEL_PORT}:127.0.0.1:${REMOTE_ACCESS_PORT} user@host
```

Keep that process open while using the service. Stop it when finished.

Use multiplexing-safe options when stale SSH control sockets could hide tunnel failures:

```bash
ssh -N -o ControlMaster=no -o ControlPath=none -L 127.0.0.1:${LOCAL_TUNNEL_PORT}:127.0.0.1:${REMOTE_ACCESS_PORT} user@host
```

## Deploy Tool Flow

Validate the access stack:

```bash
docker compose --env-file access.env -f docker-compose.yml config --quiet
```

Deploy remotely:

```bash
deploy -e access.env -f docker-compose.yml --deploy-all --remote
```

If `SSH_URI` is set in the env file, direct deploy actions require `--remote` or `--local`.

## Verification

After the tunnel starts, verify from the developer machine using the service protocol:

```bash
curl -i http://127.0.0.1:${LOCAL_TUNNEL_PORT}/
```

For databases or non-HTTP services, use the normal local client pointed at `127.0.0.1:${LOCAL_TUNNEL_PORT}`.

When access is no longer needed, stop the SSH tunnel and stop or undeploy temporary access Compose projects.
