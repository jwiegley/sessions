# Decision: a native-preserving AI session archive

**Status:** recommended architecture, ready for bounded pre-implementation experiments
**Decision date:** 2026-08-12
**Evidence:** [RESEARCH.md](RESEARCH.md)
**Scope boundary:** design only; this document contains neither implementation code nor an implementation roadmap

## Decision summary

Build one self-hosted archive whose authoritative state is:

1. immutable, exact native file objects;
2. immutable capture manifests that preserve host, source, path, metadata, completeness and hash provenance; and
3. versioned configuration needed to interpret those manifests.

Run a single coordinator on `hera`. It initiates scheduled SSH pulls from all five hosts, with source-local snapshot assistance only where an ordinary read cannot safely capture a live store. Claude, Codex and Droid lifecycle hooks may enqueue an early run, but a daily full reconciliation is the completeness mechanism. Every committed source generation is immutable. SHA-256 deduplicates identical file objects physically; logical entries and provenance are never deduplicated away.

Keep a rebuildable SQLite/FTS5 index on `hera` for cross-agent lexical search. Readers interpret native JSON/JSONL and consistent read snapshots of SQLite, retain source locators, and report unknown schema explicitly. AgentsView, Agent Sessions, claude-vault, ccusage and Letta/ATIF converters may read published native trees or derived data, but none owns archive truth. DuckDB, vectors, OpenTelemetry, OpenInference, ATIF and Letta trajectories remain optional derivatives.

Implement the future coordinator and baseline readers in **Haskell**, packaged by Nix. Reuse system SSH, rsync, SQLite and restic rather than implementing transport, database or backup engines. Python is not required by the selected core. If bounded experiments demonstrate that Haskell cannot meet multi-platform SQLite/Nix or adapter-maintenance needs without materially more risk, the language decision reverses under the thresholds below; native and manifest contracts do not change.

## 1. Requirements and hard gates

### 1.1 Requirements

| ID | Requirement | Source and acceptance condition |
| --- | --- | --- |
| **R1 Native authority** | Every collected datum remains recoverable byte-for-byte in its original native representation. | User constraint. A content hash of restored bytes must match the capture manifest. |
| **R2 No required canonical form** | Parsing, normalization, analytics, indexing and export are non-authoritative, disposable and rebuildable. | User constraint. Deleting `derived/` and `state/` must not impair native recovery. |
| **R3 Complete declared scope** | All 45 agent-machine cells remain represented, including absent, empty, historical-only, cloud-only, inaccessible and unknown states. | Research inventory. No source silently disappears from status. |
| **R4 Incremental and idempotent** | A daily run transfers only needed bytes, may be repeated safely, and never duplicates or overwrites committed truth. | Operational requirement. Repeating an unchanged source snapshot creates no new payload object or capture. |
| **R5 Live-store safety** | Concurrent JSONL and WAL SQLite cannot yield falsely complete or incoherent captures. | Fleet evidence. Every capture records its coherence/completeness state. |
| **R6 Provenance and identity** | Host, account/user context, surface, source root, native path, capture generation, native identifiers and lineage claims remain distinguishable. | Native IDs are not globally unique. Every search result returns a source locator. |
| **R7 Loss and mutation visibility** | Truncation, deletion, malformed data, schema drift, migration, resume, fork and branch are retained and diagnosed rather than repaired in place. | Vendor churn. Prior captures remain immutable. |
| **R8 Self-hosted privacy** | No archive content is sent to a third party; logs and metrics contain no transcript content or credentials. | User constraint. Network egress is SSH to declared hosts and declared backup endpoints only. |
| **R9 Search and read** | Cross-agent lexical search, filtering and native retrieval work from one hub; index loss is recoverable. | User outcome. A hit resolves to exact native bytes/locator, not only normalized text. |
| **R10 Backup and raw-only recovery** | Loss of hub state and indexes is recoverable from native objects, manifests and configuration in backup. | Recovery contract. A clean restore can verify and rebuild without vendor source hosts. |
| **R11 Schema evolution** | Unknown files and fields are preserved before understood; readers and manifest schemas evolve without rewriting old authority. | Unstable formats. Preservation succeeds even when interpretation fails. |
| **R12 Operability** | One writer, bounded concurrency, explicit health/status, offline-host tolerance and no always-on custom network service are required initially. | Small fleet and minimality. Scheduled jobs and a CLI suffice. |
| **R13 Nix portability** | The same pinned package/module set covers Darwin arm64, Linux arm64 and Linux x86_64 roles. | Observed fleet. Deployment closure and external tool versions are explicit. |
| **R14 Language fitness** | Prefer Haskell unless Python materially reduces selected-architecture risk or complexity. | User preference. The comparison must cover every core capability. |
| **R15 Security and retention** | Least privilege, owner-only plaintext access, optional-at-rest encryption, indefinite default native retention and explicit destructive policy are required. | Logs may contain secrets. Nothing authoritative is pruned implicitly. |

### 1.2 Hard gates

An architecture is rejected regardless of weighted score if it:

- replaces a native artifact with normalized, reserialized, compressed-only or database-only data;
- cannot restore exact native bytes without the original source host;
- treats an index, viewer database, telemetry backend or cloud API as authoritative;
- silently omits an unknown, inaccessible or unsupported source;
- copies a live SQLite main file as though it were a complete database;
- requires third-party content upload; or
- selects Python only because it is familiar or has a larger general AI ecosystem.

## 2. Evaluation criteria

Architectures passing the gates are scored 0–5. Weighted totals guide rather than replace the gates.

| Criterion | Weight | What earns 5 |
| --- | ---: | --- |
| Native fidelity and independently verifiable recovery | 25 | Exact bytes, immutable generations, hashes, provenance and clean restore |
| Live-file correctness and failure recovery | 15 | Transaction-aware snapshots, atomic commit, resumable staging, no false completeness |
| Incremental/offline fleet operation | 15 | Pull reconciliation, physical dedup, idempotence and explicit offline state |
| Search and future interpretation | 10 | Source-linked lexical search, schema-tolerant readers, disposable index |
| Simplicity and existing-tool reuse | 10 | One coordinator; SSH/rsync/SQLite/restic reused; few bespoke services |
| Privacy and security | 10 | Local-only, least privilege, content-free telemetry, protected derivatives |
| Portability and maintainability | 10 | Nix-pinned multi-platform closure and narrow stable contracts |
| Extensibility without lock-in | 5 | Optional exporters/readers can change without archive migration |

## 3. Coherent alternatives

| Alternative | Hard gate | Fidelity | Live safety | Incremental | Search | Simplicity | Privacy | Portability | Extensibility | Weighted result |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **A. Canonical normalized SQLite/DuckDB warehouse** | **Fail:** native bytes no longer authoritative | 1 | 4 | 4 | 5 | 3 | 4 | 4 | 2 | Rejected |
| **B. Mutable per-host rsync mirror + AgentsView** | **Fail:** source deletion/truncation can erase the only copy | 3 | 2 | 4 | 5 | 5 | 5 | 4 | 3 | Rejected |
| **C. Immutable native objects + capture manifests + rebuildable SQLite FTS** | Pass | 5 | 5 | 5 | 4 | 4 | 5 | 4 | 5 | **94/100** |
| **D. Existing indexer database plus its raw mirror** | **Fail:** parser/index retention contracts become archive custody | 3 | 3 | 4 | 5 | 5 | 4 | 3 | 3 | Rejected |
| **E. Restic repository as the only archive namespace, index after mount/restore** | Pass | 5 | 4 | 4 | 2 | 4 | 5 | 4 | 3 | **82/100** |
| **F. Distributed per-host indexes with federated query** | **Fail:** offline/pruned hosts defeat independent recovery | 2 | 3 | 3 | 4 | 2 | 4 | 3 | 4 | Rejected |

