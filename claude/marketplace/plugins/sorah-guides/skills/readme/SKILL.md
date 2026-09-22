---
name: readme
description: This skill should be used when the user asks to "write a README", "create a README", "improve the README", "polish the README", "rewrite README.md", "make the README look good", "prepare a project for open-sourcing", or asks how to promote or present an OSS library, gem, crate, CLI tool, or service. Provides README structure, opening/tagline patterns, example and install conventions, evidence-based promotion techniques, badge policy, and license wording.
version: 0.1.0
---

# README

Conventions for composing READMEs for open source libraries, CLI tools, and services. Derived from sorah's own projects and from the top-downloaded crates.io and rubygems.org projects. Project-specific conventions and an existing README's established style always take priority.

A README has one job: let a stranger decide within one screen whether the project solves their problem, then get them to a working first use. Everything else is optional and must earn its place.

## Workflow

1. Gather facts from the repository before writing. Never invent them.
   - Name, package name, and registry (`*.gemspec`, `Cargo.toml`, `package.json`, `go.mod`)
   - Actual install channels: published gem/crate, Homebrew tap, AUR, container image, GitHub release binaries (check CI release workflows)
   - Minimum language/runtime version (`required_ruby_version`, `rust-version`, `engines`)
   - CLI help output (`--help`) and real config samples in the repo (`config.sample.yml`, `contrib/`, `examples/`)
   - `LICENSE*` files and copyright holder; `SECURITY.md`, `CONTRIBUTING.md`, `docs/`
   - Upstream projects it wraps, replaces, or was inspired by
