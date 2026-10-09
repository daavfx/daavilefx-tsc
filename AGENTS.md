# Build and dev rules

Fork-specific working rules. Compiler porting rules live in
[crates/ts_goport/PORTING.md](crates/ts_goport/PORTING.md); the parity harness is documented in
[scripts/goport/README.md](scripts/goport/README.md).

## Identity

- Fork of [pingdotgg/ts-rust](https://github.com/pingdotgg/ts-rust), a Rust port of Microsoft's
  TypeScript-Go compiler. This checkout is
  [daavfx/daavilefx-tsc](https://github.com/daavfx/daavilefx-tsc).
- Remotes: `origin` = daavfx/daavilefx-tsc (ours), `upstream` = pingdotgg/ts-rust. Do not push to
  `upstream`: a push there arrives as a pull request on the upstream repo. Pull upstream into a
  topic branch instead.
- The compiler port is upstream's work. Keep the credit, the MIT license text and the notices
  ([LICENSE](LICENSE), [NOTICE.md](NOTICE.md), `licenses/`) intact in everything you touch.

## Layout

- `crates/ts_goport`: the compiler. The part crates `goport_util` and `goport_lsproto` live in
  `crates/ts_goport/parts`; the lib files are in `crates/ts_goport/libs`. The main bins are
  `goport` (type check) and `tsgo` (the Go `tsgo` command line); `crates/ts_goport/src/bin` also
  holds the `goport_*` helpers.
- `crates/ts_wasm`: the wasm32-wasip1 build (profile `wasm`).
- `tools/ts_ast_codegen` generates `crates/ts_goport/src/astdata`; `tools/ts_diagnostics_codegen`
  generates `crates/ts_goport/src/diagnostics/catalog.rs` and
  `crates/ts_goport/src/diag.rs`.
- `scripts/`: `verify.sh`, `run-cargo-capped.sh`, `tsgo-oracle.sh`; `scripts/upstream/` holds the
  pin tooling (`pin.py`, `drift.py`, `record.py`, `rerecord.sh`); `scripts/goport/` holds the
  parity harness.

## Build

- `cargo build --release --bins`. Rust toolchain 1.93 or newer (CI pins 1.93.0); the workspace is
  edition 2024, resolver 3.
- The default `jemalloc` feature is a no-op on Windows and wasm: `tikv-jemallocator` and
  `tikv-jemalloc-ctl` are only enabled for other targets, and the binaries use the system
  allocator there.
- `--profile goport` is the fat-LTO release profile (`lto = "fat"`, one codegen unit) that PGO
  builds on top of. It is optional and slow; use it for timing and for shipped binaries. A plain
  `--release` build does not change compiler output.
- Windows target: `x86_64-pc-windows-msvc` is supported (named pipes for `--pipe`, native path
  handling, the Windows fs watch, `os.SameFile` in `LookPath`). There is no Windows CI runner and
  upstream ships no Windows binary, so the local Windows build is the source of truth for that
  target: build and test there before claiming a change works on Windows.
- Do not build on the C: drive (low disk). Keep `target/` on F:: set `CARGO_TARGET_DIR` (for
  example `F:\qfx-build`) or use a local `target/` under F:.

## Tests

- `cargo test --release --locked --workspace`.
- The Go baseline suite (`cargo test --release -p ts_goport --test go_baselines`) compares against
  a Go checkout of a pin: `TS_GO_REPO=<checkout>` (`scripts/upstream/pin.py path goCheckout`
  resolves it for a pin). It needs Go and is optional. The full parity harness (goport tests,
  gate, LSP and API oracles) is documented in
  [scripts/goport/README.md](scripts/goport/README.md).

## Windows-first conventions

- Prefer PowerShell for new scripts and ad-hoc commands. The shipped scripts are bash and are
  being ported one at a time; until one is ported, call it through bash but write the new code in
  PowerShell.
- The upstream oracle and parity scripts (`scripts/goport/`, `scripts/upstream/`) contain paths
  that only exist on the previous author's machine. Edit those paths before running anything that
  expects a Go checkout, an oracle binary or a pin cache. `pin.py exec` runs the command in a
  bubblewrap mount namespace, which is Linux-only; on Windows use `pin.py show` and `pin.py path`
  and set the paths by hand.

## Upstream pin

- `UPSTREAM.json` is the machine-readable pin record, `UPSTREAM.md` the provenance. `current` is
  the pin the compiler tracks: microsoft/TypeScript `673a5f17d713`, the Go module under `tsc/`
  (TypeScript 7.1.0-dev). Keep `current`, `UPSTREAM.md` and the README status section in step.
- `GOPORT_PIN=<key>` (the first 12 hex digits of a pin commit) runs one command against another
  pin through `scripts/upstream/pin.py`. CI reads `current` from `UPSTREAM.json`.
- A pin bump is a deliberate act with per-pin evidence (oracle outputs, baselines). Do not bump it
  as part of an unrelated change.
