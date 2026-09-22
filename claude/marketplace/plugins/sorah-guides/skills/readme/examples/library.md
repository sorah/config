# Foo: HTTP request signing for Rack applications

[![Gem Version](https://badge.fury.io/rb/foo.svg)](https://rubygems.org/gems/foo)
[![ci](https://github.com/OWNER/foo/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/foo/actions/workflows/ci.yml)

Foo is a Rack middleware that verifies [HTTP Message Signatures (RFC 9421)](https://www.rfc-editor.org/rfc/rfc9421) on incoming requests. It lets internal services authenticate each other without sharing bearer tokens.

Heavily inspired by [upstream/bar](https://github.com/upstream/bar), but supports Ed25519 keys and key rotation.

## Installation

```
bundle add foo
```

## Usage

```ruby
# config.ru
require 'foo'

use Foo::Middleware,
  keys: Foo::KeyStore.from_directory('/etc/foo/keys'),
  required_components: %w[@method @path content-digest]  # default: %w[@method @path]

run MyApp
```

Verified key ID is available as `env['foo.key_id']`. Requests failing verification receive `401` with a `WWW-Authenticate` header.

### Key rotation

Place multiple keys in the directory. Foo accepts any key present, so add the new key, deploy, switch signers, then remove the old key.

## Configuration

- `keys` (required): a `Foo::KeyStore`.
- `required_components` (default `%w[@method @path]`): components a signature must cover.
- `max_age` (default `300`): maximum signature age in seconds.

## Caveats

- Only Ed25519 and ECDSA P-256 keys are supported.
- Request bodies are read fully to verify `content-digest`. Put a body size limit in front of this middleware.

## Development

```
bundle install
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/OWNER/foo.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
