#!/usr/bin/env python3
"""Inventory checkout bytes and installed tools; this makes no proof verdict."""
import argparse
import collections
import hashlib
import json
import os
import stat
import subprocess
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--commit", required=True)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    out = Path(a.output)
    out.mkdir(parents=True, exist_ok=False)
    commands = []

    def run(argv, name):
        r = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (out / (name + ".stdout")).write_bytes(r.stdout)
        (out / (name + ".stderr")).write_bytes(r.stderr)
        commands.append({"command": argv, "exit_code": r.returncode})
        if r.returncode:
            raise RuntimeError(f"{name} exited {r.returncode}: {r.stderr.decode(errors='replace')}")
        return r.stdout

    head = run(["git", "rev-parse", "HEAD"], "head").decode().strip()
    assert head == a.commit, "UPSTREAM_COMMIT_MISMATCH"
    run(["git", "diff", "--exit-code", "HEAD", "--"], "tracked")
    tree = run(["git", "ls-tree", "-rz", "HEAD"], "tree")
    manifest, groups, count, total = {}, collections.defaultdict(list), 0, 0
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        meta, name = entry.split(b"\t", 1)
        mode, kind, expected = meta.decode().split()
        assert kind == "blob", "UNHANDLED_GIT_OBJECT_KIND"
        path = Path(os.fsdecode(name))
        info = path.lstat()
        if mode == "120000":
            assert stat.S_ISLNK(info.st_mode)
            data = os.fsencode(os.readlink(path))
        else:
            assert mode in ("100644", "100755") and stat.S_ISREG(info.st_mode)
            assert bool(info.st_mode & 0o111) == (mode == "100755"), str(path)
            data = path.read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert actual == expected, f"GIT_BLOB_MISMATCH: {path}"
        manifest[str(path)] = hashlib.sha256(data).hexdigest()
        groups[str(path).casefold()].append((str(path), info.st_dev, info.st_ino, actual))
        count += 1
        total += len(data)
    collisions = [v for v in groups.values() if len(v) > 1]
    for group in collisions:
        assert len({(x[1], x[2]) for x in group}) == len(group), "CASE_PATHS_ALIAS"
    raw = (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode()
    (out / "tracked-sha256.json").write_bytes(raw)
    binary = Path("projects/zlib/bin/checksum_fuzzer/checksum_fuzzer.plain")
    report = {"commit": head, "tracked_files": count, "tracked_bytes": total,
              "tracked_sha256_manifest": hashlib.sha256(raw).hexdigest(),
              "case_collision_groups": len(collisions), "case_paths": sum(map(len, collisions)),
              "case_paths_have_distinct_inodes": True,
              "uid": os.getuid(), "gid": os.getgid(), "commands": commands,
              "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest() if binary.exists() else None,
              "proof_verdict": "not_assessed"}
    (out / "identity.json").write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    print(json.dumps(report), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
