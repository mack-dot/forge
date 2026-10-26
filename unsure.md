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
