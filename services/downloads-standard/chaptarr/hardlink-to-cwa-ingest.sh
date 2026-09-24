#!/bin/sh
set -eu

ROOT_FOLDER=/media/books
INGEST_FOLDER=/media/books-ingest

# Chaptarr fires this on "Test" from the Connect settings page too -
# nothing to link yet, so succeed without touching the filesystem.
if [ "${Chaptarr_EventType:-}" = "Test" ]; then
  echo "hardlink-to-cwa-ingest: Test event, nothing to do"
  exit 0
fi

if [ -z "${Chaptarr_AddedBookPaths:-}" ]; then
  # Debug aid: this branch fired on a real Test click even though
  # Chaptarr's CustomScript.cs sets Chaptarr_EventType=Test unconditionally -
  # logging the raw value received to find out why the check above missed it.
  echo "hardlink-to-cwa-ingest: Chaptarr_AddedBookPaths is unset - nothing to link (Chaptarr_EventType='${Chaptarr_EventType:-<unset>}')" >&2
  exit 1
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
  # CWA is a Calibre/ebook tool - it can't process audiobook formats.
  # Chaptarr's root folder is a Mixed-type one (ebooks and audiobooks
  # both land under /media/books), so filter out audiobook files here
  # rather than sending them into CWA's ingest to get stuck/ignored.
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
  echo "hardlink-to-cwa-ingest: linked $src -> $dest"
done
