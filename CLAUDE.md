# Track & Field Career Game (Godot)

In-depth career mode track and field (yleisurheilu) game, built in Godot together with the user.

**Docs:** `docs/GDD.md` = the source of truth for every design decision (read the relevant part before design or code work);
`docs/ROADMAP.md` = milestones and the order of sessions; `docs/CODEMAP.md` = the per-system details (class names, data files,
tools, numbers: **read the paragraph of a system when you work on it**; it holds what this file used to say at length);
`docs/AUDIT.md` = the check-ins (realism audits + project reviews); `docs/PLAYTESTS.md` = the user's playtest notes.

**User:** no programming experience: explain how to run and test things in plain steps; Claude writes all code.

**Status (2026-10-25):** M1 done (character creation, training, calendar, saves, the 800 m race, rankings, responsive UI). M2 part 1
done (day-by-day mode, health, season periodization, race realism R1–R5 + commentary R4, meet formats, the multi-year check and the
talent balance). M2 part 2 built so far: the coaching + school + people design (GDD 4.9), sessions C1–C6 (coach model, moments,
People tab + Sunday talk, proposals + Veto, goals + race advice, the coach market), M1 (the mind), D1 (research data), S1–S3b (school,
the application, lukio, matriculation), P1 (the cast + moments for ages 14–15). Three check-ins done (2026-10-10, 10-11, 10-18); the
fix session after the third one (TUVA, offers to minors through a parent, `GameConfig`, `-Quick`, split school file, the lukio
courses setting, this trimmed file) is in `docs/GDD.md` "Built (check-in fixes 2026-10-18)". Season playtest 2 (2026-10-18: "a tedious
micromanagement clicker") led to the redesign **GDD 4.10 "plan → play → see"** (read it before any work on the week, the people or the
UI: one Sunday planner, mid-week stops only for real decisions, causes visible, people as state + free-time slots). F1 (the 11
playtest bugs) done (GDD 4.10 "Built (step F1)"; coach texts say `{he}` / `{his}`, never a bare "he"). V1 (the look) done: **GDD 5
"The look (V1)"** is the style guide for every new or restyled screen (dark "Stadium Night", condensed numbers, TV-style race card;
mock-ups in `docs/v1/`). **L1 done** in two sessions (user, 2026-10-23): L1a (the V1 kit, the Sunday week planner = the This week
tab, the coach's notes, moments wait for Sunday, the new tabs; GDD 4.10 "Built (step L1a)") and L1b (the 9 free-time slots + standing
habits replacing the school's two settings, invitations in the slots, save v5; "Built (step L1b)"). **L2 is split** (user, 2026-10-25,
GDD 4.10 "L2's questions"): **L2a done** (the "what this race did" card after every race + the scratch card, kept in
`Game.race_cards`; "Built (step L2a)"). Next, in `docs/ROADMAP.md` order: L2b (causes everywhere) → L3 (the loop) → K1 (Career tab) → the user's playtest 3 → P2 →
R6–R7 (races) → G1 / G3 / T1 / G2 → D2 → restyle → B1, then the check-in at the end of M2. Youth opponents stay fictional (minors); real athletes
only at senior level.

## How to run and check (Windows PC of the user)

- Godot 4.7.2: `C:\Users\timo8\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (the `_console.exe`
  prints to the terminal). Run with `Start-Process ... -RedirectStandardOutput` and a timeout (piped output can hang). A tool:
  `godot --headless --path . -s res://tools/<name>.gd [-- args]`. Windowed (UI tools): `--rendering-driver opengl3 --resolution 1280x720`.
- Git CLI is not on PATH: use GitHub Desktop's `%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe`. Commit there;
  pushing needs the user's login: **tell the user to press "Push origin" in GitHub Desktop** (and remind them when there are unpushed commits).
