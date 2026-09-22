# Promotion Techniques

Patterns observed in the most-downloaded crates.io and rubygems.org projects and in sorah's own READMEs. Each technique lists when it applies. Use only claims the repository or the user can back.

## Taglines

### Formulas

| Formula | Example |
|---|---|
| Adjectives + category + ecosystem | "Simple, efficient background jobs for Ruby." (sidekiq) |
| Adjectives + category | "An ergonomic, batteries-included HTTP Client for Rust." (reqwest) |
| Category + differentiator | "SQLx is an async, pure Rust SQL crate featuring compile-time checked queries without a DSL." |
| Anchor to known tool | "A *cat(1)* clone with syntax highlighting and Git integration." (bat) |
| Anchor to known tool | "zoxide is a smarter cd command, inspired by z and autojump." |
| Replacement statement | "It is a simple, fast and user-friendly alternative to `find`." (fd) |
| Imperative mechanism + benefit | "Record your test suite's HTTP interactions and replay them during future test runs for fast, deterministic, accurate tests." (vcr) |
| Pain-first | "Nokogiri makes it easy and painless to work with XML and HTML from Ruby." |
| Goal-first | "Capybara helps you test web applications by simulating how a real user would interact with your app." |
| Pitch in H1 | "# Kamal: Deploy web apps anywhere" |
| Yet another, with reason | "# Needroleshere - Yet Another AWS IAM Roles Anywhere helper", then "works well as a drop-in replacement of the official ... with some advantages including:" |
| Deployment context | "Backend renderer used at https://diary.sorah.jp/ and https://blog.sorah.jp/" (kozeki) |

Humor works only when the domain is trivial: "It's base64. What more could anyone want?"

### Second paragraph

State the mechanism or differentiator in one or two sentences:
- sidekiq: "uses threads to handle many jobs at the same time in the same process"
- rayon: "makes it easy to convert a sequential computation into a parallel one. It also guarantees data-race freedom."
- faraday: positions itself relative to a known concept, "embraces the concept of Rack middleware"

### Checklist-style lead (ankane style)

```markdown
# Strong Migrations

Catch unsafe migrations in development

&nbsp;&nbsp;✓&nbsp;&nbsp;Detects potentially dangerous operations<br />
&nbsp;&nbsp;✓&nbsp;&nbsp;Prevents them from running by default<br />
&nbsp;&nbsp;✓&nbsp;&nbsp;Provides instructions on safer ways to do what you want

Supports PostgreSQL, MySQL, and MariaDB
```

Suits tools with a crisp 3-point value. Prefer a plain bullet list in sorah's style.

## Feature Lists

Triad of properties with bold labels (tokio, puma, starship):

```markdown
* **Fast**: Tokio's zero-cost abstractions give you bare-metal performance.
* **Reliable**: Tokio leverages Rust's ownership, type system, and concurrency model to reduce bugs and ensure thread safety.
* **Scalable**: Tokio has a minimal footprint, and handles backpressure and cancellation naturally.
```

Suits product-grade frameworks and apps. For most projects prefer a plain capability list (sorah style, mairu "Key features", acmesmith "Features"): one line per capability, link to the section that details it.

Before/after examples make features tangible (searchkick: "misspellings - `zuchini` matches `zucchini`").

## Comparisons

The most credibility-building section. Be specific and fair.

- Per-alternative subsections: mairu `## Comparison with other products and solutions` / `### vs. aws-vault` / `### vs. Weep`
- Structured diff: subsystemctl `## Difference with arkane-systems/genie` split into Interface / Behavior / Internal bullets
- Concede the alternative's niche: vault2kube "vault-k8s would be a good choice when you cannot trust k8s secrets store..."
- Mutual redirection between sibling projects: anyhow/thiserror "Use Anyhow if you don't care what error type your functions return ... Use thiserror if you are a library"
- Redirect misfits: hyper "If you are looking for a convenient HTTP client, then you may wish to consider reqwest"; sqlx "SQLx is not an ORM!"
- Credit: `## Prior Art`, "heavily inspired by X"

### Why / Why not

ripgrep's three sections are the model:
- "Why should I use ripgrep?"
- "Why shouldn't I use ripgrep?" ("You need a portable and ubiquitous tool ... The best tool for this job is good old grep.")
- "Is it really faster than everything else?"

