#!/bin/sh
# Hardlinks a just-imported book from Chaptarr's library into CWA's ingest
# folder, skipping audiobook formats (CWA only handles ebooks).
set -eu

ROOT_FOLDER=/media/books
INGEST_FOLDER=/media/books-ingest
# CWA's PUID/PGID. Chaptarr runs as root, so folders it creates need handing over.
CWA_OWNER=1000:1000

# Test clicks don't set Chaptarr_AddedBookPaths - treat that as a no-op
# success rather than trying to detect "Test" specifically.
if [ -z "${Chaptarr_AddedBookPaths:-}" ]; then
  echo "hardlink-to-cwa-ingest: nothing to link (Chaptarr_EventType='${Chaptarr_EventType:-<unset>}')"
  exit 0
fi

IFS='|'
for src in $Chaptarr_AddedBookPaths; do
  case "$src" in
    "$ROOT_FOLDER"/*) ;;
    *)
      echo "hardlink-to-cwa-ingest: skipping '$src', not under $ROOT_FOLDER" >&2
      continue
      ;;
  esac
  # Guard: audiobooks go to Chaptarr's /media/audiobooks root, but CWA would choke on one landing here.
  case "$src" in
    *.mp3|*.m4a|*.m4b|*.flac|*.ogg|*.opus|*.wav|*.aac)
      echo "hardlink-to-cwa-ingest: skipping '$src', audiobook format" >&2
      continue
      ;;
  esac
  rel=${src#"$ROOT_FOLDER"/}
  dest="$INGEST_FOLDER/$rel"
  mkdir -p "$(dirname "$dest")"
  ln -f "$src" "$dest"
  # CWA must own the folders to delete processed files. Skip the file: it shares an inode with the library copy.
  dir=$(dirname "$dest")
  while [ "$dir" != "$INGEST_FOLDER" ]; do
    chown "$CWA_OWNER" "$dir"
    dir=$(dirname "$dir")
  done
  echo "hardlink-to-cwa-ingest: linked $src -> $dest"
done
