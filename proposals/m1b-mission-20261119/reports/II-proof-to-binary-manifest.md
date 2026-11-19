# Step II: proof-to-binary evidence manifest, a draft with a verifier and controls (W5, Opus)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W5 step II report: the proof-to-binary evidence manifest. This is a draft. Nothing in the repository was changed and nothing was proved. M1 stays OPEN and `end_to_end=false`.

**Design in short** (full text in MANIFEST_DESIGN.md)
- The manifest binds files by SHA-256. Each binding is a pair `{locator, sha256}`.
- There are three locator kinds:
  - a file under `--root`;
  - a git blob named by a full 40-character commit (a branch name is refused);
  - a file under `--toolchain-root`.
- There is no new cryptographic protocol. SHA-1 appears only where HOL itself writes it: the parent links inside `.dat` files. Each of those parent files is also pinned by SHA-256.
- The fields cover:
  - the approved spec and protocol. Each digest must equal the approval table in `proposals/refund-decision.md` (commit e3aa546f) and `spec.lock`.
  - five implementation sources: `impl/Refund.dfy`, `Boundary.dfy`, `forge_refundScript.sml`, the WholeProg script and the Arm8Compile script.
  - the final theorem `forge_refundSlideProfileA.refund_profile_a_sl`. The verifier checks that it is a stored theorem in the `.dat` and named in the `.sig`, checks the digest of the printed statement, and checks that the 11 premises equal the printed antecedent.
  - the dependency closure. The verifier walks the parent links from the final theory. The listed theory set must equal the reached set. Every tag must be in {DISK_THM}, and the replay comparison records must agree.
  - the toolchain: three commits checked against the pin file, the Dafny build checked against `spec.lock`, and the compile theorem `refund_arm8_compiled`. Its log must show `backend$compile arm8_target$arm8_config`, oracles DISK_THM, no axioms and 0 hypotheses.
  - the artifact: file SHA-256, size 238776, the code slice (offset 16592, 130,436 bytes) and the bitmap slice (offset 180248, 20,248 bytes), each tied to `refund_file_code` or `refund_file_bitmaps` in `forge_refundImage`, which is inside the closure.
  - Profile A: 13 items, a set fixed in the verifier code from OWNER_DECISIONS Q1 to Q5. Each item must be APPROVED with `verified=false`. The premise ledger must be REVIEWED, and the Q3c condition must be VALIDATED.
  - obligations, open issues, replays (chain, 158 cases, clean, independent) and the contract link.
- Fail-closed rules:
  - a missing key, an unknown key, a null value, a file that cannot be read, a bad hex digest or any difference gives exit 1.
  - a crash gives exit 2.
- Claim levels: the caller gives `--level`. A manifest key that looks like a level is refused (`PRODUCER_STATED_LEVEL`). The verifier computes the highest level the evidence supports.
  - M1-A needs every identity check, Profile A complete, the ledger reviewed, Q3c validated, no open obligation or issue, the chain, 158-case and clean replays PASSED, and a link at least REVIEWED. REVIEWED means 18 rows HOLDS and CLOSED, by a reviewer the owner named who is not the author.
  - M1-B also needs a MACHINE_CHECKED link (a Dafny half record plus a HOL link theorem inside the closure of the final theorem) and the independent replay PASSED.
  - The owner should confirm one choice of mine: the clean replay is required at M1-A, and the independent replay only at M1-B.

**Files written** (in `<session scratch folder>/m1b/W5/`)
- MANIFEST_DESIGN.md
- m1_manifest_draft.json
- make_draft_manifest.py
- verify_m1_manifest.py
- run_controls.py
- controls-result.txt
- controls-stdout.txt
- real-verdict-M1-A.txt
- real-verdict-M1-B.txt
- ctl/ (copies used by the controls, with one verdict file per run)
- helpers: find_dats.py, walk_probe.py, sx_probe.py, dat_locations.json, walk.json, upstream_hits.json

**Real exit codes**
- Draft manifest at M1-A: exit 1, highest level supported "none".
- Draft manifest at M1-B: exit 1, highest level supported "none".
- What is missing, in order:
  - `PIN_NOT_PROTECTED`
  - `PREMISE_LEDGER` (status DRAFT)
  - A-Q3C `NOT_DONE`
  - `OBLIGATION_OPEN` (O4: the premises are shown satisfiable for one slide only)
  - `OPEN_ISSUE` ×3 (I.2 row 17, row 18, the bodiless Dafny axiom)
  - 158 cases `RUNNING`
  - clean replay `NOT_RUN`
  - `LINK_NOT_ESTABLISHED`
  - for M1-B also: independent replay `NOT_RUN` and `LINK_METHOD_WEAKER`
- Every identity check that can run today passed:
  - spec and protocol equal the approved digests;
  - the 5 sources;
  - 71 closure theories (55 from git c003a982, 16 from untracked `results/`);
  - 85 Forge-to-Forge parent links and 24 links to 18 upstream parents, by SHA-1 and SHA-256;
  - all tags;
  - the statement digest and the 11 premises;
  - the compile record;
  - the artifact and both slices.
