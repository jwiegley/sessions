# Implementation plan: native-preserving AI session archive

**Status:** proposed implementation sequence; reviewed planning artifact only
**Architecture authority:** [DESIGN.md](DESIGN.md)
**Evidence base:** [RESEARCH.md](RESEARCH.md)
**Planning date:** 2026-08-12
**Execution boundary:** this document authorizes neither implementation nor fleet mutation

## 1. Mandate and planning boundary

This plan translates the selected architecture into work packages suitable for a later `obr` issue tree. It does not reopen the architecture decision. Where implementation evidence may reverse a conditional choice, the relevant experiment precedes the dependent production work and records the decision explicitly.

The plan covers local implementation, synthetic verification, packaging, recovery, and a separately authorized rollout sequence. It does not assign owners, duration, cost, service-level targets, retention periods, or capacity thresholds that the evidence has not established. Missing values remain decision gates.

No work package in this document is active merely because the plan exists. Creating the `obr` tree, performing a spike, ingesting private data, connecting to a fleet host, deploying a package, or enabling a timer each requires a later confirmed goal. The first remote mutation and the first capture of private session bytes are separate authorization boundaries.

### 1.1 Source-of-truth invariant

The archive authority consists of exact native byte objects, immutable capture manifests, and the versioned configuration required to interpret their declared scope. `state/` and `derived/` are disposable. A normalized record, SQLite index, materialized tree, viewer database, API response, telemetry backend, or restic repository cannot silently replace the three authoritative inputs.

Every production package preserves the following consequences:

1. Object identity is SHA-256 over exact captured bytes; parsing and reserialization never establish identity.
2. Physical deduplication never erases a logical host/source/path occurrence.
3. A committed manifest generation is immutable and chained to its predecessor.
4. Unknown or malformed data is preserved before interpretation.
5. A source generation is `complete` only after its snapshot contract proves completeness or coherence.
6. `state/` and `derived/` may be deleted and reconstructed without loss of native bytes or provenance.
7. A source deletion or truncation creates new evidence; it does not rewrite prior evidence.
8. Materialized views use verified read-only copies or copy-on-write reflinks. Writable aliases to authoritative objects are forbidden.
9. Logs, metrics, errors, and ordinary status output contain no transcript content, native path text, command output, or credentials.
10. Raw-byte and manifest-provenance salvage from `native/` plus `manifests/` requires neither a source host nor prior mutable state. Full R10 operational recovery—including trusted interpretation, search reconstruction, policy, and source re-enrollment—also requires restored `VERSION`, versioned `config/`, and `readers.lock`.

### 1.2 Hard rejection gates

A package design is rejected if it:

- replaces native artifacts with normalized, reserialized, compressed-only, database-only, or export-only data;
- requires a source host to restore captured bytes;
- grants archive custody to an index, viewer, telemetry system, cloud API, or backup implementation;
- silently omits an absent, inaccessible, opaque, cloud-only, unsupported, or unknown source;
- treats a copied live SQLite main file as a complete database;
- sends archive content to a third party without a separate explicit export action;
- introduces a second archive writer or bidirectional merge path;
- makes Python the core merely because its general ecosystem is larger; or
- weakens a trust-boundary check, crash invariant, or recovery proof for implementation convenience.

### 1.3 Fixed implementation posture

The following choices remain fixed unless the named gate records evidence meeting the reversal threshold:

- `hera` is the sole coordinator, authority writer, index host, and backup initiator (`GATE-03`).
- Collection is scheduled pull reconciliation over OpenSSH/rsync; lifecycle hooks are latency hints, not completeness (`GATE-04`).
- The core is one role-aware Haskell executable packaged by Nix (`GATE-01`).
- OpenSSH, rsync, SQLite/FTS5, restic, launchd, and systemd are reused rather than reimplemented.
- The baseline search service is local SQLite/FTS5 with exact native locators (`GATE-05`, `GATE-08`).
- Python and TypeScript remain optional plugin runtimes under `derived/`; they do not enter collection, verification, baseline search, or recovery.
- The live archive is owner-only plaintext on a protected host; SSH protects transit and restic encrypts backup repositories (`GATE-07`).
- Native objects and manifests are retained indefinitely by default; authority garbage collection is disabled (`GATE-09`).
- The initial user interface is a local CLI. No custom listening service, vector index, DuckDB baseline, or mandatory telemetry pipeline is planned (`GATE-08`).

## 2. Coverage baseline

This section assigns stable planning locators before package decomposition. Later tables must map every locator to one or more package IDs or to an explicit decision gate.

### 2.1 Requirement ledger

| Locator | Required implementation outcome | Planned coverage |
| --- | --- | --- |
| `R1` | Exact native bytes remain independently verifiable and recoverable | `AUTH-01`, `AUTH-02`, `AUTH-03`, `REC-01` |
| `R2` | All normalization, indexing, analytics, and export remain disposable derivatives | `VIEW-01`, `RDR-01`, `IDX-01`, `PLUG-01`, `REC-01` |
| `R3` | All 45 declared agent-machine cells remain visible, including negative and unknown states | `FND-02`, `ORCH-01`, `OBS-01`, `E2E-01` |
| `R4` | Reconciliation is incremental, idempotent, resumable, and immutable after commit | `STATE-01`, `AUTH-01`, `AUTH-02`, `ORCH-01`, `E2E-01` |
| `R5` | Concurrent JSONL, mutable trees, and WAL SQLite cannot be called falsely complete | `GATE-02`, `CAP-03`, `CAP-04`, `ORCH-01`, `E2E-01` |
| `R6` | Host, source, path, generation, native identifier, and lineage provenance remain distinct | `FND-02`, `AUTH-02`, `RDR-01`, `IDX-01` |
| `R7` | Truncation, deletion, malformed data, schema drift, migration, resume, fork, and branch remain visible | `AUTH-02`, `ORCH-01`, `RDR-01`, `MIG-01`, `E2E-01` |
| `R8` | Collection, logging, indexing, and plugins preserve the self-hosted privacy boundary | `FND-03`, `CAP-02`, `PLUG-01`, `OBS-01`, `NIX-02` |
| `R9` | Cross-agent lexical search returns exact source locators and exposes coverage gaps | `GATE-05`, `RDR-01`, `IDX-01`, `IDX-02` |
| `R10` | Backup and clean recovery work from authority alone | `BACK-01`, `REC-01`, `E2E-01` |
| `R11` | Unknown source and schema versions preserve successfully before reader support exists | `CAP-01`, `AUTH-02`, `RDR-01`, `MIG-01` |
| `R12` | One writer, bounded resources, offline tolerance, and content-free status remain operable | `STATE-01`, `ORCH-01`, `OBS-01`, `NIX-02` |
| `R13` | One pinned closure supports Darwin arm64, Linux arm64, and Linux x86_64 roles | `GATE-01`, `FND-01`, `NIX-01`, `NIX-02` |
| `R14` | Haskell remains the core unless architecture-specific evidence activates the Python reversal | `GATE-01`, `FND-01`, `REL-01` |
| `R15` | Least privilege, owner-only data, explicit retention, and destructive-policy gates are enforced | `GATE-07`, `GATE-09`, `FND-03`, `BACK-01`, `NIX-02` |

### 2.2 Design-section ledger

| Locator | Design obligation | Planned coverage |
| --- | --- | --- |
| `D4` | Authority tiers and non-negotiable invariants | `AUTH-01`–`AUTH-03`, `STATE-01`, `REC-01` |
| `D5` | Exact logical hierarchy and safe materialized views | `FND-02`, `AUTH-01`, `AUTH-02`, `STATE-01`, `VIEW-01`, `BACK-01` |
| `D6` | Stable archive identities, deterministic manifests, and logical occurrence preservation | `FND-02`, `AUTH-01`, `AUTH-02`, `RDR-01` |
| `D7` | Single-writer host roles and inward-only data flow | `GATE-03`, `CAP-02`, `ORCH-01`, `NIX-02` |
| `D8` | Adapter, snapshot, reader, and optional-export contracts | `CAP-01`–`CAP-04`, `SRC-01`–`SRC-09`, `RDR-01`–`RDR-10`, `PLUG-01` |
| `D9` | Fifteen-step idempotent reconciliation transaction | `STATE-01`, `AUTH-01`–`AUTH-03`, `ORCH-01`, `BACK-01` |
| `D10` | Mutation, anomaly, deduplication, and lineage policy | `AUTH-02`, `ORCH-01`, `RDR-01`, `MIG-01` |
| `D11` | Rebuildable FTS index, query semantics, native retrieval, and coverage | `GATE-05`, `IDX-01`, `IDX-02` |
| `D12` | Haskell core and constrained external/plugin boundaries | `GATE-01`, `FND-01`, `FND-03`, `PLUG-01` |
| `D13` | Three-system Nix package, app, checks, source modules, and hub modules | `FND-01`, `NIX-01`, `NIX-02` |
| `D14` | Threat model, least privilege, hostile paths/data, plugin isolation, and encryption posture | `GATE-07`, `GATE-11`, `FND-03`, `CAP-02`, `PLUG-01`, `NIX-02` |
| `D15` | Content-free status, health, alerts, concurrency, and disk safety | `GATE-08`, `OBS-01`, `ORCH-01`, `NIX-02` |
| `D16` | Retention, restic backup, integrity checking, and authority-only recovery | `GATE-03`, `GATE-09`, `BACK-01`, `REC-01` |
| `D17` | Manifest, hash, source, reader, index, migration, and export version policy | `AUTH-02`, `RDR-01`, `IDX-01`, `MIG-01` |
| `D18` | Reversal thresholds and bounded evidence gates | `GATE-01`–`GATE-11`, `REL-01` |

### 2.3 Experiment ledger

The nine design experiments retain their original order. A gate is accepted only through recorded evidence; a failed gate selects the documented reversal or returns the architecture to review.

| Locator | Experiment and decision | Gate | Dependent production work |
| --- | --- | --- | --- |
| `E01` | Measure unique bytes, change rate, hub throughput, and headroom; prove at least one failure-independent off-hub endpoint through approved credential use, reachability, integrity check, synthetic backup, and hash-verified clean restore; retain or reverse `hera` and the candidate endpoint | `GATE-03` | `BACK-01`, `NIX-02`, rollout |
| `E02` | Simulate SSH outage, interruption, resume, and catch-up across all target architectures; retain or revise pull reconciliation | `GATE-04` | `CAP-02`, `ORCH-01`, `NIX-02` |
| `E03` | Compare coherent exact WAL bundle methods with logical SQLite snapshots under concurrent synthetic writes | `GATE-02` | `CAP-04`, SQLite-backed source adapters |
| `E04` | Benchmark SQLite/FTS and optional readers at structure-preserving scale; retain or revise baseline search | `GATE-05` | `IDX-01`, `IDX-02`, `GATE-08` |
| `E05` | Build the bounded Haskell/Python and three-system Nix spike; retain Haskell or activate the explicit reversal | `GATE-01` | every production package |
| `E06` | Threat-model signatures and append-only anchoring; retain unsigned chains or select key custody | `GATE-07` | `AUTH-02`, `BACK-01` |
| `E07` | Establish whether local CLI remains sufficient; a remote API is considered only after a concrete need | `GATE-08` | `IDX-02`, `NIX-02` |
| `E08` | Evaluate AgentsView, Agent Sessions, and licensing against synthetic materialized trees | `GATE-06` | `RDR-01`–`RDR-10`, `PLUG-01`, `DOC-01` |
| `E09` | Define hold, garbage-collection, and redaction policy only if capacity or law requires deletion | `GATE-09` | retention configuration; no authority prune otherwise |

### 2.4 Unresolved-question ledger

| Locator | Unresolved question or risk | Required disposition |
| --- | --- | --- |
| `Q01` | Complete standard-account Claude Desktop local/cloud surface | `GATE-10`; unknown remains explicit until approved metadata-only evidence exists |
| `Q02` | Desktop-only Codex bytes outside shared rollouts/state | `GATE-10`; generic browser caches remain excluded |
| `Q03` | Cursor database blobs and cloud-session semantic coverage | `GATE-10`, `SRC-08`, `RDR-09`; byte preservation does not wait for decoding |
| `Q04` | Factory Sessions API eligibility and organization retention | `GATE-10`, `SRC-09`; API export remains a separate optional source |
| `Q05` | Read-only coherent exact WAL capture | `GATE-02`; `CAP-04` cannot claim complete without accepted evidence |
| `Q06` | Which macOS xattrs, resource forks, and hardlink relations are semantically native | `GATE-11`; conservative allowlists precede desktop adapters |
| `Q07` | Daily change rate, deduplication ratio, and capacity | `GATE-03`; no fabricated forecast |
| `Q08` | Failure-independent backup endpoints and restore expectations | `GATE-03`; `BACK-01` remains blocked until at least one off-hub endpoint passes approved credential use, reachability, integrity check, synthetic backup, and hash-verified clean restore |
| `Q09` | Freshness, search, and rebuild service levels | `GATE-05` measurements followed by `GATE-08` user decision |
| `Q10` | Private full-path display and indexing policy | `GATE-08`; reversible private paths remain authoritative regardless of UI policy |
| `Q11` | Signature and key-custody requirement | `GATE-07`; unsigned SHA-256 chains remain baseline unless threat model reverses it |
| `Q12` | Privacy/legal erasure policy | `GATE-09`; authority garbage collection remains disabled |
| `Q13` | Haskell/Nix maintainability on all target systems | `GATE-01`; Python reversal remains evidence-bound |
| `Q14` | First optional viewer | `GATE-06`; local SQLite CLI is sufficient baseline |
| `Q15` | Privacy-safe parser fixture production | `GATE-11`; synthetic or structurally redacted fixtures only |

### 2.5 Research constraints

| Locator | Constraint carried into implementation |
| --- | --- |
| `RC01` | Vendor-native artifacts, not ATIF, Letta, telemetry, audit records, or an index, are archival authority. |
| `RC02` | Codex and Droid hooks exist but are bounded and disableable; reconciliation remains the completeness mechanism. |
| `RC03` | OpenCode and several desktop surfaces use live SQLite; a main-file copy cannot establish completeness. |
| `RC04` | Pi sessions are mutable trees within one JSONL file; branching cannot be flattened into a linear transcript. |
| `RC05` | Desktop application presence does not prove a complete distinct local transcript store. Unknown and cloud-only coverage remains visible. |
| `RC06` | Existing readers and normalizers are parser prior art or optional projections, never archive custody. |
| `RC07` | Haskell has adequate core libraries; Python is materially stronger only for optional DuckDB, ATIF/Pydantic, OpenInference, and some adapter ecosystems. |
| `RC08` | Observed fleet size is a discovery signal, not a capacity forecast; private-data sizing requires later approval. |
| `RC09` | `cass` licensing requires review before reuse; no package assumes that reuse. |
| `RC10` | Real transcript excerpts, credentials, tool output, and native path text do not enter fixtures, logs, issue descriptions, or ordinary evidence. |

