# Renderer Conventions

## Detection Sequence

Check renderers in this exact priority order. Stop at the first that succeeds.

### 1. Local Kroki container (preferred)

Check for `~/.config/brains/renderer.json`. If the file exists and contains a `kroki_url` field:

**Validate `kroki_url` before use:**
- Scheme MUST be `http` or `https`. Reject any other scheme.
- Host MUST be a local address: `localhost`, `127.0.0.1`, `::1`, or a `.local` domain. Reject external hostnames (this prevents SSRF — diagram source must not be sent to arbitrary hosts via this path).
- Strip any trailing `/` from `kroki_url` before appending `/mermaid/svg`.
- If validation fails, fall through to the next renderer (do not abort; treat as unavailable).

```
POST ${kroki_url}/mermaid/svg
Content-Type: text/plain
Body: <mermaid source>
```

A 200 response with SVG content means the renderer is available. Use this renderer.

If the file is absent, `kroki_url` is missing, fails validation, or the POST fails (connection refused, non-200): fall through to the next renderer.

### 2. mmdc via npx (secondary)

Attempt:

```bash
npx -p @mermaid-js/mermaid-cli mmdc -i <input.mmd> -o <output.svg>
```

Note: this fallback requires a working Node.js (≥18.19) and npm/npx toolchain and may download packages on first run (latency expected). In air-gapped or constrained environments, expect this to fail — source-only is the correct fallback there.

If npx is not installed, the package download fails, or mmdc exits non-zero: fall through.

### 3. Source-only fallback

No SVG is produced. Write the `.mmd` file only. Emit the HTML comment hint in the ADR `## Diagram` section:

```html
<!-- renderer unavailable; to enable SVG rendering, run /brains:setup --with-kroki or install @mermaid-js/mermaid-cli -->
```

## NO-CLOUD DEFAULT

**The skill MUST NOT send diagram source to any external cloud service by default.**

Kroki.io (`https://kroki.io`) is an external cloud service. It MUST NOT be used as an automatic fallback. The local Kroki container (`yuzutech/kroki` running on the user's machine) is distinct from the public Kroki.io cloud — using the local container does not violate this rule.

## --kroki-cloud Explicit Consent Path

The user MAY pass `--kroki-cloud` to opt into the public `https://kroki.io` cloud renderer. Requirements:
- **DISALLOWED in auto-trigger mode.** When `brains:diagram` is invoked automatically from a workflow (ADR generation step 8), `--kroki-cloud` MUST be ignored and source-only fallback MUST be used. Interactive consent cannot be obtained in auto-trigger context.
- In standalone mode: prompt the user with "This will send your diagram source to https://kroki.io (an external cloud service). Confirm? [y/N]"
- If the user does not confirm, fall back to source-only.
- MUST NOT be used as an automatic fallback under any circumstances.

## renderer.json Write Contract (Immutability Rule)

`~/.config/brains/renderer.json` is written **only** by `brains:setup --with-kroki` and deleted/cleared **only** by `brains:setup --without-kroki`. No other BRAINS skill — `brains:diagram`, `brains:brains`, `brains:implement`, `brains:nurture`, `brains:secure`, or any future skill — is permitted to create, modify, or delete this file. Reading `kroki_url` for renderer detection is the only permitted access for non-setup skills. This is a spec-enforced behavioral contract.
