---
name: secure
description: This skill should be used when the user asks to "secure", "security review", "check for vulnerabilities", "threat model", "security audit", "check for secrets", "OWASP review", or invokes "/brains:secure". Security review, vulnerability assessment, and threat modeling. Supports --single (default), --parallel, and --debate modes. When invoked by a phase-3 teammate with --scope phase-N, scopes the security review to changes in that plan-phase and files follow-up beads tasks for the next phase or cleanup.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--scope phase-N | all] [paths...]"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent
---

# Secure: Security Review and Hardening

Conduct a structured security review covering vulnerability assessment, threat modeling, dependency auditing, and secrets scanning. Fix critical issues found.

Set the plugin base path:
```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior

| Mode | Flow |
|------|------|
| `--single` | Local LLM reviews independently. **(default)** |
| `--parallel` | Review locally, then send to council for security review. |
| `--debate` | Multi-round security deliberation across LLMs. |

For `--parallel` and `--debate`, read and follow `$BRAINS_PATH/references/multi-llm-protocol.md`. Under `--lean`, read the compact excerpt at `$BRAINS_PATH/references/multi-llm-protocol-compact.md` instead; consult the full file only for debate-round synthesis or error handling.

## Scope

The `--scope` flag controls what secure reviews:

- `--scope phase-N` — review only files touched in the current plan-phase. File follow-up beads tasks labelled `brains:phase-<N+1>` if a next phase exists, else `brains:cleanup`. Invoked by phase-3 teammates.
- `--scope all` (default when invoked standalone) — classic behavior, reviews all recent changes.

## Process

### 1. Scope the Review

Determine what to review:

- **BRAINS outputs**: Check `docs/plans/` for architecture specs — identify the security surface from the design
- **Recent changes**: `git diff main...HEAD --stat` to scope changed files
- **User scope**: If specified, focus there. Otherwise, review the full security surface.

### 2. Secrets Scan

Check for hardcoded secrets, API keys, and credentials:

```bash
# Common secret patterns (use Grep tool for cross-platform reliability)
# Fallback shell command if Grep tool unavailable:
grep -rn -E '(api[_-]?key|secret|password|token|credential|private[_-]?key)\s*[:=]' . \
  --include='*.py' --include='*.js' --include='*.ts' --include='*.go' \
  --include='*.rs' --include='*.java' --include='*.yaml' --include='*.yml' \
  --include='*.json' --include='*.toml' --include='*.env' \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor \
  --exclude-dir=__pycache__ --exclude-dir=target --exclude-dir=.venv || true
```

Also check:
- `.env` files committed to git (should be in `.gitignore`)
- Hardcoded URLs with credentials
- Base64-encoded strings that might be keys
- AWS, GCP, Azure credential patterns

### 3. OWASP Top 10 Review

Evaluate the codebase against OWASP Top 10 categories:

| Category | What to Check |
|----------|---------------|
| Injection | SQL, command, LDAP injection in user input handling |
| Broken Auth | Session management, password handling, token validation |
| Sensitive Data | Encryption at rest/transit, PII handling, logging of secrets |
| XXE | XML parser configuration |
| Broken Access Control | Authorization checks, IDOR vulnerabilities |
| Security Misconfiguration | Default credentials, verbose errors, unnecessary features |
| XSS | Output encoding, CSP headers, DOM manipulation |
| Insecure Deserialization | Untrusted data deserialization |
| Vulnerable Components | Known CVEs in dependencies |
| Insufficient Logging | Security event logging, audit trails |

Focus on categories relevant to the project's stack and architecture. Skip categories that don't apply.

### 4. Dependency Audit

Check for known vulnerabilities in dependencies:

```bash
# Node.js
[[ -f package-lock.json ]] && npm audit --json 2>/dev/null | head -100 || true

# Python
[[ -f requirements.txt ]] && pip-audit -r requirements.txt 2>/dev/null || true

# Rust
[[ -f Cargo.lock ]] && cargo audit 2>/dev/null || true

# Go
[[ -f go.sum ]] && govulncheck ./... 2>/dev/null || true
```

If audit tools are not available, manually check key dependencies against known vulnerability databases.

### 5. Threat Modeling

For the system's architecture, identify:

- **Assets**: What data/resources need protection?
- **Trust boundaries**: Where does trusted code meet untrusted input?
- **Attack vectors**: How could each trust boundary be violated?
- **Mitigations**: What controls exist or are needed?

Use the STRIDE model where helpful:
- **S**poofing — authentication concerns
- **T**ampering — data integrity
- **R**epudiation — audit logging
- **I**nformation Disclosure — data leaks
- **D**enial of Service — resource exhaustion
- **E**levation of Privilege — authorization bypass

### 6. Council Review (if multi-LLM mode)

**Parallel mode:** Send findings and code to the council for security review:

```
Security review for [project].

[Architecture summary — focus on security surface]
[Files to review — focus on trust boundaries]
[Findings so far]

Evaluate:
1. Are there vulnerabilities we missed?
2. Are the identified risks correctly assessed?
3. Are there additional attack vectors to consider?
4. Are the proposed mitigations sufficient?
```

Use `star-chamber review` for code-focused security review.

**Debate mode:** Run multi-round security deliberation. Each round may focus on different threat categories.

### 7. Compile Security Report

Prioritize findings:

| Severity | Category | Finding | File(s) | Remediation |
|----------|----------|---------|---------|-------------|
| Critical | Injection | [description] | [files] | [fix] |
| High | Secrets | [description] | [files] | [fix] |
| Medium | Access Control | [description] | [files] | [fix] |
| Low | Misconfiguration | [description] | [files] | [fix] |

Present to the user. Get approval before fixing.

### 8. Remediate

Fix critical and high severity issues:

- Apply fixes one at a time
- Run tests after each fix
- Commit atomically with descriptive messages (e.g., `fix(security): sanitize user input in query builder`)
- Do NOT log or echo secrets in fix verification

For medium and low severity, recommend fixes but defer to user judgment.

## Output

Write the security report to `docs/plans/YYYY-MM-DD-<topic>-secure.md`:

```markdown
# Security Review: [Topic]

## Scope
[What was reviewed]

## Secrets Scan
[Results — clean or findings]

## OWASP Assessment
[Relevant findings by category]

## Dependency Audit
[Results — clean or vulnerable packages]

## Threat Model
[Assets, boundaries, vectors, mitigations]

## Findings
[Prioritized table of findings]

## Remediations Applied
1. [description] — [commit hash]

## Remaining Risks
[Accepted risks with justification]

## Council Feedback
[If multi-LLM mode was used]
```

Commit to git.

When invoked with `--scope phase-N`, additionally:

- Report file: `docs/plans/<slug>-phase-<N>-secure.md`
- Follow-up tasks filed to beads with label `brains:phase-<N+1>` (if next phase exists) or `brains:cleanup`.

Close the `Secure: phase <N>` umbrella task on completion.

## Phase Transition

Secure is the final BRAINS phase. After completion:

> "Secure phase complete. [N] findings: [X] critical, [Y] high, [Z] medium.
> [M] issues remediated. Security report committed to `<path>`.
>
> The BRAINS pipeline is complete. All phase outputs are in `docs/plans/`."

## Additional Resources

- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — shared multi-LLM invocation protocol
