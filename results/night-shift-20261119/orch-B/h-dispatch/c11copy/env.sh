# h-dispatch copy of orch-C/c11-host/env.sh: T = the export under test (DT=base|tree), CORE = the IssueOnce build.
H=<REPO>/results/night-shift-20261119/orch-B/h-dispatch
T=$H/${DT:?set DT=base or tree}
E=$H/c11copy
W0=$H/work/c11-$DT
CORE=<REPO>/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs
NODE=/opt/homebrew/bin/node
tsrun() { (cd $T && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C NODE_PATH=<REPO>/node_modules timeout 120 $NODE --import tsx "$@"); }
