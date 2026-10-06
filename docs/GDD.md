# Game Design Document — Track & Field Career (working title)

Version 0.5 — 2026-10-06 (M2 step 3: health model built, first tuning pass in 4.6). Living document: updated after each design discussion.

## 1. Vision

A **Football Manager-depth, realistic career simulation** of one track and field athlete, from age 14 to retirement.
No arcade minigames. The player makes meaningful **decisions** in training, life and during competitions;
the simulation resolves the outcome.

**The feeling we're after:** being at a real athletics meet. A 2D stadium with the track, the crowd,
and other events happening at the same time around your own event.

## 2. Core decisions (confirmed)

| # | Topic | Decision |
|---|---|---|
| D1 | Genre & depth | Deep, realistic career sim in the style of Football Manager. No minigames. |
| D2 | Competition gameplay | Decisions at suitable points during events, for all events. No dexterity/minigame input. |
| D3 | Presentation | 2D. Pretty, modern, sleek UI. |
| D4 | Platforms | PC and mobile → UI must be responsive and touch-friendly from day one. |
| D5 | Career | Control **one athlete**. |
| D6 | Events | **All** Olympic/standard events. Athlete can switch or add events (e.g. 400m flat → 400m hurdles like Femke Bol). Combined events (decathlon, heptathlon) supported. |
| D7 | Start | Career starts at **age 14**, in a Finnish club. |
| D8 | Realism | Real-world structure is a top priority: real competitions, calendars, records, athletes and venues. |
| D9 | Systems | All of these are wanted (to be designed one by one): training plans, physical attributes & progression, injuries, coaching, sponsors & money, fame & media, nutrition & sleep, equipment, mental side & motivation, rivals, relationships, doping/anti-doping, school/work–life balance. |
| D10 | Time | Both **day-by-day** and **week-by-week** advance options. |
| D11 | Developer | User has no programming experience. Claude writes the code; user runs and tests it in Godot. |
| D12 | Audience | Personal project, not for sale/publishing → real athlete names, clubs, venues and competition names are used freely. All world data still lives in editable data files. |
| D13 | In-event decisions | Event-specific decision points, e.g. 800/1500m: lane/position, follow or lead, kick timing, responding to moves; 100m: preparation, warm-up, start aggressiveness (false-start risk); HJ/PV: entry heights, passes, pole choice, run-up adjustments; throws/LJ: safe vs all-out attempt, run-up adjustment after fouls. |
| D14 | Meet length | Player chooses per meet: quick result or detailed play-through. |
| D15 | Character creation | In-depth: choose main event, allocate points, answer background questions. |
| D16 | Club & hometown | Any Finnish hometown and club can be chosen; real clubs included. |
| D17 | School/work | School is a real system at 14–18 (grades, exams vs competitions); later university/work vs going professional. |
| D18 | Control & coaches | The athlete is in control. Coaches/specialists can be hired; they can make decisions which the athlete can veto. |
| D19 | Career end | Career runs until the player chooses to retire. (Ageing, injuries and money create natural pressure.) |
| D20 | World | Starts from a real-world 2026 snapshot (real athletes, PBs, records, calendar), then fully simulated forward: AI athletes train, improve, decline, retire; new fictional talents appear; records can fall. |
| D21 | Start year | 2026. |
| D22 | First playable version | 800m, Finnish youth career, 1–2 seasons. See `docs/ROADMAP.md`. |
| D23 | Gender | Player chooses male or female athlete; affects age classes (P/T), competitions and rivals. |
| D24 | Attributes | Shown as numbers on a 1–20 scale (Football Manager style). Event groups get their own extra attributes (e.g. throws). Hidden attributes stay hidden. See 4.1. |
| D25 | Training | Start with ready-made sessions placed into days; later a full custom session editor; a hired coach can build plans from focus areas. |
| D26 | 800m decisions | Race plan, break from lanes (100m), halfway split, responding to moves, kick timing, home straight. |
| D27 | Language | English UI for now (text kept translatable for Finnish later). |
| D28 | Visual style | Dark mode, Football Manager-inspired: dense but clean data screens, panels, tables. |

## 3. M1 proposals (Claude's defaults — change anytime)

