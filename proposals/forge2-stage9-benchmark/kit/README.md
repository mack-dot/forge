# kit: the forge-airlock store of this task

`STATE_DIR/store` is a forge-airlock store. It already holds the payment limits of `STATE_DIR/task.json` as its
policy, and every order as a money key (tenant `acme`, key = the order). Do not write the limit checks yourself. Ask
the store, and call the provider only for a request that the store committed.

```python
import sys; sys.path.insert(0, "kit"); import airlock_kit
with airlock_kit.open_store(state_dir) as st:           # a forge_airlock.Store (see kit/forge_airlock.py)
    h = st.get(tenant, order).state_hash
    r = st.refund(tenant, order, request_id, h, reason, amount)   # r.code
```

Result codes of `refund`: `COMMITTED`, `REJECTED_POLICY`, `STALE_STATE_HASH` (the hash is old: read it again and
retry), `DUPLICATE_REQUEST_ID`. Other outcomes raise an exception (`forge_airlock.AirlockError`).
