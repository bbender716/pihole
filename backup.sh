#!/bin/bash
# Weekly automated backup: syncs Pi-hole config and pushes to GitHub if changed.
# Scheduled via cron; logs to /var/log/pihole-backup.log

REPO="$(cd "$(dirname "$0")" && pwd)"
LOG="/var/log/pihole-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "Starting Pi-hole backup"

# Sync config files into repo
bash "$REPO/sync.sh" >> "$LOG" 2>&1

# Check for any changes
if git -C "$REPO" diff --quiet && git -C "$REPO" diff --cached --quiet; then
    log "No changes detected, skipping commit"
    exit 0
fi

# Commit and push
git -C "$REPO" add -A
git -C "$REPO" commit -m "chore: weekly config backup $(date '+%Y-%m-%d')" >> "$LOG" 2>&1
git -C "$REPO" push origin main >> "$LOG" 2>&1 && log "Pushed to GitHub" || log "ERROR: push failed"
