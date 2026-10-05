# Track & Field Career Game (Godot)

In-depth career mode track and field (yleisurheilu) game, built in Godot together with the user.

**Status:** M1 done — character creation, weekly training, season calendar, save/load, the 800m race simulation, season rankings and the responsive UI (desktop + phone portrait) are done. Next: M2 (day-by-day mode, injuries, coaching, school). Youth opponents stay fictional (minors); real athletes only at senior level. Milestones: `docs/ROADMAP.md`.
**Design doc:** `docs/GDD.md` — the source of truth for all design decisions. Read it before design or code work.

**User:** no programming experience — explain how to run/test things in plain steps; Claude writes all code.

## Tech & structure
- Godot **4.7.2** (user's version), GDScript only, GL Compatibility renderer (PC + mobile). Base viewport 1280x720, stretch `canvas_items`/`expand`.
- `scenes/main.tscn` + `scripts/main.gd` — app shell; applies theme, hosts the current screen.
- Autoloads: `Data` (`scripts/core/data.gd`, loads `data/*.json`), `Router` (`scripts/core/router.gd`, `Router.go("screen_id")`; register screens in `SCREENS`), `Game` (`scripts/core/game.gd`, current athlete + date; career starts 2 Nov 2026).
- `Athlete` (`scripts/core/athlete.gd`): attributes are floats 1–20 keyed by id from `data/attributes.json`; `to_dict`/`from_dict` for saving. `AthleteFactory` builds the 14-year-old from creation choices (base ranges + background answer effects from `data/background_questions.json` + 12 points, max +3 each).
- **Responsive UI:** `Layout` (`ui/layout.gd`) holds `Layout.compact` (true for a portrait/squarish window, i.e. phone). `main.gd` picks the mode on every window resize, sets the window `content_scale_size` (wide: 1280x720-based, scale floor 0.7; compact: 480 px logical width), rebuilds the theme (`ThemeBuilder.build(compact)`) and emits `Router.layout_changed`. Every screen builds its layout from `Layout.compact` and rebuilds on that signal (hub, wizard, race, load game, main menu). Rules: use `UIKit.flex()` (BoxContainer that is a row on PC, a column on phone), `Layout.page_margin()`, 44 px minimum for anything tappable, **no hover-only info** (use `UIKit.attr_row(..., description)` / `UIKit.tap_to_explain` and `ChoiceCard` instead of tooltips). Hub: tabs on top (`TabButton`) on PC, bottom bar (`BottomTabButton`) on phone. Race decisions are a full-screen dimmed overlay. Check with `tools/layout_check.gd` (live-resizes through 1280x720, 720x1280, 390x844, 1000x900, 844x390) and `screenshot_tour.gd --resolution 390x844`.
- **Backdrop:** `scripts/ui/backdrop.gd` + `ui/backdrop.gdshader` draw the background gradient; a photo in `assets/backgrounds/<screen_id>.jpg` (or `default.jpg`) is shown blurred and darkened (see the README there). No photos are included yet; panels are slightly translucent (`Palette.SURFACE_PANEL`).
- Screens built in code use `UIKit` (`scripts/ui/ui_kit.gd`) helpers: labels, panels, toggles, FM-style `attr_row` with value colours.
- Screens: `scenes/screens/*.tscn` (mostly just a root node now) with scripts in `scripts/ui/`; the hub, wizard and race screen build their shell in code so it can switch layout.
- Theme is built in code: colours/sizes in `ui/palette.gd`, styles in `ui/theme_builder.gd`. Label variations: TitleLabel, HeadingLabel, MutedLabel, CaptionLabel; button variation: PrimaryButton. Font: Inter (`assets/fonts`, OFL).
- World data lives in `data/*.json` (events, attributes) — never hard-code real-world data in scripts.
- Verify changes before pushing: download Godot 4.7.2 Linux build to the scratchpad, run `godot --headless --import --path .` then `godot --headless --path . --quit-after 30` and check for errors; screenshots via `xvfb-run ... --rendering-driver opengl3 --write-movie out.png --fixed-fps 10 --quit-after 15`, or the click-through tour `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot_tour.gd -- <out_dir>` (update it when screens change). Look at the screenshots before pushing.
- `Training` (`scripts/core/training.gd`): weekly simulation (fatigue day by day, progression per week); `Game.advance_week()` runs it with `Game.training_plan`. Career hub has Overview / Training / Calendar / Last week tabs + Continue.
- `Calendar` (`scripts/core/calendar.gd`): dated meets from `data/competitions.json` (keys `id@year`), eligibility, standards; `Game.entries` holds entered meet keys; races in a week are passed to `Training.simulate_week` (report `races` has meet + fatigue at race time, ready for the race sim). Tune with `tools/training_balance.gd`.
- On the user's Windows PC: Godot is at `C:\Users\timo8\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (run the tour without xvfb). Git CLI isn't on PATH: use GitHub Desktop's `%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe` to commit; pushing needs the user's login, so ask them to press "Push origin" in GitHub Desktop. Run Godot via `Start-Process ... -RedirectStandardOutput` with a timeout (piped output can hang).
- Races: `Game.advance_week()` plays the week with `WeekSim` (`scripts/core/week_sim.gd`) and returns true when it stops on a race day; then `Game.race_day` (`RaceDay`: field from `Rivals`, heats/final) is run by the race screen (`scripts/ui/race_screen.gd`) and `Game.finish_race()` continues the week. `Race` (`scripts/core/race.gd`) is the step engine (outdoor 400 m or indoor 200 m geometry); `RacePerformance` maps attributes → ability → time (`data/races.json`). Dots are drawn by `scripts/ui/race_runners_view.gd`. Tune with `tools/race_balance.gd`.
- `Rankings` (`scripts/core/rankings.gd`): season = 1 Nov–31 Oct; `season_list` ranks the player + rivals by season best (`sb`/`sb_season` on each rival). `Rivals.train_week` also lets rivals race on their own (chance per month in `data/races.json`). Career hub "Rankings" tab. Check with `tools/rankings_check.gd`.
- `SaveGame` (`scripts/core/save_game.gd`): JSON slots in `user://saves/` (autosave every week + snapshots from the Save button); `Game.to_dict/from_dict`. JSON makes numbers floats, so dates go through `Game.int_date`. Dev tools must set `SaveGame.DIR` to another folder so they never overwrite the user's saves (the tour uses `user://tour_saves/`).
- `-s` tool scripts can't use autoload names (`Data`, `Game`) or classes that use them at compile time: `load()` those scripts inside the running tree instead.
- Visuals: the user cares about realism; get reference images/specs before drawing real-world things (stadium layout etc.) instead of guessing.

## Working rules
- **Model recommendation:** start every reply with a line saying which model the user should use for their *next* message:
  `**Next message: Opus** / **Next message: Sonnet**` (+ suggested effort: low / medium / high).
  - Opus: design discussions, architecture, complex systems, hard bugs.
  - Sonnet: routine GDScript implementation, small features, fixes.
  - Switching models mid-conversation makes the new model re-read the whole conversation (costs extra credits). So recommend a *different* model only for the start of a **new** conversation; within an ongoing one, recommend staying on the current model. When a task is finished, suggest starting a new conversation.
- Keep sessions focused on one task; record decisions in docs, not just chat.
- Commit and push at the end of every work session.