- **Character creation:** gender → name, hometown, club → main event (800m in M1) → background questions
  (e.g. other sports as a kid, family's sporting background, school ambition) which shape starting attributes and hidden traits →
  allocate a small pool of points.
- **Season (Finnish youth):** indoor season Jan–Mar, outdoor May–Sep; club/regional meets, district championships,
  national age-group championships, team competitions. *Exact competition names, age classes and dates to be verified before building the calendar data.*
- **Time:** week-by-week in M1; day-by-day comes in M2.

## 4. Systems

### 4.1 Athlete model

All visible attributes 1–20. Event groups add their own attributes as events are added.

**Physical (all athletes):** speed, acceleration, speed endurance, aerobic capacity, lactate threshold, running economy,
strength, power (explosiveness), mobility, durability (resistance to training load).

**Body:** height, weight, age, biological maturation stage (early/average/late developer).

**Technical:** running technique, starts. Later per group: hurdling, jumping technique, throwing technique (per implement), pole vault technique, etc.

**Mental:** race tactics, composure (big-race nerves), determination, competitiveness, pain tolerance, consistency, professionalism.

**Hidden (never shown as numbers, only hinted via tests and coach reports):** talent ceiling (potential), trainability,
recovery rate, injury proneness, maturation timing, ambition.

### 4.1.1 Character creation (built)

1. Identity: gender, first/last name (random Finnish name option), hometown, club (hometown clubs listed first). `data/clubs.json` holds 122 real clubs, sourced from SUL's Tähtiseurat list and Finnish Wikipedia's athletics-club category. The original 11 were confirmed by the user, and Vammalan seudun Voima was added at the user's request. Every club's town is also selectable as a hometown.
2. Main event (all events shown; only 800 m playable in M1).
3. Background questions (`data/background_questions.json`): previous sport, who got you into athletics, family background, where you train (saved as `training_base`, e.g. indoor hall vs outdoor-only track, for the training system), physical development (sets maturation: early/average/late), handling pressure, school level. Each answer adjusts visible and hidden attributes. The user asked for a wide range of answers, including weak starting points. Example: "Never really exercised" gives low physical stats but very high trainability.
4. 12 attribute points, max +3 per attribute.
5. Summary → career starts on 2 Nov 2026 (start of the Finnish training year), athlete born Jan–Oct 2012 (age 14).

Starting levels: physical 4–7, technical 3–6, mental 5–9 before background effects; potential 13–18 (hidden).

### 4.2 Training & progression (first version built)

Decisions (user, 2026-10-05): attributes shown as whole numbers with green/red **trend arrows** (FM style, no decimals);
the **club coach gives a starter plan** that the player can edit; the **plan repeats every week** until changed.

- **Plan:** Mon–Sun, up to 2 ready-made sessions per day, empty day = rest. Sessions in `data/training.json`
  (easy run, long run, fartlek, tempo, 800 m intervals, speed & strides, hill sprints, start practice, club group session,
  strength & core, running drills, mobility, cross-country skiing Dec–Mar).
- **Season & facilities:** outdoor tracks are closed Nov–Apr. Without an indoor hall or a sports class (`training_base` from
  character creation), track sessions are done on roads/snow at 70 % effect.
- **Fatigue (0–100):** simulated day by day. Each day a share of fatigue fades (better with recovery rate and professionalism,
  more on rest days) and session load is added (less with high durability). Fresh < 25, Normal < 45, Tired < 65, Exhausted.
  Above 35 sessions lose effect, down to 10 % at 100.
- **Progression (weekly):** each session gives stimulus to some attributes; gain = rate × diminishing-returns curve
  (minimum effective dose, then flattening) × trainability × headroom to the hidden potential. Untrained physical attributes
  slowly fade; puberty adds natural growth to strength/power/speed (more for late developers).
- **Feedback:** weekly report (sessions, load, fatigue, notes, attributes that moved a whole point) and the plan screen
  shows expected fatigue after a few weeks and a training-focus chart.
- **Tuning** (`tools/training_balance.gd`, 1 year from age 14): coach plan → fatigue ~23, key attributes +1.5–3.5;
  2 easy runs a week → little progress; 12 sessions a week → tired (~58) and only somewhat better in the trained areas.
  Overtraining becomes risky with injuries: new targets in 4.6.

### 4.3 800 m race simulation (first version built)

Decisions (user, 2026-10-05): opponents should be real athletes where possible, otherwise generated. **Claude's
constraint:** youth opponents (14–17) are fictional, because real youth athletes are minors. Their levels are calibrated
on aggregate result standards only, with no individual names or results. Real athletes come in at senior level
(Kalevan kisat, internationals). Detailed races show **runners as dots on the track**.

- **Ability → time:** 800 m ability (1–20) = weighted attributes (`data/races.json`), mapped to an even-effort time by
  gender. Anchors: SUL skill-badge standards for 15-year-olds (boys A/B/C 2:16 / 2:26 / 2:36, girls 2:33 / 2:43 / 2:53),
  SM 14-15 standards, Kalevan kisat standards, world-class seniors. A new 14-year-old is ~2:40 (boys) / ~2:55 (girls).
- **Engine** (`Race`, 0.1 s steps): each runner has a sustainable speed and an anaerobic reserve (metres). Running
  above it drains the reserve, drafting drains it 7 % slower, and an empty reserve means tying up. The race is in lanes
  until the break line after the first bend. Running wide on a bend costs distance, and runners can get boxed in.
  Kick timing depends on the runner type (kickers vs grinders) and tactics.
- **Tracks:** outdoor 400 m with 8 lanes. Indoor 200 m with 6 lanes, tight bends (~2 s slower), 4 laps, and heats of 6
  at indoor championships.
- **Race day form:** consistency sets the day-to-day spread, composure matters at national/international meets, and
  fatigue above 25 costs ability.
- **Player decisions (detailed mode):** pre-race plan (front / pack / kick late), position at the break, bell /
  halfway (push / hold / ease), covering a rival's move, kick timing (200 m or 100 m to go), home straight (go wide /
  wait for the inside). In quick mode the athlete decides by plan and race tactics.
- **Rivals:** a pool of 150 fictional runners (same birth year and gender, Finnish names, real clubs). They train every
  week like the player (toward their own ceiling), keep PBs and fill the fields: local 5–8, district 8–12,
  international youth 9–14. At the national championships, everyone with the standard enters plus ~12 % without it,
  with heats when needed (2 auto qualifiers per heat + fastest losers).
- **Results:** stored on the athlete (results list, PB). They show on the Overview and in the weekly report.
- **Tuning:** `tools/race_balance.gd` (median times hit the anchors within ~1 s).

### 4.4 Season calendar (first version built)

Decisions (user, 2026-10-05): big meets use **real dates**; small local/district meets get **believable estimated dates**
at real venues (marked `estimated` in `data/competitions.json`); the **player enters meets, the coach suggests** (★).

