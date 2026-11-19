# Refund-slice binding manifest: design extension (worker Z8, 2026-11-19). DRAFT

Extends `drafts/manifest/MANIFEST_DESIGN.md` (W5). The originals are copied unchanged to `orig/`.
Not evidence. M1-B OPEN. `end_to_end=false`. Changes no repository file.

## 1. The question

ONE verifier run (`verify_refund_bindings.py`) answers, fail-closed, for each of the 47 links of
`TOP_LEVEL_GRAPH.md` (sections 2 and 7; U5 split into U5a and U5b; X11e added):
which exact files are bound to the link, at which evidence class, from which stored record, and which links
and bytes have NO binding. It recomputes every digest. It does not run Dafny, HOL, Node or a build. Its last
line is `identity verified; proofs NOT re-run`, or `REFUSED; proofs NOT re-run`.

## 2. Classes (computed by the verifier, never read from the manifest)

| Class | Rank | The verifier gives it when |
| --- | --- | --- |
| SOURCE_PROOF (Dafny source proof) | 3 | a `dafny_proofs` entry of kind `source` passes every identity check AND one stored run record of a known kind shows the expected exit, the expected summary line, and the digests of the files it names equal the closure now; or a Slice 1 record of kind `slice1_dafny_verify`/`slice1_refund_gate` with exit 0 that names the current bytes |
| MODEL (proof about a model) | 3 | a HOL record (`hol_case`, `m1r1_command`, `u294_command`) with exit 0, its log digest consistent with its own record, and the named theorems as `CHECKED`/`FORGE_THEOREM` lines; or the F2.0 protocol-model record |
| TEST | 2 | a test record (`slice1_suite`, `conformance`, `y9_extract_result`) that passes and names the current bytes; or the export byte equality |
| ASSUMPTION | 1 | an `assumptions` entry; approved ones need a pinned decision record that contains the marker |
| REPORTED_ONLY | 0 | only a sentence in a pinned report (the quote must be in the file) |
| UNBOUND | 0 | no evidence, or only `unbound` items |

The record kinds and the class each can support are a table in the verifier (`KIND_CLASS`). A stated class
above the computed one: `CLASS_OVERSTATED`. Any other difference: `CLASS_MISMATCH`. Both refuse.

## 3. New manifest entries (format `forge.m1b.refund-binding-manifest/1`)

- `toolchain`: the whole Dafny tree `.toolchain/dafny-4.11.0/dafny` (290 files, self-contained .NET runtime
  and Z3 inside) as a set digest; the launcher and `z3-4.12.1` pinned separately and required to be inside
  the tree; `gate/backends/dafny.py` pinned; the gate `OPTIONS` list is read from it (Python `ast`).
