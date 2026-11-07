# Configuring tw-orca-tracking

Everything beyond the basics in the [README](README.md): styles, what each state looks like, how agents are tracked, every setting, and troubleshooting.

- [Changing settings](#changing-settings)
- [Styles](#styles)
- [States, spinners and bars](#states-spinners-and-bars)
- [Agent marks and colors](#agent-marks-and-colors)
- [How agents are tracked](#how-agents-are-tracked)
- [All settings](#all-settings)
- [Commands](#commands)
- [Instant refresh from Claude Code](#instant-refresh-from-claude-code)
- [Troubleshooting](#troubleshooting)
- [Files](#files)

## Changing settings

Every setting is an `ORCA_TW_*` environment variable. Set it on the install command, and `install.sh` copies it into the launchd job:

```bash
ORCA_TW_STYLE=pipeline ORCA_TW_SPINNER=loop ./install.sh
```

Re-running `./install.sh` *without* a variable puts that setting back to its default. Include every setting you want to keep each time.

To try a setting once without installing it:

```bash
ORCA_TW_STYLE=flap orca-widget-sync --force
```

The next tick of the background job puts the installed style back.

## Styles

`ORCA_TW_STYLE` picks the layout. All styles except `table` color each agent.

### `ascii` (default)

The table drawn as monospace text.

```
agent      workspace     task                 state             since
◈ cursor   web           #87 Fix navbar       ! needs you       1m
≡ ibm bob  billing       PR 12                / [===>      ]    2m
✻ claude   api/feat-x    ENG-142 Add auth     - [=>        ]    now
♞ ollama   sandbox                            · idle            3m
orca · 2 working · 1 needs you                                  04:23
```

### `pipeline`

Each agent is a stage of an [ascii.rest pipeline](https://ascii.rest/pipeline/).

```
╭─ orca · 1 working ───────────────────────────────────────────────────────────╮
│   ▄▄  ≡ ibm bob  tengingarstjori           ████░░░░░░░░░░░░░░   1m  running  │
│  !    ◈ cursor   fix navbar                ███████░░░░░░░░░░░   2m  waiting  │
│  +    ✻ claude   Repository architecture…  ██████████████████  52m  passed   │
│  ·    ♞ ollama   sandbox                   ··················  38m  idle     │
╰──────────────────────────────────────────────────────────────────────────────╯
```

| Agent state | Glyph | Bar | Status |
|---|---|---|---|
| working | spinner | fills with time in the turn, **capped at 90%** | running |
| blocked / waiting | `!` | holds where it stopped, resumes after you approve | waiting |
| done (Orca hooks) | `+` | full | passed |
| idle right after a Bob/Ollama turn | `+` | full | passed (for 10 min) |
| idle | `·` | `··················` | idle |
| exited | `x` | `··················` | exited |

**About the bar:**
- **It isn't real progress.** It shows how long the agent has been working.
- **The 90% cap** means a long task never looks finished. Only a real `done` from Orca fills the bar.
- **Bob and Ollama** never report `done`. When one goes quiet after working, it counts as *passed* for 10 minutes, then shows idle. That's a guess from the output stopping.
- **The title line** turns amber when an agent needs you.

### `flap`

A departures board after [ascii.rest/split-flap](https://ascii.rest/split-flap/), amber on black.

```
╭─────────────────────────────────────────────────────────╮
│ O R C A     A G E N T S                       0 4 : 5 7 │
│                                               ▔ ▔   ▔ ▔ │
├─────────────────────────────────────────────────────────┤
│     task                      status              since │
│ ≡   B I L L I N G             W O R K I N G       2 M   │
│ ▔   ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔   ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔ ▔   ▔ ▔ ▔ │
╰─────────────────────────────────────────────────────────╯
```

The optional flip animation is off by default (see [Animation is slow](#animation-is-slow)).

### `table`

TerminalWidget's native table with zebra rows. TerminalWidget can't color table cells, so there's no per-agent color.

## States, spinners and bars

These apply to the `ascii` style. `pipeline` has its own bar, described above.

| State | Shown as | Notes |
|---|---|---|
| working | `/ [===>      ]` | Spinner plus progress bar. The bar fills over 5 minutes of work |
| blocked / waiting | `! needs you` | Also sends a one-time macOS notification |
| idle | `· idle` | |
| done | `+ done` | |
| exited | `x exited` | Terminal closed or disconnected |

Rows are sorted: needs you, working, idle, done, exited.

**Spinners** (`ORCA_TW_SPINNER`, frames from [ascii.rest/spinners](https://ascii.rest/spinners/)):
- `pipe` is the default: `| / - \`
- `loop`: `▝▀▘ ▀▀ ▝▜ █ ▗▟ ▄▄`…
- `none`
- `scan`, `bounce`, `slide` and `wave` are bar-shaped, so they replace the progress bar.

**Progress bars** (`ORCA_TW_BAR`, from [ascii.rest/progress-bar](https://ascii.rest/progress-bar/)):

```
equals  [===>      ]   hash   [####......]   blocks ▕███▌      ▏
lamps   ████░░░░░░     line   ━━━━──────
scan    ··░▓█··        bounce [  o   ]       slide  [  ===   ]      wave ▂▅▇█▇▅▂
```

**Linked issues:** if an Orca workspace has a linked issue, PR or Linear ticket, its key (`ENG-142`, `#87`, `PR 12`) goes at the start of the task column.

## Agent marks and colors

| Mark | Tag | Color | Agent |
|---|---|---|---|
| `✻` | `cld` | orange `#e07a3f` | Claude |
| `◈` | `cur` | teal `#2dd4bf` | Cursor |
| `≡` | `bob` | IBM blue `#4589ff` | IBM Bob |
| `♞` | `oll` | pink `#f472b6` | Ollama |
| `✦` / `◎` | `gem` / `cdx` | violet / green | Gemini / Codex |
| `•` | first 3 letters | gray | Anything else |

**About the marks:**
- **Not brand logos:** they're plain glyphs that nod to each agent: Claude Code's spinner star, IBM's stripes, Cursor's cube, Gemini's sparkle.
- **One cell wide:** the Menlo font draws each one itself at exactly one character wide, which keeps the columns aligned. Glyphs Menlo doesn't have (☰, ⬢, ⌬) fall back to another font at a different width and push the columns out of line.
- **Fixed colors:** *needs you* is always amber and *exited* always red.

**Changing them:**

```bash
ORCA_TW_LOGOS="cursor=▲,ollama=ʘ" ORCA_TW_COLORS="claude=#ff8800" ./install.sh
```

- `ORCA_TW_LABEL=tag` shows `[cld] claude` instead of the mark.
- `ORCA_TW_TAGS="cursor=crs"` changes the tags.

## How agents are tracked

| Source | Agents | State |
|---|---|---|
| `orca worktree ps --json` (agents with Orca status hooks) | Claude, Cursor, Gemini, … | Orca's own: `working`, `blocked`/`waiting`, `idle`, `done` |
| `orca terminal list` + `orca terminal read --screen` | IBM Bob, Ollama, and Cursor without hooks | Approval prompt on screen means *needs you*; output in the last 6 s means *working*; quiet means *idle*; disconnected means *exited* |

**Hooks:** run `orca agent hooks status` and check that `claude` and `cursor` show `installed`. Turn them on with `orca agent hooks on`. With hooks, agents report exact states and conversation names.

**Screen detection:** Bob and Ollama are recognized from text on their terminal screen (`SCREEN_SIGS` in the script):
- **Bob:** "Agent Mode", "Approve Once"
- **Ollama:** `>>> Send a message`
- **Cursor:** "Cursor Agent", "Run (once)"

Once identified, a terminal is remembered in `~/.cache/orca-widget/state.json`, so it's still tracked after its banner scrolls away. A terminal title starting with `bob`, `ollama` or `cursor` also works as a shortcut. In practice Bob overwrites its title, and `orca terminal rename` doesn't change what Orca's API reports.

**Other behavior:**
- If Orca isn't running, the widget shows `[x] orca offline`.
- Tapping the widget opens Orca.

## All settings

| Variable | Default | Meaning |
|---|---|---|
| `ORCA_TW_STYLE` | `ascii` | `ascii`, `pipeline`, `flap`, `table` |
| `ORCA_TW_TARGET` | `orca-agents` | Widget target name |
| `ORCA_TW_WIDGET_SIZE` | `xl` | `small`, `medium`, `large`, `xl`. The font is sized to fill this widget |
| `ORCA_TW_FONT_SIZE` | auto | Fixed font size in points |
| `ORCA_TW_FONT` | `Menlo` | Widget font |
| `ORCA_TW_PADDING` | `18` | Points of padding around the text (0–64) |
| `ORCA_TW_SPINNER` | `pipe` | `pipe`, `loop`, `scan`, `bounce`, `slide`, `wave`, `none` |
| `ORCA_TW_SPIN_SECS` | `30` | Seconds per spinner frame |
| `ORCA_TW_BAR` | `equals` | `equals`, `hash`, `blocks`, `lamps`, `line`, `none` |
| `ORCA_TW_BAR_WIDTH` | `10` | Progress bar cells (`ascii` style) |
| `ORCA_TW_BAR_FULL_SECS` | `300` | Seconds of work for a full bar |
| `ORCA_TW_LABEL` | `logo` | `logo` (glyph mark) or `tag` (`[cld]`) |
| `ORCA_TW_LOGOS` | (none) | Mark overrides, e.g. `cursor=▲` |
| `ORCA_TW_TAGS` | (none) | Tag overrides, e.g. `cursor=crs` |
| `ORCA_TW_COLORS` | (none) | Color overrides, e.g. `claude=#ff8800` |
| `ORCA_TW_ANSI` | `truecolor` | `truecolor`, `256`, `off` |
| `ORCA_TW_PIPE_WIDTH` | `18` | Pipeline bar cells |
| `ORCA_TW_PIPE_CAP` | `0.9` | Highest fill a running bar reaches |
| `ORCA_TW_PIPE_PASSED_SECS` | `600` | How long a finished Bob/Ollama turn shows *passed* |
| `ORCA_TW_FLAP_COLS` | `agent:1,task:12,status:9,since:3` | Board columns as `field:tiles`; fields are `agent`, `workspace`, `task`, `status`, `since` |
| `ORCA_TW_FLAP_ROWS` | `6` | Board rows |
| `ORCA_TW_FLAP_TITLE` | `AGENTS` | Board header |
| `ORCA_TW_FLAP_FG` / `ORCA_TW_FLAP_BG` | `#f5c542` / `#0b0b0b` | Board colors |
| `ORCA_TW_FLAP_FRAMES` | `0` | Flip-animation frames per change |
| `ORCA_TW_FLAP_FRAME_SECS` | `0.35` | Pause between flip frames |
| `ORCA_TW_ACTIVE_SECS` | `6` | Output this recent counts as working (Bob/Ollama) |
| `ORCA_TW_UNHOOKED` | `^\s*(bob\|ollama\|cursor)\b` | Terminal-title shortcut regex |
| `ORCA_TW_NOTIFY_ON` | `blocked,waiting` | States that send a notification (add `done` to hear when a turn ends) |
| `ORCA_TW_INTERVAL` | `5` | Poll seconds (used by `install.sh`) |
| `ORCA_TW_APP_ID` | `com.stablyai.orca` | App opened when you tap the widget |
| `ORCA_TW_CACHE` | `~/.cache/orca-widget` | Where state is saved between runs |
| `ORCA_BIN`, `TW_BIN` | `/usr/local/bin/orca`, `~/bin/terminal-widget` | Binary paths |

## Commands

```bash
orca-widget-sync --watch             # live log of state changes, Ctrl-C to stop
orca-widget-sync --dry-run --print   # show rows and the command, push nothing
orca-widget-sync --force             # push now even if nothing changed
./install.sh status                  # background job state + recent errors
./install.sh uninstall               # stop and remove the background job
terminal-widget log --target orca-agents --follow
```

## Instant refresh from Claude Code

Merge the entries in [`hooks/claude-settings-snippet.json`](hooks/claude-settings-snippet.json) into `~/.claude/settings.json`. Add them next to Orca's managed hooks rather than replacing those. Claude's prompt, notification and stop events then refresh the widget right away instead of on the next 5-second tick.

## Troubleshooting

### Animation is slow

macOS redraws desktop widgets only about every 30–60 seconds and skips pushes in between. You can see this in `terminal-widget log --target orca-agents`, where revision numbers jump. That's why the spinner moves one frame per 30 seconds and flip animation is off: faster frames would never reach the screen.

### Text is tiny or overflows

The font is sized for `ORCA_TW_WIDGET_SIZE` (extra-large by default). If your widget is a different size, set it, or fix the size with `ORCA_TW_FONT_SIZE=15`. The `ascii` table is about 75 characters wide, so it's only readable on an extra-large widget.

### Colors don't show

Try `ORCA_TW_ANSI=256`, or `ORCA_TW_ANSI=off` for plain text.

### Bob or Ollama is missing

Check that its screen shows one of the recognized phrases (see [How agents are tracked](#how-agents-are-tracked)). If your version prints something different, add it to `SCREEN_SIGS` in `orca-widget-sync`.

### Nothing updates

- Run `./install.sh status` and check `~/Library/Logs/orca-widget-sync.log`.
- Make sure the widget's **Target name** is `orca-agents`.
- Run `orca status` to confirm Orca is running.

## Files

| File | What it does |
|---|---|
| `orca-widget-sync` | One sync pass: reads Orca, then pushes to the widget only if what's shown changed. Python 3.9, standard library only |
| `install.sh` | Install, uninstall or check the background job |
| `launchd/…plist.template` | The background job definition (filled in by `install.sh`) |
| `hooks/claude-settings-snippet.json` | Optional Claude Code hooks for instant refresh |
| [`RESEARCH.md`](RESEARCH.md) | Design notes and the flow diagram |
