#!/bin/bash

# Configuration
TOKEN=$(cat /data/.hermes/.github_token)
REPO_URL="https://${TOKEN}@github.com/kakotoe/HERMESBUP.git"
BACKUP_DIR="/data/hermes_backup_repo"
HERMES_DIR="$HOME/.hermes"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Create backup directory and clone if not exists
if [ ! -d "$BACKUP_DIR/.git" ]; then
    rm -rf "$BACKUP_DIR"
    git clone "$REPO_URL" "$BACKUP_DIR"
    
    cd "$BACKUP_DIR" || exit 1
    
    # Configure git
    git config user.email "hermes@nousresearch.com"
    git config user.name "Hermes Agent"
else
    cd "$BACKUP_DIR" || exit 1
    # Check if repo has commits
    if git rev-parse HEAD >/dev/null 2>&1; then
        git pull origin main || git pull origin master || true
    fi
fi

cd "$BACKUP_DIR" || exit 1

# Prepare backup folder
rm -rf "$BACKUP_DIR/hermes_backup"
mkdir -p "$BACKUP_DIR/hermes_backup"

# Copy important files manually using tar with excludes
tar -cf - -C "$HERMES_DIR" \
    --exclude="logs" \
    --exclude="cache" \
    --exclude="audio_cache" \
    --exclude="image_cache" \
    --exclude="models_dev_cache.json" \
    --exclude="ollama_cloud_models_cache.json" \
    --exclude="provider_models_cache.json" \
    --exclude=".*_cache*" \
    --exclude="*.lock" \
    --exclude="*.pid" \
    --exclude=".skills_prompt_snapshot.json" \
    --exclude="bin" \
    --exclude="platforms" \
    --exclude="state.db" \
    --exclude="sessions" \
    --exclude="kanban.db" \
    --exclude=".github_token" \
    . | tar -xf - -C "$BACKUP_DIR/hermes_backup"

# Reset git to clean the previous failed commit from history
git reset --soft HEAD~1 2>/dev/null || rm -rf .git/refs/heads/main .git/objects/*
git init
git config user.email "hermes@nousresearch.com"
git config user.name "Hermes Agent"
git remote add origin "$REPO_URL"

# Add and commit
git add .
git commit -m "Automated Hermes Backup: $TIMESTAMP"

# Push. Force push to overwrite the repository cleanly (since we recreated .git)
git push -u origin HEAD:main -f

echo "Backup completed and pushed successfully at $TIMESTAMP"
