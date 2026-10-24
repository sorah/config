---
name: steep-adoption
description: This skill should be used when introducing static type checking to an existing Ruby library or gem, or when continuing such a rollout. It applies when the user asks to "add type checking to this gem", "adopt Steep", "add RBS signatures", "set up rbs-inline", "ship sig/ with the gem", "add a Steepfile", or "type this library", or asks to add types to a project with a `*.gemspec` and no Rails app, even if they do not name a checker. Provides the rollout playbook for libraries: a repository survey, decisions to settle up front, the infra commit, a green baseline, bottom-up typing, third-party signature gaps, and review. Pair with the steep skill, which defines how the types themselves are written. For Rails applications, use sorbet-adoption instead.
version: 0.1.0
---

# Steep Adoption

A playbook for bringing an untyped Ruby library to full Steep coverage with rbs-inline annotations. Libraries use Steep rather than Sorbet: RBS is what gems ship in `sig/` and what ruby/gem_rbs_collection serves, so the signatures a library writes for itself are the same ones its consumers load. Distilled from the gems `problem`, `protobufable`, `protovalidate-rb` and `typeid_rails`.

Load `sorah-guides:steep` before writing any annotation. That skill defines how types are written; this one decides order, scope and mechanics. For commits and PR bodies use `/sorah-guides:commit` and `/sorah-guides:pull-request`; for the CI job, `sorah-guides:github-ci`.

The rollout runs in this order:

1. Survey and decide
2. Infra commit
3. Typing, bottom-up
4. Review

## Lessons that shaped this playbook

- **Shipped stubs leak downstream.** A gem whose `sig/` declared `Rails::Railtie.initializer` collided with another gem declaring the same method, and the consumer had to `ignore` one of them in `rbs_collection.yaml`. Stubs of other gems' APIs go in `sig-stub/`, which the gemspec leaves out.
- **gem_rbs_collection can be stale or wrong.** Its google-protobuf entry stopped at 3.22, with a non-generic `RepeatedField` that contradicted the signatures protovalidate ships. A narrow local collection source fixed it, where a `sig/manual` file could not, because library RBS cannot reference project signatures.
- **Generated RBS can disagree with everything else.** `protoc --rbs_out` emitted a two-parameter `RepeatedField`. Generated Ruby is `ignore`d and typed by hand.
- **Unannotated methods pass silently.** rbs-inline generates `(untyped) -> untyped` for a method with no `#:`, and Steep's default diagnostics never mention it. Coverage has to be checked, not assumed from a green `steep check`.
- **A stale `sig/generated` checks the wrong shape.** An annotation can change without anyone regenerating, so the generated directory is committed and CI fails when it differs from a fresh run.

## Phase 0: Survey and decide

### Survey first

| Check | Why it matters |
|-------|----------------|
| Existing `sig/`, `Steepfile`, `sorbet/config` or `# typed:` sigils | Continue an existing style rather than replacing it; ask before switching checkers |
| Size: files and methods in `lib/` | One PR for a small gem; stacked PRs (the `sorbet-adoption` slice mechanics) once it passes a few dozen files |
| Runtime and optional dependencies, and whether gem_rbs_collection or the gem itself ships signatures for each | Plans `sig-stub/` files and local collection sources. `rbs collection install` lists what it found |
| Generated Ruby (`*_pb.rb`, parsers) | `ignore` in the Steepfile, typed by hand in `sig/manual` |
| Rails integration: concerns, `class_attribute`, `included do`, railtie, renderers | Needs self-type interfaces in `sig/manual` and narrow `steep:ignore` blocks |
| `class Foo < Data.define` or `Struct.new` subclassing | Rewrite to assignment plus reopening, in its own commit before typing |
| The gemspec's `files` list | `sig/generated` and `sig/manual` must ship; `sig-stub/`, `Steepfile` and `rbs_collection*` must not |
| Consumers that are Sorbet apps, and DSLs that generate methods | Such consumers read Ruby, not RBS. A tapioca DSL compiler under `lib/tapioca/` serves them, and is `ignore`d by Steep |
| Existing CI, hk and mise layout | The steep step joins whatever already runs RuboCop |

### Decisions

Settle these with the user through AskUserQuestion, recommended option first.

