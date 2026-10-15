# GitHub & Commit Examples

Verbatim (or lightly corrected) examples from the author's own writing. Use as a palette for rhythm and phrasing; do not copy verbatim. Grammar slips present in the originals have been corrected here.

## Own / Team Repository PR Bodies

Terse, often a fragment or a link. Lowercase start is fine.

```
for better backend latency

https://github.com/ruby-no-kai/rko-router/issues/81
```

```
- long max-age
- long s-maxage
```

```
use static NAT on onpremises router devices so they don't need to handle dynamic NAPT table and allow redundancy
```

```
Not working properly, perhaps https://github.com/hyperium/tonic/issues/1424
```

Nested "why" bullets:

```
- declare proxy_redirect to avoid redirecting to http:// url
  - this would avoid the dance like ...
    - gh-pages returns http URL for trailing slash redirection (why?)
```

Labelled trailers (ruby/ruby style):

```
bug: https://bugs.ruby-lang.org/issues/20515
follow-up: 22e4eeda...
follow-up: https://github.com/ruby/ruby/pull/10875
```

Redesign PRs get paragraphs:

> This change makes mairu-exec spawn a credential provider in a child process. … We now call a child process running a credential provider "sidecar".

## Upstream Issues & PRs

Capitalised, problem first, then reasoning; cite specs.

- "Previously roadworker issues 1 ChangeResourceRecordSets API call (change batch) per ResourceRecordSet. This doesn't allow:"
- "This is a fix for the issue I mentioned at … I believe the present implementation can't interop with OpenSSL."
- "big.Int Bytes() returns a variable-length byte string, while the SEC1 ECDH procedure is defined to output a fixed-length byte string (in big-endian)."
- "Same as https://github.com/ruby/reline/pull/510, 'ruby' command is not always available so don't rely on that specific name."
- "This behaviour is defined in various documents including RFC6979 Section 2.3.2., SEC 1 Section 2.3.8., NIST FIPS 186-4 Appendix C.2.1."

Issue reports and feature requests: ask first, then context.

- "Please address the usage of the deprecated behaviour in Ruby 2.7."
- "Looks like there are many usages of `Proc.new` w/o block in aws-sdk-ruby, so I'm opening this issue instead of sending a PR."
- "… is not planned to be reverted, so I'd like to let you know."
- "I wonder if GitHub Actions could issue ID tokens with a `repository_name` claim along with the existing `repository_owner`."

## Maintainer Replies (own projects)

- "IIRC some secret providers don't support return characters, so I am not going to directly support this."
- "You can send a patch without having CI, I'll wait for a patch first."
- "A proper bash & zsh completion script is welcome, but this is still just a hack."
- "To repeat, I do not recommend using both an outdated distro on the host and an outdated base distro."
- "PRs are always welcome and I'm positive for this feature. Looking forward to it!"
- "should be fixed in 2.7.1, thanks"
- "v1.1.0 released in late 2024. thanks for the patience."
- "dupe of #24 - I'll proceed to release the new version 😫 sorry"

## Code Review

Often a suggestion block alone. Otherwise one line:

- "Because it is user input, isn't it?"
- "I believe determining RP ID or AppID is the RP implementation's job, by something like:"
- "I'm not confident enough but if I read the RFC correctly I believe this should be like:"
- "maybe this is app/resources' job"
- "Why isn't MailgunEvent a protobuf message type? Can't we allow parsing via ProtoJSON using the json_name option?"
- "I want to keep the snapshot hash as is for now because the proposed change enumerates all attributes 2 or 3 times, which seems too noisy and redundant."
- "I disagree with this direction of change. While some readers may confuse it with the method name, in general `input` is not a good variable name."
- "We also want to have resource_policy_id in `access`, but I'd suggest a new resource to cover `access` instead of extending …"

## Nudges & Process

- "@maintainer consider merging this" / "@maintainer ping"
- "@reviewer could you take a look at this please?"
- "feel free to merge once you update the timestamp in the History section"
- "CIs passed." / "test failures seem unrelated to my change"
- "✅ verified --with-opt-dir=/opt/homebrew works well on arm64 macOS"
- "♻️ updated"
- "Sorry for being late to reply."

## Commit Bodies

One clause continuing the subject:

```
target directory should be absolute path

because we do chdir.
```

```
site-gateway(ec2): VPC route must be installed

otherwise fails when more than 2 routers exist in the same VPC
```

```
fluentd nginx: Specify time_format

to avoid "argument out of range" error
```

Bare upstream reference:

```
Patch strongswan for a bug on $PLUTO_MARK_{IN,OUT}

https://github.com/strongswan/strongswan/pull/37
```

Cause → effect:

- "Logger makes a lock, so it can't be called from trap context."
- "nkmi.me domain could be unresolved while the VPN connection is down."
- "OpenSSL message digest algorithm has changed since 1.1.0. Specify SHA256 explicitly to avoid confusion between client and server."
- "It looks like setting force=true is recommended for controller-ish usage. This should resolve conflict errors …"

Before/after framing: "previously, scripts in an array were concatenated …", "Now responds to HEAD requests".

Release commit:

```
v0.2.0

= Enhancements
- Support --synced-release (#12)

= Bug fixes
- Better error handling (#5, @contributor)
```

Light touches: "oops, fixed router-id", "Forgot to rename :/", "Debian: 1.63 on bookworm :(", "Sequel::Model requires an active database connection on class inheritance. What??"
