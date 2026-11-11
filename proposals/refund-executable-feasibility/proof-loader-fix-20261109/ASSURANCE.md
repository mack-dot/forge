# U341 assurance update

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| Duplicated theory directory | FIXED LOCALLY | Two path expressions now supply virtual paths; all other driver bytes unchanged. |
| Original defect reproduction | TESTED | Real pinned loader child exit1 with exact duplicated-path ENOENT. |
| Corrected parent file access | TESTED | Real loader child exit0; all four parent files read and compared byte for byte. No theory source compilation. |
| Future import path mapping | TESTED | Public resolver maps two virtual filenames to correct output locations. No generated theorem/import yet. |
| Initial regression error | PRESERVED | Non-exported API caused static error/exit1; not counted as expected ENOENT. Corrected test uses public API. |
| Workflow syntax and generated modes | TESTED | Shell syntax0; proof/repeat/import/two controls use corrected theory paths. |
| Frozen candidate,controls,dependencies,protected files | UNCHANGED | Relevant manifest identities and50 protected hashes/mission match. |
| Generic theorem and hosted corrected execution | NOT_ESTABLISHED / NOT RUN | Local file-layer regression is not a proof result. |
| Historical integrity mutations | TESTED, retained | Three in-process rejections; no separate exit codes. |
| Full M1 software correctness | NOT_ESTABLISHED | Native correspondence,composition and independent replay remain separate. |

Same-machine runtime,hash and cached-state trust limits remain. No protected
change,Stage12,release signing,deployment or hosted job occurred.
