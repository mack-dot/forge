# Decision on the Stage 8 refund contract

The user approved exactly the four protected additions at
[e3aa546f86dc5b43ec8c754792e3db4cb413b410](https://github.com/mack-dot/forge/blob/e3aa546f86dc5b43ec8c754792e3db4cb413b410/proposals/refund.md):

> I approve the exact four protected-file additions in `proposals/refund.md` at commit `e3aa546f86dc5b43ec8c754792e3db4cb413b410`, bound to the published approval manifest and file digests.
>
> This approval is limited to the Stage 8 research contract, protocol, lock, and policy. It does not authorize real refunds or future unspecified gate changes.
>
> Proceed with the approved contract, preserve all existing verification requirements, and prepare any additional protected gate changes for separate exact approval. Keep `end_to_end=false`.

The published candidate Git blob identities, manifest, and patch were checked
against that commit's tree. All four target paths were absent. The exact candidate
bytes were then copied to these targets:

| Target | SHA-256 |
| --- | --- |
| `spec/refund/RefundSpec.dfy` | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` |
| `spec/refund/protocol.md` | `5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4` |
| `spec/refund/spec.lock` | `993dade887f6141e9a9e27ae78e17b6cc2545923f334d83c17aad40bc3b28b57` |
| `policy/refund.yaml` | `4409904602e6b670c0fbf773b8f303426e22e0caac077f3d6ed5f016cecf2c83` |

Approved patch SHA-256:
`a19163b9db66b6a260bd6fb1f6e27cc49fa654a87aa5b4fe959191ee52065ef3`.
The historical proposal and pending manifest remain unchanged. The adoption
record is `results/stage8/contract-adoption/identity.json`.

This records conversational intent approval. It is not a signed user
attestation, a proof result, permission to execute real refunds, or permission
to change gates. New protected gate additions need separate exact approval.
Existing verifier requirements remain in force. `end_to_end=false`.
