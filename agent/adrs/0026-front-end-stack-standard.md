# ADR-0026: One front-end stack per kind of project

- **Status**: Accepted (2026-11-21)
- **Date**: 2026-11-21
- **Tags**: front-end, languages, standards
- **Scope**: user (applies to all personal repos and agent surfaces)

## Context

Nothing said which front-end stack a new project should use, so every new
project was free to choose, and an agent starting one had no default to reach
for.

What the estate did on 2026-11-21, described without naming repositories:

- **Two web apps** serve static HTML, CSS and hand-written JavaScript from a Go
  binary, with the assets embedded. Neither uses a framework. The only bundling
  is one small esbuild step for a TypeScript module. One of the two is mostly
  plain JavaScript.
- **One native app** has SwiftUI clients for iOS and the Mac and a Jetpack
  Compose client for Android. Each is a thin layer over a UI-free core. It is
  the only project with a written style guide and UI principles.

So the web side was already consistent in practice, and unwritten. Content
sites had no stated choice at all.

The backend default is settled separately and is context here: Go, standard
library first. That shapes the front end. Whatever runs in the browser is
served by a Go binary, so a stack that brings its own server is a second
backend.

Most of this code is written by an agent and read by the owner. That makes two
things matter more than they would for a team of people: the result should
read the same way from one project to the next, and as many mistakes as
possible should be caught by a check the agent can run.

## Decision

### 1. Four layers, one standard each

| Layer | When | Standard |
| --- | --- | --- |
| **Content site** | Pages written ahead of time, no server logic | Hugo |
| **Web app** | A Go service with pages and some behaviour | Go-served HTML with TypeScript modules, bundled by esbuild and embedded in the Go binary |
| **Highly interactive app** | A screen that is mostly client state: an editor, a live multi-user view | React with TypeScript, built with Vite, served by the Go binary as a static bundle |
| **Native** | iOS, Mac, Android | SwiftUI and Jetpack Compose, each a thin layer over a UI-free core, with a parity matrix |

A project uses the lowest layer that fits its case.

### 2. TypeScript wherever JavaScript would otherwise be written

This holds in all three web layers, including the small scripts on a Hugo
site. The owner's reason: an agent does the heavy lifting, and typed code
reads more consistently. Type-checking is also a check an agent can run.

### 3. React is the one choice for the top layer

There is no per-project framework decision. When a screen needs the top layer,
it is React.

- **Not Next.js.** The backend is Go, so React ships as a static bundle and
  talks to the Go service.
- **Not React Native.** Native is SwiftUI and Compose.

### 4. htmx is ruled out for now

There is no trial. The two existing web apps already work the plain-TypeScript
way, and a fourth approach is one more thing to choose between.

### 5. A higher layer than the case needs takes a written reason

A repo may use a higher layer than its case needs only with the reason
recorded in its own ADR, naming this one, per
[ADR-0015](0015-tiered-adrs.md)'s rule that a repo deviates from a user-tier
decision explicitly. The same holds for any stack not in the table.

### 6. A cross-project style guide lives here

[`docs/style-guide.md`](../docs/style-guide.md) holds what is true of every
project's interface, whichever layer it is built in. Project-specific look
stays in the project.

## Alternatives considered

- **Angular, Vue or Svelte for the top layer.** Each would work. One choice
  was wanted so that no project has to make it, and React is the one taken.
- **htmx for web apps** (server-sent HTML fragments, almost no client code).
  It would remove most client code from a tool that is mostly forms and
  tables. Ruled out for now, for the reason in section 4.
- **A component framework for every web app.** A small tool would pay the full
  cost: a second ecosystem, a dev server, and dozens of dependencies to keep
  current. Kept for the top layer only.
- **Plain JavaScript where a script is small.** Rejected by section 2. The
  cost is a build step on pages that had none.
- **No standard, chosen per project.** This was the position before, and the
  reason for this ADR.

## Consequences

### Positive

- A new project starts with its stack already chosen, by which layer it is.
- The web layers share one language and one type-checker, so an agent's work
  reads the same across projects.
- The lower two web layers keep a small dependency surface.
- Every layer ships the same way: static files, served by or alongside a Go
  binary.

### Negative / trade-offs

- Which layer a project belongs to is a judgement. The line between "some
  behaviour" and "mostly client state" is where it will be argued.
- The top layer brings Node, a package manager and a steady stream of
  dependency updates into any repo that uses it.
- Existing hand-written JavaScript no longer matches the standard. This ADR
  does not schedule its conversion; it applies to new code, and to old code
  when it is next reworked.
- Hugo sites need a TypeScript build step for even a small script.

### What this does not decide

- The order of preference among backend and scripting languages. That question
  is still open in
  [#772](https://github.com/pmgledhill102/agentic-coding-config/issues/772).
- State management, routing, component libraries or test tooling within the
  React layer. The first project to need them decides, in its own ADR.
- The look of any one project.

## Revisit triggers

- The top layer is needed in more than one project and React is being fought
  against in each.
- A Hugo site grows server logic. It has become a web app and moves up a
  layer; if that keeps happening, the content-site layer is drawn in the wrong
  place.
- A web app accumulates enough hand-rolled client state that it is a
  framework in all but name. The line between the middle two layers needs
  restating.
- A tool that is mostly forms and tables turns out to cost far more client
  code than its behaviour justifies. That is the case htmx was set aside for,
  and the point to reopen section 4.
- Repos record deviations under section 5 often enough that the exception is
  the norm.

## References

- [#772](https://github.com/pmgledhill102/agentic-coding-config/issues/772):
  the options and the owner's decision, in its comments
- [#785](https://github.com/pmgledhill102/agentic-coding-config/issues/785):
  the review this decision came out of
- [ADR-0015](0015-tiered-adrs.md): why this is a user-tier decision, and how a
  repo deviates from it
- [`docs/style-guide.md`](../docs/style-guide.md): the cross-project style
  guide
