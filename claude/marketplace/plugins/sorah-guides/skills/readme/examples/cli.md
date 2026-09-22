# foo - command runner with short-lived cloud credentials

foo is a command-line tool that obtains short-lived credentials on demand and passes them only to the command that needs them. Nothing is written to `~/.aws/credentials`.

```console
$ foo exec 123456789012/ReadOnly -- aws s3 ls
2024-01-01 00:00:00 my-bucket
```

## Key features

- Per-command credentials: each `foo exec` receives only the role it asks for
- Works as an [AWS credential process](https://docs.aws.amazon.com/sdkref/latest/guide/feature-process-credentials.html) provider for SDKs
- Caches credentials in a background agent, never on disk

## Installation

- Cargo: `cargo install --locked foo`
- Homebrew: `brew install OWNER/tap/foo`
- Arch Linux (AUR): `yay -S foo`
- Binary: [GitHub releases](https://github.com/OWNER/foo/releases)

## Get started

### 1. Register your identity provider

```jsonc
// ~/.config/foo/servers.d/example.json
{
  "url": "https://sso.example.com",
  "id": "example",           // Optional, defaults to {url}
  "region": "us-east-1"
}
```

### 2. Run a command

```
foo exec 123456789012/ReadOnly -- terraform plan
```

### 3. Use from AWS SDKs

```ini
# ~/.aws/config
[profile readonly]
credential_process = foo credential-process 123456789012/ReadOnly
```

## Usage

```
foo exec ROLE -- COMMAND...     # run COMMAND with credentials for ROLE
foo login SERVER                # authenticate against SERVER ahead of time
foo list-roles [SERVER]         # show roles available to you
```

See `foo help SUBCOMMAND` for all options.

## Comparison with other tools

### vs. aws-vault

aws-vault stores long-term access keys in the OS keychain. foo holds no long-term secrets and requires an SSO-capable identity provider. aws-vault remains the better choice when only IAM users are available.

## Security

### Reporting security issues

See [SECURITY.md](./SECURITY.md).

## License

Apache License 2.0

Copyright 2024 Your Name