2. Classify the project (see [Project Shapes](#project-shapes)) to pick a skeleton and length.
3. Write the opening (title, tagline, first paragraph) first. If it cannot be written in two sentences, the project's positioning is unclear. Ask the user rather than pad.
4. Write the smallest working example, then fill remaining sections.
5. Verify every command, path, flag, and link against the repository. Run the example when feasible.
6. Review against the [Checklist](#checklist).

When improving an existing README, preserve its voice, heading style, and structure unless asked for a rewrite. Fix inaccuracies and stale content first, then add missing essentials.

## Project Shapes

| Shape | Examples | Length | Notes |
|---|---|---|---|
| Foundational library | libc, itoa, cfg-if | Very short | Purpose sentence, dependency snippet, one example, docs link, MSRV, license |
| Focused library | thiserror, anyhow, webmock, hocho | Short–medium | Example-driven; README may be the manual |
| Framework / large library | tokio, sidekiq, faraday | Medium, docs elsewhere | README is a hub: pitch, minimal example, links to guides/API docs |
| CLI tool | ripgrep, fd, mairu, envchain | Medium–long | Install matrix, quick usage, config, comparisons |
| Service / daemon | himari, ecamo, needroleshere | Medium–long | How it works, setup, configuration, security model, caveats |

Once a README passes ~500 lines, either add a table of contents or move reference material to `docs/` and link it. Keep in the README even when docs move: tagline, pitch, install, minimal example, requirements, links to docs, where to get help, license.

## Skeleton

Default order. Omit sections with nothing true to say.

```
# Name: tagline                  (or "# Name - tagline")
[badges, optional]
Intro paragraph(s)
## Features / Why / What?        (optional)
## Requirements / Prerequisites  (when non-obvious)
## Installation / Setup
## Usage / Getting started / Quick start
## Configuration
## How it works                  (services, security-sensitive tools)
## Comparison / Difference with X / Prior art
## Security / Security Model
## Caveats
## Development
## Contributing
## License
```

For per-shape sample READMEs, see `examples/`.

## The Opening

The title and first paragraph carry most of the README's persuasive weight.

**Title.** `# Name` followed by a tagline after `:` or ` - `. The tagline is a short noun phrase, no trailing period.

```
# Acmesmith: A simple, effective ACME v2 client to use with many servers and a cloud
# Needroleshere - Yet Another AWS IAM Roles Anywhere helper
# Ecamo - SSL image proxy with authentication
```

**First paragraph.** "X is a [category] that [does what] [for whom/where]." One to four sentences, plain and factual. Then state the differentiator or mechanism.

Techniques that work:
- Name the category in the reader's vocabulary: "a Ruby static code analyzer (a.k.a. `linter`)"
- Anchor to a known tool: "a *cat(1)* clone with syntax highlighting", "alternative to `find`", "drop-in replacement of the official rolesanywhere-credential-helper"
- Credit prior art: "heavily inspired by atmos/camo"
- Two or three concrete adjectives, not superlatives: "Simple, efficient background jobs for Ruby."
- Admit limits early when they define the project: regex states it lacks backreferences and guarantees linear time in exchange
- State fit honestly: "If your team can use full-suite IdP such as Okta or Google Workspace, then this app may not be for you."

Avoid: spec-first openings ("This is an implementation of RFC 7159"), openings that describe the repository layout, and anything before the pitch other than badges and a logo.

## Examples and Code Blocks

- Put the smallest runnable example within the first screen of Usage. Show the "aha" moment, not the full API.
- Use real, copy-pasteable commands. Prefix with `$ ` only when command output is shown, to separate command from output.
- Start config and source blocks with a filename comment: `# config.ru`, `# ~/.aws/config`, `# /etc/systemd/system/foo.service`.
- Document CLI subcommands and config keys with end-of-line comments rather than prose paragraphs.
- Tag source and config fences with a language (`ruby`, `rust`, `toml`, `yaml`, `jsonc` for commented JSON, `ini` for systemd units) so they highlight. Use `console` for `$` transcripts with output. Plain command blocks may stay untagged.
- Use realistic generic placeholders: `example.com`, `123456789012`, `ALL_CAPS` for CLI arguments.
- Link long configuration out: "See [config.sample.yml](./config.sample.yml) to start."
- Use numbered H3 steps for multi-step setup: `### 1. Configure ...`, `### 2. Run ...`.

## Promotion

Promotion in a README means making the value obvious with evidence, not adjectives. Pick techniques proportionate to the project; a small library needs none beyond a good opening and example.

- **Features list**: short bullets of capabilities the reader cares about. Bold lead-ins only here, not across the whole document.
- **Comparison with alternatives**: `## Comparison with other products and solutions` with `### vs. X` subsections, or `## Difference with X`. Say when the alternative is the better choice; this is the single most credibility-building section.
- **Why / Why not**: ripgrep's "Why shouldn't I use ripgrep?" and bootsnap's "When not to use" make the rest of the claims believable.
- **Benchmarks**: only with the workload, hardware, and a reproducible script or link. Never fabricate or estimate numbers; ask the user for real measurements.
- **Visuals**: screenshot or asciinema/SVG screencast for CLI/TUI/web UI output; architecture diagram for services. Skip for libraries.
- **Social proof**: "used in production at X" only when the user confirms it.
- **Stability**: supported versions, MSRV policy, maturity statements, or a Caveats section.

See `references/promotion.md` for verbatim patterns and exemplars.

## Badges

Badges are optional. When used, keep 2–4 that answer a question the reader has: current version (gem/crates.io), CI status, API docs (docs.rs), and chat only if a community channel is actually staffed.

- Keep one visual style across the row
- Prefer reference-style link definitions to keep the raw Markdown readable
- Never add badges for dead services (Travis CI, Gitter, inch-ci, david-dm, Code Climate GPA), static self-asserted badges ("coverage 100%"), or vanity stars/forks

## Ecosystem Conventions

Each registry has idioms that readers expect. Consult `references/ecosystems.md` for:
- Ruby: stripping the `bundle gem` template, `bundle add`, MIT boilerplate
- Rust: `[dependencies]` snippet vs `cargo add`, MSRV, feature flags, dual-license text, `include_str!` doctests
- CLI install matrices (Cargo, Homebrew tap, AUR, Nix, mise, release binaries, container images)

## Sections Worth Getting Right

- **Installation**: list only channels that actually exist. For CLI tools, one bullet or H3 per channel.
- **Configuration**: document every key with its default, either as a commented sample block or a bullet list. Link the full sample file.
- **How it works**: for services and security-sensitive tools, explain the mechanism in a short list or diagram so operators can reason about failure modes.
- **Security / Security Model**: trust boundaries and what the tool protects against. Point to `SECURITY.md` or a contact for vulnerability reports.
- **Caveats**: bullet list of hard limits ("Only RSA, P-256, P-384 keys are supported."). Preferred over vague "experimental" banners.
- **Development**: real commands to build and test. Drop the bundler `bin/setup`/`rake release` text for end-user-facing READMEs unless it is accurate and useful.
- **Contributing**: one line: "Bug reports and pull requests are welcome on GitHub at https://github.com/OWNER/REPO." Link `CONTRIBUTING.md` if it exists.
- **License**: match the `LICENSE` file exactly. Include a copyright line when the project has one. See `references/ecosystems.md` for wordings.

## Voice and Formatting

- Plain, factual, technical. Third person for the project ("Mairu reads ...", "This tool ..."). Dry humor is fine in small doses.
- Short paragraphs; lists for enumerations; tables for compatibility matrices.
- Consistent heading case within a README, sentence case by default. Established section names such as "Security Model" are fine. ATX headings (`##`) only; do not mix with setext underlines.
- Relative links for in-repo files; anchor links for cross-references instead of repeating content.
- Avoid marketing superlatives ("blazing-fast", "revolutionary") unless backed by a benchmark in the same README.
- Avoid the usual machine-written tells: em dashes (use ` - `, a colon, or two sentences), bold lead-ins on every bullet, "Whether you're X or Y", "seamless", "robust", "powerful", emoji section headers, and closing summary paragraphs.
- GitHub alerts (`> [!WARNING]`) sparingly, for one genuinely critical notice at most.

## Anti-patterns

- Leftover template text: `TODO: Write usage instructions here`, `USER`/`[USERNAME]` placeholders, `UPDATE_WITH_YOUR_GEM_NAME...`
- No code example for a user-facing library
- Sponsors, alumni lists, or notices placed above the pitch
- Documenting install channels, flags, or config keys that do not exist
- Fabricated benchmarks, users, testimonials, or compatibility claims
- Stale version numbers or "latest release: vX" in prose
- Headings that are really code comments, and walls of badges

## Checklist

- [ ] Title plus tagline states what the project is
- [ ] First paragraph answers what, for whom, and why this over alternatives
- [ ] Minimal working example on the first screen of Usage
- [ ] Every install channel, command, flag, config key, and path verified against the repository
- [ ] Requirements and supported versions stated where non-obvious
- [ ] Limits stated in Caveats or the opening
- [ ] Every claim of speed, adoption, or compatibility has evidence
- [ ] No template leftovers, dead badges, or stale versions
- [ ] License section matches `LICENSE`
- [ ] Renders correctly on GitHub and on the registry page (crates.io renders `README.md`; rubygems.org does not, so gems rely on GitHub)

## Additional Resources

### Reference Files

- **`references/promotion.md`** - Tagline formulas, comparison/why-not sections, benchmark presentation, social proof, stability statements, with verbatim examples from popular projects
- **`references/ecosystems.md`** - Ruby, Rust, and CLI distribution conventions: install snippets, license boilerplate, MSRV, feature flags, badge markup
- **`references/exemplars.md`** - Heading skeletons of well-regarded READMEs (mairu, needroleshere, acmesmith, sidekiq, nokogiri, tokio, thiserror, ripgrep, uv, strong_migrations)

### Examples

Sample READMEs for fictional projects, showing structure and voice. Every fact in them is a placeholder:
- **`examples/library.md`** - Focused Ruby gem (Rack middleware)
- **`examples/cli.md`** - Rust CLI tool with multiple install channels and numbered setup steps
- **`examples/service.md`** - Self-hosted service with How it works, Security Model, and Caveats
