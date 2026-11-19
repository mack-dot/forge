# common: run a TS file in target-v6 with the scrubbed env
T=<SCRATCH>/redteam-C/target-v6
E=<REPO>/results/night-shift-20261119/orch-C/c11-host
CORE=<REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs
NODE=/opt/homebrew/bin/node
tsrun() { (cd $T && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=<REPO>/node_modules timeout 120 $NODE --import tsx "$@"); }
