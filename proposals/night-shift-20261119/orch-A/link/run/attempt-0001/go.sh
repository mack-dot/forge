#!/bin/bash
# Run package for links S5/S6 (worker A4, 2026-11-19). NOT RUN. Every case starts HOL: one case per call.
#
# Usage:  bash /Users/mackianni/forge/results/night-shift-20261119/orch-A/link/run/attempt-0001/go.sh <CASE> [case-folder-name]
# CASE:   pre | H0 | H0p | R1 | R2 | R3 | I1 | H1 | H2 | NC1..NC6 | PC1 | NS1..NS3 | H4 | NR1 | E0 | E0r
# Order:  pre, H0 (H0p only if H0 fails on a load), R1, R2, R3, I1, H1, H2, then H3 = NC1..NC6 PC1 NS1..NS3,
#         H4, NR1, optional E0 E0r. Stop at the first verdict that is not PASS and report it.
#
# IMPORTANT (runner guard): run_case.py refuses (exit 3) when ANY process has 'cakeml-heap', 'arm8-heap' or
# 'cake_compile_heap' in its command line. Call this file as shown above. Do NOT write the heap path
# on the invoking command line (for example inside 'bash -c "..."' or 'zsh -c "..."'): that shell would match.
# The heap path is set inside this file only.
#
# Env options:  LOADPATH=1   give loadpath.sml as FIRST extra argument in R1, R2, R3, I1 (use only if H0 failed
#                            on 'load' and H0p passed; RUN_PLAN.md section 3, row H0)
#               U294_CWD=plan  run R1, R2, I1 in the runner default cwd (CertifiedProg) instead of the RECORDED
#                            U294 cwd forge_refund_call_experiment (default: recorded)
#               ALLOW_SWAP=1 start although swap use is above 85 % (RUN_PLAN.md section 0 says: wait)
set -u
RUN=/Users/mackianni/forge/results/night-shift-20261119/orch-A/link/run/attempt-0001
F=/Users/mackianni/forge
D=$F/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny
EXPORT=$RUN/inputs/FlatCore.sexp
EXPORT_SHA=58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d
export FORGE_HEAP=cakeml/misc/cakeml-heap
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
cd "$RUN" || exit 9

pre() {   # RUN_PLAN.md section 0. Writes pre-<case>.txt. Returns 5 if swap > 85 % and ALLOW_SWAP is not 1.
  local f=$RUN/pre-$1.txt
  { date; memory_pressure | tail -1; sysctl vm.swapusage; df -g /System/Volumes/Data | tail -1
    echo "other HOL children:"; pgrep -fl 'cakeml-heap|arm8-heap|cake_compile_heap' | cut -c1-160; echo "pgrep exit $?"; } > "$f" 2>&1
  cat "$f"
  local pct
  pct=$(sysctl -n vm.swapusage | awk '{t=$3; u=$6; sub("M","",t); sub("M","",u); if (t+0>0) printf "%d", 100*u/t; else print 0}')
  echo "swap used percent: $pct" | tee -a "$f"
  if [ "$pct" -gt 85 ] && [ "${ALLOW_SWAP:-0}" != 1 ]; then echo "STOP: swap above 85 % (RUN_PLAN.md section 0)"; return 5; fi
  return 0
}

insha() {   # <file> <expected sha256>: refuse to start when the input bytes differ (the runner does not hash them).
  local got; got=$(shasum -a 256 "$1" | cut -d' ' -f1)
  echo "input $1 sha256 $got expected $2"
  [ "$got" = "$2" ] || { echo "STOP: input digest differs"; return 6; }
}

ctlsha() {  # expected SHA-256 of a control file, from controls/CONTROLS.json
  python3 -I -c "import json,sys;print([r['sha256'] for r in json.load(open('$RUN/controls/CONTROLS.json')) if r['control']==sys.argv[1]][0])" "$1"
}

