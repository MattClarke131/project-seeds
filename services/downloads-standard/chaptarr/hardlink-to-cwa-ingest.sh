#!/bin/sh
# Hardlinks a just-imported book from Chaptarr's library into CWA's ingest
# folder, skipping audiobook formats (CWA only handles ebooks).
set -eu

ROOT_FOLDER=/media/books
INGEST_FOLDER=/media/books-ingest

# Chaptarr fires this on "Test" from the Connect settings page too, without
# Chaptarr_AddedBookPaths (confirmed live: Chaptarr_EventType isn't even set
# on Test, despite what CustomScript.cs's naming implies) - succeed without
# touching the filesystem whenever there's nothing to link, rather than
# trying to detect "Test" specifically.
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
