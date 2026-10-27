# Stage 8 blocker: snapshot preserves values but changes the prototype

**PENDING. Scope is frozen. The approved gate is unchanged.**

The user approved the gate additions at
`d2d557e2dcd564049fbd97171b0af67659eacf81`, then instructed us to finish with
contracts, policies and gate files frozen. This diagnostic proposal is not
permission to edit those files. Stage 8 remains CURRENT.

## Observed failure

The real hostile EXIT returned 1. The unchanged approved test reached T2 with
seed 8001. It failed after two generated T2 cases and six shrinks. All three
1,000-case T1 runs and 68 concrete fixtures had passed first.

Fast-check supplied a response record with a null prototype. The compiled model
returned the expected result. The subsequent mutation check compared the input
with `structuredClone({ c, r })`. That clone had normalized the response's null
prototype to Object.prototype. Node's strict assertion therefore rejected the
snapshot comparison, although the primitive fields and original input were
unchanged. The raw output identifies the difference as `[Object: null prototype]`.

The real evidence-separation EXIT returned 1 at the same protected assertion.
Its two fresh source-proof bundles had reproduced byte for byte first. No
passing property-test bundle or completed Stage 8 result was produced.

Records: [hostile failure](../results/stage8/hostile-outputs/attempt-0001/report.json)
and [evidence separation failure](../results/stage8/evidence-separation/attempt-0001/report.json).
Both contain exact commands, actual codes, input identities and archived logs.

## Exact repair for a later, separate decision

Change only the T2 input snapshot in `gate/refund/hostile.ts`. Context and
response records contain primitive fields. Copy those fields into objects with
the original prototypes. Keep the existing strict equality assertion, generated
inputs, seeds, counts, oracle, compiled-model calls and every other gate rule.
This retains prototype identity and field-value mutation checks. It does not
filter out null-prototype inputs or weaken a refund claim.

The [manifest](refund-hostile-snapshot/approval-manifest.json) binds the existing
approved bytes and the exact candidate. The baseline is the approved gate now
included unchanged in this checkpoint, not an assertion that the target already
existed at the older proposal commit.

- Existing SHA-256: `cc3db1659761d16bb123fd984ec84ece6b58c6ec1eebe925602a9f8122987dea`.
- Candidate SHA-256: `0e15d543f42c32b0b6c2b7aab7eb66962dc7c1facde380c44f00a8710a9c475a`.
- Patch SHA-256: `127daf49e2864495ab0651e35e54e0028ca29008f60b091ca43f4d95e27701a5`.
- Manifest SHA-256: `98645de7678354a2892aa48ab4a7d96bcd7ca92ccd13d9b0576be9ba4d54224e`.

The candidate suite was executed directly from `proposals/`, against the actual
generated module and adapter, before the final scope-freeze instruction. It
returned 0 for 9,000 generated cases and 68 fixtures. The protected gate was not
changed or substituted. This is a development result, not a Stage 8 EXIT pass,
canonical accepted integration evidence, or completion of the remaining negative
controls. Input digests and logs are in `results/stage8/snapshot-proposal/`.
The patch dry-run also returned 0 without applying the patch.

Applying this repair would require separate exact approval. Under the current
freeze it remains unapplied. `end_to_end=false`.

## Complete protected diff

```diff
diff --git a/gate/refund/hostile.ts b/gate/refund/hostile.ts
--- a/gate/refund/hostile.ts
+++ b/gate/refund/hostile.ts
@@ -207,7 +207,12 @@
           unavailable(await adapter.decode(badWire[bad]));
         }),
       T2: fc.asyncProperty(contextArb, responseArb, async (c, r) => {
-        const before = structuredClone({ c, r });
+        // These records have only primitive fields. Preserve their prototypes
+        // as well as field values; structuredClone normalizes null prototypes.
+        const before = {
+          c: Object.assign(Object.create(Object.getPrototypeOf(c)), c),
+          r: Object.assign(Object.create(Object.getPrototypeOf(r)), r),
+        };
         assert.deepEqual(assess(c, r), expected(c, r));
         assert.deepEqual({ c, r }, before);
       }),
```
