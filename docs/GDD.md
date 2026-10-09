# Game Design Document — Track & Field Career (working title)

Version 0.7 — 2026-10-07 (race realism designed, 4.3.1; earlier: M2 steps 3–6 built, 4.6 / 4.8). Living document: updated after each design discussion.

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
- **Race realism (designed 2026-10-07):** pack racing, rival moves and personalities, falls, the action bar, coach
  and commentary. See 4.3.1; it replaces the plan lap factors, the fixed decision points and the commentary above.

### 4.3.1 Race realism (designed 2026-10-07; R1 pack engine built 2026-10-07, R2 moves / boxes / falls 2026-10-08, R3 player controls 2026-10-08, R5 balance 2026-10-09, R4 to come)

Playtest (user, 2026-10-07): the order seems settled early, while real 800 m races are often one bunch with moves
anywhere. Wanted: pack racing (staying together, drafting, being boxed in), rival moves at any point that can change the
order late, the player answering them, and commentary that reacts to what happens and to the player's choices.

**Measured before (M1 engine, `tools/race_shape.gd -- 100`, 8 runners, seed 11).** Gaps in metres when the leader
passes 200 / 400 / 600 m; finish gaps are medians:

| Row | 1st→last 200/400/600 m | 1st→4th at 400 | Within 5 m of leader at 400 | Leader at 400 / 600 wins | Order 400 / 600 vs finish (r) | Finish 1st→2nd / 4th / last | Won by < 0.2 s | Time / table |
|---|---|---|---|---|---|---|---|---|
| Youth even field (ability 7 ± 0.8) | 23 / 46 / 65 | 19 | 1.7 | 62 % / 71 % | 0.84 / 0.88 | 2.5 / 7.0 / 17.5 s | 6 % | 0.996 |
| Youth local meet, wide (7 ± 1.6) | 37 / 74 / 108 | 31 | 1.4 | 85 % / 94 % | 0.93 / 0.94 | 4.6 / 11.7 / 33.0 s | 3 % | 0.995 |
| Youth championship final (9 ± 0.5) | 17 / 35 / 47 | 16 | 1.9 | 50 % / 69 % | 0.75 / 0.82 | 2.0 / 4.9 / 11.9 s | 7 % | 0.997 |
| Youth indoor (7 ± 0.8) | 24 / 46 / 65 | 21 | 1.6 | 79 % / 88 % | 0.85 / 0.88 | 3.1 / 8.4 / 18.3 s | 5 % | 1.012 |
| Girls even field (7 ± 0.8) | 21 / 42 / 60 | 18 | 1.8 | 66 % / 81 % | 0.82 / 0.87 | 2.9 / 7.6 / 17.8 s | 4 % | 0.997 |
| Senior national final (15 ± 0.4) | 13 / 28 / 36 | 12 | 2.1 | 53 % / 67 % | 0.62 / 0.73 | 1.0 / 2.8 / 7.0 s | 8 % | 0.997 |
| 8 identical runners (9, consistency 20) | 10 / 21 / 24 | 9 | 2.7 | 38 % / 47 % | 0.41 / 0.51 | 0.5 / 1.8 / 4.1 s | 25 % | 0.999 |

`race_balance.gd` before (median vs anchor): girls 5–13 within −1.4…+0.4 s; boys 5–13 within −1.0…+0.1 s; indoor boys
+1.1…+2.4 s (slower by design: tight bends).

**Real races** (times only; youth athletes are minors, so no names are used or stored):
- Nuorten SM 14–15, Mikkeli 31.7.–2.8.2026, and 16–17, Hyvinkää 7.–9.8.2026 (Tilastopaja results 113170 / 113276;
  17 races of 6–11 runners, P/T 14–17, seeded timed sections). Medians: 1st→2nd **1.1 s**, 1st→4th **3.5 s**, 1st→last
  **11.9 s**; 2 of 17 won by < 0.2 s. Typical shape: a tight front group, then a long tail (e.g. 2:05.24, 2:06.04,
  2:06.20, 2:06.25, 2:06.47, 2:08.64, 2:08.86, 2:14.47).
- Kalevan kisat, Jyväskylä 24.–26.7.2026 (Tilastopaja 113047), men's final + 3 heats: medians 1st→2nd **0.06 s**,
  1st→4th **1.1 s**, 1st→last **4.1 s**; the final 1:50.88 / 1:50.88 / 1:51.48 / 1:51.78 … 1:53.59. Women (less deep):
  1st→2nd 0.14 s, 1st→4th 2.5 s, 1st→last 9.6 s.
- District youth meet (15–9-v. pm-kilpailut, Riihimäki 22.–23.8.2026, Tilastopaja 113558): small fields, big gaps
  (e.g. T15 2:39.05 / 2:42.85 / 2:52.88): wide fields really do string out.
- World level (Wikipedia): Paris 2024 men's final 1st→4th 0.48 s, 1st→8th 2.65 s; Tokyo 2021 men's final bell 53.76,
  all 9 within 1.47 s; Budapest 2023 the winner was last at 400 m; World U20 2024 final 1st→4th 0.29 s; Tokyo 2021
  women "the pack still tight" at the bell.
- Renfree et al. 2014 (IJSPP 9:362, 2012 Olympics): order vs finish r = 0.61 at 400 m, 0.84 at 600 m. NCAA 2025
  (Citius Mag): half the champions led at the bell; both 800 m winners came from 5th–6th. Since 2011 world medallists
  run the first lap 2.2 ± 1.1 s faster than the second. Pugh 1971 (J Physiol): ~8 % of the energy at 6 m/s goes to air
  resistance; running 1 m behind someone cut oxygen use ~6 %.

**Why the field strings out (the M1 engine):** (1) every runner runs their own clock: target speed = own even pace ×
plan factor, nobody adjusts to the race except not running into the runner in front; (2) the plan sets lap 1: front
×1.05, pack ×1.03, back ×1.01, so two equal runners are ~18 m apart at 400 m (the identical-runners row); (3) weaker
runners drop off from the gun instead of hanging on and being dropped late; (4) drafting only discounts the drain
above the sustainable speed by 7 %, worth ~0.1–0.2 % of effort (real ~6 %); (5) rival kicks are pre-rolled distances,
nobody covers a move; (6) the player's decisions come at fixed distances, the "rival move" one only at 420–570 m; (7)
about four kinds of commentary line. The order-vs-finish correlation is near real; the **gaps** are 2–5× too big, so a
change of place late is a fade, never a fight.

**Decisions (user, 2026-10-07):**
1. Race shapes per level as proposed (table below).
2. **Pauses for the big moments plus an always-there action bar** (the player can make their own move at any time).
3. **Rival personalities**, kept per rival, hidden at first, a tag after racing someone twice, mentioned by the commentator.
4. **Boxed in** always has a way out at a cost; **falls and tripping: yes**.
5. **Quick results use the same engine**; the athlete decides by race tactics.
6. **TV commentator and the coach**: the coach shouts from the side of the track, as coaches really do.
7. Energy shown as **a word**.
8. Good race vs bad race ≈ **0.5–1 % of time** (1–2 places in an even field); smart racing **can cause upsets** when a
   stronger runner races badly, with a proper balance (targets below).
9. At 2x / 4x the race **drops to 1x** for a moment when something happens near the player.

**Decisions (user, 2026-10-08, step R2):**
10. **A rival's fall:** most falls only cost the race; a small share keeps the rival out for 1–3 weeks (`out_weeks`,
    ~1 in 8 falls, half of the DNFs), rolled with the race's dice, applied when the health model is on.
11. **Tactical races start slower:** lap 1 8–12 % below the field's even pace (was 3–7 %): real tactical finals start
    ~10 % slower, and only then is there a real sprint finish.
12. **The senior final finish target waits for step 7:** the engine turns each runner's ability *on the day* into
    finish gaps almost one to one, and race-day form (±0.6 ability ≈ ±1.8 s for a senior, elite seniors really vary
    ~1 %) spreads the senior test field wider than a real national final. Seniors' race-day consistency is designed
    with the multi-year check.
13. **Energy: going faster than your own even pace costs extra** (R2): the reserve drains by (speed − cs) ×
    (speed / own even speed)³; even pace costs as before, a too-fast start or a long sprint costs more, a slow
    tactical lap saves more. With the old straight-line drain *when* a runner spent the reserve hardly mattered
    ("leading too fast" even helped a strong runner). The upset targets left short (Δ 0.5, good vs bad) are tuned
    again in R5, once the player's action bar and cards exist (R3).

**Decisions (user, 2026-10-08, step R3):**
14. **The coach's shout (stand-in rule until R4 gives him a real spot):** the coach stands at one spot, outdoors on the
    back straight (200 m round the lap), indoors on the infield; he sees the player within 110 m along the track
    (indoors the whole track), so on some cards he is silent. He shouts the sensible answer 80 % of the time, another
    answer otherwise (`controls.coach`).
15. **Phone action bar:** Push / Hold / Ease / Kick now in one row, **Move out as a full-width second row** (always
    reachable).
16. **The "metres to go" kick card stays** as a third always-card (break, bell, kick). Claude's change: it comes when
    the player reaches their *own kick point* instead of fixed at 600 m run, because the athlete's natural kick used to
    start by itself before that for about three races in four (grinders), and the card was then never asked.

**Decisions (user, 2026-10-08, after R3):**
17. **Mistakes must cost; no arcade feel.** A good vs a bad race is worth about 0.5–1 % of time; the follow-up to R3
    below builds it (the energy exponent, committing answers, early kicks, letting a move go) and fixes the lap splits.
18. **No arbitrary cap on cards:** a race that demands more cards gets more. The cap is now a safety valve (10); what
    limits the cards is that one needs a real moment and comes at least 8 race seconds after the last (about 5–6 a race).
19. **The drop to 1x says why** ("SLOWED TO 1x · SAVOLAINEN KICKS"): the user could not tell which moves merit it.

