# tw-orca-tracking

A live TerminalWidget desktop widget showing the agents running in Orca: Claude (and other agents with Orca hooks), IBM Bob and Ollama.

```
agent      workspace     task                 state             since
◈ cursor   web           #87 Fix navbar       ! needs you       1m
≡ ibm bob  billing       PR 12                / [===>      ]    2m
✻ claude   api/feat-x    ENG-142 Add auth     - [=>        ]    now
♞ ollama   sandbox                            · idle            3m
orca · 2 working · 1 needs you                                  04:23
```

The look follows [ascii.rest](https://ascii.rest), rendered in Menlo.

### Styles

Pick one with `ORCA_TW_STYLE=<style> ./install.sh`. Any `ORCA_TW_*` variable set on that command is copied into the launchd job.

| Style | What it is | Per-agent color |
|---|---|---|
| `ascii` (default) | The table drawn as monospace text (above) | Yes: agent tag/name and its working spinner |
| `pipeline` | Agents as stages of an [ascii.rest pipeline](https://ascii.rest/pipeline/) inside a rounded frame (below) | Yes: agent mark/name, stage glyph, bar and status |
| `flap` | A departures board after [ascii.rest/split-flap](https://ascii.rest/split-flap/): amber on black, one tile per character, `▔` split lines | Yes: agent tiles |
| `table` | TerminalWidget's native table with zebra rows | No: native cells can't be colored |

```
╭─────────────────────────────────────────────────────────╮
│ O R C A     A G E N T S                       0 4 : 5 7 │
│                                               ▔ ▔   ▔ ▔ │
├─────────────────────────────────────────────────────────┤
│ agent   task                  status              since │
│ C U R   8 7   F I X   N A V   N E E D S   Y O U   1 M   │
│ ▔ ▔ ▔   ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔   ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔   ▔ ▔ ▔ │
│ B O B   B I L L I N G         W O R K I N G       2 M   │
│ ▔ ▔ ▔   ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔   ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔   ▔ ▔ ▔ │
╰─────────────────────────────────────────────────────────╯
```

```
╭─ orca · 1 working ───────────────────────────────────────────────────────────╮
│   ▄▄  ≡ ibm bob  tengingarstjori           ████░░░░░░░░░░░░░░   1m  running  │
│  !    ◈ cursor   fix navbar                ███████░░░░░░░░░░░   2m  waiting  │
│  +    ✻ claude   Repository architecture…  ██████████████████  52m  passed   │
│  ·    ♞ ollama   sandbox                   ··················  38m  idle     │
╰──────────────────────────────────────────────────────────────────────────────╯
```

Pipeline stages:

| Agent state | Glyph | Bar | Status |
|---|---|---|---|
| working | spinner (`ORCA_TW_SPINNER`) | `█` fills with time in the turn, **capped at 90%** | running |
| blocked / waiting | `!` | holds where it stopped; resumes from there after you approve | waiting |
| done (Orca hooks) | `+` | full | passed |
| idle, right after a Bob/Ollama turn | `+` | full | passed (for 10 min) |
| idle | `·` | `··················` | idle |
| exited | `x` | `··················` | exited |

The bar isn't real progress: it shows how long the agent has been working. The 90% cap means a long task never looks finished; the bar only goes full on a real `done` from Orca. Bob and Ollama have no hooks and never report `done`, so "was working, now quiet" counts as *passed* for `ORCA_TW_PIPE_PASSED_SECS` (600) and then drops to idle. That's inferred from output stopping, not a confirmed finish. The title line turns amber when an agent needs you. Settings: `ORCA_TW_PIPE_WIDTH` (18), `ORCA_TW_PIPE_CAP` (0.9), `ORCA_TW_PIPE_PASSED_SECS` (600).

Flap settings:
- `ORCA_TW_FLAP_COLS`: which columns show, default `agent:3,task:10,status:9,since:3`. You can also use `workspace`.
- `ORCA_TW_FLAP_ROWS`: number of rows, default 6.
- `ORCA_TW_FLAP_TITLE`: header text.
- `ORCA_TW_FLAP_FG` / `ORCA_TW_FLAP_BG`: board colors.
- `ORCA_TW_FLAP_FRAMES`: set to e.g. `4` to push a flip animation when tiles change, with tiles rolling through the drum and `▀` on turning flaps. It's off by default (see below).

**Animation limit.** macOS redraws desktop widgets only about every 30–60 s and drops pushes in between. You can see this in `terminal-widget log --target orca-agents`, where revision numbers skip. Fast animation (flip bursts, quick spinners) therefore mostly never reaches the screen, so the spinner advances one frame per 30 s and flip frames are off by default.

### Agent marks and colors

| Mark | Tag | Color | Agent | How it's tracked |
|---|---|---|---|---|
| `✻` | `cld` | orange `#e07a3f` | Claude | Orca hooks |
| `◈` | `cur` | teal `#2dd4bf` | Cursor | Orca hooks. Falls back to screen detection (`Cursor Agent`, approval prompts, `ctrl+c to stop`) if the hooks aren't installed |
| `≡` | `bob` | IBM blue `#4589ff` | IBM Bob | Screen detection |
| `♞` | `oll` | pink `#f472b6` | Ollama | Screen detection |
| `✦` / `◎` | `gem` / `cdx` | violet / green | Gemini / Codex | Orca hooks |
| `•` | first 3 letters | gray | Anything else Orca reports | Orca hooks |

The marks are original glyphs that hint at each agent (Claude Code's spinner star, IBM's stripes, Cursor's cube, Gemini's sparkle); they aren't brand logos. Each one is drawn by Menlo itself at exactly one cell wide, which keeps the columns aligned. Glyphs Menlo doesn't have (☰, ⬢, ⌬) fall back to another font at a different width and shift the columns. The flap board shows the mark as a one-tile agent column. `ORCA_TW_LABEL=tag` switches back to `[cld] claude`.

Override with `ORCA_TW_LOGOS="cursor=▲,ollama=ʘ"`, `ORCA_TW_TAGS="cursor=crs"` and `ORCA_TW_COLORS="cursor=#ffffff,claude=#ff8800"`. *Needs you* is always amber and *exited* red. If the colors don't show, try `ORCA_TW_ANSI=256` (or `off`).

### States

| State | Shown as | Notes |
|---|---|---|
| working | `/ [===>      ]` | [Spinner](https://ascii.rest/spinners/) plus a [progress bar](https://ascii.rest/progress-bar/). Agents don't report % done, so the bar fills with time spent in the current turn and is full after 5 min |
| blocked / waiting | `! needs you` | Also sends a one-time macOS notification |
| idle | `· idle` | |
| done | `+ done` | |
| exited | `x exited` | Terminal closed or disconnected |

The spinner moves **one frame per 30 s**, about as often as macOS redraws the widget (see *Animation limit* above). Once all agents are idle the pushes stop. Set `ORCA_TW_SPINNER=none` for a static bar.

Styles:
- `ORCA_TW_SPINNER`: `pipe` (default, `| / - \`), `loop`, `none`, or one of the bar-shaped spinners `scan`, `bounce`, `slide`, `wave`, which replace the progress bar.
- `ORCA_TW_BAR`: `equals` (default), `hash`, `blocks`, `lamps`, `line` or `none`.

```
equals  [===>      ]   hash   [####......]   blocks ▕███▌      ▏
lamps   ████░░░░░░     line   ━━━━──────
scan    ··░▓█··        bounce [  o   ]       slide  [  ===   ]      wave ▂▅▇█▇▅▂
```

If an Orca workspace has a linked issue, PR or Linear ticket, its key (`ENG-142`, `#87`, `PR 12`) is shown at the start of the Task column.

**Demo machine with Cursor:** run `orca agent hooks status` and make sure `cursor` shows `installed` (turn hooks on with `orca agent hooks on`). With hooks on, Cursor reports exact states and conversation names. Without them, the screen fallback still identifies Cursor, but working/idle comes from output activity.

See [RESEARCH.md](RESEARCH.md) for how this works and the flow diagram.

## Setup

1. **Place the widget.** Add a TerminalWidget widget to the desktop, then open *Edit Widget* and set **Target name** to `orca-agents`. A medium or large size fits the table best.
2. **Install the poller:**
   ```bash
   ./install.sh
   ```
   This links `~/bin/orca-widget-sync` and loads the launchd agent `dev.orca.widget-sync`, which runs every 5 s.
3. **Bob and Ollama need no setup.** They have no Orca status hooks, so the script reads their terminal screen through `orca terminal read --screen` and recognizes them by what's on it (`SCREEN_SIGS` in the script). Once a terminal is identified, the match is remembered in `~/.cache/orca-widget/state.json`, so the agent is still tracked after its banner scrolls away. A terminal title starting with `bob`/`ollama` also works as a shortcut. In practice Bob overwrites the title, and `orca terminal rename` doesn't change what the API reports.

## Files

| File | What it does |
|---|---|
| `orca-widget-sync` | One sync pass: reads Orca, then pushes to the widget only if what's shown changed. Python 3.9 stdlib. |
| `install.sh` | `install` / `uninstall` / `status` for the launchd agent |
| `launchd/…plist.template` | The launchd job (rendered by `install.sh`) |
| `hooks/claude-settings-snippet.json` | Optional Claude Code hooks for instant refresh |

## How state is determined

| Source | Agents | State |
|---|---|---|
| `orca worktree ps --json` → `agents[]` (live panes only) | Claude, Gemini, Cursor, … (anything with Orca hooks installed) | Orca's own: `working`, `blocked`/`waiting` (shown as *needs input*), `idle`, `done` |
| `orca terminal list --json` + `orca terminal read --screen` | IBM Bob, Ollama | Approval prompt on screen (`Approve Once`, `Press Enter to confirm`) → *needs input*; output in the last 6 s → *working*; quiet → *idle*; disconnected → *exited* |

Rows are sorted needs input → working → idle → done → exited. When an agent moves into `blocked` or `waiting`, that push also sends a one-time macOS notification. If the Orca runtime isn't reachable, the widget shows "Orca is not running". Tapping the widget opens Orca.

## Configuration (environment variables)

Set these in the plist's `EnvironmentVariables` and re-run `./install.sh`. You can also export them before running the script by hand.

| Variable | Default | Meaning |
|---|---|---|
| `ORCA_TW_TARGET` | `orca-agents` | Widget target name |
| `ORCA_TW_UNHOOKED` | `^\s*(bob\|ollama\|cursor)\b` | Regex for terminal titles without hooks; group 1 is the agent |
| `ORCA_TW_TAGS` | (none) | Agent tag overrides, e.g. `cursor=crs,claude=cc` |
| `ORCA_TW_SPINNER` | `pipe` | `pipe`, `loop`, `scan`, `bounce`, `slide`, `wave`, `none` |
| `ORCA_TW_BAR` | `equals` | `equals`, `hash`, `blocks`, `lamps`, `line`, `none` |
| `ORCA_TW_BAR_WIDTH` | `10` | Progress bar cells |
| `ORCA_TW_BAR_FULL_SECS` | `300` | Seconds of work for a full bar |
| `ORCA_TW_FONT` | `Menlo` | Widget font (empty = TerminalWidget default) |
| `ORCA_TW_WIDGET_SIZE` | `xl` | `small`, `medium`, `large` or `xl`. Text styles size the font to fill this widget, because `--fit-text` doesn't scale multi-line text. The table is ~75 columns, so it's only readable on `xl` |
| `ORCA_TW_PADDING` | `18` | Points of padding around text styles (0–64) |
| `ORCA_TW_LABEL` | `logo` | `logo` (glyph mark) or `tag` (`[cld]`) |
| `ORCA_TW_LOGOS` | (none) | Mark overrides, e.g. `cursor=▲` |
| `ORCA_TW_FONT_SIZE` | auto | Fixed font size in points, overriding the automatic size |
| `ORCA_TW_STYLE` | `ascii` | `ascii`, `pipeline`, `flap`, `table` |
| `ORCA_TW_COLORS` | (none) | Agent color overrides, e.g. `claude=#ff8800` |
| `ORCA_TW_ANSI` | `truecolor` | `truecolor`, `256`, `off` |
| `ORCA_TW_SPIN_SECS` | `30` | Seconds per spinner frame |
| `ORCA_TW_ACTIVE_SECS` | `6` | Output this recent counts as *working* |
| `ORCA_TW_NOTIFY_ON` | `blocked,waiting` | States that trigger a notification (add `done` to be told when a turn finishes) |
| `ORCA_TW_INTERVAL` | `5` | Poll seconds (read by `install.sh`) |
| `ORCA_BIN`, `TW_BIN` | `/usr/local/bin/orca`, `~/bin/terminal-widget` | Binary paths |

## Useful commands

```bash
orca-widget-sync --watch             # live log of state changes (no push), Ctrl-C to stop
orca-widget-sync --dry-run --print   # show rows and the command, push nothing
orca-widget-sync --force             # push now even if unchanged
./install.sh status                  # launchd state + recent errors
terminal-widget log --target orca-agents --follow
./install.sh uninstall
```

## Optional: instant refresh from Claude Code

Merge the entries in `hooks/claude-settings-snippet.json` into `~/.claude/settings.json`, next to Orca's managed hooks rather than replacing them. Claude prompt, notification and stop events then refresh the widget within about 1 s instead of on the next tick.
