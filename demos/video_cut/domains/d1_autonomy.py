"""Domain 1, spacecraft autonomy (also Scene 2 of the video). Policy: demos/video_cut/policies/ship-autonomy.json
(money airlock, parametric). The store has a pinned human cosign key.

Mapping. The engine has no spacecraft rule. Its money airlock tests the sum of one reason against a trusted
fact of the key, and it can demand a human signature for a reason. The wire verb is REFUND; the reason names
the command and the amount is a count (1 = one command). One key is one bay. A trusted opener opens the key
with the facts. It shows crew_in_bay=1 and it derives vents_allowed=0 from it (crew in the bay: no vent).
- VENT_BAY: committed vents + amount <= fact vents_allowed. With vents_allowed=0: REJECTED_POLICY REASON_CAP.
- OVERRIDE_BAY_LOCK: REQUIRE_HUMAN_COSIGN. No signature: COSIGN_REQUIRED. A signature by another key:
  COSIGN_INVALID. The signature of the pinned human key: the request commits (record cosign flag 1).
- CYCLE_AIR_FILTER: amount <= 1 commits (the routine command).

Labels. Every shot: NATIVE CHECK + FINITE TEST (Rust engine, not proved). The signature check is Ed25519
through Node (trusted). Nothing in this module is PROVED. end_to_end=false.

Gaps (also printed by ctx.gap).
- The engine cannot test "crew_in_bay == 0". It tests a sum against a fact. The trusted opener derives
  vents_allowed from crew_in_bay; the engine does not check that derivation. crew_in_bay is shown only.
- The override is a separate reason. A cosigned override commits; the engine does not then test vents_allowed.
- The temporary human key belongs to the same OS user as the agent in this take (PROTOCOL.md section 7).
  The take shows the cosign mechanism, not the separation that "the agent cannot self-cosign" needs.
- native ssh-keygen cosign: NOT IN TAKE (not on main).
- No AI model and no ship run here. The commands are scripted. The wire verb is REFUND.
"""
import forge_airlock as fa
from constants import AI_NAME, SHIP_NAME, HUMAN_NAME, BAY_NAME

NUMBER, NAME, TITLE = 1, 'autonomy', 'Spacecraft autonomy'
D = 'autonomy'
T, K = 'ship-1', 'bay-3'  # engine ids; the display names are used in headlines only
LBL_COSIGN = 'NATIVE CHECK + FINITE TEST; Ed25519 verify through Node (trusted)'
RULE_OPEN = 'trusted opener sets the facts: crew_in_bay=1 (shown); it derives vents_allowed=0 from it'
RULE_VENT = 'VENT_BAY: committed vents + amount <= fact vents_allowed (trusted, 0; the opener derives it from crew_in_bay=1)'
RULE_OVERRIDE = 'OVERRIDE_BAY_LOCK: REQUIRE_HUMAN_COSIGN (commit only with a valid signature of the pinned human key)'
RULE_ROUTINE = 'CYCLE_AIR_FILTER: amount <= 1 COMMIT'


def run(ctx):
    st = ctx.store('ship', ['ship-autonomy.json'], cosign=True)
    ctx.shot(D, '%s: %s opened' % (SHIP_NAME, BAY_NAME), RULE_OPEN,
             'OPEN_MONEY %s %s open-bay-3 ship-autonomy 100 crew_in_bay=1 vents_allowed=0' % (T, K),
             'COMMITTED', lambda: st.open_money(T, K, 'open-bay-3', 'ship-autonomy', 100, {'crew_in_bay': 1, 'vents_allowed': 0}))
    h = st.get(T, K).state_hash
    ctx.shot(D, '%s vents %s' % (AI_NAME, BAY_NAME), RULE_VENT, 'REFUND %s %s ai-vent-1 <hash> VENT_BAY 1' % (T, K),
             'REJECTED_POLICY REASON_CAP', lambda: st.refund(T, K, 'ai-vent-1', h, 'VENT_BAY', 1))
    ctx.shot(D, '%s tries an override' % AI_NAME, RULE_OVERRIDE, 'REFUND %s %s ai-ovr-1 <hash> OVERRIDE_BAY_LOCK 1' % (T, K),
             'REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED', lambda: st.refund(T, K, 'ai-ovr-1', h, 'OVERRIDE_BAY_LOCK', 1), LBL_COSIGN)
    forged = ctx.sign(st, fa.refund_action(T, K, 'ai-ovr-2', h, 'OVERRIDE_BAY_LOCK', 1), stranger=True)
    ctx.shot(D, 'Override, forged signature', RULE_OVERRIDE,
             'REFUND %s %s ai-ovr-2 <hash> OVERRIDE_BAY_LOCK 1 <signature by another key>' % (T, K),
             'REQUIRE_HUMAN_COSIGN COSIGN_INVALID',
             lambda: st.refund(T, K, 'ai-ovr-2', h, 'OVERRIDE_BAY_LOCK', 1, signature=forged), LBL_COSIGN)
    ctx.shot(D, '%s cycles the air filter' % AI_NAME, RULE_ROUTINE, 'REFUND %s %s ai-filter-1 <hash> CYCLE_AIR_FILTER 1' % (T, K),
             'COMMITTED', lambda: st.refund(T, K, 'ai-filter-1', h, 'CYCLE_AIR_FILTER', 1))
    h2 = st.get(T, K).state_hash
    real = ctx.sign(st, fa.refund_action(T, K, 'human-ovr-1', h2, 'OVERRIDE_BAY_LOCK', 1))
    ctx.shot(D, '%s signs the override' % HUMAN_NAME, RULE_OVERRIDE,
             'REFUND %s %s human-ovr-1 <hash> OVERRIDE_BAY_LOCK 1 <signature by the pinned human key>' % (T, K),
             'COMMITTED', lambda: st.refund(T, K, 'human-ovr-1', h2, 'OVERRIDE_BAY_LOCK', 1, signature=real), LBL_COSIGN)
    flags = [r[-1] for r in ctx.replay('ship') if r[0] == 'REFUND' and r[3] == 'human-ovr-1']
    ctx.note(D, 'cosign flag of the human-ovr-1 record in the WAL (engine replay)', flags, 'measured live')
    ctx.gap(D, 'the engine cannot test "crew_in_bay == 0": it tests a sum against a fact. The trusted opener derives '
               'vents_allowed from crew_in_bay; the engine does not check that derivation')
    ctx.gap(D, 'the override is a separate reason: a cosigned override commits and the engine does not then test vents_allowed')
    ctx.gap(D, 'the temporary human key belongs to the same OS user as the agent in this take (PROTOCOL.md section 7): '
               'the take shows the cosign mechanism, not the separation that "the agent cannot self-cosign" needs')
    ctx.gap(D, 'native ssh-keygen cosign: NOT IN TAKE (not on main)')
    ctx.gap(D, 'no AI model and no ship run here: the commands are scripted; the wire verb is REFUND')
