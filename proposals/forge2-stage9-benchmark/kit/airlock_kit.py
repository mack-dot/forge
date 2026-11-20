"""Opens the airlock store of a benchmark STATE_DIR. Arm C only. It decides nothing.

    import airlock_kit
    with airlock_kit.open_store(state_dir) as st:      # a forge_airlock.Store
        h = st.get(tenant, order).state_hash
        r = st.refund(tenant, order, request_id, h, reason, amount)   # r.code: COMMITTED, REJECTED_POLICY, ...
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import forge_airlock


def open_store(state_dir, timeout=60.0):
    store = os.path.join(state_dir, 'store')
    return forge_airlock.Store(store, timeout=timeout, serve_argv=[os.path.join(HERE, 'airlock-engine'), 'serve', store])
