# Visual Companion Guide

Browser-based visual brainstorming companion for showing mockups, diagrams, and options during phase 1 (`/brains:brains`). Available as a tool — not a mode. Accepting the companion means it is available for questions that benefit from visual treatment; not every question goes through the browser.

## When to Use

Decide per-question, not per-session. The test: **would the user understand this better by seeing it than reading it?**

**Use the browser** when the content itself is visual:
- UI mockups, wireframes, layouts, navigation structures
- Architecture diagrams, system components, data flow maps
- Side-by-side visual comparisons of design directions
- Design polish — look and feel, spacing, visual hierarchy
- State machines, flowcharts, entity relationships rendered as diagrams

**Use the terminal** when the content is text or tabular:
- Requirements and scope questions
- Conceptual A/B/C choices described in words
- Tradeoff lists, pros/cons, comparison tables
- Technical decisions (API design, data modeling)
- Clarifying questions where the answer is words, not a visual preference

A question about a UI topic is not automatically a visual question. "What does personality mean in this context?" is conceptual — use the terminal. "Which wizard layout works better?" is visual — use the browser.

## Starting a Session

Set `BRAINS_SCRIPTS` to the brains skill's scripts directory:

```bash
BRAINS_SCRIPTS="$BRAINS_PATH/skills/brains/scripts"
```

Start the server:

```bash
$BRAINS_SCRIPTS/start-server.sh --project-dir "$(pwd)"
```

Returns JSON with `port`, `url`, `screen_dir`, and `state_dir`. Save these values.

Tell the user to open the URL. Remind them to add `.superpowers/` to `.gitignore` if not already present.

## The Loop

1. **Check server is alive** (`$STATE_DIR/server-info` exists, `server-stopped` does not). If server has shut down, restart with `start-server.sh`.

2. **Write HTML** to a new file in `screen_dir`:
   - Use semantic filenames: `approaches.html`, `architecture.html`, `layout.html`
   - Never reuse filenames — each screen gets a fresh file
   - Use the Write tool (not cat/heredoc)
   - Server automatically serves the newest file
   - Write **content fragments** (no `<!DOCTYPE>` or `<html>`) — the server wraps in frame template

3. **Tell user what to expect** and end the turn:
   - Remind them of the URL
   - Brief text summary of what is on screen
   - Ask them to respond in the terminal

4. **On next turn** — after user responds:
   - Read `$STATE_DIR/events` if it exists (JSON lines of browser interactions)
   - Merge with terminal text for full picture
   - Terminal message is primary feedback; events provide structured interaction data

5. **Iterate or advance** — if feedback changes current screen, write a new file (e.g., `approaches-v2.html`). Only move to next question when current step is validated.

6. **Unload when returning to terminal** — push a waiting screen:
   ```html
   <div style="display:flex;align-items:center;justify-content:center;min-height:60vh">
     <p class="subtitle">Continuing in terminal...</p>
   </div>
   ```

## CSS Classes Available

The frame template provides these classes:

### Options (A/B/C choices)
```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content"><h3>Title</h3><p>Description</p></div>
  </div>
</div>
```

Add `data-multiselect` to the container for multi-select.

### Cards (visual designs)
```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-image"><!-- mockup --></div>
    <div class="card-body"><h3>Name</h3><p>Description</p></div>
  </div>
</div>
```

### Mockup container
```html
<div class="mockup">
  <div class="mockup-header">Preview: Dashboard Layout</div>
  <div class="mockup-body"><!-- mockup HTML --></div>
</div>
```

### Split view (side-by-side)
```html
<div class="split">
  <div class="mockup"><!-- left --></div>
  <div class="mockup"><!-- right --></div>
</div>
```

### Pros/Cons
```html
<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>Benefit</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>Drawback</li></ul></div>
</div>
```

### Mock elements
```html
<div class="mock-nav">Logo | Home | About | Contact</div>
<div class="mock-sidebar">Navigation</div>
<div class="mock-content">Main content area</div>
<button class="mock-button">Action</button>
<input class="mock-input" placeholder="Input">
<div class="placeholder">Placeholder area</div>
```

### Typography
- `h2` — page title
- `h3` — section heading
- `.subtitle` — secondary text
- `.section` — content block
- `.label` — small uppercase label

## Browser Events Format

Interactions recorded to `$STATE_DIR/events` (one JSON object per line, cleared on new screen):

```jsonl
{"type":"click","choice":"a","text":"Option A","timestamp":1706000101}
{"type":"click","choice":"b","text":"Option B","timestamp":1706000115}
```

Last `choice` event is typically the final selection. The click pattern may reveal hesitation worth asking about.

## Cleaning Up

```bash
$BRAINS_SCRIPTS/stop-server.sh $SESSION_DIR
```

With `--project-dir`, mockups persist in `.superpowers/brainstorm/` for reference.