### 3.1 Why C wins

C is the only option that makes native fidelity, capture history and search independent concerns without introducing a custom distributed system. E also preserves bytes, but a backup repository is a poor primary namespace: routine browsing, capture provenance, coherence states and exact source-path history become restore/mount concerns. C therefore uses restic behind the archive rather than as its user-facing authority.

### 3.2 Rejected premises

- **“ATIF is full fidelity, so store ATIF.”** It is full-featured interchange, not byte fidelity; conversion necessarily constructs a different document.
- **“The latest normalized database contains all useful information.”** Usefulness cannot be known in advance, and unsupported desktop blobs disprove it.
- **“Hooks make collection reliable.”** Hooks are disableable, bounded and absent from Pi/OpenCode; crashes and old files remain.
- **“Bidirectional sync is simpler.”** It creates multi-writer conflict and live-SQLite hazards. Sources are read-only inputs; the hub is the sole archive writer.
- **“One native session ID means one session.”** Copies, migrations, accounts and host-local ID generation can collide; provenance must namespace claims.
- **“DuckDB is required for search.”** SQLite FTS5 supplies baseline lexical search. DuckDB becomes justified only by measured analytical workloads.

## 4. Authority model and invariants

### 4.1 Authority tiers

Only three things are required for recovery: `config/`, `native/`, and `manifests/`. `state/` and `derived/` may be deleted at any time. A backup is valid only if it contains the three recovery inputs.

| Tier | Authoritative? | Contents | Mutation rule |
| --- | --- | --- | --- |
| `config/` | Yes for declared scope/policy, never for transcript content | Source enrollment IDs, host labels, allowlisted roots, adapter selection, exclusions with reasons, retention and backup policy; secret references only | Versioned changes; backed up |
| `native/` | **Yes** | Exact byte objects and non-file native payloads such as symlink targets or admitted xattrs/resource forks | Immutable; content-addressed; never rewritten or recompressed in place |
| `manifests/` | **Yes** | Immutable source-generation manifests and append-only chain metadata that map native paths/metadata to byte objects and classify completeness | Commit only after every referenced object is durable; never edit |
| `state/` | No | Locks, staging, last-seen metadata, retry queues, transfer cache, mutable heads, run receipts | Mutable and disposable; reconstruct from manifests or next reconciliation |
| `derived/` | No | Materialized native trees, SQLite/FTS, logical SQLite snapshots, parse diagnostics, ATIF/Letta/OTel/DuckDB/vector/HTML exports | Disposable; each product records input manifest IDs, reader/tool version and options |
| `backup/` | Redundant authority | External restic repositories and local content-free receipts | Append snapshots; prune only under explicit backup policy |

### 4.2 Non-negotiable invariants

1. A native object contains exactly the captured bytes. Its filename is its SHA-256; verification never parses or reserializes it.
2. Every logical occurrence remains in a manifest even when its payload hash equals an object already stored for another host/path.
3. A source generation is immutable and links to its predecessor. Reconciliation never edits the predecessor to look current.
4. A generation cannot be `complete` unless its adapter’s snapshot contract succeeded. An exact but changing capture may be retained as `open` or `unstable`; this is evidence, not a completeness claim.
5. Unknown or malformed artifacts are captured before parsing. Reader failure cannot fail preservation.
6. No index row, native session ID, normalized record, path, mtime or source-host state is sufficient proof of object identity; only payload hash plus manifest reference is.
7. Deleting `state/` and `derived/` leaves all source bytes and provenance intact.
8. Source deletion creates a new observation/generation state; it never deletes a prior object or manifest.
9. Backup success is not inferred from command exit alone: a repository snapshot ID and periodic integrity/restore check are required.
10. Collection logs contain identifiers, counts, durations and error classes—not transcript content, native path text, command output or credentials.

## 5. Exact logical hierarchy

The hierarchy is logical; physical volumes and restic repositories may be mounted elsewhere. Native and manifest paths are private (`0700` root; owner-only files by default).

```text
session-archive/
├── VERSION
├── config/
│   ├── hosts/
│   │   ├── hera.toml
│   │   ├── clio.toml
│   │   ├── vps.toml
│   │   ├── vulcan.toml
│   │   └── andoria-08.toml
│   ├── sources/
│   │   └── <source-id>.toml
│   ├── policy.toml
│   └── readers.lock
├── native/
│   └── objects/
│       └── sha256/
│           └── <first-two-hex>/<remaining-62-hex>
├── manifests/
│   └── v1/
│       └── <host-id>/<source-id>/<YYYY>/<MM>/
│           └── <UTC-first-observed>--<manifest-id>.json
├── state/
│   ├── coordinator.sqlite
│   ├── lock/
│   ├── staging/<run-id>/
│   ├── transfer/<host-id>/<source-id>/
│   └── runs/<YYYY>/<MM>/<run-id>.json
├── derived/
│   ├── native-trees/<host-id>/<source-id>/<manifest-id>/...
│   ├── current/<host-id>/<source-id> -> ../native-trees/...
│   ├── read-snapshots/<manifest-id>/...
│   ├── index/<index-schema>/<generation>/sessions.sqlite
│   ├── diagnostics/<reader-version>/<manifest-id>.json
│   ├── exports/{atif,letta,otel,html}/...
│   └── analytics/{duckdb,parquet,vectors}/...
└── backup/
    ├── receipts/<repository-id>/<YYYY>/<MM>/<snapshot-id>.json
    └── restore-checks/<repository-id>/<YYYY-MM-DD>.json
```

`native/objects` is partitioned by hash, never by host or date; this gives physical deduplication without losing logical provenance. Host/source/date partitioning belongs in manifests. `derived/native-trees` recreates a vendor’s original relative layout with verified read-only copies or copy-on-write reflinks to objects; writable hardlinks to authoritative objects are forbidden. It is the compatibility surface for existing readers. `derived/current` changes atomically only after materialization succeeds.

Backups are external to `session-archive/` to avoid recursive backup. The local `backup/` directory contains content-free receipts and restore-check results. A restic snapshot covers `VERSION`, `config`, `native`, and `manifests`; `state` and `derived` are excluded by default.

## 6. Identity, naming, and provenance

### 6.1 Stable identities

- **`host-id`** is an enrollment UUID that never changes; `hera` and the other names are labels. A renamed or rebuilt machine keeps the ID only after an explicit migration decision.
- **`source-id`** is an enrollment UUID for one producer instance: host ID + agent family + surface + account/organization scope + admitted root set. It is not derived from a mutable pathname.
- **`run-id`** identifies one coordinator attempt and is operational state, not session identity.
- **`object-id`** is `sha256:<digest>` of exact payload bytes plus a separately recorded length. A hash collision is a fatal verification error, never “deduplicated.”
- **`tree-digest`** hashes a versioned, length-delimited, path-byte-sorted description of all admitted entries, metadata, object IDs and coherence states. It detects an unchanged source without depending on JSON key order.
- **`manifest-id`** is SHA-256 of the exact immutable manifest bytes. The preceding manifest ID is embedded, forming a per-source chain. The manifest filename carries first-observed UTC plus the ID.
- **`native-session-id`**, message IDs, parent IDs and thread IDs are reader claims. Their namespace is at least `(source-id, format-fingerprint, native-id)`; they never name archive objects.

### 6.2 Manifest contract

A versioned source-generation manifest records, at minimum:

