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
