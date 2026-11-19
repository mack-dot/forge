# X4 proof identity analysis (step B4), 2026-11-19

Draft in a scratch folder. Not evidence. No HOL run. Paths are relative to `<HOME>/forge` unless absolute.
`R` = `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records`. `H` = `.toolchain/experiments/refund-cakeml-20261104/HOL` (commit `9783a499`).

## 1(a) What today's import check binds

`R/final-cases/imp4-0001.sml`:

```sml
fun clean th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors end;
fun same name tm = let val th = DB.fetch T name in aconv (concl th) tm andalso clean th end handle _ => false;
...
val u404 = DB.fetch "forge_refundProfileA" "refund_profile_a_slide0";
val exp_ta = slide (concl u404);
val _ = check "refund_profile_a_sl" exp_ta;
...
val cdef = DB.fetch "forge_refundEnvModel" "refund_ffi_contract_def";
...
val closure = T :: Theory.ancestry T;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = if length axs = 4 then () else bad := !bad + 1;
```

It binds:
- the statement TERM of 15 stored theorems, by `aconv`. The constants in both terms are resolved by NAME in the same session. So `aconv` compares names and types, not meanings.
- the expected terms are built from LOADED theorems (`u404` from `forge_refundProfileA`, `cdef` from `forge_refundEnvModel`). If a parent changes, the expectation changes with it.
- the tag of each checked theorem: no hypotheses, oracles only `DISK_THM`.
- the axiom count of the ancestry: 4 (`stdout.log`: `CLOSURE_AXIOM bool.SELECT_AX`, `INFINITY_AX`, `ETA_AX`, `BOOL_CASES_AX`; `CLOSURE_NODES 542`).

It does not bind: any definition of an ancestor theory (`eligible_def`, `refund_fields_def`, `refund_render_fields_def`, `refund_request_def`, `refund_image_mem_def`, `refund_file_def`, `code_def`), and no `.dat` byte.

The runner `R/final-cases/run_case.py` hashes the HOL binary, the heap, each loaded `.sig` and `.sml`, and the executable (`assert inputs[IMAGE] == 'b8ed5ec2…'`). It does NOT hash any `.dat` file (`imp4-0001/command.json` `input_sha256` lists only `.sig`/`.sml`, heap, `hol`, image).

### Is H2 right? What HOL itself binds

H2 is right about the import check. The check passes for any ancestor content that keeps the same names and types and lets the chain build. But H2 does not use what HOL itself records. HOL records parents by content hash. It does not verify the file it reads against that hash.

What HOL does (source cited):
1. **At export.** `H/src/postkernel/Theory.sml:1126-1131`: the `.dat` is written, then `val hash = SHA1.sha1_file {filename = #tmp datfile_t}`. The hash goes into `<thy>Theory.sml` (`TheoryPP.pp_struct hash`). The `.dat` header holds each parent as `(name . sha1)` (`Theory.sml:1102` `parents = map dest_thyid (Graph.fringe())`). Real example, `R/final-cases/e4-0001/theory-export/forge_refundSlideProfileATheory.dat` lines 1-4: `("forge_refundProfileA" . "20be22cb…")`, `("forge_refundSlideSat" . "e60e1e78…")`. Its `.sml`: `hash = "a8f4f9be…"`.
2. **At load.** `H/src/postkernel/TheoryReader.sml:27-37`: `load_thydata_from_dat {thyname,path,hash}` reads the file, checks only the stored NAME (line 33), then calls `Theory.link_parents (thyname, hash) (map mungename parents)`. The `hash` is the string from the `.sml`. No SHA-1 of the file is computed. `RawTheoryReader.sml:257-260` only decodes.
3. **Parent check.** `Theory.sml:703-723` `link_parents`: every `(parent name, parent hash)` recorded in the child must already be in the theory graph (`Graph.isin`, `Theory.sml:178`, equality of name AND hash string, `thyid_eq`, line 129). Otherwise `link_parents: the following parents … should already be in the theory graph` and an error.