| Decision | Recommended default |
|----------|---------------------|
| Checker and syntax | Steep with rbs-inline (`#:` comments) generated into a committed `sig/generated`. Keep hand-written `sig/<gem>.rbs` if the project already has it |
| Scope | `lib/` only. Specs are never typed |
| Tooling dependencies | `rbs`, `rbs-inline` and `steep` as gemspec development dependencies (or Gemfile entries with `require: false`), no `sorbet-runtime` |
| Shipping | `sig/generated` and `sig/manual` in the gem; stubs of other gems in `sig-stub/`, unshipped |
| PR shape | Infra commit, then typing commits bottom-up, in one PR for a small gem. A large gem gets an infra PR and stacked slices |
| Target | Every method in `lib/` annotated, no `untyped` without a reason |

## Phase 1: Infra commit

`references/infra.md` has the file-by-file checklist with templates. In summary:

1. **Prep commits first.** Rewrite `class Foo < Data.define(...)` and similar patterns the checker cannot follow, each as its own behaviour-preserving commit.
2. **Dependencies.** Add the gems, `bundle install`.
3. **Configuration.** Write `Steepfile`, `rbs_collection.yaml` (ignoring development-only gems), and `.gitignore` for `.gem_rbs_collection/`. Run `bundle exec rbs collection install` and commit the lock file.
4. **Tasks.** `rake rbs` regenerates and validates, `rake steep` depends on it, and `default` runs specs and steep.
5. **Hooks and CI.** One hk step running `bundle exec steep check` with no file list, `sig/generated/**` excluded from linters, and a CI `steep` job that checks `sig/generated` is current. The lint job skips the steep step.
6. **Green baseline.** Stamp `# rbs_inline: enabled` on the root file and `version.rb`, generate, and run `bundle exec rake steep`. When the untyped remainder of `lib/` reports errors, list those paths under `ignore` in the Steepfile with a comment; each typing commit removes its own entries, so the list is the remaining work.
7. **Commit** as `build: type check with rbs-inline and steep`, with a body explaining that `sig/generated` is committed and checked, and what `sig/manual` is for.

## Phase 2: Typing, bottom-up

Order by call dependency, so each layer's callees are already typed:

1. Errors, constants, configuration
2. Value objects and `Data` types
3. Core logic
4. Mixins and concerns
5. Framework integration: railtie, renderers, Rack apps, controllers' helpers
6. Optional integrations loaded by a separate `require`

For each file or group:

1. Run `scripts/stamp_rbs_inline.rb` on the files.
2. Annotate every method, constant, attribute and instance variable, following the `steep` skill.
3. Add what inline annotations cannot express to `sig/manual`, and third-party gaps to `sig-stub/` or a local collection source, each with a header comment saying why.
4. Remove the files' Steepfile `ignore` entries, and run `bundle exec rake steep` and the specs.
5. Commit the annotations, the regenerated `sig/generated` and the manual signatures together. A runtime change found while typing (a raise that replaces a silent nil, a fixed bug) is its own commit with a spec.

A suspected bug is never fixed silently inside an annotation commit. Report it, then fix it separately with a test.

## Phase 3: Review

1. Confirm coverage: grep `sig/generated` for `untyped`, and every `def` in `lib/` for a preceding `#:`. Each remaining `untyped` has a reason that fits the `steep` skill's escape hatches.
2. Grep `lib/` for `steep:ignore`, `# @type` and trailing `#:` casts on locals. Each needs a one-line reason and should not hide a nil.
3. Check the Steepfile `ignore` list holds only generated or Sorbet-only code.
4. Run `gem build` and list the package (`tar -xOf <gem> data.tar.gz | tar -tz`): `sig/` ships and `sig-stub/` does not.
5. Add a Types section to DESIGN.md: where signatures live, why `sig/generated` is committed, what `sig/manual`, `sig-stub/` and any local collection source hold, and which DSL blocks are `steep:ignore`d.
6. Mention typed signatures in the README only if the project lists features; a CHANGELOG entry notes that the gem now ships RBS.

## References

- **`references/infra.md`**: the infra commit checklist, with templates for the gemspec, Steepfile, `rbs_collection.yaml`, Rakefile, hk and the DESIGN.md section
- **`scripts/stamp_rbs_inline.rb`**: inserts `# rbs_inline: enabled` after the leading magic comments
