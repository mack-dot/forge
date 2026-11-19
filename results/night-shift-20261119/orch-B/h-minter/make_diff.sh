#!/bin/bash
# h-minter: build h-minter.diff (owned paths only) between pristine/ (branch-head export) and tree/.
H=<REPO>/results/night-shift-20261119/orch-B/h-minter; cd $H || exit 1
FILES="ts/refund-finality/minter.ts impl/finality-core/IssueOnce.dfy $(cd tree && ls tests/refund-finality/regress/m_*.ts)"
: > h-minter.diff
for f in $FILES; do
  if [ -e pristine/$f ]; then
    git diff --no-index --src-prefix=a/ --dst-prefix=b/ pristine/$f tree/$f | sed -e "s#a/pristine/#a/#g" -e "s#b/tree/#b/#g" -e "s#a/tree/#a/#g" >> h-minter.diff
  else
    git diff --no-index --src-prefix=a/ --dst-prefix=b/ /dev/null tree/$f | sed -e "s#b/tree/#b/#g" -e "s#a/tree/#a/#g" >> h-minter.diff
  fi
done
echo "$FILES" | tr ' ' '\n' > h-minter.files.txt
(cd tree && shasum -a 256 $FILES) > new-files-sha256.txt
shasum -a 256 h-minter.diff > h-minter.diff.sha256
