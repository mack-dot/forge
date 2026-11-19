#!/bin/bash
# Sequential Dafny jobs (each through dafny_locked.sh): translations, then gate-option verifications.
cd <REPO>/results/night-shift-20261119/orch-B/r-jsbound
for f in C1-input-concat-spread C2-literal-32000-spread T1b-uncharged-literal-16000-loop; do ./tr.sh src/$f.dfy 1; done
for f in src/fr/*.dfy; do ./tr.sh $f 1; done
for f in B1-param-shadows-BigNumber C1-input-concat-spread C2-literal-32000-spread T1b-uncharged-literal-16000-loop T2-set-equality-charged-linear M1-live-strings-in-recursion; do ./vf.sh src/$f.dfy 1; done
for f in src/fr/*.dfy; do ./vf.sh $f 1; done
echo BATCH1 DONE
