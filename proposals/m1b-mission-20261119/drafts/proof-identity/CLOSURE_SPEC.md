# Closure specification: strengthened proof identity check (X4 draft, 2026-11-19)

Purpose: OWNER_DECISIONS.md text 3 point 4: "include transitive definitions and assumptions, not statement text alone. Require exact dependency closure and independently validated content hashes."
Formats: `forge.closure-export/1` (made by `closure_export.sml`) and `forge.closure-manifest/1` (pinned). Checker: `check_closure.py`. This file extends the `proof_dependencies` part of the W5 manifest (`scratchpad/m1b/W5/m1_manifest_draft.json`); it does not replace W5's verifier. Suggested link: W5 `proof_dependencies` gets one field `closure_manifest: {locator, sha256}`.

## Elements the manifest must hold

(i) **Statement.** For the final theorem (`forge_refundSlideProfileA.refund_profile_a_sl`, and the same for `…_every_machine_run`): the canonical term (de Bruijn s-expression with every constant as `Thy$Name` and its full type) and the printed text. The canonical term is the compared object; the printed text is for people and is compared too.

(ii) **Definition closure.** Start with every constant and type operator in the statement and hypotheses. For each constant `(Thy, Name)`:
- if `Thy` is in the STOP set: record `CONST Thy$Name type STOP` and do not recurse;
- else: every theorem of class Def in `DB.definitions Thy` whose conclusion contains that constant: record `CONST … DEF Thy.defname`, record `DEF Thy.defname <canonical conclusion>` and its tag, and recurse into the constants and types of that conclusion;
- if none: `NODEF` (a primitive or a constant characterised by a non-Def theorem); allowed only because the manifest names it, so a person reviews each one.
Types: `TYPE Thy$tyop DEF Thy.tyop_TY_DEF | STOP | NODEF`, same recursion.
How in HOL (pinned tree `9783a499`): `HolKernel.find_terms is_const` (`src/postkernel/HolKernelDoc.sig:23`), `Term.dest_thy_const` (`src/prekernel/FinalTerm-sig.sml:47`), `Type.dest_thy_type` (`FinalType-sig.sml:18`), `DB.definitions` (`src/postkernel/DB.sig:30`), `DB.fetch` (`DB.sml:538`). `Theory.current_definitions` covers only the current segment and is not usable for loaded ancestors. The rule "conclusion contains the constant" over-approximates. That is safe: it can add definitions, never hide one.
STOP set: the HOL core theories and the pinned upstream CakeML and L3 theories (everything not `forge_*`). A STOP theory is not opened, but it stays in (iii) with its `.dat` hash and is bound to the upstream commit (HOL `9783a499`, CakeML and Poly/ML commits of `rebuild.py`). Every `forge_*` theory is opened.

(iii) **Ancestry.** Every theory in `T :: Theory.ancestry T` (`Theory.sig:45`) with its graph hash (`Theory.hash`, `Theory.sig:42`), its parents (`Theory.parents`), and, in the manifest, the SHA-1 and SHA-256 of its `.dat`. For the M1 final theorem that is 541 theories plus `min` (`CLOSURE_NODES 542`). 
Which files HOL actually read: HOL does not expose the `.dat` path of a loaded theory (`Theory.metadata_lookup` is not in `Theory.sig`; `Meta.loaded ()` in `tools-poly/poly/poly-init2.ML:188` gives module names only). Two sound ways:
- in-session: install the `dat_guard` hook on `TheoryReader.load_thydata_fn` (public, `src/postkernel/TheoryReader.sig`, `TheoryReader.sml:72-78`) before any theory is loaded. It calls `SHA1.sha1_file` on each path HOL reads, refuses a mismatch with the `.sml` hash, and logs `LOADED_DAT thy sha1 path`;
- outside: the generated `<thy>Theory.sml` reads `OS.Path.base (#(FILE)) ^ ".dat"`, so for every `.sml` given on the command line the `.dat` is the file next to it (`.hol/objs/`). Hash it before and after the run, like `run_case.py` already does for `.sig`/`.sml`.
Theories inside the heap are not read in the session. They are covered by the heap SHA-256 plus the hash chain: their graph hash strings must equal the pinned SHA-1, and a pinned `.dat` with that SHA-1 must exist. That binds the file, not the heap's memory; the heap stays trusted (see the analysis, section 5).
Why this pins content: each `.dat` records `(parent . SHA-1 of parent .dat)` (`Theory.sml:1102`, `:1128`), and `link_parents` (`Theory.sml:703-723`) refuses a parent whose (name, hash) is not in the graph. With the bytes of every read `.dat` checked, the final `.dat` SHA-256 fixes every ancestor's content. Checked on real files: `walk_sha1_chain.py`, 541 nodes, 0 mismatch (not at load time).

