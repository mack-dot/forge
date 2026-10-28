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


## U062 — Docker access is restored; binary proof results remain pending

- References: U002, U061.
- Observed: the prior Stage 7 attempt ran docker version and returned 1 with
  connect: operation not permitted for the Docker daemon socket. No file changed
  after that toolchain failure. That diagnostic remains in the conversation.
- Observed: the user enabled full permissions. The actual retry returned 0.
  The pinned upstream checker image downloaded with exit 0 and ran offline
  under Docker's linux/amd64 support on this ARM64 Mac. Rocq version and Python
  version commands both returned 0. Raw command records are under
  results/stage7/commands/; no proof verdict is inferred from startup.
- Pins: upstream bf6a65114ed2e255098e213e183e83f63c2cabcc; checker index
  sha256:cc9ae43a9f4b0dd59d7c8d30727d36e039bfe72a2a9f9c4a99c68e413037e902;
  AMD64 manifest sha256:1b7a1e562f37e418359b646d68d9e0b69b512fa8a03188b0c35fe1ca4b3f4be2;
  LPS commit f1006fe8178338a499b5e5c41be83006c4edd058.
- Uncertainty: successful startup does not establish that the selected proof
  fits this host's resource limits. The zlib checksum proof has not run here.
- Impact: Stage 7 remains CURRENT. end_to_end=false. LPS's published scope and
  unchecked model-to-system assumptions must remain explicit in later evidence.
- Next check: finish the exact upstream checkout and hash-pinned dependencies;
  replay zlib/checksum_fuzzer/plain_halts with the published checker.


## U063 — Binary evidence and abstraction discovery are separate objectives

- References: U060, U061, U062.
- New instruction: the user prioritizes completing the binary layer first.
  After Stages 0–10, investigate whether agents discover reusable abstractions.
  First product priorities are an installable CLI, independent replay, an agent
  skill, and verification impact reports. VISION.md records these directions.
- Observed: Stage 6 reused ledger lemmas in a booking proof and measured the
  established verifier's native cache. This establishes reuse for those cases.
- Uncertainty: no experiment has established that an autonomous Forge discovery
  system finds useful abstractions, reduces total cost, or beats native caching
  or human-selected shared lemmas. Broad developer usefulness is also unmeasured.
- Impact: do not describe cache orchestration as a demonstrated discovery
  breakthrough. Keep discovery cost, rejected candidates, maintenance, and human
  help in any future comparison. Keep checked claims and rejection tests fixed.
- Next check: finish the foundation in order. Then use held-out tasks and equal
  budgets to test discovery against the recorded baselines. No discovery system
  or later product feature is implemented by this documentation update.


## U064 — Linux source identity recovered; proof checking is still pending

- References: U002, U062, U063.
- Observed: the pinned upstream tree contains 110 case-collision groups and 222
  paths. Attempt 0001 retained the host checkout's changed-byte diff and exited
  1 before Rocq ran. Its files and all earlier Stage 7 command records remain
  byte-identical to the recovery snapshot.
- Observed: the Linux volume is ext4, owned by 1000:1000, mode 0755. The failed
  clone used 501:20 and could not write there. The earlier chown returned 0, but
  its intended owner was not present on the subsequent mount. The cause of that
  ownership reset is not established; recovery makes no assumption about it.
- Repair: use the existing non-root opam user (1000:1000). A fresh shared clone
  and checkout of bf6a65114ed2e255098e213e183e83f63c2cabcc both returned 0.
  The read-only Git object source is trusted only for its exact task-specific
  path; no global Git/Docker setting or broad host permission changed.
- Observed: attempt 0002 checked every tracked file against the upstream tree:
  149053 files, 8606911568 bytes. All 222 case paths coexist as distinct inodes.
  The selected zlib ELF matches its pinned digest. Rocq, rocqchk, dune, Python,
  Git, opam inventory, and Python package version commands all returned 0.
- Observed failure: attempt 0002 exited 1 because the subprocess recorder tried
  to execute the upstream shell launcher as Python. No Rocq proof ran. The
  corrected recorder invokes the same Python module and arguments as that
  launcher and only observes actual subprocess return values. The previous
  recorder and all failed output are archived under results/stage7/.
- Requirement: the user's recovery instruction adds independent rocqchk checks
  to upstream replay. Both independent checks and the published assumption
  audit must complete before acceptance; --rocqchk is now in the invocation.
- Impact: infrastructure identity is established for that run, not a binary
  theorem. No Stage 7 EXIT has passed. end_to_end=false.
- Next check: finish the actual upstream proof and independent checks, then the
  invalid-proof control. Only after those pass, begin the own-binary proof.


## U065 — Upstream proof compiled; independent proof checking remains pending

- References: U062, U064.
- Observed: attempt 0003 completed the statement build and its independent
  rocqchk pass with exit 0. The statement closure audit reports 86 allowed
  assumptions. The proof library build, fresh target proof compilation, and
  generated theorem-binding wrapper compilation also returned 0.
- Observed: the published wrapper audit reports 15 allowed assumptions. These
  are Rocq primitive arrays, integers, and strings; classical logic; and
  dependent functional extensionality. The exact names are retained in
  results/stage7/commands/recovery-upstream-wrapper-audit/. This is not the
  complete dependency-closure audit, which is still running.
- Observed: all 201 LPS source files inside the pinned image match aggregate
  hash c69c38f381767a112d0b4d5692548369f65cbf3a73ba198f76f98310894dd4de
  from the pinned upstream Dockerfile. The actual hash check returned 0.
  Tool executable hashes are also retained. Image build provenance remains
  trusted; this source identity check is not a compiler-correctness proof.
- Uncertainty: the final rocqchk pass has not completed. Its required result,
  full assumption audit, and the final source-identity check remain pending.
- Impact: no upstream-replay EXIT pass is claimed. Stage 7 remains CURRENT;
  end_to_end=false. The negative fixture is prepared but has not run. No own
  C/Rust binary proof work has begun.
- Next check: finish the independent proof check and source-identity check.
  Then run the negative control before starting the own-binary phase.


## U066 — Upstream replay passed with full independent checking

- References: U064, U065.
- Observed: the complete upstream-replay EXIT returned 0 on attempt 0003.
  Both independent rocqchk commands returned 0. The final dependency closure
  reports 86 allowed assumptions and no type-in-type, unsafe fixpoints, or
  assumed positivity. The theorem-specific wrapper audit reports 15 allowed
  assumptions. Full raw output and exact commands remain in that attempt.
- Observed: all 149053 tracked files and the selected ELF have identical
  pre/post digests. The tracked SHA-256 manifest digest remains
  52436d2401d74c3dbba702abdb73b0b3b2d517ec71e80d449176aa5b3f9ba55c.
- Observed counts: the library has 407 source modules; its Dune log records
  407 actual module compilations. Independent checking processed 469 modules
  for the statements and 997 modules for the final proof closure, including
  all 407 proof-library modules. These are distinct counts.
- Scope: this establishes the pinned zlib plain_halts theorem under its
  published LPS model and premises. It does not establish an own Forge binary
  theorem, deployment correctness, or binary versions of the ledger claims.
- Remaining work: negative-control and own-binary EXITs have not passed.
  Stage 7 remains CURRENT and end_to_end=false.
- Next check: require the real compiler to reject the prepared bad proof and
  to reject a valid True certificate at the published theorem-binding wrapper.
  Only then begin the own-binary proof.
- New research instruction: after stable acceptance, measure construction,
  compilation, and independent checking separately. Preserve this baseline.
  The current run has no complete per-phase timing/peak-memory instrumentation;
  periodic Docker samples are not peak-RSS measurements. Do not infer missing
  timings or claim matched performance gains from this observation alone.