- **Age classes:** M/N + age in the competition year (born 2012 → M15/N15 in 2027). SUL now uses M/N for youth classes too.
- **Season 2026–27** (sources: SUL Arvokilpailukalenteri 2026 and preliminary 2027, SM-tulosrajat 2026, kilpailukalenteri.fi,
  Vammalan seudun Voima's competition list): indoor local meets Dec–Feb, district indoor finale, **Nuorten SM-hallit M/N14-15
  13–14.2.2027 Lappeenranta**, **Tampere Junior Indoor Games 12–14.3.**, outdoor local meets from mid-May, **Youth Athletics
  Games 17–20.6. Lahti**, Pohjola Seuracup district rounds (June/Aug), Lajikarnevaalit 3–4.7., district youth championships,
  **Nuorten SM M/N14-15 6–8.8.2027 Kauhava**, SM-maastot 23.10. Lahti (XC, not playable yet). Senior events (Kalevan kisat Pori,
  Ruotsi-ottelu Stockholm, World Championships Beijing) are shown but not enterable.
- **Qualifying standards (SM 14-15, 2026 values):** 800 m M15 2:21.00, N15 2:35.00, M14 2:28.00, N14 2:36.00. Max 3 events,
  max 1 without the standard, so a pure 800 m runner can always enter.
- **Later seasons** repeat the list 52 weeks later as estimates (national venues "TBA") until real data is added.
- **Races** replace that day's training, add fatigue and train race-related attributes (`race_session` in the data).
  Results come with the race simulation (4.3).

### 4.5 Day-by-day mode (M2, designed 2026-10-05)

Decisions (user, 2026-10-05): **two buttons, no mode switch**; day changes apply to **this week only**; each day has an
**intensity** setting (Easy / Normal / Hard).

- **Time controls:** the hub has **Next day** (plays one day) and **Play week** (plays the rest of the week to Sunday
  night). Play week stops early when something needs the player: a race day, a new injury or a strong warning sign,
  and later coach/school events (see 4.7, "stop events"). Weeks always run Mon–Sun, so the weekly plan and report keep working.
- **Weekly plan = template.** It repeats every week and is edited in the Training tab, as in M1.
- **Day changes (this week only):** any not-yet-played day of the current week can be changed: swap, skip or add a
  session (max 2 per day), make it a rest day, or set intensity. Intensity changes load and training effect (numbers
  in `data/health.json`, see 4.6). Changes work in both styles of play: edit the days, then press Play week.
- **Fixed:** played days, future weeks (they come from the template), entered races. On race day the player can
  **scratch** (not start).
- **Simulation:** `Game.date` is the real current day. The current week (`WeekSim`) lives between days and is saved.
  `WeekSim` gets a single-day step; `Game.advance_day()` plays one day, `Game.advance_week()` plays until Sunday or
  the next stop event. **Fatigue and health change daily; attribute progression is still applied once a week**
  (Sunday night), so the M1 training balance stays valid. Rivals still train weekly. Race flow is unchanged: Next day
  on a race day opens the race screen, and the race completes that day.
- **Hub UI:** a **week strip** under the header on PC and phone (7 day cells: date, session markers, race badge;
  played days dimmed with a fatigue dot; today highlighted). Tapping a day opens the **day editor** (side panel on
  PC, bottom sheet on phone, 44 px controls). On a phone the cells are ~62 px wide and show day letter, date and markers.
  Overview starts with a **Today** card (today's sessions, how you feel, warning signs, next race). The Report tab
  shows this week day by day plus last week's summary. Header shows the real date; phone buttons read "Day" / "Week".
- **Save/load:** save version 2 stores the date, the in-progress week (played days, this week's changes, stimulus so
  far, notes, fatigue stats) and the health state. Autosave after every played day. Version-1 saves load fine:
  they're always on a Monday with no week in progress, so new fields start empty.
- **Built (step 2, 2026-10-06):** the week strip, day editor, Today card and Report tab as described above. Details
  chosen while building: strip markers are coloured by intensity (blue Easy, grey Normal, red Hard); a changed day shows
  a small accent dot (also after it was played); the day editor shows the day's load next to the weekly plan's, who
  changed it, and "Back to plan"; unavailable sessions stay in the picker, greyed out with the reason in their name;
  the Today card replaces Overview's old Condition and Next race blocks; the Report tab also shows last week's days;
  warning signs ("None." for now) and scratching a race are left as marked spots for step 4.
- **Built (step 1, 2026-10-05):** engine, day changes, events, day log, save v2, Next day / Play week and a simple
  stop-event panel. Details chosen while building: intensity Easy = ×0.7 load / ×0.8 effect, Hard = ×1.3 load /
  ×1.15 effect (first values, tuned in step 5); a race reached with Play week continues the week after the race
  (as in M1), one reached with Next day completes just the race day; a stop event raised after a day's training shows
  that night, before the next day is played; the day log and events keep the last 4 weeks.

### 4.6 Injuries & health (M2, designed 2026-10-05)

Decisions (user, 2026-10-05): **minor problems can be trained/raced through with a warning, serious injuries and fever
are blocked**; risk is shown through **body signs + "load vs normal" + a Low/Moderate/High plan risk word** (no exact
percentages); **illnesses are included now**. Everything else below is Claude's proposal, accepted by the user.

**Data:** `data/health.json` (body areas, rates, thresholds, intensity multipliers, illness rates, rival injury chance)
and `data/injuries.json` (catalogue). Sessions in `data/training.json` get a `strain` per body area and an optional
acute-risk value. No injury numbers in scripts.

**How injuries happen (body-area strain model):**
- Six body areas: shins, feet, knees, heels/Achilles, hamstrings, calves. Each has a hidden **strain** value.
- Each session adds strain to its areas. Strain fades daily (bone slowly, muscle faster; faster on rest days and with
  recovery rate). Extra strain from fatigue, Hard intensity, hard surfaces (off-track winter road running) and **load
  spikes**: the body adapts to its last ~4 weeks of load (acute vs chronic load), so gradual build-ups are safe and
  sudden jumps are not. Durability, recovery rate and professionalism protect; hidden **injury proneness** multiplies
  everything (~×0.6–1.8).
- Strain shows as **soreness** per area (none / a bit sore / sore / painful). Daily injury chance is near zero below
  "a bit sore" and rises steeply above it; ~15 % of injuries come with only a slight warning.
- **Acute bad luck** per session: ankle sprains (trail fartlek, icy winter roads), hamstring/calf strains (speed work,
  races; more when tired).
- **Growth spurt:** a growth-spurt age from gender + maturation (early/average/late) makes knees and heels more
  vulnerable around it (an average-maturing boy is in it at 14).
- **History:** a past injury raises the same area's risk for ~6 months.
- **Illness:** daily chance higher Nov–Mar, when tired and in the days after a race; lower with professionalism.

**Catalogue (youth runners; time ranges real-world, actual length drawn inside the range):**

| Tier | Examples | Time | Allowed |
|---|---|---|---|
| Niggle | shin splints (MTSS), Osgood-Schlatter flare, Sever's (growth), patellofemoral pain, calf/hamstring tightness | 1–4 wk | train with limits |
| Injury | hamstring/calf strain gr. 1–2, ankle sprain, tibial/metatarsal stress reaction, Achilles tendinopathy (16+), ITB syndrome (15+) | 1–8 wk | no running, then easy only |
| Serious | stress fracture (tibia, metatarsal), hamstring tear gr. 2–3 | 6–16 wk | no running; cross-training when allowed |
| Illness | cold 3–7 days, flu/fever 7–14 days | days | cold: easy training; fever: none |

- Which injury: by strain level (moderate → niggle, very high → stress reaction), age, gender (girls: higher bone-stress
  risk, later explained by nutrition) and growth phase. **Training through can escalate** (shin splints → stress
  reaction → stress fracture).
- Each injury has **phases** in the data (e.g. stress reaction: no running 4–6 wk → easy only 1–2 wk → full).

**While injured:**
- The day editor greys out banned sessions and says why. New **cross-training** sessions: aqua jogging, stationary
  bike, swimming, gym/core (aqua jogging keeps the most aerobic fitness).
- Override: niggles, colds and minor-injury limits can be ignored after a clear warning (more strain, escalation risk).
  Serious injuries and fever lock banned sessions and races.
- **Racing** with a niggle or cold is allowed: slower, and the problem may get worse.
- Fitness fades through the normal detraining (no stimulus = slow loss) plus a stronger loss after ~10 days with no
  training. **No permanent attribute damage**: the cost is lost time and recurrence risk. Coming back too fast is
  itself a load spike, so a gradual return matters.
- **Rivals** get a simple weekly chance to be out for a few weeks (they miss training and races).

**Warning signs & UI (no hover-only info, 44 px targets):**
- Today card: soreness per area in words + colour, tap for the cause and what helps. Week strip: warning marker on sore days.
- Training tab: "load vs your normal" (%) and plan risk (Low / Moderate / High).
- Play week **stops** the first time an area turns "sore": keep going / take it easy today / rest day (on the night
  before a race: race as planned / scratch from the race, since a race day can't be made easier; step 5).
- New injury: **diagnosis panel** (name, plain explanation, expected time range, what's allowed).
- Injury proneness stays hidden; after repeated injuries a hint ("you seem to pick up knocks easily").

**Balance targets** (`tools/training_balance.gd`, 200 athletes per plan, 1 year from age 14; adds a "careful" policy
= take it easy when sore, and a "ramp" plan = build up to the hard plan over 8 weeks):

| Plan | Injuries/yr | Serious | Progress |
|---|---|---|---|
| Coach plan | ~0.5–1 (mostly niggles) | < 5 % | as in M1 |
| Lazy | ~0 | ~0 | little |
| Hard, warnings ignored | 3+ | > 40 % | **below the coach plan** |
| Hard, careful | ~1–1.5 | ~10 % | above the coach plan |
| Ramp to hard | clearly below "hard, ignored" | | ~ the same as hard, careful (reworded in step 5: it was "best") |
| Illness (all plans) | 2–3 colds/yr, mostly winter | | |

Rule of thumb: training harder pays off only if you listen to your body.

**Built (step 3, 2026-10-06, headless):** `HealthSystem` with the data above; the health UI is step 4. Details
decided while building (all numbers in `data/health.json` / `data/injuries.json`):
- **Strain & soreness:** soreness levels at strain 30 / 50 / 70 (a bit sore / sore / painful; step 5 moved them to
  34 / 52 / 70, see "Tuned (step 5)"). Daily keep: bone 0.875,
  tendon 0.87, muscle 0.8 (minus recovery rate / professionalism, more fade on rest days). Hard intensity ×1.35
  strain, Easy ×0.6. Tired legs up to ×1.25, off-track winter sessions ×1.3 on shins/feet/knees, durability ×1.3–0.7,
  growth spurt up to ×1.5 on knees and heels (boys peak 14.0, girls 12.0, ±1.2 years by maturation), past injury up
  to ×1.3 for 6 months.
- **Adaptation (how "the body adapts to its last ~4 weeks" works):** besides the acute:chronic spike (above 1.2 adds
  strain, up to ×1.8), the body has a **capacity** that follows the chronic load slowly (about 4 weeks to catch up, up
  to 2.5× the coach plan's load): strain added is divided by it. So a gradual build-up is safe, a sudden jump isn't,
  and after weeks out (capacity drops) going straight back to full training is itself a big risk. Without this the
  hard plan was permanently 3× the coach plan's strain and every target was out of reach.
- **Risk curve:** overuse risk per area doubles every 9 strain points (0.24 %/day at "sore"), zero below 20, fading in
  up to 30; × injury proneness 0.6–1.8, girls ×1.15 on bone. Injury picked from the catalogue by strain (niggles from
  20, injuries from 50, serious from 75). One injury per area at a time, several areas can be hurt at once.
- **Locks & overrides:** niggles, colds and the later "easy running" phase of injuries can be trained through;
  serious injuries (all phases), the first phase of injuries (no running) and fever are locked. A locked athlete is
  withdrawn from that day's race automatically (the player's own scratch button is step 4). Training through: +2 days
  per day (not for illness) and an escalation chance of 30 %/day × (area strain / 50)² (kept between ×0.25 and ×3), racing on it 20 %.
- **Restrictions:** presets limits / easy running / no running / no impact / easy day / rest; banned sessions are
  swapped for their first allowed `instead` session (e.g. 800 m intervals → aqua jogging), as day changes "by injury"
  from today to Sunday, and put into a new week before its Monday.
- **Catalogue additions:** sore foot (plantar fascia), tight Achilles, and separate acute "pulled hamstring/calf".
  Achilles tendinopathy (16+) and ITB syndrome (15+) as in the table, so heel problems of 14–15-year-olds don't escalate.
- **Illness:** 0.52 %/day × month (Jan 2.0 … Jul 0.3), × tiredness (up to ×1.7), ×1.8 for 3 days after a race, × professionalism 1.2–0.8; 88 % colds, 12 % flu.
- **Other:** "sore" stop event at most once per area per 14 days; extra detraining 0.01/day after 10 days in a row
  without any training; rivals 0.6 %/week chance to be out 2–6 weeks (≈2 % of rivals out at any time); plan risk =
  expected overuse injuries in the next 4 weeks of the plan at average proneness: Low < 0.1 ≤ Moderate < 0.18 ≤ High.
  **Running detraining** (user decision 2026-10-06, after the first tuning pass): after 10 days in a row without a
  running session or race, speed endurance −0.01, running economy −0.006, lactate threshold −0.005 and speed −0.005
  per day, even when cross-training (pool running and the bike keep the aerobic engine, not running-specific fitness).
  "Load vs your normal" can be huge right after a layoff (normal ≈ 0): the UI should cap it (e.g. "over 300 %").

**First tuning pass** (`tools/training_balance.gd`, 200 athletes per row, 1 year from 14, random backgrounds, half
girls, coach-recommended meets entered; neutral = follows limits but keeps going when sore, careful = Easy when sore and
rest when painful, ignore = keeps going and trains through every unlocked limit). M1 coach plan without health: 800 m
ability +1.18.

| Row | Injuries/yr | Niggle / injury / serious | Days injured (no running) | Illness/yr (Nov–Mar) | 800 m ability | Target met? |
|---|---|---|---|---|---|---|
| Coach | 0.67 | 84 / 15 / 0 % | 10 (3) | 2.2 (71 %) | +1.18 | yes (as M1) |
| Coach, careful | 0.69 | 86 / 13 / 0 % | 10 (2) | 2.2 | +1.18 | (careful hardly matters: rarely "sore") |
| Lazy | 0.07 | (bad luck only) | 1 (2) | 2.2 | +0.37 | yes |
| Hard, warnings ignored | 5.3 | 43 / 12 / 44 % | 270 (173) | 2.7 | +1.03 | yes (3+, > 40 % serious, below coach) |
| Hard, neutral | 3.4 | 76 / 21 / 2 % | 55 (20) | 2.5 | +1.58 | (no target) |
| Hard, careful | 1.58 | 78 / 21 / 0 % | 24 (6) | 2.9 | +1.65 | ~1–1.5 nearly; **~10 % serious not reached (0 %)**; progress above coach yes |
| Ramp to hard | 2.5 | 73 / 23 / 3 % | 42 (17) | 2.8 | +1.58 | clearly below "ignored" yes; **best progress no (tie)** |
| Ramp, careful | 1.52 | 80 / 19 / 0 % | 22 (5) | 2.7 | +1.63 | |

Warnings: on the hard plans 70–90 % of overuse injuries came after the area had been "sore" (the rest after "a bit
sore"); on the coach plan, which rarely makes anyone sore, most niggles came after only "a bit sore" (59 %) or none.
Plan risk at week 12: coach Low 95 %; hard plans split between Low (already adapted) and High (not yet / after a layoff).

- **M1 unchanged:** with the health model off, all M1 fingerprints are bit-for-bit identical (part 2 of the tool);
  with it on, the coach plan's progress is the same as M1 (+1.18).
- **Open (for step 5; settled or handed to the user in "Tuned (step 5)" below):** (1) Hard-careful gets no serious injuries (careful players back off before bone stress gets
  bad), target was ~10 %: accept, or add rare "silent" stress reactions. (2) Ramp ties with hard-careful on progress
  (+1.63 vs +1.65): the ramp loses a little training while building up, careful-hard gets away with the jump because
  it backs off when sore. The ramp is clearly safer for a player who doesn't listen (2.5 vs 3.4 injuries/yr). (3) The
  coach plan's niggles mostly come with only a slight warning ("a bit sore"), so step 4 should show "a bit sore"
  clearly on the Today card. (Solved: ignoring warnings no longer out-progresses the coach plan, thanks to running
  detraining.)
**Built (step 4, 2026-10-06, the health UI; the model's numbers are untouched):** everything under "Warning signs &
UI" above, on PC and phone, with 44 px targets and no hover-only information. Details chosen while building:
- **Today card:** the top part (today, how you feel, next race) is still the button for today's editor. Under it,
  *Warning signs*: one row per area that is at least a bit sore (amber "A bit sore", orange "Sore", red "Painful"),
  tap a row for the one-line advice, why it is sore (recent training, a load spike, tired legs, growth spurt, an old
  injury) and what helps; "No soreness" otherwise, plus a line that "a bit sore" is the early warning (open point 3 of
  step 3). Next to it *Injury & illness*: tier, phase, what's allowed now, "expected back" (about N days / weeks and a
  date; it moves later when you train through it), and whether it is locked or "may get worse"; tap for the plain
  explanation.
- **Week strip:** a round "!" on days you were sore (colour = how sore; played days from the day log, today from the
  body now) and a "+" on days an injury or illness limited (colour = tier: niggle amber, injury orange, serious red,
  illness blue). The Overview's help line explains both.
- **Diagnosis and "sore" panels:** the same look (caption with the date, heading, explanation, a card with a coloured
  edge). Diagnosis: tier and area, the explanation, expected time, allowed now, racing (can't / about X % slower and it
  may get worse), and "Locked" or "You can train through it, but it may get worse"; one OK button. "Sore": the sore
  areas as the same tappable rows (opened when only one) and the three choices as big buttons with their detail
  ("Take it easy today" is the highlighted one). The panel scrolls on a short window.
- **Day editor:** soreness today and an *Injury limits* box (the reasons from the model); banned sessions are greyed out
  in the pickers as "(not with Shin splints)"; intensity buttons above what the injury allows are disabled; a day that
  only your injury changed has no "Back to plan" (it would be put straight back). *Train through it…* asks once more
  with the consequences (more strain, +2 days of recovery per day, what it can turn into) and then uses `override_day`;
  after that the banned sessions can be picked again and are marked "(against limits)". Not offered when locked.
  A trained-through day shows *Follow the limits again* (`HealthSystem.cancel_override`), which puts the limits back.
- **Race day:** the day editor and the race screen warn when you'd race injured (slower by the injury's share, may get
  worse) or can't race (locked: you are withdrawn when the day starts, as before), and both have *Scratch from this
  race* (asks once more) = `Game.scratch_race`: the entry is withdrawn, a race screen that was waiting is dropped, the day
  becomes a training day with the injury limits, and an event "Scratched: …" is logged. On the race screen scratching is
  only offered in the first round.
- **Training tab:** "Body strain" under the plan summary: *Load vs your normal* (the plan's week against the average
  week of your last four, capped at "over 300 %", with a sentence: lighter / about usual / a step up above 120 % / a big
  jump above 160 %) and *Plan risk* Low / Moderate / High (green / amber / red) with a sentence, and a line for the
  current week with its day changes. The section works for any plan passed in (`HealthUI.plan_section(plan, week)`), so
  season periodization (roadmap step 6) can show a phase's plan. Every plan edit (and Coach's plan / Clear week, and
  entering or withdrawing from a race) re-applies the injury limits to this week and redraws the week strip.
- **Report tab:** each played day lists its injuries/illnesses and sore areas; last week's facts have a health line; the
  proneness hint ("You seem to pick up knocks easily") is shown at the top after 3 injuries within a year.
- **Ctrl+S** saves, like the Save button ("Saved ✓"), desktop only.
- Display texts and thresholds live in `data/health.json` under `ui` (load cap and the % where the words change, the
  soreness advice lines); no model numbers were changed.

**Tuned (step 5, 2026-10-06, balance & playtest).** One number set changed: the soreness levels in
`data/health.json` went from 30 / 50 / 70 to **34 / 52 / 70** (nothing else in the model, no script numbers). Why: the
Today card showed "a bit sore" on 42 % of days for an athlete on the *recommended* coach plan (2–4 body areas, for
months), so the early warning meant nothing. With 34 it is 18 % of days on the coach plan (hard plans: about 53 %,
down from about 76 %), and the injury numbers did not move (the hazard curve is untouched; only what the player is
shown changed). Price: more coach-plan niggles arrive with no soreness before them (no warning in the week before:
36 % → 67 %; they are almost all niggles at the lowest risk); on the hard plans it is 14 % → 24 % for careful players.

Final numbers (`tools/training_balance.gd`, 200 athletes per row, 1 year from age 14, half girls, coach-recommended
meets entered; neutral = follows limits but keeps going when sore; careful = Easy when sore, rest when painful;
ignore = trains through everything that isn't locked). Ability = 800 m ability gain (± standard error); M1 without
health: coach +1.18, so the coach plan is unchanged. Days = per year, with an injury / with no running allowed.
"Sore days" = days with at least one area at least a bit sore. Stops = stop events per year (sore warnings +
diagnoses, colds included), and in how many of the 52 weeks Play week stops at least once.

| Row | Injuries/yr | Niggle / injury / serious | Days (no running) | Colds/yr | Ability | Sore days | Stops (weeks) | Target |
|---|---|---|---|---|---|---|---|---|
| Coach | 0.67 | 84 / 15 / 0 % | 10 (3) | 2.2 | +1.18 ±0.01 | 18 % | 3.3 (3.1) | met |
| Coach, careful | 0.69 | 84 / 15 / 0 % | 10 (3) | 2.3 | +1.18 | 18 % | 3.3 (3.1) | met |
| Lazy | 0.07 | 30 / 69 / 0 % | 1 (2) | 2.2 | +0.37 | 0 % | 2.2 (2.2) | met |
| Hard, warnings ignored | 5.4 | 44 / 13 / 42 % | 270 (173) | 2.7 | +1.03 ±0.03 | 38 % | 21.9 (13.0) | met (3+, > 40 %, below coach) |
| Hard, neutral | 3.4 | 76 / 21 / 2 % | 55 (20) | 2.5 | +1.58 ±0.02 | 54 % | 14.0 (10.0) | (no target) |
| Hard, careful | 1.56 | 81 / 17 / 0 % | 23 (5) | 2.8 | +1.64 ±0.01 | 53 % | 9.7 (8.6) | injuries ≈ (target 1–1.5); **serious 0 % vs ~10 %: open, below**; progress above coach met |
| Ramp, neutral | 2.5 | 72 / 23 / 4 % | 42 (18) | 2.8 | +1.58 ±0.02 | 52 % | 10.7 (8.2) | clearly below "ignored" met |
| Ramp, careful | 1.44 | 81 / 18 / 0 % | 21 (5) | 2.8 | +1.63 ±0.01 | 52 % | 8.4 (7.8) | |

- **M1 unchanged:** part 2 of the tool, "fingerprints identical to part 1: YES", and the fingerprints are the same
  numbers as before step 4 (coach 215.999957139 / 13.751549603 / 1203.029795007 …).
- **Colds** (coach row, per athlete by month, Nov … Oct): 0.24 0.33 0.40 0.38 0.27 | 0.11 0.12 0.04 0.09 0.07 0.07 0.14 =
  2.26 a year, 71 % of them Nov–Mar, about 9 % of illnesses are flu. As designed.
- **Days lost:** a coach-plan athlete has an injury or niggle on about 10 days a year (3 with no running) and is ill
  on 12; a careful hard athlete 23 (5); a player who ignores everything 270 (173, almost half the year).
- **Boys vs girls** (400 athletes, 200 each; the first 100-athlete run seemed to show a big gap, but it was the
  particular athletes: the same seeds are used in every run): coach 0.71 boys / 0.66 girls a year; hard neutral 3.65 /
  2.88. The boys' extra at 14 is the growth spurt (knees 0.79 vs 0.27 and heels 0.45 vs 0.28 a year; boys peak at 14,
  girls at 12); shins and feet are equal, and the share of serious injuries is the same (2 % / 2 %; 4 % / 2 % at 16).
  Girls' extra bone risk (×1.15, and ×1.5 on the stress-reaction weights) is visible only on the hard-ignore row
  (47 % serious vs 38 % for boys).
- **Ages 14 / 15 / 16** (only the birth date moves; the attributes stay a 14-year-old's, so this shows age and
  growth effects, not real older athletes): coach 0.68 / 0.79 / 0.67, hard neutral 3.26 / 3.31 / 3.22, hard careful
  1.56 / 1.59 / 1.50 (100 athletes at 15, so ±0.1). No age effect beyond noise; what changes is the kind: boys'
  knee and heel growth niggles (coach plan: 0.36 per boy at 14, 0.18 at 16) fade, Achilles tendinopathy (16+) and ITB
  syndrome (15+) become possible.
- **Play week stops:** 2.8–3.3 weeks a year on the coach plan, 8–10 on the hard plans when you listen to your body,
  13 of 52 for someone who ignores everything. Not annoying (a stop is a real decision or a diagnosis); no change
  needed. The "sore" warning stays at most once per area per 14 days.

Decisions on the open points:
1. **Hard-careful serious injuries: not decided, waiting for the user.** Today a careful player never gets a serious
   injury (0 %): the stress reaction needs strain 50 and is locked, so it can't be trained through into a fracture,
   and a careful player backs off before strain reaches 75. Options (100 athletes per row, with the new soreness
   levels; serious share of injuries, injuries/yr, progress):

   | Option | Hard careful | Ramp careful | Hard neutral | Hard ignore | Coach |
   |---|---|---|---|---|---|
   | A. Accept (now: stress fractures from strain 75, weight 0.5) | 0 %, 1.56, +1.64 | 0 %, 1.44 | 2 %, 3.4 | 42 % | 0 % |
   | B1. Data only: from strain 40, weight 1.0 | 5 %, 1.41, +1.65 | 4 % | 10 % | 42 % | 1 % |
   | B2. Data only: from strain 40, weight 1.5 | 7 %, 1.42, +1.65 | 5 % | 12 % | 42 % | 1 % |
   | B3. Data only: from strain 38, weight 1.5 | 8 %, 1.45, +1.64 | 8 % | 14 % | 43 % | 1 % |

   **Recommendation: B3** (the two stress-fracture entries in `data/injuries.json`: `min_strain` 75 → 38, `weight`
   0.5 → 1.5). No new mechanism, injuries/yr and progress hardly change, and the "hard, careful" strategy is no longer
   free: about one careful athlete in nine loses 6–12 weeks to a bone injury a year. It is "silent" in practice,
   because on a hard plan an athlete is "a bit sore" about half of the days anyway, but the player does see the
   soreness (strain 38–52 is "a bit sore" to "sore"). A truly warning-free injury would need a new mechanism (a
   small daily chance independent of soreness): not recommended, it would hit the coach plan too. Not applied; say
   "apply B3" (or B1 / B2 / A) and it is a two-number change plus a re-run of the table.
2. **Ramp vs hard-careful progress: reword the target, no model change.** Ramp-careful +1.63 vs hard-careful +1.64
   (standard error 0.01–0.02 each), and ramp-neutral +1.58 vs hard-neutral +1.58: a tie. The ramp's value is safety
   (neutral: 2.5 vs 3.4 injuries a year, 42 vs 55 days injured, 4 % vs 2 % serious; ignoring: it cannot save you).
   Progress does not reward the ramp because an injury costs little progress in this model (you swap to pool
   running, so a careful hard athlete loses only 5 days of running a year); making the ramp "best" would mean making
   layoffs hurt much more, which is a design question for step 7 (multi-year progression), not a tuning tweak.
3. Today card shows "a bit sore" clearly: done in step 4, and now it appears only when it means something (above).

Playtest (step 5): a whole season played through the real hub buttons on PC size (coach plan, careful boy: 102 button
presses, 4 stop events = 3 injuries and a cold, no sore stops, stops in 4 weeks) and on phone size (hard plan, girl who
keeps going when sore: 81 presses, 9 stop events = 5 sore + 4 diagnoses, stops in 7 weeks), plus the screenshot tour
and the layout check on both sizes (105 "no overflow", none overflowing). No errors. Timings (a laptop with an Intel
HD 520): the hub redraws in 105–120 ms on average and 316–388 ms at most after Next day / Play week (a whole week of
days is simulated in that), 50–60 ms (at most 90) after answering an event; autosave 18–20 ms and about 100 KB; `plan_risk` 6.4 ms per
call (28 simulated days, measured while other processes were running), `load_vs_normal` 0.3 ms: nothing slow.
Saves: the user's own version-2 saves (up to Feb 2029, from before and after the health model) and a version-1 save
load and play on 21 days; a save in the middle of an injury continues bit for bit (`health_check.gd`); autosave runs
after every played day; Ctrl+S shows "Saved ✓".

Fixed in step 5:
- **A button that did nothing:** the "sore" warning on the night before a race offered "Take it easy today" and "Rest
  day", but a race day can't be edited, so nothing happened. Now it says "Today is a race day (name)" and offers
  "Race as planned" / "Scratch from the race" (`Game.scratch_race`). Check: `health_check.gd` "sore warning before a race".
- The soreness thresholds (above).
- On a phone the Today card shows "Injury & illness" before "Warning signs" when there is an injury (it used to sit
  below up to six sore rows).

Suggestions for later (not done): (a) a **return plan** after a layoff: after two weeks out, the unchanged coach
plan reads "load 168 % of normal, plan risk High" and the player has to rebuild by hand: the coach (Coaching) or the
periodization step could propose gradual return weeks. (b) **Injuries cost little progress** (see point 2); decide in
step 7 whether long layoffs should cost more aerobic base. (c) If the Today card still feels busy on a hard plan
(about 1.5 sore areas on an average day), show the three worst areas and fold the rest into "+2 more". (d) The
diagnosis panel is dated the evening it happened ("FRI 13 NOV") while the header already shows the next day; "last
night" may read better. (e) `tools/health_check.gd` prints ALL CHECKS PASSED even when a script error aborts one check
function (found while editing: read stderr); each check could report that it finished.

### 4.7 Daily events & hooks (M2 foundation, designed 2026-10-05)

Decisions (user, 2026-10-05): **no Inbox tab yet**: events show on the Today card and in the Report's day log (revisit
an FM-style Inbox when coaching arrives). The **Finnish school calendar comes with the school system**; for now days
are only weekday/weekend.

- **System slots in the day loop:** every day runs *day start → training/race → health → day end*, plus *week end*.
  Systems (Health now; Coach, School later) hook into these steps and save their own state in the save file.
- **Events:** one format for everything that needs attention: date, source (health / coach / school), title, text,
  optional choices. A **stop event** pauses Play week and shows a decision panel (same style as race decisions);
  the source system handles the answer. First users: new injury, first "sore" warning. Later: coach changes with
  Accept / Veto, school exam vs meet clashes.
- **Day changes remember who made them** (player / coach / injury restriction), so the day editor can show "changed
  by coach" with Veto (D18).
- **Day log:** what was actually done each day (sessions, intensity, fatigue, soreness, events). Used by the Report
  tab now, and later by the coach and school.
- **Day type:** weekday / weekend now; school days, exams and holidays later.

### Other systems (to be designed)

- Nutrition, sleep
- Mental side, motivation, relationships
- Coaching
- Money, sponsors, equipment
- Fame, media, rivals
- School / work–life balance
- Doping / anti-doping
- World simulation (other athletes, records, rankings)

## 5. Presentation

- 2D stadium view during meets: track, crowd, simultaneous events.
- Modern, sleek, responsive UI (desktop + mobile).
- **Idea (user, for later):** the plain dark UI feels generic. Use athlete photos as screen backgrounds, darkened and/or blurred behind the panels so they never hurt readability. Could vary per screen or event (e.g. an 800 m pack on the career hub). Needs a set of good, properly licensed photos (e.g. Wikimedia Commons) or the user's own. **Status (UI polish pass, 2026-10-05):** the backdrop system is built (blurred + darkened photo behind translucent panels, per screen, falls back to a gradient). A deliberately harsh test image stayed readable, but loose text (tabs, captions) is the weak spot, so photos should be calm and dark. Photos added (2026-10-05, user-approved): two Finnish athletes at Kalevan Kisat 2018 and Lahti Stadium, all CC BY-SA 4.0 from Wikimedia Commons; a Credits screen is still to do. See `assets/backgrounds/README.md`.

## 6. Data

- Real-world database: athletes, records, competitions, venues, qualification standards.
- Stored as editable data files (so it can be corrected and updated without touching code).
