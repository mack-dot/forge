# Step B4: proof identity over definitions and the dependency closure (X4, Opus; no HOL run; synthetic controls and one real hash walk)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

X4 (proof-identity), step B4. I did not run HOL. I wrote no repository file and ran no git command that changes state. Note: `git status` now shows `FORGE_MASTER_IDEA.md` and `README.md` as modified. I did not change them.

**Is H2 right?** Yes, for the import check. `imp4-0001.sml` line 11 compares only `aconv (concl th) tm` plus the tag. Constants match by name. The expected terms are built from the loaded parents (`u404`, `cdef`), so if a parent changes, the expected term changes with it. No ancestor definition is compared. `run_case.py` hashes `.sig`, `.sml`, the heap, `hol` and the executable, but no `.dat` file.

HOL itself binds parents by content hash, but it never checks the file it reads:
- **At export:** `Theory.sml:1128` takes the SHA-1 of the `.dat` and writes it into `<thy>Theory.sml`. Each `.dat` header records its parents as `(name . sha1)` (`Theory.sml:1102`).
- **At load:** `TheoryReader.sml:27-37` checks only the stored name. It then calls `link_parents` with the hash string taken from the `.sml`. No SHA-1 of the file is computed.
- **Parent check:** `Theory.sml:703-723` refuses a parent whose (name, hash) pair is not in the theory graph.

Consequences:
- An old child theory cannot load on top of an altered parent.
- If someone rebuilds the altered parent and everything after it, every SHA-1 up to the final `.dat` changes. The statement still prints the same, so `imp4` passes.
- So: the statement, plus a pinned SHA-256 of the final `.dat`, plus a check that every `.dat` file read has the SHA-1 its child records, does pin the whole closure.
- The gap today: a `.dat` swapped on disk while its `.sml` stays the same loads without any error.

Real check (plain Python, read-only): `walk_sha1_chain.py` exit 0.
- It found 541 nodes from the committed final `.dat` (542 with `min`, equal to `CLOSURE_NODES 542`), with 0 unresolved and 0 mismatches.
- The SHA-256 of all 71 `forge_*` nodes equals `comparison.json`.
- This shows that files with the right content exist now. It does not show that those files were the ones read in the `imp4` session.

Two side findings:
- The 24 phase-2 theories are not ancestors of `refund_profile_a_sl`, so they are not proof dependencies of the final theorem.
- The `altered-amount` fixture never built. Its record shows exit 1 after 52.35 s, with a tactic failure at `refund_fields_original_method`. H2's claim that "the final theorem prints byte-identically" was never demonstrated.

**Tags (L3 is right):**
- Kernel `compute` adds no tag (`std-thm.ML:1533-1559`).
- `Thm.disk_thm` is public (`FinalThm-sig.sml:150`), so any session code can make a theorem whose tag shows only `DISK_THM`.
- Axioms are not stored in `.dat` files (`Tag.sml:82-89`), so `null axs` is always true for loaded theorems and shows nothing. The real axiom check is the `DB.axioms` sweep over the ancestry, which gives the 4 `bool` axioms.

**Closure specification, in short.** The manifest must hold:
1. The statement as a canonical term, plus the printed text.
2. The definition closure: every constant and type, followed through every `forge_*` theory. Upstream theories stop the walk and are bound only by their `.dat` hash.
3. The 541 ancestors, each with its graph SHA-1 and the SHA-1 and SHA-256 of its `.dat`. Which files HOL actually read comes from a load guard that hooks `TheoryReader.load_thydata_fn`; that hook is public.
4. Oracles and hypothesis counts for the final theorem and every definition, and the axiom set of the ancestry.
5. The code-to-file binding (`refund_file`, `code`, the slices), with what lies outside it listed.

The comparison is exact equality of every record: any missing or extra record refuses. Reference values count as independent only when a second operator computes them and publishes them signed or through a channel the agent cannot write. Values from the same machine show only "unchanged since the producer recorded it".

**Synthetic controls (real exit codes, fake inputs):**

| case | expected | actual |
| --- | --- | --- |
| c0 baseline | 0 | 0 |
| c1a altered definition text, same statement (H2) | 1 | 1 |
| c1b H2 with the whole chain rebuilt | 1 | 1 |
| c2 missing ancestor | 1 | 1 |
| c3 extra ancestor | 1 | 1 |
| c4 changed `.dat` | 1 | 1 |
| c5 extra oracle | 1 | 1 |
| c6a H2, reference list re-pinned by the same producer | 0 | 0 |
| c6b same, with `--require-independent` | 1 | 1 |
| c7 truncated export | 1 | 1 |
| c8 `.dat` swapped on disk | 1 | 1 |

