# Stage 6: booking proofs and measured reuse

The approved booking source passes B1–B4 with Dafny 4.11.0. Its checked trace includes
cancellation, slot reuse, historical retries, and ID conflicts. The source evidence
replayed byte for byte. `end_to_end=false`.

[Source evidence](../results/stage6/source-evidence.json) · [Actual measurements](../results/stage6/benchmark.json)
· [Recomputed totals](../results/stage6/report.json) · [Rejection controls](../results/stage6/controls-final.json)

## Exact experiment

Five repetitions × five cases × three conditions produced 75 baseline/candidate pairs.
Each pair charges both audits and the full baseline check. Fresh processes handle the
cold and shared-file conditions. The dependency condition uses native Dafny/Boogie
snapshot reuse after checking its baseline in the same process. No custom proof cache
or dependency checker decides correctness.

| Condition | Pairs | Verifier process seconds, including baseline | Checked members, including failures | Reused members | New solver resources |
| --- | ---: | ---: | ---: | ---: | ---: |
| cold | 25 | 269.713 | 1100 | 0 | 342198540 |
| shared_files | 25 | 271.067 | 1100 | 0 | 342198540 |
| dependency_graph | 25 | 175.828 | 590 | 510 | 224568970 |

The table includes the deliberately invalid helper and reject-all controls. Rejected
candidates do not produce accepted artifacts. Member counts differ from assertion-batch
counts. Cached trace durations and resources are historical values, so the totals above
exclude them from new solver work. Process times are actual outer verifier durations.

## Median verifier process seconds by case

| Case | Cold | Shared files | Dependency graph |
| --- | ---: | ---: | ---: |
| unchanged | 10.969 | 11.676 | 6.158 |
| booking_body | 10.868 | 11.340 | 9.146 |
| helper_body | 10.949 | 11.140 | 6.590 |
| broken_helper | 11.270 | 10.736 | 6.029 |
| reject_all | 9.036 | 9.188 | 6.998 |

The one-file condition concatenates the exact approved declarations and implementation
bodies after removing only their fixed include lines. The shared condition retains their
file layout. Every condition checks the same 22 members and the same candidate changes.
Full source fixtures and hashes accompany the raw logs.

## Shared preparation and authoring

Failed preparations and development checks remain in the recomputed report. They include
the first two booking proof attempts, the first two trace proof attempts, the hardware
inventory failure, and the report-count correction. Setup costs are not silently assigned
to one condition or omitted from the preparation record.

| Runtime token category, recorded interval | Count |
| --- | ---: |
| cache_write_input_tokens | 0 |
| cached_input_tokens | 9944960 |
| input_tokens | 10041872 |
| output_tokens | 104763 |
| reasoning_output_tokens | 53391 |
| total_tokens | 10146635 |

The runtime total equals input plus output. Cached input and reasoning output are
reported separately and are not added again. This is a shared authoring interval, not
a comparison of three independent LLM runs or a final whole-project bill. The cutoff,
prior-phase counters, event index, and all usage records are in
[accounting.json](../results/stage6/accounting.json).

Recorded human interventions: 3. Automatic goal continuations: 3.

## Reproduce and limits

```sh
python3 scripts/benchmark_reuse.py
python3 scripts/exit_stage_6.py --case report
```

The first command performs a fresh experiment and preserves earlier runs. New times
can differ. The second recomputes totals from the selected recorded experiment and
checks hashes, raw traces, source evidence, controls, and usage sums.

- Five repeats of five fixed cases per condition on this recorded host; no wider inference.
- Cold and shared layouts contain the same declarations; shared files still receive full checks.
- Every baseline/warm-up is charged; cached historical statistics are not charged as new solver work.
- Negative controls are included in totals and are never accepted artifacts.
- The host was not isolated from all other OS/user activity. Timing reruns can differ.
- Authoring tokens are shared preparation, not three independent LLM authoring experiments.
- All available runtime usage categories in the stated interval are retained; post-cutoff activity is outside it.
- Private transcript content stays local; public event hashes do not reveal hidden instructions or reasoning.
- Early proposal resolution and one hardware inspection lack isolated subprocess timing; these are not proof runs.
- Source proof does not establish compiled, deployed, concurrent, durable, or authenticated behavior.

Native cache reuse retains the stated internal MD5 no-collision and dependency-tracking
assumptions. The acceptance evidence uses fresh full verification without a result cache.
No compiler, binary, deployment, LLM-productivity, or general engineering benefit is claimed.
