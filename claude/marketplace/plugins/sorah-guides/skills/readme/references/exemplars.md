# Exemplar READMEs

Heading skeletons of READMEs worth imitating, grouped by project shape. Fetch the original (`gh api repos/OWNER/REPO/readme -H 'Accept: application/vnd.github.raw'`) when a closer look helps.

## sorah's own

### mairu (Rust CLI, credentials manager)

`sorah/mairu`. A thorough README that works as the manual.

```
# Mairu
## Key features
## Installation                 (bullets per channel: Cargo, mise, aqua, Homebrew tap, AUR, binary)
## Get started
### 1. Configure Mairu for your AWS SSO instance
### 2. Use as a executor
### 3. Use as a credential process provider
## Configuration
## Usage in detail
### `auto` role / ### Role chaining / ### Reauthentication / ### Docker support
## Credential Server API
## Comparison with other products and solutions
### vs. aws-vault / ### vs. Weep / ...
## Security
### Reporting security issues / ### Possible threats
## License                      (Apache 2.0 + copyright line)
```

### needroleshere (Rust daemon/helper)

`sorah/needroleshere`. Uses a comparison table, a security model section, and caveats.

```
# Needroleshere - Yet Another AWS IAM Roles Anywhere helper
[badges: crates.io, CI, deps.rs]
## Install
## Usage
### Process credentials provider mode (`process-credentials`)
### Server mode (`serve`)
## Comparison between modes     (compatibility table with footnotes)
## Security Model
## Caveats
## Example configurations of systemd units
## Development
## License
## Copyright Notice
```

### acmesmith (Ruby gem + CLI, plugin architecture)

`sorah/acmesmith`. The classic gem shape, with extensibility documented.

```
# Acmesmith: A simple, effective ACME v2 client to use with many servers and a cloud
## Features
## Installation
### Docker
## Usage                        (CLI synopsis with end-of-line comments)
## Configuration
### Storage / ### Challenge Responders / ### Post Issuing Hooks
## Vendor dependent notes
## Contributing
## Writing plugins
## Development
## License
```

Also: `sorah/envchain` (narrative "What?" opening, screenshot, Sponsor section) and `sorah/vault2kube` ("What's this" plus "Difference with vault-k8s").

## Ruby

### sidekiq (short, confident, commercial edition)

```
# Sidekiq                      (Gem Version, CI, Forum badges)
tagline + mechanism paragraph
## Requirements
## Installation                 (bundle add sidekiq)
## Getting Started              (wiki, video, Web UI screenshot)
## Performance                  (benchmark table with caveats)
## Want to Upgrade?             (Pro/Enterprise pitch)
## Problems?                    (where to ask, office hours)
## Contributing
## License
## Author
```

### nokogiri (full-service, support hierarchy)

```
# Nokogiri                     (right-floated logo)
pitch
## Guiding Principles
## Features Overview
## Status                       (badges moved here, below the pitch)
## Support, Getting Help, and Reporting Issues
## Installation
## How To Use Nokogiri
## Technical Overview
## Contributing
## License
```

### strong_migrations (problem-first, Bad/Good)

```
# Strong Migrations
tagline + three check-mark lines + supported databases + battle-tested line
## Installation
## How It Works
## Checks                       (each: #### Bad / #### Good)
## Best Practices
## Credits
## History
## Contributing
```

### faraday (minimal hub, docs on a site)

```
# [logo](website)
badges, pitch
## Why use Faraday?
## Getting Started              (links to website)
## Supported Ruby versions      (policy sentence)
## Contribute
## Copyright
```

## Rust

### tokio (framework hub)

```
# Tokio                        (tagline + Fast/Reliable/Scalable bullets)
badges · Website | Guides | API Docs | Chat
## Overview
## Example                      (Cargo.toml + full echo server)
## Getting Help
## Contributing
## Related Projects
## Supported Rust Versions
## Release schedule / ## Bug patching policy
## License / ### Contribution
```

### thiserror / anyhow (small focused library)

```
Title · 4 badges (github, crates.io, docs.rs, build)
"This library provides ..." · [dependencies] snippet
## Example / ## Details         (bullets, each with code)
## No-std support
## Comparison to anyhow
#### License                    (dual license in <sup>/<sub>)
```

### ripgrep (CLI, credibility-first)

```
ripgrep (rg)                    (setext title) · description · badges · license line
### CHANGELOG · ### Documentation quick links
### Screenshot of search results
### Quick examples comparing tools   (benchmark table)
### Why should I use ripgrep?
### Why shouldn't I use ripgrep?
### Is it really faster than everything else?
### Feature comparison
### Installation                (per package manager)
### Building · ### Running tests
### Vulnerability reporting
```

### uv / ruff (product-grade CLI)

```
# uv · badges · tagline · hero benchmark chart + caption
## Highlights                   (bullets with links)
## Installation                 (standalone installer first, then pip/pipx)
## Documentation
## Features                     (### per workflow with shell transcripts)
## Contributing
## FAQ
## Acknowledgements
## License
```

### fd / bat (CLI with visuals)

fd: Features → Demo (animated SVG) → How to use → Benchmark → Troubleshooting → Integrations → Installation.
bat: centered logo, nav row, one screenshot per feature, per-OS install headings, `doc/alternatives.md` for comparisons.
