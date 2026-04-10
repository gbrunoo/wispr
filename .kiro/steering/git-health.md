---
inclusion: auto
description: Rules for safe branch cleanup and git hygiene
---

# Git Health

## Branch Cleanup

- Before deleting any remote branch, run `gh pr list --state open` and exclude branches backing open PRs.
- Never delete the `website` branch — it hosts the project site and is long-lived.
- Only delete branches that are fully merged and have no open PRs.
- Always run `git remote prune origin` after deleting remote branches to clean up stale tracking refs.

## Pushing

- Always use `git push --no-verify` to bypass Git Defender pre-push hooks.

## Protected Branches

- `main` — production branch
- `website` — project website, never delete
