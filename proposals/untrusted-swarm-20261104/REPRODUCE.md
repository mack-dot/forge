# Reproduce FUSE-1 prerequisites

Run from `/Users/mackianni/forge`. The packet uses local archived files and the
existing macOS toolchain. No installation, model invocation or network is needed.
Do not run historical proof drivers: they modify shared toolchain directories.

The authored inputs are prepared with:

```
python3 -B proposals/untrusted-swarm-20261104/prepare.py
```

This command refuses existing output. It was run during setup. It does not prove
the two candidate refactors or execute any hidden controls. Subsequent review
corrected the claim inventory before freeze; prepare.py contains those corrections.

Create the prerequisite freeze once, before the first probe:

```
python3 -B proposals/untrusted-swarm-20261104/benchmark.py freeze
```

An existing freeze must never be overwritten. For a new prerequisite replay,
select a fresh run ID. These are the exact first-run commands:

```
python3 -B proposals/untrusted-swarm-20261104/benchmark.py preflight --run preflight-0001
python3 -B proposals/untrusted-swarm-20261104/benchmark.py report --run preflight-0001
python3 -B proposals/untrusted-swarm-20261104/benchmark.py validate --run preflight-0001
```

Expected, not actual results: the original file digest should exit0; a one-byte
substitution should make system shasum exit1. The OS canary may fail if nested
sandbox creation is forbidden. The overall prerequisite harness must exit2 while
required isolation, compute broker and admission capabilities are unavailable.
Report/readback exit0 checks the packet only. It cannot convert that result into
a proof or a completed experiment. Actual results belong in ROADMAP and the raw
result files, not this expectations section.

Fresh runs preserve old directories. A second preflight is justified only by a
changed prerequisite or an explicit reproduction check, not a blind permission
retry. After an OS refusal, do not request escalation or attempt another route.
Use `validate` for read-only reproduction of saved identities.

`FREEZE.sha256` and `anchors/` provide local integrity references. They are not
authenticated, protected storage or signatures. A party that can rewrite both
data and anchors defeats that local check. This is one reason scored trials are
blocked in the shared environment.

To begin the full comparison, first implement and qualify the exact prerequisite
capabilities named in capabilities.json. Freeze a separate complete execution
binding with model/configuration, private worker image, checker closure and typed
claims, resource meter, candidate-aware hidden mutation generator and seed
commitment. Use 18 fresh cells and 20 fresh role contexts for each team cell.
Do not reuse any of the setup reviewers. Any changed protocol requires a new
version; do not mutate FUSE-1 after results exist.

All current native/M1 limitations remain. No protected change, signing,
publication, merging, deployment or Stage12 is part of this procedure.
