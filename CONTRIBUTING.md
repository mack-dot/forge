# Contributing to Forge

Thank you for helping. Forge has one unusual rule: **a contribution is accepted
because a checker established it, not because it looks right.** Everything
below follows from that.

## 1. Set up

Follow the five-minute quickstart in the [README](README.md#try-it-in-five-minutes).
You need macOS on Apple Silicon and Python 3.10.11 for the local profile, or the
Ubuntu x86_64 CI profile in `toolchain/linux-pins.json`. The gate rejects other
tool versions on purpose: evidence must name exactly what ran.

Keep tools inside `.toolchain/` (it is gitignored). Write gate output under
`build/` (also gitignored). Never commit downloaded tools or virtualenvs.

## 2. Check your change

| What you changed | Run | Expected |
| --- | --- | --- |
| A Dafny ledger implementation | `.toolchain/venv/bin/python gate/gate.py --impl <file> --evidence build/<name>.json` | `0` accepted, `1` rejected with the claims not established |
| The planted-bug controls | `.toolchain/venv/bin/python scripts/exit_stage_1.py --case planted-bugs` | `0` (all four bugs rejected by the gate, passed by the weak unit tests) |
| Docs only | Check every command you document by running it | Paste the real exit codes in your PR |

Exit codes mean: `0` the operation succeeded, `1` the gate rejected, `2` a
configuration or tool error. A script that *expects* a rejection returns `0`
when the rejection really happens. Keep these apart when you report results.

## 3. Open a pull request

- Fork, branch, commit, open a PR to `main`. You need no special access.
- Fill in the PR template. Paste the exact commands and their **actual** exit
  codes. "Should pass" is not evidence; a failure you report is useful.
- On a PR to `main`, the proof gate runs the trusted code from `main` against
  your changes as data, with a read-only token. For first-time and outside
  contributors, a maintainer approves the run first.
- Every change to `main` goes through a pull request. Once `.github/CODEOWNERS`
  is merged (PR #15), changes to trust-critical paths also need code-owner review.

## 4. Protected changes

`spec/`, `spec.lock`, `policy/` and `gate/` are protected. So are the
provenance workflows and the files bound by `gate/provenance/implementation.lock`.
Do not change them in an ordinary PR, and never change them to make a check
pass. Instead:

1. Open an issue with the "Propose a spec, policy or gate change" template:
   the behavior you want and a plain-English reason.
2. Write `proposals/<name>.md` with the **exact diff**, the reason, and any
   examples or counterexamples.
3. The owner approves the exact bytes (by hash). Only then is the change
   applied, and the approval is recorded.

The PR gate reports `UNAPPROVED_PROTECTED_CHANGE` for any pull request that
touches `gate/`, `policy/`, `spec/`, `toolchain/`, `schemas/`, `.github/`,
`spec.lock` or `AGENTS.md`. That rejection is expected: such a pull request
merges only after the owner's exact-byte approval.

A spec states human intent. Weakening a claim so an implementation passes is
the one change Forge exists to prevent.

## 5. Hard rules

- No `assume`, `{:axiom}`, `{:verify false}`, `Admitted`, `sorry`, axiom
  declarations or bodiless lemmas in implementations. The gate's audit
  rejects them; deliberately invalid fixtures live only in `bugs/` and tests.
- Never write a custom verifier, proof checker or SMT wrapper that judges
  correctness. Forge dispatches established tools and binds their results.
- Do not overclaim. Tested is not proved. Bounded checking is not an unbounded
  proof. Keep `end_to_end=false` unless every link is covered.
- [unsure.md](unsure.md) is append-only. Add a new entry with a new ID that
  refers to the old one; never edit, delete or reorder an existing entry.
- Pin every tool version. Put no timestamps in evidence.

## 6. Good first contributions

Look for issues labelled `good first issue`. Docs fixes that you have actually
run, new planted bugs that the gate must reject, and clearer rejection
messages are always welcome.

## 7. Security

Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).

## 8. License

Forge is licensed under the Apache License 2.0. By contributing, you agree that
your contribution is licensed under the same terms (Apache-2.0, Section 5).
