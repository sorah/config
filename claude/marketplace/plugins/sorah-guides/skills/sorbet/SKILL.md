---
name: sorbet
description: This skill should be used when writing, reviewing, or fixing types in a Ruby or Rails project typechecked by Sorbet with inline RBS comments, or when adding a Ruby file to such a project. Signs include a `sorbet/config` file, `# typed:` sigils, `#:` signature comments, or the user mentioning "Sorbet", "srb tc", "RBS comment", "typed: strict", "tapioca", "RBI shim", "T.must", "as !nil", "Must.because", or a Sorbet error code. Provides signature syntax, nil and union handling (Must, `_maybe` readers), concern and Data.define patterns, shim-versus-cast rules, and a catalogue of Sorbet gaps with workarounds. Project-specific conventions (docs/type-checking.md) always take priority.
version: 0.1.0
---

# Sorbet with Inline RBS

How to write types in a project that typechecks with Sorbet using inline RBS comments. Signatures live in `#:` comments that Ruby ignores, so `sorbet-runtime` is not loaded and nothing about the types runs in production. The project's `docs/type-checking.md` takes priority over this guide. To introduce Sorbet to a project that does not have it yet, use the `sorbet-adoption` skill. Libraries and gems typecheck with Steep instead; see the `steep` skill.

## Ground rules

- Write signatures only as `#:` RBS comments in `.rb` files.
  - `sig` blocks, `extend T::Sig`, `T.let`, `T.must`, `T.cast` and `T.untyped` need `sorbet-runtime`. Where it is absent they raise `NameError` at load time. Where a gem pulls it in anyway, they turn into runtime checks nobody asked for.
  - `.rbi` shim files are the exception: they are never loaded, and `sig` blocks are the correct syntax there.
- Do not run `srb tc -a`. Its autocorrect inserts exactly the forbidden `T.` forms.
- A new file under `app/`, `lib/` or `config/` starts at `# typed: strict`. Spec files carry no sigil, because the RSpec DSL does not typecheck.
- The target level is `strict`, not `true`. At `true`, Sorbet requires no signatures, so a file can pass with almost none, and the signatures are what make the types useful to the next person writing a call.
- Run `bundle exec srb tc` from the project directory after every change.
- Before keeping or defending a workaround, delete it and run `srb tc` again. Many workarounds turn out to be unnecessary on a retry: a constant cast `as untyped` before `.new`, `.class.to_s` in place of `.name`, a cast on `Time.current`.

## Signatures

```ruby
#: (String, expires_in: Integer, ?scopes: Array[String]) -> Token
def issue(subject, expires_in:, scopes: [])

#: (String, readonly: bool, ?actor: User?,
#|  ?tags: Array[String]) -> void
def record_event(name, readonly:, actor: nil, tags: [])

#: [T] () { () -> T } -> T
def with_lock(&block)

#: Integer
attr_reader :max_age

DEFAULT_TTL = 300 #: Integer

def initialize(order_id:, amount:)
  @order_id = order_id
  @amount = BigDecimal(amount) #: BigDecimal
  @invoice = nil #: Invoice?
end
```

- Give every method a signature, including private ones. Give every constant and every instance variable one too.
- Constants and instance variables take a trailing `#:` on the line that assigns them. A `#:` on the line above does not attach to a constant.
- Declare every instance variable in `initialize`, including any that a later step method fills: assign it `nil` there with a nilable type. Sorbet rejects a non-nilable instance variable first assigned outside `initialize` (error 5005).
- A memoized `@x ||= ...` needs a nilable type.
- A `#:` after a modifier `if` does not attach to the assignment (7043). Parenthesize the value instead: `@cart = (Cart.new(user:) if user) #: Cart?`.
- A method that `yield`s must still declare a block parameter (`&block` or `&_block`) before its signature can describe a block (3552).
- Put required keywords before optional ones (5049). Reordering keyword parameters in the definition is safe because callers pass keywords by name. Never reorder positional parameters.
- Name your splats. An anonymous `**` or `*` in a class that also contains an RBS `#:` cast segfaults `srb tc`. Sorbet also cannot check explicit keywords mixed with a splat (7019), so merge the options into one hash before the call, or spell the keywords out.
- Split a multiple assignment, and an `attr_reader` that names several attributes with different types. A multiple assignment cannot carry a `#:` for each target.
- When the same union appears in several signatures, define an alias once on the owning class, such as `#: type payer_like = User | Organization | Guest`, and refer to it elsewhere as `Owner::payer_like`.
- Values that are nil together are typed as a tuple union: `[Header, Claims] | [nil, nil]`.
- Write `Module[untyped]`, not a bare `Module`, at `strict`.
- A `#: as` annotates the whole right-hand side of a line. It cannot sit in the middle of an expression.
- Widening a value that is already nilable with `#: as T?` trips the strict-only useless-cast check. Use a plain `#: T?` declaration instead.
- `&.` on a receiver that Sorbet knows is non-nil is an error (7034). Drop the safe navigation.