- manifest schema and collector version; manifest predecessor and tree digest;
- host/source IDs and display labels; OS/architecture, producer version and account/organization scope when discoverable without secrets;
- source roots and path encoding; UTC start/end/first-observed times; clock-offset observation;
- snapshot method and one of `complete`, `open`, `unstable`, `partial`, `incoherent`, `unavailable`, `absent`, `empty`, `not_applicable`, or `unknown`;
- each entry’s raw relative path bytes (reversibly encoded), display path, file kind, mode, size, timestamps, hardlink group/symlink target, admitted xattr/resource-fork payload references, and object ID;
- pre/post stability observations and source-side hash when available;
- sidecar relationship and native database bundle membership;
- declared exclusions and reasons, including credentials, cookies and generic caches; and
- content-free warnings: malformed structure, unknown schema fingerprint, missing sidecar, clock anomaly, truncation, or snapshot failure.

Absolute home paths are not placed in object names. Manifest paths remain private because project names and session IDs may themselves be sensitive. Secrets used for SSH, restic or keychains are referenced by credential-helper name, never embedded.

### 6.3 Physical deduplication versus logical identity

If the same rollout appears on `hera` and `clio`, its bytes occupy one object, but both source/path entries survive. If a session migrates to another path, the new manifest points to the same object and records the new occurrence. If a resumed session rewrites or appends the file, the new bytes are a new object. Semantic readers may correlate those occurrences, but they may not erase them or alter manifests.

## 7. Host roles and data flow

| Host | Role | Data flow |
| --- | --- | --- |
| `hera` | Sole archive writer, scheduler, object/manifest store, index/search host, local source | Captures its own sources locally; pulls all remote sources; publishes derived trees/index; initiates backup |
| `clio` | macOS source for all five CLIs plus four desktop surfaces | Read-only SSH pull to `hera`; optional read-only restored viewer, never a second writer |
| `vps` | Linux source; includes historical Droid despite absent executable | Read-only SSH pull; no full replica due limited disk |
| `vulcan` | Linux arm64 source | Read-only SSH pull; no archive writes |
| `andoria-08` | Large Linux source; candidate capacity-tier restic endpoint | Read-only SSH pull to `hera`; backup role only after durability/availability experiment |

All arrows carrying transcript data point toward `hera`; there is no peer merge. Source-local helpers are invoked over SSH for a bounded allowlisted snapshot operation and return a private staging path or stream. Hooks write only a local, content-free reconciliation hint; they do not push transcript content or mutate the archive. A Nix timer/launchd schedule on `hera` runs daily reconciliation and may drain hints more often.

At least one restic repository must be off `hera`, and production policy should maintain a second independently administered copy. `andoria-08` has sufficient observed capacity but is not accepted as the sole backup until its storage durability, reachability and restore performance pass the bounded experiment in section 18.

## 8. Source adapter and reader contracts

Collection and interpretation are separate extension points. An adapter must not need to understand message content to preserve a source.

### 8.1 Collection adapter

For one enrolled `source-id`, an adapter provides these logical operations:

1. **Probe:** report producer presence/version, declared roots, source state, capabilities and content-free errors. Executable absence does not suppress store discovery.
2. **Plan:** enumerate allowlisted roots, sidecar relationships, exclusions, required local helper, and snapshot strategy. The plan is inspectable before bytes move.
3. **Acquire:** publish a private staged capture or stream. Each entry carries raw relative path bytes and pre/post stability observations. Database bundles carry a coherence token/method.
4. **Validate:** perform format-independent byte length/hash checks and adapter-specific coherence checks without modifying source files.
5. **Classify:** return one explicit completeness state plus content-free warnings. Unknown schema is acceptable; unknown snapshot coherence is not silently `complete`.
6. **Fingerprint:** emit a structural format fingerprint from producer version, file magic, header/schema/table/column names and record-type names. It must not include content values.

The coordinator owns object insertion and manifest commit. An adapter cannot write `native/`, `manifests/`, or the index. Discovery and capture include regular files, symlinks and explicitly admitted metadata; sockets, transient locks, cookies, credential stores, generic caches and unbounded logs are excluded with recorded reasons. Adding an exclusion that could contain session semantics is a policy change requiring review.

### 8.2 Snapshot strategies

| Source class | Required capture behavior | Complete when |
| --- | --- | --- |
| Closed immutable file | Stream/copy bytes once; hash and verify length | Source metadata remains stable through acquisition |
| Append/changing JSONL | Copy to unique staging; compare source size/mtime before and after; retry boundedly; retain every acquired object | Stable attempt, or adapter-defined atomic close marker; otherwise `open`/`unstable` |
| Mutable directory/tree | Enumerate before and after; stage files under one run; detect added/removed/changed entries | Stable tree or source/filesystem snapshot; otherwise `partial`/`unstable` |
| WAL SQLite | Capture exact DB/WAL/SHM under a coherent filesystem snapshot or coordinated quiescence; separately create SQLite logical read snapshot | Exact bundle method proves same point in time; logical snapshot alone does not prove byte-identical native bundle |
| Opaque/encrypted/protobuf store | Preserve exact admitted bytes and metadata; do not decode or reject | Byte capture coherent under its source class; semantic coverage remains `unknown` |
| Cloud/vendor API export | Preserve exact response body, pagination/order metadata and response headers that affect interpretation; never overwrite local native source | Vendor confirms complete page set for a bounded export; provenance says `vendor-export`, not local native |

A source-local helper may create a read snapshot in a private temporary directory, but it cannot delete, checkpoint, vacuum, reindex or otherwise mutate the producer store unless a later goal explicitly approves a proven-safe operation. If exact live-SQLite bundle coherence cannot be achieved read-only, the capture is retained and labeled, and implementation pauses on that adapter rather than weakening R1/R5.

### 8.3 Semantic reader

A versioned reader consumes a manifest plus exact objects or a documented logical read snapshot. It emits a stream of **query projections**, not a canonical archive. Each projection may contain:

- source locator `(manifest-id, entry path, byte/record locator)`;
- namespaced native session/event/parent/tool IDs and relationship claims;
- timestamp with source timezone/clock confidence;
- source family/surface/host/project/model/role/tool/status facets when understood;
- searchable text or binary attachment metadata;
- token/cost fields with units and extraction confidence; and
- reader version, format fingerprint, parse diagnostics and omitted/unknown-field counts.

Readers are schema-tolerant: preserve unknown fields by locator, treat optional data as optional, and quarantine only the failed projection—not the native object. A reader cannot mark source data corrupt merely because it is newer. It returns `unsupported-fingerprint`, `partial-parse`, `malformed-record`, or `missing-sidecar` diagnostics. Updating a reader rebuilds its projections; it never migrates native objects or manifests.

### 8.4 Optional normalization and export

`export --format atif`, `export --format letta`, and telemetry/OpenInference export are explicit read operations over a selected manifest/session query. Every output records input manifest IDs, reader and exporter versions, options, loss/omission diagnostics and creation time. By default, outputs are written under `derived/exports` with owner-only permissions. An external destination or upload requires a separate explicit user action.

Letta’s TypeScript package and Harbor’s Python/Pydantic tools remain subprocess plugins rather than dependencies of the core. Their failure cannot affect collection, native verification, baseline search or backup.

## 9. Idempotent daily update protocol

One coordinator lock protects the authority. Work across hosts/sources may run with bounded concurrency, but commits for a given `source-id` are serialized.

