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
  - [x] **6a. Week plan storage + intensity in the plan** (repeat mode only, no phases yet; **done 2026-10-06**, details
        in GDD 4.8 "Built (step 6a)": all of the below, `training_balance.gd -- 0` runs only parts 1–2 + a new 2b,
        `day_engine_check` / `health_check` have the new checks, all 4 of the user's v2 saves load and play, tour +
        layout check clean at all sizes): `week_plan.gd`;
        `Game.season` with `mode = "repeat"` and `repeat_week` replacing `Game.training_plan`; `WeekSim.plan_intensity`;
        `plan_risk` / `load_vs_normal` / `Training.preview / expected_fatigue / simulate_week` / `HealthUI.plan_section`
        take a week plan (`WeekPlan.of` accepts the old Array); Training tab: Easy / Normal / Hard per day (44 px, phone
        layout); save version 3 (v2 and v1 saves load as repeat mode, all Normal); update every tool that sets
        `training_plan`. *(Sonnet, high)*
        Check: `training_balance.gd` parts 1–2 fingerprints identical; `day_engine_check`, `health_check` (+ a check that
        Hard days in the plan raise load vs normal and plan risk, and that a plan-level Easy day equal to a day change
        is dropped as "same as plan"); load your own v2 save; tour + layout check.
  - [x] **6b. Season model (headless; done 2026-10-07**, details in GDD 4.8 "Built (step 6b)": per-season records, the
        Monday nearest 1 Nov, default targets entered at career start, 16–17 main meets from the SUL 2027 calendar,
        Training tab shows a notice + "Use one repeating week instead" in phases mode; `tools/season_plan_check.gd` and
        `tools/saves_check.gd` are new**) `data/periodization.json` (phase types, skeleton, anchor rules, lighter /
        ramp / taper / race-week / return rules, the Balanced templates of GDD 4.8), `"main"` tags in
        `competitions.json` (+ 16-17 main meets with sources, or rely on the fallback), `SeasonPlan` (phases mode,
        anchors, edges, targets max 3, `week_for(monday)` with `why` per day), `Game.current_week()` takes its plan from
        it; new careers start in phases mode on Balanced (no offer event yet). *(Sonnet, high; Opus if the anchor rules
        get tangled)*
        Check: new `tools/season_plan_check.gd`: every Monday of 2026–27 and 2027–28 has a plan, phases in order with no
        gaps, the 2026–27 dates match the GDD table, lighter weeks every 4th base week, taper days −10…−1 before each
        target, easy day before races only in race phases, moving an edge / a target moves the phases, a missing target
        falls back to the main meet, save/load bit for bit; fingerprints still identical in repeat mode.
  - [x] **6c. Form (done 2026-10-07):** `FormSystem` (sharpness per day, freshness), `sharp` values in `training.json`, applied in
        `RaceDay._player_entrant` like the slowdown, `FormSystem.enabled`; calibrate `neutral` so the repeating coach week
        averages 0; form word on the Today card (tap = explanation) and before a race. *(Sonnet, medium)*
        Check: `race_balance.gd` identical with form off; a check tool shows the repeating coach week ≈ 0 % average
        form, a tapered target ≈ "Peaking", the first race after base "Rusty"; fingerprints identical.
  - [x] **6d. Coach's three plans + balance (done 2026-10-07**, details and numbers in GDD 4.8 "Built (step 6d)": youth ★ limits
        (Steady at durability ≤ 4, Ambitious at 9 / 11), Ambitious = doubles + a rest day, Steady = Balanced's sessions mostly Easy,
        race-season rest day + mobility the day before a target (Nuorten SM now Peaking); Balanced 0.78 injuries / +1.17, Steady 0.67 /
        +1.02, Ambitious careful 0.99 / +1.49; Balanced progress below +1.25, Steady injuries above 0.4 and Ambitious injuries
        below 1.3 **accepted as measured (user, 2026-10-07)**; the Training tab shows "Coach's plan: Balanced ★"**)** Steady and Ambitious templates, the ★ rule, `training_balance.gd` part 4
        (season rows × neutral / careful, form at targets, season best at targets); tune the templates to the GDD 4.8
        targets and write the numbers into the GDD. No model changes without asking. *(Opus, high: tuning)*
        Check: part 4 table against the targets; parts 1–2 identical; run rows in parallel (~4 at a time).
  - [x] **6e. Season UI (done 2026-10-07**, details in GDD 4.8 "Built (step 6e)": phase editor = a full page in the Training tab,
        targets marked ◆, plan cards behind "Change plan", the lead-in cached per opened phase (~33 ms), an edge in this week or
        before can't move; `season_plan_check` section "season UI (step 6e)"**)** Training tab mode switch, coach plan cards, season bar (PC) / phase list (phone), phase
        editor (days + intensity, lighter weeks, ramp, edges, Back to coach's), targets (Training tab + Calendar
        Target toggle), `plan_section` for future phases with the lead-in (cached), week strip caption, `why` in the day
        editor, phase line in the Report. *(Sonnet, high; split into two sessions if big: Training tab first, then
        strip / calendar / report)*
        Check: tour + layout check (no overflow at the 5 sizes) with phases, a taper week and a lighter week seeded;
        `season_plan_check.gd` still passes; look at the screenshots.
  - [x] **6f. Coach events, season rollover, return block, multi-season check, playtest (done 2026-10-07**, details in GDD 4.8
        "Built (step 6f)": the autumn offer stops Play week, then a Next season box in the Training tab until the season starts (★ if
        no choice); targets kept and entered; "Easing back in" after any 14+ days without running, stoppable, races stay; `season_check`
        50 × 3 seasons: injuries 0.70 / 0.78 / 0.54, ability +1.17 / +1.14 / +1.06 a season, save/load at the boundary bit for bit**)**
        `SeasonSystem` (GameSystem
        id `season`): the "three plans" offer at career start and each autumn (★ if ignored), next season's phases and
        targets, the return block (Accept / No thanks); new `tools/season_check.gd` (50 athletes × 3 seasons);
        a season played through the hub on PC and phone (`season_playtest.gd`); update docs and CLAUDE.md.
        *(Sonnet, high)*
        Check: `season_check.gd` (rollover, 2028 leap year, save/load at the boundary, no drift), all earlier checks,
        tools that play days still finish (they set repeat mode / answer the offer), playtest screenshots.
- [ ] **Race realism (designed 2026-10-07, GDD 4.3.1)**, before step 7, so the multi-year check measures the new
      race times. From the playtest notes "Races are decided too early" and "More immersive races". Each session ends
      with the checks named, a commit and "Push origin"; `race_shape.gd` + `race_balance.gd` numbers before and after
      go into GDD 4.3.1:
  - [x] **R1. Pack engine (headless):** race shapes (`races.json` `shapes`, mix per level / round), the leader's pace,
        following a group, drafting (~2 % of speed), hanging on and being dropped, misjudged energy, rival
        `personality` (+ made on load for old saves, `met` count), plan lap factors replaced by the wanted place,
        the cruising-speed scale calibrated; the player's cards stay the old fixed ones for now. *(Opus, high)*
        Check: `race_balance.gd` medians ±1 s of the anchors, `race_shape.gd` time / table within ±0.5 % and the shape
        targets of GDD 4.3.1 (tight front group, long tail; wide local fields still strung out), `form_check.gd`,
        `rankings_check.gd`, the race screen still runs (`race_perf.gd`).
        Done 2026-10-07 (GDD 4.3.1 "Built (step R1)", before/after table there): `cs_scale` 1.003, field pace = 3rd
        strongest of 8, tuck in on bends, pack runners move up to 4th, kick ≤ 1.12 × even speed (pre-form ability);
        youth final 0.7 / 3.0 / 9.5 s ✓, 5 of 8 within 5 m at 400 ✓, time / table 0.996–1.002 outdoors ✓; the senior
        final finish (0.7 / 2.1 / 5.6 s, 25 % under 0.2 s) is left for R2's kick chain. `day_engine_check` has new
        personality / `met` / repeatable-race checks; fixed old tool problems: `rankings_check` and `race_perf` now
        answer stop events (both could hang since health / step 6f), `race_perf` no longer presses the card's "?".
        `race_perf` 60 fps on PC (indoor) and phone (outdoor) at 4x.
  - [x] **R2. Moves, boxes, falls (headless):** surges at any point, covering / letting go, the kick chain, boxed in +
        the three ways out, contact / stumble / fall (+ a fall bringing down the runner behind), race injuries in
        `injuries.json` through the health model, the obstruction DQ, heats easing in, the engine's race event list
        (for the commentary), the duel rows and fall counts in `race_shape.gd`; tune the upset targets. *(Opus, high)*
        Check: the shape, upset and fall targets of GDD 4.3.1; `health_check.gd`; R1 checks still pass.
        Done 2026-10-08 (GDD 4.3.1 "Built (step R2)", decisions 10–13): answering a kick = going with the kicker;
        energy drain × (speed / own even speed)³; tactical lap 1 8–12 % slower; `cs_scale` 1.017; falls 1 per 96
        runner-races in bunched finals ✓; youth final 1.3 / 3.4 / 9.4 s ✓; time / table 0.997–1.005 outdoors ✓;
        `race_balance` within ±1 s outdoors ✓. **Not met, carried on:** the senior final finish (0.6 / 2.0 / 5.9 s →
        step 7: seniors' race-day consistency), the upsets at Δ 0.5 (37–40 % vs 45–55 %) and good vs bad race
        (~0 % vs 0.5–1 %) → R5. New `tools/race_check.gd`; `race_shape.gd` duel rows + tuning overrides;
        `race_balance.gd` takes races per row and a group.
  - [x] **R3. Player controls (UI):** event-driven decision cards (max 6, priority), the action bar (Push / Hold / Ease
        / Move out / Kick now, double tap for Kick, PC + phone, 44 px), the drop to 1x near the player, the Feeling
        word, the coach's shout on cards, quick mode answering the new cards, help entries (`race_running` etc.,
        raise `version`). *(Sonnet, high)*
        Check: tour + layout check with seeded race states (no overflow at the 5 sizes), `help_check.gd`,
        `race_perf.gd` 60 fps, quick vs watched with default choices within ~1 place on average.
        Done 2026-10-08 (GDD 4.3.1 "Built (step R3)", decisions 14–16): cards from engine events (`Race._check_cards`,
        max 6, `data/race_cards.json` + `races.json` `controls`), the action bar (`RaceActionBar`), Feeling, drop to 1x,
        the coach's shout (sees part of the track), quick mode answers the same cards; help `race_before` / `race_running`
        v3; new `tools/race_watch.gd`, `race_check.gd` rewritten for the cards, `layout_check` + tour race states. Sensible
        answers vs quick mode: within ±0.2 places (target ≤ 1) ✓.
        **Follow-up the same day (user: "mistakes must cost, no arcade feel", GDD 4.3.1 "Follow-up to R3", decisions
        17–19):** energy exponent 3 → 5, committing answers switch off the kick-protecting speed cap, a kick from far out
        dies (+1.7 s from 470 m), letting a move go closes slowly, positive lap splits (+2.4 / +2.6 s, fast / honest),
        `kick_need_per_100` 0.07, `cs_scale` 1.029, card cap 6 → 10 (safety valve), the drop to 1x names its reason; new
        `tools/race_value.gd` (what each answer is worth). A bad vs a good race now costs 0.3–0.9 % of the time ✓ (target
        0.5–1 %) but only 0.1–0.5 places; the R2 rows moved (table in the GDD) and the senior final is still too spread.
        **Left for R5:** places (the answers should be worth more places), the upsets at Δ 0.5, a decisive move.
  - [x] **R4. Commentary, coach and race story (UI + data):** `data/race_commentary.json` (variants, placeholders,
        tags, voices TV / coach / you), no repeats + rate rules, choice verdicts, the coach's spot by the track, PC box +
        banner, phone ticker + log sheet, the Race story on the result screen, personality tags and the SB column (backlog
        item) in the pre-race field. *(Sonnet, high)*
        Check: a tool plays 50 races and prints how often each line is used (no line twice in a race, no event without
        lines); tour + layout check; `help_check.gd`; look at the screenshots.
        Done 2026-10-09 (GDD 4.3.1 "Built (step R4)", decisions 35–38): a real broadcast, not a log: stadium announcer at
        small meets, commentator + expert at championships (Yle / MTV style by meet), talk about the field, the season and
        the next meets between the calls; moves followed (got away / caught / faded), kicks dying, boxes, heat runners
        easing off; four coach personalities (`data/coaches.json`) with their own words, splits called from his spot (drawn
        on the track), verdicts 10 s after a card; Race story on the result screen; PB + SB columns and style tags in the
        field. New `RaceCommentary`, `RaceStory`, `Coaches`, `data/race_commentary.json`, `tools/commentary_check.gd`.
  - [x] **R5. Balance & playtest:** all GDD 4.3.1 targets in one table before / after, watched races on PC and phone
        (indoor and outdoor, heats + final), fixes, docs + CLAUDE.md. Carried over from R2: the upsets at Δ 0.5 and a
        good vs bad race worth 0.5–1 % (with the player's cards / action bar in place).
        **Decided 2026-10-09 (GDD decisions 20–23):** rework the box ways so the best answer depends on the distance left
        (wait early / step out mid-race / push through late), make a move decisive when the mover can carry it (measure
        first with `race_value.gd`: how often a mover finishes ahead of those who let it go), judge the answers' worth
        in tight finals too, no difficulty setting. Reset `sensible_choice` and the coach's advice from the new numbers. *(Opus, medium: tuning;
        Sonnet for the fixes)*
        Check: every check tool above, `training_balance.gd -- 0` fingerprints identical, `season_check.gd`.
        Done 2026-10-09 (GDD 4.3.1 "Built (step R5)", decisions 24–25): boxes — easing out drops back behind the
        runner on the shoulder (median 1.1 m, was 7 % of speed for the whole box), room (shoulder runner half a stride
        back) makes pushing a nudge, no gaps open on bends; measured: the room decides, not the distance (decision 24:
        no room wait, room ease, last 100 m push), none is a trap. Moves — new `tools/race_moves.gd` showed covering
        changed nothing (61 / 62 %); now a mover presses on after the surge (`moves.drive`) and those who let it go don't
        chase: a clearly stronger mover gets away (91–98 %), a clearly weaker one is caught (3–11 %); between equals not
        settled (tight final decisive, youth / senior finals the other way, noise-level samples: playtest + R4). Sensible answers reset (move: go with a mover over 1 % weaker; dig in hardly
        ever; take the lead on a slow pace). A watched race with every answer wrong costs 0.9–2.0 % (was 0.3–1.0 %);
        sensible vs quick within 0.3 places. Upsets at Δ 0.5: 34–38 % → decision 25 sets the target to 35–45 %.
        Youth rows time / table within ±0.5 %; senior finals 1.006–1.009 left for step 7. New `tools/watch_race.gd`
        (playtest: straight to an indoor / outdoor race, with heats). **Watched playtest by the user still to do**
        (GDD 4.3.1 R5 "Playtest plan"; observations go into the next session).
  - [x] **R5 playtest fixes (UI), built 2026-10-09:** decisions 26–27 (GDD 4.3.1 "Built (R5 playtest fixes)"): the decision
        card beside the track (PC: top of the right column; phone: a bottom sheet from the action bar down; the track
        stays visible), a pause button beside 1x / 2x / 4x (the action bar works while paused, Space on PC); the result
        screen shows every heat's results (yours first) with Q (place) / q (time) marks. Help `race_running` v6,
        `race_result` v5. Checks: `layout_check` (5 sizes, card clear of the track, paused, heat results), the tour,
        `race_perf` 60 fps, `help_check`, `race_check`, `day_engine_check`. Still open from the playtest plan: the other
        three watched races (outdoor any on PC twice, outdoor heats on the phone).
  - [x] **Realism audit + meet formats, built 2026-10-09** (`docs/AUDIT.md`; GDD 4.3.1 decisions 28–34, "Measured
        2026-10-09" and "Built (meet formats)"): (1) the audit table (✓ / ≈ / ✗ with sources); (2) surges, kicks and heat
        easing measured with the new `tools/race_surge_ease.gd`; (3) Finnish championships run the 800 m in seeded timed
        sections (SUL MK-säännöt 2026), heats + semis + final from the World Athletics table for heats meets, later
        heats / sections chase the time to beat, heats run to qualify (easing ~0.3 s, heat winners slower than in the
        final), the time needed shown before and during the race, the indoor break line after two bends (WA 2025),
        season bests by calendar year. New `tools/race_rounds.gd`; `watch_race.gd -- sections|heats`. All R5 rows
        identical outdoors. *(Opus)*
- [x] **Check-in 2026-10-10** (realism audit of R4 + project review, `docs/AUDIT.md` "Check-in (2026-10-10)"): order of
      work agreed with the user below; next check-in after step 7.
- [x] **Fix session (after the check-in, done 2026-10-10; GDD 4.3.1 "Built (check-in fixes)"; `run_all_checks.bat`, Dev menu in the main menu of a test build):** (1) R4 realism fixes: section / heat places never called a podium or medal
      ("wins the heat / section"; Race story and coach use the overall place in sections); the 10 s verdict says "so
      far" and the real verdict on a choice comes in the Race story after the finish; talk between the calls only 1–2
      short facts on lap 1; the crew knows the favourites' styles at streamed / TV meets (the player's own tag still
      after two races); Nuorten SM (national level) gets one commentator, no expert; coach words fit a minor (no
      "sweetheart" / "love"); "ranked x of y" over the whole field; "his club"; the two trailing commas in
      `race_commentary.json`; "better / as expected / below" from the pre-race ranking. (2) The two open chips:
      `help_check` "day editor ?" (fails only in the PC layout, i.e. windowed) and the heat Q / q marks vs the next
      round's size. (3) One "run all checks" script: the quick checks in both layouts, reads stderr for SCRIPT ERROR,
      one honest PASS / FAIL list. (4) A Dev menu in debug builds for the user: watch a test race (indoor / outdoor,
      sections / heats), jump the career forward. Help entries for anything new. *(Sonnet, high)*
- [x] **Season playtest by the user (done 2026-10-10):** one whole season played; the notes, sorted, and what the save
      showed are in `docs/PLAYTESTS.md`. Headline: "very bored, wouldn't return after one season"; last in 12 of 18
      races; the rivals grew faster than the player.
- [x] **Character creation: points pool from the answers (built 2026-10-10, GDD 4.1.1 "Built (points pool)"):** pool =
      6 + the experience behind the answers (6–16), max +3, experience costs trainability; every answer re-priced (no
      free answers); the coach's guess of the 800 m time, dots for what counts for the 800 m, "Let the coach spread
      them", the summary's "where it came from". New `tools/start_spread.gd`. *(Opus)*
- [x] **Quick fixes from the season playtest (done 2026-10-10, GDD 4.3.1 "Built (playtest fixes)"; Claude's placement 2026-10-10: before step 7, because the race-time swings
      and the missing attribute history would spoil step 7's measurements, and the coach / PB fixes touch every race
      the user plays):** (1) the race-time swings (2:49.80 → 2:28.57 in two weeks, 2:25.71 → 2:45.00 in 17 days): find
      the cause (quick-sim answers? racing sore or injured? form?) and fix it; (2) the kick: "Wait for the home
      straight" must not start the kick by itself at 100 m to go, and **Kick now** must work at any distance (user:
      "I want to decide when I kick"); (3) the coach's "kicked too far out" after a kick at ~100 m; (4) no opposite coach
      shouts right after each other ("drifting, wake up!" / "your own pace", "move it" / "back off"); (5) verdicts and
      the Race story count a PB / SB and the time against the athlete's own level, not only the place (a 2 s PB
      called "not good enough"); (6) PB / SB marks in every result list (yours and the rivals'); (7) a monthly record of
      the attributes and the best time (in the save; step 7 and the Statistics tab use it); (8) the Report tab: a short
      summary first, the day-by-day details folded away; (9) the Rankings tab: highlight the player, explain it, help
      entry. *(Sonnet, high; Opus for (1) if the cause is not obvious)*
      **Done 2026-10-10** — (1) no bug: the day-form roll is wide for a low consistency (sd 4.3 s at consistency 5.5), plus injury
      slowdowns (~4 %) and quick mode's wrong answers; the spread was narrowed by 25 % (user's choice); (2) Wait never kicks by
      itself in a watched race, Kick now works at any distance, a Quick result follows a kick plan; (3) the late-kick wording;
      (4) no contradicting coach advice; (5)–(6) PB / SB in verdicts, the coach's lines and every result list; (7) the monthly
      record + its Progress page; (8) the Report tab folded; (9) the Rankings tab. New `tools/playtest_fix_check.gd`,
      `tools/race_spread.gd`, `tools/race_season_times.gd`. Left for later (from the same playtest): the whole-race controls
      idea and the coach's/people interaction (Coaching + School).