## U067 — The negative binding control passed; own-binary work is now eligible

- References: U066.
- Observed: invalid-proof attempt 0001's complete EXIT returned 0. The
  prepared fixture returned 1 because I has type True, not plain_halts.
  A separate True certificate compiled with 0. The unchanged published
  binding-wrapper template then returned 1 because that certificate has
  type True instead of Statements.plain_halts. These are proof-related
  rejections. No missing-file, permission, or container error counted as a pass.
- Observed: pre/post source identity checks returned 0 and all source and
  selected ELF digests match. The compiler codes remain separate from the
  harness's successful rejection-test exit.
- Observed: the host's Apple clang lists no RISC-V target. The published
  compiler image 6a6b4816865c7ec61801ae0fcab6d9c81a599ffcb20616576a9c668abd8b0a7b
  was pulled with exit 0. Its clang and lld version commands each returned 0
  and report 20.1.8. No own executable has been compiled or proved yet.
- Scope decision: use a small C arithmetic self-test with a runtime loop.
  Its proposed claim is about the exact compiled executable under LPS, not
  arbitrary arithmetic inputs or the source-to-binary correctness of clang.
  The published image loader, proof helpers, wrapper audit, and independent
  kernel check remain mandatory. No custom semantics or decoder is planned.
- Publication: the user requested a commit and push before continuing. Publish
  the verified upstream and negative results with all historical failures,
  while leaving Stage 7 CURRENT and own-proof NOT RUN. end_to_end=false.
- Next check: pin the C source, build flags and ELF, then prove and independently
  check that own binary. Performance work follows stable acceptance.


## U068 — Own ELF built reproducibly; valid-entry witness required

- References: U067.
- Observed: public commit 51f7b58ae0aae50e3940c8fcce8eaf8e16dfebf9 preserves
  the upstream replay, negative control, and earlier failures. The remote tree
  matched all 238 prepared file contents and preserved unrelated remote files.
- Observed: own-build attempt 0001 returned 0. Both real clang compilations
  returned 0 and produced the same 1240-byte RISC-V ELF, SHA-256
  8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6.
  Exact source, compiler image, clang/lld 20.1.8, flags and output are retained.
  This is build reproducibility, not compiler correctness or a binary proof.
- Scope: the fixed-input GCD self-test must terminate normally with status 0
  for every valid input and entry under the pinned LPS may_fail model. The
  numerical constants are embedded in this exact executable. No arbitrary-input
  GCD or deployed-artifact claim follows.
- Requirement: the user explicitly requires a valid-entry witness. The new
  WitnessSpec states existence of a valid input and entry, together with the
  same normal-termination property. Its proof uses the published valid input
  and image-entry existence lemmas for this compiler-produced image. The
  original universal termination statement and its hash are unchanged.
- Observed: own-proof attempt 0001 is running. No own proof result is yet
  established. Its runner and candidate sources were frozen before execution;
  pre-witness drafts are also retained. Both theorem wrappers and the entire
  independent dependency closure must pass with the unchanged allowlist.
- Impact: Stage 7 remains CURRENT; end_to_end=false. The latest user direction
  is to transition to Stage 8 and stop if all three EXITs pass. Performance and
  proof-construction research therefore remain deferred to a later run.
- Next check: finish the actual own-proof EXIT, including the final source and
  ELF identity checks. Preserve failed attempts; never weaken the statement.


## U069 — Own binary termination and non-vacuity independently checked; Stage 7 complete

- References: U066, U067, U068.
- Observed: own-proof attempt 0001's complete EXIT returned 0. The generated
  ELF image, image validity, execution certificate, universal termination
  theorem, witness statement and witness proof all compiled with 0. Both
  unchanged published theorem-binding wrappers compiled with 0.
- Observed: the real rocqchk -o -bytecode-compiler no command returned 0 over
  the complete 579-module dependency closure. Its official audit lists 86
  permitted assumptions and no type-in-type, unsafe fixpoints or assumed
  positivity. Each theorem-specific audit lists 13 permitted primitive
  assumptions. Exact names, module names, raw output and commands are retained.
- Scope: halts_may_fail [verdict_accept] Images.program applies to the exact
  ELF 8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6.
  Every valid modeled execution terminates normally with status 0, without a
  budget-refusal exemption. A separate, independently checked theorem supplies
  a valid input and entry and the same termination property there. The original
  universal statement hash remains unchanged; the witness is an added check.
- Observed: both complete upstream source identity commands returned 0. Their
  manifests match. The own ELF, C and proof sources, and generated image inputs
  retain their initial digests. Post-check hashing of all 579 compiled dependency
  files returned 0; this is identity evidence, not another kernel execution.
- Observed: canonical evidence serialization returned 0 twice, directory diff
  returned 0, and the existing JSON Schema check returned 0. No second proof
  replay is inferred from serialization or structural validation.
- Incidental diagnostic: a read-only docker exec inspection returned 1 because
  the successfully completed container had already stopped. The actual EXIT
  returned 0; the collected host logs supplied the inspection data. The failed
  inspection is retained separately and is not a proof failure or negative test.
- Limits: this is a fixed-input self-test, not general-input GCD correctness.
  ELF loading/data import, published image provenance, Rocq primitives, model
  fidelity, host runtime and hardware remain trusted. Compiler correctness,
  deployment identity, whole-service correctness and performance gains remain
  unproved or unmeasured. No assumption allowlist or protected file changed.
- Impact: all three Stage 7 EXIT commands have passed. Stage 7 is DONE and
  Stage 8 is CURRENT. end_to_end=false. All historical failures remain intact.
- Next check: publish the complete record set and stop at this transition, as
  explicitly requested. Stage 8 implementation and verification-economics
  experiments require a later run; neither was started here.


## U070 — Stage 8 requires exact intent approval before implementation

- References: U069; the user's Stage 8 instruction and follow-up requiring both
  universal safety and complete acceptance of every valid proposal.
- Observed: public main is ef06de72b38bb00041b4e52204880e75c4c002a9. Thirty
  tracked instructions, schema/toolchain inputs and protected files match that
  revision. A local snapshot covers all 31 existing protected files, including
  local cache files. No existing approved refund contract was found.
- Approval boundary: the user explicitly requires exact approval before changes
  to protected specifications, policies or gate files. Prior Stage 7 permissions
  do not approve a new reason set, numeric cap, fallback or payment policy.
- Proposal: proposals/refund.md and proposals/refund/protected.diff define four
  additions, with candidate bytes and digests in approval-manifest.json. None
  is applied. Universal safety has no response-validity precondition; every
  eligible candidate must be accepted unchanged. Rejection returns an empty
  plan. An always-reject implementation must be rejected by the real verifier.
- Proposed decisions: exact integer minor units through 2^63-1; a trusted
  original/remaining balance and eligibility/open context; three exact reason
  labels; valid zero authorizations; no-refund fallback; a strict 4096-byte JSON
  interface; 5000 ms external deadline; terminal request/retry rules. These are
  pending business decisions, not silently adopted policy.
- Scope: the mathematical boundary quantifies over all modeled responses.
  JSON parsing, generated runtime behavior, timers, one-shot delivery and effect
  isolation need separate tested or assumed boundaries. Cumulative refunds,
  atomic balance reservation, durable idempotency, real payment execution and
  factual truth of model reasons are not established by this stateless source
  contract. The Stage 7 C ELF proof does not cover the new runtime integration.
- Observed checks: pinned Dafny version and candidate resolve returned 0.
  Dafny explicitly did not attempt verification. Patch dry-run returned 0;
  no patch was applied. Pinned policy-schema validation returned process exit 0.
  These proposal checks are not Stage 8 EXIT passes or a proof.