run() {     # <CASE-ID> <case-folder> <source> [extra ...]; env vars are set by the caller
  local cid=$1 case=$2; shift 2
  pre "$case" || return $?
  echo "COMMAND: FORGE_CWD=${FORGE_CWD:-<default>} FORGE_CPU_SECONDS=$FORGE_CPU_SECONDS python3 -I -B run_case.py $case $*"
  python3 -I -B run_case.py "$case" "$@" > "$RUN/$case.run.json"
  local rc=$?
  echo "RUNNER EXIT $rc (a signal or CPU-limit stop also gives 1; read actual_exit in $case/command.json)"
  echo "$rc" > "$RUN/$case.runner-exit.txt"
  [ -f "$RUN/$case/command.json" ] || { cat "$RUN/$case.run.json"; return $rc; }
  grep -n "^FORGE_BEGIN\|^FORGE_THEOREM\|^CHECKED\|^IMPORTED\|COMPLETE$\|Exception\|rror" "$RUN/$case/stdout.log" | cut -c1-200 | tail -40
  tail -c 800 "$RUN/$case/stderr.log"
  python3 -I -B "$RUN/check.py" "$cid" "$case" | tee "$RUN/$case.verdict.txt"
  return $rc
}

lp() { [ "${LOADPATH:-0}" = 1 ] && echo "$RUN/loadpath.sml"; }
u294cwd() { [ "${U294_CWD:-recorded}" = plan ] && echo "" || echo "$D/forge_refund_call_experiment"; }
SB=forge_refundSourceBindingTheory

case_H0()  { FORGE_CPU_SECONDS=300 run H0 "${1:-probe-0001}" probe.sml; }
case_H0p() { FORGE_CPU_SECONDS=300 run H0p "${1:-probe-0002}" probe.sml "$RUN/loadpath.sml"; }
case_R1()  { insha "$EXPORT" $EXPORT_SHA || return $?
  local c=${1:-u294-hol}; local cw; cw=$(u294cwd)
  FORGE_CWD=${cw:-$D/forge_refundCertifiedProg_experiment} FORGE_SOURCE_SEXP=$EXPORT FORGE_SOURCE_PROOF_OUT=$RUN/$c \
  FORGE_CPU_SECONDS=900 run R1 "$c" u294/proof-0004.sml $(lp); }
case_R2()  { insha "$EXPORT" $EXPORT_SHA || return $?
  local c=${1:-u294-rel}; local cw; cw=$(u294cwd)
  FORGE_CWD=${cw:-$D/forge_refundCertifiedProg_experiment} FORGE_SOURCE_SEXP=$EXPORT FORGE_SOURCE_PROOF_OUT=$RUN/$c \
  FORGE_CPU_SECONDS=300 run R2 "$c" u294/relation.sml $(lp) "$RUN/u294/preload.sml" \
    "$RUN/u294-hol/$SB.sig" "$RUN/u294-hol/$SB.sml"; }
case_R3()  { insha "$EXPORT" $EXPORT_SHA || return $?
  local c=${1:-u294-bridge}
  FORGE_CWD=$D/forge_refundCertifiedProg_experiment FORGE_SOURCE_SEXP=$EXPORT FORGE_SOURCE_PROOF_OUT=$RUN/$c \
  FORGE_CPU_SECONDS=300 run R3 "$c" u294/bridge.sml $(lp) "$RUN/u294/preload.sml" \
    "$RUN/u294-hol/$SB.sig" "$RUN/u294-hol/$SB.sml"; }
case_I1()  { insha "$EXPORT" $EXPORT_SHA || return $?
  local c=${1:-u294-import}; local cw; cw=$(u294cwd)
  FORGE_CWD=${cw:-$D/forge_refundCertifiedProg_experiment} FORGE_SOURCE_SEXP=$EXPORT FORGE_SOURCE_PROOF_OUT=$RUN/$c \
  FORGE_CPU_SECONDS=300 run I1 "$c" u294/audit.sml $(lp) "$RUN/u294/preload.sml" \
    "$RUN/stored/hol-0004/$SB.sig" "$RUN/stored/hol-0004/$SB.sml"; }
case_H1()  { insha "$EXPORT" $EXPORT_SHA || return $?
  FORGE_CONTRACT_SEXP=$EXPORT FORGE_CPU_SECONDS=1200 run H1 "${1:-contract-0001}" forge_refundExportedContractScript.sml; }
case_H2()  { insha "$EXPORT" $EXPORT_SHA || return $?
  FORGE_CONTRACT_SEXP=$EXPORT FORGE_CPU_SECONDS=1200 run H2 "${1:-contract-repeat}" forge_refundExportedContractScript.sml; }
ctl_export() {  # <ID> <file>  export control: the main script with a mutated export
  insha "$RUN/controls/$2" "$(ctlsha "$2")" || return $?
  FORGE_CONTRACT_SEXP=$RUN/controls/$2 FORGE_CPU_SECONDS=900 run "$1" "${3:-ctl-$1}" forge_refundExportedContractScript.sml; }
