# AGENTS.md: onboarding for coding agents

Read this before changing anything in this repo. The [README](README.md) covers what the project is, and [CONFIGURE.md](CONFIGURE.md) covers user-facing behavior and every setting. This file covers how the code works, how to change it safely, and the traps found while building it.

## What this is

`orca-widget-sync` is a single Python script. A launchd job runs it every 5 seconds. Each run does three things:

1. Asks the [Orca](https://www.onorca.dev/docs/cli/reference) CLI which AI agents are running and what state each is in.
2. Renders that as text (or a CSV table).
3. Pushes it to a [TerminalWidget](https://terminalwidget.app/cli) desktop widget with the `terminal-widget` CLI, **only if what's displayed changed**.

There's no server, no daemon loop and no dependencies. Each run is one pass and exits.

```
launchd (5s) ──▶ orca-widget-sync ──▶ orca status / worktree ps / terminal list / terminal read
                       │
                       ├─ collect()  → rows: agent, workspace, task, state, since
                       ├─ render     → ascii | pipeline | flap | table
                       ├─ hash == last hash?  → exit (no push)
                       └─ terminal-widget --target orca-agents --background-mode …
```

## Repo map

| Path | Purpose |
|---|---|
| `orca-widget-sync` | The whole program, about 900 lines |
| `install.sh` | `install` / `uninstall` / `status`. Fills in the plist template, copies any `ORCA_TW_*` variables from the caller's shell into it, and (re)loads launchd |
| `launchd/dev.orca.widget-sync.plist.template` | launchd job. Runs `/usr/bin/python3 <script>` every `__INTERVAL__` seconds. `__ENV__` is replaced with the `ORCA_TW_*` variables |
| `hooks/claude-settings-snippet.json` | Optional Claude Code hooks that run the script for an instant refresh |
| `README.md` | Short user intro: what it is, install, use |
| `CONFIGURE.md` | Full user reference: styles, states, settings table, troubleshooting |
| `RESEARCH.md` | Original design notes and flow diagram (some details now outdated; the code wins) |
| `docs/` | Images for the README |

Runtime files that aren't in the repo:
- `~/.cache/orca-widget/state.json`: state saved between runs.
- `~/.cache/orca-widget/lock`: the run lock.
- `~/Library/Logs/orca-widget-sync.log`: errors only (stderr).
- `~/Library/LaunchAgents/dev.orca.widget-sync.plist`: the installed launchd job.

## How the script is organized

The script is in one file, split into sections by comment banners (`# ---- name ---`). Find things by function name; line numbers drift.

| Section | Key names | Notes |
|---|---|---|
| config | `SCREEN_SIGS`, `UNHOOKED_RE`, `ACTIVE_SECS`, `NOTIFY_ON`, `CACHE` | Every setting is `ENV("ORCA_TW_…", default)` at import time |
| look | `text_font_args`, `STATE_LABEL`, `SPINNERS`, `BAR_*`, `PIPE_*`, `AGENTS`, `AGENT_ALIASES`, `AGENT_COLORS` | Visual constants; `AGENTS[id] = (name, tag, mark)` |
| helpers | `orca_json`, `agent_id`, `agent_label`, `paint`, `bar`, `state_cell`, `issue_label`, `short`, `ago` | `orca_json(*args)` runs `orca … --json` and returns `.result` |
| collection | `read_screen`, `identify`, `collect` | Turns Orca output into rows |
| render | `to_csv`, `ascii_render`, `pipeline_render`, `pipe_status`, `push_*`, `tw` | `tw(args, stdin, dry)` is the only place that runs `terminal-widget` |
| split-flap | `STYLE`, `flap_model`, `flap_render`, `flap_frames`, `push_flap` | Note: `STYLE` is defined in this section, not in config |
| watch | `watch` | `--watch`: prints state changes, never pushes |
| main | `main` | Lock, load state, collect, render, hash, push, save |

### `collect(now, identities, starts)`: where state comes from

1. **Agents with hooks:** `orca worktree ps --json` lists workspaces, each with `agents[]` filled in by Orca's status hooks (Claude, Cursor, Gemini…). Rows are kept only if `hasLivePty`. Their state comes from Orca: `working | blocked | waiting | done | idle`. These values are confirmed from the Orca app bundle, and `blocked`/`waiting` both mean "needs you".
2. **Agents without hooks** (IBM Bob, Ollama, and Cursor when its hooks are off): `orca terminal list --json` lists terminals. Any terminal whose pane (`tabId:leafId`) isn't already a hooked row has its screen read with `orca terminal read --screen` and matched against `SCREEN_SIGS[agent].identify`. State is worked out as:
   - `SCREEN_SIGS[agent].blocked` matches → `blocked`
   - `.working` matches → `working`
   - `lastOutputAt` within `ACTIVE_SECS` → `working`
   - otherwise `idle`
   - disconnected → `exited`

   These rows get `inferred: True`.
3. **What gets remembered:**
   - `identities` (`handle → agent`): an agent's banner scrolls away, but the terminal is still that agent.
   - `starts` (`key → [state, since_ms, prev_state, last_fill, base]`): agents without hooks don't report when a state began. The pipeline style also needs the previous state (to show "passed") and the last bar fill (so the bar holds while waiting and resumes after an approval).

   Both are saved in `state.json`.

A row is a dict: `key, agent_id, agent, workspace, task, state, since_ms`, plus `inferred, prev_state, last_fill` when they apply.

### `main()`: one pass

1. Takes `flock` on the lock file. Timer and hook runs skip if it's held; `--force` and `--print` wait for it.
2. Loads `state.json` and checks `orca status` (if Orca isn't reachable, it shows the offline view).
3. Calls `collect`, then renders according to `STYLE`.
4. Calls `sha256(rendered text)`. **If the hash matches the last one, it exits without pushing.** That's why font and padding arguments aren't in the hash: changing them alone won't trigger a push, so use `--force`.
5. Sets `notify` when any agent newly entered a state in `NOTIFY_ON`.
6. Pushes, then saves `{digest, states, identities, starts, flap, at}`. `--dry-run` never saves.

## Run, test, verify

```bash
./orca-widget-sync --dry-run --force --print   # rows as JSON + the exact terminal-widget command
./orca-widget-sync --watch                     # live state changes, Ctrl-C to stop
./orca-widget-sync --force                     # really push now
ORCA_TW_STYLE=pipeline ./orca-widget-sync --dry-run --force   # try a style without installing
./install.sh status                            # launchd runs / last exit code
terminal-widget log --target orca-agents --limit 5   # did the widget actually render?
```

Strip colors when previewing: `… | sed 's/\x1b\[[0-9;]*m//g'`.

**There's no test suite.** Test logic by loading the script as a module and replacing the two I/O functions with fakes. This is the pattern used throughout development:

```python
import importlib.machinery, importlib.util, time
loader = importlib.machinery.SourceFileLoader("ows", "orca-widget-sync")
spec = importlib.util.spec_from_loader("ows", loader)
m = importlib.util.module_from_spec(spec); loader.exec_module(m)

now = time.time()
fake = {("worktree", "ps"): {"worktrees": [...]},
        ("terminal", "list"): {"terminals": [...]}}
m.orca_json = lambda *a: fake[a[:2]]
m.read_screen = lambda handle: {"h2": "Agent Mode"}.get(handle, "")

ids, starts = {}, {}
rows = m.collect(now, ids, starts)        # call repeatedly with a later `now` to simulate time
print(m.pipeline_render(rows, now))
```

Run it with `/usr/bin/python3` (3.9), the interpreter launchd uses. To test transitions, keep `ids` and `starts` between calls. Check alignment by stripping ANSI codes and asserting that every frame line is the same length.

**Before saying a visual change works:** `terminal-widget` exiting 0 only means the update was saved. Confirm a new `Rendered revision N` in `terminal-widget log`. You can't see the widget yourself (screen capture isn't permitted, and the TerminalWidget payload folder is sandboxed), so ask the user to look.

## Rules for changing code

- **Standard library only, and Python 3.9 compatible.** No `match`, no `X | Y` type unions, no third-party imports. launchd runs `/usr/bin/python3`.
- **New settings:** add them as `ENV("ORCA_TW_…", default)` and document them in the CONFIGURE.md settings table. Every `ORCA_TW_*` name in the code should appear there. Check with:
  ```bash
  comm -23 <(grep -oE 'ORCA_TW_[A-Z_]+' orca-widget-sync install.sh | cut -d: -f2 | sort -u) <(grep -oE 'ORCA_TW_[A-Z_]+' CONFIGURE.md | sort -u)
  ```
- **Alignment with colors:** measure and pad the *plain* text, then wrap it in `paint()`. Never call `ljust` on a string that already has ANSI codes. See `ascii_render`, `pipeline_render` and `flap_render`.
- **Glyphs must be one cell wide in Menlo.** Marks, spinner frames and bar characters all need to come from Menlo itself, or fallback fonts shift the columns. Check with CoreText (`CTFontGetGlyphsForCharacters` on `Menlo`). A known-bad example is `☰ ⬢ ⌬ ⎔`, which fall back to Apple Symbols.
- **Every push goes through `tw()`,** with `--background-mode` so the push never brings TerminalWidget to the front.
- **Keep pushes rare:** anything that changes the rendered text every tick (clock, spinner frame) forces a push every tick. Spinner frames advance once per `SPIN_SECS` (30 s) for this reason.
- **Docs:** user-facing behavior goes in CONFIGURE.md. The README stays short (what it is / install / use / link).

### Adding a new agent

1. Add it to `AGENTS`, `AGENT_COLORS`, and, if it has variant names, `AGENT_ALIASES`. Pick a mark that Menlo draws at one cell wide.
2. If Orca has hooks for it, that's all: it arrives through `worktree ps` as `agentType`.
3. If not, add a `SCREEN_SIGS` entry. Use an `identify` regex that matches text that stays on screen (footers, prompts, approval dialogs), not just the startup banner. Add a `blocked` regex for its approval prompt, and optionally a `working` regex for something only visible mid-turn. You can find the real strings with `orca terminal read --terminal <handle> --screen --json`, or by grepping the agent's installed bundle.
4. Test it with the fake-data pattern above, then add it to the marks table in CONFIGURE.md.

### Adding a style

Write `<style>_render(rows, now) -> str` and `push_<style>(rows, now, notify, dry)` (use `text_font_args(text)` for sizing). Then hook both into the two `STYLE` checks in `main()`: one where `shown` is computed, one where the push happens. Document the style in CONFIGURE.md.

## Gotchas (all hit during development)

**TerminalWidget:**
- `--title` is rejected with `--table`. Use `--caption-text`.
- Native table cells can't be colored. That's why `ascii` and `pipeline` draw their own tables as `--text` with `--ansi-mode on`.
- `--fit-text` doesn't scale multi-line text, which leaves it tiny. `text_font_args()` sets an explicit `--font-size` from `WIDGET_SIZES[ORCA_TW_WIDGET_SIZE]` instead.
- `--padding fill` turns on full-width mode, which **overrides `--font-size`**. Use a number for padding.
- macOS redraws desktop widgets only about every 30–60 s and drops pushes in between (revision numbers skip). Fast animation is pointless, so flap flip frames default to 0.
- The tap action `open-app` takes a bundle id (`com.stablyai.orca`), not an app name.

**Orca:**
- `orca terminal rename` doesn't change the `title` that `terminal list` returns, and Bob overwrites its own title anyway. Don't rely on titles; screen signatures are the main way agents without hooks are identified.
- `agents[]` keeps closed sessions, so filter on `hasLivePty`.
- No watch, stream or events API exists, so polling is the only option. `orca terminal wait --for tui-idle` is the only blocking primitive.

**launchd and the shell:**
- launchd keeps running the script **while you edit it**, so a half-saved file causes transient errors (for example `NameError`) in `~/Library/Logs/orca-widget-sync.log`. After finishing edits, clear the log with `>| ~/Library/Logs/orca-widget-sync.log` (zsh `noclobber` blocks a plain `>`) and recheck `./install.sh status`.
- `launchctl kickstart` without `-k` can hang; avoid it.
- Re-running `./install.sh` without a variable resets that setting to its default. Include every variable the user wants to keep, and check the current ones first with `plutil -p ~/Library/LaunchAgents/dev.orca.widget-sync.plist | grep ORCA_TW`.
- `--dry-run` doesn't save state, so repeated dry runs show `since` as "now" and bars near empty. That's not a bug.
- A background job started from a non-interactive shell ignores SIGINT. `watch()` installs its own SIGINT/SIGTERM handlers for this reason, so use `kill` (SIGTERM).
- In zsh, `echo ===` fails (`=cmd` expansion). Use another separator.

## Workflow conventions

- **Commits:** imperative subject, a body explaining why, and a trailer:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```
  Commit or push only when the user asks.
- **Remote:** `git@github.com:greyhoundforty/tw-orca-tracking.git` (public), branch `main`.
- **Changing the user's live widget:** use `./install.sh` with their existing `ORCA_TW_*` settings carried over. Tell them how to revert.
- **The user verifies visuals:** after a visual change, confirm the render in the log, then ask the user how it looks.
