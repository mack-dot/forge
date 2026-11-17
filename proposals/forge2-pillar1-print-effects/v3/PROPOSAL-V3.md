# Proposal version 3: gate ratification records and print-effect tracking

Date: 2026-11-17. Status: PROPOSAL. Not merged. A ratification record
that names this text has effect only when the record and this text are
on `main` by the owner's merge. `end_to_end=false`. Stage 12 is not
authorized by this text.

## Step A — the rule (bootstrap; needs the owner's explicit merge)

Files: `gate/approval.py`, `gate/ratification.py` (new),
`gate/incremental.py`.

A pull request that changes protected files passes the PR gate only if
the trusted base checkout holds a record
`governance/gate-ratifications/<id>.json` with:

- `tier`: the integer 0; `decision`: `ratified_as_written`;
  `end_to_end`: false;
- `files`: EVERY changed protected file with its old and its new
  SHA-256, equal to the real digests on both sides;
- `proposal` and `proposal_sha256`: a text in the trusted base;
- `controls`: files under `bugs/` with digests that the changed gate
  must reject. A control may not have the path of a planted bug of the
  trusted base.

Scope: files under `gate/` and `toolchain/`, except `gate/approvals/`
and `gate/provenance/`. One exception: a file named `spec.lock` whose
new bytes are its old bytes with the digests of ratified `toolchain/`
files replaced in one pass.

Floor controls, run in a tree made of the trusted checkout plus exactly
the ratified bytes: the changed gate rejects every trusted planted bug
and every control for a proof or audit reason; it accepts the trusted
`impl/Ledger.dfy`; its `protected_manifest` returns what the trusted
one returns for that tree; its `authorize` refuses a changed, an added
and a removed protected file.

The floor controls do NOT prove that the changed gate is not weaker.
The owner's review of the exact bytes is the safeguard. A record in the
candidate is never read.

## Step B — print-effect tracking (the first change under the rule)

Protected files: `gate/backends/dafny.py` and `toolchain/pins.json`,
`toolchain/linux-pins.json` (option `--track-print-effects`),
`gate/ContractBinding.dfy` (a caller without print effects),
`spec/refund/spec.lock` (new digest of `toolchain/pins.json`),
`gate/refund.py` (new digest of that lock).

Other files: `scripts/exit_stage_5.py` (class `effect_rejected`),
`bugs/print_effect.dfy`, `bugs/print_effect_marked.dfy`, and records
made again by real runs (`evidence.json`, Stage 5 and Stage 6 records).

Effect: a compiled method that prints is rejected by the pinned Dafny
(exit 2) and so by the gate (exit 1). Without the option the gate
accepts both planted print bugs.

## Not in this proposal

- `gate/provenance/implementation.lock` and the Stage 9 signed release.
  They pin files that step B changes. Their renewal needs a hosted
  signing run. Stage 9 is DEFERRED_TO_HOSTED_SIGSTORE_ON_PR.
- Any change of `main`'s coverage rule. With that rule a pull request
  that changes a file which no obligation lists ends as UNSUPPORTED
  (exit 3). Step B contains such files.
