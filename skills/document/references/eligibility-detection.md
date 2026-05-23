# Eligibility Detection (Document Mode)

Hybrid detection procedure for `/brains:document` and the `/brains:brains` Step-1 delegation guard. Deterministic bash classifies and counts the changed working-tree file set; the main LLM resolves in-scope target documents from the prompt for greenfield work. The numeric gate is fully deterministic and testable.

The eligibility ceiling is: **≤ 4 target documents, with zero non-document files in the changed set.**

> **Revision (2026-05-23, pre-merge simplification):** the original design also enforced a ≤ 10 on-disk dependent-file ceiling, which required an LLM pass to read each document, extract three link forms, resolve relative paths, and `test -f` each target. That dependent-counting machinery was the most expensive and least-deterministic part of the gate, enforcing a soft heuristic on top of the cheap ≤ 4-document count. It was dropped — the document-count ceiling plus the zero-non-document-files rule is the guard. See ADR-006 Revision note.

## 1. Canonical changed set (deterministic bash)

The changed set is the union of unstaged, staged, and untracked-not-ignored files. It MUST NOT depend on an ambiguous branch base-ref.

```bash
{ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort -u
```

- `git diff --name-only` — unstaged changes.
- `git diff --cached --name-only` — staged changes.
- `git ls-files --others --exclude-standard` — untracked files that are not `.gitignore`d.

`sort -u` yields the unique union. This list is the input to classification (§2). When the changed set is empty (greenfield topic), skip to §4.

## 2. Versioned document allow-list and classification

Classify every path in the changed set by file extension against this **versioned allow-list**. A path is a document only when its extension is one of:

- `.md`
- `.markdown`
- `.mdx`
- `.rst`
- `.txt`
- `.adoc`

Every other extension is **non-document**, explicitly including:

- Notebooks: `.ipynb`
- Diagrams: `.svg`, `.mmd`, `.dsl`
- Any source-code extension (`.py`, `.js`, `.ts`, `.go`, `.rs`, `.sh`, `.rb`, `.java`, `.c`, `.cpp`, `.h`, …)

Classification is **by changed-file extension, not by content**. Fenced or inline code samples appearing *inside* a document (e.g. a ` ```python ` block in a `.md` file) MUST NOT count as code presence — the file is a document because its extension is `.md`.

Classification yields **three** classes — `document`, `code`, and `other-non-document` — because the eligibility and asymmetric-override rules treat them differently: any non-document file blocks auto-eligibility (req 13), but only **code** files drive the manual hard-refuse (req 17). `other-non-document` covers non-code, non-document files such as `.svg`, `.mmd`, `.dsl`, and `.ipynb`.

```bash
CHANGED="$({ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort -u)"
DOC_RE='\.(md|markdown|mdx|rst|txt|adoc)$'
CODE_RE='\.(py|js|ts|tsx|jsx|go|rs|sh|bash|rb|java|c|cc|cpp|h|hpp|cs|php|swift|kt|scala|lua|sql|pl|r)$'
DOCS="$(printf '%s\n' "$CHANGED" | grep -E "$DOC_RE" || true)"
NONDOCS="$(printf '%s\n' "$CHANGED" | grep -vE "$DOC_RE" | sed '/^$/d' || true)"
CODE="$(printf '%s\n' "$NONDOCS" | grep -E "$CODE_RE" || true)"
DOC_COUNT="$(printf '%s\n' "$DOCS" | sed '/^$/d' | wc -l | tr -d ' ')"
NONDOC_COUNT="$(printf '%s\n' "$NONDOCS" | sed '/^$/d' | wc -l | tr -d ' ')"
CODE_COUNT="$(printf '%s\n' "$CODE" | sed '/^$/d' | wc -l | tr -d ' ')"
```

`DOCS` is the candidate target-document set; `NONDOCS` are all non-document files (any presence blocks auto-eligibility per §5); `CODE` is the code subset of `NONDOCS` (presence drives the manual hard-refuse per §7). The code allow-list above is illustrative, not exhaustive — treat any recognized source-code extension as code.

## 3. Counting target deliverables only

The `DOC_COUNT` toward the ≤ 4 ceiling MUST count **target deliverable** documents only. It MUST NOT count BRAINS-generated artifacts the document-mode spine authors mid-flight:

- the slim ADR in `docs/adr/`
- the optional orientation note in `docs/research/`
- beads state under `docs/plans/.state/`

These are outputs of the document-mode spine, not deliverables under review. When recomputing counts after editing (§4), exclude any path the spine itself authored.

## 4. Greenfield scope resolution (main LLM)

When the changed set is empty (no existing diff), the main LLM MUST:

1. Resolve the intended in-scope **target documents** from the user's prompt plus a repository scan (Glob/Grep for the named or implied files).
2. Fix that target scope **before** editing.
3. Re-validate the target-document count (§2 / §3) **after** editing, against the now-changed working tree.

The fixed scope is the authoritative target-document list; subsequent counting (§3) excludes any artifact the spine authored.

## 5. Eligibility decision

A change is eligible for document mode **only when BOTH hold**:

1. Zero non-document files in the changed set (`NONDOC_COUNT` == 0, per §2).
2. Target documents ≤ 4 (`DOC_COUNT` of deliverables only, per §3).

If either condition fails, apply the mode-sensitive threshold behavior (§6) or the asymmetric override (§7) as appropriate.

## 6. Mode-sensitive threshold behavior (auto-detected, oversized)

When auto-detection finds document-only work (zero non-document files, per §5 condition 1) that exceeds the ≤ 4-document ceiling, behavior is mode-sensitive:

- **Interactive — warn and ask.** Surface the measured count (documents N and the ≤ 4 ceiling) and offer to either proceed via the full `/brains:brains` pipeline or cancel. Await the user's choice.
- **`--autopilot` — detect-then-fallback.** Automatically invoke the full `/brains:brains` pipeline. The fallback MUST emit an explicit, **loud notice** stating the measured count and the reason for falling back, so misclassification is never silently hidden:

  > "DOCUMENT MODE FALLBACK: measured N target documents, exceeding the ≤ 4 ceiling. Falling back to the full /brains:brains pipeline."

## 7. Asymmetric manual override (`--document-mode` on an ineligible change)

Manual `--document-mode` on an ineligible change behaves **asymmetrically**, sorted by the nature of the ineligibility:

- **Non-document code files present** (`CODE_COUNT` > 0): **hard-refuse**. Document mode has no secure pass, so actual code in the change is categorically unsafe here. Refuse and direct the user to the full `/brains:brains` pipeline. State which code files triggered the refusal. This is the strongest rule; evaluate it first.
- **Oversized or non-code non-document scope** (`CODE_COUNT` == 0, but documents > 4, or `other-non-document` files such as `.svg`/`.mmd`/`.dsl`/`.ipynb` are present): **warn-and-confirm**. Interactively, surface the count and the offending files and confirm once before proceeding into the document-mode spine; under `--autopilot`, fall back to the full pipeline with the loud notice (§6).

Fenced or inline code *inside* a document NEVER triggers the refusal — classification is by changed-file extension (§2), not document content.