- Gate limitation: existing gates bind the ledger and booking contracts. This
  proposal approves no unspecified gate implementation. Any required new gate
  or binding patch must receive exact approval before application, as the user
  requires. Relocating gate logic to evade that protection is not permitted.
- Impact: Stage 8 remains CURRENT, all three EXITs are NOT RUN, no wrapper or
  fuzzing implementation has started, no model evaluation has run, and
  end_to_end=false. Planned fuzz counts are not actual coverage.
- Next check: publish the exact pending contract for review and stop. Obtain
  human approval of its precise revision before adopting its protected files.

## U071 — Exact refund contract adopted; separate gate decision remains open

- References: U070; the user's exact approval of the four additions at
  e3aa546f86dc5b43ec8c754792e3db4cb413b410, with no real refunds or future
  unspecified gate changes authorized.
- Observed: public main still named that approved revision. The Git tree,
  candidate Git blob identities, manifest and patch hashes matched. All four
  target paths were absent. The exact approved bytes were copied to the spec,
  protocol, lock and policy paths. All prior protected files remain unchanged.
  Adoption details are in results/stage8/contract-adoption/identity.json and
  proposals/refund-decision.md. The historical proposal remains unchanged.
- Observed: the concrete pure Refund.Assess implementation and proposed binding
  passed actual pinned Dafny verification (exit 0): six required obligations,
  including an arbitrary-input call and an eligible successful witness. The
  empty-report audit returned 0 with zero findings. The JavaScript build
  returned 0 and verified four source obligations. Complete logs, exact argv,
  source digests, before/after identities, TRX and generated bytes are retained.
- Observed failure: the first strict TypeScript check of the proposed hostile
  suite returned 2 (TS2769, differing property tuple types). Its source snapshot
  and complete output remain in static-0001. Correcting that type declaration
  produced exit 0 in static-0002. No hostile test cases ran in either check.
- Proposal: proposals/refund-gate.md contains three exact protected additions:
  a fresh-check entrypoint, universal/witness binding, and finite hostile suite.
  It includes a complete patch and immutable candidate digest manifest. Python
  syntax parsed. Patch dry-run returned 0. No proposed gate path exists yet.
- Scope: direct development verification is not an accepted Stage 8 evidence
  bundle or an EXIT pass. The gate acceptance workflow has not run. Runtime
  adapter, EXIT harness, proof/audit rejection controls, effect-bypass control,
  hostile tests and evidence reproduction remain unfinished. Planned counts
  are not observations. No real model-quality evaluation has run.
- Assumptions: source verification trusts Dafny, Boogie, Z3, their runtimes and
  the host. The proposed runtime tests use a controlled logical clock and a
  recording executor. They cannot prove physical timeout delivery, parser or
  compiler fidelity, durable idempotency, cumulative refunds, external payment
  effects, deployment identity or model accuracy. JSON/JavaScript string
  behavior is not proved equivalent to the Dafny Unicode-string model.
- Impact: U070's contract-approval uncertainty is resolved. Gate approval is
  still required by the user's limited approval. Stage 8 remains CURRENT;
  every Stage 8 EXIT is NOT RUN; end_to_end=false. Historical failures remain.
- Next check: publish the adopted contract and exact pending gate diff. Obtain
  approval of those exact three additions before applying them. Then implement
  the fixed runtime adapter and EXIT harness, run all required real checks and
  rejection controls, preserve failures, and verify canonical reproduction.

## U072 — Approved Stage 8 gate exposes a frozen test-snapshot blocker

- References: U071; exact approval of the three gate additions at
  d2d557e2dcd564049fbd97171b0af67659eacf81; the later instruction to freeze scope
  and make no changes to approved contracts, policy or gate files.
- Observed: the approved public tree, manifest, patch and candidate digests
  matched. All three targets were absent and received the exact approved bytes.
  All previously protected files stayed unchanged. The decision and adoption
  records are proposals/refund-gate-decision.md and results/stage8/gate-adoption/.
- Observed: the unprotected adapter, supplemental tests and EXIT harness were
  implemented. Strict TypeScript checking returned 0. The adapter has no payment
  client; its executor is supplied externally and the tests only record calls.
- Observed failure: wrapper EXIT attempt 1 returned 1. Its positive gate and
  actual negative verifier/auditor runs behaved correctly, but the harness
  omitted Dafny's audit.md.expect file when looking for the assumption finding.
  That unprotected report-reader fix was made. Full wrapper attempt 2 returned
  0. Both complete attempts and original source snapshots remain archived.
- Observed: six required obligations passed, including the arbitrary-input
  binding and eligible successful witness. The over-limit mutant failed actual
  verification with 4 at R1; reject-all failed with 4 at R4. The assumption escape
  failed the actual auditor with 2 and an explicit Refund.Assess finding. Their
  gate processes returned 1. No protected requirement changed.
- Observed blocker: hostile-outputs returned 1. After 68 fixtures and 3,000
  passing T1 cases, T2 seed 8001 failed after two cases and six shrinks. The
  first expected-value assertion passed. Its subsequent mutation assertion
  compared a null-prototype input record against a structuredClone snapshot
  with Object.prototype. The raw assertion shows that prototype difference.
- Observed: evidence-separation returned 1 at the same protected T2 assertion.
  Its two fresh accepted source bundles were byte-identical and also matched
  the successful wrapper EXIT's bundle. All three independently executed the
  real Dafny proof and audits. Source artifact SHA-256:
  de34f8f9deb55c5978b9ccf4656b91b1361d6c0600348bcae4e5abd5f127f3e5.
  Canonical source evidence SHA-256:
  acafe3f90623314d4389604ffbc8d99c880091ea8a28f805b255ae1a60c753fe.
- Observed development checks: supplemental tests returned 0 for 23 fixtures
  and 500 generated cases (seeds 8004 and 8005), covering stale responses,
  caller/result mutation, executor reentry/failure and numeric/wire boundaries.
  An unapplied prototype-preserving snapshot candidate, executed directly from
  proposals/ before the final freeze, returned 0 for 9,000 cases and 68 fixtures.
  Its diff dry-run returned 0 without application. These are finite development
  observations, not passing Stage 8 EXITs or accepted integration evidence.
- Unfinished: the EXIT harness has not reached effect-bypass, duplicate-dispatch,
  fabricated/mislabeled-evidence or spec-tamper controls. It has not established
  canonical integration evidence reproduction. Model quality is unmeasured;
  there is no passing eval_measured record. Full results, seeds, shrinks, raw
  output, source identities and actual codes are in results/stage8/status.json
  and its linked attempt directories. Previous failures are preserved.
- Interpretation: the approved test snapshot causes a false mutation report
  for a generated input. It is not evidence of an observed refund-policy
  violation. It remains a real rejection: neither a proposed fix nor a direct
  candidate test run can convert the unchanged approved gate into a pass.
- Impact: Stage 8 remains CURRENT — blocked; Stage 9 is NOT STARTED;
  end_to_end=false. The source proof still trusts Dafny/Boogie/Z3 and the host.
  Compilation, parsing, external clocks, durable idempotency, real payments,
  deployment identity and model accuracy are outside its universal guarantees.
- Next check: preserve and publish this blocked checkpoint. Under the current
  freeze, do not apply proposals/refund-hostile-snapshot.md. A separate exact
  decision is required before that protected repair could be applied and the
  incomplete EXIT requirements and negative controls could be rerun.

## U073 — Exact snapshot repair approved; all Stage 8 EXIT requirements pass

