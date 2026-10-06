# Roadmap

Build in layers: every milestone ends with something playable.

## M0 — Project setup
- [x] Godot 4 project, folder structure, dark theme, main menu, data loading
- [x] User setup: Godot + GitHub Desktop installed, can pull and press Play

## M1 — Vertical slice: "800m youth season"
- [x] Athlete model (attributes, hidden potential, maturation) — growth over time comes with training
- [x] Character creation (identity, club, event, 5 background questions, 12 attribute points, summary)
- [x] Career hub with FM-style athlete profile (placeholder for the main game screen)
- [x] Weekly training plan → attribute progression, fatigue (first version; tune once races exist)
- [x] Finnish youth calendar (2026–27 season with real big-meet dates; later seasons estimated)
- [x] 800m race simulation with in-race decisions (quick + detailed mode), indoor + outdoor tracks
- [x] Results and PBs (fictional youth rivals with their own PBs)
- [x] Simple rankings (season list of your age class; season = 1 Nov – 31 Oct, rivals also race on their own)
- [x] Save / load (weekly autosave + snapshot saves, Continue / Load Career in the main menu)
- [x] Basic sleek UI (desktop + mobile layout): responsive wide/phone layouts, tab bar, 44 px touch targets, tap-to-explain instead of tooltips, optional blurred photo backdrop (see `docs/screenshots/`)

## M2 — Depth on the slice
Part 1: day-by-day mode, injuries & health (design: GDD 4.5–4.7). One session per step:
- [x] **1. Day engine + hooks:** `WeekSim` single-day step and save/load mid-week; `Game.advance_day()` /
      `advance_week()` (stops on stop events); `Game.date` = today; day loop with system slots, event format,
      day log; day changes with "changed by"; intensity (`data/health.json`); save version 2 (v1 saves still load),
      autosave daily. UI: just the Next day / Play week buttons + a simple stop-event panel. *(Opus)*
      Done: training balance bit-for-bit unchanged; checks in `tools/day_engine_check.gd`; T key = test stop event in debug builds.
- [x] **2. Week strip & day editor UI:** week strip (PC + phone), day editor (side panel / bottom sheet) on top of the
      `WeekSim` day-change API, Today card, Report day log (`Game.day_log`); update `layout_check.gd` and the
      screenshot tour. *(Sonnet)*
      Done: engine untouched (balance fingerprints identical); `layout_check.gd` now flags overflow, the tour and
      `day_engine_check.gd` cover the new UI. Left for later steps: warning-sign slot on the Today card and
      the scratch-race button (step 4), coach Veto (coaching).
- [x] **3. Health model:** body-area strain, soreness, injury and illness rolls, catalogue with phases
      (`data/injuries.json`), growth spurt, history, cross-training sessions, detraining when out, rival injuries;
      `training_balance.gd` with 200 athletes, injuries/illness/days lost, careful policy and ramp plan; first tuning
      pass. Headless only. *(Opus)*
      Done: `HealthSystem` + data; M1 fingerprints identical with the model off; checks in `tools/health_check.gd`;
      watch a season with `tools/health_season.gd`, H key in the hub prints the hidden numbers. First-pass numbers
      in GDD 4.6 "Built (step 3)" (running detraining added after the first pass, so ignoring warnings no longer pays);
      the small open points go to step 5.
- [x] **4. Health UI:** soreness on Today card + strip markers, diagnosis panel, "sore" stop decision, banned
      sessions + override warnings, scratch / race injured (slower, may worsen), load vs normal and plan risk in
      the Training tab. *(Sonnet)*
      Done: model untouched (only `Game.scratch_race` added and display texts in `data/health.json` `ui`); also the
      Report tab's health lines and the Ctrl+S save. Checks: `health_check.gd` (health UI section), seeded health
      states in `screenshot_tour.gd` and `layout_check.gd` (no overflow at 5 window sizes). Details: GDD 4.6 "Built (step 4)".
- [x] **5. Balance & playtest:** tune to the GDD 4.6 targets, play through a season on PC and phone, fix rough
      edges, update docs. *(Sonnet; Opus if tuning gets stuck)*
      Done: all targets met except "~10 % serious for hard-careful" (decision for the user, recommendation: a
      data-only change, see GDD 4.6 "Tuned (step 5)") and the ramp target, reworded (same progress as hard-careful,
      far fewer injuries). Data change: soreness levels 30/50/70 → 34/52/70 (the coach plan was "a bit sore" on 42 %
      of days, now 18 %). Fixed: the "sore" warning before a race day (Easy / Rest did nothing there). New tools:
      `tools/season_playtest.gd`; `training_balance.gd` prints boys vs girls, ages, stops and colds by month.
      Playtest through the real hub on PC and phone size: no errors; suggestions for later in the GDD.
