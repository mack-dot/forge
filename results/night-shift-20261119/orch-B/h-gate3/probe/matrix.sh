#!/bin/bash
# Confinement matrix: probe.cjs under four configurations. Each run: fresh D, 5 s alarm, scrubbed env.
P=<REPO>/results/night-shift-20261119/orch-B/h-gate3/probe; N=/opt/homebrew/Cellar/node/24.3.0/bin/node; SB=<REPO>/results/night-shift-20261119/orch-B/h-gate3/probe/../child.sb
for cfg in plain permission sandbox both; do
  D=$(mktemp -d $P/../work/D-XXXX); D=$(cd $D && pwd -P); cp $P/probe.cjs $D/; rm -f $P/canary/*
  $N $P/listen.cjs 4000 $D.port > $D.listen & LP=$!; while [ ! -s $D.port ]; do perl -e 'select(undef,undef,undef,0.05)'; done; PORT=$(cat $D.port)
  case $cfg in
    plain) pre=""; flags="";;
    permission) pre=""; flags="--permission --allow-fs-read=$D";;
    sandbox) pre="/usr/bin/sandbox-exec -D D=$D -f $SB"; flags="";;
    both) pre="/usr/bin/sandbox-exec -D D=$D -f $SB"; flags="--permission --allow-fs-read=$D";;
  esac
  r=$(cd $D && env -i perl -e 'alarm 5; exec @ARGV' $pre $N --no-warnings $flags probe.cjs $P $PORT 2>&1 | tail -1)
  wait $LP
  echo "$cfg | $r | listener $(cat $D.listen) | canary_files $(ls $P/canary | wc -l | tr -d ' ') | D_files $(ls $D | tr '\n' ' ')"
  rm -rf $D $D.port $D.listen; rm -f $P/canary/*
done