- [x] **7. Multi-year progression check (done 2026-10-10, GDD 4.2 "Multi-year check"):** new `tools/career_check.gd`
      (7 seasons, six kinds of athlete, every race run, pairs on the same rolls) and `tools/rival_curves.gd`; compared with
      Tilastopaja 2026 championships, Finland's 2025 lists and Tønnessen et al. 2015. Found: rivals 5–14 s too fast and never
      stopping (the cause of "last in 12 of 18"), the player too fast after 17 and girls never levelling off, the experience
      trade unfair (beginner still behind at 21), fields of 41, no meets after Oct 2029. Built (user's choices): the rivals'
      age curve + stop at the ceiling, the player's age slowdown + puberty window, novice gains (beginner level at 17),
      real championship fields, seniors' narrower race-day form (decision 12), meets for 20 seasons + club meets for adults,
      rival injuries ~4 %. Health per week matches Mann 2021 (no change). Open: the race-to-race spread at 19–21 (~2 %, race
      shapes), senior meets and older rivals (M4). Original task:
      extend the balance tools to 5–8 seasons (ages 14–21) through the game
      loop with health on, and compare the player's and the rivals' curves with real Finnish standards (e.g. a
      talented athlete reaches SM-level youth finals at 15–17 and Kalevan kisat standard around 19–21; most rivals
      plateau). Tune the progression ceiling, maturation and rival growth; also check whether rivals need the health
      model and plan-based training. Also seniors' race-day consistency (GDD 4.3.1 decision 12: the senior final
      finish target). From the audit (`docs/AUDIT.md`): the share of days with a health problem (~6 % vs ~25 % real),
      championship field sizes (every Nuorten SM field is 41) against real entry lists. From the points pool and the
      playtest (2026-10-10): the tools' athletes must spend the pool (`AthleteFactory.coach_spread`), as real players
      do; check that the experience trade is fair (a beginner, pool 6, catches a trained athlete, pool 16, by about
      16–17, and neither always wins); in the user's season the rivals' middle grew ~1.9 ability, the player ~1.2
      (potential 13.2), so the player fell from the bottom quarter to the bottom tenth. *(Opus)*