- **`run_all_checks.bat`** (double-click; `tools/run_all_checks.ps1`): every check with ONE PASS / FAIL list (a check passes only with
  its "all good" line, no FAIL line and no SCRIPT ERROR / Parse Error in stdout or stderr; outputs kept in `%TEMP%\llookjbb_checks_*`).
  Full run ~30-35 min on the user's PC (run it at the end of a session; `playtest_fix_check` alone ~14 min, limit 1200 s); **`-Quick`** ~5 min (use it while working); `-Only help,health` runs the checks
  whose name contains a word. Not in it (too slow, run by Claude after engine changes): `race_shape`, `training_balance` (parts 3+),
  `race_check`, `layout_check`, the tour, `career_check`, the long playtests.
- **Fingerprints that must stay identical unless a change is MEANT to change them** (prove it after each step): `training_balance.gd -- 0`
  (coach row 206.798298350 / 14.102831594 / 1226.006524079), `quick_fingerprint.gd` (races hash 73182f4e…), `school_fingerprint.gd`
  (grades 8–9: 42fd3635… / 01dd20d7…, all 55076d77…). The rule: the neutral setting (lab) keeps them identical.
- **`GameConfig`** (`scripts/core/game_config.gd`): ONE place for the game's switches, two presets: **`real`** = the player's game
  (what `main.gd` uses: talks, proposals, goals, suggestions, the market, the school's decisions and the people all on) and **`lab`** =
  the neutral game of the fingerprints (a club coach of 10s, moods in the middle, school life load 0, no injuries, nothing that stops
  Play week). A program picks one in one line, with overrides when needed: `GameConfig.use("lab", {"health": true})`; flip one option
  mid-run with `GameConfig.set_option("mind", false)`; `GameConfig.describe()` prints it. `-s` tools cannot name classes: they
  `load("res://scripts/core/game_config.gd").use(...)`. `main.gd` only uses `real` when no preset was chosen before (a tool that runs
  `main.tscn` picks its own first). Never set a system's static switch directly in new code.
- Screens: `tools/layout_check.gd [-- <dir> [WxH]]` (live resize through five sizes, prints OVERFLOW / SQUEEZED / WRONG),
  `tools/screenshot_tour.gd -- <out_dir>` (click-through tour with screenshots; `--resolution 390x844` for the phone), `tools/help_check.gd`
  (every "?" pressed; headless it tests the phone layout only, run it windowed for the PC layout). Look at the screenshots before
  pushing. Tools use their own save folders (`SaveGame.DIR`: `user://tool_saves/`, `user://tour_saves/`), never the player's saves.
- Playtest by tool: `tools/season_playtest.gd -- <out_dir> [coach|hard|season] [careful|neutral|player] [seed] [days]` plays a season through
  the real hub (counts stops by kind a week); `tools/watch_race.gd` (a windowed race); the Dev menu of a debug build (main menu: watch a
  test race, jump the career forward, test moments).
- A Linux cloud session can download the Linux Godot build into the scratchpad and use `xvfb-run` for screenshots.

## Rules that bite (learned the hard way)

- **The check tools print "ALL CHECKS PASSED" even when a `SCRIPT ERROR` aborted one check function: always read stderr too.**
- A new `class_name` needs `godot --headless --import` once before tools see it. `tools/load_check.gd` loads every script (a headless
  import does not show parse errors).
- `-s` tool scripts cannot use autoload names (`Data`, `Game`, `Router`) or classes that use them at compile time: `load()` the script
  inside the running tree and read constants from an instance. Tools can't name `WeekPlan`: `load("res://scripts/core/week_plan.gd").make(days, intensities)`.
- Tools that play days with the people / talks / decisions on must answer stop events and play by the date (`while advance_day() != WEEK_DONE`
  never ends on a stop; a stop on Sunday evening returns STOP, not WEEK_DONE). Tools in `lab` never meet stops from the new systems.
- GDScript lambdas capture locals by value when they are made: create the controls before the closures that use them.
- Never keep a lambda bound to a node in a `static var`: Godot crashes on quit (exit code -1073741819 after "ALL CHECKS PASSED",
  L1b). Keep a `weakref(node)` instead and clear it in `_exit_tree`.
- JSON files: never edit them with PowerShell `Set-Content` (BOM); use the Edit tool. Godot's JSON reader misses the last binary digit of
  ~1 in 8 decimals: `SaveGame.load_slot` re-reads decimals from the text (`_exact_numbers`), so saves continue bit for bit.
- Every system has its own dice (seeded from the career, state saved as strings) and never touches the global dice: same career =
  same coach / cast / market; tools that need a fixed game seed it.
- A change that is not about the races never touches `race.gd` or the races hash (competitiveness etc. wait for a race session).
- Realism: world data lives in `data/*.json` with a source and read date, never in scripts; no real people below senior level; real
  coaches use neutral words and only facts from their listed pages (re-check before release). Get reference images / specs before
  drawing real things (stadium layout etc.). The user cares about realism over neat balance: the world varies; prove neutrality with a
  tool switch, not by making everything equal.
- The player decides, the game doesn't: no automatic decisions in races; a quick result follows a player-set tactic.
- Interaction is the point: the user chose the stricter −1 trust over quiet defaults; since L1a the Sunday planner is the one weekly
  stop (it opens every week) and mid-week stops are only for real things (GDD 4.10).
  Ask before anything that changes how the game plays beyond what was agreed.
- Split sessions rather than cut the user's picks (S3 became S3a / S3b); correct earlier claims a tool disproves.

## Tech & structure (one line per system; details in `docs/CODEMAP.md`)

**Engine and shell.** Godot **4.7.2**, GDScript only, GL Compatibility renderer (PC + mobile), base viewport 1280x720, stretch
`canvas_items`/`expand`. `scenes/main.tscn` + `scripts/main.gd` = app shell (theme, `GameConfig`, hosts the current screen). Autoloads:
`Data` (`scripts/core/data.gd`, loads `data/*.json`), `Router` (`Router.go("screen_id")`, screens registered in `SCREENS`), `Game`
(current athlete, today's date, the systems; career starts Mon 2 Nov 2026). Screens: `scenes/screens/*.tscn` (mostly a root node) with
scripts in `scripts/ui/`; the hub, wizard and race screen build their shell in code so it can switch layout.

**UI rules.** `Layout` (`ui/layout.gd`): `Layout.compact` = portrait / squarish window (phone); `main.gd` picks the mode on every resize,
sets `content_scale_size`, rebuilds the theme (`ThemeBuilder.build(compact)`) and emits `Router.layout_changed`; every screen builds from
`Layout.compact` and rebuilds on that signal. Use `UIKit` helpers (labels, panels, `flex()` = a row on PC and a column on a phone,
FM-style `attr_row`, `ChoiceCard`), `Layout.page_margin()`, `Layout.stacked()`, **44 px minimum for anything tappable, no hover-only
info** (use `attr_row(..., description)` / `UIKit.tap_to_explain`). Hub = a 56 px header bar with the tabs on PC (`TabButton`), a
bottom bar with icons on a phone (`BottomTabButton`): This week (`WeekPlanner`, the one place the week is shown and changed) / Season /
Calendar / People / Career / Rankings (old ids overview / training still work). Theme in code: `ui/palette.gd`, `ui/theme_builder.gd`;
the V1 kit for new screens: variations BigNumber / CardHeading / BodyLabel / ItemLabel / WhyLabel / SectionLabel …, `Icons` (Lucide,
`assets/icons`), `StatBar`, `CauseChip`, `CalloutCard`; fonts Inter + Barlow Condensed (numbers). Backdrop (big moments only; the hub
is plain BG): `scripts/ui/backdrop.gd` + a blurred photo in `assets/backgrounds/` (CC BY-SA, credits in its README; the `.import` files must keep `mipmaps/generate=true`; an
in-game Credits screen is still to do). **Help:** texts only in `data/help.json` (`screens` + `topics`, sections ≤ ~50 words, `version`);
`Help`, `HelpButton` ("?" with a "new" dot), `HelpPanel`, `HelpOverlay`.

**Core model.**
- `Athlete` (attributes floats 1–20 from `data/attributes.json`, `to_dict`/`from_dict`) + `AthleteFactory` (creation answers, the points
  pool: pool = 6 + the answers' experience, coach's spread, estimate; GDD 4.1.1).
- `Training` (session / fatigue / progression; age rate, puberty, novice bonus, dose per attribute, age brake; numbers in
  `data/training.json progression`), `Rivals` (the rival pool, age curves, bloom / drift / pace, churn), `Rankings`, `Calendar` (meets from
  `data/competitions.json`, eligibility, standards, date helpers; `Calendar.SEASONS_AHEAD` 20), `Standards` (real SM / TF / Kalevan limits
  with sources).
- Week plan: `WeekPlan` = `{days, intensity}`; `SeasonPlan` (`Game.season`; repeat or phases mode, `week_for(monday)` = the one place that
  answers "what is the plan for this week"; the coach's three plans Steady / Balanced / Ambitious + the ★ pick); `SeasonSystem` (the "three
  plans" stop, the rollover, easing back in); `FormSystem` (race-day Form from sharpness + freshness).
- **Day engine** (GDD 4.5/4.7): `Game.date` = today (the next day to play); `Game.advance_day()` / `advance_week()` / `finish_race()` return
  `DAY_DONE` / `WEEK_DONE` / `RACE` / `STOP`; `WeekSim` = the week in progress (day changes by player / coach / injury); `GameSystem`
  hooks (`on_day_start → on_health → on_day_end`, `on_week_end`, `on_answer`); `Game.post_event(source, title, text, choices, stop)` /
  `answer_event`; `Game.systems` order: Health, Season, Form, Coach, School, Mind, Moments (StoryletSystem), Goals, Suggests, Proposals,
  Market (see `_make_systems`).
- `HealthSystem` (soreness, injuries, illness, adaptation; `data/health.json`, `data/injuries.json`), UI in `HealthUI` / `HealthEventPanel`.
- `SaveGame`: JSON slots in `user://saves/`, autosave after every played day, **version 5** (L1b: the habits); older saves load (each
  system's state is `{}` until it first runs; a v4 save's study effort / free time become habits).

**Races.** `RaceDay` runs a meet as `single` / `sections` / `heats` (World Athletics table); `Race` = the pack engine (drafting, moves,
kick chain, boxes, falls, DNF/DQ; every number in `data/races.json`; same seed = same race); the player's cards and action bar
(`data/race_cards.json`); quick mode with a kick plan; `RacePerformance` maps attributes → time. `RaceCommentary` + `RaceStory` + the
coach voices (`data/race_commentary.json`, `data/coaches.json`) only READ the race. **L2a:** the race ends on "what this race did"
(`RaceRecap` records it, read-only; `RaceRecapView`; `data/race_recap.json`): `finish_race()` = `end_race_day()` + `resume_after_race()`,
the cards kept in `Game.race_cards` (the planner's race strap opens one), the scratch card from `Game.scratch_race`. UI: `race_screen.gd`, `RaceActionBar`, `CommentaryBox`
/ Strip / Ticker. Checks: `race_rounds`, `commentary_check`, `race_check`, `race_shape`, `quick_fingerprint`.

**People and school (M2 part 2; every one has a switch in `GameConfig`).**
- `CoachSystem` (coach records with 11 attributes, trust, fit; `data/coaching.json`; 12 real coaches in `real`), `CoachMarket` (Find a coach,
  scouting, offers: **under 18 an offer comes through a parent in the family thread and waits on the coach's page; remote coaches from 16**,
  ending chain; `data/market.json`).
- `StoryletSystem` (moments engine: threads, the 3–5 a week rate, standing orders, custom kinds; since L1a an important moment WAITS
  for the Sunday planner (`waiting()`), no people stops; storylets in `data/storylets/`, format in its README; the Sunday talk = the
  coach's `planner_line` + a thread message, race message and mood topics; `Cast` = family, friends, school people, partners, rivals;
  `data/cast.json`), `CoachTalk`, `CoachVerdict` (the coach's judgement of a change: truth + his noise), `CoachProposals` (his NOTES on
  the planner days, written on Sunday, ≤ 2 a week, Make it easy / Keep mine = the Veto; mid-week only the "scratch?" stop), `CoachAsk`,
  `SeasonGoals` (time / milestone / habit with real standards), `RaceAdvice`, `CoachSuggests` (a planner card on Sunday).
- `MindSystem` (confidence / motivation / stress, mental plan, effects on training and races; `data/mind.json`).
- `HabitSystem` (L1b: the 9 free-time slots (evenings + Sat + Sun) with study / rest / friends / family, the standing habits, this
  week's changes; they move grades, the life load and the moods where the old study effort / free time did; the default habit = the
  neutral one; `data/habits.json`; **call `HabitSystem.touch()` after changing anything a slot reads**) + invitations (storylets with
  `invite`, posted on Sunday into a slot, planned on the planner, happening on their evening; never a Play-week ask) + `HabitsUI`.
- `SchoolSystem` (stages, 17 subjects, tests, report cards, life load, the meet-and-tests decision; `data/school_life.json`) +
  `SchoolCalendar` (real 2026–27 dates, rules after) + `SchoolApplication` (the joint application, points, the path, moving; a rejection
  offers a **TUVA year**, stored as path kind `grade_10`) + `Lukio` / `Matriculation` (courses, periods, exams; `data/lukio.json`).
  Research data: `towns.json`, `urheilulukiot.json`, `school.json`, `application.json`, `standards.json`, each fact with a source.
- UI: `PeopleView` (People tab: threads, profile, Find a coach, School page, Rivals), `PeopleUI`, `MomentEventPanel`, `StandingOrders`
  (Season tab, under YOUR HABITS and the mental plan: the coach's notes on / off, **"Lukio courses: ask me every period / let the counsellor plan them"**, saved rules),
  `SchoolUI` / `SchoolView` / `LukioUI` / `MatricPlanView` / `SchoolApplyView`, `MindUI`, `GoalsUI`, `CoachProfile`, `CoachMarketView`.

**Tools and docs.** All checks live in `tools/` (see "How to run and check"); `tools/json_check.gd` parses every data file (and the research
data's sources). The GDD has a "Built (…)" note per session with the decisions.

## Working rules

- **Model recommendation:** start every reply with a line saying which model the user should use for their *next* message:
  `**Next message: Opus** / **Next message: Sonnet**` (+ suggested effort: low / medium / high).
  - Opus: design discussions, architecture, complex systems, hard bugs. Sonnet: routine GDScript implementation, small features, fixes.
  - Switching models mid-conversation makes the new model re-read the whole conversation (costs extra credits). So recommend a
    *different* model only for the start of a **new** conversation; within an ongoing one, recommend staying on the current model. When a
    task is finished, suggest starting a new conversation.
- Keep sessions focused on one task; record decisions in docs (GDD "Built (...)" notes), not just chat.
- **Every new feature adds or updates its help entry** in `data/help.json` (a new screen gets a "?"; raise `version` when an entry changes
  meaningfully) and `tools/help_check.gd` must still pass.
- Run `run_all_checks.bat -Quick` while working and the full run at the end; prove the fingerprints; layout check + tour for changed screens.
- Commit at the end of every work session and tell the user to press "Push origin".
- **Check-ins (user, 2026-10-09):** after each larger step (done 2026-10-10, 10-11, 10-18; the next at the end of M2) remind the user that
  a check-in is due: a realism audit of what was built since the last one plus a project review (progress vs GDD 1–2 and the roadmap,
  what is missing, what is fragile, Claude's honest opinions, priorities together). Output: a dated section in `docs/AUDIT.md`; roadmap
  changes only with the user's OK. Recommend Opus for it.
- Keep this file short (~20–25 KB): put per-system detail in `docs/CODEMAP.md`, decisions in the GDD.