1. **Start and lock.** Create a `run-id`; acquire the single-writer lock; load validated config and current per-source manifest heads. A stale lock is resolved by process identity and an atomic lease rule, never by deleting it blindly.
2. **Inventory.** Enumerate every enrolled cell, including N/A/absent/empty/historical-only entries. Record a content-free run observation for all 45 cells.
3. **Reachability and clock.** Open SSH with pinned host keys and bounded timeout; record reachability and approximate clock offset. An offline host does not fail other hosts.
4. **Probe and plan.** Run each adapter’s metadata-only probe. Compare producer/root/format fingerprint with the last manifest. A hook hint merely raises priority.
5. **Acquire to staging.** Use an adapter-specific strategy from section 8. Transfer into `state/staging/<run-id>`; never into a published native tree. Resume partial rsync transfers only in that run/source namespace.
6. **Stability/coherence check.** Compare pre/post source observations; retry changing files a bounded number of times. Retain the last exact acquisition with `open`, `unstable`, `partial` or `incoherent` rather than declaring failure or silently dropping it.
7. **Verify and insert objects.** Hash exact staged bytes while reading; verify length; fsync the temporary object; atomically rename into the SHA-256 namespace; fsync its directory. If the object exists, verify its length and hash before reuse. Never trust destination existence alone.
8. **Build candidate manifest.** Sort entries by raw path bytes; include exclusions, snapshot method, state, warnings, tree digest and predecessor. Re-read every referenced object before commit or rely on a just-completed verified insertion receipt within the same lock.
9. **Idempotence test.** If tree digest, completeness state, producer metadata and policy-relevant warnings equal the current head, create no new manifest. The run receipt records `unchanged`. A changed availability state may create one transition manifest; repeated identical unavailability does not.
10. **Commit generation.** Serialize the manifest deterministically, compute its ID, fsync a temporary file, atomically rename it under `manifests/`, fsync the directory, then atomically update the disposable head in `state/`. A crash before this point leaves only unreferenced objects/staging, safe for later GC.
11. **Publish compatibility tree.** Materialize `derived/native-trees/.../<manifest-id>` from objects; verify it; atomically switch `derived/current`. Failure leaves the old derived tree active and does not roll back authority.
12. **Update index.** Readers process new/changed manifest entries in one SQLite transaction. Publish a complete new index generation or transactionally update the active one with an input-manifest watermark. Parse failures become diagnostics and coverage gaps.
13. **Verify authority.** Check manifest chain continuity, object existence/length/hash for new references, and source-state totals. A failed verification blocks backup success status but does not delete committed evidence.
14. **Back up.** Snapshot `VERSION`, `config`, `native`, and `manifests` to every due restic repository. Save content-free repository snapshot IDs/receipts. One repository failure is visible and retryable.
15. **Finish.** Write a content-free run receipt, release the lock, and emit status/metrics. Staging is cleaned only under the retention policy after referenced bytes are durable.

This protocol is idempotent at three levels: unchanged source generations create no new manifest; duplicate bytes create no new object; replaying a committed manifest into derived/index state reaches the same result.

## 10. Mutation, lineage, and anomaly policy

| Condition | Archive action | Reader/index action |
| --- | --- | --- |
| Open or concurrently changing file | Preserve each exact acquired version; state `open`/`unstable`; retry next reconciliation | Index only complete records through last valid boundary and label coverage partial |
| Appended or otherwise changed file | New object and source generation; prior object remains | Re-read changed occurrence; replace only derived projections tied to old manifest |
| Exact duplicate | Reuse object hash; keep every logical occurrence | May correlate hits, never discard provenance |
| Truncated/replaced file | New object; warning with prior occurrence; never treat shorter file as deletion of suffix | Rebuild projections from new generation; retain old generation queryable by time |
| Malformed JSON/record | Preserve exact bytes and manifest; structural warning | Index valid independent records if reader can prove boundaries; emit diagnostics |
| Resumed session | Preserve native changed/new files and native parent/resume claims | Namespaced graph edge with confidence; no semantic dedup by message text |
| Forked/branched session | Preserve each native representation; Pi in-file branches stay one tree | Preserve parent IDs/branch summaries; expose branch selection in query |
| Migrated/copied session | Preserve new host/path occurrence, often reusing same object | Correlation claim from hash/native ID; retain both source identities |
| Native ID collision | No effect on object/manifest identity | Distinct `(source-id, fingerprint, native-id)` nodes; collision diagnostic if a reader expected uniqueness |
| Source file deleted | New manifest state/tombstone observation; old object retained indefinitely | Mark latest occurrence absent; historical hits remain |
| Source host offline | No data mutation; availability transition/receipt | Search continues over last committed generation; status shows age |
| New schema/record/table | Capture normally; fingerprint/warning changes | Old reader reports unsupported/partial; new reader rebuilds projections |
| Encrypted/opaque content | Capture admitted bytes; record encryption/opaque status | Metadata-only search until a safe reader exists |
| Credential/cache discovered in admitted root | Quarantine staging reference; do not commit payload until policy classifies it | No indexing; security diagnostic without value/path disclosure in logs |

No content-based deduplication is permitted in the authority or baseline index. Similar messages in resumed/forked sessions may be meaningful repetitions. Analytics may offer a duplicate-content view, explicitly labeled derived.

## 11. Query and search model

### 11.1 Rebuildable index

The baseline index is one hub-local SQLite database with FTS5. It is a cache of reader projections, never a transcript store. Its logical tables represent:

- input manifest watermarks and reader/format versions;
- source occurrences and exact native locators;
- session/thread/branch nodes and confidence-labeled lineage claims;
- message/tool/reasoning/document projections where understood;
- searchable text plus facets; and
- parse/coverage diagnostics.

Each projection’s primary identity includes the input manifest and native locator. Updating a source generation never destroys the ability to query an older manifest; the default view merely selects the latest eligible occurrence. One SQLite writer transaction publishes a consistent watermark. For full rebuilds, construct a new generation beside the old one, run integrity and coverage checks, then atomically switch the active pointer.

### 11.2 Query semantics

Default search covers the latest `complete` generation of every available source and the last complete generation of an offline source. It visibly reports excluded coverage: open/partial sources, unsupported fingerprints, opaque records and unindexed attachments. Options may include unstable/latest captures or historical generations.

Supported baseline facets are: host, agent family, surface, source, project/workspace, native session/thread ID, model, role/event kind, tool, date range, completeness, parse status, lineage relation and manifest generation. A result contains:

- a local snippet and score;
- interpreted facets with confidence;
- source state and index coverage;
- `(host-id, source-id, manifest-id, relative path, byte/record locator)`; and
- the exact object ID(s) needed to retrieve native bytes.

“Open native” resolves the locator through a materialized native tree or streams the object without rewriting it. “Show interpreted” renders a reader projection. The UI must distinguish those actions. Query-time ATIF/Letta export is a third, explicitly lossy action.

Lexical search is required. Semantic/vector search is opt-in, local-only and derived; missing embeddings must fail open to lexical search. Raw `ripgrep` over a selected materialized tree is an emergency fallback and must warn that native data can contain secrets and binary/opaque structures.

### 11.3 Index completeness

For each `(manifest, reader)` pair, the index records counts of discovered entries, read entries, successful projections, partial/malformed records, opaque records and skipped entries with reasons. Search never presents “no result” as “not present” when coverage is incomplete. A reader upgrade invalidates only its projections and dependent exports.

## 12. Component and language boundaries

### 12.1 Haskell core

One Haskell package produces one role-aware executable. Logical components are narrow:

- **coordinator CLI:** configuration validation, locking, scheduled reconciliation, retries, run receipts and status;
- **source-helper mode:** metadata probe and bounded source-local snapshot/stream operations invoked locally or over SSH; no resident agent;
- **object/manifest store:** byte hashing, atomic insertion, deterministic manifests, chain verification and materialization;
- **adapters:** source discovery, allowlists, sidecars, format fingerprints and snapshot classification;
- **readers:** schema-tolerant projections and diagnostics for baseline formats;
- **SQLite index/search:** FTS5 generation, source-linked query and rebuild;
- **verify/recover:** authority verification, state reconstruction and restore audit; and
- **plugin supervisor:** explicit subprocess interface for optional exporters/readers.

The core uses `bytestring`/platform I/O, `aeson`, `sqlite-simple` or `direct-sqlite`, `typed-process`, `optparse-applicative`, `crypton`, `async`/STM and optionally `fsnotify`. It does not implement SSH, rsync, SQLite, compression, backup, a web server, a scheduler, vector search or cloud SDKs.

### 12.2 External tools

- **OpenSSH** supplies authenticated transport and host identity.
- **rsync** supplies efficient file delta/staging where the adapter declares it safe.
- **SQLite CLI/library** supplies logical backups, integrity checks and FTS5.
- **restic** supplies encrypted deduplicating backup and retention.
- **launchd/systemd timers** supply scheduling.
- **AgentsView/Agent Sessions/claude-vault/ccusage** remain optional independent readers.

Every subprocess is invoked with an argument vector, fixed environment allowlist, closed or controlled standard streams, timeout and captured content-free error classification; no shell interpolation of source paths is permitted.

### 12.3 Python and TypeScript boundary

Python is **not** a runtime dependency of collection, verification, baseline index/search or restore. Optional Python packages may implement Harbor/Pydantic ATIF, OpenInference, DuckDB analytics, or Letta’s official Python wrapper behind a versioned stdin/stdout/file plugin contract; Letta’s TypeScript runtime may be used through the same boundary. Plugins receive only explicitly selected native/derived inputs and write only under `derived/`; they cannot access manifest/object write paths.

### 12.4 Haskell versus Python decision matrix

Scores are 0–5. Weighted points are `weight × score / 5`. Core invariants are deliberately weighted above optional analytics.

| Selected-architecture capability | Weight | Haskell | Python | Evidence/judgment |
| --- | ---: | ---: | ---: | --- |
| Model authority/state invariants | 15 | 5 | 4 | Algebraic types and explicit effects fit completeness and commit states; both can be correct |
| Exact byte I/O and hashing | 10 | 5 | 5 | Mature libraries/stdlib in both |
| Tolerant JSON/JSONL drift | 10 | 4 | 5 | `aeson Value` is sufficient; Python iterates slightly faster |
| SQLite/FTS and snapshots | 10 | 4 | 5 | Both mature; Python exposes backup APIs more directly; external SQLite avoids a core dependency on that advantage |
| Filesystem/process/SSH/rsync integration | 15 | 5 | 5 | Mature `typed-process`/platform tools and Python stdlib |
| Bounded concurrency/failure modeling | 10 | 5 | 4 | Haskell `async`/STM and typed states are a strong fit |
| CLI and Nix multi-platform deployment | 10 | 5 | 4 | Both package cleanly; one compiled closure and established user preference favor Haskell |
| Testing and single-operator maintenance | 15 | 4 | 4 | QuickCheck/tasty and pytest/Hypothesis are both adequate; adapter churn favors Python, invariant-heavy core favors Haskell |
| Optional DuckDB/ATIF/OpenInference ecosystem | 5 | 2 | 5 | Python is materially stronger, but these components are optional plugins |
| **Total** | **100** | **90** | **90** | Tie; the explicit Haskell preference governs because Haskell satisfies every core need |

**Decision:** Haskell. This is not a claim that its data/AI ecosystem is stronger. It is a statement that the selected core does not require Python’s stronger ecosystem. The language decision reverses if any bounded experiment in section 18 shows a core requirement cannot be met cleanly in the pinned Haskell/Nix closure, or if at least two authoritative source adapters require maintained Python-only libraries that cannot be isolated as reader plugins without duplicating snapshot/provenance logic.

## 13. Nix packaging and deployment shape

The later implementation flake should expose these logical outputs for `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`:

- `packages.<system>.session-archive`: pinned Haskell executable plus runtime declarations for required external tools;
- `packages.<system>.default`: the same package;
- `apps.<system>.session-archive`: CLI entry point;
- `devShells.<system>.default`: GHC/Cabal, formatting, lint, tests, SQLite/restic/rsync fixtures and Markdown tools;
- `checks.<system>.unit`: pure identity/manifest/state-machine tests;
- `checks.<system>.integration`: synthetic filesystem/JSONL/SQLite/crash/recovery tests;
- `checks.<system>.package`: closure and CLI smoke test;
- `nixosModules.session-archive-source`: user, package, allowlisted source-helper command and optional content-free hook hints;
- `nixosModules.session-archive-hub`: source role plus coordinator service/timer, private storage, status and backup jobs;
- `darwinModules.session-archive-source`: package, user LaunchAgent/helper and optional hook hints; and
- `darwinModules.session-archive-hub`: source role plus `hera` coordinator LaunchAgent/timer, private storage, status and backup jobs.

Module options describe IDs, labels, roots, schedule, concurrency, store path, backup repository references and feature flags. They never contain passwords, private keys or transcript data. Credentials are obtained from owner-only runtime files or credential commands supplied outside the Nix store. Evaluation must reject world-readable archive paths and a hub/source role collision that would create two writers.

Source hosts need the package only when an adapter requires the helper; ordinary immutable/JSONL roots may be pulled with OpenSSH/rsync alone. There is no custom listening port. The hub’s search interface is local CLI initially; a read-only web service is deferred until a concrete remote-query requirement exists.

## 14. Security and privacy

### 14.1 Threat model

Transcripts may contain source code, personal data, secrets printed by tools, credentials pasted by users, malicious filenames, malformed parser inputs, prompt-injection text and executable-looking content. A source host may be compromised and attempt path traversal or object substitution. Optional readers/plugins may be buggy or malicious. The archive protects confidentiality and custody; it does not assert that vendor-generated content is truthful.

### 14.2 Controls

- Run the hub under a dedicated unprivileged account. `config`, `native`, `manifests`, `state`, and `derived` are owner-only; search output inherits the same trust boundary.
- Use SSH public-key authentication, pinned host keys, `BatchMode`, explicit host aliases and least-privilege source access. Prefer a forced-command helper or read-only filesystem account over a general remote shell when practical.
- The helper accepts only configured source IDs and fixed operations. It rejects absolute output paths, `..`, NUL, symlink escapes, devices, sockets and paths outside enrolled roots.
- Treat names and metadata as untrusted bytes. Resolve paths beneath an already-open root, never by string concatenation; do not follow symlinks during traversal unless preserving the link itself.
- Stream payloads; never place transcript content in argv, environment, logs, metrics, exception messages or manifest warnings. Redact remote stderr to an error class and private debug artifact with strict permissions if diagnosis requires it.
- Exclude known credential stores, cookies, keychains, transient secret files and generic application caches by explicit adapter policy. When a newly discovered path might contain both transcript and credentials, quarantine and require classification rather than guessing.
- Open native databases read-only for inspection. No journal checkpoint, reindex, vacuum, migration or repair is allowed on producer stores.
- Index/export content is as sensitive as native data. It receives equal filesystem protection and is excluded from ordinary desktop search, cloud sync and crash reporting. Materialized trees use verified read-only copies or copy-on-write reflinks; plugins and readers never receive a writable alias of an authoritative object.
- Optional plugins execute without network by default, with read-only selected inputs and a fresh derived-output directory. They cannot access SSH/restic credentials or authority write paths.
- Backups use restic encryption and independent credentials. Full-disk encryption on `hera` and backup media is recommended but optional under the user’s stated constraint.
- SHA-256 provides content identity and corruption detection, not authenticity against an attacker who can rewrite both objects and manifests. Per-source manifest chaining detects omission/reordering within a retained chain. Optional offline signing or append-only backup anchoring is the upgrade path for hostile-hub tamper evidence.
- No automatic content upload, model call, telemetry content capture, gist/share action or semantic-model download is permitted. External export requires an explicit destination and confirmation outside scheduled collection.

