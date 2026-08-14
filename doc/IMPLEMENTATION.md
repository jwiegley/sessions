# Implementation plan: minimal AI session-log gatherer

## Scope

Build one small command, `bin/gather-sessions`, that copies configured
session-log directory trees into one destination tree without interpreting
their contents.

## Configuration

Use a UTF-8, tab-separated file. Blank lines and lines beginning with `#` are
ignored.

```text
machine<TAB>agent<TAB>host<TAB>source-directory
```

- `machine` and `agent` are safe destination labels containing only letters,
  digits, `.`, `_`, and `-`; neither may be `.` or `..`.
- `host` is `-` for a local directory or an ordinary SSH destination such as
  `user@example.net`.
- `source-directory` is an absolute path. It may contain spaces but not tabs or
  newlines.
- Each `(machine, agent)` pair occurs once, so two rows cannot write the same
  destination. Give each root for one agent a distinct agent label.

A row copies the *contents* of `source-directory` into:

```text
<collection-root>/<machine>/<agent>/
```

Thus every source-relative path is preserved beneath the machine and agent
labels.

## Command

```text
bin/gather-sessions CONFIG COLLECTION_ROOT
```

For each valid row, the command creates its destination directory and runs one
of:

```text
rsync -a --checksum --protect-args -- SOURCE_DIRECTORY/ DESTINATION/
rsync -a --checksum --protect-args -- HOST:SOURCE_DIRECTORY/ DESTINATION/
```

Before creating output, GNU `realpath -m` canonicalizes the collection root and
every local source. Any containment in either direction is a configuration
error. Each computed destination must also resolve exactly to its literal path
beneath the root; an existing symlink in that path is rejected before transfer.

The implementation does not use `--delete`, does not run a custom source-side
helper, and does not write beside a source. Rows are processed independently.
A missing local directory or failed remote transfer is reported to standard
error; remaining rows are still attempted; the final exit status is nonzero if
any row failed.

## Ordered work

### GATH-01 — Configuration and layout

- Document the four-column configuration.
- Validate row shape, labels, absolute source paths, and duplicate destinations.
- Provide `config/sources.example.tsv` covering the currently known agents
  through data only.

### GATH-02 — Gather command

- Implement the local and SSH/rsync forms above.
- Preserve bytes and source-relative paths.
- Use rsync content checksums so equal-size, equal-mtime edits still update.
- Reject local source/destination overlap before creating the collection root.
- Do not delete destination files and do not mutate sources.
- Continue after independent-row failures and aggregate the final status.

### GATH-03 — Focused verification and documentation

A single synthetic test must prove:

- exact `<root>/<machine>/<agent>/<relative-path>` layout;
- byte identity for text and non-text files;
- unchanged reruns do not rewrite destination files;
- changed source files update on the next run, including equal-size and
  equal-mtime edits;
- missing sources are reported and do not prevent another row from collecting;
- overlapping local sources and destinations fail before creating output;
- source trees are unchanged before and after gathering; and
- the command returns nonzero when any row fails.

`README.md` documents requirements, configuration, invocation, destination
layout, rerun behavior, and failure behavior—nothing more.

## Dependency order

```text
GATH-01 -> GATH-02 -> GATH-03
```

All earlier expanded-scope issues are deferred and detached from this path. No
database, indexing, normalization, conversion, object store, manifest chain,
archive management, backup, retention, migration, plugin, deployment, or
observability package is required.
