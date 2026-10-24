---
name: steep
description: This skill should be used when writing, reviewing, or fixing types in a Ruby library or gem typechecked by Steep, or when adding a Ruby file to such a project. Signs include a `Steepfile`, `rbs_collection.yaml`, a `sig/` directory (`sig/generated`, `sig/manual`, `sig-stub`), `# rbs_inline: enabled` magic comments, `#:` or `# @rbs` annotations, `# steep:ignore`, or the user mentioning "Steep", "steep check", "RBS", "rbs-inline", "rbs collection", "gem_rbs_collection", or a `Ruby::` diagnostic ID. Provides the file layout, rbs-inline annotation syntax, what belongs in hand-written signatures, concern and Data.define patterns, third-party signature handling, nil handling and escape hatches. Project-specific conventions (DESIGN.md, docs/) always take priority.
version: 0.1.0
---

# Steep with rbs-inline

How to write types in a Ruby library typechecked by Steep. Signatures are written inline as `#:` and `# @rbs` comments, generated into RBS files by `rbs-inline`, and checked by `steep check`. Nothing about the types runs at load time. The project's DESIGN.md or `docs/` takes priority over this guide. To introduce Steep to a project that does not have it yet, use the `steep-adoption` skill. Applications (Rails apps) use Sorbet instead; see the `sorbet` skill.

## Layout

```
Steepfile                 target :lib, signature "sig/generated", "sig/manual", check "lib"
rbs_collection.yaml       third-party signatures, from ruby/gem_rbs_collection
rbs_collection.lock.yaml  committed; .gem_rbs_collection/ is gitignored
sig/generated/            rbs-inline output, committed, never edited by hand
sig/manual/               what inline annotations cannot express, shipped with the gem
sig-stub/                 stubs of other gems' APIs, not shipped
rbs/<gem>/<version>/      a local collection source, when a gem's signatures are missing or wrong
```

- `sig/generated` is committed so the gem ships it and CI can check it is current. Regenerate it with `bundle exec rake rbs` (`rbs-inline --output=sig/generated lib` plus `rbs validate`) after every annotation change. A stale `sig/generated` means Steep checks a shape the code no longer has.
- Only `lib` is checked. Specs carry no annotations.
- Generated code (protoc/buf `*_pb.rb`) is `ignore`d in the Steepfile and typed by hand in `sig/manual`. A Sorbet-only part such as `lib/tapioca/` is ignored as well.
- Some gems write every signature by hand in `sig/<gem>.rbs` mirroring `lib/`, with no rbs-inline. Keep a project's existing style, and edit the `.rbs` alongside the `.rb` in the same commit.

## Ground rules

- Line 2 of every file in `lib/` (after `# frozen_string_literal: true`) is `# rbs_inline: enabled`. Without it rbs-inline skips the file and its methods have no signatures at all.
- Give every method a signature, including private ones. An unannotated method is generated as `(untyped a) -> untyped`, and Steep's default diagnostics accept that silently.
- Never write `sig` blocks, `extend T::Sig` or any `T.` form. The library has no `sorbet-runtime`.
- Run `bundle exec rake steep` (regenerate, validate, check) after every change. `steep check` takes the whole project and ignores a file list.
- Before keeping or defending a workaround, delete it and run the check again.

## Annotations

```ruby
# frozen_string_literal: true
# rbs_inline: enabled

module Mylib
  class Client
    DEFAULT_TIMEOUT = 5 #: Integer

    attr_reader :endpoint #: String

    # @rbs @timeout: Integer
    # @rbs @session: Session?
    # @rbs self.@default: Client?

    #: (String endpoint, ?timeout: Integer) -> void
    def initialize(endpoint, timeout: DEFAULT_TIMEOUT)
      @endpoint = endpoint
      @timeout = timeout
      @session = nil
    end

    #: [T] () { (Session) -> T } -> T
    def with_session(&block)
      block.call(session)
    end

    #: (Array[String] ids, ?strict: bool) -> Hash[String, Record]
    private def fetch_all(ids, strict: false)
      # ...
    end
  end
end
```

- A method signature is a `#:` line directly above the `def`. A YARD comment above it is fine; rbs-inline reads only the `#:` line.
- Constants and attribute readers take a trailing `#:`.
- Instance variables that no `attr_*` declares get `# @rbs @name: Type` in the class body; class-level ones get `# @rbs self.@name: Type`.
- Generic methods put the type parameters first: `#: [T] (...) -> T`.
- A `#:` comment runs to the end of the line, so it cannot sit inside parentheses or mid-expression.
- When the same union appears in several signatures, declare a `type` alias in `sig/manual` and refer to it by name.

## Mixins and concerns

