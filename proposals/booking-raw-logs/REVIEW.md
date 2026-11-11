# Preserve raw native-ledger evidence in the booking experiment

Proposal only. NOT installed, published, merged or dispatched. Stage 12 remains
unauthorized. PR 36's ordinary-upload repair is separate and unchanged.

Independent review of successful run 41523691535 found that the booking proof
logs/TRX are retained, but outer-ledger version, audit and snapshot logs are not.
The receipt records parsed member counts, so those counts cannot be independently
checked against raw native traces from this artifact. The completed run's missing
files cannot be recovered by a later local patch.

[fix.patch](fix.patch) adds only upload paths for those raw logs and the exact
Snapshot/v0/v1 ledger proof inputs. It does not upload entire copied source trees
or historical results. The trusted harness, candidate restriction, acceptance
tests, permissions, immutable actions and bootstrap pins remain unchanged.
It does not add a dependency-invalidation case or enable cross-run evidence reuse.

The exact main preimage and patch/proposed-file hashes are in
[validation.json](validation.json). YAML semantic comparison confirms that only
the existing artifact path changes; git apply --check returned 0. No fixed hosted
upload result is claimed.

Publication and exact-head independent review need separate authorization. This
packet does not authorize approval, merge or dispatch. A later approved workflow
revision also needs a compatible candidate based on that revision and exact-head
execution authorization; do not silently reuse or alter the approved PR 34 head.
