# A4 link package (worker report, condensed by Orchestrator A; HOL NOT RUN)

- Run folder `run/attempt-0001/` built per `drafts/link-contract/RUN_PLAN.md` section 1. Every planned SHA-256 matches.
  `go.sh` (one function per case: H0 H0p R1 R2 R3 I1 H1 H2 NC1–6 PC1 NS1–3 H4 NR1 E0 E0r), `check.py`, `PASS_CRITERIA.md`.
- Call `bash …/go.sh <CASE>` only (never put a heap path on the command line: the guard's `pgrep -f` would match).
- Plan defects (D1–D6): the runner does not hash the export (go.sh now does); a signal becomes exit 1 in the runner;
  CHECKED records span lines; marker `ELIGIBLE_LINK_COMPLETE` missing from the runner list; U294 recorded cwd is
  `forge_refund_call_experiment`, not the plan's; pgrep self-match.
- Fallback `forge_refundExportedContractScript_v2.sml` (tactic-only; statements byte-identical) for a second attempt.
- Exporter identity: export `58154ddf…` made by `dotnet DafnyDriver.dll bake` of a patched fork from source `a89484e3`;
  the build folder `.toolchain/experiments/refund-dafny-frontend-20261104` does not exist today: the source-to-export
  binding is a RECORD only. Class: ASSUMPTION (TESTED-UNPROVED by D12).
- Residual after S6: "Dafny clause k ⇔ HOL formula k under β" (β: strings as the same code list, chars < 256;
  unbounded integers both sides). Class: ASSUMPTION (S4+S7 merged).
- Composition: C7 (HOL) → bridge (S4+S7+β) → S3 (Dafny refinement) → Uniqueness, PostIsApproved. Two kernels and a bridge;
  not one theorem. No amount-0 witness in C9 (gap G8).
- Edge classes now: C1–C9, H4: MISSING until H1, H2, H3, H4, NR1 pass. S5 replay: MISSING. S3: MACHINE-CHECKED (Dafny).