## Nil handling: never `#: as !nil`

A `#: as !nil` cast is a silent `T.must`. When the invariant behind it breaks, the program fails with a `NoMethodError` somewhere downstream instead of at the line that made the assumption. Remove the nil instead. Try these in order:

1. **Restructure so the nil never exists.**
   - Return the value of a transaction or block, instead of seeding `x = nil` and assigning `x` inside the block.
   - Give a `case` the `else raise` it is missing when its other arms are already rejected upstream. The method then returns a non-nilable value, and every caller stops asserting.
   - Use `fetch` for required keys and indexes. When the input comes from outside, use `fetch(0) { raise InvalidToken }` so a bad request returns a 4xx rather than a `KeyError` 500.
   - Use APIs that return non-nil values: `each_byte`, `drop(n)`, `first(n)`, `rpartition`.
2. **Bind a guarded call to a local, then guard the local.** Sorbet narrows locals, not method calls: `if (session = result.session) && session.active?`.
3. **Give the owner a reader that raises.** The plain name returns the non-nil value and raises when it is absent. A nilable variant, when some caller needs one, is named `<name>_maybe`.
   ```ruby
   #: () -> User?
   def current_user_maybe = current_session_maybe&.user

   #: () -> User
   def current_user = Must.because(current_user_maybe) { "gate on require_login! before reading current_user" }
   ```
   - For a service object, give each instance variable that a step method fills (`check_prerequisite!`, `perform`) a private raising reader.
   - A class-level DSL accessor such as `def slot(value = nil)` keeps its plain name for declarations. Add a `slot_value` reader that raises `NotImplementedError, "#{name} declares no slot"`.
4. **`Must.because(value) { "invariant" }`.** The reason names what makes the value present.
5. **`Must.expect(value)`.** Use the reason-less form only for a non-optional `belongs_to` reader (tapioca types every `belongs_to` as nilable), or for a stdlib call whose guard is on the adjacent line.

Further rules:

- Narrowing does not cross method boundaries.
  - When a caller's guard is what makes a value present, do not add a parameter just to hand the callee a narrowed copy of something it can already reach. That covers its own instance variables, its readers, and data inside an argument it already receives.
  - Examples: `notify_owner!(@owner)` beside `@owner`, or `renew(result:, record: result.record)`.
  - Unwrap inside the callee with a raising reader or `Must.because`, which names the caller's guard as the reason. A new parameter is right only when it carries something the callee could not otherwise reach.
- If a result type has nilable members only because one mode leaves them nil, split it into one type per mode, so the full mode's members are non-nil.
- A nilable value used once can be consumed with `value&.then { use(it) }` instead of a local plus a cast.

## Unions

- Narrow a union to one member with `Must.be_a(value, Klass)`, never `#: as Klass`.
- End a `case` that handles every member of a union with `else value #: absurd`. Sorbet then reports any member added later that no arm handles. An `else raise` there is reported as unreachable code.
- Sometimes a precise parameter type makes the method's own runtime guard unreachable (7006).
  - If the guard checks caller-supplied or wire input, declare the parameter wider, as the common base class, `Object` or `untyped`, so the guard stays live. Never delete validation of external input to please the checker.
  - Otherwise keep the precise type and remove or report the dead guard.
- Use `untyped` only for values that really are heterogeneous:
  - a value-or-callable dispatched on `respond_to?(:call)`;
  - a box holding arbitrary secrets;
  - a protobuf message class chosen at runtime;
  - `**options` forwarded into a dependency.

  Never use it to silence an error on a parameter.

## Must

Copy this module into a project that lacks it.
- In a Rails app it goes in `app/models/must.rb`.
- In a gem it goes in `lib/<gem>/must.rb` as `<Gem>::Must`.
- Make `Violation` a direct subclass of `StandardError`, not of the library's error base, so the library never renders it as a domain error.
- Add a spec. It should check that the value is returned, that `Violation` carries the block's message, and that the block is not called when the value is present.

```ruby
# typed: strict
# frozen_string_literal: true

# Runtime counterpart of Sorbet's T.must for a value the type checker cannot
# prove present. The reason names the invariant that makes it so.
module Must
  class Violation < StandardError; end

  #: [T] (T? value) { () -> String } -> T
  def self.because(value, &_block)
    case value
    when nil then raise Violation, yield
    else value
    end
  end

  #: [T] (T? value) -> T
  def self.expect(value)
    case value
    when nil then raise Violation, "expected a value, got nil"
    else value
    end
  end

  #: [T] (untyped value, Class[T] klass) -> T
  def self.be_a(value, klass)
    case value
    when klass then value
    else raise Violation, "expected #{klass}, got #{value.class}"
    end
  end
end
```

