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
- [ ] **3. Health model:** body-area strain, soreness, injury and illness rolls, catalogue with phases
      (`data/injuries.json`), growth spurt, history, cross-training sessions, detraining when out, rival injuries;
      `training_balance.gd` with 200 athletes, injuries/illness/days lost, careful policy and ramp plan; first tuning
      pass. Headless only. *(Opus)*
- [ ] **4. Health UI:** soreness on Today card + strip markers, diagnosis panel, "sore" stop decision, banned
      sessions + override warnings, scratch / race injured (slower, may worsen), load vs normal and plan risk in
      the Training tab. *(Sonnet)*
- [ ] **5. Balance & playtest:** tune to the GDD 4.6 targets, play through a season on PC and phone, fix rough
      edges, update docs. *(Sonnet; Opus if tuning gets stuck)*

Part 2 (design later, plugs into the step-1 hooks):
- [ ] Coaching (hire, veto)
- [ ] School (grades, exams vs meets, Finnish school calendar)

## Ideas backlog (from the user, 2026-10-06; placement is Claude's proposal, not yet designed)
- **Ctrl+S to save:** tiny. Do it in M2 step 4 (hub UI session): same as the Save button (new snapshot, "Saved ✓" feedback), desktop only. *(Sonnet)*
- **Choose your birth date:** birth date is already an input to `AthleteFactory`. Day + month inside the starting
  birth year is safe (same age class); other years change the start age, eligible meets and the rival cohort, so
  that waits until more age classes exist (M4+). Small character-creation task after step 5. *(Sonnet)*
- **Choice of coaches / coaching groups / coaches per sub-area** (e.g. speed, endurance, strength, mental, physio):
  belongs to M2 part 2 "Coaching". Needs a design session first (Opus); it plugs into the step-1 hooks (`by = "coach"`,
  Accept / Veto in the day editor, coach events). Design it together with School, since both compete for the athlete's time.
- **Profiles for all other athletes + profile pictures:** two stages. (1) After M2 part 1: a rival profile screen
  (tap a name in Rankings or a race field: club, age, PB / season best, results history, scouting-style attribute
  hints) with procedurally drawn avatars (generated in code, never real photos) for the fictional youth rivals.
  Needs rival results history stored. (2) With senior level (M4+): real athletes with data from `data/*.json` and, where a
  properly licensed photo exists (e.g. Wikimedia Commons CC BY-SA, needs the Credits screen), a real photo.
  Youth stay fictional (minors). The player's own avatar can come with stage 1 too.

## M3 — Stadium view
- [ ] 2D stadium during meets: track, crowd, simultaneous events

## M4+ — Breadth
- [ ] Other running events (400m–10000m, steeple), then hurdles & sprints, jumps, throws, combined events
- [ ] International circuit, championships, qualification standards
- [ ] Full world simulation, sponsors, media, rivals, nutrition, equipment, doping…
