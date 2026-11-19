#!/bin/sh
# r-issueauth Q5: can a caller controlling ENV + CWD (not files) run planted code or start a FOREIGN-id minter through
# the closed launch? exit 1 = DEFEATED (planted code ran, or a minter started with a checker id != the honest one);
# exit 0 = claim HOLDS (no planted code; any minter that starts is the honest pinned one).
set -u
DIR=<REPO>/results/night-shift-20261119/orch-B/r-issueauth/closed; PIN=5b05e94b53189b592a6b49cd4a1380f80f8dac98eb97b64a9047ba95a5f40b42; LOCK=<REPO>/results/night-shift-20261119/orch-B/r-issueauth/x/spec/refund/spec.lock; BASE=42c9d159ffe142ee4c2b7c2c23187f76f3ae7e6944300c578568972656ac4aa6
LAUNCH=<REPO>/results/night-shift-20261119/orch-B/r-issueauth/x/ts/refund-finality/launch/minter-launch.sh
W=<REPO>/results/night-shift-20261119/orch-B/r-issueauth/probes/_q5work; rm -rf "$W"; mkdir -p "$W"; PLANT="$W/plant"
echo 'require("fs").writeFileSync(process.env.PLANT_PATH,"x")' > "$W/evil.js"
mkdir -p "$W/badbin"; printf '#!/bin/sh\ntouch "%s"\necho 0000000000000000000000000000000000000000000000000000000000000000  fake\n' "$PLANT" > "$W/badbin/shasum"; chmod +x "$W/badbin/shasum"
fail=0
run() { name="$1"; shift; rm -f "$PLANT"; out=$("$@" </dev/null 2>/dev/null); rc=$?
  cid=$(printf '%s' "$out" | sed -n 's/.*"checkerSha256":"\([0-9a-f]*\)".*/\1/p')
  plant=no; [ -f "$PLANT" ] && plant=YES
  verd=OK
  if [ "$plant" = YES ]; then verd="DEFEAT(planted code ran)"; fail=1;
  elif [ -n "$cid" ] && [ "$cid" != "$BASE" ]; then verd="DEFEAT(foreign checker id $cid)"; fail=1;
  elif [ -n "$cid" ]; then verd="honest-ready (env stripped; safe)"; else verd="refused rc=$rc (safe)"; fi
  printf '%-40s %s\n' "$name" "$verd"; rm -f "$PLANT"; }
run "A1 launch+NODE_OPTIONS=--require" env -i PATH=/usr/bin:/bin NODE_OPTIONS="--require $W/evil.js" PLANT_PATH="$PLANT" sh "$LAUNCH" "$DIR" "$PIN" "$LOCK" on
run "A2 launch+NODE_OPTIONS=--import"  env -i PATH=/usr/bin:/bin NODE_OPTIONS="--import $W/evil.js" PLANT_PATH="$PLANT" sh "$LAUNCH" "$DIR" "$PIN" "$LOCK" on
run "A3 launch+DYLD_INSERT_LIBRARIES"  env -i PATH=/usr/bin:/bin DYLD_INSERT_LIBRARIES=/x.dylib sh "$LAUNCH" "$DIR" "$PIN" "$LOCK" on
run "A4 launch+NODE_PATH"              env -i PATH=/usr/bin:/bin NODE_PATH="$W" sh "$LAUNCH" "$DIR" "$PIN" "$LOCK" on
run "A5 launch+hostile PATH shasum"    env -i PATH="$W/badbin:/usr/bin:/bin" PLANT_PATH="$PLANT" sh "$LAUNCH" "$DIR" "$PIN" "$LOCK" on
run "A6 direct cjs+extra env var"      env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C TZ=UTC FORGE_MINTER_CLOSED="$PIN" EVIL=1 /opt/homebrew/bin/node --no-addons --disallow-code-generation-from-strings "$DIR/minter.cjs" "$DIR/core.cjs" "$LOCK" on
run "A7 direct cjs+wrong node options" env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C TZ=UTC FORGE_MINTER_CLOSED="$PIN" /opt/homebrew/bin/node "$DIR/minter.cjs" "$DIR/core.cjs" "$LOCK" on
run "A8 direct cjs+NODE_OPTIONS req"   env -i PATH=/usr/bin:/bin HOME=/var/empty LANG=C TZ=UTC NODE_OPTIONS="--require $W/evil.js" PLANT_PATH="$PLANT" FORGE_MINTER_CLOSED="$PIN" /opt/homebrew/bin/node --no-addons --disallow-code-generation-from-strings "$DIR/minter.cjs" "$DIR/core.cjs" "$LOCK" on
run "A9 launch with CWD = attacker dir" env -i PATH=/usr/bin:/bin PWD="$W" sh -c "cd '$W'; exec sh '$LAUNCH' '$DIR' '$PIN' '$LOCK' on"
rm -rf "$W"
echo "RESULT: $( [ $fail -eq 0 ] && echo 'no planted code; only the honest pinned minter starts (claim HOLDS)' || echo 'DEFEATED')"
exit $fail