Consequences:
- A STALE child cannot be loaded on top of an altered parent: the parent's new SHA-1 is not the one in the child's `.dat`. HOL refuses.
- An attacker who REBUILDS the altered parent and all dependants gets new SHA-1 values at every level, up to the final theory. The final theory's `.dat` then differs (it embeds its parents' hashes). The final statement still prints the same. The import check passes (H2).
- Therefore: **final statement + SHA-256 of the final `.dat` pinned + verification that every ancestor file actually read has the SHA-1 its child records** pins the content of every ancestor `.dat` (a hash chain, like a Merkle tree). This holds up to SHA-1 second-preimage resistance and up to the trust in the heap (see below).
- The gap: HOL takes the hash from the `.sml` text and never hashes the `.dat` it reads. A `.dat` swapped on disk while its `.sml` stays the same loads without an error. `run_case.py` does not hash `.dat` files either. So in the import-check session nothing binds the bytes read.
- Heap theories: theories inside `cake_compile_heap` were loaded when the heap was built. Their graph hash strings are fixed in the heap. Their contents are bound only by the heap SHA-256 (`2f5dbb71…` in `e4-0001/command.json`), not re-read.

What I checked on real files (plain Python, read-only, this machine): `<session scratch folder>/m1b/X4/walk_sha1_chain.py` walks the `(parent . sha1)` records from the committed final `.dat`, finds each parent by name under `results/` and the tool tree, and keeps a file only if its SHA-1 equals the recorded one. Actual exit 0. Result `walk_real.json`: 541 nodes resolved (542 with `min`, equal to `CLOSURE_NODES 542`), 0 unresolved, 0 mismatches, every `.sml` hash string equal, no theory with two hashes. 71 of the nodes are `forge_*` theories. Their SHA-256 equal the `fresh` values in `comparison.json` (71 of 71). This shows files with the right content EXIST now. It does not show that these were the files read in the `imp4-0001` session.

Another finding: the 24 theories of `comparison-phase2.json` (for example `forge_refundArm8Proof`, `forge_refundInstallSite`, `forge_refundWriteWord`) are NOT ancestors of `forge_refundSlideProfileA`. They are not proof dependencies of the final theorem.

The `altered-amount` fixture: its recorded build FAILED. `certified-library-20261104/records/proof-altered-amount/command.json` (branch `origin/backup/forge-local-2026-11-11`): `actual_exit 1`, `wall_seconds 52.35`, log: `Tactic failure proving "refund_fields_original_method"`. So H2's sentence "built on such a parent, the final theorem prints byte-identically and the import check passes" was never demonstrated with this fixture. The defect in the check is real. The demonstration needs a parent that builds (section 4).

## 1(b) Identities recorded today

| What | Recorded | By whom |
| --- | --- | --- |
| 95 forge theories (71 phase 1 + 24 phase 2): `.dat`, `.sig`, `.sml` SHA-256 | `R/comparison.json` (72 rows: 71 theories + `C72-imp4-0001`), `R/comparison-phase2.json` (24); all `equal` | `fresh` and `recorded` are both computed by the same agent family on the same machine. The `recorded` values come from the earlier agent runs (2026-11-12 to -17). This is a same-machine replay. It is not independently validated. |
| Final theory files | `e4-0001/command.json` `objects`: `.dat` `4ff2a7e2…`, `.sig` `d61d4460…`, `.sml` `065df441…` | same |
| Loaded `.sig`/`.sml`, heap, `hol`, executable | `imp4-0001/command.json` `input_sha256` | same |
| `.dat` files read by the import check | NOT recorded | |
| 16 upstream theories built during the replay (`arm8_configProof`, `arm8_targetProof`, `arm8_targetProofLemmas`, `asmSigned`, `dafnyProps`, `dafny_ast`, `dafny_evaluate`, `dafny_evaluateProps`, `dafny_freshen`, `dafny_freshenProof`, `dafny_misc`, `dafny_semanticPrimitives`, `dafny_to_cakeml`, `dafny_to_cakemlProof`, `result_monad`, `sexp_to_dafny`) | listed as new files in `R/tooltree-compare-final-phase2.json`; no hash pinned, no comparison | |
| The other ~454 upstream HOL/CakeML theory `.dat` files of the closure (470 non-forge nodes in total, including L3 `arm8` model theories) | NOT recorded in the M1 records. An older snapshot (`dependency_snapshot_0002.py`, 2026-11-04, 378 nodes, compiler closure only) hashed `.uo/.ui/.sml/.sig/.dat` of a smaller closure | |
| Heaps | SHA-256 of `cake_compile_heap` in each `command.json`; no record of how the heap was built from which `.dat` | |
| Definition texts of the closure | NOT recorded anywhere | |

## 1(c) Tags