**Decisions (user, 2026-10-09, before R5):**
20. **No difficulty setting, ever.** Opponents are as hard as their attributes make them: fields come from the meet's level
    (never from the player's level), rivals train toward their own ceilings and race by the same rules, no rubber-banding.
    A far stronger rival is hard or impossible to beat. (Checked at step 7 against real Finnish development.)
21. **Time and place are one thing:** no artificial place effect for answers; what a time cost does to the place depends on
    how tight the field is (0.5 s is 1–2 places in a tight final, nothing in a wide field). R5 measures the answers' worth
    in tight finals as well.
22. **Boxed in: every way out is realistic, none is a trap.** Waiting works early and fails late (the race runs out), easing
    back and stepping out costs the 2–4 m of the design (not 7 % of speed for as long as the box lasts), pushing through is
    the right call late when a gap exists (contact / DQ risk stays). The best answer depends on the distance left. R5.
23. **A move is decisive when the mover can carry it to the end:** chasers pay a lot to close a gap on someone with more
    reserve (or a better kick), and a mover who is going to fade is caught. R5 first measures how often a mover who surged
    finishes ahead of those who let it go, then tunes (surge size, closing cost, `let_go_close`).

**Decision (user, 2026-10-09, during R5):**
24. **Boxed in: the room decides** (replaces "the best answer depends on the distance left" of decision 22; "none is a
    trap" stays). Measured in R5: the best way out depended on whether someone is right on your shoulder, hardly on the
    distance left, because a box in a moving field clears within a second or two. With someone right on your shoulder:
    wait (on a bend a gap rarely opens); with room (the runner on your shoulder half a stride back): ease and step out, or
    push through on the home straight. The box card says which it is.
25. **Upsets: keep a good vs bad race at 0.5–1 % of time; the Δ 0.5 upset target becomes 35–45 %** (was 45–55 %, which
    would need a bad race to cost 1.3–1.8 %; measured in R5: neutral 31 %, A's bad + B's good race 34–38 %).

**Engine: pack racing.** The race is decided by who has energy left late, not by who ran their own pace.
- **Race shape**, rolled before the start (data, `races.json` `shapes`): *fast from the gun* (lap 1 ≈ 3–5 % faster than
  the field's even pace), *honest* (≈ 1–2 % faster: the normal positive split), *tactical* (≈ 8–12 % slower, then a
  long sprint; was 3–7 % until R2, decision 11). Mix: local youth 50 / 35 / 15, district 40 / 40 / 20, championship heats 30 / 50 / 20, finals
  20 / 35 / 45 (fast / honest / tactical). A front runner in the field moves weight towards fast; no front runner
  towards tactical. The leader aims for the shape's pace; the commentator calls it at 200 m.
- **Following:** every runner wants a place (personality + plan: lead / front of the pack / back of the pack / own
  pace). Behind a group they run the group's speed. Running faster than their own sustainable speed drains the reserve
  (from R2 faster the further above their own even pace, decision 13); **drafting** (≤ 1.5 m behind, same line) lowers the cost by about 2 % of speed (from Pugh's 6 % of energy,
  less on bends and in the second row; data). Leading costs the full price.
- **Hanging on and being dropped:** a runner stays with the group while their expected reserve at their kick point
  is enough (personality and determination set how deep they dig). When it isn't, they fall back to their own pace:
  "dropped". This gives the real shape: a tight front group, a long tail.
- **Misjudged energy:** each runner feels their reserve with an error (± a few %, smaller with better race tactics),
  fixed per race, so a long kick sometimes dies in the last 50 m. The player's Feeling word shows the *felt* reserve.
- **Moves:** any runner may surge (+4–8 % for 50–150 m) at any point after the break: chance by personality, race
  shape (more in tactical races) and position. Runners close to the move cover it or let it go (personality, tactics,
  energy). A covered move bunches the field again; an uncovered one opens a gap that may hold or come back.
- **Kick chain:** a kick near the front sets off answers instead of every kick being pre-rolled.
- **Boxed in:** on the inside with a runner ≤ 1.5 m ahead and one alongside outside: no faster than the runner ahead.
  Ways out: *wait* (a gap opens when the pack stretches or the runner ahead fades; more often with better race
  tactics), *ease and step out* (costs 2–4 m), *push through* (a gap between two runners: contact risk, a small
  obstruction-DQ risk). Rivals obey the same rules (kickers get boxed too).
- **Contact, stumbles and falls:** contact can happen where paths cross at close range: cutting in at the break line,
  bunched bends, swinging out late, pushing through. A contact is mostly nothing, sometimes a **stumble** (1–3 m and a
  little reserve), rarely a **fall** (4–8 s, rarely DNF); a fall can bring down the runner just behind. Target ≈ 1 fall
  per 60–100 bunched races per runner, much rarer in strung-out fields; front running is safest. A fall rolls an acute
  race injury in the health model (new `injuries.json` entries: graze / bruise niggle, rarely an ankle sprain; spiked =
  cut niggle). Obstruction DQ only from "push through", tiny chance (data).
- **Heats:** with automatic places, runners safely in them ease off in the last 30–50 m (not when fastest losers count).
- **Plan lap factors go**; the pre-race plan picks the place the player wants (Lead / Sit in the pack / Wait at the back).
- **Calibration:** one data number (cruising-speed scale) brings the median back to the anchors: tactical races are
  slower, fast ones quicker, the mix averages to the table. The off-screen rival races (`Rivals.train_week`, table ×
  ~1.008) stay as they are, so the engine's median time / table must stay within ±0.5 % of 1.00.
- All randomness from the race's own RNG (tools stay repeatable).

**Rival personalities** (`personality` on the rival dict; old saves get one on load, made from the rival's
`anaerobic` and a hash of its id, so no save version change): **Front runner** (leads, honest or fast, long drive from
300–400 m; common among youth), **Pack runner** (sits 2nd–4th, covers moves, kicks 200–150), **Kicker** (back of the
pack, ignores mid-race moves, kicks 150–100, big reserve), **Surger** (one or two moves at 300–550 m). Weights by
`anaerobic` (low → front / surger, high → kicker). Race tactics = how well they judge and time it, not the type.
Shown as a tag in the pre-race field after the player has raced that rival twice (`met` count on the rival); the
commentator mentions it ("known for her late kick").

**Player controls (detailed mode).**
- **Pre-race:** plan (Lead / Sit in the pack / Wait at the back).
- **Pause cards** (the race waits, as now), **event-driven**, at most 6 per race (data), the most important first; minor
  ones only go to the commentary: break position and bell / halfway (always); a rival move within ~15 m (any distance:
  *Go with them / Let them go / Counter-attack*); boxed in while a move goes (*Wait / Ease and step out / Push through
  (risk)*); losing contact (*Dig in / Run your own pace*); a slow tactical pace (*Take the lead / Stay put*); home
  straight (as now); after a fall (*Get up and chase / Finish steady*). The card shows the coach's shout when the coach
  can see it ("Coach: Go with him!").
- **Action bar**, always there, no pause, 44 px: **Push / Hold / Ease / Move out / Kick now** (the active one
  highlighted; Kick now needs a second tap within 2 s, "Tap again to kick", against mistaken taps on a phone).
- **Slow motion:** at 2x / 4x the race drops to 1x for ~5 race seconds when a move, box, contact or fall happens
  within ~20 m of the player (data), then returns to the chosen speed.
- **Feeling** word under the clock: Comfortable / Working / Hurting / Empty (felt reserve, fatigue).
- **Quick mode:** the same engine; cards answered by the athlete (race tactics, as `_auto_choice` today), no action bar.

**Coach and commentary.**
- **Voices:** the **TV commentator** (third person), the **coach** (shouts to the player from a spot by the track:
  outdoors near the 200 m start / back straight, once a lap; indoors from the infield, twice a lap; splits, "Relax!",
  "Stay on his shoulder!", reacting to rivals; advice quality = the club coach's for now, good not perfect; hired
  coaches change it later), and **"you" lines** for the player's own choices. Now and then another runner's coach is
  heard ("Go Aino!").
- **Events, not text:** the engine posts race events (start, break leader, pace calls at 200 / 400 / 600 compared with
  the field's even pace, pack shape, move, cover, dropped, boxed, escape, contact / stumble / fall, lead change, kick,
  kick dying, close finish, photo finish, PB / SB) and the commentary picks lines for them.
- **Lines in `data/race_commentary.json`:** per event several variants with placeholders (`{name}`, `{m}`, `{split}`,
  `{gap}`, `{pos}`), tags (shape, level, indoor, voice). Never the same variant twice in a race, the last ~30 used
  remembered across races, at least ~2 race seconds between lines except important ones, one pace call per 200 m.
- **Choices get a verdict** ~10 s later from what happened ("You went with him and it's paying off", "Waiting has cost
  you two places").
- **UI:** PC = a COMMENTARY box of fixed height in the side panel (6 lines, newest on top, scroll for older; coach
  lines in the accent colour with a COACH tag), key moments also as a 2-second banner over the track. Phone = a 2-line
  ticker under the track; tap opens the full log as a sheet (the race waits, like help). Result screen: **Race story**
  (splits at 200 / 400 / 600 for the player and the winner, 4–6 key moments, the coach's one-line verdict).
- Texts in data, so they can be translated (D27).

**Sketches** (the action bar, banner, ticker and card; layout as today):
```
PC                                                      side panel
┌───────────────────────────────────────────────┬──────────────────────────┐
│ Nuorten SM · Final                [1x][2x][4x]│ 1:31.4                   │
│        (track with dots)                      │ You 4th · 229 m to go    │
│   ┌──────────────────────────────────┐        │ Feeling: working         │
│   │ Korhonen kicks — 229 m to go!    │ banner │ POSITIONS …              │
│   └──────────────────────────────────┘        │ COMMENTARY               │
│ [Push] [Hold] [Ease] [Move out] [Kick now]    │ ▸ Korhonen kicks!        │
│                                               │   COACH: Go with him!    │
└───────────────────────────────────────────────┴──────────────────────────┘
Card (dimmed overlay)                         Phone
┌ A rival makes a move ─────────────── ? ┐    ┌──────────────────────────────┐
│ Korhonen kicks with 229 m to go.        │    │ Final          [1x][2x][4x]  │
│ You: 4th, boxed on the rail.            │    │      (track, 250 px)         │
│ Coach: "Go with him!"                   │    │ ▸ Korhonen kicks! 229 to go  │
│ [ Go with him ]   costs energy now      │    │   COACH: Go with him!        │
│ [ Let him go ]    he may fade late      │    │ 1:31.4  You 4th · working    │
│ [ Ease, step out ] free, but −3 m       │    │ [Push][Hold][Ease][Kick]     │
│ [ Push through ]  risk of contact       │    │ POSITIONS …                  │
└─────────────────────────────────────────┘    └──────────────────────────────┘
```
(The phone bar has room for four buttons; Move out moves to the card / a second row when needed, decided in the build.)

**Balance and verification:**
- `race_balance.gd`: medians within ±1 s of the anchors (before: above). `race_shape.gd`: time / table median within
  ±0.5 % of 1.00.
- **Shape targets** (`race_shape.gd`): youth championship final row: finish 1st→2nd ≈ 0.6–1.5 s, 1st→4th ≈ 2.5–4.5 s,
  1st→last ≈ 9–15 s (real 1.1 / 3.5 / 11.9); senior national final row: 1st→2nd ≈ 0.1–0.5 s, 1st→4th ≈ 0.7–1.5 s,
  1st→last ≈ 3–5.5 s, won by < 0.2 s in 30–60 % (real 0.06 / 1.1 / 4.1, 3 of 4); even finals: ≥ 4 of 8 within 5 m of
  the leader at 400 m, the leader at 400 m wins 30–50 %, order vs finish r ≈ 0.6 at 400 m and ≈ 0.8 at 600 m; wide
  local fields stay strung out (1st→last ≥ 20 s).
- **Upsets** (new duel rows in `race_shape.gd`: runner A stronger by Δ ability with a bad race, e.g. leads too fast /
  waits boxed / kicks from 400 m, runner B with a good race, in an even field): a good vs bad race is worth ≈ 0.5–1 %
  of time on average; at Δ = 0.5 B beats A ≈ 35–45 % (decision 25; was 45–55 %) (vs ≈ 30 % when both race neutrally); at Δ = 1 ≈ 20–30 %; at
  Δ = 2 under 5 %. Watched with sensible choices vs quick mode: at most ~1 place better on average.
- **Falls:** ≈ 1 per 60–100 bunched races per runner; printed by `race_shape.gd`.
- Form (4.8) works on ability before the race, so `form_check.gd` must still pass unchanged; `training_balance.gd`
  parts 1–2 fingerprints identical (no races there); `rankings_check`, `day_engine_check`, `health_check`,
  `help_check` pass; `race_perf.gd` keeps 60 fps on PC and phone size; the tour and layout check get seeded race states
  (action bar, banner, ticker, card with the coach's shout, race story).
- Build order and sessions: ROADMAP "Race realism".

**Built (step R1, 2026-10-07): the pack engine (headless).** `Race` (`scripts/core/race.gd`), all numbers in
`data/races.json` `engine` / `shapes` / `personalities`, all dice from the race's own RNG (the lane draw used the global
dice before; `day_engine_check` now checks that the same seed gives the same race).
- **Shape** rolled at the first step (after the player's plan is known): mix by `RaceDay.shape_mix()` (local / district
  by level, championships by round: heat / final; tools without a meet use `default_mix` district), ±10 points
  fast/tactical for a front runner / none. The leader runs `ref_speed` × lap 1 / lap 2 factor (fast 1.03–1.05 /
  0.97–0.99, honest 1.01–1.02 / 0.98–1.00, tactical 0.93–0.97 / 1.00–1.02). **The field's even pace** =
  `pace_ref_quantile` 0.25 = the 3rd strongest of 8 (Claude's tuning: the median left the strong runners so much
  spare that every race ended in a huge kick; the strongest strung the field out like M1).
- **Following:** within 10 m of the runner ahead a runner runs their speed, closing to 1 m behind (0 = alongside in
  another line); **drafting** 2 % of speed (≤ 1.5 m behind; diagonally ×0.5; on a bend ×0.7); the leader pays full price.
  **Tuck in on bends** (Claude's addition): on a bend or 15 m before one, a runner alongside on the outside drops in
  behind and moves to the rail; two-wide on a tight bend costs 3–6.5 % of distance, and this rule also bunched the
  finish (senior final 1st→4th 2.6 → 1.8 s).
- **Places:** lanes before the break at the race pace × 1.015 (lead) / 1.0 (pack) / 0.99 (back); until 600 m lead
  runners move to the front and pack runners up to 4th, when they have the energy for 2 % more speed; anyone passes a
  runner slower than 98.5 % of the race pace.
- **Hanging on / dropped:** a runner follows while the reserve they *feel* they will have at their kick point is at
  least 0.125 × kick metres / 100 × reserve (= even spending), less by `dig` (personality + (competitiveness − 10) ×
  0.02, the player's determination, max 0.5) and never more than the kick can use; otherwise they slow to the speed
  that keeps it, never below 97 % of the speed that empties the reserve at the line (their own pace). Dropped = over
  5 m behind the runner ahead (they stop digging).
- **Misjudged energy:** felt reserve = reserve + error × reserve, error sd 6 % (race tactics 1) … 1 % (20), fixed per
  race. Kick timing noise 40 … 10 m.
- **Kick speed** (Claude's tuning): at most the runner's even speed × (1.12 + 0.01 × (speed − ability)), from the
  ability *before* the day's form (sprint speed hardly changes day to day), max 95 % of top speed. The old 95 % of top
  speed meant a 26 s last 200 m for a 2:20 youth runner.
- **Personalities** on every rival (`personality`, `met`): made from `anaerobic` + a hash of the id (no dice), so a
  new pool and an old save get the same ones; first pool: front 27 %, pack 35 %, kicker 19 %, surger 18 %. Front:
  lead, kick 300–400; pack: 2nd–4th, kick 150–200; kicker: back, kick 100–150; surger: pack, kick 150–250 (surges in R2).
  `met` counts races run together with the player (heat + final = 2). Tag hidden until R4.
- **Plan lap factors removed;** the pre-race plan is the place (labels now *Lead / Sit in the pack / Wait at the
  back*, help `race_before` v2). The old fixed cards still work (break = the place; bell push / ease = ×1.03 / ×0.97
  until the kick; the old "back" ×0.99 is gone). Checked: 100–200 races per plan × answer policy (first / last /
  random / quick), nothing stuck, every card still comes up.
- **Calibration:** `cs_scale` 1.003.
- **Measured after** (`race_shape.gd -- 100`, same rows and seed as "Measured before"; the tool now passes each row's
  shape mix: even field / indoor / girls district, local wide local, finals and identical final):

| Row | 1st→last 200/400/600 m | 1st→4th at 400 | Within 5 m at 400 | Leader at 400 / 600 wins | r 400 / 600 | Finish 1st→2nd / 4th / last | Won by < 0.2 s | Time / table |
|---|---|---|---|---|---|---|---|---|
| Youth even field | 15 / 32 / 51 (was 23 / 46 / 65) | 7 (19) | 3.4 (1.7) | 61 / 66 % (62 / 71) | 0.86 / 0.90 (0.84 / 0.88) | 2.0 / 5.9 / 16.4 s (2.5 / 7.0 / 17.5) | 11 % (6) | 0.996 (0.996) |
| Youth local meet, wide | 27 / 55 / 85 (37 / 74 / 108) | 12 (31) | 3.1 (1.4) | 54 / 65 % (85 / 94) | 0.90 / 0.93 (0.93 / 0.94) | 2.4 / 8.3 / 27.9 s (4.6 / 11.7 / 33.0) | 12 % (3) | 1.002 (0.995) |
| Youth championship final | 7 / 16 / 28 (17 / 35 / 47) | 4 (16) | 5.1 (1.9) | 29 / 39 % (50 / 69) | 0.59 / 0.76 (0.75 / 0.82) | 0.7 / 3.0 / 9.5 s (2.0 / 4.9 / 11.9) | 24 % (7) | 1.002 (0.997) |
| Youth indoor | 16 / 33 / 52 (24 / 46 / 65) | 10 (21) | 2.8 (1.6) | 60 / 71 % (79 / 88) | 0.79 / 0.87 (0.85 / 0.88) | 2.3 / 6.6 / 17.0 s (3.1 / 8.4 / 18.3) | 7 % (5) | 1.014 (1.012) |
| Girls even field | 14 / 29 / 44 (21 / 42 / 60) | 7 (18) | 3.4 (1.8) | 49 / 53 % (66 / 81) | 0.83 / 0.87 (0.82 / 0.87) | 1.7 / 5.4 / 15.7 s (2.9 / 7.6 / 17.8) | 10 % (4) | 1.001 (0.997) |
| Senior national final | 5 / 11 / 19 (13 / 28 / 36) | 3 (12) | 5.6 (2.1) | 34 / 46 % (53 / 67) | 0.52 / 0.73 (0.62 / 0.73) | 0.7 / 2.1 / 5.6 s (1.0 / 2.8 / 7.0) | 25 % (8) | 1.001 (0.997) |
| 8 identical runners | 3 / 6 / 12 (10 / 21 / 24) | 2 (9) | 6.1 (2.7) | 26 / 44 % (38 / 47) | 0.44 / 0.73 (0.41 / 0.51) | 0.5 / 1.7 / 4.5 s (0.5 / 1.8 / 4.1) | 27 % (25) | 1.001 (0.999) |

  Winner's laps by shape (youth final): fast 67.7 + 66.9, honest 69.1 + 67.0, tactical 73.1 + 64.7 s (lap 1 includes
  the ~1.5 s start).
- **Targets:** time / table within ±0.5 % in every outdoor row ✓ (indoor 1.014, slower by design as before); youth
  championship final 0.7 / 3.0 / 9.5 s ✓ (targets 0.6–1.5 / 2.5–4.5 / 9–15); even finals ≥ 4 within 5 m at 400 ✓
  (5.1 / 5.6); leader at 400 wins 29 % / 34 % ✓ (30–50); r 0.59 / 0.76 (youth) ✓, 0.52 / 0.73 (senior, a little low);
  wide local fields strung out ✓ (27.9 s). **Left for R2:** the senior final finish (0.7 / 2.1 / 5.6 s, 25 % under
  0.2 s; targets 0.1–0.5 / 0.7–1.5 / 3–5.5, 30–60 %): every kick is still pre-rolled and nobody answers one, so a long
  kick opens 15–20 m; the kick chain and covering moves are R2. Upsets and falls: R2.
- **`race_balance.gd`** (median vs anchor, 12 races per row): girls −0.9…+0.1 s, boys −0.6…+1.1 s (ability 5; with 60
  races per row every outdoor row is within −0.9…+0.3 s), indoor +0.8…+4.1 s (60 races: +2.1…+3.0 s; before
  +1.1…+2.4: pack running on tight indoor bends costs a little more).
- **Unchanged:** `form_check`, `health_check`, `help_check`, `day_engine_check` (+ new: personalities, old save,
  `met`, repeatable race) all pass with clean stderr; `rankings_check` fills its list (it now answers health stop
  events, which could freeze it before); `training_balance.gd -- 0` fingerprints identical (215.999957139 /
  13.751549603 / 1203.029795007); `race_perf.gd` (see ROADMAP R1).

**Built (step R2, 2026-10-08): moves, boxes, falls (headless).** All in `Race` (`scripts/core/race.gd`), every
number in `data/races.json` `engine` (`moves`, `chain`, `box`, `contact`, `heat_ease`, `drain_power`), every die from
the race's own RNG (`day_engine_check`: same seed → same race, results *and* event list). Decisions 10–13 above.
- **Energy (decision 13):** reserve drain = (speed − cs) × (speed / own even speed)³ (`drain_power` 3; 0 = R1).
  Every "how fast can I go" answer (the kick, hanging on, covering, surging) solves this exactly (`_hold_speed`).
- **Moves:** after the break + 20 m a runner not kicking may surge (+4–8 % for 50–150 m): per 100 m front 0.04, pack
  0.03, kicker 0.01, surger 0.03 (0.5 between 300 and 550 m run), × 0.5 / 1 / 2 in fast / honest / tactical races,
  × 0.7 for the leader, × 0.3 more than 5 m behind; at most 2 each; only when the reserve they *feel* they can spare
  covers it. Runners from 2 m ahead to 15 m behind cover (follow the surger at up to 1.08 × its speed, digging 0.3
  deeper) or let it go (no faster than their speed / the race pace until 20 m after the surge): cover chance front 0.6,
  pack 0.75, kicker 0.2, surger 0.5, player 0.5, moved by race tactics towards 0.9 (can afford) / 0.15 (can't).
- **Kick chain** (Claude, measured): a kick in the first 4 places or within 6 m of the leader makes the runners from
  3 m ahead to 12 m behind answer (front 0.8, pack 0.85, kicker 0.5, surger 0.75, player 0.7; × 0.6 before their own
  kick point; tactics towards 0.95 / 0.2 by whether they could hold the kicker's speed to the line). **Answering =
  going with the kicker** (covering), their own kick at their own point; a coverer near the front passes it on. First
  build answered with an immediate all-out kick: every front runner then went from 400 m and the senior final spread
  *out* (0.9 / 2.8 / 7.0 s).
- **Boxed in:** wants past (kicking, in a move, covering, or in the last 300 m), a runner < 1.5 m ahead in the line and
  someone on the shoulder: no faster than the runner ahead. Way out by weights: wait (more early, more with tactics; a
  gap opens 0.02–0.25 per second by race tactics: the runner on the shoulder drifts wide), ease and step out (0.93 ×
  the speed ahead until the outside is clear: costs a few metres), push through (more with grit and in the last
  150 m; contact 50 %, obstruction DQ 1 %). The player's way is picked the same way (quick mode's race tactics) until
  R3. Per race in a youth final: 17.6 boxes, most under half a second, 2.8 lasting 2 s or more; out by wait 71 % /
  ease 24 % / push 4 %.
- **Contact / stumble / fall:** a runner on someone's heels (< 0.9 m behind, < 0.55 m sideways) has contacts per
  second: cutting in after the break 0.3, either moving sideways 0.15, bend 0.04, straight 0.015; push through rolls
  its own. A contact: the runner behind is the one in trouble 75 %; stumble 15 % (1–3 m, 2–5 m of reserve), fall 2 %
  (down 3.2–7 s + getting up ≈ 4–8 s, 5 m of reserve, DNF 6 %, the runner right behind goes down too 30 %); the one
  ahead is spiked 3 %. A rival who falls is out 1–3 weeks with 12 % (50 % after a DNF). Front running is safest: only
  the runner on someone's heels is at risk (the leader only when clipped from behind).
- **Race injuries (GDD 4.6):** the fall / spike comes from the race's RNG (`RaceDay.incidents` → the race day's
  record); the injury is rolled after the race day by the health model with its own saved dice, so a saved game goes
  on bit for bit (the race itself, as before, runs on the race day's own fresh RNG and is never saved half-way).
- **DNF / DQ:** `status` dnf / dq, time 0, listed after the finishers (DQ before DNF); never a PB, season best,
  qualifier, rival PB; the result screen shows – and DNF / DQ ("Did not finish", "Disqualified (obstruction)"), the
  report line DNF / DQ (+ "You fell." / "You were spiked."), Overview and day editor DNF / DQ.
- **Heats:** in a heat (2 automatic places) a runner in an automatic place ≥ 3 m clear of the first runner outside
  them eases to 0.95 × speed in the last 30–50 m. Not in finals.
- **Event list** (`Race.events`, for R4): start, break_leader, pace (200 / 400 / 600: split, % vs the field's even
  pace, front group, spread), pack (300 / 500), move, cover, let_go, dropped, boxed, escape (way, seconds), gap_opens,
  contact (where), stumble, fall, brought_down, dnf, dq, spiked, lead_change (after ≥ 2 s), kick (answer_to),
  kick_dying, ease, close_finish (< 0.3 s) / photo_finish (< 0.05 s), finish; each with who, runner index, player,
  metres run, place and gap to the leader. Debug builds print them to the Output panel while a race is watched.
- **Shapes:** tactical lap 1 0.88–0.92 (decision 11), lap 2 1.01–1.03 (was 1.00–1.02; Claude: keeps the finals on the
  table). **`cs_scale` 1.017** (was 1.003).
- **Measured after** (`race_shape.gd -- 100`, same rows and seed; R1 in brackets; "no tactics" = the gaps if
  everyone ran their even time for the day):

| Row | 1st→last 200/400/600 m | 1st→4th at 400 | Within 5 m at 400 | Leader at 400 / 600 wins | r 400 / 600 | Finish 1st→2nd / 4th / last | No tactics | Won by < 0.2 s | Time / table |
|---|---|---|---|---|---|---|---|---|---|
| Youth even field | 15 / 32 / 47 (15 / 32 / 51) | 9 (7) | 2.9 (3.4) | 62 / 68 % (61 / 66) | 0.83 / 0.91 (0.86 / 0.90) | 1.8 / 6.0 / 14.9 s (2.0 / 5.9 / 16.4) | 2.7 / 6.7 / 15.7 | 8 % (11) | 0.998 (0.996) |
| Youth local meet, wide | 27 / 57 / 89 (27 / 55 / 85) | 14 (12) | 2.9 (3.1) | 59 / 64 % (54 / 65) | 0.93 / 0.95 (0.90 / 0.93) | 2.3 / 8.7 / 28.2 s (2.4 / 8.3 / 27.9) | 4.2 / 12.1 / 32.2 | 5 % (12) | 0.997 (1.002) |
| Youth championship final | 7 / 17 / 29 (7 / 16 / 28) | 4 (4) | 4.9 (5.1) | 49 / 61 % (29 / 39) | 0.59 / 0.84 (0.59 / 0.76) | 1.3 / 3.4 / 9.4 s (0.7 / 3.0 / 9.5) | 1.9 / 4.4 / 11.1 | 13 % (24) | 1.004 (1.002) |
| Youth indoor | 15 / 31 / 48 (16 / 33 / 52) | 10 (10) | 3.1 (2.8) | 60 / 68 % (60 / 71) | 0.80 / 0.90 (0.79 / 0.87) | 1.8 / 6.0 / 14.8 s (2.3 / 6.6 / 17.0) | 2.2 / 6.0 / 16.8 | 8 % (7) | 1.015 (1.014) |
| Girls even field | 15 / 31 / 47 (14 / 29 / 44) | 9 (7) | 3.0 (3.4) | 70 / 66 % (49 / 53) | 0.85 / 0.91 (0.83 / 0.87) | 2.0 / 5.9 / 15.8 s (1.7 / 5.4 / 15.7) | 2.6 / 6.8 / 18.1 | 7 % (10) | 0.997 (1.001) |
| Senior national final | 6 / 13 / 23 (5 / 11 / 19) | 4 (3) | 5.0 (5.6) | 45 / 46 % (34 / 46) | 0.52 / 0.75 (0.52 / 0.73) | 0.6 / 2.0 / 5.9 s (0.7 / 2.1 / 5.6) | 0.9 / 2.5 / 6.3 | 25 % (25) | 1.004 (1.001) |
| 8 identical runners | 3 / 7 / 11 (3 / 6 / 12) | 3 (2) | 5.6 (6.1) | 44 / 54 % (26 / 44) | 0.45 / 0.65 (0.44 / 0.73) | 0.6 / 1.7 / 4.7 s (0.5 / 1.7 / 4.5) | 0.5 / 1.6 / 3.7 | 20 % (27) | 1.005 (1.001) |
| *New:* senior final, consistent field (15 ± 0.25, consistency 13 ± 3) | 5 / 10 / 17 | 3 | 5.3 | 35 / 43 % | 0.48 / 0.69 | 0.5 / 2.0 / 4.8 s | 0.7 / 1.7 / 4.9 | 20 % | 1.006 |

  Winner's laps by shape (youth final): fast 67.2 + 67.4, honest 68.0 + 66.4, tactical 75.4 + 63.6 s. Per race (youth
  final): 0.9 moves, 1.7 let go, ~10 covers (moves and kicks), 4.0 contacts, 0.7 stumbles.
- **Targets:** time / table within ±0.5 % in every outdoor row ✓ (0.997–1.005; indoor 1.015, slower by design); youth
  championship final 1.3 / 3.4 / 9.4 s ✓; even finals ≥ 4 within 5 m at 400 ✓ (4.9 / 5.0); leader at 400 wins 49 % /
  45 % ✓ (30–50); r 0.59 / 0.84 (youth) ✓, 0.52 / 0.75 (senior, a little low as in R1); wide local fields strung out
  ✓ (28.2 s). **Senior final not met** (0.6 / 2.0 / 5.9 s, 25 % under 0.2 s; targets 0.1–0.5 / 0.7–1.5 / 3–5.5,
  30–60 %): decision 12, step 7. Even the consistent field gives 2.0 s to 4th (no tactics 1.7 s): the engine does not
  squeeze a field's ability differences in the final 200 m (only tactical races do: senior tactical 1st→4th 1.4 s vs
  fast / honest 2.6–2.9 s), so a real-looking senior final needs both a tighter day spread and that question again
  in step 7 / R5.
- **Falls:** bunched finals (youth final, senior final, identical field together) **1 per 96 runner-races** ✓
  (target 60–100; senior alone 1 per 73); the other, more strung-out rows 1 per ~170. DNF ≈ 6 % of falls; DQ 0–1 per
  100 races.
- **Upsets** (`race_shape.gd -- 100 duel…`: runner A stronger by Δ, B; 6 others around them, an even final; A's bad
  race = leads at 1.07 × own even pace / waits boxed at the back / kicks from 400 m; B's good race = perfect feel,
  race tactics 20 for decisions, sits in the pack, kicks from 200, eases out of boxes):

| Δ | B beats A, both neutral | A bad + B good (leads too fast / waits boxed / kicks from 400) | Target |
|---|---|---|---|
| 0.5 | 37 % | 40 / 34 / 39 % | 45–55 % (vs ≈ 30 % neutral) |
| 1 | 25 % | 17 / 18 / 21 % | 20–30 % |
| 2 | 4 % | 3 / 3 / 8 % | under 5 % |

  A bad race against A's good race costs −0.9…+0.5 % of time (relative to the rest of the field), about 0 on average
  over the nine cases (waiting boxed +0.1…+0.5 % is the only one that always costs); B's good race −0.2 %. Target
  0.5–1 %. **Not met: Δ 0.5 and good vs bad** (decision 13: tuned again in R5 with the player's cards and action
  bar); Δ 1 and Δ 2 near their targets. Why: a strong runner in a slower field can't use their whole reserve in a
  capped kick, so leading hard (Δ 2: −0.9 %) or kicking long is not automatically a bad race for them; with the R1
  straight-line drain leading too fast helped even at Δ 0.5 (−0.75 %).
- **`race_balance.gd`** (median vs anchor): girls −0.8…+0.3 s (40 races per row), boys −0.5…0.0 s (80 per row; at 40
  the 12-race noise put ability 9 at −1.1 s), indoor +1.8…+2.7 s (R1 +2.1…+3.0, slower by design).
- **Speed:** ~0.5 s per race headless (R1 ~0.4; neighbour searches use the step's order, insertion-sorted standings,
  cached numbers): at a championship the other heats take ~2 s after the player's heat.
- **Checks:** new `tools/race_check.gd` (plans × answers incl. quick mode: no stuck race, every old card per plan;
  rare incidents with raised rates; heats easing only in heats; every event type with its fields); `day_engine_check`
  + DNF / DQ results (recorded, no PB / SB, DNF / DQ texts, save / load) and repeatable events; `health_check` + race
  injuries (tables, fall → mostly grazes, spike → spike wound, same dice → same injury, a fall on race day → the
  diagnosis, rival out_weeks only with the health model on); help `race_running` and `race_result` v2.

**Built (step R3, 2026-10-08): the player's controls.** Engine in `Race` (`scripts/core/race.gd`), texts in
`data/race_cards.json` (cards, the lines the choices put in the commentary, the coach's shouts), every number in
`data/races.json` `controls`, UI in `scripts/ui/race_action_bar.gd` and `scripts/ui/race_screen.gd`. Decisions 14–16 above.
- **Cards** (replace the fixed decision points; first built with at most 6 per race, since the follow-up 10 as a safety
  valve only, `controls.cards`): *break*, *bell / halfway* and the
  *kick card* always (3 places in the budget, kept free); then, most important first (`priority`): a **fall** (when the
  player is back on their feet), **boxed in while a move goes** (boxed at least 0.8 s and a rival surging / kicking from
  5 m behind to 30 m ahead, or the player's own move), a **rival move** (the engine's reaction zone: a surger from 15 m
  ahead to 2 m behind, a kicker near the front from 12 m ahead to 3 m behind), the **home straight** (700 m run, a runner
  within 2.5 m ahead), **losing contact** (5–30 m behind the runner ahead for 1 s, more than 150 m to go), a **slow
  pace** (the leader slower than 0.96 × the field's even speed, 150–400 m run, the player in the first 4 and within 15 m).
  Optional cards: at least 8 race seconds apart (a fall ignores that), a kind at most 2 / 1 times, "losing contact" only
  while fewer than 5 cards were shown and "slow pace" while fewer than 4, so the low-priority ones leave room. A card the
  budget refuses is not asked and the engine decides as before (a rival's roll). The race waits while a card is open.
- **What each answer does** (checked state by state in `race_check.gd`): break: lead / pack / back = the place the
  player wants; bell: Push / Hold / Ease = pace × 1.03 / 1.00 / 0.97 until the kick (the same switch as the bar); kick
  card: Kick now starts the kick, Wait kicks with 100 m to go and answers no other kick until then; move: *Go with them*
  covers the surger (the surger's speed, up to 1.08 ×, digging 0.3 deeper) or goes with a kicker (covers until their own
  kick point, or kicks at once when they are at it), *Let them go* holds back until the surge is over, *Counter-attack*
  = their own surge (1.08 × for 120 m) or their own kick now; box: Wait / Ease and step out / Push through = the way out
  (as the rivals', R2); losing contact: *Dig in* digs 0.3 deeper (even though dropped), *Run your own pace* does not;
  slow pace: *Take the lead* = wants the lead + Push, *Stay put*; home straight: as before; fall: *Get up and chase* digs
  0.5 deep + Push, *Finish steady* = Ease and kick from 150 m.
- **Action bar** (`Race.command`, no pause): Push / Hold / Ease set the pace factor until the kick (the active one lit;
  the bell card sets the same); **Move out** = 5 s one lane further out (at most 3 m from the rail) going for a pass,
  2 % faster than the runner ahead when they can afford it; boxed in with "wait" it becomes "ease and step out"; not
  offered in the lanes, once kicking it only moves out, and not when already 3 m or more out; **Kick now** starts the kick
  at once (after the break); in the UI two taps within 2 s ("Tap again to kick", phone: "Tap again"). While kicking,
  Push / Hold / Ease are dimmed and the Kick button reads "Kicking!". PC: one row under the track; phone: Push / Hold / Ease / Kick now + a
  full-width Move out row, fixed under the clock, never scrolling away.
- **Feeling** under the clock: the share of the reserve the player *feels* they have left (misjudged by their race
  tactics, so it can be wrong) minus 0.003 per fatigue point above 25: Comfortable ≥ 0.6, Working ≥ 0.3, Hurting ≥ 0.1,
  Empty below. At the bell the mean felt share is 0.48–0.56, at the kick card 0.24–0.30.
- **Drop to 1x** (race screen): at 2x / 4x a move, kick, contact, stumble, fall or brought-down within 20 m of the player,
  or the player's own box (rivals' boxes are everywhere in a pack and don't count), holds the race at 1x for 5 race
  seconds ("SLOWED TO 1x" under the Feeling word), then back to the chosen speed. Measured: 16–36 % of a race's time.
- **Coach**: `coach_sees()` and `_coach_line`; the shout in an accent-coloured block on the card ("COACH"); his dice come
  from the race's state but not from its stream, so watching does not change the race. Outdoors he is silent on 36–41 %
  of the cards (the bell, mostly), indoors never; right 78–84 % (data 80 %). **R4** moves the spot to the real one.
- **Quick mode**: the same cards and the same engine, answered by the athlete: the sensible answer with a chance from 45 %
  (race tactics 1) to 90 % (20), otherwise any answer (`controls.auto`); no bar. `Race.sensible_choice(card)` (numbers in
  `controls.sensible`) is also the coach's advice and the "sensible watched player" of the tools. Break: the pre-race plan.
- **Measured** (`tools/race_watch.gd`, the same 80–100 races played four ways from the same field and dice; player
  race tactics 10; average place of the player, 1 = best):

| Config | quick | sensible answers | coach's shouts | poor answers | cards / race | at 1x |
|---|---|---|---|---|---|---|
| Youth final, player a little stronger | 3.64 | 3.59 | 3.62 | 3.64 | 5.1 | 29 % |
| District meet, wide field | 3.08 | 3.12 | 3.07 | 3.16 | 4.7 | 16 % |
| Girls even field | 4.68 | 4.71 | 4.71 | 4.90 | 5.0 | 20 % |
| Senior final | 4.61 | 4.67 | 4.70 | 4.71 | 5.2 | 35 % |
| Indoor heat | 4.19 | 4.26 | 4.25 | 4.26 | 5.1 | 25 % |

  **Sensible vs quick: within ±0.1 places (target: at most about 1) ✓** — watching with sensible answers is no better
  than the athlete's own. **Not met, for R5:** sensible vs *deliberately poor* answers (anything but the sensible one:
  leading at the break, countering, pushing at the bell, kicking early, pushing through boxes) differ by only 0.00–0.19
  places and 0.0–0.4 s (e.g. 138.75 vs 138.89 s; girls 166.08 vs 166.42 s), against the target of a good vs a bad race ≈
  0.5–1 % of time (1–2 places). The answers change the engine (checked state by state) but mostly *move* effort from one
  part of the race to another (a push at the bell is paid back in the kick), so the finishing time hardly changes: R5
  has to make the mistakes cost more (see the realism review below).
- **Checks:** `race_check.gd` (ALL PASSED, ~300 races + rare incidents: ≤ 6 cards, break / bell once, every card comes up,
  every answer of all 9 cards tried and the state right after it correct, the bar's commands, Feeling's four words,
  the coach rule both laps and his accuracy, the slow-motion events, quick mode answers everything, same seed → same
  cards), `help_check` (477), `layout_check` (5 sizes × outdoor and indoor × bar / "Tap again" / card with the coach's
  shout / "slowed to 1x" / result: no OVERFLOW / SQUEEZED), the tour (PC and phone), `race_perf` (PC indoor 4x: 15–17 ms a
  frame; phone outdoor 4x: 16.7–17.6 ms; a few start-up frames over 33 ms like before), `day_engine_check`, `health_check`,
  `form_check`, `rankings_check`, `training_balance -- 0` (fingerprints identical), `race_shape.gd` rows 2 and 5 at
  100 races **identical to the digit** to before R3 (nothing changed for runners without a player).
- **Realism review (2026-10-08, of everything built so far; no changes made, for R5):**
  - ✓ Times: the median race time is on the time table within ±0.5 % outdoors; youth final gaps 1.3 / 3.4 / 9.4 s vs real
    1.1 / 3.5 / 11.9 s; wide local fields strung out; ~5 cards and 1–2 moves a race; the Feeling numbers fit the kick (a
    200–250 m kick needs 25–31 % of the reserve and the kick card finds 24–30 %).
  - ✗ **Lap splits:** the winner's laps (R2 table) are 67.2 + 67.4 (fast), 68.0 + 66.4 (honest) and 75.4 + 63.6 s
    (tactical) in a youth final: the *honest* race is a 1.6 s negative split, while world medallists run the first lap
    2.2 ± 1.1 s *faster* (Renfree / GDD 4.3.1 above), and a tactical race a 12 s negative split, where real tactical
    youth finals are mostly 3–6 s. With the finals mix (20 / 35 / 45) the average final is a ~6 s negative split. Cause:
    lap 1 carries the 1.5 s standing start, and the honest lap-1 factors (+1–2 % of even speed) don't make up for it.
  - ✗ Senior final finish too spread (known, decision 12, step 7).
  - ~ Contacts 4 a race, stumbles 0.65 a race, falls 1 per 73–96 runner-races in bunched finals: inside the targets
    (60–100), but at the high end of what elite 800 m races show (about 1 fall per 200).
  - ✗ **The answers hardly matter** (above): a clever player gains nothing over the athlete, a careless one loses nothing.

**Follow-up to R3 (2026-10-08): mistakes cost, realistic splits** (decisions 17–19; the rival engine changes below
change the R2 rows, which the user allowed).
- **Why the answers did not matter** (`tools/race_value.gd`, new: each answer of a card played against the sensible
  answer from the same moment): the energy rule was almost neutral for the ±3 % pace changes of the cards (a push is
  paid back in the kick), the speed cap that protects every runner's kick also protected the player from their own
  commitments, a kick from far out was computed to arrive exactly empty, and moves did not matter. Measured before:
  push / ease at the bell ±0.01 s, going with a move +0.2 s, digging in +0.3 s, bad vs good race 0.1–0.2 % of time.
- **What changed** (data in `races.json`; the commit and early-kick rules touch only the player, the rest all runners):
  1. **Energy exponent 3 → 5** (decision 13 revised): faster than your own even pace costs much more, slower saves little.
     Duel rows (`race_shape.gd -- 100 duel1`): leading 7 % too fast went from −0.2 % (it paid) to **+1.06 %** of time.
  2. **Committing answers** (Go with them, Dig in, Get up and chase) switch off the speed cap for the length of the
     move / 150 m / the rest of the race (`commit_left`, `controls.commit`): you run what the move demands until the
     reserve is gone, then tie up. Digging in with 250–400 m to go costs **+1.2 s (0.9 %)** and 0.6 places.
  3. **A kick started earlier than the player's own kick point** runs faster than the felt reserve can hold and dies
     before the line (`controls.kick_early`, 0.08 % of speed per metre earlier, from 30 m; measured with a scratch tool over 30 races:
     a kick from 470 m to go costs **+1.6 s** (≈ 1 %), from 350 m −0.1 s: a grinder's long kick is a real tactic, only a
     kick from far out is a mistake). At their own point it is exact, so ordinary races keep their times. (Even with
     per-metre overshoot 0.012 % the early kick had *saved* 0.5 s: in this energy model an even effort is the cheapest.)
  4. **Letting a move go** means closing on the field only slowly until your own kick (`moves.let_go_close` 1.0).
  5. **Counter-attack** is a +12 % surge for 150 m (was +8 % for 120 m): early it costs, near the end it can pay.
  6. **Kick reserve** held back for the kick `kick_need_per_100` 0.125 → 0.07, **`cs_scale` 1.029**, and the **fast /
     honest lap factors** 1.055–1.075 / 0.945–0.965 and 1.035–1.045 / 0.955–0.975 (were 1.03–1.05 / 0.97–0.99 and
     1.01–1.02 / 0.98–1.00): runners stop banking so much for the kick and the first lap is run faster.
- **Lap splits** (winner's laps, youth final, then senior final): fast 65.4 + 67.8 / 53.9 + 55.9 s (**+2.4 / +2.0 s**
  positive split, was −0.2 / +0.4), honest 65.7 + 68.3 / 54.0 + 55.4 s (**+2.6 / +1.4 s**, was −1.6 / +1.1), tactical
  74.8 + 64.0 / 60.6 + 52.1 s (−10.8 / −8.5 s, unchanged: decision 11). Real medallists: +2.2 ± 1.1 s.
- **Rows** (`race_shape.gd -- 100`; R2 in brackets; 1st→last at 200 / 400 / 600 m | 1st→4th at 400 | finish 1st→2nd /
  4th / last | time / table):

| Row | Gaps | 1st→4th | Finish gaps | Time / table |
|---|---|---|---|---|
| Youth even field | 16 / 34 / 46 (15 / 32 / 47) | 12 (9) | 2.0 / 6.5 / 15.4 s (1.8 / 6.0 / 14.9) | 0.9985 (0.998) |
| Youth local meet, wide | 29 / 59 / 87 (27 / 57 / 89) | 17 (14) | 3.0 / 9.3 / 27.9 s (2.3 / 8.7 / 28.2) | 0.997 (0.997) |
| Youth championship final | 8 / 19 / 28 (7 / 17 / 29) | 7 (4) | 1.1 / 3.6 / 10.0 s (1.3 / 3.4 / 9.4) | 1.0077 (1.004) |
| Youth indoor | 18 / 37 / 52 (15 / 31 / 48) | 14 (10) | 2.6 / 7.9 / 17.3 s (1.8 / 6.0 / 14.8) | 1.0156 (1.015) |
| Girls even field | 16 / 34 / 46 (15 / 31 / 47) | 12 (9) | 2.2 / 6.8 / 17.0 s (2.0 / 5.9 / 15.8) | 0.9984 (0.997) |
| Senior national final | 7 / 15 / 22 (6 / 13 / 23) | 6 (4) | 0.7 / 2.3 / 6.1 s (0.6 / 2.0 / 5.9) | 1.0065 (1.004) |

  Youth final targets still met (1.1 / 3.6 / 10.0 s vs 0.6–1.5 / 2.5–4.5 / 9–15); the senior final stays too spread
  (decision 12, step 7). Falls in bunched finals 1 per 73–89 runner-races (target 60–100). `race_balance.gd` medians
  within ±1 s of the anchors outdoors (male 5 → 13: +0.6, +0.9, −0.3, 0.0, 0.0 s; female ≤ ±0.6 s).
- **What the answers are worth now** (`race_value.gd`, youth final, 200–250 races; time / places against the sensible
  answer): push at the bell +0.25 s / +0.21 places, hold +0.12 s, ease ≈ 0; going with a move > 400 m out +0.35 s /
  +0.22 places while letting it go −0.34 s / −0.18; counter-attack > 400 m out +0.53 s / +0.30 places, at 250–400 m
  −0.17 s; boxed: pushing through +0.2–1.3 s, easing back +0.3–2.6 s, waiting best at every distance; kick: waiting for
  the straight +0.47 s when you have the reserve for it. The sensible answers (and so the coach's advice) were reset to
  these findings: ease at the bell unless fresh (felt ≥ 0.75), let moves go unless the mover out-kicks you and you can
  afford it, dig in only within 10 m of the pack with ≥ 0.6 left, wait when boxed.
- **Measured with `race_watch.gd`** (100 races per mode, average place; time in seconds):

| Config | quick | sensible | coach | poor answers | poor − sensible |
|---|---|---|---|---|---|
| Youth final, player a little stronger | 3.67 | 3.88 | 4.00 | 3.98 | +0.10 places, +0.37 s |
| District meet, wide field | 3.29 | 3.21 | 3.28 | 3.41 | +0.20 places, +0.71 s |
| Girls even field | 5.06 | 4.92 | 4.91 | 5.38 | +0.46 places, +1.56 s |
| Senior final | 4.77 | 4.74 | 4.78 | 5.02 | +0.28 places, +0.56 s |

  Sensible vs quick: −0.21 … +0.14 places (noise level at 100 races; target: at most about 1 ✓). **A bad race now costs
  0.3–0.9 % of the time (target 0.5–1 % ✓)** but only 0.1–0.5 places, because the player's place also depends on who
  is in the race. Cards per race 5.2–6.0 (max 10), 16–35 % of the time at 1x.
- **Why the user won:** (user's save, 10 Jan 2027, Hippoksen hallikisat 1st of 6 in 2:29.96) the athlete's 800 m
  ability had grown to 7.35, the **median of the 150 rivals** (47th percentile; pool 3.2–13.0, median 7.5); local meets
  draw their field from the weakest 80 % of the pool (`fields.local.pool_range` 0–0.8), so he met runners of 5.2–8.4
  and beat 7 of the 10 he has met. Winning one local race at the median is normal (≈ one in ten, more after a good
  training spell); the first sims were fresh 14-year-olds around ability 5–6, below the pool.

**Built (step R5, 2026-10-09): balance and playtest** (decisions 20–25; the rivals' engine changed, so every row below
moved; "before" = the R3 follow-up, measured again from a copy of the commit before R5 with the same tools).
- **No difficulty setting (decision 20):** nothing adapts to the player; fields still come from the meet's level. All
  changes below are the same rules for every runner.
- **Boxed in (decisions 22, 24):** *ease and step out* drops back at `ease_speed` 0.88 × the speed of the runner on the
  shoulder until the outside is clear and then steps out (the box lasts up to `ease_hold` 6 m behind the runner ahead):
  it costs a median **1.1 m** (boxes that cost over 0.5 m; mean 0.4 m), not 7 % of speed for as long as the box lasts
  (that rule cost 0.3–2.6 s). **Room** = the runner on the outside shoulder is at least `room_m` 0.5 m behind: *push
  through* with room is a nudge (contact 20 %, obstruction DQ 0.2 %), without room a shove (60 %, 1 %). *Wait*: a gap
  opens at `gap_rate` × `gap_bend` 0.25 on a bend (nobody drifts wide there). The best way (`box.best`, the coach's
  advice and quick mode): no room → wait, room → ease and step out, room in the last 100 m → push. Rivals take the best
  way with a chance from 30 % (race tactics 1) to 90 % (20), otherwise by habit (wait 1 / ease 0.5 / push 0.1 + grit).
  The box card says whether there is room (`{room}`: "There's half a gap on your outside." / "X is right on your
  shoulder."). The escape event reports `lost` (metres against the runner who was ahead). The action bar's Move out
  with a runner right beside the player now drops back a stride and steps out behind them (before it did nothing for
  the 5 s: 3 of 10 presses in `race_check`).
  Measured (`race_value.gd -- 800 box <config> back`: the box card is rare, ~140 cards in 800 races from the back;
  seconds against the then-advice, negative = better):

| Box card | wait | ease and step out | push through |
|---|---|---|---|
| Before (R3 follow-up, `race_value`) | best at every distance | +0.3…+2.6 s | +0.2…+1.3 s (incl. DQ as 200 s) |
| Youth final, no room (111 cards) | **−0.11** | +0.11 | +0.05 |
| Youth final, room (27) | −0.07 | **−0.53** | −0.35 |
| Tight final, no room (117) | **−0.05** | +0.16 | +0.46 |
| Tight final, room (24) | −0.15 | **−0.46** | −0.19 |
| Tight final, > 400 / 250–400 / < 250 m to go | **0 / −0.14 / −0.05** | +0.21 / 0 / +0.01 | +0.74 / +0.24 / +0.18 |

  None is a trap any more (worst ≈ 0.5 s); the room decides, the distance hardly (decision 24).
  **R2 box numbers, before → after** (`race_shape.gd -- 100`, per race; out by wait / ease / push; boxes lasting 2 s or
  more): youth even field 8.5 (5.8 / 2.3 / 0.3; 1.17) → 7.2 (5.7 / 1.2 / 0.2; 1.15); youth final 16.8 (11.8 / 4.1 / 0.8;
  2.85) → 16.4 (12.6 / 3.2 / 0.6; 2.21); senior final 16.8 (11.4 / 4.4 / 0.9; 2.88) → 16.5 (12.6 / 3.1 / 0.8; 2.53); 8
  identical runners 28.6 (19.3 / 8.1 / 1.1; 4.44) → 27.5 (21.4 / 5.1 / 1.0; 4.07). Most boxes last under half a second
  (median 0.1–0.3 s). DQ 0–2 per 100 races in every row (before 0–2).
- **Moves (decision 23).** Measured first (new `tools/race_moves.gd`: every rival surge, the runners who covered it or let
  it go, and the same race played again with that runner covering every move vs letting every move go): before, the
  mover finished ahead of those who let it go 55 % (tight final) / 71 % (even field) / 55 % (senior final) of the time,
  decided by who was stronger on the day (83–94 % when the mover was, 10–24 % when not), and **covering changed nothing**:
  the mover finished ahead equally often either way (61 / 62 %; close pairs 37 / 39 %) while covering cost +0.05…+0.39 s.
  Why: after the surge the mover settled straight back into the race's pace and the runners who let it go followed at
  that pace and closed the gap in their kick for free.
  **Built:** after their surge a mover **presses on** (`moves.drive`: 1.03 × the race's pace, at most their speed cap,
  past anyone slower) until their kick, while the cap is at least 1.005 × the pace; those who covered stay with them;
  those who let it go keep the race's pace (no chasing) while the move goes on, until their own kick. A mover who can't
  afford the drive settles back and is caught. Covering closes a gap at most `cover_max` 1.04 × the mover's speed (was
  1.08). `let_go_close` stays 1.0, the surge size 4–8 % for 50–150 m stays.
  **After** (tight final, the rivals' counterfactual, cover every move − let every move go; mover ahead covered / let go):

| Mover vs the runner reacting (day) | Before | After |
|---|---|---|
| Within 1 % | +0.20 s / +0.07 places; 37 % / 39 % | **−0.16 s / −0.27 places; 32 % / 48 %** |
| Over 1 % stronger | +0.48 s / +0.24; 97 % / 97 % | +0.47 s / +0.36; 98 % / 97 % |
| Over 1 % weaker | +0.36 s / +0.34; 10 % / 10 % | +0.44 s / +0.20; 9 % / 3 % |

  Robust in every row: a clearly stronger mover gets away either way (91–98 %) and covering their drive costs
  (+0.26…+0.51 s); a clearly weaker one is caught (let go: 3–11 % finish ahead). **Between equals it is not settled:** the
  tight final shows the decisive effect (the mover beats a let-goer 48 % vs 32 % covered, covering pays −0.16 s), but the
  youth final (44 close pairs: +0.46 s, 48 % / 41 %) and the senior final (65: +0.29 s, 60 % / 43 %) go the other way;
  ±0.3 s is the noise of these samples. Left for the playtest and R4 (the commentary will show moves and drives).
  Moves per race: youth final 0.99 → 0.70 (runners covering a drive don't surge), senior 0.82 → 0.87.
  **The player's move card** (`race_value.gd`, youth final / tight final, 150 races; going with a move commits the player,
  decision 17): against a mover over 1 % stronger on the day going costs +0.7…+1.2 s and letting go is right; within 1 %
  letting go is better by 0.1–0.3 s; against one over 1 % weaker letting them press on costs +0.2…+0.5 s, so going is
  right. Before, letting go was best in every bucket (going +0.2…+0.5 s, against a stronger mover −0.8 s for letting go).
- **Sensible answers reset (the coach's advice, quick mode)** from `race_value.gd`: box = the best way (above); move =
  go with a mover more than 1 % weaker on the day when you can afford it, let the others go (`go_edge` −0.01; was "the
  mover's kick is better"); dropped = dig in hardly ever (`dig_share` 0.9: digging in cost +0.5…+0.6 s in finals); slow
  pace = take the lead whatever your rank when you feel ≥ 0.7 (`slow_rank` 8, `slow_share` 0.7: leading gained ~0.5 s over
  staying put). Bell (ease), kick (now), straight (wide), fall: unchanged, still right.
- **Time and place are one thing (decision 21):** no place effect; `race_value` / `race_watch` got tight finals (field sd
  0.3, and sd 0.3 with consistency 15) and print DNF / DQ separately (a DQ used to count as 200 s).
- **Measured with `race_watch.gd`** (100 races per mode; average place, time of finished races; poor = never the sensible
  answer; before in brackets):

| Config | quick | sensible | coach | poor | poor − sensible |
|---|---|---|---|---|---|
| Youth final, player a little stronger | 3.73 (3.68) | 3.49 (3.88) | 3.59 (4.00) | 4.03 (4.05) | +0.54 places, +1.28 s, 0.92 % (+0.17, +0.39 s, 0.28 %) |
| District meet, wide field | 3.13 (3.28) | 2.97 (3.21) | 3.14 (3.28) | 3.81 (3.44) | +0.84, +2.97 s, 2.0 % (+0.23, +0.77 s, 0.52 %) |
| Girls even field | 4.84 (5.07) | 4.54 (4.92) | 4.53 (4.91) | 5.61 (5.42) | +1.07, +2.96 s, 1.8 % (+0.50, +1.68 s, 1.00 %) |
| Senior final | 4.64 (4.82) | 4.45 (4.74) | 4.64 (4.78) | 5.14 (5.13) | +0.69, +1.13 s, 1.0 % (+0.39, +0.62 s, 0.55 %) |
| Indoor heat | 4.10 (4.26) | 3.99 (4.05) | 4.10 (4.25) | 4.75 (4.68) | +0.76, +2.08 s, 1.4 % (+0.63, +1.28 s, 0.87 %) |
| Tight final (sd 0.3) | 4.71 (5.00) | 4.60 (4.80) | 4.52 (4.80) | 5.28 (5.30) | +0.68, +1.50 s, 1.1 % (+0.50, +1.12 s, 0.79 %) |
| Tight final, consistent field | 4.76 (5.17) | 4.56 (4.96) | 4.58 (4.84) | 5.44 (5.38) | +0.88, +1.78 s, 1.3 % (+0.42, +1.21 s, 0.86 %) |

  Sensible vs quick: within 0.1–0.3 places (target: at most about 1 ✓); the sensible watched player is now the best
  of the four (before the athlete's own quick answers beat it in the youth final). A watched race with every answer
  wrong costs 0.9–2.0 % of time and 0.5–1.1 places (before 0.3–1.0 %, 0.2–0.6 places); in the tight finals 1.5–1.8 s ≈
  0.7–0.9 places. (Every answer wrong is the worst case; one bad race in the duel rows costs 0.5–1.0 %, decision 8.) Cards per race 5.3–5.9, 15–29 % of the time at 1x.
- **What the answers are worth now** (`race_value.gd -- 100 all`, youth final / tight final, against the sensible
  answer; before in brackets, against the R3 advice):
  - *bell:* push +0.36 / +0.72 s (+0.20 / +0.75), hold +0.13 / +0.23; ease (the advice) right;
  - *kick card:* wait for the straight +0.19 / +0.13 s (+0.12 / +0.19); kick now right;
  - *move, mover over 1 % stronger on the day:* go +0.95 s, +0.78 places / +0.71 s, +0.16 (before going was the advice
    for a better kicker: then letting go was −0.77 / −0.28 s better); *within 1 %:* go −0.12 s / +0.02 s against letting
    go (three runs: ±0.25 s either way, an even call); *over 1 % weaker:* letting go +0.31 s, +0.17 places / +0.16 s,
    +0.28 (going is right); *counter-attack* > 400 m out +1.97 / +1.91 s (+0.64 / +0.91), under 250 m about even;
  - *dropped:* dig in +0.92 / +0.30 s (+0.67 / +1.08): run your own pace;
  - *slow pace:* take the lead −0.36 / −0.35 s against staying (measured before the reset; now the advice);
  - *break:* "back" −0.20 / −0.05 s and −0.08 / −0.14 places against the plan "shoulder" (−0.31 / −0.19 before): the
    break answer is the player's own plan, left as it is (playtest point 6 below);
  - *box:* see the box table above; *straight:* wide / inside within 0.05 s.
  With the R5 advice no answer beats the sensible one by more than noise, and the worst answers (counter-attacking early,
  going with a much stronger mover, pushing the bell lap) cost 0.7–2 s.
- **Upsets and good vs bad** (`race_shape.gd duel…`; the box mistake is now "sits at the back and pushes out of every
  box", since waiting is right without room; B's and A's good race take the best way out):

| Δ | B beats A, both neutral | A bad + B good (leads too fast / pushes out of boxes / kicks from 400) | A's bad vs good race | Target |
|---|---|---|---|---|
| 0.5 (300 races) | 31 % (37 %) | 38 / 28 / 34 % (42 / waits boxed 38 / 46 %) | +1.02 / −0.02 / +0.50 % | 35–45 % (decision 25) |
| 1 | 27 % (24 %) | 24 / 22 / 25 % (28 / waits boxed 15 / 23 %) | +1.02 / +0.36 / +0.45 % | 20–30 % ✓ |
| 2 | 3 % (1 %) | 4 / 2 / 5 % (3 / waits boxed 1 / 3 %) | +0.85 / +0.52 / −0.05 % | under 5 % ✓ (5 % at the edge) |

  **Decision 25 (user, 2026-10-09):** a good vs bad race stays worth 0.5–1 % of time (decision 8); the Δ 0.5 upset
  target becomes **35–45 %** (was 45–55 %: with a neutral 31 % and the day-to-day spread of A − B ≈ 5 s, B winning 45–55 % needs a
  bad race to cost 1.3–1.8 %). Leading too fast and kicking from 400 m are inside 0.5–1 % ✓; a box mistake costs about
  nothing now (none is a trap, decision 22).
- **Rows** (`race_shape.gd -- 100`, the 8 rows; before → after):

| Row | 1st→last 200/400/600 m | 1st→4th at 400 | Within 5 m at 400 | Leader at 400 / 600 wins | r 400 / 600 | Finish 1st→2nd / 4th / last | < 0.2 s | Time / table |
|---|---|---|---|---|---|---|---|---|
| Youth even field | 16/34/46 → 16/35/48 | 12 → 13 | 2.7 → 2.6 | 60/73 → 64/71 % | 0.80/0.90 → 0.83/0.89 | 2.0/6.5/15.4 → 2.3/6.6/16.7 s | 6 → 9 % | 0.9985 → 0.9987 |
| Youth local meet, wide | 29/59/87 → 28/58/84 | 17 → 16 | 2.5 → 2.3 | 65/76 → 71/73 % | 0.91/0.94 → 0.89/0.95 | 3.0/9.3/27.9 → 2.6/9.2/27.5 s | 7 → 4 % | 0.9970 → 0.9984 |
| Youth championship final | 8/19/28 → 9/20/32 | 7 → 8 | 4.4 → 4.0 | 40/59 → 51/70 % | 0.51/0.77 → 0.60/0.80 | 1.1/3.6/10.0 → 1.4/4.1/10.4 s | 14 → 10 % | 1.0077 → 1.0046 |
| Youth indoor | 18/37/52 → 17/36/51 | 14 → 14 | 2.6 → 2.4 | 74/83 → 68/75 % | 0.82/0.90 → 0.79/0.86 | 2.6/7.9/17.3 → 2.7/7.6/16.9 s | 8 → 6 % | 1.0156 → 1.0157 |
| Girls even field | 16/34/46 → 17/34/47 | 12 → 11 | 2.6 → 2.8 | 61/69 → 61/67 % | 0.82/0.88 → 0.79/0.89 | 2.2/6.8/17.0 → 2.0/6.1/16.0 s | 5 → 4 % | 0.9984 → 0.9975 |
| Senior national final | 7/15/22 → 6/14/22 | 6 → 5 | 4.5 → 4.8 | 44/63 → 44/57 % | 0.52/0.75 → 0.47/0.69 | 0.7/2.3/6.1 → 1.0/2.5/6.3 s | 15 → 19 % | 1.0065 → 1.0093 |
| 8 identical runners | 5/12/16 → 4/10/14 | 4 → 3 | 5.0 → 5.1 | 45/56 → 31/48 % | 0.40/0.67 → 0.42/0.65 | 0.5/1.9/4.9 → 0.6/1.8/5.0 s | 15 → 23 % | 1.0054 → 1.0064 |
| Senior final, consistent field | 4/11/15 → 6/14/20 | 4 → 5 | 5.1 → 4.4 | 34/46 → 41/48 % | 0.40/0.65 → 0.49/0.67 | 0.6/1.8/5.2 → 0.8/2.2/5.2 s | 16 → 18 % | 1.0083 → 1.0071 |

  **Targets:** youth final 1.4 / 4.1 / 10.4 s ✓ (0.6–1.5 / 2.5–4.5 / 9–15); leader at 400 wins 51 % (youth final, a
  little over 30–50; was 40 %); falls in the bunched finals (youth final, senior final, identical) 27 in 2 400
  runner-races = **1 per 89** ✓ (60–100; before 1 per 73); winner's laps (youth final) fast 65.7 + 68.7 (+3.0 s), honest
  66.2 + 67.9 (+1.7 s), tactical 74.5 + 63.9 (decision 11); senior fast / honest +1.7 s each: positive splits ✓. **Time /
  table:** every youth row within ±0.5 % ✓ (0.9975–1.0046; the youth final was 1.0077 before); the senior rows 1.0064–1.0093
  (before 1.0054–1.0083) are not: the outdoor rows span 1.2 % (fast-heavy district mixes ~0.998, tactical-heavy finals
  ~1.005–1.009), so one `cs_scale` can't put both ends inside; `cs_scale` stays 1.029 and the senior finals go to step 7
  with decision 12. `race_balance.gd -- 60` (median − anchor, ability 5 / 7 / 9 / 11 /
  13): boys +0.15 / +0.10 / 0.00 / −0.75 / +0.43 s (before +0.50 / −0.09 / +0.04 / +0.16 / +0.51), girls +0.60 / +0.35 /
  +0.04 / +0.11 / 0.00 s (before +0.55 / +0.03 / +0.06 / −0.11 / +0.18): within ±1 s ✓.
- **Tools:** new `tools/race_moves.gd` (moves: observed + counterfactual, by the mover's edge), new `tools/watch_race.gd`
  (playtests: a new career straight to an indoor / outdoor race, with heats if asked, saves in `user://tool_saves/`);
  `race_value.gd` (configs 5–6 tight finals, a plan argument, `card+card`, DNF / DQ apart, move buckets by the mover's
  edge and distance, box buckets by room), `race_watch.gd` (configs 5–6, DNF / DQ apart, poor − sensible in s and %),
  `race_shape.gd` (what a box cost by way; duel "pushes boxed"; B's good race takes the best way), `race_check.gd` (R5
  boxes: the best way, easing costs a few metres, the room line on the card; the rare-incident check knows the
  [no room, room] numbers). Help `race_running` v5 (moves, boxes) and `race_result` v3.
- **Playtest plan (the user, watched):** `tools/watch_race.gd` starts a new career in a separate save folder and takes
  you straight to a race: `-- indoor any` (a small hall meet), `-- indoor heats` (district indoor final day, 30 Jan
  2027), `-- outdoor any`, `-- outdoor heats` (Youth Athletics Games, 17 Jun 2027); `ability=9` makes the athlete a
  youth finalist so the races are close; `--resolution 390x844` before `-s` for the phone. Six races: indoor any + indoor
  heats on PC, outdoor heats (heat and final) on the phone, outdoor any on PC twice (once following the coach, once
  doing the opposite). Look for: (1) does a box card say "room" or "right on your shoulder", and does the answer it
  suggests feel right; (2) when a rival surges and presses on, do the ones who let it go fall away, and does a weaker
  mover come back; (3) does Move out always do something; (4) does the "SLOWED TO 1x" reason match what you see; (5) does
  the coach's shout feel sensible (it is right ~80 % of the time); (6) is sitting at the back too good (measured: at the
  break "back" beats "shoulder" by 0.2–0.3 s in finals; not changed in R5); (7) anything that looks unrealistic.
- **Checks:** `race_check` ALL PASSED (+ the R5 box checks: easing out of boxes lasting 1 s or more costs a median 1.2 m,
  90 % under 3.4 m; Move out 9 of 10), `help_check` (479), `day_engine_check`, `health_check`, `form_check` all passed
  with clean stderr; `rankings_check` fills its list; `training_balance.gd -- 0` fingerprints identical (215.999957139 /
  13.751549603 / 1203.029795007); `layout_check` (5 sizes, no OVERFLOW / SQUEEZED); `race_perf` 60 fps (PC indoor 4x
  16.7–17.1 ms a frame, phone outdoor 4x 16.7–17.0 ms; a few single frames over 33 ms as before); `watch_race.gd`
  reaches outdoor heats (17 Jun 2027) and indoor heats (30 Jan 2027, phone size).

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
- **Race falls (GDD 4.3.1, step R2):** the race engine decides that the athlete fell or was spiked (the race's own
  dice); after the race day the health model rolls what it did with its own saved dice (`health.json`
  `race_incidents`): a fall is grazes (45 %) or a bruise (22 %), rarely an ankle sprain (8 %), otherwise nothing; being
  spiked is a spike wound. New niggles in `injuries.json` (cause `race`): grazes (easy training 1–3 days), bruise
  (limits 3–7 days), spike wound (easy training 2–4 days). The diagnosis stop event comes as for any injury.
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
  the career's first. Repeat mode has no offers and no rollover (confirmed by the user after the playtest: a player on one
  repeating week plans their own week, so the coach stays quiet); **switching the season plan back on in a season that started while
  it was off rolls that season over at once** (found in the user's playtest: their test of easing back in left the career in repeat
  mode over 1 Nov 2027). The new age class needs nothing new: the coach's targets are worked out per season (2027–28: SM-hallit
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
