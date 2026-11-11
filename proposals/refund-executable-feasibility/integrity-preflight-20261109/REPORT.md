# U334: exact workflow review found and corrected a redirect scope defect

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner explicitly described the latest message as a recommendation,not an
authorization. Neither integrity nor proof execution is authorized by it.

U333 used urllib.request.urlopen,which can follow a redirect before checking
response.geturl(). It rejected a changed final URL, but only after a possible
request outside the stated host scope. A controlled local HTTP302 response
demonstrated the original handler attempting the second URL; child exit1.
The fake transport intercepted every request. No network socket was opened.
This is an orchestration defect,not a refund theorem or input defect.

The revised driver installs an HTTPRedirectHandler that raises before following
a redirect. All commit,manifest,archive,candidate and quotation checks remain.
The workflow uses a new proposal branch; no published file was changed.
The original U333 packet remains byte-identical in both directories.

| Executed check | Actual exit | Evidence |
| --- | --- | --- |
| Revised preparation / embedded shell syntax |0 / 0|PREPARATION.json |
| Original controlled HTTP302 case |1|Follow-up URL detected before any socket |
| Revised positive response |0|Exact fixture bytes accepted |
| Revised301/302/303/307/308 controls |1/1/1/1/1|Zero follow-ups; exact reasons checked |
| Corrected control recorder |0|REDIRECT-CONTROLS-V2.json |
| U333 preservation and pinned constants |0|SOURCE-PRESERVATION.json |
| Hosted integrity / HOL / replay |NOT RUN|No external execution authority |

The initial control recorder exited0 after checking only child exit codes.
Its308 child raised HTTPError without the expected result record. That summary
was insufficient. Its source and all stdout/stderr remain. The corrected
recorder checks exact rejection reasons,request lists and request counts.
On local Python3.10,308 is rejected by the existing HTTP error path; the other
four codes enter the new redirect refusal. Ubuntu runtime behavior is untested.
No local fixture result is remote byte readback or universal correctness proof.

The previous1,493-member audit and three identity-mutation controls are reused
from U333. They were not rerun. The source pins and theorem premise quotation
did not change. Full remote package readback and the theorem remain unestablished.

[APPROVAL.md](APPROVAL.md) fixes the exact revised11897-byte workflow and9886-byte
driver. Scope:one Ubuntu job,5-minute cap,permissions{},180-second driver wall
limit,90 CPU seconds,1GiB address space,32MiB/file,zero core dumps. It reads the
same26196042 payload bytes plus eight bounded metadata responses from the two
existing input commits. No new proof payload,install,secret or input execution.
Only the reviewed workflow is published. Recheck parent/trigger definitions and
new workflow commit identity before publishing its trigger branch.

NO-GO for the old U333 workflow. GO recommendation for the revised integrity-only
preflight after explicit approval. No approval extends to HOL,candidate repeat,
fresh import or proof controls. Native memory/frame,whole-program composition
and21-snapshot replay remain separate. Local Git metadata remains unresolved;
no Git repair or new commit was attempted. Evidence is preserved as local files.