- References: U072; the user's exact one-file approval at
  76f58de25fb5ebe305831432907e42a4210add40, limited to the published
  prototype-preserving snapshot replacement in gate/refund/hostile.ts.
- Observed: the public commit/tree, original file, candidate, manifest and
  patch digests matched. The real git apply dry-run and patch application each
  returned 0. Applied SHA-256 is
  0e15d543f42c32b0b6c2b7aab7eb66962dc7c1facde380c44f00a8710a9c475a.
  All other protected files remain unchanged. The approval and adoption records
  are proposals/refund-hostile-snapshot-decision.md and
  results/stage8/snapshot-repair-adoption/identity.json.
- Observed: new unprotected controls extract the exact approved T2 callback,
  expected oracle, compiled-model bridge and constants with TypeScript's parser.
  Node executes that code against the actual compiled wrapper. Four unchanged
  ordinary/null-prototype input combinations passed. Sixteen actual field or
  prototype changes failed the exact snapshot assertion, after the real model
  returned. No copied replacement assertion or simulated proof checker is used.
- Preserved development failures: the new control's first type check returned 2
  for insufficient object narrowing; the corrected check returned 0. Hostile
  attempt 2 returned 1 because the extraction omitted the rejected helper.
  The protected suite and supplemental checks had passed first. Correcting
  this unprotected extraction allowed the complete hostile EXIT to pass.
- Observed final EXITs: wrapper-proof attempt 4 returned 0; hostile-outputs
  attempt 3 returned 0; evidence-separation attempt 2 returned 0. All declared
  source/harness inputs matched current files and before/after snapshots.
  Earlier wrapper attempt 3 also passed. Every previous attempt remains intact.
- Observed proof controls: all six source, contract, arbitrary-input binding
  and success-witness obligations passed with fresh Dafny execution and empty
  audits. Over-limit and reject-all mutants failed verification with 4 at R1
  and R4. The assumption escape failed the actual auditor with 2. Each negative
  gate returned 1. The approved contract and verification options are unchanged.
- Observed test controls: each accepted hostile-suite run executed 9,000 cases
  and 68 fixtures using the approved seeds/counts. Supplemental tests passed
  500 generated cases (8004/8005) and 23 fixtures. Effect-bypass and duplicate
  dispatch each failed the actual test process with 1 for an assertion reason;
  each gate returned 1. Counts describe finite executed tests, not a universal
  runtime theorem or additional distinct coverage on repeated seeds.
- Observed evidence controls: property_tested-as-proof and eval_measured-as-proof
  were rejected by method policy with gate 1. Wrong artifact, invented case
  count and altered spec identity each returned gate 1 for the intended reason.
  Invented-count rejection followed fresh real checks, not cached acceptance.
- Observed reproduction: the source and property bundles each match three fresh
  accepted runs byte for byte. Both name the same proved source artifact where
  linked. Source evidence SHA-256:
  be32ef9e27fee402aefd9fab6de9cc66ceb03d1d68101d6b238364756ebd8c86.
  Property evidence SHA-256:
  77d94ab0c41ea5c887924515f0921f6c0362c32d427b3f11d7afc79f21cbe0dd.
  Compiled JavaScript module SHA-256:
  d462e12309766d5b055715500daab5c238e9c9d06236b47577d43941c22b4dda.
- Records: results/stage8/completed/completion.json links actual EXIT reports,
  codes, commands, full assumptions, case/shrink records and canonical files.
  All 373 pre-existing Stage 8 record files matched their original hashes.
  The old blocked status and approved proposal text remain unchanged.
- Limits: source_proof covers the mathematical boundary, including universal
  safety and exact acceptance. Finite property/unit tests cover executed runtime
  scenarios. Model quality is unmeasured, with no score or passing eval_measured
  record. Dafny/Boogie/Z3 and the host remain trusted. Compiler/parser fidelity,
  physical deadlines, durable idempotency, cumulative refunds, actual payment
  execution and deployed identity remain outside the universal proof.
- Impact: the Stage 8 EXIT requirements are complete. Mark Stage 8 DONE and
  Stage 9 CURRENT in this checkpoint, keep end_to_end=false, publish and verify
  the remote commit/tree, then stop. No Stage 9 implementation has started.

## U074 — Stage 9 requires an explicit provenance trust contract

- References: U073; the user's Stage 9 instruction to prepare an exact proposal
  and stop before changing protected specifications, gates or policies.
- Observed: public main and 68 local baseline files matched Stage 8 commit
  80a65d46b1dbc8f3ccfd249bfd628568406c5774. The accepted own ELF is 1,240 bytes,
  SHA-256 8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6.
  Its existing evidence is unsigned. The existing ledger, booking and refund
  policies do not authorize a provenance signer or define release acceptance.
- Proposed, not approved: proposals/provenance.md binds exactly three additions
  by manifest and patch digests. These define a GitHub Actions keyless identity,
  pinned Cosign 3.1.4, public Sigstore TUF trust, current request/policy checks,
  fresh producer compilation and complete independent Rocq checking, and actual
  deployed-file observation. This is not approval to execute a new workflow.
  Its separately approved implementation lock is a mandatory missing prerequisite;
  unknown future gate code cannot activate this policy automatically.
- Observed preparation: GitHub API metadata supplied Cosign release asset hashes
  and immutable source revision 0e48502cf5ef34e2e60bbd3617aa19945712f705.
  Official CLI source exposes exact certificate/workflow constraints and
  established attestation commands. This is source/interface research, not
  cryptographic verification or successful execution of those interfaces.
  Cosign and local RISC-V QEMU executables are absent from PATH. No installation
  was attempted. There is no hidden failed installation or passing signature.
- Observed preparation checks: python3 proposals/provenance/check_proposal.py
  returned 0. Its real git apply --check returned 0. The patch was not applied.
  Forty-seven existing files and the complete 579-module audit are locked;
  the two 13-assumption theorem lists and the 86-assumption closure list match
  the accepted audit exactly. All 1,406 snapshotted existing files matched before
  the documentation updates, including 30 protected files and all old Stage 7–8
  records. Raw output and identities are in results/stage9/preparation/.
- Uncertainty: actual OIDC issuance, certificate constraints, TUF validation,
  fresh kernel replay in the authorized producer, signature controls, packaging
  and deployed namespace observation have not executed. The prospective gate
  must reject if any required capability is unavailable. Source inspection and
  a checksum supplied by a release API do not establish tool authenticity by
  cryptographic verification. Bootstrap distribution remains an explicit trust.
- Limits: the proposed deployment scope is observed file materialization in a
  started local container, not guest ELF execution, persistent process identity,
  model-to-hardware fidelity or deployment correctness. GitHub, Sigstore, the
  release controller and its clock/state, checker isolation, container runtime,
  OS and hardware remain trusted. Stage 8 source proofs and finite tests remain
  distinct; model quality is unmeasured. Signing cannot establish correctness.
- Impact: Stage 9 remains CURRENT — blocked on exact contract approval. All six
  required EXIT commands are NOT RUN. No protected file, signing workflow or
  acceptance code changed. No Stage 10 work started. end_to_end=false.
- Next check: obtain exact revision-bound approval of the three proposed files.
  Then apply only those bytes and prepare a separate exact gate/workflow proposal.
  Never interpret this contract decision as approval of unspecified gate code.

## U075 — Contract approved exactly; separate implementation proposal is pending

- References: U074; the user's exact three-file approval at
  097431cf458e5c62332575b09e953224471fa64d, explicitly excluding gate code,
  workflows, signing, production deployment and future protected changes.
