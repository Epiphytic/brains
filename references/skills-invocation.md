# Skills Invocation (query + search/activate/invoke + fallback)

BRAINS shared reference for running skills discovery once `--skills` is active and detection (`references/skills-detection.md`) has resolved a provider. Consumed by `skills/brains/SKILL.md`, `skills/map/SKILL.md`, `skills/implement/SKILL.md`, and `skills/implement/teammate.md`.

> Read `references/skills-detection.md` first — it determines whether the hotskills path or the find-skills fallback path applies for this session.

## Query derivation order

Per ADR-005 req 20, derive the search query from the following sources, top-to-bottom. Use the first source that yields a non-empty string:

1. **Future `--skills-query "..."` argument** — explicit per-invocation override. Out of scope for the current iteration; wire the parser to accept and pass through if/when it lands.
2. **Current beads task title** — phase 2/3 only. Read from the active task record (`bd show <id>` or in-memory state). Use the verbatim title; do not summarize.
3. **Topic slug** — phase 1, or phase 2/3 when no specific task is active. Use the kebab-case slug as-is (hotskills will tokenize).
4. **User's original prompt** — truncated to 80 chars at a word boundary. Last resort; least specific.

If none of the above yields content, the skill MUST log the literal line `"no query derivable for --skills; skipping skill discovery"` and skip discovery. Do NOT call `hotskills.search` or `npx skills find` with an empty query — both would either error or return noise.

## Hotskills sequence (preferred path)

When detection (per `references/skills-detection.md`) returned hotskills-available AND a query is derivable:

1. **Search:** call `hotskills.search({query, limit:10})`. The `limit:10` ceiling balances coverage against token cost; do not raise without justification.
2. **Pick the candidate:**
   - **Under `--autopilot`:** scan results in returned order and pick the **first** result with `gate_status === "allow"`. If none has `allow`, log `"no allowed skill for query <query>; skipping activation"` and continue (do NOT block the autopilot run, per ADR-005 req 9).
   - **Without `--autopilot`:** present the ranked picker to the user (see hotskills' `/hotskills` Case C semantics) and await user selection. On user-decline, skip activation.
3. **Activate:** call `hotskills.activate({skill_id, install_count})` with the picked skill. Use `installs` from the search result for `install_count`. **`force_whitelist` MUST NOT be passed under `--autopilot`** — regardless of any flag combination. Hotskills' `gate_status` IS the security gate; `--autopilot` skips user gates for *flow*, not *security*.
4. **Invoke:** call `hotskills.invoke({skill_id})`. The returned `body` is the SKILL.md content for the activated skill — follow it inline as guidance for the in-flight task.

### Verbatim safety contract (under `--autopilot`)

- `force_whitelist` MUST NOT be passed under `--autopilot`.
- `npx skills add` MUST NOT be invoked under `--autopilot`.

These are the two hard "no" rules of the `--skills --autopilot` safety contract. Any code path that violates either MUST be flagged in nurture/secure review.

## Find-skills fallback

When detection returned hotskills-unavailable (tool absent or `hotskills.list` threw):

1. **Verify `npx` is on PATH:** `command -v npx`. If absent, log the literal line `"Skills discovery requires either hotskills (preferred) or Node.js/npx for the find-skills fallback. Install one to use --skills."` and continue without skill discovery for the session. Do NOT attempt any further fallback action.
2. **Lazy-load the vendored doc:** read `references/find-skills.md` (relative to the BRAINS plugin root) NOW — not earlier. This is the lazy-load that satisfies ADR-005 req 29: the file is touched only when the fallback actually fires. Under `--lean`, the same lazy-load applies.
3. **Follow the vendored instructions:** invoke `npx skills find <query>` via the Bash tool, parse results per the find-skills doc, and present them to the user (interactive) or log them and continue (autopilot).

### Verbatim safety contract (autopilot, fallback path)

- **`npx skills add` MUST NOT be invoked under `--autopilot`.** Auto-install is reserved for the hotskills path where `gate_status` provides a security gate. The fallback has no equivalent gate; any auto-install would let arbitrary upstream skills land in an unattended run.
- Under autopilot, the fallback ends at presenting / logging the search results. Surface the install command for post-hoc human action; do not run it.

## Lazy-load summary

Per ADR-005 req 29:

| File | When loaded |
|---|---|
| `references/skills-detection.md` | At start of a `--skills` run (this file's caller is already loading it) |
| `references/skills-invocation.md` | At start of a `--skills` run (this file is the caller's invocation reference) |
| `references/find-skills.md` | **Only when the find-skills fallback fires** — never upfront |

This keeps the upfront token cost of `--skills` bounded; the largest file (`find-skills.md`, ~6 KB vendored) is loaded only when hotskills is genuinely unavailable AND `npx` is present AND a query was derivable.
