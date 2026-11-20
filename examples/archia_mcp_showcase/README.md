# Archia MCP airlock: live showcase

Status: FINITE TEST of an unproved Rust proxy (NATIVE CHECK). Nothing here is proved.
The policies are NOT spec-cleared. No clearing check runs in the showcase.

## Run

    python3 examples/archia_mcp_showcase/run_showcase.py [--binary PATH] [--work DIR] [--json FILE]
            [--flood-gib N] [--no-color] [--no-pause]

- `--binary`: the proxy binary. Default: the script builds it into the work folder with
  `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/mcp_proxy/main.rs`.
- `--work`: a fresh (empty or new) folder for stores, keys and logs. Default: a new temporary folder.
  The script prints its path.
- `--flood-gib`: size of the Beat 3 flood line. Default 10. The bytes go through a pipe in 1 MiB chunks.
  They are never held in memory and never written to disk.
- `--json FILE`: `{"checks": {...}, "metrics": {...}, "beats": {...}}`. `checks` and `beats` hold only
  values that do not change between runs. Times, RSS, state hashes and chain values go under `metrics`.
- `--no-color`: no ANSI colors (also when `NO_COLOR` is set). `--no-pause`: no 1 s pause between beats.
- Exit code: `0` every check is true; `1` a check is false or a beat broke; `2` setup error.

Needs: Python 3 (stdlib only), `rustc` (only without `--binary`), `/usr/bin/ssh-keygen`, `/bin/ps`.
Measured on one M1 Mac: about 8 s with `--flood-gib 1`, about 11 to 13 s with the default 10 GiB.

## What each part does

| Part | Action | Witness of each check |
| --- | --- | --- |
| Layer 01 | Prints the policy and facts files, their SHA-256, and the bounds that the proxy enforces | none (display only); it states NOT spec-cleared |
| Beat 1 | 20 concurrent `issue_payout` of $500.00 with one pre-state hash, then 5 retries with the winner's request id | server wire log (exactly 1 `issue_payout` line), server audit file (exactly 1 payout), `get_balance` = 0.00 |
| Beat 1 control | The same 20 calls, NO proxy: a server with $500.00 and a server with $10,000.00 | the control servers' audit files (1 payout; 20 payouts) |
| Beat 2a | Session `clinic_id=Clinic_Alpha` reads a Clinic_Beta chart, then an Alpha chart | every byte that the client received in 2a, searched for the Beta chart values of a direct no-proxy call; server wire log and audit (the server did answer) |
| Beat 2b | `update_dosage` 500 mg against the 50 mg fact, then 25 mg | server wire log (0 `update_dosage` lines after the block), SHA-256 of the server state file, the state file after the 25 mg commit |
| Beat 3 | One line of N GiB with no newline, then 1 + 30 commits | `ps -o rss=` samples of the proxy process (peak < 5.0 MiB, the one owner-approved bound), server wire log (0 flood lines), server audit (31 payouts). Latency is printed, never asserted |
| Layer 03 | `bin/forge-mcp-proxy verify-evidence` on every `evidence.wal`; a copy with one flipped byte | exit code and output of `verify-evidence` (exit 0 with all records signed; exit 1 for the tampered copy) |

The cap of Beat 2b comes from the airlock's facts file `policies/healthcare.facts.json`. The proxy does not ask
the server for it.

## Clearing: what exists and what is missing

`scripts/spec_clearing.py` and `src/airlock/py/diff_policy.py` give a NO_CHOICE verdict only for Goal 20 MONEY
policies, and only through the pinned Dafny. No generator maps this MCP policy format (`policies/*.policy.json`)
to a Dafny model. So no clearing check of these policies exists. A real one would need: a generator from this
policy format to a Dafny model, a clearing subject for it, and a Dafny verify and audit run. The showcase starts
no Dafny, HOL or Node.

## What this does NOT show

- The proxy is unproved Rust. The routing, the CAS, the filters and the evidence code are a native check.
- The scoped-read filter trusts the `clinic_id` / `org_id` labels that the server puts in its answer.
- The CAS runs on the airlock's own ledger (`ledger.wal`), not on the bank's or the EHR's state.
- One machine, one run. No hardware claim. No compliance claim.
- `verify-evidence` does not detect the removal of trailing records. That needs an outside anchor of the last
  chain value.
- The other limits of the proxy are in `src/mcp_proxy/PROTOCOL.md`, section 8.
