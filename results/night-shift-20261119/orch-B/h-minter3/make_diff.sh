#!/bin/bash
# h-minter3: one diff against 74fb70eb for the owned/changed files; apply --check on a fresh export.
H=<REPO>/results/night-shift-20261119/orch-B/h-minter3; cd $H
F=(impl/finality-core/IssueAuth.dfy ts/refund-finality/minter.ts ts/refund-finality/launch/minter-launch.sh tests/refund-finality/suite.ts
 tests/refund-finality/regress/m2_closed_launch.ts tests/refund-finality/regress/m2_refused_pair_stays_closed.ts
 tests/refund-finality/regress/m2_squat_invented_prestate_does_not_block.ts tests/refund-finality/regress/m3_off_identical_retry.ts
 tests/refund-finality/regress/m3_one_effect_per_request_id.ts tests/refund-finality/regress/m3_refusal_does_not_close.ts
 tests/refund-finality/regress/m3_refusal_texts_generic.ts tests/refund-finality/regress/m3_store_replaced_by_mv.ts
 tests/refund-finality/regress/m3_zero_squat_limit.ts)
: > h-minter3.diff
for f in "${F[@]}"; do
  if [ -e pristine/$f ]; then git diff --no-index pristine/$f tree/$f; else git diff --no-index /dev/null tree/$f; fi |
    sed -e "s|a/pristine/|a/|g; s|b/tree/|b/|g; s|a/tree/|a/|g" >> h-minter3.diff
done
printf '%s\n' "${F[@]}" > h-minter3.files.txt
shasum -a 256 h-minter3.diff > h-minter3.diff.sha256
(cd tree && shasum -a 256 "${F[@]}") > files-sha256.txt
rm -rf check && mkdir check && git -C <REPO> archive 74fb70eb ts tests impl scripts spec interop package.json tsconfig.json | tar -x -C check
(cd check && git init -q . && git apply --check ../h-minter3.diff); echo "apply --check on a fresh export of 74fb70eb: exit $?"
rm -rf check