### 2.6 Validation-scenario ledger

| Locator | Design walkthrough | Planned evidence |
| --- | --- | --- |
| `S01` | Normal daily collection and unchanged rerun | `ORCH-01`, `IDX-01`, `BACK-01`, `E2E-01` |
| `S02` | Offline host, stale-but-searchable data, and later catch-up | `GATE-04`, `ORCH-01`, `OBS-01`, `E2E-01` |
| `S03` | Interrupted transfer or crash at every commit boundary | `STATE-01`, `AUTH-01`–`AUTH-03`, `ORCH-01`, `E2E-01` |
| `S04` | Concurrent or live JSONL | `CAP-03`, `SRC-01`–`SRC-03`, `SRC-05`, `E2E-01` |
| `S05` | Desktop or OpenCode live database | `GATE-02`, `CAP-04`, `SRC-04`, `SRC-06`–`SRC-09`, `E2E-01` |
| `S06` | Native identifier collision and duplicated migration | `AUTH-02`, `RDR-01`, `IDX-01`, `E2E-01` |
| `S07` | Resume, fork, and Pi in-file branch | `SRC-01`–`SRC-03`, `SRC-05`, `RDR-02`–`RDR-04`, `RDR-06`, `E2E-01` |
| `S08` | Format or schema change with preservation ahead of interpretation | `CAP-01`, `RDR-01`, `MIG-01`, `E2E-01` |
| `S09` | Total loss and rebuild of state, materialized trees, and index | `VIEW-01`, `IDX-01`, `REC-01`, `E2E-01` |
| `S10` | Hub loss and recovery solely from preserved authority | `AUTH-03`, `BACK-01`, `REC-01`, `E2E-01` |

## 3. Work-package contract

Every package heading uses a stable identifier of the form `FAMILY-NN`. Later `obr` creation preserves the identifier in the issue title or external reference. Renaming prose does not change the identifier.

Each package contains the same mandatory fields:

- **Purpose:** the single reviewable outcome.
- **Inputs:** decisions, contracts, or prior artifacts consumed.
- **Outputs:** concrete implementation or evidence artifacts produced.
- **Depends on:** package IDs whose completion is a prerequisite; `none` means no graph edge.
- **Completion evidence:** observable conditions required before closure.
- **Tests:** runnable or reviewable evidence, using synthetic or structurally redacted data only.
- **Safety and rollback:** how failure remains non-destructive and how the prior valid state is retained.
- **Traceability:** requirement, design, experiment, scenario, question, or research locators satisfied.

A package does not receive an estimate or owner in this plan. An `obr` issue may later add assignment, but dependencies and acceptance evidence remain authoritative.
## 4. Sequence and dependency model

The issue tree follows six implementation phases and one dormant deployment track. Phase boundaries are evidence boundaries: passing a phase means that its artifacts can be consumed by the next phase without relying on an unverified proxy. Gate packages may run concurrently where their inputs are independent, but no production package begins before `GATE-01` records the core-language and three-system packaging decision.

### 4.1 Phase structure

| Phase | Purpose | Packages | Exit evidence |
| --- | --- | --- | --- |
| **0. Bounded decisions** | Resolve or explicitly retain every conditional architecture choice before dependent work | `GATE-01`–`GATE-11` | Decision records identify evidence, result, reversal outcome, and dependent packages released or returned to design |
| **1. Authority foundation** | Establish the minimal Haskell/Nix base, configuration, trust primitives, immutable authority, and disposable state | `FND-01`–`FND-03`, `AUTH-01`–`AUTH-03`, `STATE-01` | Exact bytes and deterministic manifests survive crash injection and state deletion under synthetic tests |
| **2. Collection** | Implement generic capture contracts, one-writer reconciliation, and the nine declared source surfaces | `CAP-01`–`CAP-04`, `ORCH-01`, `SRC-01`–`SRC-09` | Every declared surface produces an explicit complete, partial, absent, unavailable, not-applicable, or unknown synthetic observation without weakening snapshot rules |
| **3. Interpretation and search** | Materialize safe native views, interpret supported formats, build the disposable index, and isolate optional plugins | `VIEW-01`, `RDR-01`–`RDR-10`, `IDX-01`, `IDX-02`; optional `PLUG-01` | Search returns native locators and visible coverage; deleting all derived products permits a complete rebuild; optional plugins may remain deferred |
| **4. Operations and recovery** | Add observability, migration, backup, clean recovery, packaging, and role modules | `OBS-01`, `MIG-01`, `BACK-01`, `REC-01`, `NIX-01`, `NIX-02` | A pinned three-system closure passes synthetic backup, clean restore, migration, privilege, and service-lifecycle checks |
| **5. Acceptance and deployment readiness** | Execute all design walkthroughs locally, complete operator documentation, and record release readiness | `E2E-01`, `DOC-01`, `REL-01` | R1–R15 and S01–S10 have direct evidence; remaining unknowns and rollout prerequisites are explicit |
| **Deployment track** | Introduce private data and fleet mutation only under later, stage-specific confirmations | `APR-01`–`APR-08`, `DEP-01`–`DEP-08` | Every mutating stage is blocked by its own explicit manual approval package, then verifies backup/rollback and stops before the next increase in blast radius |

### 4.2 Critical paths

The **Depends on** fields are authoritative; prose order is not. At plan review, graph expansion yields the following useful critical spines; equal-length predecessor ties are shown explicitly:

```text
Authority and reconciliation (equal longest branches):
GATE-01 -> FND-01 -> FND-02 -> FND-03 -> AUTH-01 -> AUTH-02
  -> AUTH-03 -> ORCH-01
  -> STATE-01 -> ORCH-01

Clean recovery (equal longest branches):
GATE-01 -> FND-01 -> FND-02 -> FND-03 -> AUTH-01 -> AUTH-02
  -> AUTH-03 -> RDR-01 -> IDX-01 -> REC-01
  -> STATE-01 -> ORCH-01 -> BACK-01 -> REC-01

Longest release/deployment spine:
GATE-01 -> FND-01 -> FND-02 -> FND-03 -> AUTH-01 -> AUTH-02
  -> AUTH-03 -> RDR-01 -> IDX-01 -> OBS-01 -> NIX-02
  -> E2E-01 -> DOC-01 -> REL-01
  -> APR-01 -> DEP-01 -> APR-02 -> DEP-02 -> APR-03 -> DEP-03
  -> APR-04 -> DEP-04 -> APR-05 -> DEP-05 -> APR-06 -> DEP-06
  -> APR-07 -> DEP-07 -> APR-08 -> DEP-08
```

The last path is longest because integrated acceptance waits for content-free coverage/status and the role-module checks that expose it. Source/reader packages remain parallel prerequisites of `E2E-01`; they are not optional merely because no one source path is the unique longest chain. `PLUG-01` alone is optional and cannot block baseline acceptance. Any failed authority, snapshot, backup, recovery, security, or required source-coverage package does block release readiness.

### 4.3 Critical gates

| Gate | Blocks | Failure disposition |
| --- | --- | --- |
| `GATE-01` Haskell/Nix fitness | Every production package | Activate the documented Python comparison only on demonstrated core complexity or risk; preserve all authority contracts |
| `GATE-02` exact WAL coherence | `CAP-04`, SQLite-backed source completion | Retain exact acquisitions as `incoherent` or `unknown`; do not claim complete or weaken R1/R5 |
| `GATE-03` hub capacity and backup independence | `BACK-01`, `NIX-02`, all deployment packages | Keep dependents blocked until another controlled hub/endpoint passes sizing, failure-domain, approved-credential, reachability, integrity-check, synthetic-backup, and hash-verified clean-restore evidence |
| `GATE-04` pull reconciliation | `CAP-02`, `ORCH-01`, `NIX-02` | Revise transport/cadence only from measured reachability and retention evidence; retain one writer |
| `GATE-05` SQLite/FTS fitness | `IDX-01`, `IDX-02` | Revise the disposable search tier without migrating authority |
| `GATE-06` existing-reader reuse | Format-specific readers and `PLUG-01` | Reuse only tools that preserve source-linked boundaries and acceptable licensing; otherwise implement the smallest missing reader |
| `GATE-07` security, encryption, and signing posture | `AUTH-02`, `BACK-01`, `NIX-02` | Select key custody or stronger storage controls before dependent work; never add signatures without recoverable keys |
| `GATE-08` operator policy and interface | `IDX-02`, `OBS-01`, `NIX-02`, deployment | Keep the local CLI and unspecified SLOs until concrete evidence and user decisions exist |
| `GATE-09` retention and erasure | `BACK-01`, destructive retention options | Keep indefinite authority retention and disabled garbage collection unless an explicit policy proves otherwise |
| `GATE-10` desktop/cloud coverage | Desktop source packages | Preserve documented roots and explicit unknown states; do not infer transcripts from caches |
| `GATE-11` metadata and fixture privacy | Source adapters and readers | Use conservative metadata allowlists and synthetic fixtures until policy evidence is accepted |

### 4.4 Safe parallelism

Parallel work is permitted only where packages write disjoint artifacts and consume stable contracts:

- `GATE-01`–`GATE-07`, `GATE-10`, and `GATE-11` may gather evidence independently; `GATE-08` follows `GATE-05` and `GATE-06`, while `GATE-09` follows `GATE-03` and `GATE-07`.
- After `FND-01`, configuration modeling (`FND-02`) and package/check work (`NIX-01`) may proceed in parallel; trust-boundary primitives (`FND-03`) follow the stable configuration/path types.
- After their shared foundations, object storage (`AUTH-01`), disposable state (`STATE-01`), and generic adapter contracts (`CAP-01`) may proceed in parallel.
- `CAP-02`, `CAP-03`, and `CAP-04` are independent implementations of the stable `CAP-01` contract after their own gates pass.
- `SRC-01`–`SRC-09` are independent extensions of `CAP-01` after their capture and policy gates; they may proceed in parallel with `ORCH-01`, which consumes only the stable adapter contract.
- `RDR-02`–`RDR-10` are independent after `RDR-01`, `GATE-06`, and their source packages.
- `VIEW-01`, the format-specific readers, and the initial `IDX-01` implementation may overlap after their explicit predecessors; publication into an active derived generation remains single-writer.
- Documentation may be drafted alongside implementation, but `DOC-01` cannot close until `E2E-01` establishes actual commands and outcomes.
- Deployment is serial. Each stage increases the data or host blast radius and therefore closes only before the next begins.

Parallel packages never share a writable worktree, authority root, test repository, or derived-generation destination. Integration occurs through reviewed contracts and synthetic fixtures.

## 5. Decision-gate packages

The gate packages produce evidence and decisions rather than production code. Their outputs are durable inputs to the later `obr` graph; an experiment’s command transcript or private data does not belong in an issue description.

### GATE-01 — Select the core language and prove three-system Nix fitness