(iv) **Assumptions.** For the final theorem and for every DEF in (ii): oracles (sorted) and the hypothesis count. Allowed oracles: `DISK_THM` only. Hypotheses: 0. Axioms: the `DB.axioms` of every ancestor (the tag never shows axioms of disk theorems, `Tag.sml:82-89`); allowed: exactly `bool.BOOL_CASES_AX`, `bool.ETA_AX`, `bool.INFINITY_AX`, `bool.SELECT_AX`. Not visible and therefore named as trusted: kernel `compute` (`std-thm.ML:1533-1559`) and `Thm.disk_thm` (`FinalThm-sig.sml:150`).

(v) **Code constant to file.** The closure of (ii) reaches `refund_entry_pre` → `refund_image_mem` → `refund_file`, and `code`. The manifest must hold: the DEF records of `refund_image_mem_def`, `refund_file_def`, `code_def` (via (ii)); the executable SHA-256 `b8ed5ec2…` and size 238776; the slice table (file offset, length, SHA-256 of each slice; W5 `artifact.slices`). Inside the binding: `__TEXT` bytes 0-163840 and the bitmap 180248-200496 (kernel-checked APPEND layout). Outside: `__DATA`/`__DATA_CONST` 163840-180248 (GOT, 23 binds), `__LINKEDIT` 200496-238776, `LC_MAIN` entry offset (checked in ML only), `libSystem` and the dyld cache, and the way the file bytes enter HOL (ML reader, offsets from a Python tool). Also outside: how `code` was computed (`cv_compute`, no tag).

## Comparison rule

- Every record of the export (except `FORMAT`, `END`, and the machine-local path in `LOADED_DAT`) must occur in the manifest the same number of times, byte for byte, and the reverse. Any missing or extra record refuses. No normalisation except the stable sort done by the exporter.
- `TARGET` equal; exactly one `STATEMENT`; every `THM_TAG` oracle set ⊆ allowed; every hypothesis count 0; the `AXIOM` set equal to the allowed set.
- `ANCESTOR` set equal to the pinned `.dat` set; graph SHA-1 equal to pinned SHA-1; every `LOADED_DAT` SHA-1 equal to the graph SHA-1; every `.dat` file given is hashed by the checker (SHA-1 and SHA-256) and must equal the pins; a `LOADED_DAT` without a file to hash refuses.
- Truncated or malformed export refuses. Exit 0 only when no reason exists.

## Who computes the reference values

| Source of the pinned manifest | What exit 0 then means |
| --- | --- |
| Same agent family, same machine (today's `recorded` values) | Only "nothing changed since the producer wrote it down". A producer that substitutes a parent can re-pin (synthetic control c6a: exit 0). Not independent. |
| Clean replay: same operator, fresh machine or container from pinned sources | Rules out local drift and stale files; not producer substitution. |
| Second operator (a person or a separate trust domain, not the agent that writes proofs), from pinned sources, publishes the manifest signed or through a channel the agent cannot write | Independently validated. The `independent: true` flag counts only with that signature or channel; the flag in the JSON alone is a claim (c6b shows the checker can enforce the rule, not authenticate it). |
| Independent replay of the upstream theories (HOL, CakeML, L3) from their commits | Needed for the STOP theories' `.dat` pins to be independent too. |
