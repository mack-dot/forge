#!/bin/sh
# Run in a normal terminal with the existing contributor GitHub login.
# Publication and review request only. Never approves, merges or dispatches.
set -eu
repair_repo=mack-dot/forge
repair_head=9a0247e9b36fa9558df3943333fc9b33ce967544
repair_branch=integration/receipt-authentication-contributor
repair_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repair_previous=$(gh api user --jq .login)
trap 'gh auth switch --hostname github.com --user "$repair_previous" >/dev/null 2>&1 || true' EXIT
gh auth switch --hostname github.com --user mackiannii
[ "$(gh api user --jq .login)" = mackiannii ] || {
  echo 'Contributor identity was not selected. No publication.' >&2
  exit 1
}
[ "$(gh api "repos/$repair_repo/git/commits/$repair_head" --jq .tree.sha)" = b3cb9c42bae48ef6ce7239dfcccdcb4560e7e186 ]
[ "$(gh api "repos/$repair_repo/git/ref/heads/main" --jq .object.sha)" = e7b5b52aad5d020224dd057e1019004b15dc8739 ]
# Create, never overwrite: any existing replacement branch causes a safe stop.
gh api --method POST "repos/$repair_repo/git/refs" \
  -f "ref=refs/heads/$repair_branch" -f "sha=$repair_head" >/dev/null
gh pr create --repo "$repair_repo" --base main --head "$repair_branch" \
  --title 'Authenticate obligation receipt reuse within the trusted verifier process' \
  --body-file "$repair_dir/CONTRIBUTOR-PR-BODY.md" --reviewer mack-dot
gh pr view "$repair_branch" --repo "$repair_repo" \
  --json url,author,headRefOid,baseRefName
echo 'Replacement published. Approval and merge remain separate.'