Calling `value.nil?` on an unconstrained type parameter is an error (7038), which is why the module narrows with `case`. Unlike a redundant cast (7015), a redundant `Must` call is not reported, so remove stale ones by hand.

## Concerns and mixins

- If a concern calls methods of the class that includes it, declare that class above `module` with `# @requires_ancestor: ActiveRecord::Base`. This needs `--enable-experimental-requires-ancestor` in `sorbet/config`, and you can write one line per ancestor.
- Where that does not apply, for example in a `ClassMethods` body or a lambda such as `default from: -> { ... }`, make the first line of the method or lambda body `#: self as ApplicationController`.
  - Never alias self (`x = self #: as Host`).
  - Never add `_controller`-style accessors.
  - Never reach the host through `send`.
- Inside such a module, cast `self.class` with `#: as singleton(Host)`. When the module also needs its own class methods, cast to an intersection: `#: as singleton(ActiveRecord::Base) & Foo::ClassMethods`.
- If a bare module calls `raise`, `loop` or `caller_locations`, add `include Kernel` to the module and call the method plainly. Never write `Kernel.raise`.
- Sorbet cannot see methods or `include`s added inside an `included do` block. Include the module directly in the class, or declare the method in a shim.

## Data.define

- Write `Foo = Data.define(:a, :b)`, never `class Foo < Data.define(...)`. Sorbet cannot resolve a computed superclass. To add a constant, reopen the class with `class Foo` after the assignment.
- Generated readers have no inline form. Declare them in `sorbet/rbi/shims/data_define.rbi`:
  ```ruby
  # typed: strict

  # Sorbet synthesizes the readers of a `Data.define` class without signatures,
  # which a `# typed: strict` file cannot supply inline.

  class Checkout::Result
    sig { returns(Invoice) }
    def invoice; end
  end
  ```
- Sorbet types the generated `initialize` with positional parameters. A keyword constructor with validation or defaults would then need `allocate.tap { send(:initialize, ...) }`. Write a plain class instead, with a keyword `initialize`, readers, `==`, `eql?`, `hash` and `freeze`.

## Shims before casts

- When a gem defines methods at load time, write an RBI in `sorbet/rbi/shims/<gem>.rbi` with a one-line comment saying why tapioca cannot see the method. One shim fixes every call site, while a cast fixes one. Ways a gem can hide a method from tapioca:
  - `class_eval` in an `included` hook
  - `method_missing` delegation
  - reopening a class after `tapioca gem` has run
  - `Mapper.include(Routing)` at load time
- Write a shim too when a community annotation contradicts this app. For example, `Time.current` returns `ActiveSupport::TimeWithZone` whenever `config.time_zone` is set.
- Stale RBIs are regenerated, not shimmed:
  - run `tapioca gem` after `Gemfile.lock` changes;
  - run `tapioca dsl` after adding a model, a column or an association.
- See `references/known-gaps.md` for shims that most Rails apps need.

## Rails specifics

- Write a class-level validation condition as `if: ->(record) { record.purpose == ... }`. Sorbet types the `self` of a bare `-> { }` block as the class, not the record.
- Rewrite `alias_method :revoked?, :discarded?` as `def revoked? = discarded?` when the target comes from a module. Sorbet resolves aliases before it applies module inclusion.
- Mailer actions and job `perform` methods have no `initialize` of their own, so their instance variables stay nilable.
  - A local can carry the non-nil value within the action.
  - Across methods, give the variable a private reader built on `Must.because`.
- Tapioca types `NOT NULL` columns as non-nil, but an unsaved record can still hold nil. A validator that checks presence has to read the column through a local.

## Comments

- A note explaining a Sorbet quirk is never part of a doc comment. Doc comments are the contract for callers.
- If the code is self-explanatory (`def revoked? = discarded?`), write no comment.
- If the shape of the code needs a reason, such as keywords spelled out instead of `**`, write one line inside the method body.
- A file held below `strict` names the Sorbet limitation in its commit message. If the limitation is general, also record it in the project's `docs/type-checking.md` Known gaps section.

## Specs

- A spec that builds `Class.new do def initialize(...) end end`, or defines `def self.name` on an anonymous class, leaks into `Object` for the whole project. The symptom is an unrelated `Foo.new` reporting keyword or arity errors against `Object#initialize`, or `Class#name` appearing private. Give that spec `# typed: ignore`.
- Run the specs that cover typed files after any change beyond pure annotations: restructuring, raising readers, or new guards.

## References

- **`references/known-gaps.md`**: Sorbet error codes and limitations, each with its workaround, plus shims commonly needed in Rails apps
- <https://sorbet.org/docs/rbs-support> for the inline RBS comment syntax