- `DISK_THM`: every theorem read from a `.dat` gets it (`H/src/thm/std-thm.ML:1478-1485` `disk_thm`, `H/src/prekernel/Tag.sml:76-77` `read_disk_tag`). It means "trusted because a file says so". HOL does not re-check proofs on load.
- `Thm.disk_thm` is PUBLIC (`H/src/prekernel/FinalThm-sig.sml:149-150`). Any ML code in a session can make a theorem with only the `DISK_THM` tag. A clean tag cannot show that a theorem was proved.
- Oracles: `mk_oracle_thm` adds the user tag (`std-thm.ML:1237-1240`; `DISK_THM` is forbidden as a user tag). Oracle tags are stored in the `.dat` and merged through inference (`Tag.sml:73-74`). So oracle use in any ancestor proof shows in the final tag. This part is sound.
- Axioms: the `.dat` does not store axiom references (`Tag.sml:82-89`: "The axioms are not currently dumped"). A theorem from disk always has an empty axiom list. So `null axs` in `clean` is always true for loaded theorems and shows nothing. The real axiom check is the `DB.axioms` sweep over the ancestry (`imp4-0001.sml`, `CLOSURE_AXIOM`, 4).
- Kernel `compute` (used by `cv_compute`): `std-thm.ML:1533-1559`. The result's tag is only the merge of the input equations' tags (`tag1`, line 1547; `make_thm Count.Compute (tag1, empty_hyp, eqn)`, line 1556). No oracle, no mark. L3 is right: the tag cannot show that `compute` was used. `src/thm/Compute.sml` is in the trusted kernel. `Count.Compute` counts per session only.
- "Zero hypotheses, four bool axioms" binds: no undischarged assumption in the final theorem, and no `new_axiom` in any of the 542 theories other than the four of `bool`. It does not bind: the meaning of definitions, the use of `compute`, theorems made with `disk_thm`, or the bytes of the `.dat` files.

## 2. Strengthened check

See `CLOSURE_SPEC.md` (same folder).

## 3. Drafts and synthetic controls

- `closure_export.sml`: HOL draft, NOT RUN, never type-checked. Part A is a load guard (`TheoryReader.load_thydata_fn` hook) that SHA-1-hashes every `.dat` read and refuses a mismatch. Part B prints the export.
- `check_closure.py`: compares an export with a pinned manifest and hashes the `.dat` files. Exit 0 equal, 1 refused, 2 crash.
- `run_synthetic_controls.py` writes FAKE inputs under `synthetic/` and runs the checker. Real exit codes (`synthetic/results.json`):

| case | what | expected | actual |
| --- | --- | --- | --- |
| c0-baseline | unchanged | 0 | 0 |
| c1a-h2-definition-text-only | `refund_fields_def` text `amount + 1`, same name, same STATEMENT | 1 | 1 |
| c1b-h2-rebuilt-chain | H2 as an attacker does it: altered parent, rebuilt dependants, consistent SHA-1 chain, same STATEMENT | 1 | 1 |
| c2-missing-ancestor | one ANCESTOR removed | 1 | 1 |
| c3-extra-ancestor | one ANCESTOR added | 1 | 1 |
| c4-changed-dat | one `.dat` byte added | 1 | 1 |
| c5-extra-oracle | `cheat` oracle on the final theorem | 1 | 1 |
| c6a-h2-repinned-no-provenance-rule | H2 chain against a manifest RE-PINNED by the same producer | 0 | 0 |
| c6b-h2-repinned-require-independent | same, `--require-independent` | 1 | 1 |
| c7-truncated-export | two records cut | 1 | 1 |
| c8-loaded-dat-swapped | `.dat` swapped on disk, `.sml` hash unchanged | 1 | 1 |

Runner exit 0. First run: runner exit 1, because the checker compared the `FORMAT`/`END` lines against the manifest (a draft bug: c0 and c6a refused). Fixed; second run above.
c6a is the important limit: if the producer also writes the reference list, the check proves nothing. The `independent` flag is a claim in the manifest. The checker cannot authenticate it. It must come from a signature or a separate channel of a second operator.

## 4. The real control for later (do not run now)

Facts: the committed fixture fails to build (exit 1 after 52.35 s at `refund_fields_original_method`). Even if it built, `refund_fields` is translated into the code. The compiled bytes would change, and the `forge_refundImage` byte equality with the pinned `refund_file` would fail (run_case asserts the image SHA). So the real chain most likely refuses this alteration by itself. That is good, but it does not test the identity check. Two controls are needed.

