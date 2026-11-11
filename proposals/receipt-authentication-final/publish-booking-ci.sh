#!/bin/sh
# Authorized publication only. Never approves, merges, or dispatches.
set -eu
booking_repo=mack-dot/forge
booking_head=db5b76f0f0ff52cdbe121ee2cfde5cb4e7f3f072
booking_branch=integration/booking-reuse-ci
booking_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Return to the owner account that was active before agent preparation.
trap 'gh auth switch --hostname github.com --user mack-dot >/dev/null 2>&1 || true' EXIT
gh auth switch --hostname github.com --user mackiannii
[ "$(gh api user --jq .login)" = mackiannii ] || {
  echo 'Contributor identity required. No publication.' >&2
  exit 1
}
[ "$(gh api "repos/$booking_repo/git/ref/heads/main" --jq .object.sha)" = edd9f9d95b315ea9985c9d892522923a457a3964 ]
[ "$(gh api "repos/$booking_repo/git/commits/$booking_head" --jq .tree.sha)" = 624ef75c46cdd260b39308763cfdf27ed8ba99e5 ]
gh api --method POST "repos/$booking_repo/git/refs" \
  -f "ref=refs/heads/$booking_branch" -f "sha=$booking_head" >/dev/null
gh pr create --repo "$booking_repo" --base main --head "$booking_branch" \
  --title 'Run booking verification and safe reuse on GitHub-hosted Linux' \
  --body-file "$booking_dir/BOOKING-WORKFLOW-PR-BODY.md" --reviewer mack-dot
gh pr view "$booking_branch" --repo "$booking_repo" \
  --json url,author,headRefOid,baseRefName
echo 'Workflow PR published for review. No merge or dispatch performed.'