- [ ] **6. Season periodization (design + build):** the weekly plan follows the training year instead of repeating
      the autumn base plan: phases (general base Nov–Jan, specific / indoor racing Feb–Mar, base again Apr, race
      season May–Aug with lighter weeks, autumn break Sep–Oct), the club coach's plan per phase, deload weeks, and a
      **taper** before a target championship (form peak on the day). Player still edits; changes apply per phase.
      **Also (user decision, 2026-10-06):** an optional intensity (Easy / Normal / Hard) per weekday *in the plan
      itself* (the Training tab has none today: intensity is only a this-week day change), default Normal so the
      M1 balance stays identical; it feeds "Load vs your normal" and plan risk (`HealthUI.plan_section(plan)`).
      Design the plan storage once for both (phase plans + per-day intensity).
      Realism gap found in the step-3 review (2026-10-06). Design session first. *(Opus)*
      **Designed 2026-10-06: GDD 4.8** (phases tied to targets, repeat mode kept, one week per phase + edges, automatic
      lighter weeks, coach's Steady / Balanced / Ambitious plans, taper for up to 3 targets, easy day before races, a
      return block after a layoff, Form ±1.5 %). Build in these sessions, in order; each ends with the checks named,
      a commit, and "Push origin":
  - [ ] **6a. Week plan storage + intensity in the plan** (repeat mode only, no phases yet): `week_plan.gd`;
        `Game.season` with `mode = "repeat"` and `repeat_week` replacing `Game.training_plan`; `WeekSim.plan_intensity`;
        `plan_risk` / `load_vs_normal` / `Training.preview / expected_fatigue / simulate_week` / `HealthUI.plan_section`
        take a week plan (`WeekPlan.of` accepts the old Array); Training tab: Easy / Normal / Hard per day (44 px, phone
        layout); save version 3 (v2 and v1 saves load as repeat mode, all Normal); update every tool that sets
        `training_plan`. *(Sonnet, high)*
        Check: `training_balance.gd` parts 1–2 fingerprints identical; `day_engine_check`, `health_check` (+ a check that
        Hard days in the plan raise load vs normal and plan risk, and that a plan-level Easy day equal to a day change
        is dropped as "same as plan"); load your own v2 save; tour + layout check.
  - [ ] **6b. Season model (headless):** `data/periodization.json` (phase types, skeleton, anchor rules, lighter /
        ramp / taper / race-week / return rules, the Balanced templates of GDD 4.8), `"main"` tags in
        `competitions.json` (+ 16-17 main meets with sources, or rely on the fallback), `SeasonPlan` (phases mode,
        anchors, edges, targets max 3, `week_for(monday)` with `why` per day), `Game.current_week()` takes its plan from
        it; new careers start in phases mode on Balanced (no offer event yet). *(Sonnet, high; Opus if the anchor rules
        get tangled)*
        Check: new `tools/season_plan_check.gd`: every Monday of 2026–27 and 2027–28 has a plan, phases in order with no
        gaps, the 2026–27 dates match the GDD table, lighter weeks every 4th base week, taper days −10…−1 before each
        target, easy day before races only in race phases, moving an edge / a target moves the phases, a missing target
        falls back to the main meet, save/load bit for bit; fingerprints still identical in repeat mode.
  - [ ] **6c. Form:** `FormSystem` (sharpness per day, freshness), `sharp` values in `training.json`, applied in
        `RaceDay._player_entrant` like the slowdown, `Form.enabled`; calibrate `neutral` so the repeating coach week
        averages 0; form word on the Today card (tap = explanation) and before a race. *(Sonnet, medium)*
        Check: `race_balance.gd` identical with form off; a check tool shows the repeating coach week ≈ 0 % average
        form, a tapered target ≈ "Peaking", the first race after base "Rusty"; fingerprints identical.
  - [ ] **6d. Coach's three plans + balance:** Steady and Ambitious templates, the ★ rule, `training_balance.gd` part 4
        (season rows × neutral / careful, form at targets, season best at targets); tune the templates to the GDD 4.8
        targets and write the numbers into the GDD. No model changes without asking. *(Opus, high: tuning)*
        Check: part 4 table against the targets; parts 1–2 identical; run rows in parallel (~4 at a time).
  - [ ] **6e. Season UI:** Training tab mode switch, coach plan cards, season bar (PC) / phase list (phone), phase
        editor (days + intensity, lighter weeks, ramp, edges, Back to coach's), targets (Training tab + Calendar
        Target toggle), `plan_section` for future phases with the lead-in (cached), week strip caption, `why` in the day
        editor, phase line in the Report. *(Sonnet, high; split into two sessions if big: Training tab first, then
        strip / calendar / report)*
        Check: tour + layout check (no overflow at the 5 sizes) with phases, a taper week and a lighter week seeded;
        `season_plan_check.gd` still passes; look at the screenshots.
  - [ ] **6f. Coach events, season rollover, return block, multi-season check, playtest:** `SeasonSystem` (GameSystem
        id `season`): the "three plans" offer at career start and each autumn (★ if ignored), next season's phases and
        targets, the return block (Accept / No thanks); new `tools/season_check.gd` (50 athletes × 3 seasons);
        a season played through the hub on PC and phone (`season_playtest.gd`); update docs and CLAUDE.md.
        *(Sonnet, high)*
        Check: `season_check.gd` (rollover, 2028 leap year, save/load at the boundary, no drift), all earlier checks,
        tools that play days still finish (they set repeat mode / answer the offer), playtest screenshots.