**R1, micro control (seconds, certain to build).** Scratch tree `$S/X4-real/micro`. Theory `forge_h2P` with `c_def: c = 1n`; variant `forge_h2P` with `c = 2n` in a second tree. Child `forge_h2C` proves `⊢ c = c` (or `0 < c`, true for both). Steps per tree: `Holmake --no-cache -j1 forge_h2CTheory.uo`; old-style check `aconv (concl (DB.fetch "forge_h2C" "t")) ``c = c``` passes for both (the defect); `closure_export.sml` on both; `check_closure.py` of the variant against the manifest of the original: expected exit 1 with `MISSING/EXTRA DEF forge_h2P.c_def` and `MISSING/EXTRA ANCESTOR` for both theories.

**R2, the real chain with `altered-amount`.** Run in a COPY of `run_case.py`, because `run_case.py` writes case folders next to itself (`OUT = Path(__file__).resolve().parent`), which is inside the repository.
```
S=/private/tmp/…/scratchpad/m1b/X4-real            # scratch only
mkdir -p $S && cp R/final-cases/run_case.py $S/ && cp R/final-cases/imp4-0001.sml $S/
# 1. altered parent in a scratch copy of the experiment folder (Holmakefile INCLUDES must be absolute; check first)
cp -R $TC/cakeml/compiler/dafny/forge_refundCertifiedProg_experiment $S/certprog
git show origin/backup/forge-local-2026-11-11:proposals/refund-executable-feasibility/certified-library-20261104/records/controls/altered-amount/forge_refundCertifiedProgScript.sml > $S/certprog/forge_refundCertifiedProgScript.sml
(cd $S/certprog && HOLDIR=$TC/HOL CAKEMLDIR=$TC/cakeml $TC/HOL/bin/Holmake --no-cache -j1 forge_refundCertifiedProgTheory.uo)
#    expected today: exit 1 at about 52 s (recorded). If so, STOP: record it; make a variant that also
#    restates refund_fields_original_method, or use R1.
# 2. if step 1 exits 0: rebuild the 46 forge dependants of forge_refundCertifiedProg in scratch copies, in the
#    order of R/plan.json, with the replay driver pointed at $S (R/scripts/driver.py; adapt, not checked by X4).
#    Expected: a failure at the first theory that checks code bytes against refund_file (forge_refundImage or
#    earlier). If all 46 exit 0, continue.
# 3. old check, on the rebuilt chain:
python3 -I -B $S/run_case.py imp4-alt-0001 imp4-0001.sml <125 rebuilt .sig/.sml paths, order of deps-imp4.txt>
#    expected if reached: exit 0, IMPORTED_COUNT 15 MISMATCH_COUNT 0 (the defect)
# 4. new check:
FORGE_THY=forge_refundSlideProfileA FORGE_THM=refund_profile_a_sl FORGE_STOP=<pinned upstream list> \
python3 -I -B $S/run_case.py cx-alt-0001 closure_export.sml $S/dat_guard.sml <same 125 paths>
python3 -I -B check_closure.py $S/cx-alt-0001/export.txt <manifest pinned by a second operator> --require-independent --dat …
#    expected: exit 1; MISSING/EXTRA ANCESTOR forge_refundCertifiedProg and its dependants; MISSING/EXTRA DEF refund_fields_def
```
Expected time from records: `forge_refundCertifiedProg` 52.2 s (`R/summary.json`); its 46 forge dependants 4,274.3 s; `imp4-0001` 77.6 s; the export about 80-110 s (like `imp4-0001` and `e4-0001` 105.9 s). Total about 4,500 s (75 min), one HOL job, peak RSS up to 4.8 GiB (`summary.json` 4768 MiB). If step 1 fails as recorded: about 1 min.
Files written: `$S/certprog/.hol/objs/forge_refundCertifiedProgTheory.{dat,sig,sml,uo,ui}` and logs; 46 dependant object sets under `$S`; `$S/imp4-alt-0001/{invocation.json,command.json,stdout.log,stderr.log,proof.sml}`; `$S/cx-alt-0001/…` plus `export.txt`. Nothing under the repository or `.toolchain`.

## 5. What stays trusted after the strengthened check

- The HOL kernel at `9783a499`, including `src/thm/Compute.sml` (compute leaves no tag), and the trust that each `.dat` came from a proof run (`DISK_THM`; `disk_thm` is public).
- Poly/ML and the saved heap `cake_compile_heap` (its theories are not re-read).
- `closure_export.sml`, the `dat_guard` hook, and `check_closure.py`.
- SHA-1 inside the HOL graph (chosen-prefix collisions are practical; the external SHA-256 of every `.dat` covers this) and SHA-256.
- The `.dat` content of ~454 upstream theories that nobody replayed (only 16 were built in the replay), bound to upstream sources only by commit.
- The person or operator who pins the reference list, and the channel that carries it.

