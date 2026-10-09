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
  - [ ] **R4. Commentary, coach and race story (UI + data):** `data/race_commentary.json` (variants, placeholders,
        tags, voices TV / coach / you), no repeats + rate rules, choice verdicts, the coach's spot by the track, PC box +
        banner, phone ticker + log sheet, the Race story on the result screen, personality tags and the SB column (backlog
        item) in the pre-race field. *(Sonnet, high)*
        Check: a tool plays 50 races and prints how often each line is used (no line twice in a race, no event without
        lines); tour + layout check; `help_check.gd`; look at the screenshots.
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
- [ ] **7. Multi-year progression check:** extend the balance tools to 5–8 seasons (ages 14–21) through the game
      loop with health on, and compare the player's and the rivals' curves with real Finnish standards (e.g. a
      talented athlete reaches SM-level youth finals at 15–17 and Kalevan kisat standard around 19–21; most rivals
      plateau). Tune the progression ceiling, maturation and rival growth; also check whether rivals need the health
      model and plan-based training. Also seniors' race-day consistency (GDD 4.3.1 decision 12: the senior final
      finish target). *(Opus)*

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

- **Club (seura) and hometown pages (user, 2026-10-07):** see your own club's information, and the same for every club: general
  info, all its athletes. Likewise your hometown and every hometown: info and all its athletes. Needs clubs / hometowns to
  have athletes (rival cohort per club and town) and the rival profile screen above. Needs a design session first. *(Opus, then Sonnet)*
