# Game Design Document — Track & Field Career (working title)

Version 0.6 — 2026-10-06 (M2 steps 3–5: health model built and tuned, 4.6; step 6 season periodization designed, 4.8). Living document: updated after each design discussion.

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
(From M2 step 6 this is the "one repeating week" mode; the default becomes a season plan with phases, see 4.8.)

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
- **Added in M2 step 6b** (same SUL calendar): Nuorten SM-hallit M/N17-19-22 26–28.2. Turku, Nuorten SM M/N19-22 13–15.8. Helsinki,
  and watch-only SM-hallit (Jyväskylä), EM-hallit (Valencia) and EYOF; meets carry a `main` tag for their season's main
  championship (GDD 4.8).
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
1. **Hard-careful serious injuries: DECIDED 2026-10-06: option B3 applied** (stress fractures `min_strain` 38, `weight` 1.5; expect careful ≈ 8 % serious, neutral ≈ 14 %, coach ≈ 1 %, per the option table; the final-table rows above are from before it). Today a careful player never gets a serious
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
periodization step could propose gradual return weeks. (Designed in 4.8: the club coach's "return block".) (b) **Injuries cost little progress** (see point 2); decide in
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

### 4.8 Season periodization (M2 step 6, designed 2026-10-06)

Decisions (user, 2026-10-06): phases are **tied to target meets**; the player can keep **one repeating week** instead
(a switch in the Training tab); the player edits **one week per phase and moves phase edges by whole weeks** (plus the
this-week day changes of 4.5); **lighter weeks come from an automatic rule**; the club coach offers **three season plans
by load: Steady / Balanced / Ambitious**, shown as cards with a ★ pick, offered once at career start and again each
autumn; a **return block after a layoff** is offered already in step 6; a small **Form** mechanism (about ±1.5 % of race
time); the coach proposes the target meets, **up to 3 targets a season**, each with a 10-day **taper**; an **easy day
before every race** in the race phases; balance targets as in "Balance" below. The rest is Claude's proposal, accepted
with these answers.

**Why it matters in this model (read before tuning).** Progression has diminishing returns per attribute *per week*
(4.2), so spreading the stimulus every week is always best: a "base first, specific later" order earns nothing by
itself. Periodization pays off through (1) **safety**: lighter weeks and gradual build-ups let the body's capacity
(4.6) follow, so more total load is possible at the same risk; (2) **race-day Form** (below): freshness from a taper and
sharpness from recent race-specific work; (3) **structure**: the coach's year, with the right sessions in the right
months (track closed Nov–Apr, skiing Dec–Mar). The weekly progression model itself is **not** changed in step 6.

**Week plan (one storage for both features).** A week plan is
`{"days": [7 lists of session ids], "intensity": [7 × "easy" / "normal" / "hard"]}` (helpers in a new
`scripts/core/week_plan.gd`: make, `of(x)` accepts the old plain Array = all Normal, days, intensity, equals).
`WeekSim` gets `plan_intensity`; `intensity(d)` = the day change, else `plan_intensity[d]` (was always Normal), and "a
change equal to the plan is dropped" compares against it. With every intensity Normal everything is bit for bit as
before. `HealthSystem.plan_risk`, `load_vs_normal`, `Training.preview / expected_fatigue / simulate_week` and
`HealthUI.plan_section` take a week plan (an old Array still works through `WeekPlan.of`).

**Season plan** (`scripts/core/season_plan.gd`, `Game.season`, replaces `Game.training_plan`):
- `mode`: `"repeat"` (one repeating week = M1 behaviour, `repeat_week`) or `"phases"`.
- `season`: the start year (the season runs Nov–Oct as in Rankings; its plan starts on the **Monday nearest to
  1 November** (user, 2026-10-07; the first wording "the week that contains 1 Nov" gave 26 Oct 2026, before the
  career starts): Mon 2 Nov 2026, Mon 1 Nov 2027, Mon 30 Oct 2028).
- `variant`: `"steady"` / `"balanced"` / `"ambitious"` (the coach plan it came from); `targets`: up to 3 meet keys.
- `phases`: `{type, week (a week plan), edited, lighter (on/off), ramp_weeks}` in skeleton order; `shifts`: the
  player's moves of each phase edge in whole weeks (relative to the anchors, so a moved target still works).
- `return_block`: `{start, weeks}` or empty.
- `week_for(monday)` → `{days, intensity, why (per day, "" or a reason), phase, phase_week, phase_weeks, kind}` with
  kind `normal` / `lighter` / `taper` / `return`. A pure function of the season plan, the entries and the date: no
  dice, cheap. `Game.current_week()` sets the week's plan from it every time (it now sets `_week.plan` from the
  repeating plan), so the strip, the day editor, "Back to plan" and the injury limits (4.6) all keep working
  unchanged on top of it.
- Save version 3 stores `season`; a version-2 / version-1 save becomes repeat mode with its `training_plan` and all
  days Normal (it plays exactly as before), and the Training tab offers the coach's season plans.

**Built (step 6a, 2026-10-06):** week plan storage, repeat mode only. As designed above, plus these details:
- `WeekPlan` also has `coach()`, `empty()` and `copy_of()`. `WeekSim` keeps the days in `plan` (unchanged, so code that
  reads `week.plan[d]` still works) and the intensities in `plan_intensity`. Unknown or missing intensities count as Normal.
- `SeasonPlan.week_for(monday)` returns the plan itself, not a copy (the Training tab edits it in place; later steps
  return a freshly built week plan with `why` and the rest of the fields listed above). `Game.current_week()` hands it to
  the week through `WeekSim.set_plan`, which also drops any day change that has become equal to the plan (e.g. you made a
  Tuesday Easy for this week, then set Tuesday to Easy in the plan).
- Injury limits and "train through it" give the *plan's* intensity back when they end (before: always Normal), so a
  Hard day in the plan stays Hard after a cold. A cold on a Hard day still caps it at Easy while it lasts.
- `HealthSystem.load_vs_normal` takes a `WeekSim` or a week plan (a plan = this week with nothing played).
- Training tab: Easy / Normal / Hard buttons per day (a segmented row on PC, a full-width row under the pickers on a
  phone; disabled on a rest day, where intensity changes nothing). A line under the intro lists the multipliers from
  `data/health.json`; the day's load and the summary (weekly load, expected fatigue, body strain) include them.
- Save version 3 stores `season = {mode, repeat_week}`; saves of version 1–2 load as repeat mode with every day Normal.
- Verified: `training_balance.gd` parts 1–2 fingerprints unchanged (coach 215.999957139 / 13.751549603 /
  1203.029795007) and a new part 2b shows plan-level intensity gives the same fingerprints as day changes; all 4 of the
  user's version-2 saves load and play. Measured with `health_check` for one athlete after 28 coach days: load vs normal
  Easy 60 % / Normal 100 % / Hard 135 % (the Hard strain multiplier); plan risk of a middle plan Low at Normal and High at
  Hard, of the hard plan Low at Easy and High at Normal; coach plan stays Low even all-Hard.

**Built (step 6b, 2026-10-07):** the season model, headless. As designed above, plus these details decided while building:
- **Data:** `data/periodization.json` has the phases (name, text, colour, race phase, lighter, start rule, `omit_without`),
  the lighter / ramp / easy-day / taper rules with their `why` texts, the fallback anchor dates and the Balanced
  templates and `ramp_weeks` (2 for every phase, 1 for the transition). `Data.periodization`. No numbers in scripts.
