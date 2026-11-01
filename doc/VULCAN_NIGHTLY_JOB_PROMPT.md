# Move session gathering to a nightly Vulcan job

You are an expert NixOS and Unix operations engineer working directly on
`vulcan`. Complete this migration end to end. Keep the implementation small:
use the existing Bash gatherer, rsync, SSH, and one NixOS systemd service/timer.
Do not redesign this into an archive platform.

## Objective

Make Vulcan the machine that:

1. owns the collected session tree;
2. pulls every configured coding-agent session root nightly;
3. preserves sparse files rather than expanding their holes;
4. keeps all source hosts read-only;
5. reports failures through systemd and the journal; and
6. can be updated through the existing source and NixOS repositories.

The expected archive root is:

```text
/home/johnw/Documents/Sessions
```

The expected sessions repository checkout is:

```text
/home/johnw/src/sessions
```

Use a staging tree for migration:

```text
/home/johnw/Documents/Sessions.next
```

Default the nightly run to **02:30 Vulcan local time** unless the existing
NixOS configuration has a clear scheduling convention or conflict. Use a
persistent timer so a missed run executes after the machine returns.

## Current known state

- Repository: `git@github.com:jwiegley/sessions.git`
- Existing command:

  ```bash
  bin/gather-sessions CONFIG COLLECTION_ROOT
  ```

- Current live Hera configuration: `config/sources.johnw.tsv`
- Current archive on Hera: `/Users/johnw/Documents/Sessions`
- Last successful full reconciliation on Hera finished with status `0`.
- Current Hera archive inventory at prompt-authoring time:
  - about 470 GiB allocated;
  - 130,054 regular files;
  - 65 symlinks;
  - 27 `(machine, agent)` destination pairs.
- The large Andoria files are sparse. On the NFS source, the main examples were:
  - Codex: about 157 GiB allocated, 399 GiB apparent;
  - Pi: about 1.1 GiB allocated, 4.8 GiB apparent;
  - Claude Code: about 921 MiB allocated, 2.0 GiB apparent.
- The current Hera copy expanded those sparse holes. A sparse-aware Vulcan copy
  should require roughly 220 GiB rather than 470 GiB, subject to filesystem
  allocation differences and source growth.

The relevant sessions commits should include at least:

```text
38772b9 Add raw session gatherer
2208e84 Test session gathering safety
b1e9371 Document session gathering
f2c15f6 Narrow project scope to gathering
d92fbd6 Add live fleet source config
```

Commit hashes may differ if local commits are subsequently rewritten or
integrated. At prompt-authoring time, `d92fbd6` is present on `origin/main`.
Verify behavior and file contents, not only hashes. If a future remote checkout
does not contain the live config, stop and ask for it to be transferred; do not
silently invent a different fleet inventory.

## Non-negotiable scope

Build only the nightly raw-file gathering job and the minimum migration support
needed to move it to Vulcan.

Do **not** add:

- a database;
- indexing or search;
- normalization, parsing, or conversion;
- content-addressed storage;
- compression or an archive format;
- retention or pruning;
- Restic or another backup system;
- a custom daemon, queue, or network service;
- automatic Git pulls in the nightly service; or
- duplicate source rows for machines sharing one home directory.

Do not print or inspect session contents. Metadata, paths, counts, allocated
sizes, apparent sizes, checksums, exit statuses, and timestamps are sufficient.

## Authority and safety boundaries

You are authorized to:

- read the configured session roots over SSH;
- modify the sessions checkout on Vulcan;
- modify Vulcan's NixOS configuration;
- run the managed Vulcan build/switch process;
- create the Vulcan archive and staging directories; and
- start and verify the new local service and timer.

You are **not** authorized to:

- modify any source host;
- install SSH keys or edit remote `authorized_keys` without asking;
- bypass host-key checking;
- decrypt any SOPS file;
- delete or rename the Hera archive;
- delete any pre-existing Vulcan archive tree;
- enable destination deletion in rsync;
- add all NFS aliases as independent logical machines;
- push commits unless explicitly requested; or
- weaken a failing test or safety check to finish the migration.

If `/etc/nixos` uses the managed build driver, run builds and switches from
there with `./build`, as instructed by the repository. Never invoke
`nixos-rebuild` directly when the managed driver is present. Never create,
remove, or seize the `.nixos-build` lock. If the lock cannot be acquired, report
that exact blocker and stop.

