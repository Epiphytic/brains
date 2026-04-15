---
name: suggest
description: This skill should be activated when a task involves significant complexity — multiple components, cross-cutting concerns, unfamiliar codebases, architectural decisions, or multi-step implementations. It suggests the BRAINS workflow to the user without auto-invoking it.
user-invocable: false
---

# BRAINS Complexity Detection

Assess incoming tasks for complexity signals and suggest the BRAINS workflow when warranted. Never auto-invoke BRAINS — only recommend it to the user and let them decide.

## Complexity Signals

Flag the task as BRAINS-worthy when **two or more** of these signals are present:

- **Multi-component scope**: Task touches 3+ files, modules, or services
- **Cross-cutting concerns**: Changes span multiple architectural layers (API, database, UI, infra)
- **Architectural decisions**: Task requires choosing between fundamentally different approaches
- **Unfamiliar territory**: Working in a codebase or domain with no prior context
- **Integration risk**: Changes affect external APIs, shared state, or other teams' code
- **Security surface**: Task involves auth, permissions, user input handling, or secrets
- **Ambiguous requirements**: The request leaves significant design decisions unspecified
- **Greenfield work**: Building a new system, service, or major feature from scratch

## Assessment Process

1. Read the user's request carefully
2. Scan for complexity signals listed above
3. If two or more signals are present, suggest BRAINS
4. If only one signal is present but it's strong (greenfield, major architectural decision), still suggest

## Suggestion Format

When complexity warrants BRAINS, present a brief, non-intrusive suggestion:

```
This looks like it could benefit from a structured approach. The BRAINS workflow
can help with [specific complexity identified — e.g., "exploring the design space
before committing to an architecture" or "ensuring the security implications are
covered"].

/brains:brains <topic>

This starts phase 1 (interactive research + questionnaire + ADR). On ADR
approval it chains into /brains:map (phase 2: plan + beads tasks), and then
/brains:implement (phase 3: teammate-executed implementation with per-phase
nurture and secure review).

Or just proceed directly if you prefer.
```

Tailor the suggestion to the specific complexity detected. Do not use generic language — name the specific signals observed.

## When NOT to Suggest

- Simple bug fixes with clear root cause
- Single-file changes with obvious implementation
- Documentation updates
- Configuration changes
- Tasks the user has explicitly said to "just do"
- Tasks where BRAINS is already in progress

## Key Constraint

**Never auto-invoke any BRAINS skill.** The user decides whether to use the workflow. The suggestion is advisory only.
