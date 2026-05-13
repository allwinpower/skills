# Local SSH Setup Operations

## Safety Sequence

1. Inspect existing config and resolved behavior before editing:

```bash
sed -n '1,220p' ~/.ssh/config
ssh -G HOST | awk '/^(user|hostname|identityfile|identityagent|identitiesonly|forwardagent|addkeystoagent) / {print}'
```

2. Confirm the persistent alias if the user did not explicitly provide one. If no alias is confirmed, use direct commands such as `ssh -A admin@HOST`.
3. Prefer adding a host-specific block before `Host *`, not changing global defaults.
4. Load the intended key into the existing user-session agent.
5. Verify with connection sharing disabled so stale control masters cannot hide new settings.

## Host Entry Pattern

Use this shape when the user provides an alias:

```sshconfig
Host ALIAS
    HostName HOST_OR_IP
    User USER
    IdentityFile ~/.ssh/KEY_FILE
    AddKeysToAgent yes
    ForwardAgent yes
    IdentityAgent /run/user/UID/openssh_agent
```

Only include `ForwardAgent yes` when remote workflows require the forwarded agent, such as SSH-agent-backed sudo or a remote hop that must use local keys.

Use `IdentityAgent` only when the local agent socket is stable and verified. On systemd user sessions, this is often `/run/user/<uid>/openssh_agent`.

## Agent Setup

Prefer an existing user-level SSH agent:

```bash
systemctl --user status ssh-agent.service
printf '%s\n' "${SSH_AUTH_SOCK:-}"
ssh-add ~/.ssh/KEY_FILE
ssh-add -l
```

Do not add `eval "$(ssh-agent)"` to `.bashrc` by default. That creates duplicate agents and usually does not make non-interactive SSH sessions more reliable.

## Multiplexing Checks

Existing `ControlMaster` sockets can reuse old SSH settings. After changing config, verify with:

```bash
ssh -A -o ControlMaster=no -o ControlPath=none ALIAS 'ssh-add -l'
```

If a stale master must be closed, use:

```bash
ssh -O check ALIAS
ssh -O exit ALIAS
```

Only close a control master when it is not being used as a recovery session for active remote maintenance.

## Naming Policy

- Use the exact alias requested by the user.
- If the user gives a project/environment name, ask before persisting it as an alias.
- If no alias is provided, do not invent one; use `user@HOST`.
- Avoid encoding assumptions like company, region, or environment names unless the prompt or repo source of truth states them.
