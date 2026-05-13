# Debian 13 Rootless Docker Bootstrap Operations

## Safety Sequence

1. Connect with the provider bootstrap user that already has sudo, such as `debian`.
2. Upload or paste `scripts/bootstrap_debian13_rootless_docker.sh` onto the remote host.
3. Run it with default admin keys, or add more login keys with `ADMIN_EXTRA_SSH_PUBKEYS`. If local key selection or agent forwarding is not already verified, use `$local-ssh-setup` before this step.
4. Keep the bootstrap session open and verify `admin` from a second local terminal.
5. Only after verification, rerun the script with `REMOVE_BOOTSTRAP_USER=yes BOOTSTRAP_USER=<initial-user>` to remove the bootstrap user and home directory.

If any verification fails, keep the bootstrap user in place and fix the failing subsystem before deleting any account.

When checking a host after changing SSH config, use `$local-ssh-setup` for local client setup and bypass stale multiplexed connections:

```bash
ssh-add -l
ssh -G HOST | awk '/^(user|hostname|identityfile|identityagent|identitiesonly|forwardagent|addkeystoagent|controlmaster|controlpath) / {print}'
ssh -A -o ControlMaster=no -o ControlPath=none admin@HOST 'ssh-add -l'
```

The script default-installs these `admin` login keys:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvNI10a8cqHLy+X3XbodaiMx8RMfXx/HDbcD03zrqT8
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFGf+oyDlpCQ+58vymJIWiXoOuW7hwqu4R7iOvLItfYX
```

## Resulting Host Policy

- `admin` is the only SSH-login user.
- Root SSH is disabled with `PermitRootLogin no`.
- Password and keyboard-interactive SSH are disabled.
- `admin` has an unknown random password hash; SSH password login is disabled by sshd policy.
- `admin` sudo is authorized by `libpam-ssh-agent-auth` against `/etc/security/sudo_authorized_keys`.
- Rootless Docker runs as a user service for `admin`.
- Rootful Docker is disabled after rootless verification.

## Sudo Model

The sudo policy is intentionally tied to cryptographic proof from the forwarded SSH agent, not to the existence of an SSH-looking shell. Environment variables such as `SSH_CONNECTION` are not sufficient authorization because they can be spoofed by a local process.

The expected operator flow, after local SSH setup is verified with `$local-ssh-setup`, is:

```bash
ssh -A admin@HOST
sudo whoami
```

On Debian 13 with `libpam-ssh-agent-auth`, non-interactive `sudo -n true` may fail with `sudo: a password is required` even though TTY sudo with a forwarded agent succeeds. Verify sudo with a TTY:

```bash
ssh -A -tt -o ControlMaster=no -o ControlPath=none admin@HOST 'sudo -k; sudo true; sudo whoami'
```

If sudo prompts for a password, do not assume the server sudo policy is broken first. Check these local-client causes in order:

- `ssh-add -l` must show an authorized key; `The agent has no identities` means PAM has nothing to verify.
- `ssh -G HOST` must resolve `forwardagent yes` and the intended identity. Because OpenSSH uses the first value found for many options, a top-level `Host *` block can prevent later host-specific values from taking effect; put host-specific blocks before `Host *`.
- `ssh -A -o ControlMaster=no -o ControlPath=none admin@HOST 'ssh-add -l'` must show the forwarded key on the server.
- If config was changed, check and close stale multiplexed sessions with `ssh -O check HOST` and `ssh -O exit HOST` before testing plain `ssh HOST`.

If the admin key is a FIDO2 `*-sk` key and `libpam-ssh-agent-auth` cannot verify it, switch to a PAM FIDO2/U2F sudo design instead of weakening sudo to shell-presence checks.

## Docker Rootless Notes

- Debian 13 codename must be `trixie`.
- Required subordinate ID ranges live in `/etc/subuid` and `/etc/subgid`.
- `loginctl enable-linger admin` allows the rootless Docker user service to start at boot.
- Low ports 80/443 require `cap_net_bind_service` on `rootlesskit`; otherwise publish ports >=1024 or use a host proxy.
- Use `DOCKER_HOST=unix:///run/user/<admin_uid>/docker.sock` for remote Docker contexts when needed.
- If `dockerd-rootless-setuptool.sh` first runs without a user systemd bus, it may leave a stale Docker context pointing at `/home/admin/.docker/run/docker.sock`; force/update the context to `/run/user/<admin_uid>/docker.sock`.

## Rollback and Recovery

- Keep provider console or rescue access available before removing the bootstrap user.
- Keep the original bootstrap session open for recovery, then close it before deleting that user; `deluser --remove-home` fails while the user still owns live processes.
- If sshd config validation fails, do not reload sshd.
- If `admin` SSH fails after reload, fix `/etc/ssh/sshd_config.d/99-admin-only.conf` from the still-open bootstrap session.
- If sudo fails for `admin`, first verify the local agent has an authorized key and that forwarding is effective with `$local-ssh-setup`, then confirm `/etc/security/sudo_authorized_keys`, `/etc/pam.d/sudo`, and sudoers `env_keep` for `SSH_AUTH_SOCK`.
- If rootless Docker fails, leave rootful Docker disabled only after a successful rootless `docker info` check.
- Confirm rootful `docker.service`, `docker.socket`, and `containerd.service` are disabled and inactive after rootless verification.
- If bootstrap cleanup is needed later, rerun the script with `REMOVE_BOOTSTRAP_USER=yes`; the main setup steps are idempotent.

## Deploy Tool Compatibility

For Docker Compose projects deployed by a wrapper that passes `docker compose --env-file`:

- Compose files should use top-level `name: ${PROJECT}`.
- The chosen env file must define `PROJECT`.
- `SSH_URI` is optional and selects remote deployment.
- Keep project env files as deploy-tool inputs only.
- Do not add those env files under service-level `env_file:`.
- Pass runtime variables explicitly through service `environment:` interpolation, for example `KEY: ${KEY}`.
