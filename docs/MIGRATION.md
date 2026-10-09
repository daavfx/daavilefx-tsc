# Migrating a typecheck gate from tsc 5.x to daavilefx-tsc

This is the companion to the README's Status section: the practical side of
moving a real project's `--noEmit` gate onto this compiler. Everything below
was learned migrating mid-size Vite + React + Tauri projects (tens to ~1,000
TS files) from `typescript ~5.8`.

## What changes, in one paragraph

daavilefx-tsc ports TypeScript **7.1.0-dev**. Two TypeScript-level behavior
changes (not port bugs) affect 5.x projects: `baseUrl` was removed from the
config surface, and `strict` defaults to true (since TS 6.0). Handle those two
and the gate behaves identically, roughly an order of magnitude faster
(measured 8–23x on the migration projects: single seconds where tsc takes
tens of seconds).

## Preconditions

- The project's gate is green under its current `tsc` (or its failures are
  triaged and understood — never migrate a red gate, you will not know what
  moved).
- You can run both compilers on the project: `tsc --noEmit -p tsconfig.json`
  and `tsgo --noEmit -p tsconfig.json`.

## Known migration issues

### 1. `baseUrl` is rejected (TS5102)

TypeScript 7 removed the `baseUrl` option. `tsgo` fails the whole run with
`error TS5102: Option 'baseUrl' has been removed` while tsc 5.x accepts it.

Fix: delete the `"baseUrl": "."` line wherever `paths` already covers
resolution. With `baseUrl: "."`, `paths` entries resolve relative to the
tsconfig directory — exactly what they do with no `baseUrl` at all — so on
tsc 5.x the removal is behavior-preserving. Verify by re-running the tsc
gate before and after: identical verdict expected. (If a project relies on
bare imports that only `baseUrl` resolves, add explicit `paths` entries
instead.)

Note `extends` inheritance: a child config without the key inherits the
parent's, so strip it from every config in the chain.

### 2. `strict` defaults to true

Since TypeScript 6.0, an absent `strict` flag means strict on
([#62333](https://github.com/microsoft/TypeScript/issues/62333), the 6.0
announcement, confirmed for 7.0). Projects written under the old default
will see strict-family diagnostics (implicit-`any` TS7006/TS7031,
parameter-variance TS2322, union narrowing TS2339) that their tsc never
reported.

Two honest options, in order of preference:

1. **Fix-forward.** The flagged issues are usually real latent bugs
   (re-indexed strings, un-narrowed unions, bivariant callbacks). Fix them
   and set `"strict": true` explicitly. Both compilers then agree by
   construction, and the project gets the stricter gate for free.
2. **Preserve behavior.** Set `"strict": false` explicitly. The gate output
   should then be identical to tsc 5.x (modulo the item below).

Never leave `strict` absent: an absent flag means different things to the
two compilers, and every future diff will be noise. Explicit is the whole
point.

### 3. Cosmetic: union member display order

`tsgo` may print union constituents in a different order than tsc
(`A | B` vs `B | A`). Same type, same error code and position — normalize
(or eyeball past it) when diffing.

### 4. The four upstream divergences

The README's Known problems (dual-reach `TS6059`, stale cross-project reads
in `tsc -b`, LSP memory growth, `--version`) apply here unchanged. The
dual-reach case deserves attention in multi-package trees where one
package's sources resolve through several host `node_modules`: compare the
`TS2307`/`TS6059` counts per directory, not just the totals.

## Validation method

1. Baseline: `tsc --noEmit -p <config>` → save output + exit code + wall time.
2. Candidate: `tsgo --noEmit -p <config>` → same.
3. Normalize paths (both compilers print `file(line,col):` — make them
   relative to the same root), then diff.
4. Classify the delta by zone: project-owned files vs vendored / generated /
   excluded trees. A gate that filters (debt zones, `exclude`) must be
   compared **after** filtering — raw line counts always differ because of
   issue 2.
5. Verdict classes:
   - **Identical** (same files, codes, positions): swappable.
   - **Strict-only extras, all outside owned files**: swappable; the extras
     are future work, not regressions.
   - **Anything else**: do not swap. Minimize first (a 10-line strict-only
     repro distinguishes a port bug from a project issue).

## The env-flag A/B pattern

Do not replace the gate binary in one jump. Branch inside the gate script:

```js
// DAAVILEFX_TSC=1 runs this identical gate through tsgo instead of tsc.
function resolveTsgo() {
  if (process.env.DAAVILEFX_BINS) return join(process.env.DAAVILEFX_BINS, 'tsgo.exe');
  const home = process.env.DAAVILEFX_HOME ?? '<daavilefx-tsc-checkout>';
  return join(home, 'target', 'release', 'tsgo.exe');
}

let proc;
if (process.env.DAAVILEFX_TSC === '1') {
  const tsgoBin = resolveTsgo();
  if (!existsSync(tsgoBin)) { /* error out, do not fall back silently */ }
  proc = spawnSync(tsgoBin, args, { encoding: 'utf8' });
} else {
  proc = spawnSync(process.execPath, [tscBin, ...args], { encoding: 'utf8' });
}
```

Requirements on the tsgo side: it accepts the same `-p/--noEmit/--pretty
false/--watch` flags, prints the same `file(line,col): error TSNNNN:`
lines, and uses the same exit-code contract (0 clean, 1 diagnostics,
2 crash/bad input) — all verified. The gate's own output parser needs no
changes. Never fall back silently: a missing binary must fail loudly, or a
"green" run means nothing.

## Flip checklist (per project)

- [ ] Gate green under tsc (or failures triaged).
- [ ] `baseUrl` stripped everywhere in the config chain; tsc gate re-verified.
- [ ] `strict` explicit (`true` after fix-forward, `false` to preserve).
- [ ] Dual-run done; verdict identical after zone filtering.
- [ ] Env-flag branch in the gate script; both modes proven from the
      project's own `npm run` entry.
- [ ] The gate change is committed (the script + configs, not the binaries).
- [ ] Rollback known: unset the variable (default path is untouched), or
      revert the gate commit — one line either way.

## Rollback

Unset `DAAVILEFX_TSC`. The default code path is byte-identical to before
the change, so rollback is instant and needs no rebuild. If the flip itself
was committed (default switched to tsgo), revert that one commit.
