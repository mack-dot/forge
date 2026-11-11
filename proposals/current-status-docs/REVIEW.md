# Current-status documentation correction

Problem: main's ROADMAP still names Stage9 as current. README mixes historical
and current descriptions. Newer source and execution records describe Stage11
merged, the hosted booking experiment, and the outstanding integration boundary.

Base: f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3.
Files: README.md and ROADMAP.md only.
Patch: main-docs.patch. Exact proposed full files are retained alongside it.

The patch adds a current integration summary, labels the older Stage9 preface as
historical, and corrects the claim that binary checking/deployment identity are
entirely future work. It preserves end_to_end=false and the distinction between
model proofs, observed execution, provenance and deployed-file identity.

Validation: git apply --check against the inspected main returns0.
No semantic test was needed for these text changes. The patch is not applied,
committed, published or merged. Existing coverage behavior for this documentation
change is NOT RUN; no exception or green-check claim is made.

Neither path is in the current implementation lock. No spec,policy,gate,workflow
or branch protection changes. No research-stage transition occurs.

Publication requires its own grant under the master mission. Independent review
and any later merge authority remain separate. This packet is ready for review;
it is not authorization to bypass current fail-closed coverage.

