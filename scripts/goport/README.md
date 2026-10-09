# goport measurement scripts

Parity/gate harness that compares Rust bins against the Go oracle.
Run from the repo root. Paths below are relative to `scripts/goport/`.

## Gate

- `gate.sh <label>`: full regression gate. Run it before any goport merge.
- `gate-compare.py <base manifest> <new manifest>`: item-by-item gate
  manifest compare. See its docstring for MATCH/ALLOWED/FAIL rules.
- `gate-allow.txt`: allow list consumed by `gate-compare.py`.
- `exit-rule.sh`: shared exit-rule helper used by gate stages.
- `compare-tests.py`: compares goport test results against a base.
  See its docstring for exit codes and formats.

## Build / emit compare

- `compare-build.sh`: compares build outputs between bins.
- `compare-emit.sh`: compares emit outputs between bins.
- `bin-identity.sh <out> <bins-a> <bins-b>`: byte-for-byte output of two
  bin dirs (`tsgo -p` with emit and `goport -p`) on the sample projects.
- `treehash.py`: directory tree hash helper for compare stages.
- `lib-blobs.sh`: shared blob helpers for the compare stages.
- `layout-name-map.py`: maps old suite/name pairs to new ones when the
  upstream renames tests. Lines are old suite, old name, new suite, new name.

## Oracles

- `api_oracle.py`: API oracle runner against Go.
- `lsp_oracle.py`: LSP oracle runner against Go.
- `oracle-rebase.py`, `oracle-rebase.sh`: rebase oracle baselines at a new pin.
  See each script header for exact usage.
- `go_baselines/`: checked-in Go baseline helpers for the oracles.
- `masked-answers.py`: masks known-volatile answer fields before compare.
- `gosigs.py`: Go signature helper for oracle setup.
- `genflags.py`: flag generation helper for oracle/test runs.
- `gen/`: generator inputs for the above helpers.

## LSP / editor bench

- `ls_edit_bench.py --rust BIN`: editor sessions (typing, error then fix,
  request mix, imports, long session) against Go. Reports RSS, edit latency
  and answers; exit 1 when Rust is over the limits in its docstring.
- `lsp_battery_edits.py`: edit-script generator for the LSP battery.
- `lsp_battery_fixes.py`: fixup helper for the LSP battery edit scripts.

```
flock /tmp/goport-lsguard.lock scripts/goport/ls_edit_bench.py \
    --rust cand=/abs/path/to/candidate/tsgo --rust base=/abs/path/to/base/tsgo \
    --out <out-dir>/<label>
```

- Use absolute binary paths. Each server starts in its project directory.
- Other upstream pin: `GOPORT_PIN=<key> scripts/upstream/pin.py exec -- scripts/goport/ls_edit_bench.py ...`.
- One session again: `--projects hono --scenarios long`. New limits on an old
  run: `--recheck --out DIR`.

## Project measurement

- `measure.sh`, `measure-extra.sh`: project comparisons used by the gate.
- `sweep.sh`: sweep runner over the sample projects.
- `sweep-extra2.sh`: additional sweep pass. See script header for scope.
- `sweep-hono-runtime.sh`: Hono runtime sweep. See script header for scope.
- `errcopies.sh`: error-copy comparison runner.
- `np-suite.sh`: sample-project suite runner. See script header for exact set.
- `goport-tests.sh`: runs the goport test set.
- `t3code`: t3code corpus references used by sweep/compare stages.

## Perf / build timing

- `perf.sh <label> <bin>...`: median of 3 wall time and peak RSS on the
  sample projects, runs interleaved across the binaries. Refuses to start on
  a loaded host (`PERF_WAIT=1` waits for a quiet host).
- `buildbench.sh`: timed `ts_goport` builds under a lock.
- `measure-extra.sh`: extra measurement pass outside the default gate set.
- `perf-npm.sh`: npm-side perf helper.
- `run-when-quiet.sh`, `run-when-quiet-wait.sh`: run a command only when the
  host load is low. See each script header for thresholds and flags.

## Build / pack / reuse

- `xbuild.sh`: cross/extended build helper. See script header for targets.
- `npm-pack.sh`: packs the npm artifact from a local build.
- `npm-test.sh`: runs the npm test pass against a local pack.
- `pgo-train.sh`: PGO training run for release builds.
- `tmp-port.sh`: restores legacy `/tmp/port` helper files after a reboot or
  tmpfiles cleanup. Put new tools here, never in `/tmp`.
- `fp.py <checkout>`: source fingerprint of a checkout.
- `fpcommit.py <checkout> <commit>`: fingerprint of a checkout as of a commit.
- `oldsha.py`: old-SHA lookup helper. See script header for exact usage.
- `prune-worktrees.py`: lists stale worktrees and merged branches.
  `--apply` removes them.
- `purge-foreign-fingerprints.py`: removes fingerprint records that do not
  belong to this checkout.
- `wfstatus`: one-line workflow status helper. See script header for usage.

## Tests for these scripts

- `compare-tests.test.mjs`: tests for `compare-tests.py`.
- `layout-name-map.test.mjs`: tests for `layout-name-map.py`.
- `gate-allow.test.mjs`: tests for `gate-allow.txt` handling.
- `gate-compare.test.mjs`: tests for `gate-compare.py`.
- `exit-rule.test.mjs`: tests for `exit-rule.sh`.

## Environment

- `GOPORT_PIN`: upstream pin key consumed by `scripts/upstream/pin.py exec`.
- `TS_GO_REPO`: path to the Go (`typescript-go`) checkout used as oracle.
- `PERF_WAIT=1`: make `perf.sh` wait for a quiet host instead of exiting.

## Build toolchain

Rust 1.93 stable.

```
cargo fmt --check
cargo clippy --release --bins
cargo build --release --bins
```

- The gate editor stage needs `tsgo` in `--bins`: build all bins with
  `--release --bins`.
- For timing, build every side with the same toolchain.