- [x] **Check-in 2026-10-11** (realism audit since the last check-in + project review, `docs/AUDIT.md` "Check-in
      (2026-10-11)"): found that a top talent never reaches senior national level (16 careers to age 25 on the coach's
      plan: none at the Kalevan kisat standard 1:53.50, the best 2:00.0) and that the rival pool's youth leaders stay
      leaders far more often than real ones; fixed the calendar lookups (`week_for` 993 → 201 µs, its check was flaky
      since step 7), moved the indoor-bend number into `races.json`, corrected GDD 4.2 (SUL's real Kalevan kisat entry
      rule). Order agreed below. Next check-in at the end of M2.
- [x] **Talent balance: can a talent make it? (done 2026-10-11, GDD 4.2 "Talent balance"):** measured 64 careers to 25 on
      Steady / Balanced / Ambitious / a best-case plan (no top talent reached Kalevan kisat; the 800 m-specific qualities barely
      responded, the age brake hit everyone, the plans never grew, the rivals' order was fixed at 14); targets agreed with real
      sources; built the user's choices: a dose per attribute, the age brake only near the ceiling, the coach's plans by age group
      (14–15 / 16–17 / 18–19 / adults), rivals' churn (drifting ceilings, bloom ages, good and flat years). Now top-talent
      boys on Balanced are 4th–7th of the birth year at 21 and 3 of 4 under 1:53.50 by 23 (Ambitious: all by 21); rivals'
      top 20 kept 17 → 21 58–62 % (was 75–82 %).
      Open: the plans differ by only 1–2 s at 21 (Coaching), ~2 races a year from 23 (more meets), dropouts (rival profiles).
      Original task: measure first with
      `career_check.gd` over 11 seasons (ages 14–25) on the Steady / Balanced / Ambitious plans and a best-case plan,
      with races run; agree targets with the user (the shape: a top talent, potential 17+, on a decent plan reaches the
      top 3 of the birth year by 19–21 and the Kalevan kisat standard by about 21–23; an average one national youth
      finals; a low one club level) and compare with real Finnish careers; then tune what the measurements point at
      (the start deciding everything, potential barely used, trainability barely showing, the average-vs-trained
      pairs never level). Also the rivals' growth churn (late bloomers, early plateaus; real: ~20 % of top U18
      middle-distance runners reach the senior top, Brustio et al. 2024). Coaching later adds a smaller layer on top
      (coach quality and fit: finalist vs medallist), so the club coach is never a trap. Prove that the first season's
      balance moves only as intended (`training_balance`, `season_check`). *(Opus)*

