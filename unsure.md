# Uncertainty log

This is an append-only log. Never edit or remove an existing entry, including
its status. Add a new entry with a new ID to correct or resolve a prior entry.
Reference the earlier ID. A hypothesis is not a result. Operational observations
here are not proof evidence.

## U001 — Ledger behavior choices

- Status: OPEN. Stage: 1; do not implement during Stage 0.
- Known: C1–C5 and rejection of self-transfers are required.
- Unsure: zero amounts, account existence, integer bounds, request-ID conflicts,
  and whether rejected requests alter retry records need exact definitions.
- Impact: different choices change valid inputs and the meaning of C3/C5.
- Next check: present the initial behavior contract for human intent approval
  before freezing the spec. Do not resolve ambiguity through code repairs.

## U002 — Binary coverage for this project's claims

- Status: OPEN. Stage: 7.
- Known: the published Theorem pipeline checks claims about specific RISC-V
  binaries. Our roadmap starts with an upstream replay and an own no-crash proof.
- Unsure: whether the selected core and desired functional properties fit the
  pinned pipeline at an acceptable resource cost. No local replay has run.
- Impact: no-crash evidence cannot establish ledger conservation or all deployed
  service behavior. Keep `end_to_end=false` while required links are missing.
- Next check: run the upstream replay when Stage 7 becomes CURRENT, then the own
  proof and required independent check. [Upstream checking procedure](https://github.com/theorem-labs/oss-verify-proofs/blob/main/docs/checking.md)

## U003 — Complete dependency tracking for incremental checks

- Status: OPEN. Stage: 4.
- Known: hashing changed files alone cannot identify every affected claim.
- Unsure: whether the pinned backend exposes enough dependency information for
  the intended member-level reuse without unsafe omissions.
- Impact: a missed dependency could reuse evidence that no longer applies.
- Next check: compare selective checks with full verification on controlled
  changes. Block or broaden checks whenever dependency coverage is uncertain.

## U004 — Broad usefulness and cost

- Status: HYPOTHESIS. Stages: 6 and 10.
- Known: useful candidates include small components with explicit invariants.
- Unsure: setup effort, spec maintenance, proof failure rates, and cost per real
  PR have not been measured for this system. No productivity benefit is established.
- Impact: do not promise usefulness for every task or extrapolate savings.
- Next check: benchmark reuse in Stage 6 and observe actual PRs for Stage 10.

## U005 — Existing runtime provenance

- Status: PARTIALLY OBSERVED. Stage: 0.
- Observed: `node --version` returned `v24.3.0`; `python3 --version` returned
  `Python 3.10.11`. Both succeeded. Their executable SHA-256 values are recorded
  in `toolchain/pins.json`. The host reports Darwin ARM64 and macOS 27.0.1.
- Unsure: executable hashes alone do not validate entire distributions or their
  libraries. Distribution validation and a reproducible installation path remain
  unfinished. No fresh runtime installation has been claimed.
- Next check: validate and record the distributions during Stage 0. Retain the
  incomplete toolchain status until every required check has run.

## U006 — Dafny installation and host compatibility

- Status: OPEN. Stage: 0.
- Observed: no `dafny`, `dotnet`, or `z3` executable was found on PATH. The
  official release lists an ARM64 macOS archive for Dafny 4.11.0 and its SHA-256.
  The archive URL and checksum are recorded in `toolchain/pins.json`.
- Unsure: this session can download the archive, the archive runs on this host,
  and the bundled Z3 executes correctly. None has been established locally.
- Next check: download the pinned archive, verify its published digest, then run
  version and true/false lemma checks. If installation or execution fails, stop
  under the roadmap's hard rule. [Official release assets](https://github.com/dafny-lang/dafny/releases/expanded_assets/v4.11.0)

## U007 — GitHub publication and license

- Status: OPEN. Publication is pending.
- Observed: the connected GitHub account is `mack-dot`. The earlier CLI API
  request exited 1 with `error connecting to api.github.com`. No repo was created.
- Unsure: the initial authentication warning may reflect that connection failure;
  it does not establish that credentials are invalid. The connected app cannot
  create a repository with its available tools.
- Next check: retry the authorized public-repository creation when CLI connectivity
  is available. Choose an explicit open-source license before release.

## U008 — Stage 0 download attempt

- Status: ATTEMPT STARTING; success is not assumed.
- Command: `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip`
- The invocation appends any download diagnostic below. Its actual exit code is
  reported by the command runner. If it fails, make no further changes in that run.

Download diagnostic:
curl: (6) Could not resolve host: github.com

## U009 — Download failure confirmed; one reachability retry

- References: U006, U008.
- Observed: U008 returned exit code 6 with `curl: (6) Could not resolve host: github.com`.
- Current state: the pinned archive is absent. Dafny installation and all proof
  checks remain unexecuted. This is an installation blocker, not a proof failure.
- Unsure: whether network reachability has changed since the first attempt.
- Next check: rerun the same pinned download once. Stop immediately if it fails.
  If connectivity remains unavailable, the official archive must be supplied
  at `.toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip`. Its required SHA-256 is
  `c90c75e7d5db9c6ccbb7127840dfe43f0ac938b039a7ebed146d8ead383a572f`.

Retry diagnostic:
curl: (6) Could not resolve host: github.com

## U010 — Installation blocker audit

- References: U006, U008, U009.
- Observed: the second download returned exit code 6 with the same DNS error.
  On this third consecutive goal turn, neither Dafny on PATH nor the pinned
  archive is available. There is no running installation to wait for.
- Required external change: restore access to the official release, or supply
  the exact archive and validate it against the recorded SHA-256.
- Next check: make one final download attempt to revalidate reachability. If it
  fails again, mark the goal blocked. Keep Stage 0 CURRENT and all Dafny proof
  checks NOT RUN. Do not start Stage 1 or substitute another verifier.

Final reachability diagnostic:
curl: (6) Could not resolve host: github.com

## U011 — User-requested download retry

- References: U006, U010.
- Observed: the third prior attempt exited 6 with the same DNS error.
- New input: the user requested another attempt. Connectivity may have changed.
- Next check: retry the pinned official archive download. If it succeeds, verify
  its SHA-256 before extraction, then continue Stage 0. Success is not assumed.

User-requested retry diagnostic:
curl: (6) Could not resolve host: github.com

## U012 — Available installation routes checked

- References: U006, U011.
- Observed: U011's download returned exit code 6. No matching Dafny archive was
  found in the project download folder, Downloads, Homebrew cache, or `/private/tmp`.
- Observed: the connected GitHub fetch tool explicitly rejects binary responses.
  Its attachment downloader supports private image attachments only. Neither
  tool can download the Dafny release archive. No available tool changes this
  session's network permissions.
- Limitation: the shell reports a DNS error; the precise cause is not established.
  This session also has restricted network access. Do not bypass that restriction
  with alternative endpoints, proxying, or changes to system network settings.
- Next check: one direct download attempt following the user's instruction.
  If it fails, run the official download in a terminal outside this session, or
  change the session's network access externally. Then verify the pinned checksum
  here before installation. No proof or installation success is claimed.

Latest direct download diagnostic:
curl: (6) Could not resolve host: github.com

## U013 — Local Dafny archive available and checksum verified

- References: U006, U008–U012.
- New input: the user reported installing Dafny. A subsequent directory listing
  found `.toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip` (54,789,814 bytes).
- Observed: `shasum -a 256 -c` returned 0 and matched the pinned official SHA-256,
  `c90c75e7d5db9c6ccbb7127840dfe43f0ac938b039a7ebed146d8ead383a572f`.
- Resolution: the archive acquisition blocker is resolved for Stage 0. This does
  not establish that shell networking or GitHub publication now works.
- Remaining uncertainty: the archive must still be extracted and its tools run.
  No Dafny proof result is claimed by the checksum check.

## U014 — Multiple bundled Z3 executables

- References: U006, U013.
- Observed: the archive lists both `z3-4.12.1` and `z3-4.14.1`.
- Decision for Stage 0: select bundled Z3 4.12.1 explicitly, pin its executable
  digest, and pass its path to Dafny. Do not let PATH select another solver.
- Next check: run the actual version commands and inspect the installed Dafny CLI
  help before setting resource and timeout options. Execution is not yet verified.

## U015 — Runtime and solver checks completed; provenance limit retained

- References: U005, U006, U013, U014.
- Observed: archive extraction exited 0. Dafny reported
  `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` with exit 0. The explicitly
  selected bundled solver reported `Z3 version 4.12.1 - 64 bit` with exit 0.
- Observed: the installed Dafny CLI help confirms that time-limit 0 disables the
  verification time limit and that `--resource-limit` controls Z3 resources.
- Observed: with identical locked options, the true lemma exited 0 with one
  verified declaration; the false lemma exited 4 with a diagnostic for its false
  postcondition. The raw outputs are in `toolchain/results/`.
- Observed: fresh Node and Python version commands each exited 0 and matched
  pins 24.3.0 and 3.10.11. Their existing installations are reused, not reinstalled.
- Remaining uncertainty: the original Node/Python installer archives were not
  authenticated. A Homebrew receipt identifies Node as bottle-installed; no
  Python receipt matched the queried `org.python.*` prefix. That does not prove
  an invalid Python installation. Executable hashes do not cover all libraries.
- Scope decision: record the preinstalled runtimes and host components as trusted
  inputs. Keep `distribution_checksum_verified=false` for Node/Python. These
  provenance limits do not change the specified Stage 0 version and smoke EXITs.

## U016 — Stage 0 complete; later uncertainties remain open

- References: U005, U006, U013–U015.
- Observed: `shasum -a 256 -c toolchain/checksums.sha256` exited 0 and matched all
  five recorded entries: the Dafny archive, Dafny executable, selected Z3
  executable, Node executable, and Python executable.
- Observed: `dafny --version` also ran through a shell-local PATH setting and
  exited 0 with the pinned version. No global shell configuration changed.
- Resolution: the specified Stage 0 EXITs have run with the required results.
  Stage 0 is DONE; Stage 1 is CURRENT. Work stops at this transition.
- Remaining limits: U001–U004 concern later stages. U007 publication is still
  pending. U015's runtime-provenance assumptions remain disclosed and unresolved.

## U017 — Initial ledger intent proposed; approval pending

- References: U001.
- Finding: a success result alone does not require the requested funds to move.
  The proposed C4 therefore specifies exact sender and recipient balance changes,
  unchanged other accounts, and insertion of the accepted request record.
- Proposed choices: integer amounts greater than zero; existing distinct accounts;
  unbounded integer balances; no fees; exact-balance transfers allowed. Accepted
  request IDs bind to their full payload. An exact retry returns Ok without change.
  Reusing an accepted ID with different arguments is rejected without change.
- Proposed rejection scope: invalid requests change neither balances nor accepted
  records. A rejected request is not cached and may become valid after other
  transfers. This differs from permanently caching every rejected result.
- Observed: the draft's first two resolver runs exited 2 for syntax and indentation
  diagnostics. Only those reported issues were corrected. The third run exited 0;
  Dafny explicitly reported that it did not attempt verification.
- Pending: human approval of the concrete contract and diff in
  `proposals/initial-ledger.md`. The draft is not installed under `spec/`, and no
  implementation claim or Stage 1 EXIT is established. Stop for that approval.

## U018 — Initial intent approval received and applied

- References: U001, U017.
- New input: the user explicitly approved the proposal as written and requested
  publication to a public Forge repository for other agents to follow.
- Observed: the candidate still matches SHA-256
  `e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`.
- Resolution: copied those exact approved bytes to `spec/LedgerSpec.dfy` and
  created `spec.lock`. The approved input, retry, and rejection decisions resolve
  U001's intent questions for this baseline. No implementation proof is claimed.

## U019 — Public repository creation remains unconfirmed

- References: U007, U012.
- Observed: a fresh `gh api user` invocation exited 1 with
  `error connecting to api.github.com`. Authentication warnings are not sufficient
  to diagnose invalid credentials while connectivity itself fails.
- Observed: the connected app returned 404 for `mack-dot/forge`. That response
  does not distinguish an absent repository from one the app cannot access.
  The app can write repository files but has no repository-creation operation.
- Observed: `git init -b main` exited 1 with
  `/Users/mackianni/forge/.git: Operation not permitted`. The workspace's `.git`
  path is read-only under this session's filesystem permissions.
- Next step: prepare the approved workspace for publication and attempt the
  explicitly authorized public-repository creation with the GitHub CLI. Do not
  report publication until the repository and its uploaded contents are verified.

## U020 — Gate development findings and corrections

- Observed: the concrete ledger verified on its first run with 12 verified
  obligations and no errors. Dafny's audit reported zero findings. The initial
  gate accepted it and produced five source_proof records with end_to_end=false.
- Observed: the first reproducibility, stale-spec-lock, and audit-control runs
  passed. The planted-bug run stopped because the gate did not name C1 for the
  self-transfer fixture. The source offset confirms Dafny JSON lines are one-based;
  the adapter had incorrectly added one. Corrected that diagnostic mapping.
- Observed: the initial empty abstract-import binding control rejected the
  deliberately weak candidate for missing proof coverage, not the expected
  refinement diagnostic. An empty binding module alone is not sufficient evidence
  for this adapter's contract-binding requirement.
- Correction: require the exact source preamble declaring `module Ledger refines
  LedgerSpec` and the sole approved include. Dafny still checks the actual
  refinement and all proof obligations. Retain the existing coverage requirement.
  This narrows accepted source formatting; it does not weaken verification.
- The approved spec and spec.lock are unchanged. Rerun the affected checks and
  regenerate evidence because the gate and binding-harness digests changed.

## U021 — Repository creation attempt failed

- References: U019.
- Observed: `gh repo create mack-dot/forge --public --description 'Proof-gated changes: LLMs propose, established checkers decide, reproducible evidence records what was established.'`
  exited 1 with `error connecting to api.github.com`.
- Publication is not established. The user was asked to create an empty public
  `mack-dot/forge` repository. Once it is accessible, the connected app can upload
  these files without writing the protected local `.git` directory.

## U022 — Final Stage 1 run preparation

- References: U020.
- Observed: after the diagnostic and binding fixes, all required Stage 1 checks
  returned 0. All four planted bugs passed the fixed basic unit suite and were
  rejected by the gate. The self-transfer, off-by-one, and retry fixtures caused
  actual verifier exit 4. Direct audit comparison of sneaky_assume exited 2.
- Observed: Dafny writes a `.expect` diagnostic file beside the audit comparison
  baseline when the comparison fails. The gate now copies the unchanged baseline
  into its temporary build directory before invoking that same comparison.
  Acceptance criteria are unchanged; generated reports no longer target gate/.
- Logging improvement: audit rejection messages include the actual auditor exit
  code. Scenario runs archive existing logs before replacing the current report.
  Earlier failed attempts remain explicitly recorded in U020 and ROADMAP.md.
- Next check: run the final gate revision and its EXIT scenarios, then freeze the
  real run record and stop at the stage transition.

## U023 — Final Stage 1 results and remaining publication blocker

- References: U018–U022.
- Observed: the final gate command exited 0 and accepted C1–C5 as source_proof.
  The reproducibility, planted-bugs, spec-lock, contract-binding, and audit-controls
  scenario commands each exited 0. The real run record is in results/stage1.json.
- Observed: self_transfer, off_by_one, and retry_double passed the basic unit
  suite with exit 0 and caused verifier exit 4 and gate exit 1. sneaky_assume
  passed that unit suite with exit 0 and caused audit exit 2 and gate exit 1.
  Audit failures establish forbidden assumptions or unchecked code, not a
  counterexample to each affected claim. Diagnostic C1 on retry_double means
  unestablished by that run; it does not establish a conservation violation.
- Observed: changed-spec/old-lock and missing-refinement controls each caused
  gate exit 1. Bodiless-lemma, axiom-lemma, and verify-false controls each caused
  direct audit exit 2 and gate exit 1. Their scenario scripts correctly returned 0.
- Observed: current source, trusted-input, fixture, and evidence digests match
  the recorded values. The approved spec equals the proposal byte for byte.
  `cmp evidence.json build/stage1/reproducibility/evidence.json` exited 0.
- Scope: end_to_end=false records absent binary and deployment coverage.
  It is not a ledger proof failure. No later-stage work has started.
- Publication: a final connected-app lookup still returned 404 for mack-dot/forge.
  Missing repository and missing app access remain indistinguishable. Prior
  CLI connection and local .git permission failures remain unresolved. The app
  cannot create repositories. No upload or public visibility is established.
- Continuation: the goal tracker still reports blocked from the earlier wait.
  User approval resolved the initial-spec decision; it did not change the tracker
  state or network permissions. Resuming the goal does not fix repository access.
- Next action: record Stage 1 DONE and Stage 2 CURRENT in ROADMAP.md, then stop.
  Publication requires an accessible public repository or restored CLI access.

## U024 — Full roadmap continuation authorized

- References: U023.
- New input: the user resumed the goal and requested the entire roadmap in order,
  with binary and deployment coverage addressed when those stages are reached.
- Resolution: the earlier blocked goal state no longer describes continuation.
  Stage transitions still end each run; the active goal can continue in a new run.
- Scope: Stage 7 covers binary proof work. Stage 9 covers signed provenance and
  deployed identity. Keep end_to_end=false until the required links are checked.
- Remaining limits: this instruction does not establish GitHub access, approve
  future spec diffs, or permit simulated results. Existing publication blockers
  remain open, and later spec changes still require concrete human approval.

## U025 — Stage 2 validator provenance and evidence authority

- References: U015, U023, U024.
- Observed: installed jsonschema 4.21.1 and PyYAML 6.0.1 imported successfully.
  Draft202012Validator checked a schema and validated an instance; process exit 0.
  Runtime and transitive dependency versions and installed file digests are now
  pinned in toolchain/validator-pins.json and requirements-stage2.txt.
- Limit: original package archives were not independently authenticated. These
  are observed installation pins, not proof of distributor identity. Native
  dependency bytes are specific to this host platform.
- Decision: policy uses explicit allowed methods per required claim and tier,
  without a universal ranking or automatic method upgrades. Stage 2 evidence
  will bind the policy version and content hash.
- Decision: schema validation alone establishes document structure. Imported
  evidence must match current artifact inputs and policy, then match a fresh
  backend run before acceptance. Local unsigned evidence cannot authorize itself.
- Preservation: exact Stage 1 evidence, gate source, and scenario source are
  archived under results/stage1/ before the planned Stage 2 refactor.
- Preparation: the first archive/pin script exited 1 at parse time because a
  bytes literal contained a Unicode dash. No script statements executed.
  The corrected script encodes the text as UTF-8.
- Next check: actual Stage 2 accept/reject scenarios and all Stage 1 regressions.

## U026 — Stage 2 checks completed with Stage 1 behavior preserved

- References: U020, U023, U025.
- Observed: the refactored gate exited 0 and produced format-2 evidence with
  schema version 2.0.0 and policy forge-ledger 1.0.0, tier critical. Dafny
  established the same 12 obligations. All five evidence methods remain
  source_proof and end_to_end remains false.
- Observed: the schema, artifact-mismatch, method-policy, round-trip, and
  policy-controls scenario commands each exited 0. Actual child codes are in
  results/stage2.json. Both the legacy and current bundles passed the established
  schema validator. Three altered artifact bindings caused gate exit 1.
- Observed: critical policy rejected unit_tested, bounded_model_checked, and
  kernel_checked_proof labels with gate exit 1. These were deliberately edited
  rejection inputs, not claims that those methods had run. No method was upgraded.
- Observed: a valid supplied bundle passed a fresh real backend run; cmp exited 0.
  A forged producer with otherwise valid bindings failed the fresh-result
  comparison with gate exit 1. Fifteen policy/claim/provenance/format controls
  each returned the intended rejection. Failed checks left no accepted output.
- Observed: all five Stage 1 scenario commands also exited 0. The three functional
  bugs still caused actual verifier exit 4; sneaky_assume still caused audit exit
  2. All four fixtures passed the deliberately incomplete unit suite with exit 0
  and failed the gate with exit 1. Extra audit controls still failed as intended.
- Observed: the approved spec and spec.lock are unchanged. Current input hashes
  match the new evidence. The Stage 1 archive matches its prior recorded digest.
  cmp of root evidence against the Stage 1 reproducibility rerun exited 0.
- New evidence SHA-256:
  0400b148904360eb3fde1940acaf73ba0a1342f9244da8cf1f69046a6c9d4e16.
- Remaining limits: schema validation is structural only. The gate remains a
  trusted local process with unsigned evidence. Original validator package
  archives remain unauthenticated as disclosed in U025. No binary or deployment
  coverage is established, and a final GitHub lookup still returned 404.
- Resolution: Stage 2 EXITs are established. Record Stage 2 DONE and Stage 3
  CURRENT, then stop this run. Do not claim that publication or later work is done.

## U027 — Stage 3 JavaScript dependencies are not yet installed

- References: U015, U024, U026.
- Observed: node --version exited 0 with v24.3.0. npm --version exited 0 with
  11.10.0. The pinned Dafny build --help command exited 0 and supports the JS
  target, explicit output, and the same verification resource options.
- Observed: targeted searches found no installed fast-check, tsx, or bignumber.js
  in the checked project locations. The cache index lists some TypeScript-tool
  archives, but that does not establish a complete usable dependency installation.
- Observed: npm view fast-check@4.3.0 version dependencies dist.integrity --offline
  --logs-max=0 and the equivalent tsx@4.21.0 command each exited 1 with ENOTCACHED:
  cache mode is only-if-cached but no cached response is available.
- Plan: install the exact direct versions in package.json into this workspace.
  Use a workspace-local npm cache, disable lifecycle scripts, and record actual
  npm output and its exit code. No installed dependency or Stage 3 result is
  claimed yet. Transitive versions and integrity values still need a real lock.
- Required boundary: handwritten TypeScript must preserve integer values using
  bigint. Tests will compare against the actual Dafny-generated model, including
  retries, invalid requests, exact balances, and values above safe JS integers.
  Comparison tests remain tested_against_proved_model, never source_proof.
- Next action: attempt the pinned installation. If it cannot install or run,
  stop with the exact diagnostic; do not implement or claim passing Stage 3 work.

## U028 — Dependencies installed; supported Node loader works within permissions

- References: U027.
- Observed: the original npm install exited 1 with getaddrinfo ENOTFOUND
  registry.npmjs.org. Its log is retained under .toolchain/npm-cache/_logs/.
  A later DNS probe also exited 1 with socket.gaierror Errno 8.
- New input: the user ran the installation externally. npm ls --depth=0 now exits
  0 with all five requested direct versions. package-lock.json records exact
  transitive versions and integrity fields. TypeScript 5.9.3 ran with exit 0.
  Real fast-check tests and bignumber.js conversion also ran with exit 0.
- Observed: tsx CLI version invocation exited 1 because the session denied its
  local IPC socket (listen EPERM). The user explicitly authorized IPC access.
  The elevated retry never ran: execution policy rejects sandbox escalation.
- Correction to the earlier blocker assessment: the installed tsx Node loader
  and TypeScript transformer ran successfully through node --import tsx, exit 0.
  This uses existing permissions and does not open the denied CLI socket.
  The toolchain can therefore support current-stage implementation and testing.
- Scope: retain the required npx tsx app/main.ts EXIT as unestablished until that
  exact command runs successfully. A loader invocation cannot silently satisfy
  that command. Prepare and test the actual app before requesting any external
  command run or change to the planned EXIT interface.
- Next check: real Dafny JS compilation, TypeScript/model comparison properties,
  and the planted TypeScript self-transfer rejection. No Stage 3 EXIT has passed.

## U029 — Stage 3 implementation and tests pass; exact demo EXIT pending

- References: U026–U028.
- Observed: real Dafny JS compilation exited 0 with 12 verified obligations.
  Generated JS has no CommonJS exports. The build retains its exact bytes and
  appends only the tracked interop/export.cjs visibility footer. Module digest:
  2387fcdf5fcfb6d9bc4a05e752b55549cd001ada104431a5bf1311e92ce2b567.
- Observed: node --import tsx app/main.ts exited 0 and printed exactly Ok then
  Rejected. It calls the actual compiled model through the bigint/BigNumber bridge.
- Observed: the first TypeScript noEmit check exited 2 for the property example's
  inferred array shape. Changed it to an explicit one-element tuple; the next
  check exited 0. No implementation or approved spec repair was needed.
- Observed: the correct handwritten TypeScript passed 300 fast-check runs with
  seed 3032026, 3,506 compared transitions, 474 retries, and 430 fresh successes.
  Every required corpus category had nonzero observed counts. Inputs include
  integers above Number.MAX_SAFE_INTEGER. These finite comparisons are not proof.
- Observed: the planted self-transfer bug caused actual checker exit 1. It shrank
  to initial balances [1,0,0,0] with the fixed operation prefix. The gate also
  exited 1 with PROPERTY_REJECTED and emitted no accepted evidence.
- Observed: correct-typescript, self-transfer, evidence-labels, reproducibility,
  and loader-demo scenario commands each exited 0. All five Stage 1 and all five
  Stage 2 regression commands also exited 0. Actual codes are in results/stage3.json.
- Observed: source evidence retains source_proof; TypeScript evidence uses
  tested_against_proved_model. Critical policy rejected the TypeScript result
  with gate exit 1. Repeated builds and evidence were byte-identical.
- Scope: original npm tarballs were not independently authenticated here; exact
  lock values and observed installed package trees are pinned. The generated
  runtime, compiler, export footer, conversion bridge, and fixed TS module layout
  remain assumptions. source_to_module_proved=false and end_to_end=false.
- Approval boundary: the user authorized IPC, but the host rejected the elevated
  request before execution. A supported loader works without the denied socket.
  The user was asked to approve changing only the exact demo command, or to run
  the original command externally. No response to that concrete choice is recorded.
- Pending: npx tsx app/main.ts must still really succeed, or its invocation must
  be explicitly changed. Stage 3 remains CURRENT; no Stage 4 work has started.
  The public GitHub lookup still returns 404, so publication remains unconfirmed.

## U030 — Demo invocation change approved; Stage 3 complete

- References: U027–U029.
- New input: after the concrete request to replace only the demo EXIT, the user
  said they approve whatever is needed. Apply that approval to the already
  demonstrated node --import tsx app/main.ts replacement.
- Observed: the replacement command ran again with exit 0 and printed exactly
  Ok then Rejected. Current source and trusted-input hashes match both saved
  source-proof and TypeScript-comparison evidence bundles.
- Preserved failure: the original npx tsx app/main.ts command really ran and
  exited 1 with listen EPERM for the CLI socket. Its scenario also exited 1.
  The earlier elevated request never ran because execution policy rejected it.
  Replacing the invocation does not turn either failure into a success.
- Scope: only the demo invocation changed. The approved spec, lock, policy,
  property corpus, and evidence methods are unchanged. The other Stage 3 EXITs
  already ran successfully, and their actual reports still match current inputs.
- Resolution: record Stage 3 DONE and Stage 4 CURRENT, then stop this run.
  No Stage 4 implementation or later-stage spec change is approved by this record.
- Publication remains blocked: a fresh connected-app lookup returned 404 for
  mack-dot/forge. A fresh gh repo create mack-dot/forge --public request with the
  recorded description exited 1 with error connecting to api.github.com.
  The connected app exposes no repository-creation operation. Publication needs
  restored CLI connectivity or an accessible repository created externally.
- Continuation: the goal tracker still reports blocked from the earlier IPC wait.
  The demo blocker is resolved. Automatic continuation needs a user-controlled
  goal resume; this agent's status tool cannot set a goal to active.

## U031 — Public repository created and connected access confirmed

- References: U019, U021, U023, U029, U030.
- New input: the user reported creating the public repository.
- Observed: the connected GitHub app returned repository ID 1434789853,
  owner mack-dot, visibility public, default branch main, and push/admin access
  for https://github.com/mack-dot/forge. The main-ref lookup returned 409,
  Git Repository is empty. No existing remote files were observed.
- Resolution: the repository-creation/access blocker is resolved. Local CLI
  networking and local .git write access have not been claimed fixed.
- Next action: publish the authorized completed-stage snapshot through the
  connected app, then verify the remote branch and every uploaded file digest.
  No successful upload is claimed by this availability check alone.

## U032 — Completed-stage snapshot published and verified

- References: U031.
- Observed: the connected app published the completed Stage 0–3 snapshot to
  the public mack-dot/forge repository on main. Snapshot commit:
  c909a640ffaef595bf720c71e196e1706e69a9ac.
- Observed: a fresh main-ref lookup matched that commit. The recursive Git tree
  was not truncated and contained exactly 68 files. Every remote blob SHA and
  mode matched the local publication snapshot. Local Git hash-object exited 0.
- Observed: a fresh repository lookup confirmed owner mack-dot and public
  visibility. Repository URL: https://github.com/mack-dot/forge.
- Published records include the approved spec and lock, implementations,
  negative fixtures, gates, schema, policy, pinned tool descriptions, full
  roadmap, append-only findings, source-proof evidence, and comparison evidence.
  Generated build folders, installed packages, caches, and local Git metadata
  were excluded. The generated JS module is reproducible from the tracked build.
- Resolution: the requested public publication is established for this snapshot.
  Local CLI connectivity and local .git permissions are still separate limits;
  the connected GitHub app supplied the verified publication path.
- Scope: publication is not a new program proof, a signature, or a deployment.
  Stage 3 remains DONE; Stage 4 remains CURRENT and unimplemented. Evidence
  retains source_proof for Dafny, tested_against_proved_model for TypeScript,
  source_to_module_proved=false, and end_to_end=false.
- Next action: publish this append-only receipt and verify the resulting branch
  head and changed log blob. The receipt names the already verified snapshot;
  it does not claim a self-referential commit hash for its own publication.

## U033 — Member selection skips a broken helper proof

- References: U003, U032. Stage: 4, CURRENT.
- Observed: python3 scripts/probe_stage_4.py exited 0. This is a diagnostic,
  not an acceptance gate or a Stage 4 EXIT. Each child invoked real pinned
  Dafny 4.11.0 with bundled Z3, resource limit 1000000, no verification time
  limit, one core, and included-file verification.
- Observed: full verification of the unchanged ledger exited 0. Selecting only
  Ledger.Apply with --filter-symbol Ledger.Apply. also exited 0.
- Observed: an isolated implementation copy with assert false in TotalReplace
  failed full verification with exit 4. The TRX report names that helper's
  correctness obligation as Failed. The same copy returned exit 0 when the
  command selected only Ledger.Apply. The approved source and spec did not change.
- Scope: this demonstrates a coverage gap if member selection is used alone.
  It does not show a Dafny soundness defect, establish a safe dependency graph,
  prove a cached result reusable, or complete the required GitHub Action runs.
  No artifact is accepted by this diagnostic. end_to_end remains false.
- Evidence: results/stage4-member-probe.json records exact child commands,
  numeric exit codes, source hashes, obligation names, and counts. Raw logs
  and disposable fixtures remain under build/stage4-member-probe/.
- Documentation: the pinned manual documents symbol selection and describes
  funcCallGraph as a function call graph. That description alone does not
  establish complete proof dependencies for method bodies and contracts:
  https://dafny.org/v4.11.0/DafnyRef/DafnyRef.
- Open: dependency completeness, trusted baseline reuse, and actual CI execution.
  Current toolchain pins name Darwin/arm64. A CI host must use a validated,
  pinned environment; this probe does not establish portability.
- Next check: obtain dependency information from the established Dafny tools,
  compare selective results with full verification after controlled changes,
  and verify all affected helpers. Broaden verification whenever coverage is
  uncertain. Stage 4's three real-PR EXITs remain NOT RUN.

## U034 — Built-in snapshot reuse passed local dependency controls

- References: U003, U033. Stage: 4, CURRENT.
- Observed: the pinned Dafny source exposes legacy snapshot verification. Its
  translator creates member checksums; bundled Boogie 3.5.5 collects proof
  dependencies and chooses cache reuse. No custom dependency checker was built.
- Observed: python3 scripts/check_stage_4_local.py exited 0. The trusted baseline
  was fully checked first. An unchanged candidate reused all 12 obligations.
  A valid Apply edit checked 2 obligations and reused 10. All C1-C5 claims share
  Apply; these are member-obligation counts, not five independent proof runs.
- Observed: broken-helper, weakened-helper-contract, and self-transfer cases
  returned incremental gate exit 1 and actual Dafny exit 4. Fresh checks without
  caching also returned 4. Unannotated assume returned audit exit 2 and gate 1.
  A fresh verify command also returned 2 because warnings were not allowed.
- Observed: spec-plus-lock edits and C2 weakening were rejected before any
  checker invocation. Repeated valid candidates produced identical evidence.
- Preserved failure: the first local driver run exited 1 because it expected
  exit 0 from the bare-assume fresh check. The real result was 2, with a warning
  naming the unannotated assumption. Only that test expectation changed.
- Scope: the local gate accepts only the fixed ledger layout against an external
  trusted checkout. The tests do not prove the cache or general dependency
  completeness. Real PR workflows and exact-revision spec approval are pending.
- Evidence: results/stage4-local.json, results/stage4-local-attempt1.json,
  gate/incremental.py, and docs/stage4-change-loop.md.

## U035 — Cache checksum and determinism assumptions remain explicit

- References: U003, U034.
- Observed in the pinned upstream source: Dafny 4.11.0 computes MD5 checksums
  for verification cache entries. Boogie compares member and dependency
  checksums before reuse. MD5 is not a security-grade artifact hash.
- Impact: reuse trusts that no cache-checksum collision occurs among the inputs
  in the run. The new evidence states this assumption. The controls do not
  establish resistance to an adversarial cache collision. The default full
  gate remains available without this cache assumption.
- Observed in Boogie 3.5.5 source: cache entries have an idle-expiry policy.
  A delayed run can perform more checks after entries expire. Cache counts and
  timing therefore remain outside canonical proof evidence; they are recorded
  in the operational report. Proof scope and source identities remain bound.
- Scope: no guarantee of independent proof-kernel checking or broad-language
  cache soundness is made. No binary or deployment coverage is added.
- Source links and reproduction details are in docs/stage4-change-loop.md.
- Next check: exercise the same controls on the pinned CI environment and retain
  these assumptions in the PR report. Do not invent a replacement cache verifier.

## U036 — Linux CI environment requires its own measured pins

- References: U033, U034.
- Observed: current accepted local toolchain pins describe Darwin/arm64.
  They cannot authenticate Linux executables by reusing the same binary hashes.
- Prepared: a trusted-main GitHub Actions inventory workflow using commit-pinned
  checkout, setup-python, and upload-artifact actions. It selects Python 3.10.11,
  pip 25.3, and the existing validator package versions. It checks the official
  Dafny 4.11.0 Linux archive SHA-256 before extraction.
- Source: the Dafny release API supplied Linux archive digest
  a46a9ff7cdd720f7955854c78e95df13f4cfe6b80691b05f8654fe19e8267179.
- Scope: this inventory job accepts no PR or artifact. It must really run, and
  its executable and package digests must be pinned before the CI gate uses them.
  Python distribution and wheel publisher authentication are not inferred from
  merely observing installed bytes. The host image remains in the trusted base.
- Pending: publish and run this workflow, inspect its actual result, and then
  implement the PR workflow using the validated CI profile. No successful CI
  installation or Stage 4 EXIT is claimed by this preparation entry.

## U037 — Exact evidence reproduction now runs without path substitution

- References: U034, U035.
- Observed gap: a direct inspection returned exit 1 because the first snapshot
  evidence used a candidate-checkout placeholder in reproduce_cmd. Repeated
  identical-input tests had passed, but that did not establish literal replay.
- Change: the gate saves exact candidate inputs in a content-addressed directory
  under build/change-inputs/. Its saved command names that directory and creates
  a fresh work directory automatically. Accepted evidence is published atomically.
- Observed: the final python3 scripts/check_stage_4_local.py run exited 0 after
  the gate and CI inventory files were finalized. It also executed the exact
  saved reproduction command, which exited 0 and produced identical evidence.
- Observed: all prior rejection controls still behaved as required. Raw failures
  and intermediate results remain preserved; none were changed to passing codes.
- Evidence: results/stage4-local.json records the literal command and its exit
  code. results/stage4/source-evidence.json and results/stage4/apply-edit.dfy
  archive the accepted local example. The local control script reconstructs
  its inputs on a fresh checkout with the recorded toolchain.
- Scope: this is local source-proof replay under the explicit cache assumptions.
  It does not complete a real-PR EXIT or authorize a fee-spec change.

## U038 — Linux inventory ran successfully; profile is recorded but not enabled

- References: U032, U034, U036, U037.
- Observed: the Stage 4 local gate and inventory workflow were published on main
  at bafcd92533034dc342c53688f058ab8cfbc577a6. The connected GitHub app confirmed
  the branch head and all 17 changed blob hashes and modes.
- Observed: GitHub Actions run 40397041174 and job 121832698153 completed with
  success. The actual .toolchain/ci-python/bin/python toolchain/inventory_ci.py
  step exited 0. Its recorded child commands returned 0 for tool versions,
  wheel download, installation, validator imports, and the true lemma. The false
  lemma returned the required verification failure code 4.
- Evidence: https://github.com/mack-dot/forge/actions/runs/40397041174.
  results/stage4/ci-inventory.json preserves the run, job, artifact, real child
  commands, numeric exit codes, and measured package and executable digests.
  Reconstructing the inventory from its job-log chunks reproduced its reported
  SHA-256 abcd98359f85cb1daa315cd718d84b7145bd9e4b93451f3315361aa428637c95.
- Recorded: toolchain/linux-pins.json, validator-linux-pins.json, and
  requirements-linux.txt capture the observed Linux executable, package-file,
  and wheel digests. These files are not yet selected by the acceptance gate.
- Scope: Python and wheel publisher authentication is not inferred from observed
  file digests. The Dafny archive matched its published release digest. This
  inventory accepts no ledger candidate, PR, binary, or deployment.
- Resolution: a real Linux runner can install and run the selected toolchain.
  The earlier portability question now has concrete installation evidence.
- Next check: add a fixed Linux profile to the trusted gate, preserve all local
  rejection behavior, then run the actual PR workflow and its required EXITs.
  The fee proposal and exact-text human approval also remain pending.

## U039 — Linux PR acceptance is implemented; real PR results are pending

- References: U034–U038.
- Change: the incremental gate selects a fixed Linux profile. Its installer
  checks the recorded archive, executable, wheel, and installed package digests.
  The default local profile retains its existing pins and rejection rules.
- Observed: the updated python3 scripts/check_stage_4_local.py command exited 0.
  It checked 2 candidate obligations and reused 10 for the valid Apply edit.
  Broken proofs and unapproved protected changes were rejected. Literal replay
  exited 0 and reproduced byte-identical evidence.
- Prepared: the PR workflow executes trusted base-revision code. It checks
  candidate tracked files against the exact commit before and after checking.
  Candidate scripts do not run. Checker subprocesses receive an environment
  allowlist. A separate trusted job posts claims and a commit status.
- Scope: local controls do not establish successful PR execution or enforce
  repository merge settings. The real-PR EXIT runner reads GitHub job results,
  actual receipt logs, exact source bytes, comments, and statuses.
- Pending: publish the workflow, run the three real PR demonstrations, inspect
  installation and checker results, then execute the real-PR EXIT commands.
  No fee-spec change is approved by this implementation work.

## U040 — GitHub event policy is an external workflow dependency

- References: U039.
- Observed: GitHub's current documentation says the default public-repository
  pull_request_target policy is in evaluate mode. It announces enforcement for
  affected repositories on December 2, 2026. This is not a present observed
  failure of Forge's workflow.
- Source: https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target.
- Impact: continued operation may require an applicable repository event policy
  permitting this trigger. The connected app cannot manage administration
  settings. A posted commit status alone also does not enforce merge protection.
- Scope: trusted code reads candidate sources as data. Verification has read-only
  repository permissions; posting runs separately with only reporting permissions.
  This limits credentials but does not prove the checker or runner is exploit-free.
- Next check: inspect actual PR runs now. Recheck applicable event policy before
  the announced enforcement date. Do not infer a configured merge rule or policy.

## U041 — Regression fixtures must use evidence from the current trusted code

- References: U039.
- Observed: the Stage 2 method-policy regression exited 1. Its unit_tested
  fixture was rejected with TRUSTED_INPUTS before reaching METHOD_POLICY.
  The root evidence file still bound the earlier adapter and dependency code.
- Cause: regression setup refreshed source evidence too late in the command
  sequence. The gate correctly rejected stale trusted-input digests.
- Action: preserve the failed report, run the real full source gate to refresh
  evidence, and repeat the affected Stage 2 checks. No acceptance rule changed.
- Observed: the refresh exited 0. All five repeated Stage 2 cases exited 0,
  including method-policy and fresh-checker round-trip. The earlier failure
  remains in results/stage4/regressions.json and stale-evidence-regression.json.
- Scope: this resolves a test setup error. It does not grant authority to
  hand-edited evidence or complete any real-PR EXIT.

## U042 — Real PR acceptance and rejection EXITs passed

- References: U034–U041.
- Published: README thesis, Linux profile, trusted PR workflow, and regression
  records at 0e6d48ca008695f0c8a89965264bd62f73fbd8b2. All 21 changed blobs
  and modes matched the local publication payload. The uncertainty log preserved
  every prior byte. PR receipts and the EXIT runner followed at
  b2906e2f64f9e1ecd364d2dced55a391f736c236; its five changed blobs were verified.
- Observed: PR 1 / run 40402849081 accepted the implementation edit with gate 0.
  Baseline: 12 checked. Candidate: 2 checked, 10 reused. Literal replay exited 0
  and produced byte-identical evidence. Both workflow jobs succeeded.
- Observed: PR 2 / run 40402945633 and PR 3 / run 40402975014 rejected the spec
  plus matching-lock edit and C2 weakening, respectively. Both gates exited 1
  with UNAPPROVED_PROTECTED_CHANGE and no accepted evidence. Both reporting jobs
  succeeded and posted claims and failed commit statuses on the exact heads.
- Observed: the GitHub run API reports the PR head in head_sha for these target
  event runs. The EXIT runner checks that observed field against the PR head;
  the trusted checkout is independently bound to the event's base SHA.
- Observed: actual EXIT run 40403180524, job 121854084912, completed successfully.
  python3 scripts/exit_stage_4.py --case affected-claims exited 0.
  python3 scripts/exit_stage_4.py --case unapproved-spec exited 0.
- Evidence: results/stage4/pr-runs.json, pr-1/2/3-receipt.json, exit-run.json,
  exit-affected-claims.json, and exit-unapproved-spec.json.
  https://github.com/mack-dot/forge/actions/runs/40403180524.
- Scope: the Linux source-proof path and the demonstrated real PR controls now
  have observed results. The MD5 cache assumption remains. No binary, deployment,
  merge-protection configuration, or approved fee-spec result is established.

## U043 — Fee intent is concrete and awaits exact-text approval

- References: U042.
- Prepared: proposals/fees.md proposes a one-unit fee on each fresh successful
  transfer. The sender pays amount plus one; account 0 receives the fee. Fresh
  requests involving account 0 are rejected. An identical accepted retry or an
  invalid request has no fee and no state effect.
- Candidate spec SHA-256:
  2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940.
- Candidate lock SHA-256:
  32cf117f5bcaec2fb0c072650ceb9b535576ab409579a56c00979ed151b03b69.
- Scope: the exact diff is unapplied. Its proposed lock approval fields describe
  the required post-approval state; they are not an approval already obtained.
  No proof of the proposed implementation is claimed. Examples are requirements,
  not executed tests. The approved spec and lock bytes remain unchanged.
- Next check: human approval of this exact proposal, followed by the trusted
  revision-bound approval path, implementation changes, and the approved-spec
  real PR EXIT. Stage 4 stays CURRENT; later stages have not started.

## U044 — The published fee proposal received explicit approval

- References: U043.
- Observed: the user answered yes to the request to approve fees.md as written
  at public revision 648229df2d0e13e8d872e0a867ab0ce940ea8146.
- Applied locally: exactly the published spec and lock diff. Their SHA-256 values
  match the two candidate digests in U043. The original checkout is preserved
  under build/stage4-fees-original. No proof result is inferred from approval.
- Recorded: gate/approvals/fees-v2.json binds the base and approved input hashes
  and the immutable proposal revision and content. This is a trusted-maintainer
  record of conversational approval, not a cryptographic user signature.
- Next check: enforce the approval from the trusted PR base, reject any later
  spec edit, verify the fee refinement, and run the approved-spec real PR EXIT.

## U045 — Fee proofs, model comparisons, and exact approval controls passed locally

- References: U044.
- Observed: the real Dafny source gate accepted the fee refinement on its first
  attempt (exit 0). The real model build exited 0. Ten explicit behavior examples
  passed against both TypeScript and the compiled model (exit 0), including
  exact funding, absent/reserved fee accounts, rejected requests, and retries.
- Observed: all 16 commands in results/stage4/fee-regressions.json exited 0.
  This includes the fresh source gate and all supported Stage 1–3 scenarios.
  The existing planted bugs still pass the weak unit tests and fail the gate.
- Observed: python3 scripts/check_stage_4_approval.py exited 0. The v1 baseline
  checked all 12 obligations. The approved v2 candidate checked 4 and reused 8.
  Repeated runs and literal replay produced byte-identical evidence.
- Observed: a further spec edit, C2 weakening, candidate-owned approval edit,
  and policy edit were each rejected with gate exit 1. No accepted evidence was
  emitted. The updated local incremental controls also exited 0.
- Evidence: results/stage4/approval-local.json, approved-local-evidence.json,
  fee-initial-checks.json, fee-regressions.json, fee-typescript-evidence.json,
  and results/stage4-local.json. The prior snapshots remain archived.
- Scope: local source proof and finite model comparisons retain separate methods.
  The approval record is trusted maintainer input, not a signed user identity.
  Native cache assumptions remain; no binary or deployment coverage is added.
- Next check: publish trusted approval support while retaining the v1 baseline,
  then run the v2 spec and implementation as a real PR and execute approved-spec.

## U046 — The fee example fixture needed a type-correct setup

- References: U045.
- Observed: typechecking after adding fees.examples.ts exited 2. TypeScript
  rejected two fixture setup calls to set on the public ReadonlyMap state type.
  The runtime examples had passed; that did not establish type correctness.
- Fix: construct the accepted-entry maps in the fixture factory before exposing
  the State value. The production read-only types and ledger code are unchanged.
- Observed: the repeated npx --no-install tsc --noEmit command exited 0 and
  node --import tsx tests/fees.examples.ts exited 0 with all ten examples.
  Both the failed and successful commands remain in fee-initial-checks.json.
- Scope: a test fixture typing error, not a failed Dafny proof or changed spec.

## U047 — Exact approved fee transition passed the real workflow and all Stage 4 EXITs

- References: U044–U046.
- Published: trusted approval support at 8751d3fdbc2705beaeed28a492bab983271a7b1c.
  All 20 changed blob hashes and modes were verified. The v1 spec remained the
  trusted baseline for the real fee PR.
- Observed: PR 4 / run 40405564741, verification job 121862309455, accepted the
  approved v2 candidate with gate exit 0. The baseline checked all 12 obligations;
  the candidate checked 4 and reused 8. Literal replay exited 0 and produced
  identical evidence. Verification and reporting jobs both succeeded.
- Evidence records spec SHA-256
  2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940,
  exact base/approved lock and spec digests, and the trusted approval record.
- Observed: PR 5 / run 40405711794, verification job 121862797245, attempted C2
  weakening after fee approval. It exited 1 with UNAPPROVED_PROTECTED_CHANGE,
  emitted no accepted evidence, and its reporting job succeeded. Exact-text
  approval did not authorize a later edit, even with an updated candidate lock.
- Observed: PR 4 merged at 08cae1c59f6c1b40354851b422070a1edb4dc39d. The merged
  tree exactly matched the checked PR tree. The subsequent EXIT record update
  at 88057d49f9abe6cf3a701c1f388a2377108428e3 had all four changed blobs verified.
- Observed: final EXIT run 40409284514, job 121875254229, succeeded. The exact
  affected-claims, unapproved-spec, and approved-spec commands each exited 0.
  Raw gate codes were 0 for both accepted PRs and 1 for all three rejected PRs.
- Evidence: results/stage4/exit-run.json, the three per-case EXIT reports,
  pr-4-receipt.json, and pr-5-receipt.json. Earlier reports remain archived.
  https://github.com/mack-dot/forge/actions/runs/40409284514.
- Resolution: all Stage 4 EXIT requirements are established for their recorded
  revisions. Stage 4 is DONE; Stage 5 is CURRENT. This run stops at that transition.
- Limits: approval is a trusted maintainer record of the user's response, not a
  signed user attestation. Native cache assumptions remain explicit. TypeScript
  has finite model-comparison evidence, not proof. No binary, compiler,
  concurrency, persistence, or deployment guarantee was added; end_to_end=false.

## U048 — Stage 5 driver expectations needed correction; proof results were preserved

- References: U047.
- Observed: the approved successful-execution witness passed Dafny with 13
  verified obligations and exit 0 on its first run. An isolated spec with both
  validity predicates replaced by false admitted a reject-all implementation.
- First driver failure: its coverage check expected the production spec's
  well-formedness tasks for IsRetry and IsFreshValid. The real TRX omitted those
  tasks for the constant-false predicates and reported 10 verified obligations.
  Only the isolated fixture's expected coverage was corrected. The production
  gate and approved spec were not modified.
- Second driver failure: Dafny actually rejected the vacuous witness with exit 4,
  but the driver read a message field instead of Dafny's defaultFormatMessage.
  The assertion diagnostic was present in the actual checker log.
- Mutation driver failure: the balance-clearing mutant failed WellFormed and
  key-preservation postconditions before named C1–C5 clauses. The driver now
  records those exact contract locations rather than inventing a claim label.
- Evidence: vacuity-attempt1.json, vacuity-attempt2.json, and
  mutations-attempt1.json under results/stage5/ preserve real failed driver codes.
  Original logs remain in build/stage5-history/ and the published log archive.
- Scope: these were reporting/control errors. No failed proof was relabeled as
  passed, and no production acceptance rule or spec was relaxed.

## U049 — A successful witness and finite mutation results expose scope limits

- References: U048.
- Observed: python3 scripts/exit_stage_5.py --case vacuity exited 0 after the
  driver corrections. The approved witness verified (Dafny 0). The isolated
  reject-all implementation verified against its vacuous spec (Dafny 0), while
  the same non-trivial-success witness failed there (Dafny 4).
- Observed: python3 scripts/exit_stage_5.py --case mutations exited 0. Eight
  valid, audit-clean mutants failed actual spec postconditions. Two survived.
  The measured spec-proof kill rate is 8/10, or 80.00%, for this exact corpus.
- Survivors: the algebraic rewrite control and the added print statement.
  Printed output is outside the approved ledger-state claims. Survival is not
  proof of equivalence or satisfaction of every human requirement.
- Excluded from that denominator: one syntax-invalid mutant (resolve 2) and one
  forbidden-assumption fixture (audit 2). Neither is counted as a spec-proof kill.
  No inconclusive check occurred. The labeled algebraic control stays included.
- Observed: the generator produced 227 actual comparisons against the compiled
  model: 6 Ok and 221 Rejected. Each matched the handwritten TypeScript.
  These finite examples are tested_against_proved_model, not a TypeScript proof.
- Limits: the witness rules out this reject-all vacuity, not every intent error.
  The kill rate is not an estimate of real-world defect coverage. The compiler,
  runtime, and bridge link remains an assumption; end_to_end=false.
- Next check: exact replay of canonical reports and generated documents, then
  publish the completed Stage 5 record without changing protected inputs.

## U050 — Generated comparison evidence now binds the candidate bytes and replays exactly

- References: U049.
- Observed gap: the first generated example record bound the reference source
  and compiled model but omitted a candidate artifact digest. A direct metadata
  inspection exited 1. Passing comparisons alone did not fill that identity gap.
- Change: the generator records the TypeScript source manifest, candidate digest,
  and comparison-input digests. The driver captures input hashes before checking
  and rejects changes to source, witness, driver, or comparison inputs during a run.
- Observed: the final metadata inspection exited 0. Candidate source digest:
  f1b083ba262b96618a5d68936c46098f95ccfe6d73c19a276dd49e83d8773a47.
- Observed: after the correction, both complete runs of generation, vacuity,
  mutations, and report rendering exited 0. Five real cmp commands each exited 0:
  examples.json, source-evidence.json, spec-quality.json, claims.md, and
  spec-quality.md were byte-identical. The final replay record contains 13 real
  commands and their codes. Earlier records remain archived with explicit names.
- Evidence: results/stage5/input-binding-inspection.json, input-binding-final.json,
  replay.json, and spec-quality.json. The canonical diagnostic summary contains
  no timestamps or timing data. Raw logs are separate operational records.
- Resolution: the final comparison evidence identifies the actual candidate as
  well as its reference model. This adds no compiler or deployment proof.

## U051 — Stage 5 completed with measured scope and unchanged protected inputs

- References: U048–U050.
- Observed: plain-English C1–C5 rendering and 227 generated accept/reject examples
  were produced by the real source gate, compiler, and model comparisons.
- Observed: the final python3 scripts/exit_stage_5.py --case vacuity command exited
  0; approved witness verifier 0, vacuous reject-all verifier 0, vacuous witness 4.
- Observed: the final python3 scripts/exit_stage_5.py --case mutations command
  exited 0. Spec kills: 8; survivors: 2; invalid: 1; audit rejected: 1;
  inconclusive: 0. Kill rate: 8/10, including the labeled algebraic control.
- Evidence: docs/claims.md, docs/spec-quality.md, and results/stage5/ retain the
  source identities, exact commands, real codes, counts, failures, and limits.
  The log archive index binds 86 actual logs to their recorded SHA-256 values.
- The approved spec, lock, policy, gate, and toolchain inputs remained unchanged.
  The vacuous spec and all implementation mutations were isolated test fixtures.
- Resolution: all Stage 5 EXIT requirements are established. Stage 5 is DONE;
  Stage 6 is CURRENT. This run stops at that transition; no Stage 6 work ran.
- Limits: neither a witness nor a finite kill rate proves complete intent coverage.
  The print-effect survivor shows the current state-only scope. TypeScript remains
  tested against the model. The compiler/runtime/bridge link and native trusted
  base remain assumptions; every artifact keeps end_to_end=false.

## U052 — Stage 6 booking intent needs an exact approval decision

- References: U001, U049, U051. Stage 5 publication is complete at public main
  c5e3be0fb5188a05ea0559b63396cf7712061c2c. A fresh connected GitHub read confirmed
  that head when Stage 6 preparation began. The prior turn made concrete progress.
- Observed: no booking spec or implementation existed at Stage 6 entry. The
  roadmap names four claims but leaves selection and cancellation/retry details
  open. Existing exact approvals cover the ledger and fee change, not this draft.
- Proposed: select the lowest allowed free slot; cancellation uses a separate
  operation ID and targets the original booking ID. Accepted retries return the
  historical receipt with no state change. Rejected IDs are not reserved.
- Consequence: a book retry after cancellation does not restore the booking.
  An old cancellation retry does not free a slot used by a later booking. These
  requirements are explicit in proposals/booking.md and its exact spec diff.
- Observed: the real command .toolchain/dafny-4.11.0/dafny/dafny resolve
  proposals/booking/BookingSpec.dfy exited 0 on attempt 1. It explicitly reported
  that verification was not attempted. This is not a proof or Stage 6 EXIT.
- Evidence: results/stage6/proposal/resolve-attempt1.json and its raw log.
  Candidate SHA-256: 6d10e909fc685eb28fc1d582dcb37b61294bf5ac2466236b06447a82a60d2319.
- Status: PENDING HUMAN APPROVAL of the exact proposal. Production protected
  files remain unchanged. No booking implementation or later-stage work ran.
- Next check: receive the required intent decision, then verify the concrete
  refinement and complete dependency closure using the established Dafny backend.

## U053 — Reuse measurement must include setup and disclose token coverage gaps

- References: U004, U034, U052.
- Observed: the ledger implementation already contains TotalRemove and
  TotalReplace for finite integer-map sums. The proposed booking state uses
  0/1 capacity flags. An update to an existing slot meets TotalReplace's stated
  membership premise. Reuse is a design candidate, not yet an accepted proof.
- Planned measurement: compare one self-contained source input, shared source
  files with full cold checks, and the shared layout with native Dafny/Boogie
  dependency-cache reuse. Charge baseline verification and all setup. Record
  layout differences, complete obligations, failure controls, and five repeats.
- Known limit: those fixed-source verifier measurements alone cannot establish
  an LLM authoring benefit. Source sharing alone is not a cached proof result.
  Native cache trust and MD5-collision assumptions from U034 remain explicit.
- Observed: get_goal reported 778672 cumulative goal tokens at the Stage 6 entry
  checkpoint. This aggregate is not a per-condition counter or a Stage 6 total.
  No provider-category or complete authoring-transcript export was inspected.
- Open: complete token, prompt/response, failure-attempt, and human-intervention
  accounting across Stage 6 setup and measurement. Missing data is unknown,
  never zero. Common preparation must not be silently dropped or allocated by guess.
- Impact: no complete cost or speedup claim is established. Missing required
  accounting is a Stage 6 completion blocker until resolved or explicitly revised
  by the user; the booking proposal does not waive the measurement requirement.
- Next check after intent approval: establish measurement boundaries and inspect
  available usage provenance before executing the benchmark. Report recorded
  totals separately from fresh timing reruns. Keep end_to_end=false.

## U054 — Exact booking proposal approved and applied

- References: U052–U053.
- Observed: the user replied "go ahead" to the pending exact booking-proposal
  approval request. The proposal is frozen at public revision
  2dee3d0546c36e5d7a3c233d722dd87c3729dd76.
- Action: copied the approved spec and lock bytes to spec/booking/ without
  alteration. The existing ledger spec, root lock, policy, and gate are unchanged.
  proposals/booking-decision.md records the decision and exact digests.
- Resolution: the Stage 6 intent-approval blocker is resolved. This is a
  conversational approval record, not a signed attestation or proof result.
- Open: source proofs, benchmark execution, full accounting, and both Stage 6
  EXIT commands remain required. No later-stage work is authorized by this record.

## U055 — Booking source proof passed after explicit invariant steps and assertion isolation

- References: U054.
- Observed: implementation proof attempts 1, 2, and 3 returned real Dafny codes
  4, 4, and 0. Attempt 1 could not establish the minimum helper's bound and the
  free-slot/active-booking equivalence. Explicit quantifier steps fixed those gaps.
  Attempt 2 exhausted the resource budget for the combined Apply obligation.
- Change: Dafny's established isolate_assertions annotation separates Apply's
  assertions. The command-line solver resource limit remains 1000000 and the
  verification time limit remains 0. The resource limit applies to each isolated
  assertion batch; this is not a claim of a one-million-unit whole-program limit.
- Observed: attempt 3 passed 99 assertion batches across 22 members, including
  the actual ledger dependency. The approved booking/ledger specs and locks were
  not weakened. No assumption or verification-bypass construct was introduced.
- Evidence: results/stage6/development/attempt1–attempt3/ retain real codes,
  logs, input digests, and source versions. Attempt 1 source was recovered from
  its original applied patch and matches its recorded checker-input SHA-256.
- Scope: source proof only. Mathematical finite maps/sets and integer reasoning
  do not establish compiled runtime resource bounds or deployed behavior.

## U056 — The complete booking trace is checked; its first two proof failures are retained

- References: U055.
- Observed: trace verification attempts 1, 2, and 3 returned 4, 4, and 0. All
  three real audit commands returned 0 against the trusted empty audit report.
- Attempt 1 lacked an explicit minimum-slot instantiation and exhausted resources
  in several long-path checks. The trace was split into checked step methods.
  Attempt 2 exposed the occupied-state existential witness needed for WellFormed.
  A proved SingleOccupancy lemma supplies that witness; the spec stayed unchanged.
- Observed: the final full closure passed 238 assertion batches across 33 members.
  Its actual calls cover booking, rejection without recording an ID, cancellation,
  reuse of that rejected ID, historical book/cancel retries, and ID conflicts.
- Observed: the initial new booking gate exited 0, accepted B1–B4 as source_proof,
  and wrote source-bound evidence. Its successful trace is also pinned by digest
  before final gate replay. New booking policy requires source_proof for all four
  claims and does not change the existing ledger policy or backend.
- Evidence: results/stage6/development/witness1–witness3/ and gate-initial/.
  No booking, compiler, binary, container, or deployment guarantee was inferred
  from test labels. end_to_end=false.

## U057 — Available authoring usage is recoverable from the actual runtime records

- References: U053.
- Observed: this thread's local session contains per-response token_usage_record
  events and cumulative counters. The first export sums all six available token
  categories across 58 responses in the declared Stage 6 interval. The sums match
  the cumulative-counter differences exactly. No missing category was set to zero.
- Observed checkpoint: 6535683 input tokens, including 6446080 cached input;
  65462 output tokens, including 28657 reasoning output; 6601145 total tokens.
  Cache-write input is reported as 0 by the runtime. Subcategories are not added
  again. These are recorded runtime numbers, not a provider billing attestation.
- Evidence: scripts/export_stage6_usage.py and
  results/stage6/accounting/through-4481.json. Later exports may extend the interval
  while preserving earlier snapshots. The original cumulative goal counter is a
  different metric; it is not substituted for these provider-category records.
- Observed: three user interventions in that interval: the intent approval and
  two status requests. Three automatic goal continuations are recorded separately.
- Limits: the available prompt/response events remain in the local session. The
  public index exposes hashes and counts, not private instructions or reasoning.
  This is not an export of every internal provider transport request body. The
  cutoff excludes later activity, so it is not a final whole-project bill.
- Next check: extend the snapshot at final reporting, reproduce its arithmetic,
  and keep shared authoring costs separate from fixed-source verifier conditions.

## U058 — Benchmark preparation failures were recorded before the full experiment

- References: U055–U057.
- Observed: preparation run-0001 exited 1 before proof pairs ran. Its sysctl
  hardware command exited 1 with "sysctl: sysctl fmt -1 1024 1: Operation not
  permitted". This was hardware inventory, not a failed Dafny toolchain run.
- Resolution: the OS system_profiler command exited 0 and returned Apple M1 Pro,
  MacBookPro18,1, 16 GB memory, and processor information. Its unrelated Activation
  Lock-status warning is retained. The inventory driver omits serial/device IDs.
- Observed: run-0002 exited 1 after the cold reject-all control. Dafny correctly
  rejected three assertions inside one member. The report had incorrectly added
  assertion errors to the member count. It now compares actual member outcomes
  and retains the distinct assertion-error count. The checker was not changed.
- Observed: run-0003 completed all 15 one-repeat preflight pairs with exit 0.
  Correct variants passed; the broken shared helper and reject-all booking were
  rejected under all three conditions for their intended assertion/postcondition.
- Evidence: results/stage6/runs/run-0001–run-0003/ retain raw logs, codes, timing,
  source identities, and prior driver versions. These costs remain preparation
  records; they are not silently discarded from the reported experiment history.
- Next check: complete the five-repeat experiment, replay source evidence, check
  the report totals, and retain all baseline warm-up costs and native-cache limits.

## U059 — An audit-scope control exposed a gap; the new booking gate now checks concrete roots

- References: U056, U058.
- Observed: the first controls run exited 1. A planted unannotated assume statement
  produced audit 0 when only the witness entry file was passed to Dafny audit.
  The subsequent verifier returned 2 for the missing axiom-annotation warning,
  and the gate returned 1. It did not emit accepted evidence for the fixture.
- Observed: a direct audit naming Booking, Ledger, and the witness returned 2 and
  reported one finding. This established the missing audit scope. The new booking
  gate now passes each concrete implementation as an explicit audit input.
- Resolution: the final python3 scripts/check_stage_6.py command exited 0.
  Correct source and imported-evidence replay both passed, and cmp returned 0.
  All six negative gates returned 1. The assumption and bodiless-lemma cases each
  returned audit 2 before proof verification. No negative wrote accepted evidence.
- Evidence: results/stage6/controls/report.json preserves the failed control;
  development/control-assume-warning/ and audit-scope-probe/ preserve real child
  results. controls-2/report.json and controls-final.json hold the final controls.
- Scope: the change strengthens the new audit boundary. The approved specs,
  locks, existing ledger gate, and existing ledger policy were not weakened.
  This resolves the audit-scope limit of the earlier U056 observations.

## U060 — The full reuse experiment and recorded totals passed their real EXIT commands

- References: U058–U059.
- Observed: python3 scripts/benchmark_reuse.py exited 0 after 75 real pairs:
  five cases, five repetitions, three conditions. Correct variants passed and
  both invalid controls failed at the intended checker member in every condition.
- Measurements across 25 pairs each, including baselines: cold verifier processes
  used 269.712851166 seconds; shared files 271.066563456; native dependency reuse
  175.827515081. Checked members were 1100, 1100, and 590 respectively. Native
  reuse reported 510 reused members. Negative controls are included in these counts.
- Observation: cold and shared-file layouts each used 342198540 new solver
  resources; native reuse used 224568970. Cached historical statistics are excluded
  from new-work totals. Shared files alone did not skip verification in this run.
- Observed: python3 scripts/exit_stage_6.py --case report exited 0. It recomputed
  actual totals, checked raw logs and accepted source evidence, and reconciled
  runtime token sums. The repeated report command exited 0; both actual cmp
  commands exited 0 for the report JSON and generated document.
- Observed: all 450 materialized input files matched their frozen fixture bytes.
- Evidence: results/stage6/benchmark.json, report.json, report-exit-attempt1.json,
  report-replay.json, input-identities.json, and docs/reuse-benchmark.md.
- Limits: these are fixed-source measurements on the recorded M1 Pro host. The
  host was not isolated from all OS/user activity. Five repeats do not establish
  general speedups, LLM authoring savings, or developer productivity. Fresh timing
  reruns can differ. The native-cache assumptions from U034 remain explicit.

## U061 — Stage 6 completed; accounting and integration limits remain explicit

- References: U054–U060.
- Observed: the final reporting interval contains 76 actual runtime usage records.
  Their six-category sums match cumulative differences. Input: 10041872 tokens,
  including 9944960 cached. Output: 104763, including 53391 reasoning. Total:
  10146635. Reported cache-write input: 0. Subcategories are not added again.
- Observed: three user interventions (approval and two status requests) and three
  automatic goal continuations are separate. Failure and setup records remain in
  the report. Shared authoring costs are not assigned to conditions by guess.
- Limits: the token interval closes before publication, so these are not final
  whole-project costs. Available local prompt/response events have a public hash
  index; private instructions/reasoning and internal provider transport bodies
  are not published. Early syntax resolution and one hardware inspection lack
  isolated subprocess timing; neither was a proof run. No missing metric is zeroed.
- Integration boundary: the existing PR Action still reports ledger C1–C5.
  Booking B1–B4 acceptance uses the explicit booking gate command. No automatic
  booking PR-enforcement guarantee is established by this stage.
- Resolution: Stage 6 EXIT commands both ran and returned 0 with their required
  behavior. Stage 6 is DONE; Stage 7 is CURRENT. This run stops at that transition.
  No binary-layer work ran. Source evidence remains source_proof; end_to_end=false.
