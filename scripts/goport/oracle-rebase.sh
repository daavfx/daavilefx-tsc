#!/usr/bin/env bash
# Oracle rebase runs of a pin bump. Bins built at the old pin run the LSP oracle and the API oracle
# against the goldens of the new pin, two runs of each. Then oracle-rebase.py writes the
# batch.oracleRebase fragment and the class tables.
#
# usage: scripts/goport/oracle-rebase.sh <pin> <name> <bins dir> <out dir> [--no-wire] [--known-diffs TSV]
#   <pin>       the new pin (UPSTREAM.json of this checkout names its oracle and pin root)
#   <name>      the runs are lsp-<name>-1, api-<name>-1, lsp-<name>-2 and api-<name>-2, in that order; the labels
#               must be free in ls-oracle/battery/results and tests2/api/results
#   <bins dir>  bins (tsgo, COMMIT, bins.sha256), for example the bins of a saved evidence cache
#   <out dir>   logs/, api-root/ (the API out-root: traces -> the pin's API traces, golden and results ->
#               tests2/api), oracle-rebase.json (the fragment) and classes-lsp.md and classes-api.md
#   --no-wire   the bins speak the pin's API protocol: no --wire, and the fragment has no wire
#   --known-diffs TSV  <key> TAB <reason> lines for batch.oracleRebase.api.knownDiffs
# The tools are lsp_oracle.py and api_oracle.py of this checkout. The batteries are the ones with a
# selfchecked golden set at the pin (ls-oracle/battery and tests2/api, as rerecord.sh picks them), so a
# new battery or a new golden set joins the run with no edit here. The runs take about 15 minutes.
# The output ends with DONE or FAIL rc=<N>.
set -uo pipefail
ROOT=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd)
R=$ROOT/target/continuation-r97-goport
SELF=$(realpath "${BASH_SOURCE[0]}")
G=$(dirname "$SELF")
die() { echo "oracle-rebase.sh: $*" >&2; echo "FAIL rc=2"; exit 2; }

