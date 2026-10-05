# Game Design Document — Track & Field Career (working title)

Version 0.4 — 2026-10-05 (M2 design: day-by-day mode, injuries & health). Living document: updated after each design discussion.

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
- Play week **stops** the first time an area turns "sore": keep going / take it easy today / rest day.
- New injury: **diagnosis panel** (name, plain explanation, expected time range, what's allowed).
- Injury proneness stays hidden; after repeated injuries a hint ("you seem to pick up knocks easily").

**Balance targets** (`tools/training_balance.gd`, 200 athletes per plan, 1 year from age 14; adds a "careful" policy
= take it easy when sore, and a "ramp" plan = build up to the hard plan over 8 weeks):

| Plan | Injuries/yr | Serious | Progress |
|---|---|---|---|
| Coach plan | ~0.5–1 (mostly niggles) | < 5 % | as in M1 |
| Lazy | ~0 | ~0 | little |
| Hard, warnings ignored | 3+ | > 40 % | **below the coach plan** |
| Hard, careful | ~1–1.5 | ~10 % | a bit above the coach plan |
| Ramp to hard | clearly below "hard, ignored" | | best |
| Illness (all plans) | 2–3 colds/yr, mostly winter | | |

Rule of thumb: training harder pays off only if you listen to your body.

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
