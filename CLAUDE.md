# Track & Field Career Game (Godot)

In-depth career mode track and field (yleisurheilu) game, built in Godot together with the user.

**Status:** M1 in progress — athlete model, character creation and weekly training done. Next: Finnish youth calendar, then 800m race simulation. Milestones: `docs/ROADMAP.md`.
**Design doc:** `docs/GDD.md` — the source of truth for all design decisions. Read it before design or code work.

**User:** no programming experience — explain how to run/test things in plain steps; Claude writes all code.

## Tech & structure
- Godot **4.7.2** (user's version), GDScript only, GL Compatibility renderer (PC + mobile). Base viewport 1280x720, stretch `canvas_items`/`expand`.
- `scenes/main.tscn` + `scripts/main.gd` — app shell; applies theme, hosts the current screen.
- Autoloads: `Data` (`scripts/core/data.gd`, loads `data/*.json`), `Router` (`scripts/core/router.gd`, `Router.go("screen_id")`; register screens in `SCREENS`), `Game` (`scripts/core/game.gd`, current athlete + date; career starts 2 Nov 2026).
- `Athlete` (`scripts/core/athlete.gd`): attributes are floats 1–20 keyed by id from `data/attributes.json`; `to_dict`/`from_dict` for saving. `AthleteFactory` builds the 14-year-old from creation choices (base ranges + background answer effects from `data/background_questions.json` + 12 points, max +3 each).
- Screens built in code use `UIKit` (`scripts/ui/ui_kit.gd`) helpers: labels, panels, toggles, FM-style `attr_row` with value colours.
- Screens: `scenes/screens/*.tscn` with scripts in `scripts/ui/`.
- Theme is built in code: colours/sizes in `ui/palette.gd`, styles in `ui/theme_builder.gd`. Label variations: TitleLabel, HeadingLabel, MutedLabel, CaptionLabel; button variation: PrimaryButton. Font: Inter (`assets/fonts`, OFL).
- World data lives in `data/*.json` (events, attributes) — never hard-code real-world data in scripts.
- Verify changes before pushing: download Godot 4.7.2 Linux build to the scratchpad, run `godot --headless --import --path .` then `godot --headless --path . --quit-after 30` and check for errors; screenshots via `xvfb-run ... --rendering-driver opengl3 --write-movie out.png --fixed-fps 10 --quit-after 15`, or the click-through tour `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot_tour.gd -- <out_dir>` (update it when screens change). Look at the screenshots before pushing.
- `Training` (`scripts/core/training.gd`): weekly simulation (fatigue day by day, progression per week); `Game.advance_week()` runs it with `Game.training_plan`. Career hub has Overview / Training / Last week tabs + Continue. Tune with `tools/training_balance.gd`.
- On the user's Windows PC: Godot is at `C:\Users\timo8\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (run the tour without xvfb). Git CLI isn't on PATH: use GitHub Desktop's `%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe` to commit; pushing needs the user's login, so ask them to press "Push origin" in GitHub Desktop. Run Godot via `Start-Process ... -RedirectStandardOutput` with a timeout (piped output can hang).
- `-s` tool scripts can't use autoload names (`Data`, `Game`) or classes that use them at compile time: `load()` those scripts inside the running tree instead.
- Visuals: the user cares about realism; get reference images/specs before drawing real-world things (stadium layout etc.) instead of guessing.

## Working rules
- **Model recommendation:** start every reply with a line saying which model the user should use for their *next* message:
  `**Next message: Opus** / **Next message: Sonnet**` (+ suggested effort: low / medium / high).
  - Opus: design discussions, architecture, complex systems, hard bugs.
  - Sonnet: routine GDScript implementation, small features, fixes.
- Keep sessions focused on one task; record decisions in docs, not just chat.
- Commit and push at the end of every work session.
