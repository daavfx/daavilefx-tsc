# DAAVILEFX-TSC — Plan

Fork of [`pingdotgg/ts-rust`](https://github.com/pingdotgg/ts-rust), owned by
[`daavfx`](https://github.com/daavfx).

**Remote:** <https://github.com/daavfx/daavilefx-tsc> (public, admin)
**Local:** `F:\ts-rust\daavilefx-tsc`
**Upstream:** `pingdotgg/ts-rust` (remote `upstream`)

## Status (2026-10-09)

- Phases 0–3 done and pushed (`8cd03f1d`): fork, Windows build proven,
  de-slop (~52 MB / ~250 files), identity rewrite, 98 branches pruned.
- Phase 4 done: `scripts/build-windows.ps1` (proven end-to-end),
  `scripts/daavilefx.ps1` (`check` / `emit` / `typesyms` / `version`,
  exit codes pass through for gates and harnesses).
- First fork bug fixed and proven: `goport_typesyms` mangled Windows
  paths into an empty `..!C` file (bad `project_dir` on backslashes +
  drive-letter `:` landing in an NTFS alternate stream). Fixed both,
  `app.ts.types` + `app.ts.symbols` now emit with full type/symbol data.
- Phase 5 verdict (copytrader_ui, 285 files, tsc 5.8.3 clean):
  tsgo is **8.1x faster (5.7 s -> 0.7 s)** and its 3 diagnostics are
  **byte-identical to `tsc --strict`** (same codes, positions, messages;
  only union member display order differs cosmetically). The strict
  behavior on a strict-less tsconfig is **upstream TS 6/7 behavior, not a
  port bug**: strict is true by default since TS 6.0 (#62333, 6.0
  announcement). Migration = add `"strict": false` (zero code changes,
  keeps the gate green) or fix the 3 real latent issues found
  (atlas.tsx double index, SetfileBuilderPage union access,
  RiskToSizer variance) and go strict.

## Use cases (what this is for)

1. **Quantum app type-check gate.** `daavilefx.ps1 check -p <tsconfig>`
   replaces `tsc --noEmit` in `scripts/typecheck-core.mjs`. Upstream numbers:
   62.63 s (tsc 6) / 16.10 s (tsc 7) / 7.25 s (tsc-rs) over five projects.
2. **Local-LLM verification oracle.** The llama.cpp harness feeds a file or
   project to `check`, reads `file(line,col): error TSNNNN: message` lines
   off stdout/stderr, and retries the model with the diagnostics. Exit codes
   are the contract: 0 clean, 1 type errors, 2 crash/bad input.
3. **Codebase intelligence.** `daavilefx.ps1 typesyms -p <tsconfig> -o <dir>`
   dumps `.types` + `.symbols` per file — the RAG / RYIUK-memory substrate,
   no Node required.
4. **In-editor diagnostics (later).** `crates/ts_wasm` builds the same
   compiler as a `wasm32-wasip1` module for the DaavileIDE webview.
   PROVEN 2026-10-09: `scripts/wasm/build.sh` runs under Git Bash
   (`WASM_OPT=none` without binaryen) → 5.77 MB module (1.75 MB brotli);
   the repo's own `npm/wasm` loader type-checks in-memory projects in
   Node with correct diagnostics and exit codes (smoke test, module
   removed afterwards — rebuild with build.sh).

Out of scope: bundling (Vite/esbuild keep that job), the vendored Orca fork
(32,775 TS files we don't own), release-critical-path use before the Phase 5
dialect verdict (TS 7.1.0-dev vs our TS 5.8.2).

---

## 0. Answers to the fork questions

### "If we fork we can't delete, right?"

Wrong — a fork is a normal repository that you own. You can delete any file,
rewrite history, force-push, rename, or make it private. Nothing about forking
restricts your rights.

What forking *does* do, and what you cannot undo:

1. **The fork network is permanent.** GitHub records that `daavilefx-tsc` was
   forked from `pingdotgg/ts-rust`. That link cannot be removed (it can only be
   detached, which stops sync but keeps the record). Every commit we inherit is
   still reachable through upstream, forever, and through the network view.
2. **Deleting a branch on your fork does not delete it upstream.** The 100
   `goport-*` branches we inherited exist on `pingdotgg/ts-rust` as well.
   Pruning them here tidies *our* repo only.
3. **Rewriting history here detaches nothing upstream**, but it does break our
   own `origin/main..upstream/main` comparison, and any SHA we already pushed.
   Rewriting is only worth it if we want to remove PII from *our* view.
4. **You cannot delete or edit `pingdotgg/ts-rust` itself**, and a push to
   `upstream` would arrive as a pull request, not a commit.

Verdict for this project: **do not rewrite history.** The author already
scrubbed his public history once (2026-10-07, per the old `AGENTS.md`), the
remaining references are working notes in the *working tree*, and history
rewriting costs us the ability to pull upstream fixes. Clean the files, not the
past.

### What must survive the cleanup (legal, not optional)

| File | Why |
|---|---|
| `LICENSE` | `MIT AND Apache-2.0`. MIT requires the copyright and permission notice to be retained. |
| `NOTICE.md` | Apache-2.0 §4 notice preservation. |
| `licenses/Go-LICENSE.txt` | Go is BSD-3-Clause; the port contains Go-derived code. |
| `licenses/TypeScript-LICENSE.txt`, `TypeScript-NOTICE.txt` | Apache-2.0, upstream TypeScript. |
| `licenses/Unicode-LICENSE.txt`, `vscode-languageserver-node-LICENSE.txt` | Unicode + MIT respectively. |

Everything else in this repo is ours to change.

---

## 1. What we want (the goal, in priority order)

1. **A TypeScript compiler binary that runs on Windows.** Not a node wrapper, not
   a WASM demo — a native `.exe` we can put on PATH and call from scripts.
2. **A fast type-check gate for our own apps.** `tsc --noEmit` on
   `daavfx_dashboard` (1,086 TS files) is the slowest gate we own. Upstream's own
   benchmark: 62.63 s (tsc 6) / 16.10 s (tsc 7) / **7.25 s (tsc-rs)** over five
   projects — 8.6× faster than tsc 6.
3. **Type and symbol extraction over the whole tree** (`goport_typesyms`), as the
   data substrate for RYIUK memory, the Audit tab, and dependency analysis.
4. **WASM build for DaavileIDE** — TS diagnostics inside the Oraca webview with
   no Node child process.
5. **A verification oracle for local-LLM codegen** — the fastest available
   compiler check, used as ground truth for our llama.cpp models instead of
   hope.

Out of scope, deliberately: replacing Vite/esbuild for bundling; migrating the
vendored `daavilefx` Orca fork (32,775 of our 36,788 TS files, not our code).

## 2. What we need

| Need | Status | Note |
|---|---|---|
| Rust toolchain | have 1.95.0 MSVC | CI pins 1.93.0; 1.95 is newer, fine. |
| Windows build support in source | **already present** | PR #29 (`windows-msvc-tests`, merged) = "build and pass the test suites on `x86_64-pc-windows-msvc`". Carries `osvfs.rs`, `nativepath.rs`, `fswatch/windows.rs`, the named-pipe transport. |
| MSVC C++ build tools | to verify | needed for the linker on the MSVC target. |
| A Windows CI runner / release binary | **does not exist** | CI matrix is ubuntu x64/arm + macos-26; release is linux-musl + darwin-arm64. We are the first Windows user. |
| Go + Node for the oracle harness | optional | only for `go_baselines` and the parity scripts. Not needed to build or use the compiler. |
| Dialect decision | **open** | The port pins TypeScript **7.1.0-dev**; our apps run **5.8.2/5.8.3**. See Phase 5. |

## 3. What we will do

### Phase 0 — Fork (done)

`gh repo fork pingdotgg/ts-rust --fork-name daavilefx-tsc --clone`.
Verified: `viewerPermission: ADMIN`, `visibility: PUBLIC`, `isFork: true`,
96,313 KB disk usage, `origin` + `upstream` remotes set.

### Phase 1 — Prove it builds on Windows

The single most important question: does it actually compile here? Upstream
claims it does but ships no Windows runner.

```
cargo build --release --bins          # tsgo, goport, goport_typesyms, ...
```

Then `cargo test --release -p ts_goport` as the real proof (PR #29 only claims
the *tests* build and pass — nobody has run them since on a public runner).

Build goes to `F:\qfx-build` (shared cargo target per `AGENTS.md`) or a local
`target/`. Expected: 30-60 min for 631k lines without LTO.

### Phase 2 — De-slop

Three lists, in the slop section below. The whale is
`docs/typechecker-batches/` at **42.5 MB across 160 files** — pure LLM batch
receipts, the single largest non-source mass in the repo.

Two dependencies to cut first:

- `ci.yml:76` and `release.yml:187` read the pin out of
  `docs/typechecker-state/current.json`. Repoint both at `UPSTREAM.json`
  (which already carries the current pin) and the directory can go.
- `candidate.sh:804` already excludes both directories from its analysis, so
  the goport pipeline does not depend on them.

### Phase 3 — Rewrite identity

`AGENTS.md`, `README.md`, `UPSTREAM.json`, repo description/topics, prune the
100 inherited branches back to `main`.

### Phase 4 — Windows usability

PowerShell build script replacing `run-cargo-capped.sh`, libs placed next to the
binaries (`--features noembed` needs the `copy-libs.sh` equivalent), and a
`daavilefx.ps1` wrapper so `tsgo`/`goport` are one command away.

### Phase 5 — First real use, and the dialect verdict

Run both compilers over `copytrader_ui` (285 files — the smallest real app, and
the only one with `tsc && vite build`) and diff the diagnostics. The size of
that delta decides everything: if it is small, the TS 7 dialect is a non-issue
and Phase 5 becomes "swap the gate". If it is large, tsc-rs stays an advisory
second opinion until a TS 5-compatible pin exists.

## 4. The slop lists

Measured 2026-10-09 against `main` (`bee1c500`).

### 4.1 Delete — LLM working notes (no code depends on them)

| Path | Size | Why it is slop |
|---|---|---|
| `docs/typechecker-batches/` | **42.5 MB / 160 files** | Per-batch LLM receipts, hundreds of `/home/theo` paths and host names. |
| `docs/typechecker-state/history.jsonl` | **7.5 MB** | 287 "Theo" and 606 `/home/theo` hits. |
| `recommendations.md` | 13.5 KB | Theo's chat forward pasted verbatim. |
| `ts-rust-recovery-plan.html` | 7.2 KB | One-off HTML status page. |
| `docs/typechecker-accountability.md` | 48.1 KB | Agent-role rules for his `/goal` loop. |
| `docs/typechecker-port-goal.md` | 132.5 KB | Goal spec for a port that finished. |
| `docs/typechecker-demo-status.md` | 124.4 KB | Progress log. |
| `docs/typechecker-completion-goal.md` | 69.8 KB | Same. |
| `docs/typechecker-port-map.tsv` | 42.7 KB | Generated progress table. |
| `docs/typechecker-reset-plan.md` | 21.9 KB | Context-reset choreography. |
| `docs/typechecker-modern-project-inputs.md` | 23.5 KB | |
| `docs/typechecker-wave*/`, `parser-*` | ~0.5 MB | Wave-by-wave notes. |
| `docs/goport-agent-brief.md` | 8.2 KB | Host login brief. |
| `docs/goport-protected/`, `docs/probes/`, `docs/reviews/`, `docs/project-inputs/` | ~1.3 MB | |
| `scripts/check-typechecker-batch.mjs` + `.test.mjs` | 194 KB | Only reads the deleted batches. |
| `scripts/state`, `scripts/state.mjs`, `scripts/state.test.mjs` | 25.7 KB | Only manages the deleted state. |
| `scripts/goport/remote.sh`, `buildbench-remote.sh`, `gh-inbox.py`, `macos-like-test.sh`, `build-bolt.sh` | ~20 KB | `remote.sh` ssh's to his two hosts. |
| 100 inherited `goport-*` branches | — | Unmerged lane worktrees from his loop. |

Total removed: **~52 MB and ~250 files** — most of the repo's non-source mass.

### 4.2 Rewrite — keep the content, strip the identity

| Path | Change |
|---|---|
| `AGENTS.md` (root, 18.9 KB, 8 "Theo" hits) | Replace with DAAVILEFX rules. Drops `/home/theo` paths, "Theo has authorized continued work", the `goal-no-ask` hook, and the 2,000-worktree warnings. |
| `README.md` (14 KB) | Remove host names (`mini-743d`, `dbook-lan`). **Keep** the MIT credit and the cost story (`$420k` / `~$24k`) — it is provenance and it is honest. Add a DAAVILEFX section. |
| `UPSTREAM.json` (6.8 KB) | `/home/theo/...` pin paths → ours. |
| `UPSTREAM.md` (7 KB) | Keep; minor path edits. The provenance ledger is genuinely useful. |
| `.gitignore` | Drop `.claude`. |
| `npm/trust-setup.sh`, `npm/pack.mjs`, `scripts/audit/metrics.py` | Drop `pingdotgg` hard-coding and the `recommendations.md` reference. |
| `ci.yml`, `release.yml` | Repoint the pin lookup from `docs/typechecker-state/current.json` to `UPSTREAM.json`. |

### 4.3 Keep — code, tooling, provenance

`crates/`, `tools/`, `npm/`, `libs/` (113 `.d.ts`), `.github/`,
`scripts/verify.sh`, `scripts/run-cargo-capped.sh`, `scripts/upstream/pin.py`,
`scripts/wasm/`, `scripts/effect/`, `scripts/bench-apps/`, `scripts/goport/`
(the parity harness itself), plus the docs worth reading:
`docs/PORTING.md`, `docs/project-graph-limitations.md`,
`docs/effect-diagnostics.md`, `docs/history.md`.

## 5. Risks

1. **No Windows CI exists.** PR #29 proves it once, locally. Our build is the
   second data point, and it is the one that counts.
2. **TS 7.1.0-dev ≠ TS 5.8.** The port is byte-equal to Go `tsc` *at its pin*,
   not to TypeScript 5.8. Every diagnostic comparison is against a moving
   dialect. Phase 5 measures this before any gate is swapped.
3. **Four known upstream divergences** (rootDir `TS6059` in dual-reach monorepos,
   stale cross-project reads in `tsc -b`, LSP memory growth, `--version`).
   Our `shared/packages` + `shared/ui` multi-host pattern is exactly the
   dual-reach case flagged first — watch for a `TS2307` flood.
4. **Upstream is a one-person LLM port with no Windows distribution.** Every
   upstream pin bump means a rebuild and a revalidation by us.
5. **No secrets found** (no tokens, no `ghp_`, no API keys) in the working tree.
