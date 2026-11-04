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

## U090 — Probe 2 attempt 2: fresh proof on a hosted runner passes the installed receipt check

- References: U089; proposals/stage9-hosted-runner/probe2.yml;
  proposals/stage9-hosted-runner/replay_probe.py;
  results/stage9/hosted-probe-0003/.
- Observed: commit 2185141295ad6cca80ae2d334dbe61eff5e21f4c (ownership fix) was
  pushed with exit 0. Run 40717015652 concluded success; watch, view and
  download returned 0. Both jobs succeeded.
- Observed (docker-pin): the exact Engine 28.5.1 install returned 0 again.
- Observed (replay job, 20.3 min): seed fetch 96 s; Python packages 3 s, 45 of
  45 equal to the lock; two pulls 143 s; volume clone and checkout 134 s; own
  ELF build 1 s, result built_reproducibly, sha256 8ced2ab6… (equal to the
  approved release artifact); producer.replay() 793 s.
- Observed (replay): all six recorded commands returned 0 (pull, proof run,
  collect, inspect, closure run, closure copy). The proof container had
  OOMKilled false and ExitCode 0. The receipt (sha256 a13681af…) lists 656
  files; closure-identities.json has 579 objects. The installed
  validate_receipt() accepted it inside replay(); result.json has accepted true
  with expected_source_commit 2185141…. Disk after: 59.9 GB free; volume
  10.96 GB; images 9.62 GB.
- Observed: GitHub artifact digests are
  sha256:00c9a38c… (replay, 56,441,617 bytes) and sha256:b3b62bcd… (docker).
  They expire on 2027-01-26. The full download is kept locally. .gitignore now
  excludes probe .vo/.glob/.vos/.vok files and the two tree listings, as it
  already does for Stage 7.
- Scope: the request was synthetic (random challenge, dispatched commit). No
  package, statement, signature, controller admission or deployment ran. This
  is not an EXIT result. Native x86_64 .vo closure objects matched the approved
  identities, which the receipt-repair proposal required before signing.
- Inference: the hosted-runner design is feasible within the 6-hour limit. The
  prerequisite recipe is: pinned Docker install, Python 3.10.11, hash-pinned
  pip 25.1.1, the macOS-path symlink for the pip command, a depth-1 upstream
  fetch, chown of the seed .git to 1000:1000, the recorded volume clone, and
  the unchanged own-build script in a staging root.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: prepare the exact protected implementation proposal for hosted
  runners (workflows, runtime.json, producer.py, preflight.py, lock) and get
  exact-byte approval. Owner decision is still open.

## U091 — Repository transferred to the superpowermentors-1 organization

- References: U086, U090; policy/provenance.json signer fields;
  results/stage9/repository-transfer-0001/.
- Observed: the user said "cool i just transfered it". A read-only check of
  the old API path returned full_name superpowermentors-1/forge, id 1434789853
  (unchanged), owner id 235148649, owner type Organization, visibility public,
  main at ad994235… (unchanged). An unauthenticated API read returned 200.
- Observed: repository Actions enabled, allowed_actions all. The organization
  plan is team (not free). two_factor_requirement_enabled is false. The
  organization has 7 repositories and 3 members (mack-dot, sam-spm,
  superpowermentorss); all three are admins on forge. Team spm has pull. Branch
  protection on main: none. One repository ruleset ("mack") is active, but its
  ref_name include list is empty, so it matches no branch. Reading the
  organization Actions policy returned 403 (the token lacks admin:org).
- Inference: the installed gate now fails closed. policy/provenance.json names
  mack-dot/forge and owner id 235131950, so repository_identity() rejects with
  REPOSITORY_IDENTITY, and the workflows' github.repository conditions skip
  their jobs. No run was made to observe this.
- Trust impact: any of the three admins can push to main and dispatch the
  signing workflow. The contract already trusts "GitHub account/workflow
  controls"; the set of accounts behind them has grown from one to three.
- Uncertainty: whether the user intends this existing team organization (not a
  new dedicated one) as the permanent signer owner. Whether sam-spm and
  superpowermentorss are organization owners (implicit admins) is not read.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: user confirms the owner and the admin set. Then prepare one exact
  proposal: contract/policy identity and the hosted-runner implementation.

## U092 — Owner confirmed; hosted-runner and identity candidate built and checked locally

- References: U090, U091; proposals/provenance-hosted/ (build_candidate.py
  7d764783…, src/hosted_setup.py e8d5f1f6…, dry_run.py bcebe0df…, probe3.yml
  7caa6b4f…); results/stage9/hosted-candidate-0001/.
- Decision: the user said "yes it is i will make this under the company as i
  work here now". superpowermentors-1/forge is the permanent signer owner. The
  three organization admins are therefore in the trust set. This is a
  conversation record, not approval of protected bytes.
- Candidate (unapplied, 10 files): contract and policy name
  superpowermentors-1/forge and owner id 235148649; policy version 2.0.0, epoch 2
  (signer change); the predicate type URL follows the owner; spec.lock binds the
  new hashes. runtime.json has two pinned profiles: controller (macOS Docker
  Desktop, as before) and producer (GitHub-hosted ubuntu24, Docker CE 28.5.1,
  containerd.io 2.4.2-3, buildx plugin 0.38.1-1, builder default). runtime()
  checks the active profile and the classic image store. The package descriptor
  build_command no longer names the builder. preflight checks a hosted Linux
  runner, records (not pins) the image version and kernel, and uses Linux
  Cosign. New hosted_setup.py installs pinned Docker and builds the Stage 7
  prerequisites (the U090 recipe). Both workflows use ubuntu-24.04 and
  setup-python 3.10.11. New lock acf73308… (62 files). Diff 11ee6957….
- Observed (scratch copy): git apply --check and git apply returned 0; all 10
  files equal the candidate bytes; py_compile returned 0; the workflows parse;
  context(acf73308…) returned 0; context(9b10a237…) rejected with
  UNAPPROVED_IMPLEMENTATION.
- Observed (controller profile on the Mac, classic store): the candidate
  package() accepted; all 12 commands returned 0; config f15f5bd4… (equal to
  U083) with the new build_command. Descriptor saved as
  controller-descriptor.json (04b90da4…).
- Uncertainty: producer-profile values for runc, buildx output and BuildKit
  under containerd.io 2.4.2-3 are not yet observed. The implementation lock's
  contract_approval_commit field still names the original contract approval.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
  Nothing protected is applied.
- Next check: probe 3, a hosted dry run of the candidate that requires the hosted
  package descriptor to equal the controller descriptor.

## U093 — Candidate dry run: hosted pins pass; package is not reproducible across builds

- References: U083, U092; proposals/provenance-hosted/;
  results/stage9/hosted-probe-0004/.
- Observed: commit e0eae926… (candidate, dry-run workflow) was pushed with exit
  0. The first dispatch returned HTTP 404 (workflow not yet registered); the
  second returned 0, run 40724981390. watch returned 1; view and download 0.
- Observed: on the hosted runner the candidate diff applied and all 10 files
  matched. The candidate hosted_setup.py passed in 772 s (pinned Docker CE
  28.5.1, containerd.io 2.4.2-3, buildx plugin 0.38.1-1; Stage 7 prerequisites).
  The candidate preflight.py passed. The candidate package() passed runtime():
  every producer-profile pin matched. It built config 45570f02…, not the
  controller's f15f5bd4…, so dry_run.py rejected with
  INDEPENDENT_PACKAGE_REPRODUCTION. replay() did not run.
- Observed cause: the two configs differ only in the ELF layer diff_id
  (da96748c… versus c5256282…). In both layers the ELF entry is identical
  (mtime 0, mode 0444, 1000:1000). The parent directories opt and opt/forge
  carry the build time as mtime (1793197975 versus 1793205219).
- Observed (local, Mac, Docker driver, no cache): two builds with
  --output=type=docker,rewrite-timestamp=true gave different IDs (b996c09e…,
  dfb0f116…); the directory mtimes were again build times. The Docker driver's
  exporter does not apply rewrite-timestamp. Config and history created times are
  already 1970-01-01.
- Correction: the U083 byte-identical package runs and the U092 controller run
  reused the BuildKit cache, as U083 warned. They do not show reproducibility.
  The approved installed gate has the same defect: any uncached rebuild by the
  producer fails INDEPENDENT_PACKAGE_REPRODUCTION. It fails closed.
- Impact: the candidate is not ready for approval. Stage 9 remains CURRENT. All
  six EXITs are NOT RUN. end_to_end=false.
- Next check: a pinned docker-container BuildKit builder with rewrite-timestamp;
  two uncached builds must give the same ID, then cross-host equality.

## U094 — Pinned BuildKit container builder makes the package reproducible locally

- References: U093; proposals/provenance-hosted/ (build_candidate.py 1c44da89…,
  probe3.yml 113653a3…); results/stage9/hosted-candidate-0002/.
- Observed (Mac, classic store): docker buildx create --driver docker-container
  with moby/buildkit:v0.25.1@sha256:79cc6476… returned 0; inspect showed
  BuildKit v0.25.1 and that image. Two --no-cache builds with
  --output=type=docker,rewrite-timestamp=true both returned 0 with the same ID
  f584305022f2e811…. The 55 base diff_ids equal the approved list; the added
  layers are 87095790… (ELF) and 5f70bf18… (empty). The test builder was removed.
- Candidate update: both runtime profiles use builder forge-pinned
  (docker-container, that image, BuildKit v0.25.1). runtime() creates it when
  absent and checks driver, version and image. package() exports with
  type=docker,rewrite-timestamp=true; the descriptor adds buildkit_image. New
  diff 5593a720…, new lock f9f09a2f….
- Observed (fresh scratch copy): git apply --check and git apply returned 0; 10
  of 10 files match; py_compile 0; context(f9f09a2f…) 0 over 62 files;
  context(9b10a237…) rejected UNAPPROVED_IMPLEMENTATION.
- Observed (controller profile, new empty builder): run_package.py returned 0;
  14 commands; builder-present returned 1 (absent, expected), builder-create 0,
  all others 0. Config f584305022f2e811… equals the uncached test.
  controller-descriptor.json is now 22f80a1b….
- Uncertainty: cross-host equality (Mac arm64 versus hosted amd64 BuildKit) is
  not yet observed.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: probe 3 again with lock f9f09a2f….

## U095 — Candidate dry run passes: hosted package equals the controller package; fresh receipt accepted

- References: U093, U094; proposals/provenance-hosted/approval-manifest.json
  (43878f45…); results/stage9/hosted-probe-0005/.
- Observed: commit 64a7760319016fe003ba036e1468732631ccf833 was pushed with exit
  0. Dispatch returned 0, run 40731196167. gh run watch --exit-status returned 0;
  view and download returned 0. Conclusion success; job 40.5 min. Artifact
  digest sha256:5801f183… (56,513,817 bytes), expiring 2027-01-26.
- Observed (steps): the candidate diff applied on the hosted runner and all 10
  files matched. hosted_setup.py passed in 1,377 s. preflight.py passed (image
  ubuntu24 20261023.334.3, kernel 6.17.0-1022-azure, recorded). package() and
  replay() passed in 997 s.
- Observed (package): 20 recorded commands. builder-present returned 1 (absent,
  expected); every other command returned 0, including builder-create, build,
  save, both proof runs and both copies. The hosted descriptor equals
  controller-descriptor.json exactly: config f584305022f2e811…, same 57
  diff_ids, same buildkit_image. dry_run.py's INDEPENDENT_PACKAGE_REPRODUCTION
  check passed.
- Observed (proof): the proof container had OOMKilled false and ExitCode 0. The
  receipt (55beedc3…) lists 656 files; 579 closure objects. The candidate
  validate_receipt() (release.py unchanged) accepted it. result.json
  (0c6fd2dd…) has accepted true at expected_source_commit 64a77603….
- Scope: a synthetic request; no statement, controller admission, signature,
  workflow identity check or deployment. Not an EXIT result.
- Disclosed limits for approval: hosted image version and kernel are recorded,
  not pinned. setup-python 3.10.11 is pinned by action commit and version, not
  by archive hash; context() checks the interpreter version. The pip command
  runs through a macOS-path symlink to reproduce the approved bin/idna bytes.
  The implementation lock field contract_approval_commit still names the
  original contract approval 097431cf…. Three admins can push to main and
  dispatch (U091).
- Impact: all required dry-run checks pass. The candidate awaits exact-byte
  approval. Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: the user approves or rejects the exact set (diff 5593a720…, lock
  f9f09a2f…, 10 file hashes). Separate authorization is still required for the
  real dispatch, public signing and deployment.

## U096 — Trust-boundary review of the 10-file candidate: two items fail on live state

- References: U091, U092, U095; proposals/provenance-hosted/approval-manifest.json
  (43878f45…); proposals/provenance-decision.md; results/stage9/trust-review-0001/.
- Request: the user asked for a read-only review of five items before approval.
  No candidate byte was changed.
- Item 1 FAIL: contract_approval_commit is 097431cf…, the public commit of the
  original contract approval (protocol 2784bdd0…, policy 9e27f627…, spec.lock
  43610d81…). No code reads it (context() and repository_identity() read only
  files). The candidate replaces all three contract files but keeps the field,
  so the lock would name an approval of contract bytes it does not use.
- Item 2 PASS: the hosted run linked the macOS path to
  /opt/hostedtoolcache/Python/3.10.11/x64/bin/python3, the interpreter that
  context() checked first (hosted_setup.py:95). Only one pip process used it
  (line 59; --require-hashes, --no-deps, --only-binary, requirements from the
  verified upstream commit). Its 45 output files are checked against the lock
  at hosted_setup.py:64 and producer.py:144 and are mounted read-only into the
  proof container (producer.py:163). The link is not a proof input.
- Item 3 FAIL (live state): inside the applied candidate the bindings agree
  (policy, protocol text, spec.lock, implementation lock over 62 files, both
  workflow conditions, producer.workflow(), and common.signature() passing
  identity, issuer, repository, ref, trigger and the request commit to Cosign).
  But GitHub now reports the repository as mack-dot/forge, id 1434789853, owner
  id 235131950, type User; superpowermentors-1/forge returns HTTP 301. main is
  still 27e6044b…, so the transfer back happened after that push. The candidate
  names superpowermentors-1/forge and owner 235148649, so it would fail closed.
  The installed policy (mack-dot/forge, 235131950) matches the live owner again.
  The locked file proposals/refund-decision.md names mack-dot as history only.
- Item 4 FAIL: the contract states only "GitHub account/workflow controls"; no
  access set is named. The live repository now has one collaborator (mack-dot,
  admin), not three. main has no effective rules (rules endpoint returns []),
  no branch protection (HTTP 404), and ruleset "mack" matches no branch. Fork
  pull-request approval is first_time_contributors. Acceptance soundness rests
  on the verifier's exact-commit and lock check, not on branch rules.
- Item 5 PASS: all 10 candidate files equal the manifest hashes; the diff hash
  equals 5593a720…; the installed base files equal the manifest old hashes; the
  manifest and diff published at 27e6044b… equal the local bytes.
- Impact: the candidate must not be approved as is. Stage 9 remains CURRENT.
  All six EXITs are NOT RUN. end_to_end=false.
- Next check: the user states the final owner. Then generate one new approval
  set (identity, contract_approval_commit, explicit access assumption) and rerun
  the local checks and the hosted dry run.

## U097 — Owner stays mack-dot; v2 implementation-only candidate; GitHub hardening applied

- References: U096; proposals/provenance-hosted-v2/ (approval-manifest.json
  d37d8327…, build_candidate.py d7d428dc…, dry-run.yml 74d1836b…);
  proposals/github-ruleset/; results/stage9/rebase-mack-dot-0001/,
  hosted-candidate-v2-0001/, github-settings-0001/.
- Decision: the user said "yes i moved it back to mack-dot" and "Keep
  `mack-dot/forge` as the final canonical repository". They asked for an
  implementation-only approval set with no organization migration and no policy
  2.0.0. U091–U095's organization candidate (v1) is superseded and kept as
  history.
- Observed (contract audit, contract-audit.txt): commit 097431cf… exists in
  mack-dot/forge. It publishes the proposal files, not the spec/ paths, so a
  raw fetch of spec/provenance/protocol.md at that commit returned 404 (first
  attempt, kept as a failure). The published manifest (92c56b5d…) and patch
  (ebbbeb7e…) match the decision record. Protocol, policy and spec.lock are
  byte-equal across the published proposal, the installed files and main. The
  installed lock binds them and names contract_approval_commit 097431cf…. The
  policy identity matches live GitHub (mack-dot/forge, 1434789853, owner
  235131950, User, public). U096 item 1 is resolved: the reference is valid.
- v2 candidate (7 files, contract unchanged): runtime.json and hosted_setup.py
  byte-equal to v1; producer.py, preflight.py and both workflows equal v1 except
  the four organization edits (workflow() and the producer-run URL keep
  mack-dot/forge). Diff 39c6c3d7…, lock 30880e08….
- Observed (scratch): git apply --check and git apply 0; 7 of 7 files match;
  contract files unchanged after apply; py_compile 0; workflow conditions name
  mack-dot/forge; context(30880e08…) 0 over 62 files; context(9b10a237…)
  rejected UNAPPROVED_IMPLEMENTATION. Controller package with a freshly created
  builder: exit 0, 14 commands (builder-present 1 as expected, others 0),
  config f584305022f2e811…, descriptor identical to v1 (22f80a1b…).
- Settings (the user said "i want to follow the reccomendations"): private
  vulnerability reporting, Dependabot alerts, secret scanning and push
  protection enabled; fork pull-request workflow approval set to
  all_external_contributors; sha_pinning_required true (all 32 action uses were
  already SHA-pinned). Each command returned 0 and read back as set. Default
  workflow token stays read; workflows cannot approve pull requests.
- Not yet applied: the protect-main ruleset (it blocks direct pushes, so it
  follows this push) and deletion of the inert ruleset 25915179.
- Contributor readiness (started, then paused for this rebase): the clean-clone
  quickstart passed (gate accepted impl/Ledger.dfy, exit 0; rejected all four
  planted bugs, exit 1; evidence byte-identical to evidence.json ed015ad9…).
  It ran on the maintainer's host in a new directory, not on a clean machine.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: v2 hosted dry run; then the user's exact-byte approval.

## U098 — Contributor readiness: docs, license, settings and issues

- References: U097; docs/contributor-readiness.md; results/contributor-readiness/.
- Scope note: this is documentation and onboarding work requested by the user.
  It is not a stage execution and changes no Stage 9 record, protected file,
  release workflow or lock.
- Decisions (user): Apache-2.0 ("lets do apache 2.0"); copyright holder "we can
  say superpowermentors holds the license" (exact legal name unconfirmed);
  follow the recommendations; "def post them" (issues).
- Observed: quickstart in a fresh clone (quickstart-test-0002): clone,
  download, checksum, unzip, venv, pip each 0; gate on impl/Ledger.dfy 0
  (ACCEPTED C1–C5); gate on bugs/off_by_one.dfy 1 (VERIFICATION_REJECTED C4);
  scripts/exit_stage_1.py --case planted-bugs 0; evidence byte-identical to
  evidence.json (ed015ad9…). A helper's earlier run also rejected
  retry_double, self_transfer and sneaky_assume with exit 1, and reported doc
  gaps (no download command, host-specific checksum manifest, undocumented
  output path rule, raw ValueError for an --evidence path outside the repo).
- Observed: ruleset protect-main created (id 26065125, exit 0); inert ruleset
  25915179 deleted (exit 0); effective rules on main read back as deletion,
  non_fast_forward, required_linear_history, pull_request. Label "proposal"
  created; issues #6–#13 created (exit 0 each).
- Observed (audit): id-token: write only in provenance.yml (sign job) and
  provenance-negative.yml, both workflow_dispatch only. proof-gate.yml is the
  only pull-request trigger (pull_request_target); its check job is
  contents: read with candidate as data and persist-credentials false; its
  report job (pull-requests and statuses write) runs base code. No secrets,
  variables, environments, deploy keys or webhooks; one collaborator.
- Uncertainty: Linux quickstart, the TypeScript demo and a truly clean machine
  are not tested; hostile-input resource exhaustion in the PR gate is not
  audited; the NOTICE legal name is unconfirmed; one-person review only.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U099 — PR gate rejected the first contributor PR for protected .github files

- References: U098; results/contributor-readiness/pr14-gate-0001/.
- Observed: PR #14 at 33d913d4… triggered proof-gate run 40743715513. gh run
  watch --exit-status returned 1. The verify job failed at "Check exact PR
  revisions"; the report job succeeded and posted "Forge: rejected", gate exit
  1, C1–C5 not established, with UNAPPROVED_PROTECTED_CHANGE for
  .github/CODEOWNERS, four issue templates and the PR template ("approval of
  exact spec text is required; PR labels do not authorize it").
- Observed (code): gate/incremental.py protects gate, policy, spec, toolchain,
  schemas and .github, plus spec.lock and AGENTS.md. gate/approval.py accepts
  only approved spec text. The rejection is correct behavior, not a defect.
- Inference: any owner-approved change under .github/, toolchain/ or schemas/
  (including the Stage 9 v2 workflows) will show this rejection on its PR.
- Action: the .github files move to a separate PR for exact-byte approval;
  PR #14 keeps only unprotected files. CONTRIBUTING.md and the readiness report
  now state this. No gate behavior was changed.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U100 — Copyright holder: owner's personal project

- References: U098; NOTICE; proposals/license.md.
- Decision: asked about the copyright holder, the user said "theoretically i
  own it but i did make some of it on company time idk", then "just treat it as
  my project tis is differnt than my engineerin loop i made at spm". NOTICE now
  names mack-dot (GitHub handle; legal name not given) and Forge contributors,
  instead of "Superpower Mentors".
- Advice given, not a legal finding: employer ownership can depend on the
  employment agreement and local law for work done on company time; the user
  was advised to check the agreement and keep Forge work off company time.
- Impact: none on Stage 9. All six EXITs are NOT RUN. end_to_end=false.

## U101 — Repository private; copyright treated as SPM's; license and releases on hold

- References: U098, U100; PR #14, PR #15.
- Decision: after outside advice on employee-invention ownership, the user made
  the repository private and said "lets just say spm owns the license for now i
  love the company and dont wanna start anyhting". This supersedes U100's
  personal-project holder. Read as: SPM is treated as the copyright holder; no
  open-source license is granted. Only SPM could grant one.
- Observed: GitHub reports visibility private; an anonymous API request returns
  HTTP 404. The rules endpoint for main returns HTTP 403 ("Upgrade to GitHub Pro
  or make this repository public"), so the protect-main ruleset is not enforced
  while the repository is private on this plan.
- Status: main has no LICENSE file. PR #14 (Apache-2.0 LICENSE, NOTICE naming
  mack-dot) and PR #15 stay unmerged. Issues #6–#13 are no longer public.
- Impact on Stage 9: the installed gate fetches GitHub data without a token
  (U084), so it fails closed while private. Stage 9 is paused: no approval
  request, dispatch or signing. The running v2 dry run (a measurement) is
  recorded locally. All six EXITs are NOT RUN. end_to_end=false.
- Next check: a written agreement with SPM on ownership and licensing; then
  update NOTICE and the license to match.

## U102 — v2 dry run passes on the mack-dot/forge boundary; private repository blocks release verification

- References: U097, U101; proposals/provenance-hosted-v2/;
  results/stage9/hosted-probe-0006/ (key-hashes.txt).
- Observed: run 40743117460 (dry-run v2, head e37ef2c5…) concluded success.
  The first dispatch attempt returned HTTP 404 (workflow not yet registered);
  the second returned 0. The background watcher was stopped when the user asked
  for a read-only audit; the run was then read with gh run view (0) and gh run
  download (0). Artifact sha256:bf75cdaa… (56,513,813 bytes).
- Observed (steps): candidate diff applied; hosted_setup.py 426 s;
  preflight.py 2 s (ubuntu24 20261026.354.1, kernel 7.0.0-1017-azure, recorded);
  package() and replay() 1,561 s. 20 recorded commands: builder-present 1
  (absent, expected), all others 0. Proof container OOMKilled false, ExitCode 0.
  Receipt 656 files, 579 closure objects, accepted by validate_receipt().
  The hosted package descriptor equals controller-descriptor.json exactly
  (config f584305022f2e811…). result.json accepted true at e37ef2c5….
- Scope: synthetic request; no statement, admission, signature or deployment.
  Not an EXIT result.
- Observed blocker: the repository is private (U101). Both the installed gate
  and the v2 candidate fetch GitHub repository metadata and locked files
  without a token (common.fetch), so release verification fails closed while
  private. Hosted runs in a private repository use paid minutes.
- Impact: the v2 candidate passes every required dry-run check. Stage 9 remains
  CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: negative controls for the v2 artifact boundary (U103); then the
  owner's exact-byte approval and the visibility decision.

## U103 — Real negative controls for the v2 artifact-identity boundary

- References: U093, U094, U102; proposals/provenance-hosted-v2/negative_controls.py;
  results/stage9/v2-negative-controls-0001/ (results.json c663a679…).
- Invariant: only a package whose image config, every layer diff_id and the
  ELF bytes at /opt/forge/gcd-selftest.elf equal the approved descriptor and
  the release ELF can pass package identity; only the pinned BuildKit image may
  build it.
- Observed: from a scratch copy with the v2 candidate applied (lock 30880e08…),
  negative_controls.py returned 0. 28 recorded Docker commands returned 0. It
  calls the candidate's own producer.package(), package_identity() (which runs
  image_identity()) and runtime(), with real BuildKit builds and image saves.
- Results: positive control ACCEPTED (pinned builder reproduced the approved
  descriptor). Substituted ELF (one extra byte) under the approved descriptor:
  PACKAGE_CONFIG_IDENTITY. Under a descriptor naming its own config:
  PACKAGE_ROOTFS_BINDING. Under a fully self-consistent descriptor (own config
  and diff_ids): PACKAGE_FILESYSTEM_ELF:substituted. Docker-driver --load build
  without timestamp rewrite: PACKAGE_CONFIG_IDENTITY. Pinned builder name with
  BuildKit v0.24.0 (6eceb897…): BUILDER_VERSION. The substituted builder was
  removed afterwards; runtime() recreates the pinned one when needed.
- Not run: the containerd image-store rejection (IMAGE_STORE) needs a Docker
  Desktop setting change on the controller; hosted-profile negative controls
  (HOSTED_RUNNER, Docker package pins) were not run.
- Scope: package identity only. No signature, admission or deployment.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U104 — v2 approval readiness: REVISE; lock does not bind unlisted executable files (demonstrated)

- References: U096, U102, U103; results/stage9/v2-approval-readiness-0001/.
- Observed (hashes): all 7 v2 files equal the manifest (d37d8327…); the diff
  is 39c6c3d7…; the 6 changed bases equal the installed bytes; the lock
  30880e08… binds the other 6 candidate files.
- Observed (private verifier): the installed repository_identity() against
  mack-dot/forge main e37ef2c5… raised HTTPError 404 (harness exit 3). Release
  verification fails closed while the repository is private; v2 does not change
  common.py.
- Independent review (fresh agent, read-only, no prior verdicts given):
  F1 high — the lock hashes only listed paths; an added module or __pycache__
  .pyc next to the gate runs before context(). F2 high — merging v2 makes the
  sign job runnable on hosted runners; one dispatch creates public Rekor
  entries, and the sign job does not consult the controller. F3 medium — the
  sign job's Python comes from setup-python by version only. F4 medium —
  hosted_setup.py checks only the first Docker key fingerprint. F5 low — some
  identity checks are self-reported; pending requests never expire. No package
  or ELF identity bypass and no fork or other-workflow signer path was found.
- Observed (F1 control, scratch copy with v2): an added gate/provenance/
  argparse.py wrote a marker and stopped preflight.py (exit 1) before context()
  ran; context(30880e08…) with that file present returned 0 (62 locked files;
  the extra file is not locked). Enforcement is missing; the attack succeeds.
  The same gap exists in the installed gate.
- Observed (F3): setup-python's archive python-3.10.11-linux-24.04-x64.tar.gz
  (sha256 3d10b78a…) runs setup.sh, whose line 55 upgrades pip from PyPI
  without a pin; with no network it fails (harness exit 7). Extracting the
  hash-checked archive, LD_LIBRARY_PATH=$P/lib and ensurepip (bundled pip
  23.0.1) worked offline (exit 0) once the runner-image libsqlite3 was present
  (exit 127 without the library path, exit 1 without libsqlite3). python3.10
  sha256 7ad319a3…; system OpenSSL 3.0.13, SQLite and libc stay unpinned.
- Verdict: REVISE. Do not approve the v2 bytes as they are. Do not merge any
  hosted provenance workflow while public signing is unauthorized.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U105 — v3 candidate: U104 corrections built and checked locally

- References: U104; proposals/provenance-hosted-v3/ (build_candidate.py
  3697e68c…, f1_controls.py c38cc3a4…, approval-manifest.json 18b8f59b…);
  results/stage9/v3-local-checks-0001/.
- Candidate (unapplied, 8 files; contract, policy and contract_approval_commit
  unchanged): v2 plus F1 — repository_identity() now refuses to run inside a
  workflow job, uses a verifier-only read-only token
  (FORGE_VERIFIER_GITHUB_TOKEN) for repository metadata, fetches the exact
  commit by git into a verifier-owned store outside the checkout (token only in
  the environment), and source_tree() checks every locked byte and rejects any
  unlocked file under gate/provenance/, any unlocked code file under scripts/ or
  examples/binary/, any __pycache__ path, symlink or submodule; all 33
  scripts/*.py are now locked (89 locked files). F2 — the sign and negative jobs
  run only when repository variable FORGE_SIGNING_AUTHORIZED is 'true'. F3 —
  a step downloads python-3.10.11-linux-24.04-x64.tar.gz, checks sha256
  3d10b78a… before extraction, and runs the bundled ensurepip offline,
  replacing setup-python. F4 — hosted_setup.py also requires the Docker key
  file sha256 1500c1f5…. preflight's producer-run lookup uses the job token
  (FORGE_PRODUCER_GITHUB_TOKEN). Diff 5d3e838f…, lock 0215a316….
- Observed (fresh scratch): git apply --check and git apply 0; 8 of 8 files
  match; syntax ok; workflow conditions as stated; context(0215a316…) 0;
  context(30880e08…) and context(9b10a237…) rejected UNAPPROVED_IMPLEMENTATION.
- Observed (f1_controls.py, exit 0): clean commit ACCEPTED; real commits with
  gate/provenance/argparse.py, scripts/json.py, a scripts/__pycache__ .pyc and
  gate/provenance/extra.json rejected UNLOCKED_EXECUTABLE; a changed
  release.py rejected AUTHENTICATED_WORKFLOW_INPUT; a symlink rejected
  SOURCE_ENTRY_TYPE; GITHUB_ACTIONS=true rejected VERIFIER_NOT_INDEPENDENT; a
  producer token without a verifier token rejected GITHUB_TOKEN_REQUIRED.
- Not run: the authenticated fetch from the private repository and any hosted
  run of the v3 workflows (both need decision B); the Linux key-hash check.
- Remaining limits: the controller's own checkout is trusted; hosted kernel and
  system libraries are recorded, not pinned; pending requests do not expire;
  the certificate's repository ID and run attempt are not checked by the
  verifier; public signing still writes to the public Rekor log.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U106 — v3 leaves pre-verification execution; v3.1 authenticates before any repository code

- References: U104, U105; proposals/provenance-hosted-v31/;
  results/stage9/v3-pre-verification-0001/, v31-controls-0001/.
- Request: the user chose to proceed toward private verification only, with no
  approval of protected changes and no public signing.
- Observed (v3, controller): with a planted gate/provenance/json.py,
  release.py exited 9 and the attacker marker was written; with an
  unchecked-hash __pycache__/common.cpython-310.pyc (common.py unchanged), exit
  9, marker written; with PYTHONPATH set to a directory holding argparse.py,
  exit 9, marker written. sitecustomize.py beside the script did not run.
  v3 source_tree() accepted a commit whose implementation.lock was forged.
  F1 is therefore unresolved in v3 (controller and producer); v3 is superseded.
- v3.1 (unapplied, 9 files, diff d24ff942…, lock 6f3aafe6…, 90 locked files):
  new gate/provenance/bootstrap.py, stdlib only, refuses to run without
  -I -S -B, checks the lock hash and the exact executable file set (no unlocked
  files, __pycache__, symlinks), and launches only locked scripts with
  PYTHON* variables removed and an empty bytecode cache. Each workflow job
  first checks bootstrap.py's bytes against the lock with inline Python from the
  workflow file, then routes every repository script through bootstrap.py.
  The verifier requires the commit's implementation.lock to equal its own,
  uses a fresh Git store per verification, and turns HTTP errors into
  GITHUB_HTTP_STATUS rejections.
- Observed (v3.1, fresh scratch): git apply 0; 9 of 9 files match; context
  6f3aafe6… 0; v3 and installed locks rejected. v3's f1_controls.py against
  v3.1: exit 0, 9 of 9. controls.py: exit 0, 14 of 14, attacker code executed
  in none (shadow modules, sitecustomize, unchecked-hash bytecode, missing
  isolation flags, tampered bootstrap, forged lock, changed locked file,
  unlocked script, change after an earlier passing check rejected with exit 1;
  PYTHONPATH injection ran release.py --help with exit 0 and no marker; forged
  lock in a candidate commit rejected IMPLEMENTATION_LOCK_AT_COMMIT). Missing,
  empty, newline-injected, spaced and short credentials were rejected
  GITHUB_TOKEN_REQUIRED before any network request.
- Observed (non-signing dry run): check_no_signing.py returned 0
  (NO_SIGNING_PATH) for private-dry-run.yml and 1 for both production v3.1
  workflows (control). The dry run has only contents: read, no secrets, only
  allowlisted pinned actions, and a first step that fails if an OIDC request URL
  exists. Not pushed or dispatched.
- Remaining pre-verification trust: the runner image, checkout action, bash,
  curl, sha256sum and tar before the hash-checked Python; system libraries;
  the controller's interpreter and operator command; a local-attacker race
  between a bootstrap check and exec; the unlocked dry-run harness files.
- Not run (need the user's bounded authorization): authenticated metadata and
  git fetch with a real verifier credential; invalid (HTTP 401) and
  under-scoped tokens; repository identity substitution against live GitHub;
  the hosted dry run.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U107 — B preparation: package, receipt, bootstrap and isolation evidence; B1 authorized

- References: U106; results/stage9/b-prep-0001/; proposals/provenance-hosted-v31/.
- Observed (local, v3.1 code): negative_controls.py returned 0; 29 commands
  (builder-present 1, expected; others 0); positive control ACCEPTED and 5
  attacks rejected exactly as in U103; results.json c663a679… is byte-identical
  to the v2 run. validate_receipt() on the hosted v2 receipt (run 40743117460):
  ACCEPTED; with one dependency byte flipped: PROOF_RECEIPT_BYTES; with another
  challenge: STALE_PROOF_RECEIPT.
- Observed (local Linux container, hash-checked Python archive, no network):
  the workflow's inline check exited 0 and loaded 48 modules, all from the
  archive; bootstrap.py --check exited 0 (BOOTSTRAP_VERIFIED) with 78 modules,
  all from the archive; with a planted json.py in gate/provenance and the working
  directory, bootstrap exited 1 and the planted code did not run.
- Observed (isolation): .github/workflows/stage9-private-dry-run-v31.yml
  (b415d911…) equals the reviewed source; check_no_signing.py returned 0; no
  job-level uses, environment or secrets. references; actions: checkout and
  upload-artifact pinned by SHA. Only stage4-exits.yml and
  toolchain-inventory.yml run on push to main, each with path filters. GitHub's
  Dependency Graph runs at 18:05Z and 18:42Z followed settings changes.
- Observed (B3 wrapper, b3_verify.sh): the pre-token path passed the inline and
  bootstrap checks and stopped with exit 3 for a nonexistent Keychain item,
  before any network request. No real credential was used.
- Authorization: the user authorized B1 only, if the package controls passed,
  the manifest was exact and no signing, publication, release or privileged
  workflow could be triggered. B2, B3, v3.1 installation, public signing and any
  IP or licensing decision remain unauthorized. The test branch is not pushed.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U108 — B1 pushed: exact reviewed tree on main; no workflow activity

- References: U107; results/stage9/b-prep-0001/b1-publication-manifest.json
  (9cd45a9f…); results/stage9/b1-push-0001/.
- Observed (pre-push): remote main e37ef2c5…; the manifest tree
  32bfb2ddbdab146b4b8493fe94e8708c91b4adbf has 1,317 added or modified files
  (21.2 MB, largest 4.2 MB), no deletions, no protected paths, one .github file
  (stage9-private-dry-run-v31.yml), none of the PR #14 or #15 files, no
  matching push-trigger paths, and no token or key patterns. Three record files
  named package.json are Forge descriptors, not npm manifests.
- Observed (push): git commit-tree built 993bee7bf8acb5d1e444b6a245c36272e193d4f6
  from that exact tree with parent e37ef2c5…, author and committer
  mack-dot <235131950+mack-dot@users.noreply.github.com> (chosen instead of the
  SPM address because of the open ownership question). The first git push
  returned exit 1; its error line was not captured. The second push of the same
  commit succeeded (e37ef2c..993bee7). The remote reported 10 low-severity
  Dependabot alerts on the default branch.
- Observed (post-push): main is 993bee7… with tree 32bfb2dd… (equal to the
  reviewed tree). The compare API lists 300 files (its limit) and one .github
  change: the added workflow. The workflow is registered (id 399919898, state
  active) and was not dispatched. No workflow run was created for 993bee7….
- Not done: the test branch, B2, B3, v3.1 installation, signing.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U109 — B2 private dry run: trust steps pass; hosted_setup.py runs out of disk

- References: U107, U108; results/stage9/b2-dry-run-0001/.
- Authorization: the user replied "approve" to the B2 request (exactly one
  dispatch). B3, v3.1 installation and signing remain unauthorized.
- Observed: main was 993bee7b… and no run was in progress. gh workflow run
  returned 0; run 40771238211 (workflow_dispatch, head 993bee7b…, "Forge Stage 9
  private dry run v3.1 (no signing)"). No other workflow run was created during
  or after it. The watcher saw completion after 246 s; no cancellation.
- Observed (permissions): the job log lists GITHUB_TOKEN permissions
  Contents: read and Metadata: read only. Runner image ubuntu-24.04
  20261025.353.1.
- Observed (steps): the OIDC-absence check, checkout, candidate apply,
  hash-checked Python archive and checkout authentication (inline check and
  bootstrap --check) all succeeded. hosted_setup.py through the bootstrap
  failed after 225 s; preflight and the package/replay step were skipped. The
  records show 16 commands with exit 0 (Docker key, apt, pinned Docker install,
  upstream fetch, pip pin, macOS-path link, 45 Python packages, seed ownership),
  then docker pull of the checker image exit 1: "failed to register layer: …
  no space left on device".
- Artifact: forge-stage9-private-dry-run-v31-40771238211, sha256:9a140a6d…,
  18,633 bytes.
- Inference (not measured): earlier probes ran while the repository was public
  and saw 91.9 GB free; this private run's free space was not recorded. Private
  repositories may receive smaller standard runners (fewer CPUs, less memory
  and disk). The proof container needs 4 GiB memory and the setup needs roughly
  25 GB of disk.
- Impact: the trust path up to repository code is demonstrated on a hosted
  private runner; the proof path is not. Stage 9 remains CURRENT. All six EXITs
  are NOT RUN. end_to_end=false.
- Next check: record disk, memory and CPUs first, reclaim unused preinstalled
  toolchains on the disposable runner, and fail explicitly when space is too
  small; then one more authorized dispatch.

## U110 — Local Docker cleanup; v3.2 adds the runner disk fix, checked locally

- References: U109; results/stage9/docker-cleanup-0001/, v32-local-checks-0001/;
  proposals/provenance-hosted-v32/.
- Cleanup (user: "yes" to the listed Forge leftovers): before deletion, all 7
  target containers were in state created, never started, from Forge package
  images f584305022f2/f15f5bd4ef7c; no other container used the target
  images; moby/buildkit v0.24.0 was f618f93ec6d0 (digest 6eceb897…). docker rm
  of the 7 containers returned 0; docker rmi of f15f5bd4ef7c, f584305022f2,
  3a3b43655444, 3ab45eec8599, b996c09e7ad6, dfb0f1161801, f618f93ec6d0 and
  d9b8c34d61a9 (ubuntu:24.04) returned 0 (13 entries deleted). Images went from
  5.749 GB to 5.46 GB. Kept: the checker image, BuildKit v0.25.1, every volume
  (including forge-stage7-upstream-bf6a65114ed2, 11.32 GB) and all non-Forge
  images and containers. Local cleanup does not affect hosted runners.
- v3.2 (unapplied, 9 files, diff 993ebd23…, lock be23ec85…): v3.1 plus a proof
  job step that records disk, memory and CPUs and removes unused preinstalled
  toolchains and images on the disposable runner, and a hosted_setup.py check
  that records free space (disk.json) and rejects DISK_SPACE below 35 GB before
  image pulls. A matching non-signing dry run is in
  proposals/provenance-hosted-v32/private-dry-run.yml.
- Observed (local): check_no_signing.py 0 for the v3.2 dry run and 1 for the
  production workflow; v3.2 applied in a fresh scratch copy with 9 of 9 files
  matching; context(be23ec85…) 0; v3.1 and installed locks rejected;
  bootstrap --check 0; f1_controls.py 0 (9 of 9); controls.py 0 (14 of 14,
  attacker code executed in none).
- Not tested: the disk step and DISK_SPACE check (hosted runner only).
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U111 — Repository public again (user); B1′ authorized

- References: U101, U110.
- Decision: the user replied "approve and start i made it public so its easier
  to get thru the research for now". Read as: B1′ (push the v3.2 proposal files,
  the v3.2 non-signing dry-run workflow and records to main) is authorized; the
  user changed the repository to public. B2′, B3, v3.x installation and public
  signing remain unauthorized. No licensing or ownership decision is implied.
- Effect: hosted runs are free and run on public-repository runners; the
  installed verifier's unauthenticated GitHub reads work again.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U112 — B1′: direct push refused by the restored ruleset; PR #16 opened

- References: U108, U111; results/stage9/b1prime-0001/.
- Observed (manifest): base main 993bee7b…; tree
  3822a938257d0510ed0268fe5a16facf74eaf61f; 505 files (9.7 MB); no deletions;
  no protected paths; one .github file (stage9-private-dry-run-v32.yml, equal to
  the reviewed source, check_no_signing.py 0); no PR #14 or #15 files; no
  push-trigger matches; only unsure.md modified; no token or key patterns.
- Observed (push 1): git commit-tree built e3c51767250d1b09100d06b6147a573a3f7a2a62
  (tree verified). git push exit 1: "src refspec …efs/heads/main does not
  match any". Cause: in zsh, $C:refs was read as the :r modifier. This also
  explains the uncaptured first push failure in U108.
- Observed (push 2, braced refspec): exit 1, "push declined due to repository
  rule violations". With the repository public, the protect-main ruleset is
  enforced again; main is unchanged at 993bee7b….
- Observed: the same commit was pushed to branch stage9/b1prime-v32 (exit 0) and
  PR #16 was opened (exit 0). The proof gate is expected to report
  UNAPPROVED_PROTECTED_CHANGE for the .github file. A GitHub Dependency Graph
  run started at 21:38:42Z, after the user's visibility change and before any
  B1′ action.
- Open: the owner merges PR #16 (squash keeps the tree). B2′ is not authorized.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U113 — B1′ complete: PR #16 merged by the owner with the reviewed tree

- References: U112; results/stage9/b1prime-0001/.
- Observed: the user ran the merge ("okay i ran it"). PR #16 state MERGED at
  2026-10-28T21:42:34Z by mack-dot; merge commit
  3670d688f90acb9c00b1af36fa4cdc36d1bdb361 with one parent 993bee7b… and tree
  3822a938257d0510ed0268fe5a16facf74eaf61f, equal to the reviewed manifest tree.
- Observed: workflow stage9-private-dry-run-v32.yml registered (id 399937849,
  state active), not dispatched. No workflow run was created by the merge. The
  proof gate on PR #16 (run 40773876527) concluded failure; the expected cause
  is the protected .github input.
- Not done: B2′, B3, v3.x installation, signing.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U114 — B2′: v3.2 dry run on a hosted runner passes end to end without signing

- References: U109, U113; results/stage9/b2prime-dry-run-0001/
  (result.json a5d607de…, receipt.json 1fe9c104…).
- Authorization: the user replied "approve" to the B2′ request (one dispatch).
- Observed: main was 3670d688… with no run in progress; gh workflow run 0; run
  40787574980 (workflow_dispatch, head 3670d688…). No other workflow run was
  created; the watcher saw completion after 1,713 s. Conclusion success. Job
  token permissions: Contents: read, Metadata: read. Artifact sha256:c35915a1…
  (56,513,517 bytes). The repository was public at the time (U111), so this
  ran on a public-repository runner.
- Observed (steps): OIDC-absence check, checkout, candidate apply,
  hash-checked Python, checkout authentication; disk step 155 s (/ free
  91,306,496,000 bytes before, 123,193,401,344 after); hosted_setup.py 386 s
  (23 commands; only the expected volume-absent probe non-zero; disk.json free
  111,798,132,736 bytes ≥ 35,000,000,000); preflight 1 s (ubuntu24
  20261026.354.1, kernel 7.0.0-1017-azure); package() and replay() 1,137 s.
- Observed (result): accepted true at 3670d688…; 20 commands, only the expected
  builder-absent probe non-zero; the hosted package descriptor equals the Mac
  controller descriptor (f584305022f2e811…); proof container OOMKilled false,
  ExitCode 0; receipt 656 files and 579 closure objects accepted by
  validate_receipt().
- Scope: synthetic request; no statement, admission, signature, release or
  deployment. Not an EXIT result. The authenticated verifier path (B3) is not
  run.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U115 — B3 preparation: test branch pushed and verified; no-credential verifier tests

- References: U114; results/stage9/b3-0001/; proposals/provenance-hosted-v32/b3_verify.sh.
- Authorization: the user approved B3 with constraints: push only
  test/v32-candidate, verify it, review the wrapper and its code independently,
  test the public path without a token first, then the owner runs the
  authenticated test; no signing, release, licensing change or installation.
- Observed: branch test/v32-candidate =
  edb729a8bea278a77a1bd33451859958a4b7b3e4 (tree 1b77abd0…, parent main
  3670d688…), built from main plus the 9 v3.2 candidate blobs; branch push
  exit 0. A fresh unauthenticated public clone showed HEAD edb729a8…, main still
  3670d688…, exactly 9 differing paths equal to the v3.2 manifest set, each
  with the manifest SHA-256. No workflow run was created by the branch push.
- Observed (no credential): the installed verifier (lock 9b10a237…), with no
  token, fetched 61 locked files from public main 3670d688… and ACCEPTED (exit
  0). In the branch clone, bootstrap --check returned 0; the v3.2 verifier with
  no token rejected GITHUB_TOKEN_REQUIRED and wrote no HTTP record; v3.2
  source_tree() ACCEPTED commit edb729a8… and rejected main 3670d688… with
  IMPLEMENTATION_LOCK_AT_COMMIT.
- Observed (wrapper): bash -n 0; with a nonexistent Keychain item the wrapper
  passed the inline and bootstrap checks and exited 3 before any network
  request; with an existing output directory it exited 2.
- Limit: while the repository is public, GitHub lets any valid token read it,
  so an under-scoped token cannot fail; the wrapper reports that case as
  NOT_DISCRIMINATING. Same-user processes can read another process's
  environment on macOS; the owner should run the wrapper while no other agent
  session is active.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U116 — B3 wrapper: independent review found credential and validity gaps; fixed in the wrapper

- References: U115; proposals/provenance-hosted-v32/b3_verify.sh (sha256 69d2bd667955ff183d1929fe048fd493dd3129bc1326d45a33f9b2ad45544499).
- Independent review (fresh agent, read-only, no prior verdict): high — the
  leak scan passed the token and its base64 form to grep as arguments; medium —
  a grep read error was reported as clean; credential-negative cases stop at
  the API, and on a public repository git fetch needs no token; the "fresh
  store" case did not check freshness; the verifier inherited the owner's shell
  environment (SSL, git and DYLD variables, git config, netrc); low — PATH and
  cwd lookups, Keychain prompt between checks and import, relative OUTPUT,
  stores outside the scan, no scan on interrupt. Verdict: SAFE AFTER FIXES.
- Wrapper fixes: scan patterns go through a pipe (grep -f <(printf …)); any
  grep status other than 1 sets exit 4; the verifier runs in a subshell with
  every exported variable removed, HOME and TMPDIR inside OUTPUT,
  PATH=/usr/bin:/bin:/usr/sbin:/sbin, GIT_CONFIG_GLOBAL=/dev/null,
  GIT_CONFIG_NOSYSTEM=1, GIT_TERMINAL_PROMPT=0 and absolute tool paths;
  credentials are read before the checks; OUTPUT must be absolute and new;
  git stores land inside OUTPUT; the scan also runs on INT/TERM; a new
  repeat-used-a-fresh-store case compares the two store paths. The claim is
  limited to: API identity read with the token, and source bytes matching the
  commit hash.
- Observed (no credential): bash -n 0 (bash 3.2.57); relative OUTPUT exit 2;
  nonexistent Keychain item exit 3; existing OUTPUT exit 2. The scan function
  run alone with a dummy string: clean directory STATUS 0, planted string 4,
  unreadable file 4.
- Remaining (candidate code, protected; v3.3 item): git children inherit
  FORGE_VERIFIER_GITHUB_TOKEN in their environment; same-user processes can
  read process environments on macOS; an under-scoped token cannot fail on a
  public repository.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U117 — B3 runs 1–2 stopped before any request; wrapper v2; owner waives the self-run rule

- References: U115, U116; results/stage9/b3-0001/owner-run-1.txt,
  owner-run-2.txt, wrapper-v2.diff, wrapper-v2-tests.txt.
- Run 1 (owner): exit 3, no Keychain item forge-verifier-readonly.
- Run 2 (owner): exit 1. The Keychain value failed the verifier format check
  [A-Za-z0-9_]{20,255} (gate/provenance/common.py:107), which runs before the
  HTTP request, so no request was made. Then store() raised StopIteration and
  6 cases did not run. Leak scan clean. Which character failed is unknown: the
  agent does not read the credential.
- Wrapper v2 (sha256 6190aa58972361b46e2ebc857e3d1213c5a4c895462598519f9297d444bfeeb3):
  a shell format check after each Keychain read (exit 3, prints only length,
  prefix class and counts); store() returns None, so the fresh-store case fails
  instead of crashing. Dummy Keychain items only (deleted after): malformed
  exit 3; well-formed bogus token exit 5 with all 8 cases run and HTTP 401;
  malformed under-scoped item exit 3.
- Owner waiver, verbatim: "I waive the self-run rule for B3; the agent may run
  the wrapper." Scope: B3 only. Consequence: the token passes through a process
  that the agent session starts; the agent still does not print, store or
  transmit it, and the wrapper output and records are scanned for it. All
  other B3 constraints remain, including review before any run.
- Uncertainty: the independent review of wrapper v2 is not yet reported.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: the review verdict; then B3 run 3 with a new OUTPUT.

## U118 — B3 wrapper v2 reviewed SAFE; run 3 stopped: the Keychain value is not a token

- References: U117; results/stage9/b3-0001/wrapper-v2-review.txt, agent-run-3.txt.
- Independent review of wrapper v2 (sha256 6190aa58…): no high or medium
  findings; verdict SAFE. Five low hardening items (L1–L5) are recorded and not
  applied, so the run used the reviewed bytes. L2 and L5 preconditions were
  checked absent before the run and removed with env -u.
- Run 3 (agent, under the owner waiver): exit 3. The wrapper reports the
  Keychain value as length 68, prefix other, 14 characters outside
  [A-Za-z0-9_], 5 of them blank. A fine-grained token is github_pat_ plus 82
  characters (93); a classic token is ghp_ plus 36 (40). So the item holds
  some other text. No check, request or credential use happened.
- Uncertainty: what the stored text is; the agent does not read it. The
  "outside" count can be inexact (L4); the decision is exact.
- Impact: B3 is not complete. Stage 9 remains CURRENT. All six EXITs are NOT
  RUN. end_to_end=false.
- Next check: the owner stores the bare token; run 4 with a new OUTPUT.

## U119 — A B3 credential was pasted into the agent chat; it is treated as exposed

- References: U117, U118.
- Event (2026-10-28): the owner pasted the new fine-grained token value into
  the agent conversation instead of the Terminal. It is now in the session
  transcript and in model input. This record does not contain it.
- Agent action: did not use, repeat, store or run anything with the pasted
  value. Asked the owner to regenerate the token on GitHub (this invalidates
  the pasted value) and to store the new one through the clipboard command,
  with the order: paste the command into Terminal first, then copy the token,
  then press Enter (copying the command would replace the clipboard).
- Uncertainty: until the owner regenerates or deletes it, the pasted token is
  valid (read-only, mack-dot/forge, expires 2026-11-04).
- Impact: B3 waits for a fresh token. Stage 9 remains CURRENT. All six EXITs
  are NOT RUN. end_to_end=false.
- Next check: the owner confirms regeneration; B3 run 5 with a new OUTPUT.

## U120 — Owner accepts the exposed B3 token; not regenerated

- References: U119.
- Owner decision, verbatim: "just dont push to git all good we chilling".
  The pasted token stays valid (read-only Contents and Metadata, only
  mack-dot/forge, expires 2026-11-04).
- Agent position: the agent still does not use the pasted value and does not
  store it; the owner stores the token in the Keychain. No file in the
  repository or in results contains it (prefix scan, U119).
- Effect on B3 constraint 7 ("no credential in agent-visible output"): breached
  by the paste, not by the wrapper or the procedure. A B3 pass shows the
  wrapper and verifier behavior; it does not show that this token stayed
  private.
- Residual risk: low while the repository is public (the token reads only
  public data); higher if the repository becomes private before 2026-11-04.
- Next check: regenerate the token before any change of the repository to
  private; B3 run 5 after the owner stores the token.

## U121 — B3 passed (run 5): authenticated independent verification of the v3.2 candidate

- References: U115–U120; results/stage9/b3-0001/agent-run-5.txt, run-5-results.jsonl.
- Observed: wrapper v2 (reviewed SAFE) exit 0; 8/8 cases PASS: exact commit
  accepted twice, each with a fresh store; repository identity substitution
  rejected (REPOSITORY_IDENTITY); main rejected (IMPLEMENTATION_LOCK_AT_COMMIT);
  nonexistent commit rejected (COMMAND_FAILED:source-fetch); bogus token
  rejected (HTTP 401, so no anonymous fallback on the API path); no token
  rejected before any request. No credential copy in 687 record files
  (wrapper scan and a separate agent scan).
- Owner constraints, status: 1 branch only, protected main untouched: met
  (U115). 2 branch SHA and manifest: met (U115). 3 review before any run: met
  (U116, U118). 4 public path without a token: met (U115). 5 authenticated
  run, no fallback: met for the API path; git fetch on a public repository
  needs no token, so git authentication is not tested. 6 substituted
  identity, wrong commit, bogus credential: met; stale metadata: covered only
  as a fresh Git store and a live API read, with no injected stale response;
  insufficient permissions: not testable while the repository is public. 7 no
  credential in argv, logs or records: met by the procedure; agent-visible
  output breached once by the owner's paste (U119, U120).
- Not applied: wrapper hardening L1–L5 (U118); v3.3 item, git children
  inherit FORGE_VERIFIER_GITHUB_TOKEN.
- Impact: B3 is complete. v3.2 is not installed. Stage 9 remains CURRENT. All
  six EXITs are NOT RUN. end_to_end=false.
- Next check: separate owner approval for v3.2 installation (diff 993ebd23…,
  lock be23ec85…).

## U122 — Owner approves v3.2 installation; PR from the verified test branch

- References: U114, U115, U121; proposals/provenance-hosted-v32/approval-manifest.json.
- Owner approval, verbatim, in reply to the request for v3.2 installation
  (diff 993ebd23ab4f63426b45fed0093b69531dcabcb8176ae54906f34a3909eb83df,
  lock be23ec85ec2d9652bd1c87f6870c0d7130862af169319af24975b941ac3b5f57):
  "and do it please". Scope: install v3.2 on main through a PR that the owner
  merges. Not included: signing authorization, FORGE_SIGNING_AUTHORIZED,
  releases, PRs #14 and #15, licensing or ownership.
- Method: PR from test/v32-candidate (edb729a8, tree 1b77abd0, parent = main
  3670d688), the exact commit verified in B3. The ruleset requires linear
  history, so the merge is a squash; the check is tree equality.
- Pre-merge state (observed): no repository variables (signing job skipped);
  id-token appears only in provenance.yml and provenance-negative.yml, both
  workflow_dispatch only; proof-gate.yml runs on pull_request_target;
  stage4-exits.yml and toolchain-inventory.yml run on push.
- Impact: until the merge, the installed lock stays 9b10a237. Stage 9 remains
  CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: after the merge, main tree = 1b77abd0, main lock = be23ec85,
  the local verifier accepts main, and no signing run starts.

## U123 — v3.2 installed on main (d260d2a9); signing stays off

- References: U122; results/stage9/v32-install-0001/summary.txt.
- Observed: the owner squash-merged PR #17 pinned to head edb729a8. main =
  d260d2a94aec074f9a43c0a41a5b81b05fce2224, tree 1b77abd0 = the B3-verified
  tree. Lock be23ec85. Fresh clone: inline check 0, bootstrap --check 0;
  source_tree accepts main and rejects the old main with
  IMPLEMENTATION_LOCK_AT_COMMIT. Local copy synced (it equalled the manifest
  old hashes); local check 0 after removing two bytecode caches.
- Proof gate: exit 1, UNAPPROVED_PROTECTED_CHANGE. gate/approval.py can bind
  approval only to exact spec text (spec/LedgerSpec.dfy and spec.lock). So the
  gate cannot approve changes to its own code or workflows; the owner's
  approval for this change exists only in U122 and the admin merge.
- Uncertainty: no machine-checkable approval record binds this installation
  to the owner. A future implementation-approval record (like
  gate/approvals/*.json for spec) would close that; it is protected work and
  needs its own approval.
- Not shown by installation: any signed provenance. FORGE_SIGNING_AUTHORIZED
  is unset; provenance.yml has never run.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: records PR merged by the owner; then a separate signing
  authorization decision.

## U124 — Owner approves a no-signing rehearsal of the installed provenance.yml

- References: U123.
- Owner reply, verbatim, to the proposal of a rehearsal ("Reply 'approve
  rehearsal'"): "do it in the cli yes u can merge them". Read as: run the
  rehearsal through the CLI, and the agent may merge its own PRs.
- Scope: one controller request on the Mac from a fresh clone of main
  (d43f5f4d), one dispatch of provenance.yml on main with the installed lock
  be23ec85. FORGE_SIGNING_AUTHORIZED stays unset, so the sign job must be
  skipped: no OIDC token, no signature, no Rekor entry. Not included: setting
  the variable, signing, releases, PRs #14 and #15.
- Merge permission: the agent's attempt to write .claude/settings.local.json
  was refused by the Claude Code classifier (Self-Modification); the owner
  creates that file. Until then the owner merges.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.
- Next check: the sign job is skipped; the proof job result; the hosted
  package equals the controller package.

## U125 — No-signing rehearsal of the installed provenance.yml passed

- References: U124; results/stage9/rehearsal-0001/.
- Observed: run 40810179164 on main d43f5f4d, conclusion success, 32 min
  (disk 2.2, setup 7.6, package and proof replay 22.3). sign job skipped;
  token Contents read, Metadata read; no OIDC request in the log. Artifact
  forge-stage9-unsigned-40810179164, zip sha256 34b215d3… = GitHub digest.
- Controller-side checks (controller clone at d43f5f4d, lock be23ec85): the
  artifact request equals the controller request and the pending DB row;
  validate_package and validate_receipt (656 files) accept; evidence equals
  expected_canonical; the unsigned statement equals producer.statement for
  these digests. Controls rejected: receipt byte flip (PROOF_RECEIPT_BYTES),
  other request (STALE_PROOF_RECEIPT), ELF byte flip (PACKAGED_ELF_BYTES),
  substituted package descriptor (PACKAGE_DESCRIPTOR_BINDING).
- Limits: the statement is unsigned; no Cosign, Rekor or admission ran. The
  request stays pending; it cannot be reused for signing because a re-run
  has run_attempt 2 (producer.py:224).
- Impact: All six EXITs are NOT RUN. end_to_end=false.

## U126 — Approval integrity: protected merges were admin overrides

- References: U122, U123; proposals/approval-integrity/PROPOSAL.md;
  results/stage9/approval-audit-0001/.
- Observed: the agent's gh is logged in as mack-dot (owner; scopes repo,
  workflow), so every agent PR is owner-authored and cannot be approved by the
  owner. GitHub rule suites record result=bypass for #16, #17, #18; the
  pull_request rule failed ("approval from someone other than the last
  pusher"); #17 has 0 reviews. No CODEOWNERS on main. 993bee7b and e37ef2c5
  were direct pushes. The audit script exits 1; forged-pass and
  missing-record controls produce no false APPROVED.
- Uncertainty: the APPROVED path is untested (no qualifying approval exists).
  Rule-suite retention is limited; archives are needed.
- Next check: identity separation (machine account), then CODEOWNERS by an
  approved PR as the first positive control.

## U127 — Pinned Cosign verifies public bundles; the unsigned EXIT marker is wrong

- References: results/stage9/cosign-offline-0001/; proposals/provenance-v33/exit-harness.diff.
- Observed: cosign-darwin-arm64 v3.1.4 download sha256 9f9b8cd5… = policy pin;
  GitCommit 0e48502c = policy source_commit; installed at .toolchain/stage9/cosign
  (ignored). With Forge's verify-blob-attestation flags on a public cli/cli
  SLSA bundle (Fulcio public-good, Rekor entry): initialize 0, verify 0.
  Controls: wrong identity 1 with `expected SAN value "…", got "…"`; wrong
  blob 1 with the digest marker; emptied signatures 1 with "failed to verify
  log inclusion: transparency log signature does not match", NOT the
  harness marker "exactly one signature is required".
- Impact: EXIT unsigned would end NOT_THE_INTENDED_SECURITY_REJECTION although
  Cosign rejects correctly (D1). The fix is in scripts/ (locked): proposal only.
- Limits: verification only; Cosign signing and Forge's own bundles untested.

## U128 — Independent audit of installed v3.2: code runs before authentication

- References: U106, U107, U125; results/stage9/v32-audit-0001/ (22 checks);
  proposals/provenance-v33/.
- Demonstrated (ubuntu:24.04 emulation, fake OIDC variables, not a hosted
  run): V1 HIGH — provenance.yml:43,105 and provenance-negative.yml:49 run
  `python3 -m ensurepip` with the checkout as cwd before the authentication
  step, so a root ensurepip.py or runpy.py in the commit runs, sees the OIDC
  request variables, and the next step still prints BOOTSTRAP_VERIFIED (c02–c04).
  V2 HIGH — hosted_setup.py:54 runs `sys.executable -m pip` with cwd=ROOT; a
  root pip/ package ran after bootstrap (c05). V3 MEDIUM — bootstrap and
  source_tree inventory only gate/provenance, scripts and examples/binary, so
  they accept the V1/V2 commits (c06). V4 MEDIUM — receipt challenge and
  commit are labels written after the proof (producer.py:200-202); a relabelled
  old receipt was accepted (c11), and release.py:274 claims
  producer_fresh_kernel_receipt_verified. LOW — the verifier guard checks only
  GITHUB_ACTIONS == 'true'; pending requests never expire.
- Agent check: the cited lines are as described (workflow lines 43, 46, 105;
  common.py:81 cwd=ROOT; producer.py:200-202).
- Earlier false-pass risks: controls.py checks exit code without the reason and
  writes bytecode without -B; earlier controls planted files only inside the
  inventoried roots and never ran the pre-authentication step.
- Not tested: a hosted run of V1; real OIDC minting; authenticated identity;
  valid-bundle admission and replay; the full hosted_setup path.
- Impact: signing under v3.2 is unsafe until V1 and V2 are fixed. Stage 9
  remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U129 — Identity separation is not in effect for the agent

- References: U126; proposals/approval-integrity/PROPOSAL.md.
- Owner statement: "The GitHub identity separation has already been handled."
- Permission test (2026-10-29): `gh api user` prints mack-dot (id 235131950);
  repository permissions admin, maintain, push; collaborators: only mack-dot;
  no pending invitation; mackiannii has only public read. .claude/settings.local.json
  does not exist.
- Impact: any PR the agent opens is still owner-authored; approval by review is
  impossible and a merge would again be an OVERRIDE. The governance controls
  that need a separate agent identity cannot run.
- Next check: repeat the test after the owner switches the agent's credential.

## U130 — v3.3 candidate repairs V1–V4, D1, D3; local controls pass

- References: U127, U128; proposals/provenance-hosted-v33/;
  results/stage9/v33-controls-0001/.
- Candidate (not applied): 9 files, lock eb4b93db…, diff 21e1a7a4…; local
  test commit fc0a40d9 (tree 0fc5d98a) on main d43f5f4d.
- Repairs: -I for the three ensurepip steps, both pip children and the
  collector; ROOT_IMPORTABLE rule in bootstrap.py and source_tree; run-name
  carries the challenge, the receipt records run id and attempt, release.verify
  checks the run with the GitHub API (run_identity); the claim label states the
  GitHub execution-integrity assumption; verifier guard on any Actions marker;
  git never gets the token variable; the EXIT harness relaunches through the
  bootstrap and uses a positive re-check instead of error strings.
- Observed: 43/43 controls (exploits reproduced on v3.2 behaviour, refused by
  the candidate with the intended reason, no marker written); 14/14 v3.1 and
  9/9 F1 controls on the candidate.
- Not tested: a hosted run of the candidate; the positive run_identity path
  (needs a v3.3 run with the new run-name); the authenticated token path of
  run_identity (tests used gh api reads); Cosign-backed EXIT flows.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U131 — Re-attack found a D3 bypass in the first v3.3 fix; final candidate passes

- References: U130; results/stage9/v33-audit-0001/, v33-controls-0003/;
  proposals/provenance-hosted-v33/ (diff b432024f…, lock a809f701…).
- Independent re-attack of candidate fc0a40d9 (emulated ubuntu jobs, fake
  OIDC and token values): V1a/V1b/V1c and V2 ran on main and did not run on
  the candidate (Authenticate step exit 1, ROOT_IMPORTABLE); the verifier tree
  rule rejected every importable root plant; run_identity rejected the real
  rehearsal and dry-run records and 11 synthetic mismatches.
- Found: D3 HIGH — the first fix imported argparse and others before its
  relaunch, so a planted scripts/argparse.py ran on the controller host; -E -s
  -B skipped the relaunch. D1 — the unsigned fixture changed payload and
  signatures together; SIGNATURE_REJECTED also covers malformed input.
- Fixed: the harness refuses at its first statement (only sys, built in)
  unless the bootstrap started it (flags plus the bootstrap's pycache prefix);
  the EXIT commands in ROADMAP now launch through the bootstrap; the unsigned
  fixture removes only the signatures; source_tree also rejects a root
  directory with an importable name.
- Observed: 48/48 controls on final candidate 405b453a (tree ae535888), with
  the D3 exploit reproduced on v3.2 and refused for a direct run, an -E -s -B
  run, a bootstrap run with the planted module, a wrong lock and a changed
  locked file; 14/14 v3.1 and 9/9 F1 controls.
- Residual: run_identity does not tie the signing certificate's run to the
  receipt run; the guard can be avoided by an operator who unsets the
  variables; a gitlink or namespace directory at the root passes both checks
  (not importable as a regular module); hosted behaviour and the positive
  run_identity path are untested.
- Impact: Stage 9 remains CURRENT. All six EXITs are NOT RUN. end_to_end=false.

## U132 — Owner approves a no-signing rehearsal of installed v3.3

- References: U131; ROADMAP v3.3 rows.
- Owner reply, verbatim, to "Reply 'approve rehearsal'": "approve".
- Scope: one controller request from a fresh clone of main 19c4896b (lock
  a809f701…) and one dispatch of provenance.yml on main with
  FORGE_SIGNING_AUTHORIZED unset. Not included: setting the variable, signing,
  Rekor entries, the negative workflow, EXITs, pushes.
- Next check: the run name equals "forge-stage9 <challenge>"; the sign job is
  skipped; the receipt records this run; run_identity accepts it; relabel
  controls are rejected.

## U133 — Approval-integrity work stopped at the identity boundary

- References: U126, U129; results/stage9/identity-check-0002/identity.txt.
- Owner instruction: "First verify the active GitHub identity and effective
  permissions. If the agent can still act as the owner, stop at that boundary."
- Observed 2026-10-29T05:01Z: gh api user = mack-dot (id 235131950); active
  token scopes gist, read:org, repo, workflow; repository permissions admin,
  maintain, push; collaborators: only mack-dot (admin); 0 pending invitations;
  no CODEOWNERS on main; ruleset bypass actor RepositoryRole 5 (admin, PR
  mode). A second account (mackiannii) is also in the agent's keyring.
- Decision: stopped. No CODEOWNERS PR, ruleset change, approval transition or
  ratification was attempted.
- Next check: after the owner's switch, gh api user must print a non-owner
  account with push and without admin, and no owner token may remain in the
  agent's keyring.

## U134 — v3.3 runs on a hosted runner; the run binding holds on a real run

- References: U131, U132; results/stage9/rehearsal-0002/.
- Observed: run 40820302652 (main 19c4896b, lock a809f701) success; the run
  name recorded at dispatch is "forge-stage9 " + the request challenge; sign
  skipped; token Contents and Metadata read only. Controller checks 13/13
  with the installed code: artifact digest, request (pending row), package,
  receipt with execution {run_id 40820302652, attempt 1}, run_identity on the
  real GitHub run record, evidence, statement. Rejected: relabel to a new
  challenge (PROOF_RUN_IDENTITY), receipt naming the v3.2 run
  (PROOF_RUN_IDENTITY), re-run attempt (PROOF_RECEIPT_EXECUTION), other request
  (STALE_PROOF_RECEIPT), byte flip (PROOF_RECEIPT_BYTES).
- Limits: run records were read with gh as the agent account, not with the
  verifier token; no signature; freshness inside the run assumes GitHub ran the
  locked workflow.
- Impact: All six EXITs are NOT RUN. end_to_end=false.

## U135 — Identity separation applied; approval controls on the real ruleset

- References: U133; results/stage9/approval-experiment-0001/.
- Owner approval: "do it i approve"; chosen agent account: mackiannii.
- Observed: mack-dot invited mackiannii (write); mackiannii accepted; gh
  logged out mack-dot. Agent identity mackiannii (id 143109898): pull, push,
  triage, no admin. Rule-suite records are admin-only (404 for the agent), so
  the audit now infers status for non-admin readers and marks it inferred.
- Controls (PR #21, CODEOWNERS, authored by mackiannii): self-approval refused
  (exit 1, "Can not approve your own pull request"); merge without approval
  refused (exit 1); admin-bypass merge NOT RUN (Claude Code classifier); direct
  push of a policy/ file to main refused (GH013), main unchanged.
- Historical audit as the agent: #16–#20 OVERRIDE (inferred), unchanged.
- Residual: the agent runs as the same macOS user as the owner; Claude in
  Chrome can reach the owner's browser session until the owner blocks
  github.com there.

## U136 — First human-approved transition on main (PR #21, CODEOWNERS)

- References: U133, U135; results/stage9/approval-experiment-0001/ (files 10–18).
- Observed: the owner approved commit A 88ad9c72 (review 5698193782). The agent
  (mackiannii) pushed B 52cbf8cb, which added @mackiannii as a code owner;
  GitHub dismissed review 5698193782 at B (dismissal_commit_id 52cbf8cb) and
  the PR became BLOCKED, REVIEW_REQUIRED. The agent pushed C 2e3587f8, which
  reverts B (tree 0f757d83 = tree of A; CODEOWNERS sha256 d5f98954…). A merge
  of C with only the stale approval was refused (gh pr merge exit 1). The owner
  approved C (review 5699085293). The agent merged with --squash
  --match-head-commit C (exit 0): main aac837a0, merged by mackiannii (Write,
  no admin), tree 0f757d83 = approved head tree, parent 19c4896b.
- Audit (agent, rule suites unreadable): aac837a0 APPROVED,
  INFERRED_NON_ADMIN_MERGE_CANNOT_BYPASS. #16–#20 OVERRIDE (inferred) and
  993bee7b UNAPPROVED, unchanged. Audit exit 1 (history not all APPROVED).
- Limits: the APPROVED status is inferred, not read from a rule-suite record
  (admin-only); the owner can confirm "pass" in Rule Insights. The stale-merge
  refusal may be the gh client's own mergeStateStatus check; the REST merge
  control was NOT RUN (Claude Code classifier). GitHub tells accounts apart,
  not people; the agent runs as the same macOS user as the owner. The owner
  asked the agent to submit the approval through the owner's session; the
  agent declined (file 11).
- Mismatch: the local .github/CODEOWNERS (path-scoped, sha256 2e937943…) is
  not the file on main (`*  @mack-dot`, d5f98954…). Not changed.
- Impact: All six EXITs are NOT RUN. end_to_end=false. CODEOWNERS on main now
  requires the owner's review for every later PR, including ratification of
  the OVERRIDE commits and any release-admission change.
- Next check: owner ratification procedure for #16–#20; release.verify refuses
  a lock not introduced by an APPROVED or ratified merge (protected, needs
  approval).

## U137 — Ratification procedure and approved-lineage admission prepared (not applied)

- References: U136; proposals/approval-integrity/RATIFICATION.md;
  results/stage9/approval-experiment-0001/ files 19–20;
  results/stage9/lineage-controls-0001/, -0002/.
- Owner wrote "done" for Rule Insights, the Claude in Chrome block and the B3
  token revocation. Owner attestation only; the agent verified none of them
  (rule suites still 404 for the agent).
- Full history audit as the agent (42 commits): 1 APPROVED (#21); 6 OVERRIDE,
  inferred (#4, #16–#20); 35 UNAPPROVED direct pushes. Statuses unchanged.
  The inference assumes the current ruleset existed at each merge; for #4 that
  is unverified.
- Prepared: ratification record 0001 (baseline 19c4896b, tree 67829210…, lock
  a809f701…, 41 covered commits; sha256 facf9cd5…) and the v3.4 admission
  change (approved_lineage in common.py, called by release.verify; new lock
  9bf8f905…, diff f31a1bad…). Controls on the real history: 17/17 with
  lineage.py and 17/17 with the candidate common.py. Real refusals: main
  aac837a0 today (19c4896b has no owner approval) and direct push 993bee7b.
  Simulated (in memory): the draft record admits aac837a0; wrong tree, older
  baseline, off-main baseline, override source, duplicate key, extra field,
  conflicting records, removed, stale, agent, late or superseded approval,
  tree mismatch and wrong base branch are refused.
- Limits: full v3.4 control suite not run; verifier-token fetch not exercised;
  GitHub tells accounts apart, not people.
- Impact: All six EXITs are NOT RUN. end_to_end=false. Nothing pushed.
- Next check: owner approval of the ratification PR (one file), then of the
  v3.4 install PR; each is a separate authorization.

## U138 — Owner identity returned to the agent's gh; ratification PR #22 opened as the owner

- References: U135, U137; results/stage9/ratification-pr-0001/.
- Owner approval (pasted): open the ratification PR only, as mackiannii; one
  file; no merge.
- Observed: at 14:30:20Z `gh api user` printed mackiannii (01-branch.txt).
  At 14:30:52Z it printed mack-dot (02-push-and-open.txt). gh auth status now
  lists mack-dot (keyring, active) and mackiannii (inactive); permissions
  admin=true. ~/.config/gh/hosts.yml changed at 14:30Z. The agent did not run
  gh auth login or gh auth switch; the source of the change is unknown to the
  agent (likely an owner login in another terminal of the same macOS user).
- Effect: the branch push (governance/ratification-0001, head 0159b4d2) used
  the owner credential, and PR #22 is authored by mack-dot. The commit author
  is mackiannii. PR #22 has one file (blob 84ea1cf8, sha256 b0f61a88…), base
  aac837a0, not merged. The agent also made read-only API calls with the owner
  credential while checking (03-identity-after-open.txt).
- Consequence: the owner cannot approve PR #22 (author) and, with
  require_last_push_approval, cannot approve a push made by mack-dot. PR #22
  is not a valid ratification vehicle. Do not approve or merge it.
- Decision: stopped at the boundary ("If the agent can still act as the owner,
  stop at that boundary"). No close, switch, logout or new push was done.
- Impact: All six EXITs are NOT RUN. end_to_end=false. Classifications
  unchanged.
- Next check: after the owner removes mack-dot from the agent's gh keyring,
  gh api user must print mackiannii with admin=false; then, with the owner's
  authorization, mackiannii pushes the same commit 0159b4d2 to a new branch,
  opens a new PR and closes #22.

## U139 — Credential separation not demonstrable; corrective PR not pushed

- References: U138; results/stage9/ratification-pr-0001/04-separation-check.txt.
- Owner approval (pasted): corrective PR only, subject to four verified
  checks; stop without pushing if any check fails or cannot be demonstrated.
- Method: read-only, without any GitHub API call (an API call would have used
  the active owner token). Keychain checks read attributes only, never secrets.
- Check 1 (gh user = mackiannii): FAIL. hosts.yml active user is mack-dot.
- Check 2 (Write, no admin or bypass): NOT RUN; it needs an API call as
  mackiannii, and no agent-only environment exists.
- Check 3 (git push uses mackiannii): FAIL. For https://github.com the helper
  is `gh auth git-credential`, which uses the active account (mack-dot).
- Check 4 (no owner credential reachable): FAIL. The agent runs as macOS user
  mackianni, the owner's user. The login keychain holds gh items for mack-dot
  and mackiannii, and a github.com internet password for a third account
  name. ~/.git-credentials exists (helper `store`). Claude in Chrome tools are
  available in the session; the github.com block is an owner attestation only.
  An isolated HOME or GH_CONFIG_DIR would not remove this access.
- Decision: stopped without pushing. PR #22 stays open, owner-authored, unmerged.
- Impact: All six EXITs are NOT RUN. end_to_end=false.
- Next check: an agent environment under a different, non-admin macOS user
  (or a remote environment) that holds only the mackiannii credential; checks
  1–4 run from inside it.

## U140 — Corrective ratification PR #23 opened by mackiannii; #22 closed

- References: U138, U139; results/stage9/ratification-pr-0001/05–07.
- Owner decision (AskUserQuestion): "Go now, record residual". Owner wrote
  "im locked tf down" (attestation; not verified by the agent).
- Method: one subshell with GH_TOKEN = the mackiannii token from gh; the owner
  token was not used; no token was printed; the shared gh login (active
  mack-dot) was not changed.
- Checks: 1 PASS (mackiannii 143109898); 2 PASS (admin=false, maintain=false,
  push=true, ruleset current_user_can_bypass=never); 3 PASS (the github.com
  credential helper returned the mackiannii token); 4 NOT DEMONSTRATED, residual
  accepted by the owner (same macOS user; owner keychain items reachable).
- Result: branch governance/ratification-0001-agent = 0159b4d2 (pushed exit 0);
  PR #23 by mackiannii, base aac837a0, one added file, blob 84ea1cf8, sha256
  b0f61a88… at the head (matches); review requested from mack-dot; BLOCKED,
  REVIEW_REQUIRED. PR #22 closed unmerged by mackiannii with a comment. The
  GitHub event feed did not yet show the branch-creation actor (lag).
- Impact: no approval, merge, v3.4 install or signing. All six EXITs are NOT
  RUN. end_to_end=false.
- Next check: owner review of PR #23 (exact head 0159b4d2); merge only with a
  separate authorization.

## U141 — PR #23 record mislabels one commit as a direct push

- References: U140; results/stage9/ratification-pr-0001/08-first-parent-19c4896b.txt.
- Observed: of the 41 commits reachable from 19c4896b, 40 are on the
  first-parent path. 0f11517d (2026-10-26) is reachable only as the second
  parent of merge 08cae1c5 (#4): it is the head of PR #4, not a direct push.
  The record (sha256 b0f61a88…) gives it the evidence text "no merged pull
  request for this commit (direct push)". The first half is true; "(direct
  push)" is false. The other 34 entries are first-parent commits without a PR.
- Impact: the error is in an informational field; the v3.4 lineage check does
  not read `covers`. It is still a false statement in a trust record.
- Decision: not corrected; the owner authorized the exact commit 0159b4d2 only.
- Next check: owner choice: approve as is with this note, or authorize one
  corrective commit on the PR #23 branch (new file hash; the approval must
  then bind the new head).

## U142 — PR #23 corrected: 0f11517d attributed to PR #4; audit limitation found

- References: U140, U141; results/stage9/ratification-pr-0002/.
- Owner authorization (pasted): one corrective commit on PR #23 as mackiannii.
- Evidence (GitHub API, as mackiannii): of the 35 commits without a merged PR,
  34 are first-parent commits with no associated PR (direct pushes);
  0f11517d is not first-parent and GitHub associates it with PR #4 (merge
  08cae1c5).
- Change: only `evidence` text, 35 fields. 0f11517d is now UNCERTAIN (head of
  PR #4, no recorded approval, as for #4); the 34 others state their basis.
  audit_status, audit_reason, pull, tree, baseline and statement are unchanged
  (checked by program). No entry is APPROVED. New sha256 34ae62bc…, blob
  79d717b8…, 16,775 bytes.
- Checks before push: 1–3 PASS, 4 residual accepted. Push 0159b4d2..174880e8
  exit 0. PR #23 head 174880e8; file sha256 at head matches; description
  updated (same text apart from the trailing newline). Reviews: none; review
  requested from mack-dot; BLOCKED, REVIEW_REQUIRED.
- Controls with the corrected file: 17/17 (lineage.py, lineage-controls-0005)
  and 17/17 (candidate common.py, -0006).
- Audit limitation (not fixed; no audit or verifier code changed):
  audit_main_approvals.py lists all commits reachable from main, not only
  first-parent transitions, and matches a PR only by merge SHA. A commit that
  arrives through a non-squash merge, or a non-final commit of a rebase merge,
  is reported NO_MERGED_PULL_REQUEST, which reads as a direct push. Main is
  squash-only since ruleset 26065125, so only earlier history is affected
  (one commit). The v3.4 lineage check walks first parents and refuses merge
  commits; it does not share this error. The proposal record U137 count "35
  UNAPPROVED direct pushes" is superseded: 34 direct pushes plus 0f11517d.
- Impact: no approval, merge, v3.4 install or signing. All six EXITs are NOT
  RUN. end_to_end=false.
- Next check: owner review of PR #23 at exact head 174880e8.

## U143 — Owner approved ratification PR #23 at the exact head

- References: U142; results/stage9/ratification-pr-0002/06-owner-review.txt.
- Observed (read as mackiannii): review 5699889214 by mack-dot (id 235131950,
  OWNER), state APPROVED, commit_id 174880e8 = PR head, submitted
  2026-10-29T14:58:47Z. reviewDecision APPROVED; mergeStateStatus CLEAN; main
  still aac837a0.
- Not done: merge (needs its own authorization). All six EXITs are NOT RUN.
  end_to_end=false.

## U144 — Ratification 0001 merged; first real approved lineage on main

- References: U143; results/stage9/ratification-pr-0002/07–08;
  results/stage9/lineage-real-0001/.
- Owner authorization: "do it for me" (merge of PR #23).
- Observed: checks 1–3 PASS as mackiannii (check 4 residual accepted); owner
  exact-head approvals on 174880e8: 1. `gh pr merge 23 --squash
  --match-head-commit 174880e8` exit 0: main 9aadcd63, merged by mackiannii,
  parent aac837a0, tree dcac5503 = approved head tree; one file added; its
  sha256 on main 34ae62bc… = approved file.
- Audit (43 commits, as mackiannii): 9aadcd63 (#23) and aac837a0 (#21)
  APPROVED, INFERRED_NON_ADMIN_MERGE_CANNOT_BYPASS. The 42 earlier rows are
  unchanged (commit, status, reason). Audit exit 1 (history not all APPROVED).
- Proposed lineage rule on real data, not simulated (read-only, proposal code,
  verifier unchanged): main 9aadcd63 ACCEPTED: #23 (review 5699889214) → #21
  (review 5699085293) → ratified baseline 19c4896b. aac837a0 still refused
  (its tree has no record).
- Limits: statuses are inferred (rule suites admin-only); same macOS user
  residual; v3.4 is not installed, so no running code reads the record.
- Impact: All six EXITs are NOT RUN. end_to_end=false. No v3.4 install, no
  signing.
- Next check: full v3.4 regression suite (48 + 14 + 9 controls with lineage
  stubs) and the authenticated verifier-token path, before any v3.4 install
  decision.

## U145 — v3.4 regression, wiring and authenticated verifier path pass

- References: U137, U144; results/stage9/v34-regression-0001/,
  v34-controls-0001 (failed, harness error), v34-controls-0002,
  v34-v31controls-0001, v34-f1controls-0001, v34-tokenpath-0001.
- Candidate: fresh clone of main 9aadcd63 plus the 3 manifest files
  (common.py d63010fc…, release.py 778cebb9…, lock 9bf8f905…), local commit
  b3251278. bootstrap --check: installed v3.3 on main 0; candidate 0.
- run_controls_v34.py (copy of the v3.3 suite; NEW, OLD, MAIN and a v3.2 lock
  constant changed): first run 47/48. The failure was the harness: the v3.2
  reproduction got the v3.3 lock (UNAPPROVED_IMPLEMENTATION). Fixed with a
  separate V32_LOCK; second run 48/48. v3.1 controls 14/14; F1 controls 9/9.
- Wiring (AST of candidate release.verify): approved_lineage called once, on
  request expected_source_commit, after run_identity and before the
  unchanged-candidate check; result carries approved_lineage and the trust
  assumption; end_to_end False; main() rejects on any exception. 8/8.
  A full positive release.verify run needs a signed bundle: NOT RUN.
- Authenticated path (real urllib fetch; FORGE_VERIFIER_GITHUB_TOKEN = the
  mackiannii token as a stand-in; the owner verifier token not used): 10/10.
  v3.3 repository_identity and run_identity accepted; v3.4 approved_lineage
  accepts main 9aadcd63 and refuses aac837a0; candidate repository_identity
  refuses main (v3.3 lock at commit); 404, missing, malformed and invalid
  (401) tokens and GITHUB_ACTIONS refused. Token value found in 0 record files.
- Limits: the real verifier token (owner-held, read-only) is still untested;
  statuses are inferred; same macOS user residual.
- Impact: All six EXITs are NOT RUN. end_to_end=false. Nothing installed.

## U146 — v3.4 install PR #24 opened by mackiannii for owner review

- References: U145; results/stage9/v34-regression-0001/04-open-pr.txt;
  results/stage9/v34-tokenpath-0001/results.txt.
- Owner direction (pasted): finish the enforcement chain; review v3.4 as a
  separate protected PR and approve its exact head; signing only after that.
- Checks 1–3 PASS as mackiannii; check 4 residual accepted; main 9aadcd63.
- PR #24: head ce7b5377 (parent 9aadcd63), tree d6793b63 = tested tree of
  b3251278; three files; lock 9bf8f905…; review requested from mack-dot;
  BLOCKED, REVIEW_REQUIRED. Not approved, not merged.
- Real lineage checks with the candidate code over the authenticated path:
  PR #24 head refused (NO_MERGED_PULL_REQUEST); PR #23 approved branch head
  174880e8 refused (approval of a branch head alone does not admit); main
  9aadcd63 accepted. Token in 0 record files.
- Impact: nothing installed; no signing. All six EXITs are NOT RUN.
  end_to_end=false.
- Next check: owner review of PR #24 at exact head ce7b5377; merge only with
  a separate authorization; after merge, fresh-clone bootstrap --check with
  9bf8f905, the audit, and approved_lineage on the install merge.

## U147 — Owner approved v3.4 install PR #24 at the exact head

- References: U146; results/stage9/v34-regression-0001/05-owner-review.txt.
- Observed (read as mackiannii): review 5700119180 by mack-dot (OWNER),
  APPROVED, commit_id ce7b5377 = PR head, 2026-10-29T15:12:42Z.
  reviewDecision APPROVED; mergeStateStatus UNSTABLE (a non-required check);
  main still 9aadcd63.
- Not done: merge (needs its own authorization). All six EXITs are NOT RUN.
  end_to_end=false.

## U148 — Ledger proof gate rejects PR #24 by design (protected inputs)

- References: U147; results/stage9/v34-regression-0001/06-proof-gate-check.txt;
  gate/approval.py.
- Observed: check `verify` on PR #24 head = failure; bot comment "Forge:
  rejected … The candidate changes protected inputs without approval bound to
  their exact content." PR #21 (CODEOWNERS) got the same; PR #23 (one
  governance file) was accepted. The ruleset requires no status checks.
- Cause (code read): gate/approval.authorize accepts a protected-input change
  only when the changed set is exactly {spec/LedgerSpec.dfy, spec.lock} and a
  gate/approvals record binds both. Any change to other protected inputs (the
  gate code) is always UNAPPROVED_PROTECTED_CHANGE. A GitHub review cannot
  satisfy it.
- Impact: not a v3.4 defect. Merging #24 merges a PR that the ledger gate
  reports as rejected, as with #19 and #21. Two approval mechanisms exist and
  are not unified (ledger gate approvals for spec text; owner exact-head review
  plus lineage for releases). No change proposed now (no architecture
  expansion).

## U149 — v3.4 installed by an approved merge; release admission now enforces lineage

- References: U147, U148; results/stage9/v34-install-0001/.
- Owner authorization: "i authorize" (merge of PR #24).
- Observed: checks 1–3 PASS as mackiannii (check 4 residual accepted); owner
  exact-head approvals on ce7b5377: 1. `gh pr merge 24 --squash
  --match-head-commit ce7b5377` exit 0: main f4f8a68c, merged by mackiannii,
  parent 9aadcd63, tree d6793b63 = approved and tested tree; three files; lock
  on main 9bf8f905…; 0 Actions variables.
- Fresh clone of main: inline lock check 0; bootstrap --check 0; old lock
  a809f701 refused (exit 1). Installed v3.4 over the authenticated path
  (stand-in token): repository_identity on main accepted; approved_lineage on
  f4f8a68c accepted (#24 → #23 → #21 → ratified 19c4896b); 19c4896b refused.
  Token in 0 record files.
- Audit (44 commits): f4f8a68c (#24) APPROVED (inferred); 43 earlier rows
  unchanged. Three earlier attempts ended with exit 2 on HTTP 503 from
  pulls/21 and pulls/24 (kept as 03a–03c); the same endpoints answered 200 when
  called directly.
- EXIT harness compatibility (code read): exit_stage_9.py checks gate exit
  codes and rejection reasons, not result keys; the new result fields do not
  break it. Each positive verify now makes about 25 API calls; a 503 makes an
  EXIT not_established (fail closed), so a re-run may be needed.
- Local copy synced (3 files and the ratification record); local check first
  BYTECODE_CACHE (caches left by an earlier run without -B), caches removed,
  then BOOTSTRAP_VERIFIED.
- Impact: All six EXITs are NOT RUN. end_to_end=false. No signing.
- Next check: owner authorization of a no-signing v3.4 rehearsal (recommended),
  then of the signing experiment; proposals/approval-integrity/SIGNING-v34.md.

## U150 — Owner authorizes one no-signing v3.4 hosted rehearsal

- References: U149; proposals/approval-integrity/SIGNING-v34.md step 1.
- Owner authorization (pasted): "Rehearse." Step 1 only: one no-signing hosted
  rehearsal against main f4f8a68c and lock 9bf8f905…; FORGE_SIGNING_AUTHORIZED
  unset; no Sigstore signing, OIDC signing credential, Rekor entry,
  deployment or release; no protected-file change; 503 = not established.
- Preconditions at 2026-10-29T15:25Z (as mackiannii): main f4f8a68c; 0 Actions
  variables; last provenance runs 40820302652 and 40810179164; Docker 28.5.1
  with builder forge-pinned.
- Next check: the request from a fresh clone; dispatch; sign job skipped;
  controller checks including approved lineage.

## U151 — v3.4 no-signing rehearsal: hosted run and controller checks pass

- References: U150; results/stage9/rehearsal-0003/;
  ~/forge-stage9-rehearsal-0003 (request, controller, artifact zip).
- Request: fresh clone of main f4f8a68c, bootstrap → producer --action
  request, lock 9bf8f905: exit 0 (15:25–15:30Z). Package f584305022f2… (same
  pinned package as earlier rehearsals); challenge 5ab0425c….
- Dispatch as mackiannii (main f4f8a68c, 0 variables): exit 0. Run
  40902238551, attempt 1, event workflow_dispatch, head f4f8a68c, title
  "forge-stage9 5ab0425c…" = challenge, actor mackiannii. Conclusion success:
  proof 15:30:25–16:05:01Z success; sign skipped. Token permissions Contents
  read, Metadata read (no IdToken). Log: 0 matches for id-token, Fulcio, Rekor,
  Sigstore. Artifact forge-stage9-unsigned-40902238551 (id 12912322356): zip
  sha256 bb0096fd… = GitHub digest; no Sigstore bundle.
- Controller checks (verify_rehearsal_v34.py, installed v3.4 from the fresh
  clone, gh read as mackiannii): attempt 1 exit 1, 14/15; the lineage control
  failed on the harness's HTTP status parser ("(HTTP 404)" read as
  gh-api-error; the override was still refused, with another reason).
  Parser fixed; attempt 2 exit 0, 15/15: artifact digest, request = pending
  controller row, package binding (hosted ELF = controller ELF = policy
  artifact 8ced2ab6…), receipt binding (656 files), receipt execution =
  {40902238551, 1}, run_identity, evidence = controller-computed (f19714ce…),
  approved lineage (#24 → #23 → #21 → ratified 19c4896b), override-source
  lineage control refused, statement binding (88eb881d…); 5 tamper controls
  rejected with the intended reasons.
- Real HTTPS path (stand-in token): run_identity, approved_lineage and
  repository_identity accepted; token in 0 record files. Controller row still
  pending (not consumed). No 503 occurred in these checks.
- Limits: no signature, so the signature check and the six EXITs are NOT RUN;
  freshness assumes GitHub executed the locked workflow; GitHub reads used the
  mackiannii account (the owner verifier token is untested); same macOS user
  residual; statuses inferred.
- Impact: Stage 9 is not complete. All six EXITs are NOT RUN. end_to_end=false.
- Next check: separate owner authorization of the signing experiment
  (SIGNING-v34.md step 2).

## U152 — Owner authorizes the Stage 9 signing experiment

- References: U151; proposals/approval-integrity/SIGNING-v34.md step 2.
- Owner reply, verbatim, to "Next step, when you decide: authorize the signing
  experiment. It creates 7 permanent public Rekor entries, and it requires your
  verifier token for the EXITs.": "authorized".
- Scope taken: a new request at f4f8a68c (lock 9bf8f905); the owner sets
  FORGE_SIGNING_AUTHORIZED (only the owner can create repository variables);
  the agent (mackiannii) dispatches provenance.yml (R1) and, after R1 succeeds,
  provenance-negative.yml (R2); the owner deletes the variable. Public effect:
  Rekor entries under provenance.yml@refs/heads/main and
  provenance-negative.yml@refs/heads/main (permanent).
- Not included: the six EXITs need the owner's verifier token, which the agent
  never handles; the owner runs them.

## U153 — Signing variable set by the owner; R1 dispatched

- References: U152; ~/forge-stage9-signing-0001/run/.
- Owner: "did it". Agent check (as mackiannii) 16:10:09Z: one variable,
  FORGE_SIGNING_AUTHORIZED = "true", created 16:10:02Z.
- New request from a fresh clone of f4f8a68c: exit 0 (16:13–16:17Z);
  package f584305022f2…; lock 9bf8f905…; challenge 63f3549a….
- Dispatch R1 as mackiannii (main f4f8a68c, variable true, no active runs):
  exit 0. Run 40910241018, attempt 1, head f4f8a68c, title
  "forge-stage9 63f3549a…" = challenge.
- Next check: proof success; sign success; then R2 with producer_run_id
  40910241018; then the owner deletes the variable.

## U154 — R1 signed; R2 blocked: GitHub's new job-token format fails Forge's token check

- References: U153; results/stage9/signing-0001/.
- R1 run 40910241018 (attempt 1, head f4f8a68c, title = challenge 63f3549a…):
  success. proof 16:18:24–16:52:32Z; sign 16:52:35–16:53:10Z, every step
  success ("Sign exact release statement and explicitly marked rejection
  fixtures"). Artifacts: forge-stage9-signed-40910241018 (d8536599…),
  forge-stage9-unsigned-40910241018 (02ab412c…). Signing under
  provenance.yml@refs/heads/main happened; its Rekor entries are permanent.
  The agent has not yet downloaded or verified the signed bundles.
- R2 run 40916168141 (provenance-negative.yml, producer_run_id 40910241018,
  variable true, head f4f8a68c): failure after 10 s at "Check pins and
  authenticate producer run metadata": preflight.py → common.fetch →
  GITHUB_TOKEN_REQUIRED:FORGE_PRODUCER_GITHUB_TOKEN. Retrieval and the
  wrong-signer signing step were skipped: no negative signature, no Rekor
  entry under provenance-negative.yml. First run of this workflow ever.
- Cause (inference, strong): the job log shows the variable set (masked); the
  bootstrap passes every non-PYTHON variable; so the token reached
  common.fetch and failed `[A-Za-z0-9_]{20,255}`. GitHub changelog
  2026-10-02: installation tokens, including the Actions GITHUB_TOKEN, are now
  "ghs_APPID_JWT", about 520 characters, length varies. Over 255 characters
  (and a JWT carries '.' and '-'). The token value was not observed.
- Impact: the installed v3.4 cannot produce the wrong-signer fixture; the
  wrong-signer EXIT cannot run. A fix changes common.py, so the lock, the
  source commit and R1 must all be new; this R1 cannot pair with a later R2.
  Verifier side: fine-grained PATs (github_pat_, 93 chars) still match.
- All six EXITs are NOT RUN. end_to_end=false. FORGE_SIGNING_AUTHORIZED was
  still set at the time of this entry; deletion requested from the owner.

## U155 — Owner keeps FORGE_SIGNING_AUTHORIZED set

- References: U152–U154.
- Owner: "we can keep it for now" (2026-10-29, after the delete request).
- State: repository variable FORGE_SIGNING_AUTHORIZED = "true" (created
  16:10:02Z). Effect: any dispatch of provenance.yml or provenance-negative.yml
  on main by an account with write access (mack-dot, mackiannii) runs the
  signing jobs and writes permanent Rekor entries.
- Agent rule kept: no dispatch without a new explicit owner authorization;
  every dispatch script checks the variable and main before it runs.

## U156 — v3.5 token repair verified locally; ready for a protected PR

- References: U154, U155; proposals/token-compat-v35/; results/stage9/
  v35-token-controls-0001..0003, v35-preflight-0001..0002,
  v35-regression-0001, v35-controls-0001..0002, v35-v31controls-0001..0002,
  v35-f1controls-0001..0002, v35-lineage-controls-0001..0002, v35-audit-0001;
  results/stage9/signing-0001 (R1, R2 preserved).
- Change: common.fetch token check `[A-Za-z0-9_]{20,255}` → `20 <= len <= 4096
  and fullmatch([A-Za-z0-9._~+/-]+=*)` (RFC 6750 token characters). Final:
  common.py 02830668…, lock a177cb07…, diff 07b069fb…. Variant A
  (`[\x21-\x7e]{20,4096}`, lock 845a935b…) superseded after audit finding 5.
- Offline token controls (local HTTP server, real common.fetch): variant A
  25/25 both versions (one earlier harness crash on NUL: the OS refuses NUL in
  the environment); final 34/34 for v3.4 and v3.5. v3.4 refuses the 520-char
  stateless shape (R2's reason, no request sent); v3.5 accepts legacy, OAuth,
  fine-grained and stateless 520–4096, sends exactly "Bearer <token>"; refuses
  unset, empty, short, >4096, LF, CRLF injection, space, tab, DEL, non-ASCII,
  U+2028, quotes, comma, semicolon, backslash, parentheses, inner `=`;
  401/403/404/503 → GITHUB_HTTP_STATUS; connection refused → URLError (no
  data). Token in 0 record files.
- Linux preflight (python:3.10.11-slim amd64 @fd86924b…, cosign linux-amd64
  424e2c97… = policy, real preflight.py via bootstrap unless noted):
  final 10/10 (variant A also 10/10). Same synthetic 520-char token: v3.4
  blocked GITHUB_TOKEN_REQUIRED:FORGE_PRODUCER_GITHUB_TOKEN (exact R2
  failure); v3.5 → real GitHub API 401 (fail closed); v3.5 with the API
  answered from R1's real record (harness, not bootstrap) → success. Real
  agent token on the real API: R1 → success (full preflight incl. cosign
  version); R2 run → PRODUCER_RUN_IDENTITY; "12ab" → PRODUCER_RUN_ID; run 1 →
  404; no token → GITHUB_TOKEN_REQUIRED; v3.4 baseline → success. Real and
  synthetic token in 0 files.
- Regression on the final candidate (local 669805b7, tree 36ee0f91):
  bootstrap 0; 48/48; v3.1 14/14; F1 9/9; lineage 17/17; release.py
  unchanged.
- Independent audit (2 rounds): nothing blocks.
- Open (not fixed, outside scope): a real stateless token was never used
  (only hosted jobs mint them); actions/download-artifact with it unverified;
  preflight accepts any successful provenance.yml run at the same commit
  (case 6: the unsigned rehearsal run passes; R2 then fails at download);
  urllib forwards Authorization on cross-host redirects; cosign inherits the
  producer token; the old c10 hyphen control now ends in 401, not
  GITHUB_TOKEN_REQUIRED.
- Impact: nothing installed or dispatched. All six EXITs are NOT RUN.
  end_to_end=false. FORGE_SIGNING_AUTHORIZED still "true" (U155).

## U157 — v3.5 PR #25 opened by mackiannii for owner review

- References: U156; results/stage9/v35-regression-0001/04a, 04.
- Attempt 1: the final checkout's origin was a local scratch clone; the push
  went there and gh pr create failed (no branch on GitHub; GitHub branch 404
  confirmed). No GitHub change.
- Attempt 2 (checks 1–3 PASS; main f4f8a68c; variable true; no active runs):
  push to https://github.com/mack-dot/forge.git exit 0; PR #25 by mackiannii,
  head 05a7ac1f (parent f4f8a68c), tree 36ee0f91 = tested tree; two files
  (common.py 02830668…, lock a177cb07…); BLOCKED, REVIEW_REQUIRED.
- Not done: approval, merge, dispatch, signing. All six EXITs are NOT RUN.
  end_to_end=false.

## U158 — Owner approved v3.5 PR #25 at the exact head

- References: U157; results/stage9/v35-regression-0001/05-owner-review.txt.
- Observed (read as mackiannii): review 5702213130 by mack-dot (OWNER),
  APPROVED, commit_id 05a7ac1f = PR head, 2026-10-29T17:33:28Z.
  reviewDecision APPROVED; mergeStateStatus UNSTABLE: the ledger proof gate
  check `verify` failed, as expected for a gate/** change (U148); not
  required. main still f4f8a68c.
- Not done: merge (needs its own authorization). All six EXITs are NOT RUN.
  end_to_end=false.

## U159 — v3.5 installed by an approved merge; lineage and lock verified

- References: U158; results/stage9/v35-install-0001/.
- Owner authorization: "authorize" (merge of PR #25).
- Checks 1–3 PASS as mackiannii (check 4 residual accepted); owner exact-head
  approvals on 05a7ac1f: 1. `gh pr merge 25 --squash --match-head-commit
  05a7ac1f` exit 0: main 5b1b5570, merged by mackiannii, parent f4f8a68c,
  tree 36ee0f91 = approved and tested tree; two files; lock a177cb07…;
  variable FORGE_SIGNING_AUTHORIZED still set (owner decision).
- Fresh clone: inline lock check 0; bootstrap --check 0; old lock 9bf8f905
  refused (exit 1). Installed v3.5, real HTTPS path (stand-in token):
  repository_identity on main accepted; approved_lineage on 5b1b5570 accepted
  (#25 → #24 → #23 → #21 → ratified 19c4896b); 19c4896b refused. Token in 0
  files. Audit (45 commits, first attempt): #25 APPROVED (inferred); 44
  earlier rows unchanged. Local copy synced; local check 0.
- R1 attempt-1 Rekor entries (from the preserved signed artifact): 6 dsse
  entries, identity provenance.yml@refs/heads/main, log indices 3571986339
  (release), 3571986951, 3571987562, 3571988224, 3571988995, 3571989402.
  Permanent; tied to lock 9bf8f905 and commit f4f8a68c; not usable with v3.5.
- Prepared (not run): proposals/token-compat-v35/SIGNING-v35.md and
  run_exits_owner.sh (owner-run; reads the verifier token without echo).
- Owner instructions: keep all credentials (no revoke or rotate); keep the
  signing variable as configured; no dispatch without separate authorization.
- All six EXITs are NOT RUN. end_to_end=false. Stage 9 not complete.

## U160 — Owner authorizes dispatch of attempt 2 (R1 and R2) under v3.5

- References: U159; proposals/token-compat-v35/SIGNING-v35.md step 1.
- Owner reply, verbatim, to 'Reply "dispatch R1 and R2" to start': "start them".
- Scope: a new request at main 5b1b5570 (lock a177cb07…); R1 provenance.yml;
  after R1 success, R2 provenance-negative.yml with producer_run_id R1;
  downloads and Rekor listing. Variable FORGE_SIGNING_AUTHORIZED already
  "true" (owner decision). Expected permanent effect: 7 Rekor entries.
- Not included: the six EXITs (owner-run with the verifier token).

## U161 — Attempt 2: request built; R1 dispatched

- References: U160; ~/forge-stage9-signing-0002/.
- Request from a fresh clone of 5b1b5570, lock a177cb07: exit 0
  (17:45–18:19Z, slower than before); package f584305022f2…; challenge
  9e1f885f….
- Dispatch R1 as mackiannii (main 5b1b5570, variable true, no active runs):
  exit 0. Run 40929727313, attempt 1, head 5b1b5570, title
  "forge-stage9 9e1f885f…" = challenge.

## U162 — Attempt 2 signed: R1 and R2 succeed under v3.5; 7 Rekor entries; EXIT setup ready

- References: U161; results/stage9/signing-0002/; ~/forge-stage9-signing-0002/.
- R1 run 40929727313 (head 5b1b5570, title = challenge 9e1f885f…): success.
  proof 18:19:39–18:53:58Z; sign 18:54:01–18:54:39Z. Artifacts: signed
  cebef9ce…, unsigned 3dd2e832… (zip digests = GitHub).
- R2 run 40935393475 (provenance-negative.yml, producer_run_id 40929727313,
  head 5b1b5570): success in 21 s. Every step succeeded, including "Check
  pins and authenticate producer run metadata" (real stateless job token
  through v3.5 common.fetch), "Retrieve the authenticated run's signed
  candidate" (actions/download-artifact with that token) and "Sign under this
  unauthorized workload identity only". Artifact negative 7e0b4bc4… (= GitHub).
  This closes the v3.5 open items "no real stateless token used" and
  "download-artifact unverified".
- Permanent Rekor entries (dsse), from the R2 artifact bundles:
  provenance.yml@refs/heads/main: 3574048063 (release), 3574049457,
  3574050743, 3574051983, 3574052947, 3574053714 (controls);
  provenance-negative.yml@refs/heads/main: 3574086992 (wrong-signer).
  Total public entries for this project now 13 (6 from attempt 1, U159).
- EXIT setup, no credential: fresh clone of 5b1b5570 (exit-main); Cosign
  darwin-arm64 9f9b8cd5… = policy; inline lock check 0; bootstrap 0;
  write_controller_config exit 0 (candidate = R2 artifact; challenge
  9e1f885f…; lock a177cb07); controller row pending.
- Not run: the six EXITs (owner-run with the read-only verifier token via
  proposals/token-compat-v35/run_exits_owner.sh). end_to_end=false. Stage 9
  not complete. FORGE_SIGNING_AUTHORIZED still "true".

## U163 — Owner directs the agent to run the EXITs with the stored verifier token

- References: U117, U119, U162.
- Owner, verbatim: "use the same token i gave" (in reply to the instructions
  for owner-run EXITs).
- Interpretation recorded: a waiver like U117, for the six Stage 9 EXITs and a
  validity check only. The agent loads the token from the macOS Keychain item
  forge-verifier-readonly (account mack-dot, created 2026-10-29T02:04:02Z)
  directly into the verifier's environment. It never prints, copies, stores
  or passes the value as an argument, and does not read it from the chat.
- The owner states this is the token given earlier; U119 records that a token
  was pasted into the chat, so this verifier credential is treated as
  exposed. It is read-only for a public repository; it cannot forge GitHub
  API answers or signatures.
- Independence limit: the agent, not a separate person or machine, runs the
  verifier with this credential (same macOS user, U139).
- Owner confirmation after the validity check: "i approve its ok". Validity
  check (not an EXIT): token loaded from Keychain (length 93, value not
  shown); approved_lineage on 5b1b5570 over the real HTTPS path ACCEPTED;
  token in 0 record files.

## U164 — Official EXITs: five passed; deployed-identity not established (image directory mode)

- References: U162, U163; results/stage9/exits-0001/console.txt;
  ~/forge-stage9-signing-0002/exit-main/results/stage9/<case>/attempt-0001/.
- Setup: clone 5b1b5570, lock a177cb07, candidate = R2 artifact, request
  9e1f885f (pending), verifier token from Keychain (U163), inline check 0,
  bootstrap 0. Each case through the bootstrap, once.
- Actual exit codes: valid-bundle 0 (STAGE9_VALID_BUNDLE_PASSED); unsigned 0;
  wrong-signer 0; wrong-digest 0; wrong-policy 0; deployed-identity 1
  (STAGE9_NOT_ESTABLISHED: UNEXPECTED_GATE_EXIT:accepted-deployment).
  19:04:50–19:07:47Z. No 503. Verifier token in 0 files.
- deployed-identity cause (observed): observe.py --case accepted verified the
  release, set the request to consumed, created and started the container
  (sha256:f584305022f2…, --user 1000:1000, read-only, no network), then
  `docker exec --user 1000:1000 <c> cat /opt/forge/gcd-selftest.elf` exited
  1: "Permission denied". In the image /opt/forge is dr--r--r-- 1000:1000
  (no search bit); the ELF is -r--r--r--. The Dockerfile line `COPY
  --chown=1000:1000 --chmod=0444 gcd-selftest.elf /opt/forge/gcd-selftest.elf`
  gave the created directory the file mode. The runtime user cannot read its
  own artifact: a packaging defect, first exercised by this EXIT.
- State after: controller row consumed (admission happens before the
  deployment observation; a failed observation spends the request). The
  stopped container 48b1a28d806a (role accepted) is kept as evidence.
- Impact: Stage 9 is NOT complete (5 of 6 EXITs). end_to_end=false. A re-try
  needs a fix (Dockerfile, in the lock: new lock, new package identity), an
  approved install PR, a new request and new R1/R2 (7 more Rekor entries);
  a coherent set should re-run all six EXITs under one lock.

## U165 — v3.6 deployment repair: root cause confirmed; candidate tested

- References: U164; proposals/deploy-perms-v36/; results/stage9/
  v36-repro-0001, v36-package-0001, v36-deploy-0001, v36-consumption-0001(.txt),
  v36-regression-0001, v36-controls-0001, v36-v31controls-0001,
  v36-f1controls-0001, v36-lineage-controls-0001, v36-token-controls-0001.
- Root cause confirmed (v3.5 image f584305022f2…): added layer entries are
  opt (0755 0:0), opt/forge (dir 0444 1000:1000), the ELF (0444 1000:1000).
  In a container started with observe.py's exact flags (non-root 1000:1000,
  read-only, network none, cap-drop ALL, no mounts, running): stat works,
  `test -x /opt/forge` exit 1, `cat` exit 1 "Permission denied"; the working
  directory is the same unsearchable path. As root (separate container) the
  ELF sha256 is 8ced2ab6… No other packaged path exists.
- Repair (v3.6): Dockerfile moves `WORKDIR /opt/forge` before the COPY (2
  comment lines). Dockerfile bb0a3d3d… → c915c79d…; lock a177cb07… →
  5f78da21…; diff 836cb178…. common, release, observe, producer unchanged.
- Package: producer.package (pinned builder) twice: identical package
  d9e9fb40f9d2…, 57 layers (2 added), passes image_identity/layer_effect;
  entries opt/forge dir 0755 1000:1000, ELF 0444 1000:1000; ELF 8ced2ab6….
  The directory owner can write it, but the observed container's root
  filesystem is read-only (checked by the observer).
- Real-container controls with observe.observe (13/13): v3.5 still
  COMMAND_FAILED:observed-elf; v3.6 ACCEPTED (UID 1000 reads 8ced2ab6…);
  substituted bind mount, substituted-ELF image → DEPLOYED_ARTIFACT_MISMATCH;
  exact-bytes bind mount → DEPLOYMENT_MOUNT_OBSCURES_IDENTITY; tmpfs over
  /opt/forge → COMMAND_FAILED:observed-elf; wrong image →
  DEPLOYED_PACKAGE_MISMATCH; network, writable rootfs, root user, privileged
  → DEPLOYMENT_ISOLATION; not started → DEPLOYMENT_NOT_RUNNING; stop during
  observation → DEPLOYMENT_CHANGED.
- Package-binding controls (6/6, one earlier run 5/6 from a wrong expected
  reason name in the harness: PACKAGED_ELF_BYTES).
- Consumption audit on copies (5/5): consumed → STALE_OR_CONSUMED_REQUEST for
  release.py --admit and observe.py accepted; verification failure and kill
  before COMMIT leave pending; a second writer is locked out. Originals
  unchanged. Behaviour judged intentionally fail-closed; recovery cost is a new
  request, R1 and R2 per post-admission failure (CONSUMPTION.md). No change.
- Regression on candidate 216b2447 (tree 6d6b2a2f): 48/48, 14/14, 9/9,
  lineage 17/17, token 34/34; old lock refused; bootstrap 0.
- Pending: independent adversarial review; PR. All six EXITs: five passed
  under v3.5 (U164), deployed-identity not established. Stage 9 NOT complete.
  end_to_end=false.

## U166 — Independent review of v3.6: no blocker; four pre-existing findings confirmed

- References: U165; results/stage9/v36-review-adjudication-0001/;
  scratchpad audit-v36 (reviewer scripts).
- Verdict: the change is minimal and correct and adds no defect. Confirmed:
  only Dockerfile and implementation.lock differ from v3.5 (ELF, policy,
  artifact-identities, spec.lock, results byte-identical); all 90 lock entries
  equal the candidate files; recipe_sha256 = candidate Dockerfile hash;
  deploy_controls uses the production observe.observe with main()'s flags
  (but skips runtime, verify and the controller transaction, with a 3-field
  request); consumption-before-observation is intentional; CONSUMPTION.md
  corrected for two overclaims.
- Pre-existing findings (not introduced by v3.6; observe.py and release.py
  unchanged), adjudicated by the agent's own runs where marked:
  - F1 (low; confirmed by agent run): observe() checks Mounts but not
    HostConfig.Tmpfs, Env or Entrypoint; `cat` resolves through PATH. A
    container with `--tmpfs /opt/forge` holding an exact ELF copy is
    ACCEPTED (Mounts [], Tmpfs {'/opt/forge': …}). observe.py main() creates
    the container with fixed flags, so the official path cannot add a tmpfs.
    Suggested hardening: require empty Tmpfs, compare Config/HostConfig to
    the create flags, exec /usr/bin/cat.
  - F2 (info): the Docker daemon is a trust root; mounts made inside the
    namespace (for example via nsenter with host access) are invisible to the
    before/after inspections (reviewer run).
  - F3 (low): layer_effect ignores parent-directory modes, so the v3.5
    package passed the package check; the deployment observation caught it.
  - F4 (medium; confirmed by agent run): Python tarfile and dockerd read a
    crafted layer with conflicting PAX and GNU long names differently; the
    candidate's image_identity ACCEPTS it, while dockerd places "WRONG" at the
    target (sha256 70fe0cc3…). observe() rejects such a deployment. Exposure:
    release.py --admit for a signed crafted package; the controller builds
    its own package, so this needs a compromised builder. Suggested hardening:
    reject typeflags x, g, L, K, S in raw layer headers.
- Decision: not folded into v3.6 (scope: minimal deployment repair). Each
  later lock change costs a new R1/R2 (7 Rekor entries); the owner decides
  whether to harden F1/F4 before the completion run.

## U167 — v3.6 PR #26 opened by mackiannii for owner review

- References: U165, U166; results/stage9/v36-regression-0001/02-open-pr.txt.
- Checks 1–3 PASS (check 4 residual accepted); main 5b1b5570; variable
  FORGE_SIGNING_AUTHORIZED "true"; no active runs.
- PR #26: head 5867db32 (parent 5b1b5570), tree 6d6b2a2f = tested tree;
  two files (Dockerfile c915c79d…, lock 5f78da21…); review requested from
  mack-dot; REVIEW_REQUIRED. Not approved, not merged.
- Plan for the completion run: proposals/deploy-perms-v36/SIGNING-v36.md (not
  run). All six EXITs: five passed under v3.5 (U164); deployed-identity not
  established. Stage 9 NOT complete. end_to_end=false.

## U168 — v3.6 merged as main 624c9faf; completion run not started

- References: U165, U166, U167; results/stage9/v36-install-0001/.
- Owner review 5705585056 APPROVED by mack-dot on the exact head 5867db32
  (read by the agent through the API). Owner merge authorization in chat.
- The failing `verify` check on 5867db32 is the ledger proof gate, which
  rejects every gate/** change (U148). The main ruleset requires no status
  check, so it did not block the merge.
- Merge by mackiannii: checks 1–3 PASS (admin=false, bypass=never, helper
  token = mackiannii; check 4 residual accepted); `gh pr merge 26 --squash
  --match-head-commit 5867db32` exit 0. Main 624c9faf (parent 5b1b5570),
  tree 6d6b2a2f = approved head tree; two files; lock 5f78da21… on main.
- Fresh clone at 624c9faf: inline lock check 0; bootstrap --check 0; old lock
  a177cb07 refused (exit 1); approved_lineage(624c9faf) ACCEPTED through
  #26 → #25 → #24 → #23 → #21 → ratified 19c4896b; 19c4896b alone refused.
  No token in the records. Local checkout synced; bootstrap verified.
- Audit of 46 main commits: exit 1 (expected: older rows); #26 APPROVED
  (inferred non-admin merge); 45 earlier rows unchanged.
- FORGE_SIGNING_AUTHORIZED unchanged ("true", U155). No dispatch, no new
  request, no new Rekor entry.
- Next: commit C for SIGNING-v36.md is 624c9faf. Dispatch (new request, R1,
  R2; 7 Rekor entries) needs separate owner authorization. F1–F4 stay open
  (U166); the owner chose to harden them after Stage 9. Stage 9 NOT complete.
  end_to_end=false.

## U169 — Stage 9 completion run under v3.6: all six official EXITs exit 0; Stage 9 DONE

- References: U155, U163, U164, U165, U166, U168;
  results/stage9/signing-0003/, results/stage9/exits-0002/;
  ~/forge-stage9-signing-0003/ (full EXIT records, 1.4 GB, kept).
- Authorization: owner dispatch authorization for main 624c9faf, lock
  5f78da21 (pasted in chat). Not changed: verifier, policy, proof claims,
  implementation, signing variable (FORGE_SIGNING_AUTHORIZED "true", U155).
- Observations:
  - Request at 624c9faf (GH_TOKEN unset; producer needs none): exit 0;
    package d9e9fb40… (= SIGNING-v36.md); challenge 8a6ba7f4…; row pending.
  - R1 provenance.yml run 40966460258 (head 624c9faf, actor mackiannii,
    attempt 1): success. R2 provenance-negative.yml run 40969828051
    (producer_run_id 40966460258): success, every step.
  - Artifacts downloaded into new folders; zip digests = GitHub (signed
    8ded75a0…, unsigned 62a0adcc…, negative 27e144bc…).
  - 7 new permanent Rekor entries (dsse): provenance.yml@refs/heads/main
    3578450049 (release), 3578452739, 3578453975, 3578456247, 3578458664,
    3578462150; provenance-negative.yml@refs/heads/main 3578489035. Project
    total 20 (U159, U162, this entry).
  - EXIT setup in a fresh clone of 624c9faf: Cosign darwin-arm64 9f9b8cd5…
    = policy; inline lock check 0; bootstrap 0; config 0.
  - Six official EXITs, one request, one lock, in order, token from Keychain
    per U163: valid-bundle 0, unsigned 0, wrong-signer 0, wrong-digest 0,
    wrong-policy 0, deployed-identity 0 (last). Each passed on attempt 0001.
    Gate outcomes: valid-bundle verified twice (Cosign 0), altered evidence
    EVIDENCE_DIGEST, fabricated receipt PROOF_RECEIPT_BINDING, wrong method
    CLAIM_METHOD_BINDING; unsigned/wrong-signer/wrong-digest positive before
    and after, negative SIGNATURE_REJECTED with Cosign 1; wrong-policy
    POLICY_BINDING, STALE_OR_SUBSTITUTED_REQUEST, EVIDENCE_BINDING,
    CLAIM_METHOD_BINDING; deployed-identity: `docker exec --user 1000:1000
    <c> cat /opt/forge/gcd-selftest.elf` in the running container of image
    d9e9fb40… with no mounts read 8ced2ab6… (accepted); a bind-mounted
    substitute read 573f5828… (DEPLOYED_ARTIFACT_MISMATCH); a second
    admission got STALE_OR_CONSUMED_REQUEST. Controller row now consumed.
  - No file in the EXIT records holds the verifier token.
- Result: ROADMAP rule 3 met. Stage 9 marked DONE; Stage 10 set CURRENT; no
  Stage 10 work started. end_to_end=false.
- Limits of what this shows (inference, not measured):
  - Deployment claim = file identity at observation time only
    (deployment_correctness_proved=false, riscv_execution_claimed=false).
  - The agent ran the verifier on the owner's machine with the owner's
    read-only token (U163); no separate person or machine (U139).
  - The GitHub-hosted runner, GitHub OIDC, Sigstore/Rekor, the Docker daemon
    and the pinned buildx builder are trusted components.
- Residual findings, still open (U166), with threat-model limits:
  - F1 (low): observe() does not inspect HostConfig.Tmpfs. Safe only while
    the controller itself creates the container with the fixed flags of
    observe.py main(). Not safe for observing containers that someone else
    created. Fix before that use.
  - F2 (info): the Docker daemon is a trust root. A party with host or daemon
    control can show the observer any bytes. Out of scope for Stage 9.
  - F3 (low): the package check ignores parent-directory modes (the cause of
    the v3.5 failure got past it). Deployment observation is the only check
    that catches such a package.
  - F4 (medium): image_identity and dockerd read crafted PAX/GNU long-name
    layers differently. Safe only while the builder is trusted (the
    controller builds its own package). Not safe for packages from an
    untrusted builder; observe() is then the only defence. Fix before that
    use.
- Next check: owner decision on hardening F1/F3/F4 before any wider threat
  model; owner decision on FORGE_SIGNING_AUTHORIZED now that signing ran.

## U170 — Stage 9 evidence frozen locally; signing variable left to the owner; Stage 10 not started

- References: U155, U169.
- Freeze: results/stage9/freeze-0001/manifest.json (sha256 3afdd6b1…a298) hashes
  16,206 files (1.93 GB): signing-0003, exits-0002, v36-install-0001 records,
  and in ~/forge-stage9-signing-0003 the request, controller database, run
  logs, the three artifact zips and unpacked bundles, the six EXIT case
  folders and controller.json. It also names main 624c9faf, lock 5f78da21…,
  challenge 8a6ba7f4… and the 7 Rekor log indexes.
- Observation: GitHub expires the R1/R2 artifacts on 2027-01-27. After that
  only the local copies (this manifest) and the permanent Rekor entries stay.
  /Users/mackianni/forge is not a git working tree, and
  ~/forge-stage9-signing-0003 is outside it; neither has a backup yet.
- Signing variable: the pasted note recommends setting
  FORGE_SIGNING_AUTHORIZED to false. mackiannii has admin=false; repository
  variables of a personal-account repository need the owner. The agent does
  not use the owner's token. Owner action in the browser; still "true".
- Stage 10: not started. The pasted note recommends mack-dot/forge as host.
  Observation: 18 PRs so far, all by mack-dot (13 since 2026-10-15) or
  mackiannii (5). Inference: a two-week sample there is small and not
  independent of Forge's own development. Needs separate owner
  authorization naming the host repository.

## U171 — Signing variable off; owner replaces Stage 10 shadow mode with an in-repo benchmark (proposal)

- References: U155, U170.
- Observation: FORGE_SIGNING_AUTHORIZED = "false", updated
  2026-10-29T23:37:55Z (owner, browser; read by mackiannii). Signing
  workflows now stop at their authorization check.
- Owner, verbatim: "set to false and i think that we should just instead of
  shadow a repo we come up with benchmark tests in here in another folder".
- Proposal written: proposals/stage10-benchmark.md (new folder bench/; frozen
  manifest of cases and expected classes before any run; gate code
  unchanged; EXIT scripts/exit_stage_10.py --case report). Not applied:
  ROADMAP Stage 10 text unchanged until the owner approves the proposal.
- Impact (inference): the benchmark measures classification on a synthetic
  corpus by the same authors. It drops the operational evidence that shadow
  mode would have given (real PRs, elapsed time, real false-positive rate).
- Next check: owner approval of the proposal; then the exact case list and
  manifest hash as a second approval before any run.

## U172 — Stage 10 benchmark prepared and frozen; official run waits for owner approval

- References: U171; proposals/stage10-benchmark.md; bench/; results/stage10/dry-run-0001/.
- Owner approval of the plan (pasted conditions 1–8, verbatim summary in
  ROADMAP Stage 10). "Stop for my approval of the complete case list and
  manifest hash before running the official benchmark."
- Observations:
  - 51 cases (bench/CASES.md): accept 14 (incl. 3 seeds, 8 valid
    alternatives, 3 unchanged supplied evidence), defect 8, policy_reject 11,
    missing_evidence 10 (adversarial evidence), unsupported 4, tool_failure 4.
    Gates: ledger PR (gate/incremental.py) 20, ledger evidence (gate/gate.py)
    11, booking 11, refund 9.
  - Expected classes, exits and reason prefixes come from the approved plan
    and from reading the gate code; no case ran through Dafny or a gate.
  - bench/manifest.json sha256
    98df027211b25a6349c3d8cde4e8661394bf8de0a14ea0558ee61f4c6aa14889 hashes
    every bench file and scripts/exit_stage_10.py; base 624c9faf; toolchain
    pins 74dcc4b8…; Python 3.10.11; 2 passes; 1800 s timeout per case.
  - Dry run exit 0: sandboxed dafny --version 0; IP connection refused
    (PermissionError); 51/51 case trees built, edits applied, removed; about
    15 s per case for cloning and cleanup.
- Inferences and open points:
  - The 4 `unsupported` cases expect "no acceptance". The ledger PR gate has no
    "no claim" result and ignores files outside its scope, so it may accept
    them. That would count as a false accept: a pre-registered finding, not a
    reason to relabel.
  - Valid-alternative labels rest on the authors' reasoning only. A rejected
    alternative needs adjudication: gate wrong or label wrong.
  - Estimated official run time 1.5–2 h (two passes); not measured.
  - Not covered: binary/ELF and Stage 9 provenance gates; ts/ hostile tests.
- Next check: owner approval of the case list and manifest hash; then the
  official run with --approved-manifest-sha256 and the EXIT report.

## U173 — Owner approves the Stage 10 case list and manifest hash

- References: U172.
- Owner, verbatim: "i approve it how do i do that" (reply to the request to
  approve manifest 98df027211b25a6349c3d8cde4e8661394bf8de0a14ea0558ee61f4c6aa14889
  and the case list in bench/CASES.md). Recorded as approval of that exact
  hash; the runner refuses any other manifest.
- Next: official run results/stage10/run-0001 (two passes), then
  python3 scripts/exit_stage_10.py --case report.

## U174 — Stage 10 run-0001 not established: host PyYAML drift; every gate stopped at its pin check

- References: U172, U173; results/stage10/run-0001/.
- Observation: all 102 case runs (51 × 2 passes) ended in about 0.1 s.
  Gates with a direct run exited 2 with "TOOLCHAIN_ERROR: PyYAML version
  differs from pin" (gate.py, booking.py and refund.py print it after
  "GATE_ERROR:"). Supplied-evidence cases became harness_error
  SEED_EVIDENCE_MISSING because no seed produced evidence. No Dafny check ran.
- Cause (observed): PyYAML 6.0.3 was installed into the user site-packages
  (~/Library/Python/3.10/...) on 2026-10-27 20:23, in one batch with aiohttp,
  boto3, botocore, hf_xet and others (installer "pip", no REQUESTED marker:
  a dependency of another tool). The user site comes first on sys.path, so it
  hides the pinned PyYAML 6.0.1 in the framework site-packages (Feb 2024).
  The pinned attrs 25.3.0 is itself in the user site, so disabling the user
  site does not restore the pinned set. The normal shell has the same
  problem; the runner's reduced environment did not cause it. No Forge
  session in the transcript installed PyYAML 6.0.3.
- Result: run-0001 is not a measurement of the gates. It is kept unchanged
  and is not reported as the Stage 10 result. It shows only that the gates
  fail closed (exit 2) on dependency drift.
- Not changed: gates, pins, labels, manifest 98df0272…
- Next check: owner choice. (a) restore the pinned state on the host (remove
  the user-site PyYAML 6.0.3 so the pinned 6.0.1 is found) and rerun the same
  manifest as run-0002; or (b) change the runner's Python path, which gives a
  new manifest hash and needs new approval.

## U175 — Host fix: user-site PyYAML 6.0.3 removed (owner choice); same manifest rerun as run-0002

- References: U174; results/stage10/host-fix-0001/.
- Owner choice (question answer): "Remove PyYAML 6.0.3 (Recommended)".
- `python3 -m pip uninstall -y PyYAML` exit 0 removed only the user-site
  6.0.3 (its RECORD kept in host-fix-0001). Python now loads the pinned
  6.0.1 from the framework site-packages; gate/dependencies.check_dependencies
  passes for all six pinned packages. Undo: pip3 install --user PyYAML==6.0.3.
- Gates, pins, labels and manifest 98df0272… unchanged. run-0002 started
  with the same --approved-manifest-sha256.
- Residual: another local tool installed on 2026-10-27 now gets PyYAML 6.0.1.

## U176 — Stage 10 run-0002: EXIT report exit 0 twice; 47/51 match; 4 unsupported false accepts; Stage 10 DONE

- References: U172–U175; results/stage10/run-0002/ (report.json 5e776f59…,
  report.md 38dcdd37…, exit-console.txt).
- Observations (primary pass; manifest 98df0272…; base 624c9faf):
  - accept 14/14 (8 valid alternatives re-proved, e.g. transfer-lemma
    checked=4, early-return checked=2); defect 8/8 VERIFICATION_REJECTED;
    policy_reject 11/11; missing_evidence 10/10 with the expected prefixes;
    tool_failure 4/4 exit 2 (missing Dafny: raw OSError text, no prefix;
    corrupt Z3 and lying checker: executable digest differs from its pin).
  - unsupported 0/4: all four exit 0 with "ACCEPTED: C1 C2 C3 C4 C5;
    checked=0; reused=12". gate/incremental.py checks only its ledger source
    scope and the protected manifest; any other file change passes silently.
    One of these PRs breaks the fee logic of the shipped ts/ledger.ts.
  - Repeat pass: 51/51 same decision, 18/18 accepted evidence byte-identical.
  - Latency: wall p50 3.2 s, p95 12.5 s; CPU total 148.8 s (primary pass).
- Result: ROADMAP rule 3 met for Stage 10 (EXIT required a complete,
  reproducible measurement, not a perfect score). Stage 10 marked DONE; no
  successor stage. end_to_end=false.
- Inference: the PR gate's "ACCEPTED" means "the ledger claims still hold",
  not "this PR is verified". A PR-level report needs a "no claim covers these
  files" result. That is a gate change for separate owner approval; it was
  not made here.
- Open points:
  - No human adjudication recorded yet. Adding adjudications.json to
    run-0002 makes exit_stage_10.py report a mismatch with the saved report,
    so adjudications need a new, separately named report version.
  - The planned EXIT's default --run names run-0001 (not established, U174);
    the official invocation used --run results/stage10/run-0002.
  - Limits: internally authored; not independent; not a real-PR shadow study;
    binary/ELF and provenance gates not covered.

## U177 — Coverage-soundness repair authorized; false accepts reproduced; candidate drafted and reviewed

- References: U176; owner messages 2026-10-30 (authorization of a minimal,
  separately reviewed repair; Phase 1–7 prompt; implementation/validation
  prompt). proposals/coverage-soundness/ (COVERAGE.md, heldout/, model/);
  results/coverage-repair/phase1-repro-0001/; candidate tree
  ~/forge-coverage-v1 (branch coverage-soundness-v1, local commits only).
- Phase 1 (observed): the four frozen Stage 10 `unsupported` cases rerun
  against the original gate at 624c9faf: each exit 0, "ACCEPTED: C1 C2 C3
  C4 C5; checked=0; reused=12", evidence written. Boundary violation:
  gate/incremental.py compares only impl/Ledger.dfy, spec/LedgerSpec.dfy,
  gate/ContractBinding.dfy and the protected manifest; every other file in
  the PR is invisible, and pr_check.py/post_pr_report.py publish the ledger
  acceptance as the PR result.
- Phase 2: COVERAGE.md defines VERIFIED / REJECTED / NOT_ESTABLISHED /
  UNSUPPORTED (exit 0/1/2/3), the invariant Verified => ProofValid ∧
  SpecApproved ∧ ArtifactBound ∧ CoverageEstablished ∧ AuthorizationValid,
  and CoverageEstablished as: every changed path is established by the
  check (impl/Ledger.dfy; spec + spec.lock only with a bound approval) and
  no reader of an established path (Dafny includes, approved spec locks, a
  trusted declared-consumer list) is left un-re-established.
- Phase 3/4 (independent adversarial review of the contract and the draft;
  18 findings, no critical/high): no path to VERIFIED for a non-identical
  tree. Mediums: C-01 VERIFIED reachable only for an empty diff (sound,
  conservative: any impl/Ledger.dfy change is UNSUPPORTED because booking,
  the TypeScript model, the Stage 5 witness and evidence.json read it);
  C-02 the Stage 4 harness scripts build partial trees (rewritten to full
  trees; expectations for ledger edits become exit 3); C-03 lock did not
  bind the PR gate (new lock adds gate/approval.py, coverage.py,
  incremental.py, pr_check.py, post_pr_report.py); C-04 a dirty base tree
  is NOT_ESTABLISHED. Fixed: C-05 report text injection (paths rendered as
  JSON literals), C-13 TOCTOU (coverage assessed before the final re-hash),
  C-14 size caps that dropped the status, C-12 __pycache__ skip (now only
  .pyc/.pyo), missing readers (gate/booking.py, tests/Basic.dfy,
  stage5_tools/typescript for spec and lock).
- Phase 6 (observed): proposals/coverage-soundness/model/Acceptance.dfy,
  pinned Dafny 4.11.0: "8 verified, 0 errors" (Safety, Terminates,
  UnsupportedRestsOnProof, ToolFailureIsNotEstablished, InvInit, InvStep,
  ExitCodesDistinct). Theorem about the model only.
- New lock 4e2abe26a40d35f37127c2a1b268b5681d6952c527a7ee1d1b3e1439d215f004
  (95 files); bootstrap --check verified; old lock 5f78da21 refused.
- Harness incident (own error): the lock was rewritten in the clone while
  check_stage_4_local.py was copying candidates; the gate rejected
  apply-edit with UNAPPROVED_PROTECTED_CHANGE on the lock. Correct gate
  behaviour; the suite was rerun after the commit.
- Open until the runs finish: regression results; held-out 16 cases
  (frozen: cases.json e69611a3…, runner b4e685a4…); frozen 51-case rerun
  (expected before/after: the 4 false accepts become UNSUPPORTED; the 4
  ledger valid alternatives become UNSUPPORTED, not accept; the frozen
  classes.json maps exit 3 to tool_failure because it predates exit 3).
  Timings in these runs were measured under concurrent load.

## U178 — Coverage candidate: regression suites, control suites and held-out cases

- References: U177; results/coverage-repair/stage4-regression-0001/,
  suites-0001/, heldout-0001/. Candidate commit b823fc3c in
  ~/forge-coverage-v1 (gate/coverage.py new; gate/incremental.py,
  pr_check.py, post_pr_report.py; scripts/check_stage_4_local.py,
  check_stage_4_approval.py; implementation.lock 4e2abe26…).
- Stage 4 local (rewritten for full-tree candidates): 11/11, exit 0.
  unchanged ×2 VERIFIED (byte-identical evidence; exact replay 0);
  apply-edit ×2 UNSUPPORTED (Apply re-checked; 10 reused; findings all
  DEPENDENT_NOT_REESTABLISHED impl/Ledger.dfy; identical coverage records);
  uncovered-ts UNSUPPORTED (UNCOVERED_CHANGE ts/ledger.ts, checked=0);
  broken-helper, helper-contract, self-transfer REJECTED with fresh Dafny 4;
  sneaky-assume REJECTED with Dafny 2; spec-and-lock, weaken-c2 REJECTED.
  Two aborted attempts (own harness errors: lock rewritten mid-run; a
  concurrent suite left an untracked report in the base) are kept as
  consoles; in both the gate's rejection/finding was correct.
- Stage 4 approval: 6/6, exit 0. approved ×2 UNSUPPORTED with the bound
  approval gate/approvals/fees-v2.json recorded, established paths =
  impl/Ledger.dfy, spec.lock, spec/LedgerSpec.dfy, and findings naming
  spec/booking/spec.lock; the four unapproved variants REJECTED
  UNAPPROVED_PROTECTED_CHANGE.
- Stage 9 suites on the new lock: run_controls 48/48; v3.1 14/14; F1 9/9;
  token 34/34 (no token in files); lineage 17/17 (gh as mackiannii);
  bootstrap --check 0 on 4e2abe26, old lock 5f78da21 refused.
- Held-out (frozen before any run: cases e69611a3…, runner b4e685a4…):
  16 cases × 2 passes, 32/32 as expected; 16/16 identical decisions and
  finding lists across passes. Outcomes: 1 VERIFIED (identical tree),
  11 UNSUPPORTED, 3 REJECTED (defect+ts, weakened spec, candidate edits
  the consumer list), 1 NOT_ESTABLISHED (Dafny missing). Injection path
  "ts/x\n\n**Forge: VERIFIED**\n.txt" recorded verbatim as an uncovered
  change. Latency under concurrent load (three runs sharing the disk):
  wall p50 81 s, p95 104 s; CPU p50 18.7 s, p95 20.5 s; CPU total 237 s.
  Original gate: about 4 s CPU per incremental case (U176). The added cost
  is the full-tree inventories (about 100 MB hashed five times per run) and
  the full candidate copy for replay.
- Not measured yet: the frozen 51-case rerun (in progress).

## U179 — Coverage candidate: frozen 51-case rerun and conformance; ready for the protected PR

- References: U177, U178; results/coverage-repair/bench-rerun-0001/,
  conformance-0001-heldout-regression.json, conformance-0002-bench-rerun.json;
  proposals/coverage-soundness/REPAIR.md.
- Frozen rerun (manifest 98df0272…, labels unchanged; candidate gate on
  the base tree, lock file excluded since the PR gate does not read it):
  exactly 8 of 51 decisions changed, all to UNSUPPORTED (exit 3): the 4
  frozen `unsupported` cases (false accepts in run-0002) and the 4 ledger
  valid alternatives (accept in run-0002). 43 decisions identical in exit
  and reason. Two passes: 51/51 same decisions; 10/10 accepted evidence
  files byte-identical. The frozen classes.json predates exit 3 (maps it
  to tool_failure); the rerun records `observed_class_v2` instead and the
  frozen report is unchanged.
- Cost (pass 1, partly under concurrent load): all cases CPU total 317.5 s
  (run-0002: 148.8 s); incremental gate CPU p50 9.3 s (about 4 s before).
- Conformance (model facts derived from operation.json, not from the
  outcome): 49 + 40 = 89 records, 0 nonconforming.
- Inference: the repair removes the false accepts and, by contract, turns
  every ledger edit into UNSUPPORTED (the dependents are real: booking's
  proof includes Ledger.dfy). Whether that conservativeness is acceptable
  is the owner's decision at review; the alternative (re-running dependent
  gates inside the PR gate) is a scope expansion not made here.
- Next: open the protected PR as mackiannii from a commit whose tree
  equals the tested tree; stop for review. No merge, no signing, no
  dispatch, no change to Stage 9/10 evidence.

## U180 — Coverage-soundness PR #27 opened by mackiannii; stopped for owner review

- References: U177–U179; results/coverage-repair/pr-open-0001.txt,
  pr-body-coverage.md.
- Checks 1–3 PASS (mackiannii 143109898; admin=false, bypass=never; helper
  token = mackiannii); check 4 residual accepted. Main 624c9faf;
  FORGE_SIGNING_AUTHORIZED=false; no active runs.
- PR #27: head 4ab56e04 (parent 624c9faf), tree 133cee25 = tested tree
  (candidate commit b823fc3c); 7 files (+388 −75); lock 4e2abe26…; review
  requested from mack-dot (gh's first attempt reported a GraphQL error; the
  REST request succeeded and the PR lists mack-dot); BLOCKED,
  REVIEW_REQUIRED. Not approved, not merged.
- Expected: the ledger proof gate on #27 reports the protected gate/**
  change without a bound approval (U148); not a required check.
- Not done, by instruction: merge, signing, dispatch, changes to Stage 9 or
  Stage 10 evidence, new research stages. end_to_end=false.

## U181 — Owner defines Stage 11: product-grade incremental verification

- References: U180; owner mission "Forge — Product-Grade Incremental
  Verification" (2026-10-30), Phases 1–8 and five success criteria.
- Recorded in ROADMAP as Stage 11 CURRENT with three planned EXITs (NOT RUN).
  PR #27 is not assumed merged; work builds on its head 4ab56e04 and will be
  rebased if #27 changes.
- Phase 1 audit (observed): each existing gate already declares and hashes
  its own input set (dafny.prepare input_paths; booking SOURCES + lock +
  policy; refund APPROVED + COMMON_INPUTS + SOURCE_FILES (+ JS inputs);
  typescript describe() inputs; incremental paths). Those declared sets, not
  a hand-written list, are the candidate basis for the dependency graph.
- Open: run times of the dependent gates; whether a candidate copy can run
  them (node_modules and .toolchain are untracked and must be provisioned).

## U182 — Stage 11 candidate built: obligation graph, verification tree, smoke results

- References: U181; proposals/incremental-verification/ (CONTRACT.md, eval/,
  model/); candidate clone ~/forge-s11 (branch stage11/incremental-verification,
  stacked on PR #27 head 4ab56e04; local commits only).
- Design (observed basis): every existing gate reports the exact input set it
  hashed (bundle trusted_input_sha256 keys ∪ source_manifest). gate/obligations.py
  declares seven obligations (ledger-proof, ledger-evidence, ledger-model,
  booking, refund-proof, refund-tests, ledger-witness) with those input sets
  and checks each run's bundle against the declaration (drift →
  NOT_ESTABLISHED). Declarations were checked against real bundles: two
  corrections made (refund gates do not hash gate/gate.py or policy/tiers.yaml;
  gate.py --check-evidence does not hash its evidence argument, now an
  explicit "argument input"). ledger-witness has no bundle: declared only.
- Affected obligations run concurrently inside an immutable copy of the
  candidate whose protected manifest equals the trusted base's, with the trusted
  base's .toolchain and node_modules linked in; inventory equality is checked
  before and after. A content-addressed cache (obligation + input digests)
  reuses an established record only for identical bytes.
- Smoke (five candidates, own harness; scratchpad s11-smoke*.log): identical
  → VERIFIED; ts/ledger.ts fee defect (a Stage 10 false accept) → REJECTED
  (ledger-model PROPERTY_REJECTED); ledger comment edit without regenerated
  evidence.json → REJECTED (ledger-evidence ARTIFACT_MISMATCH); the same edit
  with regenerated evidence → VERIFIED with ledger-evidence, ledger-model,
  booking and ledger-witness re-established (three reused from the cache
  written by the previous run: identical input bytes); behaviour-preserving
  ts edit → VERIFIED (ledger-model fresh, 7 s). Dependent obligations took
  6–22 s each.
- Defect found and fixed in the candidate: the obligation runner set
  PYTHONNOUSERSITE=1, hiding the pinned attrs in the user site
  (TOOLCHAIN_ERROR). Own harness errors: an uncommitted report edit during
  a smoke run made the gate (correctly) reject three cases; rerun.
- Model v2 (model/Acceptance.dfy, adds obligation steps): 9 verified, 0 errors.
- New lock 9e642e4a7b8adec5c9347443200ac9f21d408198c0e78d07ec4a546df555de34
  (97 files; adds gate/obligations.py and scripts/exit_stage_11.py);
  bootstrap verified on the clean tree; 4e2abe26 refused.
- Running: frozen evaluation (18 cases; cases e69… no: ceec69ca…, runner
  80d25691…; cold and warm), Stage 4 regression suites, independent
  adversarial review. Not yet done: PR #27 baseline run on the same cases,
  Stage 9 control suites on the new lock, PR.

## U183 — Stage 11 independent review: six blockers; fixes applied to the candidate

- References: U182 (correction: the held-out hashes named there belong to the
  Stage 11 eval: cases.json ceec69ca…, runner 80d25691…, later revised). Review
  by an independent agent of ~/forge-s11 (read-only; two scratch experiments).
- Blockers reported (verdicts the reviewer gave):
  F1 critical EXPLOITABLE: ledger-model's harness inputs (scripts/javascript_env.py,
  scripts/build_model.py, interop/export.cjs, interop/model.ts,
  tests/ledger.property.ts) were candidate-controlled and executed; a PR editing
  the property harness to write a "passed" report would be VERIFIED.
  F2 critical EXPLOITABLE (demonstrated in scratch): tsconfig.json `paths`
  redirects fast-check for refund-tests; same via javascript_env.py.
  F3 high EXPLOITABLE locally: planted gate/__pycache__/*.pyc replaces protected
  modules in walk mode; in CI an executed obligation could fork a process that
  outlives the step (UNCERTAIN escalation).
  F4 high: ledger-witness checked only a verified count (vacuous witness passes;
  an honest helper lemma fails).
  F5 high CONSERVATIVE: refund-proof and refund-tests race on build/refund-gate.lock
  (observed in eval-0002: e05 cold NOT_ESTABLISHED, warm VERIFIED).
  F6 high: dependent gates cannot run in the Linux CI shape (macOS pins, no node).
  Mediums: F7 cache key omitted declaration/trusted context; F8 TypeScript imports
  not modelled; F9 proposals/*-decision.md hashed but unbound. Low: exit-code
  table; strict UTF-8 decoding.
- Fixes in the candidate (commit 412a6af9, lock 65aea32b…):
  every non-subject input of an obligation must equal the trusted base's bytes
  before the run and in the recorded bundle (TRUSTED_INPUT_CHANGED → REJECTED);
  the executed harness files, tsconfig.json, package.json and package-lock.json
  are protected files; obligations run in their own sessions and are killed as a
  group; PYTHONDONTWRITEBYTECODE + private PYTHONPYCACHEPREFIX; __pycache__
  removed from the verification tree; candidate .pyc files are inventoried as
  changes; obligations do not run while any change is uncovered; ledger-witness
  now audits the witness against gate/expected-audit.md and requires named TRX
  members (Witness, Apply); refund obligations serialized (mutex); cache key
  includes the declaration, the trusted protected manifest and the pins, and
  records are stored only after the integrity re-check; output decoded with
  errors=replace. F6 and F8 are disclosed limitations (CONTRACT.md §5), not fixed.
- Evaluation runs eval-0001 (runner PATH) and eval-0002 (refund lock race) are
  kept as aborted records. The frozen cases are unchanged; the final run will be
  eval-0003 on the fixed candidate.

## U184 — Review fixes confirmed on the candidate (commit c4c45d2b, lock 8d26f3f1…)

- References: U183; results/stage11/smoke-attacks-0001.txt, -0002.txt.
- Own-harness smoke, gate from the candidate clone, candidates copied from it:
  F1 attack (fee defect + property harness rewritten to print "passed") →
  REJECTED UNAPPROVED_PROTECTED_CHANGE: tests/ledger.property.ts (nothing ran);
  F2 attack (tsconfig paths redirect fast-check + wrapper bound removed) →
  REJECTED UNAPPROVED_PROTECTED_CHANGE: tsconfig.json; F3 (planted
  gate/__pycache__/common.cpython-310.pyc + README edit) → UNSUPPORTED with the
  .pyc and README listed as uncovered changes, no obligation run; F4 (vacuous
  witness `lemma Witness() {}`) → REJECTED OBLIGATION_REJECTED ledger-witness
  PROOF_COVERAGE (SuccessfulExecution.Witness (correctness) missing);
  refund negated-branch alternative → VERIFIED with refund-proof and
  refund-tests re-established (serialized, 4.2 s + 6.8 s); ledger local
  variable rename + regenerated evidence → VERIFIED, Apply re-checked (2
  checked, 10 reused), booking 13.9 s, ledger-model 9.2 s, ledger-evidence
  4.1 s, ledger-witness 3.2 s, all fresh.
- Two more own-harness defects found and fixed before this run: the saved
  replay input's bytecode check (REPRODUCTION_INPUT when a candidate carried
  .pyc), and a relative TRX path the checker did not write (NOT_ESTABLISHED,
  fail-closed). The eval runner's evidence regeneration no longer leaves
  bytecode in candidates (runner hash e5c7fdcf…; cases unchanged).
- Model v3 (covered-first order): 10 verified, 0 errors.
- Running: eval-0003 (frozen cases), Stage 4 suites, Stage 9 control suites
  on lock 8d26f3f1…; re-review requested.

## U185 — Second review: N1 critical (subject runs inside the harness); fixed by binding; eval restarted

- References: U183, U184; reviewer's second pass (read-only).
- Status reported: F1, F2, F3 (hijack), F5, F9, F11 closed; F4 partially (vacuous
  witness body still a subject); F6 and F8 disclosed; F7 partially (local
  persistent cache writable by the same uid); F10 open (low).
- New N1 (critical, EXPLOITABLE): tests/ledger.property.ts requires ts/ledger.ts
  and gate/refund/hostile.ts imports ts/refund.ts into the harness process; a
  changed subject can install process 'exit' handlers that write the expected
  report shape and set exit 0, so a one-file PR to ts/ledger.ts or ts/refund.ts
  would be VERIFIED with tested_against_proved_model / property_tested claims.
  N2 (medium): a rewritten witness body `method Witness() {}` still passes the
  named-member check. N3 (medium): TypeScript imports unmodelled. N4 (low):
  binding check followed symlinks. N5/N6/N7 info.
- Fix chosen (smallest sound; commit 9e000c26, lock 07d9e9a9…): in-process
  TypeScript subjects (ts/ledger.ts, ts/types.ts, ts/refund.ts) and the Stage 5
  witness file are bound inputs, not subjects; a change to them is UNSUPPORTED
  with finding NOT_REESTABLISHABLE and no obligation runs. ledger-model and
  refund-tests still re-establish their claims when the Dafny side changes
  (trusted-base TypeScript tested against the recompiled candidate model).
  binding_violations rejects symlinks. Consequence: useful acceptance is
  limited to the Dafny side until the harnesses isolate the subject in a child
  process (next engineering item, disclosed in CONTRACT.md §5). Frozen eval
  expectations for e03, e07, e10, e12, e18 (TypeScript or witness subjects)
  will not match and are reported as mismatches, not relabelled.
- eval-0003 aborted and kept (eval-0003-aborted-n1-fix). Running: eval-0004,
  Stage 4 suites, Stage 9 control suites on 07d9e9a9…; third review pass.

## U186 — Third review: no soundness blockers; EXIT script and contract aligned; regression final

- References: U185; reviewer's third pass (read-only).
- Status reported: N1–N4 closed. Compiled Dafny from an audited, verified impl
  can print, read process.argv, run at load (Main) and halt with exit 1; it
  cannot read or write files or set exit 0, so it cannot change a verdict.
  Residual: resource exhaustion → timeout → NOT_ESTABLISHED. P1 (medium): the
  EXIT script and frozen cases predate the binding rule; P2/P3/P5 wording;
  P4 cosmetic (left; keeps gate bytes identical to the evaluated tree).
- Applied: scripts/exit_stage_11.py requires e02, e04, e05 VERIFIED and the
  bound-subject cases UNSUPPORTED (e06 REJECTED: the property harness is
  protected); frozen expectations for e03, e06, e07, e10, e12, e18 are kept
  and reported as superseded by the design change, not edited. CONTRACT.md
  rows and wording fixed. Candidate commit 200d101f, lock c7a3139d…; gate/*.py
  byte-identical to the tree under evaluation (eval-0004).
- Stage 4 suites on the final gate: local 13/13 (apply-edit ×2 REJECTED by
  ledger-evidence; apply-edit-regen VERIFIED with four obligations
  established; uncovered-ts UNSUPPORTED NOT_REESTABLISHABLE; uncovered-docs
  UNSUPPORTED; 6 REJECTED with the original fresh-Dafny codes); approval 6/6
  (approved ×2 UNSUPPORTED with all obligations established and
  UNKNOWN_DEPENDENCY on bugs/ and proposals/ readers). Conformance over the
  19 final regression traces: 0 nonconforming. Own-harness smoke of the N1 fix:
  ts fee bug and vacuous witness UNSUPPORTED (NOT_REESTABLISHABLE); the
  legitimate-rename smoke case was contaminated by a stray untracked report
  file in the clone (flagged as uncovered: correct), so it is superseded by
  eval-0004 e02 (VERIFIED, five obligations).
- Running: eval-0004; control suites on c7a3139d…; reviewer's final check.

## U187 — Disk-full incident; final lock 50f56592; control suites pass

- References: U186; results/stage11/suites-0004/.
- Observation: the data volume reached 100 % during eval-0005 and the control
  rerun (ENOSPC); the harness could not start commands. Causes: scratch copies
  from the gate runs (replay inputs, smoke and eval work trees) plus 26 unused
  anonymous Docker volumes. Owner approved: Docker volume prune (9.8 GB), the
  Stage 7 upstream volume forge-stage7-upstream-bf6a65114ed2 and unused images
  (Stage 7 records stay in results/stage7 archives; the Stage 9 evidence
  containers and their two images were kept), and deletion of my scratch
  trees. Free space after: 25 GB. Runs that died of ENOSPC are kept as aborted
  records (eval-0005-aborted-disk-full, eval-pr27-0001-aborted-disk-full,
  suites-0004/controls-attempt2-disk-full); none is evidence of a gate result.
- Final candidate: commit 946e2446, lock 50f56592… (adds scripts/exit_stage_11.py
  revision). gate/*.py bytes unchanged since 9e000c26 (the tree under
  evaluation). Control suites on 50f56592: 48/48 (after a transient git exit
  128 under disk pressure and the ENOSPC attempt, both kept), v3.1 14/14, F1
  9/9, token 34/34, lineage 17/17.
- Eval cases.json e12 has an edit anchor that belongs to the booking witness,
  not the Stage 5 witness (own authoring error, frozen): the runner now
  records it as not constructible; it is evidence of nothing and is excluded
  from the stale-dependency EXIT with a printed note.
- Running: eval-0006; then the PR #27 baseline on the same cases.

## U188 — INCIDENT: eval runner deleted the real pinned Dafny through a symlink; restored and verified

- References: U187; proposals/incremental-verification/eval/FROZEN.json (runner
  revisions); results/stage11/eval-0006-superseded-reader-edge-fix/.
- Observation: run_eval.py linked /Users/mackianni/forge/.toolchain into each
  case root; frozen case e17 ("Dafny missing", root_changes: delete
  .toolchain/dafny-4.11.0/dafny/dafny) followed the link and deleted the real
  pinned executable. e18 then failed with "dafny: No such file" instead of the
  node_modules error, which exposed the deletion. Own harness defect; not a
  gate behaviour. No other real toolchain file was touched (e18 only unlinked
  a root symlink; no other delete op exists in the cases).
- Restoration: copied the byte-identical file from ~/forge-coverage-v1/.toolchain
  (an APFS clone of the toolchain made earlier); sha256 5d02cbb8… equals
  toolchain/pins.json; `dafny --version` 4.11.0+fcb2042d…; Z3 pin also
  verified. The runner now clones the toolchain into each root and refuses
  delete ops through symlinks (runner hash 319b65cd…; cases unchanged).
- eval-0006 (18 cases) completed before the fix and showed: e01, e02, e04,
  e05 VERIFIED (e02 cold 29.5 s with five obligations; warm 11.5 s); e08, e09
  REJECTED by obligations; e11 REJECTED; e13, e15, e16 UNSUPPORTED; e17
  NOT_ESTABLISHED; e03, e07, e10 UNSUPPORTED and e06 REJECTED (design change);
  e12 not constructible; e14 UNSUPPORTED but without the expected
  UNKNOWN_DEPENDENCY finding; e18 NOT_ESTABLISHED for the wrong reason (the
  deleted Dafny). Kept as superseded.
- Gate defect found by e14: dafny_dependents() skipped a reader that was
  itself a changed path (seen set initialised with the targets), so a new
  Dafny file that includes a changed covered file was not reported as an
  unknown dependency. Fixed in gate/coverage.py (commit 8433ddc5, lock
  4e9e7e54…); outcome in e14 was already UNSUPPORTED (the new file is
  uncovered), so no false accept resulted.
- Running: eval-0007 (final gate, fixed runner), PR #27 baseline, control
  suites on 4e9e7e54…, Stage 4 suites.

## U189 — Runner delete guard tested on a disposable fixture; live roots verified

- References: U188; results/stage11/runner-guard-test-0001/ (fixture).
- Test of the fixed run_eval.py apply(): a delete under a symlinked
  .toolchain raised "refusing to delete through a symlink" and the real
  fixture file stayed; the same delete in a copied .toolchain removed only
  the copy. Live eval-0007 and PR #27 baseline case roots carry real
  .toolchain directories (APFS clones), not links. The real pinned Dafny is
  present and matches its pin.
- Owner's recovery sequence (preserve logs; verify pins; fix runner; test on
  a disposable fixture; rerun in isolation) is complete except the reruns,
  which are in progress.

## U190 — Stage 11 EXITs passed on the recorded host; frozen evaluation and baseline recorded

- References: U181–U189; results/stage11/eval-0007/, eval-pr27-0003/,
  exit-console.txt; proposals/incremental-verification/REPORT.md.
- EXITs (candidate 8433ddc5, lock 4e9e7e54…): legitimate-change 0;
  stale-dependency 0 (e12 excluded: not constructible); report 0 twice with
  byte-identical report.json 865f0000… and report.md 15dd582f….
- Frozen evaluation: 18 cases; match 12; false accept 0; false reject 0;
  false unsupported 0; 5 frozen expectations superseded by the post-freeze
  binding rule (e03, e06, e07, e10, e18; kept, not edited); 1 not
  constructible (e12). e02 (ledger rename + regenerated evidence), e04
  (booking alternative), e05 (refund alternative) VERIFIED; all three
  UNSUPPORTED under PR #27. Cold wall p50 13.6 s / p95 39.1 s; warm 7.4 s /
  26.1 s; CPU total 258 s cold, 133 s warm; 18/18 same decisions; reuse in 4
  cases never changed a decision.
- Conformance: 34 eval traces + 19 regression traces, 0 nonconforming.
- Inference on the owner's five criteria: (1) reject unsupported: evidence,
  no false accept, three review passes; (2) accept legitimate non-empty
  changes: yes for the Dafny side; TypeScript changes UNSUPPORTED by design;
  (3) explain scope: per-obligation table in the PR report; (4) ordinary PR
  workflows: locally yes (seconds), in CI no (macOS pins, no node) — not met;
  (5) reproducible: two runs, identical decisions, byte-identical report.
  ROADMAP marks Stage 11 DONE on the recorded host with criterion 4 stated as
  not met; the owner may reclassify at review.
- Not rerun: the 51 Stage 10 cases under Stage 11 (frozen classes.json
  predates exit 3; ledger alternatives would need regenerated evidence);
  disclosed in ROADMAP.
- Next: protected PR as mackiannii stacked on PR #27's branch; stop for
  review. No merge, no signing, no change to Stage 9/10 evidence.

## U191 — Stage 11 PR #28 opened by mackiannii, stacked on PR #27; stopped for review

- References: U190; results/stage11/pr-open-0001.txt, pr-body-stage11.md.
- Checks 1–3 PASS; check 4 residual accepted. Main 624c9faf; PR #27 open at
  4ab56e04 (its branch gate/coverage-soundness-v1); signing variable "false";
  no active runs.
- PR #28: head a8dee75f (parent 4ab56e04), tree caaf0554 = tested tree
  (candidate commit 8433ddc5); 8 files (+838 −118); lock 4e9e7e54…; base
  gate/coverage-soundness-v1 so the diff shows only the Stage 11 change.
- Observation: the review request through the REST API failed with
  "Could not add requested reviewers" on this base; a second attempt is
  recorded in pr-open-0001.txt. The main ruleset (owner review, squash
  only) applies to PRs into main; a PR into another branch may not carry the
  same protection. Not merged and will not be merged by the agent. After #27
  merges, retarget #28 to main so the ruleset applies before any merge.
- Not done, by instruction: merge, signing, dispatch, changes to Stage 9/10
  evidence, new research stages. end_to_end=false.

## U192 — Owner review of PR #28 verified on the exact head; PR #27 still unreviewed; no merge

- Date: 2026-10-30. Refs: U165 (approval protocol), U176 (PR #27), U191 (PR #28).
- Owner message in chat: "approved" (no PR number). Verified through the API as
  `mackiannii` (read-only): PR #28 has one review by `mack-dot`, state APPROVED,
  commit `a8dee75ff22d5bd975dff02e8abefc2d82ae1334` = current head, submitted
  2026-10-30T13:03:32Z. PR #27 (head `4ab56e04`, base main) has zero reviews and
  mergeable_state `blocked`. main = `624c9faf`. `FORGE_SIGNING_AUTHORIZED=false`.
- Not done: no merge. A chat "approved" is a review approval, not a merge
  authorization (U165); the owner gives each merge its own authorization.
- Dependency: PR #28's base is PR #27's branch `gate/coverage-soundness-v1`, which
  has no ruleset. Merging #28 before #27 would rewrite #27's head (its branch would
  then carry the Stage 11 change), invalidate any future review of #27 at `4ab56e04`,
  and merge outside the owner-review rule. Order that keeps the rule: owner reviews
  and authorizes the merge of #27 at `4ab56e04`; after #27 is in main, retarget #28
  to main (its head stays `a8dee75f`, review stays valid); then separate merge
  authorization for #28.
- Next check: reviews on PR #27 at `4ab56e04`.

## U193 — Merge authorization for PR #27 received in chat; held because no GitHub review exists

- Date: 2026-10-30. Refs: U165, U192.
- Owner messages: "approved", then "authroized". API as `mackiannii` (read-only):
  PR #27 head `4ab56e04`, reviews = 0, reviewDecision REVIEW_REQUIRED,
  mergeable_state blocked. Check `verify` = failure, expected for a `gate/**`
  change (U148); the main ruleset requires a pull-request review, not status checks.
- Not done: no merge. The protocol (U165) needs an owner review on the exact head
  before a merge authorization is acted on; the ruleset would also refuse the merge.
- Next check: reviews on PR #27 at `4ab56e04`; then merge on "authorize merge #27".

## U194 — PR #27 merged into main at 0bf31d9f; PR #28 retargeted to main, now conflicting; rebase push not performed

- Date: 2026-10-30. Refs: U176, U191, U192, U193.
- Owner review on PR #27 verified through the API: `mack-dot` APPROVED at exact head
  `4ab56e04` (2026-10-30T14:07:20Z, review 5713497921). Owner merge authorization
  given in chat ("authroized", reaffirmed "i did").
- Merge as `mackiannii` (checks 1–3 passed, bypass=never): `gh pr merge 27 --squash
  --match-head-commit 4ab56e04`, exit 0, 2026-10-30T14:17:14Z. main =
  `0bf31d9f86208c8bf0736a61439f86177c260b99`, parent `624c9faf`, tree `133cee25` =
  approved head tree; 7 files; lock on main `4e2abe26a40d35f37127c2a1b268b5681d6952c527a7ee1d1b3e1439d215f004`.
  Record: results/coverage-repair/merge-27-0001.txt. `FORGE_SIGNING_AUTHORIZED=false`.
- PR #28 retarget: `gh pr edit --base main` failed with a GraphQL server error; the
  REST PATCH succeeded. Effects: the ruleset dismissed the owner's approval (stale on
  base change), reviewDecision REVIEW_REQUIRED, mergeable_state `dirty` (the branch
  still carries the pre-squash commit `4ab56e04`; GitHub reports a conflict with the
  squash commit), 9 files shown instead of 8.
- Fix prepared, not executed: cherry-pick `a8dee75f` onto `0bf31d9f` (tree must equal
  the tested tree `caaf0554`; content must equal `a8dee75f`) and force-push the PR
  branch only (`--force-with-lease` on the known head). The run was refused by the
  session's permission classifier (force push). Script:
  scratchpad `rebase28.sh`. Alternative without a force push: push the rebased
  commit to a new branch and open a new PR that supersedes #28.
- Not done: merge of #28; signing; dispatch; changes to Stage 9/10 evidence.
- Next check: owner chooses rebase-and-force-push of `stage11/incremental-verification`
  or a new PR; then owner review on the new exact head; then separate merge
  authorization.

## U195 — Replacement Stage 11 PR #29 opened on exact main 0bf31d9f; PR #28 branch untouched; not merged

- Date: 2026-10-30. Refs: U191, U194. Owner instruction: "new PR"; no force push; do
  not modify the #28 branch; verify tree, lock and that recorded results still apply.
- As `mackiannii` (checks 1–3 passed, bypass=never, `FORGE_SIGNING_AUTHORIZED=false`):
  branch `stage11/incremental-verification-v2` from `main` `0bf31d9f`; `cherry-pick -x
  a8dee75f` → head `c00b85da9d22f5e05626a3d3e25845d338230f6d`, parent `0bf31d9f`.
- Verification before push: tree `caaf0554ef39fe7a5721f8d7d091c779674fedaf` = tree of
  `a8dee75f` = tree of the tested candidate `8433ddc5`; `git diff a8dee75f c00b85da`
  empty; diff vs main 8 files +838 −118 (same as #28); lock sha256
  `4e9e7e54f8cf9bf5b28889a9340c6b764175efdf1a3c9d0c391eb998c81983ed`;
  `bootstrap.py --implementation-sha256 <new> --check` → BOOTSTRAP_VERIFIED exit 0; old
  lock `4e2abe26…` → IMPLEMENTATION_LOCK exit 1. Because the tree is byte-identical to
  the tested tree, every recorded result on `8433ddc5` (eval-0007, eval-pr27-0003,
  suites-0005, conformance, smoke attacks, Stage 11 EXITs) applies to this head
  unchanged; nothing was rerun. Record: results/stage11/pr-open-0002.txt.
- Plain push (no force); PR #29 https://github.com/mack-dot/forge/pull/29, base main,
  8 files; REST reviewer request failed 422 (as for #28), `gh pr edit --add-reviewer
  mack-dot` succeeded; reviewDecision REVIEW_REQUIRED, mergeStateStatus BLOCKED (ruleset
  applies). Comment posted on #28 pointing to #29; #28 left open, branch still
  `a8dee75f`. Expected: check `verify` fails on #29 (gate/** change, U148).
- Not done: merge; signing; dispatch; Stage 9/10 evidence changes; closing #28 (owner's
  call).
- Next check: owner review on PR #29 at exact head `c00b85da`; then separate merge
  authorization.

## U196 — Owner review of PR #29 verified on the exact head; merge awaits separate authorization

- Date: 2026-10-30. Refs: U165, U195.
- API as `mackiannii` (read-only): PR #29 head `c00b85da9d22f5e05626a3d3e25845d338230f6d`,
  review by `mack-dot` (id 235131950) APPROVED on that commit, 2026-10-30T14:39:01Z,
  review id 5713886773; reviewDecision APPROVED; mergeable_state `unstable` (check
  `verify` fails as expected for a gate/** change, not required by the ruleset).
  main = `0bf31d9f`. `FORGE_SIGNING_AUTHORIZED=false`.
- Not done: merge. Awaiting the owner's separate merge authorization for #29 (U165).
- Next check: on "authorize merge #29", re-verify head and review, then squash merge
  with `--match-head-commit c00b85da`.

## U197 — PR #29 (Stage 11) merged into main at 4e4112c6; main tree = tested tree caaf0554

- Date: 2026-10-30. Refs: U195, U196. Owner merge authorization: "go" in reply to the
  request for "authorize merge #29".
- As `mackiannii` (checks 1–3 passed, bypass=never, `FORGE_SIGNING_AUTHORIZED=false`):
  re-verified head `c00b85da` and owner APPROVED review on it; `gh pr merge 29 --squash
  --match-head-commit c00b85da` exit 0 at 2026-10-30T15:22:33Z. main =
  `4e4112c677ec79c66f191a068f259e85c20953d3`, parent `0bf31d9f`, tree
  `caaf0554ef39fe7a5721f8d7d091c779674fedaf` = tested candidate tree; 8 files; lock on
  main `4e9e7e54f8cf9bf5b28889a9340c6b764175efdf1a3c9d0c391eb998c81983ed`. No active
  workflow runs. Record: results/stage11/merge-29-0001.txt.
- PR #28 left open with head `a8dee75f` (owner's call to close). Approved lineage from
  the ratified baseline now: 4e4112c6 → 0bf31d9f → 624c9faf → … → 19c4896b.
- Not done, by instruction: signing, release, dispatch, protected-main installation,
  Stage 9/10 evidence changes, new stages. The installed gate on CI still runs the old
  lock until the owner authorizes installation; CI `verify` on gate/** PRs keeps failing
  until then (U148).
- Next check: owner decision on installing lock 4e9e7e54 into the controller / CI, and on
  Linux pins for the dependent gates (CONTRACT.md §5).

## U198 — Operational readiness, step 1: main, lock and controller state verified; controller not updated

- Date: 2026-10-30. Owner mission: "Continue Forge operational readiness from merged Stage 11 main."
- Verified (read-only): GitHub main `4e4112c677ec79c66f191a068f259e85c20953d3`, tree `caaf0554…`;
  lock on main `4e9e7e54…`. Fresh clone `~/forge-main`: `bootstrap.py --implementation-sha256
  4e9e7e54… --check` → BOOTSTRAP_VERIFIED exit 0; old lock `4e2abe26…` → exit 1.
  `FORGE_SIGNING_AUTHORIZED=false`. CI `verify` on PR #29 ran the Linux pinned toolchain
  (PINNED_LINUX_TOOLCHAIN_READY) and the base gate correctly REJECTED the gate/** change
  (UNAPPROVED_PROTECTED_CHANGE, U148 class); CI now trusts main = Stage 11 for new PRs.
- Controller (Stage 9 hosted signing): the last controller rows (read-only sqlite in
  `~/forge-stage9-signing-000{1,2,3}/controller/controller.sqlite`) bind locks
  `9bf8f905` (pending), `a177cb07` (consumed) and `5f78da21` (consumed, source `624c9faf`,
  package `d9e9fb40…`). **No controller row exists for lock `4e9e7e54` or source
  `4e4112c6`.** The controller has not been updated for Stage 11; doing so needs the
  separately approved signing path, which stays off. The local records working copy
  `/Users/mackianni/forge` still carries gate files at lock `5f78da21` (v3.6); it is a
  records directory, not a trusted base, and was not changed.

## U199 — PR #28 closed without merging; branch retained

- As `mackiannii`: comment then `gh pr close 28` at 2026-10-30T20:01:33Z; state closed,
  merged=false, branch `stage11/incremental-verification` still at `a8dee75f`.
  Record: results/stage11/close-28-0001.txt.

## U200 — Disk and Docker audit (read-only); 25 GB of regenerable gate scratch identified

- Record: results/ops-readiness/disk-docker-audit-0001.md. Free space 14 GiB (97% used).
  `/Users/mackianni/forge/build/` holds 25 GB: four `stage9-integrity-*tests*` work
  directories (6 GB each) and `stage9-receipt-candidate-0001` (1.4 GB). Their result records
  are on GitHub main (`results/stage9/integrity-repair-preparation/`); the work directories are
  fixture tree copies, not evidence. Docker: both 3 GB images are Stage 9 evidence packages
  (image id = controller `package_sha256`), four labelled containers are evidence contexts;
  11 never-started containers (0 B) and the buildx `forge-pinned` state volume (4.3 GB cache)
  are deletable; postgres/redis resources belong to another project. Nothing deleted.
- Next check: owner approval of the specific deletions listed in the audit record.

## U201 — Records durability gap: Stage 9 (v3.4–v3.6), 10, 11 and coverage-repair records exist only on this Mac

- GitHub main lacks results/stage10, results/stage11, results/coverage-repair,
  proposals/incremental-verification, proposals/coverage-soundness and 55 results/stage9
  folders; its unsure.md and ROADMAP.md are older than the local files. No Time Machine
  destination is configured. The records directory is not a git working tree.
- Curated text records (json/md/txt/log/jsonl/py/dfy, ≤2 MB, excluding repository copies):
  10 061 files, 27 MB — a records PR of this size is feasible; the repository copies inside the
  control-suite folders (7 GB) are reproducible from pinned commits and would stay local.
- Impact: a disk failure loses the Stage 10/11 evidence and the Stage 9 v3.4–v3.6 records.
  Proposed: open a records-only PR (non-protected paths) before any cleanup; owner decides.

## U202 — Linux profile candidate built, verified on a fresh Linux container, opened as PR #30; not merged

- Date: 2026-10-30. Refs: U198–U201; CONTRACT.md §5 "CI shape".
- Candidate `561d2dda904daf18f17a0fede93f28b502d72884` (tree `4d106778…`, parent main
  `4e4112c6`), 13 files +187 −46, lock `ac883083f6326b9d017f3228966f235c1108b05f4129f81c0de8020e1c127f1a`
  (bootstrap VERIFIED on a clean export; old lock refused). Design: host-profile pin table in
  gate/common.py; Linux JavaScript pins observed inside the container (results/ops-readiness/
  linux-pins-0001); evidence.json regenerated (four bound gate files changed); profile-bound
  committed evidence → ledger-evidence NOT_ESTABLISHED (EVIDENCE_PROFILE).
- macOS regression on the final tree: Stage 4 local 13/13 (LOCAL_CONTROLS_PASSED), approval 6/6
  (results/ops-readiness/stage4-*-macos-final.txt). An earlier run failed with REVISION_ERROR
  because the working tree was uncommitted (own harness error; stage4-local-macos-0001.txt kept).
- Fresh Linux (ubuntu-22.04 amd64 container, pinned Python/pip/Dafny/Z3/Node, npm ci):
  identical VERIFIED; booking alternative VERIFIED (booking re-proved); refund alternative
  VERIFIED (refund-proof + refund-tests, warm reused); ledger rename without regenerated
  evidence NOT_ESTABLISHED (EVIDENCE_PROFILE; booking, ledger-model, ledger-witness established).
  Cold wall 26–150 s (median 87), warm 33–85 s (median 49); CPU 29–171 s; peak RSS 236–322 MB;
  evidence identities identical cold vs warm. Records: results/ops-readiness/linux-0001/,
  REPORT.md.
- Not independently generalizable: container on the owner's Mac; OS libraries recorded, not
  pinned; package digests from one pinned install; npm 11.4.2 (bundled) vs engines 11.10.0
  (not checked by the gate; recorded).
- PR #30 https://github.com/mack-dot/forge/pull/30 opened as `mackiannii` (checks 1–3; plain
  push of new branch ops/linux-profile-v1); reviewer mack-dot requested; REVIEW_REQUIRED,
  BLOCKED. Expected: CI `verify` REJECTED (gate/** change, U148 class).
- Not done: merge; .github workflow Node step (B2); per-profile evidence (B3); controller
  update (B4); records PR (B5); deletions (B6). All listed with the smallest protected change
  in results/ops-readiness/REPORT.md §4.
- Next check: owner review on PR #30 at exact head `561d2dda`; owner decisions on B2–B6.

## U203 — Verified records backup (raw + sanitized), PR #30 review package, deletion proposal, Linux CI steps

- Date: 2026-11-01. Refs: U200–U202. Owner mission: evidence preservation first, then Linux readiness.
- Backup set: 10 160 text records (Stage 9 local-only folders ×55, Stage 10, Stage 11,
  coverage-repair, ops-readiness, both proposals, bench, ROADMAP.md, unsure.md, AGENTS.md);
  295 repository-copy directories and files > 2 MB excluded (reproducible; list kept).
  Secret scan (values never printed): no GitHub/AWS/Slack/JWT/private-key patterns; two
  Bearer/Authorization matches in results/stage9/v35-audit-0001/probe-variant-a.py are
  synthetic placeholders in a probe script; home path `/Users/mackianni` in 2 501 files;
  Keychain item name in 4 files (name only, no value); emails: docker@example.com and the
  owner's noreply address. Raw archive `/Users/mackianni/forge-backups/forge-records-raw-2026-11-01.tar.xz`
  sha256 `e2491743d39ee0fad290c34c558b3f147e4a72125e72171615cee49674f2986b` (exact bytes, per-file
  manifest `d2f6313b…`); sanitized archive (`/Users/mackianni` → `$HOME`, 2 501 files changed,
  raw↔sanitized hash map in its manifest) `ac84dd27cfe9b7a57f1eb085fd37d06df787d7dddc7f9b94fe52c06c92996570`.
  Both re-extracted: 0 hash mismatches, embedded manifests equal. **Still on the same disk**: the
  owner must copy `~/forge-backups/` off-machine; no off-machine copy was made (no destination).
  Record: results/ops-readiness/backup-2026-11-01/.
- PR #30 review package: results/ops-readiness/pr30-review/PR30-REVIEW.md (+ full patch, lock
  delta verified against tree blobs: 9 changed, 3 added, 100 entries; pin summaries; CI status:
  verify REJECTED as expected for gate/**). Posted as a comment on PR #30
  (issuecomment-6559540216). Head unchanged `561d2dda`; REVIEW_REQUIRED; not merged.
- Deletion proposal (nothing deleted): results/ops-readiness/DELETION-PROPOSAL.md — Tier 1 five
  exact `build/stage9-*` paths = 25.3 GiB, referenced only by name in 7 GitHub-tracked records;
  Tier 2 Docker 0 B–4.3 GB; Tier 3 scratch clones (keep ~/forge-linux until PR #30 merges;
  keep ~/forge-coverage-v1 Dafny copy; copy controller.sqlite files before touching signing clones).
- Linux CI steps: results/ops-readiness/LINUX-CI-STEPS.md — PR #30, then the Node workflow step
  (protected .github/), then profile-specific committed evidence (`evidence-linux.json`,
  design decision), then a first genuine booking-edit PR.
- Not done, by instruction: merge; workflow change; signing; deletions; off-machine copy.
- Next check: owner copies the backup off-machine; owner review on PR #30 at `561d2dda`;
  owner tier approvals for deletions; owner decision on evidence-linux.json design.

## U204 — GitHub status checked; Stage 11 merged, Linux PR still awaits review

- Date: 2026-11-02. Refs: U197–U203. Scope: user-requested status check only.
- Evidence: connected GitHub API reads confirm main at
  `4e4112c677ec79c66f191a068f259e85c20953d3`; #27 and #29 merged; #28 closed
  without merge. PR #30 remains open at `561d2dda904daf18f17a0fede93f28b502d72884`.
  The review API returned no reviews. `gh pr view 30 --repo mack-dot/forge
  --json number,url,headRefOid,reviewDecision,mergeStateStatus,statusCheckRollup`
  exited 0: REVIEW_REQUIRED, BLOCKED, verify FAILURE, report SUCCESS.
- Latest run: https://github.com/mack-dot/forge/actions/runs/41125456987.
  Connected job-log read for job 124302708053 shows PINNED_LINUX_TOOLCHAIN_READY,
  then UNAPPROVED_PROTECTED_CHANGE, gate exit 1. This is a protected-change
  rejection, not a passing proof or evidence of a dependent-proof failure.
  The connector's commit-run lookup returned no runs because it filters for
  pull_request events; `gh run list` confirmed the pull_request_target run.
- GitHub main's ROADMAP.md still says CURRENT Stage 9. Local Stage 11 status
  prose also contains historical statements that the candidate awaits merge;
  U197 and today's live merge records supersede those statements. This directory
  is a records directory: `git status --short --branch` exited 128 (not a git
  repository), consistent with U201. No source synchronization was attempted.
- Impact: code has advanced beyond the published execution record. The first
  Linux CI proof is still pending. U203 records only same-disk backups; an
  off-machine copy was not verified in this check.
- Uncertainty: no EXITs were rerun, no full code review was performed, and no
  current signing/controller or off-machine backup state was checked.
- Next check: preserve the curated records off-machine and prepare their
  publication; obtain exact-head review for #30; after its authorized merge,
  review the pinned Node workflow step and run a genuine booking-change PR.
  Ledger changes additionally need the per-profile evidence design in
  results/ops-readiness/LINUX-CI-STEPS.md. No stage transition or GitHub mutation.

## U205 — Authorized integration review stops at missing PR #30 approval

- Date: 2026-11-02. Refs: U197–U204. Owner mission: Linux CI integration and
  verified incremental execution, Phases 0–5; stop at Phase 1 if approval is
  missing; no Stage 12, signing-policy change, deletion or approval bypass.
- Fresh evidence: check_archives.py exited 0. Both November 1 archives and
  manifests match the recorded digests; 10,160 members each, no hash/size
  mismatches, embedded manifests and raw-to-sanitized map match. No contents
  printed. Copies reside on internal /dev/disk3s5. tmutil exited 0 but reported
  no destinations. An independent copy is not established; a manual remote
  copy remains unknown. Prepared copy_backup.sh and BACKUP-PROCEDURE.md;
  sh -n exited 0, transfer NOT RUN (no destination). The archives are curated
  text records, not the entire Stage 9 freeze or this session's new records.
- Fresh GitHub reads: #30 head 561d2dda904daf18f17a0fede93f28b502d72884, base
  4e4112c677ec79c66f191a068f259e85c20953d3, tree
  4d10677833ac3b8a407a92c95460125915a9cc55. Zero reviews and review threads;
  open, unmerged, BLOCKED. Visible active ruleset requires one code-owner
  approval and last-push approval, dismisses stale reviews, requires resolved
  threads and squash merges; no required-status rule in that ruleset.
  Classic protection read returned HTTP 403; full required checks remain
  unverified. CLI collection/retries had connection errors (exit 1); one
  direct gh pr view exited 0. Connected APIs supplied the retained records.
- Fresh source checks: 100/100 locked file hashes match exact commit blobs;
  9 changed entries, 3 added Linux pin files, none removed. Lock ac883083…
  equals GitHub bytes. Workflow and bootstrap equal base. Committed evidence
  changes only four trusted gate-input digests. Clean-export bootstrap with
  ac883083… exited 0; previous lock 4e9e7e54… exited 1, IMPLEMENTATION_LOCK.
  This establishes integrity only, not Linux proof execution or approval.
- Scoped source review: coverage, input and artifact binding checks retained;
  profile mismatch does not accept; release admission/signing code unchanged.
  No accepting-path defect established by inspection. This is not a fresh
  adversarial regression suite or independent threat-model validation.
- Historical CI log fetched now: run 41125456987, verify gate exit 1,
  UNAPPROVED_PROTECTED_CHANGE; receipt commands empty. Report job success
  publishes rejection. Observed job elapsed: 31 s + 18 s = 0.8167 minutes;
  run elapsed 57 s. Billing API zero is not zero runner use. No comparable
  cold/warm/invalidated proof timings; discovery time and startup remain unknown.
- Impact: success criterion NOT ESTABLISHED. Phases 2–5 execution held by the
  explicit Phase 1 stop. Linux ledger and booking A/B/C NOT RUN. Existing Node
  proposal inspected but no workflow edit. Cache remains local to a job;
  in-job replay can use trusted receipts, but cross-job reuse is not established.
- Records: results/ops-readiness/integration-2026-11-02/STATUS.md,
  SESSION-COMMANDS.json, source-integrity.json, bootstrap-results.json,
  archive-check.json, API snapshots and evidence-manifest.sha256.
- Next check: independent destination/read-back; mack-dot exact-head approval
  of #30 and separate merge authorization, then re-check all protection rules.
  Defer Stage 12. No stage transition, merge, GitHub write, signing or deletion.
- Record packaging: initial manifest command used the wrong relative path
  (Python exit 1, shasum exit 2). Corrected directory selection: manifest
  generation and all 47 file checks exited 0. This was a report-packaging
  error, not a checker result; retained in SESSION-COMMANDS.json.

## U206 — Correction to U205's record-file count

- Evidence: the successful manifest command checked **52 files**, not 47.
  All 52 returned OK. Manifest SHA-256:
  `894efdf00de69930c85535b777e81af10d62623bd055d92bf14b29579281eb0e`.
- Impact: U205's packaging sentence contains a transcription error only;
  archive member counts, source checks and proof status do not change.
- Uncertainty and next check: off-machine preservation and exact-head review
  remain pending as stated in U205. No additional execution is claimed.

## U207 — Phase 1 review continued; narrow Node and observation proposals prepared

- Date: 2026-11-02. Refs: U202–U206. Owner authorizes continued review,
  protection/backup checks, smallest integration proposal and executable test
  definitions. No Stage 12, approval, merge, deployment, signing-policy change,
  branch-protection change or SPM work is authorized or performed.
- Fresh GitHub reads: #30 still at 561d2dda904daf18f17a0fede93f28b502d72884,
  base 4e4112c677ec79c66f191a068f259e85c20953d3; zero reviews, blocked/unmerged.
  verify still failure and report success from historical run 41125456987.
  Main branch summary reports classic protection enabled=false and required
  checks off/empty. Rulesets including parents lists only active 26065125,
  which requires human approval but no status checks. Full classic endpoint
  still returns HTTP 403. Complete administrator settings remain unverified;
  an authorized administrator must supply read-only protection/effective-rule
  exports. No access escalation through owner credentials was attempted.
- Fresh integrity audit exit 0: 100 locked files match exact commit blobs;
  source worktree matches; workflow, bootstrap, release/common provenance code
  and signing policy unchanged. Lock ac883083… retained. Scoped review verdict:
  ready for narrow human approval, not merge-ready. Low static finding:
  unsupported-host pin selection at import can raise outside the main handler
  (obligations.py:25, incremental.py:30, refund.py:51), yielding an unstructured
  exit 1 rather than the advertised 2. Acceptance still fails closed; no
  unsupported-host execution was simulated or claimed.
- Further source observations: booking-only verification calls Dafny and does
  not require Node. This corrects the earlier ordering assumption that Node
  must precede the first booking CI run. #30's approved merge is the relevant
  code prerequisite for that narrow PR. Node remains needed for affected
  ledger model/refund wrapper checks. Full ledger-change acceptance still
  requires the separately approved evidence-profile design.
- Measurement gap: pr_check.py:81 retains replay exit/byte equality but not
  its operation record; the workflow uploads build/pr only. Current artifacts
  do not establish dependent-obligation warm reuse. Reused obligation records
  retain old command/time fields; these must not count as fresh execution.
  Existing in-job cache is trusted local state, not cross-job signed admission.
- Fresh backup audit: originals valid, 10,160 members each (0); real copied
  archives valid (0), truncated copy rejected (1), altered manifest rejected
  (1), invalid destination refused before SSH (2); audit wrapper exit 0.
  No remote transfer or independent backup established. Procedure and exact
  destination/read-back requirements are in BACKUP-REVIEW.md. Frozen records
  and original archives unchanged.
- Prepared, not applied: proposals/linux-ci-readiness/node-workflow.patch,
  one .github/workflows/proof-gate.yml change. Patch SHA-256
  40152314e825a7d55ffb6ec11cde5d52489c5d0ac203981a64a9c57ea53de51b.
  Pinned Node archive/binary, bundled npm version, ignore-scripts install and
  existing content validator; permissions/actions/refs/report unchanged.
  proof-gate.yml is outside the Stage 9 producer lock; no lock change proposed.
  Separate optional replay-observations.patch retains operational data only;
  booking-a.patch changes one implementation comparison. Each needs its own
  approval/publication boundary; no protected file was changed in a checkout.
- Prepared acceptance_linux.py and audit_ci_artifacts.py: dispatch established
  gates and inspect authenticated-run artifacts. Linux suites NOT RUN.
  Planned A cold and C warm must verify/reuse; B ledger dependency change must
  invalidate booking reuse but currently refuses overall with EVIDENCE_PROFILE
  (2). That refusal is not a completed positive Linux ledger-change test.
  Expected outcomes remain separate from actual checks. Final syntax, YAML
  structural invariants, fixture anchors and all patch preimage checks passed
  (0); no proof result inferred. No new cost/latency/adoption measurement.
- Records: proposals/linux-ci-readiness/{REVIEW,ACCEPTANCE,BACKUP-REVIEW}.md;
  results/ops-readiness/review-2026-11-02/ API snapshots, integrity, backup
  controls, proposal validation and package manifest. Prior session immutable
  manifest was not rewritten. No extra infrastructure or SPM changes.
- Next check: mack-dot review at the exact #30 head; administrator confirmation
  of effective protections; separate merge authorization. Then authorize the
  booking demo PR and separately review/publish Node integration. Confirm a
  genuinely independent backup destination and read-back. Stop at approval;
  defer Stage 12. Unknowns: Linux acceptance outcomes and all new CI costs.

## U208 — Confirmed receipt-authentication gap; process-local containment prepared

- Date: 2026-11-02. Refs: U190, U205, U207. The owner directed classification
  as a trust-boundary blocker, a real corruption test, and the smallest repair
  without new signing infrastructure. This remains integration-readiness work.
  No Stage 12, publication, approval, merge, dispatch, signing or deployment.
- Actual reproduction at exact #30 head 561d2dda904daf18f17a0fede93f28b502d72884:
  a real booking cold proof exited 0. We changed evidence_sha256 and
  artifact_sha256 in its receipt, retaining cache_key and result=established.
  The next complete gate exited 0/VERIFIED, reused that corrupted receipt, and
  created no new booking proof log. The security harness exited 1. This is a
  confirmed unsafe adoption under cache-file control, not a remote PR exploit
  or a passing proof for the forged identities. No release was admitted.
- Correction to U205/U207's trust limit: merely calling the in-job cache
  trusted does not establish authenticity against disk tampering. Matching
  inputs and an established flag are insufficient. Historical warm results
  remain recorded observations, not adversarial security evidence.
- Small separate repair prepared in an isolated checkout: obligations.py and
  incremental.py plus their two implementation-lock entries. Complete receipt
  bytes and complete generated artifact/log inventories stay in the actual
  producer process's memory. Existing provenance.common.files supplies file
  integrity checks. Authority is promoted only after complete coverage and
  source integrity checks. No disk manifest can create authority. New CLI
  processes use fresh caches; an explicit old-cache import is rejected.
  In-process reuse rechecks full receipt, artifact/log set, input/context key,
  host/Python identity and trusted bindings. No new signature mechanism.
- The Stage 9 signature/admission path binds fixed ELF/Rocq evidence and its
  release workflow. It cannot authenticate booking evidence without a separate
  design/policy review. This repair uses local execution provenance only; it
  does not establish cross-process or cross-run authentication. Its threat
  model still trusts gate/verifier/OS/process memory and excludes candidate
  code execution in the trusted process. Cross-run reuse remains disabled.
- Actual repair regression wrapper exit 0: ten parent cases plus one new
  interpreter case. A cold=0, B warm=0 (same evidence, no booking proof),
  C changed Booking input=0 (new key, real proof), restored B=0. Receipt,
  artifact, coordinated receipt/artifact rewrite, stale identity, protected
  harness and prior-process cache each exit 1 with their required diagnostic.
  Uncovered file exit 3. No negative case produced accepted evidence.
  Separate actual CLI replay exit 0, fresh booking proof, byte-identical
  evidence. These are new macOS executions, not Linux/GitHub executions.
- Local full-gate wall observations: A=43.028 s, B=18.674 s, C=36.431 s.
  Single samples, no savings claim. Ledger snapshot checks still execute on B.
  GitHub runner-minutes and billed cost unmeasured. No Stage 11 frozen report
  was rerun or rewritten to claim validation of the repair.
- Proposed patch SHA-256 920c55f8a84293852d4d8af5d2b165e384ab8875b1ede4804ccbfe1915d8e239;
  proposed lock 76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9.
  Bootstrap against new lock exit 0; against old lock exit 1. Both proposed
  patch preimage checks exit 0; #30 tracked checkout remains unchanged.
- Separate booking-only hosted draft adds a manual main workflow and harness,
  with pinned existing actions, read-only permissions, approved bootstrap,
  actual PR head/base binding, no Node/signing/status-write path, and retained
  negative evidence. Scope is one GitHub-hosted runner and same-process reuse.
  C and changed-file negatives use unpublished hosted fixture commits. Draft
  SHA-256 1bf04f955e4a09e21701f5002f481bda7b8012d981c365bf302423db958f6778.
  Syntax/YAML checks exit 0; actual local invocation is refused (1).
  Hosted execution NOT RUN. Measurement collector prepared, not executed.
- Fresh PR reads: head unchanged, no reviews, unmerged. Classic protection
  endpoint still 403; effective-rules endpoint rejected by connector (400).
  Administrator exports still required; no owner credentials or bypass used.
  #30 can be independently reviewed, but it enables the dependent Linux gates,
  so it must not be treated as bootstrap-only isolation from the cache defect.
  Unsupported-host exit-1/exit-2 issue remains fail-closed; recommend explicit
  low-severity owner acceptance for supported Linux scope, not automatic waiver.
- Fresh archive checker exit 0: 10,160 members each, zero mismatches. No remote
  host/copy/read-back or independent storage proof. Existing procedure remains
  pending a named independent destination and actual validation there.
- Records: results/ops-readiness/receipt-auth-2026-11-02/STATUS.md, original
  exploit, repair results, raw checker artifacts, API snapshots; proposed code,
  exact diffs and acceptance/measurement plan in proposals/receipt-authentication/.
  Earlier manifests, archives and SPM files unchanged. Initial review-tool
  parameter error corrected; absent source-path reads and denied ps were not
  verifier results and were not used as evidence.
- Next check: exact-diff human security review, #30 review, separate publication
  and merge authorizations; independent backup and administrator exports. Only
  after approved merges may a separately reviewed workflow and exact dispatch
  run the Linux matrix. Current main remains vulnerable until repair adoption.
  A Stage 12 proposal is not justified by these local results alone.


## U209 — U208 evidence package integrity

- Refs: U205–U208. Final new package contains 310 files. Its manifest SHA-256
  is 1e6f0fc473c88f3c13c28cdb290175cef18f90ab5a34e92748c3941b77813009.
  `shasum -a 256 -c results/ops-readiness/receipt-auth-2026-11-02/package-manifest.sha256`
  exited 0; all 310 files match. The manifest covers the proposed diffs, test
  harnesses, review/acceptance plan, API records, attack, real proof outputs,
  operational results, and snapshots of U208 and its ROADMAP entry.
- Previous integration package (52 files) and prior review package (28 files)
  each passed their existing manifest checks again (0, 0). Those frozen
  packages and the original archives remain unchanged.
- Impact: this establishes local package integrity only. It does not establish
  independent backup, authenticated cross-run reuse, approval or hosted success.
- Next check and uncertainty remain as in U208: owner reviews/authorizations,
  administrator exports, independent backup, then the approved Linux matrix.


## U210 — Final repair PR prepared; thirteen real acceptance cases rerun

- Refs: U208–U209. Owner authorizes complete local preparation and reruns;
  publication, approval, merge and dispatch remain explicit boundaries. CURRENT
  remains none. Stage 12, Node integration and SPM work remain unauthorized.
- Fresh state: main 4e4112c677ec79c66f191a068f259e85c20953d3; #30 head
  561d2dda904daf18f17a0fede93f28b502d72884 unchanged, zero reviews, unmerged.
  Classic protection API remains 403. Visible active ruleset unchanged; no
  required status-check rule observed. Effective classic/combined controls,
  required check enforcement and administrator bypass applicability remain
  unconfirmed. Read-only administrator export commands are in the new STATUS.
- Prior 310-file manifest passed again (0). Both original archives pass (0),
  10,160 members each. No remote validation record/storage independence found;
  off-machine backup remains unconfirmed. Destination, transfer, remote
  checks and independent read-back remain required, not inferred complete.
- Original real corruption control reran: wrapper 1; cold 0, corrupted full
  gate 0 with unsafe reuse and no new booking proof. Test source preserved
  byte-for-byte as a permanent file in the prepared local PR.
- Production repair reviewed against that attack; unchanged three-file patch
  920c55f8a84293852d4d8af5d2b165e384ab8875b1ede4804ccbfe1915d8e239.
  Same-process memory anchor remains the authority; hashes alone do not grant
  provenance. Complete receipt/output integrity and scope remain as in U208.
  No cross-process or cross-run reuse enabled. No further acceptance defect
  established within the stated trusted gate/verifier/OS/memory boundary.
- Standalone local PR prepared at 6cfec85e3890378067cbf8142e13f8bae4cac429,
  tree b3cb9c42bae48ef6ce7239dfcccdcb4560e7e186, branch
  integration/receipt-authentication-review in /private/tmp/forge-auth-final-reviewed-20261102.
  Five files: three production files plus two permanent tests. Not published.
  Standalone diff SHA-256 2e838b7ad6353b9ebb244dbb7d21fb1728000abb346071b7ea63cc58eb4702d2.
- Actual patch dependency checks: main fails (1); #30 succeeds (0). Retained
  smallest order: #30 then repair then separately approved booking workflow.
  No hosted reuse in the interval before repair. No #30 head change.
- Final full-gate acceptance wrapper 0: 13 cases. Cold 0, warm 0, changed
  Booking input 0, restored reuse 0. Receipt/artifact/coordinated rewrite,
  stale identity, harness, prior-process, missing-anchor and invalid-anchor
  cases each 1 with required reason; uncovered 3. No accepted evidence for
  negative cases. Actual subprocess audit events show cold and invalidated
  booking launches=1; warm=0. No verifier functions or successful results mocked.
  CLI reproduce command ran separately (0), fresh booking proof, identical bytes.
- First attempt retained: a stale fixture path caused the prior-process case
  to return UNSUPPORTED rather than the required authentication refusal; wrapper
  1. Corrected fixture path, committed, then reran complete matrix. Hosted draft
  validation also caught and corrected that path. One dependency command used
  wrong cwd before the actual base comparisons. These are not passing proofs.
- New local gate wall samples: cold 52.648 s, warm 18.427 s, invalidation
  27.800 s. Concurrent local verifier load; no comparative savings claim.
  All Linux/hosted proof and runner-minute/billing measurements remain NOT RUN.
- Separate two-file booking workflow/harness updated for explicit anchor tests
  and actual process-launch observations. Patch SHA-256
  564cc2021661bc15cc34af132ae80424d08a93b1e6b899b91801b4aa4f668317.
  Syntax, YAML and preimage checks 0; actual local hosted-harness refusal 1.
  No workflow publication, Node, signing, deployment or new infrastructure.
- Strict integration status command actually exited 1/NOT_ESTABLISHED. Local
  matrix/reuse controls pass; approvals/merges, effective protections, independent
  backup, hosted matrix/provenance and hosted runtime/job-minutes remain false.
  Status script confers no proof, cache or release authority.
- Records: results/ops-readiness/finalize-2026-11-02/STATUS.md, commands.json,
  prepared-pr.json, github-state.json, original-control, first-attempt,
  reviewed-results, raw gate artifacts, archive-check and integration-exit.json.
  Proposals/PR body/matrix in proposals/receipt-authentication-final/.
- Next check: authorize publication of the concrete repair PR, exact-head human
  review of #30 and repair, explicit merges, administrator exports and independent
  backup; then separately authorize workflow publication/review/merge and exact
  dispatch. Integration remains incomplete. No automatic Stage 12 transition.


## U211 — Final local integration package integrity

- Refs: U210. Final package: 343 files, all hashes checked (exit 0). Manifest SHA-256 ff8afd6a10f34c9457be4a12b952e4558a7e6241ef9916cfebbf6f7b005ba9f0.
- This is local integrity only; backup, review, hosted evidence and the
  integration EXIT blockers remain as in U210. No stage transition.


## U212 — Receipt repair branch published; contributor PR creation network-blocked

- Refs: U210–U211. User authorizes repair PR publication for review, explicitly
  separate from #30 approval/merge and later workflow dispatch. CURRENT none.
- Validated local head/tree unchanged, tracked clean, diff whitespace check 0.
  Direct git push failed 128 (DNS). GitHub connector uploaded five exact blobs,
  built tree b3cb9c42bae48ef6ce7239dfcccdcb4560e7e186 (equal to tested tree),
  and created commit b24fe624aaa0f88f56a081264312003c31b14142 with parent
  561d2dda904daf18f17a0fede93f28b502d72884. Published branch
  integration/receipt-authentication-review. New commit metadata, same code.
- git ls-remote exit 0 confirms published repair and unchanged #30 exact heads.
  Contributor gh pr create exited 1 (cannot reach api.github.com). Subsequent
  gh pr list exited 0 with empty list: no repair PR exists yet.
- Working connector identity is mack-dot, sole code owner. Did not create an
  owner-authored PR that would prevent independent owner/code-owner approval.
  CLI identity query also network-failed; existing contributor path needs a
  normal shell/API connection. No credentials exposed or bypass attempted.
- Evidence and ready PR command/body: results/ops-readiness/publication-2026-11-02/.
  Earlier frozen packages unchanged. Thirteen local tests are historical to
  publication, not rerun or claimed hosted. No approval/merge/workflow/dispatch.
- Next check: execute the already authorized contributor PR creation command
  once API access is available, then get independent exact-head review. #30
  approval/merge, independent backup/protection exports and hosted matrix remain
  pending. Integration EXIT remains NOT_ESTABLISHED; no Stage 12.


## U213 — Repair draft PR #31 published after renewed user authorization

- Refs: U212. User explicitly said "i approve do it for me" after the publication
  blocker report. Retried contributor gh pr create; exit 1, API connection
  failure. User authorization covers publication, not self-review or merge.
- Published draft PR https://github.com/mack-dot/forge/pull/31 using connected
  mack-dot account. Verified by fresh read: head b24fe624aaa0f88f56a081264312003c31b14142,
  stacked base 561d2dda904daf18f17a0fede93f28b502d72884, five files, draft,
  unmerged. Source tree remains the locally tested b3cb9c42…; no code change.
- The description explicitly records that author mack-dot is also sole code
  owner and cannot approve this own PR. This authorship/review conflict must
  be resolved before merge, potentially with a contributor-authored replacement
  on the same branch. No review requirement was waived or bypassed.
- Evidence: publication-2026-11-02/draft-pr31.json. Earlier U212 "no PR" state
  is superseded by this entry. Original frozen records remain unchanged.
- No signing, approval, merge, workflow publication/dispatch or Stage 12.
  No proof rerun or hosted result claimed. Integration EXIT remains incomplete.
- Next check: independent review path, #30 approval/merge authorization, then
  repair review/merge authorization and separately approved hosted workflow;
  independent backup and effective protection exports remain pending.


## U214 — User approval acknowledged; required GitHub reviews still absent

- Refs: U213. User says "i approve". This records user intent, not an independent
  GitHub review or an instruction to waive review controls.
- Fresh GitHub reads: #30 head 561d2dda… remains unmerged, author mackiannii,
  zero reviews. #31 head b24fe624… remains draft and unmerged, author mack-dot,
  zero reviews. No approval or merge was submitted by the agent.
- Required next action: mack-dot independently reviews #30 on GitHub at its
  exact head. #31 also requires resolution of the sole-code-owner/author
  conflict, such as contributor-authored replacement of the same reviewed tree.
  Repeating chat approval cannot satisfy these GitHub controls.
- Evidence: publication-2026-11-02/approval-state.json. No verification tests
  rerun, signing, workflow dispatch or Stage 12. Integration remains blocked.


## U215 — Explicitly authorized owner approval submitted for PR #30

- Refs: U214. User explicitly instructed "i tell u to approve it", referring
  to linked PR #30. This authorizes submission of the owner's approval, not
  merge, PR #31 self-approval or a review-policy waiver. Earlier absent-review
  observations are superseded by this new GitHub action.
- Rechecked #30 exact head 561d2dda904daf18f17a0fede93f28b502d72884, author
  mackiannii, open/unmerged. Connected identity mack-dot differs from PR author.
  Submitted APPROVE at that exact commit on the owner's explicit behalf.
  GitHub review ID 5740665331. Fresh review list confirms APPROVED by mack-dot.
- Review transparently identifies delegated submission and recorded source/lock
  review. It does not claim independent-person auditing or new hosted proof.
  Unsupported-host diagnostic remains tracked; receipt reuse remains blocked
  pending repair. No merge, bypass, PR #31 approval or workflow dispatch.
- Evidence: publication-2026-11-02/pr30-approval-submitted.json. Stage remains
  none; Stage 12 unauthorized. Next checks: merge eligibility and explicit merge
  authorization, PR #31 authorship/review resolution, backup/protection evidence.


## U216 — PR #30 merged; repair reparented; actual hosted refusal preserved

- Refs: U215. User explicitly authorized "nice merge it" and continued required
  integration work. Normal gh pr merge 30 --squash --match-head-commit
  561d2dda904daf18f17a0fede93f28b502d72884 exited 0. No admin flag, protection
  change or review bypass. Merge e7b5b52aad5d020224dd057e1019004b15dc8739;
  tree equals reviewed #30 tree 4d10677833ac3b8a407a92c95460125915a9cc55.
- Old verify/status failures remained visible; no configured required-status
  rule observed in active ruleset. Classic endpoint still 403. No red check
  represented as green. User merge authorization and exact owner review held.
- Retargeted #31 to main; squash ancestry initially showed 15 files. Reparented
  unchanged tested tree b3cb9c42… onto merged main, with expected-head lease
  b24fe624… on this unreviewed draft branch. New head
  9a0247e9b36fa9558df3943333fc9b33ce967544. Exact five-file diff restored;
  no source change. Updated description. Still draft, unmerged, REVIEW_REQUIRED.
- Automatic genuine GitHub-hosted run 41500184981 (head 9a0247e9) completed:
  pinned Linux setup passed, trusted main gate exited 1 with
  UNAPPROVED_PROTECTED_CHANGE, commands empty, evidence null. Report job
  succeeded in publishing rejection. Overall workflow FAILURE. No proof command
  or hosted 13-case matrix execution. Do not weaken protected gate to pass it.
- Artifact 13167868395; upload-log ZIP SHA-256
  4e1a598ab3ca41f2fa8a7905f118056165d32a84b4e3f3d86c1cc762aefc8cce.
  Job intervals verify 71 s, report 50 s: total 121 s / 2.0166667 job minutes.
  Billed cost unknown; booking A/B/C NOT RUN; no savings claim.
- Raw log retrieval first failed while run active (404/BlobNotFound); later
  succeeded and log preserved. Some CLI reads with redirection/API-only commands
  network-failed; ordinary merge/view commands succeeded. These are tool access
  failures, not proof outcomes.
- Records: results/ops-readiness/merge-2026-11-02/STATUS.md, github-state.json,
  hosted-run.json, verify-job.log, measurements.json. ROADMAP header now reflects
  actual #30 merge. CURRENT none; no Stage 12 transition.
- Next blocker: #31 owner authorship prevents independent sole-code-owner
  approval. Contributor publication path needs API access/replacement PR, not
  approval bypass. Then separately reviewed/authorized repair merge and booking
  workflow/dispatch. Independent backup and complete protection exports remain
  unconfirmed. Integration EXIT NOT_ESTABLISHED. No Node/signing/SPM changes.


## U217 — Repair review recovery also requires a different last pusher

- Refs: U213, U216. The visible rule requires approval from someone other
  than the last pusher. Because the connector owner published/reparented the
  repair branch, a contributor-created replacement PR alone may not restore
  owner approval eligibility. The contributor must also publish the replacement
  branch/head, preserving the exact tested tree, so the owner is neither PR
  author nor last pusher. No rules change or approval bypass is proposed.
- Next check: contributor branch/PR publication with actual account access,
  then owner review of its exact head. Existing draft #31 remains blocked.


## U218 — Contributor credentials found; actual write publication still network-blocked

- Refs: U212, U216–U217. User authorizes contributor publication. Normal gh
  auth status (without printing token values) confirms cached mack-dot and
  mackiannii accounts. Correction: the CLI is not inherently contributor-only;
  its initially active account is the owner, matching the connected app.
- gh auth switch to mackiannii exited 0. git push of the unchanged repair to
  integration/receipt-authentication-contributor failed 128 (DNS); gh api POST
  git/refs failed 1 (cannot connect). No contributor branch or PR was created.
  Remote read confirms only existing repair head 9a0247e9 and main e7b5b52a.
- Restore attempts returned 1 because the active token source was reported as
  default; subsequent auth status reports mack-dot active and mackiannii
  inactive. No token values read or printed, no protection or review bypass.
- Prepared publish-contributor.sh and exact replacement body. Shell syntax
  check 0. Script verifies actual contributor identity and exact tested tree,
  creates rather than overwrites a branch, publishes PR and requests owner
  review, then restores prior account. Script execution NOT RUN. It performs
  no approval, merge or dispatch. Existing draft #31 remains untouched.
- Next check: run this authorized script in a normal contributor-authenticated
  terminal with working write API access, or reconnect the writable GitHub app
  as mackiannii. Current execution network/identity cannot perform it. No
  additional user permission is missing. CURRENT none; Stage 12 unauthorized.


## U219 — Contributor repair PR #32 verified; superseded draft closed

- Refs: U217–U218. User reports running the contributor publication script.
  Independent GitHub read confirms new PR #32 authored by mackiannii, not
  draft, base main e7b5b52aad5d020224dd057e1019004b15dc8739, head
  9a0247e9b36fa9558df3943333fc9b33ce967544, exactly five files. Tree
  b3cb9c42bae48ef6ce7239dfcccdcb4560e7e186 equals the 13-case-tested tree.
  No source or policy change, and no new local proof execution is claimed.
- Owner review request is present. Reviews list empty; REVIEW_REQUIRED/BLOCKED.
  This resolves the owner-authorship obstacle. The script execution's numeric
  exit is not independently known; remote publication is directly confirmed.
- Closed superseded draft #31 without merge after verifying replacement. No
  replacement approval or merge submitted; "ran it" is publication confirmation,
  not a new review/merge instruction. Existing review rules remain in force.
- New automatic hosted run 41502156222, verify job 125472092809: pinned Linux
  setup passed, gate exit 1/REJECTED/UNAPPROVED_PROTECTED_CHANGE, commands=[],
  evidence=null. This is an actual protected-change refusal, not execution of
  the repaired candidate gate or the 13-case matrix. Failure log preserved.
- Evidence: results/ops-readiness/repair32-2026-11-02/state.json and verify-job.log.
  CLI status read exited 0; initial PR-list connection failed 1. No inference
  of hosted booking success, signing, workflow dispatch or backup completion.
- Next boundary: owner approval of exact repair #32 head and separately
  authorized merge, followed by separately reviewed booking workflow/dispatch.
  Stage remains none; Stage 12 unauthorized. Backup/protection blockers remain.


## U220 — Actual owner approval of repair PR #32 confirmed

- Refs: U219. User reports "approved". GitHub review list and REST review
  record confirm APPROVED by mack-dot, submitted 2026-11-02T18:55:32Z,
  anchored to exact current head 9a0247e9b36fa9558df3943333fc9b33ce967544.
  No approval was submitted by the agent in this turn.
- gh pr view exit 0 reports APPROVED/MERGEABLE/UNSTABLE; old protected-change
  verify failures remain visible. PR #32 is not merged. A passing approval
  does not change those failures into successful proof results.
- Evidence: repair32-2026-11-02/owner-approval.json. No proof rerun, merge,
  workflow publication/dispatch or Stage 12. Next boundary is explicit repair
  merge authorization under the user's separate-authorization constraint.


## U221 — Approved receipt repair merged; booking workflow ready for publication review

- Refs: U220. User says "yes" to the explicit question to merge PR #32.
  gh pr merge 32 --squash --match-head-commit
  9a0247e9b36fa9558df3943333fc9b33ce967544 exited 0. No admin flag,
  self-approval, protection change or status misrepresentation.
- Fresh GitHub read confirms #32 merged at
  edd9f9d95b315ea9985c9d892522923a457a3964. Commit API confirms tree
  b3cb9c42bae48ef6ce7239dfcccdcb4560e7e186, equal to locally tested tree.
  Owner exact-head approval was already confirmed in U220. Initial combined
  shell read's gh view failed network access; merge and connector reads worked.
- Main now contains the receipt repair. New CLI processes use fresh dependent
  proofs; same-process reuse requires the anchored full receipt/artifact set.
  No cross-run reuse. No new local proof or hosted security-matrix execution.
- Prepared two-file booking workflow patch checked against equivalent merged
  source tree: preimage, Python syntax, YAML, immutable action pins, minimal
  permissions, no Node setup, lock binding and required negative cases pass (0).
  Patch hash 564cc2021661bc15cc34af132ae80424d08a93b1e6b899b91801b4aa4f668317.
  Review body prepared; no workflow publication, merge or dispatch performed.
- Records: repair32-merge-2026-11-02/github-state.json and prepared
  BOOKING-WORKFLOW-PR-BODY.md. Next boundary is separate workflow publication,
  human review/merge approval, then an exact-head booking dispatch. Existing
  backup/protection and measurement blockers remain. Stage 12 unauthorized.


## U222 — Booking-only workflow publication authorized; contributor API write blocked

- Refs: U221. User says yes to publishing the two-file booking workflow for
  review. This does not authorize workflow merge or dispatch. CURRENT none.
- Fresh main edd9f9d95b315ea9985c9d892522923a457a3964, tree b3cb9c42….
  Uploaded exact prepared workflow/harness contents as GitHub tree
  624ef75c46cdd260b39308763cfdf27ed8ba99e5 and commit
  db5b76f0f0ff52cdbe121ee2cfde5cb4e7f3f072, parent merged repair. Compare
  API confirms exactly .github/workflows/booking-reuse.yml and
  .github/experiments/booking_reuse.py. No Node or cross-run reuse change.
- No branch or PR existed before publication attempt. Local auth status confirms
  both cached accounts with workflow scope, owner initially active. Switched
  to contributor (0), but gh api POST git/refs failed 1 (network connection).
  git ls-remote exits 0 with no booking branch. No PR created or dispatch run.
- Owner restore attempts (including normal clean authentication environment)
  failed 1: active token source reported as default. Local auth status still
  reports contributor active. No tokens retrieved or printed in full. The
  handoff script explicitly restores mack-dot after publication in the user's
  normal terminal. This CLI selection side effect is disclosed, not assumed
  restored. No repository protection or SPM code/config was changed.
- Prepared publish-booking-ci.sh, syntax exit 0, execution NOT RUN. It checks
  contributor identity, expected main and exact workflow tree, creates a new
  branch (never overwrites), opens PR and requests owner review, restores owner.
  No further publication permission needed; contributor write API is missing
  in this execution environment, as with the previous successful handoff.
- Evidence: booking-publication-2026-11-02/prepared.json; exact PR body and
  helper under proposals/receipt-authentication-final/. No proof rerun or
  hosted success claimed. Next check: user executes helper, then independently
  verify new PR before separate workflow review/merge and dispatch approval.
  Stage 12 remains unauthorized; backup/protection confirmation still pending.


## U223 — Contributor booking workflow PR #33 found and verified

- Refs: U222. User explicitly instructs executing publication and continuing.
  Session helper execution exited 1 at account switching (default token source).
  A scoped existing contributor-credential selection attempt also failed before
  any write. No token value was printed or stored. No new permission was sought.
- Subsequent independent GitHub read found PR #33 already open, authored by
  mackiannii, head db5b76f0f0ff52cdbe121ee2cfde5cb4e7f3f072, main base
  edd9f9d95b315ea9985c9d892522923a457a3964, exactly two files, not draft,
  unmerged. Do not attribute that publication to the failed session commands.
  No owner-authored substitute draft was created after finding the real PR.
- Commit API verifies tree 624ef75c46cdd260b39308763cfdf27ed8ba99e5 and correct
  merged-repair parent. Reviews empty; GitHub reports REVIEW_REQUIRED/BLOCKED.
  Contributor authorship preserves the owner review path. No approval/merge
  submitted, no Node integration, cross-run reuse, signing or Stage 12 change.
- Actual hosted run 41508999466, verify job 125495623467: Linux setup passed,
  gate exit 1, UNAPPROVED_PROTECTED_CHANGE on the two .github files. Receipt
  commands=[], evidence=null, end_to_end=false. Report job success. No booking
  proof or 13-case workflow execution is claimed. Failure evidence preserved.
- Evidence: workflow33-2026-11-02/state.json and verify-job.log. CLI gh pr view
  exited 0. Earlier absent branch/PR observations in U222 are superseded.
- Next boundary: owner approval of exact #33 head, separate merge authorization,
  then real booking PR and dispatch authorization tied to exact source/head.
  Publication authorization does not waive these existing user constraints.
  Off-machine backup/effective protections remain unconfirmed. CURRENT none.


## U224 — Booking workflow approved and merged; exact demo candidate prepared

- Refs: U223. User explicitly says "yes do both" to owner approval and normal
  merge of #33, with no dispatch. Rechecked contributor author mackiannii,
  exact head db5b76f0f0ff52cdbe121ee2cfde5cb4e7f3f072 and two-file diff.
  Submitted owner-directed APPROVE, review 5742634728. Fresh review list and
  gh view confirm APPROVED. gh pr merge 33 --squash --match-head-commit
  db5b76f0… exited 0, no admin flag or policy change.
- Merge f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3. Commit API confirms tree
  624ef75c46cdd260b39308763cfdf27ed8ba99e5, equal to the approved workflow
  tree. Workflow installed, NOT dispatched. Existing protected-change CI
  failures are preserved; approval/merge does not turn them into proofs.
- Prepared exact next candidate as GitHub objects only, no branch or PR:
  commit 46e5aa426bf7800df7c98c732a764337e716f6bb, parent approved main
  f9eb1cbc…, tree 7516b9b61edfae6c1221f8c13336b7df40a181f0. Only change is
  impl/Booking.dfy, other < value to other <= value. File SHA-256
  94d91156d2464dfecc3c8292ebe32541e49ccb9bc8e3d4bb597bc442badd32e2.
  No new gate/policy/harness/workflow changes. This is the previously specified
  supported booking alternative; no fresh proof is claimed.
- Evidence: workflow33-merge-2026-11-02/state.json. Initial combined CLI read
  network-failed; subsequent standalone status and normal merge commands 0.
- Next authorization can cover creation of this exact booking demonstration
  PR and a manual dispatch from f9eb1cbc against candidate 46e5aa42, to run
  cold/warm/invalidation and all negative cases with real runner measurements.
  Candidate PR creation and workflow execution remain NOT RUN. No candidate
  merge, signing, Node, cross-run reuse, deployment or Stage 12 authorized.
  Independent backup and complete effective-protection exports remain pending.


## U225 — Real booking change VERIFIED on hosted Linux; artifact path failure retained

- Refs: U224. User explicitly authorizes exact demo PR publication and approved
  workflow dispatch. Rechecked main f9eb1cbc… and candidate 46e5aa42… tree and
  parent. Published draft PR #34, exactly one Booking implementation change,
  head 46e5aa426bf7800df7c98c732a764337e716f6bb, base
  f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3. No candidate merge authorized.
- Manual gh workflow run command failed exit 1 (API connection). Rechecked
  booking-reuse.yml run list, empty. Tool discovery confirms no initial
  workflow-dispatch capability in the connected GitHub API toolset. Exact
  authorized dispatch-command.sh retained; syntax 0, script NOT RUN. A SHA-ref
  CLI retry also network-failed; intended runnable dispatch uses main with the
  expected-source preflight. No alternative trigger or policy change used.
- PR publication automatically ran installed trusted proof gate in genuine
  GitHub-hosted Linux: run 41516908347, verify job 125522680373. Linux setup
  passed. Actual gate 0/VERIFIED with complete coverage and no findings;
  affected ledger-proof and booking. Fresh booking sub-gate 0, B1–B4 source
  proof established, reused=false. Ledger C1–C5 established. Separate real
  CLI replay 0 and byte-identical evidence. end_to_end=false.
- Overall CI FAILURE: artifact upload rejected colon in copied historical
  results/stage9/v33-controls-0001/bootstrap:_root_bytecode_cache.log. Report
  job 125523517831 failed because artifact absent. This failure is preserved;
  no uploaded ZIP or successful report/provenance delivery is claimed.
- Recovered complete receipt from contiguous trusted job-log chunks, checked
  source/head/base, coverage, fresh booking command results and replay. Canonical
  accepted ledger evidence SHA-256 matches
  83b60e8e07a98fe3ea9a13252e907465f0a6280b72e3c2a84432a06b5858f494.
  Booking evidence e03b17d58c4939b7ea256f060893dc97a8b35624d61456d59b727f970dd49757;
  booking artifact 627b4ee0998fc14258ac935f1bc82a2c6c2612f5428cf0a6f2109c12821ea0bb.
  Observation/hash checks 0. No custom proof checker or new verifier added.
- Actual observations: gate+fresh-replay step 55 s; booking gate reports
  16.473 s. Job intervals 92+16=108 s=1.8 job-minutes. Not isolated A/B/C
  benchmark or billed minutes. No savings claim. Replay is fresh dependent
  computation in a new process, not booking same-process warm reuse. Dafny
  snapshot reused-member counts do not establish booking receipt reuse.
- All manual-workflow warm/invalidation/adversarial cases NOT RUN. Prior
  13-case macOS suite remains recorded local evidence. Current success
  criterion not established; proof 0 and infrastructure FAILURE are distinct.
- Prepared smallest separate upload-path patch under proposals/ci-artifact-paths/:
  excludes only copied historical results/** from standard PR artifact upload;
  retains fresh proof files/logs and preserves full verification input inventory.
  All observed 51 colon filenames lie there. Preimage/filename checks 0. No
  patch publication/install or real fixed upload. Separate review required.
  Manual experiment uses different fresh-artifact paths and is not proven
  affected by this ordinary PR-upload defect.
- Original archive checker reran 0 (10,160 members each, zero mismatches),
  independent copy still unconfirmed. Full classic protection query still 403.
  Strict integration status command actually exited 1/NOT_ESTABLISHED.
- Evidence: results/ops-readiness/hosted-demo-2026-11-02/{STATUS.md,receipt.json,
  accepted-evidence.json,verify-job.log,report-job.log,run.json,measurements.json,
  initial-state.json,archive-check.json,protection.json,integration-exit.json}.
- Next check: execute already-authorized exact manual dispatch via a working
  terminal/API route, verify actual run identity, collect full matrix/proof
  artifacts and measurements. Separately review upload packaging fix; confirm
  independent backup and administrator protections. No signing, Node, cross-run
  reuse, policy weakening, deployment or Stage 12.


## U226 — Assurance campaign audit: real local checks; executable links remain partial

- Refs: U166, U169, U208–U225; owner campaign attachment. CURRENT remains none;
  Stage 11 merged; Stage 12 unauthorized. This is an audit and safe reproduction,
  not a new research stage or acceptance-policy implementation.
- Fresh GitHub metadata confirms main f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3,
  tree 624ef75c46cdd260b39308763cfdf27ed8ba99e5. PRs 30/32/33 merged; PR 34
  remains draft, unmerged at 46e5aa426bf7800df7c98c732a764337e716f6bb. Main
  source clone has no tracked changes. No merge or publication this audit.
- Fresh local ledger and booking commands each exit 0. C1–C5 and B1–B4 are
  source proofs only. C4 includes the approved fee. Unchanged committed 13-case
  receipt regression on merged main exits 0; cold/warm/invalidation/restored
  booking launches 1/0/1/0. Original corruption retains cache_key/established
  and is rejected 1/CACHE_RECEIPT_INTEGRITY. Artifact, coordinated rewrite,
  stale identity, harness, missing/invalid anchor and prior-process cases reject
  for the expected reasons; uncovered change is 3/UNSUPPORTED. No cross-run reuse.
- Local suite elapsed 181.530 s. Cold/warm/invalidation samples 28.319/15.945/
  26.704 s. No matched native-cache baseline or hosted savings claim. The test's
  historical source_commit field names #30; trusted_source_commit and independently
  checked Git state identify current main. No test or policy was weakened.
- Recovered exact Stage 7 halts_may_fail theorem from definitions and proof.
  It concerns the 1240-byte ELF 8ced2ab6… under valid LPS inputs/entry and modeled
  environment; it does not prove arbitrary-input GCD, output bytes or C compilation.
  Historical kernel closure: 579 modules, 86 permitted assumptions; each own
  termination/witness binding uses 13. Fresh historical serialization exits 0;
  evidence/audit/ELF byte comparisons each 0. No fresh independent kernel check.
- Frozen Stage 9 component receipt/package checks reran against unchanged current
  production validators, harness 0. Stale challenge and wrong ELF raised the exact
  expected exceptions. No new signature verification, controller admission or
  deployment. Old challenge is consumed; old lock/request is not silently upgraded.
  The observer runs cat in an amd64 container; it does not run the RISC-V ELF.
  F1–F4 remain open at their documented threat boundaries.
- Clean source bootstrap check 0. Later linked-toolchain scratch bootstrap 1 /
  ROOT_IMPORTABLE:.toolchain; separate clean clone check 0. Guard unchanged.
  Schema-only 0 is structure only. file/objdump-format 0; disassembly 1 because
  installed objdump lacks the target. Docker discovery 1: socket operation not
  permitted. No qemu-riscv64/rocq/rocqchk in PATH; no installation or alternate
  proof semantics. Missing runtime and independent-replay links remain explicit.
- Exact U225-authorized booking dispatch retried: CLI exit 1, API connection
  failure; direct workflow run list 0, empty. No manual run started. Owner consent
  for this exact operation already exists. Full hosted A/B/C/D remains NOT RUN.
  The earlier ordinary hosted gate/replay passed, but upload/report and workflow
  failed. Its 1.8 elapsed job-minutes are not billed usage or a reuse benchmark.
- Original archive checker 0: 10160 members each, no mismatch. Off-machine storage
  remains unconfirmed; prepared procedure needs independent destination, transfer,
  remote full validation/read-back and storage identity. Archives omit large and
  later evidence. Classic protection 403 still leaves effective controls unverified;
  administrator read-only exports are listed in the campaign report.
- Deliverables: results/campaign-audit-2026-11-02/CAMPAIGN.md, assurance-graph.json
  (24 claims, 312 classified links), EXPERIMENT.md, acceptance.json, raw logs,
  commands/source/evidence inventories. Existing integration status tool actually
  exits 1/NOT_ESTABLISHED. Metadata consistency check 0 is not proof checking.
- Smallest known workflow patch still applies cleanly (0). Exact separate review
  packet: proposals/ci-artifact-paths/APPROVAL.md. No publication/install/merge.
  RISC-V experiment still needs access to existing pinned environment and an exact
  approved runtime pin before execution. No protected schema/policy changes.
- Impact: H1 and E1 PARTIALLY_ESTABLISHED; E2 and durable reuse E3 NOT_ESTABLISHED.
  end_to_end=false. Stage 12 stays unauthorized; no Node, signing, deployment,
  protection, cross-run adoption or SPM change. Next check: working authorized
  hosted route, backup/admin records, pinned proof access, then scoped runtime
  experiment review. Do not infer any missing result from this audit.


## U227 — Concrete local upload repair; RISC-V runtime remains an environment/authentication gap

- Refs: U225, U226. Previous goal turn made progress with fresh verification and
  assurance records. This continuation prepares the exact reviewable packaging
  commit and investigates the remaining runtime source. CURRENT none; Stage 12
  unauthorized. No stage transition or protected main change.
- Fresh remote main read 0: f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3. PR 34
  read 0: draft/open/unmerged, same head 46e5aa42 and main base. booking-reuse.yml
  list 0: empty. No live manual workflow handle exists; no new dispatch attempted
  in this continuation. Prior exact U225 dispatch authorization still exists.
- Prepared local commit 705457e069abbe399128808b1efc7242d8eaeaa1, tree
  6b711b27efcd5c22248424a44d102b0dac6ae7ce, parent current main. Only file is
  .github/workflows/proof-gate.yml. Bytes exactly match the earlier proposed file,
  SHA-256 295b760ac2986d921c0459673c86d800784e81d248406b91454d5c85a5fc4e83.
  Patch check/application, diff check and commit preparation each 0 in an isolated
  temporary clone. Main unchanged. No publication, review, merge or signing.
- Self-contained proposal.bundle SHA-256
  b1f89e52d6df0c3a609b2a02b241beeffd71a91a74b4c84d4c7ad923f121e55a.
  Bundle verify, new bundle clone, exact checkout, git fsck --strict and diff
  check each 0; replay tree/file hashes match. This is another local process and
  filesystem copy, not independent storage or authenticated release evidence.
- Runtime investigation: archived Stage 7 tool identities cover six proof tools,
  not a complete OS inventory. No emulator is established inside the inaccessible
  image. Inspected host PATH/Homebrew inventory has no QEMU or GnuPG. Existing
  Docker access remains the needed route to the pinned Linux environment.
- Official QEMU mirror identifies v11.1.3 tag object
  34105b228c52e1d1d055003fab74d0503fa4bc37, commit
  005c61c0ef6f6ae615283440b4bb7be51b2c6ddd, tree
  330ad0feb766c9f88dd3950d2b5d14230e668a4f. VERSION 11.1.3; configure bytes
  from tag and exact commit match. Source lines 792–800 require Linux for explicit
  linux-user selection; a Darwin QEMU installation would not close that requirement.
  Source inspected only. No configure/build/emulator execution.
- Source identity is not source authentication. GitHub tag verification is false /
  no_user; commit unsigned. This does not establish an invalid PGP signature.
  No independent signature check ran. The official archive key must not be assumed
  to authenticate this separate stable Git tag. Actual archive-signature download
  exits 6 / DNS failure. Archive hash, verified signature, complete pinned build
  dependencies and executable hash are not established. Candidate pin is explicitly
  not ready for execution. No custom cryptographic checker or tool installation.
- Fresh classic-protection API still 403. Generic fetch for effective branch rules
  rejects that endpoint with tool HTTP 400. Neither establishes absent controls.
  Administrator read-only effective/classic/inherited exports remain required.
  Independent off-machine backup remains unconfirmed; no destination or transfer.
- Evidence: results/campaign-preparation-2026-11-02/{STATUS.md,commands.json,
  prepared-state.json,replay.json,proposal.bundle,qemu-source-candidate.json,
  qemu-release-tag.json,qemu-configure.source.txt,observations.json}.
  Publication packet: proposals/ci-artifact-paths/READY.md. Publication needs its
  own authorization; it would not authorize review approval or merge.
- Impact: no new hosted proof, executable observation or complete EXIT. H1/E1
  remain partial; E2/durable reuse E3 and integration EXIT NOT_ESTABLISHED;
  end_to_end=false. Next checks need working authorized hosted access, separate
  publication consent, administrator/backup evidence and a trusted Linux runtime.
  No new infrastructure, Node, deployment, protection, cross-run reuse or SPM work.


## U228 — Third-turn access/authorization blocker audit; no live hosted experiment

- Refs: U225–U227. Previous goal turn was progress: exact local repair and
  runtime-source investigation completed. This turn revalidates the same external
  execution and approval boundaries. It produces no new proof or hosted result.
- Fresh git main read, PR 34 metadata and booking workflow list each exit 0.
  Main f9eb1cbc…, candidate 46e5aa42… remain unchanged; PR 34 draft/open/unmerged.
  Manual workflow list is empty before and after the dispatch attempt. There is
  no live run/session handle to wait on. Existing ordinary PR failure is terminal.
- Retried the already-authorized exact booking dispatch after current identity
  checks: CLI 1, API connection failure. No new run found. Missing user consent
  is not the blocker for that exact operation. Connected tools still have no
  initial workflow-dispatch method; rerun methods cannot start a nonexistent run.
- Fresh Docker discovery exits 1: socket connect operation not permitted. The
  existing pinned Linux proof environment remains inaccessible. Classic-protection
  API remains HTTP 403. Expected remote backup read-back file is absent; this
  leaves off-machine storage unconfirmed, not proved nonexistent.
- Same blocking conditions remain across U226, U227 and this third consecutive
  goal turn. Authorized useful local preparation is complete at this boundary.
  Further proof/CI/guest execution needs an external access change. Publishing
  705457e0 still needs separate authority under the campaign rules. Backup and
  effective protection confirmation need owner/admin evidence. No workaround,
  expanded scope, repeated passing proof or new infrastructure is justified.
- Full objective remains unachieved. H1/E1 partial, E2/durable reuse E3 and
  integration EXIT NOT_ESTABLISHED; end_to_end=false; CURRENT none; Stage 12
  unauthorized. Blocked-audit threshold is met; request goal status blocked.
- Evidence: results/campaign-preparation-2026-11-02/blocked-audit.json. Exact
  publication packet READY.md and authorized hosted dispatch helper remain ready.
  Resume after a working execution route or the relevant explicit authorization /
  administrator / independent-storage evidence arrives. No merge, publication,
  signing, protection change, Node, deployment, cross-run adoption or SPM work.


## U229 — Hosted matrix established; exact-binary runtime precondition is violated

- Refs: U166, U169, U225–U228; owner campaign attachment. Owner resumed work and
  authorized the prepared packaging publication. CURRENT none; Stage 12 remains
  unauthorized. Earlier blocked access reports are historical, not current.
- Actual main f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3, tree
  624ef75c46cdd260b39308763cfdf27ed8ba99e5. PRs 30/32/33 remain merged.
  PR 34 stays draft/unmerged at 46e5aa426bf7800df7c98c732a764337e716f6bb.
- The already-authorized exact booking workflow dispatch returned 0. Real hosted
  run 41523691535, attempt 1, job 125545854178 succeeded. All 13 cases matched:
  cold/warm/invalidation/restored booking launches 1/0/1/0. Gate returns 0/0/0/0;
  eight receipt/artifact/identity/harness/anchor/prior-process attacks returned 1;
  uncovered change returned 3. None accepted evidence on failure. Artifact audit
  command returned 0. Matching key and established status do not permit adoption.
- A/B/C elapsed 28.525340852/9.931031468/28.552900072 s. Job 198 s = 3.3 runner-
  minutes. Public standard Ubuntu usage API reports zero billable milliseconds;
  this is not zero computation or an invoice/savings claim. Warm still executes
  outer-ledger work; only Booking proof is skipped. Its receipt retains original
  producer commands and duration, which are not warm execution observations.
- Artifact 13179905102 ZIP SHA-256
  372cd7781b1be493a13bbd4398cb6871cbf2effe6458810425dd25fcf49efbf1
  matches the authenticated GitHub artifact API. Raw Booking verification logs
  and 238 passing TRX results are retained for cold and invalidation. Outer-ledger
  raw snapshot/audit/version logs were not uploaded; parsed member counts are
  producer observations only. C changes a source helper predicate, not a separate
  cross-file dependency, model or policy. Preserve these scope limits.
- Fresh old-run job log reconstructed the prior receipt, equal to its frozen
  record. Prior and current hosted outer evidence bytes match 83b60e8e… . Current
  Booking bytes match e03b17d5…; prior Booking bundle/raw logs were not retained,
  so only its reported digest is available for that earlier execution.
- Published exact packaging repair 705457e069abbe399128808b1efc7242d8eaeaa1
  as contributor-authored PR 36. Initial owner-authored PR 35 was closed unmerged;
  explicit cached contributor credential selection corrected publication identity.
  No credential recorded. PR 36 remains OPEN, REVIEW_REQUIRED/BLOCKED with no
  approval; protected-workflow gate fails as expected before approval. No merge
  or bypass. The successful manual upload does not prove the ordinary PR upload
  repair works. PR 36 needs independent exact-head review and merge authority.
- Owner CLI read-only protection exports now succeed. Classic protection is
  absent (404); effective active ruleset 26065125 requires independent review,
  CODEOWNERS, last-push approval, stale dismissal and resolved threads. It blocks
  force pushes/deletion. It has an admin PR bypass, unused. Neither effective
  rules nor detail requires status checks/workflows. This is an observed control
  gap, not a 403 uncertainty. No protection was changed.
- Fresh isolated historical signature-only check 0 (4.599941 s). Unchanged full
  release.verify 0 (68.136261 s), with actual online TUF/Cosign, full artifact/
  receipt/source/run bindings and five approved lineage merges. Historical source
  624c9faf… and lock 5f78da21… only. No controller read, signing, new admission or
  deployment. Normal HOME retained; no independent-machine or fresh-cache claim.
- Authenticated QEMU 11.1.3 source archive signature with real GnuPG, exit 0.
  Separate Ubuntu 8.2.2+ds-0ubuntu1.18 static runtime package authenticated through
  existing image keyring, signed InRelease, exact Packages index and .deb hashes.
  Runtime SHA-256 be89e201dc6112ef101617ab575c95119ad123f80ca2b51b6c36ef218ac9df65.
  No source build or package installation into the proof image was claimed.
- Direct mounted ELF loading first returned 1 without guest trace; cause unknown.
  A private tmpfs copy of the exact ELF 8ced2ab6… then ran under pinned QEMU and
  returned 0. Trace starts at PC 0x11158 and ends in exit_group(0). Original signed
  bytes unchanged. This is TESTED observation only, not an admitted deployment.
- Independent audit found initial SP 0x2aaaab2abc30 below valid_sp_va Sv48 minimum
  0x7fff80000000. Existing-predicate Rocq diagnostic compile actually returned 0
  (577.665 s), proving the observed SP is invalid. Existing valid_entry premise
  therefore fails. Full QEMU/LPS initialization and environment refinement remain
  unestablished. Do not interpret a successful run as theorem instantiation.
- Restored exact approved checker image and case-sensitive source volume, with
  original pins/non-root resources; restoration checks 0. Fresh unchanged own-
  proof EXIT then returned 1 after 1496.251277 s. Container returned 137. Inspect
  and collection each returned 1; container, volume and image were absent. Cause
  UNKNOWN; no OOM evidence, no identified cleanup actor. Docker events reader
  timed out without recovered events. No resource relaxation or blind retry.
  Failure evidence remains on the host. No fresh full independent kernel verdict.
- Concrete unpublished proposals preserve raw outer logs, run the current proof
  alone on GitHub, and state an additional abstract-model property for separate
  intent review. Proof-only workflow syntax/pin/patch checks 0; hosted execution
  NOT RUN. New property NOT RUN. Neither proposal changes an accepted contract.
  Current production signing workflow and obsolete dry runs were not dispatched.
- Original archives remain preserved and locally validated in prior session
  commands. Exact-name Google Drive searches returned no copies; this does not
  establish absence everywhere. Independent archive backup remains unconfirmed.
  Need owner-selected private destination or existing-copy identity, transfer,
  remote full manifest/member checks, read-back and independent storage evidence.
  New hosted artifact is off-machine evidence for H1, not backup of old archives.
- Existing integration status command returned 1, naming unconfirmed backup.
  protections_verified means inspected, not passing-check enforcement. H1 is
  established within the same-process supported boundary. E1 remains partial;
  E2 and generic durable reuse E3 NOT_ESTABLISHED. Historical consumer verification
  is a narrower successful E3 check. end_to_end=false; no stage transition.
- Evidence: results/campaign-resume-2026-11-02/STATUS.md, assurance-graph.json,
  hosted-acceptance.json, command records, raw logs and exact artifact ZIP. Old
  sealed campaign audit/preparation records remain unchanged. See proposals/
  {ci-artifact-paths,booking-raw-logs,binary-proof-replay,runtime-entry-domain}/.
- Next checks: independent PR 36 review; confirm private archive storage; resolve
  required-check policy separately; authorize exact new workflow publication and
  later dispatch, or restore a stable existing local proof environment. New model
  scope requires explicit intent approval. No signing, Node, cross-run adoption,
  production deployment, protection change or SPM work is authorized here.


## U230 — Fresh historical consumer controls and archived-object kernel recheck

- Refs: U226–U229; owner campaign attachment. The previous goal turn was progress:
  actual hosted results and record/proposal preparation changed the next action.
  User resumed the full goal. CURRENT none; Stage 12 unauthorized. No objective
  was reduced to H1 or historical signature verification alone.
- Fresh main/PR36 reads 0: main f9eb1cbc… unchanged; PR36 still open at705457e0,
  REVIEW_REQUIRED/BLOCKED with no reviews. No approval, merge, new workflow
  publication, dispatch, signing, admission, deployment or SPM change this turn.
- Safe alternative to the interrupted source build: inspect the complete archived
  certificate instead of rebuilding or restoring the missing source volume.
  Existing approved image pull returned0. Parent preparation returned0 after
  checking all579 .vo inputs against the independently pinned old artifact-
  identities,45 Python package files and exact86 upstream tool/allowlist files.
- New readonly, network-disabled UID/GID1000 container runs the unchanged published
  oft.check._rocqchk with the exact old kernel command, CPU0/memory4g/pids512.
  Actual Rocq process and advancing log were confirmed by Docker inspect/top.
  Raw output streams directly to a private host directory. Session24949/container
  forge-archived-kernel-recheck-20261102-0001 is RUNNING at this record. No final
  independent-kernel exit exists yet. Postflight is NOT RUN. Do not restart this
  process because observation expires; re-poll the same handle/actual container.
- Independent readonly review found no blocking defect in this intended check.
  It noted that the running driver checks expected audit-tool bytes but permits
  extras internally. Exact membership passed in the parent before launch and
  again live; postflight requires it after completion. No extra file observed.
  Host/import races remain within the explicit trusted-host boundary. Old lock
  labels are not authentication; the fresh crypto and remote artifact chain below
  anchor the inputs. No result or source-build claim is inferred from labels.
- Observed Rocqchk executable SHA256
  3b432fdfa34b7b49887b21293705442b243399ce866ea0d22d4c94c91247670b.
  Exact image Python3.12.3/568 installed-library hashes are recorded. The host is
  the same physical Mac. Docker top exposes Rosetta translation; its injected
  host path is not visible inside the container. Initial optional metadata probe
  returned1 on that path; second probe0 records actual available hashes and the
  visibility limit. No separate Rosetta binary hash or independent host claim.
- Read-only GitHub API listing/download returned0/0. Original signed artifact
  12939158560 remains unexpired in run40966460258 at historical source624c9faf… .
  Fresh ZIP SHA256
  8ded75a093cb5d9c1e24f240c4209279b363e4d5fc3338a73a20b086c984cfb4
  matches the authenticated API digest and old downloaded ZIP. Full safe member/
  CRC/hash comparison returned0: all881 files/132535811 uncompressed bytes match
  the baseline bundle. This confirms GitHub storage of this signed bundle only.
  It does not confirm the original raw/sanitized archive pair or later local
  campaign records are independently backed up.
- New isolated historical release.verify consumer matrix: initial harness1 due
  to this agent's wrong predicted ELF rejection name. Actual verifier correctly
  rejected substituted packaged.elf as PACKAGED_ELF_BYTES with Cosign0. Original
  failed suite/fixtures/results remain intact. Corrected expectation cites the
  unchanged release.py:160; RELEASE_ELF_IDENTITY:157 concerns the immutable
  reference, not the changed package file. No policy or permanent test weakened.
- Corrected full14-case suite actually returned0. Two full bracketing positives
  and a signature-on-its-own-artifact probe returned0/Cosign0. Nine evidence,
  receipt, dependency, coordinated proof+receipt, ELF, signed policy/spec/method/
  request binding negatives returned1 with exact reasons and Cosign0. Unsigned
  and wrong-digest negatives returned1/Cosign1 with intended diagnostics. The
  valid different-artifact signature passes for its own bytes and rejects for
  the required ELF. Setup/infrastructure errors cannot satisfy those assertions.
- Independent agent review and root record audit0 checked all14 cases and464 raw
  command-output hashes. The copied fixtures isolate every mutation. Positive
  checks55.370986/55.054855 seconds. Measurements are local; no hosted runner-
  minute, fresh-cache, independent-machine or savings claim. No controller read,
  consumed-request replay/admission test, signature creation or new release.
- Consumer record inventory returned0:12124 files/links,2123171281 inventory bytes;
  manifest73ac8f86ed618e85b77765e8edd6bb1a0f5db3b16be3ed7f5518dbbf7e8b80a7.
  It preserves both attempts. This local inventory is integrity only, not evidence
  authentication or off-machine backup. Prior sealed campaign records unchanged.
- New graph checkpoint retains24 claims/312 classified links. H1 stays established
  within its recorded same-process boundary. Historical consumer validation has
  stronger fresh evidence; generic cross-run cache adoption remains disabled.
  E1 still partial: kernel replay is incomplete and observed QEMU SP still
  violates valid_entry. Full runtime refinement and approved complete executable
  assurance contract are absent. E2 remains NOT_ESTABLISHED; do not start it.
- Evidence: results/campaign-kernel-recheck-2026-11-02/attempt-0001/{STATUS.md,
  REPRODUCE.md,kernel-invocation.json,expected-inputs.json,active-checkpoint.json,
  historical-download-verification.json,assurance-graph-checkpoint.json}; and
  results/campaign-consumer-controls-2026-11-02/attempt-0002/{STATUS.md,
  results.json,acceptance-audit.json,correction.json,independent-review.json}.
- Next action: poll the confirmed live kernel, collect its actual terminal status,
  then run postflight only after success. Preserve any failure. Runtime intent/
  model boundary still needs its exact decision; original backup needs a private
  destination/existing-copy proof; PR36 needs independent review; required merge
  checks are absent. New workflow/spec/publication/dispatch boundaries are unchanged.
  Do not mark the full campaign complete. end_to_end=false; goal remains active.


## U231 — Independent proofs pass; recorded execution conforms to published model steps

- Refs: U226–U230. CURRENT none; Stage 12 unauthorized. This turn made concrete
  progress. It did not reduce the full objective to the checks already passing.
  All kernel/compiler/execution sessions in this record are terminal.
- Historical archived-object replay actually returned0: the exact old proof
  and witness closure is579 modules,86 permitted assumptions. Container0, no OOM,
  input hashes unchanged; postflight0. Parent1533.486016s, driver1530.232012s.
  Raw kernel log SHA25617f533b4873ea0ba11ede10140b6b1c41289402398737056862e00508e935758.
  The interrupted fresh source build remains failed1/137 with unknown cause;
  independent compiled-certificate checking is a different completed operation.
- Clarify E3 against the campaign's actual definition: independent PROCESS
  validation of a named claim, not a generic durable cache. Historical S7
  termination/witness validation is ESTABLISHED for exact ELF8ced2ab6… under old
  source624c9faf…/lock5f78da21… . Fresh remote archive/authentication, exact input
  identities, full independent kernel, supported claim checks and14 consumer
  controls all ran. Generic cross-run receipt adoption remains disabled and is a
  separate NOT_ESTABLISHED capability. No old signature or request was upgraded.
- A local initializer-domain proposal compiled0; published binding/audit0, same13
  permitted primitive assumptions. It removes unused validity hypotheses only in
  a distinct abstract proposition. Original accepted theorem remains unchanged.
- Authority correction: the campaign already permits safe LOCAL feasibility tests.
  This agent's prior local-compile permission request was broader than necessary.
  No reply was inferred as approval. No baseline specification/policy was changed.
  ADOPTING an additional claim or activating an evidence profile still requires
  exact intent/protected-change approval. Publication/merge/signing/dispatch/
  deployment/Stage12 boundaries remain separate. Self-authored pre-test proposal
  permission wording does not override the campaign's existing local-test grant.
- New memory-independent proposition compiled0(1.532591s), published wrapper0/
  assumption audit0(13 primitives). Exact sourceSHA
  ffe5a677e14b5d426196b3c8e56c821f4775037855b63c2a902c2f253c7cebfc.
  It quantifies arbitrary data memory and initializer parameters and any unhalted
  LPS model with no lazy mappings. Existing published soundness proves normal
  exit0. It is not a theorem about arbitrary machine states or arbitrary GCD inputs.
- Its full independent published _rocqchk actually returned0:569 recursive modules,
  86 permitted closure assumptions, container0/no OOM. Parent1599.281454s;
  driver1598.600330s. Required new statement/wrapper objects were checked; all loaded
  objects lie in the581-object pool(579 old authenticated objects+2 new exact
  objects). Exact audit import membership and all pool hashes pass before/after.
  No dependency was admitted or skipped. Actual569-member closure is preserved.
  Raw kernel logSHA413c743d3f67dbcc431f9945b862baea3ce13fe1f59f04392b70679cb1b94aaf.
- Separate-process rebuild in empty directories returned0/0. Theorem object
  8462ea5aeee1a0f30c1c82f7ec88799693be0575f2affdc1a8c2706348622324
  and wrapper object1fd3d856df27d344c972290aac0dbbae80be36561d10ec9bc682da0419d14655
  reproduced byte for byte. No cached verdict was adopted. New proof remains
  unadopted/unsigned for its additional claim, notwithstanding its checked truth.
- Separate stronger arbitrary-register trial exhausted the fixed4GiB budget:
  actual137, OOMKilled=true,65.094146s. This is a method/resource failure, not a
  proof that the proposition is false. Source/output/container state are retained.
  No cap was raised and no passing result was invented. The memory proposition
  was compiled before this optional stronger experiment; its scope was unchanged.
- New exact-byte QEMU run returned0. Actual pinned help lists one-insn-per-tb,
  fpu/page/nochain logging; debug-help conventionally returned1 after printing
  usage, not a guest/proof failure. Trace contains21 instruction frames/13 words,
  guest RX0x11000..0x12000 and RO0x10000..0x11000, entryPC0x11158, terminalexit_group0.
  Guest SP remains0x2aaaab2abc30; the old valid_entry premise is still false.
- Rocq entry/register/word comparisons returned0; altered word returned1 at the
  intended equality. Initial wrong import prefix failed1 as setup and was not
  counted as a negative control. Corrected prefix matches published source;
  original files/logs are retained, not rewritten into passing results.
- Full21-state projected comparison using EXISTING Omni.run_steps returned0.
  It compares PC+all32 integer+32 floating registers at steps0..20. Single changed
  intermediate x10 at frame4(1071->1070) returned1 at the transition equality.
  Extended check quantifies arbitrary data memory, reservation and FCSR; positive0
  (2.219351s), same middle-register negative1(3.161118s). Published assumption
  parser reports13 permitted primitive assumptions. Independent readonly review
  reconstructed raw frames and checked source/hash/negative-difference identities.
- Model step21 pending syscall94,arg0 is computed, not an observed post-ecall frame
  or syscall dispatch. These comparison objects have compiler acceptance; separate
  full independent kernel for them NOT RUN. Finite projected conformance is not
  universal QEMU refinement, full physical-state abstraction or noninterference.
  Reservation/FCSR values remain unobserved but the finite equality holds for any
  such values. Actual execution is a private exact-byte research copy in the
  checker image, not a new admitted deployment of the old signed package.
- A concrete11-file proposal is prepared locally at
  5bb008a1b7d40b8887d045f50eb55e54544bb76f, tree44c0d88af2c94978729f5e83fa71b9045e0e25a0,
  basef9eb1cbc… . Only proposals/fixed-elf-assurance/** changes. It contains exact
  proof/wrapper, raw lossless-compressed kernel/runtime logs, full dependency/
  assumption data, finite comparison source and clear non-admissible case limits.
  git diff/apply checks and bundle verification0. BundleSHA
  ab64719c4ffa6fc699f6a7558f084a9c9a4adcf6c8256427438d0e16459fb868.
  Initial packaging diff-check2 flagged an original QEMU trailing space; outer
  preparation1. All initial data are retained; lossless XZ preserves exact raw
  bytes and final diff-check0. No proof/evidence content was stripped.
- Fresh main/PR36/effective-rules reads0: mainf9eb1cbc unchanged; PR36 still OPEN,
  REVIEW_REQUIRED/BLOCKED at705457e0 with no reviews. Rules still require review
  but no status/workflow checks. No settings or baseline source changed. Proposal
  5bb008a1 publication and claim-intent decision are pending; it was not pushed.
  Earlier proof-only workflow is now optional for hosted source rebuilding; it is
  not needed to pretend that a local kernel recheck remains blocked. No new
  workflow was published or dispatched.
- E1 is PARTIALLY_ESTABLISHED: additional model theorem and observed conformance
  are real; accepted intent/profile, runtime/refinement assumptions and new
  release/runtime/package authorization are unresolved. The old signature cannot
  authenticate this new statement. Strict integration EXIT remains NOT_ESTABLISHED
  while original independent archive backup is unconfirmed. GitHub stores the old
  signed bundle, not a confirmed backup of the raw/sanitized pair or later records.
  E2 remains NOT_ESTABLISHED; no component implementation or Stage12 started.
- Current evidence: results/campaign-kernel-recheck-2026-11-02/attempt-0001/
  {STATUS.md,assurance-graph.json,postflight.json}; results/campaign-memory-
  feasibility-2026-11-02/attempt-0001/{result.json,binding/,kernel-recheck-0001/,
  rebuild-0001/}; results/campaign-runtime-projection-2026-11-02/; and proposals/
  runtime-state-projection/{prepared-pr.json,review-packet/README.md,proposal.bundle}.
  Previous sealed records remain unchanged. New local tests do not authorize
  publication, policy activation, admission, signing, merge or deployment.


## U232 — Observation proof independently kernel-checked; approval boundaries remain

- References: U229, U230, U231. CURRENT remains none. Stage12 is unauthorized.
- Evidence: actual unchanged published `_rocqchk` returned0 for
  ForgeObserved.ObservedTransitions. Container0, OOMKilled=false, postflight0.
  Actual recursive closure567 modules;86 permitted closure assumptions. All
  loaded objects are in the exact580-object pool:579 independently anchored
  historical objects plus the exact local observation object. Required root is
  included; all input hashes and exact audit import membership match before/after.
- Parent wall1488.771601s; driver1485.525275s. Raw kernel log SHA256:
  8d4ea9d50da50abe71e95bd7e3cbae1bf5d111228fa3b483769b660cce361482.
  These are local emulated-container measurements, not hosted runner usage,
  native performance or savings. This check does not adopt an old cached verdict.
- A new process compiled the exact observation source in an empty output
  directory: actual0,2.363891s. The .vo reproduced byte for byte:
  efebc5920bfeafbf5b3355bbb1799ff9cdfee42e3035ff7855a28b77fff90c76.
  Source95e121bb0c14f0f625e4cd9521a434858dd2d757366b00c9ba13eaf55881ec39.
- Read-only independent review found no blocker to this limited statement.
  Two inherited metadata fields remain preserved and explicitly corrected:
  earlier candidate wrapper hash and historical baseline module/assumption
  lists. They are not used by this driver as verdicts. Actual closure/assumption
  outputs determine the result. No wrapper-binding check is claimed here.
- Impact: the21-state projected PC/GPR/FPR equality and modeled pending syscall
  now have a separate full kernel check. The U231/packet statement that this
  independent comparison check was NOT RUN is superseded. Finite conformance
  does not establish universal QEMU refinement, complete physical-state
  abstraction, loader correctness or outside noninterference. Actual exit0 is
  an observation; the model syscall request is not an observed post-ecall frame.
- Five newly sealed earlier result directories passed full inventory read-back0.
  Their195 file/link entries and68767020 inventory bytes remain unchanged.
  Original raw/sanitized archives passed the existing checker0 again:10160
  members each, no mismatches. This does not establish independent storage.
  Owner-selected SSH destination requested; no answer/copy was inferred.
- Effective main rules and ruleset reads returned0/0. Classic protection read
  returned1/HTTP404, not403. Active review rules still apply; required status/
  workflow checks are absent. Admin PR bypass exists but was not used. No
  protection changed. Final PR34 head46e5aa42 and PR36 head705457e0 are unchanged,
  both open; PR36 reviews remain empty. Main remainsf9eb1cbc.
- Proposed additional claim/publication packet5bb008a1 remains local, unchanged,
  unpublished and unapproved. Its source/property were not changed by the new
  check. A local observation-kernel supplement records the new evidence. No
  missing intent approval became consent through time or a successful proof.
- Uncertainty/impact: E1 remains PARTIALLY_ESTABLISHED; accepted profile/intent,
  runtime/refinement assumptions and new authorized release bindings remain open.
  E3's historical independent-process validation stays ESTABLISHED within its
  exact scope. Generic cross-run receipt reuse remains disabled. E2 remains
  NOT_ESTABLISHED. Integration EXIT remains NOT_ESTABLISHED; end_to_end=false.
- Next check: owner decision for exact proposed claim/publication5bb008a1;
  independent PR36 review and separate merge authority; confirmed independent
  archive destination and remote full read-back; administrator decision on
  required checks. No signing/admission/deployment/Node/SPM/Stage12 action.
- Records: results/campaign-observation-kernel-2026-11-02/attempt-0001/
  {STATUS.md,postflight.json,kernel-output/,rebuild-0001/,metadata-review.json,
  independent-review-final.json,final-github-state.json,assurance-graph.json};
  results/campaign-e1-seals-2026-11-02.json; proposals/runtime-state-projection/
  OBSERVATION-KERNEL-SUPPLEMENT.md. Earlier sealed records remain unchanged.


## U233 — New proof-object corruption and weaker-statement substitution refuse

- References: U231, U232. Previous goal turn made progress through the actual
  independent567-module observation kernel check. Current stage remains none;
  Stage12 is unauthorized. The full campaign remains incomplete.
- New actual local controls: one-bit mutation of ObservedTransitions.vo is
  rejected1 by the existing driver at exactly
  AssertionError: DEPENDENCY_BYTES:/observed/ObservedTransitions.vo.
  A real Rocq-compiled weaker statement uses20 projected states instead of21,
  with unchanged module/lemma names. Compilation0, held-object identity refusal1,
  same exact reason. Matrix command0 checks both intended outcomes explicitly.
- Both negative containers exit1/noOOM and neither starts the proof kernel.
  These are intended object-integrity refusals, not compiler/setup failures or
  semantic kernel rejections. The previous positive567-module kernel0 was not
  rerun. The original receipt-corruption regression remains separate and intact.
- The expected anchor remains outside the candidate fixture mounts. Its SHA256
  3ef50c1e7e46d2015342aeca56a491abe9f7639b9039785582c4118f06ab4d7c
  and driverd95421f6d621a7dfd0cec0bbfe6f9c123e00dd7db8bd248ac4036512a69ff1a7
  remain unchanged, as do original source95e121bb… and objectefebc592… .
  Original input identities match before/after. Expected digests were not taken
  from either hostile candidate, and no policy or accepted spec changed.
- Weak source0e5a9b2dc58a809a99955aec587207725958d50003ea5c4e0bdc68050c64f0f6
  compiles to2176e4fbeb5ced35e7278bd271e30b5fe71a843f7b2ce4140b95c21993f09446.
  Corrupted object907b0a915c0e31af44f36913ba50e73229065c574849360ee35623eeddef8610.
- Read-only independent review confirms the intended refusals. A metadata
  correction preserves the raw generic candidate_compiled_before_this_run=true
  flag: only the corrupted object's ancestor was compiled; its mutated bytes
  were not. The flag is not used for acceptance. No owner/GitHub approval follows.
- Local elapsed measurements: real weaker-fixture compilation4.600383s,
  corrupted-object guard0.584913s, weaker-object guard0.525794s. These are local
  orchestration/identity-guard durations, not full proof times, hosted minutes
  or savings. No full kernel check was repeated for hostile inputs.
- Fresh GitHub reads succeed: mainf9eb1cbc unchanged; PR36 remains open at
  705457e0, basef9eb1cbc, reviews empty. Proposed packet5bb008a1 remains local,
  unpublished and unapproved. No publication, approval, merge, workflow dispatch,
  signing, admission, deployment, branch-protection, Node or SPM operation occurred.
- Impact/uncertainty: this establishes refusal against a separately held trusted
  local expectation. It does not authenticate an attacker-supplied expectation,
  establish durable new-claim provenance, or resist coordinated candidate-and-
  anchor rewriting. Generic cross-run receipt adoption remains disabled.
  E1 remains PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical E3 remains
  established only within its old named claim/artifact/lock trust scope.
- Remaining boundary/next check: exact proposed claim/publication owner decision,
  independent PR36 review and separate merge authority, owner-selected independent
  archive destination plus full remote validation, administrator required-check
  decision. No unanswered question was treated as consent. Integration EXIT
  remains NOT_ESTABLISHED; end_to_end=false.
- Evidence: results/campaign-observation-adversarial-2026-11-02/attempt-0001/
  {STATUS.md,run_controls.py,results.json,summary.json,identities-*.json,
  corrupt-object/,weakened-statement/,metadata-corrections.json,
  independent-review.json,assurance-graph-delta.json,github-state.json};
  proposals/runtime-state-projection/OBJECT-INTEGRITY-SUPPLEMENT.md.


## U234 — Local native-cache baseline and real Forge work measurements

- References: U225, U229, U232, U233. Current stage remains none; Stage12 is
  unauthorized. Safe local measurement of the completed booking workload is
  independent of the pending E1 claim/profile decision. The full campaign remains
  incomplete. No new acceptance mode, backend, policy, framework or workflow.
- Actual pinned Dafny4.11 version/internal-help commands0/0. Existing native
  snapshot support was exercised through the current gate's legacy options and
  unchanged scripts/benchmark_reuse.py trace parser. Modern help alone did not
  establish native cache behavior. No package/tool install occurred.
- Actual run_pair.py0: two fresh full-booking/witness commands0/0, elapsed
  10.793149s and10.842894s(total21.636042s),33 members checked each. Native A→A
  snapshot command0,10.632152s for the entire pair,33 checked then33 reused.
  Frozen inputs are the five approved booking proof source files, with the same
  supported PR34 helper implementation change. All required33 member names match.
- Actual measure_forge.py0 uses unchanged incremental.check, not a substitute
  acceptance path. Cold/warm/invalidation gate exits0/0/0, complete coverage,
  affected ledger-proof/booking. Booking launches1/0/1 and receipt reuseF/T/F.
  Gate wall27.589211/10.510417/27.120746s. Isolated booking verifier command
  wall10.193022/0/10.170594s. Warm still executes outer ledger/audit/policy/
  coverage/integrity work. Its zero is no new booking command, not a reused
  receipt's original duration relabeled as current cost.
- A/B evidence matches exactly(a55a18d4…); source artifact627b4ee0… . C changes
  source identity, cache key and source artifactd78b1410…; fresh evidencec0f051dd… .
  Both fresh booking executions retain238 passing TRX batches, normalizing to
  the same33 required native member names. C changes only the equivalent helper
  body from other<=value to !(other>value), as in the earlier hosted demonstration.
- Actual native_invalidation.py0: full C checker0/11.614398s, native A→C pair
  checker0/13.920191s including its cold baseline. Native first snapshot checks33;
  changed snapshot checks Booking.Least(correctness) and reuses32. All33 members
  are present with zero errors, and C's five hashes match the Forge C fixture.
- Read-only independent review checked raw log hashes, fixture source hashes,
  complete coverage, actual command outcomes and member counts. It found no gate
  bypass or misleading timing calculation within the stated scope. No approval.
- Scope/uncertainty: this is one preparation sample per case, fixed order, local
  macOS/arm64. The full Forge gate has extra ledger/binding/audit/policy work;
  raw native booking verification does not. Legacy trace and modern JSON/TRX
  command interfaces also differ. Same booking inputs/member sets do not make
  total acceptance costs identical. Direct whole-gate speedup comparison is invalid.
- Native33 member names, Forge238 TRX batches and339 native reported assertions
  are distinct units. Cached native row times/resources are retained producer
  values, not current warm work. Pair times include baseline; isolated native
  warm wall is not measured. Fresh pairs use two processes, native pairs one;
  startup/parsing and OS-cache effects prevent exclusive attribution to reuse.
  No general savings, hosted runner-minutes or invoice cost is established.
- Repeated/counterbalanced complete-path comparison remains NOT RUN. Existing
  native dependency collection/cache/checksum behavior stays in the checker TCB;
  no adversarial checksum collision study. Generic Forge cross-run receipt
  adoption remains disabled. Old Linux evidence/signatures were not transferred
  to this macOS run. No new source-to-executable/service correctness claim follows.
- Main/PR36 remain at the fresh U233 identities; no new external mutation.
  Local proposal5bb008a1 remains unchanged/unpublished/unapproved. E1 stays
  PARTIALLY_ESTABLISHED, E2 NOT_ESTABLISHED, historical E3 scoped validation
  unchanged. Off-machine archive backup is unconfirmed. No pending answer became
  consent. Exact owner claim/publication decision, independent PR36 review and
  separate merge authority, backup destination/read-back and required-check
  decision remain. No Node integration, SPM, signing, admission, deployment,
  protection change or Stage12. Integration EXIT NOT_ESTABLISHED; end_to_end=false.
- Evidence: results/campaign-native-cache-feasibility-2026-11-02/attempt-0001/
  {STATUS.md,run_pair.py,measure_forge.py,native_invalidation.py,frozen-inputs.json,
  pair-commands.json,pair-summary.json,*-snapshots.json,forge-observations/,
  native-invalidation/,independent-review.json,assurance-graph-delta.json}.


## U235 — Three unchanged owner-boundary audits; blocked threshold satisfied

- References: U231, U232, U233, U234. Current stage remains none; Stage12 is
  unauthorized. Full campaign objective is not achieved. No milestone was
  redefined around the completed hosted matrix or local proof experiments.
- Evidence: three consecutive goal turns have only revalidated the same genuine
  owner-action boundary. They are no progress, not verified waits. The previous
  meaningful turn ran object-integrity controls and local native/Forge measurements.
  Audits1/2/3 are in results/campaign-boundary-audit-2026-11-02/attempt-000{1,2,3}/.
- Third fresh GitHub reads succeed: mainf9eb1cbc unchanged, PR36 exact705457e0
  open/unmerged, reviews empty. Local proposal git HEAD/status0/0:5bb008a1 and
  clean. No new owner reply authorizes its claim adoption or publication.
  Earlier exact-head grants do not authorize a new claim/profile or operation.
- Three known proof-container inspections0/0/0 show no running process. Earlier
  completed proof exits remain0. No timeout, stale state file, expressed intent
  or unanswered question was treated as a live process or consent. No process
  was restarted merely to generate activity. No proof/benchmark was rerun.
- The expected destination-integrity.json is absent. An independent archive copy
  remains unconfirmed, not disproved everywhere. A private destination or
  verifiable existing-copy identity is missing. Local checksums and a different
  GitHub-hosted signed bundle do not confirm backup of the original archives or
  subsequent records. No data was uploaded to a guessed destination.
- Impact: continuing the first executable assurance case needs an exact owner
  decision on the prepared claim/publication packet5bb008a1. Adopting protected
  acceptance/profile changes, new release bindings, signing/admission/dispatch/
  deployment still have separate approval boundaries. PR36 needs independent
  review and separate merge authority. Required-check policy needs an explicit
  administrator decision; branch protections were not altered.
- No remaining already-live check can resolve these human-authority or storage
  facts. More repetitions would not establish the missing intent/provenance/
  approval links. The current raw-verifier preparation does not establish equal
  complete-acceptance costs; the repeated complete-path study remains NOT RUN.
  E2 must not start before the first narrow assurance case and separate authority.
- Blocked audit criterion is now satisfied: same equivalent condition for three
  consecutive no-progress goal turns, no new grant/external change, and no
  meaningful next action within the current authority that closes this boundary.
  The agent must request goal status blocked. The actual goal-tool return follows
  this journal entry; this entry is not a fabricated execution of that API.
- Next owner actions: decide exact scope/publication5bb008a1 after reading
  proposals/runtime-state-projection/READY.md and its referenced proof/limits;
  independently review PR36 at705457e0; provide separate merge authority when
  eligible; select independent backup destination or supply copy/storage identity
  and permit full remote validation; decide required-check settings explicitly.
  Publication approval alone does not authorize merge, policy activation,
  signing, admission, dispatch, deployment or Stage12.
- Prior evidence remains intact and scoped. H1 established in its recorded
  experiment; E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical E3
  independent-process validation established only for the old named claim,
  exact ELF/source/lock and stated trust model. Generic cross-run receipt
  adoption remains disabled. Integration EXIT NOT_ESTABLISHED; end_to_end=false.
  No Node/SPM, protected source, review, publication, merge, signing, deployment,
  admission, workflow dispatch or branch-protection change occurred in these audits.


## U236 — Resumed local publication preparation; complete evidence packet fc85ecc2

- References: U231-U235. User set goal active; this is a fresh resumed audit.
  That resume is not publication, policy or signing authority. Previous turn was
  no progress; this resumed turn made concrete progress and resets its consecutive
  no-progress count to0. Full objective remains unachieved; Stage12 unauthorized.
- New readiness finding: original5bb008a1 review worktree is sparse. Git index
  marks protected paths S and sparseCheckout=true; commit blobs exist, but actual
  gate/spec/workflow files are absent on disk. The first real incremental check
  returns1/UNAPPROVED_PROTECTED_CHANGE before proof/coverage. This is a local
  checkout/setup mismatch, not an unsafe gate acceptance or the intended new-
  proposal refusal. Original failure and sparse diagnostics are retained.
- Prepared a full independent checkout of the same5bb commit. First bundle fetch
  using an assumed branch ref returns128: the bundle advertises HEAD. Corrected
  fetch of advertised HEAD, full checkout and clean/head checks all return0.
  No commit, baseline source, protected policy or approval was changed to fix setup.
- Real trusted incremental gate on complete5bb returns3/UNSUPPORTED, exactly11
  UNCOVERED_CHANGE findings, all checker commands0 and no verification evidence.
  This establishes current ordinary-gate behavior for the actual proposal data;
  green ledger proofs cannot authorize new unregistered Rocq claims.
- Finalized updated local proposal in a separate full Git worktree. New exact
  headfc85ecc2c7f12caa6c8991fa002410bdf78dd51d,
  treede8b0d3c97077ea52b64932ce591f5a1bd3fec02, basef9eb1cbc… . All14 diff paths
  are proposals/fixed-elf-assurance/**. Source theorems remainffe5a677…/95e121bb… .
  Original5bb commit, packet, bundle and patch remain intact. No protected or
  workflow changes. Git commit/diff/bundle verification/patch-application check/
  object check and packet-to-worktree byte comparisons return0.
- Updated packet includes raw lossless567-module observation-kernel log and
  actual567-module/86-assumption context within its580-object pool, exact input
  identities and fresh byte-identical object rebuild. A deterministic26-member
  tar.xz contains original positive driver/anchor/object, both hostile fixtures,
  raw commands/logs/outcomes and explicit inherited-field corrections. Archive
  read-back exactly matches all source bytes. No new proof execution was claimed
  merely from packaging; the actual kernel/guard executions remain U232/U233.
- Independent readonly review confirms all26 archive members, kernel log hash
  8d4ea9d5…, source hashes, closure/pool and context inputs. It found stale NOT RUN
  fields in derived observation-checks.json. Those were corrected before commit:
  actual full kernel0 is separate from the historical primitive-assumption audit,
  whose renamed flag accurately states that this audit did not run the kernel.
  Reviewer confirms the finding resolved. No human/GitHub approval follows.
- Real current gate on completefc85 returns3/UNSUPPORTED with exactly14 uncovered
  paths, every existing checker command0 and no evidence output. Control assertions
  return0. Source/default policy is unchanged; no coverage exception or fake green.
  These are local macOS checks, not actual hosted results for the new head.
- Read-only actor preflight selects the existing contributor credential only in
  memory:mackiannii/id143109898, repository1434789853, push=true/admin=false.
  The connected GitHub tool uses owner mack-dot, so the CLI contributor selection
  is necessary to preserve independent owner review. Token not printed/stored;
  no account switch, external push or PR creation. Branch lookup exits1/HTTP404;
  matching open-PR query0/empty. Mainf9eb1cbc and PR36 head705457e0/reviews empty.
- Prepared exact draft PR body and publication command arguments. The original
  local origin points at another local repository, so future authorized push must
  use the explicit GitHub URL and exact SHA, never default origin or force push.
  Recheck actor/role/head/base/diff/remote branch before writing. No reviewer,
  auto-merge, dispatch, signing, admission or deployment command is proposed.
- Approval request is now publication ONLY of exactfc85 as a contributor-authored
  draft for independent owner review. It supersedes the unapproved5bb publication
  request; it does not adopt the mathematical claim or acceptance profile. Intent
  and protected-profile approval remain later exact decisions. The ordinary
  existing PR workflow may run automatically and report the uncovered status;
  no manual hosted Rocq experiment or new workflow is authorized by publication.
  Owner response is pending. No elapsed time or preselected option is consent.
- Remaining uncertainty/impact: E1 stays PARTIALLY_ESTABLISHED; new claim/profile
  intent, durable new-claim provenance, full runtime/refinement assumptions and
  new authorized release bindings remain open. E2 not started/NOT_ESTABLISHED;
  historical E3 scope unchanged. Generic cross-run receipt adoption stays disabled.
  Independent original archive backup is unconfirmed; owner-selected destination/
  read-back and administrator required-check decisions remain open. No Node/SPM,
  new framework/persistent infrastructure, protection change or Stage12 work.
  Integration EXIT NOT_ESTABLISHED; end_to_end=false.
- Next action: await exact draft-publication response, then perform only that
  authorized operation after fresh preflight. Publication is not merge/profile/
  signing/dispatch/deployment authority. Exact packet and PR body:
  proposals/runtime-state-projection/publication-v2/{READY.md,pr-body.md,
  publication-plan.json,prepared-pr.json,review-packet/,proposal.bundle}.
  Raw preparations/initial failures/current coverage controls/actor checks/review:
  results/campaign-publication-readiness-2026-11-02/attempt-0001/ .


## U237 — Resumed publication boundary unchanged for three turns

- References: U235, U236. U236 made actual preparation progress after the user
  resumed the goal and reset the blocked audit. Since then three consecutive
  resumed goal turns only revalidated the same genuine owner-action boundary.
  They are no progress, not verified waits. The old pre-resume count is not used.
- Current evidence: fresh GitHub reads show mainf9eb1cbc unchanged; PR36 exact
  705457e0 remains open/unmerged with no reviews. Exactfc85 lookup returns422,
  no commit found. Local fc85 HEAD/status0/0, clean. The expected independent-
  backup read-back is absent. No new publication answer or owner authority.
- Three known proof-container inspections0/0/0 show no running process. All
  earlier proof results remain scoped; no new proof/benchmark run or restart.
  Completed processes and unanswered questions are not live/authorized actions.
- Prepared exactfc85 publication-v2 package/body/command plan remains sealed
  and unpublished. Its14 data paths correctly return UNSUPPORTED in the current
  gate with no evidence; U236 records actual3 and control0. No policy exception,
  generic cache adoption or false green is introduced to make it mergeable.
- Impact: the missing immediate step is explicit publication authorization for
  the prepared contributor-authored draft. This is separate from claim/profile
  adoption and independent exact-head review/merge, signing/admission/dispatch/
  deployment. The campaign explicitly denies automatic publication authority.
  Goal continuation alone and earlier exact-operation grants do not supply it.
- Other external blockers remain independent backup destination/read-back,
  independent PR36 review/separate merge authority and administrator required-
  check policy. No source/verification change can create these human-authority
  or independent-storage facts. E2 does not start before the first narrow case.
  More passing checks or an easier target would not close the full objective.
- Blocked audit is now satisfied for the resumed run:three consecutive equivalent
  no-progress turns, authoritative state unchanged, no live check to monitor and
  no meaningful authorized action that resolves the missing next boundary.
  A blocked goal API request follows this record; its returned status is
  authoritative. This is not completion or a scope reduction.
- Next action: owner response to exact draft-publication request for
  fc85ecc2c7f12caa6c8991fa002410bdf78dd51d, then fresh actor/base/head/remote
  preflight before only that write. Publication does not approve the theorem,
  protected profile, merge, signing, manual dispatch, admission, deployment or
  Stage12. Other independent review/backup/administrator actions stay pending.
- Records:results/campaign-boundary-audit-2026-11-02/resumed-0001/attempt-000{1,2,3}/.
  Exact decision packet:proposals/runtime-state-projection/publication-v2/READY.md.
  Existing raw/sanitized archives and sealed proof/measurement/packet records
  remain intact. No data upload, review, publication, merge, protection, Node,
  SPM, new infrastructure or Stage12 action occurred in these checks.
- Full objective remains unachieved:E1 PARTIALLY_ESTABLISHED, E2 NOT_ESTABLISHED,
  historical E3 scoped validation unchanged. Integration EXIT NOT_ESTABLISHED;
  end_to_end=false. No performance or whole-application correctness upgrade.


## U238 — Second resumed publication boundary unchanged for three turns

- References: U236, U237. Three consecutive second-resume audits show the same
  owner-action boundary. Counts restart after resume; no old count was carried.
- Fresh GitHub reads: main f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3; PR36
  head705457e069abbe399128808b1efc7242d8eaeaa1, open/unmerged, reviews empty.
  Exactfc85ecc2 lookup returns HTTP422/no commit found. This is absence from
  that lookup, not a proof result. Local HEAD/status commands exit0/0; clean.
- Expected independent-backup destination-integrity.json remains absent. No
  independent storage identity or archive read-back was supplied. Backup stays
  unconfirmed. Earlier accessible Drive searches do not prove global absence.
- No new exact publication grant arrived. The campaign section0 explicitly
  excludes automatic publication authority. Continuing local work does not
  approve this new external write. Existing scoped proof results remain intact;
  no new proof or benchmark was run to manufacture progress.
- Impact: no meaningful authorized action resolves the next owner boundary.
  The three-turn blocked audit is satisfied. A blocked goal API request follows;
  its returned status is authoritative. The full objective remains unachieved.
- Next check: owner publication decision for exactfc85 contributor-authored
  draft, then fresh actor/base/head/remote preflight. Decision packet:
  proposals/runtime-state-projection/publication-v2/READY.md. This does not
  approve claim/profile, independent review, merge, signing, admission, manual
  dispatch, deployment or Stage12. Independent PR36 review, backup confirmation
  and administrator required-check decisions remain separate blockers.
- Evidence:results/campaign-boundary-audit-2026-11-02/resumed-0002/attempt-0003/.
  CURRENT none; E1 PARTIALLY_ESTABLISHED; E2 NOT_ESTABLISHED; historical E3
  scope unchanged. Integration EXIT NOT_ESTABLISHED; end_to_end=false.


## U239 — Third resumed run reaches the same owner-action boundary

- References:U236, U237, U238. The three fresh resumed turns each revalidated
  the same blocker. Previous/current turns are no progress, not verified waits.
  Earlier blocked counts were not carried across resume.
- Actual fresh reads: mainf9eb1cbc unchanged; PR36 exact705457e0 remains
  open/unmerged with reviews empty. Exactfc85 lookup HTTP422/no commit found.
  Local HEAD/status exit0/0, exactfc85 and clean. No publication answer arrived.
  Expected independent-backup destination-integrity.json remains absent.
- Evidence:results/campaign-boundary-audit-2026-11-03/resumed-0003/attempt-000{1,2,3}/.
  No new proof/benchmark or hosted run occurred. These metadata checks do not
  strengthen existing proofs, establish backup absence globally or provide
  approval. Completed verification results retain their exact recorded scope.
- Uncertainty/impact: next external write needs the owner's separate decision
  under campaign section0. No available source change can supply that authority,
  independent owner review or off-machine archive read-back. More routine tests
  do not close those requirements. The blocked audit is satisfied for this
  resumed run. A blocked goal API request follows; returned status authoritative.
- Next check: explicit owner decision for draft publication of exactfc85ecc2
  under proposals/runtime-state-projection/publication-v2/READY.md, followed
  by fresh identity/base/head/remote preflight. This does not grant claim/profile
  approval, merge, signing, dispatch, admission, deployment or Stage12.
  Independent PR36 review, backup and administrator required-check decisions
  remain separate. Full objective unachieved; E1 PARTIALLY_ESTABLISHED, E2
  NOT_ESTABLISHED, historical E3 unchanged; integration EXIT NOT_ESTABLISHED;
  end_to_end=false. No protected change or external write occurred.


## U240 — Fourth resumed run awaits the same explicit owner decisions

- References:U236, U239. Three consecutive fresh fourth-resume audits confirm
  the same boundary. Previous/current turns are no progress; no prior blocked
  count was carried across resume. Questions submitted in audit1 remain unanswered.
- Fresh evidence:mainf9eb1cbc unchanged, PR36 exact705457e0 open/unmerged and
  reviews empty; exactfc85 lookup HTTP422/no commit found. Local HEAD/status
  exit0/0; exactfc85 and clean. Backup destination-integrity.json absent.
  No new publication grant, independent backup identity or read-back supplied.
- Impact: campaign section0 requires a separate publication decision. Neither
  goal continuation nor an unanswered question supplies authority. No source
  change can create independent review, storage or authorization facts. No
  meaningful authorized next action closes this boundary. The fresh three-turn
  blocked audit is satisfied; blocked API request follows, returned status
  authoritative. Full objective remains unachieved.
- Next check: owner answer for exactfc85 draft publication and independent
  backup host/existing copy identity. Publication-v2/READY.md defines the
  precise grant; claim/profile, independent review/merge, signing/admission,
  manual dispatch/deployment and Stage12 remain separate. Administrator
  required-check decision and PR36 independent review remain open.
- Evidence:results/campaign-boundary-audit-2026-11-03/resumed-0004/attempt-000{1,2,3}/.
  No proof/benchmark rerun, live-process wait, protected change or external write.
  E1 PARTIALLY_ESTABLISHED, E2 NOT_ESTABLISHED, historical E3 unchanged.
  Integration EXIT NOT_ESTABLISHED; end_to_end=false; CURRENT none.


## U241 — Focused hosted booking EXIT reinspection; no failing booking case

- References:U229, U240. Owner directs inspection of actual hosted booking
  results and the smallest fix, keeping ordinary proof-report upload separate.
  This turn makes concrete audit progress; prior turn was no progress.
- Fresh live GitHub job/artifact reads confirm run41523691535/attempt1, job
  125545854178 successful, including matrix and artifact upload. Fresh artifact
  download13179905102 matches API ZIP SHA372cd778… and prior archive byte for
  byte. Safe extraction yields73 files. Sealed original records were not changed.
- Unchanged hosted record auditor copied to the new result directory returns0,
  checks13 expected outcomes with launch counts1/0/1/0, exact bindings, coverage,
  evidence identity and rejection reasons. Raw cold and invalidation logs each
  say238 verified/0errors; each retained TRX has238 Passed results. Those are
  historical hosted executions, not new proofs or hosted dispatches.
- The existing strict integration status command returns1 again. Its exact
  remaining false predicate is off_machine_backup_confirmed. No booking case
  fails its acceptance contract. H1 is ESTABLISHED within supported same-process
  scope; strict integration EXIT stays NOT_ESTABLISHED. Do not substitute the
  expected negative gate1/3 codes for failed acceptance cases.
- Smallest next operation: owner-selected independent private host or existing
  copy identity, prepared copy_backup.sh transfer/full remote member validation,
  read-back and separate storage-independence evidence. No destination supplied;
  transfer NOT RUN. No source fix is warranted and no readiness boolean changed.
- Limits:protection inspection is not required-check enforcement. The recorded
  export has no required status/workflow checks; administrator policy decision
  stays separate. Outer-ledger raw logs missing; member counts producer-reported.
  C invalidates a Booking helper source input, not every dependency/model/policy.
  Cross-run adoption remains disabled. Observed job198s/3.3runner-minutes is not
  a per-case bill or a stable savings measurement.
- Fresh PR36 read remains open/unmerged at705457e0. Its ordinary proof-gate
  upload repair is independent of successful booking upload. No approval, merge,
  external write, dispatch, signing, admission, deployment or protected change.
  Earlier separate draft-publication request remains separate from this result.
- Evidence:results/hosted-booking-exit-review-2026-11-03/attempt-0001/STATUS.md,
  hosted-audit-command.json(actual0), strict-integration-exit-command.json(actual1),
  downloaded ZIP, artifact-integrity.json, raw-verifier-observations.json,
  live-github-state.json and hosted-acceptance.json. Full campaign unachieved;
  CURRENT none; Stage12 unauthorized; end_to_end=false.


## U242 — Owner-authorized exact proposal push and draft PR37 publication

- References:U236, U240, U241. Owner explicitly says approval followed by
  commit and push. This grants publication of the prepared proposal for review.
  It does not adopt its new mathematical claim/profile or bypass review/merge.
- Existing commitfc85ecc2c7f12caa6c8991fa002410bdf78dd51d was already committed
  and clean. No empty/replacement commit was created. Fresh checks verify
  basef9eb1cbc, exactly14 proposals/fixed-elf-assurance paths, diff-check0,
  unchanged theorem hashes and byte equality with every prepared packet file.
- Connected GitHub actor is owner mack-dot. Because that tool cannot select
  the contributor identity, CLI uses existing mackiannii credential in memory
  only. Fresh API verifies id143109898, repository1434789853, push=true/admin=false.
  No auth account switch, printed token or token/environment disk record.
- Remote branch absent and matching PR list empty before write. Exact explicit-
  GitHub-URL push exits0; read-back equalsfc85. Main before/after remainsf9.
  Draft PR creation exits0. PR37 https://github.com/mack-dot/forge/pull/37
  is OPEN/draft/unmerged, headfc85/basef9, author mackiannii. Independent
  connector read confirms those identities; CLI merge state BLOCKED. No force
  push, self-review, merge, protected change or manual workflow dispatch.
- Current filtered workflow-run query returns empty. This does not prove no
  automatic workflow can run. No hosted success for this proposal is claimed.
  Earlier local gate3/UNSUPPORTED14 uncovered paths remains the actual recorded
  result. No coverage exception or policy relaxation was introduced.
- Impact/next check: publication boundary resolved. Independent intent/profile
  review, exact-head code review and separate merge authority remain. Existing
  proof-report upload PR36 stays separate. Independent archive backup is still
  unconfirmed; no destination supplied and no readiness boolean changed.
  H1 remains established under its existing scope. Strict integration EXIT
  NOT_ESTABLISHED; full campaign unachieved; end_to_end=false; CURRENT none;
  Stage12 unauthorized. Further signing/admission/deployment stay unauthorized.
- Evidence:results/elf-proposal-publication-2026-11-03/attempt-0001/{preflight,
  push,create-draft-pr,pr-readback,publication-result,github-readback}.json plus
  exact command/read records. Sealed original packet remains unchanged as
  historical preparation; this execution record supersedes its pending status.


## U243 — PR37 hosted gate refuses the14 unsupported proposal paths

- References:U241,U242. Owner asks current status. Fresh main remainsf9eb1cbc.
  PR37 exactfc85 remains draft/open/unmerged with no reviews. PR36 exact705457e0
  remains open/unmerged and separate.
- Filtered commit workflow query returned empty, but full PR statusCheckRollup
  identifies run41672433464: verify FAILURE and report SUCCESS. Do not infer no
  CI from the connector's event-filtered query. Read actual verify job126044039402
  log and reconstruct its complete receipt from contiguous chunk offsets.
- Actual FORGE_PR_RESULT binds PR37/basef9/headfc85 and reports exit3,
  UNSUPPORTED,14 UNCOVERED_CHANGE findings and evidence_sha256=null. The
  proposed paths lack declared obligations. This matches the earlier local
  fail-closed result; it is not a passing proof or an infrastructure crash.
- Impact:publication succeeded; this draft is not merge-ready or an admitted
  claim. Intent/acceptance-profile and independent review remain necessary.
  Do not add an exception or weaken coverage merely to make its CI green.
  Report-job success does not override verification refusal, nor establish
  that the separate PR36 upload repair was installed.
- Next check:independent review of the proposed claim and exact later acceptance
  scope. H1 hosted booking remains established under its existing scope;
  strict integration's last actual exit1 still names unconfirmed backup.
  No review/merge/dispatch/signing/policy/protection change occurred.
- Evidence:results/elf-proposal-publication-2026-11-03/attempt-0001/
  {status-followup,hosted-pr37-receipt}.json; hosted job log URL in followup.
  CURRENT none; Stage12 unauthorized; end_to_end=false.


## U244 — Exact PR37 assumption review distinguishes model truth from runtime mapping

- References:U231,U232,U241,U243. Owner directs next-step review, then asks
  what the remaining gap means. Exact headfc85 unchanged; technical review and
  independent agent review identify no source defect in the stated abstract
  claim. This is not owner intent approval or GitHub independent review.
- Actual current identity audit0: exact clean HEAD/status0/0; two theorem
  sources match committed blobs and recorded kernel input hashes; five LPS
  sources match historical pinned-container copy records. No new full kernel,
  compiler, verifier or QEMU execution was performed. Historical569/567 checks
  retain their original execution scope and source identities.
- The termination proposition keeps canonical initialized registers/ROM/
  pending-syscall/reservation/FCSR fields while replacing only data memory.
  It requires m_halted=None and m_vm_lazy=[]. Arbitrary data memory does not
  establish these model conditions for an actual host process.
- The separate observation proposition checks21 PC/GPR/FPR frames and a modeled
  pending94/0 request, with arbitrary data/reservation/FCSR. That does not
  broaden the termination proposition or prove actual syscall dispatch,
  loader/VM mapping, full physical-state abstraction or QEMU/Linux fidelity.
  may_fail_cfg addresses modeled failure families, not arbitrary host behavior.
- Impact: the remaining technical boundary is the concrete-to-LPS process
  mapping and justified runtime/syscall assumptions. More frames alone do not
  establish it. The published packet discloses this correctly. E1 remains
  PARTIALLY_ESTABLISHED; new intent/profile and release binding unapproved.
- Existing strict integration command actually returns1; sole false predicate
  off_machine_backup_confirmed. No backup destination/read-back supplied. This
  operational requirement is separate from the theorem's truth and the passed
  hosted booking matrix. No readiness field changed. PR36 remains separate.
- Evidence:results/pr37-assumption-review-2026-11-03/attempt-0001/
  {STATUS.md,identity-audit.json,integration-exit-command.json,integration-exit.json}.
  No external write, self-review, merge, policy/protection change, dispatch,
  signing, admission or deployment. CURRENT none; Stage12 unauthorized;
  integration EXIT NOT_ESTABLISHED; end_to_end=false.


## U245 — Fixed-ELF assumption inventory and unchanged-theorem obligations

- References:U229,U231-U244. Owner requested exhaustive assumption/observation
  matrix and separate backup/strict EXIT. Current inventory has84rows:
  27 formal facts,13 observations,27 explicit assumptions,17 unsupported links.
  Counts describe inventory,not a whole-executable correctness score. Includes
  all8 machine fields,8 quantified inputs,2 explicit Model premises,7 Model
  components,6 failure families,13 direct and86 historical recursive trust names.
- Primary pinned upstream SCOPE fetched at semantics f1006fe8; Git blob verified,
  content SHAa89800125abc948e61412d00f092744f354a55529ef1d40e812c3df7a7531fe6.
  U01-U21 rows retain every target/limit/unchecked-condition/precision item,
  separate from the additional proposition's actual logical premises.
- Existing init_model/unchanged-theorem instantiation actually compiles0.
  False nonempty-lazy and already-halted premises reject1/1 at intended
  equalities. Formal legal witness is not actual QEMU state correspondence.
- Current pinned readelf2.42 inspection0: held ELF8ced2ab6,ELF64 little-endian,
  RISC-V,ET_EXEC,entry11158,two LOADs/404 file-backed bytes. Actual trace has
  13 distinct words/52 of60 text bytes and five guest mappings,including final
  RX stack-adjacent page. Full live ROM/loader/hidden-state relation remains open.
- Local archive/member checker0: raw/sanitized each10160 members,zero mismatches,
  manifests and raw/sanitized map valid. Fresh accessible Drive exact/related
  queries empty,not global absence. No remote read-back/private host/existing-
  copy identity supplied. Existing strict integration command1,sole false
  predicate off_machine_backup_confirmed. Newer required records also need
  independent preservation/restore; Nov1 procedure alone does not cover them.
- Independent read-only review corrected V01 identity to OBSERVED and made
  crypto/root/expected-digest and native-versus-QEMU trust explicit. Review of
  updated84rows/new auxiliary source found no material overclaim. This is
  technical evidence,not human/GitHub approval.
- Uncertainty/impact:actual-state/loader/syscall mapping remains unsupported;
  no theorem/premise/policy was weakened. Source/object identity remains
  unchanged. Next check:independent new auxiliary closure replay and explicit
  snapshot-to-existing-Model/process relation. No actual correctness upgrade
  follows from a formal witness,signature,artifact hash or successful trace.
- Evidence:results/fixed-elf-assumption-matrix-2026-11-03/attempt-0001/
  {MATRIX.md,matrix.json,matrix.csv,inventory-check.json,published-source/,
  formal-instantiation/,elf-header-command.json,strict-integration-exit-command.json,
  local-archive-integrity-command.json,drive-backup-searches.json,
  original-proof-inputs-unchanged.json,independent-review.json}. Inventory
  generator0 validates metadata structure only,not semantic correctness.


## U246 — Master mission Markdown, audit/design packet and decomposed model checks

- References:U245. Owner cleared the earlier goal and supplied the new master
  mission. Saved exact attachment as FORGE_MASTER_MISSION.md with SHA
  86cd64e897be4fb95d2022a2381bbb4dc663efed5d70db445a4a9826e8213f7e.
  FORGE_CURRENT_STATE_AND_PLAN.md provides all7 first deliverables:current audit,
  capability gaps,Mermaid trust-boundary architecture,milestones,next5actions,
  unrun benchmark design,and risk/complexity assessment. Planning is not product
  implementation,benchmark preregistration or Stage12 authorization.
- Fresh mainf9 unchanged; PR34 exact46e5aa42 draft/open/unmerged,PR36 exact
  705457e0 open/unmerged,PR37 exactfc85 draft/open/unmerged/no reviews. Nine
  relevant Forge checkouts have no tracked changes. Records root is not Git.
  Main ROADMAP still says Stage9; root/main README differ. Preserve those
  historical texts and owner changes; do not infer state from stale headers.
- Current held-lock/input audit0: lock76b983ac matches and all100 files match,
  896182bytes/16403 text lines plus45 container-Python file entries. These are
  locked input surfaces,not total TCB. Gate33files/5591lines,policy4/379,
  spec8/1516,schemas2/442,workflows12/955. External tools/model/OS/hardware
  trust is additional. Prepared2-file README/ROADMAP correction applies cleanly
  with git apply --check0; patch not applied/published,coverage NOT RUN.
- Connector protection reads400/403 retained. Existing owner CLI credential
  selected only in memory for read-only exports; actor/admin role checked.
  Effective rules/inherited ruleset/detail reads0; classic404/CLI1. Fresh
  rules require review,linear history and no delete/force-push,but no required
  status/workflow checks. No settings changed,bypass used or token recorded.
- Initial aggregate RuntimeAccounting compilation137/OOMKilled=true after
  83.358566s at unchanged4GiB. This is a failed method,not proof. Decomposed
  first/last instruction checks0,structural empty-accounting lemma0,remaining
  19 instruction checks0. First combined proof1 had a tactic-focus error;
  corrected composition AllAccesses0 proves empty reports/model-component
  preservation for k<21. Original source and all failures remain preserved.
- WrongRange negative expected1 but compiled0. Preserve this invalid oracle:
  raw CPU run_steps/step_accesses can repeat ecall at same PC without dispatch.
  Its access assertion is true; it is not a checker false accept or passing
  rejection control. Run.sstep_cfg requires pending=None before instruction
  transitions. New PendingBoundary0 proves None at0..20 and Some94 afterward.
  False post-ecall pendingNone rejects1 at SomeNone versusSome(Some94). Original
  13case hosted receipt matrix is untouched.
- Published Print Assumptions parser/allowlist audit0 over4auxiliary roots
  reports same13 primitive names,subset prior86,no new axiom. New recursive
  independent kernel closure NOT RUN; new QEMU execution NOT RUN. These are
  model/unit checking facts,not full physical correspondence,claim adoption,
  admission profile or signed release. Independent read-only review agrees.
- Raw producer operational JSON in the first batch had a trailing literal
  backslash-n encoding error. Raw files retained; normalized derivative records
  label the correction. An initial journal-append helper failed with NameError
  before writing bytes; this corrected append preserves the original prefix.
  Neither collection error is a security refusal or theorem result.
- Evidence:results/{runtime-accounting-feasibility,runtime-access-one-step,
  runtime-access-decomposition,runtime-access-batch,runtime-pending-boundary,
  runtime-access-assumptions,master-mission-audit}-2026-11-03/ and U245 matrix;
  proposals/current-status-docs/{main-docs.patch,validation.json}. Exact argv,
  numeric exits,raw outputs,source hashes and expected cases are retained.
- Complexity increased through local documentation/proof/evidence artifacts,
  not accepted gate/policy/runtime code or services. No Node/SPM,new framework,
  approval/merge,dispatch,signing,admission,deployment or protection change.
  Next safe step:independent closure replay and explicit state/process relation.
  Backup destination/restore and PR/claim/profile decisions remain external
  boundaries. Full new master goal unachieved;goal remains active. CURRENT none;
  Stage12 unauthorized;integration EXIT NOT_ESTABLISHED;end_to_end=false.


## U247 — New auxiliary obligations pass independent594-module kernel replay

- References:U244-U246. Owner asks for exhaustive fixed-ELF assumptions and
  smallest independently checkable connection obligations,with separate backup
  confirmation and the existing strict EXIT. Matrix84 retains27 formal facts,
  13 observations,27 assumptions and17 unsupported links;counts are inventory,
  not a correctness score. New follow-up names C1-C7 connection obligations.
- Actual python3 -B results/runtime-auxiliary-kernel-2026-11-03/attempt-0001/run.py
  exits0. It dispatches the unchanged existing published checker against exact
  held historical dependencies and new local auxiliary objects,with readonly
  inputs,networknone,UID1000,oneCPU and unchanged4GiB memory/swap limit.
  Actual recursive rocqchk process0,container0,OOMKilled=false;594 modules and
  same86 permitted closure assumptions. No -norec or admitted dependencies.
- Roots cover all21 no-data-access/accounting facts,pending syscall guard and
  the unchanged-theorem initializer witness. Actual postflight0 verifies exact
  invocation,source/object/tool identity before/after and root/closure membership.
  Kernel log SHAad90c2208bcabb509cb98aa842ea84ccf962bc4aec1e26cee8eee85991c45768.
  Kernel operation1415.391444559seconds;outer1418.698787666seconds. Local elapsed
  observations,not hosted cost,benchmark or savings. Independent process on
  this machine;not independent physical-machine reproduction or new QEMU run.
- This closes the previously NOT RUN independent auxiliary-closure check only.
  It does not establish actual entry-state/ROM/loader/Model abstraction,
  QEMU/Linux step/syscall fidelity,observer fidelity,new claim/profile approval
  or authenticated release binding. Original theorem,premises and13 direct
  primitive trust assumptions remain unchanged. Previous137/OOM,tactic failure
  and invalid WrongRange negative oracle remain preserved.
- Full recorded state is unavailable:reservation/FCSR/pending interpretation
  and full ROM/load relation remain open. A future capture is evidence for a
  new run,not retroactive measurement of the historical run. Formal initializer
  legality does not prove physical correspondence or physical demand paging.
- Actual current raw/sanitized archive/member check0,each10160 members/zero
  mismatch. Current strict integration reruns1/NOT_ESTABLISHED,sole false
  predicate off_machine_backup_confirmed. No independent destination,remote
  read-back/storage identity or restore result supplied. Local integrity and
  empty accessible Drive searches do not establish an independent backup.
- Fresh GitHub read confirms mainf9eb1cbc,PR37 headfc85ecc2 draft/open/unmerged
  and no submitted reviews. No external write,approval,merge,workflow dispatch,
  protection/policy change,signing,admission,deployment,Node or SPM work occurred.
  Existing rules lack required status/workflow checks;no controls changed.
- Next check:compose the exact existing sstep_cfg process rules with the checked
  prefix facts and define the justified concrete-to-existing-initial-state
  relation. Preserve all runtime/specification assumptions. Backup needs the
  existing-copy identity or an independent owner-selected private destination;
  new claim/profile adoption and independent reviews remain separate boundaries.
- Evidence:results/runtime-auxiliary-kernel-2026-11-03/attempt-0001/ and
  results/fixed-elf-assumption-matrix-2026-11-03/attempt-0002/{STATUS.md,
  CONNECTION_OBLIGATIONS.md,github-readback.json,final-integration-exit-command.json}.
  Prior plan/checkpoint preserved;FORGE_CURRENT_STATE_AND_PLAN.md updated.
  CURRENT none;Stage12 unauthorized;integration EXIT NOT_ESTABLISHED;
  full executable correctness NOT_ESTABLISHED;end_to_end=false. Goal remains
  active;the full master mission is unachieved.


## U248 — Existing process-prefix composition and separate debug-observer experiment

- References:U245-U247. Previous goal turn made concrete progress:independent
  kernel594 passed. Current authorized continuation composes the already checked
  access/accounting and pending-guard facts with existing LPS sstep_cfg/star_cfg.
  No new machine semantics,termination claim,axiom or acceptance profile added.
- Actual ProcessPrefix first compilation1 failed only at list-concatenation
  inference for star_cfg_step. Corrected explicit empty-list arguments compile0.
  Halted-Model substitution rejects1 for intended Some0-versus-None premise.
  Fresh source rebuild0 reproduces byte-identical object39edf12fad47aaa68cc964a7a3421311f73299b48ed81530e3550cb8d13e5f31.
  Source0ca6b319c2622d2ff9371d48f918d5841a2fd4fa203a6d5e5fb75142ace7e445.
  Published direct-assumption parser0 reports same13 inherited primitives.
  Full new recursive replay is RUNNING under live tool session41686/container
  forge-process-prefix-kernel-20261103-0001 at this checkpoint;no final exit yet.
- Pinned Ubuntu QEMU source1:8.2.2+ds-0ubuntu1.18 acquisition/extraction/complete
  distribution-source-chain replay0/0/0. Existing gpgv0 and apt-helper0 bind
  signed Release to full Sources64f40b56... and all3 archives. Source uploader
  signature remains unverified;missing key warning preserved. Distribution
  signature authority is explicit. Runtime source-to-binary rebuild NOT RUN.
  Initial source APT100/outer1 came from capability settings preventing sandbox
  user change;successful retry uses existing acquisition profile,not weaker
  authentication. Initial compile-dispatch mount-filter assertion1 also remains
  preserved;neither was a proof execution or passing security control.
- New source inspection explains logger omissions and shows reservation reset
  sentinel-1,CSR-backed FCSR access,RISC-V vDSO loading and94/A7 exit dispatch.
  These are source-inspected implementation facts,not a QEMU/Linux/LPS refinement
  proof or retrospective capture of unrecorded physical state.
- Existing checker image has no GDB. Separate observer proposal prepared and
  tested locally with Ubuntu GDB15.1-1ubuntu1~24.04.1,executable0baeb299d3aa39f40ca72c3cb8ae5b15a5bd01f1995583a52cfdd7527bfffe07.
  Authenticated APT downloaded13 packages;dpkg-deb unpacked them,no install or
  maintainer scripts. Observation runs UID1000,networknone,512MiB,container
  loopback;GDB initialization/auto-load/debuginfod disabled. Accepted toolchain
  image,policy and100 locked files remain unchanged. New observer trust is
  explicit and unapproved as authoritative acceptance evidence.
- First observer's prefix metadata checks could accept FCSR0x1 or a PC suffix.
  Counterexample/original source preserved. Exact unique-field repair passes
  all9 local metadata controls;negative subprocesses1 at intended fields.
  Fresh repaired observer/QEMU/GDB0/0/0 measures entryPC11158,SP2aaaab2abc30,
  FCSR0,and344+60 complete held LOAD bytes matching via cmp0/0. Corrupt capture
  cmp1. Guest auxv identifies new-run RX page2aaaab2ac000;4096 bytes captured.
  This is a new finite OBSERVED/TESTED run,not authoritative proof or admission.
- Whole raw trace cmp1 differs only in final exit_group0 process ID9 versus10.
  Preserve that failure. Exact pre-exit458-line/39366-byte prefix comparison0
  retains all observed mapping/instruction/register rows;no semantic decoder
  was introduced. It supports the same checked finite projection literals.
  New trace526c4a21...,vDSO page5dc91e13.... No old FCSR/reservation value inferred.
- GDB warns of a corrupt vDSO string-table index;readelf returns0 but reports no
  .dynamic section when viewing the memory-page dump. These remain diagnostics,
  not full vDSO validity. Header section-table offset2856 exceeds LOAD file
  bytes1748;omitted file-only metadata is a source-based possible explanation,
  not a proved diagnosis. No vDSO code execution or universal correctness claim.
- Full initial-state/Model mapping,reservation,sparse ledger,observer fidelity,
  QEMU/Linux semantics and new claim/release binding remain unestablished.
  Original theorem and no-lazy premise remain unchanged. Finite projected
  process compatibility is narrower than full concrete-state correspondence.
- Source-only local review packet36 members/28proof sources has SHA
  c4832922ed9c94945202ce41b66bf76768f78094cd6237be8b6ae95792d2d1fe.
  Base dependencies remain separate;clean-machine replay NOT RUN. Packet hashes
  identify bytes,not authenticated provenance or approval. No publication.
- Fresh PR37 remainsfc85 draft/open/unmerged/no reviews,basef9. Strict integration
  actual1 still has sole blocker off_machine_backup_confirmed. SSH config has
  no Forge/backup alias;not proof of global absence. No private key read,SSH
  connection,archive transfer or readiness mutation. New records need backup.
- Evidence:results/{runtime-process-prefix,runtime-process-prefix-assumptions,
  runtime-process-prefix-kernel,qemu-source-assumption-audit,fixed-elf-observer}-2026-11-03/;
  results/fixed-elf-assumption-matrix-2026-11-03/attempt-0003/;
  proposals/fixed-elf-observer/. Complexity added:local proof/source/observer
  artifacts and explicit GDB observation trust,not production gate/services.
  Next check:finish live independent replay,review exact physical-entry/Model
  relation and disclosed residual assumptions. Backup destination/read-back,
  independent reviews and authoritative-profile/publication decisions remain
  separate boundaries. No Node,SPM,framework,protection change,approval,merge,
  dispatch,signing,admission,deployment or Stage12. end_to_end=false;full mission
  remains unachieved and goal active.


## U249 — Kernel595 passes; complete observer-content check rejects generated bytecode

- References:U247,U248. The live kernel session41686 completed without restart.
  Actual python3 -B results/runtime-process-prefix-kernel-2026-11-03/attempt-0001/run.py
  exits0;recursive rocqchk0,container0,OOMKilled=false. Postflight.py0 verifies
  all frozen tool/source/object inputs and required roots.595 modules,same86
  permitted closure assumptions,no new axioms. Kernel log SHA
  1876758495c140fb397af0dc349530c6aaafab8e46bb5c5aad39928120b5b0d9.
  Kernel1658.714140672s,outer1659.407074542s;local times,not hosted cost/savings.
  U248's RUNNING status is historical;terminal result is now established for
  this auxiliary model-prefix scope,not physical refinement or claim adoption.
- A separate complete package-to-observer replay independently verifies2Ubuntu
  repository signatures,4uncompressed binary-index digests and all13 observer
  archives. Its first strict used-tree comparison exits1:the first writable
  GDB version probe generated22 Python bytecode-cache files absent from the
  signed packages. All413 vendor members match;435 used members include those
  extras. Same GDB executable hash is insufficient to bind its complete runtime
  input tree. Preserve failed matcher,used tree,metadata and prior captures.
- Repair is a fresh authenticated extraction mounted read-only for execution,
  with GDB-specific PYTHONDONTWRITEBYTECODE=1. No excluded paths,deleted caches,
  altered reference manifests or weakened matcher. Same strict matcher0 verifies
  all413 files/symlinks. Current observer attempt0003/QEMU/GDB0/0/0;post-use
  inventory0 still matches413 members with no generated caches. This binds
  distribution content under existing Ubuntu-key trust;it does not prove
  debugger correctness or give the new outputs authoritative provenance.
- Current run again observes FCSR0,PC11158/SP2aaaab2abc30 and all404 held ELF LOAD
  bytes;cmp0/0,modified text cmp1. Entire current trace matches previous debug
  trace byte for byte0,SHA526c4a21.... Relative to the historical trace,only
  final PID differs;the458-line pre-exit prefix is identical. No retrospective
  old FCSR/reservation observation is inferred. The earlier9 exact-marker
  controls and original prefix counterexample stay intact;no hosted test changed.
- GDB vDSO string-table warning and readelf missing .dynamic diagnostic remain
  explicit. Zero tool exits do not establish full vDSO validity. Current guest
  auxv/4096-byte capture identifies the page for this run;source-based omitted-
  section explanation is not a proved diagnosis. Model/physical mapping,
  canonical reservation,sparse ledger,runtime/observer fidelity and new release
  binding remain open. Original termination theorem and its premises unchanged.
- Current source-only read-only-observer supplement has41 members/28proof
  sources,SHA2c97ed61e3a817afd4de9094682852d312491c9a5f8306834484a323ad2a3414.
  Original36-member packet c4832922... remains preserved. Both are unpublished,
  depend on the base proof pool and are not authenticated claim authority.
  Clean-machine replay NOT RUN. Claim boundary is explicit in
  proposals/fixed-elf-observer/CLAIM_BOUNDARY.md;no policy/profile adoption.
- Accepted100-file lock inputs remain unchanged. Actual archive/member check0,
  remote read-back absent;strict integration last actual1/NOT_ESTABLISHED has
  sole false predicate off_machine_backup_confirmed. No SSH destination or
  independent-copy identity supplied;no archive transfer/readiness mutation.
  Fresh PR37 exactfc85 draft/open/unmerged/no reviews,basef9. PR36 separate.
- Evidence:results/runtime-process-prefix-kernel-2026-11-03/attempt-0001/;
  results/fixed-elf-observer-2026-11-03/attempt-0002/{producer-chain-command.json,
  producer-chain-difference.json,producer-chain-readonly-command.json} and
  attempt-0003/{capture-command.json,producer-after-command.json,capture/};
  results/fixed-elf-assumption-matrix-2026-11-03/attempt-0003/;
  proposals/fixed-elf-observer/. Source and failure records preserved.
- Next:review the bounded claim and precise entry/Model relation,reservation
  and runtime trust assumptions;verify an independent backup after destination/
  existing-copy identity is supplied. Separate publication/profile/independent
  review authority remains required. Current step adds observation integrity
  checks/local artifacts,not production services/frameworks or accepted gate
  code. No Node,SPM,signing,admission,deployment,merge,dispatch,protection change
  or Stage12. end_to_end=false;full mission unachieved;goal remains active.


## U250 — Goal controller reports blocked after current concrete progress

- References:U248,U249. Final get_goal readbacks twice report the same master
  objective as blocked. No update_goal call occurred in this turn. The reason
  for the controller state change is UNKNOWN;do not invent a blocked-audit
  threshold or infer that the passing checks failed.
- This supersedes U249's goal-active wording only. Current turn made progress:
  kernel595/86 passed,new bounded observer ran,and strict producer-content
  failure was preserved/repaired. Full mission remains unachieved. Safe local
  documentation/backup-preparation work remains;publication/adoption/merge and
  actual independent backup still have the stated external boundaries.
- Evidence:results/fixed-elf-assumption-matrix-2026-11-03/attempt-0003/
  goal-controller-readback.json and corrected checkpoint/continuation records.
  Initial journal helper SyntaxError occurred before executing any writes;
  corrected append preserves old prefix. No goal was marked complete or paused.
  No scope/authority expansion follows from a controller status. CURRENT none;
  Stage12 unauthorized;end_to_end=false.


## U251 — Owner reports other-device backup and authorizes local readiness commits

- References:U247-U250. Owner says to resume,approves continued work,reports a
  backup on another device,and requests commits. Manual task work resumes under
  that authorization. Initial goal-controller readback still reports blocked;
  no status mutation or invented automatic-resume result is claimed.
- Backup existence now has direct owner attestation. This supersedes wording
  that no copy was reported. Device/location,specific raw/sanitized archive
  identity,newer-record coverage and remote integrity/restore remain unverified.
  A concise information question is pending;no repeated approval was requested.
  Owner statement is preserved without turning it into a command execution.
- Fresh GitHub mainf9eb1cbc and PR37 exactfc85 remain unchanged;PR37 draft/open/
  unmerged. Created two isolated local worktrees fromf9;no main/protected change.
  Actual commits0/0:docs3934b4e24ddc576b0e08e1512756f1b18d79dda2 and
  observere60b97b697a6f78f0ca347054e17d2a72d7ad7b5. Four documentation files
  correct stale public status and preserve master mission/audit;38 proposal/
  evidence files preserve the bounded observer/process supplement. No push.
- Both final whitespace checks0. Initial check2 flagged document whitespace;
  only Git copies of mission/audit were normalized,word content unchanged;
  exact attachment copy remains intact in owner workspace. A raw readelf output
  check2 flagged intentional trailing space;its Git copy was packed losslessly,
  not normalized. Original evidence files remain unchanged. Commit readback0
  validates source archive2c97ed61... and raw kernel log18767584... from blobs.
- Existing trusted inventory/registry coverage preflights3/3 report4 and38
  uncovered paths respectively. This is structural preflight only,not a full
  proof-gate run or successful verification. No proof/evidence claim was minted;
  no coverage exception,policy change or protected toolchain change. Existing
 595-module/observer checks are historical executed results,not rerun for packing.
- Prepared private same-device Git bundle of complete histories for both
  branches:forge-readiness-commits-2026-11-03.bundle,24618591bytes,SHA
  f9ad6a46f892b204ea12b38bea12b971e0e4dc72e7b50f5dd0ec0fe5ee9a4ee6.
  Create/verify0/0. Local clone restoration/fsck0/0 into separate object database
  recovers the exact observer archive. This is local recovery of committed Git
  data,not an off-machine archive restore or a complete external proof pool.
  Older archives remain intact;no off-machine transfer was performed.
- Existing strict status command with explicit owner-report metadata returns1;
  off_machine_backup_confirmed remains the sole false field pending archive
  identification/validation. Historical readiness input not overwritten;new
  owner report is retained separately. No owner approval or data was discarded.
- Evidence:results/owner-resume-commit-2026-11-03/attempt-0001/{STATUS.md,
  owner-attestation.json,commit-commands.json,commit-readback.json,
  docs-coverage-preflight.json,observer-coverage-preflight.json,bundle-manifest.json,
  local-bundle-restore-result.json,integration-exit-command.json}. Worktrees:
  /private/tmp/forge-readiness-docs-20261103 and
  /private/tmp/forge-observer-review-20261103. Mainf9,PR37fc85,required checks and
  prior proof inputs unchanged. PR36 stays separate. Publication/independent
  exact-head review/profile adoption/merge/signing/admission remain distinct.
- Next:identify the owner's existing backup contents/device,validate the exact
  archives/restore within the existing procedure,and publish only under the
  corresponding grant. No Stage12,Node,SPM,new framework,infrastructure service,
  protection change,dispatch or deployment. end_to_end=false;full mission remains
  unachieved. Current turn made concrete progress;no blocked-audit claim made.


## U252 — Immediate behavioral slice audit and hidden-state-independent consequence

- References:U229,U247-U251. Owner keeps the existing goal and makes the six-link
  behavioral vertical slice the immediate priority. Cross-run reuse,benchmarks
  and developer-interface work are later horizons,not prerequisites. CURRENT
  none;Stage12 unauthorized. No goal replacement or stage transition.
- Fresh GitHub main remainsf9eb1cbc;PR37 exactfc85 is draft/open/unmerged with
  no submitted reviews. Original fixed-input self-test performs a real remainder
  loop1071/462 and checks21. It does not establish arbitrary-input GCD or transfer
  Dafny/refund source claims to the ELF. Approved provenance explicitly claims
  deployed_file_identity and riscv_execution_claimed=false.
- Actual new Rocq compilation0 proves exact loop pairs,final result equal to
  Z.gcd1071 462,and modeled exit0 for arbitrary data memory,reservation and FCSR
  at the observed register initializer. Original theorem and Model premises
  halted=None/lazy=[] are unchanged. This removes the need to reconstruct the
  two hidden values for this proposed consequence;their historical physical
  values remain unknown. Actual incorrect22 result proof is rejected1 for the
  intended21-versus22 type mismatch. Auxiliary source SHA5a230c7e...;object
  f1d3b7e2.... New full recursive independent kernel NOT RUN;compilation and
  historical595 replay must not be relabeled as a fresh full replay.
- Fully qualified assumption-print compile0;unchanged published parser0 lists
  the same13 direct primitives,within the previous86 closure. Held host39proof
  objects and28sources match. Host parser import failed1 due Linux YAML binding
  on macOS;then Linux parser rejected short names1. Both preserved. Separate
  fully qualified output repaired the metadata input,without changing theorem,
  parser,allowlist or installed tools. No acceptance threshold was weakened.
- Fresh unchanged historical consumer accepts its original signed bundle0.
  Execution/correspondence claim additions are rejected1/1,EVIDENCE_DIGEST,after
  actual Cosign0 in each case. The old signature cannot authenticate the new
  claim. No controller access,new signing,admission,deployment or generic
  cross-run proof adoption. Finish-audit checks0. Strict integration status1
  still has only the archive-validation flag false. Owner's other-device backup
  attestation is retained;exact contents/remote integrity remain unverified.
- Evidence:VERTICAL_SLICE_STATUS.md;results/vertical-slice-audit-2026-11-03/
  attempt-0001/{positive-command.json,negative-command.json,audit-command.json,
  parser-command.json,identity-audit.json,consumer-results.json,acceptance.json,
  integration-exit-command.json};original failure metadata/sources remain.
- Impact:the full concrete machine/process-to-Model relation and exit dispatcher/
  Linux fidelity remain open. Finite trace agreement and source inspection do
  not establish universal runtime refinement. New claim/profile provenance and
  independent release admission are also absent. end_to_end=false.
- Next:review the existing exact-head claim and separate auxiliary source;close
  the precise entry/Model/syscall relation,freeze/check the final binding and
  complete kernel closure,and propose only the necessary protected release
  binding changes. New profile/adoption/publication/merge/signing/admission
  retain their corresponding approvals. Keep PR36 separate. Preserve existing
  vDSO diagnostics and original failing controls;do not replace them with passes.


## U253 — Local vertical-slice records committed; no new claim adopted

- References:U251,U252. Existing owner authorization covers local commits.
  Actual commits0/0:documentation9b0a678e30f4875fc0a77235a4ad918f292860a6
  and observer supplementc8e87fd019e587d0ed576b478020f2e1a78a8bc7.
  Parent commits3934b4e2/e60b97b6 remain intact. No publication or merge.
- The first commit dispatcher returned1 after its observer whitespace check2
  rejected the raw negative log's final blank line. The documentation commit
  had already passed. Preserved all commands;packed only the Git copy of the
  raw rejection log with deterministic,lossless gzip. Original raw log unchanged.
  Final observer whitespace check0;committed blob/manifest readback0 verifies31
  source/log/metadata blobs and exact decompressed rejection bytes. No proof
  source or expected outcome changed. Both local worktrees clean.
- Fresh postflight0 checks86 published tool files/45 Python dependency files
  against the held kernel-input manifest. Main tracked diff0 and original
  unsure.md prefix preserved. No accepted evidence or signed receipt minted.
- Evidence:results/vertical-slice-audit-2026-11-03/attempt-0001/{commits.json,
  commit-commands.json,commit-recovery-commands.json,committed-readback.json,
  postflight.json}. Local supplement is source/log review material with external
  dependencies,not a self-contained authoritative replay packet. Current Git
  backup bundle predates these commits;newer off-machine coverage is unknown.
- Next:the exact entry/Model/syscall relation and claim/profile review remain
  the shortest technical path. Full new-root recursive checking,protected
  binding changes,fresh provenance and independent admission remain pending.
  No Stage12,Node,SPM,benchmark,interface,new framework or persistent service.
  All prior runtime assumptions/failures remain;end_to_end=false.


## U254 — Fixed behavior and modeled exit independently replayed; runtime transfer remains conditional

- References:U229,U247-U253. The owner authorizes continued local work and commits.
  CURRENT none;Stage12 unauthorized;end_to_end=false. No new stage or scope.
- Fresh Behavior source compilation0 reproduces objectf1d3b7e2 byte for byte.
  New ExitBridge compilation0 and separate rebuild0 reproduce objectb433ae9a.
  It conjoins fixed GCD21, the unchanged must-exit0 theorem and an explicit
  LPS ExitEv0/haltsSome0 realization using published must_exit_at_cfg_realizes.
  Model guards halted=None/lazy=[] remain. No new axiom or machine semantics.
- Complete recursive independent kernel0:597 modules, exact same86 permitted
  closure assumptions;1540.643432076 seconds. Raw logSHA34f857e07117fd417c839fee4a7df645b5bc63390c84e3bf85d45b6c8cf3db8b.
  This closes U252/U253's NOT RUN item for these new roots. Their historical
  wording remains intact. New process, same physical host; full replay, not
  -norec. Postflight0 confirms30 source identities unchanged. Object pool609
  is not the actual loaded closure count; exact loaded membership is retained.
- Fresh producer/baseline/postidentity0/0/0. Same21-frame projection,404 LOAD
  bytes, FCSR0, guest and parent exit0; observer did not kill QEMU. Actual
  debugger interference changes a2=21 to22; guest/parent2 and unchanged observer
  rejection1. Existing wrong-GCD22 and halted-model controls reject1/1; nine
  marker controls pass harness0 with one positive0 and eight negative1. Corrupt
  proof and substituted ELF reject1/1 before kernel/guest launch. Corrupt LOAD
  comparison rejects1. None of those expected negatives is a proof success.
- New exit distinction: inspected authenticated QEMU source calls gdb_exit in
  preexit_cleanup before the host exit_group. GDB notification alone cannot
  establish physical termination. Actual parent wait0 supplies a distinct finite
  observation. QEMU/Linux/observer/host fidelity and physical progress remain
  assumptions; source inspection is not a refinement or binary-build proof.
- Prepared portable proof and runtime packets with external expected hashes.
  Relocated inputs rebuild both proof objects identically0 and replay runtime0
  without mounting original worktrees. This is same-machine portability, not
  an independent physical-host test. Full kernel ran against the same held
  objects; relocated --rebuild-only is not another full replay. QEMU's held
  digest retains historical producer trust; fresh package-chain checking covers
  the413-member GDB observer tree, not a QEMU source-to-binary rebuild.
- First portable extraction failed1: host Python3.10.11 lacks tar data-filter
  support. Retained that failure and used the same standard filter in the
  existing pinned Python3.12.3 image, exit0. No filter removed/tool installed.
  All prior parser,OOM,oracle,observer and vDSO failures remain preserved.
- Effective rules/ruleset exports0: independent review protections present,
  no required status checks/workflows. Classic protection endpoint1/HTTP404;
  effective rules obtained separately. No governance change. Mainf9 and PR37
  exactfc85 remain unchanged;PR37 draft/open/unmerged/no reviews. PR36 separate.
- Original archives validate0 and actual local restore0:10160 members each,
  zero hash mismatches. Existing local Git bundle verifies0. Owner's other-
  device copy remains reported; exact location, remote archive hashes and restore
  are NOT RUN. Existing strict integration EXIT1 has only the backup flag false.
  Old bundle excludes latest commits; old archives exclude the new evidence.
- Evidence:results/executable-correspondence-2026-11-03/attempt-0001/{REPORT.md,
  CORRESPONDENCE.md,APPROVAL-PACKET.md,assurance-result.json,kernel-output/,
  observation-commands.json,identity-controls.json,relocated-replay-commands.json,
  local-restore-result.json,integration-exit-command.json}. Exact argv and raw
  logs retained. Proofpacket3ae40b4c...;runtimepacket55eec1b9....
- Verdict PARTIALLY_ESTABLISHED. The fixed result is intermediate a0=21 for
  inputs1071/462, not arbitrary-input GCD or output21. Finite projected embedding
  does not prove complete concrete state or every QEMU successor. Physical
  pending/Model applicability, instruction/capture fidelity, noninterference,
  Linux exit meaning and universal progress remain explicit reviewed conditions.
- Next boundary: exact conditional contract/profile proposal at
  proposals/fixed-elf-correspondence/, plus independent review of the separate
  proof/observer supplement. Protected spec patch is unapplied and passes only
  apply --check. No policy, producer, workflow or signed claim was changed.
  Fresh authorized provenance and independent admission remain NOT RUN. Local
  commit authorization does not authorize publication/adoption/merge/dispatch/
  signing/admission/deployment. Keep all six T1-T6 trust conditions explicit.


## U255 — Correspondence supplement committed and locally recoverable

- References:U253,U254. Owner's explicit local-commit authorization used.
  New supplement commit 0d0cdcee801401f620ad643fb36154a312332e54 on
  proposal/fixed-elf-correspondence-20261103; documentation commit
  6fd95ff32096dfc7cd2c99abc4cede1224ce531e. Actual commit0/0, whitespace0/0.
  No push, review, protected change, merge, dispatch, signing or admission.
- Committed readback0 verifies24 reviewed files and313 losslessly archived raw
  records, the complete kernel log and proof packet. Both worktrees clean;
  Git object checks0/0; main tracked diff0; prior unsure prefix unchanged.
- New private same-device recovery bundle create/verify0/0; actual bare clone
  restore/fsck0/0 recovers both new heads and exact proof/record archives.
  File:/Users/mackianni/forge-backups/forge-correspondence-commits-2026-11-03.bundle; mode0600;
  bytes26703632; SHA256d8aa9f1620da36e3681a38636b3ed5874a0397cba867256b15459a01425c6188.
  Older bundles remain unchanged. The70MB runtime archive remains separately
  preserved in the owner workspace; it is not inside this Git bundle.
- Evidence:results/executable-correspondence-2026-11-03/attempt-0001/
  {commits.json,commit-commands.json,commit-readback.json,
  commit-readback-commands.json}. Source/record packet is review material,
  not newly authenticated authoritative evidence. Independent physical-host
  replay and off-machine archive validation/restore remain NOT RUN.
- Next boundary: independent review and exact conditional claim/profile approval;
  fresh protected producer/admission binding requires its concrete approval.
  PR37 remains exactfc85 and unapproved; PR36 independent. No Stage12 or scope
  change. PARTIALLY_ESTABLISHED; end_to_end=false; full objective remains open.


## U256 — Fresh observation now binds to the exact checked trace

- References:U254,U255. Owner requests continued work; existing local commit
  authorization persists. CURRENT none;Stage12 unauthorized;end_to_end=false.
- Found a narrow integration omission: the existing runtime replay authenticates
  its held producer inputs and observes exit0/LOAD bytes, but does not itself
  compare the complete trace to the checked projection. Its scope explicitly
  says finite observation, so this is not evidence of a false authoritative
  proof/admission. Prior manual trace binding and all prior results remain valid.
- Actual new adversarial run sets entry a0=1 before capture. The unchanged ELF
  overwrites it, so both QEMU and the unchanged observer exit0. The trace changes
  from526c4a21... tocb4aa0c0.... A successful exit alone cannot supply the original
  initializer/trace premise. The new byte-binding comparison rejects this real
  changed-entry record1 with TRACE_IDENTITY_MISMATCH.
- New review-only wrapper pins the full existing runtime manifest outside that
  manifest, dispatches a fresh existing observer, checks input identity again,
  then checks the entire trace,404 LOAD bytes, execution identities/arguments,
  integer parent exit0, no observer kill and no scope upgrade. It accepts no old
  output directory as a fresh execution. No ISA decoder, semantics, proof checker,
  trusted receipt, signature or cross-run adoption is introduced.
- Actual final wrapper0; source251252a55e422b6184c818de9d1d0c572426cb670c9d9a3ccaefb16adc7d8472
  pinned before/after execution;6.806320625 local elapsed seconds. Matrix0:
  16 cases match, one valid comparison0 and15 expected refusals1. Cases include
  real changed entry, altered/extra/missing trace, LOAD substitution, stale ELF,
  harness change, missing command, nonzero/boolean parent status, observer kill,
  scope upgrade, missing anchor, coordinated packet/manifest change and existing
  output. Raw failures remain. Initial smoke run preceded final command-field
  guard/result-label correction; final run records the exact final source.
- Full kernel was not rerun: no theorem/object/assumption changed. Current source
  postflight0 validates30 frozen proof sources. Historical597/86 remains historical.
  The exact trace/literal translation, physical pending/Model abstraction, QEMU/
  Linux fidelity, noninterference/progress and authenticated new release chain
  remain explicit review conditions. The wrapper cannot establish these by hashes.
- Actual local continuation commit0:945499592c33a3a84f205c0ccf68c4088c3d6d8b.
  Standalone review commit0:8125552117589b1c1274c48982fce37ae2f33415,
  branch proposal/fixed-elf-correspondence-review directly on mainf9.
  Only40 files under proposals/fixed-elf-correspondence; older observer-audit
  commits excluded from this draft branch. No protected source/workflow changed.
  Final whitespace0/0; committed readback0 checks38 files and996 raw archived
  members; both local worktrees clean. Parent archives/commits remain unchanged.
- New private local recovery bundle create/verify/clone-restore/fsck0/0/0/0:
  /Users/mackianni/forge-backups/forge-correspondence-review-2026-11-04.bundle;
  SHA256c29177833f57363a2ed99942d007ebc744ee230669b1e4815b4c7496a5f53e0b; mode0600;26995742bytes.
  Owner-reported independent copy remains unvalidated. Existing strict integration
  EXIT1 still has only off_machine_backup_confirmed false. No remote copy or
  restore was inferred from this new local recovery operation.
- Fresh PR37 read remains exactfc85/draft/open/unmerged/no reviews; mainf9. PR36
  remains separate. Exact draft body prepared; publication authorization requested
  for head81255521 and is pending, not inferred from elapsed time. No push,
  publication, merge, dispatch, signing, admission or deployment occurred.
- Evidence:results/fixed-elf-runtime-binding-2026-11-04/attempt-0001/{REPORT.md,
  entry-commands.json,entry-result.json,final-run-command.json,matrix-commands.json,
  matrix-result.json,held-proof-postflight.json,commits.json,committed-readback.json,
  preservation-result.json}. Review packet at /private/tmp/
  forge-correspondence-publication-20261104/proposals/fixed-elf-correspondence/.
- Next boundary: authorize draft publication for independent review; exact claim/
  profile and protected integration adoption remain separate. Overall verdict
  PARTIALLY_ESTABLISHED. No new research stage or end-to-end correctness claim.


## U257 — Full mission preserved; refund source relation checked; executable link remains open

- References:U254,U255,U256. The owner's new mission prioritizes a nontrivial
  real-component executable claim. M1–M4 retain their new definitions. Old GCD
  evidence remains supporting evidence. CURRENT none; Stage12 unauthorized;
  end_to_end=false. Saving the mission does not complete the active goal.
- Full attachment saved byte for byte as FORGE_MISSION.md,32046bytes,SHA256
  7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c.
  FORGE_MISSION_STATUS.md tracks milestones, evidence, commands, blockers and
  next action. ROADMAP and the historical plan link to the new mission.
- Live main remains f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3, tree
  624ef75c46cdd260b39308763cfdf27ed8ba99e5. PR34/36/37 remain open and
  unmerged at46e5aa42/705457e0/fc85ecc2;34/37 are drafts. The latest PR
  collection contains37 through30. These reads do not supply approval.
- Historical hosted run41523691535 artifact13179905102 rehashed to live API
  digest372cd7781b1be493a13bbd4398cb6871cbf2effe6458810425dd25fcf49efbf1.
  Actual archived cold/warm/invalidation0/0/0, verifier launches1/0/1;
  all13 acceptance cases match; cross-run reusefalse. No new hosted run.
- Selected full approved refund R1–R5 for feasibility because its decision is
  stateless. No domain restriction: all mathematical integers, finite strings
  and response constructors; no new precondition. No modified approved spec.
  Fresh existing wrapper-proof EXIT0,9.892985208018217local seconds:
  source0; over-limit/reject-all gate1,verifier4; forbidden assumption gate1,
  auditor2. Protected inputs unchanged. Original attempt0005 report retained.
- New primitive-field source implementation and universal adapter relation
  checked by actual Dafny4.11.0/Z3 4.12.1: verify0,7verified,0errors.
  Equality covers original decision and intent, with full R1–R5 and non-vacuity.
  Repeat0; identical sources and positive checker output. Removed amount bound
  and always-reject bodies each verifier4 for unproved postconditions. Test
  runner0 explicitly checks exits and reasons; no custom verifier introduced.
- Initial new audit invocation2 because its expected report did not exist.
  Preserve this harness failure. Retry uses existing empty audit baseline and
  returns0,zero findings. No proof, source or expected finding was weakened.
- Trust boundary: ordinary Dafny/Boogie/Z3 checking; no independent kernel
  certificate, native refund artifact, compiler correspondence or runtime claim.
  Feasibility BLOCKED_BY_CORRESPONDENCE. Published verified Dafny/CakeML work
  is a candidate; exact supported representations and reproduced full backend
  remain unverified. No toolchain installed or protected file/workflow changed.
- Operational controls remain separate: owner-reported other-device backup
  lacks exact archive hash/restore validation. Existing branch protection audit
  is historical; no control was changed or newly inferred. Pending old fixed-
  ELF draft publication is not a prerequisite for this local component work.
- Evidence:results/mission-m1-feasibility-2026-11-04/attempt-0001/ and mirrored
  proposals/refund-executable-feasibility/. Full claims and next check in
  FORGE_MISSION_STATUS.md. Local commit permission persists; publication,
  merge, dispatch, signing and admission keep their separate approval boundaries.
- Next check: inspect the established verified compilation implementation and
  its integer/string/input/output relation against the complete refund domain.
  Do not count source equivalence, paper claims or old GCD proof as M1 completion.


## U258 — Published refund model checked; full Unicode and executable transfer remain open

- References:U257,U254. CURRENT none; Stage12 unauthorized; end_to_end=false.
  Full approved refund R1–R5 remains the M1 target. No restricted-domain
  replacement, protected acceptance change or new release is authorized here.
- Built isolated pinned Poly/ML5.9.2 at4557554077078decce4ce5f90da00a713cfc32e4,
  HOL4 at9783a49979c94c401ff8c0e51b2eefae7ea95ae3 and CakeML source at
  cd9155694c16831373ab695a670794f23282ed62. Actual configure/build/compiler/
  install and HOL configure/build each returned0. No production pin changed.
- Actual Dafny Unicode witness0 confirms an eligible U+0100 identifier is
  preserved. Deliberately false low-byte identity check4 fails at the intended
  assertion. Earlier escaped-character syntax checks2/2 remain archived as
  harness failures, not passing security controls. No upstream defect inferred.
- New program AST uses the published HOL4 Dafny semantics. Exact guard and
  complete six-field result, normal modeled return and unchanged heap are
  checked for arbitrary integers and byte strings. Manual AST-to-approved
  Unicode-source correspondence is not established. No new semantics or axiom.
- Full-result attempts0001/0002 each returned1 with unresolved computation.
  Proof-tactic correction in0003 returned0 without changing the statement or
  implementation. Removing the amount bound and always rejecting each produce
  intended theorem failure1. Reason/output checks0. Fresh original replay0;
  all six exported files are byte-identical; comparison0. Failures retained.
- Final source SHA256381eeac200322362afc5436db742aed3714c72bb39cd70363336f7b7ac525dd9;
  theorem data8001b59be234763706df25ba09a194d707ff04d147c7e103621f6e5e04d85cd9.
  Theorems:forge_refund.refund_guard_value and refund_full_result. Fresh closure
  audit0 records112 imported theory nodes, no unresolved parent edge and builtin
  min identity. Complete imports include bool.SELECT_AX, INFINITY_AX, ETA_AX,
  BOOL_CASES_AX. Both own theorems have DISK_THM tags and zero explicit hypotheses.
  Exported data and matching content hashes are not authenticated provenance.
- Published dafny_to_cakemlProof replay returned0,267.9495331249782 local seconds.
  Applying its correct_from_stmt relation to refund is still NOT RUN. The tools'
  trusted base and four foundation axioms require an exact independently reviewed
  profile before acceptance. No native refund artifact or runtime claim exists.
- Source audit found two explicit boundaries: HOL mlstring has 8-bit characters;
  modeled Dafny Print has no I/O effect. Preserve the full approved Unicode
  domain and prove an encoding/calling relation. Printed agreement cannot supply
  the missing observable-output theorem. Do not narrow legitimate inputs.
- Original30 input hashes remain unchanged; postflight0. Private raw archive
  holds118 members, all read and hashed; validation0; SHA256
  ea050c65ebc3f61f760671da0a340a6ceb65fd9b529a359a97ee5ce112d18de4.
  Four failed-proof debug heaps remain in that archive and original local paths.
  Owner-reported off-machine copy still lacks exact archive/restore validation.
- Evidence:results/refund-verified-backend-2026-11-04/attempt-0001/; durable
  packet proposals/refund-executable-feasibility/verified-backend-20261104/.
  Current tracker and ROADMAP contain actual exits and unresolved requirements.
  Hosted refund verification and performance measurements remain NOT RUN.
- Next check: instantiate the published compiler relation for the exact refund
  body/expression; discharge freshness, no-shadowing and no-assertion conditions.
  Then preserve full Unicode, checked output/calling, native identity and approved
  admission obligations. M1–M4 remain open; no publication or policy adoption.


## U259 — Exact refund body-to-CakeML behavior checked under explicit entry relations

- References:U257,U258. CURRENT none; Stage12 unauthorized; end_to_end=false.
  Full refund R1–R5 remains the target. This closes a model/compiler
  sub-obligation; it does not establish native or full Unicode correspondence.
- Applied the actual published correct_from_stmt theorem to the exact refund
  body and generated CakeML expression. Kernel-checked compilation equality
  binds the expression. Freshness, no shadowing and no assertions are discharged.
  A checked projection transfers all six output fields into CakeML model
  references and namespace entries. No new semantics/verifier/axiom introduced.
- forge_refund_compile.refund_compiled_behavior explicitly requires state_rel
  for the initial states and env_rel for the environments. It establishes a
  finite modeled execution, correct six values, internal Return convention and
  cml_state_preserved. It does not construct a complete caller, prove physical
  termination or establish externally observable output. These remain open.
- Actual run0001 returned1 on a trivial quantified static goal;0002 returned0
  for the compiler relation. Added projection attempt0003 returned1 on an
  unqualified theorem name;0004 returned1 with unsubstituted value equalities.
  Qualified reference and proof substitution repair gave0005 exit0. No theorem
  premise, source behavior or expected test outcome was weakened. Final source
  removes an unused existential variable; final/repeat0/0, six identical exports.
- New substitution control replaces only the compiled expression with Unit,
  while keeping translator, source and required equality fixed. Actual exit1
  at refund_compilation; expected reason matched, no accepted exports. Controls
  and byte-comparison exit0. Prior amount/reject-all controls stay unchanged.
- Final proof source17e6b07f69faacb9a6b68e4b538c7f817e7927467fde908809df514bed923f3d;
  theorem data c422a03764add97460c4280b3aab8015a30be9f4338402b12d27807d9dcf4b25.
  Fresh closure inspection0:139 nodes, nine own theorems, no missing parent or
  artifact. Same four foundation axioms SELECT_AX/INFINITY_AX/ETA_AX/BOOL_CASES_AX.
  DISK_THM with zero explicit hypotheses does not erase conditional premises.
  Fresh local source replay, not candidate data or hashes, supplies checking.
- Postflight initially returned1 because the owner baseline was compared to
  the separate main Git worktree. Six gate/script paths differ there. Retained
  error record; corrected original-workspace check0 with all30 frozen hashes
  unchanged. Main Git and CakeML tracked diffs are clean. No source changed.
- Parent model/report commitd0269c051390ffe76b41ba1e522568870f3a4f83 returned0;
  exact124-file committed readback0, worktree clean, no publication. New raw
  archive has100 members checked0,38757739bytes,mode0600,SHA256
  ff3e243b043e7bfc148dd3704564b77319b7af3f91efdbc1123712fb209cca7a.
  Failed proof heaps remain in that archive and original local records.
- Evidence:results/refund-compiler-relation-2026-11-04/attempt-0001/;
  proposals/refund-executable-feasibility/compiler-relation-20261104/.
  No new hosted verification, signing, review, publication, merge or admission.
  Owner-reported independent archive copy still needs exact hashes/restore.
- Next check: use the published method/calling proof to construct and prove an
  applicable initial state/environment and caller-visible return tuple. Preserve
  full Unicode representation, native/runtime and independent admission gaps.
  M1–M4 stay open. No protected profile adoption or acceptance policy change.


## U260 — Generated refund method and explicit model caller return the full tuple

- References:U257,U258,U259. Previous goal turn was progress: exact compiler
  relation and reproduction committed77ab7003. This run closes another model
  sub-obligation. CURRENT none;Stage12 unauthorized;M1 open;end_to_end=false.
- The published compiler generates the exact nine-input/six-output method
  from the checked refund_body. New refund_method_compilation proves exact
  equality. Fixed model program declares Return/method, invokes it with typed
  inputs from a constructed namespace, catches Return and exposes answer.
- New forge_refund_call.refund_caller_returns checks this initialization/call
  directly through published evaluate_decs. For every typed model input and
  arbitrary FFI state it returns all six expected fields and preserves FFI.
  No generic state_rel/env_rel premise remains in this new theorem. It does
  not assert the earlier generic env_rel holds for all callers. It proves
  desired behavior independently for this explicit caller. No new semantics.
- Domain remains arbitrary model integers/booleans/byte strings. The complete
  approved Unicode domain is still the target; its representation relation is
  open. Inputs are namespace values, not fixed examples embedded in the caller
  AST. Physical input decoding/native calling are not established. Clock32 is
  sufficient model fuel, not a latency/memory/physical-termination bound.
- Actual attempt0001 exit1 after15 dependency theories built. It retained an
  impossible conditional-Boolean case. Concrete valid-call EVAL diagnostic0
  returns expected tuple; not a replacement universal proof. Debug inspection0
  exposed the inconsistent assumptions. Attempt0002 exit1 after operator SIGINT
  (child signal2,331.425340333seconds) of broad conditional distribution. This
  was not a proof failure counterexample or successful negative control.
- Two narrow Boolean equalities are proved by cases; program and required
  theorem unchanged. Attempt0003 exit0,74.594393292local seconds. Repeat0,
  69.620541958seconds; six exact exported files match. Source SHA256
  081becc8f43334e716d8d7657c65740394d554e812ded8bdc169bffac2c022fe;
  theorem datad756c352edb5dee390d9004976a07ecd25d16cacf7b2aac7dec467ab19f996cd.
- Adversarial caller argument swap exit1 with unsolved request=charge and
  charge=request. Missing arg0 binding exit1 with false return goal. Both fail
  the unchanged refund_caller_returns; no accepted exports. Reasons and exact
  byte reproduction checked0. Prior body/compiler controls remain unchanged.
- Fresh closure inspection0:156 theory nodes, three own theorems, no missing
  parent/artifact. Same four HOL foundation axioms SELECT_AX,INFINITY_AX,ETA_AX,
  BOOL_CASES_AX. Own tags DISK_THM/zero explicit hypotheses. Trusted source
  replay and imported builds, not self-reported candidate hashes, supply checking.
- Owner-workspace30 frozen input hashes unchanged0. Main Git and pinned CakeML
  tracked diffs remain clean. No protected code, spec, policy or workflow changed.
  No publication, merge, dispatch, signing, admission or deployment. Hosted
  refund tests/measurements NOT RUN; no savings claim from local proof duration.
- Raw70-member archive validated0;57327554bytes;mode0600;SHA256
  9bf52f6acfeea2bdddce7b98c329b59618b2f5bc1a8ebfa7f313431aeb897727.
  Three failed-proof heaps are retained there and in original local paths.
  Owner-reported off-machine backup remains unvalidated for exact hashes/restore.
- Evidence:results/refund-caller-2026-11-04/attempt-0001/ and
  proposals/refund-executable-feasibility/caller-20261104/. Exact commands,
  failures, theorem statements, source/object hashes and reproduction recorded.
- Next check: establish full Unicode/byte representation preserving empty IDs,
  ASCII reason equality and caller-ID round trips; retain the U+0100 negative
  control. Then connect the same method to native compilation/calling or I/O.
  No generic CLI/cache/infrastructure. Native artifact and authorized independent
  admission remain open. No Stage12 or end-to-end correctness claim.


## U261 — Durable mission checklist and historical-state labels

- References:U257,U258,U259,U260. The owner requested a Markdown tracking
  record. FORGE_MISSION.md remains the byte-exact mission. The existing
  FORGE_MISSION_STATUS.md now starts with the remaining assurance links and
  their completion conditions. No research scope or acceptance rule changed.
- Preflight exit0: the mission matches its original attachment. The four
  baseline records match the clean docs worktree at96bea8465767f999b11c7f9b0efda212c6e26a15.
  Evidence readback exit0:72 caller-packet manifest entries and12 local links
  checked. Historical positive/repeat0/0 and negative1/1 records agree. These
  checks establish local record integrity, not fresh proof execution or producer
  authentication. Prior failed attempts remain unchanged.
- The tracker now labels GitHub data as the recorded inspection snapshot.
  No remote refresh, review, approval, merge, dispatch or publication occurred.
  It distinguishes the earlier generic compiler premises from the later
  checked model caller. Native input/output remains unproved.
- A limited local source search found HOL's portableML UTF8 implementation.
  Reading that implementation does not establish a verified Unicode relation.
  No applicable UTF8 theorem was identified by this search; this is not a claim
  that none exists. The rule against a custom decoder remains in force.
- Impact: M1 remains open. Full Unicode representation, exact executable and
  runtime binding, independent claim/profile review and new admission remain
  unresolved. The owner's independent backup still needs exact hash/restore
  validation. Stage12 remains unauthorized;end_to_end=false.
- Next check: use established representation infrastructure to prove the
  full-domain relation needed by refund. Preserve empty strings, exact ASCII
  reason equality and caller IDs. Retain the U+0100 truncation control. Do not
  mistake a model representation theorem for native I/O or executable proof.
- Documentation check records:
  results/mission-tracking-2026-11-04/attempt-0001/.


## U262 — Full-domain UTF-8 source representation and refund transport checked

- References:U257,U258,U259,U260,U261. The previous turn completed the requested
  Markdown tracking update atbcf3ac2. This turn closes the source-level Unicode
  representation obligation. It does not close native executable correspondence.
  CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
- Existing Dafny4.11 UTF-8 library found in the installed release. Exact source
  fetched atfcb2042d6d043a2634f0854338c08feeaaaf4ae2; clone/checkout0/0. The
  upstream UnicodeStringsWithUnicodeChar wrapper contains an explicit axiom.
  It is excluded. Selected24 unchanged source files contain no bypass scan match;
  full included-source verification and Dafny audit0/zero findings ran.
- New source proofs establish character-to-scalar identity without that axiom,
  scalar/sequence inverse through the existing UTF-8 decoder, byte-valued output,
  encoding injectivity, empty/nonempty equivalence, ASCII identity and exact
  allowed-reason equivalence. StringRoundTrip and ByteViewIdentity connect actual
  encoded bytes to recovered source characters. No new codec algorithm, verifier,
  machine semantics or axiom. Helper functions project existing types only.
- RefundUtf8Transport.Equivalent has no input precondition. All mathematical
  integers, Unicode strings and response constructors remain. The approved
  eligibility, amount, reason and count are preserved; encoded caller IDs are
  copied exactly and have the checked inverse relation. No bank effect occurs.
- Received conditional transport source from separate local work. Its exact
  record commit is73728c2efa94b452637dfd10f36546f6f8a08d23. Original result:
  positive/repeat0/0, three intended controls4/4/4, initial warning-as-error2.
  This run reverified that source and the unchanged approved implementation/spec
  together with the concrete representation proof. No result was accepted solely
  on the other task's report. Its conditional theorem alone was insufficient.
- Character/scalar attempts0001/0002 resource-exhausted4/4. Split scalar proof
  passed in0003/0004, but the integer helper still exhausted resources: both
  complete runs4/4. Attempt0005 passed0 after isolating the integer lemma and
  adding the modular arithmetic fact. No sixth attempt of the failing proof.
- Sequence attempt0001 failed4 with inferred subset constraints and a missing
  map projection; explicit types/facts give0002=0. Transport0001 failed4 from
  reason-proof resource exhaustion and retained indentation warnings; isolated
  proof obligations and parentheses give0002=0. Claims and domain unchanged.
- Final/repeat0/0:1426 assertion batches each, all included inputs checked.
  Thirty source files are byte-identical; symbol/outcome sets match. Raw timing
  CSVs are not byte-identical proof certificates. Local proof wall times:
  33.995498125 and32.948114625 seconds. No application/hosted savings claim.
- Final proof source SHA256:
  804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990.
  Dafny/Boogie/Z3 and host remain trusted. No new independent kernel certificate,
  native artifact, protected checker profile or authenticated admission exists.
- Original U+0100 truncation test retained byte for byte; fresh exit4 at the
  intended false identity assertion. Over-limit authorization claim fails4 at
  assert ok for amount61/remaining60. Unconditional ID substitution fails4 at
  rejected empty-charge output; preserved, not counted as the accepted-ID test.
  A separate accepted-only substitution fails4 at charge=Encoded(context.chargeId).
  Exact diagnostic/exit checks pass0. No test requirement was weakened.
- Translation-only diagnostic0 checked zero symbols and is not proof evidence.
  Raw pinned Z3 cast diagnostic0/unsat is not the source proof. Final acceptance
  comes from complete Dafny executions. All resource failures remain explicit.
- Thirty frozen owner-workspace inputs unchanged0. Pinned upstream tracked diff
  unchanged. Main tracked diff unchanged; an untracked .toolchain symlink points
  to the owner toolchain and was left intact. No protected changes, publication,
  review, merge, dispatch, signing, admission or deployment.
- Local raw archive validation0:848 members,19105354bytes,0600. SHA256
  c7abfc881e446d080969bc0a7d62d57a15528c7a8b121cdef9c608880dc838c2.
  Raw sources, translations and logs remain. The owner's separate-device backup
  still needs exact archive hashes and a restore test; this new archive is not
  assumed copied there.
- Evidence:results/refund-unicode-2026-11-04/attempt-0001/ and
  proposals/refund-executable-feasibility/unicode-20261104/. The separate
  string-transport-20261104 packet retains its own exact source and controls.
- Next check: bind the same method to whole-program native compilation and I/O.
  Inspected existing mlsexp.fromString_sexp_to_string and SexpProg.inputSexp_spec
  as a parser/I/O route. Refund application of those proofs has NOT RUN. Check
  primitive initialization, input/output relation, installed machine bytes and
  resource-limit/runtime premises. Do not narrow strings or integers to fit a
  fixed-width helper. Native/model assurance binding, independent profile review
  and new provenance/admission remain open. Hosted refund metrics NOT RUN.


## U263 — Refund wire schema preserves the full model input and output domain

- References:U258–U262. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. This is local executable-integration preparation.
- The proposed adapter composes existing mlsexp parsing, dest9/dest7 and typed
  string/Boolean/integer projections. No codec algorithm, machine semantics,
  verifier, checker or axiom was introduced. Every mathematical integer and
  finite byte string has a representation. The U262 full Unicode source relation
  remains separate from the HOL/native assurance binding.
- Found that upstream mlsexp.fromString ignores the unconsumed suffix. The
  proposal instead uses published parse and rejects any nonempty remainder.
  It also proves refusal of malformed syntax, missing fields, wrong field types
  and malformed integers. No input-domain precondition was added to refund.
- Twelve own theorems establish complete input parsing/field round trips,
  composition with the same generated-method model-caller result, output
  field/parser round trips and the listed refusals. Native stdin/stdout and the
  library heap/frame contract are not implied by these theorems.
- Actual schema commands:0001=1 (proof-file syntax);0002=0;
  full-0001=1 (HOL constant-name collision);full-0002=0;repeat=0.
  The failed source attempts remain intact. The final/repeat six export files
  are byte-identical. Four controlled alterations fail1 each for the intended
  theorem: swapped input identity; ignored trailing data; forbidden conversion
  to nonnegative integers; swapped output identity. Exact reason check0.
- Source SHA256:9a6e51a5c840d751ad793f8fa99e4162e76c96e8a975a7c0bd21d3c88a7af59f.
  Theory data SHA256:d9e7f1b77932f7e8c476e4a7230601f6b6cbe722a27764035e07ca01ea7becec.
- Fresh HOL inspection0:159 theory nodes,12 own theorems, zero own hypotheses.
  Four prior HOL foundation axioms remain explicit. DISK_THM imports are not
  self-authenticating proof certificates. No new independent human review.
- Separate generic-heap EVAL attempts were manually interrupted: wrapper1/1,
  child signal2/2. Their unbounded symbolic expansion is not an accepted proof
  or a counterexample to the refund rules. The published CF rules are the next
  route for reference allocation and framing. Method setup attempt1 failed at
  an untyped empty AST list; attempt2 reached the generated method but xlet_auto
  does not handle cf_ref. Both failures remain; explicit xlet/xref is next.
- Published SexpProg replay was still running at this checkpoint. No completed
  library I/O, native executable or compiled behavioral theorem is claimed.
  The intended local target is the pinned arm8 Apple export on Darwin arm64.
  The separate native audit reports runtime-object build reproduction, which
  is not a refund executable or runtime correctness proof.
- Thirty owner-workspace input hashes remain unchanged0. No protected input,
  workflow, review, merge, publication, signing, admission or deployment change.
- Immutable schema packet:proposals/refund-executable-feasibility/io-schema-20261104/.
  Raw commands, failures and incomplete native work:
  results/refund-native-io-2026-11-04/attempt-0001/.
- Completed-result recovery archive:forge-refund-io-schema-2026-11-04-0001.tar.gz,
  SHA256f2e8dc3b7e49ebbc6ab067c4c1f7f2a81bd6d08e3d9a865f551ba2da01e5a2fe,
  100286976bytes,173 members,0600; full member hash validation0. Live Sexp
  build outputs were excluded. Independent archive hashes/restore remain open.
- Next: use the published CF reference and I/O rules for this exact generated
  method, then compile the same program through the pinned native backend.
  Preserve resource-limit, FFI, assembler, loader and host assumptions. Native
  execution and new admission remain NOT RUN. M2–M4 remain subsequent work.


## U264 — Wrapper tuple checks pass, but its actual tail guard lacks proof coverage

- References:U260–U263. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. This entry preserves completed local preparation and a
  failed coverage control. It does not authorize a native claim or new policy.
- Published SexpProg source replay completed0:62 theories rebuilt, local wall
  time2267.0141792919894 seconds. Initial identity inspection failed1 because
  two pinned trees contain typeSoundScript.sml. The corrected inspection uses
  the actual built object and logged source directory; exit0. No failed
  manifest was accepted. This is parser/library proof replay, not refund I/O.
- The wrapper uses published Sexp.inputSexp, then TextIO.inputAll on the same
  stream, and requires an empty remainder. It invokes the exact generated
  refund method and formats the same six fields. No custom codec or axiom.
  Source presence of this guard does not prove execution enforces it.
- Found an actual calling-convention mismatch: the translated input decoder
  returns nested pairs, while the generated method returns a flat six-tuple.
  Program-0002 constructs declarations but retains the wrong flat input pattern.
  Program-0003 fixes that pattern. Program-0004 checks actual pattern bindings
  through the published translator predicates and pmatch semantics. It also
  checks constructor availability and the final main-call declaration. Those
  selected theorems do not prove reachability, invocation or complete I/O.
- Program attempts0001/0002/0003/0004 return1/0/0/0. The first lacks explicit
  decoder translation. The final/repeat0/0 produce six byte-identical exports.
  Final source SHA25644ac5c9ecb51f13002cb7b762608ab39d4a0967053f34cc2d85adc6d9fd12e22;
  data SHA256ecda3e2a6d3dfd8eb71c251f5a76f8f7634be849f24208c2f0a706188ab3100d.
- Original flat-input mutation fails1 at refund_decoder_bindings. Swapped
  caller-output bindings fail1 at refund_result_bindings. Both logs contain
  the intended unsolved F. Neither has an accepted final theory export.
- SECURITY/ASSURANCE COVERAGE FINDING: replacing only `if rest = "" then`
  with `if true then` returns0 and exports a theory. Required negative exit
  remains1. The complete wrapper control matrix returns1. Preserve the actual
  mutant, exported objects and failure; do not relabel it as a passing negative
  test. The pure schema suffix theorem in U263 does not cover actual wrapper
  control flow. No native admission is enabled, so this is not a claimed
  production admission counterexample. The proposed assurance remains incomplete.
- Generic-heap EVAL attempts1–5 all failed1. Attempts1/2/5 were manually
  interrupted, child signal2; attempts3/4 failed helper proofs. No accepted
  general-heap theorem; do not run a sixth attempt of the same route.
  Method/frame attempts1–4 all failed1. Explicit framing reaches allocations
  0–3; Boolean reference allocation4 remains open. Only one further complete
  attempt remains for that same proof. Failures are not successful controls.
- Separate native audit packet has46 checked members. The unchanged pinned
  runtime C source compiles twice0/0 to identical ARM64 objects. These retain
  unresolved symbols; no refund executable exists. Docker inventory1 and two
  fixture-proof attempts1/1 failed on permissions before execution/proof. No
  redirected execution, permission bypass or accepted fixture result occurred.
  Existing compiler resource-limit, installed-image, FFI and host premises remain.
- This documentation checkpoint rechecked exact stored sources, object hashes,
  repeat equality, intended failure reasons and the uncaught mutation:exit0.
  It confirms the matrix is1; it does not rerun or repair that matrix. Thirty
  frozen owner inputs remain unchanged; upstream tracked source diffs remain0.
  No complete wrapper closure audit or new independent human review has run.
  Stored theorem hashes do not establish producer authenticity by themselves.
- Records:proposals/refund-executable-feasibility/native-io-20261104/ and sibling
  native-audit-20261104/. Raw sources, logs, all attempts and saved proof heaps
  remain in results/refund-native-io-2026-11-04/attempt-0001/. Earlier schema
  packet and all journal bytes remain unchanged. No proof or failure was deleted.
- Next smallest authorized check: prove the actual wrapper continuation refuses
  a nonempty remainder using existing CakeML semantics, with explicit state and
  environment premises. Require the unchanged guard mutation to fail at that
  theorem. This check is NOT RUN. Then compose method framing and published I/O
  rules; retain source/model, resource, runtime and installed-byte obligations.
- The owner reports a copy on another device. Exact archive hashes and restore
  on that copy remain unverified. GitHub state was not refreshed here. Native
  refund execution, hosted measurements and new admission remain NOT RUN.
  Publication, protected adoption, merge, dispatch, signing and deployment still
  require their corresponding authority and independent review. M2–M4 deferred.


## U265 — Actual guard rejection and prefix bindings checked; direct CF obstacle established

- References:U260–U264. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Previous goal turn made progress through local commit57cd895.
- The actual refund_main continuation is extracted from its checked declaration.
  Using existing CakeML evaluate rules, refund_tail_rejects proves that every
  nonempty remainder raises Fail "refund: trailing input", preserving modeled
  references and FFI under explicit environment and clock32 entry conditions.
  The theorem does not execute stdin, prove the accepted path or establish a
  native process guarantee. No input-domain restriction or new axiom was added.
- Guard attempts0001/0002 were manually interrupted during broad expansion:
  dispatcher1/1, child signal2/2. Attempt0003 failed1 on a wrong theory qualifier.
  Attempt0004 passed0 after using published namespace conversions and semantic
  rewriting. Initial declaration inspection1 is also preserved; corrected exact
  equality/error lookup inspection0. No incomplete run became accepted evidence.
- The exact old guard-removal mutation still builds the old partial program0.
  The unchanged new guard theorem now fails1 at refund_tail_rejects, with no
  accepted export. Original U264 actual0 remains preserved. Parent restoration0
  reproduces all six original exports; guard repeat0 reproduces its six exports.
  The four-outcome guard dispatcher returns0. This is formal refusal, not a
  hosted or native counterexample execution.
- The entry supplement proves the actual unit-call prefix shape, its full
  namespace after the prefix returns values, the required lookups and rejection
  in that namespace. Stream, parsed value and nonempty remainder remain explicit
  returned-value premises. Clock32 is a model budget, not wall time. Additional
  prefix bindings cannot silently replace the required remainder/equality/error
  bindings. Full stream/heap composition and physical input delivery remain open.
- Entry attempt0001 manually interrupted1, child signal2, during closure expansion.
  Attempt0002 passes0 using a checked general single-recursive-call lemma. A
  mutation binds rest to empty instead of the actual remainder: expected1 at
  refund_actual_prefix_lookups, unsolved rest=empty. Entry repeat0 has six identical
  exports. Its control dispatcher0 checks both actual outcomes.
- Guard source e64a19a8ea3f63fc4c6a4f1c1d045bdc630756866cc16940c8c80ff57189aad2;
  data4e94b435a244814c62fe87730a1fdea5b716e31fc1b21c7165d5f3a7df4c244d.
  Entry source669b13bbb65cd7004bf6bab437d955f09c6cafccfdd8ffd3e40b3e0b2797d9ff;
  data4bbd481738df083a0fd905b7ded5a6dc8508b51c44222f612b84d7f8ed06844e.
  Parent source44ac5c9e and dataecda3e2a remain exact and unchanged.
- Fresh HOL inspection0 covers231 loaded theory nodes and eight own theorems,
  zero own hypotheses. SELECT_AX, INFINITY_AX, ETA_AX and BOOL_CASES_AX remain
  the four explicit foundation axioms. Imported DISK_THM is not self-authenticating.
  No new independent human review or accepted provenance profile exists.
- A separate exact-method applicability proof and repeat return0/0, six identical
  exports. The first raw match discriminant has exp2v env discriminant=NONE for
  every environment. Thus the cf_match SOME-value premise is impossible there.
  This is not a refund behavioral violation. Resolving Boolean allocation alone
  would not finish the direct CF proof. Preserve the four failed raw-method
  attempts; do not spend a fifth on the same unaddressed applicability problem.
- Pinned cfNormaliseLib source explicitly says its normalization is unverified.
  The API returns syntax; the old full_normalise_correct text is commented out.
  Four inspected upstream files match their pinned Git blobs0. The transform
  has NOT RUN. Do not assume it preserves the old generated-method theorem.
  Applicability sourceaef2ded5f125be31c99abad57e51769dee271d2ee260302941f5336d89ec04db;
  data1212f1830466a2756de7fe9de19e175d7153c3cc29acbd2de1a135e26afb54da.
- Next authorized experiment: use the published normalizer only as an untrusted
  candidate transformation. Independently prove the complete refund result for
  its exact output and a checked observable-result relation to the original
  method. No narrower domain, changed rule, unchecked equivalence or new verifier.
  If the relation cannot be proved, keep it unestablished. Native compilation
  must use the same sufficiently checked program; no replacement toy target.
- Records:proposals/refund-executable-feasibility/tail-guard-20261104/ and
  results/refund-tail-guard-2026-11-04/attempt-0001/. All previous packets, logs,
  attempts and proof heaps remain. Thirty frozen owner inputs and tracked upstream
  source trees are unchanged0. The actual wrapper/method source is unchanged.
- M1 remains NOT_ESTABLISHED. Library method/heap, prefix I/O, accepted output,
  full source/model binding, exact native artifact and runtime premises remain.
  New admission/provenance, hosted refund metrics and native execution are NOT RUN.
  Owner-reported off-machine backup still needs exact archive hashes and restore.
  GitHub state was not refreshed. No protected adoption, publication, merge,
  dispatch, signing or deployment. M2–M4 remain subsequent work.


## U266 — Candidate normalization incomplete; Markdown tracking checkpoint

- References:U261,U264,U265. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. The owner requested durable Markdown tracking. The full
  mission remains byte-identical to the attachment. FORGE_MISSION_STATUS.md
  remains the entry point; ROADMAP.md records actual outcomes.
- The published normalizer was invoked only to construct an untrusted candidate.
  No correctness of normalization was assumed. Attempts construct and
  construct-0002 return1/1 after manual SIGINT, child signal2 each. Neither
  exports a candidate AST or accepted theory. This is incomplete preparation,
  not a behavioral counterexample or proof that construction is impossible.
- The second attempt replaces broad evaluation with exact method-definition
  rewriting and adds progress markers. FORGE_INPUT_READY is observed;
  FORGE_NORMALISED_AST_READY is absent. The incomplete operation is the call to
  cfNormaliseLib.normalise_decl. A process sample returns0 but does not identify
  a named internal ML subroutine. Exact cause remains unresolved.
- First sourcea41d9fe995463ec2248c153f3cbd5c896d326ba5455cb092c81d3acd91a99cc2;
  second501afdae1901aad193b9d288ed41c70d88602647b0c0b6f6bda8462e4f57c9ff.
  Local incomplete-run elapsed durations184.03520208300324 and269.4683468750154
  seconds are recorded observations, not proof or hosted performance results.
- Initial record validation fails1 on the separate native packet's manifest
  filename. Its source/error remain preserved. Corrected validation returns0:
 30 protected owner inputs, the original wrapper source/data and329 prior
  packet members match. HOL/CakeML tracked diffs return0. No source claim changed.
- Previous guard/prefix proofs and the original uncaught mutation remain intact.
  This checkpoint adds no completed assurance link. Old generic-heap attempts
  remain five; old raw CF attempts remain four, with their applicability obstacle.
  Candidate construction has two incomplete attempts. Do not reset these counts
  or repeatedly retry the unchanged failure.
- Next check, NOT RUN: localize the incomplete operation using the published
  transform's existing operations. If it produces a candidate, independently
  prove all six return fields for the full model domain and the observable-result
  relation to the original method. Then close library framing and whole-program
  I/O. Do not adopt the candidate solely because construction succeeds.
- Packet:proposals/refund-executable-feasibility/normalisation-20261104/.
  Raw:results/refund-normalised-method-2026-11-04/attempt-0001/. Sources, actual
  argv, logs, exits and interruption records are preserved. Hashes alone do not
  authenticate their producer. The actual wrapper and method remain unchanged.
- Native refund execution, hosted measurements and new admission are NOT RUN.
  The owner reports an independent-device copy; exact archive hash/restore
  remains unverified. GitHub controls were not refreshed. Independent review,
  protected adoption, publication, merge, dispatch, signing and deployment retain
  their existing boundaries. M2–M4 remain subsequent work.


## U267 — Full library result and original-method relation checked through existing translation

- References:U260,U262–U266. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Previous goal turn saved an exact incomplete-operation
  checkpoint at341afa16. This turn adds a checked library link, not a native claim.
- Third normalization construction is manually interrupted1, child signal2.
  Exact input preparation and annotation stripping completed. Normalization did
  not return. Exact raw-method inspection returns0. Three construction attempts
  are now preserved. The source's duplicated right-operand traversal and repeated
  fresh-name scans may explain the stall; that cause is not profiled or proved.
- Alternative local route uses the existing CakeML translator to produce code
  and a translation theorem for the complete refund_fields function. It retains
  the existing eligible predicate, mathematical integers, arbitrary model byte
  strings and all nine typed inputs. All six result fields remain required.
  No bounded toy example, new codec, verifier, semantics or axiom was introduced.
- refund_fields_original_method proves the complete returned-field relation to
  the unchanged generated method under its existing primitive caller and clock32.
  It maps the new HOL nested product to the original flat CakeML result tuple.
  This is an output relation for that caller, not arbitrary contextual equivalence.
- refund_verified_spec proves the exact proposed library call under the published
  CF application judgment with emp ownership and full result representation.
  Its frame guarantees apply to this new implementation. It does not repair the
  old raw-method proof or the old wrapper. No request eligibility precondition
  was added. The stateless decision and intent count do not execute a payment.
- Library attempts0001–0004 return1/1/1/1: missing direct imports, unresolved
  Boolean representation, folded Boolean type stamp, then wrong theory qualifier.
  These are proof/setup failures, not behavioral counterexamples. Attempt0005
  returns0. The positive source remains2ef6fd80d2fcccbc092096e2e20fc5d616af1a99fe00e1e949450f55e3e31632.
- Altering the approved amount to amount+1 fails1 at refund_fields_original_method.
  Swapping charge/request in the actual new wrapper call fails1 at
  refund_verified_spec. Neither exports an accepted theory. run_controls.py0
  checks these exact reasons and positive repeat0. All six positive exports are
  byte-identical; theory data5ffd9d6f201fb279acba5abbb30b24c55b950982f84dc2724c36fdd966e6c91a.
- Fresh HOL import/inspection returns0:192 theory nodes, seven own theorem tags,
  zero own hypotheses, only DISK_THM import tags. The closure retains SELECT_AX,
  INFINITY_AX, ETA_AX and BOOL_CASES_AX. This is not replay of every upstream
  source, independent human review or authenticated producer verification.
- Saved-record readback0 confirms actual outcomes, source/object identities,
  30 frozen owner inputs and unchanged original wrapper source/data. Tracked
  HOL/CakeML source diffs remain0 at the recorded pins. No protected source changed.
- Dependency snapshot attempts1/2 return1/1 on loader source-location and kernel
  module classification mistakes. Both failed scripts/errors remain. Final0
  follows existing loader records and hashes191 theory file sets plus the HOL
  executable and CakeML heap. min is the explicit kernel seed. A file digest
  identifies bytes; it does not authorize an evidence producer.
- The actual old wrapper remains unchanged. The proposed function uses forward
  argument order and a nested return product. Its adoption needs a checked
  adapter or replacement wrapper. Existing Unicode source results remain; their
  complete binding to this exact program and native I/O remains unestablished.
- Next authorized experiment, NOT RUN: compose this complete library contract
  with the existing strict wire decoder, response schema and TextIO rules.
  Prove actual proposed-wrapper output and malformed/trailing-input refusal.
  Then bind the same whole program to the exact compiler result and its entry,
  resource, FFI and runtime premises. Do not replace full proof with fixtures.
- Packet:proposals/refund-executable-feasibility/certified-library-20261104/.
  Raw:results/refund-certified-library-2026-11-04/attempt-0001/ and
  results/refund-normalised-method-2026-11-04/attempt-0002/. Earlier failures and
  proof heaps remain. No native executable, hosted refund run or new admission.
- M1 remains NOT_ESTABLISHED. The exact implementation/claim/profile still needs
  independent review before protected adoption. Owner-reported off-machine copy
  still needs exact archive hashes and restore. GitHub was not refreshed.
  No publication, merge, dispatch, signing, admission or deployment occurred.
  M2–M4 remain subsequent work. No performance improvement is claimed.


## U268 — Wire dispatcher proof checked; I/O attempts and tracking checkpoint preserved

- References:U261,U264–U267. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. The owner requested durable Markdown tracking. The complete
  mission remains byte-identical. FORGE_MISSION_STATUS.md remains the entry point.
- Saved wire-0001 returns0 and exports seven theorems: valid request computation,
  six-field response round-trip, decoder-error preservation, trailing-input and
  malformed-input refusal, and dispatcher return/error CF application contracts.
  The existing parser, serializer and translator are reused. No model-domain
  restriction, changed refund rule, custom verifier or new semantics was added.
- Source417b69d41a58da1ab3831e25cc3cf4ec6db7c0fcafd8af50be0caf9fd2306fb9;
  data17482ed974f856688298b957aee8d5155b5d56e2a104bbe3ec2a02056a690ae1.
  This proves modeled byte-string behavior, not full Unicode/native binding.
  The original wrapper/method remain unchanged. No replacement was adopted.
- Stdio attempts0001/0002/0003 return1/1/1, each at refund_main_valid with no
  accepted I/O export. First used wrong quoted constructor case. Second fixes
  None/Some but leaves the read-rule proof incomplete. Third supplies a diagnosed
  existential witness and unfolds string representation, yet still fails.
  Exact remaining third-attempt subgoal is unresolved. Three full attempts remain
  on record; do not reset the count or repeat the unchanged failure blindly.
- Diagnostic exits1/1/1/0 remain. The third has a theorem-instantiation type
  problem. The fourth inspects intermediate goals only. Its exit0 is not a
  complete proof, accepted I/O theory or native execution result.
- Latest failed I/O source17813e63c2a6f122aa82a4c9e408bc15e09c944ed44208736bb509dc6c0f59c1.
  New wire repeat, tamper controls and closure audit are NOT RUN. Earlier library
  controls do not cover the new dispatcher. Imported objects remain an explicit
  trust boundary. Hashes alone do not authenticate a producer.
- Checkpoint readback0 validates saved source/object hashes, exact numeric exits,
  seven theorem markers,30 frozen owner inputs and unchanged original wrapper.
  Pinned CakeML/HOL tracked diffs remain0. No proof command was rerun for this
  Markdown checkpoint. Raw failed proof heaps remain; no evidence was deleted.
- Saved GitHub mainf9eb1cbc252b28c80e5dfe2774da71bc35a31bd3; PR34 draft head
 46e5aa426bf7800df7c98c732a764337e716f6bb; PR36 head705457e069abbe399128808b1efc7242d8eaeaa1;
  PR37 draft headfc85ecc2c7f12caa6c8991fa002410bdf78dd51d. All open and unmerged.
  Reviews were not fetched; no approval is inferred. PR34 remains a demonstration;
  PR36 stays separate from research work. No remote mutation occurred.
- Effective-rule/list/detail reads0/0/0 expose active ruleset26065125. It requires
  one review, code-owner review, last-push approval, stale-review dismissal and
  resolved threads, plus deletion/non-fast-forward protection and linear history.
  No required status-check/workflow rule appears in the returned effective set.
  Classic protection returnsHTTP404/exit1; this does not negate the active ruleset.
  Bypass permissions were observed but not used. No governance setting changed.
- Next check: inspect the saved third I/O proof goal before another build. Then
  prove complete modeled output/refusal, check targeted mutations and reproduce
  the exact positive exports. Whole-program/compiler entry, native artifact,
  Unicode binding and runtime/environment correspondence remain later open links.
- Packet:proposals/refund-executable-feasibility/wire-library-20261104/.
  Raw:results/refund-wire-library-2026-11-04/attempt-0001/. Sources, commands,
  all failures and copied small evidence files are preserved. No new independent
  human review, authenticated claim profile, native execution or admission.
- Off-machine exact archive hashes and restore remain unverified despite the
  owner's reported copy. Hosted refund measurements are NOT RUN. No protected
  adoption, publication, merge, dispatch, signing or deployment ran. M2–M4 remain
  later work. M1 and integration EXIT remain NOT_ESTABLISHED.


## U269 — Local native-signing scope approved; independent library audit recorded

- References:U264,U267,U268. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. This checkpoint changes one local action boundary only.
- The installed linker manual states that Apple Silicon binaries receive an
  ad-hoc signature by default; -no_adhoc_codesign disables that step. Apple
  Platform Security documents the native arm64 signature requirement. The
  official search result was available; direct page fetch returned HTTP429.
  No link or signing action was used to test this requirement.
- After the resumed audit thread explained that the prior no-signing instruction
  blocks the native route, the owner replied exactly: i approve. That thread
  acknowledged approval only for the local ad-hoc signature needed to execute
  the eventual macOS arm64 refund artifact. Release signing, publication,
  deployment, protected changes and Stage12 remain unauthorized. No signing
  has run. The approval does not establish artifact correctness or admission.
- Approval source thread:01a1a730-e1f4-7d02-b06e-46b82d817f5f. The original task's
  attempt to retrieve that exchange failed. The resumed thread therefore owns
  the eventual local linking/signing/executable controls; the compiler/proof
  work can prepare unsigned output. Conversation authorization is not a signed
  release-approval artifact. Exact scope is preserved in local-signing-authorization.json.
- Independent saved-record audit0 confirms candidate source2ef6fd80, six
  identical positive/repeat exports0/0, intended altered-amount and swapped-ID
  refusals1/1,192 recorded theory nodes and four existing foundation axioms.
  This is a hash/statement review, not a new independent kernel replay.
- Candidate outputs use nested pairs; the old method uses a flat six-field
  tuple. Their wire integration must retain all field positions. No old tuple
  proof transfers automatically. The source semantics also distinguishes
  logical termination from a POSIX process exit status. Native error-code claims
  need an explicit bridge; checker refusal codes are not application exits.
- Static normalizer inspection identifies duplicate traversal of logical right
  operands and growing fresh-name scans as a plausible stall cause. No measured
  attribution or complexity theorem is claimed. The alternative certified
  library does not establish the old normalizer's correctness.
- Static build-driver inspection identifies a likely permission cause: HOL
  cache-key computation calls PolyML tmpName, and the installed SDK defines
  P_tmpdir as /var/tmp, outside this thread's writable roots. The exact denied
  syscall remains untraced. No fixture retry, permission bypass or tool-source
  change occurred. The prior EPERM failures1/1 remain unresolved.
- Own read-only ld -help query returned1 for an unsupported option; retained.
  Source/manual and candidate readbacks returned0. Follow-up packet commit and
  14-file committed readback returned0/0. Commit
  3c5bb8ca822d2078e85c2f2533f1191b62efd8f9 is local, unsigned and unpublished.
- Evidence:proposals/refund-executable-feasibility/native-audit-followup-20261104/REPORT.md
  and results/refund-native-audit-2026-11-04/attempt-0002/. All50 frozen protected
  paths and the mission bytes match; prior516530 journal bytes remain intact.
- Impact: local signature permission is resolved in the resumed thread. Native
  executable correctness, actual controls and independent correspondence remain
  unestablished. Next: finish the whole-program and error-path bridge, compile
  the exact program, and bind its final artifact hash to native controls. Keep
  end_to_end=false until the complete required relation is independently checked.


## U270 — Proposed modeled I/O contracts and five adversarial controls pass

- References:U267–U269. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. The prior turn committed a5e974b5 with exact unfinished I/O
  evidence. This turn closes the modeled I/O application link, not native execution.
- Saved-goal diagnostics0005/0006/0007/0008 return1/1/0/0. Unfolding the existing
  option relation removes an incompatible witness. Published computation tactics
  discharge the concrete constructor-pattern obligations. All failed diagnostics
  and post-completion goal-inspection errors remain. They are not accepted exports.
- Full I/O attempt0004 returns0. refund_main_valid proves exact modeled stdout
  after consuming stdin when the wire result is INR output. refund_main_error
  proves Fail err with consumed input and otherwise unchanged STDIO when the
  result is INL err. Both retain the explicit stdin-content premise.
- The repair changes proof tactics only. No rule, program behavior, semantics,
  axiom or domain was weakened. Original wrapper and generated method unchanged.
  Complete Unicode/source/native binding remains open. No actual bank operation
  follows from the stateless refund decision and intent-count result.
- I/O source6f7aa17a5c671d83c94d2726932a7757083e30ee5508cce64f667f43138e0a68;
  data8971cd15449d1edbd0836aaba9f7339cd3a3da01268103cccd317d4df8054255.
  Wire source417b69d4 and data17482ed9 remain exact. Both fresh positive repeats
  return0 and each reproduces all six exports byte for byte.
- Swapped response IDs fail1 at refund_render_fields_roundtrip. Accepting the
  trailing-input error fails1 at refund_run_wire_decode_error. Suppressing the
  dispatcher exception fails1 at refund_dispatch_error. Wire control runner0
  explicitly checks all three reasons and the repeat. No accepted mutant export.
- Suppressing output and substituting a named file for stdin each fail1 at
  refund_main_valid. I/O control runner0 checks both reasons and the repeat.
  These checker failures are not application process exit codes.
- readback_io.py0 checks all five refusals, identities, original wrapper and30
  frozen inputs. Pinned HOL/CakeML tracked diffs0. Fresh closure import0 covers230
  nodes and39 exported theorem tags with zero hypotheses and only DISK_THM tags.
  SELECT_AX,INFINITY_AX,ETA_AX,BOOL_CASES_AX remain the four foundation axioms.
  Dependency snapshot0 hashes229 theory file sets and the kernel/heap. min is the
  kernel seed. This is not a replay of every upstream source or human review.
- Eight inspected upstream sources match their pinned blobs0. The published
  semantics Success label is not a POSIX status theorem; modeled Rraise can
  satisfy its termination classification. Native status/stdout/stderr require
  actual controls and their own explicit runtime relation. No exit1 is inferred.
- Separate follow-up audit3c5bb8ca is copied and verified0,14 files. U269 and its
  exact shared-doc append remain intact. Its thread owns eventual local linking,
  ad-hoc signing and executable controls under that thread's owner approval.
  This task prepares unsigned proof/compiler work. No signing or native run occurred.
- The separately started whole-program source bridge is IN_PROGRESS at this
  checkpoint. run_whole.py whole-0001 has no completed numeric exit yet. Published
  library dependencies build first. Do not infer a passing whole-program theorem
  from the application contracts or from successful dependency builds.
- Next check: finish that exact live build; localize any actual failure. Require
  an entry-substitution control and positive reproduction, then bind the exact
  program to the existing arm8 compiler. Preserve source initialization, resource,
  code installation, FFI, Unicode and concrete runtime premises explicitly.
- Packet:proposals/refund-executable-feasibility/stdio-contract-20261104/.
  Raw:results/refund-stdio-composition-2026-11-04/attempt-0001/. All prior attempts,
  heaps and evidence remain. Imported object hashes do not authenticate a producer.
- Native execution, hosted refund measurements and new admission remain NOT RUN.
  Exact claim/profile review and independent-copy archive hashes/restore remain
  open. GitHub was not refreshed. No protected adoption, publication, merge,
  dispatch, release signing or deployment ran. M2–M4 remain later priorities.


## U272 — Frozen native wire fixtures checked through direct HOL evaluation

- References:U262,U263,U267,U269,U270. CURRENT none; M1 open; Stage12
  unauthorized; end_to_end=false. U271 is reserved by the original task for
  its separate whole-program checkpoint. No earlier entry was changed.
- The22 frozen fixture expectations now have fresh kernel evaluation evidence.
  The documented HOL run interface with the explicit pinned CakeML heap returns0.
  It checks the existing refund_fields and refund_run_wire definitions and
  evaluates the published serializer to44 exact typed input/output files.
  No new refund predicate, codec, verifier, machine model or axiom was introduced.
- The initial direct run returned1 while loading intLib at TAUT_PROVE without
  the explicit CakeML heap. Its source and diagnostics remain preserved. The
  earlier Holmake EPERM attempts1/1 remain unresolved as build-driver runs.
  No denied operation was rerouted through another task; no permission or
  temporary-path implementation changed. The direct interface ran in this
  thread with the same filesystem restrictions.
- Six malformed-wire checks return0:trailing newline, second request, unclosed
  expression, empty stream, missing fields and invalid integer. Each has an exact
  model error equality and input-byte equality. Native error status is unproved.
- Wrong expected amount and swapped expected caller IDs each return1 at EQT_ELIM
  before any fixture theorem marker. These are the intended claim refusals.
  The positive repeat returns0 and all44 typed files are byte-identical.
  There are100 first-pass evaluation theorems:88 typed and12 malformed.
- Control preparation first returned1 because its text split selected the ML
  assignment. An incorrectly continued dependent dispatch returned1 for an
  absent script, without starting HOL. Both are preserved infrastructure errors,
  not accepted negatives. Corrected preparation returned0. Closure inspection
  first returned1 for an unqualified hyp name; corrected Thm.hyp inspection0.
- Independent closure and hash readback0 checks229 nodes,228 disk-theory file
  sets,36 wire-theory tags and the four existing HOL foundation axioms. DISK_THM
  remains explicit. This does not independently replay every imported source or
  authenticate a producer. Fixture materialization and host execution remain
  trust dependencies. The complete Unicode source proof did not rerun.
- Packet:proposals/refund-executable-feasibility/native-fixtures-20261104/REPORT.md.
  Raw:results/refund-native-audit-2026-11-04/attempt-0003/.
  Typed batch source7f73ec35; pinned heap36f7c254; pinned HOL executable736c669e.
  Local unsigned unpublished commit32e3613da6edc070d373101986c0bdfeb826f5c8.
  Committed readback0 checks300 files. All50 protected paths and mission bytes
  match; the original516530-byte uncertainty prefix remains intact.
- Impact: fixed native inputs and expected bytes now have model proof evidence.
  No refund native compile result, link, signature or execution is established
  by this audit. U269's limited local ad-hoc signature permission remains.
- Next check: bind exact compiler bytes/data/configuration and generated assembly
  to the native artifact, then execute these frozen cases with captured streams
  and statuses. Preserve resource, installation, physical I/O, whole-program
  error-path, Unicode/model and independent assurance gaps. No Stage12, release
  signing, deployment, protected adoption or publication is authorized.


## U271 — Whole-program refund source theorem checked and reproduced

- References:U267,U270,U272. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. U272 was appended first by the separate audit task; its
  position and bytes remain intact. This entry closes a source-semantics link.
- run_whole.py whole-0001 returns0. The existing prove_sem_thm bridge checks
  declaration initialization, the actual refund_main namespace binding, the
  unchanged initial FFI and required library references. It accepts three
  exported theorems. Twelve published dependencies also build successfully.
- refund_semantics applies to the exact refund_prog declarations. Preconditions
  are stdin_content equal to the canonical nine-field request serialization,
  wfcl cl, wfFS fs and STD_streams fs. Its sem_satisfies conclusion is modeled
  Terminate Success with an extracted filesystem equal to consumed stdin plus
  the complete rendered six-field refund result appended to stdout.
- Every typed model request remains covered, including authorized and rejected
  results. No eligibility premise or numeric bound was added. Model byte strings
  and integers remain unbounded. The full Unicode/source/model assurance binding
  is still open. The stateless decision does not perform actual bank operations.
- Replacing the bridge entry with refund_dispatch while retaining refund_main_v
  fails1 on SOME refund_dispatch_v = SOME refund_main_v. No mutant theory is
  accepted. The driver verifies that the intended entry check ran. This is not
  an infrastructure failure or a native process status.
- The positive repeat returns0. All six exported files are identical. The
  control dispatcher returns0. Whole source SHA256:
  37d623cc2437f391d4a0e72afcc72ed0b541e82f985dc5a2dfbe73a29e3ef4d0.
  Repeated theory data SHA256:
  52b94fa448fa6de315cab80251ed5cdf46184a576e9478644b374e8071b19ded.
- Fresh closure import, dependency snapshot and readback return0/0/0. There are
  243 nodes,242 disk-theory file sets and42 exported theorem tags. The inspected
  tags have no hypotheses and only DISK_THM imports. The four existing foundation
  axioms remain SELECT_AX,INFINITY_AX,ETA_AX,BOOL_CASES_AX. Hashing imports does
  not authenticate their producer or independently replay every upstream source.
- First build elapsed737.2824473340006 local seconds, including dependencies.
  No hosted measurement or performance improvement is inferred. All earlier
  unsuccessful diagnostics and proof attempts remain preserved.
- Local recovery create/verify/restore/fsck return0/0/0/0. The restored bundle
  has exact commit cb68edf783ac249089999151df5821a90239b26d and116 checked files.
  Bundle SHA25615d842a4d333e34e4b895e6383ef5d095192826c26e9e854f6639f5c04d08b6d.
  This is same-machine recovery, not an independently verified off-machine copy.
- The separate U272 fixture packet matches all300 files in local commit
  32e3613da6edc070d373101986c0bdfeb826f5c8; import readback0. It supplies tested
  inputs and kernel-checked expectations, not a native behavioral theorem.
- The existing in-logic ARM64 compiler is now running on exact refund_prog_def.
  Record:results/refund-arm8-compile-2026-11-04/attempt-0001/compile-0001/.
  Its terminal result is IN_PROGRESS at this checkpoint. No successful refund
  compile, machine-code identity or linked executable is claimed. No new compiler,
  decoder, verifier, semantics or axiom was introduced.
- Next check: complete that exact invocation, then inspect its actual theorem,
  byte/data/configuration identities, reproduction and compiler-correctness
  composition. Preserve resource-limit behavior, installation, FFI and OS premises.
  The whole-program malformed-input path remains separate from POSTe. Logical
  Success and checker exit codes do not prove POSIX termination/status.
- Evidence:proposals/refund-executable-feasibility/whole-program-20261104/REPORT.md;
  raw results/refund-stdio-composition-2026-11-04/attempt-0001/. Original approved
  method and wrapper remain unchanged. Native execution, hosted refund tests and
  new admission remain NOT RUN. M1 and strict integration EXIT remain open.
- Independent exact-claim/profile review and off-machine archive hash/restore
  remain unresolved. GitHub was not refreshed. U269 limited local signing stays
  with the separate audit task. No protected adoption, publication, merge,
  dispatch, release signing or deployment ran here. M2–M4 remain later priorities.
