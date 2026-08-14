#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
gather=$repo/bin/gather-sessions
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

hash_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  else
    shasum -a 256
  fi
}

snapshot() {
  COPYFILE_DISABLE=1 tar -cf - -C "$1" . | hash_stream
}

inode() {
  if stat -f '%i' "$1" >/dev/null 2>&1; then
    stat -f '%i' "$1"
  else
    stat -c '%i' "$1"
  fi
}

mtime() {
  if stat -f '%m' "$1" >/dev/null 2>&1; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

# Allocated 512-byte blocks. BSD stat reports these directly with %b; GNU
# stat's %b is in units of %B, which is 512 on every filesystem this runs on.
blocks() {
  if stat -f '%b' "$1" >/dev/null 2>&1; then
    stat -f '%b' "$1"
  else
    stat -c '%b' "$1"
  fi
}

# Apparent size in bytes.
apparent() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

source_dir=$tmp/source\ tree
collection=$tmp/collection\ root
mkdir -p "$source_dir/nested"
printf 'first log\n' >"$source_dir/nested/session.jsonl"
printf '\000\001\177\200\376\377' >"$source_dir/raw.bin"
printf 'AAAA' >"$source_dir/same-stat.bin"
touch -t 202001020304.05 "$source_dir/same-stat.bin"
printf 'keep after source removal\n' >"$source_dir/vanishing.log"
ln -s nested/session.jsonl "$source_dir/current"
printf 'hera\tpi\t-\t%s\n' "$source_dir" >"$tmp/local.tsv"

snapshot "$source_dir" >"$tmp/source.before"
"$gather" "$tmp/local.tsv" "$collection" >"$tmp/first.out"
snapshot "$source_dir" >"$tmp/source.after"
cmp "$tmp/source.before" "$tmp/source.after"
cmp "$source_dir/nested/session.jsonl" \
  "$collection/hera/pi/nested/session.jsonl"
cmp "$source_dir/raw.bin" "$collection/hera/pi/raw.bin"
cmp "$source_dir/same-stat.bin" "$collection/hera/pi/same-stat.bin"
[[ $(mtime "$source_dir/same-stat.bin") == "$(mtime "$collection/hera/pi/same-stat.bin")" ]]
[[ -L $collection/hera/pi/current ]]
[[ $(readlink "$collection/hera/pi/current") == nested/session.jsonl ]]

inode_before=$(inode "$collection/hera/pi/raw.bin")
"$gather" "$tmp/local.tsv" "$collection" >"$tmp/unchanged.out"
[[ $(inode "$collection/hera/pi/raw.bin") == "$inode_before" ]]

same_stat_mtime=$(mtime "$source_dir/same-stat.bin")
printf 'BBBB' >"$source_dir/same-stat.bin"
touch -t 202001020304.05 "$source_dir/same-stat.bin"
[[ $(mtime "$source_dir/same-stat.bin") == "$same_stat_mtime" ]]
snapshot "$source_dir" >"$tmp/same-stat.before"
"$gather" "$tmp/local.tsv" "$collection" >"$tmp/same-stat.out"
snapshot "$source_dir" >"$tmp/same-stat.after"
cmp "$tmp/same-stat.before" "$tmp/same-stat.after"
cmp "$source_dir/same-stat.bin" "$collection/hera/pi/same-stat.bin"

sleep 1
printf 'second log, updated\n' >"$source_dir/nested/session.jsonl"
snapshot "$source_dir" >"$tmp/changed.before"
"$gather" "$tmp/local.tsv" "$collection" >"$tmp/changed.out"
snapshot "$source_dir" >"$tmp/changed.after"
cmp "$tmp/changed.before" "$tmp/changed.after"
cmp "$source_dir/nested/session.jsonl" \
  "$collection/hera/pi/nested/session.jsonl"

rm "$source_dir/vanishing.log"
"$gather" "$tmp/local.tsv" "$collection" >"$tmp/removed.out"
[[ -f $collection/hera/pi/vanishing.log ]]

snapshot "$source_dir" >"$tmp/overlap.before"
if "$gather" "$tmp/local.tsv" "$source_dir/collection" \
  >"$tmp/overlap.out" 2>"$tmp/overlap.err"; then
  echo 'expected an overlapping collection root to fail' >&2
  exit 1
else
  [[ $? -eq 2 ]]
fi
grep -F 'collection root overlaps local source' "$tmp/overlap.err" >/dev/null
[[ ! -e $source_dir/collection ]]
snapshot "$source_dir" >"$tmp/overlap.after"
cmp "$tmp/overlap.before" "$tmp/overlap.after"

inverse_root=$tmp/inverse-root
inverse_source=$inverse_root/source
mkdir -p "$inverse_source"
printf 'source beneath root\n' >"$inverse_source/log"
printf 'hera\tpi\t-\t%s\n' "$inverse_source" >"$tmp/inverse.tsv"
snapshot "$inverse_root" >"$tmp/inverse.before"
if "$gather" "$tmp/inverse.tsv" "$inverse_root" \
  >"$tmp/inverse.out" 2>"$tmp/inverse.err"; then
  echo 'expected a source beneath the collection root to fail' >&2
  exit 1
else
  [[ $? -eq 2 ]]
fi
grep -F 'collection root overlaps local source' "$tmp/inverse.err" >/dev/null
[[ ! -e $inverse_root/hera ]]
snapshot "$inverse_root" >"$tmp/inverse.after"
cmp "$tmp/inverse.before" "$tmp/inverse.after"

symlink_root=$tmp/symlink-root
source_one=$tmp/symlink-source-one
source_two=$tmp/symlink-source-two
mkdir -p "$symlink_root/hera" "$source_one" "$source_two"
printf 'FROM-ONE\n' >"$source_one/log"
printf 'ORIGINAL-TWO\n' >"$source_two/log"
ln -s "$source_two" "$symlink_root/hera/pi"
printf 'hera\tpi\t-\t%s\nclio\tpi\t-\t%s\n' \
  "$source_one" "$source_two" >"$tmp/symlink.tsv"
snapshot "$source_two" >"$tmp/symlink-source.before"
if "$gather" "$tmp/symlink.tsv" "$symlink_root" \
  >"$tmp/symlink.out" 2>"$tmp/symlink.err"; then
  echo 'expected a symlinked destination path to fail' >&2
  exit 1
else
  [[ $? -eq 2 ]]
fi
grep -F 'destination path contains a symlink' "$tmp/symlink.err" >/dev/null
[[ $(cat "$source_two/log") == ORIGINAL-TWO ]]
[[ ! -e $symlink_root/clio ]]
snapshot "$source_two" >"$tmp/symlink-source.after"
cmp "$tmp/symlink-source.before" "$tmp/symlink-source.after"

printf 'clio\tmissing\t-\t%s\nclio\tpi\t-\t%s\n' \
  "$tmp/does-not-exist" "$source_dir" >"$tmp/partial.tsv"
if "$gather" "$tmp/partial.tsv" "$tmp/partial" \
  >"$tmp/partial.out" 2>"$tmp/partial.err"; then
  echo 'expected missing source to make the final status nonzero' >&2
  exit 1
else
  [[ $? -eq 1 ]]
fi
grep -F 'missing source directory' "$tmp/partial.err" >/dev/null
cmp "$source_dir/raw.bin" "$tmp/partial/clio/pi/raw.bin"

mkdir "$tmp/fake-bin"
cat >"$tmp/fake-bin/rsync" <<'RSYNC'
#!/usr/bin/env bash
printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$1" "$2" "$3" "$4" "$5" "$6" >>"$RSYNC_CALL_LOG"
[[ $5 != badhost:* ]]
RSYNC
chmod +x "$tmp/fake-bin/rsync"
printf 'one\tpi\tbadhost\t/sessions\n' >"$tmp/remote.tsv"
printf 'two\tclaude\tgoodhost\t/session logs\n' >>"$tmp/remote.tsv"
remote_root=$(realpath -m -- "$tmp/remote root")
if RSYNC_CALL_LOG="$tmp/rsync.calls" PATH="$tmp/fake-bin:$PATH" \
  "$gather" "$tmp/remote.tsv" "$tmp/remote root" \
  >"$tmp/remote.out" 2>"$tmp/remote.err"; then
  echo 'expected one failed remote transfer' >&2
  exit 1
else
  [[ $? -eq 1 ]]
fi
{
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    -a --sparse --checksum -- badhost:/sessions/ \
    "$remote_root/one/pi/"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    -a --sparse --checksum -- 'goodhost:/session logs/' \
    "$remote_root/two/claude/"
} >"$tmp/rsync.expected"
cmp "$tmp/rsync.expected" "$tmp/rsync.calls"
grep -F 'gather failed: one/pi' "$tmp/remote.err" >/dev/null

# This collection only ever adds and updates. Assert directly on the captured
# argv that no destructive flag ever reaches rsync, so a future edit cannot
# quietly introduce one: the vanishing.log case above proves the behaviour,
# this proves the mechanism. Also guard -s/--protect-args, which rrsync rejects
# outright ("option -s has been disabled on this server"), so a restricted
# source host would fail every transfer.
if awk -F'\t' '
  {
    for (i = 1; i <= NF; i++) {
      if ($i == "--delete" || $i == "--delete-excluded" ||
          $i == "--remove-source-files" || $i == "--inplace" ||
          $i == "-s" || $i == "--protect-args") {
        exit 0
      }
    }
  }
  END { exit 1 }
' "$tmp/rsync.calls"; then
  echo 'a forbidden rsync flag reached argv' >&2
  exit 1
fi

printf '../unsafe\tpi\t-\t/tmp/source\n' >"$tmp/invalid.tsv"
if "$gather" "$tmp/invalid.tsv" "$tmp/invalid-root" \
  >"$tmp/invalid.out" 2>"$tmp/invalid.err"; then
  echo 'expected unsafe destination label to fail' >&2
  exit 1
else
  [[ $? -eq 2 ]]
fi
grep -F 'unsafe machine label' "$tmp/invalid.err" >/dev/null
[[ ! -e $tmp/invalid-root ]]

sparse_source=$tmp/sparse\ source
mkdir -p "$sparse_source"
sparse_bytes=67108864
dd if=/dev/zero of="$sparse_source/sparse.bin" bs=1 count=0 \
  seek="$sparse_bytes" >/dev/null 2>&1
printf 'sparse marker\n' |
  dd of="$sparse_source/sparse.bin" bs=1 conv=notrunc >/dev/null 2>&1
printf 'andoria-08\tcodex\t-\t%s\n' "$sparse_source" >"$tmp/sparse.tsv"
"$gather" "$tmp/sparse.tsv" "$tmp/sparse root" >"$tmp/sparse.out"

sparse_copy=$tmp/sparse\ root/andoria-08/codex/sparse.bin
cmp "$sparse_source/sparse.bin" "$sparse_copy"
[[ $(apparent "$sparse_copy") -eq $sparse_bytes ]]

# The allocation assertion is only meaningful where stat exposes block counts
# AND the filesystem actually stores holes. Check the SOURCE fixture first: if
# it came back fully allocated, this filesystem does not do sparse files and
# asserting on the copy would fail for a reason unrelated to the gatherer.
if source_blocks=$(blocks "$sparse_source/sparse.bin" 2>/dev/null) &&
  copy_blocks=$(blocks "$sparse_copy" 2>/dev/null) &&
  [[ $source_blocks -gt 0 ]] &&
  [[ $((source_blocks * 512)) -lt $((sparse_bytes / 2)) ]]; then
  # Without --sparse the hole is written out in full and the copy allocates
  # roughly $sparse_bytes; with it, allocation stays near the source's.
  [[ $((copy_blocks * 512)) -lt $((sparse_bytes / 2)) ]]
  [[ $copy_blocks -le $((source_blocks * 4)) ]]
else
  printf '%s\n' \
    'gather-sessions: sparse allocation assertion skipped (no hole support)'
fi

printf '%s\n' 'gather-sessions: all tests passed'
