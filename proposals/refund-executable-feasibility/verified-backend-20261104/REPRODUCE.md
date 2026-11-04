# Reproduce the local sub-obligation

This is an experimental proof replay, not a production acceptance command.
Use a fresh directory. Do not load candidate-supplied exported theories as
proof of their contents. Do not replace the approved refund contract with the
byte-string sub-obligation. No hosted or native refund result is claimed.

1. Fetch the exact CakeML, HOL4 and Poly/ML commits in `REPORT.md`. Check their
   Git identities and object integrity. Keep the supplied upstream licenses.
2. Build Poly/ML and HOL4 from source. `tool-build/commands.json` records the
   actual argument arrays, working directories and local timings. Set a fresh
   experiment prefix in the new process environment; retain all original logs.
   The recorded build used existing GMP6.3.0. Record your own host/tool hashes.
3. In the pinned CakeML checkout create an experiment directory under
   `compiler/dafny/`. Copy `refund_kernel/forge_refundScript.sml` and the
   supplied `refund_kernel/Holmakefile`. The inherited HOL project uses the
   locally built HOL tree. Run that tree's `bin/Holmake --no-cache -j 2
   forge_refundTheory.uo`. Require actual exit0 and execution of both theorem
   proofs. The script itself defines the exact propositions and prints tags.
4. In separate clean experiment directories run each negative source from
   `refund_kernel/negative-over-limit/` and `negative-reject-all/`. Require
   actual exit1 at the intended theorem, respectively the unsolved amount
   bound and the false result goal. Infrastructure or parser errors do not
   satisfy these tests. `negative-controls-result.json` records this run.
5. Rebuild the original source with prior exports held outside the build
   directory and caching disabled. Require proof execution and compare all
   exported bytes. The original run and repeat records are retained. This
   run's six exports match; that does not promise cross-host object identity.
6. Run the retained closure audit in a fresh HOL process against the freshly
   rebuilt libraries. Inspect tags, hypotheses, all imported theories and
   foundation axioms. The four explicit HOL axioms remain in the trust base.
7. In `compiler/dafny/proofs/`, run the same `Holmake --no-cache -j 2
   dafny_to_cakemlProofTheory.uo`. This upstream proof replay returned0 here.
   It does not instantiate the compiler theorem for refund automatically.
8. The Unicode witness uses the original pinned Dafny4.11.0/Z34.12.1 checker.
   Replay the exact argument arrays in `unicode-witness-0002/commands.json`
   against the copied approved sources. Require witness0 and false equality4
   with its intended assertion error. The earlier syntax errors stay archived.

The supplied Python harnesses are records of the original local experiment.
Their absolute paths describe that run. Use fresh paths for another run; do
not overwrite existing result directories or reuse old result flags as proof.
Keep every new command, actual exit, failure, source identity and artifact hash.

Next proof task: apply the published `correct_from_stmt` relation to the exact
refund body and generated CakeML expression, discharging its static premises.
Then establish the full Unicode representation and checked calling/output
relation before claiming the approved component's executable behavior.
