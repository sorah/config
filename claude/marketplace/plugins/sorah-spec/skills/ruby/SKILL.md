---
name: Ruby Spec Interview
description: This skill should be used when conducting spec interviews or implementing specs for Ruby projects, or when the spec mentions "Ruby", "RSpec", "service objects", "Struct", or Ruby class/module patterns. Provides Ruby-specific interview and implementation checklist items.
version: 0.1.0
---

# Ruby Spec Interview Guide

Ruby-specific checklist for spec interviews and implementation. For underlying Ruby conventions, consult the `sorah-guides:ruby` skill. Project-specific conventions always take priority.

## Interview Checklist

When interviewing a spec for a Ruby project, verify these areas are fully specified:

### Architecture & Design
- Service object class names, method signatures, and return types
- Module/namespace hierarchy and file layout
- Which value objects use Struct/Data vs plain classes
- `include` vs `extend` decisions for shared behavior

### Behavior & Logic
- Method signatures: keyword arguments, required vs optional parameters
- Error handling: which specific exceptions are rescued and why
- Nil handling strategy for each interface boundary

### Testing
- RSpec structure: which spec types cover each component (unit, integration)
- Factory definitions needed for test data
- Error path and edge case coverage expectations

### Security
- Password/credential hashing algorithm and cost factor
- Token storage format (hashed, never plaintext)
- Secret comparison approach (constant-time)
