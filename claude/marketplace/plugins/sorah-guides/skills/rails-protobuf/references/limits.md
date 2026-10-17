# Limits and pitfalls

Facts about the protobuf-native Rails stack that shape schema and code. Read when designing a message, debugging an encoding mismatch, or typing protobuf code under Sorbet.

## ProtoJSON naming

- Connect JSON is canonical ProtoJSON, lowerCamelCase (`input.assignedSponsorshipIds`). Column storage (`preserve_proto_fieldnames: true`) and plain JSON endpoints (`render proto_json:`) keep `.proto` names. Violation field paths follow the encoding the request used.
- Renaming a field renames its JSON key, a breaking change for JSON clients even though the wire number is unchanged.
- An enum is a name in ProtoJSON and a `Symbol` or `Integer` in Ruby: an unknown value decodes as its number. Narrow with `is_a?(Symbol)` before mapping.
- protoc-gen-es types `int64` as `bigint`. A field a plain-JSON client reads needs `[jstype = JS_STRING]`, and the TypeScript then sees a string.

## Presence

- ProtoJSON decodes `null` on an `optional` field as unset, so `optional` cannot distinguish "clear" from "leave alone". Use a field mask list for partial updates.
- An unset `optional string` on an Input maps to a null column; an empty string is a value its rules judge (an optional URL sent as `""` fails its format rule).
- Repeated fields cannot be absent. When a response must say "absent", nest a wrapper message whose presence carries it.

## Validation

- A rule on the Input and a model validation are two implementations. RE2 anchors `^`/`$` on the whole text where Ruby anchors per line; `.+?` accepts whitespace. Parity specs hold only the samples they list.
- A request can pass protovalidate and still answer 422 from a database-backed model validation.
- protovalidate evaluates every rule on a field. A quadratic CEL expression raises past its iteration budget and answers 500; guard inside the expression.
- Two-variable comprehensions and `lists.range` are unavailable, so a rule cannot name a repeated element's position.
- Standard-rule messages are written for developers (`value does not match regex pattern`) and in English. Use CEL rules with messages for text a person reads, and validate localized forms client-side.

## Generated code in git

- The descriptor blob in `*_pb.rb` / `*_pb.ts` is one line; resolve a conflict in it by taking either side and regenerating.
- RPCs appended to one service conflict in its generated file. Group RPCs into sections in the service `.proto` and the routes block so hand-written conflicts stay small.
- A generator that deletes `*_pb.*` before regenerating breaks any process booting Rails meanwhile ("not in the descriptor pool").
- Try template changes with `buf generate` into a scratch directory first; a failure after the delete leaves `gen/` empty.

## Sorbet

- Sorbet ignores the `.rbs` protoc writes. `tapioca dsl --only=Protobuf` generates the message RBIs; run it as part of generation.
- `tapioca gem` sees only what a gem's entrypoint loads. List optional integrations in `sorbet/tapioca/require.rb`: `connect_rpc_rails/protovalidate`, `protobufable/alba_binding`, `protobufable/column_validatable`, `protobufable/connect`, `protobufable/protovalidate`.
- `connect_request` is untyped. Read a field into a typed local: `slug = connect_request.conference_slug #: String`.
- protobufable's tapioca DSL compiler types `message` as the declared class when every `protobuf_body` in the controller names the same one, and as their union otherwise. An action narrows the union with a typed local (`msg = message #: Foo`); RBI cannot vary a method's return type per action.
- `Protobufable::JsonType` attributes are untyped; declare the reader in a shim.
- A concern including another concern needs `mixes_in_class_methods` in a shim for Sorbet to see the inner `ClassMethods` (sponsor-app `sorbet/rbi/shims/protobuf_request_body.rbi`).
- Without `sorbet-runtime`, no `T.` forms: type request fields with `#:` comments on the reading line.

## Deployment

- A CDN that does not forward `Connect-Protocol-Version`, `Connect-Timeout-Ms` or `Sec-Fetch-Site` breaks Connect calls and forgery protection. Gate Connect routes behind a config flag (`config.x.connect_rpc.enabled`) until the edge forwards them.
- `connect-timeout-ms` is enforced with `Timeout.timeout`, which can interrupt the action anywhere.
- Unary only: no streaming, gRPC, gRPC-Web or request compression.
