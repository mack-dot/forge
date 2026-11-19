# M1 evidence manifest: design draft (W5, step II, 2026-11-19)

Draft in the scratch folder. Not evidence. It changes no file of the
repository and no protected path. M1 is OPEN. `end_to_end=false`.

## 1. The question and the rule

The manifest lets a verifier answer one question:

> Is this exact artifact covered by this exact proof, against this exact
> approved contract, under these exact assumptions?

Four rules:

1. The CALLER names the level (`--level M1-A` or `--level M1-B`). The
   manifest never states a level. A key that looks like a level
   (`level`, `verdict`, `achieved`, `claim_status`, `m1_status`,
   `closed`) is a refusal (`PRODUCER_STATED_LEVEL`).
2. The verifier computes the supported level from the evidence fields
   only. It prints the highest supported level: `none`, `M1-A` or `M1-B`.
3. Every comparison fails closed. A missing key, an unknown key, a null
   value, a file it cannot read, a digest that is not 64 lowercase hex
   characters, or a different value is a refusal. A crash is exit 2 and
   never a pass.
4. The manifest binds bytes by SHA-256. It adds no new cryptographic
   protocol, key or signature. The only other hash is SHA-1, and only
   where HOL4 itself writes it (parent links inside `.dat` files). The
   verifier pins each of those files by SHA-256 too.

Exit codes: 0 = the requested level is fully supported; 1 = refused,
with reasons; 2 = crash.

## 2. Locators

Each bound file is `{locator, sha256}`. A locator has one of three kinds:

| Kind | Form | Read by |
| --- | --- | --- |
| `file` | path relative to `--root` (no `/` at the start, no `..`) | plain file read |
| `git` | `{commit: <40 hex>, path}` | `git cat-file blob <commit>:<path>` (read-only). A branch name is refused |
| `toolchain` | path relative to `--toolchain-root` | plain file read |

The integrity of a file never depends on the locator. The verifier
computes the SHA-256 of the bytes and compares it with the manifest.
If git or the folder returns other bytes, the check fails.

## 3. Fields

Column "Missing or unknown" says what the verifier does. "Refuse" means
both levels unless the row says otherwise.

