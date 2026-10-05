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
- [ ] **2. Week strip & day editor UI:** week strip (PC + phone), day editor (side panel / bottom sheet) on top of the
      `WeekSim` day-change API, Today card, Report day log (`Game.day_log`); update `layout_check.gd` and the
      screenshot tour. *(Sonnet)*
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

## M3 — Stadium view
- [ ] 2D stadium during meets: track, crowd, simultaneous events

## M4+ — Breadth
- [ ] Other running events (400m–10000m, steeple), then hurdles & sprints, jumps, throws, combined events
- [ ] International circuit, championships, qualification standards
- [ ] Full world simulation, sponsors, media, rivals, nutrition, equipment, doping…
