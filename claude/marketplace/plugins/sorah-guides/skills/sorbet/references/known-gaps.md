# Sorbet Known Gaps

Limitations that show up when typing a Rails app or a gem with inline RBS, and the fix for each.

## Contents

- Error codes
- Limitations without an error code
- Shims most Rails apps need
- Files that stay below strict

## Error codes

| Code | Symptom | Fix |
|------|---------|-----|
| 3552 | A block in an RBS signature is rejected | Declare `&block` or `&_block` on a method that only `yield`s |
| 4002 | `class Foo < Data.define(...)` cannot be resolved | `Foo = Data.define(...)`, then reopen `class Foo` to add constants. Do not suppress the code in `sorbet/config` |
| 4010 / 7004 | A `Data.define` subclass overrides `initialize` with keywords; `super` resolves to `Object#initialize` | Turn it into a plain class |
| 4010 | A community annotation contradicts the gem RBI (activesupport `String#as_json`, `Array#to_xml`) | `typed_overrides: { activesupport: "false" }` under `annotations:` in `sorbet/tapioca/config.yml` |
| 5005 | An instance variable is "declared inside `initialize` or declared nilable" | Declare it in `initialize` with `= nil #: T?`. Mailers and jobs have no `initialize`, so give the variable a nilable type there |
| 5049 | A required keyword follows an optional one | Reorder the keywords in the definition; call sites are unaffected |
| 7003 | `raise` does not exist on a bare module | `include Kernel` in the module |
| 7006 | A guard is unreachable because the parameter type is too precise | For external input, widen the parameter so the guard stays. Otherwise drop the guard |
| 7015 | Unnecessary cast | Remove the cast. `Must` calls are never reported, so prune those by hand |
| 7019 | A splat is passed into fixed arity (`Open3.popen2e(*cmd)`), or explicit keywords are mixed with `**opts` | Merge everything into one hash before the call, or spell the keywords out. A file blocked only by a stdlib call stays at `false`/`true` |
| 7034 | `&.` on a non-nilable receiver | Drop the safe navigation |
| 7038 | `nil?` on an unconstrained type parameter | Narrow with `case value when nil ... else value end` |
| 7043 | A `#:` after a modifier `if` (`@x = Foo.new if y #: Foo?`) does not attach to the assignment | Parenthesize the value: `@x = (Foo.new if y) #: Foo?` |

## Limitations without an error code

- **Segfault.** `srb tc` crashes when a class contains an RBS `#:` cast and also a method with an anonymous `**` (under `--enable-experimental-rbs-comments`). Name the splat.
- **Sorbet ignores `.rbs` files.**
  - RBS support is for inline comments only. Generated `sig/**/*.rbs`, for example from protoc `--rbs_out`, is invisible to Sorbet.
  - Types for generated code reach Sorbet only as RBI, from `tapioca gem` or `tapioca dsl`.
  - `tapioca gem` sees only the constants that the gem's entrypoint loads. List lazily loaded entrypoints in `sorbet/tapioca/require.rb`.