- Observed: public main/tree and all six frozen proposal files matched. The
  manifest SHA-256 is 92c56b5d36c44242a826905f2c7194052b802b7079d0d0130d686dbf885551cf.
  Both real git apply --check and application returned 0. The three installed
  protected files match the exact approved bytes; no previous protected file
  changed. All 1,360 snapshotted prior files matched at adoption. The approval
  record and raw outputs are proposals/provenance-decision.md and
  results/stage9/contract-adoption/. This is conversational approval, not a
  cryptographic user signature or evidence of verification success.
- Prepared, not approved: proposals/provenance-implementation.md freezes eleven
  additions: eight protected files, two manual workflows and the EXIT harness.
  The proposed implementation lock binds 60 input files and 45 existing pinned
  upstream Python dependency files. No proposed target is applied. The code
  delegates signatures to Cosign and proof checks to the unchanged published
  Rocq pipeline; it performs identity, receipt and method-policy comparisons.
- Proposed controls: actual authenticated wrong-signer/wrong-artifact fixtures,
  signature absence, validly signed wrong policy/method/spec, stale challenge,
  altered evidence, fabricated receipt, repeated admission and actual deployed
  file substitution. Expected checker diagnostics are inspected in pinned
  Sigstore source. An unexpected error blocks, including changed validation
  order. No missing file, failed network request or container failure qualifies
  as a successful security rejection. None of these controls has executed.
- Observed inventory: Python 3.10.11, Docker client/server 28.5.1, Docker Desktop
  4.48.0, Buildx 0.29.1-desktop.1 and BuildKit 0.25.1. The initial read-only
  docker buildx inspect default --format '{{json .}}' returned 125 with
  "unknown flag: --format". The supported docker buildx inspect returned 0.
  Both attempts and full raw output are retained. No image was built or started.
- Observed checks: Python syntax parsing/compilation, workflow YAML structure,
  proposal digest/input checks and the real implementation-patch dry-run passed.
  python3 proposals/check_provenance_implementation.py returned 0; its actual
  git apply --check returned 0. These are preparation checks only. They do not
  show that the unexecuted implementation satisfies its contract.
- Uncertainty: the proposal needs a dedicated self-hosted macOS ARM64 runner
  with the frozen runtime, runner 2.338.2, and the preserved Stage 7 environment.
  No usable runner is established or registered in this preparation. Provisioning
  and isolation remain separate operational prerequisites. Version inspection
  alone does not authenticate a runner binary; provisioning must check the pinned
  official archive digest. No registration token or host configuration changed.
- Uncertainty: Cosign issuance/verification, current TUF behavior, certificate
  diagnostics, package reproduction, fresh proof receipt transfer and actual
  deployed-file observation remain unexecuted. The pinned native interfaces and
  syntax checks are insufficient to mark any Stage 9 EXIT as passed. Runtime
  incompatibilities must retain their actual errors and cannot weaken acceptance.
- Limits: the package is identified as a Docker image config with all layer
  diff IDs, not falsely labelled an OCI distribution manifest. The deployment
  observation concerns actual file materialization, not RISC-V execution or
  persistent runtime correctness. GitHub, Sigstore, the dedicated producer,
  controller/clock/state, container runtime, OS and hardware remain trusted.
  Source proof, kernel proof, property tests and unmeasured model quality stay
  distinct. end_to_end=false.
- Impact: U074's contract-approval blocker is resolved. Stage 9 remains CURRENT,
  now blocked on the separately reviewable implementation/workflow approval.
  All six real EXIT commands are NOT RUN. Stage 10 has not started.
- Next check: obtain exact approval for the frozen implementation/workflow files
  and an explicit decision on the defined research execution operations. Do not
  provision a runner or dispatch a signing job under the prior limited approval.

## U076 — Preservation audit newline error resolved without changing history

- References: U075; the preparation-only preservation audit.
- Observed: the first inline audit returned 1 at its unsure.md prefix assertion.
  The comparison appended a newline to a prefix that already contained the
  original final newline. Its exact stdin, actual code and traceback are retained
  in results/stage9/implementation-preparation/preservation-attempt-0001/.
- Observed resolution: the exact prefix through U074 matches the original
  recorded SHA-256. The corrected audit returned 0. All 30 prior protected files
  and 1,316 Stage 7–8 record files match; only ROADMAP.md and the append-only
  unsure.md changed among the prior snapshot. The three approved additions match,
  and all 11 implementation proposal targets remain absent.
- Impact: this was an audit-script defect, not a proof or security rejection.
  No historical uncertainty entry or failed evidence was rewritten to pass.
  Stage 9 remains CURRENT; all six EXITs are NOT RUN; end_to_end=false.
- Next check: publish and verify this approval/proposal checkpoint, then stop
  for exact implementation/workflow approval. Actual signing and runtime checks
  remain pending, as stated in U075.

## U077 — Exact implementation applied; receipt audit and runner admission block execution

- References: U075, U076; proposals/provenance-implementation-decision.md;
  docs/stage9-signing-preparation-audit.md;
  proposals/stage9-runner-provisioning.md.
- Approval: the user approved only the exact 11 additions published at
  06b40caa6bf5fb6963756b39646413559f84c61d. Workflow dispatch, public Sigstore
  signing, runner registration and deployment execution remain unauthorized.
  The approval record is a conversation record, not a cryptographic signature.
- Observed adoption: published proposal identities matched. Both git apply
  --check and git apply returned 0. All 11 installed files match the approved
  bytes and SHA-256 hashes. All 1,446 snapshotted pre-existing files were
  unchanged at adoption. No protected implementation was repaired afterward.
- Observed safe check: python3 scripts/check_stage9_installation.py returned 0.
  It checked exact bytes, syntax, manual workflow structure, 60 locked files
  and 45 upstream Python dependency files. It ran no proof or signature check.
- Observed failure: python3 scripts/audit_stage9_receipts.py --output
  results/stage9/implementation-adoption/receipt-audit-0001 --work
  build/stage9-receipt-audit-0001 returned 1. The real approved receipt validator
  did not reject invalid dependency hashes, a substituted copied ELF or a
  missing copied ELF when the supplied manifest matched the inputs. It did
  reject nonce mismatch (STALE_PROOF_RECEIPT) and mutation after manifest
  creation (PROOF_RECEIPT_BYTES). Raw logs, commands, digests and all generated
  fixtures are preserved. Historical Stage 7 inputs remain unchanged.
- Scope: the audit fed real historical logs to the JSON validator as explicitly
  invalid negative fixtures. No kernel, workflow, signature or deployment ran.
  The results establish helper-level validation gaps, not a complete signed
  release bypass. No fixture counts as accepted or fresh proof evidence.
- Finding: signing calls the receipt validator and checks the exact canonical
  statement and locked checkout. The validator checks only dependency-map count
  and value length; it does not bind those values to checked dependency bytes.
  It compares the reported ELF hash but not the actual copied ELF. Signing
  does not rehash the downloaded packaged.elf. Earlier package extraction and
  later file observation exist in code but remain unexecuted in Stage 9.
- Trust limit: a receipt's new nonce does not authenticate a new kernel run.
  Freshness relies on the approved producer job, its isolation and GitHub's
  same-run artifact handoff. The signer does not rerun the kernel itself. Do
  not claim complete independent validation from JSON comparisons or syntax.
- Observed environment constraint: read-only repository metadata reports
  owner.type=User and visibility=public. No enforced restriction to the two
  approved workflows has been established for a dedicated runner. Labels only
  route jobs. Organization runner-group access controls cannot be assumed for
  this personal repository. No runner was registered or host settings changed.
- Uncertainty: dedicated hardware, exact host OS build, workflow admission,
  current availability of the pinned runner and network access remain untested.
  The documented RAM/storage allocations are proposals, not measurements.
  A repository transfer or signer-identity change is not authorized.