Also: bootsnap "When not to use Bootsnap"; strong_migrations "You probably don't need this gem for smaller projects"; himari "this app may not be for you".

### Bad/Good format

For linters and safety tools, show each problem as `#### Bad` / `#### Good` code pairs (strong_migrations). Shows value without claiming it.

## Benchmarks

Present only real measurements. Required context:
- Workload and corpus ("Linting the CPython codebase from scratch", "the Linux kernel")
- Hardware
- Reproduction script or link
- A caveat

ripgrep table shape:

```markdown
| Tool | Command | Line count | Time |
| ---- | ------- | ---------- | ---- |
| ripgrep | `rg -n -w '[A-Z]+_SUSPEND'` | 536 | **0.082s** (1.00x) |
| GNU grep | `grep -r -n -w '[A-Z]+_SUSPEND'` | 536 | 0.422s (5.15x) |
```

fd pastes raw `hyperfine` output, then summarizes and qualifies: "**Note**: This is *one particular* benchmark on *one particular* machine ... See [this repository] for all necessary scripts."

sidekiq keeps a version-over-version throughput table with honest caveats ("Real world applications will rarely if ever need to use concurrency greater than 10").

Real-world outcomes also count: bootsnap "Discourse reports a boot time reduction of approximately 50%".

uv/ruff place a benchmark bar chart as the hero image with an italic caption naming the workload, using `<picture>` for dark/light variants.

## Visuals

- CLI/TUI: screenshot right after the intro, or an animated SVG (`svg-term`, asciinema) as `![Demo](doc/screencast.svg)`. bat places one screenshot per feature heading.
- Web UI: screenshot plus live demo link (pghero "See it in action").
- Services: architecture diagram under `## How it works` (nginx_omniauth_adapter). Mermaid renders on GitHub.
- Dark mode logo/chart:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo-dark.svg">
  <img alt="Project" src="docs/logo-light.svg">
</picture>
```

Always write meaningful alt text.

## Social Proof

Only with user confirmation:
- "used in major open-source projects like: Apache Airflow, FastAPI, ..." (ruff)
- ":tangerine: Battle-tested at [Instacart]" (ankane gems)
- "default server for Ruby on Rails" (puma)
- "Built with X" showcase section (ratatui, nom "Parsers written with nom")
- Named testimonials (ruff) for product-grade projects only

## Stability and Support Statements

- Requirements: sidekiq "Redis 7.0+ ... Ruby: MRI 3.2+ or JRuby 9.4+"
- Support policy: faraday "we support Ruby 3.0+ ... If something doesn't work on one of these Ruby versions, it's a bug."
- Version support table (rack):

```markdown
| Version | Support |
|---------|---------|
| 3.2.x | Bug fixes and security patches. |
| 3.1.x | Security patches only. |
| <= 3.0.x | End of support. |
```

- Release/LTS policy (tokio: Release schedule, Bug patching policy, LTS releases with end dates)
- Maturity: bevy `## WARNING` about breaking changes every ~3 months; uv FAQ "Is uv ready for production?"
- Safety: axum "This crate uses `#![forbid(unsafe_code)]`"
- Compatibility matrix with footnotes (needroleshere, `:white_check_mark:` cells)

## Navigation and Docs Hubs

For projects with external docs, a nav row under the header:

```markdown
[Website](https://tokio.rs) | [Guides](https://tokio.rs/tokio/tutorial) | [API Docs](https://docs.rs/tokio/latest/tokio) | [Chat](https://discord.gg/tokio)
```

Or a "You may be looking for:" list (serde), or `## Documentation` link list (himari, ayane).

## Getting Help and Community

- Where to ask, and where not to: capybara "Ask on the discussions (please do not open an issue)"; sidekiq "Do not directly email any Sidekiq committers with questions or problems."
- Security contact: `### Reporting security issues` pointing to `SECURITY.md` or an address.
- Nokogiri's support hierarchy: Reading / Ask For Help / Report A Bug / Security and Vulnerability Reporting / Semantic Versioning Policy.

## Funding and Commercial Editions

- Placed after the technical content, never above the pitch.
- sidekiq: "I also sell Sidekiq Pro and Sidekiq Enterprise, extensions to Sidekiq which provide more features, a commercial-friendly license and allow you to support high quality open source development all at the same time."
- buf reassures: "The BSR is not required to use `buf`."
- Personal projects: a `## Sponsor` section or a single donation button (envchain, acmesmith).