- A module that calls methods of its includer declares them with `# @rbs module-self _FooSelf` in its leading comment, and the interface `_FooSelf` lives in `sig/manual/<path>.rbs`. Use `::Exception` or another class directly when that is what the includer is.
- A module self-type constrains includers, not the module's own type. Where code needs the value as both, declare an intersection alias: `type detailable_error = ::Exception & Detailable`.
- `class_attribute` installs accessors at runtime, which RBS cannot infer. Declare them in an interface (`_FooClass`) in `sig/manual`, together with the class-level DSL.
- Write `module ClassMethods` as an ordinary nested module rather than `class_methods do`. Steep checks the module, and `ActiveSupport::Concern` still picks it up by name. Give it `# @rbs module-self _FooClass`.
- `included do` and Rails DSL blocks whose `self` Rails supplies at runtime cannot be named in RBS. Wrap only that block in `# steep:ignore:start` / `# steep:ignore:end`, with a one-line comment above saying why, and declare what the block installs in `sig/manual`.

```ruby
# `self` inside an ActiveSupport::Concern block is the including class, which RBS has no
# way to name.
# steep:ignore:start
included do
  validate(:validate_columns)
end
# steep:ignore:end
```

## Data.define

- Write `Foo = Data.define(...)`, never `class Foo < Data.define(...)`. Steep cannot see into a computed superclass, and RuboCop flags it too. Reopen with `class Foo` below the assignment to add behaviour.
- When the class keeps the generated constructor, annotate each member on its own line, and rbs-inline generates the readers and both forms of `new`:
  ```ruby
  Point = Data.define(
    :x, #: Integer
    :y #: Integer
  )
  ```
- When the class overrides `initialize` (validation, defaults), the generated `new` rejects the new keywords. Write the class in `sig/manual` instead, and add this stub once, because core RBS declares no `Data#initialize` for `super` to reach:
  ```rbs
  class Data
    def initialize: (**untyped) -> void
  end
  ```

## Third-party signatures

- `rbs_collection.yaml` pulls from ruby/gem_rbs_collection. Mark development-only gems (rbs, steep, rspec-*, rubocop*, yard) `ignore: true` so their signatures neither load nor conflict.
- After changing the Gemfile or `rbs_collection.yaml`, run `bundle exec rbs collection install` and commit the lock file. CI installs with `--frozen`.
- A gem with no signatures, or with signatures the code contradicts:
  - If only this library's code calls it, declare the narrow surface `lib/` reaches in `sig-stub/<gem>.rbs` with a header comment saying why.
  - If another gem's shipped signatures reference its types, a project file cannot satisfy them, because library RBS cannot reference project signatures. Put it in a local collection source, `rbs/<gem>/<version>/<gem>.rbs` with a `manifest.yaml`, and add `- type: local, path: rbs` to `sources`.
  - Keep either one narrow on purpose: every declaration is something `lib/` calls.
- A gem whose shipped signatures conflict with another's (two library declarations of one method) gets `ignore: true`, and the part this library calls is declared in `sig-stub/`. Name the conflict in a comment.
- Stdlib libraries not pulled in by a gem's manifest go in the Steepfile as `library "securerandom"`.
- Never ship stubs of another gem's API. A gem that ships `Rails::Railtie.initializer` in its `sig/` collides with every other gem that does the same, and downstream projects have to ignore it. Stubs live in `sig-stub/`, which the gemspec leaves out.

## Nil and unions

Steep narrows locals and also calls of `attr_reader`s on `if x`, `unless x.nil?`, `case`/`when` and `is_a?`. Prefer, in order:

1. Restructure so the nil never exists: return the block's value instead of assigning a seeded local, `fetch` required keys, give a `case` an `else raise`.
2. Bind to a local and guard it: `if (session = result.session) && session.active?`.
3. A reader that raises, with `<name>_maybe` for the nilable form, as the `sorbet` skill describes.
4. An explicit `raise ... if value.nil?` naming the invariant.

A trailing `#: String` on a `String?` value is an unchecked cast: Steep accepts it without a diagnostic and it fails at runtime somewhere downstream. Treat it as the `sorbet` skill treats `#: as !nil`. An assertion between unrelated types is only a hint under the default diagnostics, so it is no safety net either.

## Escape hatches

Each needs a one-line reason above it.

- `value = expr #: untyped` for a value that really is dynamic, such as a message class looked up from a descriptor pool at runtime.
- `untyped` in a signature for forwarded `*args`/`**options`, or an includer's own constructor that a mixin forwards to.
- `# steep:ignore:start` / `end` around a DSL block only, never around ordinary code.
- `# @type self: singleton(ActiveRecord::Base)` inside a block whose `self` Steep cannot infer, in hand-written-signature projects.

## Comments

- A note explaining a Steep or RBS quirk is never part of a doc comment. Doc comments are the contract for callers.
- A file in `sig/manual` or `sig-stub` opens with a comment saying why it is hand-written, and each declaration that needs a reason gets one line.
- Record a general limitation in DESIGN.md's Types section.

## References

- <https://github.com/soutaro/rbs-inline/wiki/Syntax-guide> for the full annotation syntax
- <https://github.com/soutaro/steep> for Steepfile options and diagnostics
- The `github-ci` skill's `references/test-jobs.md` for the CI job
