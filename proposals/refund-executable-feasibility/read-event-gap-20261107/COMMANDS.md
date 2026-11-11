# Executed commands

Working directory: `/Users/mackianni/forge`.
Runner prefix:

```text
python3 -B results/refund-read-event-gap-20261107/attempt-0001/run_hol.py
```

| Arguments | Actual wrapper / HOL exit |
| --- | ---: |
| model-0001 proof-0001.sml |0/0 |
| repeat proof-0001.sml |0/0 |
| fresh-import import.sml model-0001 |0/0 |
| wrong-replay-result wrong-replay-result.sml model-0001 |1/1 |
| omitted-error-event omitted-error-event.sml model-0001 |1/1 |
| generic-0001 generic-read-0001.sml |1/1 |

Every child uses its exact recorded argv,cwd,source hash and parent identities.
Full stdout/stderr and generated files are retained per case. CPU limit120
seconds,core limit0. The fresh import and first negative control overlapped;
they used separate output directories and immutable common parents.

`python3 -B results/refund-read-event-gap-20261107/attempt-0001/readback.py`
exits0. Its git pin and eight-source diff checks each exit0. The separate
generic failure readback also exits0. No native,hosted,signing or replay command
ran. No process remains active from these checks.

Two guessed source-location inspections failed before correction. One aggregate
shell command exits2 for the missing semantics/ffiScript.sml path; the actual
file is semantics/ffi/ffiScript.sml. Another aggregate command exits1 for missing
proposal record names. Their individual component exit codes were not captured.
An exploratory search ended with exit1 for no matching theorem name. These are
inspection outcomes,not proof refusals. See records/inspection-failures.json.