(($# >= 4)) || die "usage: oracle-rebase.sh <pin> <name> <bins dir> <out dir> [--no-wire] [--known-diffs TSV]"
PIN=$1 NAME=$2 BINS=$(realpath -m "$3") OUT=$(realpath -m "$4")
shift 4
WIRE=3 KNOWN=
while (($#)); do
  case $1 in
    --no-wire) WIRE= ;;
    --known-diffs) KNOWN=$(realpath "$2") && shift ;;
    *) die "unknown option $1" ;;
  esac
  shift
done
# The battery lists (inlined; LSP/API lists are re-derived from the golden dirs below).
# LSP_BATTERIES and API_BATTERIES are re-derived from the golden dirs below;
# the EXT/NO_EXT lists pin the oracle SHAs that lack an extended-protocol build.
LSP_BATTERIES=b1-inline,b1-query-core,b2-query-core,b1-hono,b2-hono,fourslash
API_BATTERIES=(effect hono hono-xchecker qc qc-callbacks qc-lsp qc-proto qc-xchecker tsp-lsp zod)
API_EXT_BATTERIES=(hono-ext qc-ext zod-ext)
API_NO_EXT_ORACLES=(d2dc9ff46ff5 204f15c76702)
pin() { python3 "$G/../upstream/pin.py" "$@"; }
ORACLE=$(pin path oracle "$PIN") || die "pin $PIN is not in $(dirname "$G")/../UPSTREAM.json"
OSHA=$(pin show "$PIN" | jq -r .oracle.sha256)
O12=${OSHA:0:12}
# The batteries with a selfchecked golden set at this pin, as rerecord.sh picks them.
batteries_of() { local d; for d in "$1/golden/$O12"/*/; do [[ -f $d/selfcheck-summary.json ]] && basename "$d"; done; }
LSP_BATTERIES=$(batteries_of "$R/ls-oracle/battery" | paste -sd,)
API_BATTERIES=$(batteries_of "$R/tests2/api" | paste -sd,)
NTRACES=$(pin path root "$PIN")/target/continuation-r97-goport/tests2/api/traces
APIROOT=$OUT/api-root
API=(${API_BATTERIES//,/ })
LABELS=("lsp-$NAME-1" "api-$NAME-1" "lsp-$NAME-2" "api-$NAME-2")
dir_of() { [[ $1 == lsp-* ]] && echo "$R/ls-oracle/battery/results/$1" || echo "$R/tests2/api/results/$1"; }

# Inputs: the oracle and its goldens, the pin's API traces, the bins, free labels.
[[ $(sha256sum "$ORACLE" | cut -d' ' -f1) == "$OSHA" ]] || die "$ORACLE does not have the pin's sha256 $OSHA"
for d in "$R/ls-oracle/battery/golden/$O12" "$R/tests2/api/golden/$O12" "$NTRACES"; do [[ -d $d ]] || die "missing $d"; done
[[ -x $BINS/tsgo && -f $BINS/COMMIT && -f $BINS/bins.sha256 ]] || die "$BINS needs tsgo, COMMIT and bins.sha256"
(cd "$BINS" && sha256sum -c --quiet bins.sha256) || die "$BINS does not match its bins.sha256"
for l in "${LABELS[@]}"; do [[ ! -e $(dir_of "$l") ]] || die "$(dir_of "$l") exists: pick another name"; done

if [[ -z ${REMOTE_HOST:-} ]]; then
  mkdir -p "$OUT/logs" || die "cannot make $OUT/logs"
  opts=()
  [[ -n $WIRE ]] || opts+=(--no-wire)
  [[ -z $KNOWN ]] || opts+=(--known-diffs "$KNOWN")
  exec "$RS" job auto bash "$SELF" "$PIN" "$NAME" "$BINS" "$OUT" "${opts[@]}"
fi

H=$REMOTE_HOST
cd "$ROOT" || die "no $ROOT"
unset GOPORT_PIN GOPORT_PIN_ACTIVE
mkdir -p "$APIROOT"
ln -sfn "$R/tests2/api/golden" "$APIROOT/golden"
ln -sfn "$R/tests2/api/results" "$APIROOT/results"
ln -sfn "$(realpath "$NTRACES")" "$APIROOT/traces"
echo "$(date -u +%FT%TZ) host $H pin $PIN oracle ${OSHA:0:12} bins $(cut -c1-9 "$BINS/COMMIT") tsgo $(sha256sum "$BINS/tsgo" | cut -c1-12)" \
  "lsp tool $(sha256sum "$G/lsp_oracle.py" | cut -c1-12) api tool $(sha256sum "$G/api_oracle.py" | cut -c1-12) wire ${WIRE:-none}"
{ "$RS" sync-scripts "$H" &&
  "$RS" push "$H" "$ORACLE" "$G/lsp_oracle.py" "$G/api_oracle.py" "$R/ls-oracle/battery/golden/$O12" "$R/tests2/api/golden/$O12" \
    "$(realpath "$NTRACES")" "$APIROOT" &&
  "$RS" sync-bins "$H" "$BINS" &&
  "$RS" run "$H" "cd $BINS && sha256sum -c --quiet bins.sha256 && mkdir -p $R/tests2/api/results && echo bins ok"; } \
  >> "$OUT/logs/sync-$H.log" 2>&1 || { echo "sync to $H failed (log $OUT/logs/sync-$H.log)"; echo "FAIL rc=3"; exit 3; }
rc=0
for label in "${LABELS[@]}"; do
  log=$OUT/logs/$label.log
  echo "$(date -u +%FT%TZ) start $label"
  if [[ $label == lsp-* ]]; then
    l="python3 $G/lsp_oracle.py check --out-root $R/ls-oracle/battery --battery $LSP_BATTERIES --goport $BINS/tsgo"
    l+=" --oracle $ORACLE --label $label --jobs 12"
  else
    l="export GOPORT_PIN_ACTIVE=$PIN; set -e; for b in ${API[*]}; do python3 $G/api_oracle.py check --out-root $APIROOT"
    l+=" --battery \$b --goport $BINS/tsgo --oracle $ORACLE --label $label --jobs 12 ${WIRE:+--wire $WIRE}; done"
  fi
  r=0
  "$RS" run "$H" "$l" < /dev/null >> "$log" 2>&1 || r=$?
  "$RS" fetch "$H" "$(dir_of "$label")" >> "$log" 2>&1 || r=$((r ? r : 4))
  echo "$(date -u +%FT%TZ) end $label rc $r"
  ((r == 0)) || rc=$r
done
((rc == 0)) || { echo "FAIL rc=$rc"; exit "$rc"; }
python3 "$G/oracle-rebase.py" fragment --pin "$PIN" --bins "$BINS" --lsp-tool "$G/lsp_oracle.py" --api-tool "$G/api_oracle.py" \
  ${WIRE:+--wire "$WIRE"} --host "$H" --lsp "$(dir_of "${LABELS[0]}")" "$(dir_of "${LABELS[2]}")" \
  --api "$(dir_of "${LABELS[1]}")" "$(dir_of "${LABELS[3]}")" ${KNOWN:+--known-diffs "$KNOWN"} --out "$OUT/oracle-rebase.json" \
  > /dev/null || { echo "FAIL rc=5"; exit 5; }
for k in lsp api; do
  python3 "$G/oracle-rebase.py" classes "$(dir_of "$k-$NAME-1")" "$(dir_of "$k-$NAME-2")" --out "$OUT/classes-$k.md" > /dev/null ||
    { echo "FAIL rc=6"; exit 6; }
done
echo "$(date -u +%FT%TZ) fragment $OUT/oracle-rebase.json sha256 $(sha256sum "$OUT/oracle-rebase.json" | cut -c1-12)"
echo DONE
