Configure GitHub repository settings and branch protection for this project. This is independent of local tooling setup — run it before or after `/setup-common`.

> **Note:** This command uses `gh repo edit` and `gh api` to modify remote GitHub settings. Each call will prompt for approval.

## What to configure

### 1. Detect current state

Before making changes, gather the current repository configuration:

- Run `gh repo view --json name,owner,defaultBranchRef,deleteBranchOnMerge,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed,isPrivate,hasWikiEnabled,hasProjectsEnabled` to get repo metadata
- Run `gh api repos/{owner}/{repo}/branches/{default_branch}/protection` to check existing branch protection (a 404 means none is configured)
- Check if `.github/workflows/` exists and list workflow files to detect CI

Display a summary table showing **current vs proposed** values before applying any changes.

### 2. Repository settings

Apply all settings in a single `gh repo edit` call:

```sh
gh repo edit \
  --delete-branch-on-merge \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --enable-auto-merge \
  --allow-update-branch \
  --enable-wiki=false \
  --enable-projects=false
```

If wiki or projects are currently enabled, note this in the summary but still disable them. Most hobby projects don't use these features.

### 3. Squash merge commit message format

Set the default squash merge commit message to use the PR title:

```sh
gh repo edit --squash-merge-commit-message pr-title
```

### 4. Secret scanning (public repos only)

If the repository is **public**, enable secret scanning and push protection:

```sh
gh repo edit --enable-secret-scanning --enable-secret-scanning-push-protection
```

If the repository is **private**, skip this step and note: "Secret scanning requires GitHub Advanced Security (paid) for private repos. Skipping."

### 5. Branch protection

Auto-detect CI status check names by reading workflow files in `.github/workflows/`. Look for jobs triggered by `pull_request` events and extract their `name:` values — these are the status check contexts GitHub uses.

Apply branch protection to the default branch using the GitHub API. The JSON payload should contain:

- `required_status_checks.strict`: `true` (branch must be up-to-date before merging)
- `required_status_checks.contexts`: array of detected CI check names, or `[]` if no CI workflows exist
- `required_pull_request_reviews`: `null` (solo developer — cannot require approvals from others)
- `enforce_admins`: `true` (critical — prevents admin-level tokens and coding agents from bypassing rules)
- `restrictions`: `null` (not applicable for personal repos)
- `required_linear_history`: `true` (complements squash-only strategy)
- `allow_force_pushes`: `false`
- `allow_deletions`: `false`

Use `gh api -X PUT repos/{owner}/{repo}/branches/{default_branch}/protection` with the payload. Do not use heredocs to pass the JSON — use `--input` with process substitution or write a temporary file.

If the repo has no CI workflows, the `contexts` array will be empty. This still prevents direct pushes to the default branch and enforces PRs, but won't require any specific checks to pass. Note this and suggest running `/setup-common` to add CI.

If branch protection already exists, show the current configuration alongside the proposed one so the user can see what will change. The PUT endpoint **replaces** the entire protection config — existing custom settings (like specific required reviewers or additional status checks) will be overwritten.

### 6. Default branch name check

If the default branch is `master` instead of `main`, **do not rename it automatically**. Renaming is disruptive (breaks CI, open PRs, local clones). Instead, display a warning with the manual steps:

```text
Warning: Default branch is 'master'. Consider renaming to 'main':
  git branch -m master main
  git push -u origin main
  gh api -X PATCH repos/{owner}/{repo} -f default_branch=main
  git push origin --delete master
```

### 7. Verify

After applying changes, verify the configuration took effect:

- Run `gh repo view --json deleteBranchOnMerge,squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` and confirm values match
- Run `gh api repos/{owner}/{repo}/branches/{default_branch}/protection` and confirm the protection rules are in place
- Display a final summary showing all applied settings

## Important

- This command modifies **remote GitHub settings**, not local files. It is safe to re-run (idempotent).
- Branch protection PUT replaces the entire config. If a repo has custom protection rules (e.g., required reviewers from a team), review the current config before overwriting.
- Some branch protection features require GitHub Pro on private repos. If the API returns a 403, explain this to the user.
- The `enforce_admins` setting is the most important for agent safety — without it, admin-level tokens bypass all other branch protection rules.
