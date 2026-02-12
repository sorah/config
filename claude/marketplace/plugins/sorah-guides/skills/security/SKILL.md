---
name: Security Review
description: This skill should be used when reviewing code for security vulnerabilities, performing security audits, or when the user asks about "security review", "vulnerability", "XSS", "CSRF", "injection", "race conditions", "OAuth security", "OIDC pitfalls", "timing attacks", or "access control". Provides a comprehensive vulnerability taxonomy and review methodology.
version: 0.1.0
---

# Security Review Guide

Comprehensive vulnerability taxonomy and review methodology for code security reviews. Project-specific security policies (CLAUDE.md, security docs) always take priority over this guidance.

## Common Vulnerability Classes

### Injection
- **SQL injection**: Unsanitized user input in queries; use parameterized queries or ORM query builders
- **Command injection**: User input passed to shell commands; avoid shell execution or use strict allowlists
- **LDAP injection**: Unsanitized input in LDAP queries
- **Header injection**: User input in HTTP headers enabling response splitting

### Cross-Site Scripting (XSS)
- **Reflected**: User input echoed in responses without encoding
- **Stored**: Persistent user input rendered without encoding
- **DOM-based**: Client-side JavaScript manipulating DOM with unsanitized data

### Cross-Site Request Forgery (CSRF)
- Missing or weak CSRF token validation
- Token not bound to user session
- GET requests performing state changes

### Authentication Flaws
- Weak credential handling or storage
- Insecure session management
- Missing authentication checks on protected endpoints

### Authorization Flaws
- Broken access control, privilege escalation
- Insecure Direct Object References (IDOR)
- Missing tenant isolation in multi-tenant systems

### Cryptographic Issues
- Weak algorithms (MD5, SHA1 for security purposes)
- Improper key management or hardcoded secrets
- Insufficient entropy in token/nonce generation

### Information Disclosure
- Sensitive data in logs, error messages, or API responses
- Stack traces or debug info exposed in production
- Credentials or tokens in URLs

### Insecure Deserialization
- Unsafe parsing of untrusted data formats
- Object instantiation from user-controlled input

## Domain-Specific Concerns

### Race Conditions
- **TOCTOU bugs**: Time-of-check-to-time-of-use allowing business logic violations (double-spending, duplicate issuance)
- **Concurrent access**: Missing locking or optimistic concurrency control on shared resources

### OAuth 2.0 Pitfalls
- Token leakage via referrer headers or logs
- Insufficient scope validation
- Redirect URI manipulation (open redirect, partial matching)
- Authorization code replay
- PKCE bypass or missing PKCE enforcement
- Refresh token rotation issues

### OpenID Connect Pitfalls
- ID token validation gaps (signature, expiry, issuer, audience)
- Nonce misuse or missing nonce validation
- `at_hash` / `c_hash` verification omitted
- Issuer confusion in multi-provider setups

### Session Security
- Session fixation or hijacking
- Insufficient expiration (idle and absolute timeouts)
- Cookie attribute misconfiguration (missing Secure, HttpOnly, SameSite)

### Timing Attacks
- Non-constant-time comparisons on secrets, tokens, or hashes — all secret comparisons (passwords, tokens, HMAC digests, API keys) must use constant-time operations (e.g., `ActiveSupport::SecurityUtils.secure_compare`, `hmac.compare_digest`, `crypto.timingSafeEqual`)
- Observable timing differences in authentication flows (e.g., different response times for valid vs invalid usernames)
- Database lookups that short-circuit on missing records before performing credential verification

## Review Methodology

1. **Read the actual code** — do not rely on summaries or assumptions; open and read every file under review and follow references to understand the full call chain
2. **Analyze each change** against the vulnerability classes above
3. **Check surrounding code** — vulnerabilities often arise from interactions between new and existing code
4. **Verify both presence and absence** — confirm mitigations exist where needed, and note areas reviewed that appeared secure

## Severity Classification

- **Critical**: Remotely exploitable, no authentication required, leads to full system compromise or mass data breach
- **High**: Exploitable with low complexity, leads to significant data exposure or privilege escalation
- **Medium**: Requires specific conditions to exploit, limited blast radius
- **Low**: Minor issue, difficult to exploit, minimal impact
- **Informational**: Best practice deviation, defense-in-depth recommendation
