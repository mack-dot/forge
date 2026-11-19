#!/bin/bash
# Generates the table/binding mutants and the byte controls of b-export-bridge. Logs: logs/gen-<name>.txt
cd /Users/mackianni/forge/results/night-shift-20261119/orch-B/b-export-bridge || exit 9
X=/Users/mackianni/forge/results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/output.sexp
gen() { n=$1; shift; python3 -I gen_exported.py "$@" --slice inputs/SliceTheorem.dfy --linked inputs/LinkedRefund.dfy --out-contract mutants/$n.dfy > logs/gen-$n.txt 2>&1; echo "exit $?" >> logs/gen-$n.txt; echo "$n $(tail -2 logs/gen-$n.txt | tr '\n' ' ')"; }
python3 -I make_controls.py $X mutants
gen M00-none $X
gen M01-Le-to-Lt $X --mutate-op "Le=<"
gen M02-And-to-Or $X --mutate-op "And=||"
gen M03-Or-to-And $X --mutate-op "Or=&&"
gen M04-Imp-to-RevImp $X --mutate-op "Imp=<=="
gen M05-Neq-to-Eq $X --mutate-op "Neq=="
gen M06-Eq-to-Neq $X --mutate-op "Eq=!="
gen M07-Not-dropped $X --mutate-op "Not="
gen M08-IntL-plus1 $X --mutate-op "IntL=DEC+1"
gen M09-swap-in-charge-request $X --mutate-bind in-charge-request
gen M10-swap-out-charge-request $X --mutate-bind out-charge-request
gen M11-swap-original-remaining $X --mutate-bind in-original-remaining
gen M12-double-swap-charge-request $X --mutate-bind double-charge-request
gen RA-reject-all mutants/RA-reject-all.sexp --unpinned-control
gen D1-byte-flip mutants/D1-byte-flip.sexp
gen D1b-reject-all-pinned mutants/RA-reject-all.sexp
