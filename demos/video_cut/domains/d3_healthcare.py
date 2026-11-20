"""Domain 3, healthcare. Policy: demos/video_cut/policies/clinic-dosing.json (money airlock, parametric),
and the engine's read airlock (no policy file).

Mapping. The engine has no clinical rule.
- Records: the read airlock (SDK read_scoped). The tenant is the clinic. The engine releases a result set
  only if every row has a top-level `tenant_id` equal to the clinic. One row of another clinic:
  TENANT_ISOLATION_BREACH and 0 rows released. The module measures the released row count.
- Dose: the money airlock. The wire verb is REFUND, the reason is DOSE_MG and the amount is milligrams.
  One key is one order window that a trusted opener opened with the fact safe_mg=50.
  Rule: committed DOSE_MG total + amount <= safe_mg. 25 commits; 500 is REJECTED_POLICY REASON_CAP.

Labels. Every shot: NATIVE CHECK + FINITE TEST (Rust engine, not proved). Nothing here is PROVED.
end_to_end=false.

Gaps (also printed by ctx.gap).
- MCP part: NOT IN TAKE.
- The read airlock checks only the top-level tenant_id of the rows passed to it. A nested object of another
  clinic passes. It sees no database: the rows here are scripted.
- This is not a HIPAA compliance claim.
- Doses are cumulative on the key: the rule bounds the sum of all committed doses of the key, not one dose
  and not a dose per time. safe_mg is a trusted input; the engine does not check it against a record.
"""
from harness import TakeFailed

NUMBER, NAME, TITLE = 3, 'healthcare', 'Healthcare records and dosing'
D = 'healthcare'
T, K = 'clinic-a', 'order-rx-1'
RULE_READ = 'READ: every row has a top-level tenant_id equal to the clinic, else TENANT_ISOLATION_BREACH and 0 rows'
RULE_DOSE = 'DOSE_MG: committed total + amount <= fact safe_mg (trusted, 50)'
OWN_ROWS = [{'tenant_id': 'clinic-a', 'patient': 'p-101', 'drug': 'drug-x'},
            {'tenant_id': 'clinic-a', 'patient': 'p-102', 'drug': 'drug-y'},
            {'tenant_id': 'clinic-a', 'patient': 'p-103', 'drug': 'drug-x'}]
MIXED_ROWS = OWN_ROWS[:2] + [{'tenant_id': 'clinic-b', 'patient': 'p-900', 'drug': 'drug-z'}]


def run(ctx):
    st = ctx.store('clinic', ['clinic-dosing.json'])
    _, ok = ctx.shot(D, 'Own clinic records', RULE_READ, 'READ clinic-a 3 + 3 rows of clinic-a',
                     'OK 3', lambda: st.read_scoped(T, OWN_ROWS))
    ctx.note(D, 'rows released, own-clinic read', len(getattr(ok, 'rows', [])), 'measured live')
    _, bad = ctx.shot(D, 'Another clinic row', RULE_READ, 'READ clinic-a 3 + 2 rows of clinic-a, 1 row of clinic-b',
                      'TENANT_ISOLATION_BREACH', lambda: st.read_scoped(T, MIXED_ROWS))
    released = len(bad.rows)
    ctx.note(D, 'rows released, read with 1 row of another clinic', released, 'measured live')
    if released != 0 or len(ok.rows) != 3:
        raise TakeFailed('healthcare read: released %d rows after the breach (need 0), %d rows for the own clinic (need 3)'
                         % (released, len(ok.rows)))
    ctx.shot(D, 'Pharmacy opens the order', 'trusted opener sets the facts', 'OPEN_MONEY clinic-a order-rx-1 ... safe_mg=50',
             'COMMITTED', lambda: st.open_money(T, K, 'open-rx-1', 'clinic-dosing', 100000, {'safe_mg': 50}))
    h = st.get(T, K).state_hash
    ctx.shot(D, 'Agent orders 500 mg', RULE_DOSE, 'REFUND clinic-a order-rx-1 dose-1 <hash> DOSE_MG 500',
             'REJECTED_POLICY REASON_CAP', lambda: st.refund(T, K, 'dose-1', h, 'DOSE_MG', 500))
    ctx.shot(D, 'Agent orders 25 mg', RULE_DOSE, 'REFUND clinic-a order-rx-1 dose-2 <hash> DOSE_MG 25',
             'COMMITTED', lambda: st.refund(T, K, 'dose-2', h, 'DOSE_MG', 25))
    ctx.gap(D, 'MCP part: NOT IN TAKE')
    ctx.gap(D, 'the read airlock checks only the top-level tenant_id of the rows passed to it: a nested object of another '
               'clinic passes; no database runs here, the rows are scripted')
    ctx.gap(D, 'this is not a HIPAA compliance claim')
    ctx.gap(D, 'doses are cumulative on the key: the rule bounds the sum of all committed doses, not one dose and not a dose '
               'per time; safe_mg is a trusted input of the opener')
