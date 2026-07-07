# Branch Protection Policy — `main`

This document describes the recommended branch protection rules for the
`main` branch. Apply them via GitHub UI:
**Settings → Branches → Add rule → `main`**.

## Required settings

### Branch protection rules

- ✅ **Require a pull request before merging**
  - Required approvals: **1** (or 2 for high-traffic repos)
  - Dismiss stale pull request approvals when new commits are pushed: ✅
  - Require review from Code Owners: ✅
- ✅ **Require status checks to pass before merging**
  - Require branches to be up to date before merging: ✅
  - Required status checks:
    - `Analyze & Test`
    - `Build Web`
    - `Build Android APK`
- ✅ **Require conversation resolution before merging** — all PR comments must be resolved
- ✅ **Require linear history** — forces rebase or squash merges, no merge commits
- ✅ **Do not allow bypassing the above settings** — even admins follow the rules

### Optional but recommended

- ✅ **Restrict who can push to matching branches** — only admins
- ✅ **Restrict pushes that create matching branches** — only admins can create new `main`-named branches
- 🟡 **Allow force pushes** — ❌ **Disable** for `main`
- 🟡 **Allow deletions** — ❌ **Disable** for `main`

## Tags & releases

- Tags matching `v*.*.*` trigger the [release workflow](.github/workflows/release.yml)
- Releases are created automatically by the release workflow with artifacts
- Only maintainers should push tags (no tag protection rule by default —
  rely on the release workflow's `permissions: contents: write`)

## Setting it up via `gh` CLI

```bash
gh api -X PUT repos/Exon101/sonic-cloud-flutter/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Analyze & Test", "Build Web", "Build Android APK"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

> Note: Branch protection requires a public repo or a paid GitHub plan. This
> repo is public, so the rules above are free.