- `dafny_proofs[]` (required: S3, S3a, U5a): root, entries, `include_closure` (computed by following every
  `include` line from the entries; a path that leaves the root is refused), `include_closure_digest`,
  `folder_files` + `folder_digest` (every file under the root: the audit reads all `*.dfy`), `pins`,
  `approved_copies`, `argv` = `{dafny} verify <entries> <gate OPTIONS with {z3}>` exactly, `expected_exit`,
  `expected_summary`, `controls[]` (diff or mutant file pinned, expected exit; the set must equal the
  runner's `CONTROLS`/`MUTANTS` dict), `runner` (its 64-hex literals must be a subset of the pins),
  `runs[]` (stored records), and for S3a `derived_from` (the stored classic diff applied in Python to the
  S3 file must give the S3a file; all other files equal).
  Set digest = SHA-256 of the sorted lines `path<TAB>sha256<LF>`.
- `recorded_runs[]`: HOL, Slice 1, F2.0, U294, conformance and extraction records with `bound_files`.
- `executable`: whole-file SHA-256 and size; the two slices with offset, length, SHA-256 AND the symbol pair
  each is derived from; the pinned symbol parser (`drafts/macho-extraction/y9_macho.py`, loaded from its
  hashed bytes) recomputes the offsets from the file's own symbol table; `outside_slices` must equal the
  computed complement. The whole-file hash and each slice hash are separate checks.
- `export`: FlatCore in the S3 closure, the export input, the 3,621-byte output, the export record: input =
  closure file; record input/output digests and exit 0; the HOL import (S5) must name the same output digest.
- `assumptions[]`, `reported[]` (sentence-only evidence), `unbound[]` (required: C run-time ranges, GOT
  binds, `sink.ts`, `minter.ts`, compiled JavaScript core, Node, SQLite; also stub, `__LINKEDIT`, dyld,
  the U294 exporter build). Ranges must not overlap a slice.
- `claims[]`: one per required link: `link`, `stated_class`, `evidence` (ids). A missing link, a duplicate,
  a dangling id, an unknown key or a level-like key (`computed…`, `level`, `verdict`) refuses.

Every record also gets a computed storage label (git `ls-files`/`check-ignore`, read only): `tracked`,
`ignored`, `untracked`, `scratch`. And a binding count: how many closure files the record itself names.

## 4. Evidence inventory of the MACHINE-CHECKED rows (strict)

| Row | Stored record that proves the run (SHA-256 prefix) | Storage | Finding |
| --- | --- | --- | --- |
| S2 | Slice 1 `records/evidence.json` (`c7f2f41c…`), `refund_gate.exit_code 0` | tracked | the section-7 limit run (`expect false`, exit 0, 6 verified, orchestrator): sentence only |
| S3 | `proofs/linked-refund/records/m1b-linked-refund-run2.log` (`0d77223a…`) + `build/m1b-linked-refund/attempt-0002/result.json` (`e474ec51…`) | tracked + ignored | the record names 4 of 33 closure files; FlatCore is NOT among them: the present `run_check.py` (with the FlatCore pin) never ran. W9 attempt 04 (scratch) names 33/33, but its closure list was written 9 min after the run |
| S3a | Y10 `runs/S3a-noHex/{exit,out,sha}.txt` | scratch | names 4/33 files; the S3a closure (`Strings.dfy` `b1c3769e…`) exists in scratch ONLY; the repository diff is a classic diff with NO file name; the repository copy `S3a-worker-verify-out.txt` is EDITED (path replaced), not byte-equal; orchestrator's verify run: sentence only |
| S5 | U294 `hol-0004/command.json` (`f9a364ea…`), `bridge-0001/command.json` (`71881cdc…`), exit 0 | untracked (copy from the backup branch) | `source_compiled_fields` is in `bridge-0001`, not in `hol-0004` |
| X1, X2, X14, V1 | M1R-1 `commands.json` (`91cc9f86…`) labels T05, C32, C34, T06, C42; logs consistent with the replay `MANIFEST.json` | tracked | X1: the graph names no theorem; I chose `refund_verified_spec` (a guess) |
| X3, X4 | `final-cases/{e4-0001,fs-r4-0001}/command.json`, `actual_exit 0`, stdout digest equal | tracked | none |
| U1 | Slice 1 `evidence.json`, `verify.exit_code 0` | tracked | none |
| U4 | F2.0 `summary-attempt-0002.json` (`5c7a13af…`) | tracked | none |
| U5a | Y7 `logs/result-all.json` + `main.log` (`EXIT 0`, 5/5 files, 9 control exits) | scratch | repository `records/orchestrator-verification.csv`: 56 `Passed` rows, NO exit code, NO input digest: it binds no bytes; the stored runner `run_y7.py` has `ROOT = Path('<HOME>/forge')` and calls `dafny_one.sh`, which is not in the repository: it cannot run as stored |
| V1 (2nd extraction) | `drafts/macho-extraction/extract_result.json` | untracked | a pass flag, no exit code; the orchestrator's re-check record (`scratch/y9-rerun.txt`) is a CRASH traceback (`IndexError`), not a pass. My verifier re-derives the offsets from symbols: equal |
| E3 | none | — | ROADMAP sentence only (`run 44454558079 |1|REJECTED`); computed REPORTED_ONLY, not MACHINE-CHECKED |

TESTED-UNPROVED rows without a stored record that my verifier can read: X13, V3, V6, V7 (REPORTED_ONLY);
U7's runs exist in `scratch/m1b/Y6/results/` but no record kind reads them (a verifier limit).

## 5. Controls (`run_binding_controls.py`; results in `controls-result.json`)

A snapshot of all inputs is taken first; live documents (graph, owner decisions, ROADMAP) are re-pinned to
it. Each control copies the snapshot into its own mirror and changes one thing. All 23 ran as expected:
baseline exit 0; 22 controls exit 1 with their own code (C01 to C16, see the file).

## 6. Limits

- Who pins: the reference values are computed by Z8, the same model family on the same machine that produced
  the evidence. A pass shows CONSISTENCY between files and records, NOT independence and NOT truth.
- The class is a statement about stored records, not about proofs: no proof was re-run. A record can be
  forged by whoever writes the scratch folder or the work tree; only tracked files have history.
- An independent party would re-run: `run_check.py` (current version) and the Y7 runner on a clean clone
  with its own Dafny 4.11.0 download (compare the tree digest), the M1R-1 replay, the U294 export with a
  rebuilt exporter, and its own Mach-O parser; then pin its own values and compare with this manifest.
- To be trusted, the manifest and the verifier must live on a protected path (for example under `gate/`)
  with an owner signature made with a key the agent cannot use. That is an unapplied proposal only; no
  such path or key exists (links S1, E2, E4, V5 stay MISSING).
- Live documents changed during this run (commit `1b222b84` landed): the first control run refused the
  baseline with `DIGEST_MISMATCH` on `OWNER_DECISIONS.md` and `TOP_LEVEL_GRAPH.md`. Pins to moving documents
  must name a commit.
