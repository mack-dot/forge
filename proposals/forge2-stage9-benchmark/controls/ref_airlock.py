"""Oracle control, NOT a competitor: the decision comes from the airlock store; the provider runs only after COMMITTED."""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'kit'))
import airlock_kit

state = sys.argv[1]
q = json.load(sys.stdin)
status = 'REJECTED'
if isinstance(q['amount'], int) and q['amount'] > 0:
    with airlock_kit.open_store(state) as st:
        for _ in range(50):
            try:
                h = st.get(q['tenant'], q['order']).state_hash
                r = st.refund(q['tenant'], q['order'], q['request_id'], h, q['reason'], q['amount'])
            except airlock_kit.forge_airlock.AirlockError:
                break
            if r.code == 'STALE_STATE_HASH':
                continue
            status = {'COMMITTED': 'PAID', 'DUPLICATE_REQUEST_ID': 'DUPLICATE'}.get(r.code, 'REJECTED')
            break
if status == 'PAID':
    subprocess.run([sys.executable, os.path.join(HERE, 'provider.py'), state, q['order'], q['request_id'], q['reason'],
                    str(q['amount'])], check=True, stdout=subprocess.DEVNULL)
print(json.dumps({'status': status}))
