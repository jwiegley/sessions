# sessions

`gather-sessions` copies raw AI coding-agent session directories from local and
remote machines into one ordinary directory tree. It does not parse, convert,
index, search, archive, prune, or back up the files.

## Requirements

- Bash 4 or newer
- rsync 3 with `--protect-args`, `--checksum`, and `--sparse`
- GNU `realpath` from coreutils
- SSH access and rsync on each configured remote machine

## Configure sources

Copy [`config/sources.example.tsv`](config/sources.example.tsv) and edit it.
John's current five-machine configuration is
[`config/sources.johnw.tsv`](config/sources.johnw.tsv); its shared-NFS hosts use
one logical Andoria namespace. Each file has four tab-separated fields per row:

```text
machine<TAB>agent<TAB>host<TAB>source-directory
```

- `machine` and `agent` become destination directory names. Use only letters,
  digits, `.`, `_`, and `-`.
- `host` is `-` for a local source or an SSH destination such as
  `johnw@andoria-08`.
- `source-directory` is an absolute path. Spaces are supported.
- Give each root for one agent a distinct agent label.

Blank lines and lines beginning with `#` are ignored. The example lists every
session root established by the project research. Codex Desktop has no proven
separate root, and Factory Desktop shares the Droid session root, so browser and
Electron caches are not listed.

## Gather

Choose a collection directory and run:

```bash
bin/gather-sessions config/sources.tsv /path/to/session-collection
```

For a row such as:

```text
andoria-08<TAB>pi<TAB>johnw@andoria-08<TAB>/home/johnw/.pi/agent/sessions
```

files appear beneath:

```text
/path/to/session-collection/andoria-08/pi/
```

with every source-relative path preserved.

Rerunning the command uses content checksums to copy new and changed files, even
when an edit keeps the same size and modification time. Unchanged files are not
recopied. The command never deletes destination files or mutates a source.

The collection root and every local source must be disjoint. Their canonical
paths are checked before output is created, so a collection root within a source
or a source within the collection root is rejected. Existing symlinks in a
computed `<collection-root>/<machine>/<agent>` path are also rejected before
transfer.

Every row is attempted; missing directories, unavailable hosts, and rsync
failures are reported to standard error. The final exit status is nonzero if
any row failed.

## Test

The synthetic test uses temporary directories and a fake SSH/rsync endpoint. It
does not read real session logs or contact a remote host. It includes regression
cases for equal-size/equal-mtime edits, both root/source containment directions,
a destination symlink redirected into another configured source, and sparse-file
preservation. The sparse case asserts the copy's allocated blocks stay far below
its apparent size, and skips that assertion where the filesystem does not store
holes.

```bash
test/gather-sessions.bash
```