The runner exited 0. The first run exited 1 because of a bug in my checker: it compared the `FORMAT`/`END` lines against the manifest. I fixed it and reran; the table is from the second run. c6a is the key limit: if the producer also pins the reference values, the check proves nothing.

**Plan for the real control (not run):**
- **R1, micro control:** two parent theories with the same name and `c = 1` versus `c = 2`, and a child theorem that holds for both. Expected: the old check passes, the new check refuses. It takes seconds.
- **R2, the real fixture:** run in a copy of `run_case.py`, because `run_case.py` writes its case folders next to itself, inside the repository. Steps: build the altered `forge_refundCertifiedProg`, rebuild its 46 `forge_*` dependants, run the old check, then the export and the new check.
  - Expected today: the build fails after about 52 s, as recorded.
  - If it builds, the chain most likely fails later, at the byte check against `refund_file`, because the code would change.
  - Time from the recorded wall times: about 4,500 s (75 min) in one HOL job, peak memory up to 4.8 GiB.
  - Commands and the files it writes are in section 4 of the analysis.

**What is not recorded today:**
- any `.dat` file read in the import-check session;
- the 16 upstream theories built during the replay (no pins);
- the other upstream theories (470 non-`forge` nodes in total, including the L3 models);
- how the heap was built: only its SHA-256 is recorded;
- any definition text;
- any independent reference value.

**What stays trusted after the strengthened check:**
- the HOL kernel, including `Compute.sml`, and the trust that each `.dat` came from a proof run;
- Poly/ML and the heap;
- my exporter, the load guard and the checker;
- SHA-1 and SHA-256;
- the about 454 upstream theories that nobody replayed;
- the operator who pins the reference list.

Next obligation: a second operator rebuilds the 71-theory chain from pinned sources on another machine, runs `closure_export.sml`, and publishes a signed manifest; this machine's export must equal it record by record.

**What I could not determine:**
- Whether `closure_export.sml` type-checks. It was never run.
- Whether the "mentions the constant" rule finds the defining theorem of every constructor and record field.
- Whether the heap's theories match the `.dat` files found on disk.
- Whether the replay `driver.py` can be pointed at a scratch tree.
- Whether an alteration of an ancestor definition that keeps every proof valid exists in the real chain.

**Links for the top-level graph:** the full table with evidence and upgrades is in the analysis. Classes:
- **MACHINE-CHECKED:** `RefundSpec.dfy` → `Refund.dfy` proof (Dafny, `ROADMAP.md:1449`); ancestor names and hash strings (`link_parents` in `imp4`); tags and axioms (`imp4`); HOL code constant → `__TEXT` and bitmap slices (`forge_refundImage`).
- **TESTED-UNPROVED:** `.dat` bytes against the recorded SHA-1 (X4 walk); 95 `forge` hashes (same agent family); executable SHA in `run_case`; conformance-suite binary.
- **ASSUMPTION (not approved):** heap contents; kernel `compute` and `disk_thm`.
- **MISSING:** Dafny R1–R5 → HOL functions; pinned definition closure; upstream `.dat` pins; the rest of the executable (`__DATA`, GOT, `__LINKEDIT`); executable → deployed binary; independent recomputation of the proof records.

**FIRST MISSING link:** Dafny contract R1–R5 → HOL `eligible` / `refund_fields` / `refund_render_fields`. In the identity part, the first MISSING link is the pinned definition closure.

Files are in `<session scratch folder>/m1b/X4/`:
- `PROOF_IDENTITY_ANALYSIS.md`
- `CLOSURE_SPEC.md`
- `closure_export.sml`
- `check_closure.py`
- `run_synthetic_controls.py`
- `synthetic/results.json`
- `walk_sha1_chain.py`
- `walk_real.json`

| step | status | evidence or blocker |
| --- | --- | --- |
| B4 proof identity | REPORTED | `X4/PROOF_IDENTITY_ANALYSIS.md`, `X4/CLOSURE_SPEC.md`; synthetic controls 11 of 11 as expected (`X4/synthetic/results.json`, runner exit 0); real SHA-1 chain walk exit 0, 541 nodes, 0 mismatches (`X4/walk_real.json`) |
| B4 real control (R1/R2) | BLOCKED | needs the HOL slot; `closure_export.sml` is not run |