| Field | Source of truth | How the verifier checks it | Missing or unknown |
| --- | --- | --- | --- |
| `manifest_format` | this design | equals `forge.m1.evidence-manifest/1` | refuse |
| `end_to_end` | `README.md`, owner rule | must be `false` | refuse |
| `approved_spec.contract`, `.protocol` | `spec/refund/RefundSpec.dfy`, `protocol.md` | SHA-256 of the file equals the manifest AND equals the digest in the table of the approval record | refuse (`SPEC_NOT_APPROVED` or `DIGEST_MISMATCH`) |
| `approved_spec.approval_record`, `.approval_commit` | `proposals/refund-decision.md` (owner's conversational approval of commit `e3aa546f…`) | record pinned by SHA-256; the commit is named in it; the table rows give the approved digests | refuse |
| `approved_spec.lock` | `spec/refund/spec.lock` | pinned; its `spec_sha256`, `protocol_sha256` equal the contract and protocol digests; its `dafny_build` equals `toolchain.dafny_build` | refuse |
| `implementation_sources[]` | five roles: `approved_assess_impl` (`impl/Refund.dfy`), `boundary_dafny` (`Boundary.dfy`), `hol_dafny_ast_program` (`forge_refundScript.sml`), `whole_program_script`, `compile_application_script` | the role set is exact; each file is read and its SHA-256 compared | refuse |
| `final_theorem.theory`, `.name` | the HOL `.dat` of the final theory | the name is a stored theorem (class 2) in the `.dat`, and `val <name> : thm` is in the `.sig` | refuse (`THEOREM_NOT_FOUND`) |
| `final_theorem.sig` | `.sig` file | pinned; equal to the `.sig` digest in the replay comparison record | refuse |
| `final_theorem.statement_log`, `.statement_sha256` | the run's `stdout.log` (HOL printer output after `CHECKED <name>`) | the verifier extracts the printed block, collapses white space, compares the SHA-256 | refuse (`STATEMENT`) |
| `final_theorem.premises[]` | the printed statement | the antecedent, split at top-level ` ∧ `, equals the listed premises in order | refuse (`PREMISES`) |
| `proof_dependencies.forge_theories[]` | `.dat` files; replay records | each `.dat` pinned; `.dat` and `.sig` digests equal the replay comparison record (else `STALE_PROOF_RECORD`); the theory name inside the file equals the entry | refuse |
| parent links | the `(theory ("name" ("parent" . "<sha1>")…))` header of each `.dat` | the SHA-1 of the parent `.dat` equals the child's record. The walk starts at the final theory. The listed set must equal the reached set exactly | refuse (`PARENT_LINK`, `DEPENDENCY_NOT_BOUND`, `CLOSURE_MISMATCH`) |
| `proof_dependencies.upstream_parents[]` | CakeML and HOL theory files of the pinned build | pinned by SHA-256; SHA-1 equals the child's record; the set equals the upstream parents reached | refuse |
| `proof_dependencies.allowed_tags` | HOL tag policy | must be exactly `["DISK_THM"]`; every stored entry of every bound `.dat` has tags inside this set (empty is allowed) | refuse (`ORACLE_OR_TAG`, `WEAK_TAG_POLICY`) |
| `proof_dependencies.replay_comparisons[]` | `comparison.json`, `comparison-phase2.json` (M1R-1, M1R-2) | pinned; every theory row `REPLAYED` and `equal` | refuse |
| `toolchain.pin_source`, `polyml_commit`, `hol_commit`, `cakeml_commit` | a pin file | pinned; the three commits equal the pin file; the pin file must be under `toolchain/` (protected) | refuse (`TOOLCHAIN_MISMATCH`, `PIN_NOT_PROTECTED`) |
| `toolchain.dafny_build` | `spec/refund/spec.lock` | equal | refuse |
| `toolchain.backend_config`, `.compile_theorem` | compile theorem `refund_arm8_compiled` and its run log | log pinned; it has `FORGE_ORACLES DISK_THM`, empty `FORGE_AXIOMS`, `FORGE_HYPOTHESES 0`, and a statement that starts `⊢ backend$compile <backend_config>`; the theorem is stored in a theory inside the closure; `refund.S` pinned | refuse (`COMPILER_CONFIG`) |
| `artifact.file`, `.size` | the executable | SHA-256 and byte count | refuse (`DIGEST_MISMATCH`, `ARTIFACT_SIZE`) |
| `artifact.slices[]` | code (offset 16592, 130,436 bytes) and bitmaps (offset 180248, 20,248 bytes = 2,531 words) | the slice of the file has the listed SHA-256; the named HOL theorem (`refund_file_code`, `refund_file_bitmaps`) is stored in the image theory; the image theory is in the closure | refuse (`ARTIFACT_SLICES`, `ARTIFACT_NOT_LINKED`) |
| `assumption_profile.profile`, `.items[]` | `OWNER_DECISIONS.md` Q1 to Q5 | profile is `A`; the item ID set equals the set FIXED IN THE VERIFIER (13 items); each item `APPROVED`, has a `decision_ref`, and has `verified: false` | refuse (`PROFILE`) |
| `assumption_profile.decision_record` | `OWNER_DECISIONS.md` | pinned | refuse |
| `assumption_profile.premise_ledger` | step I.3 ledger | every premise maps to at least one profile item; status `REVIEWED`; record pinned | refuse (`PREMISE_LEDGER`) |
| `assumption_profile.conditions[]` | Q3c (file reader and offset tool) | exactly one condition `A-Q3C`; status `VALIDATED`; record pinned and restates the artifact digest | refuse |
| `obligations[]` | compiler, initialization, slide obligations | each `DISCHARGED` or `APPROVED_ASSUMPTION` | refuse (`OBLIGATION_OPEN`) |
| `open_issues[]` | review findings | each `RESOLVED` | refuse (`OPEN_ISSUE`) |
| `replays.chain_same_machine` | M1R-1, M1R-2 | `PASSED`; record pinned | refuse |
| `replays.recorded_cases_158`, `.clean` | step I.4a; a future clean replay | `PASSED`; record pinned; the record restates `status` and `artifact_sha256` | refuse |
| `replays.independent` | a future replay on another machine by another operator | as above | refuse M1-B only |
| `contract_link.status` | `NOT_ESTABLISHED` < `REVIEWED` < `MACHINE_CHECKED` | M1-A needs at least `REVIEWED`; M1-B needs `MACHINE_CHECKED` | refuse (`LINK_NOT_ESTABLISHED`, `LINK_METHOD_WEAKER`) |
| `contract_link.review` | a dated review record | pinned; names the spec and artifact digests; reviewer named by the owner and not the author; rows 1 to 18 each once, each `HOLDS` and `CLOSED` | refuse M1-A |
| `contract_link.mechanical` | Dafny half record; HOL link theorem | Dafny record pinned, exit 0, `VERIFIED`, names the approved spec digest; HOL theorem stored in a theory inside the closure of the final theorem | refuse M1-B |

A "record" for a future status (review, ledger, Q3c validation, replays,
Dafny half) is a JSON file that restates its own `status` and the
`artifact_sha256`. So a record for another artifact or another state does
not fit. This is a proposed record format; no such record exists yet.

## 4. How a statement is bound

Three layers, from strong to weak:

1. The `.dat` file holds the stored term of every theorem, its tags and
   its dependency list. Its SHA-256 binds the exact statement. The
   verifier reads the structure only (names, classes, tags, parents). It
   does not decode the term.
2. The `.sig` file names the exported theorems.
3. The printed statement in the run log is the HOL printer's text of the
   same theorem. Its digest binds what a person reads. The verifier
   checks that the premise list equals the printed antecedent.

Limit: the verifier does not prove that layer 3 is the printing of the
term in layer 1. That rests on the HOL run that wrote both. A second
verifier could decode the term table of the `.dat` and compare.

## 5. Claim levels

The owner's words (OWNER_DECISIONS.md, text 2) as machine rules. The
verifier computes `common`, `A-only` and `B-only` reasons.
`M1-A` is supported when `common + A-only` is empty. `M1-B` is supported
when `common + A-only + B-only` is empty.

| Requirement | M1-A | M1-B |
| --- | --- | --- |
| all identity checks of section 3 (spec, sources, theorem, closure, toolchain, artifact) | yes | yes |
| Profile A exactly, every item approved, ledger reviewed, Q3c validated | yes | yes |
| no open obligation, no open issue | yes | yes |
| chain replay, 158 recorded cases, clean replay: PASSED | yes | yes |
| contract link at least REVIEWED (18 rows HOLDS by an owner-named non-author) | yes | yes (MACHINE_CHECKED is stronger) |
| contract link MACHINE_CHECKED (Dafny half + HOL theorem in the closure) | no | yes |
| independent replay PASSED | no | yes |

Proposal for the owner: M1-A requires the clean replay; only M1-B
requires the independent replay (mission acceptance criterion 5). This
split is my reading. The owner may move the clean replay or the
independent replay between the levels.

For M1-B the final theorem should be the composed theorem
(approved contract to machine code). Then the link theorem is inside its
closure, and the closure check binds it. The verifier checks that the
link theorem exists in the closure. It does not check what the link
theorem says. A person must read that statement (layer 3).

## 6. What the verifier says today

Real exit codes are in `controls-result.txt`. For the unchanged draft
manifest, both levels: exit 1, highest level `none`. Reasons:
`PIN_NOT_PROTECTED`, `PREMISE_LEDGER` (DRAFT), A-Q3C `NOT_DONE`,
`OBLIGATION_OPEN` (O4), three `OPEN_ISSUE` rows, 158 cases `RUNNING`,
clean replay `NOT_RUN`, `LINK_NOT_ESTABLISHED`; and for M1-B also
independent replay `NOT_RUN` and `LINK_METHOD_WEAKER`.

Every identity check that can run today passes: spec and protocol
digests equal the approved digests; five sources; 71 Forge theories of
the closure (55 read from git commit `c003a982…`, 16 from untracked
`results/` files), 85 Forge-to-Forge parent links and 24 links to 18
upstream parents (from the local `.toolchain/` build), all by SHA-1 and
SHA-256; tags; the printed statement and its 11 premises; the compile
record and backend configuration; the executable and both slices.

Observed during the run: `OWNER_DECISIONS.md` (untracked) changed twice
while I worked. The verifier refused at once with `DIGEST_MISMATCH` on
`assumption_profile.decision_record`. The draft manifest was rebuilt
from the current file. A decision record must be a tracked, merged file
before any level can be claimed. `run_controls.py` takes one snapshot of
every input file at its start and re-pins only that record to the
snapshot, with a printed note.

Defect found by the controls and repaired: in the first control run a
null `artifact.file` made the verifier crash (exit 2, `AttributeError`).
A crash is not a pass, but it is not a reasoned refusal either. The
verifier now checks the shape of every pinned pair before it reads any
file, and refuses with `MISSING_EVIDENCE`.

## 6a. Controls

`run_controls.py` has two baselines. REAL is the draft manifest. It must
be refused at both levels. SYNTHETIC is the same manifest with every gap
filled by stand-in records in the scratch folder. They are marked
`SYNTHETIC STAND-IN, NOT EVIDENCE`. That baseline must be SUPPORTED. It
shows that the verifier can pass, so a control's refusal comes from the
control and not from a verifier that always refuses. Each control
changes one thing. On SYNTHETIC it must give exit 1 and its own reason
code, and that code must be new compared with the baseline. Controls:
substituted artifact (one byte, digest unchanged; and digest re-pinned),
stale proof record (older digest; and a changed `.dat` with its digest
re-pinned), weaker method (REVIEWED link for M1-B; M1-A must still pass
on SYNTHETIC), unapproved spec change (one byte, digest re-pinned),
changed CakeML pin, changed backend configuration, missing field,
unknown field, a producer-stated level, a null artifact, and a swapped
upstream parent.

## 7. What stays trusted

- The verifier code, the Python interpreter and its `hashlib`.
- SHA-256 (second preimage resistance). SHA-1 only inside HOL's parent
  links, each also pinned by SHA-256.
- The `.dat` structure reader of the verifier (a small S-expression
  reader; it reads names, classes, tags and parents; it does not decode
  terms). Its reading of an empty tag list as "no oracle" is an
  inference from the HOL format, not a checked fact.
- The HOL4 kernel, its `compute` extension used by the cv translator,
  Poly/ML and the HOL printer, for every stored theorem and printed text.
- The upstream ancestry above the 18 direct upstream parents (about
  1,900 CakeML and HOL theories): bound only by the three pinned commits
  and the local build. Not walked.
- The ML file reader and the offset tool of U389 (Q3c, conditional).
- The person who approved the spec (a conversational approval recorded
  in `proposals/refund-decision.md`, not a signature), and the owner's
  decision texts (inferred to be the owner's, U473).
- git as a store of bytes only (the SHA-256 is checked after reading).

## 8. A second independent verifier

It would need: this design and the record formats (not the code); its
own SHA-256 and SHA-1; its own `.dat` reader written from the HOL4
source of the theory-data format, ideally with a term decoder so that it
can compare layer 1 with layer 3; its own copy of the Profile A item set
from `OWNER_DECISIONS.md`; the files (git commit `c003a982…` and the
untracked `results/` and `.toolchain/` files, or a clean replay that
writes them again); and agreement with this verifier on every control
of `run_controls.py`. It should be written by another person or team
in another language.
