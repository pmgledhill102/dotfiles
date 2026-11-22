Get GCP credentials for this session through the credential broker: request a human-approved grant, show the verification phrase the human must match, and install a short-lived token straight to disk. Use when a task needs GCP access and the session has none, or when a previously working grant has expired.

## When to use this

Reach for it when a GCP call fails for want of credentials, or before starting
work you already know needs them — `gcloud`, Terraform against a GCP provider,
a client library, anything that authenticates to Google Cloud.

Signals that this is the right move:

- `gcloud` reports no active account, or `ADC not found`
- an API call returns 401/403 and no grant is installed
  (`~/.claude/bin/gcp-credentials status` says `grant : none on this machine`)
- a grant that was working has expired — see [Grant expired](#grant-expired)

Do **not** request credentials speculatively. Every request pings a human on
Discord and burns a little of their willingness to read the card carefully. One
per session, when the work actually needs it.

Investigating something **outside** the sandbox — a cost, an IAM policy, a log,
a service in another project — is a different tier with its own grant: see
[Investigating across the estate](#investigating-across-the-estate---tier-readonly-estate).

## How it works, in one paragraph

The broker turns **one human approval into a grant** lasting 1–7 days (the
sandbox tier; the estate tier is shorter). Inside
that window a background loop silently re-mints 1-hour GCP access tokens with no
further approvals. The human approves in Discord only if the card shows the same
three-word phrase as the session — that match is what binds an approval to
*this* session rather than to whichever request happened to arrive first. Design
and trust model: ADR 021 in the private infrastructure repository.

If the repo has no sandbox project yet, the same approval **also creates one**,
so the card is authorising a project as well as the access — and says so, on
fixed terms the broker composes rather than the agent: today a £25/mo budget cap
and auto-deletion after 7 days, extendable to at most 30 (ADR 008, ADR 022).
Read the terms off the card rather than from here; the numbers live in that repo
and this is a copy.

That TTL is why a grant can come back shorter than asked for — see [The grant
may be shorter than you asked for](#the-grant-may-be-shorter-than-you-asked-for)
— and why an idle sandbox is **not** a cost that accumulates: it is deleted,
with the budget capping what it can spend before then. Do not treat a sandbox as
something to be tidied up.

The build takes two to three minutes, during which the helper reports
`provisioning` — see [Waiting on a human, then waiting on
GCP](#waiting-on-a-human-then-waiting-on-gcp). Design: ADR 022.

## Requesting

```sh
~/.claude/bin/gcp-credentials request --purpose "stand up an Apigee instance and its supporting infra"
```

The project is resolved from the repo's `origin` remote, so nothing needs
configuring per project. Override with `--project <id>` if the broker cannot
resolve it, or `--repo <remote>` when working outside a checkout.

### Never ask the user which project to use

**The flow supplies the project. You do not choose it, and you must not ask the
user to.** On success the helper prints it, `gcloud` is already pointed at it,
and `status` reports it at any time.

This matters because repo scripts often carry a default project ID in a
`shared/env.sh` or similar, and it is tempting to ask which one to target. Asking
is wrong twice over: it interrupts the human for something already decided, and
their answer can send the work to a project the grant does not cover — the token
is scoped to one project, so a "helpful" override just produces permission
errors that look like a broken grant.

If the repo has no sandbox yet, the broker does not fail: approving the card
**creates one**, and the project it creates is the one to use. Wait for the
helper to report it rather than filling the gap with a guess or a question.

So: read the project from the helper's output, pass it to whatever needs it, and
say which project you are working in. Ask the user only if the helper exits
non-zero and the table below says to.

Useful options: `--ttl 72h` (1–7 days, default 24h), `--timeout 900`,
`--no-gcloud` if you only want the token file.

### If a grant is already live, `request` refuses

`request` checks for an unexpired grant on disk before it opens anything, and
exits 2 rather than asking a human to approve access they have already approved:

```text
gcp-credentials: a live grant already exists for example-project-sbx, valid for
another 19h 40m (until 2026-08-16T11:33Z). ... Run 'gcp-credentials renew' to
mint a token now, or 'gcp-credentials refresh --background' if the refresh loop
has died; 'gcp-credentials status' shows which. Pass --force to request a new
approval anyway.
```

This is not an error to work around. Do what it says — `renew` and
`refresh --background` need no human and take one HTTP call. `--force` exists
for the case where the existing grant is genuinely the wrong one (wrong project,
wrong tier, too little time left for the work); spending an approval to get back
something you already hold is not that case.

Nothing was sent to the broker when you see this, so no approval was consumed.

Write a **specific purpose**. It is the only thing the human has to judge the
request by, and it is rendered on the card as untrusted, agent-written text.
"deploy the Apigee bootstrap module to the sandbox" is approvable;
"do some GCP work" is not.

### Surface the phrase immediately

The command prints a block like this:

```text
==================================================================
  APPROVAL REQUIRED — verification phrase:

        mint-copper-falcon

  Approve in Discord ONLY if the card shows exactly this phrase.
==================================================================
```

`request` returns as soon as it has the phrase. It does **not** wait for the
decision, and that is deliberate: relay the phrase in your own reply, then
collect the answer separately.

Relay it **verbatim, as the first line of the turn's final message** — not in
text written between tool calls, not buried in tool output, and not inside a
sentence. Put it on a line of its own, in a code block,
behind the capitalised label `VERIFICATION PHRASE:`. Then say what they are
approving:

````markdown
```text
VERIFICATION PHRASE: mint-copper-falcon
```

Requesting GCP credentials for `example-project-sbx` (sandbox tier, 24h).
Approve the Discord card only if it shows exactly that phrase.
````

**Where the phrase goes matters more than how it looks.** The Claude app
rewrites text sent between tool calls into a short third-person summary, and
that summary can drop the phrase entirely, code block and all. The turn's final
message is shown as written. So no formatting rescues a phrase written before a
tool call: it has to be in the last message. The code block and label then make
it stand out wherever it is shown as written.

### Then collect the decision

```sh
~/.claude/bin/gcp-credentials wait
```

This blocks until the human answers, then installs the token and starts refresh.

**Run it in the background, then end the turn with the phrase message.** Right
after `request`, start `wait` with the Bash tool's `run_in_background: true`,
writing no text before either call. Then write the phrase message as the turn's
final message, and end the turn. A backgrounded `wait` returns at once, so the
message still reaches the human straight away, and the harness re-invokes you
when `wait` exits, so you carry on the moment the card is answered with no
second prompt from the user. Do not poll, and do not wait with `sleep`.

**Never run `request --wait`, and never run `wait` in the foreground.**
`request --wait` exists for a human at an interactive terminal. A blocked
foreground command cannot produce a reply, so the phrase would sit unread in the
output of something still running while the human is asked to match it against
nothing. The phrase is only a session binding if it reaches the person *before*
they answer the card, so the order is fixed: `request`, then the backgrounded
`wait`, then the phrase as the turn's final message.

Read the result as in [Reading the outcome](#reading-the-outcome) when the
background command reports back.

If the session scrolls or you lose track, `status` reports the outstanding
request and its phrase.

### Waiting on a human, then waiting on GCP

`wait` distinguishes two waits, and it is worth relaying which one you are in.
Before the decision it reports waiting for approval — that is the one a nudge in
Discord can help with. After approval it may report:

```text
  approved — waiting for the agent identity to become usable (GCP propagation, usually under a minute)
```

Nothing is wrong there and nobody needs chasing. The broker refuses to hand over
a grant it cannot actually mint a token for, so it waits for the identity to
propagate rather than issuing something that would fail on first use. It
resolves on its own, without a second approval. Say so if asked, and wait.

When the repo had no sandbox, there is a longer wait first, while the project is
built:

```text
  approved — creating the sandbox project (this takes two to three minutes)
```

Also normal, also nobody to chase. **Do not fill the time by asking the user
which project to target** — that is what this wait is deciding. Tell them the
sandbox is being created and roughly how long it takes, and wait. If it never
appears the helper exits non-zero and the reason is posted to the operations
channel by the service that built it.

## Reading the outcome

| Exit | Meaning | What to do |
| --- | --- | --- |
| 0 | Installed | Carry on. Say which project and when the grant expires. |
| 2 | Usage error, **or a live grant already exists** | Fix the arguments. If it names a live grant, use `renew` / `refresh --background` instead — see [above](#if-a-grant-is-already-live-request-refuses). |
| 3 | **Denied** or revoked | Stop. A human said no. Do not re-request without asking them why. |
| 4 | **The card expired** — the broker closed it | Nobody answered, and the broker treats that as a deny. The card is dead, so nothing can land on it late. Ask the user before a fresh `request`. |
| 4 | **Timed out** — this helper stopped waiting first | Not a deny: nobody has answered *yet*, and the card may still be live. Tell the user it is waiting on them; `wait` collects a late approval. Do not open a second card. |
| 4 | **Timed out mid-provisioning** | Already approved; the sandbox is still being built server-side and nothing is lost. Run `wait` again, or a later `request` resolves the finished sandbox. Nothing to ask. |
| 4 | **Grant no longer active** (from `renew`, `refresh` or `wait`'s token exchange) | It expired or a human revoked it, and the broker does not say which. Ask the user before requesting again — if it was revoked, someone said no. |
| 5 | Rate limited | Wait. Do not loop. |
| 6 | Not configured | No request key or no broker URL — see [Setup](#setup-not-per-session). |
| 7 | Approved, but the identity never became usable | **Not a deny** — nobody refused. Report the reason the helper printed. Requesting again is legitimate; if it recurs, say so, because the sandbox's agent identity needs attention. |
| 8 | This helper is too old for the broker | Relay the remedy below and **stop**. Retrying cannot help — nothing is wrong with the request, the client simply cannot speak the current contract. Locally the fix is `chezmoi apply --refresh-externals`, **not** a plain `chezmoi apply`. |
| 1 | Broker unreachable or mint failed | Report it. Do not proceed as if credentials exist. |
| 1 | **HTTP 502 from something between this session and the broker** (no broker error in the response) | A path fault, not a broker fault: the broker may never have seen the request. Retry once after a minute rather than diagnosing the broker; if it persists, check the broker's request log for whether the call arrived. Only a 502 that says the *approval channel* is unavailable means the broker was reached and nobody was asked. |

Exit 7 is worth distinguishing from exit 3 in what you tell the user. A deny is a
decision and asking again without checking is rude; a failure is a fault, and
retrying is the reasonable response.

Exit 8 is neither. Nothing is wrong with the request and nobody decided
anything — this helper predates a change to the broker's contract and cannot
speak it. The broker refuses **before** posting a card, so no approval was spent
and none will be until the helper is updated. Relay the remedy and stop;
retrying is the one thing that certainly will not help.

The remedy differs by surface, and the local one is easy to get wrong:

| Surface | Remedy |
| --- | --- |
| Local machine | `chezmoi apply --refresh-externals` (or `chezmoi update --refresh-externals`) |
| Cloud sandbox | Bump `Rev:` in the environment's setup script, then start a fresh session |

**A plain `chezmoi apply` does not fetch a newer helper.** `~/.claude/` is
delivered as a chezmoi *archive external* with a `refreshPeriod` of 168h, so
inside that week-long window chezmoi reuses the cached archive and re-applies the
same stale helper — the exit-8 message repeats verbatim, from the one instruction
whose whole purpose was to end it. `--refresh-externals` is what forces the
re-download. The same caveat applies to `dotup` when the period has not elapsed.

If the hint the broker printed says plain `chezmoi apply`, prefer the command
above: the broker composes that string, and correcting it there is tracked
separately.

Never carry on without credentials after a non-zero exit. Silently falling back
to whatever identity happens to be lying around is the exact failure the broker
exists to prevent.

## After a successful request

Report only what the helper printed:

> Credentials installed for `example-project-sbx`, grant expires 2026-08-13T11:33Z.
> Background refresh is running.

`gcloud` is pointed at the token through a dedicated `agent-broker`
configuration, which is activated. `~/.claude/bin/gcp-credentials release`
restores the configuration that was active before.

### If the project was just created: early 403s are propagation

When the sandbox was built by this very approval, the helper says so and warns
that API enablement and IAM bindings are still propagating. **A 403 or 404 on
your first calls is propagation, not misconfiguration.** Wait ~60 seconds and
retry once before diagnosing anything — and do **not** modify IAM or org policy
to work around it. You hold `roles/owner`; "fixing" a propagation delay by
granting things is how a sandbox's permissions end up unrecognisable.

### The grant may be shorter than you asked for

A grant is clamped to the sandbox's own expiry — a 24h grant against a sandbox
that is deleted in 12h becomes a 12h grant, and the approval card said so. If
the helper reports a shorter expiry than requested, that is why; it is not an
error. A sandbox expiring within the hour is refused at request time with a
pointer at `/sandbox extend` — relay that to the user rather than retrying.

### Someone else may be working in the same project

Sandboxes are shared per repo. If the helper prints a `WARNING` about other
active grants — or `status` shows a `sharing :` line — another session holds a
live grant on the same project, under the same identity, at `roles/owner`.
Nothing prevents you overwriting each other's work. **Tell the user before any
destructive operation** (`terraform destroy`, deleting resources, rewriting
state): they may be running the other session themselves and know what it is
doing.

### `gcloud beta`, and an error that may only mean an old SDK

In a cloud sandbox, **`gcloud beta` and `gcloud alpha` work**, even though the
image ships without those components. The sandbox's `gcloud` wrapper sets
`CLOUDSDK_CORE_DISABLE_PROMPTS=1`, and with prompts disabled gcloud installs a
missing component itself and carries on. It does not wait on a confirmation
nobody can give. A missing component is not a reason to fall back to REST.

The image's SDK can be old, though (570 at the time of writing), and some
preview features need a newer one. The failure doesn't say "upgrade". Cloud Run
custom URLs (`--domain=<name>.cloud.run`) fail on 570 with *"The provided domain
does not appear to be verified for the current account"* and work on 590.0.1.
So when an error contradicts what you know about the account or project, check
`gcloud version` before you diagnose IAM or verification, then:

```sh
gcloud components update --quiet
```

This needs no approval and no grant. It updates the SDK in place for this
container only, and a rebuilt sandbox is back on the image's version. That is
deliberate: updating in every build would add time to most sessions to serve a
few (#678).

## Things never to do

- **Never print, `cat`, `grep`, `head` or otherwise read the token file.** The
  whole design rests on the credential not entering the transcript. The helper
  writes it from the HTTP response to disk without it passing through a shell
  variable; reading it back undoes that in one tool call.
- **Never run `gcloud auth print-access-token`** (or `print-identity-token`, or
  `terraform output` on anything holding a token). Same reason.
- **Never read `~/.config/gcloud`.** On a local machine that directory holds the
  human's own long-lived admin refresh token. It is not yours, it is not scoped,
  and it is not an hour long. If the broker path fails, the answer is to report
  the failure, not to reach around it.
- **Never ask the user to paste a token, key, or service-account JSON into the
  session.** Anything pasted is in the transcript forever. If credentials are
  needed, they come through the broker.
- **Never pass the request key on a command line.** The helper reads it from the
  environment or a 0600 file for a reason; `--key`-style arguments are visible in
  process listings.
- **Never pass the access token as a command-line argument.** Not
  `-H "Authorization: Bearer $(cat …)"`, not `--token`, not as any argv. This
  holds everywhere, on every surface — see below for why it is not the same as
  the environment-variable form it resembles.
- **Never re-request after a deny** without the user telling you to.

## Getting the token into a command without putting it in argv

The token has to reach the tool somehow. Two shapes are safe and one is not,
and the unsafe one looks exactly like the safe ones:

| Shape | Token lands in | Readable by |
| --- | --- | --- |
| `-H "Authorization: Bearer $(cat …)"` | **argv** | **every process on the machine, via `ps`** |
| `VAR="$(cat …)" cmd` | the environment | the owning user only |
| `curl --config <0600 file>` | a 0600 file | the owning user only |

`/proc/<pid>/cmdline` is world-readable; `/proc/<pid>/environ` is 0400,
owner-only. So the command-substitution idiom that makes all three look
equivalent — same `$(cat …)`, same "never echoed" property — is doing something
materially different in the first row.

This is the rule the helper already applies to itself: `write_header_cfg` sends
the request key through a `--config` file *precisely* to keep it out of argv.
The access token is the more valuable of the two secrets.

**Environment-variable form** — the default, and what to reach for first:

```sh
GOOGLE_OAUTH_ACCESS_TOKEN="$(cat ~/.config/claude/credential-broker/access_token)" terraform plan
```

**A raw REST call, which is what an agent reaches for `curl` to do** — read the
token inside a small script, so it never appears in any command line, including
`printf`'s. Do not build the header in the shell: a `printf` that expands the
token puts it in that process's argv just as `-H` does, and the credential guard
refuses the command for the same reason.

```python
# call.py -- run as: python3 -I call.py   (from a scratch directory)
import json, os, urllib.request

tok = open(os.path.expanduser("~/.config/claude/credential-broker/access_token")).read().strip()
url = "https://cloudresourcemanager.googleapis.com/v1/projects/example-project-sbx"
req = urllib.request.Request(url, headers={"Authorization": "Bearer " + tok})
print(json.dumps(json.load(urllib.request.urlopen(req)), indent=2))
```

A second header such as `x-goog-user-project` goes in the same `headers` dict.
`curl --config <0600 file>` also keeps the token out of argv, but the file has
to be written without the token passing through a command line, which in a shell
is the part that goes wrong; the script does not have that step.

Or, when the API accepts it, skip the header entirely and let `gcloud` carry the
auth — it is already pointed at the token file:

```sh
gcloud projects describe example-project-sbx --format=json
```

On a single-tenant ephemeral container the practical exposure from argv is
close to nil. On a local machine, where this helper is used identically and
other processes genuinely are running, it is not. **The rule does not vary by
surface** — partly because a session cannot always tell which one it is on, and
mostly because a habit that is conditional is not a habit.

## An authentication failure? Run `renew` first, then think

**Before diagnosing any GCP authentication error, run:**

```sh
~/.claude/bin/gcp-credentials renew
```

If it succeeds, the problem is solved and there was nothing to diagnose. It
costs one HTTP call, needs no human, and is a no-op you can afford to be wrong
about.

The reason is that the background refresh loop is **not reliable in a sandbox**.
Detached processes are reaped there — observed twice in one session, once across
an idle gap and once inside a twenty-minute window of active work. When that
happens the grant stays valid for days while the token quietly ages out, so the
first symptom is an authentication error that looks like a broker fault, an IAM
problem, or a revoked grant, and is none of them.

Applies to `Request had invalid authentication credentials`, a bare 401 or 403
from a Google API, and `Unable to read file [...access_token]`. The last one
means the token was *removed*, not rejected — a grant that ended, or a `release`
— and `renew` will tell you which by failing with an exit code that says so.

Escalate only if `renew` itself fails:

- exit 4 — the grant is genuinely over; request a new one
- exit 2 — no grant on this machine at all; request one
- exit 1 — the broker is unreachable, which is a real fault worth reporting

### `ACCESS_TOKEN_TYPE_UNSUPPORTED` — the one `renew` cannot fix

This error reads like a broker fault or an IAM problem and is neither. It means
**an environment variable is outranking the token file**, so gcloud never looks
at what the helper installed.

gcloud resolves every property in the order environment variable →
configuration → default. `CLOUDSDK_AUTH_ACCESS_TOKEN` is both higher precedence
*and* a different property (`auth/access_token`) than the
`auth/access_token_file` the helper sets, so a preset value wins over everything
the helper does — silently. It was preset in a sandbox image, and cost most of a
debugging session because every diagnostic said healthy.

`status` now says so directly:

```text
gcloud  : OVERRIDDEN by CLOUDSDK_AUTH_ACCESS_TOKEN — gcloud ignores the broker token; calls will fail
          unset it, or run gcloud through a wrapper that does. The grant is fine.
```

The variables that do this:

| Variable | Overrides |
| --- | --- |
| `CLOUDSDK_AUTH_ACCESS_TOKEN` | `auth/access_token_file` — the observed case |
| `CLOUDSDK_AUTH_ACCESS_TOKEN_FILE` | the same property the helper sets |
| `CLOUDSDK_CORE_PROJECT` | the project the helper sets — calls go elsewhere |
| `GOOGLE_APPLICATION_CREDENTIALS` | client libraries and Terraform, not gcloud |
| `GOOGLE_OAUTH_ACCESS_TOKEN` | client libraries and Terraform, not gcloud |

**The remedy is `unset`, not `renew` and not `request`.** The grant is valid and
the token file is correct; this is gcloud plumbing. `renew` will cheerfully
succeed and change nothing, and `request` spends a human approval on a problem
no approval can solve.

```sh
unset CLOUDSDK_AUTH_ACCESS_TOKEN
```

If the variable is preset by the environment image rather than by something in
the session, it will come back in the next session: say so, so it gets reported
to whoever owns the image. A general-purpose dev container presetting
`CLOUDSDK_AUTH_ACCESS_TOKEN` hijacks gcloud auth for anything that brings its
own credentials.

## After a container restart or a resumed session

**Check this before anything else in a resumed cloud session.** Sandboxes
restart container processes across an idle gap: the filesystem survives — your
installed tools, the token file, the log — but the background refresh loop does
not. Nothing restarts it, so the token ages out and dies while the grant is
still perfectly valid.

Symptoms, in the order you meet them:

- `gcloud` fails with `Request had invalid authentication credentials`
- `~/.claude/bin/gcp-credentials status` shows a live grant, `refresh : not
  running`, and a token flagged stale:

  ```text
  token   : present at ~/.config/claude/credential-broker/access_token (minted 2h 11m ago — STALE, past its 3600s lifetime)
            nothing has minted since, so the refresh loop is probably dead:
            'gcp-credentials refresh --background' mints now and restarts it
  ```

`status` derives that age from the token file's mtime, so it is reporting when a
token was last successfully minted — not merely that a file exists. A `STALE`
line is the answer on its own; there is no need to read the refresh log to
confirm it, and no reason to go looking at IAM.

The fix needs **no human approval** — the grant is what a human approved, and it
has not expired:

```sh
~/.claude/bin/gcp-credentials refresh --background
```

That mints a token immediately and resumes the loop.

**Do not run `request` for this.** It pings a human for an approval that is not
needed, spending the one genuinely scarce resource in this design to fix a local
process problem. Requesting again is for an expired *grant*, not a dead loop —
`status` tells you which you have.

`renew` mints once and exits, without touching the loop, when that is all you
want.

## Grant expired

The grant, not the token, is what runs out. Symptoms:

- `~/.claude/bin/gcp-credentials status` shows `token : none installed`, or a
  grant whose expiry is in the past
- `gcloud` fails with a missing-token-file error
- the refresh log ends with `grant expired; token removed`

That is the designed end of the window, not a fault. Request again — a fresh
approval, a fresh phrase — and tell the user that is what you are doing:

````markdown
```text
VERIFICATION PHRASE: willow-basalt-heron
```

The 24h grant expired, so I'm requesting a new one. Approve the Discord card
only if it shows exactly that phrase.
````

Do not diagnose it as an auth bug, and do not go looking for another credential.

## Investigating across the estate: `--tier readonly-estate`

A second, separate grant: **read-only across the whole organisation**, for
questions that cross project boundaries and change nothing. Design and the exact
role set: ADR 025 in the private infrastructure repository.

| It can read | It cannot |
| --- | --- |
| Project and resource metadata, IAM policies, logs, monitoring, service and scheduler config, billing, and the rows of the billing-export dataset | Change anything; read secret values; read bucket contents (Terraform state included); read BigQuery data outside billing export |

**When:** a budget alert (which project, what is costing the money), a failed
apply that turns on what an IAM policy actually says, a drift or scope finding,
what a function in another project logged. **Never for work** — every write
fails by construction, and the sandbox tier is where work happens.

```sh
~/.claude/bin/gcp-credentials request --tier readonly-estate --purpose "find which project is driving the services budget alert"
~/.claude/bin/gcp-credentials wait --tier readonly-estate
```

- **No `--project` or `--repo`.** The grant is not scoped to one, and the helper
  refuses both rather than let a request look narrower than it is.
- **Short:** 4h by default, `--ttl` from 1h to 24h.
- **Relay the scope with the phrase.** The card leads with the scope. Your
  reply keeps the phrase as its first line, as for any request, and makes the
  scope the first thing the prose says:

  ````markdown
  ```text
  VERIFICATION PHRASE: read-silver-heron
  ```

  Requesting **read-only access to the entire organisation** (readonly-estate
  tier, 4h). Approve the Discord card only if it shows exactly that phrase.
  ````

- **It sits alongside a sandbox grant.** Separate grant, token and refresh loop;
  a live sandbox grant does not block it and it does not replace one. `status`
  shows both. Commands without `--tier` act on the sandbox grant, except when
  the estate grant is the only one there.

**Using it.** The estate grant gets its own gcloud configuration,
`agent-broker-estate`, which is **not** activated, so the session's default
gcloud stays on its sandbox. Opt in per call:

```sh
CLOUDSDK_ACTIVE_CONFIG_NAME=agent-broker-estate gcloud projects list
CLOUDSDK_ACTIVE_CONFIG_NAME=agent-broker-estate gcloud logging read '...' --project <the project you are inspecting>
```

That configuration's default project is the estate identity's home project,
which is where API quota is billed and BigQuery runs jobs — **not** the scope of
the grant. Pass `--project` for whatever you are inspecting. The cloud sandbox's
gcloud wrapper renews the estate token on the same per-call basis as the
sandbox one, keyed on the configuration the call uses.

**Logs are the residual risk, so they get a rule.** The grant reads every
project's logs, production included, and an application can log things it
should not. Quote the minimum lines needed to explain a finding; **never paste
raw log output wholesale** into the transcript, a PR body, or an issue. A public
issue full of production log lines is an exfiltration path that needs no
attacker.

End it early, once the question is answered **and no further read is
planned**, with `~/.claude/bin/gcp-credentials revoke --tier readonly-estate`.
Exit codes are the same as for the sandbox tier. If you have already told the
user a follow-up read is coming within the grant's TTL (after a deploy, after a
CI run), keep the grant and revoke after that read: a fresh card for each step
spends the approval this skill rations. Size `--ttl` to cover the planned
follow-up when you request it, with margin, because a grant that expires just
before the read it was held for costs the same second approval. This covers
only a follow-up the session has already committed to; the default stays short
and revoked.

## Other subcommands

```sh
~/.claude/bin/gcp-credentials status    # grant, token, refresh, gcloud — no secrets
~/.claude/bin/gcp-credentials release   # drop the token locally, keep the grant
~/.claude/bin/gcp-credentials revoke    # end the grant at the broker as well
```

`status` and `release` are pre-approved in `settings.json`; `request`, `revoke`
and `teardown` prompt, because all three reach the broker and two of them ping a
human.

Run `release` when finishing a session on a shared/local machine, so the human's
gcloud configuration goes back to theirs. Run `revoke` when the access should
end outright — after finishing a piece of work early, or if anything about the
session looks wrong.

## Handing the sandbox back: `teardown`

`release` and `revoke` end **access**. Neither touches the project, and neither
should — see [How it works](#how-it-works-in-one-paragraph): a sandbox is the
*repo's*, it is capped and it deletes itself at its TTL, so an unattended one is
not a leak to be tidied away.

`teardown` is the other thing entirely — it destroys the sandbox project:

```sh
~/.claude/bin/gcp-credentials teardown
```

One human approval on a card naming the project, the repo and the count of live
grants on it. On approval the broker revokes **every** live grant on that
sandbox — including this session's own — and deletes the project. The command
blocks until the decision, then cleans up locally: refresh stopped, token file
and grant file removed, gcloud configuration restored.

The repo is resolved from `origin`, exactly as `request` does with no `--repo`,
and **the project cannot be named**. That is the control rather than an
omission: the broker answers a teardown carrying a project with a 400, so a
session can only ask about a sandbox its own checkout resolves to, and cannot
end up believing it targeted something it did not. `--timeout SECS` is the only
option (default 900).

### When to run it, which is rarely

**Only when the user has asked for it.** Wrong repo, an experiment abandoned, a
sandbox created by a request that should not have been made. Never as tidy-up at
the end of a session, never because a project "looks unused", and never on your
own initiative — someone else may hold a live grant on it right now, and the
card's grant count is the only place that shows up.

If the work merely finished, the answer is `release` (or nothing at all). The
sandbox expires by itself.

### The phrase, and why this one is different

The banner is identical to `request`'s and the human check is the same one. But
`teardown` blocks rather than splitting into `request`/`wait`, so **you cannot
relay the phrase before the human answers** — it reaches your reply only once
the command has returned with a decision.

That is deliberate: the approval revokes this session's own grant, so something
has to be still running to stop the refresh loop and remove the token. Say so
when you tell the user you are running it, and tell them what the card will show
(project, repo, grant count) so they have something to match against besides the
phrase. The standing rule carries the rest of the weight: **an approval card
nobody was expecting is denied.**

### Reading a teardown's outcome

| Exit | Meaning | What to do |
| --- | --- | --- |
| 0 | Torn down, **or** nothing to tear down | Read the output — the second case says so plainly and changed nothing. |
| 2 | Usage error, or the broker refused the request shape (HTTP 400) | A 400 here is this helper and the broker disagreeing about the contract. Report it; retrying sends the same bytes. |
| 3 | **Denied** | Stop. The sandbox and every grant on it are untouched. |
| 4 | **The card expired** — the broker closed it | Nothing was destroyed and nothing changed locally, and the broker treats the silence as a deny. The card is dead, so nothing can land on it late and there is nothing to keep watching. A fresh `teardown` opens a new card. |
| 4 | **Timed out** — this helper stopped waiting first | Nothing was destroyed and nothing changed locally — but the card may still be live, so a late approval would tear it down with nothing watching. Tell the user. |
| 5 | Rate limited | Wait. Teardown shares the credential-request budget. |
| 8 | Helper too old | Same remedy as [above](#reading-the-outcome). |
| 1 | Broker unreachable, or more than one sandbox matched | Report it. Nothing was destroyed. |

After a successful teardown there is no grant and no token: `renew` has nothing
to mint from and `status` reports none. That is the expected end state, not a
fault. If work continues in that repo it needs a fresh `request`, which will
create a new sandbox.

## Setup (not per session)

Two things are machine or environment properties, configured once, never pasted
into a session:

| What | Cloud sandbox | Local macOS |
| --- | --- | --- |
| Request key | an environment **API credential**, with `$CREDENTIAL_BROKER_REQUEST_KEY=proxy-injected`; or the key itself in that variable | `~/.config/claude/credential-broker/request-key`, mode 0600 |
| Broker URL | `$CREDENTIAL_BROKER_URL` | `~/.config/claude/credential-broker/url` |

**`proxy-injected` is a mode switch, not a key.** It means the environment's
agent proxy attaches `X-Request-Key` to broker requests after they leave the
VM, so the key is never in the container. The helper then sends no key of its
own, and `status` shows `key : proxy-supplied`. In this mode, a 401 on
`request` means the environment's credential is wrong or missing. That's a
setup task for the human, like exit 6: report it, and never go looking for the
key.

Exit 6 names both locations. If a machine is missing them, that is a setup task
for the human — say so and stop; do not attempt to work around it.

### Cloud sandboxes also need the broker on the network allowlist

A cloud sandbox reaches only allowlisted domains. The **Trusted** default list
covers `*.googleapis.com`, so GCP API calls work once a token is installed — but
it does **not** cover the broker's own host, which is a `*.run.app` address. Add
it under **Custom** network access, with the default list still included:

```text
credential-broker-<hash>-nw.a.run.app
```

Without it the request fails at the network layer, which reads as the broker
being down rather than as an environment that was never allowed to call it.

The cloud bootstrap installs `gcloud` by default on `*-cloud-sandbox` profiles
(`--with-gcloud`). In an environment built with `--no-gcloud`, or one not built
by the bootstrap, it is absent. Then, if a task needs it, `dl.google.com` — the
SDK download host — also has to be allowlisted;
neither `cloud.google.com` nor `gcloud.google.com`, both of which are on the
default list, serve the tarball. Install it from the **environment's setup
script** rather than mid-session, because `gcp-credentials request` only wires
up a gcloud configuration if gcloud exists at the moment it runs. Installed
afterwards, gcloud is left pointing at nothing and the fix costs a second human
approval.

## Approval hygiene, for the human

Worth restating when relaying a phrase, because it is the only real defence:

- Approve **only** if the card's phrase matches the session's, character for
  character.
- A card arriving with no session running is grounds to deny, always.
- The purpose text on the card is written by an agent and is marked untrusted.
  Project, identity, tier and duration are composed by the broker and can be
  relied on.