## NFS-shared Andoria rule

These SSH names share one home directory through NFS:

```text
andoria-08
andoria-t2
delphi-3bd4
gpu-server
```

They are one logical source, not four.

Keep exactly one logical destination namespace:

```text
andoria-08/<agent>/...
```

Use one reachable alias only as transport. `andoria-t2` is the current preferred
transport. Do not create destination directories named `andoria-t2`,
`delphi-3bd4`, or `gpu-server`. Do not add duplicate rows whose content comes
from the same `/home/jwiegley` NFS tree.

## Required work sequence

### 1. Read local instructions and inspect state

Before editing anything:

```bash
hostname
id
printf '%s\n' "$HOME"
df -h /home/johnw/Documents
readlink -f /etc/nixos || true
```

Read all applicable instruction files in both repositories, including
`AGENTS.md`, `CLAUDE.md`, and local NixOS documentation. Never decrypt SOPS
secrets.

Inspect the sessions checkout:

```bash
cd /home/johnw/src/sessions
git status --short --branch
git remote -v
git log --oneline -10
```

If the checkout is absent, clone it from:

```bash
git clone git@github.com:jwiegley/sessions.git /home/johnw/src/sessions
```

If the checkout is dirty, do not discard or overwrite changes. Determine their
owner and relevance; stop for guidance if they conflict with this work.

Do not configure the nightly service to run `git pull`. Code updates must remain
reviewed, explicit operations.

### 2. Verify prerequisites and unattended SSH

Require these local commands on Vulcan:

```text
bash
rsync
ssh
realpath
```

Verify versions. rsync must support `--protect-args`, `--checksum`, and
`--sparse`.

Test read-only, noninteractive SSH access from Vulcan:

```bash
for host in hera clio vps andoria-t2; do
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" \
    'printf "host=%s user=%s home=%s\n" "$(hostname -s)" "$USER" "$HOME"'
done
```

Use existing SSH configuration and keys. Do not use
`StrictHostKeyChecking=no`. If host trust or credentials are missing, report the
specific host and stop for authorization before changing either side.

Confirm each remote has rsync 3.x and the expected source directories. Probe
only metadata and existence; do not print session contents.

### 3. Preserve sparse files in the gatherer

Inspect `bin/gather-sessions`. If it does not already pass `--sparse` to rsync,
make the smallest code change so its transfer invocation is equivalent to:

```bash
rsync -a --sparse --checksum --protect-args -- SOURCE/ DESTINATION/
```

Update the exact-argv test and documentation. Add a focused sparse-file
regression that:

1. creates a large sparse fixture with a tiny amount of real data;
2. gathers it;
3. confirms source and destination bytes match;
4. confirms the destination's allocated blocks are substantially below its
   apparent size; and
5. remains portable across the repository's supported Darwin/Linux shells, or
   cleanly performs the allocation assertion only where the required `stat`
   interface is available.

Do not use `--inplace`, `--delete`, or `--remove-source-files`.

Run at minimum:

```bash
shellcheck bin/gather-sessions test/gather-sessions.bash
shfmt -d -i 2 -ci bin/gather-sessions test/gather-sessions.bash
bash -n bin/gather-sessions test/gather-sessions.bash
test/gather-sessions.bash
```

### 4. Create a Vulcan-oriented source config

Do not use the Hera config unchanged: its Hera rows are local and its Vulcan
rows are remote.

Create `config/sources.vulcan.tsv` from `config/sources.johnw.tsv` with these
transport changes only:

- Hera rows: change host from `-` to `hera`.
- Vulcan rows: change host from `vulcan` to `-`.
- Clio rows: keep host `clio`.
- VPS rows: keep host `vps`.
- Logical `andoria-08` rows: keep the logical machine label `andoria-08`, and
  use only `andoria-t2` as transport.
- Keep every source path unchanged for its source host.
- Keep all 27 unique `(machine, agent)` destinations.

Validate mechanically:

- exactly 27 active rows;
- exactly 27 unique `(machine, agent)` pairs;
- Vulcan local rows point to `/home/johnw/...`;
- Hera and Clio rows point to `/Users/johnw/...`;
- Andoria rows point to `/home/jwiegley/...`;
- exactly one logical Andoria namespace;
- no logical rows named `andoria-t2`, `delphi-3bd4`, or `gpu-server`.