A source transcript can contain instructions aimed at an AI reader. Readers and operators treat it as inert data. Search/render surfaces escape active HTML, terminal control sequences and links by default.

### 14.3 Encryption decision

Encryption in transit is supplied by SSH. Restic encrypts backup repositories. The live hub archive remains ordinary owner-only files so native-byte verification, read-only copy/reflink materialization, existing readers and local recovery remain simple. Host full-disk encryption is recommended. File-level encryption is not required initially because it would add key lifecycle and random-access complexity; revisit if the archive moves to shared storage or host-level encryption cannot satisfy the confidentiality policy.

## 15. Observability and operations

### 15.1 Content-free status

The CLI/status surface reports, by host and source: last attempt/success/complete generation, age, producer/fingerprint, availability/completeness, files/bytes observed and transferred, new/reused objects, manifest ID, index watermark/coverage, backup snapshot IDs, retries and error class. It never reports prompts, snippets, tool outputs, native path text or credentials.

Required metrics are counters/gauges/histograms such as run duration, source age, transferred bytes, object reuse ratio, unstable files, parse coverage, unknown fingerprints, manifest-chain errors, object-verification errors, staging bytes, free-space headroom and backup/restore-check age. Local structured logs and exit codes are sufficient initially; OpenTelemetry emission is optional and content-free.

### 15.2 Health states and alerts

- **Healthy:** every applicable source has a recent complete generation; authority verified; index watermark current or explicitly lagging within policy; required backups recent.
- **Degraded:** one host offline, open/partial source, index lag, optional plugin failure or one redundant backup failed; last complete data remains searchable.
- **Unhealthy:** authority hash/chain failure, no valid backup within policy, free-space safety floor crossed, source silently absent from inventory, or exact-snapshot invariant violated.

Alerts should cover: no daily run, source age beyond policy, first unknown fingerprint, repeated unstable capture, sudden truncation/deletion, material byte-growth anomaly, low disk, object/manifest verification failure, backup failure and overdue sampled restore. An alert identifies IDs and classes only; an operator uses a privileged local diagnostic command for details.

### 15.3 Concurrency and resource limits

Concurrency is bounded separately for hosts, sources, hashing, readers and backup. `vps` receives conservative limits. Indexing and backup yield to authority capture. Free-space policy reserves headroom for the largest observed source generation, staging, index rebuild and restic operation; crossing the hard floor stops new acquisition before the filesystem fills, while verification/search remain available.

## 16. Retention, backup, and recovery

### 16.1 Retention

- Native objects and manifests are retained indefinitely by default.
- Source deletion, vendor cleanup, archive commands, migration and account closure do not propagate deletion into prior authority.
- Unreferenced staging files have a short bounded retention for crash diagnosis, then may be deleted after proving no committed manifest references them.
- Derived trees/indexes/exports follow generation-count or age limits and may be deleted without approval because they are rebuildable; user-created exports outside `derived/` are outside this policy.
- Authority garbage collection is disabled initially. A future policy may remove only objects unreachable from every retained manifest and every backup hold, after dry-run reporting and explicit confirmation. It may never rewrite retained manifests.
- Legal/privacy deletion, if later required, is a separate exceptional policy: append a signed redaction/tombstone decision and remove the specified authority from every replica/backup according to that policy. This design does not pretend immutable retention and erasure are simultaneously automatic.

### 16.2 Backup policy

Use restic for `VERSION`, `config`, `native`, and `manifests`. Maintain at least one repository off `hera`; recommend two failure-independent repositories. Repository credentials are independent of hub login and not stored in Git/Nix. Daily archive snapshots follow successful authority verification. Retention may keep daily/weekly/monthly repository snapshots, but pruning must not remove the only copy of any retained authority generation.

Run regular `restic check`-class integrity verification and a scheduled sampled restore to a fresh temporary root. Periodically perform a full disaster-recovery rehearsal. Backup receipts record repository, snapshot ID, covered manifest heads and verification result but no content.

### 16.3 Recovery solely from preserved authority

A clean recovery requires no source host and no prior SQLite database:

1. Restore `VERSION`, `config`, `native`, and `manifests` from a selected restic snapshot into a new private root.
2. Verify every manifest’s ID, predecessor chain, schema version and referenced object length/hash. Reject missing/colliding objects; do not “repair” from derived data.
3. Reconstruct disposable manifest heads and coordinator state by walking each source chain.
4. Materialize selected `derived/native-trees` from object references and verify every output byte/object link.
5. Recreate any logical SQLite read snapshots required by readers only when the exact native database bundle is usable under its recorded method; otherwise preserve/search metadata and report the gap.
6. Run pinned readers over manifests/objects to build a fresh SQLite/FTS generation with coverage diagnostics; atomically select it.
7. Restore optional exports/analytics by rebuilding them from selected manifests, never by trusting an old derived copy.
8. Compare reconstructed source/head totals with backup receipts and run normal query/native-open smoke checks.
9. Re-enroll source hosts only after recovered authority is healthy; the first post-recovery reconciliation creates successor generations rather than overwriting restored history.

Recovery succeeds at R1/R10 once steps 1–4 verify exact bytes and provenance. Search recovery succeeds after step 6. Unsupported current readers cannot invalidate native recovery.

## 17. Format and version migration policy

- **Manifest schema:** immutable versioned readers support old schemas. A new schema writes new manifests only; old manifests are never rewritten. If an upgraded tool needs a view of an old manifest, it constructs a derived in-memory/current-schema projection with both IDs recorded.
- **Object hashing/encoding:** `sha256` and object layout are versioned in `VERSION`. A future hash algorithm adds a parallel namespace and cross-hash manifest, retaining old objects until every manifest and backup can verify both; no in-place rename.
- **Source fingerprint:** a changed producer version, JSON header/record set, SQLite schema or file magic creates a new fingerprint. Collection continues; semantic indexing is blocked or partial only for the affected fingerprint.
- **Reader:** versions declare supported fingerprints and projection schema. Upgrade rebuilds dependent index partitions/exports and must pass regression fixtures generated from synthetic, redacted structures—not real transcripts.
- **Index:** schema changes always build a new derived generation, verify coverage, then switch atomically. Rollback selects the prior generation.
- **Source migration:** root/account/host changes create or explicitly migrate `source-id` according to enrollment policy. Both old and new occurrences remain; inferred continuity is a reader claim.
- **Vendor export/API:** each response format and endpoint version is a separate source kind/fingerprint. It never becomes a silent replacement for native local data.

The preservation path is deliberately more stable than any parser: unknown future bytes still enter objects/manifests under a generic file-tree adapter when their snapshot coherence is understood.

## 18. Reversal thresholds and bounded pre-implementation experiments

These are evidence-gathering experiments, not an implementation plan. They must use synthetic data or metadata-only copies unless a later confirmed goal authorizes private archive ingestion.

