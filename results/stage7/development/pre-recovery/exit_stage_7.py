#!/usr/bin/env python3
"""Run Stage 7 acceptance scenarios through the published upstream checker.

This runner checks input identity and expected command outcomes. It defines no
machine semantics and does not decide whether a theorem is true.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / ".toolchain/stage7/upstream"
PINS = json.loads((ROOT / "toolchain/stage7-pins.json").read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def run_command(command, cwd, output):
    with output.open("wb") as stream:
        result = subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    return {"command": command, "cwd": str(cwd.relative_to(ROOT)),
            "exit_code": result.returncode, "output_sha256": digest(output)}


def inputs():
    selected = set()
    for directory in ("tools/oft", "toolchain", "theories",
                      "projects/zlib/checksum_fuzzer", "proofs/zlib/checksum_fuzzer"):
        selected.update(p for p in (UPSTREAM / directory).rglob("*")
                        if p.is_file() and "__pycache__" not in p.parts)
    for name in ("release.yaml", "dune-project", "oft", "approvals.yaml",
                 "projects/zlib/project.yaml"):
        selected.add(UPSTREAM / name)
    binaries = UPSTREAM / "projects/zlib/bin/checksum_fuzzer"
    selected.update(p for p in binaries.iterdir() if p.is_file())
    return {str(p.relative_to(UPSTREAM)): digest(p) for p in sorted(selected)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=["upstream-replay"], required=True)
    args = parser.parse_args()
    parent = ROOT / "results/stage7" / args.case
    parent.mkdir(parents=True, exist_ok=True)
    number = 1
    while (parent / f"attempt-{number:04d}").exists():
        number += 1
    if number > 5:
        parser.error("five attempts already recorded; inspect the blocker")
    dest = parent / f"attempt-{number:04d}"
    dest.mkdir()
    (dest / "tmp").mkdir()
    report = {"case": args.case, "method": "binary_proof", "result": "not_established",
              "end_to_end": False, "commands": [], "pins": PINS}

    def execute(command, cwd, name):
        record = run_command(command, cwd, dest / (name + ".log"))
        report["commands"].append(record)
        write_json(dest / "report.json", report)
        return record["exit_code"]

    if execute(["git", "rev-parse", "HEAD"], UPSTREAM, "revision") != 0:
        return 1
    if (dest / "revision.log").read_text().strip() != PINS["upstream_commit"]:
        print("UPSTREAM_REVISION_MISMATCH", flush=True)
        return 1
    if execute(["git", "diff", "--exit-code", "HEAD", "--"], UPSTREAM, "tracked-before") != 0:
        print("UPSTREAM_TRACKED_INPUT_CHANGED", flush=True)
        return 1
    before = inputs()
    binary = "projects/zlib/bin/checksum_fuzzer/checksum_fuzzer.plain"
    if before[binary] != PINS["upstream_binary_sha256"]:
        print("BINARY_DIGEST_MISMATCH", flush=True)
        return 1
    write_json(dest / "inputs-before.json", before)
    command = [
        "docker", "run", "--rm", "--pull", "never",
        "--name", f"forge-stage7-replay-{number:04d}",
        "--platform", PINS["platform"], "--network", "none",
        "--cpuset-cpus", PINS["cpuset"], "--memory", PINS["memory"],
        "--memory-swap", PINS["memory_swap"], "--pids-limit", str(PINS["pids_limit"]),
        "--ulimit", "stack=-1:-1", "-u", f"{os.getuid()}:{os.getgid()}",
        "-e", "HOME=/tmp", "-e", "PYTHONPATH=/pydeps",
        "-e", "PYTHONDONTWRITEBYTECODE=1", "-e", "DUNE_CACHE=disabled",
        "-e", "TMPDIR=/records/tmp",
        "--mount", f"type=bind,source={UPSTREAM},target=/work",
        "--mount", f"type=bind,source={ROOT / '.toolchain/stage7/pydeps'},target=/pydeps,readonly",
        "--mount", f"type=bind,source={dest},target=/records",
        "-w", "/work", PINS["checker_image"], "./oft", "check", PINS["upstream_replay"],
        "--parts", "statements,proofs",
    ]
    write_json(dest / "checker-invocation.json", {"command": command, "cwd": "."})
    print(f"Running the pinned upstream checker; logs: {dest.relative_to(ROOT)}", flush=True)
    code = execute(command, ROOT, "checker")
    if code != 0:
        print((dest / "checker.log").read_text()[-4000:], flush=True)
        print(f"UPSTREAM_REPLAY_NOT_ESTABLISHED: actual Docker/checker exit {code}", flush=True)
        return 1
    if execute(["git", "diff", "--exit-code", "HEAD", "--"], UPSTREAM, "tracked-after") != 0:
        print("UPSTREAM_TRACKED_INPUT_CHANGED", flush=True)
        return 1
    after = inputs()
    write_json(dest / "inputs-after.json", after)
    output = (dest / "checker.log").read_text()
    if before != after:
        print("INPUTS_CHANGED_DURING_REPLAY", flush=True)
        return 1
    if ("proves " + PINS["upstream_statement"] + "; assumptions:") not in output or \
            "oft check: 2 step(s) passed, 0 failed;" not in output:
        print("EXPECTED_UPSTREAM_PROOF_COVERAGE_MISSING", flush=True)
        return 1
    report.update(result="passed", artifact_sha=PINS["upstream_binary_sha256"],
                  independent_rocqchk=False,
                  scope="Only the pinned upstream zlib binary and its published LPS halts statement.")
    write_json(dest / "report.json", report)
    print(output[-4000:], flush=True)
    print("UPSTREAM_REPLAY_PASSED; own binary proof and independent rocqchk remain pending.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
