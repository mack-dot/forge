"""Domain 4, cloud SRE change control. Policy: demos/video_cut/policies/sre-change.json (money airlock,
parametric). The store has a pinned human cosign key.

Mapping. The engine has no Kubernetes or firewall rule. Its money airlock tests the sum of one reason
against a trusted fact of the key, and it can demand a human signature for a reason. The wire verb is
REFUND; the reason names the change and the amount is a count. One key is one change window of one
deployment. A trusted opener opens it with total_pods=10 (shown) and max_delete=1.
- DELETE_PODS: committed deletes + amount <= fact max_delete. 1 of 10 commits; 8 of 10 is
  REJECTED_POLICY REASON_CAP.
- OPEN_PUBLIC_5432: REQUIRE_HUMAN_COSIGN. With no signature the engine answers COSIGN_REQUIRED and
  nothing commits (the change is halted).

Labels. Every shot: NATIVE CHECK + FINITE TEST (Rust engine, not proved). Nothing here is PROVED.
end_to_end=false.

Gaps (also printed by ctx.gap).
- The engine cannot multiply. The rule "deleted * 10 <= total" is not in the engine. The trusted opener
  computes max_delete = floor(total_pods / 10); the engine does not check that. total_pods is shown only.
- The adapter maps "0.0.0.0/0 port 5432" to the reason OPEN_PUBLIC_5432. The engine sees a reason name,
  not a firewall rule. A caller that sends another reason name is not caught by this rule.
- No cluster and no firewall run here. The commands are scripted. The wire verb is REFUND.
- No signed case is in this module. The temporary human key belongs to the same OS user as the agent.
"""
NUMBER, NAME, TITLE = 4, 'cloud_sre', 'Cloud SRE change control'
D = 'cloud_sre'
T, K = 'prod-eu', 'deploy-api'
RULE_DELETE = 'DELETE_PODS: committed deletes + amount <= fact max_delete (trusted, 1 = floor(total_pods 10 / 10), computed by the opener)'
RULE_PORT = 'OPEN_PUBLIC_5432: REQUIRE_HUMAN_COSIGN (commit only with a valid signature of the pinned human key)'


def run(ctx):
    st = ctx.store('sre', ['sre-change.json'], cosign=True)
    ctx.shot(D, 'Change window opened', 'trusted opener sets the facts: total_pods=10 (shown), max_delete=1',
             'OPEN_MONEY prod-eu deploy-api open-chg-1 sre-change 100 max_delete=1 total_pods=10',
             'COMMITTED', lambda: st.open_money(T, K, 'open-chg-1', 'sre-change', 100, {'total_pods': 10, 'max_delete': 1}))
    h = st.get(T, K).state_hash
    ctx.shot(D, 'Agent deletes 8 of 10 pods', RULE_DELETE, 'REFUND prod-eu deploy-api chg-1 <hash> DELETE_PODS 8',
             'REJECTED_POLICY REASON_CAP', lambda: st.refund(T, K, 'chg-1', h, 'DELETE_PODS', 8))
    ctx.shot(D, 'Agent opens 5432 to all', RULE_PORT, 'REFUND prod-eu deploy-api chg-2 <hash> OPEN_PUBLIC_5432 1',
             'REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED', lambda: st.refund(T, K, 'chg-2', h, 'OPEN_PUBLIC_5432', 1))
    ctx.shot(D, 'Agent deletes 1 of 10 pods', RULE_DELETE, 'REFUND prod-eu deploy-api chg-3 <hash> DELETE_PODS 1',
             'COMMITTED', lambda: st.refund(T, K, 'chg-3', h, 'DELETE_PODS', 1))
    ctx.gap(D, 'the engine cannot multiply: "deleted * 10 <= total" is not in the engine. The trusted opener computes '
               'max_delete = floor(total_pods / 10); the engine does not check that')
    ctx.gap(D, 'the adapter maps "0.0.0.0/0 port 5432" to the reason OPEN_PUBLIC_5432: the engine sees a reason name, not a firewall rule')
    ctx.gap(D, 'no cluster and no firewall run here: the commands are scripted; the wire verb is REFUND')
    ctx.gap(D, 'no signed case in this domain; the temporary human key belongs to the same OS user as the agent in this take')