- Impact: U075/U076's file-approval blocker is resolved. Stage 9 remains CURRENT
  on the receipt gaps, runner admission and explicit execution authorization.
  All six Stage 9 EXITs are NOT RUN. All prior failures remain. end_to_end=false.
- Next check: review a separate exact receipt-binding repair and resolve runner
  admission before registration or signing. Obtain explicit authorization for
  the concrete provisioning and research operations. Preserve the approved
  bytes until any repair is separately approved. Do not begin Stage 10.

## U078 — Integrity repair prepared unapplied; image-store identity and freshness limits remain

- References: U077; docs/stage9-signing-preparation-audit.md;
  proposals/provenance-integrity-repair.md. It supersedes the earlier unrecorded
  draft proposals/provenance-receipt-repair.md (gaps 1–2 only), which stays
  unchanged as history.
- Observed: a four-file candidate (release.py, producer.py, new
  artifact-identities.json, implementation.lock) is under
  proposals/provenance-integrity-repair/ and results/stage9/
  integrity-repair-preparation/approval-0001/. Nothing is applied. git apply
  --check and git apply returned 0 only in the scratch copy
  build/stage9-integrity-apply-0001. The protected tree hashes are equal before
  and after.
- Observed tests: test_integrity.py attempt 0001 returned 1. That was a harness
  defect: a mutation helper passed write_bytes' integer as the request, and the
  candidate rejected with PACKAGE_MALFORMED:TypeError. Attempt 0002 returned 0
  with no unexpected cases. Results: 31 receipt negatives, 5 audit cases,
  22 package negatives, 4 signing-path negatives and 120 seeded property cases
  were all rejected. 4 positive controls were accepted. The bounded layer model
  had 0 unsound acceptances in 5,652 checks. The installed validator accepted 17
  of the 31 receipt negatives. Both attempts are kept.
- Scope: the test fixtures are historical bytes that are explicitly untrusted,
  plus synthetic image archives. The positive controls show only byte equality
  with the approved identities. They are not kernel-checked proof, and they are
  not formal verification. No kernel, Docker, Cosign, workflow or deployment ran.
- Uncertainty: the fixed attempt-0001 path makes a relabeled historical receipt
  acceptable by content. Freshness still relies on the producer, the fresh
  volume, the controller and the same-run handoff (as in U077). The Stage 7
  record shows Id == RepoDigest, which suggests the containerd store. Under that
  store the approved docker_image_config descriptor may be false. The candidate
  then fails closed with PACKAGE_CONFIG_IDENTITY. The docker image save layout
  is untested because the daemon was not running. Base layers are bound only by
  registry diff_ids. No .git directory is present, so the base commit is not
  checked locally.
- Impact: gaps 1–3 have a candidate repair that awaits exact-byte approval.
  Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: user approval of the four exact hashes. Before any execution,
  confirm the runner image store and the save format, and resolve runner
  admission and execution authorization (U077).

## U079 — Approved integrity repair applied; execution blockers unchanged

- References: U077, U078; proposals/provenance-integrity-repair.md.
- Approval: the user replied "approve" to the report that listed the four
  exact SHA-256 hashes and the diff hash
  df0bd7fbbae0a2680ba076038b9096cbcc87beca3d9516492a8337c1567eda5e. The
  approval is a conversation record, not a cryptographic signature. It does
  not authorize runner registration, workflow dispatch, signing or deployment.
- Observed adoption: the diff hash matched before application. git apply
  --check and git apply returned 0. The installed release.py, producer.py,
  artifact-identities.json and implementation.lock match the approved hashes.
  common.context with lock 9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76
  returned 0 over 61 locked files. The old lock hash is now rejected with
  UNAPPROVED_IMPLEMENTATION (exit 1), as expected. py_compile returned 0.
- Observed: scripts/check_stage9_installation.py returned 1 (AssertionError at
  its candidate byte comparison). It compares installed bytes with the earlier
  11-file approval, which this approved repair partly replaces. The check is
  historical and stays unchanged. Its expectations were not edited to pass.
- Scope: no kernel, Docker, Cosign, workflow or deployment ran. Tests remain
  the finite local controls of U078.
- Impact: the receipt-repair blocker of U077 is resolved at the code level.
  Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false. The
  controller must now supply the lock hash 9b10a237….
- Next check: confirm the runner image store and the docker image save layout.
  Resolve runner admission. Obtain explicit execution authorization.

## U080 — Adversarial suite rerun against the installed gate

- References: U078, U079.
- Gap: test_integrity.py pins the pre-adoption lock 6b43c193…, so after U079 it
  stops at the lock check. Earlier runs tested byte-identical candidate copies,
  not the installed gate itself.
- Observed: derive_installed_test.py checked the hash of the unchanged
  test_integrity.py (982bdc2f…). It applied counted exact replacements and
  wrote test_installed.py (3c26d315…). Exit 0. The derived suite tests the
  installed gate under the new lock 9b10a237…. It compares that gate with the
  pre-repair approved bytes in proposals/provenance-implementation/, after it
  checks their hashes (e9f61515…, f3bcc1dc…). Its result field candidate_sha256
  hashes the installed gate files.
- Observed result: test_installed.py returned 0 with no unexpected cases. The
  repaired gate rejected 31/31 receipt negatives, 22/22 package negatives, 4/4
  signing negatives (no signature files) and 120/120 property cases. The 4
  positive controls were accepted. The layer model had 0 unsound acceptances.
  The pre-repair baseline accepted 17 of 31 receipt negatives, as in U078.
- Scope: the same local fixtures as U078. They are not kernel-checked proof
  and not formal verification. No kernel, Docker, Cosign, workflow or
  deployment ran. test_integrity.py and all earlier records stay unchanged.
- Impact: post-adoption evidence now covers the installed bytes. Stage 9
  remains CURRENT. All six EXITs are NOT RUN. end_to_end=false. The execution
  blockers in U079 are unchanged.

## U081 — Pinned Docker Desktop runtime uses the containerd store; package identity fails closed

- References: U078 (items 4–5), U079, U080; proposals/provenance-integrity-repair.md
  sections 7–8; results/stage9/image-store-observation/.
- Observed: the local runtime matches every pin in gate/provenance/runtime.json
  that was read: Docker Desktop 4.48.0 (207573), Engine 28.5.1, buildx
  v0.29.1-desktop.1, builder desktop-linux, driver docker, BuildKit v0.25.1.
  docker info reports DriverStatus driver-type=io.containerd.snapshotter.v1.
  This is the containerd image store. The host is arm64.
- Observed: observe.py (sha256 03e8f13e…) streamed docker image save for two
  local images. Both runs returned 0. No archive was stored.
  redis:7-alpine (linux/arm64, 7 layers) and the pinned checker base
  cc9ae43a… (linux/amd64, 55 layers) had the same layout: oci-layout,
  index.json, a one-entry manifest.json and blobs/sha256/. Config is
  blobs/sha256/<config digest>. Layers are gzip blobs. Each blob file hash
  equals its path name. Each gunzipped hash equals its diff_id. For the base,
  the config blob is e49a3a57…, which equals the approved base_config.
- Observed: for both images, the Config path does not equal blobs/sha256/<Id>.
  Id equals the RepoDigest digest, not the config digest.
- Inference: under this store, producer.package() fails closed. It fails at
  PACKAGE_IDENTITY or at PACKAGE_CONFIG_IDENTITY. Which one depends on whether
  the buildx iidfile holds the config digest or the manifest digest. That is
  not observed, because no image was built. The other gate layout assumptions
  (blob paths, gzip layers, diff_id binding) held for both saved images.
