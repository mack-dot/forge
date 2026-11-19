#!/bin/bash
# Usage: mkbuild.sh js/NAME.js -> build/NAME.build.js (pinned runtime prefix + user modules, as the gate build)
# and build/NAME.cjs (+ the gate footer). Same assembly as js_bound_check.cjs loadCheck.
E=<REPO>/results/night-shift-20261119/orch-C/c23-jsgate; H=<REPO>/results/night-shift-20261119/orch-B/h-gate
N=$(basename $1 .js); mkdir -p $E/build
{ cat $H/runtime-prefix.js; sed '1{/^\/\/ Dafny program Refund.dfy compiled into JavaScript/d;}' $1; } > $E/build/$N.build.js
{ cat $E/build/$N.build.js; printf '\nmodule.exports = { Refund, runtime: _dafny };\n'; } > $E/build/$N.cjs
echo $E/build/$N.cjs
