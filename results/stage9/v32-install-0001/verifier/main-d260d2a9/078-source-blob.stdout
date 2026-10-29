#!/usr/bin/env python3
"""Record a real Stage 7 command. This script makes no proof verdict."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--cwd", default=".")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", args.name):
        parser.error("name must contain lowercase letters, digits, underscores or hyphens")
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("missing command")
    root = Path(__file__).resolve().parents[1]
    dest = root / "results/stage7/commands" / args.name
    dest.mkdir(parents=True, exist_ok=False)
    cwd = (root / args.cwd).resolve()
    invocation = {"command": command, "cwd": str(cwd.relative_to(root))}
    (dest / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    with (dest / "output.log").open("wb") as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    output = (dest / "output.log").read_bytes()
    record = {**invocation, "exit_code": result.returncode,
              "output_sha256": hashlib.sha256(output).hexdigest(),
              "proof_verdict": "not_assessed_by_recorder"}
    (dest / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record), flush=True)
    print(output[-4000:].decode("utf-8", errors="replace"), flush=True)
    return result.returncode if result.returncode >= 0 else 128 - result.returncode


if __name__ == "__main__":
    sys.exit(main())