| Decision | Reverse or revise when | Bounded experiment required before implementation |
| --- | --- | --- |
| `hera` primary hub | Less than 2× projected 12-month authority+staging+rebuild headroom, unreliable uptime, or another controlled host proves materially better durability | Measure privacy-safe per-root unique bytes/change rate and `hera` filesystem/backup throughput using synthetic or metadata-only workload |
| Pull reconciliation | SSH reachability/cost prevents meeting daily SLO, or source retention is shorter than worst offline interval | Simulate offline hosts, interruption and catch-up over synthetic trees on all three architectures |
| Exact live SQLite bundle + logical read snapshot | No read-only method can capture a coherent exact bundle without unacceptable disruption | On synthetic WAL databases under concurrent writes, test APFS/filesystem snapshot, coordinated read helper, Online Backup, `VACUUM INTO`, and `sqlite3_rsync`; document which artifact is exact versus logical |
| SQLite/FTS baseline | Representative derived corpus cannot meet agreed search latency/index size/rebuild window, or required analytics are awkward and recurrent | Benchmark synthetic/structure-preserving corpus at ≥2× observed metadata scale; compare SQLite FTS with AgentsView/cass and optional DuckDB |
| Haskell core | Nix cannot produce reliable closures on all three systems; snapshot/SQLite APIs require unsafe bespoke FFI; adapter implementation is materially larger/less maintainable; or ≥2 authoritative adapters require Python-only libraries in the core | Build a throwaway, non-repository spike that performs binary hash/copy, deterministic manifest encode, subprocess timeout, SQLite FTS/backup and Nix builds on Darwin arm64/Linux arm64/Linux x86_64; compare equivalent Python closure/LOC/failure behavior |
| SHA-256 manifests without signatures | Threat model includes a malicious hub administrator or writable backup adversary | Test offline signing/verification and append-only remote anchoring; select key custody before enabling |
| Local CLI only | A concrete need arises for authenticated remote or multi-user queries | Threat-model and prototype a read-only local-socket/SSH-forwarded API; do not expose archive directly |
| Existing reader reuse | AgentsView or another MIT tool proves full target coverage, stable raw-mirror retention and source-linked API without becoming authority | Run read-only against synthetic materialized trees and compare coverage/licensing/operational behavior |
| Indefinite retention | Capacity, legal or privacy policy imposes deletion | Define explicit hold/GC/redaction contract and prove backup-wide deletion before enabling any authority prune |

The language spike is a gate, not permission to implement the system. If Haskell passes the listed core operations, preference decides. Python wins only on demonstrated core complexity/risk, not DuckDB or observability features that remain optional.

## 19. Validation walkthroughs

Each walkthrough begins from a verified manifest head and ends with the invariant it exercises.

### 19.1 Normal daily collection

1. `hera` locks the coordinator and records all 45 inventory cells.
2. Each reachable source is probed; unchanged roots may use metadata to avoid transfer, but any uncertain root is reacquired and hashed.
3. New JSONL bytes enter staging, become content-addressed objects, and receive a successor manifest only after stability and object verification.
4. Compatibility trees and the SQLite index advance atomically; restic snapshots the authority.
5. Repeating the same run finds the same tree digests, transfers no payload already verified, and emits `unchanged`.

**Validated:** R3, R4, R6, R9. Native occurrences remain distinct even when objects deduplicate.

### 19.2 Offline host

1. `vulcan` is unreachable within the SSH timeout.
2. The run records `unavailable` for its enrolled sources without manufacturing empty or deleted generations. Other hosts continue.
3. Search uses `vulcan`’s last complete manifests and displays their age plus current offline coverage.
4. On the next reachable run, reconciliation compares source state to the last committed head and catches up; hook history is irrelevant.

**Validated:** R3, R4, R7, R12. An offline host cannot erase or block existing authority.

### 19.3 Interrupted transfer or coordinator crash

- **Before object insertion:** partial data remains under the run/source staging namespace and is resumable or safely discarded after retention.
- **After object insertion but before manifest commit:** immutable unreferenced objects may remain; they are harmless and eligible for future verified reuse/GC.
- **After manifest rename but before mutable head update:** startup reconstructs the head by walking valid manifests; it never rolls back the committed generation.
- **During derived/index/backup work:** authority remains committed; the prior derived pointer stays active; retry resumes from manifest watermarks.

**Validated:** R4, R5, R10, R12. There is no state in which a partial transfer is published as a complete source generation.

### 19.4 Concurrent or live JSONL

1. The adapter records size/mtime before copying a Codex rollout and again afterward.
2. If changed, it retains the acquired exact object as `open`/`unstable` evidence and retries under a unique capture attempt.
3. A stable later copy becomes a new object and complete successor; the earlier object remains historically accessible.
4. The reader indexes only demonstrably complete record boundaries and reports partial coverage.

**Validated:** R1, R5, R7, R11. No byte splice or partial-line normalization occurs.

### 19.5 Desktop or OpenCode live database

1. The adapter identifies database, WAL and SHM plus journal mode and format fingerprint without reading content values.
2. It invokes the experimentally approved source-local read-only strategy. Exact bundle capture and logical SQLite backup receive separate artifact classes and hashes.
3. If coherent exact capture cannot be proved, the bundle is retained as `incoherent`/`unknown`; it is not promoted to complete. The logical snapshot may still support a clearly derived read view.
4. The reader opens only the logical snapshot or an approved coherent bundle. Generic Electron caches and credential files remain excluded.

**Validated:** R1, R5, R8, R11. A consistent re-created SQLite file is never mislabeled byte-identical to the producer files.

### 19.6 Identifier collision and duplicated migration

1. Two hosts contain the same native session ID, either with identical bytes or different bytes.
2. Identical bytes reuse one object; different bytes produce different objects. Both manifests retain host/source/path occurrence.
3. Reader nodes remain distinct under `(source-id, fingerprint, native-id)` and emit a collision/correlation claim rather than merging authority.
4. Search returns both provenances and can group them only in an optional derived view.

**Validated:** R1, R6, R7. Native IDs and content similarity cannot destroy evidence.

### 19.7 Resume, fork, and in-file branch

1. Claude/Codex/Droid resume or fork creates appended/new native material; Pi modifies its tree-shaped session file.
2. Reconciliation stores each changed native generation exactly, including parent/branch records and sidecars.
3. Readers preserve vendor parent edges with confidence and never deduplicate repeated text or flatten Pi into one linear transcript.
4. Historical generation selection reconstructs what was present at each capture.

**Validated:** R6, R7, R11. Semantic lineage remains a derived claim grounded in immutable locators.

### 19.8 Format or schema change

1. A producer upgrade introduces an unknown JSON record type, table/column or file magic.
2. Generic byte collection succeeds and the manifest records a changed structural fingerprint/warning.
3. The old reader emits `unsupported-fingerprint` or partial coverage; search remains available for older/understood material.
4. A new reader is tested on synthetic fixtures and rebuilds only derived projections/index generations.

**Validated:** R1, R2, R7, R11. Parser lag cannot cause data loss or authority migration.

### 19.9 Index loss and rebuild

1. Delete all of `state/` and `derived/`, including SQLite/FTS, materialized trees, read snapshots and exports.
2. Verify manifest chains and objects, reconstruct heads, materialize required trees/read snapshots, and run pinned/current readers.
3. Build a fresh index generation, compare manifest/reader coverage totals, and switch it active.
4. Search hits resolve to the same manifest/object locators as before; optional exports are regenerated only on demand.

**Validated:** R2, R9, R10. No normalized database is needed for recovery.

### 19.10 Hub loss and recovery from native authority

1. On a clean machine, restore `native/` and `manifests/` from an off-hub restic snapshot. Restore `config/` when available; it is needed to resume collection policy, not to verify captured bytes/provenance.
2. Verify every manifest/object and reconstruct source heads from manifest chains alone. If `config/` is unavailable, enrollment labels/roots and capture history remain recoverable from manifests, while credentials and future scheduling must be re-established.
3. Materialize native layouts and rebuild readers/index from exact objects and manifests. Unsupported records remain intact and visible as coverage gaps.
4. Compare restored heads with backup receipts and run sampled native-open/search checks before reconnecting source hosts.

