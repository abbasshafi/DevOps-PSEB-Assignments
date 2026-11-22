#!/usr/bin/env bash
# Nightly cleanup of Laravel daily logs. Safe to run repeatedly.
set -euo pipefail

LOG_DIR="${LOG_DIR:-/var/www/laravelapp/storage/logs}"
DELETE_AFTER_DAYS="${DELETE_AFTER_DAYS:-14}"
MAX_MB="${MAX_MB:-500}"
OWN_LOG="${OWN_LOG:-/var/log/laravel-log-cleanup.log}"

log() { echo "$(date '+%F %T') $*" >> "$OWN_LOG"; }
today_file="laravel-$(date +%F).log"

# 1) compress every daily log except today's
find "$LOG_DIR" -maxdepth 1 -type f -name 'laravel-*.log' ! -name "$today_file" -print0 |
while IFS= read -r -d '' f; do
  gzip -f "$f"
  log "compressed $(basename "$f")"
done

# 2) delete compressed logs older than N days
find "$LOG_DIR" -maxdepth 1 -type f -name 'laravel-*.log.gz' -mtime +"$DELETE_AFTER_DAYS" -print -delete |
while IFS= read -r f; do
  log "deleted $(basename "$f")"
done

# 3) size warning
size_mb=$(du -sm "$LOG_DIR" | cut -f1)
if [ "$size_mb" -gt "$MAX_MB" ]; then
  log "WARNING: $LOG_DIR is ${size_mb} MB (limit ${MAX_MB} MB)"
fi
