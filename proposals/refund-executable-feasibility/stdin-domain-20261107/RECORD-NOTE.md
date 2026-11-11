# Preflight record clarification

The retained `records/model-0001/preflight-failure.json` correctly records the
missing physical signature path and wrapper exit1. Its explanatory use of
“extensionless” is inaccurate. The historical HOL command includes `.sig` and
`.sml` names. HOL resolves generated theory files under `.hol/objs`; Python's
direct file hashing does not perform that resolution. The corrected runner
keeps the historical HOL arguments and hashes the actual generated paths.
No HOL command ran during that failed preflight.
