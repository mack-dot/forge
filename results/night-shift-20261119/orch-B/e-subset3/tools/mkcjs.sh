#!/bin/bash
# Usage: mkcjs.sh NAME. js/NAME.cjs = runtime prefix (lines 1-1188 of r-subset2's `dafny build --target js` output:
# Dafny 4.11 runtime + _System) + js/NAME.js (`dafny translate js` output, no runtime) + an exports line.
J=/Users/mackianni/forge/results/night-shift-20261119/orch-B/e-subset3/js
cat $J/runtime-prefix.js $J/$1.js > $J/$1.cjs; printf '\nmodule.exports = { Refund, runtime: _dafny };\n' >> $J/$1.cjs
