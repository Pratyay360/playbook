#!/usr/bin/env bash
set -euo pipefail

SOURCE="$HOME/containers/"
STAGING="$HOME/backup_staging"
REMOTES=("mega:/backup" "dropbox:/backup" "gdrive:/backup")
DATE=$(date +%Y-%m-%d_%H-%M-%S)
TARBALL="${STAGING}/backup_${DATE}.tar.gz"
SNAPSHOT="$HOME/.backup.snar"  # tracks incremental state
NTFY_URL="https://ntfy.sh/plutoploybackup"

# --- Notification Function ---
notify() {
  local message="$1"
  # -s hides curl progress output, > /dev/null hides the ntfy JSON response
  curl -s -d "$message" "$NTFY_URL" > /dev/null
}

# Ensure staging directory exists
mkdir -p "$STAGING"

# Full backup on Sunday, incremental rest of the week
if [[ $(date +%u) -eq 7 ]]; then
  rm -f "$SNAPSHOT"
  echo "Sunday: forcing full backup."
  notify "🔄 Starting Sunday Full Backup for containers..."
fi

# Create incremental tarball
tar -cvzf "$TARBALL" \
  --listed-incremental="$SNAPSHOT" \
  "$SOURCE" \
  && echo "Tarball created: $TARBALL" \
  || { 
       echo "ERROR: tar failed" >&2
       notify "❌ CRITICAL: Tarball creation failed for containers!"
       rm -f "$TARBALL"
       exit 1 
     }

for remote in "${REMOTES[@]}"; do
  rclone copy "$TARBALL" "${remote}/" \
    --verbose \
    && echo "Uploaded to ${remote}: backup_${DATE}.tar.gz" \
    || { 
         echo "ERROR: Upload to ${remote} failed" >&2
         notify "❌ ERROR: Backup upload to ${remote} failed!"
         rm -f "$TARBALL"
         exit 1 
       }
done

# Clean local tarball
rm -f "$TARBALL"
echo "Local tarball cleaned up."

# Prune Function - Deletes all but the 7 newest backups
prune_remote() {
  local target_remote=$1
  local delete_list="${STAGING}/to_delete.txt"
  
  rclone lsf "${target_remote}/" \
    | grep -E '^backup_[0-9]{4}-[0-9]{2}-[0-9]{2}_.*\.tar\.gz$' \
    | sort \
    | head -n -7 > "$delete_list"

  if [ -s "$delete_list" ]; then
    rclone delete "${target_remote}/" --files-from "$delete_list"
    echo "Pruned old backups on ${target_remote}."
  else
    echo "Nothing to prune on ${target_remote}."
  fi
  
  rm -f "$delete_list"
}

# Loop through the array and prune each remote
for remote in "${REMOTES[@]}"; do
  prune_remote "$remote"
done

echo "Backup process completed successfully."
notify "✅ Backup complete! Successfully uploaded and pruned across all remotes."