ctl_script() {  # <ID> <file>  statement control: a mutated script with the real export
  insha "$EXPORT" $EXPORT_SHA || return $?
  insha "$RUN/controls/$2" "$(ctlsha "$2")" || return $?
  FORGE_CONTRACT_SEXP=$EXPORT FORGE_CPU_SECONDS=900 run "$1" "${3:-ctl-$1}" "controls/$2"; }
case_NC1() { ctl_export NC1 NC1-amount-lt-in-contract.sexp "$@"; }
case_NC2() { ctl_export NC2 NC2-ids-swapped-in-contract.sexp "$@"; }
case_NC3() { ctl_export NC3 NC3-count-one-when-rejected.sexp "$@"; }
case_NC4() { ctl_export NC4 NC4-third-clause-dropped.sexp "$@"; }
case_NC5() { ctl_export NC5 NC5-reason-literal-in-contract.sexp "$@"; }
case_NC6() { ctl_export NC6 NC6-trailing-bytes.sexp "$@"; }
case_PC1() { ctl_export PC1 PC1-body-only-mutation.sexp "$@"; }
case_NS1() { ctl_script NS1 NS1-amount-plus-one.sml "$@"; }
case_NS2() { ctl_script NS2 NS2-ids-swapped.sml "$@"; }
case_NS3() { ctl_script NS3 NS3-wrong-truth-value.sml "$@"; }
CT=$RUN/contract-0001/.hol/objs/forge_refundExportedContractTheory
CTA=$RUN/contract-0001/forge_refundExportedContractTheory   # Orchestrator A: HOL adds .hol/objs itself (path fix after H4, R2, R3, I1 setup errors)
case_H4()  { [ -f "$CT.sig" ] && [ -f "$CT.sml" ] && [ -f "$CT.dat" ] || { echo "STOP: run H1 first"; return 7; }
  FORGE_CWD=$D/forge_refundWireProg_experiment FORGE_CPU_SECONDS=900 run H4 "${1:-render-0001}" \
    forge_refundExportedRenderScript.sml "$RUN/preload-render.sml" "$CTA.sig" "$CTA.sml"; }
case_NR1() { [ -f "$CT.sig" ] || { echo "STOP: run H1 first"; return 7; }
  insha "$RUN/controls/NR1-render-ids-swapped.sml" "$(ctlsha NR1-render-ids-swapped.sml)" || return $?
  FORGE_CWD=$D/forge_refundWireProg_experiment FORGE_CPU_SECONDS=900 run NR1 "${1:-ctl-NR1}" \
    controls/NR1-render-ids-swapped.sml "$RUN/preload-render.sml" "$CTA.sig" "$CTA.sml"; }
# E0 (optional): W2's drafts/link-eligible H1/H2 with loadpath.sml as first extra argument (pre-flight P6),
# in W2's cwd forge_refund_call_experiment. Its marker ELIGIBLE_LINK_COMPLETE is not in the runner MARKERS
# (RUN_PLAN.md section 2 lists six markers only); check.py reads it from stdout.log.
case_E0()  { insha "$EXPORT" $EXPORT_SHA || return $?
  FORGE_CWD=$D/forge_refund_call_experiment FORGE_ELIGIBLE_SEXP=$EXPORT FORGE_CPU_SECONDS=900 \
    run E0 "${1:-eligible-link-0001}" eligible/forge_refundEligibleLinkScript.sml "$RUN/loadpath.sml"; }
case_E0r() { insha "$EXPORT" $EXPORT_SHA || return $?
  FORGE_CWD=$D/forge_refund_call_experiment FORGE_ELIGIBLE_SEXP=$EXPORT FORGE_CPU_SECONDS=900 \
    run E0r "${1:-eligible-link-repeat}" eligible/forge_refundEligibleLinkScript.sml "$RUN/loadpath.sml"; }

[ $# -ge 1 ] || { sed -n 2,20p "$0"; exit 2; }
c=$1; shift
if [ "$c" = pre ]; then pre manual; exit $?; fi
declare -F "case_$c" > /dev/null || { echo "unknown case $c"; exit 2; }
"case_$c" "$@"
rc=$?
echo "GO.SH EXIT $rc"
exit $rc
