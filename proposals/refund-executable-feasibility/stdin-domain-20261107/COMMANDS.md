# Executed commands

Working root: `/Users/mackianni/forge`. Runner prefix:

```text
python3 -B results/refund-stdin-domain-20261107/attempt-0001/run_hol.py
```

| Appended arguments | Actual wrapper exit | Actual HOL exit |
| --- | ---: | ---: |
| model-0001 proof-0001.sml |1|NOT RUN |
| model-0002 proof-0001.sml |1|1 |
| lookup-diagnostic inspect-lookup.sml |1|1 |
| lookup-diagnostic-0002 inspect-lookup-0002.sml |1|1 |
| lookup-diagnostic-0003 inspect-lookup-0003.sml |1|1 |
| lookup-diagnostic-0004 inspect-lookup-0004.sml |0|0 |
| model-0003 proof-0002.sml |0|0 |
| model-0004 proof-0003.sml |0|0 |
| repeat proof-0003.sml |0|0 |
| fresh-import import.sml model-0004 |0|0 |
| wrong-status wrong-status.sml model-0004 |1|1 |
| missing-stdin-guard missing-stdin-guard.sml model-0004 |1|1 |

Each executed HOL child uses the exact argv and working directory in its
`records/<case>/command.json`. Full stdout/stderr and proof inputs accompany it.
The CPU limit is120 seconds per HOL process; core dumps are disabled.
No wall-time deadline determines proof acceptance. The final proof completes
without the blocked SAT or ARM8 loader route.

Other actual commands:

| Command | Actual exit |
| --- | ---: |
| `python3 -B results/refund-stdin-domain-20261107/attempt-0001/native_errno.py` |0 |
| Native executable children in `records/native-errno/observations.json` |0/0 |
| `python3 -B results/refund-stdin-domain-20261107/attempt-0001/readback.py` |0 |
| CakeML revision / HOL revision / four-source tracked diff |0/0/0 |
| `python3 -B results/refund-stdin-domain-20261107/attempt-0001/update_tracking.py` |0 |

The native controls use the existing executable. Its CPU limit is30 seconds;
no rebuild or signature creation occurs. libc return values-1 and0 are syscall
results, not process exit codes. Exact errno35 and0 are recorded separately.
Source command records are in `records/source-commands.json`.
Initial path/glob/web inspection failures are retained separately.

No new hosted command, native ARM8 instruction proof, or independent replay ran.
Any commands in NEXT-STEP.md remain plans and have no actual exit code.
