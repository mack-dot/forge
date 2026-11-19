#!/bin/bash
# S10: the closed launch minter-launch.sh. Usage: s10_launch.sh <case>
# Cases: honest | honest_store | node_options | node_path | tmpdir | home | cwd_plant | path_cut | bash_env | relative_store
# Attacker: controls ONLY the environment and the working directory of the launch (not the built files).
# Exit 1 = foreign code ran INSIDE the minter (node) process, or an honest request is not signed while the launch
# started. Exit 0 = the minter started, answered the honest request, and no marker of foreign code in node exists.
# A marker written by the launch SHELL (path_cut) is reported, not counted (it is the caller's own code, own process).
unset GH_TOKEN GITHUB_TOKEN
E=<REPO>/results/night-shift-20261119/orch-C/c24-minter2
R=<SCRATCH>/redteam-C/fix-370ff65c
L=$R/ts/refund-finality/launch/minter-launch.sh; D=$E/closed; PIN=$(/usr/bin/shasum -a 256 $D/MANIFEST.sha256 | /usr/bin/cut -d' ' -f1)
C=$1; rm -f $E/markers/*; W=$E/work/s10-$C; rm -rf $W; mkdir -p $W
REQ='{"id":1,"pre":{"chargeId":"ch_L","original":"1000","refundEnabled":true,"remaining":"1000"},"transition":{"intent":{"amount":"0","chargeId":"ch_L","reason":"duplicate_charge","requestId":"rq_L"},"post":{"chargeId":"ch_L","original":"1000","refundEnabled":true,"remaining":"1000"},"request":{"amount":"0","reason":"duplicate_charge","requestId":"rq_L"}}}'
BASE="PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C"; EXTRA=""; CWD=$W; ARGS="$D $PIN $R/spec/refund/spec.lock on"
case $C in
  honest) ;;
  honest_store|relative_store)
    # a real hardened sink store for ch_L (needs the minter's key: start once to get it, not needed for the read: the
    # minter reads only the state row; the sink pins a key, so build the store with a throwaway sink key via tsx helper)
    (cd $R && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E NODE_PATH=<REPO>/node_modules node --import tsx $E/mkstore.ts $W/s.sqlite) || exit 3
    if [ $C = honest_store ]; then ARGS="$ARGS $W/s.sqlite"; else ARGS="$ARGS s.sqlite"; fi ;;
  node_options) EXTRA="NODE_OPTIONS=--require=$E/plant/marker.cjs" ;;
  node_path) EXTRA="NODE_PATH=$E/plant/node_modules" ;;
  tmpdir) EXTRA="TMPDIR=$E/plant/tmp" ;;
  home) BASE="PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E/plant/home LANG=C" ;;
  cwd_plant) CWD=$E/plant ;;
  path_cut) BASE="PATH=$E/plant/bin:/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C" ;;
  bash_env) printf 'echo bash_env ran > %s/markers/shell-bashenv-$$\n' $E > $W/benv.sh; EXTRA="BASH_ENV=$W/benv.sh ENV=$W/benv.sh" ;;
esac
cd $CWD
printf '%s\n' "$REQ" | env -i $BASE $EXTRA timeout 30 /bin/sh $L $ARGS > $W/out.txt 2> $W/err.txt
rc=$?
echo "case=$C launch_rc=$rc"; head -c 300 $W/err.txt | tr '\n' ' '; echo
ANS=$(sed -n 2p $W/out.txt | head -c 160); echo "answer: $ANS"
CL=$(grep -o '"closedLaunch":{[^}]*}' $W/err.txt); echo "closedLaunch: $CL"
echo "markers: $(ls $E/markers | tr '\n' ' ')"
NODE_MARK=$(ls $E/markers | grep -v '^shell-' | wc -l | tr -d ' ')
[ "$NODE_MARK" != "0" ] && { echo "DEFECT: foreign code ran inside the minter"; exit 1; }
case $C in relative_store) echo "$ANS" | grep -q '"ok":true' && { echo "SAFE"; exit 0; } || { echo "DEFECT: honest request refused (relative store path)"; exit 1; } ;; esac
echo "$ANS" | grep -q '"ok":true' && [ -n "$CL" ] || { echo "DEFECT or NOT STARTED: no signed answer / no closed launch"; exit 1; }
echo SAFE; exit 0
