# d-v6sink: patches a COPY of the d-v3sink harness (lib.ts, diff.ts) in a heavy folder. Usage: python3 harness_patch_v6.py DIR
# lib.ts: (1) SINKS gets "cb-v6"; (2) a V6 core adapter: when the core file exports Shell6 (sinkcore-v6.cjs), the
#   reference outcome is the compiled ShellCoreV6.StepQ6 on (stored charge, shell token, sigOk, preOk := stored == pre,
#   id settled). Runtime cross-checks: a V6 commit is a V3 commit with the same next core; a V6 Reject(w) is a V3
#   rejection with the same reason w; RejectNotAuthorized only where V3 commits (lemma LostExactlyUnauthorized).
#   (3) sinkOut maps the new reason to "rejected:NotAuthorized".
# diff.ts: (4) a new generator kind "signed-unauthorized" (trusted key, fresh id, current pre-state hash): an unapproved
#   reason with a consistent post-state, or an amount above remaining with post remaining 0 (a consistent post with a
#   negative remaining cannot pass the decoder); (5) kinds generated on a refund-DISABLED s0 get the suffix "@disabled".
import sys
d = sys.argv[1]
def sub(path, a, b):
    s = open(path).read(); assert s.count(a) == 1, (path, a); open(path, "w").write(s.replace(a, b))
L = d + "/lib.ts"; D = d + "/diff.ts"
sub(L, '  "cb-v3": Z + "/sinks/cb-v3.ts",', '  "cb-v3": Z + "/sinks/cb-v3.ts",\n  "cb-v6": Z + "/sinks/cb-v6.ts",')
sub(L, 'export const coreKind = SHELL ? "v3" : "other";',
    'const SHELL6 = M.Shell6 && M.Shell6.__default && M.Shell6.__default.StepQ6 ? M.Shell6 : null;   // d-v6sink\n'
    'export const coreKind = SHELL6 ? "v6" : SHELL ? "v3" : "other";')
sub(L, '''  const o = r.dtor_out;
  return { core: r.dtor_core, out: o.is_Committed ? "committed" : "rejected:" + whyName(o.dtor_why) };''',
'''  const o = r.dtor_out;
  if (SHELL6) {
    // d-v6sink: the V6 reference. StepQ6 on the stored charge; preOk := stored == pre (A4' form); settled lookup.
    const t = d.tok;
    const st6 = M.Shell.ShellToken.create_ShellToken(t.dtor_specId, t.dtor_checkerId, t.dtor_requestId, t.dtor_post, t.dtor_intent, t.dtor_sig);
    const q = SHELL6.__default.StepQ6(core.dtor_charge, st6, d.sigOk, rt.areEqual(core.dtor_charge, t.dtor_pre), core.dtor_settled.contains(t.dtor_requestId));
    shellChecks.stepQ6 = (shellChecks.stepQ6 ?? 0) + 1;
    if (q.is_Commit) {
      if (!o.is_Committed) throw new Error("V6 adapter: StepQ6 commits where V3 Step rejects");
      return { core: r.dtor_core, out: "committed" };
    }
    if (q.is_Reject) {
      if (o.is_Committed || whyName(o.dtor_why) !== whyName(q.dtor_why)) throw new Error("V6 adapter: StepQ6 reason differs from V3 Step");
      return { core: r.dtor_core, out: "rejected:" + whyName(q.dtor_why) };
    }
    if (!o.is_Committed) throw new Error("V6 adapter: RejectNotAuthorized where V3 Step rejects");
    return { core, out: "rejected:NotAuthorized" };
  }
  return { core: r.dtor_core, out: o.is_Committed ? "committed" : "rejected:" + whyName(o.dtor_why) };''')
sub(L, 'export const shellChecks = { stepP: 0, audit: 0 };', 'export const shellChecks: any = { stepP: 0, audit: 0 };')
sub(L, '    "charge id is not the stored charge id": "ChargeIdMismatch",',
       '    "charge id is not the stored charge id": "ChargeIdMismatch",\n    "not authorized by the approved relation for the stored state": "NotAuthorized",')
sub(D, '    if (k0 < 0.06) {', '''    if (k0 >= 0.06 && k0 < 0.09) { const id = fresh();   // d-v6sink: signed (trusted key) but unauthorized
      if (r.next() < 0.5) { const x = refund(pre, id, r.next() < 0.3 ? 0n : amt(), "goodwill_" + r.int(3)); return { kind: "signed-unauthorized", text: tokenText(body(pre, id, remember(x.post), x.intent)) }; }
      const a = rem + 1n + BigInt(r.int(100)), post = remember({ ...pre, remaining: "0" });
      return { kind: "signed-unauthorized", text: tokenText(body(pre, id, post, { chargeId: pre.chargeId, requestId: id, amount: a.toString(), reason })) }; }
    if (k0 < 0.06) {''')
sub(D, '    const a = mk(cur);', '    const a = mk(cur);\n    if (!s0.refundEnabled) a.kind += "@disabled";   // d-v6sink')
