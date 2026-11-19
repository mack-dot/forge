# common: run a TS file in target-v6 with the scrubbed env
T=/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/target-v6
E=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c11-host
CORE=/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs
NODE=/opt/homebrew/bin/node
tsrun() { (cd $T && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=/Users/mackianni/forge/node_modules timeout 120 $NODE --import tsx "$@"); }
