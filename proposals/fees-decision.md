# Decision on the fee proposal

The user approved the published fee proposal as written by replying **yes** to
the explicit approval request in this task.

The approved text is frozen at
[revision 648229df2d0e13e8d872e0a867ab0ce940ea8146](https://github.com/mack-dot/forge/blob/648229df2d0e13e8d872e0a867ab0ce940ea8146/proposals/fees.md).
Its original pending-status text is historical. Do not edit that approved proposal.

The trusted [approval record](../gate/approvals/fees-v2.json) binds the original
and new spec and lock digests. The gate reads that record from the trusted base,
never from candidate-owned approval metadata. A later change to the approved
spec bytes requires a new proposal and approval.

This records conversational intent approval. It is not a signed user attestation
or proof of the implementation. Real checker results are recorded separately.