Next independently checkable obligation: a second operator, on another machine and from the pinned sources, rebuilds the 71-theory chain, runs `closure_export.sml`, and publishes a signed manifest; this machine's export must be equal to it, record by record.

## Links for the top-level graph (ValidArtifact)

| from | to | statement or check | class | evidence | what would upgrade it |
| --- | --- | --- | --- | --- | --- |
| `spec/refund/RefundSpec.dfy` (SHA-256 `90a21c71…`) | `impl/Refund.dfy` proof | `dafny verify impl/Refund.dfy proposals/refund-gate/Bindings.dfy`, exit 0 | MACHINE-CHECKED | Dafny 4.11.0 verifier; ROADMAP.md:1449, `docs/stage8-refund.md` | replay by a second operator |
| Dafny contract R1-R5 | HOL functions `eligible`, `refund_fields`, `refund_render_fields` | none (`refund_fields_original_method` relates the hand-written AST only) | MISSING | OWNER_DECISIONS.md text 3 point 6; V-adversarial-validation.md H4 | a checked correspondence theorem |
| pinned definition texts (closure) | constants of `refund_profile_a_sl` | none; `imp4-0001` compares statement text only | MISSING | `imp4-0001.sml` line 11 | run `closure_export.sml`; pin by a second operator |
| ancestor names + hash strings | final theorem | `Theory.link_parents` at load | MACHINE-CHECKED | HOL kernel (Theory.sml:703-723) in `imp4-0001`, exit 0, `stdout.log` `CLOSURE_NODES 542` | none needed for strings |
| ancestor `.dat` bytes | the SHA-1 their children record | `walk_sha1_chain.py`, files present now, 541 nodes, 0 mismatch | TESTED-UNPROVED | X4, this machine, `walk_real.json` | `dat_guard` hook in the session that loads them |
| 95 forge `.dat/.sig/.sml` | earlier recorded SHA-256 | equality, 95 of 95 | TESTED-UNPROVED | `comparison*.json`; same agent family, same machine | independent replay |
| 470 upstream `.dat` (incl. 16 built in the replay, L3 models) | a pinned reference list | none | MISSING | `tooltree-compare-final-phase2.json` lists 16 new, no pins | pinned list from upstream builds by a second operator |
| heap `cake_compile_heap` | theories inside it | SHA-256 of the heap file only | ASSUMPTION (not approved) | `e4-0001/command.json` | rebuild of the heap from pinned sources with a record |
| tags of final theorem | no oracle, no hypotheses, 4 axioms | `clean`, `DB.axioms` sweep | MACHINE-CHECKED | HOL in `imp4-0001`, `stdout.log` | none |
| kernel `compute` and `disk_thm` | soundness of theorems | not visible in tags | ASSUMPTION (not approved) | std-thm.ML:1533-1559; FinalThm-sig.sml:150 | owner decision naming the HOL kernel trusted base |
| HOL code constant / `refund_file` | executable `__TEXT` and bitmaps | APPEND layout equality, EVAL in kernel | MACHINE-CHECKED | HOL kernel, `forge_refundImage` (image-0001 records); V "Checked and found sound" | in-HOL Mach-O reader |
| executable file | file read into HOL | `assert inputs[IMAGE] == 'b8ed5ec2…'` | TESTED-UNPROVED | `run_case.py`; agent runs | none beyond SHA |
| executable rest (`__DATA`, GOT, `__LINKEDIT`) | any theorem | none | MISSING | V M1 | in-HOL load-command check, or A6/A2 statement |
| executable file | binary run in the conformance suite | SHA check by the conformance script, 2,466 vectors, 0 findings | TESTED-UNPROVED | V "Checked and found sound"; agent run | admission boundary |
| executable file | binary that is deployed and run | none | MISSING | OWNER_DECISIONS.md text 3 point 5 | independent deployment-admission boundary |
| proof records | an independent recomputation | none (only same-machine replay) | MISSING | `summary.json` claim; W5 manifest `replays.independent` | clean and independent replays |

FIRST MISSING link: Dafny contract R1-R5 → HOL functions `eligible` / `refund_fields` / `refund_render_fields`. In the identity part, the first MISSING link is the pinned definition closure of the final theorem's constants.
