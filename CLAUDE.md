# Track & Field Career Game (Godot)

In-depth career mode track and field (yleisurheilu) game, built in Godot together with the user.

**Status:** M0 done (project skeleton + main menu). Next: M1 — 800m youth season. Milestones: `docs/ROADMAP.md`.
**Design doc:** `docs/GDD.md` — the source of truth for all design decisions. Read it before design or code work.

**User:** no programming experience — explain how to run/test things in plain steps; Claude writes all code.

## Tech & structure
- Godot **4.7.2** (user's version), GDScript only, GL Compatibility renderer (PC + mobile). Base viewport 1280x720, stretch `canvas_items`/`expand`.
- `scenes/main.tscn` + `scripts/main.gd` — app shell; applies theme, hosts the current screen.
- Autoloads: `Data` (`scripts/core/data.gd`, loads `data/*.json`), `Router` (`scripts/core/router.gd`, `Router.go("screen_id")`; register screens in `SCREENS`).
- Screens: `scenes/screens/*.tscn` with scripts in `scripts/ui/`.
- Theme is built in code: colours/sizes in `ui/palette.gd`, styles in `ui/theme_builder.gd`. Label variations: TitleLabel, HeadingLabel, MutedLabel, CaptionLabel; button variation: PrimaryButton. Font: Inter (`assets/fonts`, OFL).
- World data lives in `data/*.json` (events, attributes) — never hard-code real-world data in scripts.
- Verify changes before pushing: download Godot 4.7.2 Linux build to the scratchpad, run `godot --headless --import --path .` then `godot --headless --path . --quit-after 30` and check for errors; screenshots via `xvfb-run ... --rendering-driver opengl3 --write-movie out.png --fixed-fps 10 --quit-after 15`.

## Working rules
- **Model recommendation:** start every reply with a line saying which model the user should use for their *next* message:
  `**Next message: Opus** / **Next message: Sonnet**` (+ suggested effort: low / medium / high).
  - Opus: design discussions, architecture, complex systems, hard bugs.
  - Sonnet: routine GDScript implementation, small features, fixes.
- Keep sessions focused on one task; record decisions in docs, not just chat.
- Commit and push at the end of every work session.
