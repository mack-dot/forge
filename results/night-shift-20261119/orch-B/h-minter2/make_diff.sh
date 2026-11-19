#!/bin/bash
# h-minter2: build h-minter2.diff (owned paths only) between pristine/ (export of f08a21c1) and tree/.
H=<REPO>/results/night-shift-20261119/orch-B/h-minter2; cd $H || exit 1
FILES="ts/refund-finality/minter.ts ts/refund-finality/launch/minter-build.sh ts/refund-finality/launch/minter-launch.sh impl/finality-core/IssueAuth.dfy $(cd tree && ls tests/refund-finality/regress/m2_*.ts)"
: > h-minter2.diff
for f in $FILES; do
  if [ -e pristine/$f ]; then
    git diff --no-index --src-prefix=a/ --dst-prefix=b/ pristine/$f tree/$f | sed -e "s#a/pristine/#a/#g" -e "s#b/tree/#b/#g" >> h-minter2.diff
  else
    git diff --no-index --src-prefix=a/ --dst-prefix=b/ /dev/null tree/$f | sed -e "s#b/tree/#b/#g" -e "s#a/tree/#a/#g" >> h-minter2.diff
  fi
done
echo "$FILES" | tr ' ' '\n' > h-minter2.files.txt
(cd tree && shasum -a 256 $FILES) > new-files-sha256.txt
shasum -a 256 h-minter2.diff > h-minter2.diff.sha256
