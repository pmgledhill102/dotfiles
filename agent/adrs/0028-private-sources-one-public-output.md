# ADR-0028: Private sources, one publish-only public repository

- **Status**: Accepted (2026-11-22, ratified via PR #824)
- **Date**: 2026-11-22
- **Amended**: 2026-11-22, `paul-context` added to the known-names allowlist
  (section 4), [#839](https://github.com/pmgledhill102/agentic-coding-config/issues/839)
- **Amended**: 2026-11-28, the public repository runs the install matrix on a
  `candidate` branch and `main` moves only when it passes (section 2),
  [#869](https://github.com/pmgledhill102/agentic-coding-config/issues/869)
- **Tags**: privacy, github, publishing, dotfiles
- **Scope**: user (applies to all personal repos and agent surfaces)
- **Supersedes**: the "Deferred: paired public and private repositories"
  section of [ADR-0022](0022-public-artefact-content.md)
- **Issue**: [#823](https://github.com/pmgledhill102/agentic-coding-config/issues/823)

The owner's private decision record holds what this ADR cannot: the cases
that triggered it, the private names, the machines and their tidy, and the
full consumer list. This ADR is the public, agent-binding half.

## Context

Two of the estate's repositories are public because something has to be
fetched without credentials:

- **dotfiles**: a fresh machine installs with a single `curl` of
  `install.sh`, before any credential exists, and `chezmoi init` clones the
  repo anonymously
  ([dotfiles ADR-0014](https://github.com/pmgledhill102/dotfiles/blob/main/docs/adrs/0014-public-repo-no-private-references.md)).
- **agentic-coding-config**: dotfiles mounts its `home/` at `~/.claude/`
  through a chezmoi `archive` external, and every cloud sandbox's setup script
  fetches `cloud/bootstrap.sh`, which then fetches `home/`, `profiles/` and
  `cloud/` files raw.

Work happens in those same repositories, so their issues, pull requests,
commit messages and history are public too. The rule for what may be written
there (ADR-0022's table, and dotfiles ADR-0014) is applied by the writer at
the moment of writing. It has failed repeatedly:

- dotfiles ADR-0014 records two earlier cases. Its conclusion was that
  "guidance alone had already failed to prevent it", and its answer was an
  allowlist check on committed files (`scripts/check-no-private-repos.sh`).
- That check cannot see issue or pull request bodies. A later case reached a
  public issue body, through a route ADR-0022's table already covers.

ADR-0022 weighed this ADR's model and deferred it with a revisit trigger:
"operational evidence reaches a public artefact again after this ADR is in
force, through a route the table already covers." That trigger has fired.

## Decision

### 1. Work happens only in private repositories

`agentic-coding-config` and the dotfiles source become private. Issues, pull
requests, reviews, history and CI all stay there, behind authentication. The
dotfiles source is renamed to `dotfiles-private` first (section 5), so that
the public name is free.

**A private source is named `<public-repo>-private`**, hyphenated like the
estate's `-infra` pairs. The name is derivable from the public repository's,
so writing it down discloses nothing beyond what this ADR already says: that
a private source exists.

### 2. One public repository, which nobody works in

A new public repository, `pmgledhill102/dotfiles`, holds only published
content:

- Issues, pull requests, discussions, wiki and projects are disabled.
- A ruleset on `main` allows pushes from the publish identity only: no human
  or agent pushes, and no force-push.
- Its only CI is the install matrix, which `dotfiles-private` publishes as
  the public `.github/` (its repo-tier
  [ADR-0023](https://github.com/pmgledhill102/dotfiles-private/blob/main/docs/adrs/0023-public-repo-tests-a-candidate-branch.md)).
  The dotfiles source publishes to a `candidate` branch; the matrix runs
  there, and `main` moves, by fast-forward, only when it passes.
  Everything is still gated before it is published; the matrix tests what
  was published, which is what machines fetch.

Promotion pushes as the publish App, because the ruleset on `main` admits no
other identity and the default Actions token cannot be exempted from a
ruleset. So the App's ID and key also live in the public repository, as
secrets in an environment named `promote` whose deployment branches are
restricted to `candidate`. That is acceptable because only the App can write
any branch, `candidate` included, and the repository takes no pull requests:
the only workflow that can reach the key is one a source published through
its gates. Nothing is force-pushed, and the rulesets are unchanged: a
candidate that was never promoted is superseded by a commit whose first
parent is `main` and whose second is the old candidate.

The agent-config source still publishes `agent/` straight to `main`, without
the matrix: it changes nothing outside `agent/`, so never the public
`.github/`.

Reusing the name `dotfiles` keeps the install URL and the `chezmoi init` URL
unchanged.

### 3. Layout of the public repository

| Path | From | Used by |
| --- | --- | --- |
| `install.sh`, `.chezmoiroot`, `home/`, and the docs dotfiles chooses to publish | dotfiles source | `curl` install, `chezmoi init` |
| `agent/home/` | agentic-coding-config `home/` | the `~/.claude` archive external, the cloud bootstrap |
| `agent/profiles/` | agentic-coding-config `profiles/` | the WSL `CLAUDE.md` external, the cloud bootstrap |
| `agent/cloud/` | agentic-coding-config `cloud/` | cloud sandbox setup scripts |
| `agent/adrs/` | agentic-coding-config `adrs/` | user-tier ADRs, readable from a sandbox with no clone |

The `~/.claude` mount stays an `archive` external, now pointing at the public
repository's own archive with `include = ["dotfiles-main/agent/home/**"]` and
`stripComponents = 3`. The personal-only gate, the WSL `CLAUDE.md` swap and
the retired-paths prune keep working as they are. Folding the payload into the
chezmoi source as `home/dot_claude/` is not part of this decision: chezmoi
would then interpret every agent-config file name (`run_*`, `private_*`,
`dot_*`, `.tmpl`), and pruning retired files would change with it.

### 4. A publish job in each source, with fail-closed gates

Each private source has a publish workflow that runs on every push to its
`main`:

1. Build its subtree from a **path allowlist**. A new file is published only
   once its path is added to the list.
2. Run the gates over the built tree. Any failure publishes nothing:
   - **Repository names**: every `pmgledhill102/<name>` reference must be on
     the **known-names allowlist**. That list holds the public repositories,
     plus the private repositories whose names are already public: the two
     sources (`agentic-coding-config`, `dotfiles-private`), and
     `paul-context`, the private context repository that the retrospective,
     journal and session skills read from and write to. Those skills cannot
     work without its name, so the owner has ruled the name already public
     (#839). No other private name joins the list without the same ruling,
     recorded here. This extends dotfiles' `check-no-private-repos.sh` to the
     published tree.
   - **Links**: a link may point only at a repository on the known-names
     allowlist. Links between published files are rewritten to their public
     paths. Links into a source's unpublished files, such as
     agentic-coding-config's `docs/`, its issues and its PRs, are kept as they
     are. They resolve only for an authenticated reader, which is the intent.
   - **Issue numbers**: a source's own issue and PR numbers are allowed, with
     their subjects. The issues are private, so a number gives an anonymous
     reader nothing to follow. Numbers from any other private repository fail
     the repository-names gate when they are written `<name>#N`.
   - **Secrets**: gitleaks over the built tree.
3. Fetch the public `main`, replace only this source's subtree, and commit
   with a generated message (`Publish agent config`, `Publish dotfiles`) as
   the publish identity. Source commit messages and history are never
   published. The public SHA is recorded in the private job log, which is the
   only map from public commits back to their sources.
4. Push. On a non-fast-forward rejection, because the other source published
   first, refetch and retry from step 3. Each source owns its own subtree, so a
   retry never conflicts.

The publish identity is a **GitHub App** installed on the public repository
only, with `contents: write`. Each private source stores the App's ID and
private key as secrets, and mints a short-lived installation token per run.
Nothing long-lived can push to the public repository.

### 5. Migration order

Every step before cutover keeps today's consumers working:

1. **Build and rehearse.** Add the publish jobs and gates to both sources,
   publishing to a temporary public repository. Rehearse there: a
   `chezmoi init` from it, an `apply` with the archive external, and a cloud
   sandbox bootstrap.
2. **Prepare the repoint.** In one pull request per source, move every
   consumer to its final public path: the archive external's URL and
   `include`, dotfiles CI's fetch of `home/standards/tools.json`, the cloud
   bootstrap's `git ls-remote` and raw base URL, the documented setup-script
   `curl` in `cloud/README.md`, the estate audit's fallback fetch of
   `home/standards/github-repo.json`, and links in Markdown that point at
   `agentic-coding-config/blob/...`. Merge them at cutover.
3. **Cutover**, in one sitting, because the gap is a window where anonymous
   installs fail:
   1. Rename `dotfiles` to `dotfiles-private`. GitHub then redirects the old
      name to it.
   2. Make it private, and make agentic-coding-config private.
   3. Create the public `dotfiles`, apply section 2's settings, and run both
      publish jobs. Creating a repository under the old name ends GitHub's
      redirect, so the install URL now resolves to the public output.
   4. Merge the repoint pull requests, and let the publish jobs run again.
   5. Update each cloud environment's setup script to fetch
      `dotfiles/main/agent/cloud/bootstrap.sh`.
   6. Verify: the `curl` install on a clean user account, a cloud session's
      bootstrap, and `chezmoi apply --refresh-externals` on one machine.
4. **Tidy each persistent machine** with a one-off script, POSIX `sh` for
   macOS and PowerShell for Windows. A machine's chezmoi source clone still
   tracks the old repository's history, which the new public repository does
   not share, so the script moves `~/.local/share/chezmoi` aside, runs
   `chezmoi init` from the public URL, and runs
   `chezmoi apply --refresh-externals`. Machines treated as ephemeral are
   rebuilt instead.
5. **Retire the temporary repository** used in step 1.

### 6. What changes in the policy text

- The ADR tiers rule says user-tier ADRs are public at
  `agentic-coding-config/adrs/`. That becomes the published copy under
  `dotfiles/agent/adrs/`.
- ADR-0022's table still governs what a **published file** may say. Its rows
  for public issues, pull requests and commit messages no longer apply,
  because no public repository accepts them.
- The cross-repo route ("file a detailed issue in the target repo") is
  unchanged. Both targets are now private.
- dotfiles ADR-0014 is superseded in the dotfiles source, which keeps its
  check as one of section 4's gates.

## Alternatives considered

- **Keep ADR-0022's writer-applied rule and add checks to it.** No check can
  run on an issue or pull request body before it is posted, which is where
  the latest case reached. Rejected.
- **Two public mirrors, one per source.** This keeps today's URLs, but
  doubles the public surface and the publish settings for no gain. The
  archive external already reads a subtree of one repository. Rejected.
- **Merge the two private sources into one.** It could be done later, but it
  is not needed to close the leak, and it would double the migration.
  Deferred.
- **Fold the agent config into the chezmoi source (`home/dot_claude/`).** See
  section 3. Deferred.
- **Publish the sources' history, filtered.** A history filter has to be
  right for every past commit, and commit messages are where evidence most
  often lands. Rejected: the public repository's history is publish commits
  only.

## Consequences

### Positive

- No agent or human writes directly to a public repository, so a
  writer-applied rule is no longer the only defence. A slip reaches a private
  tracker.
- Making agentic-coding-config private also withdraws its existing issues
  and edit histories from public view. Copies already cached or forked
  elsewhere remain.
- The install URL and every consumer's behaviour stay the same after
  cutover. Only their paths change.

### Negative / trade-offs

- The publish job has to be correct every time. A gate that is wrong in the
  permissive direction publishes what it should have stopped, so each gate
  needs a negative-control test that must fail.
- `docs/` is not published. The policy text's rationale links into it work
  only for an authenticated reader, so a sandbox session that wants a
  rationale page attaches agentic-coding-config first.
- A change reaches machines one publish later than it does today, and a
  failed gate holds every later change back until it is fixed.
- Published commits carry no source rationale. Anyone reading the public
  repository sees what changed, not why.

## Resolved questions

Settled by the owner on 2026-11-22, before acceptance:

1. **`docs/` is not published.** Its rationale stays private, and links to it
   keep working for authenticated readers (section 4, links).
2. **A source's own issue numbers are allowed.** The issues are private, so a
   number leaks nothing an anonymous reader can follow (section 4, issue
   numbers).
3. **The publish identity is a GitHub App** (section 4). Whether Apps become
   the standard identity for all estate automation that writes across repos
   is a separate decision, tracked as a follow-up.
4. **The renamed dotfiles source is `dotfiles-private`**, under the
   `<public-repo>-private` convention (section 1).

## Follow-up work (filed when this ADR is accepted)

- Publish workflow and gates in agentic-coding-config, with negative
  controls.
- Publish workflow and gates in the dotfiles source, with an issue filed
  there.
- Repoint pull requests (section 5, step 2), one per source.
- Machine tidy scripts (section 5, step 4).
- Policy-text updates (section 6), through the context fragments.
- A decision on GitHub Apps as the standard automation identity across the
  estate, replacing long-lived tokens.

## References

- [ADR-0015](0015-tiered-adrs.md): ADR tiers, and where user-tier ADRs are
  read from.
- [ADR-0022](0022-public-artefact-content.md): what each public artefact may
  say. This ADR supersedes its deferred section.
- [dotfiles ADR-0014](https://github.com/pmgledhill102/dotfiles/blob/main/docs/adrs/0014-public-repo-no-private-references.md):
  dotfiles is public by necessity, and has no private references.