- [ ] **7. Multi-year progression check:** extend the balance tools to 5–8 seasons (ages 14–21) through the game
      loop with health on, and compare the player's and the rivals' curves with real Finnish standards (e.g. a
      talented athlete reaches SM-level youth finals at 15–17 and Kalevan kisat standard around 19–21; most rivals
      plateau). Tune the progression ceiling, maturation and rival growth; also check whether rivals need the health
      model and plan-based training. *(Opus)*

Part 2 (design later, plugs into the step-1 hooks; periodization (step 6) prepares the coach's plans):
- [ ] Coaching (hire, veto)
- [ ] School (grades, exams vs meets, Finnish school calendar)

## Ideas backlog (from the user, 2026-10-06; placement is Claude's proposal, not yet designed)
- ~~**Ctrl+S to save**~~ — done in M2 step 4 (same as the Save button, "Saved ✓", desktop only).
- **Choose your birth date:** birth date is already an input to `AthleteFactory`. Day + month inside the starting
  birth year is safe (same age class); other years change the start age, eligible meets and the rival cohort, so
  that waits until more age classes exist (M4+). Small character-creation task after step 5. *(Sonnet)*
- **Choice of coaches / coaching groups / coaches per sub-area** (e.g. speed, endurance, strength, mental, physio):
  belongs to M2 part 2 "Coaching". Needs a design session first (Opus); it plugs into the step-1 hooks (`by = "coach"`,
  Accept / Veto in the day editor, coach events, and `on_week_start` from step 3 for a coach's weekly changes); a
  physio could read the health model (`HealthSystem.soreness_info`, `plan_risk`). Design it together with School, since both compete for the athlete's time.
- **Profiles for all other athletes + profile pictures:** two stages. (1) After M2 part 1: a rival profile screen
  (tap a name in Rankings or a race field: club, age, PB / season best, results history, scouting-style attribute
  hints) with procedurally drawn avatars (generated in code, never real photos) for the fictional youth rivals.
  Needs rival results history stored; it can also show "injured" (rivals have `out_weeks` since step 3). (2) With senior level (M4+): real athletes with data from `data/*.json` and, where a
  properly licensed photo exists (e.g. Wikimedia Commons CC BY-SA, needs the Credits screen), a real photo.
  Youth stay fictional (minors). The player's own avatar can come with stage 1 too.

- **Calendar race details (user, 2026-10-06):** click a race in the Calendar to see all its details: participants, level, place, standards, etc. *(Sonnet)*
- **More name variety (user, 2026-10-06):** too many repeated first names, and some last names, among rivals. Enlarge `data/names_fi.json` (and check how `Rivals` draws names). *(Sonnet)*

- **Playtest notes (user, 2026-10-06):**
  - *Coach gives only one program:* the coach should offer several plans (fits Coaching + periodization, steps 6 and Part 2). Designed in GDD 4.8: the club coach offers Steady / Balanced / Ambitious season plans (built in 6d–6f); focus plans and hired coaches wait for Coaching.
  - [x] *Race is jittery and lags after the first decision:* fixed. Two causes, found with `tools/race_perf.gd`: the indoor hall track (antialiased arcs) was redrawn every frame together with the runners (~4.6 ms of drawing per frame, 40 → 20 ms/frame on the dev laptop's Intel GPU), and the POSITIONS rows were deleted and rebuilt every frame, which re-laid-out the whole side panel with its wrapped commentary labels (the lag grew as the commentary filled up, i.e. after the first decisions). Now the hall track is its own view drawn once and the position rows are reused; steady 60 fps (16.7 ms) on PC and phone size, indoor and outdoor.
  - *More immersive races:* more in-race options, and commentary in its own box that reacts to what happens and to the player's choices (e.g. "someone kicks with 229 m to go" should be something the player can answer), less repetition, more realism. Needs a design session (Opus), then build; belongs before or inside M3 (stadium view).

## M3 — Stadium view
- [ ] 2D stadium during meets: track, crowd, simultaneous events

## M4+ — Breadth
- [ ] Other running events (400m–10000m, steeple), then hurdles & sprints, jumps, throws, combined events
- [ ] International circuit, championships, qualification standards
- [ ] Full world simulation, sponsors, media, rivals, nutrition, equipment, doping…
