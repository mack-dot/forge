"""Preserve exact records and append the U296 tracking checkpoint."""
from pathlib import Path
import hashlib,json,shlex,shutil,subprocess
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-readiness-docs-20261103')
OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
assert read(OUT/'readback.json')['actual_exit']==0
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=WT,text=True).strip()=='d69af8b1251e5ca2040967aeff2ee9607812defb'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=WT,text=True)
rel=Path('proposals/refund-executable-feasibility/runtime-premises-20261104')
assert not (ROOT/rel).exists() and not (WT/rel).exists()
for label,base in [('workspace',ROOT),('worktree',WT)]:
    for name in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']:
        assert (base/name).read_bytes()==(OUT/'tracking-before'/label/name).read_bytes(),(label,name)
    assert '\n## U296 ' not in (base/'unsure.md').read_text()

commands=['# Exact local commands — U296','',
  'Working directory: `/Users/mackianni/forge`.',
  'Expected negative outcomes remain distinct from positive proof results.',
  'Every command below actually ran. JSON records include full child arguments.', '']
for name in ['precise-0001','precise-0002','precise-0003','precise-repeat','exact-import','missing-space','changed-limits']:
    r=read(OUT/name/'command.json')
    commands += ['## '+name,'',f"Actual exit: **{r['actual_exit']}**. Local elapsed seconds: `{r['wall_seconds']}`.",'',
                 '```sh',shlex.join(r['argv']),'```','',f"Child working directory: `{r['cwd']}`.",'']
commands += ['## Identity and preservation checks','',
  '`python3 -B results/refund-runtime-premises-2026-11-04/attempt-0002/runtime_readback.py`: actual exit 0.',
  '`python3 -B results/refund-runtime-premises-2026-11-04/attempt-0002/readback.py`: actual exit 0.','',
  'The earlier exact input readback was an inline Python command; its result is retained as `records/input-readback.json`.',
  'The initial read-only HOL specialization is retained in `records/initial-inspection/command.json` (actual exit 0).',
  'No native, hosted, independent-device restore, signing or admission command ran here.','',
  'These local runs used cached parent theories. Timing differences are not evidence of a cache speedup.', '']
(OUT/'COMMANDS.md').write_text('\n'.join(commands))
packet=ROOT/rel;packet.mkdir(parents=True)
for name in ['REPORT.md','CORRESPONDENCE.md','COMMANDS.md']:
    shutil.copyfile(OUT/name,packet/name)
