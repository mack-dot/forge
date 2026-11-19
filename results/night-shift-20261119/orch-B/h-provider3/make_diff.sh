#!/bin/bash
# Builds h-provider3.diff (owned paths only) between the pristine export (5d99be9d) and tree/.
D=<REPO>/results/night-shift-20261119/orch-B/h-provider3; cd $D
out=$D/h-provider3.diff; : > $out
for f in $(cd tree && ls tests/refund-finality/provider/* tests/refund-finality/regress/p_*.ts tests/refund-finality/regress/p3_*.ts); do
  a=pristine/$f; [ -e $a ] || a=/dev/null
  git diff --no-index --no-color "$a" "tree/$f" | sed -e "s#a/pristine/#a/#g; s#b/tree/#b/#g; s#a/tree/#a/#g" >> $out
done
shasum -a 256 h-provider3.diff | tee h-provider3.diff.sha256
