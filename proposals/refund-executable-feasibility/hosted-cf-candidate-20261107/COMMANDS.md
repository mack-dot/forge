# Actual commands and proposed execution

Raw local preparation directory:
`results/hosted-cf-preparation-20261107/attempt-0001`.
Each command below uses that directory's file. `NOT RUN` is not an exit code.

| Executed command | Actual exit |
| --- | --- |
| python3 -B run_api.py parents inspect-parents.sml |0|
| python3 -B run_api.py loader-metadata inspect-loader-metadata.sml |0|
| python3 -B collect_inputs.py |0|
| python3 -B package_inputs.py |0|
| python3 -B local_inspection.py |0|
| python3 -B prepare_workflow.py |0|
| python3 -B check_transport.py |0|
| transport_probe.py wrong-hash / path-traversal / symlink |1/1/1|
| Hosted workflow / unchanged generic proof |NOT RUN|
| Independent21-snapshot replay |NOT RUN|

The parent and metadata command records include exact HOL argv, source hash,
stdout/stderr hashes and actual exit. `local-inspection.jsonl` records exact
argv/environment and lossless streams. Raw reconstructed files are also kept.
The controls' command.json files contain their exact subprocess argv and exits.
GitHub read-only operations have tool success/error results, not process exits.

Incidental source lookup failures are preserved in
`records/inspection-failures.json`. The later process-list command was denied
by the local sandbox. It is not evidence about the cfLib failure's cause.
No failed proof or denied diagnostic was rerun in this preparation.

[APPROVAL.md](APPROVAL.md) describes the not-yet-authorized external actions.
Expected proof/control outcomes in the prepared driver are acceptance criteria,
not observations. The driver remains transport/orchestration code; HOL supplies
any future proof result. It is not a replacement proof checker.