- Observed: producer.runtime() checks versions and the Desktop name, but not
  the image store. The store is a Desktop setting, not a pinned value.
- Uncertainty: the classic-store save layout is untested on this runtime. The
  runner host does not exist yet. Its store setting is unknown.
- Impact: U078 item 5 (save layout) is resolved for the containerd store on
  the pinned runtime. U078 item 4 is confirmed for that store. Stage 9 remains
  CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: user decision. Either require the classic store on the runner
  and observe the classic save layout, or approve a separate descriptor change
  for the containerd store. Do not relabel the identity. Runner admission and
  execution authorization (U077) remain open.

## U082 — Classic image store chosen; pinned base save layout matches the gate

- References: U081, U078 (items 4–5); proposals/stage9-runner-provisioning.md;
  results/stage9/image-store-observation/.
- Decision: the user chose option A ("do A"): require the classic image store
  on the runner. The user switched the local Docker Desktop setting and said
  it was applied. This is a conversation record, not a signature. It does not
  authorize runner registration, dispatch, signing or deployment.
- Observed: docker info returned 0 with driver overlay2 and no
  io.containerd.snapshotter.v1 entry. Docker Desktop is still 4.48.0 (207573).
- Observed: docker pull --platform linux/amd64 of the pinned checker base
  cc9ae43a… returned 0. observe.py (sha256 03e8f13e…, unchanged) returned 0.
  Summary sha256 8e673cdd…. Id is sha256:e49a3a57…. The Config path is
  blobs/sha256/e49a3a57…, so Config equals Id and the approved base_config.
  RepoDigests contains the pinned reference, which producer.package() requires.
  All 55 layers are uncompressed blobs named by their diff_id. 54 have a tar
  header; one is the standard 1024-byte empty layer 5f70bf18…. The layout
  (oci-layout, index.json, one-entry manifest.json) matches U081.
- Inference: under the classic store, the image-config identity of the gate is
  consistent with docker image inspect and docker image save. The gate's plain
  tar path handles uncompressed layers.
- Not observed: no package image was built. The buildx iidfile value, the added
  layer and the full producer path are untested. The gate does not check the
  store; the containerd store still makes it fail closed (U081).
- Changed: proposals/stage9-runner-provisioning.md has a new pins row that
  requires the classic store. It is not a protected or locked file.
- Impact: U078 items 4–5 are resolved for the base image on the pinned runtime.
  Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: runner admission and execution authorization (U077). A local
  package build, with explicit authorization, would test the iidfile and the
  added layer.

## U083 — Installed package step accepted locally; runner admission still blocks execution

- References: U077, U081, U082; proposals/stage9-runner-provisioning.md;
  results/stage9/package-build-observation/.
- Authorization: the user said "make those changes for me u got all perms"
  after a report that listed a local package build, runner admission and
  execution authorization. This is a conversation record, not a signature.
- Observed: run_package.py (sha256 e6c63f85…) calls clean_environment(),
  common.context(9b10a237…) and the installed producer.package(). Runs 0001 and
  0002 returned 0. All 11 recorded Docker commands returned 0. The descriptor has
  config f15f5bd4…, 57 diff_ids, the 55 approved base diff_ids as a prefix, and
  two added layers (da96748c…, 5f70bf18…). result.json (0ccd5386…),
  package.json and package-identity/ are byte-identical across runs.
- Scope: this is only the package step on the user's working Mac with the
  classic store. The second build may have used the BuildKit cache, so it shows
  stability, not a clean rebuild. Each run left one created, unstarted container.
  No kernel, Cosign, workflow, signature or deployment ran.
- Observed (read-only GitHub): mack-dot/forge is public, owner type User, one
  collaborator, fork PR approval first_time_contributors, 0 runners, five
  active workflows. main is 9679265c…. On main, implementation.lock is
  6b43c193… (pre-repair), release.py and producer.py are the pre-repair bytes,
  and artifact-identities.json is absent. provenance.yml matches the local file.
  The local tree has no .git directory.
- Observed (GitHub docs): organization runner groups need the GitHub Team plan.
  The page does not state the plan for workflow restrictions. GitHub recommends
  self-hosted runners only for private repositories.
- Constraint: the approved runner plan forbids the user's working Mac, repository
  transfer, visibility change and a widened signer policy under the present
  approval. It requires an enforceable admission mechanism before registration.
  A general grant of permissions does not supply dedicated hardware, and it does
  not select an admission mechanism. No runner was registered.
- Note: the local Docker store change (U082) was a local observation at the
  user's request. It is not the runner configuration.
- Impact: the package step is resolved locally. Stage 9 remains CURRENT. All
  six EXITs are NOT RUN. end_to_end=false.
- Next check: user selection of an admission path and of dedicated hardware.
  Publish the approved repair to main before any dispatch.

## U084 — Repository made private; installed gate's GitHub fetches now fail closed

- References: U077, U083; proposals/stage9-runner-provisioning.md;
  proposals/stage9-runner-admission.md (sha256 dfdca5d5…);
  results/stage9/visibility-change-0001/.
- Decision: after an explanation of the trade-offs, the user said "okay do
  that please go private for now". This is a conversation record, not a
  signature. It does not approve the admission amendment, a gate change,
  hardware, registration, dispatch, signing or deployment.
- Observed: before, visibility=public. gh api -X PATCH repos/mack-dot/forge
  -f visibility=private returned 0. After, visibility=private, id 1434789853
  and owner.id 235131950 (unchanged, as policy/provenance.json requires). An
  unauthenticated GET of the repository API returned HTTP 404.
- Observed (code): common.fetch() sends no token. repository_identity() and
  preflight.py fetch api.github.com and raw.githubusercontent.com for this
  repository. The policy does not pin visibility.
- Inference: while the repository is private, the installed gate cannot pass
  its repository-identity and source checks. It fails closed. No run was made
  to observe this.
- Observed: a peer session reported that the account's October GitHub Actions
  spend reached its cap. The three hosted forge workflows run only on pull
  requests to main, path-filtered pushes or manual dispatch. Self-hosted jobs
  use no hosted minutes. Hosted runs in a private repository use paid minutes.
- Uncertainty: the fork pull-request setting endpoint for private repositories
  has not been called or verified. Earlier public publication links now
  return 404 to anonymous readers.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: the user approves or rejects the amendment, chooses option A
  (authenticated fetch, protected exact-byte proposal) or B (public signing
  window), and chooses hardware. Then publish the approved repair to main.

## U085 — Option A violated verifier independence; private-fetch work paused

- References: U084; proposals/stage9-runner-admission.md (now sha256 abcba3b2…,
  with a correction note; U084 recorded the earlier version);
  spec/provenance/protocol.md lines 12–13 and 67.
- Observed: the user asked "shouldnt the verification be independent or not?".
  The question was correct. repository_identity() is called only by the release
  verifier (release.py line 270). The contract requires the verifier to use its
  own approved policy and lock; candidates cannot supply replacement trust.
  Option A as written in U084 gave the verifier the producer workflow's token.
  That design is withdrawn.
- Corrected design (not prepared): the verifier uses its own read-only token on
  the controller host. Only the producer-side check in preflight.py may use the
  job token. exit_stage_9.py passes its full environment to release.py; Cosign
  gets clean_environment(), which drops unknown variables.
- Paused: the user then asked what is best for other users, an organization and
  ease of use. No candidate bytes, scripts or protected changes were written.
- Observed: the proof container is limited to 4 GiB memory and one CPU in the
  approved command. policy/provenance.json already pins a linux-amd64 Cosign
  hash. The checker image is linux/amd64.