Part 2 (design later, plugs into the step-1 hooks; periodization (step 6) prepares the coach's plans). Agreed
2026-10-10: Coaching and School are designed together (both compete for the athlete's time), after step 7:
- [x] **Coaching + School design (done 2026-10-11, GDD 4.9):** option C "The people around you" (user's choice over A "the coach's
      office" and B "life planner", with B's fitting parts taken in): FM-style coaches with 11 attributes, character, ranges and
      scouting, real coaches where possible + fictional ones, a parent / remote coach, training groups, the family budget; the coach
      thread (People tab), the Sunday week talk, Ask the coach, proposals + Veto ("Ask me first"), season goals with real standards
      (SM, TF-juniorit / TF-nuoret), race advice by personality, trust (a coach can end it after warnings); school with real subjects,
      study effort + free time, life load, the Finnish calendar, exams, the grade-9 application with real scoring, urheilulukio,
      matriculation exams; moods confidence / motivation / stress; mental attributes that grow; a weekly mental plan; the cast and
      storylets with memory and the never-stale rules; minigames (decisions only): Rep by rep, Test days, Race rehearsal, Camp week,
      Video review, Warm-up routine, Gym day later. Build in the sessions below, in order; **each ends with its checks, the proof that
      the neutral setting gives identical `training_balance -- 0` fingerprints, a help entry for anything new, a commit and "Push
      origin".** *(The originals of the two items follow the list.)*
  - [x] **C1. Coach model (headless)** *(done 2026-10-11, GDD 4.9 "Built (step C1)"; user: club coaches' level varies, averages
        ~7–13, a coach of 10s is the neutral setting)*: coach data format (attributes, character words, facts, `source` for real coaches), the
        club-coach generator (each career's club coach averages 10: weak somewhere, good somewhere; the four personalities of
        `coaches.json` kept), `CoachSystem` (GameSystem id `coach`, off switch for the tools), effect hooks all neutral at 10 (training
        effect by attribute group, race-advice accuracy replacing `controls.coach.accuracy`, youth development / load management hooks
        prepared), trust and fit (temperament from the "pressure" answer); `Athlete.coach_id` → the coach record; save version 4 (older
        saves get their club coach). New `tools/coach_check.gd`. *(Opus, high)*
        Check: fingerprints identical; `coach_check` (a coach of 10s = no change; a coach of 16s changes only what his attributes say;
        save/load bit for bit; old saves load); `run_all_checks.bat`.
  - [x] **C2. Messages + storylet engine (headless)** *(done 2026-10-11, GDD 4.9 "Built (step C2)"; user: test moments only in
        the tools + Dev menu, a moment waits its own `expires_days` (default 2), a rule offered after the same answer twice in a row)*:
        threads per person; the storylet format (conditions, variants, replies with
        effects and cost hints, memory flags, chains, cooldowns, once), the scheduler and the rate rules, "Play week stops for:
        Important only / Every moment", unanswered = "you didn't answer", standing orders from repeated choices; a handful of test
        storylets; new `tools/storylet_check.gd`. *(Opus, high)*
        Check: `storylet_check` (no repeats inside a cooldown, rate, nothing stuck), `day_engine_check`, save/load bit for bit.
  - [x] **C3. People tab + coach thread + Sunday week talk + the coach's "why" lines** *(done 2026-10-11, GDD 4.9 "Built (step
        C3)"; user: the Sunday talk always stops Play week, the People tab in the tab itself on PC, an unanswered topic costs the
        normal −1 trust)* (UI; PC + phone, 6 bottom tabs; help entries).
        Also (user 2026-10-11, GDD 4.9.5 "Consequences shown"): a hint under every reply and a result card after answering (what
        changed, in words with ▲ / ▼, no numbers), in the moment panel and the thread; the hints of the test moments filled in.
        *(Sonnet, high)*
        Check: tour + `layout_check` (5 sizes, no OVERFLOW / SQUEEZED), `help_check` both layouts.
  - [x] **C4. Coach proposals + Veto + "Ask me first" + Ask the coach** *(done 2026-10-16, GDD 4.9 "Built (step C4)"; user: only
        when he sees a reason, at most 2 a week; "Ask me first" always stops Play week; a veto asks for a reason, silent ones cost
        trust from the 3rd in 4 weeks; "Never" = he notices, an ignored real warning −1 trust; Ask the coach = a card in place; meets
        and targets moved to C5)* (the verdict model: the truth from the training / health / form models, then the coach's view
        through his attributes). *(Opus, high)*
        Check: `tools/verdict_check.gd` (in `run_all_checks`); `training_balance` part 2e; tour + `layout_check`.
  - [x] **C5. Season goals with times + race advice by personality + "Coach suggests" meets and targets** *(done 2026-10-16, GDD
        4.9 "Built (step C5)"; user: three goals time + milestone + habit, a free choice of level from a short list, met = trust + a
        message and missed = a talk with no trust loss, personality noticeable but not decisive, his plan shown before every race,
        suggestions as a message + a Calendar mark, at most one a month)*: standards in data (SM, TF-juniorit / TF-nuoret, Kalevan
        kisat, the 2026 tables with their sources), the goals with the plan offer, Overview + Progress, race advice accuracy = race
        reading and bias = personality, the pre-race suggested plan; the coach proposes meets and targets in the Calendar ("Coach
        suggests", judged with the C4 verdict model, the player decides). *(Sonnet, high)*
        Check: `goals_check` (in `run_all_checks`), `quick_fingerprint` (the races are unchanged), `training_balance -- 0` part 2f,
        `season_check`, `verdict_check`, `help_check` in both layouts, tour + `layout_check`.
  - [x] **M1. Mind** *(done 2026-10-17, GDD 4.9 "Built (step M1)"; user: news + Sunday drift, the GDD sizes with a calm
        middle, monotony after 8 weeks on the same week / phase, a MIND panel under the Today card, the coach's line + a topic
        when a mood is low, the mental plan now, stress now with today's causes; **competitiveness in races moved to the
        race-controls design session** (the race engine untouched))*: `MindSystem` (confidence / motivation / stress, news +
        Sunday drift, causes and pulls, effects: training quality and a race-day term, off switch + neutral switch), consistency
        from races and composure from big meets and the mental plan, ambition (goals, held back, the hint), the weekly mental
        plan and the cue word, the moments' mood effects, goals met / missed / set, the coach's Motivating and mental coaching.
        `tools/mind_check.gd` (in `run_all_checks`), `tools/mind_season.gd`. *(Opus, high)*
        Check: fingerprints identical with the moods in the middle (`training_balance` part 2g); a tool prints the mood weeks of
        a season by plan and policy.
        Left for later: competitiveness in races (race controls), the training group's pull (P1), stress from school + sleep
        (S1), a pre-race routine and video review (G2 / G3), the balance of the mood sizes (B1).
  - [x] **D1. Research + data** *(done 2026-10-17, GDD 4.9 "Built (step D1)"; user: about 12 real coaches now, all four kinds,
        as many as possible once the career reaches adult level)*: 12 real coaches (4 Finnish elite / club, 4 SUL centre managers,
        4 international; each with url + date-read sources, senior athletes only), `data/urheilulukiot.json` (15 sports lukiot,
        the 20-point application, cut-offs found, SUL's five centres), `data/towns.json` (84 towns: population 2025, maakunta,
        winter-break group), `data/school.json` (the real 2026–27 year + matriculation days, later years by `estimated` rules).
        `tools/json_check.gd` checks the sources. *(Sonnet, high)*
        Left for later: **the adult-level research session** (many more real senior coaches), the federation's 0–5 scale for
        athletics (needed by S3), the unverified items listed in the files' `not_verified`, re-reading every real coach's page
        before release.
  - [x] **C6. Coach market** *(done 2026-10-17, GDD 4.9 "Built (step C6)"; user: town size moves the club coach a moderate
        step, the market grows with age (TF-juniorit opens it early), 4 new coach personalities, real coaches the same chain with
        neutral words, the tighter family budget, missing fees estimated by reputation, distance in three steps, ending after
        6 + 4 + 4 Strained weeks; follow-up: coaches offer themselves whenever they see a reason, no ceiling but an "Open to
        offers" switch, never accepted from the message, the message as detailed and as good as the coach)*: availability (town size, remote, parent, coaches choose, spots), scouting ranges and how they
        narrow, the profile page, Find a coach, changing coach (moments), the family budget. `CoachMarket`, `data/market.json`,
        `tools/market_check.gd` (in `run_all_checks`). *(Opus, high)*
        Check: a 14-year-old in a small town sees 1–3 coaches, in a centre town more; ranges narrow as designed; tour + layout check.
        Left for later: moving town (S3), camp coaches as people (G3), money (M4: a national real coach is over every budget until
        then), family reactions to a change (P1).
  - [x] **S1. School model (headless)** *(done 2026-10-17, GDD 4.9.3 "Built (step S1)"; user: holidays = relief (a normal school
        week at Normal / Normal is today's game), NO exam weeks in yläkoulu (only single tests, which cluster into busy test
        weeks; the exam-week machinery is ready for S3), free time = motivation vs rest, a mild life load)*: `SchoolSystem`
        + `SchoolCalendar` + `data/school_life.json`: the stage by date, the real 2026-27 calendar of 20 towns and the estimated
        rules, 17 real subjects with aptitudes, grades, study effort / free time, focus subjects, tests, report cards, the life
        load (fatigue recovery, colds, injuries, stress with its causes, free time's motivation), double days = two separate
        practices. `tools/school_check.gd` (in `run_all_checks`), `training_balance` part 2h. *(Opus, high)*
        Check: fingerprints identical at Normal / Normal in a normal week; grade drift per setting as in GDD 4.9.7.
        Left for later: the UI and the decisions (S2), the coach seeing school in his proposals (S2), lukio / urheilulukio /
        the application / exams / moving (S3), sleep and the family (P1), the balance (B1).
  - [x] **S2. School UI + decisions** *(done 2026-10-17, GDD 4.9.3 "Built (step S2)"; user: focus subjects free any time, the report
        card day = a result card + a choice for the next term (keep / study harder / ease off), a Monday stop with three answers for a
        race in a busy test week (race and risk / study and scratch / race and study on the bus), the camps themselves later (the
        camp-week session; only the verified data + Calendar bands now), the coach sees the life load)*: the School page in the
        People tab (this week, settings, focus, grades in Finnish notation, report cards), study effort + free time also in the
        Training tab, week strip shading + test marks, the day as blocks + the life load in words in the day editor, Calendar bands,
        Report lines, the report card as a stop, the meet-and-tests decision, the coach's simulation with the school, the four
        verified Pajulahti camps (the old data had three). *(Sonnet, high)*
        Check: tour + layout check (5 sizes), help_check both layouts, `school_check` part 13, `run_all_checks` 21 / 21,
        `training_balance -- 0` fingerprints identical.
        Left for later: the camps as a feature (applying in August, being picked, the camp week: the camp-week session, GDD 4.9.6 no. 4),
        exam days of lukio (S3), the family's reaction to a report card and sleep (P1), mood news from a report card (P1), the balance (B1).
  - [x] **S3a. The application after grade 9 + the path + moving** *(done 2026-10-17, GDD 4.9.3 "Built (step S3a)"; S3 was split
        because the user chose individual lukio courses, a test-day minigame and a 10th-grade year; user: a stop when the window opens
        and an editable list, school points from a test day with attributes + three choices, a rejection leads to the continuing
        application with a 10th-grade year among the answers, sport points from the best 800 m against the real standards, an
        academy coach you can switch to, a "training town" for moving with the club staying, the meet-and-tests rule "test the day
        before" dropped)*: `SchoolApplication` + `data/application.json`, the stages urheilulukio / lukio / vocational / 10th grade /
        school is over from the athlete's path, lukio exam weeks from the periods rule (checked against Helsingin kielilukio), morning
        practice relief, the three stops, the School page's application panel + YOUR SCHOOL, Calendar bands, moving (`training_town`),
        the market's new town + the school's academy coach, `tools/meet_test_rate.gd`. *(Opus, high)*
        Check: `school_check` part 14, layout check (5 sizes), tour (52...), `help_check` both layouts, `run_all_checks` 21 / 21,
        `training_balance -- 0` fingerprints identical.
        Left for later: S3b (below), the effects of academy services and TF-nuoret, open days, reserve places, listing schools of
        other towns than your own for the general lukio / vocational school, homesickness and family at the move (P1).
  - [x] **S3b. Lukio courses + the matriculation exams** *(done 2026-10-17, GDD 4.9.3 "Built (step S3b)"; read first: the decree
        810/2018 Annex 1 (94 / 102 compulsory credits, 150 in all = 75 two-credit courses), the exam board's rules (five exams, three
        groups, a long syllabus, at most THREE sessions in a row also in a 4-year lukio: the "4 sessions" plan was wrong), Mäkelänrinne's
        guide; user: a stop at the start of every period AND a results stop at its end (separate), 4 years in any lukio, a stop per
        exam session, the player leaves out compulsory courses in a sports lukio, a skipped exam = a no-show and a retake)*: `Lukio`,
        `Matriculation`, `data/lukio.json`, the counsellor's plan and choices (long / short maths, a new language, 3 or 4 years), course
        exams in the period's exam week, the period results, the exam plan with its rules, real exam days, grades L-I fitted to the
        board's shares, the certificate, the meet-and-tests stop with exam days, the School page's lukio panels, the stop panels, the
        strip's YO, the Calendar. *(Opus, high)*
        Check: `school_check` parts 15-16, `school_fingerprint` (grades 8-9 identical to S3a), layout check (5 sizes), tour (53...),
        `help_check` both layouts, `run_all_checks`, `training_balance -- 0` fingerprints identical.
        Left for later: compensation of a failed exam, the academy services' effects, school-specific optional courses (folded into the national ones), the lukio diploma courses,
        what the matriculation grades open after school (M4), the family's reaction to grades (P1), the balance (B1).
  - [x] **P1. The cast + first moments (ages 14–15)** *(done 2026-10-18, GDD 4.9.5 "Built (step P1)"; user: the core cast
        (1-2 parents, a sibling only with that answer, a best friend + 1-2 friends, 3 close training partners, 3 school staff),
        parents' attitude in words + reactions + moods (an 'against' family can come round), a Rivals thread of at most 3, a reply
        can give a late night (life load tomorrow) and nudge the grades, Important only ~1 people stop a week, teachers' messages on
        the School page, the confirmation camp as a choice in February)*: `Cast` + `data/cast.json`, ~150 storylets in
        `data/storylets/family / friends / group / school_people / rivals.json`, `StoryletSystem.people_enabled` (only main.gd),
        new senders / conditions / effects / placeholders, `dated` moments, the family's card and application talks, rival notes,
        `PeopleUI.roster`. *(Opus, high)*
        Check: `storylet_check` part 7 (rate, stops, repeats, coverage per storylet / age / person, save / load, neutral), layout
        check (5 sizes), tour (54...), `help_check` both layouts, `run_all_checks`, `training_balance -- 0` identical.
        Left for later: the training group's pull in hard sessions (B1), sleep as its own system (a late night is life load now),
        the family budget's real money (M4), lukio staff's moments, ages 16-17, the move's goodbyes (P2), teammates quitting or
        joining for real (P2).
  - [x] **Check-in 2026-10-18** (realism audit of C2–P1 + project review, `docs/AUDIT.md` "Check-in (2026-10-18)"): 22 / 22
        checks; `season_playtest.gd` counts stops by kind (new `player` policy): **3.1–3.2 stops a week, no week without one**
        (proposals 1.0, the Sunday talk 1.0, the people 0.8); found TUVA (the 10th grade is gone since 2022), offers sent
        straight to minors, two text bugs; the user has not played anything since playtest 1. Order agreed below.
  - [x] **Fix session (after the check-in 2026-10-18, done 2026-10-18; GDD 4.9.5 "Built (check-in fixes 2026-10-18)"; details in `docs/AUDIT.md` "Agreed with the user (2026-10-18)"):** *(built: TUVA texts; offers to under-18s through a parent + remote coaches from 16; the proposal and goals texts; `GameConfig` with `real` / `lab` + `fixed_seed`; `run_all_checks -Quick` (~6 min); `storylet_check` on fixed careers (+ `-- quick`); `school_system.gd` split into `SchoolPathPart` / `SchoolLukioPart` / `SchoolMatricPart`; the standing order "Lukio courses" + period results as a message unless a course failed; `CLAUDE.md` 103 KB → 17 KB with the details in `docs/CODEMAP.md`.)*
        (1) TUVA instead of the 10th grade, a coach's offer to an under-18 through a parent, remote coaches from 16, the two
        text bugs (a lighter proposal's "more work", "Far away · Far away"); (2) one `GameConfig` with the presets `real` /
        `lab` replacing the scattered tool switches; (3) `run_all_checks -Quick` (~5 min), fixed careers in `storylet_check`,
        `school_system.gd` split (fingerprints identical); (4) CLAUDE.md trimmed to ~20–25 KB + `docs/CODEMAP.md`; (5) the
        standing order "Lukio courses: ask me every period / let the counsellor plan them". Help entries for anything new.
        *(Sonnet, high)*
        Check: `run_all_checks` (full), `training_balance -- 0`, `school_fingerprint`, `quick_fingerprint` identical; layout
        check + tour for the changed screens.
  - [x] **Season playtest 2 by the user** *(done 2026-10-18; notes sorted in `docs/PLAYTESTS.md` "Season playtest 2")*: verdict: a tedious micromanagement clicker, boring non-immersive races, "I don't know why things happen or whether anything matters". The user chose (2026-10-18): the design session next, the stops unchanged until then.
  - [x] **Design session after playtest 2** *(done 2026-10-18: **GDD 4.10 "plan → play → see"**: the Sunday planner as the one weekly stop, mid-week stops only for real ones, the coach's changes as notes on the planner, causes visible, goals with stakes, people as state + 9 free-time slots, new people and a first relationship from ~15, the training group's pull, focus blocks + unlocks + a skill tree earned by doing, two race prototypes, the look pulled forward, a Career tab + reputation + season review; the cut list is in 4.10; the old D2 / P2 / G1-G3 / B1 / UI-overhaul list below is replaced by the new order)* *(Opus, high; no code; the user's pick, 2026-10-18)*: one conversation that decides what a week and a season should FEEL like before any more building. Brief: (1) **causes made visible**: a "why" view for the body, Form, mood and the week's result, what every answer changed, effects after each race (attributes, relationships, mood); (2) **far fewer, richer stops** (real decisions only; state-aware moments that remember choices; the pool was 101 variants for 240 moments in a season, 35 never answered; consider cutting or merging systems that do not pay off: proposals 38 of 40 "lighter", the habit goal, the Q&A events); (3) **more to play with**: training and development depth (a skill tree?), the training group's real effect, new friends, camps, warm-up and cool-down, goal reviews; (4) **race presentation and the UI overhaul** pulled forward if the user wants (research: real race graphics, zoom, a visual direction the user picks); (5) the career-simulator essence (the user: "we have lost it"). Input: `docs/PLAYTESTS.md` (playtest 2 table and the save analysis), `docs/AUDIT.md` check-in 2026-10-18 part 3. Output: decisions in the GDD, a new roadmap order. The confirmed bugs of the playtest 2 table (coach pronouns, the rippi / phone / "confidence confident" texts, the lighter-day reason, ask-then-propose, scratch reaction, the habit counter, the Dev jump) are built right after that design, or inside it.
  **The new order (agreed 2026-10-18, GDD 4.10; the loop first, the look pulled forward, a playtest by the user after the loop).**
  Every session: lab fingerprints identical unless it is meant to change them (R7), help entries for anything new, `run_all_checks
  -Quick` while working and the full run at the end, layout check + tour for changed screens, a commit and "Push origin".
  - [x] **F1. Playtest-2 bug fixes** *(done 2026-10-18: GDD 4.10 "Built (step F1)", `tools/f1_check.gd`)* (the 11 confirmed bugs of `docs/PLAYTESTS.md`'s table): (1) the coach's pronouns from the coach's
        gender, not a hard-coded "he" (~300 texts: placeholders); (2) "Confidence confident" (the mood name and word glued); (3) the rippi
        question needs `!rippi_none`; (4) `fam_screen` "phone until one" contradicts the phone rule (tie it to the rule or drop it); (5)
        mobility "a bit much for your shins" (no strain = no risk in the coach's noise); (6) the "fresh enough" reason on a lighter change;
        (7) a proposal on a day the player just asked the coach about (proposals remember "Ask the coach"); (8) the coach's reaction to a
        scratched race (before and after); (9) closing lines that promise a mechanism ("tell me … on Wednesday") and name the UI ("you see it
        in the day view"); (10) one definition of a "done" session (the habit counter vs the Sunday talk); (11) the Dev jump passes stops
        (answers them with the default) so the school years can be reached. *(Sonnet, high)*
        Done: each bug has a check that fails before and passes after; fingerprints identical; the user's save still loads.
  - [x] **V1. The look: visual direction** *(done 2026-10-18: GDD 5 "The look (V1)"; the user picked **"Stadium Night" with broadcast
        numbers**: A's dark, calm FM-dense base + B's condensed numbers and a TV-style race card; track orange kept, yellow only for race
        results; the stadium photo only on big moments; dark only for now; D28 amended; mock-ups in `docs/v1/` (planner and race card,
        PC + phone; `look.html` has all three directions and the research))* (research: FM, sports-broadcast graphics, running apps such as Strava / Garmin, mobile sports
        managers; three directions as mock-ups; the user picks; written into GDD 5 with colours, type, density and icon style; D28
        revisited). No game code. *(Opus, high)*
        Done: a chosen direction in the GDD, and the week planner shown in it as a mock-up.
  - [ ] **L1. The week planner** (GDD 4.10 decision 1): the Sunday planner replaces the Sunday talk popup; the coach's notes on days (only
        when his truth is not "Fine"; Make it easy / Keep mine); proposals are no longer stops; the mid-week stop rule; race weeks shown with
        the plan's own taper; the Training tab becomes the season plan; the 9 free-time slots with standing habits (neutral habit in `lab`);
        built in V1's look; save version 5 (older saves load). *(Opus, high)*
        **From V1 (read GDD 5 "The look (V1)" and `docs/v1/planner_pc.png` / `planner_phone.png` first):** start with the **V1 kit**:
        the new `Palette` values and tokens (`TOP_BAR`, `DAY`, `LEAD`, `PEOPLE`, `BAR_TRACK`, `DAY_REST` …), Barlow Condensed in
        `assets/fonts` (+ licence), the `ThemeBuilder` variations (`DisplayNumber`, `BigNumber`, `SectionLabel`, `WhyLabel`), the Lucide SVGs
        in `assets/icons` (+ ISC licence, README) with an `Icons` helper, and the controls `StatBar` (warning tick), `CauseChip`,
        `CalloutCard`. The old screens pick up the new colours at once (expected; check them with `layout_check` and the tour) and are
        restyled properly later. Open points for L1's own questions: the tab names (the mock-up shows This week / Season / Calendar /
        People / Career / Rankings: where Overview and Report go), whether the week strip stays in the header of other tabs, and what Play
        week does with choices still open ("2 choices waiting"). The mock-up's 32 px in-card buttons become 44 px (the rule stays).
  - [ ] **L2. Causes visible** (decision 2): body bars with % and warning lines, Form with its factors, moods with causes, the week report
        column (one "done"), the "what this race did" card (incl. a scratch), effects as words + what they do with numbers on a tap.
        *(Opus, high)*
        Done: every number the player cares about has a "why" one tap away; the tour shows each.
  - [ ] **L3. The cuts + goals + school page** (decisions 3–5 and the cut list): sort P1's ~150 storylets into delete / feed / invitation /
        story beat, a "never contradict" check in `storylet_check`, the habit goal and the cue word cut, mental training as sessions, the
        goals menu with stakes + the two reviews, the School page apart from the messages with tests in the week report. *(Opus, high)*
        Done: the cut list done; `storylet_check` finds no contradicting or promising lines; stops a week measured.
  - [ ] **K1. Career tab + the next big thing + reputation + the season review** (decision 10). *(Sonnet, high)*
        Done: every result in one list, the milestones timeline, the Overview's countdown and long path, a season ends as a chapter.
  - [ ] **Season playtest 3 by the user** (6–8 weeks of the new loop is enough): does a week feel like plan → play → see? Notes into
        `docs/PLAYTESTS.md`; the sizes of things are tuned after it (memory: feel it before tuning).
  - [ ] **P2. People as state** (decision 6, replaces the old "moments part 2"): new people from places, person pages, friendship by
        shared time and fading, invitations from the calendar and the state, a first relationship from ~15, the training group's card
        (level, fixed days, pull, leaving it), Find a coach's comparison, moments for ages 16–17 in the new form. Research first: Finnish
        teens' time use, sleep and dating age; training group sizes and schedules. *(Opus, high)*
        Done: a friend can be made and lost through slots; the group's pull shows in the week report; `storylet_check` covers the new kinds.
  - [ ] **R6. Race presentation** (decision 8): research (athletics TV graphics, World Athletics track specs outdoor + indoor, Godot 2D /
        2.5D techniques, CC0 runner art), then **two short prototypes** (TV-style 2D and a 2.5D broadcast angle) for the user to pick from,
        then the build: the stadium from specs, figures, follow camera + zoom, TV graphics, the kick slow-motion setting (Off / Short /
        Full), plain labels. Presentation only: the races hash stays. *(Opus, high)*
        Done: the user picked a prototype; `race_check`, `layout_check`, the tour; races hash identical.
  - [ ] **R7. Race controls + "Move in" + the race-day timeline + competitiveness** (the backlog's race-controls design, the warm-up /
        cool-down timeline, the tree's race-craft nodes if T1 is done): a race session that changes the engine on purpose. *(Opus, high)*
        Done: a new deliberate races hash recorded; `race_shape`, `race_rounds`, `race_check`.
  - [ ] **G1. Test days + Rep by rep** (one shared played-session screen, Auto, training PBs; research: youth test batteries and norms).
        *(Opus, high)*
  - [ ] **G3. Camp weeks** (the Pajulahti grade 7–9 camps, club, district and holiday camps, later TF camps; research: dates and costs;
        new people from camps). *(Sonnet, high)*
  - [ ] **T1. Development: focus blocks + real unlocks + the skill tree** (decision 7; research: SUL's youth path for weights, double
        days, altitude camps; the race-craft nodes wait for or join R7). *(Opus, high)*
  - [ ] **G2. Race rehearsal + Video review.** *(Sonnet, high)*
  - [ ] **D2. Real schools (research + data, then a short build)** *(independent: can run beside any session above)* *(user 2026-10-18,
        after P1: "Upper secondary school (Sastamala)" is a placeholder from S3a, not research)*: for every game town the real general
        lukiot (with their published lowest accepted averages, 5 or 6 periods), the real vocational schools (athletics-friendly
        programmes) and the real grades 7-9 schools, each fact with its source and read date, unverified ones marked; then the
        application, the School page and the lukio calendar use them instead of the town-named placeholders. *(Opus, high)*
  - [ ] **Restyle the remaining screens** in V1's look (GDD 5 "The look (V1)": the text-cutting rules, the 56 px header, the photo only on
        big moments, the race card's broadcast shapes; with layout_check, the tour and help_check updated). *(Sonnet, high)*
  - [ ] **B1. Balance session:** every target of GDD 4.9.7 + 4.10 over many seasons in the `real` preset (`career_check`, `season_check`,
        `storylet_check`, the slots' and the group's effect sizes). *(Opus, high)*
  - Then the user's playtest and the **check-in at the end of M2** *(Opus)*. Gym day comes with the specialists (later).
- [x] Coaching (original item; designed above) (hire, veto; also the coach's race advice by personality instead of the 80 % dice: the hard driver
      over-tells you to go / push, the calm one to wait, the race reader the most accurate; check-in 2026-10-10).
      From the season playtest (user, 2026-10-10: "small choices; it needs to be more interactive with the coaches and
      everyone around me", and school, coach talk and friends all wanted): the coach explains the plan and why, talks
      about the week, sets season goals with times ("what makes the coach happy"), and the days get small choices
      with the people around the athlete. The days feeling empty is the playtest's biggest complaint.
      User wishes (2026-10-11, after the talent session): (a) **ask the coach's opinion** when fine-tuning the plan (the coach
      comments on your own edits, better or worse depending on the coach); (b) **many coaches / coaching teams to choose from,
      each with their own attributes like Football Manager staff** (e.g. endurance and speed knowledge, youth development,
      periodization, race reading, motivation, injury prevention, communication; personality; availability, cost, reputation,
      location), with realistic limits on who a 14-year-old in a small town can get (club coach first, more choice with age,
      results, an urheilulukio or a move). Claude's view: yes, it fits D18 and gives the plan choice the weight the talent
      session found missing (the plans differ by only 1–2 s at 21).
- [x] School (grades, exams vs meets, Finnish school calendar; original item, designed above in GDD 4.9.3)

After Coaching and School (agreed order 2026-10-10): athlete reputation, the Statistics tab, the pre- and post-race
studios (with the race ceremony), audio. Details in the ideas backlog. Check-in 2026-10-11: the talent balance session
comes first (above, done 2026-10-11; its open point for Coaching: make the plan choice matter more, now 1–2 s at 21), then the Coaching + School design (with "Never stale", mental training and moods, the written coach
dialogue and 2–3 light-minigame ideas for the user to judge), then **more meets** (backlog "More meets in the calendar";
independent research + data, so it may run beside the design).

## Ideas backlog (from the user, 2026-10-06; placement is Claude's proposal, not yet designed)
- ~~**Ctrl+S to save**~~ — done in M2 step 4 (same as the Save button, "Saved ✓", desktop only).
- **Choose your birth date:** birth date is already an input to `AthleteFactory`. Day + month inside the starting
  birth year is safe (same age class); other years change the start age, eligible meets and the rival cohort, so
  that waits until more age classes exist (M4+). Small character-creation task after step 5. *(Sonnet)*
- **Choice of coaches / coaching groups / coaches per sub-area** (**designed 2026-10-11, GDD 4.9.1**; specialists built later) (e.g. speed, endurance, strength, mental, physio):
  belongs to M2 part 2 "Coaching". Needs a design session first (Opus); it plugs into the step-1 hooks (`by = "coach"`,
  Accept / Veto in the day editor, coach events, and `on_week_start` from step 3 for a coach's weekly changes); a
  physio could read the health model (`HealthSystem.soreness_info`, `plan_risk`). Design it together with School, since both compete for the athlete's time.
- **Profiles for all other athletes + profile pictures:** two stages. (1) After M2 part 1: a rival profile screen
  (tap a name in Rankings or a race field: club, age, PB / season best, results history, scouting-style attribute
  hints) with procedurally drawn avatars (generated in code, never real photos) for the fictional youth rivals.
  Needs rival results history stored; it can also show "injured" (rivals have `out_weeks` since step 3). (2) With senior level (M4+): real athletes with data from `data/*.json` and, where a
  properly licensed photo exists (e.g. Wikimedia Commons CC BY-SA, needs the Credits screen), a real photo.
  Youth stay fictional (minors). The player's own avatar can come with stage 1 too.

- **Club (seura) and hometown pages (user, 2026-10-07; parked until after M2, check-in 2026-10-10):** see your own club's information, and the same for every club: general
  info, all its athletes. Likewise your hometown and every hometown: info and all its athletes. Needs clubs / hometowns to
  have athletes (rival cohort per club and town) and the rival profile screen above. Needs a design session first. *(Opus, then Sonnet)*
- **More meets in the calendar (user, 2026-10-07):** add all the national and international meets that can be found, on top of
  the SUL Arvokilpailukalenteri 2027 PDF (https://www.yleisurheilu.fi/wp-content/uploads/2026/05/Arvokilpailukalenteri-2027.pdf)
  already used. Real dates with sources; where unknown, realistic estimates marked `estimated`. Also fills in more `main` meets
  for the season model (GDD 4.8). Research + data task. *(Sonnet)* **Placed (user, check-in 2026-10-11):** after the talent
  balance session, beside the Coaching + School design (independent); new meets change which races careers run, so
  measure before / after (`career_check`, `season_check`). SUL's real Kalevan kisat entry rule (direct 1:53.50 / 2:11.00,
  waiting list 1:55.50 / 2:15.00 in the same year, target 27 per sex, `docs/AUDIT.md`) goes into the data when seniors
  can enter it (M4).
- [x] **In-game help per menu (user, 2026-10-07; built 2026-10-07, GDD 5 "Help"):** not a full tutorial: every screen / tab (Overview, Training, Calendar, Rankings, Report,
  day editor, race screen, season plan later) gets a "?" / "How this works" button that opens a short help panel for that screen only,
  when the player wants it. The game is deep (training, health, form, periodization), so the help text explains each concept in plain
  words. Help texts live in `data/help.json` (one entry per screen, with sections), shown by one shared `HelpPanel` (phone: bottom sheet,
  PC: side panel, 44 px, no hover). Each new feature step adds its help entry; a small "new" dot on the "?" could mark unread help.
  Best started right after step 6e (season UI) so the big screens exist; the entries for the existing tabs can be written earlier. *(Opus for the text outline, then Sonnet)*
  **Done:** 13 screen entries + 9 topics, `HelpButton` / `HelpPanel` / `HelpOverlay`, `tools/help_check.gd`; 6f added `season_offer`,
  `return_block` and the topic `easing_back_in` (now 15 screens + 10 topics).
- **Track visuals (user, 2026-10-07; parked → M3, check-in 2026-10-10):** the user is starting to dislike how the track looks in the main menu and in the races (the
  drawn stadium / hall track). Worth a look later: get reference images of real tracks first (CLAUDE.md: realism, no guessing), then
  redraw. Could go together with M3 (stadium view). *(Opus for the look, then Sonnet)*
- **Season best (SB) in the race field (user, 2026-10-07; done in R4, 2026-10-09):** the pre-race "THE FIELD" list on the race screen (`race_screen.gd`
  `_show_pre`) shows only PB per runner; add an **SB** column next to it (this season's best, "–" when none). Rivals already carry
  `sb` / `sb_season` (Rankings, `Rivals.train_week`); the player's SB comes from `Rankings`. On a phone the row is tight (name + PB), so
  show PB and SB on one line or drop the club first. Small UI task. *(Sonnet, low)*
- **Statistics tab (user, 2026-10-08):** a tab (hub: Overview / Training / Calendar / Rankings / Report + **Stats**) with
  everything we can think of about the athlete: number of races, wins, 2nd / 3rd places, podiums, DNF / DQ, PBs and season bests
  per event and per season (best times by season, a PB history), races by level / indoor vs outdoor, average place, results table
  with filters, rivals beaten / lost to most, attribute history (curves per season), training totals (sessions, hours, load),
  injuries and illnesses (count, days lost, by area), form and fatigue history, weeks at each phase, season targets met.
  Needs the results list to keep more per race (field size, round, shape, conditions) and a per-season history; the layout
  rules apply (phone: stacked cards, no hover). Design the list first, then build in steps. *(Opus for the list, then Sonnet)*
- **Race details window after the race (user, 2026-10-08):** an information window after a race (the result screen grows
  into it, together with R4's Race story): the race in detail (splits, key moments, your place through the race), whether any
  abilities have risen (the weekly progression is on Sunday night, so this means "what the race taught", or the attributes
  that moved since the last race), the fitness / fatigue and form level, the coach's comments, health notes (fall, spike
  wound, niggles), rivals met, PB / SB / rankings effect. Details later; the data comes from `Race.events`, `RaceDay`, the
  form and health systems. *(Opus for the design, then Sonnet)*
- **Warm-up and cool-down around a race (user, 2026-10-08; designed 2026-10-11 as the "Warm-up routine", GDD 4.9.6, session G3), Finnish alkulämmittely / loppulämmittely:** a part before and
  after the race, part of the race day: the player chooses (or the coach plans) the warm-up (length, intensity, drills,
  strides), which sets race-day readiness (a poor warm-up costs a little at the start; an over-long one costs reserve), and
  the cool-down helps recovery (soreness / fatigue) and shows up in the race-day report. Plugs into the day engine
  (`on_day_start` / race day), the health model (injury risk when cold, warm-up as prevention) and Form (GDD 4.8). Needs a design
  session first. *(Opus, then Sonnet)*
- **Pacemakers (jänis) in senior races (user, 2026-10-08; parked → M4, check-in 2026-10-10):** at senior level (M4+, Kalevan kisat and international meets, Diamond
  League style) some races have a pacemaker who sets a fast first lap(s) and drops out (usually at 400–600 m), changing the race
  shape (the leader runs the target split instead of the field's even pace; the shape mix gets a "paced" shape, GDD 4.3.1).
  The player could be offered the hare's pace, and rivals' personalities react to it. Also fits "pace lights". Designed with
  senior meets. *(Opus)*
- **More athlete photos for the backgrounds (user, 2026-10-08):** now only two photographers' three CC BY-SA photos
  (`assets/backgrounds/`). Find more copyright-free / free-licence (CC0, CC BY, CC BY-SA, Wikimedia Commons, Unsplash / Pexels
  licence terms checked) athlete and track photos, ideally Finnish athletics, with the credits added to the README there and
  to the in-game Credits screen (still missing). No photos of identifiable minors (youth meets) unless the licence and
  privacy allow it; keep `mipmaps/generate=true`. Research + asset task; downloads need the user's OK per file. *(Sonnet)*
- **Training screen with training PBs (user, 2026-10-09; check-in 2026-10-10: designed as part of the Statistics tab,
  not a screen of its own):** a dedicated screen for training results and detailed training
  info: gym PBs (squat, deadlift, jumps, medicine-ball throws...), long / easy run PBs (distance, pace, time), interval PBs
  (e.g. 6 x 400 m average, best 200 m / 300 m / 600 m rep), tempo and test sessions, with history and PB marks, per
  season. The numbers come from the athlete's attributes, the session and the day's form / fatigue (so they rise as
  the athlete improves), stored per session type; the Stats tab (above) can link to it. Needs a design session
  first: which results per session in `data/training.json`, how they follow the attributes. *(Opus, then Sonnet)*
- **Venue-specific stadiums (user, 2026-10-09; parked → M3, check-in 2026-10-10):** a meet in a small Finnish town looks like it is run at Olympiastadion,
  because there is one stadium model. Give venues their own look and size (small town track with a little grandstand,
  a big arena, an indoor hall, Helsinki's Olympiastadion...) from data per venue (`data/competitions.json` venues: stands,
  capacity, colours, lighting, lanes). Get reference photos / specs of the real venues first (CLAUDE.md: realism, no
  guessing); goes with "Track visuals" below and M3. *(Opus for the look, then Sonnet)*
- **Other events in the stadium during your race (user, 2026-10-09, "if at all possible"; parked → M3, check-in 2026-10-10):** field events running in the
  infield at the same time (jumps, throws, with athletes warming up and attempts happening), so the stadium is alive.
  Fits M3 "simultaneous events"; needs the meet's programme (next item) and the venue models above.
- **Race ceremony: introductions and the start (user, 2026-10-09):** before the start the athletes are introduced (name,
  club, PB / SB, maybe a short line from the commentator), then they walk out and take their places on the track (the
  800 m start in lanes), and "On your marks - set - go" like in real life (Finnish: paikoillenne - valmiina - laukaus),
  with the gun. Goes with R4's commentary and the Race story; a pre-start stage on the race screen between the field
  list and the running stage. *(Opus for the design, then Sonnet)*
- **Pre-race studio and post-race studio with interviews (user, 2026-10-10):** the broadcast around the race, built on
  R4's commentator + expert crews and the race ceremony above: before the race a studio piece (the crew on the favourites,
  the field, the stakes, the player's story, perhaps a short interview with the player or their coach on the way to the
  start); after it a studio piece and a finish-area interview, given or not by how the race went and how well known
  the athlete is: a win, a medal, an upset (the player beat a clearly stronger runner: needs the rivals' ability / ranking
  from `Race.results`), a PB, a fall. The player's answers (modest / confident / blunt, thanking the coach...) could
  feed reputation and, later, sponsors and fame & media (GDD 2 D9). Needs **athlete reputation** (next item) to decide
  who gets interviewed. Texts as data like `race_commentary.json`; the Race story and the coach's lines are the seed.
  *(Opus for the design, then Sonnet)*
- **Athlete reputation / popularity (user, 2026-10-10):** a hidden-but-hinted number (and a few words: unknown, one to
  watch, local hero, national name...) from results (wins, medals, upsets, PBs, streaks), age (a young talent counts
  more), meet level and media moments (interviews). Drives who is interviewed and how the commentators talk about the
  player ("the young runner everyone is talking about"), later sponsors, fans, offers, the coaches who want to work
  with you. Design with Statistics and the studio / interview items. *(Opus)*
- **Voiced commentary: parked (user, 2026-10-10).** A prototype with the device's built-in text-to-speech voices (the banner lines and the coach read aloud; a Voice button; Godot `DisplayServer.tts_*`) was built and tried the same day: "horribly robotic", so it was removed again and the user chose to focus on other parts of the game first. If it comes back, the route recommended then: **pre-generated clips** made once with a neural cloud voice service (the user runs the generator with their own key, a few euros), shipped as audio files (offline, PC and phone). Our lines contain names and times, so it needs its own voice script: 150–300 short generic phrases per voice (commentator, expert, each coach) plus a clip per surname, as sports games do; the text commentary stays. Alternatives weighed: Piper on PC only (offline, medium quality, engine now GPL-3.0, each voice has its own licence, PC only), real voice actors (best, costs). Check the provider's terms for use of the audio in a game; sending text to an outside service needs the user's OK. Voices would also need Finnish text for Finnish audio (D27: all texts are data).
- **Audio (user, 2026-10-10, "can we implement any audio at any point?"): yes, from Godot's own audio nodes.** Plan: a
  small `Sound` autoload (one place that plays sounds, with master / effects / music volume and a mute, saved in the
  settings), then in steps: (1) the race: starting gun, bell, stadium crowd ambience that swells on the home straight
  and at a kick, footsteps / breathing at low volume, a finish-line beep; (2) UI clicks and soft confirmations; (3)
  music for menus (calm) and results; (4) the commentary voiced: not text-to-speech (it sounds wrong for a broadcast); a
  few recorded voice lines per crew would need real voice actors, so later or never, but the crowd could react to
  the commentary events (a roar on a kick, a groan on a fall). All sounds need free licences (CC0 / CC BY, credits in
  the Credits screen) found and approved by the user file by file (downloads need the user's OK); mobile: keep files small
  (OGG, mono for effects) and respect the phone's silent mode. *(Sonnet for the plumbing, the user for the taste, assets
  need a research session first)*
- **Race controls: run the whole race yourself (user, season playtest 2026-10-10):** "ditch the selection cards and go
  with a system where I just control the whole race (via buttons, slider, or something) based on what I see and what
  the coach says to me". The action bar (Push / Hold / Ease / Kick now / Move out) already does part of it; the cards
  would become optional or rarer. Touches GDD D2 / D26 (decisions at suitable points, no dexterity): needs its own
  design session with the user. The quick fix before step 7 only frees the kick (built 2026-10-10: Wait never kicks by
  itself in a watched race, Kick now works at any distance; plus a **kick plan** for Quick result, the first piece of "a
  tactic my AI self follows": the user asked for it, and more of it (an effort plan, a reaction to moves) belongs in this
  design session). **Also here (user, session M1, 2026-10-17):** competitiveness for the player = a little extra dig in the
  last 200 m when side by side with a rival you've met or one ranked just above you (GDD 4.9.4; a deliberate race-engine
  change with a new `quick_fingerprint` hash). *(Opus)*
- **Never stale: no "same three options again" (user, 2026-10-11; designed 2026-10-11: storylets, memory, standing orders and the
  check tool in GDD 4.9.5, the played sessions in 4.9.6; still open: rivals' dropouts and life events with the rival profiles, variety
  in the races themselves (weather, other events)):** "I'm most afraid that the game will get stale
  quickly (here's 3 options to choose from, repeating cards off and on track)… look into training minigames or
  something else; be the idea factory." **Conflict to settle first:** GDD D1 / D2 say no minigames and no dexterity
  input; the user asks to look at them again. Claude's ideas (not designed, 2026-10-11):
  (1) **Storylets instead of a card pool:** every event, card and talk has conditions (age, history, rivals, school,
  injuries, results) and consequences, and is used once or with a long cooldown; chains and milestones ("your first
  SM", "beating the rival who always beat you", "back after the stress fracture") instead of random draws;
  (2) **lines built from the athlete's own history** (the coach remembers your last answer and how it went, rivals have
  memories of you), so the same situation never reads the same;
  (3) **standing orders** for the repetitive: the player sets a rule once ("cover moves from runners weaker than me",
  "easy day when sore") and is only asked when something is new;
  (4) **key sessions played through** (decisions, no dexterity, the race engine reused): an 800 m interval session or a
  time trial where you choose each rep's pace from the coach's splits and your Feeling word, and pay for overcooking it;
  (5) **tests that reveal progress:** 30 m sprint, Cooper / 2000 m test, a lab test (VO2max, lactate) a few times a year,
  turning hidden growth into numbers the player sees (also answers "can't tell whether training works");
  (6) **arcs a season has:** national youth team selection (Sweden match, EYOF), a training camp (Kuortane, abroad,
  altitude), a new coach, a training group with teammates, a rival moving clubs, a school exam week;
  (7) **variety in the races themselves:** weather, venues, the 1500 m / 400 m / relays / cross-country (D6);
  (8) a **"never twice" rule checked by a tool** (as `commentary_check` does for the commentary).
  Placement: the Coaching + School design session (it designs the days), then each piece in its own build step. *(Opus)*
  **Decided at the check-in 2026-10-11:** D1 / D2 stay (no dexterity; sessions played through with decisions are
  fine), but the user is still interested in light minigames "if we can figure out what and the proper way to
  implement them" (the not-getting-bored factor): the design session brings 2–3 concrete, realistic, phone-friendly
  ideas for the user to judge. Rival churn is split: late bloomers and plateaus in the talent balance session,
  dropouts and rivals' life events here and with the rival profiles (the pool's top 20 at 17 stays top 20 at 21 77 %
  of the time; real ~20–30 %, `docs/AUDIT.md`).
- **More attributes, mental training (user, 2026-10-11; designed 2026-10-11, GDD 4.9.4: three moods, growing consistency and
  composure, jobs for competitiveness and ambition, a weekly mental plan; no new physical attributes):** "Are we sure we don't need more athlete attributes? Mental,
  physical? Maybe the mental side could use more training options. Keep them realistic (what athletes train in real
  life)." Today: 10 physical, 2 technical, 7 mental, 6 hidden; the mental ones grow only from races (consistency never
  grows). Claude's first thoughts (to research): real mental-skills training for runners = goal setting, imagery /
  visualisation, self-talk, breathing / relaxation, pre-race routines, attention focus, race-simulation sessions and
  video / race analysis with the coach; candidates = **confidence** and **motivation** as moods that change week to week
  (not fixed attributes), maybe **focus**, and the sessions that make composure, consistency and race tactics grow.
  Physical: probably enough (check: anaerobic capacity vs speed endurance, core / hip stability, body composition with
  nutrition D9). Needs research with sources and a design: each new attribute must matter in the race or training model,
  or it is only a number. Placement: designed with Coaching + School (sessions and time), built after. *(Opus)*
- **An ongoing chat with the coach (user, 2026-10-11; designed 2026-10-11 as the coach thread, GDD 4.9.2):** "something like a conversation we're having here; interactive,
  not repetitive". **Decided (user, 2026-10-11): no AI coach, no paid API.** What stays: (b) written dialogue built from
  the game state, made as varied as possible with the storylet ideas above ("Never stale"). The options that were
  weighed: (a) **an AI coach**: the game sends the coach's personality, the athlete's state (plan,
  soreness, results, goals, school) and the chat to Claude over the internet (Godot's HTTPRequest; GDScript has no
  official SDK, so raw HTTP), and the coach answers in free text; game actions (change a day, set a goal, change the plan)
  come back as structured tool calls that the game checks and shows as Accept / Veto, so the AI can never break the
  rules. Needs an Anthropic API key (separate from the Claude subscription) and internet; costs per message (rough, with
  ~6 000 tokens of context and a 200-token answer: Haiku 5.5 about 0.07 cents, Sonnet 5.5 about 1.4 cents or ~0.3 cents
  with caching, Opus 5.5 about 3 cents or ~0.6 cents with caching; a season of a few hundred messages = cents to a few
  euros); a personal project (D12) can do it, but the game must still work offline (written lines as the fallback),
  and the key must not end up in a public repo. (b) **written dialogue** with topics and tone choices (FM-style), lines
  built from the game state: predictable and free, but it repeats in the end. (c) **hybrid**: the game decides what is
  talked about and what can happen, the AI only words it and answers free questions. Claude's view: (c) first as a small
  prototype, so the user can feel it before the design commits. Placement: the Coaching + School design session decides
  whether and how; a prototype session after it. *(Opus)*
- ~~**Character creation: a points pool from the answers**~~ — built 2026-10-10 (GDD 4.1.1 "Built (points pool)"). The original idea (user, 2026-10-10; moved into M2 before step 7, check-in 2026-10-10): the 12 free points feel arbitrary. Idea:
  the background answers decide how many points the athlete gets to allocate (a runner from a sporty family with years
  of training starts with a bigger pool than a beginner; maybe the pool also follows the maturation answer), the base
  ranges stay or shrink, and the player spreads the pool as they like (still a cap per attribute). Needs a design
  session: what the pool's size range is (e.g. 8–16), how the answers add to it and whether the ones that give attribute
  bonuses today (`data/background_questions.json`) become pool points instead, so that the same story gives the same
  total strength; and `tools/training_balance.gd` (the 14-year-old's starting level feeds every balance number).
  *(Opus for the design, then Sonnet)*
- **Whole event card in the Calendar (user, 2026-10-09):** clicking an event shows the full event card, not only our
  800 m: all disciplines and the timetable of the meet (programme per day, rounds and times). Needs the programme
  as data: real timetables for the big meets (SUL / Kalevan kisat pages, source dated), a believable generic programme
  for the small ones (marked `estimated`). Extends "Calendar race details" below. *(Sonnet for the UI, research for the data)*
- **Regular check-ins: realism audit + project review (user, 2026-10-09):** every now and then a session that (1)
  repeats the realism audit for what was built since the last one (`docs/AUDIT.md`: matches / simplification / gap,
  with sources and our tools' numbers), and (2) reviews the development itself: where we are against the vision
  (GDD 1–2) and the roadmap, what is still missing, what is fragile or slow (tools, checks, code), Claude's honest
  feedback and opinions, and an open dialogue about priorities. Claude's proposed rhythm: after each larger step (next:
  after R4, after step 7, at the end of M2), or whenever the user asks. Output: a dated section in `docs/AUDIT.md`
  + roadmap changes the user agrees to. *(Opus)* First one done 2026-10-10 (`docs/AUDIT.md`); the second after step 7
  done 2026-10-11; the third after P1 done 2026-10-18; next at the end of M2.
- **Zoom in on the race (user, 2026-10-09; parked → M3, check-in 2026-10-10):** on the race screen the dots sometimes look far away. Let the player zoom
  in on the field (e.g. a camera that follows the pack or the player, zoom buttons / pinch on a phone, 44 px, no
  hover), keeping the whole-track view as an option. Mind `race_perf` (the stadium is drawn once; the dots view is
  redrawn every frame) and the decision card that must never cover the track (decision 26). Could go with R4 or M3.
  *(Opus for the look, then Sonnet)*
- **Every section's own result list (user, 2026-10-09, playtest of the meet formats; done 2026-10-10: the result screen lists every section after yours):** after sections the result
  screen shows the overall list and your own section only; the other sections (e.g. section 1's race) are only visible
  inside the overall list. Also show each section separately, in running order, as heats are (`RaceDay.heat_results`
  already holds them; `race_screen.gd` `_show_result`). Small UI task. *(Sonnet, low)*
- **Calendar race details (user, 2026-10-06):** click a race in the Calendar to see all its details: participants, level, place, standards, etc. *(Sonnet)*
- **More name variety (user, 2026-10-06):** too many repeated first names, and some last names, among rivals. Enlarge `data/names_fi.json` (and check how `Rivals` draws names). *(Sonnet)*

- **Playtest notes (user, 2026-10-06):**
  - *Coach gives only one program:* the coach should offer several plans (fits Coaching + periodization, steps 6 and Part 2). Designed in GDD 4.8: the club coach offers Steady / Balanced / Ambitious season plans (built in 6d–6f); focus plans and hired coaches wait for Coaching.
  - [x] *Race is jittery and lags after the first decision:* fixed. Two causes, found with `tools/race_perf.gd`: the indoor hall track (antialiased arcs) was redrawn every frame together with the runners (~4.6 ms of drawing per frame, 40 → 20 ms/frame on the dev laptop's Intel GPU), and the POSITIONS rows were deleted and rebuilt every frame, which re-laid-out the whole side panel with its wrapped commentary labels (the lag grew as the commentary filled up, i.e. after the first decisions). Now the hall track is its own view drawn once and the position rows are reused; steady 60 fps (16.7 ms) on PC and phone size, indoor and outdoor.
  - *More immersive races:* more in-race options, and commentary in its own box that reacts to what happens and to the player's choices (e.g. "someone kicks with 229 m to go" should be something the player can answer), less repetition, more realism. Needs a design session (Opus), then build; belongs before or inside M3 (stadium view).
  - *Races are decided too early (user, 2026-10-07):* the order seems settled early on, while real middle- and long-distance races
    are often run in one bunch, with moves made anywhere: at the start, midway, or about 200 m before the finish. Needs more pack
    racing (runners staying together, drafting, being boxed in) and moves from rivals at any point that can change the order late,
    plus the player's answers to them. Look first at why the field strings out early (rival pace choices, the fatigue and drafting
    numbers in `data/races.json`, `tools/race_balance.gd`). Goes together with the "more immersive races" design session above. *(Opus)*
  - **Both designed 2026-10-07:** GDD 4.3.1 "Race realism" (measured with the new `tools/race_shape.gd` against Tilastopaja
    results of Nuorten SM and Kalevan kisat 2026); build in M2 part 1 "Race realism" R1–R5, before step 7.

## M3 — Stadium view
- [ ] 2D stadium during meets: track, crowd, simultaneous events
- Parked here from the ideas backlog (check-in 2026-10-10): track visuals, venue-specific stadiums, other events in
  the stadium during your race, zoom in on the race.

## M4+ — Breadth
- [ ] Other running events (400m–10000m, steeple), then hurdles & sprints, jumps, throws, combined events
- [ ] International circuit, championships, qualification standards (with pacemakers in senior races, parked here
      from the ideas backlog at the check-in 2026-10-10)
- [ ] Full world simulation, sponsors, media, rivals, nutrition, equipment, doping…