- **`tapioca dsl` boots Rails.** Its ActiveRecord compilers open a real database connection, so the dev database or cloud credentials must be available. Ask the user to authenticate; skipping an initializer does not avoid the connection.
- **`tapioca annotations` has no output-directory option.** Annotation RBIs stay in `<project>/sorbet/rbi/annotations/`.
- **`belongs_to` readers.** Tapioca types every `belongs_to` reader as nilable, including non-optional ones. Read them with `Must.expect`.
- **`NOT NULL` columns.** Tapioca types them as non-nil, although an unsaved record can still hold nil. Validators read such a column through a local.
- **`included do` blocks.** Methods, attributes and `include`s added inside `included do` are invisible. Re-include the module directly, or declare the method in a shim.
- **`class_methods do` through relations.** Sorbet does not see a relation reaching a `class_methods do` method through delegation. Cast the relation, or declare the method on the generated relation class in a shim.
- **`alias_method`.** An alias whose target comes from an included module fails, because aliases resolve before inclusion. Write a plain method.
- **Constants defined on another module.** A `#:` on a scoped constant assignment (`Foo::BAR = x #: T`) is ignored.
- **Instance variables of gem classes.** A file that reads a gem class's instance variables (`@raw_connection`, `@options` inside a plugin module) cannot declare them, because inline RBS declares an instance variable only on an assignment and an RBI shim cannot declare one either. The file stays at `typed: true`.
- **Instance variables assigned outside `initialize`.** A class that builds its state somewhere other than `initialize`, such as a `start!` or `restore!` step, stays at `true` unless that state moves into `initialize`.
- **Multiple assignment.** Assigning from an `Array[String]` yields `String?` for each target, so destructuring does not narrow.
- **`Data` unions and runtime predicates.** Sorbet cannot narrow a `Success | Failure` union through a runtime `failure?` call. Use `case result when Failure`, or keep the value `untyped`.
- **RuboCop cops.** Predicates generated by `def_node_matcher` have no tapioca compiler. Cop files stay at `false`.
- **Foreign DSL files.** A file evaluated in another tool's context (a falcon host, `bin/ci`'s `CI` DSL) stays at `false`, or at `ignore` if it cannot even resolve.
- **Spec doubles.** A `Class.new` that defines `initialize` or `self.name` leaks into `Object`. Mark that spec `# typed: ignore`.
- **`sorbet-static` has no `ruby`-platform gem.** Lockfiles need concrete platforms (`bundle lock --add-platform x86_64-linux aarch64-linux arm64-darwin`, then remove `ruby`). Also set `BUNDLE_FORCE_RUBY_PLATFORM=false` wherever it is otherwise forced on. sorah's shell sets it to `true` globally, so pin `false` in `mise.toml [env]`.

## Shims most Rails apps need

Put each shim in `sorbet/rbi/shims/<gem>.rbi`, with `# typed: true` and a one-line comment saying why tapioca misses it.

```ruby
# SemanticLogger::Loggable defines #logger via class_eval inside its
# `self.included` hook, so tapioca cannot see it statically.
module SemanticLogger::Loggable
  sig { returns(SemanticLogger::Logger) }
  def logger; end
end

# TimeWithZone delegates unknown methods to the wrapped Time via
# method_missing, so tapioca cannot see Time methods like #floor statically.
class ActiveSupport::TimeWithZone
  sig { params(ndigits: Integer).returns(ActiveSupport::TimeWithZone) }
  def floor(ndigits = 0); end
end

# Rails sets Time.zone_default from config.time_zone at boot, so Time.current
# never returns a bare Time here.
class Time
  sig { returns(ActiveSupport::TimeWithZone) }
  def self.current; end
end

# The gem ships no signatures of its own, and an untyped #kept? widens every
# boolean expression it appears in.
module Discard::Model
  sig { returns(T::Boolean) }
  def discarded?; end

  sig { returns(T::Boolean) }
  def kept?; end
end

# google/protobuf/well_known_types reopens Timestamp with from_time/to_time
# after tapioca gem already ran.
class Google::Protobuf::Timestamp
  sig { params(time: T.any(Time, ActiveSupport::TimeWithZone)).returns(Google::Protobuf::Timestamp) }
  def self.from_time(time); end

  sig { returns(Time) }
  def to_time; end
end

# PKey#to_der has been on the base class since Ruby 3.0, but sorbet's bundled
# stdlib RBIs still declare it only on the RSA/DSA/EC subclasses.
class OpenSSL::PKey::PKey
  sig { returns(String) }
  def to_der; end
end

# The routing gem does ActionDispatch::Routing::Mapper.include(Routing) at load.
class ActionDispatch::Routing::Mapper
  include SomeRoutingGem::Routing
end
```

## Files that stay below strict

A file held at `true` or `false` is acceptable when the cause is one of the limitations above. Name the limitation in the commit message, and list it under Known gaps in `docs/type-checking.md`. A file must not stay below `strict` just because annotating it is tedious.
