#!/bin/bash
# assemble.sh SET DIR... : each JS body -> mods/SET/NAME.cjs = pinned runtime prefix (h-gate/runtime-prefix.js, unless the
# file already holds the runtime) + body + the gate footer. Same assembly as h-gate and orch-C mkbuild.sh.
H=<REPO>/results/night-shift-20261119/orch-B/h-gate; O=<REPO>/results/night-shift-20261119/orch-B/h-gate3/mods
S=$1; shift; mkdir -p $O/$S
for d in "$@"; do for f in $d/*.js; do N=$(basename $f .js)
  if grep -q "let _dafny = " $f; then cat $f; else { cat $H/runtime-prefix.js; sed '1{/^\/\/ Dafny program Refund.dfy compiled into JavaScript/d;}' $f; }; fi > $O/$S/$N.cjs
  printf '\nmodule.exports = { Refund, runtime: _dafny };\n' >> $O/$S/$N.cjs
done; done; ls $O/$S | wc -l
