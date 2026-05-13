---
name: local-ssh-setup
description: Configure and verify local SSH client access for servers, including host aliases, IdentityFile, IdentityAgent, ForwardAgent, ssh-agent key loading, and multiplexing-safe verification. Use when Codex needs to adjust ~/.ssh/config, prepare SSH agent forwarding, or make local SSH login behavior reliable before remote server work.
---

# Local SSH Setup

## Workflow

Use this skill when local SSH behavior is part of the task: adding or reviewing host entries, choosing identities, loading keys into an agent, enabling forwarding, or verifying that a remote sudo model can see forwarded keys.

Before editing `~/.ssh/config`, read `references/operations.md`. Inspect the current config with `ssh -G HOST` and confirm the intended alias with the user unless the alias was explicitly provided.

## Non-Negotiables

- Do not invent persistent `Host` aliases. If the user did not provide one, use direct `user@HOST` commands or ask for the alias.
- Prefer the OS/user-session SSH agent over shell snippets that start duplicate agents.
- Do not put private key material in config files, logs, skill files, or final answers.
- Use multiplexing-safe verification after SSH config changes: `-o ControlMaster=no -o ControlPath=none`.
- Keep host entries narrowly scoped. Avoid changing global `Host *` defaults unless the user asks for a global policy.

## Verification Commands

Use these checks after setup:

```bash
ssh -G HOST | awk '/^(user|hostname|identityfile|identityagent|identitiesonly|forwardagent|addkeystoagent) / {print}'
ssh-add -l
ssh -A -o ControlMaster=no -o ControlPath=none HOST 'ssh-add -l'
ssh -A -o ControlMaster=no -o ControlPath=none HOST 'whoami'
```

Expected results:

- `ssh -G` resolves the intended host, user, identity, identity agent, and forwarding policy.
- `ssh-add -l` shows the local public key fingerprint needed for login or remote sudo.
- Remote `ssh-add -l` shows the forwarded key fingerprint when `ForwardAgent yes` is required.