for p in sorted(OUT.rglob('*')):
    if not p.is_file():continue
    name=p.relative_to(OUT)
    if name.parts[0]=='tracking-before' or str(name) in ['REPORT.md','CORRESPONDENCE.md','COMMANDS.md']:continue
    target=packet/(name if name.parts[0]=='upstream' else Path('records')/name)
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
inspection=OUT.parent/'attempt-0001/inspect'
for p in inspection.rglob('*'):
    if p.is_file():
        target=packet/'records/initial-inspection'/p.relative_to(inspection)
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
manifest={str(p.relative_to(packet)):sha(p) for p in sorted(packet.rglob('*')) if p.is_file()}
(packet/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
shutil.copytree(packet,WT/rel)

road='''## Runtime applicability and precise conditional behavior — 2026-11-04 (U296)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Existing stronger backend specialization diagnostic | 0 | Exact premises inspected |
| Precise behavior proof attempts1/2/3; repeat | 1/1/0;0 | Three theorems; four byte-identical exports |
| Fresh exact import | 0 | Three exact statements; no new hypotheses/axioms |
| Missing space premise / changed heap limit | 1/1 | Expected exact-statement refusals |
| runtime_readback.py | 0 |16 pinned sources,12 capture members,43 prior packet members |
| readback.py | 0 |482-node closure,2403 dependency files,50 protected paths,515 prior packet members |
| New native/hosted execution, independent replay/admission/restore | NOT RUN | No physical-runtime or authority completion |

[Exact theorem, complete premise matrix, commands, hashes and failures](proposals/refund-executable-feasibility/runtime-premises-20261104/REPORT.md).
The new theorem yields complete modeled success only under its explicit full
is_safe_for_space and runtime premises. Resource sufficiency remains unproved.
The existing resource-extended theorem permits an empty resource-limit prefix;
this is now checked explicitly. Same-host imports are not independent replay.
The observed code buffer is r-x and the runtime build has no -DEVAL flag;
universal install_interfer_ok remains unjustified. Next: inspect existing
no-install/reachability proofs for this exact program and their simulation use.
Do not alter runtime permissions or remove a premise. U290 stays stopped at five
attempts. Full physical state/FFI/OS, frontend review, new provenance/admission
and exact independent-device restore remain open. Integration EXIT
NOT_ESTABLISHED. No protected adoption, publication, push, merge or dispatch.

'''
status='''## Resume here — exact runtime premises and conditional success (U296)

[Tracked proof, correspondence matrix and next action](proposals/refund-executable-feasibility/runtime-premises-20261104/REPORT.md).
The current missing link is applying the checked model theorem to the physical
refund process. The full source/model byte boundary from U295 remains intact.

| Current check | Actual exit / status |
| --- | --- |
| Stronger conditional proof attempts; repeat | 1/1/0;0 |
| Exact import of all three statements | 0 |
| Omitted resource condition / changed limit | 1/1, expected refusal |
| Runtime identity / proof closure readback | 0/0 |
| Actual resource sufficiency and full installed-state relation | NOT_ESTABLISHED |
| New native/hosted run, independent replay or admission | NOT RUN |

The checked conclusion is complete modeled success with the exact six-field
refund result, conditional on every stated premise. Four exports reproduce;
closure482 nodes/2403 files retains only four existing Boolean foundations.
Resource-limit prefixes remain possible under the earlier weaker theorem.

**Next smallest authorized action:** inspect the published no-install/reachability
results for the exact refund program. The observed428-byte code buffer is in an
r-x mapping. Its runtime build has no -DEVAL flag; permission changes are
conditional in the C source. The universal installation contract is therefore
not justified by a passing fixture. Prove an applicable reachability/simulation
argument or keep this premise unsupported. Do not change permissions or retry
U290's stopped five-attempt route. This is a premise audit, not a physical
counterexample or proof that installation is reachable.

Full ARM state, memory/frame/interference, FFI/OS progress, resource adequacy,
source serialization/shared interpretation, complete-chain independent review
and new provenance/admission remain open. Review the proposed assumption profile
before adoption. Historical signatures do not authorize the new claim.
Exact other-device archive hashes and restore are still NOT VERIFIED.
Local unsigned commits remain authorized. Publication, push, merge, dispatch,
protected adoption, signing, admission and deployment retain their boundaries.
Stage12 unauthorized; M1/integration EXIT NOT_ESTABLISHED; end_to_end=false.

'''
uncertainty='''
## U296 — Precise conditional refund success checked; runtime installation premise unresolved

- References:U262,U267,U277,U283,U289,U290,U291,U294,U295. Previous goal turn
  made progress at local commitd69af8b1251e5ca2040967aeff2ee9607812defb.
  CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
- The runtime audit reconciles every prior U277 premise with later evidence.
  Source/readback0 binds16 pinned upstream files,12 capture members,43 prior
  audit packet members, exact runtime flags/object and50 protected files.
  The unchanged native digest is
  b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
  Entry values and loaded bytes are observations, not a complete physical relation.
- Actual stronger-backend diagnostic0. Precise proof attempts1/2 return1/1:
  sem resolves to an unrelated constant; then a polymorphic singleton theorem
  application fails. Rename only the variable and rewrite with the existing
  machine_sem_sing theorem. Attempt3/repeat0/0 produce four byte-identical exports.
  No proposition, specification, input domain, semantic model or axiom weakened.
- refund_compiled_precise specializes the existing compile_correct_is_safe_for_space.
  It retains installed state, exact read_limits, canonical nine-field stdin,
  wfcl/wfFS/STD_streams/is_arm8_machine_config and space safety for every pointer
  oracle. Its conclusion is a singleton successful modeled trace with complete
  six-field output. It does not prove resource sufficiency or physical applicability.
  A helper retains singleton/nonempty behavior. Another theorem proves the old
  resource-extended relation permits Terminate Resource_limit_hit [] explicitly.
- Fresh import0 checks all three exact statements with zero explicit hypotheses
  or new tagged axioms. Closure482 nodes/2403 hashed files retains only the four
  existing Boolean foundations. Cached DISK_THM parents remain a trust boundary;
  this is not clean independent full-chain source replay or producer authentication.
  Removing the resource premise or changing only the claimed heap limit by1
  each returns1 for Exact statement mismatch: refund_compiled_precise. These are
  claim-binding controls, not physical counterexamples or admission decisions.
- Proof source933d7c3f07df5b32d9209d9755bb87a0ab17aae759858e4b507f9ea347e2b7bf;
  expected statements88fe4f5c65649d1b3e0db94adc21d242165171dd6f652ca4954aa0071ed6c15a;
  theory datae5034a037556f3d86c895e73d6523425ce781ca42e4972ddaa3220a4efa40c4c.
  readback0 also verifies515 previous byte-boundary/compiler/resource packet files.
- New runtime concern: the observed428-byte candidate code buffer lies in r-x
  text. The bound runtime compile command has no -DEVAL option; its mprotect
  calls are EVAL-conditional. The theorem's universal install_interfer_ok is
  NOT_ESTABLISHED for the physical runtime. No install mutation/faulting native
  run occurred. No checked unreachability argument is claimed. Finite absence
  of an install event does not discharge the universal premise.
- Every failure remains. Initial fresh-directory setup1 discovered historical
  attempt-0001; newly added inspection files did not replace prior packet members.
  The proof cases use attempt-0002. Wrong source-path lookup2/corrected0 and
  exact diagnostic command are retained. No old unsure entry was changed.
- Evidence:proposals/refund-executable-feasibility/runtime-premises-20261104/
  REPORT.md,CORRESPONDENCE.md,COMMANDS.md,records/readback.json. Raw records:
  results/refund-runtime-premises-2026-11-04/attempt-0002/ and the separately
  retained initial read-only inspection under attempt-0001/inspect/.
- Next check: inspect published no-install/reachability lemmas for this exact
  program and whether they can support a sound concrete/model simulation.
  Otherwise preserve the installation premise as unsupported. Do not change
  runtime permissions, enable EVAL or drop the premise. U290 stays stopped at
  five attempts. Resource sufficiency, unobserved ARM fields, complete memory,
  FFI/frame/interference/OS relations, source frontend/shared interpretation,
  independent replay/review and new provenance/admission remain open.
  Owner-reported other-device backup still lacks exact hashes and restore.
  No new native/hosted execution, protected adoption, signing, publication, push,
  merge, dispatch, admission, deployment, Node, SPM or Stage12. M1/integration
  EXIT NOT_ESTABLISHED. Only local proposal tracking and unsigned commit proceed.
'''
for label,base in [('workspace',ROOT),('worktree',WT)]:
    for name,section in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',status)]:
        p=base/name;old=p.read_text();at=old.index('\n## ')
        p.write_text(old[:at]+'\n'+section+old[at:])
    with (base/'unsure.md').open('ab') as f:f.write(uncertainty.encode())
    assert (base/'unsure.md').read_bytes().startswith((OUT/'tracking-before'/label/'unsure.md').read_bytes())
for base in [ROOT,WT]:
    for name,digest in manifest.items():assert sha(base/rel/name)==digest
result={'actual_exit':0,'packet_path':str(rel),'manifest_sha256':sha(packet/'manifest.json'),
        'packet_members':len(manifest),'append_only_unsure':True,
        'base_commit':'d69af8b1251e5ca2040967aeff2ee9607812defb',
        'new_native_or_hosted_execution':'NOT RUN','end_to_end':False}
(OUT/'document-readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
