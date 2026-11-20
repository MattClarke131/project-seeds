#!/bin/sh
# Splits Chaptarr's Mixed root folder by format: hardlinks ebooks into CWA's
# ingest folder and audiobooks into AudioBookshelf's library (#193).
set -eu

ROOT_FOLDER=/media/books
INGEST_FOLDER=/media/books-ingest
AUDIOBOOK_FOLDER=/media/audiobooks
# CWA's PUID/PGID. Chaptarr runs as root, so folders it creates need handing over.
CWA_OWNER=1000:1000

log() { echo "hardlink-to-cwa-ingest: $*"; }

is_audiobook() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *.mp3|*.m4a|*.m4b|*.flac|*.ogg|*.opus|*.wav|*.aac) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints $1 relative to ROOT_FOLDER; fails for paths outside it.
relpath() {
  case "$1" in
    "$ROOT_FOLDER"/*) printf '%s' "${1#"$ROOT_FOLDER"/}" ;;
    *) log "skipping '$1', not under $ROOT_FOLDER" >&2; return 1 ;;
  esac
}

link_ebook() {
  dest="$INGEST_FOLDER/$2"
  mkdir -p "$(dirname "$dest")"
  ln -f "$1" "$dest"
  # CWA must own the folders to delete processed files. Skip the file: it shares an inode with the library copy.
  dir=$(dirname "$dest")
  while [ "$dir" != "$INGEST_FOLDER" ]; do
    chown "$CWA_OWNER" "$dir"
    dir=$(dirname "$dir")
  done
  log "linked $1 -> $dest"
}

# AudioBookshelf mounts this folder read-only and keeps no copy, so it mirrors Chaptarr's layout permanently.
link_audiobook() {
  dest="$AUDIOBOOK_FOLDER/$2"
  mkdir -p "$(dirname "$dest")"
  ln -f "$1" "$dest"
  log "linked $1 -> $dest"
}

# Drops the mirrored link of a replaced or deleted audiobook file, plus any folders left empty.
unlink_audiobook() {
  dest="$AUDIOBOOK_FOLDER/$1"
  [ -e "$dest" ] || return 0
  rm -f "$dest"
  log "removed $dest"
  dir=$(dirname "$dest")
  while [ "$dir" != "$AUDIOBOOK_FOLDER" ] && rmdir "$dir" 2>/dev/null; do
    dir=$(dirname "$dir")
  done
}

IFS='|'

case "${Chaptarr_EventType:-}" in
  Download)
    # Upgrades list the replaced files here. Unlink them before linking, in case the new file reuses a path.
    for src in ${Chaptarr_DeletedPaths:-}; do
      rel=$(relpath "$src") || continue
      if is_audiobook "$src"; then unlink_audiobook "$rel"; fi
    done
    for src in ${Chaptarr_AddedBookPaths:-}; do
      rel=$(relpath "$src") || continue
      if is_audiobook "$src"; then
        link_audiobook "$src" "$rel"
      else
        link_ebook "$src" "$rel"
      fi
    done
    ;;
  BookFileDelete)
    # CWA's ingest copies are already gone once processed, so only audiobooks need cleanup.
    src=${Chaptarr_BookFile_Path:-}
    rel=$(relpath "$src") || exit 0
    if is_audiobook "$src"; then unlink_audiobook "$rel"; fi
    ;;
  *)
    # Test clicks and other events carry no file paths.
    log "nothing to do (Chaptarr_EventType='${Chaptarr_EventType:-<unset>}')"
    ;;
esac
