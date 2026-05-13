# Allwin Skills Maintenance

## Canonical Repo

- HTTPS: `https://github.com/allwinpower/skills`
- SSH remote: `git@github.com:allwinpower/skills.git`
- Default branch: `main`

## Pull Request Requirement

If an Allwin skill fails, is incomplete, is OS-incompatible, or misses reusable operational guidance, update the local skill files immediately when file edits are allowed. The task is not complete until the local skill update is synced and verified, and a skill-update pull request is opened or the exact blocker is reported.

## Sync First

Before using or modifying Allwin skills, check the canonical repo for updates and sync the local installed skill copy so every agent works from the same current guidance.

When git is authorized:

```bash
git pull --ff-only
```

If local instructions say not to run git unless explicitly requested, do not run git unless a repo-local instruction grants a specific skill-maintenance exception. Still update and sync the local skill files when normal file edits are allowed. Report that update checks, pull requests, branch creation, commits, or pushes are blocked until the user authorizes git operations.

## Local Update Requirement

When a reusable skill gap is discovered and file edits are allowed:

1. Patch the most specific affected skill first.
2. Patch this routing skill only when the gap is about routing, maintenance policy, cross-skill behavior, or missing skill selection guidance.
3. Keep the update as small as possible and place operational detail in `references/*.md` unless it must be visible in `SKILL.md`.
4. Sync affected skills locally:

```bash
rsync -a --delete <repo>/<skill>/ ~/.codex/skills/<skill>/
diff -qr <repo>/<skill> ~/.codex/skills/<skill>
```

Tell the user to restart Codex when new skill metadata or a new skill is added.

Treat a failed local sync or `diff -qr` as a blocker until the source and installed skill copies match.

## Git Publishing

Use this workflow when repo access works:

```bash
git switch -c skill-update/<short-topic>
# edit the affected skill files
git status --short
git add <changed skill files>
git commit -m "Update skills: <short summary>"
git push -u origin skill-update/<short-topic>
```

Then open a PR against `main`.

Do not push directly to `main` unless the user explicitly asks for a direct main push.

## PR Content

Title:

```text
Update skills: <short summary>
```

Body must include:

- observed problem or missing reusable behavior;
- affected skill or skills;
- environment and OS details, including Linux/macOS/Windows/WSL when relevant;
- change made;
- validation run;
- remaining risk or blocker, if any.

## What To Update

Prefer the smallest durable skill update:

- update `SKILL.md` when trigger language or core workflow changes;
- update `references/*.md` when operational detail, compatibility notes, or troubleshooting changes;
- update scripts when deterministic automation should change;
- update `agents/openai.yaml` only when user-facing metadata is stale.

Keep skills concise. Do not add extra changelogs or broad documentation files.

## Install Verification

Use the sync commands in "Sync First" after source changes. Treat a failed `diff -qr` as a blocker until the source and installed skill copies match.