- Controls: `run_controls.py` exit 0, ALL CONTROLS PASS, 56 verifier runs.
  - SYNTHETIC baseline (stand-in records, marked NOT EVIDENCE, scratch only): exit 0 at both levels. This shows the verifier can pass.
  - Each control on SYNTHETIC gave exit 1 with its own reason, new against the baseline, at both levels:
    - substituted artifact → DIGEST_MISMATCH
    - substituted artifact with its digest re-pinned → ARTIFACT_SLICES
    - stale proof record (older digest) → STALE_PROOF_RECORD
    - changed `.dat` with its digest re-pinned → STALE_PROOF_RECORD
    - unapproved spec change with its digest re-pinned → SPEC_NOT_APPROVED
    - CakeML pin changed → TOOLCHAIN_MISMATCH
    - backend config changed → COMPILER_CONFIG
    - missing field → MISSING_FIELD
    - unknown field → UNKNOWN_FIELD
    - level stated in the manifest → PRODUCER_STATED_LEVEL
    - null artifact → MISSING_EVIDENCE
    - swapped upstream parent → PARENT_LINK
  - Weaker method on SYNTHETIC: M1-B exit 1 with LINK_METHOD_WEAKER; M1-A exit 0, as designed.
  - On the REAL baseline every control also gave exit 1 with its own reason. LINK_METHOD_WEAKER was already present there.

**Defects and findings during the run**
- In the first control run a null artifact made the verifier crash (exit 2, AttributeError). I repaired it with a shape check of every pinned pair before any file read. All controls were then rerun.
- `OWNER_DECISIONS.md` is untracked, and it changed three times while I worked. The verifier refused each time with DIGEST_MISMATCH. The controls now take one snapshot at the start and re-pin only that record, with a printed note.
- In HOL `.dat` files a parent link is the SHA-1 of the parent `.dat`. I confirmed this on the ProfileA file. So the dependency graph can be checked by content.
- Some stored cv theorems have an empty tag list. I read this as "no oracle". That is an inference from the format, not a checked fact.

**What the manifest cannot bind today, and why**
- The contract link: it is NOT_ESTABLISHED. No machine-checked link exists, and no dated review record by an independent, owner-named reviewer exists. The I.2 report is from a model of the same family, and it found that rows 17 and 18 do not hold as worded.
- The meaning of a statement: the verifier does not decode the HOL terms. That the printed text is the printing of the stored term rests on the HOL run that wrote both.
- The upstream ancestry above the 18 direct upstream parents (about 1,900 theories): bound only by the commits and the local build.
- The real loader, dyld and libSystem bytes: never captured.
- Q3c: the second, independent extraction of the file bytes and offsets is not done.
- The 158-case replay, the clean replay and the independent replay: their records do not exist yet. The record format the verifier expects (a JSON that restates its status and the artifact digest) is proposed only.
- Durability: many inputs are not on main. Sources and 55 `.dat` files are only on the backup branch commit. 16 `.dat` files, the upstream `.dat` files and `OWNER_DECISIONS.md` are untracked, local only.

**What stays trusted**
- The verifier code, Python and its hashlib.
- SHA-256, and SHA-1 inside HOL's parent links.
- My small `.dat` S-expression reader.
- The HOL kernel, its compute extension used by cv, Poly/ML and the HOL printer.
- The ML file reader and offset tool of U389.
- The person who approved the spec (a conversational approval, not a signature) and the owner's decision texts (U473).
- git, as a store of bytes only (the SHA-256 is checked after reading).

A second, independent verifier needs:
- this design and the record formats;
- its own `.dat` reader, written from the HOL source and ideally able to decode terms, so it can compare the stored term with the printed text;
- its own copy of the Profile A item set;
- the evidence files, or a clean replay that writes them again;
- agreement on every control.

It should be written by another person, in another language.

**Future protected-path proposals** (exact diff text later; none applied)
1. A pin file under `toolchain/` with the HOL, CakeML and Poly/ML commits, plus the backend configuration name. Today they live only in `proposals/round2-20261117/m1-rebuild/rebuild.py`.
2. A manifest schema in `schemas/` (the current evidence schema has no field for a theorem, a closure, a profile or a link level), and later a `gate/` check that calls the verifier.
3. A tracked, merged owner decision record, probably under `governance/`, so that it cannot change under a pinned digest.
4. Changes to `spec/` are NOT needed. `spec.lock` was changed by Step B after the approval, but it still names the approved spec and protocol digests, and the verifier checks that.

| step | status | evidence or blocker |
| --- | --- | --- |
| II design | REPORTED | MANIFEST_DESIGN.md (in the W5 scratch folder) |
| II draft manifest | REPORTED | m1_manifest_draft.json; real values; nulls marked; M1 OPEN |
| II verifier | REPORTED | verify_m1_manifest.py; real manifest exit 1 at M1-A and at M1-B (real-verdict-*.txt) |
| II controls | REPORTED | run_controls.py exit 0; 56 runs; controls-result.txt |
| II level M1-A or M1-B through the manifest | BLOCKED | contract link not established; ledger DRAFT; Q3c not done; O4 open; 3 open issues; 158-case, clean and independent replays not finished; pins not protected |
