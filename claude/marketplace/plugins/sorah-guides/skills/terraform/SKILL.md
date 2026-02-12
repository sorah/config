---
name: Terraform Conventions
description: This skill should be used when writing or reviewing Terraform code, or when the project uses "Terraform", "HCL", "tfvars", "aws_iam_role", "data sources", or infrastructure-as-code patterns. Provides Terraform coding conventions, patterns, and best practices. Project-specific conventions always take priority.
version: 0.1.0
---

# Terraform Conventions

Coding conventions and best practices for Terraform projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## General Conventions

- Prefer data sources over hardcoded values (e.g., `data.aws_region.current`, `data.aws_caller_identity.current`)
- Use locals for computed values and merging configuration
- Use `jsonencode` to compose JSON objects instead of raw string literals

## Resource Naming

- Use snake_case for all resource names and variables, with exceptions:
  - Resource name in Terraform should match the actual resource name in the provider (e.g., when `name = "FooBar"`, use `resource "..." "FooBar"`)
- IAM role and policy names use PascalCase (e.g., `Ec2Bastion`, `EcsApp`)
- Use hyphenated lowercase for resource identifiers (e.g., `ec2-default`, `dns-cache`)

## File Organization

Standard file structure per Terraform directory:

- `aws.tf` — AWS provider configuration with standard data sources (`data.aws_region.current`, `data.aws_caller_identity.current`, `data.aws_default_tags.current`)
- `backend.tf` — S3 backend configuration
- `versions.tf` — Provider version constraints
- Resource-specific files: `vpc.tf`, `sg.tf`, `route53.tf`, `iam.tf`, etc.
- Multiple IAM files when needed: `iam_lambda.tf`, `iam_states.tf`, `iam_ec2_default.tf`
- `outputs.tf` — Output definitions (when needed)
- `locals.tf` — Local values (when needed)

## Variable Definitions

- Always specify `type` for variables
- Use `default = {}` for optional map variables
- Group related variables together with blank lines

## Resource Arguments

- Multi-line arguments consistently formatted
- Use trailing commas in lists
- Align equals signs for readability in blocks

## AWS-Specific

- Use `data.aws_iam_policy_document` whenever possible instead of `jsonencode`
- Use AWS managed policies via `data.aws_iam_policy` when available

### Tags and Metadata

- Use `default_tags` at provider level for Project and Component tags
- Include meaningful resource-specific tags when needed

### IAM Roles (`aws_iam_role`)

- Trust policies use separate `data.aws_iam_policy_document` with `-trust` suffix
- Split policies into multiple documents when they get large
- Use specific resource ARNs; avoid wildcards where possible
- Role names use PascalCase (e.g., `NetKea`, `NwEc2Default`)
- Include descriptive `description` field referencing the Terraform path

### IAM Instance Profiles (`aws_iam_instance_profile`)

- Name should match the associated IAM role name
- Use `aws_iam_role.Role.name` for both `name` and `role` attributes