- **Purpose:** execute the bounded architecture-specific Haskell/Python comparison and select the language used by every production package.
- **Inputs:** the core operation list, language matrix, and reversal threshold in [DESIGN.md](DESIGN.md#124-haskell-versus-python-decision-matrix) and [section 18](DESIGN.md#18-reversal-thresholds-and-bounded-pre-implementation-experiments).
- **Outputs:** an evidence record covering binary copy/hash, deterministic manifest encoding, subprocess timeout/cancellation, SQLite FTS/backup access, closure composition, and builds on Darwin arm64, Linux arm64, and Linux x86_64; a recorded Haskell or Python decision.
- **Depends on:** `none`.
- **Completion evidence:** both bounded implementations are compared on closure reproducibility, unsafe FFI, adapter boundary size, failure behavior, and maintainability; Haskell remains selected unless the documented core-risk threshold is met; the spike remains outside the production tree.
- **Tests:** build and run the bounded operations against synthetic bytes and SQLite data on all three systems; record exact commands, closure/tool versions, failures, and comparative code boundaries.
- **Safety and rollback:** the spike has no archive path, private fixture, source-host access, or deployment output. Failure changes only the language decision; object, manifest, adapter, and recovery contracts remain unchanged.
- **Traceability:** `R13`, `R14`, `D12`, `D13`, `D18`, `E05`, `Q13`, `RC07`.

### GATE-02 — Prove live-WAL capture semantics

- **Purpose:** select the read-only method that distinguishes an exact coherent DB/WAL/SHM bundle from a consistent logical SQLite snapshot.
- **Inputs:** SQLite artifact distinctions and the live-store hard gate in `D8`, `D18`, `Q05`, and `RC03`.
- **Outputs:** a per-filesystem method matrix for APFS/filesystem snapshots, coordinated read helpers, Online Backup, `VACUUM INTO`, and `sqlite3_rsync`, with exact-versus-logical classification and disruption constraints.
- **Depends on:** `none`.
- **Completion evidence:** concurrent-write trials establish which method, if any, proves a coherent exact bundle on each target filesystem; every unproved result is classified `incoherent` or `unknown`, never `complete`.
- **Tests:** generate synthetic WAL workloads with commits before, during, and after capture; compare SQLite integrity, transaction visibility, source artifact hashes/metadata, and reader behavior.
- **Safety and rollback:** trials use disposable databases only and prohibit checkpoint, vacuum, migration, or repair of a producer store. If no safe exact method exists, retain the architecture’s incomplete-state behavior and return the affected adapter to design review.
- **Traceability:** `R1`, `R5`, `R8`, `R11`, `D8`, `D10`, `D18`, `E03`, `Q05`, `S05`, `RC03`.

### GATE-03 — Confirm hub capacity and backup independence

- **Purpose:** retain or reverse `hera` as the sole hub and prove at least one failure-independent off-hub backup endpoint fit before backup production work begins.
- **Inputs:** aggregate fleet evidence, the provisional topology, capacity reversal threshold, `Q07`, `Q08`, candidate endpoint failure domains, and an experiment-scoped credential command supplied through an approved secret channel under a later confirmed experiment goal.
- **Outputs:** an approved sizing method; authority/staging/rebuild headroom calculation; measured synthetic or separately authorized metadata-only throughput; endpoint failure-domain assessment; selected primary/off-hub roles; and a content-free endpoint-validation receipt recording reachability, credential-command result, synthetic snapshot ID, integrity-check result, clean-restore result, and restored hashes.
- **Depends on:** `none`.
- **Completion evidence:** the chosen hub satisfies the design’s headroom and administrative-control threshold, and at least one endpoint outside the hub’s failure domain is exercised successfully rather than merely identified: approved credentials open an isolated synthetic restic repository, the endpoint is reachable, a synthetic `VERSION`/`config/`/`native/`/`manifests/` fixture is backed up, the repository passes `restic check`, and a restore into a fresh root reproduces every fixture hash. Unexercised or failing candidates do not count as redundancy; `BACK-01`, `NIX-02`, and deployment remain blocked until one candidate passes.
- **Tests:** exercise filesystem and backup throughput with synthetic data; model the largest observed source generation, staging, index rebuild, and backup overlap; test correct and rejected credentials without exposing them; test unreachable endpoint failure; create a synthetic authority snapshot; run an integrity check; restore into an empty temporary root; and compare the complete file/hash inventory.
- **Safety and rollback:** no private-byte measurement, endpoint access, repository creation, or host mutation occurs without a later confirmed experiment goal and explicit permission for the named endpoint. Use an isolated synthetic repository namespace, never log credential values, never prune or alter an existing repository, and remove only the isolated fixture/repository when approved. If no endpoint passes or `hera` fails, keep dependent packages blocked and return host/endpoint roles to architecture review.
- **Traceability:** `R8`, `R10`, `R12`, `R15`, `D7`, `D14`, `D15`, `D16`, `D18`, `E01`, `Q07`, `Q08`, `S10`, `RC08`, `RC10`.

### GATE-04 — Validate pull reconciliation and offline recovery

- **Purpose:** retain scheduled SSH/rsync pull reconciliation as the completeness mechanism under outage, interruption, and retention pressure.
- **Inputs:** one-writer topology, source lifecycle evidence, and experiment `E02`.
- **Outputs:** a transport/cadence decision record covering pinned-host SSH, partial rsync state, timeout, interruption, resume, offline age, and catch-up on all three system architectures.
- **Depends on:** `none`.
- **Completion evidence:** synthetic sources converge after repeated interruption and offline intervals without bidirectional merge, source mutation, duplicate authority, or reliance on lifecycle hooks; any cadence requirement not established by evidence remains a user gate.
- **Tests:** simulate unreachable hosts, changed files during transfer, stale partials, source truncation, and catch-up; assert that other hosts proceed and prior complete generations remain searchable.
- **Safety and rollback:** use local synthetic SSH fixtures or isolated test machines approved for the experiment. A failure may revise transport or cadence, but it cannot introduce a second writer or make hooks authoritative.
- **Traceability:** `R3`, `R4`, `R7`, `R12`, `D7`, `D9`, `D18`, `E02`, `S02`, `S03`, `RC02`.

### GATE-05 — Validate SQLite/FTS fitness

- **Purpose:** confirm that the disposable SQLite/FTS5 tier meets measured lexical search, index-size, and rebuild needs before implementing it as baseline.
- **Inputs:** query/coverage contract, observed structural scale, and `E04`; no invented latency or rebuild target.
- **Outputs:** a reproducible synthetic benchmark corpus and results for index build, update, query facets, coverage accounting, index size, and full rebuild; comparison notes for AgentsView, `cass`, and optional DuckDB where lawful and useful.
- **Depends on:** `none`.
- **Completion evidence:** measured results are presented against user-approved targets, or the target decision remains open under `GATE-08`; any replacement remains disposable and source-linked.
- **Tests:** run cold rebuild, incremental update, representative lexical/facet queries, malformed/opaque coverage, and index deletion/recreation at no less than the design’s structure-preserving scale.
- **Safety and rollback:** benchmarks contain no real transcript text or private paths. Failure changes only the derived search implementation; authority and recovery contracts remain fixed.
- **Traceability:** `R2`, `R9`, `R11`, `D11`, `D18`, `E04`, `Q09`, `S09`, `RC06`, `RC08`.

### GATE-06 — Select reusable readers and viewers

- **Purpose:** determine which existing readers reduce custom parser or UI work without assuming archive custody.
- **Inputs:** research assessments of AgentsView, Agent Sessions, `cass`, claude-vault, ccusage, ATIF, and Letta; licensing constraint `RC09`.
- **Outputs:** a source-by-source coverage and behavior matrix, license decision, source-locator assessment, raw-tree requirements, parser diagnostics comparison, and explicit reuse/build decisions.
- **Depends on:** `none`.
- **Completion evidence:** each selected tool operates read-only over synthetic materialized views or derived data, cannot write authority, exposes acceptable provenance/coverage, and has acceptable licensing; unsupported formats remain assigned to the smallest custom reader packages.
- **Tests:** run candidate tools against synthetic complete, malformed, branched, duplicated, and unknown-version fixtures; compare their outputs to the reader contract rather than to one another.
- **Safety and rollback:** candidates execute in isolated derived directories without network or authority credentials. Rejected tools leave no runtime dependency or canonical schema.
- **Traceability:** `R2`, `R9`, `R11`, `D8`, `D11`, `D12`, `D18`, `E08`, `Q14`, `RC06`, `RC09`.

### GATE-07 — Fix encryption, signing, and key-custody posture

- **Purpose:** turn the design threat model into an accepted custody posture before manifest signing, backup, or deployment choices become code.
- **Inputs:** owner-only plaintext decision, SSH/restic encryption, SHA-256 chain limits, signature experiment `E06`, and unresolved key-custody question `Q11`.
- **Outputs:** a threat model decision covering hub administrator, compromised source, writable backup adversary, offline signing, append-only anchoring, full-disk encryption, restic credentials, key loss, and recovery.
- **Depends on:** `none`.
- **Completion evidence:** the baseline unsigned-chain posture is explicitly accepted or a recoverable signing/key-rotation design is selected; credential and key locations are outside Git/Nix; every control has a recovery consequence.
- **Tests:** exercise synthetic sign/verify, corrupted chain, wrong key, lost key, rotated key, hostile path, and backup-credential failure as applicable to the selected posture.
- **Safety and rollback:** no production key is created during evaluation. Signing is not enabled until restore and rotation work without making historical authority unverifiable.
- **Traceability:** `R1`, `R8`, `R10`, `R15`, `D14`, `D16`, `D18`, `E06`, `Q11`.

### GATE-08 — Record operator policy, interface, paths, and service levels

- **Purpose:** obtain the user decisions that measurement alone cannot supply while retaining the local CLI baseline.
- **Inputs:** `GATE-05`, `GATE-06`, and unresolved `Q09`, `Q10`, and `Q14`.
- **Outputs:** explicit decisions for freshness, search, rebuild, restore expectations; private path display/redaction; first optional viewer; local-only versus remote query; alert thresholds; and any deferred values.
- **Depends on:** `GATE-05`, `GATE-06`.
- **Completion evidence:** every policy-dependent module/index/status option has a selected value or an explicit disabled/deferred state; no remote API or viewer is made mandatory without a concrete need.
- **Tests:** review sample content-free status, coverage, path-display, and CLI query outputs built from synthetic data; verify that unknown or partial coverage cannot appear as absence.
- **Safety and rollback:** retain conservative defaults—local CLI, no remote listener, private reversible paths, and no invented SLO—until the user accepts a change. Interface changes never migrate authority.
- **Traceability:** `R8`, `R9`, `R12`, `R15`, `D11`, `D15`, `D18`, `E07`, `Q09`, `Q10`, `Q14`.

### GATE-09 — Record retention, hold, garbage-collection, and erasure policy

- **Purpose:** preserve indefinite authority retention by default and define a destructive policy only when capacity, legal, or privacy requirements demand it.
- **Inputs:** `GATE-03`, `GATE-07`, retention design, experiment `E09`, and `Q12`.
- **Outputs:** an accepted baseline policy with authority GC disabled; if triggered, a separate hold/redaction/backup-wide deletion design with dry-run, confirmation, audit, and restore consequences.
- **Depends on:** `GATE-03`, `GATE-07`.
- **Completion evidence:** all non-authoritative retention is distinguished from authority deletion; no backup prune can remove the only copy of retained authority; any erasure path has explicit user/legal authorization and cross-repository proof.
- **Tests:** with synthetic manifests and backups, prove that ordinary cleanup affects only staging/derived generations; if destructive policy is selected, prove hold reachability, dry-run accuracy, tombstone/audit behavior, and deletion across replicas.
- **Safety and rollback:** absence of an approved exceptional policy means no authority deletion command or module option exists. A failed destructive-policy test leaves GC disabled.
- **Traceability:** `R1`, `R2`, `R10`, `R15`, `D16`, `D18`, `E09`, `Q12`.

### GATE-10 — Bound desktop and cloud source coverage

- **Purpose:** define what each desktop adapter can collect without inferring transcript completeness from application or cache presence.
- **Inputs:** the four desktop research findings and unresolved `Q01`–`Q04`.
- **Outputs:** an approved root/export/API coverage table for Claude Desktop, Codex Desktop, Cursor, and Factory; explicit local, shared-CLI, cloud-only, unsupported, and unknown states.
- **Depends on:** `none`.
- **Completion evidence:** every desktop surface has allowlisted evidence sources, exclusions, retention uncertainty, and a status rule; generic browser caches and credential stores are not admitted as transcripts.
- **Tests:** use vendor documentation and synthetic directory/database structures; any metadata-only fleet comparison or account export requires a later approved goal and records no content values.
- **Safety and rollback:** unknown remains `unknown`. A newly discovered path is quarantined pending classification rather than silently admitted or excluded.
- **Traceability:** `R3`, `R8`, `R11`, `D8`, `D14`, `D18`, `Q01`, `Q02`, `Q03`, `Q04`, `RC05`.

### GATE-11 — Approve native metadata and fixture-privacy policy

- **Purpose:** determine which filesystem metadata belongs to native custody and how parser fixtures can preserve structure without exposing private content.
- **Inputs:** manifest metadata contract, macOS uncertainty `Q06`, fixture uncertainty `Q15`, and privacy constraint `RC10`.
- **Outputs:** per-platform metadata allowlists for modes, symlinks, xattrs, resource forks, and hardlink groups; a synthetic/structural-redaction fixture policy with review and provenance rules.
- **Depends on:** `none`.
- **Completion evidence:** admitted metadata can be captured, hashed or referenced, restored, and tested; credential-bearing metadata and real content are excluded; structural redaction cannot be mistaken for native authority.
- **Tests:** create synthetic files with links, non-UTF-8 path bytes, modes, xattrs, resource forks where supported, malformed records, and secret-shaped canaries; verify capture/restoration and leakage scans.
- **Safety and rollback:** the default is conservative exclusion with a recorded reason. Policy expansion is versioned and does not rewrite prior manifests.
- **Traceability:** `R1`, `R8`, `R11`, `R15`, `D6`, `D14`, `D17`, `Q06`, `Q15`, `RC10`.

## 6. Authority-foundation packages

These packages establish the only state that later collection may trust. They remain deliberately smaller than the eventual executable’s command surface: common invariants live once, while adapters and readers depend on them.

### FND-01 — Establish the minimal core package and synthetic test harness

- **Purpose:** create the selected role-aware executable skeleton, library boundary, pinned dependency set, and test harness without implementing archive behavior.
- **Inputs:** accepted `GATE-01` decision and the component boundary in `D12`.
- **Outputs:** one core package, one executable entry point with role/command dispatch, library modules for later packages, synthetic fixture support, formatting/lint/test commands, and a dependency lock captured by Nix.
- **Depends on:** `GATE-01`.
- **Completion evidence:** the empty command surface builds and tests on all three target systems; dependencies are limited to selected core needs; no network service, embedded SSH, custom scheduler, vector stack, DuckDB baseline, or plugin runtime enters the core.
- **Tests:** three-system package and CLI smoke checks; test-harness self-test; dependency/closure inspection; warning-free compile, format, lint, and unit-test commands.
- **Safety and rollback:** no archive directory, config, source root, database, credential, or timer is created. Revert consists solely of removing the package skeleton.
- **Traceability:** `R13`, `R14`, `D12`, `D13`, `RC07`.

### FND-02 — Define configuration, hierarchy, and stable identity types

- **Purpose:** encode the declared archive hierarchy, host/source enrollment, policy references, and distinct identity namespaces without introducing runtime secrets.
- **Inputs:** logical hierarchy and identity contracts in `D5` and `D6`.
- **Outputs:** versioned configuration model and validator for host, source, policy, reader lock, store paths, feature flags, secret references, `host-id`, `source-id`, `run-id`, `object-id`, `tree-digest`, `manifest-id`, and namespaced native IDs.
- **Depends on:** `FND-01`.
- **Completion evidence:** invalid UUIDs, role collisions, duplicate source scopes, unsafe/world-readable paths, secret values in configuration, unknown required versions, and conflicting writers are rejected before side effects; display labels remain distinct from stable IDs.
- **Tests:** table/property tests for parsing, deterministic rendering where required, ID namespace separation, rename/rebuild migration, secret-shaped values, path ownership/mode validation, and forward-compatible optional fields.
- **Safety and rollback:** validation is pure and runs before filesystem mutation. A new config version is additive; prior configuration remains readable or fails with an explicit migration requirement.
- **Traceability:** `R3`, `R6`, `R8`, `R12`, `R13`, `R15`, `D5`, `D6`, `D13`, `D14`.

### FND-03 — Implement trust-boundary filesystem and subprocess primitives

- **Purpose:** centralize path containment, hostile-name handling, safe streaming, atomic file operations, subprocess execution, timeout, cancellation, and content-free error classification.
- **Inputs:** `FND-01`, `FND-02`, threat model `D14`, and metadata representation contract `D6`.
- **Outputs:** reviewed primitives for open-beneath-root traversal, no-follow enumeration, reversible path-byte encoding, file-kind rejection, atomic temporary-file publication, fsync discipline, argument-vector subprocesses, environment allowlists, controlled streams, timeout/cancellation, and secret-safe diagnostics.
- **Depends on:** `FND-01`, `FND-02`.
- **Completion evidence:** callers cannot escape configured roots, follow an unapproved symlink, invoke through shell interpolation, log payload bytes, inherit undeclared environment variables, or leave a partially published file after process failure.
- **Tests:** property/fuzz tests for `..`, absolute paths, NUL, non-UTF-8 bytes, symlink races, devices/sockets, malicious filenames, terminal/HTML control text, large streams, timeout, cancellation, broken pipes, secret canaries, fsync/rename failure, and process exit classes.
- **Safety and rollback:** primitives default closed at trust boundaries and write only unique staging files before atomic publication. A primitive failure returns a typed content-free error and leaves the prior published state intact.
- **Traceability:** `R1`, `R8`, `R11`, `R15`, `D5`, `D6`, `D12`, `D14`, `Q06`, `Q15`, `RC10`.

### AUTH-01 — Implement exact object insertion

- **Purpose:** insert and verify immutable exact-byte objects in the SHA-256 namespace.
- **Inputs:** `FND-02`, `FND-03`, object hierarchy and invariants in `D4`–`D6`.
- **Outputs:** streaming SHA-256/length computation, temporary-object fsync, atomic insertion, existing-object verification, collision error, object read/verify API, and insertion receipt.
- **Depends on:** `FND-02`, `FND-03`.
- **Completion evidence:** inserted bytes hash to their object ID; duplicate bytes reuse storage only after verification; a same-name/different-byte or length mismatch is fatal; crashes cannot publish partial objects.
- **Tests:** property tests over arbitrary bytes; empty/large/duplicate objects; concurrent identical insertion; injected short write, fsync, rename, disk-full, and collision failures; post-crash namespace scan.
- **Safety and rollback:** objects are immutable and inserted only by atomic rename from the authority filesystem. Unreferenced valid objects are harmless; no automatic object deletion is implemented.
- **Traceability:** `R1`, `R4`, `R6`, `D4`, `D5`, `D6`, `D9`, `S03`.

### AUTH-02 — Implement deterministic immutable manifest commitment

- **Purpose:** construct, validate, serialize, chain, and atomically commit source-generation manifests over verified object references.
- **Inputs:** `FND-02`, `FND-03`, `AUTH-01`, accepted `GATE-07` and manifest contract `D6`.
- **Outputs:** versioned manifest model; deterministic encoding; raw/display path, metadata, exclusions, bundle/sidecar, stability, warning, fingerprint, state, predecessor, and tree-digest fields; manifest ID calculation; chain validation; atomic commit.
- **Depends on:** `AUTH-01`, `FND-02`, `FND-03`, `GATE-07`.
- **Completion evidence:** byte-identical logical inputs produce identical manifest bytes/ID; path ordering is raw-byte deterministic; every object is verified before commit; predecessor and allowed state transitions validate; committed manifests never change.
- **Tests:** golden/property tests for deterministic encoding and field preservation; duplicate logical occurrences; unknown fields; all completeness states; missing object; wrong predecessor; chain fork; truncation/deletion successor; clock anomaly; optional signature posture; crash before/after rename.
- **Safety and rollback:** a candidate remains outside `manifests/` until all references and policy checks pass. Failure leaves the prior chain head unchanged; old schemas remain immutable.
- **Traceability:** `R1`, `R3`, `R4`, `R5`, `R6`, `R7`, `R11`, `D4`, `D6`, `D9`, `D10`, `D17`, `S03`, `S06`, `GATE-07`.

### AUTH-03 — Implement authority verification and head reconstruction

- **Purpose:** verify object/manifest authority and reconstruct source heads without trusting mutable state or derived data.
- **Inputs:** `AUTH-01`, `AUTH-02`, `FND-03`, authority invariants `D4`, and recovery contract `D16`.
- **Outputs:** full and incremental chain/object verifier; source-head reconstruction; verification receipt and content-free failure classes.
- **Depends on:** `AUTH-01`, `AUTH-02`, `FND-03`.
- **Completion evidence:** verification detects missing, altered, colliding, orphan-reference, and chain-break conditions; absent or corrupt mutable heads reconstruct from valid manifests; no derived artifact participates in authority repair.
- **Tests:** corrupt/missing object, malformed/forked chain, absent/incorrect mutable heads, wrong schema/hash namespace, injected read failure, and complete reconstruction from manifests alone.
- **Safety and rollback:** verification is read-only. A failure prevents downstream publication or backup success and leaves authority unchanged.
- **Traceability:** `R1`, `R6`, `R10`, `D4`, `D9`, `D16`, `S03`, `S09`, `S10`.

### STATE-01 — Implement disposable coordinator state and crash recovery

- **Purpose:** hold locks, leases, staging, transfer state, run receipts, mutable heads, retries, and watermarks without making any mutable record authoritative.
- **Inputs:** `FND-02`, `FND-03`, `AUTH-02`, update transaction `D9`, and content-free status contract `D15`.
- **Outputs:** coordinator-state store; single-writer lock/lease; unique run/source staging; resumable transfer metadata; manifest-derived head reconstruction; retry queue; content-free run receipts; bounded staging cleanup.
- **Depends on:** `FND-02`, `FND-03`, `AUTH-02`.
- **Completion evidence:** deleting the entire state store and staging permits reconstruction from manifests and the next reconciliation; stale locks are resolved by lease/process evidence rather than blind deletion; unchanged/unavailable repeats do not accumulate unbounded transitions.
- **Tests:** concurrent lock acquisition, stale/live owner distinction, crash at each state transition, state deletion/rebuild, partial transfer resume, repeated offline state, staging cleanup with referenced/unreferenced objects, and secret/path leakage scan.
- **Safety and rollback:** mutable heads update only after manifest commitment. Cleanup proves no committed reference before deletion and never touches `native/` or `manifests/`.
- **Traceability:** `R2`, `R4`, `R10`, `R12`, `D4`, `D5`, `D9`, `D15`, `S03`, `S09`.

## 7. Collection packages

Collection is format-agnostic until a source package declares roots, sidecars, fingerprints, and a snapshot strategy. The coordinator alone inserts objects and commits manifests; adapters neither write authority nor require semantic parsing to preserve bytes.

### CAP-01 — Define and implement the collection-adapter contract

- **Purpose:** provide the format-independent probe, plan, acquire, validate, classify, and fingerprint boundary used by every source adapter.
- **Inputs:** `FND-02`, `FND-03`, adapter/snapshot contract `D8`, anomaly policy `D10`, and fixture policy `GATE-11`.
- **Outputs:** versioned adapter interface; capability and source-state model; allowlist/exclusion/sidecar plan; staged-entry stream with raw path bytes and stability evidence; coherence token; completeness classification; structural fingerprint; content-free diagnostics.
- **Depends on:** `FND-02`, `FND-03`, `GATE-11`.
- **Completion evidence:** an adapter can preserve an unknown opaque tree without parsing message content; executable absence does not suppress store discovery; unsupported fingerprints and unknown coherence remain explicit; adapters cannot write authority or index state.
- **Tests:** contract tests for absent, empty, unavailable, not-applicable, immutable, changing, partial, opaque, malformed, unknown-version, excluded, and missing-sidecar sources; capability negotiation and diagnostic redaction.
- **Safety and rollback:** acquisition targets a unique staging namespace only. An adapter failure yields a typed source state and cannot insert objects, commit manifests, mutate a producer, or erase prior evidence.
- **Traceability:** `R3`, `R5`, `R7`, `R8`, `R11`, `D8`, `D10`, `D17`, `S08`, `RC01`, `RC05`.

### CAP-02 — Implement OpenSSH/rsync pull and bounded source-helper execution

- **Purpose:** supply authenticated pull transport and an allowlisted, non-resident source-helper mode without embedding an SSH implementation.
- **Inputs:** `CAP-01`, `FND-03`, accepted `GATE-04`, host/source enrollment from `FND-02`, and one-writer topology `D7`.
- **Outputs:** pinned-host SSH invocation; `BatchMode`; fixed helper operations keyed by configured source ID; bounded environment and path handling; resumable run/source rsync staging; timeout, cancellation, clock/reachability observation, and content-free error mapping.
- **Depends on:** `CAP-01`, `FND-02`, `FND-03`, `GATE-04`.
- **Completion evidence:** all transcript-bearing flow points toward the hub; helper commands cannot select arbitrary roots or outputs; interruption resumes only within the matching run/source namespace; an offline host does not block another source.
- **Tests:** synthetic SSH server or isolated approved hosts; wrong/pinned host key, authentication failure, timeout, helper path escape, malicious source ID, partial transfer, disconnect, retry, clock skew, large stream, and concurrent-source limits.
- **Safety and rollback:** source operations are read-only and fixed. No general remote shell, producer mutation, push path, peer merge, or transcript-bearing hook is introduced; failed transfers remain unpublished staging.
- **Traceability:** `R4`, `R8`, `R12`, `D7`, `D8`, `D9`, `D12`, `D14`, `E02`, `S02`, `S03`, `RC02`.

### CAP-03 — Implement immutable-file, changing-JSONL, and mutable-tree capture

- **Purpose:** acquire ordinary files and directories while distinguishing stable, open, unstable, and partial generations.
- **Inputs:** `CAP-01`, `FND-03`, metadata policy `GATE-11`, and source-class rules in `D8`.
- **Outputs:** closed-file streaming; pre/post metadata observation; unique staged copies; bounded retry for changing files; before/after tree enumeration; admitted symlink and metadata capture; stable-tree evidence; last-exact-acquisition retention.
- **Depends on:** `CAP-01`, `FND-03`, `GATE-11`.
- **Completion evidence:** a stable file/tree can be classified complete under its declared strategy; a changing JSONL or tree remains `open`, `unstable`, or `partial`; no byte splice, last-line repair, or parser success is used as capture proof.
- **Tests:** concurrent append, truncate, replace, rename, directory addition/removal, symlink swap, non-UTF-8 path, missing sidecar, metadata change, bounded-retry exhaustion, and stable rerun over synthetic trees.
- **Safety and rollback:** every attempt has a distinct staging identity; all acquired exact versions may be retained as evidence, while only validated candidates reach the coordinator. Producer files are never locked destructively or rewritten.
- **Traceability:** `R1`, `R4`, `R5`, `R7`, `R11`, `D8`, `D10`, `S04`, `Q06`, `RC02`, `RC04`.

### CAP-04 — Implement exact-bundle and logical SQLite capture

- **Purpose:** implement the accepted per-filesystem WAL capture method and a separately classified logical read-snapshot path.
- **Inputs:** `CAP-01`, `FND-03`, accepted `GATE-02`, SQLite source-class contract, and exact/logical artifact distinction.
- **Outputs:** DB/WAL/SHM bundle membership and coherence evidence; approved filesystem/quiescence helper where available; Online Backup, `VACUUM INTO`, or `sqlite3_rsync` logical snapshots as selected; separate hashes, classes, provenance, and diagnostics.
- **Depends on:** `CAP-01`, `FND-03`, `GATE-02`.
- **Completion evidence:** an exact bundle is complete only under the method proved by `GATE-02`; a logical database image is never labeled as the producer’s exact artifact set; uncertain bundles remain retained but `incoherent` or `unknown`.
- **Tests:** the accepted concurrent-WAL matrix, missing/changing WAL or SHM, journal-mode change, failed backup, busy/locked database, snapshot interruption, integrity check, transaction visibility, artifact-class confusion, and unknown schema.
- **Safety and rollback:** producer databases open read-only; no checkpoint, vacuum, migration, repair, or reindex runs against them. Failure leaves source files unchanged and prior complete archive generations active.
- **Traceability:** `R1`, `R5`, `R8`, `R11`, `D8`, `D10`, `D16`, `E03`, `Q05`, `S05`, `RC03`.

### ORCH-01 — Implement the single-writer reconciliation transaction

- **Purpose:** compose inventory, reachability, acquisition, object insertion, manifest commitment, derived publication, indexing, verification, backup request, and status into one idempotent run.
- **Inputs:** `GATE-04`, `AUTH-01`–`AUTH-03`, `STATE-01`, and `CAP-01`–`CAP-04`.
- **Outputs:** role-aware coordinator commands; bounded host/source/hash/reader/backup concurrency; all-cell inventory; prioritized hook-hint queue; deterministic per-source commit serialization; fifteen-step run state machine; backup/index handoff; final receipt and exit status.
- **Depends on:** `GATE-04`, `AUTH-01`, `AUTH-02`, `AUTH-03`, `STATE-01`, `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`.
- **Completion evidence:** an unchanged source transfers or inserts no verified payload and creates no redundant manifest; one source failure does not block unrelated sources; every enrolled cell receives a state; crashes at each boundary converge safely on rerun; no derived/backup failure rolls back authority.
- **Tests:** model/state-machine and integration tests for all fifteen steps, all crash points, duplicate runs, concurrent sources, per-source serialization, offline hosts, low-space stop, unknown fingerprint, changing capture, manifest commit, derived/index failure, and backup failure.
- **Safety and rollback:** one lock protects authority. New acquisition stops before disk exhaustion; committed authority is never rolled back; mutable heads, derived pointers, and retries reconstruct from manifests.
- **Traceability:** `R3`, `R4`, `R5`, `R7`, `R8`, `R10`, `R12`, `D7`, `D9`, `D10`, `D15`, `S01`, `S02`, `S03`.

### SRC-01 — Implement the Claude Code source adapter

- **Purpose:** discover and preserve Claude Code project JSONL plus admitted sidecars across installed, historical, empty, absent, and unavailable states.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, Claude source findings, and `GATE-11`.
- **Outputs:** versioned roots, producer probe, sidecar relationships, exclusions, structural fingerprint, changing-JSONL strategy, hook-hint metadata, and explicit retention/unknown diagnostics.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `GATE-11`.
- **Completion evidence:** JSONL and relevant tool-result/subagent/file-history sidecars preserve exact bytes and relative provenance; `uuid`/`parentUuid` remain reader claims; cleanup risk and unknown records do not suppress capture.
- **Tests:** synthetic current/older/unknown record families, append during copy, partial line, resume/fork parent links, missing sidecar, cleanup deletion, absent executable with history, hook disabled, and all source states.
- **Safety and rollback:** parser behavior cannot gate acquisition. Hooks enqueue content-free hints only; source files and settings remain unchanged.
- **Traceability:** `R3`, `R5`, `R6`, `R7`, `R11`, `D8`, `D10`, `S04`, `S07`, `RC02`.

### SRC-02 — Implement the Codex CLI source adapter

- **Purpose:** discover and preserve active and archived Codex rollout JSONL plus relevant state sidecars without treating state SQLite as transcript authority.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, Codex source findings, and `GATE-11`.
- **Outputs:** dated rollout/archive roots, producer/version probe, rollout/state classification, mixed-record fingerprint, changing-file strategy, archive/delete transitions, and SessionEnd hint handling.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `GATE-11`.
- **Completion evidence:** every rollout occurrence retains host/source/path provenance; archived and active generations remain distinct; unstable transcript schema and state-database availability do not impede raw preservation.
- **Tests:** synthetic mixed records, unknown types, append/compact/world-state changes, archive move, delete observation, absent root, warning-only version probe, duplicate migrated rollout, hook timeout/disablement, and partial transfer.
- **Safety and rollback:** state SQLite is discovery assistance only. No Codex archive/delete command, database mutation, or hook-borne transcript copy is invoked.
- **Traceability:** `R3`, `R5`, `R6`, `R7`, `R11`, `D8`, `D10`, `S04`, `S07`, `RC02`.

### SRC-03 — Implement the Pi Coding Agent source adapter

- **Purpose:** preserve Pi versioned tree-shaped JSONL without flattening branch-in-place semantics.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, installed Pi format specification, and `GATE-11`.
- **Outputs:** session-root discovery, header/version fingerprint, whole-file generation capture, custom/unknown-record support, and source-state classification.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `GATE-11`.
- **Completion evidence:** each changed session file becomes a new exact object/generation; `id`/`parentId`, compaction, branch-summary, label, and custom records remain intact; no linearization or append-fragment splice occurs.
- **Tests:** synthetic version 3 trees, in-file branches, compaction, branch summaries, forks, labels, custom/unknown records, append during copy, malformed record, no session root, and relocated session directory.
- **Safety and rollback:** the adapter never invokes `/share`, rewrites a session, or treats a reader-selected branch as the archived whole.
- **Traceability:** `R3`, `R5`, `R6`, `R7`, `R11`, `D8`, `D10`, `S04`, `S07`, `RC04`.

### SRC-04 — Implement the OpenCode source adapter

- **Purpose:** preserve the current WAL-mode OpenCode store and legacy JSON while keeping exact native bundles separate from logical reader snapshots.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, OpenCode findings, and accepted `GATE-02`.
- **Outputs:** current/legacy root discovery, SQLite journal/schema fingerprint, exact bundle plan, logical snapshot plan, migration/empty-store state, and explicit schema-retention uncertainty.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, `GATE-02`.
- **Completion evidence:** database, matching WAL/SHM, and legacy artifacts retain class/provenance; a logical backup supports readers but cannot substitute for exact artifacts; schema migration preserves prior generations.
- **Tests:** synthetic WAL writes, schema migration, missing/rotating WAL, legacy JSON fallback, empty directory, user deletion, unknown table/column, incoherent bundle, and logical-snapshot rebuild.
- **Safety and rollback:** no producer checkpoint, vacuum, migration, or reindex occurs. An unproved exact bundle remains incomplete without blocking preservation.
- **Traceability:** `R1`, `R3`, `R5`, `R7`, `R11`, `D8`, `D10`, `S05`, `RC03`.

### SRC-05 — Implement the Droid CLI source adapter

- **Purpose:** discover and preserve Droid workspace JSONL, including historical stores where the executable is absent.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, Droid findings, and `GATE-11`.
- **Outputs:** session-root/workspace discovery, version-2/unknown fingerprint, sidecar and source-state plan, resume/fork preservation, local/cloud-sync distinction, and SessionEnd hint handling.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `GATE-11`.
- **Completion evidence:** historical-only, empty, active, and absent states remain visible; local JSONL is preserved independently of cloud sync/API eligibility; private schema changes produce diagnostics, not loss.
- **Tests:** synthetic session_start/message/compaction/todo records, unknown types, resume/fork, executable absent with history, no sessions root, changing file, cloud-sync metadata without local content, and hook failure.
- **Safety and rollback:** no Droid reindex, cloud sync, API request, or hook mutation occurs during collection; API exports remain separate optional source occurrences.
- **Traceability:** `R3`, `R5`, `R6`, `R7`, `R11`, `D8`, `D10`, `S04`, `S07`, `RC02`.

### SRC-06 — Implement the Claude Desktop source adapter

- **Purpose:** preserve only documented or approved Claude Desktop session roots and attachments while exposing standard-account and cloud completeness gaps.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, accepted `GATE-10` and `GATE-11`, and Claude Desktop findings.
- **Outputs:** allowlisted local-agent/Claude-Code session roots, transcript/work/upload/output/memory/audit relationships as approved, exact/logical SQLite handling where discovered, account-export source class, exclusions, and cloud/side-chat unknown states.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, `GATE-10`, `GATE-11`.
- **Completion evidence:** approved local session material preserves relative relationships and exact bytes; renderer caches, credentials, cookies, and keychains remain excluded; cloud-only or undocumented surfaces appear as coverage gaps rather than false absence.
- **Tests:** synthetic third-party-mode layout, missing attachments, audit chain, live database, cloud-only marker, deleted session, unknown standard-account root, cache/credential canaries, and account-export provenance.
- **Safety and rollback:** ambiguous roots are quarantined for policy review. No account export, cloud request, login, or desktop mutation occurs without separate authorization.
- **Traceability:** `R3`, `R5`, `R8`, `R11`, `D8`, `D14`, `Q01`, `S05`, `RC05`.

### SRC-07 — Implement the Codex Desktop source adapter

- **Purpose:** represent Codex Desktop provenance without promoting generic application-profile caches or duplicating shared CLI authority.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, accepted `GATE-10` and `GATE-11`, and Codex Desktop findings.
- **Outputs:** shared-rollout provenance rules, approved distinct-root/export source class if evidence emerges, generic-cache exclusions, installed/desktop-only/cloud-only/unknown states, and exact-byte occurrence deduplication rules.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, `GATE-10`, `GATE-11`, `SRC-02`.
- **Completion evidence:** shared CLI bytes are referenced once physically but retain desktop/source provenance where established; unproved desktop-only content remains `unknown`; browser profile presence alone never becomes a transcript capture.
- **Tests:** synthetic shared rollout, identical/different occurrence, generic Chromium cache, approved export, desktop-only marker without bytes, live state database, and unknown app version.
- **Safety and rollback:** the default admits no generic profile root. New vendor documentation or structural evidence changes a versioned allowlist, never prior manifests.
- **Traceability:** `R1`, `R3`, `R6`, `R8`, `R11`, `D8`, `D10`, `Q02`, `S05`, `RC05`.

### SRC-08 — Implement the Cursor Desktop source adapter

- **Purpose:** preserve Cursor Agent JSONL, approved metadata stores, and opaque database bytes while reporting undecoded and cloud-only coverage.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, accepted `GATE-10` and `GATE-11`, and Cursor findings.
- **Outputs:** project transcript/root discovery, companion metadata relationship, state/store SQLite bundle plan, schema/fingerprint, opaque/protobuf status, cloud/DB-only coverage diagnostics, and ACP-hint boundary if applicable.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, `GATE-10`, `GATE-11`.
- **Completion evidence:** Agent JSONL and approved database artifacts retain exact bytes and provenance; semantic undecodability remains explicit; ACP/live visibility never substitutes for historical reconciliation.
- **Tests:** synthetic Agent JSONL, DB-only opaque blobs, WAL writes, companion-store absence, unknown schema, cloud-only marker, ACP event without historical file, credential/cache canaries, and malformed protobuf-like bytes.
- **Safety and rollback:** preservation does not require decoding. Generic IDE/browser caches and credentials remain excluded; no cloud-agent request is made.
- **Traceability:** `R1`, `R3`, `R5`, `R8`, `R11`, `D8`, `D14`, `Q03`, `S05`, `RC05`.

### SRC-09 — Implement the Factory Desktop source adapter

- **Purpose:** represent Factory Desktop and shared Droid sessions without inferring a separate transcript store from Electron state.
- **Inputs:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, accepted `GATE-10` and `GATE-11`, `SRC-05`, and Factory findings.
- **Outputs:** shared-local provenance, approved distinct-root/API-export source class, Electron cache/credential exclusions, organization/API eligibility state, and desktop/cloud completeness diagnostics.
- **Depends on:** `CAP-01`, `CAP-02`, `CAP-03`, `CAP-04`, `GATE-10`, `GATE-11`, `SRC-05`.
- **Completion evidence:** shared Droid bytes deduplicate physically while desktop provenance survives; local retention uncertainty and cloud/API gaps remain visible; an API response, when separately authorized, is labeled vendor export rather than native local data.
- **Tests:** synthetic shared session, identical/different occurrence, Electron state, API pagination/export envelope, unavailable API, organization-retention metadata, live database, and unknown app-only session marker.
- **Safety and rollback:** no API call, cloud sync, cookie capture, or desktop mutation occurs during baseline collection. Ambiguous data is quarantined.
- **Traceability:** `R1`, `R3`, `R6`, `R8`, `R11`, `D8`, `D14`, `Q04`, `S05`, `RC05`.

## 8. Interpretation and search packages

Interpretation is a projection over preserved authority. Reader failure is local to its `(manifest, reader-version, fingerprint)` coverage record; it cannot fail collection, alter a manifest, or convert a normalized representation into archive truth.

### VIEW-01 — Materialize and publish read-only native views

- **Purpose:** expose selected manifest generations in original relative layouts without allowing readers to mutate authoritative objects.
- **Inputs:** `AUTH-03`, `FND-03`, and hierarchy `D5`.
- **Outputs:** generic per-host/source/manifest native-tree materialization; verified read-only copy or copy-on-write reflink policy; atomic current-generation pointer.
- **Depends on:** `AUTH-03`, `FND-03`.
- **Completion evidence:** every output byte verifies against its object; readers have no writable alias to `native/`; identical bytes may be reused safely without losing occurrence paths; rebuild from manifests produces the same selected layout.
- **Tests:** synthetic layouts for regular files, directories, symlinks, admitted metadata, non-UTF-8 paths, and duplicate occurrences; permissions; attempted mutation; reflink unsupported fallback; atomic switch failure; concurrent reader; complete deletion/rebuild.
- **Safety and rollback:** write a fresh derived generation, verify it, then switch one disposable pointer. Failure preserves both authority and the prior current view.
- **Traceability:** `R1`, `R2`, `R6`, `D5`, `D8`, `D11`, `S09`, `RC06`.

### RDR-01 — Implement the schema-tolerant reader contract

- **Purpose:** define source-linked query projections, diagnostics, coverage, and version/fingerprint support independently of any native source format.
- **Inputs:** `AUTH-02`, `AUTH-03`, `CAP-01`, accepted `GATE-11`, and semantic-reader contract `D8`; `GATE-06` determines reuse within format-specific readers.
- **Outputs:** versioned reader interface; exact source locator; namespaced native IDs and confidence-labeled relationships; timestamp/facet/text/token projections; omitted/unknown counts; `unsupported-fingerprint`, `partial-parse`, `malformed-record`, and `missing-sidecar` diagnostics.
- **Depends on:** `AUTH-02`, `AUTH-03`, `CAP-01`, `GATE-11`.
- **Completion evidence:** an unsupported or malformed record affects only its projection and coverage; unknown fields remain retrievable by native locator; reader upgrades never rewrite authority; repeated text is not content-deduplicated.
- **Tests:** contract/property tests for complete, partial, malformed, opaque, unknown-version, duplicate, collision, parent/branch, missing-sidecar, time-confidence, and locator round-trip cases; secret and active-content escaping.
- **Safety and rollback:** readers receive read-only authority/views and write only new derived output. A prior reader/index generation remains selectable until replacement coverage passes.
- **Traceability:** `R2`, `R6`, `R7`, `R8`, `R9`, `R11`, `D8`, `D10`, `D11`, `D17`, `S06`, `S08`, `RC06`, `RC10`.

### RDR-02 — Implement the Claude Code reader

- **Purpose:** interpret supported Claude Code records and lineage while exposing unsupported records and sidecar gaps.
- **Inputs:** `RDR-01`, `SRC-01`, and accepted reuse decisions from `GATE-06`.
- **Outputs:** projections for supported user/assistant/system/message/tool/subagent/snapshot/attachment records; `uuid`/`parentUuid` lineage; sidecar locators; format-version coverage.
- **Depends on:** `RDR-01`, `SRC-01`, `GATE-06`.
- **Completion evidence:** supported records resolve to exact manifest/path/record locators; unknown records remain preserved and counted; forks/resumes and repeated content remain distinct.
- **Tests:** synthetic supported, unknown, malformed, partial-line, missing-sidecar, resume, fork, attachment, and version-drift fixtures; compare selected prior-art parser behavior where reused.
- **Safety and rollback:** parse failure cannot change source classification or authority. A reader upgrade builds a new derived generation.
- **Traceability:** `R2`, `R6`, `R7`, `R9`, `R11`, `D8`, `D10`, `S04`, `S07`.

### RDR-03 — Implement the Codex CLI reader

- **Purpose:** interpret supported mixed Codex rollout records, compaction, tool/subagent activity, and lineage without depending on state SQLite.
- **Inputs:** `RDR-01`, `SRC-02`, and `GATE-06`.
- **Outputs:** supported record projections, native/session/turn/tool identifiers, archive provenance, compaction/world-state diagnostics, and explicit unknown-type coverage.
- **Depends on:** `RDR-01`, `SRC-02`, `GATE-06`.
- **Completion evidence:** search projections preserve rollout and record locators; archived/current occurrences remain distinguishable; state-database absence cannot erase rollout interpretation.
- **Tests:** synthetic mixed records, unknown type, malformed/partial record, compaction, subagent, tool result, archive move, duplicate native ID, and format drift.
- **Safety and rollback:** the reader consumes immutable views or objects and emits only disposable projections; parser errors remain local.
- **Traceability:** `R2`, `R6`, `R7`, `R9`, `R11`, `D8`, `D10`, `S04`, `S07`.

### RDR-04 — Implement the Pi Coding Agent reader

- **Purpose:** interpret Pi’s versioned tree without flattening branch-in-place history.
- **Inputs:** `RDR-01`, `SRC-03`, installed format specification, and `GATE-06`.
- **Outputs:** header/version handling; entry projections; `id`/`parentId` graph; compaction and branch-summary semantics; labels/custom-record diagnostics; branch selection as a query facet.
- **Depends on:** `RDR-01`, `SRC-03`, `GATE-06`.
- **Completion evidence:** all graph nodes retain exact record locators; selecting one branch does not hide or delete another; unknown custom records remain visible in coverage.
- **Tests:** synthetic branched tree, fork, compaction, branch summary, label, custom record, unknown version, malformed parent, duplicate ID, and repeated text.
- **Safety and rollback:** tree interpretation is entirely derived; no branch selection rewrites or materializes a canonical linear transcript.
- **Traceability:** `R2`, `R6`, `R7`, `R9`, `R11`, `D8`, `D10`, `S07`, `RC04`.

### RDR-05 — Implement the OpenCode reader

- **Purpose:** interpret supported OpenCode logical SQLite snapshots and legacy JSON while preserving exact-bundle provenance and schema uncertainty.
- **Inputs:** `RDR-01`, `SRC-04`, accepted `GATE-02` and `GATE-06`.
- **Outputs:** versioned schema/table/column support; session/message/part/project relationships; native locators into the logical snapshot and exact bundle provenance; legacy reader; opaque-field coverage.
- **Depends on:** `RDR-01`, `SRC-04`, `GATE-02`, `GATE-06`.
- **Completion evidence:** readers never open an unapproved incoherent bundle; logical rows map back to the manifest and native artifact class; unknown migrations produce partial coverage, not collection failure.
- **Tests:** synthetic supported/migrated/unknown schemas, legacy JSON, opaque data, deleted/archive times, parent relationship, malformed rows, logical snapshot loss/recreation, and exact/logical confusion.
- **Safety and rollback:** source databases remain untouched. A logical snapshot and its projections are disposable and rebuild only from recorded authority/method.
- **Traceability:** `R2`, `R6`, `R7`, `R9`, `R11`, `D8`, `D11`, `S05`, `S08`, `RC03`.

### RDR-06 — Implement the Droid CLI reader

- **Purpose:** interpret supported Droid JSONL, resume/fork claims, compaction, and local/cloud provenance.
- **Inputs:** `RDR-01`, `SRC-05`, and `GATE-06`.
- **Outputs:** supported role/message/tool/state projections; session/start identifiers; resume/fork graph; compaction/todo diagnostics; source-linked coverage.
- **Depends on:** `RDR-01`, `SRC-05`, `GATE-06`.
- **Completion evidence:** private schema changes remain unsupported/partial rather than misparsed; local JSONL and optional vendor export projections remain separate source kinds.
- **Tests:** synthetic version 2, unknown version/type, malformed, compaction, todo, resume/fork, historical-only store, repeated native ID, and optional export envelope.
- **Safety and rollback:** no local search index or cloud API becomes a reader prerequisite; outputs remain disposable.
- **Traceability:** `R2`, `R6`, `R7`, `R9`, `R11`, `D8`, `D10`, `S04`, `S07`.

### RDR-07 — Implement the Claude Desktop reader

- **Purpose:** interpret only approved Claude Desktop local/export structures and report all standard-account/cloud gaps.
- **Inputs:** `RDR-01`, `SRC-06`, `GATE-06`, and accepted `GATE-10`.
- **Outputs:** projections for approved session/transcript/work/attachment/memory/audit structures; source-kind and export provenance; missing relationship and cloud-coverage diagnostics.
- **Depends on:** `RDR-01`, `SRC-06`, `GATE-06`, `GATE-10`.
- **Completion evidence:** every projection resolves to approved native/export artifacts; undocumented ordinary-account, side-chat, and cloud material remains an explicit gap rather than inferred content.
- **Tests:** synthetic documented layout, attachment graph, audit chain, missing sidecar, unknown standard-account structure, export, cloud-only marker, and malformed data.
- **Safety and rollback:** unapproved caches or credential stores are never reader inputs; reader support does not broaden collection allowlists automatically.
- **Traceability:** `R2`, `R8`, `R9`, `R11`, `D8`, `D14`, `Q01`, `S05`, `RC05`.

### RDR-08 — Implement the Codex Desktop reader

- **Purpose:** expose established shared Codex projections and any later approved desktop/export source without asserting unproved local completeness.
- **Inputs:** `RDR-01`, `SRC-07`, `RDR-03`, `GATE-06`, and `GATE-10`.
- **Outputs:** desktop provenance overlay for shared rollouts; separate reader path for an approved distinct export/root; unknown desktop-only coverage.
- **Depends on:** `RDR-01`, `RDR-03`, `SRC-07`, `GATE-06`, `GATE-10`.
- **Completion evidence:** shared content remains one physical object with distinct occurrence/surface claims; no browser-profile cache is interpreted as transcript content.
- **Tests:** synthetic shared rollout, duplicate/different occurrence, approved export, unknown desktop-only marker, and generic cache exclusion.
- **Safety and rollback:** absent evidence yields no distinct parser. Removing the optional overlay does not affect CLI projections or authority.
- **Traceability:** `R2`, `R6`, `R8`, `R9`, `R11`, `D8`, `Q02`, `RC05`.

### RDR-09 — Implement the Cursor Desktop reader

- **Purpose:** interpret Cursor Agent JSONL and approved metadata while preserving opaque database blobs and cloud gaps as explicit coverage.
- **Inputs:** `RDR-01`, `SRC-08`, `GATE-06`, and `GATE-10`.
- **Outputs:** Agent JSONL projections; approved metadata relationships; opaque/DB-only diagnostics; source-linked native locator; cloud/ACP coverage state.
- **Depends on:** `RDR-01`, `SRC-08`, `GATE-06`, `GATE-10`.
- **Completion evidence:** readable Agent records are searchable; undecoded DB/protobuf artifacts remain retrievable by exact locator and counted opaque; no-result never implies absence under incomplete coverage.
- **Tests:** synthetic Agent JSONL, DB-only opaque blobs, unknown protobuf, missing companion store, cloud-only marker, malformed record, schema drift, and coverage totals.
- **Safety and rollback:** decoder additions create new projections only; preservation and existing supported projections remain available if a decoder fails.
- **Traceability:** `R2`, `R6`, `R8`, `R9`, `R11`, `D8`, `D11`, `Q03`, `S05`, `RC05`.

### RDR-10 — Implement the Factory Desktop reader

- **Purpose:** expose shared Droid projections and any approved Factory API/export source while retaining desktop/cloud uncertainty.
- **Inputs:** `RDR-01`, `RDR-06`, `SRC-09`, `GATE-06`, and `GATE-10`.
- **Outputs:** desktop provenance over shared sessions; separate vendor-export projections with pagination/version metadata; organization/API/retention coverage diagnostics.
- **Depends on:** `RDR-01`, `RDR-06`, `SRC-09`, `GATE-06`, `GATE-10`.
- **Completion evidence:** shared local and vendor-export records remain distinct occurrences; API unavailability or unknown retention appears in coverage; Electron state is not transcript input.
- **Tests:** synthetic shared JSONL, API envelope/pagination, unavailable API, unknown retention, duplicated source, malformed export, and Electron-cache exclusion.
- **Safety and rollback:** API readers operate only on separately captured exports and have no network access during ordinary reading.
- **Traceability:** `R2`, `R6`, `R8`, `R9`, `R11`, `D8`, `Q04`, `RC05`.

### IDX-01 — Implement the rebuildable SQLite/FTS index

- **Purpose:** persist reader projections, native locators, lineage claims, facets, text, and coverage in a disposable, versioned SQLite/FTS generation.
- **Inputs:** accepted `GATE-05`; `RDR-01`; format readers as available; index contract `D11`.
- **Outputs:** index schema/version; manifest and reader watermarks; source/session/relationship/projection/coverage tables; FTS; transactional incremental update; fresh-generation rebuild; integrity/coverage validation; atomic active pointer.
- **Depends on:** `GATE-05`, `RDR-01`.
- **Completion evidence:** every indexed row includes an exact manifest/native locator and reader/fingerprint version; older generations remain queryable or rebuildable; unsupported/partial/opaque counts are visible; deleting the database permits full reconstruction.
- **Tests:** synthetic projections from every reader contract; duplicate/collision/branch lineage; transaction interruption; index corruption; old/new schema; incremental versus full-build equivalence; FTS query; coverage reconciliation; complete deletion/rebuild.
- **Safety and rollback:** build a new generation or commit one transaction, validate it, then switch the disposable pointer. A failed update leaves the prior index active and never changes authority.
- **Traceability:** `R2`, `R6`, `R9`, `R10`, `R11`, `D11`, `D17`, `S01`, `S06`, `S09`.

### IDX-02 — Implement the native-linked query and status CLI

- **Purpose:** provide local lexical search, filtering, coverage, native retrieval, interpreted display, and explicit lossy-export actions without a network service.
- **Inputs:** `IDX-01`, `VIEW-01`, accepted `GATE-08`, and query semantics `D11`.
- **Outputs:** local CLI commands for search/facets/history/coverage, open/stream native, show interpreted, source status, and explicit export selection; escaped snippets and control characters; exact object/manifest locators.
- **Depends on:** `IDX-01`, `VIEW-01`, `GATE-08`.
- **Completion evidence:** default search selects current complete or last-complete-offline generations and visibly reports excluded coverage; native and interpreted views are distinct; a search hit resolves to exact object bytes; no remote listener exists.
- **Tests:** all facets, historical/unstable opt-in, partial/opaque coverage, offline source age, locator round-trip, malicious HTML/terminal text, binary attachment, no-result under incomplete coverage, and native byte verification.
- **Safety and rollback:** CLI reads owner-only local state. Query and display changes require no authority migration; disabling an optional viewer leaves baseline search available.
- **Traceability:** `R8`, `R9`, `R12`, `D11`, `D14`, `D15`, `E07`, `Q09`, `Q10`, `Q14`.

### PLUG-01 — Implement the optional derived-plugin boundary

- **Purpose:** run explicitly selected ATIF, Letta, OpenTelemetry/OpenInference, HTML, DuckDB, or other exporters/readers without making their runtimes or schemas core dependencies.
- **Inputs:** `FND-03`, `RDR-01`, `VIEW-01`, `GATE-06`, and plugin boundary `D8`/`D12`.
- **Outputs:** versioned stdin/stdout/file protocol; input-manifest/reader/tool/options provenance; fresh derived-output directory; network-off execution; read-only selected inputs; timeout/resource/error handling; loss/omission diagnostics.
- **Depends on:** `FND-03`, `RDR-01`, `VIEW-01`, `GATE-06`.
- **Completion evidence:** plugin failure cannot affect collection, authority verification, baseline index/search, or backup; Python/TypeScript closures are optional; external destination/upload requires a separate explicit action and confirmation.
- **Tests:** synthetic successful/lossy/partial export, malformed plugin output, timeout, crash, network attempt, authority write attempt, secret environment access, output-path escape, version change, and deletion/rebuild.
- **Safety and rollback:** plugins receive no authority write path, SSH/restic credential, ambient network, or shared output generation. Removing all plugin outputs leaves baseline operation intact.
- **Traceability:** `R2`, `R8`, `R11`, `D8`, `D12`, `D14`, `RC01`, `RC06`, `RC07`.

## 9. Operations, recovery, and packaging packages

Operational work begins only after authority and derived-state boundaries have executable proofs. Backup success requires restore evidence; packaging success requires behavior on every target system rather than evaluation alone.

### OBS-01 — Implement content-free observability, health, and resource guards

- **Purpose:** expose actionable source/run/index/backup health without leaking transcript content, native paths, command output, or credentials.
- **Inputs:** `STATE-01`, `ORCH-01`, `IDX-01`, accepted `GATE-08`, and operations contract `D15`.
- **Outputs:** structured local logs, exit codes, status model, counters/gauges/histograms, healthy/degraded/unhealthy evaluation, alerts, privileged local diagnostics, bounded concurrency controls, and free-space safety floor.
- **Depends on:** `STATE-01`, `ORCH-01`, `IDX-01`, `GATE-08`.
- **Completion evidence:** status covers every enrolled cell and reports last attempt/success/complete age, state, counts, object reuse, manifest/index/backup watermarks, retries, and error class; low-space stops acquisition before authority corruption; no content field reaches ordinary output.
- **Tests:** state matrix, offline/partial/unknown source, index lag, backup failure, hash/chain failure, low disk, growth anomaly, overdue restore, concurrency limits, diagnostic privilege, secret/path canaries, and optional content-free telemetry export.
- **Safety and rollback:** observability failure cannot alter authority or block verification/search. Optional OpenTelemetry remains disabled and content-free; prior local status remains sufficient.
- **Traceability:** `R3`, `R8`, `R12`, `R15`, `D15`, `S02`, `Q09`, `RC10`.

### MIG-01 — Implement version and migration policy

- **Purpose:** evolve manifests, object-hash namespaces, source fingerprints, readers, indexes, source enrollment, and vendor exports without rewriting prior authority.
- **Inputs:** `AUTH-02`, `RDR-01`, `IDX-01`, version policy `D17`.
- **Outputs:** manifest decoder/version dispatch; additive manifest writer versions; parallel hash namespace/cross-hash model; fingerprint support declarations; reader/index invalidation rules; source migration record; export source-kind versioning; rollback selection.
- **Depends on:** `AUTH-02`, `RDR-01`, `IDX-01`.
- **Completion evidence:** old manifests remain byte-identical and readable; a new unknown source fingerprint still preserves; reader/index upgrades rebuild only derived data; source move/rename retains both occurrences and explicit continuity claims.
- **Tests:** old/new manifest versions, unknown future fields, parallel hash namespace, reader upgrade/downgrade, index rollback, source host/path/account migration, duplicate native IDs, export version, and interrupted migration.
- **Safety and rollback:** migrations create new authority only where the design calls for successor manifests; they never edit old objects/manifests. Derived rollback selects the prior generation.
- **Traceability:** `R6`, `R7`, `R10`, `R11`, `D10`, `D17`, `S06`, `S08`.

### BACK-01 — Implement restic backup, retention, integrity, and restore receipts

- **Purpose:** back up the complete authority scope to failure-independent encrypted repositories and prove that snapshots are usable.
- **Inputs:** `AUTH-03`, `ORCH-01`, accepted `GATE-03`, `GATE-07`, `GATE-09`, and backup contract `D16`.
- **Outputs:** fixed restic include/exclude scope for `VERSION`, `config/`, `native/`, and `manifests/`; credential-command integration; repository snapshot receipts; covered manifest heads; retention/prune guard; integrity check; sampled/full restore commands and receipts.
- **Depends on:** `AUTH-03`, `ORCH-01`, `GATE-03`, `GATE-07`, `GATE-09`.
- **Completion evidence:** every due repository records a snapshot ID and coverage after authority verification; one failure is visible without invalidating another; prune cannot remove the sole retained copy; sampled restore verifies manifest/object hashes in a fresh root.
- **Tests:** synthetic first/incremental backup, deduplication, one/two repositories, wrong/lost credentials, interrupted backup, repository corruption/check, retention prune, held generation, sampled/full restore, and receipt leakage scan.
- **Safety and rollback:** restic never becomes the browse namespace or discovery source. Backup failure leaves local authority untouched; prune is disabled until retention proof passes.
- **Traceability:** `R1`, `R8`, `R10`, `R15`, `D5`, `D9`, `D14`, `D16`, `E01`, `E06`, `E09`, `Q08`, `S01`, `S10`.

### REC-01 — Implement clean recovery from native authority

- **Purpose:** restore all three authoritative inputs on a clean root and reconstruct an operational archive without source hosts, mutable state, materialized trees, or an old index.
- **Inputs:** `AUTH-03`, `STATE-01`, `VIEW-01`, `IDX-01`, `BACK-01`, backed-up `VERSION`, versioned `config/` including `readers.lock`, and recovery sequence `D16`.
- **Outputs:** restore/verify workflow; authority/config compatibility check; chain/head reconstruction; native-view materialization; logical read-snapshot recreation where valid; fresh index build; receipt comparison; native-open/search smoke checks; safe source re-enrollment boundary; explicitly labeled salvage mode.
- **Depends on:** `AUTH-03`, `STATE-01`, `VIEW-01`, `IDX-01`, `BACK-01`.
- **Completion evidence:** full R10 recovery restores and validates `VERSION`, `config/`, `native/`, and `manifests/`; exact objects and provenance verify; state and search rebuild from scratch under pinned readers; unsupported fingerprints leave bytes intact and coverage explicit; recovered authority is healthy before source reconnection. If config is missing, only raw-byte/manifest-provenance salvage is available: policy, trusted interpretation, search claims, and re-enrollment remain disabled until config is restored or explicitly reconstructed and reviewed.
- **Tests:** clean-machine synthetic full restore with no state/derived/source hosts; missing-config salvage mode; wrong/incompatible config or readers lock; unsupported fingerprint; missing/corrupt object; chain break; unavailable logical SQLite recreation; index rebuild; receipt mismatch; and first successor after re-enrollment.
- **Safety and rollback:** recovery writes a new private root and never repairs from derived output. A failed authority or config verification prevents operational activation and leaves the selected backup snapshot unchanged; salvage mode is read-only and cannot resume collection.
- **Traceability:** `R1`, `R2`, `R6`, `R9`, `R10`, `R11`, `D4`, `D16`, `S09`, `S10`.

### NIX-01 — Package the executable, development shell, and checks for three systems

- **Purpose:** provide pinned, reproducible package/app/development/check outputs for Darwin arm64, Linux arm64, and Linux x86_64.
- **Inputs:** `FND-01`, accepted `GATE-01`, and package outputs in `D13`.
- **Outputs:** `packages.<system>.session-archive`, default package, app, development shell, unit/integration/package checks, and pinned declarations for OpenSSH, rsync, SQLite, restic, and optional plugin closures.
- **Depends on:** `FND-01`, `GATE-01`.
- **Completion evidence:** every target evaluates, builds, runs CLI smoke tests, and executes unit/integration/package checks in its pinned closure; optional plugins do not enlarge the baseline closure; runtime tool versions are inspectable.
- **Tests:** clean three-system build/evaluation, closure inspection, missing external tool, CLI help/version, test suite, shell tooling, optional plugin disabled/enabled, and no secret material in the Nix store.
- **Safety and rollback:** packaging creates store closures only; it does not create users, directories, services, credentials, archive state, or network access.
- **Traceability:** `R13`, `R14`, `D12`, `D13`, `E05`, `Q13`.

### NIX-02 — Implement source and hub NixOS/nix-darwin role modules

- **Purpose:** express least-privilege source/helper and hub/coordinator roles without producing a second writer or embedding secrets in Nix.
- **Inputs:** `FND-02`, `FND-03`, `ORCH-01`, `OBS-01`, `BACK-01`, `NIX-01`, and accepted `GATE-03`, `GATE-04`, `GATE-07`, `GATE-08`.
- **Outputs:** NixOS source/hub modules; nix-darwin source/hub modules; options for IDs, labels, allowlisted roots, schedules, concurrency, store path, credential references, backup references, and feature flags; systemd/launchd units and timers disabled until configured.
- **Depends on:** `FND-02`, `FND-03`, `ORCH-01`, `OBS-01`, `BACK-01`, `NIX-01`, `GATE-03`, `GATE-04`, `GATE-07`, `GATE-08`.
- **Completion evidence:** module evaluation rejects world-readable paths, secret values, invalid roots, hub/source writer collision, and unsafe helper commands; source hosts install no resident network service; hub role has one coordinator; generated units use owner-only runtime paths and credential helpers.
- **Tests:** module evaluation for all roles/systems; option defaults and rejection cases; unit hardening; schedule disabled/enabled; credential reference; source helper forced command; duplicate writer; package closure; service start/stop/restart on synthetic roots.
- **Safety and rollback:** module tests do not deploy. Later rollback disables units/timers first, preserves authority, and removes only package/runtime state after verification.
- **Traceability:** `R8`, `R12`, `R13`, `R15`, `D7`, `D12`, `D13`, `D14`, `D15`, `D16`.

## 10. Acceptance, documentation, and release packages

Acceptance is semantic rather than numerical: every design walkthrough must prove its stated invariant, and every residual unknown must remain visible. Passing component tests is necessary but not sufficient.

### E2E-01 — Execute the ten design walkthroughs with synthetic data

- **Purpose:** validate the integrated system against every scenario in design section 19 and the complete requirement set.
- **Inputs:** all baseline production packages through `NIX-02`; accepted gates; scenario ledger `S01`–`S10`; `PLUG-01` evidence only when that optional package is enabled.
- **Outputs:** reproducible end-to-end harness and evidence bundle for normal/unchanged collection, offline catch-up, crash boundaries, live JSONL, live SQLite, identifier collision, resume/fork/branch, schema drift, index loss/rebuild, and hub loss/recovery.
- **Depends on:** `SRC-01`, `SRC-02`, `SRC-03`, `SRC-04`, `SRC-05`, `SRC-06`, `SRC-07`, `SRC-08`, `SRC-09`, `RDR-02`, `RDR-03`, `RDR-04`, `RDR-05`, `RDR-06`, `RDR-07`, `RDR-08`, `RDR-09`, `RDR-10`, `IDX-02`, `OBS-01`, `MIG-01`, `REC-01`, `NIX-02`.
- **Completion evidence:** each scenario starts from a verified manifest head, executes the documented failure/transition, and asserts the exact R1–R15 outcomes; deleting all state/derived products and losing the hub do not impair native recovery; unknown desktop/reader coverage remains explicit; optional plugin results are tested when enabled and otherwise recorded deferred.
- **Tests:** the ten scenarios are the tests; each runs under the relevant target-system closure, with crash/fault injection and secret/path canaries where applicable.
- **Safety and rollback:** all data, hosts, repositories, credentials, and services are synthetic and isolated. A failed scenario blocks release readiness and cannot be waived by unrelated green tests.
- **Traceability:** `R1`–`R15`, `D4`–`D18`, `S01`–`S10`, `RC01`–`RC10`.

### DOC-01 — Write operator, recovery, privacy, and extension documentation

- **Purpose:** document the verified commands, invariants, status meanings, recovery procedure, privacy controls, adapter/reader extension rules, and deployment authorization boundary.
- **Inputs:** `E2E-01`, `GATE-08`, `GATE-09`, all accepted decisions, and actual CLI/module behavior.
- **Outputs:** local install/build/check guide; configuration/enrollment reference; source-state and coverage glossary; collection/search/verify/backup/restore runbook; incident and low-space procedure; adapter/reader/plugin extension guide; privacy/fixture policy; migration policy; deployment and rollback checklist.
- **Depends on:** `E2E-01`, `GATE-08`, `GATE-09`.
- **Completion evidence:** every documented command is exercised by a check or walkthrough; authority versus derived state is unambiguous; unknown states and destructive prohibitions are prominent; no credentials, private paths, transcript excerpts, invented SLOs, or unsupported claims appear.
- **Tests:** command/link validation, clean-reader walkthrough, recovery rehearsal against the runbook, sensitive-content scan, stale-version check, and cross-reference audit to R1–R15 and S01–S10.
- **Safety and rollback:** documentation never instructs remote mutation or private ingestion without an explicit approval checkpoint. Destructive operations are absent unless `GATE-09` accepted them.
- **Traceability:** `R1`–`R15`, `D4`–`D18`, `Q01`–`Q15`, `S01`–`S10`.

### REL-01 — Record implementation and deployment readiness

- **Purpose:** decide whether the locally verified implementation is fit to enter a separately authorized deployment goal.
- **Inputs:** all gate decisions, `E2E-01`, `DOC-01`, package/test evidence, and unresolved-question ledger.
- **Outputs:** requirement/scenario/evidence matrix; accepted/deferred/failed gate register; residual-risk register; deployment prerequisites; explicit no-go conditions; and applicability criteria for the future implementation issue tree.
- **Depends on:** `DOC-01`, `E2E-01`, `GATE-01`, `GATE-02`, `GATE-03`, `GATE-04`, `GATE-05`, `GATE-06`, `GATE-07`, `GATE-08`, `GATE-09`, `GATE-10`, `GATE-11`.
- **Completion evidence:** every `R`, `D`, `E`, `Q`, `RC`, and `S` locator maps to accepted evidence, an explicit retained unknown, or a blocking gate; no incomplete authority, recovery, security, or backup condition is labeled deployment-ready.
- **Tests:** programmatic evidence-coverage validation; full check suite on all target systems; diff/license/secret/privacy review; independent review of authority, recovery, and rollout boundaries.
- **Safety and rollback:** readiness is documentary and revocable. It does not create issues, deploy, ingest, connect to fleet hosts, or satisfy `APR-01`.
- **Traceability:** `R1`–`R15`, `D4`–`D18`, `E01`–`E09`, `Q01`–`Q15`, `RC01`–`RC10`, `S01`–`S10`.

## 11. Separately authorized deployment track

The deployment packages are dormant specifications for later issue mapping. They remain out of scope unless the user confirms fleet work explicitly. Authorization is graph data: every mutating stage depends on one of the manual `APR-01`–`APR-08` packages, whose only completion evidence is an explicit user decision recorded on that approval issue. No agent may infer authorization from technical readiness, elapsed time, or completion of the preceding stage.

### APR-01 — Authorize deployment preparation

- **Purpose:** obtain explicit user authorization for a deployment-preparation goal limited to synthetic rehearsal.
- **Inputs:** `REL-01` readiness record, residual risks, proposed host/role matrix, credentials plan, backup endpoints, rollback boundaries, and exact proposed preparation actions.
- **Outputs:** recorded user decision naming the allowed synthetic/local scope, prohibited private-data and remote-mutation boundaries, stop conditions, and approval provenance.
- **Depends on:** `REL-01`, `GATE-03`, `GATE-07`, `GATE-08`.
- **Completion evidence:** the user explicitly approves the stated preparation scope in the approval issue or linked goal confirmation; silence, prior architectural approval, and issue readiness do not qualify.
- **Tests:** review the proposed scope against `REL-01`; confirm that it permits no private source enrollment, remote mutation, or unattended capture.
- **Safety and rollback:** this package performs no technical action. It remains open until explicit approval and may be revoked before `DEP-01`.
- **Traceability:** `R8`, `R10`, `R12`, `R13`, `R15`, `D7`, `D13`–`D16`.

### DEP-01 — Rehearse deployment with synthetic data only

- **Purpose:** validate package/module activation, credentials plumbing, backup, and rollback on synthetic roots without private data or remote mutation.
- **Inputs:** accepted `APR-01`, approved synthetic scope, and `REL-01` evidence.
- **Outputs:** synthetic role/configuration, module activation/deactivation receipt, backup/restore evidence, health evidence, and rollback result.
- **Depends on:** `APR-01`.
- **Completion evidence:** synthetic service lifecycle, backup, clean restore, status, and rollback pass within the approved scope; no private bytes or remote configuration are touched.
- **Tests:** dry evaluation, synthetic service lifecycle, low-space guard, backup/restore, credential reference, and complete disable/cleanup rehearsal.
- **Safety and rollback:** stop before first local production mutation, remote mutation, or private-data access. Remove only synthetic/disposable state after preserving test evidence.
- **Traceability:** `R8`, `R10`, `R12`, `R13`, `R15`, `D13`–`D16`.

### APR-02 — Authorize the local capture-disabled canary

- **Purpose:** obtain explicit user authorization for the first named local package/module mutation while capture remains disabled.
- **Inputs:** accepted `DEP-01`, exact local target, package/module diff, runtime paths, credentials references, rollback commands, and proof that no source root or capture timer is enabled.
- **Outputs:** recorded user decision naming the local target and exact allowed mutations, with capture/private-data prohibitions and rollback checkpoint.
- **Depends on:** `DEP-01`.
- **Completion evidence:** the user explicitly approves the named local mutation in this approval issue; the approval names the host, role, units, paths, and capture-disabled boundary.
- **Tests:** review generated configuration and rollback against the approved scope; confirm no remote target, private root, or active capture schedule.
- **Safety and rollback:** this package performs no mutation. A changed target or mutation set requires a new approval decision.
- **Traceability:** `R8`, `R12`, `R13`, `R15`, `D7`, `D13`–`D15`.

### DEP-02 — Deploy the local canary with capture disabled

- **Purpose:** install the approved package/module on the named local target while preventing session acquisition.
- **Inputs:** accepted `APR-02`.
- **Outputs:** package and owner-only runtime directories, validated configuration, disabled or synthetic-only units, health evidence, and uninstall/disable rollback receipt.
- **Depends on:** `APR-02`.
- **Completion evidence:** identity, paths, permissions, closure, status, and rollback pass; no private source root is enrolled and no timer performs capture.
- **Tests:** local service lifecycle, synthetic capture/backup/restore, low-space guard, credential reference, capture-disabled assertion, and rollback.
- **Safety and rollback:** disable units and remove disposable runtime state while preserving any synthetic authority. Stop before private source enrollment.
- **Traceability:** `R8`, `R10`, `R12`, `R13`, `R15`, `D13`–`D16`.

### APR-03 — Authorize the first private-source canary

- **Purpose:** obtain explicit user authorization to cross the private-data boundary for one named local source only.
- **Inputs:** accepted `DEP-02`, selected source/root, privacy review, source-specific snapshot gate, capacity floor, backup endpoint, restore plan, and exact capture/scheduling actions.
- **Outputs:** recorded user decision naming the sole source/root, permitted bytes and metadata, schedule or one-shot mode, backup destination, stop conditions, and rollback posture.
- **Depends on:** `DEP-02`.
- **Completion evidence:** the user explicitly approves the named private-data scope in this approval issue; no additional source, root, host, export, or cloud API is implied.
- **Tests:** review allowlists/exclusions, live-store strategy, free-space floor, content-free logging, backup readiness, and rollback against the approval.
- **Safety and rollback:** this package performs no capture. Any source/root/snapshot-method change requires renewed approval.
- **Traceability:** `R1`, `R3`, `R5`, `R8`, `R10`, `R15`, `D8`, `D14`–`D16`.

### DEP-03 — Run one private-source canary and first backup

- **Purpose:** capture one explicitly approved local source, verify authority and coverage, and prove off-hub backup and clean restore.
- **Inputs:** accepted `APR-03`.
- **Outputs:** one-source enrollment, first exact native generation, authority verification, disposable index, off-hub snapshot, sampled clean restore, and rollback receipt.
- **Depends on:** `APR-03`.
- **Completion evidence:** native hash/provenance, state classification, coverage, backup, and restore verify; logs remain content-free; no other source or host is touched.
- **Tests:** normal run, unchanged rerun, interrupted rerun, index delete/rebuild, backup/check/restore, disable, and rollback.
- **Safety and rollback:** stop before additional sources or any remote mutation. Disable scheduling, preserve verified authority/backups, and remove only disposable state on rollback.
- **Traceability:** `R1`–`R12`, `R15`, `D7`–`D16`, `S01`, `S03`, `S09`, `S10`.

### APR-04 — Authorize remaining hub-local sources

- **Purpose:** obtain explicit user authorization to enroll the remaining approved local source roots on the selected hub before any remote host changes.
- **Inputs:** accepted `DEP-03`, exact local source/root inventory, per-source snapshot gates, capacity/backup health, staged order, and rollback boundary.
- **Outputs:** recorded user decision naming every allowed local source/root, enrollment order, exclusions, scheduling policy, stop conditions, and explicit prohibition on remote mutation.
- **Depends on:** `DEP-03`.
- **Completion evidence:** the user explicitly approves the enumerated hub-local scope in this approval issue; unlisted sources and every remote host remain blocked.
- **Tests:** review each local source against its gate, allowlist, capacity effect, backup coverage, and rollback procedure.
- **Safety and rollback:** this package performs no enrollment. Any added root or changed snapshot method requires renewed approval.
- **Traceability:** `R3`, `R5`, `R8`, `R10`, `R12`, `R15`, `D7`–`D16`.

### DEP-04 — Enroll remaining hub-local sources serially

- **Purpose:** add the approved hub-local sources one source class at a time before any remote mutation.
- **Inputs:** accepted `APR-04`.
- **Outputs:** per-source enrollment receipts, first/unchanged runs, coverage, backup inclusion, restore sample, alerts, and rollback evidence.
- **Depends on:** `APR-04`.
- **Completion evidence:** every approved hub-local source verifies authority, coverage, capacity, backup, and rollback before the next begins; remote hosts remain untouched.
- **Tests:** staged local enrollment, live JSONL/SQLite rules, unknown/absent states, low-space stop, backup failure, sampled restore, and per-source rollback.
- **Safety and rollback:** pause on any failed gate, unexplained growth, incomplete snapshot, privacy finding, or backup/recovery defect. Disable only the failing source while retaining verified authority.
- **Traceability:** `R1`–`R15`, `D7`–`D18`, `S01`, `S03`–`S10`.

### APR-05 — Authorize remote-host stage 1

- **Purpose:** obtain explicit user authorization for exactly one not-yet-enrolled remote host and select it as stage 1.
- **Inputs:** accepted `DEP-04`, the four remaining host candidates (`clio`, `vps`, `vulcan`, `andoria-08`), exact proposed host mutation/helper scope, source roots, credentials, capacity/backup health, and rollback commands.
- **Outputs:** recorded user decision naming one host, its role, allowed mutations and roots, stage-specific stop conditions, and the still-blocked remaining hosts.
- **Depends on:** `DEP-04`.
- **Completion evidence:** the user explicitly approves one named host in this approval issue; no other remote host or mutation is implied.
- **Tests:** review host identity, pinned SSH key, module/helper diff, roots/exclusions, source gates, backup coverage, and rollback against the approval.
- **Safety and rollback:** this package performs no connection or mutation. Any target or scope change requires renewed approval.
- **Traceability:** `R3`, `R8`, `R10`, `R12`, `R13`, `R15`, `D7`, `D13`–`D16`.

### DEP-05 — Enroll remote-host stage 1

- **Purpose:** mutate and enroll only the host authorized by `APR-05`, then verify collection, backup, restore, and rollback before another host is considered.
- **Inputs:** accepted `APR-05`.
- **Outputs:** host mutation receipt, per-cell/source states, first/unchanged/offline-catch-up runs, backup coverage, restore sample, health, and rollback evidence.
- **Depends on:** `APR-05`.
- **Completion evidence:** the approved host verifies all applicable source and operational contracts; unapproved hosts remain untouched.
- **Tests:** package/helper lifecycle, pinned SSH pull, source canaries, offline catch-up, live-store rules, low-space stop, backup/restore, and host rollback.
- **Safety and rollback:** pause before another host. Disable the host helper/collection while retaining verified hub authority and backups.
- **Traceability:** `R1`–`R15`, `D7`–`D18`, `S01`–`S10`.

### APR-06 — Authorize remote-host stage 2

- **Purpose:** obtain fresh user authorization for exactly one remaining remote host after stage 1 evidence is reviewed.
- **Inputs:** accepted `DEP-05`, remaining host candidates, stage 1 results, exact proposed host mutation/helper scope, roots, credentials, backup/capacity health, and rollback commands.
- **Outputs:** recorded user decision naming stage 2’s sole host and scope, with all other remaining hosts still blocked.
- **Depends on:** `DEP-05`.
- **Completion evidence:** the user explicitly approves one not-yet-enrolled host in this approval issue after reviewing stage 1; no scope carries forward implicitly.
- **Tests:** verify target uniqueness and review identity, SSH pinning, module/helper diff, roots, source gates, backup, and rollback.
- **Safety and rollback:** this package performs no connection or mutation; changed scope requires renewed approval.
- **Traceability:** `R3`, `R8`, `R10`, `R12`, `R13`, `R15`, `D7`, `D13`–`D16`.

### DEP-06 — Enroll remote-host stage 2

- **Purpose:** enroll only the host authorized by `APR-06` and stop after independent verification.
- **Inputs:** accepted `APR-06`.
- **Outputs:** stage 2 mutation, source-state, collection, backup, restore, health, and rollback receipts.
- **Depends on:** `APR-06`.
- **Completion evidence:** stage 2 passes applicable source and operational contracts without changing any other remaining host.
- **Tests:** repeat the stage 1 host test contract for the newly approved host, including offline catch-up and rollback.
- **Safety and rollback:** pause before stage 3; disable the stage 2 helper/collection while retaining authority and backups.
- **Traceability:** `R1`–`R15`, `D7`–`D18`, `S01`–`S10`.

### APR-07 — Authorize remote-host stage 3

- **Purpose:** obtain fresh user authorization for exactly one remaining remote host after stages 1 and 2 are reviewed.
- **Inputs:** accepted `DEP-06`, remaining host candidates, prior stage evidence, exact mutation/helper scope, roots, credentials, backup/capacity health, and rollback.
- **Outputs:** recorded user decision naming stage 3’s sole host and scope, with the final host still blocked.
- **Depends on:** `DEP-06`.
- **Completion evidence:** the user explicitly approves one not-yet-enrolled host in this approval issue; earlier approvals do not carry forward.
- **Tests:** verify target uniqueness and review the complete host-specific mutation, source, backup, and rollback scope.
- **Safety and rollback:** this package performs no connection or mutation; changed scope requires renewed approval.
- **Traceability:** `R3`, `R8`, `R10`, `R12`, `R13`, `R15`, `D7`, `D13`–`D16`.

### DEP-07 — Enroll remote-host stage 3

- **Purpose:** enroll only the host authorized by `APR-07` and stop after independent verification.
- **Inputs:** accepted `APR-07`.
- **Outputs:** stage 3 mutation, source-state, collection, backup, restore, health, and rollback receipts.
- **Depends on:** `APR-07`.
- **Completion evidence:** stage 3 passes applicable source and operational contracts without changing the final host.
- **Tests:** repeat the approved remote-host test contract, including offline catch-up, backup/restore, and rollback.
- **Safety and rollback:** pause before the final host; disable stage 3 collection while retaining verified authority and backups.
- **Traceability:** `R1`–`R15`, `D7`–`D18`, `S01`–`S10`.

### APR-08 — Authorize remote-host stage 4

- **Purpose:** obtain fresh user authorization for the final remaining remote host after stages 1–3 are reviewed.
- **Inputs:** accepted `DEP-07`, identity of the sole remaining host, prior stage evidence, exact mutation/helper scope, roots, credentials, backup/capacity health, and rollback.
- **Outputs:** recorded user decision naming the final host and its exact scope.
- **Depends on:** `DEP-07`.
- **Completion evidence:** the user explicitly approves the final named host in this approval issue; target uniqueness and complete scope are verified.
- **Tests:** review the final host identity, SSH pinning, module/helper diff, roots, source gates, backup coverage, and rollback.
- **Safety and rollback:** this package performs no connection or mutation; changed scope requires renewed approval.
- **Traceability:** `R3`, `R8`, `R10`, `R12`, `R13`, `R15`, `D7`, `D13`–`D16`.

### DEP-08 — Enroll remote-host stage 4 and review fleet state

- **Purpose:** enroll only the host authorized by `APR-08`, then perform the final fleet-wide state and recovery review.
- **Inputs:** accepted `APR-08`.
- **Outputs:** final host receipts; complete 45-cell state; authority, coverage, capacity, backup, restore, alert, and rollback review across the deployed fleet.
- **Depends on:** `APR-08`.
- **Completion evidence:** the final host passes applicable contracts; all 45 cells are represented; unknown/cloud-only surfaces remain explicit; one writer remains on the selected hub; backup and recovery evidence covers every enrolled source.
- **Tests:** approved host contract plus fleet offline catch-up, hooks-as-hints, live JSONL/SQLite, low-space, backup failure, sampled restore, and per-host rollback review.
- **Safety and rollback:** pause on any failed gate or unexplained state. Disable only affected collection paths while retaining verified authority and backups.
- **Traceability:** `R1`–`R15`, `D7`–`D18`, `S01`–`S10`.

## 12. Issue-tree mapping rules

The later `obr` conversion is mechanical rather than interpretive. The plan’s package IDs, dependency edges, and acceptance evidence remain unchanged when issues are created.

1. Create one epic for the archive implementation and one child epic for each phase in section 4.1. Keep the deployment track in a separate, blocked epic.
2. Create one task per package in `GATE-01`–`GATE-11`, the production and acceptance catalog, `APR-01`–`APR-08`, and `DEP-01`–`DEP-08`. Preserve the package ID in the title or external reference.
3. Copy **Purpose** into the issue description and **Completion evidence** plus **Tests** into acceptance criteria. Copy **Safety and rollback** into design/notes.
4. Translate every **Depends on** package into an `obr` blocking dependency. Do not infer dependencies from section order.
5. Represent each package in `APR-01`–`APR-08` as a manual approval/question issue, never as an executable mutation task. It may close only when its own completion evidence contains the explicit user decision; never auto-close it from readiness, an earlier approval, or a technical check. Its corresponding package in `DEP-01`–`DEP-08` remains blocked by that exact approval issue.
6. Keep gate failures open or return dependent issues to blocked. Do not close a gate with an unreviewed benchmark artifact or proxy test.
7. Record discovered work only when it is not already represented by a package. Link it with `discovered-from` and do not broaden a package silently.
8. Commit `doc/PLAN.org` with implementation changes only in the later execution goal, following repository policy. This planning goal creates no issue and changes no `obr` state.

## 13. Plan verification checklist

The final plan review treats this document as a graph and a traceability specification, not merely prose.

- Every package heading has a unique stable ID and every referenced package ID exists.
- Every package contains all eight mandatory contract fields.
- The dependency graph is acyclic; gates precede the packages they release; deployment alternates serial manual approvals and mutating stages.
- `R1`–`R15`, `D4`–`D18`, `E01`–`E09`, `Q01`–`Q15`, `RC01`–`RC10`, and `S01`–`S10` each map to one or more valid package IDs or explicit gates.
- Authority packages alone can preserve and verify exact native bytes and immutable provenance.
- Deleting all `state/` and `derived/` remains a supported acceptance test.
- No package grants custody to SQLite, a viewer, an export, telemetry, cloud API, or restic.
- Every experiment has pass/fail evidence, a reversal outcome, and dependent packages.
- Every source surface has a collection package; every interpretable surface has a distinct reader package; unknown semantic coverage remains visible.
- Tests use synthetic or structurally redacted fixtures. Real private content and fleet mutation occur only under the deployment track.
- No owner, estimate, cost, performance target, retention period, or SLO has been invented.
- `DESIGN.md`, `RESEARCH.md`, and `PLAN.org` retain their pre-plan hashes.
- The repository diff for this goal contains only `doc/IMPLEMENTATION.md`.

## 14. Residual decisions at plan completion

The plan deliberately leaves implementation-contingent decisions open. They are not omissions: each has a gate and blocks only the work that actually depends on it.

| Decision | Default while open | Resolution |
| --- | --- | --- |
| Core language | Haskell | `GATE-01`; Python only on documented core-risk evidence |
| Exact live-WAL method | Preserve uncertain exact bytes as incomplete; logical snapshot remains derived | `GATE-02` |
| Hub and backup endpoints | `hera` provisional; no endpoint treated as independent or usable without an authorized isolated synthetic backup/check/clean-restore proof | `GATE-03` |
| Pull cadence | Daily completeness concept; no invented SLO | `GATE-04`, then `GATE-08` |
| Search targets and optional analytics | Local SQLite/FTS lexical baseline; no DuckDB/vector requirement | `GATE-05`, then `GATE-08` |
| Existing reader/viewer reuse | None required for correctness | `GATE-06` |
| Signatures and key custody | SHA-256 chains plus encrypted backup; unsigned manifests | `GATE-07` |
| Remote query, path display, alerts, SLOs | Local CLI; private reversible paths; conservative/unspecified thresholds | `GATE-08` |
| Authority erasure/GC | Disabled; indefinite retention | `GATE-09` |
| Desktop/cloud completeness | Explicit unknown/unsupported states | `GATE-10` |
| Native metadata and parser fixtures | Conservative allowlist; synthetic fixtures only | `GATE-11` |

A later issue map may subdivide a package only when one part can be implemented, reviewed, and rolled back independently while retaining the package’s acceptance contract. It may not combine packages that cross an authority, privacy, recovery, or deployment gate.
