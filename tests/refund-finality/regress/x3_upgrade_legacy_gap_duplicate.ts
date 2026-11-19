// X3 UPGRADE FROM A LEGACY GAP STORE. Attack class: duplicate effect for one request id across a sink upgrade.
// Evidence: unsure U534; results/night-shift-20261119/orch-B/r-reqid/ts/upgrade_run.ts and its result
// r-reqid/ts/results/upgrade-flushed.stdout (mode "flushed": two effects for rq_victim).
// Assumption: BEFORE the upgrade a FAULTY signer's X1 token (body rq_body, intent rq_victim) was committed by the
// merged sink and dispatched by the merged dispatcher. The legacy artefacts are written here byte for byte in the
// merged format (the merged DDL; meta initial_state_sha256; one settled row; one outbox row; one ledger line in the
// merged dispatcher's format), so this file needs no copy of the old code.
// Steps: open the legacy store with the sink under test; deliver the honest token for rq_victim on the stored
// state; flush the dispatcher under test on the legacy ledger.
// EXPECTED SAFE OUTCOME: the total number of effects for rq_victim (1 before the upgrade + those after it) is at
// most 1, and the outbox holds at most one intent for rq_victim. (Refusing to serve the legacy store is safe.)
// Unsafe on the merged sink and on a sink with only the commit-time request-id check: a second effect.
import { writeFileSync } from "node:fs";
import { Harness, MERGED_DDL, Regression, fail, pass } from "./harness";

export const regression: Regression = {
  id: "X3-upgrade-legacy-gap", kind: "attack", title: "legacy gap row, then honest token after an upgrade",
  async run(h: Harness) {
    const E = h.E, S0 = h.st("ch_1", "1000", "1000"), p1 = h.dec(S0, "100");
    const intentV = h.intent("ch_1", "rq_victim", "100");
    const gap = h.sign(S0, "rq_body", p1, intentV);
    const db = h.path("legacy.sqlite");
    h.create(db, d => {
      d.exec(MERGED_DDL);
      d.prepare("INSERT INTO meta(k, v) VALUES ('initial_state_sha256', ?)").run(E.sha256hex(E.canon(S0)));
      d.prepare("INSERT INTO state(id, blob) VALUES (1, ?)").run(E.canon(p1));
      d.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run("rq_body", gap, E.sha256hex(gap));
      d.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run("rq_body", E.canon(intentV));
    });
    // The merged dispatcher's ledger line for the gap row: that effect (rq_victim, 100) was already sent.
    const line = { requestId: "rq_body", tokenSha256: E.sha256hex(gap), preStateSha256: E.stateSha256(S0),
      postStateSha256: E.sha256hex(E.canon(p1)), intentSha256: E.sha256hex(E.canon(intentV)) };
    writeFileSync(h.path("ledger.jsonl"), JSON.stringify(line) + "\n");
    const before = 1;
    const { sink, error } = await h.openSink(db, h.cfg(S0));
    let r = "sink refused to start (" + error.slice(0, 60) + ")";
    if (sink !== null) { const cur = h.stored(db)!; r = await h.commit(sink, h.honest(cur, "rq_victim", "100")); await h.close(sink); }
    const f = await h.flush(db, S0);
    const after = f.effects.filter(e => e.intent.requestId === "rq_victim").length;
    const ob = h.outbox(db).filter(o => o.intent.requestId === "rq_victim").length;
    const why = `honest=${r} effects(rq_victim) before=${before} after=${after} outbox(rq_victim)=${ob}${f.error ? " dispatcherError=" + f.error : ""}`;
    if (before + after > 1 || ob > 1) return fail("DUPLICATE ACROSS UPGRADE: " + why);
    return pass(why);
  },
};
