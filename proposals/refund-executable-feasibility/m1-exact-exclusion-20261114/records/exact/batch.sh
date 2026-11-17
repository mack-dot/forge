#!/bin/zsh
cd ${0:A:h}
export FORGE_CPU_SECONDS=1500
./go-import.sh exact-import exact-import.sml > batch-import.out 2>&1
FA=("${(@f)$(cat filtered-args.txt | tr ' ' '\n')}")
./go.sh exact-repeat exact-0010.sml $FA > batch-exact-repeat.out 2>&1
./go.sh handler-repeat handler-0001.sml > batch-handler-repeat.out 2>&1
./go-chain.sh chain-repeat chain-0018.sml > batch-chain-repeat.out 2>&1
./go-final.sh final-repeat final-0002.sml > batch-final-repeat.out 2>&1
FORGE_DUMP_THEORY=forge_simReplay ./go-dumpA.sh dump-replay-a dump.sml > batch-dumpA.out 2>&1
FORGE_DUMP_THEORY=forge_simReplay ./go-dumpB.sh dump-replay-b dump.sml > batch-dumpB.out 2>&1
./go.sh filtered-repeat filtered-0001.sml > batch-filtered-repeat.out 2>&1
echo BATCH_DONE > batch.done
