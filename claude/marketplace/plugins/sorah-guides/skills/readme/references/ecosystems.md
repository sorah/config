# Ecosystem Conventions

## Ruby (gems)

### The `bundle gem` template

`bundle gem` generates a README full of placeholders. A published README containing any of these looks unfinished:

- `TODO: Delete this and the text below, and describe your gem`
- `Welcome to your new gem! In this directory, you'll find the files you need...`
- `TODO: Write usage instructions here`
- `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG`
- `https://github.com/USER/foo` or `[USERNAME]`
- The `## Code of Conduct` section when no `CODE_OF_CONDUCT.md` exists

Replace every placeholder. Keep only template sections that remain accurate.

### Installation

Current idiom:

````markdown
## Installation

```
bundle add foo
```

Or install it yourself as:

```
gem install foo
```
````

Older form still common and acceptable when matching an existing README:

````markdown
Add this line to your application's Gemfile:

```ruby
gem 'foo'
```
````

For CLI gems, lead with `gem install foo`. For Rails engines/plugins, follow with the generator or initializer step.

### Usage

In Rails or `Bundler.require` contexts, show `require` only when the gem name and require path differ. Plain Ruby scripts and `config.ru` need it. Show a Rack app as a `# config.ru` block, and Rails config as `# config/initializers/foo.rb`.

### Development

Keep the template's `bin/setup` / `rake spec` text only if those files exist and work. Replace `rake release` instructions with nothing for end-user READMEs; release procedure belongs in maintainer docs.

### License

Template line (fine for MIT gems):

```markdown
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
```

Adapt the noun for non-gems ("The tool is available as ..."). For Apache-2.0 and others, see [License wording](#license-wording).

### Badges

Gem version (`https://badge.fury.io/rb/foo.svg` or `https://img.shields.io/gem/v/foo`) plus GitHub Actions badge (`https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg`).

## Rust (crates)

### Dependency snippet

````markdown
```toml
[dependencies]
foo = "1"
```
````

Or the `cargo add` form, shorter and version-agnostic:

````markdown
```
cargo add foo
```
````

When the example needs companion crates or features, show the full `[dependencies]` block and a sentence saying why (reqwest: "This asynchronous example uses Tokio and enables some optional features, so your `Cargo.toml` could look like this:").

### README as crate docs

When `lib.rs` has `#![doc = include_str!("../README.md")]`, README code blocks become doctests. Tag non-Rust blocks (`toml`, `sh`, `text`) and use `rust,no_run` or `rust,ignore` for examples that need network or a runtime.

### MSRV

State the minimum supported Rust version when `rust-version` is set in `Cargo.toml`. Section names in use: "Minimum supported Rust version", "Supported Rust Versions", "Rust version support". Optionally a policy sentence ("MSRV bumps are not considered breaking changes" or the opposite, per project).

### Feature flags

List Cargo features that change behavior or pull in dependencies, with defaults marked:

```markdown
## Cargo features

- `rustls` (default): Use rustls for TLS.
- `native-tls`: Use the platform TLS library instead.
```

### Other sections

- `no_std` support, if applicable
- `## Safety` when the crate forbids or carefully uses `unsafe`

### Badges

Common and meaningful: crates.io version, docs.rs, CI, MSRV. Reference-style definitions keep the header readable:

```markdown
[![Crates.io][crates-badge]][crates-url]
[![Documentation][docs-badge]][docs-url]

[crates-badge]: https://img.shields.io/crates/v/foo.svg
[crates-url]: https://crates.io/crates/foo
[docs-badge]: https://docs.rs/foo/badge.svg
[docs-url]: https://docs.rs/foo
```

## License Wording

Always match the `LICENSE*` files. Include a copyright line when one exists in the LICENSE or the author uses one.

MIT, terse:

```markdown
## License

MIT License
```

Apache-2.0 with copyright (sorah style):

```markdown
## License

This project is licensed under the Apache-2.0 License.

Copyright 2022 Sorah Fukumori
```

Apache-2.0 with notice of exceptions:

```markdown
## License

(c) Sorah Fukumori https://sorah.jp/

Apache 2.0 License unless otherwise noted.
```

Rust dual license (Rust API Guidelines):

```markdown
## License

Licensed under either of

 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or https://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or https://opensource.org/licenses/MIT)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.
```

Borrowed code: add `## Copyright Notice` or `### Credits` listing each third-party file or component with its origin and copyright, or point to `NOTICE`.

## CLI Distribution

List only channels that exist. Check release workflows, taps, and packaging repos before writing.

Bullet form (mairu style), compact when each channel is one command:

```markdown
## Installation

- Cargo: `cargo install --locked foo`
- Homebrew: `brew install OWNER/TAP/foo`
- Arch Linux (AUR): `yay -S foo`
- mise: `mise use -g github:OWNER/foo`
- Binary: [GitHub releases](https://github.com/OWNER/foo/releases)
```

H3-per-channel form when a channel needs several steps (repository setup, signing keys, container flags):

```markdown
### Docker

    docker run --rm -v $PWD:/work ghcr.io/OWNER/foo:latest
```

Recommend one channel first when there is a clearly preferred one. For container images, give the full registry path and tag scheme.

After install, show shell integration or completion setup if the tool has it (starship "Step 2. Set up your shell").

## Go, Node, and others

- Go: `go install github.com/OWNER/foo/cmd/foo@latest` for tools; `go get` line plus a `pkg.go.dev` link for libraries.
- npm: `npm install foo` (mention pnpm/yarn only if the project cares). State supported Node versions from `engines`.
- Container-first services: `docker run`/Compose sample, then Helm or manifests link.
