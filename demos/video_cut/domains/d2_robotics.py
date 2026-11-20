"""Domain 2, robotics envelope. Policy: demos/video_cut/policies/robot-envelope.json (money airlock, parametric).

Mapping. The engine has no robotics rule. Its money airlock holds integer bounds: `max_amount` (a bound on
one request) and `max_reason_total_fact` (a bound on the sum of one reason against a trusted fact of the
key). The wire verb is REFUND; the reason names the command and the amount is the command's number.
One key is one command window that a trusted controller opened with its facts.

Gaps (also printed by ctx.gap): no 2-D or 3-D geofence (one radius number only, computed by the caller);
a committed number is subtracted from the key's `original`, so one key is one command window, not a
continuous control loop; the model behind the command is not in this module.
"""
NUMBER, NAME, TITLE = 2, 'robotics', 'Robotics envelope'
D = 'robotics'
RULE_SPEED = 'SET_SPEED_MM_S: amount <= 1500 COMMIT; amount >= 1501 REJECTED_POLICY'
RULE_REACH = 'REACH_MM: total + amount <= fact geofence_radius_mm (trusted, 800)'


def run(ctx):
    st = ctx.store('robot', ['robot-envelope.json'])
    ctx.shot(D, 'Controller opens arm window', 'trusted opener sets the facts', 'OPEN_MONEY cell-7 arm-1 ... geofence_radius_mm=800',
             'COMMITTED', lambda: st.open_money('cell-7', 'arm-1', 'open-arm-1', 'robot-envelope', 100000, {'geofence_radius_mm': 800}))
    h = st.get('cell-7', 'arm-1').state_hash
    ctx.shot(D, 'Robot speed 3.5 m/s', RULE_SPEED, 'REFUND cell-7 arm-1 vla-1 <hash> SET_SPEED_MM_S 3500',
             'REJECTED_POLICY RULE', lambda: st.refund('cell-7', 'arm-1', 'vla-1', h, 'SET_SPEED_MM_S', 3500))
    ctx.shot(D, 'Reach outside the geofence', RULE_REACH, 'REFUND cell-7 arm-1 vla-2 <hash> REACH_MM 900',
             'REJECTED_POLICY REASON_CAP', lambda: st.refund('cell-7', 'arm-1', 'vla-2', h, 'REACH_MM', 900))
    ctx.shot(D, 'Safe speed 1.2 m/s', RULE_SPEED, 'REFUND cell-7 arm-1 vla-3 <hash> SET_SPEED_MM_S 1200',
             'COMMITTED', lambda: st.refund('cell-7', 'arm-1', 'vla-3', h, 'SET_SPEED_MM_S', 1200))
    ctx.gap(D, 'geofence: the engine holds one integer bound (a radius in mm that the caller computes), not a 2-D or 3-D region')
    ctx.gap(D, 'the wire verb is REFUND and a committed number is subtracted from the key total: one key is one command window')
    ctx.gap(D, 'no VLA model runs here: the commands are scripted worst cases')
