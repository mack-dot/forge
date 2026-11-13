#!/bin/sh
# Clean-container replay of two ARM8 theorems from upstream sources.
# Runs inside a fresh container. Not a proof checker: HOL's kernel is.
set -u
OUT=/out
POLY_COMMIT=4557554077078decce4ce5f90da00a713cfc32e4
POLY_TREE=190217a8d58ef06a6ec327e35c8470313d51b7e5
HOL_COMMIT=9783a49979c94c401ff8c0e51b2eefae7ea95ae3
HOL_TREE=29cad92945bc239c6389d991c6ae6b3ead1f6da3
: > $OUT/steps.tsv
step() { # label, command...
  label=$1; shift
  start=$(date +%s)
  "$@" > $OUT/$label.log 2>&1
  code=$?
  printf '%s\t%s\t%s\n' "$label" "$code" "$(( $(date +%s) - start ))" >> $OUT/steps.tsv
  return $code
}
fetch() { # dir url commit tree
  git init -q $1 && cd $1 && git remote add origin $2 &&
  git fetch -q --depth 1 origin $3 && git checkout -q FETCH_HEAD &&
  test "$(git rev-parse HEAD)" = "$3" && test "$(git rev-parse 'HEAD^{tree}')" = "$4" &&
  test -z "$(git status --porcelain)"
}
step apt-update apt-get update || exit 10
step apt-install env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential git ca-certificates libgmp-dev || exit 11
dpkg-query -W > $OUT/packages.txt
uname -a > $OUT/uname.txt
(step fetch-polyml fetch /build/polyml https://github.com/polyml/polyml.git $POLY_COMMIT $POLY_TREE) || exit 12
(step fetch-hol fetch /build/HOL https://github.com/HOL-Theorem-Prover/HOL.git $HOL_COMMIT $HOL_TREE) || exit 13
cd /build/polyml
step poly-configure ./configure --prefix=/build/poly-install --enable-intinf-as-int --with-gmp || exit 14
step poly-make make -j4 || exit 15
step poly-compiler make compiler || exit 16
step poly-install make install || exit 17
export PATH=/build/poly-install/bin:$PATH
export LD_LIBRARY_PATH=/build/poly-install/lib
step poly-version poly --version || exit 18
cd /build/HOL
step hol-configure poly --script tools/smart-configure.sml || exit 19
step hol-build bin/build || exit 20
export HOLDIR=/build/HOL
cd /build/HOL/examples/l3-machine-code/arm8/step
step arm8-step-holmake /build/HOL/bin/Holmake || exit 21
sha256sum arm8-heap ../../l3-heap > $OUT/heaps.sha256
echo 'load "/build/HOL/examples/l3-machine-code/arm8/step/arm8_stepLib";' > /build/preload.sml
case_run() { # case source expected [theory-case theory]
  c=$1; src=$2; expected=$3
  mkdir -p $OUT/$c && cp /inputs/$src $OUT/$c/proof.sml
  extra=""
  if [ $# -gt 3 ]; then
    # HOL resolves <dir>/<name> to <dir>/.hol/objs/<name> (attempt-0001 passed the stored path: script error).
    extra="$OUT/$4/$5Theory.sig $OUT/$4/$5Theory.sml"
  fi
  FORGE_NATIVE_STEP_OUT=$OUT/$c /build/HOL/bin/hol run --holstate=arm8-heap /build/preload.sml $extra $OUT/$c/proof.sml \
    > $OUT/$c/stdout.log 2> $OUT/$c/stderr.log
  code=$?
  printf '%s\t%s\t%s\n' "$c" "$code" "$expected" >> $OUT/cases.tsv
}
: > $OUT/cases.tsv
case_run compose-0001 compose-0001.sml 0
case_run compose-import compose-import.sml 0 compose-0001 forge_refundNativeReadError
case_run wrong-status wrong-status.sml 1 compose-0001 forge_refundNativeReadError
case_run install-site-0001 install-site-0001.sml 0
case_run install-import install-import.sml 0 install-site-0001 forge_refundInstallSite
case_run wrong-target wrong-target.sml 1 install-site-0001 forge_refundInstallSite
find $OUT -type f \( -name '*Theory.dat' -o -name '*Theory.sig' -o -name '*Theory.sml' \) -exec sha256sum {} + > $OUT/exports.sha256
awk -F'\t' '$2 != $3 { bad = 1 } END { exit bad }' $OUT/cases.tsv || exit 30
grep -qx NATIVE_STEP_COMPLETE $OUT/compose-0001/stdout.log || exit 31
grep -qx NATIVE_IMPORT_COMPLETE $OUT/compose-import/stdout.log || exit 32
grep -qx NATIVE_STEP_COMPLETE $OUT/install-site-0001/stdout.log || exit 33
grep -qx NATIVE_IMPORT_COMPLETE $OUT/install-import/stdout.log || exit 34
grep -qx AFTER_POSITIVE_AUDIT $OUT/wrong-status/stdout.log || exit 35
grep -qx AFTER_POSITIVE_AUDIT $OUT/wrong-target/stdout.log || exit 36
if grep -qx UNEXPECTED_CONTROL_ACCEPTANCE $OUT/wrong-status/stdout.log $OUT/wrong-target/stdout.log; then exit 37; fi
exit 0