Document which config the timer uses.

### 5. Seed a sparse staging archive from Hera

First inspect whether either path already exists:

```text
/home/johnw/Documents/Sessions
/home/johnw/Documents/Sessions.next
```

Do not overwrite, merge into, rename, or delete an unexplained existing tree.
Stop and report it.

Confirm adequate space before transfer. Create the staging tree with an
owner-only umask. Pull the existing Hera archive into the staging tree using a
sparse-aware, non-destructive copy such as:

```bash
umask 077
mkdir -p /home/johnw/Documents/Sessions.next
rsync -a --sparse --protect-args -- \
  hera:/Users/johnw/Documents/Sessions/ \
  /home/johnw/Documents/Sessions.next/
```

This seed matters because the Hera collection may retain logs that have since
disappeared from live source roots. Do not rebuild solely from current sources
and thereby lose retained history.

Do not use `--delete`. Do not delete the Hera archive after seeding.

Verify the seed using metadata and a checksum dry run:

```bash
rsync -a --sparse --checksum --dry-run --itemize-changes \
  --protect-args -- \
  hera:/Users/johnw/Documents/Sessions/ \
  /home/johnw/Documents/Sessions.next/
```

The dry run should report no content changes after a stable seed. Record:

- regular-file count;
- symlink count;
- logical machine/agent directory count;
- apparent size;
- allocated size;
- remaining filesystem capacity; and
- absence of duplicate Andoria alias directories.

If the Hera archive changes during verification, rerun until one complete pass
returns clean; do not claim a stable seed from a changing comparison.

### 6. Reconcile the staging archive from live sources

From the sessions checkout, run:

```bash
bin/gather-sessions \
  config/sources.vulcan.tsv \
  /home/johnw/Documents/Sessions.next
```

Capture stdout/stderr and preserve the command's actual exit status. A status of
`0` is required. Diagnose and retry individual failures without adding duplicate
logical sources.

Run one final full reconciliation after any retry so sessions changed during the
migration are included. Then run the gatherer again to prove an unchanged rerun
succeeds.

Verify:

- 27 configured destination pairs exist;
- no alias directories exist for `andoria-t2`, `delphi-3bd4`, or `gpu-server`;
- source hosts were not modified;
- sparse Andoria files remain sparse on Vulcan;
- archive allocation is materially below the 470 GiB expanded Hera copy; and
- at least the existing test suite and all sparse regressions pass.

### 7. Promote staging safely

If `/home/johnw/Documents/Sessions` is absent and the staging verification is
clean, rename the staging tree atomically:

```bash
mv /home/johnw/Documents/Sessions.next \
  /home/johnw/Documents/Sessions
```

If the final path already exists, stop and ask before replacing or merging it.
Do not delete any old tree as part of this task.

Retain the Hera archive. Its deletion is a separate destructive decision that
requires explicit authorization after multiple successful Vulcan nightlies.

### 8. Add the NixOS oneshot service and timer

Inspect existing Vulcan NixOS module and timer conventions before adding code.
Use the repository's established structure; do not introduce a framework for
one job.

The resulting service must be equivalent in behavior to:

- unit name: `session-gather.service`;
- `Type=oneshot`;
- run as user `johnw`;
- working directory `/home/johnw/src/sessions`;
- owner-only umask (`0077`);
- local path containing Bash, rsync, OpenSSH, and coreutils;
- network-online ordering;
- finite but ample timeout, such as 12 hours;
- exact command:

  ```text
  /home/johnw/src/sessions/bin/gather-sessions
  /home/johnw/src/sessions/config/sources.vulcan.tsv
  /home/johnw/Documents/Sessions
  ```

- no automatic Git update;
- no destination deletion;
- no custom log files required; use the systemd journal;
- failure preserved as a failed unit rather than masked; and
- no concurrent second instance while one run is active.

The timer must be equivalent in behavior to:

- unit name: `session-gather.timer`;
- nightly at 02:30 local time;
- `Persistent=true`;
- enabled through NixOS; and
- no duplicate cron, launchd, or user timer for the same job.

Do not place private keys, credentials, or session paths containing secrets in
Nix store content. Ordinary source paths and host aliases are expected in the
tracked config; credentials are not.

### 9. Build and activate through the managed NixOS path

From `/etc/nixos`, use the local managed driver and project instructions. For
example, if supported by that repository:

```bash
cd /etc/nixos
./build test
./build switch
```

Use the exact commands documented there. Do not run direct `nixos-rebuild` if
`./build` owns the workflow. If the build lock is held, stop and report the lock
error; do not remove it.

Review the Nix diff before switching. Ensure no unrelated host or service
configuration is changed.

### 10. Verify service and timer

After activation:

```bash
systemctl status session-gather.service --no-pager
systemctl status session-gather.timer --no-pager
systemctl list-timers session-gather.timer --all --no-pager
```

Run one manual service execution:

```bash
sudo systemctl start session-gather.service
systemctl show session-gather.service \
  -p Result -p ExecMainStatus -p ActiveState -p SubState
journalctl -u session-gather.service -n 200 --no-pager
```

Required result:

- `Result=success`;
- `ExecMainStatus=0`;
- timer enabled and waiting;
- next trigger visible;
- all 27 rows attempted;
- no duplicate NFS-host namespaces;
- no session content in logs; and
- no source-host mutation.

Run a second manual execution if needed to demonstrate idempotent success. Do
not simulate failure by modifying a real source or credential.

## Git and issue discipline

Follow each repository's `AGENTS.md`.

For the sessions repository, keep any new `obr` state synchronized with
`doc/PLAN.org`. Do not resurrect the abandoned archive/search roadmap. Record
only the small sparse-copy and Vulcan-runtime work needed here.

Prefer these atomic commits where applicable:

1. preserve sparse session files;
2. add the Vulcan source configuration and documentation; and
3. add the Vulcan NixOS service/timer in the NixOS repository.

Each commit must pass its focused checks. Review staged diffs and scan for
secrets before committing. Do not push unless explicitly asked.

## Rollback

Rollback must be simple and non-destructive:

1. disable/remove the timer through the NixOS configuration and run the managed
   switch;
2. leave `/home/johnw/Documents/Sessions` intact;
3. leave the Hera archive intact;
4. revert only the relevant source/NixOS commits if necessary; and
5. never use `rsync --delete` as rollback.

## Stop conditions

Stop and ask for guidance if any of these occurs:

- unattended SSH requires a new key or remote `authorized_keys` mutation;
- a source host's identity or home path differs from the recorded inventory;
- the sessions repository has conflicting uncommitted work;
- the expected source commit/config is unavailable;
- Vulcan lacks safe capacity for staging plus normal operation;
- an unexplained archive or staging tree already exists;
- sparse allocation is not materially lower than apparent size;
- the NixOS build driver is locked or fails for an unrelated reason;
- activation would change unrelated services/hosts;
- any step would require decrypting SOPS; or
- any destructive action appears necessary.

Do not work around these conditions by weakening verification.

## Definition of done

Do not declare completion until all items hold:

- [ ] Sessions source code is available in a clean Vulcan checkout.
- [ ] Sparse preservation is implemented, tested, documented, and committed.
- [ ] `config/sources.vulcan.tsv` contains exactly 27 unique destinations.
- [ ] Hera, Clio, VPS, and one Andoria transport are reachable noninteractively.
- [ ] Vulcan's local rows use host `-`.
- [ ] Andoria's four aliases produce one logical destination namespace.
- [ ] Existing Hera archive history is seeded into a sparse Vulcan tree.
- [ ] Full live-source reconciliation exits `0`.
- [ ] A final unchanged reconciliation exits `0`.
- [ ] Sparse files remain sparse and allocated size is recorded.
- [ ] No source host was modified.
- [ ] Hera's archive remains untouched.
- [ ] NixOS service builds and runs successfully.
- [ ] Nightly persistent timer is enabled with a visible next trigger.
- [ ] Journal output contains no session content or credentials.
- [ ] Relevant tests, lint, formatting, and secret scans pass.
- [ ] Git commits are atomic and working trees are clean.

## Final report

Return a concise but evidence-rich report containing:

1. files and repositories changed;
2. commit hashes and subjects;
3. exact archive/config/service/timer paths;
4. SSH reachability results by logical source host;
5. seed and reconciliation exit statuses;
6. file/symlink/destination-pair counts;
7. apparent versus allocated archive size;
8. timer's next scheduled run;
9. verification commands and outcomes;
10. confirmation that NFS aliases were not duplicated;
11. confirmation that Hera archive and all source hosts remain unchanged; and
12. any residual risk or step requiring user authorization.
