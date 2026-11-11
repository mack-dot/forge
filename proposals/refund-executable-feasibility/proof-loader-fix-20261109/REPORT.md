# U341: loader paths fixed and tested locally

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The corrected driver supplies virtual theory paths to QUse. It removes the
explicit `.hol/objs` directory from both parent-theory loads and subsequent
theorem import/control loads. HOL adds that directory once during resolution.

Only [two expressions changed](records/driver.diff). All other driver bytes and
workflow fields are unchanged. The old published workflow and failure evidence
remain intact. The new [workflow](records/workflow.yml) is local and unpublished.
No theorem,premise,input archive,dependency,protected path,permission,image guard,
resource limit or conditional control was changed.

Corrected workflow16363 bytes,SHA256:
`9a29e94d16033592704bfa20bd1ef06818e50458d4155a2216500ac205486629`.
Corrected driver SHA256:
`cf7e2f2281130d186b2ee22511b953b81e2c6750469085ec0e7629e154215dd1`.
All five generated bootstraps were checked. The direct candidate/import/control
script paths remain identical; only theory-file addressing changes.

| Executed command/check | Actual exit/result |
| --- | --- |
| `python3 -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/prepare_fix.py` |0|
| `/bin/bash --noprofile --norc -n proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/shell.sh` |0|
| Initial `test_loader.py` |1; test used a non-exported resolver API; preserved,not an accepted negative |
| Corrected `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/test_loader.py` |0; actual child exits1/0|
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/check_preservation.py` |0|
| `python3 -I -B proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/record_fix.py` |0|
| Hosted publication/execution; candidate proof |NOT RUN|

The regression invokes the existing pinned HOL runtime with its unchanged four
saved states. It calls the exported HFS_NameMunge.HOLtoFS resolver and the actual
HOLFileSys.openIn/inputAll layer used by HOLSource/QUse. It does not compile or
execute any theory source,load cfLib,run SAT,or attempt the candidate theorem.
Each child has CPU30s,wall45s,maxheap1536MiB,4MiB/file and zero core dumps.
Exact argv,limits,actual duration,stream hashes and outcomes are preserved.

The old path exits1 with the same duplicated-directory ENOENT as U340. The
corrected path exits0 and reads all four parent signature/source files. Their
bytes equal direct reads of the pinned physical files. The resolver also maps
both future import filenames to the correct single `.hol/objs` output paths.
This is a real loader regression,not a simulated pass. Future theorem exports
do not exist yet; their path-resolution checks are not fresh theorem imports.

The first test failed before path reads because HOLFileSys.toFS is internal,
not exported. Its source,runner,logs and exit1 remain. The corrected test uses
the public HFS_NameMunge.HOLtoFS API. The corrected driver itself was unchanged
by that test repair. No unaccepted failure was counted as a passing control.

Pinned runtime/saved-state/parent file identities match the frozen manifests
before and after the regression. The candidate and four prepared source files,
all50 protected hashes and mission bytes are unchanged. U282/U291 supplied the
prior loader-path evidence; U340's hosted failure remains preserved.

The specific duplicated-path defect is fixed and locally tested. Full parent
theory compilation,cfLib loading,the candidate theorem and its conditional
controls remain untested with this new workflow. No mathematical result is claimed.
[NEXT-RUN-APPROVAL.md](NEXT-RUN-APPROVAL.md) identifies the exact new workflow
and one bounded future job. The previous single retry is exhausted; nothing
was published or dispatched under the request to fix the loader.