- **A record per season** (`SeasonPlan.seasons`, year → `{variant, targets (null = the coach's), shifts, phases}`), not one set of
  fields: a season without a record is the coach's unedited plan, built on demand, so every week of every season has a plan
  (the check covers 2026–27 and 2027–28) and step 6f's rollover only has to create records. `phases[id]` holds only what the
  player changed (`week`, `lighter`, `ramp_weeks`); "edited" is worked out (differs from the coach's). Layout and default
  targets are cached per season and dropped when a move or a target changes.
- **Season start:** the Monday nearest to 1 Nov (see above). **Phase starts** = anchor week + `weeks` from the data + the
  player's shift; every phase keeps ≥ 1 week (`set_shift` cuts a move back to what fits, ±4 at most, the first phase can't
  move). A phase of a kind with no meet is left out and its neighbours still count from `anchor_fallback` dates in the data
  (general base then runs to the week spring base would start, pre-competition to where the race season would have ended).
- **Anchors:** the first indoor / outdoor meet in the season's target list; if the player took it off, the coach's pick
  (so the phases don't move, only the taper goes); no meet at all: the fallback date and the phase is left out.
- **Main meets (data, source: SUL Arvokilpailukalenteri 2027, preliminary 12.5.2026):** `main` tags on SM-hallit 14-15
  (13–14.2.2027 Lappeenranta), **SM-hallit M/N17-19-22 (26–28.2.2027 Turku, new in the data, `ages` [16, 22]: my reading
  is that the "17" class is the 16–17-year-olds, as the outdoor "M/N16-17" is, so a 16-year-old has an indoor main meet
  too; correct the ages if SUL says otherwise)**, Nuorten SM 14-15 (Kauhava), 16-17 (Oulu), and the new 19-22 (13–15.8.2027
  Helsinki). Without a fitting `main` meet the highest-level ★ meet of that season part (Tampere Junior Indoor Games, Youth
  Athletics Games for a 13-year-old). Added from the same calendar as watch-only meets: senior SM-hallit (20–21.2. Jyväskylä),
  EM-hallit (4–7.3. Valencia), EYOF M/N17 (24.7.–1.8. Lignano Sabbiadoro). Later seasons repeat 52 weeks later as before.
- **Targets:** new careers **enter the two default targets** (user decision) and withdrawing or scratching a target takes it off
  the list (`Game.withdraw → SeasonPlan.on_withdraw`). The taper counts back from the target's date whether or not it is
  entered. `Game.start_career(athlete, mode = "phases")`; tools pass `"repeat"` (no meets entered, the old coach week).
- **`week_for(monday, entries = null)`** (entries default to `Game.entries`) returns `{days, intensity, why, phase, phase_week,
  phase_weeks, kind, target}`; `target` is the meet a taper counts down to. Ramp week *k* of `ramp_weeks` *n*: the first
  `round((k+1) × 7 / n)` days are the phase's, the rest the previous phase's week (for a season's first phase the last
  phase of the season before; for the career's first phase the coach's starter week, which is the general-base week, so a
  new career starts exactly as before). A lighter week steps every day one level down, never in a taper week. The easy day
  before a race counts races in the same week only. Taper: nearest coming target within 10 days; the kept session is the
  one tagged speed, then hard (`taper.keep_tags`), else the first; the target day and other race days are left alone; each
  rule writes its `why` only when it changed something and several reasons are joined with " · ". Cost ≈ 0.4 ms per call.
- **For 6c–6f:** `layout / targets / set_targets / add_target / remove_target / set_shift / edit_phase (the phase's week to
  edit in place) / reset_phase / is_edited / set_lighter / set_ramp_weeks / phase_base / switch_to_repeat`, `SeasonPlan.phase_type(id)`
  (name, text, colour), `SeasonPlan.season_start / year_of / week_no`.
- **Training tab (the only UI change):** in phases mode it shows "Season plan": the phase and week, this week's days with their
  reasons, the plan summary (load vs your normal, risk) and a button **Use one repeating week instead** (asks once more;
  one-way until the season editor in 6e) that turns this phase's week into the repeating week.
- **Save:** version 3 kept; `season` also stores `birth_year`, `event`, `first_season` and the season records; a version-3 save
  from 6a and version-1/2 saves load as repeat mode.
- **Verified:** `tools/season_plan_check.gd` (new, 100+ checks: every Monday of 2026–27 and 2027–28, the 2026–27 dates of the
  table below, lighter weeks 4 and 8 of general and spring base, ramp, easy day before races only in race phases, taper
  −10…−1 at both targets, moving edges and targets, the fallbacks, save/load bit for bit, 104 days played through the game
  loop across a taper and the race); `training_balance.gd -- 0` fingerprints unchanged in repeat mode (215.999957139 /
  13.751549603 / 1203.029795007 …); `day_engine_check` and `health_check` pass; all 4 of the user's version-2 saves load and
  play (`tools/saves_check.gd`); tour and layout check clean at all sizes.

**Built (step 6c, 2026-10-07):** race-day form. As designed in "Form" below, plus these details decided while building:
- **Files:** `data/form.json` (all numbers, the words with their colours and texts, the UI strings), `FormSystem` (`scripts/core/form_system.gd`,
  GameSystem id `form`, hooks `on_health` only, switch `FormSystem.enabled`; "Form.enabled" in the plan is this), `FormUI`
  (`scripts/ui/form_ui.gd`), `sharp` on the sessions in `training.json` and on `race_session` in `competitions.json`.
  `RaceDay.form` holds the race's form share; time × (1 + slowdown − form), identical to before when form is 0.
- **State:** one number, `sharpness`. A new career or an old save starts at `sharpness.start` (= `neutral`); the state is written to the
  save only after the first played day (an old save loads with an empty state, and the form-less save is byte for byte as before).
  Each day: `sharpness × 0.93 + Σ sharp × the day's intensity effect` (a race day adds the race's own 15), kept within 0–100.
- **Race-morning form** uses the sharpness after yesterday and the fatigue the athlete has when the day starts; the race itself then adds
  its sharpness. The Today card shows the same number as "if you raced today" (the form of a race-free day is never used).
- **Tuned numbers (user decisions 2026-10-07: the word on the Today card means "if you raced today"; tapping gives plain reasons, no %;
  before a race the word is on the day editor's race card and the race screen, not on the week strip):**
  - `neutral` = **39.5** (calibration below). The sharpness term reaches its +0.75 % cap at **1.5 × neutral** (`sharp_term.cap_at`), not 2 ×:
    the GDD's "about 2 × 30 = 60" is 1.5 × 39.5, and with the cap at 2 × neutral (79) no plan could ever reach it.
  - **800 m intervals sharp 20** (GDD first guess 12). The old coach week has no intervals, so `neutral` is unaffected; with 12 even the
    SM-hallit taper only reached "Sharp". Other values as in the GDD (race 15, club session 7, speed & strides 4, fartlek 4, tempo 3, hill sprints 3, start practice 2).
  - Freshness as in the GDD (+0.75 % at fatigue ≤ 8, 0 at 20; a version that fell to 0 at 25, where "Tired" starts, was tried and gives every
    coach-week race a freshness bonus, which only pushes `neutral` up to 53). Word limits as in the GDD: Peaking ≥ +1.0, Sharp ≥ +0.4,
    OK > −0.3 (stored as −0.003), Rusty below; Tired (fatigue over 25) wins over all.
- **Calibration** (`tools/form_check.gd`, the old repeating coach week, one athlete, a race at every eligible Saturday meet Dec 2026–Aug 2027,
  11 races): average sharpness at the start line 37.9, average fatigue 20.1, **mean form +0.000 %** with `neutral` 39.5 (the tool also prints
  the neutral that would give exactly 0 and fails if the data is more than 0.1 % off). The Race fatigue rule and the race anchors in 4.3 are untouched
  (`race_balance.gd` runs the same code, `race.gd` / `race_performance.gd` unchanged).
- **Season plan (phases mode, Balanced, same athlete):** Sat 9 Jan (end of general base) OK −0.16 %; **Sat 13 Feb, SM-hallit (taper): Peaking +1.05 %**
  (sharpness 49, fatigue 9); **Sat 24 Apr, the last day of spring base: Rusty −0.34 %** (sharpness 21); Sat 15 May: Sharp +0.58 %; 31 May: Sharp +1.00 %;
  **Fri 6 Aug, Nuorten SM (taper): Sharp +0.82 %**. Finding for 6d: in the race season the week is so heavy (midweek fatigue ~35) that even the taper
  (days −3 Normal intervals, −1 an easy run) leaves fatigue near 19 on race morning, so the August target does not reach Peaking; the check asserts
  "Sharp or better" there. A lighter day −1 (mobility) or a lighter race-season template would fix it.
- **UI:** Today card: a "RACE FORM" row under the top part (word in its colour + one line; tap = what it means and what builds it; 44 px;
  stacked on a phone). Race day: a "RACE FORM" card in the day editor (today's race only) and on the race screen next to "YOU". Nothing is shown when
  the form model is off. The tour has `14d_form_peaking / rusty / tired` (rusty with its explanation open).
- **Save/load:** `to_dict` = `{started, sharpness}`; 60 days after a load give exactly the same sharpness and race form as without saving.
- **Verified:** `form_check.gd` ALL CHECKS PASSED (formula, calibration, season words, Tired, applied to the race time, save/load, switched off);
  `training_balance.gd -- 0` fingerprints identical (215.999957139 / 13.751549603 / 1203.029795007); `day_engine_check`, `health_check`,
  `season_plan_check` pass; tour at 1600×900 and 390×844 looked at, `layout_check` at all sizes: no OVERFLOW.

**Built (step 6d, 2026-10-07):** the coach's three plans and their balance. User decisions this session: **youth limits** for the ★ (with
durability ≤ 6 / ≥ 12 two in three new 14-year-olds were pointed to Steady and nobody to Ambitious); Ambitious gets its extra load from
**doubles and one or two Hard days, always keeping a full rest day**; the race-season fix = **a rest day in the week + mobility only on
the day before a target**; the player sees **one line** in the Training tab ("Coach's plan: Balanced ★" + the plan's sentence). Details:
- **Data** (`data/periodization.json`): `variants.steady / balanced / ambitious` (name, text, `ramp_weeks`, a week per phase), `coach_pick`
  (the ★ limits), the taper's new band key `sessions` (day −1 = `["mobility"]`, Easy). No numbers in scripts.
- **The ★ rule** (`SeasonPlan.coach_pick(athlete, today, health = null)`): durability and professionalism *as shown* (rounded); Steady with
  durability ≤ **4** or **2+** injuries in 12 months; Ambitious with durability ≥ **9**, professionalism ≥ **11** and no injury in 6 months;
  otherwise Balanced. Injuries = tiers `injury` and `serious` (niggles and illnesses don't count: 2 niggles shouldn't make the coach cautious);
  a month = 365/12 days. 200 random new 14-year-olds (no creation points): Steady 9 %, Balanced 91 %, Ambitious 0 % (Ambitious needs points
  spent on durability and professionalism). `Game.start_career(athlete, mode, variant = "")`: "" = the ★ pick; a new career starts on it.
- **A season's plan:** `SeasonPlan.variant(year)`; a season with no record keeps the plan of the latest season before it (until 6f's autumn
  offer makes records). `set_variant(year, id)` drops that season's phase weeks (the new plan replaces them) but keeps targets and moved edges;
  `edited_phases(year)` counts the changed phases for 6e/6f's "This replaces your changes to N phases".
- **Final templates** (Normal unless marked; transition is the same in all three plans: mobility Mon, easy run (Easy) Wed, Fri, Sun):

  | Balanced | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
  |---|---|---|---|---|---|---|---|
  | General base (= the coach week) | easy run + drills | club session | strength + speed & strides | fartlek | mobility | long run | rest |
  | Indoor specific | easy run + drills (E) | 800 m intervals | strength + speed & strides | club session | easy run + mobility (E) | long run | rest |
  | Spring base | easy run + drills (E) | tempo run | strength + hill sprints | fartlek | easy run + speed & strides (E) | long run | rest |
  | Pre-competition | easy run + drills (E) | 800 m intervals | strength + speed & strides | fartlek | easy run + mobility (E) | club session | rest |
  | Race season | **rest** | 800 m intervals | strength + speed & strides | fartlek + drills | mobility | club session | long run (E) |
  | Autumn general | easy run + drills (E) | club session | strength + speed & strides | fartlek | mobility | long run | rest |

  **Steady** = Balanced's sessions (autumn without speed & strides, race-season Thursday an easy run + drills) with **most days Easy**: in the
  base phases, indoor specific and autumn Mon, Wed, Thu and Sat are Easy (Tuesday's key session and Friday Normal); in pre-competition all but
  Tuesday and Saturday's club session; in the race season Wed, Thu and Sun. **Ambitious** (doubles, Hard marked H):
  general base easy run + drills / club + strength / tempo + speed & strides / fartlek H / easy run + drills / long run + strength / rest;
  indoor specific easy + drills / intervals + strength / tempo + speed & strides / club H + strength / easy run + mobility / long run + drills /
  rest; spring base easy + drills / tempo H + strength / easy run + hill sprints / fartlek H / easy run + speed & strides / long run + strength /
  rest; pre-competition easy + drills / intervals + strength / tempo + speed & strides / fartlek H / easy run + drills / club + strength / rest;
  race season rest / intervals + strength / tempo + speed & strides / fartlek + drills / easy run + mobility / club / long run + strength;
  autumn easy + drills / club + strength / easy run + speed & strides / fartlek / mobility / long run + strength / rest.
  **Ramp weeks:** Steady and Balanced 3 into indoor specific and autumn general, 2 elsewhere; Ambitious 3 into the base phases (general,
  spring, autumn), 2 elsewhere; transition 1.
- **Planned load** (session load × intensity, averaged over 2026–27): Steady 63 a week (**85 %** of Balanced), Balanced 74, Ambitious 107
  (**144 %**). Per phase Balanced: general 70 (lighter weeks included), indoor 77, spring 82, pre-competition 89, race season 83, transition 18, autumn 63.
- **What tuning found** (`training_balance.gd` part 4, about 15 template versions tried, 80–200 athletes each): (1) the transition and the
  autumn weeks cost Balanced ≈ 0.10 of progress against the repeating week, and 25 % more load in the other phases bought only +0.05–0.10;
  (2) the periodized plans' extra injuries come from **phase changes**, not load: the first weeks of 800 m intervals (indoor specific +0.07–0.10
  injuries a year against the repeating week, pre-competition +0.06) and the return after the transition (autumn +0.05); the lighter weeks
  *save* injuries (general base 0.11 vs 0.16); (3) **Easy days are the efficient way to train** (Easy cuts strain to 0.6 but keeps 0.8 of the
  effect): a Steady of Balanced's sessions mostly at Easy beat a Steady with sessions taken out (+1.02 vs +0.88–0.90 at the same load and
  injuries), and Easy easy-run days gave Balanced the same progress at slightly fewer injuries (0.78 vs 0.81, within noise) and a lower plan
  risk ("ever High" 14 % vs 27 %); (4) an active transition (3 easy
  runs instead of 2) and 3 ramp weeks into indoor specific and autumn took the plan risk after the break from 70 % to 24 % "Moderate".
- **Final numbers** (200 athletes per row, the 2026–27 season from 14, health and form on, targets + coach-recommended meets entered;
  careful in brackets; form = average race-day form, SB at target = the target was the fastest indoor / outdoor race by expected time):

  | Row | Injuries/yr | Serious | Ability ±0.01 | Fatigue | Form at targets (Peaking) | Other races | SB at target in / out | Plan risk L/M/H (ever High) |
  |---|---|---|---|---|---|---|---|---|
  | Repeating coach week | 0.67 (0.69) | 2 % | +1.17 | 25 | −0.03 % (0 %; half "Tired") | −0.09 % | 35 % / 0 % | 97/2/1 % (5 %) |
  | Steady | 0.67 (0.60) | 5 % | +1.02 (+1.03) | 21 | +1.32 % (88 %) | +0.55 % | 94 % / 64 % | 90/9/2 % (11 %) |
  | Balanced | 0.78 (0.77) | 3 % | +1.17 | 25 | +1.30 % (88 %) | +0.52 % | 92 % / 73 % | 89/9/2 % (14 %) |
  | Ambitious | 1.23 (0.99) | 9 % (4 %) | +1.48 (+1.49) | 36 | +1.22 % (86 %) | +0.50 % | 97 % / 84 % | 78/15/6 % (33 %) |

  Fatigue by phase (average / highest): Balanced general base 23/34, indoor 26/40, spring 29/38, pre-competition 31/41, race season 28/42
  (the repeating week 24–26 / 34–38); Ambitious 36–45 on average with peaks 52–64 (indoor specific). Plan risk reads Moderate at the start of
  indoor specific (Steady 60 %, Balanced 45 %, Ambitious 38 % of samples there: the intervals come in) and Ambitious also in general base
  (29 %) and autumn (50 %). For 6e: the cards' "highest plan risk" should be the typical week's (Low / Low / Moderate), not the worst sample.
- **Against the targets:** Balanced injuries ≤ 0.8 **met** (0.78), form at targets **met** (+1.30 %, Peaking 88 %; target +0.8…1.3), season best
  at a target **met** (92 % / 73 % vs 35 % / 0 %); Balanced progress **not met** (+1.17 = the repeating week, target +1.25–1.35); Steady progress
  **met** (+1.02), Steady injuries **not met** (0.60–0.67, target ≈ 0.4); Ambitious careful progress **met** (+1.49, target +1.5–1.6), its
  injuries **lower** than designed (0.99, target 1.3–1.6), neutral above careful (1.23) as designed. **Decided (user, 2026-10-07): option (a)
  for all three, accepted as measured** (a model change for progress can come up again in step 7). The options were:
  1. *Balanced progress:* (a) accept: in this model periodization pays in race-day form (+1.3 % ≈ 1.8 s at 2:20) and safety, not in weekly
     progress, as "Why it matters" says (recommended); (b) a heavier Balanced: tried, +1.21 at 0.87–0.97 injuries and plan risk "ever High" 32 %;
     (c) a model change in step 7, e.g. an adaptation bonus after lighter weeks and tapers, or a transition that costs less fitness.
  2. *Steady injuries:* the model's floor for a 14-year-old with the same race calendar (growth-spurt niggles, bad luck, races) is ≈ 0.6 at 80 %
     of the load; ≈ 0.4 needs far less training (2 easy runs a week = 0.07). (a) accept: Steady still has the freshest legs, the lowest fatigue
     and the best form at the targets (recommended); (b) fewer races for Steady (the coach's race list); (c) change the target.
  3. *Ambitious injuries below target:* accept (recommended; ignoring the warnings would still cost far more), or make it heavier.
- **The 6c issues:** the race-season week now has a rest day (Monday) and the taper's last day is mobility only: **Nuorten SM Fri 6 Aug reads
  Peaking +1.45 %** (fatigue 9; was Sharp +0.82 % at fatigue 19), SM-hallit Peaking +1.36 %. Spring base: average fatigue 29, highest 38 (as
  the repeating week's 38), a Saturday long-run morning ≈ 34; with Easy speed & strides on Fridays a race at the end of spring base reads
  Tired / −0.19 % (sharpness 29) instead of Rusty / −0.34 % (21): `form_check` now asserts "a poor day, below 0 %".
- **Tools:** `training_balance.gd` part 4 (`-- <n> part4`, or row names `week`, `steady`, `balanced careful` …; any variant id in the data can be
  tried by name; prints the planned loads, then per row injuries, progress, fatigue, form at targets / other races, SB at target, plan risk,
  and per phase fatigue, plan risk, injuries and progress; ~5 min per row of 200 on the dev PC, run 4 rows at a time). Races are not run: each
  race's expected time (ability, injury slowdown, form, the race's fatigue and composure rules, no dice) decides the season best.
  `season_plan_check.gd` new sections "the coach's three plans", "the coach's ★ pick", "a season's plan"; tools that start in phases mode
  ask for "balanced" explicitly. The tour has `22a0_training_season_plan_top` (the new line).
- **Verified:** `training_balance.gd -- 0` fingerprints identical (215.999957139 / 13.751549603 / 1203.029795007); `season_plan_check`,
  `form_check`, `day_engine_check`, `health_check` ALL CHECKS PASSED, stderr clean; tour at 1600×900 and 390×844 looked at; `layout_check`
  at all 5 sizes: no OVERFLOW.

**Built (step 6e, 2026-10-07):** the season UI. As designed in "UI" below, plus these details. User decisions this session: **one
session, two commits** (Training tab first, then strip / day editor / Report / Calendar); the **phase editor is a full page in the
Training tab** on PC and phone ("◀ Season plan" goes back); **target meets are marked ◆** (★ keeps meaning "the coach suggests" /
"the coach's pick"); the plan cards sit behind **one line + "Change plan"**. (The two-commit split was a fallback in case the session
ran long; everything was finished, so it went in as one commit.)
- **Files:** `SeasonView` (`scripts/ui/season_view.gd`, the Training tab in season mode), `SeasonBar` (`season_bar.gd`, the drawn Nov–Oct
  bar), `PhaseEditor` (`phase_editor.gd`), `SeasonUI` (`season_ui.gd`: strip caption, phase dates and states, plan-card load, the cached
  lead-in), `PlanUI` (`plan_ui.gd`: the day rows, session pickers, plan summary and days list, moved out of the hub so the repeating week and
  the phase editor share them). New model functions: `SeasonPlan.switch_to_phases / plan_year / target_candidates / can_target / phase_dates /
  lighter_on / ramp_of`, `Game.use_season_plan()`, `HealthSystem.projected(until)`, and an optional lead-in argument on `plan_risk`,
  `load_vs_normal` and `HealthUI.plan_section(plan, week, lead_in)`.
- **Mode switch:** two toggles at the top of the Training tab, both ways. To the repeating week: this phase's week becomes the repeating week
  (as in 6b) and the season records stay. Back to the season plan: the records are used as they were; a career that never had a season plan (an
  old save) gets the coach's ★ plan for the season it is in and its coming targets are entered where allowed.
- **Coach's plans:** the line "Balanced ★: …" + **Change plan** opens three `ChoiceCard`s (a row on PC, stacked on a phone): name, ★ on the coach's
  pick, "in use", **weekly load about N** (the season's phase templates × intensity, weighted by the phases' weeks; the athlete's own session load,
  so the numbers are lower than 6d's 63 / 74 / 107 for a low-durability athlete), **typical risk** (a word stored in the data per plan, `card.risk`:
  Low / Low / Moderate as measured in 6d, not computed from today's body) and **focus** (`card.focus`). Choosing a plan with edited phases shows
  "This replaces your changes to N phases … Your targets and moved edges stay" with **Use X** / **Keep my plan**.
- **The season:** PC = `SeasonBar` (phases in their data colours with names where they fit, a dark dot = your changes, a thin strip under it with
  the lighter weeks blue and taper weeks orange, ◆ + name on each target, month ticks, a white line for today; tap a phase = its editor) **plus** the
  phases as tappable cards in two columns (the bar has no room for short phases' names); phone = the cards stacked (colour edge, name, dates,
  weeks, "Now: week N", "Over", "your changes"; past phases dimmed).
- **Targets:** each target with its date, its role ("sets the indoor / outdoor phases" or "taper only"), entered or not (with **Enter** when allowed)
  and **Remove**; **Add a target meet…** lists this season's meets from today that fit the athlete's event and age class (not watch-only); at 3 the
  list is replaced by "3 targets is the most". Adding a target enters the meet when allowed. Removing doesn't withdraw the entry.
- **Phase editor:** title + dates + "now: week N" / "starts in N weeks" / "over"; "Your changes" box with **Back to coach's** (asks once more); the
  phase's week (day rows as the repeating week: two pickers, load, Easy / Normal / Hard); **Lighter weeks** On / Off (any phase); **Easing in**
  N weeks with Fewer / More (1–4, at most the phase's length; the coach's number shown); **When it runs**: start and end with ◀ Earlier / Later ▶ (the
  end moves the next phase's start; the season's first start and last end can't move; **an edge in this week or before can't move**, so the
  running week never changes under the player; a move `set_shift` cuts back shows "Can't move it further…"). A phase that is over is read-only.
  Summary: the plan summary for the phase's week (month = the phase's middle) and the body strain: the phase running now from today's body, a
  **future phase after the lead-in** ("Load vs the weeks before", "Risk when it starts").
- **Lead-in:** `HealthSystem.projected(monday)` plays the rest of this week (its day changes and races) and the season plan's weeks up to the phase's
  start on copies (body, athlete with weekly progression; races as races; no dice, no injuries) ≈ 33 ms to spring base from mid-November.
  `SeasonUI.lead_in` caches it until the season plan (other than the opened phase's own edits), the entries, the date or the health day change.
- **Week strip caption** (above the strip, caption style, hidden in repeat mode): "GENERAL BASE · WEEK 3 OF 10 · LIGHTER WEEK", "TAPER: <meet> IN 9
  DAYS" (counted from today), "RACE DAY: <meet>". **Day editor:** a "Season plan" row with the rule's `why` for that day (lighter week, ramp, easy day
  before a race, taper) and "This is your season plan's day"; "Back to plan" already returned to the season plan's day. **Report:** the week report
  stores `plan = {phase, phase_week, phase_weeks, kind, target}` in season mode (`Game._end_week`; nothing in repeat mode, so repeat-mode saves are
  unchanged) and last week's facts show "Season plan: Spring base · week 4 of 10 · lighter week". **Calendar:** in season mode a second button under
  Enter (beside it on a phone): **Make target** / **Target ◆** on meets that can be targets (from today on); at 3 targets a note says to remove one first;
  withdrawing a target takes the target off (as in 6b).
- **Verified:** `season_plan_check` new section "season UI (step 6e)" (switching both ways keeps the records exactly, an old repeat career switched on,
  phase dates contiguous, target candidates, max 3, the report's phase, the lead-in repeatable and leaving the game untouched, all UI pieces build)
  ALL CHECKS PASSED; `form_check`, `day_engine_check`, `health_check` pass, stderr clean; `training_balance.gd -- 0` fingerprints identical
  (215.999957139 / 13.751549603 / 1203.029795007); tour at 1600×900 and 390×844 (new shots `28_…32b_`: plan line, cards, the replace warning, the
  season bar and phase list, targets, phase editor future / now / past and its body strain after the lead-in, a lighter week and a taper week with the
  day editor's reason, the Report's phase line, the Calendar's Target button, the mode switch both ways) looked at; `layout_check` at all 5 sizes
  (new views: cards + warning, phases, phase editor, its strain, the phase running now, lighter and taper weeks, the Report) no OVERFLOW.

**Built (step 6f, 2026-10-07):** the coach's offers, the season rollover, easing back in (the return block), the multi-season
check. User decisions this session (all of Claude's recommendations accepted): **the autumn offer stops Play week** (once a year);
it is **not re-opened**: from the offer day until the season starts the Training tab has a **"NEXT SEASON 2027–28" box** with the
three cards, and without a choice the season starts on **the coach's ★ of that day**; **targets the player set for next season are
kept** (a plan choice only replaces phase weeks) and choosing a plan (or the rollover) **enters the season's targets where allowed**;
easing back in **can be stopped early** ("Stop easing back in…", asks once more: Training tab and day editor), there is no switch to
turn it off ("No thanks" is enough); **any 14+ days without running count** (an illness alone never gets there: flu is at most 14
days with easy running allowed after 4–7); **races in the block stay** (the event lists them, the day before is Easy); the name stays
**"Easing back in"** (the phase ramp keeps "Easing in", the help topic explains both). Claude's defaults, accepted:
- **Files:** `SeasonSystem` (`scripts/core/season_system.gd`, GameSystem id `season`, in `Game.systems`; static `offers_enabled`
  for tools), `SeasonEventPanel` (`scripts/ui/season_event_panel.gd`, the two stop panels), `PlanCards` (`scripts/ui/plan_cards.gd`,
  the three cards + the replace warning, shared by the Training tab and the offer). Data: `data/periodization.json` `offer` and
  `return_block` (rules, numbers, all texts). New model functions: `SeasonPlan.return_block / start_return / stop_return /
  return_day / return_week_on / return_weeks / return_ahead / return_last_day / return_kinds_for / copy`,
  `HealthSystem.running_allowed(k) / weeks_risk(plans) / weeks_expected(plans) / risk_word(expected)` (`plan_risk` = `weeks_risk([plan])`,
  bit for bit as before).
- **The offer:** posted by `Game.start_career` for a career on the ★ (no plan named; tools that name one never get it), and by
  `SeasonSystem.on_day_start` on the Monday 3 weeks before the next season (Mon 11 Oct 2027, Mon 9 Oct 2028, Mon 8 Oct 2029), before
  that day is played, season mode only, once per season. Event `{kind "offer", year, pick, first}`; choices = the three plans (★ first)
  + "later"; any other answer counts as "later". The panel: caption + "?" (`season_offer`), the text with the season's age class and
  the coach's targets, the cards (a row on PC in an 860 px panel, stacked on a phone), **Use <plan>** (the ★ chosen at first) and
  **Decide later in the Training tab**; a season with edited phases shows "This replaces your changes to N phases" first.
- **Rollover:** on the evening before a new season's first Monday (`on_day_end`, so the new week is built from the new record):
  without a choice the season is put on the coach's ★ of that day; its targets are entered where allowed; once per season, never
  the career's first. The new age class needs nothing new: the coach's targets are worked out per season (2027–28: SM-hallit
  M/N17-19-22 and Nuorten SM 16-17; 2028–29 the same, age 17). Old saves load with an empty state (the next autumn offer comes).
- **Easing back in:** `SeasonSystem.on_day_end` offers it on the evening when the athlete has had ≥ 14 days without running (any
  reason), tomorrow an easy run is allowed by the injury limits and tomorrow's plan has a run (or an entered race); once per layoff.
  The event: the weeks (7-day spans from the first day back) with what each means, what comes after ("Then your season plan (Spring
  base) as usual"), **plan risk for the next 4 weeks with and without the block** (from the body now, the days before the first day
  back as rest in both), entered races in the block, Accept / No thanks. The words are coarse: in 4 of 12 layoffs in `season_check`
  both read High; in 3 of them the block cut the expected injuries 2–5 times, in one hardly (a 2-week block after 26 days, then
  straight into indoor-specific intervals). So when both words are the same a line says "much the safer of the two" (block ≤ 0.6 × the full plan, `much_safer` in the data) or, when it isn't, that the weeks after it are still
  a big step (Easy days or Steady help). No numbers are shown.
- **The block's weeks** (data): 14–27 days out first + second; 28–55 first + second + lighter; 56+ first + first + second + lighter.
  *First*: one session a day (a run if there is one), all Easy, hard / speed / plyo / long sessions become an easy run. *Second*: one
  session a day, at most Normal, the first `hard` session of each 7-day span kept (a span can run over a Monday: the week before is
  counted). *Lighter*: every day one step easier. Race days untouched; the day before a race Easy. It replaces the lighter week,
  the easy day before a race and the taper on its days (ramp first, then the block); this week's day changes and the injury limits
  apply on top as always. Works in both modes (`week_for` in repeat mode returns a new plan for a block week, the repeating week
  itself otherwise). `kind` "return" with `return_week` / `return_weeks`; every block day has its `why` ("Easing back in, week 1
  of 3: one easy session").
- **UI:** week strip caption "EASING BACK IN · WEEK 1 OF 3" (only on the block's days; the rest of that week shows the phase); the
  day editor's plan row in both modes ("Season plan" / "Plan") + **Stop easing back in…**; the Training tab's box at the top (both
  modes): caption, sentence, the weeks (past ones dimmed) and Stop; the Report's last-week line ("Plan" in repeat mode). Help:
  new screens `season_offer` and `return_block`, new topic `easing_back_in`; `training_season`, `training_repeat`, `day_editor`,
  topics `easing_in` and `injuries` raised to version 2.
- **Multi-season check** (`tools/season_check.gd`, 50 athletes × 3 seasons, 2 Nov 2026 – 28 Oct 2029, Balanced, health and form on,
  offers answered "balanced", easing back in accepted, neutral policy, ~160 s): the seasons start 2 Nov 2026 / 1 Nov 2027 / 30 Oct
  2028 / 29 Oct 2029, 1092 days each in one season, 29 Feb 2028 played; offers on 2 Nov 2026, 11 Oct 2027, 9 Oct 2028, 8 Oct 2029;
  every rollover makes a Balanced record with the new age class's targets entered; every Monday has a plan with a phase; save /
  load on the Sunday before a new season (3 athletes × 2 boundaries) plays the next 28 days bit for bit; 12 easing-back-in blocks
  (2 / 3 / 4 weeks: 4 / 7 / 1), 221 block days follow their rules. **Per season** (per athlete): injuries 0.70 / 0.78 / 0.54 (serious
  0.08 / 0.04 / 0.00), illnesses 2.1 / 2.5 / 2.5, 800 m ability +1.17 / +1.14 / +1.06 (± 0.02), stops 6.1 / 5.1 / 4.6, blocks 0.14 /
  0.04 / 0.06; running banned 5.2 days a year. No drift: the ability gain falls a little with age as the weekly diminishing returns
  bite (step 7 looks at longer careers), injuries stay in the band.
- **Verified:** `season_check` 2279 checks, `season_plan_check` (new sections "the coach's offers and the season rollover", "easing
  back in"), `form_check`, `day_engine_check`, `health_check`, `help_check` (466 checks: the offer's and the block's "?") ALL CHECKS
  PASSED, stderr clean; `training_balance.gd -- 0` fingerprints identical (215.999957139 / 13.751549603 / 1203.029795007); the user's
  autosave (version 3, season plan) plays 120 days (`saves_check` now accepts a version-3 save in its own mode); `season_playtest.gd`
  with the new plan `season` through the hub on PC (seed 3: 102 presses, 5 diagnoses, 1 sore, both offers) and at 390×844 (seed 8: 88
  presses), no errors, hub redraw ≈ 118 ms on average; tour shots `5b_`–`5c_` (the first offer), `33_`–`33c_` (the autumn offer, the
  replace warning, the Next season box), `34_`–`34e_` (easing back in, its help, the day editor, the Training box, the Report line,
  the next week's strip) at 1600×900 and 390×844; `layout_check` at all 5 sizes (6 new views each) no OVERFLOW, no SQUEEZED.
  Tools that play days: in repeat mode they never get an offer, and every tool that answers stop events answers the new ones
  ("ok" = later / no thanks); `training_balance` part 3–4 count them as stops.

**Phases** (names, texts, colours, rules and templates in a new `data/periodization.json`; first season shown):

| Phase | Anchor rule (whole weeks, Monday-aligned) | 2026–27 | Lighter weeks | Race phase |
|---|---|---|---|---|
| General base | season start → indoor specific | 2 Nov → mid-Jan | every 4th week | no |
| Indoor specific | the 5 weeks up to and including the indoor anchor's week | mid-Jan → SM-hallit 13 Feb | no | yes |
| Spring base | after indoor specific → pre-competition | mid-Feb → end of Apr | every 4th week | no |
| Pre-competition | the 4 weeks before race season | May | no | yes |
| Race season | 10 weeks before the outdoor anchor → 3 weeks after it | end of May → end of Aug | no | yes |
| Transition | 3 weeks after race season | Sep | no | no |
| Autumn general | → season end | Oct | no | no |

- **Anchors** = the indoor and outdoor target, or, with no target of that kind, the season's main championship for the
  athlete's age class (new tag in `data/competitions.json`: `"main": "indoor"` / `"outdoor"`, e.g. SM-hallit 14-15 and
  Nuorten SM 14-15); with none, the highest-level ★ meet of that season part; with none at all, the phase is left out
  and the phase before it lasts longer. Next season's age class (16-17) needs its own main meets in the data (to add
  with sources in step 6b, or the fallback applies; done, see "Built (step 6b)").
- **Edges:** each edge can be moved −4…+4 weeks; every phase keeps at least 1 week. Phases always start on a Monday.

**How a week is built** (`week_for`), in this order; every rule that changes a day writes its `why`:
1. The phase's week plan.
2. **Ramp:** the first `ramp_weeks` weeks of a phase blend in from the previous phase's week, a day at a time (as the
   "ramp" row of `training_balance.gd`). For the very first phase of a career the previous week is today's coach week.
3. **Lighter week:** in phases with lighter weeks, every 4th week of the phase: every day one intensity step down
   (Hard → Normal → Easy). Strip markers turn blue. Can be switched off per phase. Not in a taper.
4. **Easy day before a race:** in race phases, the day before an entered race is Easy (when it is in the same week and
   not a race or rest day): "Easy: race tomorrow".
5. **Taper** (numbers in `data/periodization.json`, counted back from the target's race day): days −10…−4 at most one
   session a day and the long run becomes an easy run; −3 one session at Normal (keeps sharpness); −2 rest; −1 Easy,
   one session. Wins over rules 3–4.
6. **Return block** (below) wins over everything.
Then this week's day changes (player / coach / injury) apply on top, as now.

**Target meets.** The coach proposes the indoor and outdoor main championship. The player can change them or add a
third (max 3 a season) in the Training tab or with a "Target" toggle on a meet in the Calendar. Marking a target enters
the meet when allowed. Withdrawing or scratching removes the target. A target gets the taper; the indoor and outdoor
targets are also the phase anchors (a third target only gets a taper).

**The coach's three plans** (all templates in `data/periodization.json`, per variant and phase; tuned in step 6d):
- **Steady:** about 80 % of Balanced's load. Low risk, slower progress.
- **Balanced:** the club coach's normal. Its general-base week is exactly today's coach week, so a new career starts
  as it does now.
- **Ambitious:** about 140–160 % of Balanced, built up with `ramp_weeks`. Moderate risk; it pays only if you listen to
  your body.
- **The coach's ★** uses only what the player can see: Steady after 2+ injuries in the last 12 months or with
  durability ≤ 6; Ambitious with durability and professionalism ≥ 12 and no injury in 6 months; otherwise Balanced
  (thresholds in the data).
- **Offer:** a new career starts on the ★ plan. On its first day a stop event "Your coach has three plans for the
  season" offers the three plans and "Decide later in the Training tab". Each autumn (3 weeks before the new season)
  the same event comes for next season; if ignored, the ★ plan is used. Choosing a plan replaces the phases, after a
  warning when the player has edited phases ("This replaces your changes to N phases").
- **First Balanced templates** (Normal unless marked; the 6b–6c version, replaced by the tuned templates in "Built (step 6d)" above):

| Phase | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
|---|---|---|---|---|---|---|---|
| General base | easy run + drills | club session | strength + speed & strides | fartlek | mobility | long run | rest |
| Indoor specific | easy run + drills | 800 m intervals | strength | club session | mobility | long run | rest |
| Spring base | easy run + drills | tempo run | strength + hill sprints | fartlek | mobility | long run | rest |
| Pre-competition | easy run + drills | 800 m intervals | strength + speed & strides | fartlek | mobility | club session | rest |
| Race season | easy run | 800 m intervals | strength + speed & strides | easy run + drills | mobility | club session | long run (Easy) |
| Transition | mobility | rest | easy run (Easy) | rest | rest | easy run (Easy) | rest |
| Autumn general | easy run + drills | rest | strength | fartlek | mobility | long run | rest |

**Return block** (the step-5 suggestion "return plan after a layoff"). After 14 or more days in a row without running
(`HealthSystem.days_without_running`), on the first day running is allowed again, the club coach posts a stop event
"Easing back in": Accept / No thanks. Accept sets `return_block` from the next day: 2 weeks after 14–27 days out,
3 after 28–55, 4 after 56+ (data). The block's weeks are worked out from the plan that would apply: return week 1 = at
most one session a day, all Easy, hard and speed sessions replaced by an easy run; week 2 = one session a day at
Normal, one hard session kept; the last week = a lighter week; then the normal plan. It works in both modes. The event
explains the plan risk it avoids ("going straight back to your full plan: High").

**Form** (race day only; switch `Form.enabled`, like `HealthSystem.model_enabled`). A new `FormSystem` (GameSystem
id `form`, no dice) keeps **sharpness** 0–100: each day `sharpness × 0.93 + Σ session sharp × intensity effect`, with a
new `sharp` value per session in `data/training.json` (first values: race 15, 800 m intervals 12, club session 7,
speed & strides 4, fartlek 4, tempo run 3, hill sprints 3, start practice 2). Race-day form, as a share of race time:
- sharpness term: −0.75 % at 0, 0 at `neutral`, +0.75 % at 2 × `neutral` (capped);
- freshness term: +0.75 % at fatigue ≤ 8, falling to 0 at fatigue 20;
- total capped at +1.5 % faster / −1.0 % slower. The existing fatigue rule in `Race` (bonus under 10, slower above 25)
  stays as it is.
- `neutral` is calibrated so that the **old repeating coach plan averages 0** over its races (so the race anchors in
  4.3 stay right); first guess ≈ its steady-state sharpness (~30). Applied like the injury slowdown in
  `RaceDay._player_entrant`: time × (1 + slowdown − form). All numbers in the data, tuned in 6c.
- Shown as a word (no %): **Peaking** (≥ +1.0 %), **Sharp** (+0.4…1.0), **OK**, **Rusty** (≤ −0.3 %, little recent
  race-specific work), and **Tired** when fatigue is over 25. On the Today card (tap = what it means and what builds
  it) and before a race. Rivals have no form (their consistency spread covers good and bad days; step 7 revisits).

**UI.**
- **Training tab:** a switch *Season plan* / *One repeating week*.
  - **Repeat mode:** today's week editor, plus Easy / Normal / Hard per day.
  - **Season mode:**
    - *Coach's plans*: three `ChoiceCard`s with average weekly load, highest plan risk, focus and a sentence; ★ on the
      coach's pick.
    - *Season*: PC = a Nov–Oct bar with coloured phases, ★ targets and a today marker; phone = a list of phases (name,
      dates, weeks, "your changes").
    - *Targets*: change / remove / add, max 3.
  - **Tapping a phase** opens its editor: the same day pickers plus intensity per day, lighter weeks on/off, ramp
    weeks, the edges (◀ ▶ by a week), *Back to coach's*, the plan summary and
    `HealthUI.plan_section(phase week, lead_in)`.
  - **Future phases:** the lead-in plays the season plan on copies (no dice) from today up to the phase's start, so the
    risk shown is the real risk of *switching into* that phase. Cost ~6.4 ms per 28 days, so it is computed only for
    the opened phase and cached until the plan changes. "Load vs" reads *vs the phase before* for a future phase.
- **Week strip:** a caption above the cells, e.g. "General base · week 3 of 10 · lighter week", "Taper: Nuorten SM in
  9 days", "Easing back in · week 1 of 3".
- **Day editor:** the rule's `why` under the plan ("Easy: race tomorrow", "Taper"). "Back to plan" returns to the
  season plan's day.
- **Report:** the week's phase and kind in last week's facts. **Calendar:** the Target toggle. 44 px targets, no
  hover-only info, PC + phone as everywhere.

**Waits for Coaching (M2 part 2):** hiring coaches and specialists (focus plans such as speed vs endurance, plan quality
that varies with the coach), a coach changing days week by week from the day log and soreness (`by = "coach"`, Accept
/ Veto, D18), targets suggested from form and results, a physio reading the health model, coach relationships and
messages. Step 6's club coach only offers data templates, the ★ rule, targets and the return block.

**Balance and verification** (`tools/training_balance.gd`):
- **Off = identical:** with repeat mode, all intensities Normal and `Form.enabled = false`, parts 1–2 fingerprints must
  be bit for bit the same (coach 215.999957139 / 13.751549603 / 1203.029795007 …), and `tools/race_balance.gd` the
  same. Tools that play days must set repeat mode explicitly (new careers start in phases mode and post the offer
  event, which would stop every loop).
- **New part 4:** 200 athletes per row, 1 year from 14, health and form on, targets entered. Rows: repeating coach week
  (reference), Steady, Balanced, Ambitious, each neutral and careful. Prints injuries per year, ability ± standard
  error, average race-day form at targets and at other races, and how often the season best is run at a target.
- **Targets** (user, 2026-10-06):

| Row | Injuries/yr | 800 m ability / yr | Other |
|---|---|---|---|
| Repeating coach week (reference) | 0.67 | +1.18 | average race-day form ≈ 0 (±0.2 %) |
| Steady | ≈ 0.4 | ≈ +1.0 | |
| Balanced | ≤ 0.8 | +1.25–1.35 | clearly faster at targets: form ≈ +0.8…1.3 % there; season best at a target more often than on the repeating week |
| Ambitious, careful | ≈ 1.3–1.6 | ≈ +1.5–1.6 | (≈ today's "ramp, careful") |
| Ambitious, neutral | higher than careful | | |

  If a target can't be reached with templates alone (e.g. Balanced above +1.25 without more injuries), the tuning
  session reports the options instead of changing the model. (Measured in step 6d, with the open options: see "Built (step 6d)".)
- **Multi-season check** (new `tools/season_check.gd`): 50 athletes, 3 seasons (ages 14–17) on Balanced through the
  game loop with health on. The offer events are answered by the tool. It checks: the season rollover (new phases,
  targets for the new age class or the fallback, no week without a plan, the 2028 leap year), save/load at the season
  boundary continuing bit for bit, and injuries and progress per season not drifting. Longer careers (5–8 seasons) stay
  in step 7.

### Other systems (to be designed)

- Nutrition, sleep
- Mental side, motivation, relationships
- Coaching (step 6 prepares it: season plans, `by = "coach"` day changes, the coach event source; see 4.8 "Waits for Coaching")
- Money, sponsors, equipment
- Fame, media, rivals
- School / work–life balance
- Doping / anti-doping
- World simulation (other athletes, records, rankings)

## 5. Presentation

### Help (built 2026-10-07)

Not a tutorial: every screen has a **"?" ("How this works")** that opens a short help for that screen only, when the player
wants it. Decisions (user, 2026-10-07): **one "?" in the hub header** (beside Save / Menu on PC, in the top row on a phone) that
opens the help of whatever tab or page is shown; the day editor has its own "?" next to Close; **never opens by itself**, a small
accent **"new" dot** on a "?" until its help was read (and again when the entry's `version` goes up); on PC the help **covers the
day editor** in the side slot (Close goes back to the day; tapping a day brings the editor back); shared ideas are **topic entries
reached by "See also" buttons** (with "◀ Back"). Claude's defaults, accepted:
- **Texts:** `data/help.json`: `screens` (overview, training_season, phase_editor, training_repeat, calendar, rankings, report,
  day_editor, race_before, race_running, race_result, new_career, health_event) and `topics` (fatigue, soreness, injuries,
  load_vs_normal, plan_risk, form, lighter_weeks, easing_in, targets). Each: title, version, sections {heading, text (at most
  ~50 words, the check allows 60), see: [topic ids]}. Plain words, what the player sees and what to do; **no hidden numbers**
  (injury proneness, strain, formulas); numbers the UI already shows are fine. No help text in scripts.
- **Where it shows:** `HelpPanel` (title, sections all open, "See also" / Back, Close; 44 px buttons) in the hub's side slot on PC;
  everywhere else a `HelpOverlay` (dimmed layer, tap it or Esc to close): a bottom sheet on a phone (fitted, at most 72 %), a
  460 px panel over the right side on PC (race screen, wizard, health stop panels). Rebuilds on `Router.layout_changed` and keeps
  the open entry. The help opened with the header "?" follows the tab or Training page you switch to.
- **Which entry:** the hub's tab, and in Training the page (season plan / phase editor / one repeating week); the race screen by
  stage (before / running and its decision card / result); the diagnosis and "sore" panels share `health_event`. No help on the
  main menu and load screen. **F1** opens / closes the help, **Esc** closes it first (then the day editor). The race waits while
  its help is open.
- **"Read" state** is a player setting, not part of a career: `user://help_seen.cfg` (entry id → version read), not the save.
- **Long inline explanations moved into the help:** Overview's paragraph (strip markers, attributes, Ctrl+S) is one line now that
  points to the "?"; the Calendar intro keeps the ★ / ◆ key.
- **Found while building:** on PC the Training pages' wide day rows didn't fit beside the side panel (help *or* the day editor,
  which was already the case before): `Layout.stacked()` (= phone, or PC with the hub's side panel open) now gives them their
  stacked layout, and the hub rebuilds the Training page when the side panel opens or closes. The PC header says "Menu" on a
  short, wide window (phone sideways) and a long name ends in "…".
- **Rule:** every new feature step adds or updates its help entry (raise `version` when the text changes meaningfully).
- **Verified:** `tools/help_check.gd` (405 checks: the data, every screen's "?" pressed and showing an entry that exists, every
  entry used, See also / Back, the dot, Esc / F1), tour shots `1b_`, `6b_`–`6d_`, `8b2_`, `8c2b_`, `9b_`, `10b_`, `20a_`, `28a_`,
  `29a_` at 1600×900 and 390×844, `layout_check` at all 5 sizes (help on every tab, a topic, the day editor's help, the wizard,
  the race and the health panel): no OVERFLOW / SQUEEZED.

### Other presentation

- 2D stadium view during meets: track, crowd, simultaneous events.
- Modern, sleek, responsive UI (desktop + mobile).
- **Idea (user, for later):** the plain dark UI feels generic. Use athlete photos as screen backgrounds, darkened and/or blurred behind the panels so they never hurt readability. Could vary per screen or event (e.g. an 800 m pack on the career hub). Needs a set of good, properly licensed photos (e.g. Wikimedia Commons) or the user's own. **Status (UI polish pass, 2026-10-05):** the backdrop system is built (blurred + darkened photo behind translucent panels, per screen, falls back to a gradient). A deliberately harsh test image stayed readable, but loose text (tabs, captions) is the weak spot, so photos should be calm and dark. Photos added (2026-10-05, user-approved): two Finnish athletes at Kalevan Kisat 2018 and Lahti Stadium, all CC BY-SA 4.0 from Wikimedia Commons; a Credits screen is still to do. See `assets/backgrounds/README.md`.

## 6. Data

- Real-world database: athletes, records, competitions, venues, qualification standards.
- Stored as editable data files (so it can be corrected and updated without touching code).
