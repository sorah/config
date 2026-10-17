---
name: rails-protobuf
description: This skill should be used when building, extending, or reviewing a Rails app whose API schema is Protocol Buffers, served with connect_rpc_rails (Connect RPC as controller actions) and protobufable (protobuf request bodies, responses, columns, errors). Use it when adding an RPC, a `.proto` message, a `buf.validate` rule, a protobuf-bound Alba resource, a message stored in a `jsonb` column, or a problem type in a protobuf enum, even if the user only says "add an endpoint" in such an app. Signs include `ConnectRpcRails::Controller`, `connect_service`, `connect_request`, `protobuf_body`, `message`, `render proto_json:`, `with_protobuf`, `Protobufable::JsonType`, `Protobufable::Problem::Typeable`, `buf.gen.yaml`, `*_pb.rb`, or the user mentioning "Connect", "protobuf", "protovalidate", "buf". Project-specific conventions always take priority.
version: 0.1.0
---

# Protobuf-native Rails

Conventions for a Rails app whose `.proto` files are the schema of record: requests, responses, errors and structured columns are generated messages, never Hash literals. The stack:

- [connect_rpc_rails](https://github.com/ivry-inc/connect_rpc_rails): Connect unary RPCs as `ActionController::API` actions, routed from the service descriptor.
- [protobufable](https://github.com/sorah/protobufable): `protobuf_body` request bodies, `render proto_json:`, Alba resources bound to messages, messages in columns, a problem catalogue in a protobuf enum, and Connect error rendering for problems.
- [protovalidate](https://github.com/sorah/protovalidate-rb): `buf.validate` rules on requests and columns.
- [problem](https://github.com/sorah/problem): RFC 9457 errors. Read /sorah-guides:rails-problem for the error model itself.

Examples come from [ruby-no-kai/sponsor-app](https://github.com/ruby-no-kai/sponsor-app) (`docs/protobuf.md` there is the long-form tour). Project-specific conventions (CLAUDE.md, `docs/`) always take priority. For Sorbet details read /sorah-guides:sorbet; the protobuf-specific gaps are in `references/limits.md`.

## Layout and generation

| Concern | Where |
|---|---|
| Schema | `proto/<org>/<app>/*.proto`, a buf module, one package, `option ruby_package` set |
| Generated Ruby + RBS | `gen/proto/ruby/` as a path gem the `Gemfile` loads |
| Generated TypeScript | `ui/src/gen/` (protoc-gen-es) |
| Connect controllers | `app/controllers/api/<service>/` |
| Response builders | `app/resources/api/` (Alba) |
| Problem catalogue | `proto/.../problem.proto`, `app/models/errors.rb` |
| Storage messages | `proto/.../internal/`, never reachable from a service |

- One task regenerates everything (`mise run gen`: `buf build`, `buf generate` per template, then `tapioca dsl --only=Protobuf`). Generated files are committed; CI reruns generation and fails on a dirty tree. Regenerate after every `.proto` edit, comment-only ones included, since comments become JSDoc.
- `buf build` runs first so a `.proto` that does not compile leaves `gen/` untouched.
- Message classes cannot reload (a duplicate descriptor raises), so they load once through Bundler and the dev server restarts when `gen/` changes. Do not put `_pb.rb` under Zeitwerk.
- Vendored `.proto` from a gem (`proto/protobufable/`) is excluded from Ruby generation, as the gem ships its own Ruby; a second copy of a descriptor fails boot. Guard the vendored copy with a spec comparing it to the gem's.
- Proto doc comments are user-facing documentation. Write them for API clients.

## Connect RPC controllers

Route each service in `config/routes.rb`, one `connect_service` block per service:

```ruby
connect_service 'rubykaigi.sponsor_app.AdminService' do
  rpc 'GetPlan' => 'api/admin/plans'
  rpc 'CreatePlan' => 'api/admin/plans'
end
```

A controller defines one action per RPC, in snake case, takes no arguments and returns the response message. Keep actions thin: read `connect_request`, look up, save, build the response through a resource.

```ruby
class PlansController < Api::Admin::ApplicationController
  authorize :conference
  #: () -> Rk::SponsorApp::AdminServiceGetPlanResponse
  def get_plan
    Rk::SponsorApp::AdminServiceGetPlanResponse.new(plan: admin_plan_message(find_plan))
  end

  #: () -> Plan
  private def find_plan
    plan_id = connect_request.plan_id #: Integer
    conference.plans.find_by(id: plan_id) || raise(Errors::NotFound.new(
      detail: "The conference #{conference.slug.inspect} has no plan #{plan_id}.",
    ))
  end
end
```

- The API base controller (`Api::ApplicationController < ActionController::API`) includes, in order: `ConnectRpcRails::Controller`, `ConnectRpcRails::MessageValidatable`, `Protobufable::Connect::ProblemRescuable` (after `Controller`), then app concerns. Each service gets a base controller calling `connect_service` and enforcing that service's policies.
- Cross-cutting logic is plain `before_action`/`rescue_from`; there is no interceptor layer.
- Order of checks: authenticate, then validate the request message, then authorize. A policy that looks up a resource then sees only valid input. sponsor-app declares a policy per RPC (`authorize :conference` above the `def`) and raises when an RPC has none.
- `connect_request` is untyped under Sorbet: read each field into a local declared with its type (`slug = connect_request.conference_slug #: String`).
- RPCs free of side effects declare `option idempotency_level = NO_SIDE_EFFECTS;` so clients may use GET. Everything else is POST only.
- Browsers are protected without a CSRF token by refusing POSTs lacking `Connect-Protocol-Version` and cross-site `Sec-Fetch-Site`/`Origin` (`ConnectForgeryProtection` in sponsor-app). Do not grant CORS preflights for the API.

## Request validation

Write rules on the field in the `.proto` with `buf.validate`. For a rule whose message a person reads, use a CEL rule with a stable `id`; the `id` becomes the `reason` a client sees and is never reused.

```proto
string name = 1 [(buf.validate.field).cel = {
  id: "conference.name.not_blank"
  message: "value must not be blank"
  expression: "this.trim() != ''"
}];
```

- `ConnectRpcRails::MessageValidatable` answers a violation with `invalid_argument` and a `google.rpc.BadRequest`, field paths in the encoding the request used.
- Call `Protovalidate.register_all` in `config.after_initialize` so a broken CEL expression fails boot, not the first request.
- Rules needing the database stay as model validations; their failure surfaces as an invalid-record problem.
- Guard costly CEL in the expression (`this.size() > 50 || this.all(...)`); a size rule beside it does not short-circuit.

## Errors

The catalogue is a protobuf enum whose values carry their published `uri` and `http_status` through an enum value option. Declare the extension in your own `.proto` with an internal-use number (50000-99999):

```proto
extend google.protobuf.EnumValueOptions {
  optional protobufable.ProblemTypeOptions problem_type = 50001;
}

enum ProblemType {
  PROBLEM_TYPE_UNSPECIFIED = 0;
  PROBLEM_TYPE_NOT_FOUND = 3 [(problem_type) = {uri: "not-found", http_status: 404}];
}
```

```ruby
class ApiError < StandardError
  include Protobufable::Problem::Typeable
  def self.problem_type_enum = 'rubykaigi.sponsor_app.ProblemType'
  def self.problem_type_annotation = 'rubykaigi.sponsor_app.problem_type'
end

class NotFound < ApiError
  problem_type :PROBLEM_TYPE_NOT_FOUND
end
```

- A value the enum lacks, or one without the annotation, raises at class definition, so a typo fails boot.
- Over Connect, `Protobufable::Connect::ProblemRescuable` maps the status to a Connect code (401 `unauthenticated`, 403 `permission_denied`, 404 `not_found`, 409 `aborted`, 412 `failed_precondition`, 422 `invalid_argument`, 500 `internal`) and packs a `protobufable.ProblemDetails` into `details`. Clients dispatch on its `type`; enum names never go on the wire.
- Append a `google.rpc.RequestInfo` with the request ID to every Connect error (override `render_connect_error`, and the exceptions app for escaped errors), so a reported error leads to its logs.
- A classified non-problem exception's message can quote internals; replace it with the status text in `connect_error_for`.
- `Protobufable::Problem::Information` adds packed `google.rpc.*` details. sponsor-app's `Errors::InvalidRecord` publishes each model error on an attribute the request's Input declares as a `BadRequest` violation of that field, and errors on `:base` or unknown attributes as request-wide.
- Values and identifiers are append-only.

## Inputs and saving

A Create or Update request carries its `<Resource>Input` in a field named `input`. The action copies Input fields to attributes explicitly and calls `update!`/`save!`; `RecordInvalid` becomes the invalid-record problem on `input.*` fields.

```ruby
private def save_input!(plan)
  input = connect_request.input #: Rk::SponsorApp::PlanInput
  plan.update!(
    name: input.name,
    summary: input.has_summary? ? input.summary : nil,
    closes_at: input.closes_at&.to_time,
  )
end
```

Format rules live on the Input as `buf.validate`. While a non-API form still saves through the model, keep a model validation too and hold both to the same verdict with a parity spec over sample values.

## Responses from Alba resources

Never assemble a response field by field in a controller. A resource binds to its message with `with_protobuf`, which compares attributes to the descriptor at load time and raises on drift:

```ruby
class AdminPlanResource < Api::ApplicationResource # includes Alba::Resource, Protobufable::AlbaBinding
  with_protobuf Rk::SponsorApp::AdminPlan do
    attributes :id, :name, :rank, :capacity
    attributes :summary, if: proc { |plan| plan.summary.present? }
    attributes closes_at: :timestamp, if: proc { |plan| plan.closes_at }
    attribute(:price) { |plan| plan.price.to_s }
  end
end

Api::AdminPlanResource.new(plan).as_protobuf
```

- Register the `:timestamp` type once (`Protobufable::AlbaBinding.register_timestamp_type!`); a Timestamp field refuses `TimeWithZone`.
- A nullable column is an `optional` field left unset with `if:`, or its empty value when the message holds a plain scalar.
- Decimals and money are strings.
- A resource's object is never an Array or Relation (Alba treats any `Enumerable` as a collection); wrap grouped data in a `Data`.

## Plain JSON endpoints (non-Connect)

For non-Connect JSON endpoints, declare the body message above the action and read `message` instead of `params`:

```ruby
class ExpenseLineItemsController < ApplicationController
  include ProtobufRequestBody # wraps Protobufable::RequestValidatable

  protobuf_body Rk::SponsorApp::ExpenseLineItemPatch
  def update
    line_item.assign_attributes(line_item_attributes(message))
    # ...
  end
end
```

- A body that does not decode, names an unknown field, or breaks a rule is a 400 before the action runs. The message logs as `[FILTERED]`.
- Respond with `render proto_json:` (ProtoJSON, defaults omitted) built from a bound resource.
- A partial update names the fields it writes in a `repeated string field_mask` of `.proto` names. `optional` alone cannot tell "clear" from "leave", and `google.protobuf.FieldMask`'s JSON form is a lowerCamelCase string that upb refuses `_` in.

## Messages in columns

```ruby
attribute :fallback_options,
  Protobufable::JsonType.new(Rk::SponsorApp::Internal::FallbackOptions, preserve_proto_fieldnames: true),
  default: -> { Rk::SponsorApp::Internal::FallbackOptions.new }
```

- Use `jsonb`. Storage messages live in an `internal` package that no RPC reaches; the API publishes its own message and code copies between the two field by field. A spec compares their descriptors, rules included.
- `ApplicationRecord` includes `Protobufable::ColumnValidatable`, so `buf.validate` rules also guard console writes.
- Shape changes migrate stored documents in SQL, without loading models or message classes.
- Tapioca types the attribute `untyped`; declare the reader in `sorbet/rbi/shims/<model>.rbi`.

## Testing

- Request specs call RPCs the way a client does, through a helper that encodes JSON or binary, POST or GET, and decodes either the response message or a Connect error with its details (sponsor-app `spec/support/connect_helper.rb`: `connect_method`, `connect_call`, `violations_of`, `problem_type_of`).
- Assert whole messages with `eq(ExpectedMessage.new(...))`, presence with `has_foo?`, and errors by problem `type` and `[field, reason]` violations.
- For a GET-able RPC, check that GET and binary POST answer the same as JSON POST.
- A descriptor-walking spec over every RPC of every service enforces the invariants: routed to an action, policy declared, Input carried in `input`, no `internal` type reachable (sponsor-app `spec/proto/services_spec.rb`).

## Additional resources

- `references/limits.md`: proto3 and ProtoJSON semantics that shape the schema, generated-code pitfalls, and Sorbet gaps (`message` unions, `connect_request`, tapioca requires).
