# Step G8: a binding manifest for the refund slice and its verifier (Z8, Opus; Python only; no proof was run again)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z8 report: refund-slice binding manifest (DRAFT; M1-B OPEN; end_to_end=false)

I ran no Dafny, no HOL, no Node and no build. I changed no repository file. My git use was read-only (`ls-files`, `check-ignore`, `show`, `status`).

### Findings
1. **E3 has no stored record.** Its only evidence is a ROADMAP sentence (`run 44454558079 |1|REJECTED`). The verifier computes REPORTED_ONLY for it, not MACHINE-CHECKED.
2. **S3: the current `run_check.py` has never run.**
   - The stored record (`records/m1b-linked-refund-run2.log` plus the git-ignored `build/.../attempt-0002/result.json`) names only 4 of the 33 closure files. FlatCore is not among them.
   - W9's attempt 04 (scratch only) names all 33, but its closure list was written 9 minutes after the run.
3. **S3a's closure is in scratch only.** That closure is `Strings.dfy` without the HexConversion module (`b1c3769e…`). Problems with the stored evidence:
   - The repository diff is a classic diff with no file name.
   - The repository copy `S3a-worker-verify-out.txt` was edited (path replaced), so it is not byte-equal to the original.
   - The orchestrator's verify run exists only as a sentence.
   - My verifier applies the diff in Python and confirms the derivation.
4. **U5a has no byte-binding record in the repository.**
   - `records/orchestrator-verification.csv` has 56 `Passed` rows but no exit code and no input digest.
   - The stored `run_y7.py` cannot run as stored: `ROOT = Path('<HOME>/forge')`, and it calls `dafny_one.sh`, which is not in the repository.
   - The only byte-binding record is Y7's scratch `result-all.json` plus `main.log` (EXIT 0, 5 of 5 files, 9 control exits).
5. **V1, second extraction:** `extract_result.json` holds a pass flag only, with no exit code. The orchestrator's re-check record `scratch/y9-rerun.txt` is a crash (`IndexError`), not a pass. My verifier derived the offsets again from the symbols, and they are equal.
6. **S5:** `source_compiled_fields` is in `bridge-0001`, not in `hol-0004`. Both records sit in untracked `results/`.
7. **No readable stored record:** for X13, V3, V6 and V7 I found no record that my verifier can read, so they compute REPORTED_ONLY. U7's runs exist in `Y6/results`, but my verifier has no record kind for them (my limit).
8. **Documents changed during my run.** Commit `1b222b84` landed while I worked. My first control run refused the baseline with DIGEST_MISMATCH on `OWNER_DECISIONS.md` and `TOP_LEVEL_GRAPH.md`. Pins to moving documents must name a commit. The controls now take a snapshot first.
9. **Compiled JavaScript core:** the recorded `721b4d06…` was not found on disk.

### Files (all in `<session scratch folder>/m1b/Z8/`)
- `orig/`: the 5 original manifest files, byte-equal copies.
- `parser/y9_macho.py`: a copy of the parser. The verifier loads the repository copy from its hashed bytes.
- `BINDING_DESIGN.md`: the schema, the class rules, the inventory table and the limits.
- `make_binding_manifest.py`: computes every digest from disk.
- `refund_binding_manifest.json` (`9a199e5d…`).
- `verify_refund_bindings.py` and `run_binding_controls.py`.
- Outputs: `real-verdict.txt`, `controls-stdout.txt`, `controls-result.json`, `ctl/*/verdict.txt`.

**Key digests:**
- Dafny tree: `d0c1a9a9…`, 290 files.
- dafny `5d02cbb8…`, z3 `7d15df1e…`.
- Closure digests: S3 `691547b1…`, S3a `c6d90bb3…`, U5a `8cc14980…`.
- argv = `{dafny} verify <entry>` plus the gate OPTIONS read from `gate/backends/dafny.py`.

### Commands run
| command | exit |
| --- | --- |
| `python3 -I make_binding_manifest.py <repo> <scratch> …` | 0 |
| `python3 -I verify_refund_bindings.py refund_binding_manifest.json --root <repo> --scratch-root <scratch>` | 0 (final; it prints "identity verified; proofs NOT re-run") |
| `python3 -I run_binding_controls.py <repo> <scratch>` (first run) | 1 (baseline refused because the live documents changed) |
| same, final run | 0: baseline exit 0, and all 22 controls exit 1 with their own reason code |

Controls (each refused for its own reason):
- C01 LinkedRefund byte, C02 FlatCore byte, C03 Wrappers.dfy byte: DIGEST_MISMATCH.
- C04 byte in the code slice: SLICE_DIGEST and WHOLE_FILE_DIGEST.
- C05 byte at 152900, outside both slices: WHOLE_FILE_DIGEST only.
- C06 swapped SinkCore: DIGEST_MISMATCH.
- C07 stale log (W9 attempt 03): STALE_RECORD.
- C08 control diff deleted: MISSING_FILE. C08b control entry removed: CONTROL_SET.
- C09 extra file in the folder: EXTRA_FILE. C09b closure lists a file the walk does not reach: MISSING_FILE.
- C10 MODEL for X12: CLASS_OVERSTATED. C10b TEST for E3: CLASS_OVERSTATED.
- C11 to C11c (claim, proof entry, unbound item removed): MISSING_REQUIRED_ENTRY. C11d executable removed: MISSING_FIELD.
- C12 byte change plus every manifest digest re-pinned: STALE_RECORD and RUNNER_PIN.
- C13 level-like key: PRODUCER_STATED_LEVEL. C14 tool digest: TOOL_MISMATCH. C15 argv weakened: ARGV_MISMATCH. C16 S3a derivation: DERIVATION.

### Limits
- I computed the reference values myself: same model family, same machine. A pass therefore proves consistency, not independence and not truth.
- Records in scratch and in the work tree can be rewritten. Only tracked files have history.
- An independent party would re-run, on a clean clone with its own tools and its own pins:
  - the present `run_check.py` and the Y7 runner;
  - the M1R-1 replay;
  - the U294 export, with a rebuilt exporter;
  - its own Mach-O parser.
- To be trusted, the manifest and the verifier must sit on a protected path with an owner signature made with a key the agent cannot use. That is a proposal only; nothing was applied.

### Could not determine
- Who made `build/.../attempt-0002`: I inferred the orchestrator from the build/ location; this is not confirmed.
- Which X1 theorem is the "translator certificate": I chose `refund_verified_spec`, which is a guess.
- Whether stored records for X13, V3, V6 and V7 exist somewhere I did not search.

| step | status | evidence or blocker |
| --- | --- | --- |
| (1) inventory | done | BINDING_DESIGN.md §4 |
| (2) schema | done | manifest + §3 |
| (3) verifier | done; real exit 0 | real-verdict.txt |
| (4) controls | 23/23 as expected | controls-result.json |
| (5) limits | stated | §6 |

| link id | proposed class | evidence |
| --- | --- | --- |
| E3 | MISSING (stored record) | ROADMAP sentence only |
| S3 | MACHINE-CHECKED (stays) | stored record binds 4/33 files; current runner not run |
| S3a | MACHINE-CHECKED, scratch only | closure not in the repository |
| U5a | MACHINE-CHECKED, scratch only | repository CSV binds no bytes |
| V1 (2nd extraction) | TESTED-UNPROVED | flag only; orchestrator re-check crashed |
| V7 | TESTED-UNPROVED (draft) | this verifier; same agent family |
| others | unchanged | real-verdict.txt table |
