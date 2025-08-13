# Claude Code Personal Preferences

This file contains my personal preferences for Claude Code.

## General Instructions

- Follow existing code conventions and patterns in each project
- Prefer editing existing files over creating new ones
- When writing a throwaway script, prefer Ruby (except in the case human request or the project has another preference) and bundler/inline for its dependencies

## Code Quality Standards

- Throw errors instead of silently ignoring them (unless explicitly instructed otherwise)
- Do not leave empty lines containing only whitespace
- Write clean, readable code that follows language conventions
- Use consistent indentation and formatting

## Using Gemini AI

When analyzing large codebases or multiple files that might exceed context limits or you want to search the web, use the Gemini CLI with its massive context window. Use `gemini -p` to leverage Google Gemini's large context capacity.

## File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the
gemini command:

### How to use

- Single file analysis: gemini -p "@src/main.py Explain this file's purpose and structure"
- Multiple files: gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"
- Entire directory: gemini -p "@src/ Summarize the architecture of this codebase"
- Multiple directories: gemini -p "@src/ @tests/ Analyze test coverage for the source code"
- Current directory and subdirectories: gemini -p "@./ Give me an overview of this entire project"
- Web search: gemini -p "WebSearch: oauth 2.0 security best practices rfc"

### Implementation Verification Examples

Check if a feature is implemented: gemini -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"
Verify authentication implementation: gemini -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"
Check for specific patterns: gemini -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"
Verify error handling: gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"
Check for rate limiting: gemini -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"
Verify caching strategy: gemini -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"
Check for specific security measures: gemini -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"
Verify test coverage for features: gemini -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"

### When to Use Gemini CLI

Use gemini -p when:
- Analyzing entire codebases or large directories
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase

### Important Notes

- Paths in @ syntax are relative to your current working directory when invoking gemini
  - The CLI will include file contents directly in the context
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results # Using Gemini CLI for Large Codebase Analysis

## Language-Specific Style Guides

**CRITICAL REQUIREMENT**: Before writing or modifying ANY code in the following languages, you MUST first read and apply the corresponding style guide. This is non-negotiable.
**Enforcement**: If you write code without following these style guides, the code will be considered incorrect and must be rewritten.

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

### Git Commit

#### First Line (Summary)
- Try to keep total length under 50 characters
- Start with `{component_name}: ` prefix when possible
  - Component name can be shortened filename or directory name
  - Omit prefix if it would make the line too long
- Use imperative mood (e.g., "Add feature" not "Added feature")
- Use more contextful verbs than "Change", "Add", "Fix" or "Update"
- Try to explain the "why" of the change, not just the "what"

#### Additional Lines
- Leave second line empty
- Add detailed explanation, background, or reasoning in subsequent lines
- Include relevant context that helps reviewers understand the change

## File Management

- Never create files unless absolutely necessary
- Always prefer editing existing files to creating new ones
- Do not proactively create documentation files (*.md, README) unless explicitly requested
- When working with a temporary file, temporary script, or temporary output, create them in `tmp/` directory under the repository root. No need to delete.

## Git GPG Signing

- When encountered git commit error due to 'gpg: signing failed: Inappropriate ioctl for device', ask human to unlock their signing key instead of skipping signature.