- Uncertainty: hosted-runner disk space, the six-hour job limit and per-run
  Stage 7 seed setup are not measured. Plan availability of runner-group
  workflow restrictions is not confirmed.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
  The repository is still private.
- Next check: user decision on the runner platform, visibility and owner.

## U086 — Public repository and hosted Linux runners chosen; visibility change not run

- References: U077, U084, U085; proposals/stage9-hosted-runner.md (sha256
  4ddfe0c9…); proposals/stage9-hosted-runner/probe.yml (sha256 23f0d2d4…).
- Decision: after a recommendation, the user said "lets do that please" for a
  public repository and GitHub-hosted Linux producer runners. The owner or
  organization question is still open. This is a conversation record, not a
  signature, and not approval of protected bytes.
- Observed: the command gh api -X PATCH repos/mack-dot/forge -f
  visibility=public did not run. The Claude Code auto-mode permission check
  denied it ("Create Public Surface"). The repository stays private. No
  other route was tried.
- Observed: spec/provenance/protocol.md has no self-hosted, macOS, Darwin,
  Docker Desktop or runner requirement. policy/provenance.json pins Cosign for
  darwin-arm64 and linux-amd64. toolchain/stage7-pins.json names one image (the
  checker) for linux/amd64. The proof step needs a pinned upstream clone, 45
  locked Python dependency files and a seeded Docker volume.
- Inference: the platform move changes implementation files only (workflows,
  runtime.json, producer.py, preflight.py, implementation.lock). The signer
  identity and contract stay the same while the owner stays mack-dot.
- Uncertainty: hosted image updates versus exact Docker pins, free disk, the
  rebuild time of the Stage 7 prerequisites and the fresh proof duration are not
  measured. The probe is written and syntax-checked only.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
  The self-hosted runner plan and admission amendment are superseded in design.
- Next check: the user makes the repository public. Then push and dispatch the
  probe. Then prepare the exact implementation proposal.

## U087 — Repository public again; hosted-runner probe supports the Linux design

- References: U086; proposals/stage9-hosted-runner.md;
  results/stage9/visibility-change-0002/; results/stage9/hosted-probe-0001/.
- Observed: the user ran gh api -X PATCH repos/mack-dot/forge -f
  visibility=public and pasted its output. A read-only check returned
  visibility=public, id 1434789853 and owner.id 235131950. An unauthenticated
  API read returned HTTP 200, so the installed verifier fetch works again.
- Observed: the probe was pushed to main through the contents API (exit 0,
  commit ac6dfe51…, parent 9679265c…). Its blob 4470a811… equals git
  hash-object of the local file. Dispatch, watch and download returned 0. Run
  40713187818 concluded success at head ac6dfe51…. One recording command (gh run
  view with an invalid field "path") failed; its output is kept as
  run-view-0001.error.txt and a corrected command returned 0.
- Observed host: ubuntu24 image 20261026.354.1, kernel 7.0.0-1017-azure,
  x86_64, 4 CPUs, 16,760,344,576 bytes RAM, 91,895,558,144 bytes free on /.
  Docker Engine - Community 28.0.4, containerd v2.4.2, runc 1.5.2, buildx
  v0.38.1. Storage driver overlay2 with no containerd snapshotter: the classic
  image store.
- Observed pull: exit 0 in 72 seconds; 3,866,910,720 bytes more disk used. Id
  sha256:e49a3a57… equals the approved base_config, and RepoDigests contains the
  pinned reference. This matches the U082 classic-store result.
- Inference: the image-config identity design fits the hosted runner without a
  store change. Disk and memory are sufficient for one image and the 4 GiB proof
  container. The runtime pins must be replaced with Linux values.
- Uncertainty: hosted images change weekly (Docker 28.0.4 here). Exact pins need
  a pinned Docker install in the job, or a recorded exception. Rebuild time of
  the Stage 7 prerequisites and the fresh proof duration are not measured. The
  owner or organization question is open.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: measure the Stage 7 prerequisite rebuild and the fresh proof on a
  hosted runner, then prepare the exact implementation proposal.

## U088 — Approved repaired gate published to main and checked by the gate itself

- References: U079, U080, U087; results/stage9/publication-check-0001/.
- Authorization: the user said "okay fix those please" after a report that
  listed the pre-repair gate on main as an open item. This is a conversation
  record, not a signature.
- Observed: a scratch clone of main at ac6dfe51… was compared with the local
  root, honoring .gitignore. No tracked path on main was missing locally. Six
  tracked files differed in content: the four approved repair files, ROADMAP.md
  and unsure.md. Two Stage 7 ELF files differed only in mode (local 755, main
  644; same bytes 8ced2ab6…). The mode change was not committed
  (core.fileMode=false). 2,698 untracked files (4.6 MB, largest 0.22 MB) were
  added. A pattern scan found no GitHub token or private-key text.
- Observed: commit 70d46565076e47accb3117e1840c3bcd64527aff (author mack-dot, as
  in earlier commits) was pushed to main with exit 0. The installed
  repository_identity() under lock 9b10a237… returned 0 for that commit: the
  repository and owner IDs match, and all 61 locked files on main match.
- Scope: this checks publication bytes only. No proof, workflow dispatch,
  signing or deployment ran.
- Impact: the "old gate on main" item is resolved. Stage 9 remains CURRENT. All
  six EXITs are NOT RUN. end_to_end=false.
- Next check: measure the Stage 7 prerequisite rebuild and a fresh proof on a
  hosted runner (probe 2); decide the Docker pin method; owner decision.

## U089 — Probe 2 attempt 1: pins and Python packages confirmed; volume clone ownership failure

- References: U087, U088; proposals/stage9-hosted-runner/probe2.yml;
  results/stage9/hosted-probe-0002/.
- Observed: commit d722ecef… (probe 2 and its driver) was pushed to main with
  exit 0. Run 40715761881 concluded failure. gh run watch returned 1; view and
  download returned 0.
- Observed (docker-pin job, success): the runner had docker-ce and
  docker-ce-cli 5:28.0.4 and containerd.io 2.4.1 with no Docker apt source.
  Docker's key fingerprint was 9DC858229FC7DD38854AE2D88D81803C0EBFCD88. apt
  update returned 0. Installing docker-ce and docker-ce-cli
  5:28.5.1-1~ubuntu.24.04~noble returned 0. After: Engine 28.5.1, server commit
  f8215cc and client commit e180ab8 (the same commits as the Desktop pins),
  overlay2 classic store, buildx v0.38.0, kernel 6.17.0-1022-azure. The probe-1
  VM had kernel 7.0.0-1017-azure, so the kernel varies across hosted VMs.
- Observed (replay job): Python 3.10.11 and pip 25.1.1 (hash-pinned). The
  upstream seed fetch and checkout took 125 s. The recorded pip command,
  run through a symlink at the macOS framework path, gave 45 of 45 files equal
  to the approved python_container_dependencies, including the bin/idna shebang.
  Both image pulls took 178 s.
- Observed failure: the volume clone returned non-zero with "fatal: detected
  dubious ownership in repository at '/git-source'", although the command passes
  -c safe.directory=/git-source. The later steps were skipped. No proof ran.
- Inference: on Linux the bind mount keeps host ownership (runner uid 1001).
  The container user is 1000:1000. Docker Desktop file sharing on macOS hid this
  difference. Whether git 2.43 in the container honors -c safe.directory for the
  local-clone upload-pack is not established.
- Change: probe2.yml now runs sudo chown -R 1000:1000 on the seed .git before
  the volume clone. This touches only the disposable hosted VM.
- Impact: Docker pinning and the Python-package lock are feasible on hosted
  runners. Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: probe 2 attempt 2.
