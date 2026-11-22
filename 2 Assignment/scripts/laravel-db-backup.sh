#!/bin/bash

set -Eeuo pipefail

BACKUP_DIR="/var/backups/laravel"
LOG_FILE="/var/log/laravel-db-backup.log"
DB_NAME="laravel_db_prac"

umask 077

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

exec >> "$LOG_FILE" 2>&1

tmp_file=""

cleanup() {
    status=$?

    if [[ -n "$tmp_file" && -f "$tmp_file" ]]; then
        rm -f "$tmp_file"
        echo "$(date): Removed incomplete backup: $tmp_file"
    fi

    if (( status != 0 )); then
        echo "$(date): ERROR - Backup failed with exit code $status"
    fi
}

trap cleanup EXIT

echo "$(date): Starting database backup"

# Remove incomplete temporary files older than one hour
find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name 'laravel_db_*.sql.gz.tmp.*' -mmin +60 \
    -print -delete

timestamp=$(date +%Y%m%d_%H%M%S)
final_file="$BACKUP_DIR/laravel_db_${timestamp}.sql.gz"

tmp_file=$(mktemp "$BACKUP_DIR/laravel_db_${timestamp}.sql.gz.tmp.XXXXXX")

# Dump database and compress it
mysqldump \
    --defaults-extra-file=/root/.my.cnf \
    --single-transaction \
    --quick \
    --no-tablespaces \
    --routines \
    --triggers \
    --events \
    "$DB_NAME" | gzip > "$tmp_file"

# Verify the compressed backup
if [[ ! -s "$tmp_file" ]] || ! gzip -t "$tmp_file"; then
    echo "$(date): ERROR - Backup verification failed"
    exit 1
fi

# Publish only the verified backup
mv "$tmp_file" "$final_file"
tmp_file=""

chmod 600 "$final_file"

echo "$(date): Backup successful: $final_file"

# Delete backups older than 7 days
find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name 'laravel_db_*.sql.gz' -mtime +7 \
    -print -delete

echo "$(date): Backup process completed"
