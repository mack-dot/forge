## What this changes

<!-- One or two sentences. Link the issue. -->

## Evidence

<!-- Exact commands you ran and their real exit codes. Paste failures too.
     "Should pass" is not evidence. -->

| Command | Exit code |
| --- | --- |
|  |  |

## Checklist

- [ ] I did not change `spec/`, `spec.lock`, `policy/`, `gate/`, `schemas/`,
      `toolchain/` pins or `.github/workflows/`. If I did, I opened a proposal
      first (see CONTRIBUTING.md, "Protected changes").
- [ ] No `assume`, `{:axiom}`, `{:verify false}`, `Admitted`, `sorry`, axiom
      declarations or bodiless lemmas in implementation code.
- [ ] Claims in docs stay within what was actually checked. Tested is not
      proved; `end_to_end` stays `false` unless every link is covered.
- [ ] I did not edit or reorder existing entries in `unsure.md`.
