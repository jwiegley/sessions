# Design: a minimal AI session-log gatherer

**Status:** approved first-version design
**Decision date:** 2026-08-13

## Decision

Provide one command that reads a small list of session-log source directories.
It uses ordinary `rsync`/SSH pulls to copy them into one operator-selected
folder tree.

Each configured row contains:

1. a machine label;
2. an agent label;
3. an SSH host, or `-` for a local source; and
4. an absolute source directory.

The destination for a row is:

```text
<collection-root>/<machine>/<agent>/<source-relative-path>
```

Agent formats are irrelevant. The gatherer does not parse a session, recognize
a schema, or distinguish JSON, JSONL, SQLite, text, or binary files. Agent
support consists only of adding source-directory rows to the configuration.
When one agent has several roots, each root receives a distinct agent label.

## Implementation choice

Use a small Bash wrapper around `rsync`. Haskell would add a compiled package
while still delegating local and SSH transfer to `rsync`; it is therefore not
the simpler implementation for this version.

## Required behavior

- Pull local and remote source directories.
- Preserve filenames, relative paths, symlinks, timestamps, and file bytes using
  `rsync -a --sparse --checksum`.
- Copy new files and update changed files on later runs, even when a change keeps
  the same size and modification time.
- Preserve sparse files as sparse rather than expanding their holes; some
  agent session files are very large but mostly holes.
- Leave unchanged files alone.
- Never pass `--protect-args` (`-s`). rrsync disables it unconditionally, so any
  source host whose key is restricted with `command="rrsync -ro DIR"` would
  reject every transfer. Paths containing spaces still work, because rrsync
  receives the argument intact instead of re-splitting it.
- Never pass `--delete`; a source disappearance does not delete the collected
  copy.
- Never write, rename, or remove anything in a source directory. Require the
  collection root to be disjoint from sources and reject destination-path
  symlinks before transfer.
- Attempt every independent configuration row, report failures, and return
  nonzero if any row failed.

The configuration is trusted operator input, but machine and agent labels are
validated because they become destination path components.

## Explicitly absent

This tool has no object store, manifest chain, database, index, search, parser,
normalization, conversion, archive versioning, compression, retention, pruning,
backup, restore, migration, plugin, service, scheduler, deployment framework,
or content-processing layer.

The collection root is an ordinary directory. Protecting, backing up, retaining,
searching, or interpreting it is separate operator work.

## Historical material

`doc/RESEARCH.md`, earlier Git revisions, and deferred `obr` issues preserve the
broader research and design history. They do not define first-version
requirements and do not block this design.
