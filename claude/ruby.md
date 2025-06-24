#### General Conventions

- Explicit requires at top of file
- Use keyword arguments for methods with multiple parameters
- Prefer `attr_reader` over instance variable access
- Omit hash or keyword argument value when it is identical to key; `{foo:}` instead of `{foo: foo}`

#### Module and Class Structure

- Especially in AWS Lambda environment, initialize with dependency injection via `environment:` parameter

#### Method Definitions

- Use `def self.method_name` for class methods
- Short single-line methods when appropriate
- Use guard clauses for early returns

#### Error Handling

- Rescue specific errors (e.g., `Aws::S3::Errors::NoSuchKey`)
- Raise with descriptive messages

#### AWS SDK Usage

- Lazy initialize AWS clients as instance variables
- Pass logger to AWS clients
- Use symbolized keys for AWS responses

#### Constants

- Use SCREAMING_SNAKE_CASE for constants

#### Data handling

- Use `fetch` for required hash keys
- Use Hash#fetch or Array#fetch when appropriate, especially when the key or index is expected to exist.
- Consistent hash syntax with colons
- Use Struct or Data classes when creating structs instead of raw Hashes.

#### Logging

- Use structured logging with JSON when appropriate
- Log important operations (locks, state changes)