- **More meets in the calendar (user, 2026-10-07):** add all the national and international meets that can be found, on top of
  the SUL Arvokilpailukalenteri 2027 PDF (https://www.yleisurheilu.fi/wp-content/uploads/2026/05/Arvokilpailukalenteri-2027.pdf)
  already used. Real dates with sources; where unknown, realistic estimates marked `estimated`. Also fills in more `main` meets
  for the season model (GDD 4.8). Research + data task. *(Sonnet)*
- [x] **In-game help per menu (user, 2026-10-07; built 2026-10-07, GDD 5 "Help"):** not a full tutorial: every screen / tab (Overview, Training, Calendar, Rankings, Report,
  day editor, race screen, season plan later) gets a "?" / "How this works" button that opens a short help panel for that screen only,
  when the player wants it. The game is deep (training, health, form, periodization), so the help text explains each concept in plain
  words. Help texts live in `data/help.json` (one entry per screen, with sections), shown by one shared `HelpPanel` (phone: bottom sheet,
  PC: side panel, 44 px, no hover). Each new feature step adds its help entry; a small "new" dot on the "?" could mark unread help.
  Best started right after step 6e (season UI) so the big screens exist; the entries for the existing tabs can be written earlier. *(Opus for the text outline, then Sonnet)*
  **Done:** 13 screen entries + 9 topics, `HelpButton` / `HelpPanel` / `HelpOverlay`, `tools/help_check.gd`; 6f added `season_offer`,
  `return_block` and the topic `easing_back_in` (now 15 screens + 10 topics).
- **Track visuals (user, 2026-10-07):** the user is starting to dislike how the track looks in the main menu and in the races (the
  drawn stadium / hall track). Worth a look later: get reference images of real tracks first (CLAUDE.md: realism, no guessing), then
  redraw. Could go together with M3 (stadium view). *(Opus for the look, then Sonnet)*
- **Season best (SB) in the race field (user, 2026-10-07):** the pre-race "THE FIELD" list on the race screen (`race_screen.gd`
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
- **Warm-up and cool-down around a race (user, 2026-10-08), Finnish alkulämmittely / loppulämmittely:** a part before and
  after the race, part of the race day: the player chooses (or the coach plans) the warm-up (length, intensity, drills,
  strides), which sets race-day readiness (a poor warm-up costs a little at the start; an over-long one costs reserve), and
  the cool-down helps recovery (soreness / fatigue) and shows up in the race-day report. Plugs into the day engine
  (`on_day_start` / race day), the health model (injury risk when cold, warm-up as prevention) and Form (GDD 4.8). Needs a design
  session first. *(Opus, then Sonnet)*
- **Pacemakers (jänis) in senior races (user, 2026-10-08):** at senior level (M4+, Kalevan kisat and international meets, Diamond
  League style) some races have a pacemaker who sets a fast first lap(s) and drops out (usually at 400–600 m), changing the race
  shape (the leader runs the target split instead of the field's even pace; the shape mix gets a "paced" shape, GDD 4.3.1).
  The player could be offered the hare's pace, and rivals' personalities react to it. Also fits "pace lights". Designed with
  senior meets. *(Opus)*
- **More athlete photos for the backgrounds (user, 2026-10-08):** now only two photographers' three CC BY-SA photos
  (`assets/backgrounds/`). Find more copyright-free / free-licence (CC0, CC BY, CC BY-SA, Wikimedia Commons, Unsplash / Pexels
  licence terms checked) athlete and track photos, ideally Finnish athletics, with the credits added to the README there and
  to the in-game Credits screen (still missing). No photos of identifiable minors (youth meets) unless the licence and
  privacy allow it; keep `mipmaps/generate=true`. Research + asset task; downloads need the user's OK per file. *(Sonnet)*
- **Training screen with training PBs (user, 2026-10-09):** a dedicated screen for training results and detailed training
  info: gym PBs (squat, deadlift, jumps, medicine-ball throws...), long / easy run PBs (distance, pace, time), interval PBs
  (e.g. 6 x 400 m average, best 200 m / 300 m / 600 m rep), tempo and test sessions, with history and PB marks, per
  season. The numbers come from the athlete's attributes, the session and the day's form / fatigue (so they rise as
  the athlete improves), stored per session type; the Stats tab (above) can link to it. Needs a design session
  first: which results per session in `data/training.json`, how they follow the attributes. *(Opus, then Sonnet)*
- **Venue-specific stadiums (user, 2026-10-09):** a meet in a small Finnish town looks like it is run at Olympiastadion,
  because there is one stadium model. Give venues their own look and size (small town track with a little grandstand,
  a big arena, an indoor hall, Helsinki's Olympiastadion...) from data per venue (`data/competitions.json` venues: stands,
  capacity, colours, lighting, lanes). Get reference photos / specs of the real venues first (CLAUDE.md: realism, no
  guessing); goes with "Track visuals" below and M3. *(Opus for the look, then Sonnet)*
- **Other events in the stadium during your race (user, 2026-10-09, "if at all possible"):** field events running in the
  infield at the same time (jumps, throws, with athletes warming up and attempts happening), so the stadium is alive.
  Fits M3 "simultaneous events"; needs the meet's programme (next item) and the venue models above.
- **Race ceremony: introductions and the start (user, 2026-10-09):** before the start the athletes are introduced (name,
  club, PB / SB, maybe a short line from the commentator), then they walk out and take their places on the track (the
  800 m start in lanes), and "On your marks - set - go" like in real life (Finnish: paikoillenne - valmiina - laukaus),
  with the gun. Goes with R4's commentary and the Race story; a pre-start stage on the race screen between the field
  list and the running stage. *(Opus for the design, then Sonnet)*
- **Whole event card in the Calendar (user, 2026-10-09):** clicking an event shows the full event card, not only our
  800 m: all disciplines and the timetable of the meet (programme per day, rounds and times). Needs the programme
  as data: real timetables for the big meets (SUL / Kalevan kisat pages, source dated), a believable generic programme
  for the small ones (marked `estimated`). Extends "Calendar race details" below. *(Sonnet for the UI, research for the data)*
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

## M4+ — Breadth
- [ ] Other running events (400m–10000m, steeple), then hurdles & sprints, jumps, throws, combined events
- [ ] International circuit, championships, qualification standards
- [ ] Full world simulation, sponsors, media, rivals, nutrition, equipment, doping…
