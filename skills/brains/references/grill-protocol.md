# Grill Protocol — `--grill` Reference

Lazy-on-demand; load only when `--grill` is active (zero tokens on non-grill runs).

## 1. Operational Definition of "New Architectural Dimension"

An answer raises a new dimension if it satisfies **at least one** of:

- **(a)** Names a **component** not previously discussed.
- **(b)** Introduces a **constraint** (performance, compliance, SLA, capacity) not previously surfaced.
- **(c)** Names a new **actor or persona** (human role, external system, automated agent).
- **(d)** Introduces a new **data type or entity** (schema, persistent state, message type).
- **(e)** **Contradicts** a prior answer requiring re-litigation of an architectural decision.

Track consecutive answers where none of (a)–(e) apply; two consecutive triggers the convergence proceed-prompt.

## 2. Codebase-Exploration Substitution

**Budget: SHOULD perform up to 1 Grep/Read per question turn** before generating a follow-up.

Use the call to:
- Answer a candidate follow-up directly from code (skip the question if code answers it), or
- Surface a contradiction between the user's stated claim and the codebase.

**On failure:** if the call errors, MUST continue without the cross-reference; MUST NOT abort or count the failed read as a turn. When batching, at most 1 read for the entire batch.

## 3. Fuzzy-Term Sharpening

When the user uses an overloaded or ambiguous term (e.g., "account", "session", "event"):

1. Identify the ambiguity explicitly.
2. Propose a canonical term for this architecture.
3. Ask for confirmation in the **next turn** before incorporating the term into any decision.

Defer sharpening to the next turn — do not interrupt the current answer.

## 4. Edge-Case Probing

When discussing a domain relationship, state transition, or data flow, SHOULD probe with one concrete edge case:

- Choose a scenario that stresses the nominal design (concurrency, mid-transaction failure, rollback, empty/max input, expiry).
- Frame as: "What happens when X occurs while Y is in state Z?"
- Count the probe as one turn; probe each relationship at most once per session.

## 5. Convergence-Detector Pseudocode

```
turns_used = 0; streak = 0; queue = seed_questions

MUST emit before first question:
  "Grilling targets 8 total question turns. If more questions arise,
   I'll batch them to stay within budget. After 8 turns I'll check in."

while queue:
    if turns_used == 8 and len(queue) > 1:
        emit "We've covered 8 question turns. Ready to proceed, or keep grilling? [y/N]"
        if user says y/yes/proceed: break
        else: streak = 0   # keep going; re-check every turn past 8

    # Batching: kick in when anticipated total > 8
    if turns_used + len(queue) > 8:
        batch_size = ceil(len(queue) / max(1, 8 - turns_used))
        batch_size = clamp(batch_size, 2, 5)
    else:
        batch_size = 1
    batch, queue = queue[:batch_size], queue[batch_size:]

    # 1-read budget (may no-op on error)
    attempt_codebase_read(batch)

    present(batch, with_recommended_answers=True)
    answer = await_user(); turns_used += 1

    # Convergence check
    if raises_new_dimension(answer):
        streak = 0; enqueue_followups(answer, queue)
    else:
        streak += 1
        if streak >= 2:
            emit "I think we have shared understanding. Ready to proceed? [y/N/keep grilling]"
            if user says y/yes/proceed: break
            else: streak = 0

proceed_to_step_6()
```

**Seed exclusion:** under `--grill --parallel` or `--grill --debate`, the seed set comes from a star-chamber consultation — do NOT batch seed questions; batching applies only to follow-ups.

**"1 turn left" exception:** if exactly 1 question remains when turn 8 completes, ask it directly without the proceed-prompt (the round-trip cost of the prompt exceeds the cost of one more turn).
