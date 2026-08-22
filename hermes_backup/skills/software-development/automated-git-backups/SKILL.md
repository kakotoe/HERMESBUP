---
name: automated-git-backups
description: Use when automating git backups. Fixes push protection.
---
# Automated Git Backups

When writing scripts to autonomously backup state or configuration to a Git repository, follow these workflows to prevent token leaks, push rejections, and execution errors.

## 1. Avoid GitHub Push Protection Blocks
GitHub enforces Secret Scanning and Push Protection. If your backup attempts to push a file containing a Personal Access Token (PAT) or API key, the push will be immediately rejected with a `GH013: Repository rule violations` error.
*   **No Hardcoded Tokens:** Never hardcode the git authentication token directly in the backup script. If the script backs itself up, the token will be detected. Always read it from an explicitly excluded file (e.g., `TOKEN=$(cat /path/to/.github_token)`).
*   **Exclude Runtime State and DBs:** Runtime databases (like `state.db`, `sessions/`, or `kanban.db` in Hermes) often cache API keys or tokens passed in recent conversations. Exclude these files entirely from the backup payload.

## 2. Robust File Copying (Rsync Alternatives)
Containerized or minimal environments may lack `rsync`. Use `tar` as a ubiquitous, built-in alternative for copying directories with complex exclusions:
```bash
tar -cf - -C "$SRC_DIR" \
    --exclude="logs" \
    --exclude="state.db" \
    --exclude=".github_token" \
    . | tar -xf - -C "$DEST_DIR"
```

## 3. Handling Failed Commits due to Secrets
If a push is blocked by Secret Scanning, the offending commit remains in the local history. Subsequent pushes will continue to fail even if the secret is removed from the *working directory*. You must rewrite the git history before retrying:
```bash
# Soft reset to uncommit, or wipe the .git directory completely and re-init for a clean slate
git reset --soft HEAD~1 2>/dev/null || rm -rf .git/refs/heads/main .git/objects/*
git init
git remote add origin "$REPO_URL"
git add .
git commit -m "Clean backup"
git push -u origin HEAD:main -f
```

## 4. Hermes Cron Job Integration
When scheduling these automated scripts via the Hermes `cronjob` tool (action='create' or 'update'):
*   The `script` parameter MUST be a **relative filename** (e.g., `backup_hermes.sh`). The scheduler automatically looks for this file in `~/.hermes/scripts/`.
*   Do NOT use absolute paths (e.g., `/data/.hermes/scripts/backup.sh`), or the cron creation will fail.