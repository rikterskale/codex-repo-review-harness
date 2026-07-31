# Security-Focused Review Prompt (Read-Only)

Use this in addition to (or instead of) the system review prompt when you want a security-first pass.

## Priority checklist
1. Secrets & credentials in source (API keys, tokens, passwords, private keys).
2. Injection risks (SQL, command, template, XSS, path traversal).
3. Authentication / authorization gaps or bypasses.
4. Insecure deserialization or unsafe eval / dynamic code execution.
5. Missing input validation on external data.
6. Overly permissive CORS, open redirects, or SSRF.
7. Dependency risks that are obvious from lockfiles (known vulnerable patterns).
8. Logging of sensitive data.

## Rules
- Treat any hard-coded secret as **critical**.
- Prefer false negatives over flooding the report with theoretical issues.
- For every finding, state the concrete exploit scenario if possible.
- Still obey the global read-only constraints: never modify files.

Output the same Markdown report structure as the system review prompt.
