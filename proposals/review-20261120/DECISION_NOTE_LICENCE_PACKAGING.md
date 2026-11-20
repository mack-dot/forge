# Decision note for the owner: licence and packaging

Status: 2026-11-20. A note only. It picks no licence and publishes nothing. **This is not
legal advice.** Ask a lawyer before you choose. Source: review claim 2 and its
"Developer experience" section ([REVIEW.md](REVIEW.md)).

Facts today: `gh repo view mack-dot/forge --json visibility,licenseInfo` gives
`"visibility":"PRIVATE"` and `"licenseInfo":null` (exit 0). With no licence, nobody
outside has a right to use, copy or change the code.

## Licence options (one line each; general summaries)

| Option | What it permits | Main trade-off |
| --- | --- | --- |
| Apache-2.0 | Any use, commercial use included, with notice | Has an explicit patent grant and a patent-retaliation clause; permits closed forks |
| MIT | Any use, commercial use included, with notice | Very short; no explicit patent grant; permits closed forks |
| BUSL-1.1 (Business Source License) | Source available; non-production use; production use only as the licensor's "Additional Use Grant" allows | Not open source until the "Change Date" (at most four years), then it converts to the named Change License (often Apache-2.0 or GPL) |
| PolyForm Noncommercial 1.0.0 | Use for noncommercial purposes only | Blocks commercial adopters; not open source |
| Elastic License 2.0 | Most use; not as a hosted or managed service of the software; no removal of licence-key functions | Not open source; restricts service providers only |
| Stay private, no licence | Nothing for outsiders | No adoption; keeps every option open |

## Packaging plan (a plan only)

Candidate names. A read-only query on 2026-11-20 (`curl -s -o /dev/null -w '%{http_code}'`
to `https://pypi.org/pypi/<name>/json` and `https://registry.npmjs.org/<name>`) gave HTTP 404
for `forge-airlock`, `forge_airlock` and `forge-airlock-sdk` on both registries. A 404 means
that no project had that name at that time. It does not reserve the name. Scoped npm names
were NOT CHECKED. Trademark use of "Forge" was NOT CHECKED.

What each package would hold:

- Python (`pyproject.toml`): `sdk/py/forge_airlock.py`, the dispatcher `bin/forge-airlock`,
  and the engine: either the sources `src/airlock/*.rs` (the user builds with `rustc` 1.92.0)
  or a prebuilt engine binary per platform (wheels per platform).
- npm: `sdk/ts/forge_airlock.ts` (CommonJS TypeScript with erasable syntax for Node 24),
  plus the same dispatcher and engine question.
- The refund binary `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho` is a
  Mach-O ARM64 executable only (`file` output). The `canonical-refund` profile works only
  on macOS ARM64. Other platforms need a decision: ship without that profile, or build
  and pin a new binary (a new binary has no M1 record).
- The booking checker needs a model built once by Dafny 4.11.0.

What blocks packaging today:

- Each SDK finds the dispatcher relative to its own file: `sdk/py/forge_airlock.py` lines
  51-52 (`ROOT = Path(__file__).resolve().parents[2]`; `DISPATCHER = ROOT / 'bin' /
  'forge-airlock'`), `sdk/ts/forge_airlock.ts` lines 33-34. A package would need a
  configurable engine path.
- No `pyproject.toml`, no `package.json` for the SDK, no `Cargo.toml` in the repository.
- The root `package.json` is a protected path. A package manifest must be a new file in
  another folder, or an exact-diff proposal for the owner.
- No CI job builds or tests `src/airlock` or `sdk/`.
- The Goal 20 evidence bundle hashes the SDK files and the dispatcher; a packaging change
  to them changes the bundle subject.

## Decisions for the owner

1. A licence, or "stay private".
2. Whether to publish to PyPI and npm, and under which names.
3. Source build (needs `rustc`) or prebuilt engines, and for which platforms.
4. What to do with the `canonical-refund` profile off macOS ARM64.
5. Whether the product moves to its own repository, apart from the records (review
   recommendation 3).
