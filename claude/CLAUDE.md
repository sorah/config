# Claude Code Personal Preferences

This file contains my personal preferences for Claude Code.

## General Instructions

- Follow existing code conventions and patterns in each project
- Prefer editing existing files over creating new ones
- When writing a throwaway script, prefer Ruby (except in the case human request or the project has another preference) and bundler/inline for its dependencies

## Code Quality Standards

- Do not leave empty lines containing only whitespace
- Write clean, readable code that follows language conventions
- Use consistent indentation and formatting

### Error handling

- Avoid blanket exception handling (e.g. `rescue Exception`,`rescue StandardError`, `rescue` in Ruby) unless absolutely necessary
  - Error logging can be handled by runtime or frameworks
- Prefer letting exceptions propagate up the call stack, unless you have a specific reason to catch them, such as:
  - Add context to the error
  - Perform cleanup operations
  - Convert one exception type to another with additional information
  - Recover from expected error conditions
- Only catch specific exceptions when you have a meaningful way to handle them

### Code Comments

Comments should not repeat what the code is saying. Use comments for explaining **why** something is being done, or to provide context that is not obvious from the code itself.

**When to Comment:**

- To explain why a particular approach or workaround was chosen
- To clarify intent when the code could be misread or misunderstood
- To provide context from external systems, specs, or requirements
- To document assumptions, edge cases, or limitations

**When Not to Comment:**

- Don't narrate what the code is doing. The code already says that
- Don't duplicate function or variable names in plain English
- Don't leave stale comments that contradict the code
- Don't reference removed or obsolete code paths (e.g. "No longer uses X format")

## Language-Specific Style Guides

### Ruby

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

### Terraform


#### General Conventions

- Prefer data sources over hardcoded values (e.g., `data.aws_region.current`, `data.aws_caller_identity.current`)
- Use locals for computed values and merging configuration
- Use `jsonencode` to compose JSON objects, instead of raw string literal.
- Always include common data sources in aws.tf: `data.aws_region.current`, `data.aws_caller_identity.current`, `data.aws_default_tags.current`

#### Resource Naming

- Use snake_case for all resource names and variables, except the followings:
  - But resource name in Terraform should match the actual resource name in a provider. e.g. When there is an attribute like `name = "FooBar"`, then `resource "..." "FooBar"`.
- IAM role and policy names use PascalCase (e.g., `Ec2Bastion`, `EcsApp`)
- Use hyphenated lowercase for resource identifiers (e.g., `ec2-default`, `dns-cache`)

#### File Organization

**Standard File Structure**: Each Terraform directory should follow this pattern:
- `aws.tf` - AWS provider configuration with standard data sources
- `backend.tf` - S3 backend configuration
- `versions.tf` - Provider version constraints
- Resource-specific files: `vpc.tf`, `sg.tf`, `route53.tf`, `iam.tf`, etc.
- Multiple IAM files: `iam_lambda.tf`, `iam_states.tf`, `iam_ec2_default.tf`
- `outputs.tf` - Output definitions (when needed)
- `locals.tf` - Local values (when needed)

##### Variable Definitions

- Always specify `type` for variables
- Use `default = {}` for optional map variables
- Group related variables together with blank lines

##### Resource Arguments

- Multi-line arguments should be consistently formatted
- Use trailing commas in lists
- Align equals signs for readability in blocks


#### AWS specific instructions

- Use `data.aws_iam_policy_document` whenever possible, instead of jsonencode.
- Use AWS managed policies via `data.aws_iam_policy` when available

**Tags and Metadata**

- Use default_tags at provider level for Project and Component tags
- Include meaningful resource-specific tags when needed
- Use descriptive comments for non-obvious configurations

#### Resource and data source specific instruction

**aws_iam_role**
- IAM role trust policies use separate `data.aws_iam_policy_document` with `-trust` suffix
- IAM policies split into multiple documents when they get large
- Use specific resource ARNs in IAM policies, avoid wildcards where possible
- Role names use PascalCase (e.g., `NetKea`, `NwEc2Default`)
- Include descriptive `description` field referencing the Terraform path

**aws_iam_instance_profile**
- Name should match the associated IAM role name
- Use `aws_iam_role.Role.name` for both name and role attributes

### Git

- Follow the **Git Commit Style** skill (sorah-guides:commit-style) for commit message conventions including subject line style, prefix patterns, contextful verbs, and body guidelines.
- Avoid using `git -C` option as it would invalidate pre-approved permissions. Use `cd` to change working directory.

## File Management

- Never create files unless absolutely necessary
- Always prefer editing existing files to creating new ones
- Do not proactively create documentation files (*.md, README) unless explicitly requested
- When working with a temporary file, temporary script, or temporary output, create them in `tmp/` directory under the repository root. No need to delete.
  - Human usually declines using `/tmp` directory, outside of the project directory.

## Git GPG Signing

- When encountered git commit error due to 'gpg: signing failed: Inappropriate ioctl for device', ask human to unlock their signing key instead of skipping signature.
