set -u
step() { label=$1; shift; "$@" > "logs/$label.log" 2>&1; code=$?; echo "$label exit=$code | $(grep -E 'ACCEPTED|REJECTED|verified|OK$|Error|error' logs/$label.log | tail -1 | cut -c1-110)"; }
mkdir -p logs
step clone git clone -q https://github.com/mack-dot/forge.git
cd forge && mkdir -p ../logs && ln -s ../logs logs
step mkdir mkdir -p .toolchain/downloads
step download curl -fsSL -o .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip
step checksum sh -c 'echo "c90c75e7d5db9c6ccbb7127840dfe43f0ac938b039a7ebed146d8ead383a572f  .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip" | shasum -a 256 -c'
step unzip unzip -q .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip -d .toolchain/dafny-4.11.0
step venv python3.10 -m venv .toolchain/venv
step pip .toolchain/venv/bin/python -m pip install -q -r toolchain/requirements-stage2.txt
step accept .toolchain/venv/bin/python gate/gate.py --impl impl/Ledger.dfy --evidence build/quickstart/ledger.json
step reject .toolchain/venv/bin/python gate/gate.py --impl bugs/off_by_one.dfy --evidence build/quickstart/off-by-one.json
step status git status --porcelain
echo "untracked/modified after quickstart: $(git status --porcelain | wc -l | tr -d ' ')"