**Validated:** R1, R2, R6, R10, R11. Exact captured bytes and provenance recover solely from `native/` plus `manifests/`; neither source hosts nor prior derived state is required.

## 20. Requirement-to-decision traceability

| Requirement | Decisions that satisfy it | Validation |
| --- | --- | --- |
| **R1 Native authority** | Exact SHA-256 objects; immutable occurrence manifests; exact/logical SQLite distinction (sections 4–6, 8) | 19.4–19.6, 19.10 |
| **R2 No required canonical form** | `state/derived` disposable; readers/exports are projections (sections 4, 8, 11) | 19.8–19.10 |
| **R3 Complete declared scope** | Enrolled source inventory and explicit source states; 45-cell research matrix (sections 1, 9; [research inventory](RESEARCH.md#complete-agent-machine-inventory)) | 19.1–19.2 |
| **R4 Incremental/idempotent** | Hash dedup, tree digest, immutable successor commit, resumable staging (sections 6, 9) | 19.1, 19.3 |
| **R5 Live-store safety** | Source-class snapshot contracts; no false complete state (sections 8–10) | 19.3–19.5 |
| **R6 Provenance/identity** | Enrollment IDs, manifest/object/session namespaces, source locators (sections 6, 8, 11) | 19.6–19.7, 19.10 |
| **R7 Loss/mutation visibility** | Immutable generations and explicit anomaly policy (sections 9–10) | 19.2, 19.4, 19.6–19.8 |
| **R8 Self-hosted privacy** | Pull-only private archive, content-free observability, plugin sandbox, no automatic upload (sections 7, 12, 14–15) | 19.5 plus repository privacy scan |
| **R9 Search/read** | SQLite FTS projections with exact native locators and coverage (section 11) | 19.1, 19.9 |
| **R10 Backup/raw recovery** | Restic authority scope, chain/hash verify, clean rebuild (section 16) | 19.3, 19.9–19.10 |
| **R11 Schema evolution** | Preserve-before-parse fingerprints; versioned readers/manifests/indexes (sections 8, 17) | 19.4, 19.7–19.10 |
| **R12 Operability** | One writer, bounded concurrency, offline tolerance, content-free health (sections 7, 9, 15) | 19.1–19.3 |
| **R13 Nix portability** | Three-system flake outputs and role modules (section 13) | Section 18 Haskell/Nix experiment |
| **R14 Language fitness** | Capability matrix, Haskell tie-break and reversal threshold (section 12.4) | Section 18 language experiment |
| **R15 Security/retention** | Least privilege, optional encryption, indefinite authority retention and explicit deletion (sections 14, 16) | 19.2–19.5, 19.10 |

All fixed requirements map to a decision and a validation path. R13/R14 remain decision-grade rather than implementation-verified and therefore have mandatory bounded experiments before a later implementation goal.

## 21. Unresolved questions and risk register

No question below is silently answered by the recommendation.

| Question/risk | Current treatment | Decision needed or evidence required |
| --- | --- | --- |
| What is the complete standard-account `Claude.app` local/cloud session surface? | Collect documented/observed session roots; mark cloud/side-chat gaps | Metadata-only adapter experiment and account-export comparison under later approval |
| Does `ChatGPT.app` have desktop-only local transcript bytes outside Codex rollouts/state? | Do not treat generic profile caches as transcripts; mark `DU/U` | Vendor documentation or privacy-safe structural comparison |
| Which Cursor DB blobs and cloud sessions can be semantically read? | Preserve exact admitted DB bytes; index Agent JSONL; expose unknown coverage | Version-pinned reader evaluation; never gate preservation on decoding |
| Is Factory Sessions API enabled and what is organization retention? | Local JSONL is primary; API is separate optional export | Operator checks organization capability/policy without exposing content |
| Can exact WAL SQLite bundles be captured coherently without source mutation? | Hard gate; retain uncertain captures but do not call complete | Section 18 concurrent-WAL experiment on every relevant filesystem |
| Which macOS metadata are native session data (xattrs/resource forks/hardlinks)? | Manifest supports admitted metadata; default adapter must be conservative | Inspect vendor docs and synthetic behavior before choosing allowlists |
| What are daily change rate, unique-byte ratio and 12-month capacity? | `hera` provisional hub with safety floor | Metadata-only/dry-run sizing and restic dedup measurements |
| Which off-hub backup repositories satisfy failure independence? | Require ≥1, recommend 2; `andoria-08` only a candidate | Select endpoints, retention, credential custody and restore SLO |
| What freshness/search/rebuild SLOs are actually required? | Daily completeness, lexical baseline; no invented latency target | User sets SLOs after synthetic benchmark results |
| Is full path text acceptable in a private index/manifest? | Private manifests retain reversible path bytes; ordinary logs omit paths | Confirm privacy policy; optionally add display-path hashing/redaction in derived UI |
| Should authority be cryptographically signed? | Hashes/chains plus encrypted backup; no signatures initially | Threat-model hub/backup administrators and choose offline key custody if needed |
| May an archive ever honor privacy/legal erasure? | Indefinite retention; no authority GC; exceptional policy named but undefined | Separate policy design before any deletion feature |
| Will Haskell/Nix packaging remain maintainable across the fleet? | Selected conditionally | Mandatory bounded three-platform spike; Python reversal threshold is explicit |
| Which existing viewer should be the first UI? | None is required; SQLite CLI/index is baseline | Read-only synthetic evaluation of AgentsView and Agent Sessions; license review for cass |
| How are real parser regression fixtures obtained without leaking content? | Use synthetic and structurally redacted fixtures only | Define fixture-generation/privacy review in later implementation goal |

Principal residual risks are vendor pruning before reconciliation, undocumented desktop/cloud-only material, an inability to obtain coherent exact live-SQLite bundles without brief quiescence, capacity growth, parser lag, plaintext compromise on the hub, backup credential loss, and accidental inclusion of credential/cache roots. Each has an explicit alert, bounded experiment, or policy gate; none is resolved by normalization.

## 22. Decision package self-check

- **Source of truth:** exact native bytes plus immutable manifests; no normalized representation can replace them.
- **Derived disposability:** deleting every index, logical snapshot, materialized tree and export leaves exact recovery intact.
- **Topology:** one pull coordinator on `hera`; all five hosts and all nine environments remain enrolled, including absent/N/A/unknown cells.
- **Safety:** changing JSONL and WAL SQLite have explicit incomplete/coherent states; no live main-file copy is called complete.
- **Identity:** content hashes deduplicate storage only; host/source/path/native lineage remains preserved.
- **Search:** baseline lexical index returns exact source locators and exposes coverage gaps.
- **Recovery:** `native/` plus `manifests/` recover bytes and provenance without source hosts; `config/` resumes collection policy; indexes rebuild.
- **Language:** Haskell satisfies the selected core and wins the stated preference; Python remains optional for stronger analytics/observability/export ecosystems and has concrete reversal thresholds.
- **Reuse:** OpenSSH, rsync, SQLite, restic, launchd/systemd and existing readers are used before custom infrastructure.
- **Scope:** no implementation code, prototype, rollout command, estimate or task-by-task implementation plan appears here.

This decision is ready for the bounded experiments in section 18 under a separately confirmed implementation-preparation goal. It is not authorization to collect data, deploy services, change host configuration, or mutate any remote machine.
