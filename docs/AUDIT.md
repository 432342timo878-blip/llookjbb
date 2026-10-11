# Realism audit (2026-10-09)

The user's wish: an (ultra) realistic career (GDD 1–2, D1 and D8). Everything built up to the R5 playtest fixes,
checked against real rules, published results, sports science and our own tools' measurements. ✓ = matches reality,
≈ = deliberate simplification, ✗ = gap. Decisions taken after the audit: GDD 4.3.1 decisions 28–34. Measured numbers
are from the tools named (R5 values unless marked otherwise).

## The table

| Area | Item | Verdict | Source / measurement |
|---|---|---|---|
| Race | Ability → time (time table) | ✓ | SUL taitomerkkirajat (15-year-olds), SM standards; `race_balance` medians within ±1 s of the anchors |
| | Youth final gaps 1st→2nd / 4th / last | ✓ | 1.4 / 4.1 / 10.4 s vs real 1.1 / 3.5 / 11.9 s (Tilastopaja, Nuorten SM 2026) |
| | Wide local fields string out | ✓ | 27.5 s first to last (`race_shape` row 1); real district youth meets alike |
| | Senior final finish too spread | ✗ (step 7, decision 12) | 1.0 / 2.5 / 6.3 s vs Kalevan kisat 2026 0.06 / 1.1 / 4.1 s |
| | Positive lap splits in fast / honest races | ✓ | +1.7…+3.0 s; WC / OG medallists +2.2 ± 1.1 s (Sandford et al. 2018, IJSPP) |
| | Tactical races ~10 % slower first lap | ✓ | Decision 11 |
| | Energy model: cruising speed + reserve | ✓ shape / ≈ the exponent | The critical speed + D′ model (Jones & Vanhatalo 2017); the drain exponent 5 is tuning |
| | Drafting 2 % of speed | ≈ | Pugh 1971: ~6 % less oxygen 1 m behind at 6 m/s |
| | Order at 400 / 600 m vs finish | ✓ youth, a bit low seniors | r 0.60 / 0.80 vs 0.61 / 0.84 (Renfree et al. 2014); seniors 0.47 / 0.69 |
| | Moves: the strongest of the day decides, weak movers are caught | ✓ (qualitative) | `race_surge_ease.gd` (GDD 4.3.1 "Measured 2026-10-09"); no published per-move statistics |
| | Boxed in: no answer is a trap | ≈ | Plausible, no hard data |
| | Falls 1 per 89 runner-races in bunched finals | unverified | No published rate found; probably on the high side |
| | Outdoors in lanes for the first bend | ✓ | WA TR17 |
| | Indoors in lanes for the first bend | ✗ → **fixed** (decision 29) | WA since 1 Nov 2025: the 400 m break line, ~165 m |
| | More than 8 outdoors: two in a lane | ≈ | WA TR20.4 note (i): one or two a lane or an arced group start |
| | Heat runners ease off near the line | ✓ where; ✗ how much → **fixed** (decision 33) | Measured: 0.05–0.08 s, heats faster than finals; after: ~0.3 s, heat winners slower than in the final |
| | Heats + final at Finnish youth championships | ✗ → **fixed** (decision 28) | SUL Mestaruuskilpailusäännöt 2026, 5.7–5.9 and 5.11–5.13: straight finals in seeded timed sections |
| | One Q / q rule everywhere | ✗ → **fixed** (decision 28) | WAS Regulations 2025 Appendix 5 / WA TR20 table (indoors the old rule matched it, outdoors not) |
| | Your heat run first, the others after | ✗ → **fixed** | WA TR20.3.4: heat order drawn by lot, the later heats know the times |
| | Heat and final the same day (+8 fatigue) | ≈ | WA TR20.10: at least 90 min between rounds; big championships use separate days |
| | Race-day form ±1.5 % | ✓ | Tapers: ~2–3 % (Mujika & Padilla 2003) |
| | No weather | ✗ (small) | Cold, wind and rain cost real runners ~0.5–1 % |
| | All indoor tracks standard 6-lane 200 m | ≈ | SUL 2.4 allows over- and under-length hall tracks |
| | Championship fields always the cap (40 rivals + you) | unverified | `race_rounds.gd`: every Nuorten SM field had 41 after a season; to compare with real entry lists in step 7 |
| Training | Fatigue daily, progression weekly | ≈ | |
| | Diminishing returns, trainability, ceiling | ✓ | Response heterogeneity (HERITAGE) |
| | Growth spurt timing | ✓ | Boys peak ~14, girls ~12 (Malina) |
| | Coach plan ≈ −6 s a year at 14 | plausible, unverified | Step 7 against Finnish age-group statistics |
| | No indoor hall in winter: road / snow at 70 % | ✓ | Finnish reality |
| | Running-specific detraining after 10 days | ✓ | Mujika & Padilla 2000 |
| Health | Strain per area, acute:chronic spike | ≈ | Gabbett 2016; disputed (Impellizzeri 2020) |
| | Injuries a year, coach plan | ✓, slightly low | 0.67 / yr ⇒ ~49 % get one; real 68 % (Mann et al. 2021, runners aged 13–18) |
| | Share of days with a health problem | ✗ (small, step 7) | ~6 % of days injured / ill; real ~25 % any problem, ~11 % substantial (Mann et al. 2021 cohort) |
| | Areas, growth problems, girls' bone risk | ✓ | Mann 2021 (knee, foot, lower leg); Tenforde (bone stress) |
| | Colds 2.2 / yr, winter-heavy | ✓ | |
| | Nutrition, RED-S, menstrual cycle | ✗ | Planned with nutrition (D9) |
| | Rival injuries: a weekly chance | ≈ | Step 7 |
| Season | Real 2027 dates (SUL calendar) | ✓ | Later years estimated (≈) |
| | SM standards; one event without the standard | ✓ | SUL MK-säännöt 5.9 |
| | Phases, lighter weeks, 10-day taper | ✓ | Mujika: 8–14 days |
| | Season bests over Nov–Oct | ✗ → **fixed** (decision 30) | Statistics, SBs and SM standards use the calendar year |
| | Only the 800 m (no relays, XC, 300 / 1000 / 1500 m) | ✗ | Later (D6) |
| Rivals | Fictional youth, real seniors | ✓ (deliberate) | Minors |
| | 150 rivals per birth year | ≈ | Not checked against the size of real lists |
| | Rivals train weekly toward a ceiling, no health / plans | ≈ | Step 7 |
| | No difficulty setting; fields from the meet's level | ✓ | Decision 20 |

## Rules found (for the data)

- **World Athletics, 800 m qualification** (WAS Regulations 2025 Appendix 5; same as the TR20 tables): outdoors
  (final of 8) 9–16 runners: 2 heats, 3 Q + 2 q; 17–24: 3 heats, 2 + 2; 25–32: 4 heats, 3 + 4, then 2 semi-finals
  3 + 2; up to 64 in `data/races.json` `rounds.heats`. Indoors (final of 6) 7–12: 2 heats, 2 + 2; 13–18: 3 heats, 2 + 0;
  19–24: 4 heats, 1 + 2; 25+ with semi-finals. TR20.3: zigzag seeding, heat order drawn by lot; TR20.3.2b: an 800 m's
  later rounds are seeded on the original list improved by today's times; TR20.8: at least the first two of each heat
  go through on place where possible.
- **SUL Mestaruuskilpailusäännöt 2026** (very sure, the official PDF): youth championships outdoors (5.7–5.9) run the
  800 m "suoraan loppukilpailuna": the statistically best in the same section, one race up to 12 runners, otherwise
  the weakest section at least 4, places by time (4.5: when finals are run without heats, times decide the overall
  results). Indoors (5.11–5.13, also the senior SM-hallit) a straight final in one or more sections, times deciding,
  the hall's size setting a section's size. Kalevan kisat has heats (4.5: the meet's jury decides the qualification
  principles). Pace lights are allowed at SM meets except Kalevan kisat (2.7).
- Tampere Junior Indoor Games and the Youth Athletics Games: no rules found; sections assumed (decision 31).

## What a real career has that the game does not have yet

Other events (300, 400, 1000, 1500, 2000 m, cross-country, the SM relays 4×800 / 3×800); Seuracup team points that
count; school (sports class, urheilulukio, the matriculation exams); military service in the sports school or a US
college scholarship; coaching (hiring, changing, a physio, lab tests); camps (also abroad, altitude); national youth
team selection (EYOF, the Sweden match); nutrition, sleep, RED-S, the menstrual cycle; equipment (spikes); weather;
warm-up and the 90-minute check-in (varmistus); money, sponsors, media, doping control, motivation and burnout; club
changes; the Credits screen; pace lights.

## Sources

- World Athletics Technical Rules 2024 TR20 and WAS Regulations Appendix 5 (copy: northernathletics.co.uk,
  "WA-Seeding-Draws-and-Qualifications.pdf", 2025); progression tables, 2017 copy (lbfa.be).
- SUL, Yleisurheilun mestaruuskilpailusäännöt, voimassa 1.1.2026 (yleisurheilu.fi, "MK-saannot-2026-Valmis-1.pdf").
- Athletics Ireland, "World Athletics 800m indoor rule change"; Jamaica Observer 24.1.2026 (in force from 1.11.2025).
- Sandford et al. 2018, Tactical behaviors in men's 800-m Olympic and world-championship medalists, IJSPP.
- Mann et al. 2021: prevalence and burden of health problems in competitive adolescent distance runners (6-month
  cohort, J Sports Sci) and injuries and training practices (68 % a year, 6.3 per 1000 h).
- Renfree et al. 2014 (IJSPP 9:362); Pugh 1971 (J Physiol); Jones & Vanhatalo 2017 (Sports Med); Mujika & Padilla
  2000 and 2003; Gabbett 2016; Impellizzeri et al. 2020; Tenforde et al.; Malina (growth).
- Paris 2024 men's 800 m results (heat and final times).

# Check-in (2026-10-10): realism audit of R4 + project review

The first regular check-in (ROADMAP ideas backlog "Regular check-ins"). Part 1 audits what was built since the audit
above: R4 (commentary, the coach, verdicts, the Race story, the SB column and style tags) and its playtest fixes
(decisions 39–42: the subtitle strip, even sections, the coach in the stands). Part 2 reviews the project. The user's
answers and the agreed order of work are at the end. Same marks as above: ✓ matches, ≈ simplification, ✗ gap.

**Checks run first** (stderr read too): `commentary_check.gd -- 50` 257 checks, 0 failed (lines per race: announcer
27 / 30.6 / 37, stream 44 / 53.8 / 69, TV 39 / 51.7 / 64); `race_rounds.gd` ALL PASSED (41 runners → sections 10 + 10 +
10 + 11); `day_engine_check.gd` ALL PASSED; `help_check.gd` headless 493 checks, 0 failed, **but** windowed at 1280x720
500 checks, 1 failed ("day editor: the help shows 'day_editor' (got '')"): run headless the tool gets a phone-sized
window and never tests the PC layout, so the old failure is PC-only and hidden by the usual way of running it. No
SCRIPT ERROR in any stderr.

**What could and could not be verified.** Web pages only: no broadcast video or audio could be watched, so there are
no transcripts and the line counts of real commentary are estimates. SUL's announcer guide (*Kuuluttamisen opas
yleisurheilukisoissa*, 2024) was found but its PDF text could not be read here (only its table of contents via search).
The Nuorten SM 2026 result pages (Tilastopaja) and SUL's 2026 rules PDF were not reachable this time; the rule text
used is the one quoted in the audit above. No source was found on who streams the Nuorten SM or with what crew.

## Part 1: the table

| Area | Item | Verdict | Source / measurement |
|---|---|---|---|
| Commentary | Stadium announcer alone at local / district meets | ✓ | SUL announcer guide 2024 (preparation, entertaining the crowd and athletes, what to announce) and announcer card classes II / I / KV (KV for SM and international meets) |
| | Commentator + expert at the youth national championships | ≈, probably too polished → **one commentator** (user) | No evidence of a crewed Nuorten SM stream; streams are made by organisers (e.g. Yle's "Suorana suomalaisilta" carries organisations' own streams) |
| | Commentator + expert on TV at senior championships (Yle) | ✓ | Yle shows Kalevan kisat on TV and Areena (2026); Yle crews = commentator + expert (R4 research) |
| | Yle sober / MTV colourful | ≈ unverified | The R4 source compares the channels' football coverage, not athletics |
| | ~35 crew lines in a ~130 s race (commentator 24.7, expert 10.0) | ≈ | A commentator calls an 800 m almost without a pause (an estimate: ~25–35 sentences in two minutes); the expert mostly talks before the gun and over the replay, so 10 expert lines during the race is high |
| | Announcer 13 lines a race at a small meet | unverified, a bit chatty | |
| | Talk between the calls (next meet, the coach's name, Finnish history) during the race | ✗ (small) → **fix** | Real 800 m broadcasts do introductions and season facts at the line-up and after the finish; mid-race digressions are rare. Belongs to the race ceremony / studio ideas (backlog) |
| | Expert: "x % faster than the field's even pace" | ≈ | A model term; real commentators turn splits into a projected time ("on 1:58 pace") or compare with a record / PB |
| | Personality styles named only after the player has raced someone twice | ≈ → **change** (user) | Crews work from prepared notes (Yle, R4 research) and know the favourites' styles; the tag in the player's own field list (scouting) stays at two races |
| | The favourite: best season best of the year, else PB | ✓ | As commentators do; the fallback "his club" is gendered (fix) |
| | "Ranked 2nd of 5 in this field" | ✗ (small) → **fix** | Counts only runners with a season best, so "of 5" in a field of 8 |
| | Winning a section or heat called "wins it"; "A podium for you: 3rd!"; the warm coach "A medal!" | ✗ → **fix** | In sections the places and medals go by time across all sections (SUL MK-säännöt 4.5); a section or heat place is not a medal. The Race story (`RaceStory.verdict_case`: won / podium) uses the section place too |
| | "Personal best" in the first race ever | ≈ | Commentators say "a first official time" |
| | Lines never repeated, 2 s between exchanges, the coach only about what he sees | ✓ (rules) | `commentary_check`: 0 of 2446 repeats, 0 breaches |
| Coach | In the stands by the 200 m start, splits at 200 and 600 m | ✓ | The 200 m start is 200 m before the finish: an 800 m runner passes it at 200 and 600 m, the classic spot for a coach calling splits; advice from the stands is allowed (WA TR6 forbids pacing and devices, not shouting) |
| | Indoors at the rail, a split every lap | ✓ | A 200 m lap |
| | Heard within 110 m either side of his spot (55 % of a lap) | ≈ generous | In a stadium a shout carries some tens of metres; "can see" and "can be heard" are one number (`controls.coach.view_m`) |
| | Four personalities | ✓ as types | Sport psychology's autonomy-supportive vs controlling coaching (Mageau & Vallerand 2003; Bartholomew et al. 2010): calm / warm / tactician supportive, the hard driver controlling. Controlling styles in youth sport go with lower motivation and dropout: a link for the motivation system later (D9) |
| | Words for a 14-year-old | ✗ (small) → **fix** | "sweetheart", "love" (warm coach) do not fit an adult coaching a minor in today's Finnish club culture (SUL's safe-environment guidance); the hard driver's harsh lines are real but stay a personality |
| | Advice right 80 % of the time, a random other answer otherwise; every coach advises the same | ≈ → **Coaching step** (user) | Real coaches misjudge in their own way (the driver says go, the calm one says wait), not by dice; the personalities differ only in words today |
| | Race story "better / as expected / below" from the day's ability | ≈ → **fix** | The day's ability includes the hidden race-day form roll, so a bad day counts as "as expected"; a coach compares with the pre-race picture (the seeding by SB / PB) |
| | "Too fast" whenever the player was 1st–2nd at 200 m and faded | ≈ | In a slow tactical race leading at 200 m is not too fast |
| | 4–6 key moments | ✓, min 3 seen | `commentary_check`: 3–6 a race (`min_moments` 4 is not enforced) |
| | Coach cases in 50 races | — | as expected 12, boxed 10, kick died 9, podium 8, won 5, good kick 5, faded 1; never "better" / "below" |
| Verdicts | Verdict 10 s after a card (places, gap to the leader, the Feeling word, the card's signs) | ✗ → **fix** | Measured means: move.go **+1.61** (good), move.wait −0.52, straight.wide +2.72, break.lead −1.41, kick.now −0.74. R5's `race_value.gd` found letting a stronger mover go usually the better answer: going with them looks good 10 s later and costs at the finish, so the verdict can teach the wrong lesson. Real commentators judge a choice in hindsight. Fix: the 10 s line says "so far" (neutral on moves), the real verdict comes after the finish in the Race story |
| Sections | Even sections (decision 40: 13 → 7 + 6, at most 12, the slowest at least 4) | ✓ within the rule | SUL MK-säännöt 2026 5.7–5.9 (audit above): the best together, one race up to 12, the weakest section at least 4; the rule does not fix the split. Nuorten SM 2026 had 17 races of 6–11 runners (GDD 4.3.1 research), consistent with even splits; entry lists not checked again |
| Code | Two trailing commas in `race_commentary.json` (lines 94, 269) | ✗ (small) → **fix** | Godot accepts them, standard JSON does not (an editor or another tool would refuse the file); `json_check.gd` uses Godot's parser and cannot see them |
| | Rivals' weekly training and the Race story's coach line use the global, unseeded random numbers | ≈ | `Rivals.train_week` (`randf`), `RaceStory.build` (`randi`): after loading a save the rivals do not continue bit for bit (only the player's side does); tools seed it, so the checks don't show it |
| | `help_check` headless = phone layout only | ✗ → **fix** | See "Checks run first" |
| | Docs call every coach "he" | ≈ | Two of the four are women (Marja Hakala, Anneli Saarinen) |

## Part 2: project review (Claude's honest opinion)

- **Against the vision (GDD 1–2).** Deep and researched where built: training, health, periodization and the 800 m race
  (D1, D2, D10, D13, D26 well covered; D8 real calendar and rules). Not started: the athlete as a person (D9 coaching,
  money, media, motivation, nutrition; D17 school; D18 hired coaches who can be vetoed). Since 2026-10-07 nearly all
  work (R1–R5, meet formats, R4) went into the two-minute race; the 52 weeks between races have had no new feature
  and no playtest since step 6f. The race is now far deeper than the rest of the career around it.
- **Missing for M2 and for "a whole season in one sitting":** step 7 (do careers make sense over 5–8 years), Coaching
  and School, and above all **a whole season played by the user** after the race changes; step 7 should start from
  those notes.
- **Fragile or slow:** (1) checks that print "ALL CHECKS PASSED" after a SCRIPT ERROR aborted a function, and
  `help_check` testing only the phone layout headless: a single "run all fast checks" script (both layouts, reads
  stderr, one verdict) fixes both; (2) tools of 10+ minutes (`race_check` ~10 min, a full R5 before/after suite ~1.5 h
  on 4 lanes): fine for Claude, impossible for the user; (3) the user cannot playtest without command lines
  (`watch_race.gd`, `season_playtest.gd`): a Dev menu in debug builds; (4) big scripts: `race.gd` 1631 lines,
  `career_hub.gd` 962, `health_system.gd` 958, `race_screen.gd` 931, `race_commentary.gd` 839 (12 977 lines of game
  code, 8 381 of tools): workable; split a file only when it is next changed, never as a project of its own (the
  fingerprint tools protect such splits); (5) `CLAUDE.md` is 44.6 KB and is read every session, mostly build
  history already in the GDD (offered: slim it to ~12 KB; the user kept it as it is for now); (6) the ideas backlog
  has ~25 open items: fine once the far ones are parked under their milestones (done below).
- **Open task chips** carried into the fix session: `help_check` "day editor ?" (PC only, see above); a heat's Q / q
  marks once did not match the next round's size (`race_rounds` passed today: "41: 7 heats, 2 Q + 4 q").

## Agreed with the user (2026-10-10)

- **R4 fixes (all four):** section and heat places never called a podium / medal, "wins the heat / section", the Race
  story and the coach use the overall place in sections; the 10 s verdict says "so far" and the real verdict on a
  choice comes in the Race story after the finish; talk between the calls only 1–2 short facts on lap 1, the rest
  waits for the race ceremony / studios; coach words fit a minor (no "sweetheart" / "love"), "ranked x of y" counts
  the whole field, "his club", the two JSON commas, "as expected" from the pre-race ranking.
- **Rival styles:** at streamed and TV meets the crew knows the favourites' styles (prepared notes); the player's own
  field tag still needs two races.
- **Nuorten SM:** one commentator, no expert (international youth meets keep commentator + expert).
- **Coach advice by personality:** in the Coaching step (mistakes from personality, not dice; the race reader the most
  accurate).
- **Order of work:** (1) fix session: the R4 fixes, the two open chips, one "run all checks" script (PC and phone
  layouts, reads stderr) and a Dev menu for the user (debug builds: watch a test race, jump the career forward);
  (2) the user plays a whole season, notes only; (3) the character-creation points pool (it changes the starting
  athlete, so before step 7); (4) step 7, the multi-year check; (5) Coaching and School designed together; then
  reputation, statistics, studios, audio.
- **Parked (the user left the choice to Claude):** track visuals, venue stadiums, other events in the stadium and race
  zoom → M3; pacemakers → M4; club and hometown pages → after M2; the training-PBs screen becomes part of the
  Statistics tab design.
- **Next check-in:** after step 7.

## Sources (this check-in)

- SUL, *Kuuluttamisen opas yleisurheilukisoissa* (2024, yleisurheilu.fi, table of contents only) and
  *Kuuluttajakorttien myöntämisperusteet* (2013).
- Yle: Kalevan kisat 2026 on TV and Areena; "Vastauksia yleisimpiin Yle Urheilulle esitettyihin kysymyksiin"
  (yle.fi/a/3-5926339, organisations' own streams on Areena).
- SUL Mestaruuskilpailusäännöt 2026 (as quoted in the audit above); World Athletics Technical Rules TR6 (assistance).
- Mageau & Vallerand 2003, The coach–athlete relationship: a motivational model (J Sports Sci); Bartholomew,
  Ntoumanis & Thøgersen-Ntoumani 2010, controlling interpersonal style in a coaching context (J Sport Exerc Psychol).
- Our tools: `commentary_check.gd -- 50`, `race_rounds.gd`, `day_engine_check.gd`, `help_check.gd` (headless and
  windowed); R5's `race_value.gd` numbers (GDD 4.3.1 "Built (step R5)").

# Check-in (2026-10-11): realism audit since the last check-in + project review

The second regular check-in, due after step 7. Part 1 audits what was built since the check-in above: the fix session
(GDD 4.3.1 "Built (check-in fixes)"), the character-creation points pool (GDD 4.1.1 "Built (points pool)"), the
playtest fixes (GDD 4.3.1 "Built (playtest fixes)") and step 7, the multi-year check (GDD 4.2 "Multi-year check").
Part 2 reviews the project, with the 2026-10-11 backlog notes ("Never stale", "More attributes, mental training", the
coach chat). The user's answers are at the end. Same marks: ✓ matches, ≈ simplification, ✗ gap.

**Checks run first** (stderr read too): `run_all_checks.bat` **11 of 12 passed**; `season_plan_check` failed its speed
test, "week_for is cheap (< 1 ms)": 3046 µs per call with three other Godot processes running. Earlier runs of the same
check: 362–381 µs (fix session, points pool, playtest fixes), **935 µs at step 7** (passed by 65 µs), 993 µs alone
today. Cause: step 7's 21 seasons of meets (`Calendar.SEASONS_AHEAD` 20, was 2) and `Calendar.get_meet` /
`meets_between` walking the whole list on every call. No SCRIPT ERROR / Parse Error in any output; only the usual
"ObjectDB instances leaked at exit" warnings of tools that quit.

**What could and could not be verified.** Read: SUL's *SM-kisojen tulosrajat ulkoratakaudella 2025* (the official PDF,
with Poppler), Tønnessen et al. 2015 (full text), Haugen et al. 2018 (accepted manuscript), the abstracts of Hopkins
2005, Hopkins & Hewson 2001, Kearney & Hayes 2018 and Brustio et al. 2024. Not found: SUL's 2026 standards PDF (the
data's 14–15 standards say they are from it; the 2025 numbers are 0.5 s off for M15 only), the Nuorten SM 16–17 2026
result pages, anything about the Nuorten SM stream crew.

**New measurements** (scratchpad runs, not in the project): `career_check.gd -- 4 trained,average 11 0 rows norace` and
`-- 8 random 11 0 rows norace` (16 careers, 11 seasons = ages 14–25, Balanced, races finished without running them); a
throwaway rank-stability tool on the rival pool alone (20 pools of 150 per gender, `Rivals.train_week`, 11 seasons).

## Part 1: the table

| Area | Item | Verdict | Source / measurement |
|---|---|---|---|
| Step 7 | "~1:59 at 21, near the Kalevan kisat entry level"; "slowest heat runner 1:58.5" as the level | ✗ (wording) → **fixed in the GDD** | SUL SM-tulosrajat 2025: direct entry **1:53.50 / 2:11.00** (1.5. of the year before to the deadline), waiting list at least **1:55.50 / 2:15.00** in the same calendar year, filled by ranking to a target of **27** per sex; the slowest heat time came from a runner with a faster season best. No data uses it yet (Kalevan kisat is watch-only) |
| | Indoor times for the standards | ✓ | SUL 2025: "Sisäradoilla tehdyt tulokset hyväksytään ... ajat otetaan huomioon sellaisinaan" (a hall track up to 400 m) |
| | Club-only meets (seurakisat) for the standards | ≈ (later, M4) | SUL 2025 rule 3: Kalevan kisat standards only from statistics-valid meets in kilpailukalenteri.fi, not club meets; the game's open club meets are a stand-in for both |
| | 14–15 SM standards; no standards at the 16–22 SM; max 3 events, 1 without the standard | ✓ | SUL 2025 (M15 2:20.50, N15 2:35.00, M14 2:28.00, N14 2:36.00; the data's 2026 values 2:21.00 / 2:35 / 2:28 / 2:36); "M/N 16-17-19-22-sarjojen SM-kilpailut: ei käytetä tulosrajoja" |
| | Yearly improvement of the top 100 juniors (Tønnessen 2015) | ✓ | Table 1: boys 14→15 5.2 s, 15→16 3.2, 16→17 2.3, 17→18 1.5; girls 2.2 / 1.6 / 1.5 / 0.6 (exactly the numbers used) |
| | Puberty window: natural growth full until a year after the peak, gone 3 years later | ✓ | Strength spurts at the growth peak or up to ~1 year after it (Beunen et al. 1988: explosive strength 6 months after; INEX study 2021: at or within 6 months); later strength gains come from training |
| | The player's growth 21 → 25 | ✓ | ~2.7 % (ability 12.04 → 12.83, trained boys) vs Haugen et al. 2018: middle-distance runners ~3.4 % over the 5 years before their peak |
| | **A top talent never reaches senior national level** | **✗ (big)** | 16 careers to 25: nobody at the Kalevan kisat standard (≈ ability 14.9 men, 14.1 women); trained boys (potential 17.4 of max 18) 2:04.8 at 21, 2:00.6 at 25 (76th percentile); the best of all 2:00.0; trained girl (potential 16.3) 2:15.6 at 25; the birth year's best rivals 1:49–1:51. The start decides: 67th → 76th percentile in ten years, attributes at 25 still 1–6 below the potential (strength 11.3, lactate 12.4, speed 13.4). The GDD's "~1:59 at 21" was optimistic (2:04–2:05 in these runs). Only Balanced tried |
| | Experience trade (pairs) | ✓ beginners / ✗ average vs trained | Beginner (pool 6) catches the trained athlete at ~17 (step 7); an average story (pool 12, no novice bonus) never does: −0.88 at 15 → −0.58 at 25, ahead in 0 of 4 pairs. The higher trainability barely shows: the start decides (same root as above) |
| | Youth success vs senior success in the rival pool | ✗ (medium) | Game: top 20 at 17 still top 20 at 21 **77 %** boys / 83 % girls (top 20 at 15 → 21: 50 / 64 %). Real: Brustio et al. 2024, ~19–21 % of top U18 middle- and long-distance runners reach the senior top (7× the chance of the others); Kearney & Hayes 2018, only 9 % of senior top-20 men were top 20 at U13, weak to moderate correlations up to U17–U20. Not the same measure (dropouts, older senior fields), but the direction is clear: rivals never quit, stall early or bloom late |
| | Rivals' late years | ✓ | Best of a birth year 1:51.9 at 21 → 1:49.8 at 25, 20th 2:00.3 → 1:57.9 (still improving slowly, as the real ones) |
| | Peak age and decline | ✗ (later, M4 / D19) | 800 m men peak at 24.5 y, women's middle distance 26.8 y (Haugen 2018); the game has no peak and no decline for anyone |
| | Race-day spread, youth (after the 25 % cut) | ✓ | 2.1–2.4 % (the user's athlete, watched / quick). Hopkins 2005: elite up to 1500 m 1.0 % (top half 0.8, bottom half 1.1); Hopkins & Hewson 2001: slower runners ×1.0–2.3, younger ×1.1–1.8 |
| | Race-day spread, seniors | ✗ (open, as in 4.2) | ~2 % at 19–21 vs ~1 % elite |
| | Consistency comes from experience | ✗ (design) | Hopkins & Hewson put most differences in variability down to competitive experience and attitude; the game's consistency never grows (the senior narrowing is an age factor) → the mental attributes design |
| | Real championship fields; rival injuries ~4 % out | ✓ | From the 2026 entries (not re-read); Mann et al. 2021: time loss ~4 % of weeks |
| Points pool | Pool from training years, experience costs trainability | ✓ (idea) / ≈ (sizes) | Well-trained athletes respond less (HERITAGE, earlier audit); the sizes are tuning; see the pairs above |
| Playtest fixes | SB on the first time of a year; PB on a first ever time | ✓ / ≈ | The first mark of a season is its best (results convention); a debut PB is a choice |
| | One PB / SB for indoor and outdoor | ≈ | World Athletics lists short track separately ("sh"), Finnish statistics keep hall lists apart; SUL's standards take indoor times as they are |
| | Indoor tracks slower | ✓ | Bends ×0.985, about half of a 200 m lap → ~0.8 % over 800 m (the number moved to `races.json`, see the fixes) |
| | The kick is the player's call; Quick result follows a kick plan; no contradicting shouts; verdicts against the athlete's own PB / SB | ✓ (design) | The user's decisions; a coach judges a race against the athlete's own level |
| Check-in fixes | Section and heat places never a medal; the 10 s verdict "so far"; the crew knows the favourites | ✓ | SUL MK-säännöt 4.5 (previous check-in) |
| | Nuorten SM = one commentator | unverified | No source on who streams it |
| Code | `week_for` 2.5× slower since step 7, its check flaky | ✗ → **fixed** | 993 → **201 µs** alone (see the fixes) |
| | `INDOOR_BEND_SPEED` a constant in `race.gd` | ✗ (small) → **fixed** | CLAUDE.md: every race number in `races.json` |
| | Rivals' weekly training uses the global random numbers | ≈ (still open) | From the last check-in: a loaded game's rivals don't continue bit for bit |

## Fixes made in this session (user's OK, 2026-10-11; no change to how the game plays)

- **Calendar lookups.** `Calendar._index`: the first meet per key (`_by_key`) and every meet's date key in order
  (`_date_keys`, binary search in `meets_between`), rebuilt whenever the cache is another array (`career_check` sets
  `_meets_cache` itself), with a fallback to the full walk if a cache is ever unsorted. `week_for` 993 → 201 µs.
- **`races.json` `engine.indoor_bend_speed`** 0.985 (was the constant `INDOOR_BEND_SPEED` in `race.gd`).
- **GDD 4.2** corrected: the Kalevan kisat rule from SUL's 2025 standards and the 11-season result.
- **Proof:** `training_balance.gd -- 0` (fingerprints 204.145691989 / 14.102831594 / 1226.006524079) and
  `race_shape.gd -- 30` (all 8 rows, the indoor one included) identical to the digit before and after; `season_plan_check`
  ALL CHECKS PASSED alone; `run_all_checks.bat` after the fixes: **ALL 12 CHECKS PASSED**, no SCRIPT ERROR in any
  output, `week_for` 179 µs.

## Part 2: project review (Claude's honest opinion)

- **Where we are.** M2 part 1 is complete: day-by-day, health, periodization, the race (R1–R5, meet formats, R4) and
  now the multi-year curves. Since the last check-in five sessions in one day (fix session, points pool, playtest
  fixes, step 7, the backlog notes) all made the numbers make sense; none touched the playtest's headline ("very
  bored, wouldn't return after one season"). Coaching + School, designed together, is the right next design.
- **The talent finding matters for the career's promise** (GDD 1: from 14 to retirement, all events, the real world):
  if a top talent can't reach Kalevan kisat by 25, the game has no senior career to grow into. It also matters for
  Coaching: the coach's season goals ("what makes the coach happy", the playtest) need a believable path.
- **Never stale.** D1 / D2 (no dexterity) are what make this an FM-style game that works on a phone; sessions played
  through with decisions (the race engine reused), tests that reveal progress, standing orders and storylets with
  memory fight staleness without breaking them. The strongest anti-staleness lever is a world that changes: rivals
  who quit, stall, bloom late, move clubs (the churn finding above).
- **More attributes.** Not many more numbers: make consistency and composure grow with racing experience and mental
  training (it is also the real reason seniors are more consistent), and add confidence and motivation as moods that
  move week to week (they give Coaching and School something to act on). Physical: enough for now.
- **The coach chat** (decided: written dialogue, no AI): it lives or dies by the storylet system; design both at once.
- **Fragile:** (1) a speed check that passes by microseconds (fixed now); (2) `CLAUDE.md` grew 44.6 → 50.8 KB in a day
  and is read every session (still mostly build history that the GDD holds); (3) the GDD is 238 KB, its "Built"
  sections are build logs; (4) the multi-year balance was measured on one plan only, and no tool measured past 21
  before today; (5) the rivals' global random numbers. Code: 14 240 lines of game code (was 12 977), 9 980 of tools
  (8 381); `race.gd` 1 691 lines, the rest under 1 000.
- **Missing against the vision:** D9 (coaching, money, media, motivation, nutrition, relationships), D17 school, D18
  hired coaches with a veto, D6 other events, D20 real senior athletes and the world simulation, M3 stadium view,
  peak age and decline (D19).

## Agreed with the user (2026-10-11)

- **The talent fix = both, with clear roles.** First its own balance session (Opus): measure the Ambitious plan and a
  best-case plan too, agree targets with the user (the shape: a top talent on a decent plan reaches the top of the
  birth year and Kalevan kisat by about 21–23, an average one national youth finals, a low one club level), then tune,
  including late bloomers and plateaus for rivals (churn, growth part). Then Coaching adds the realistic layer on top:
  coach quality and fit, better plans and good choices move the outcome by a few percent (finalist vs medallist), so
  the club coach is never a trap.
- **More meets** (national and international, real dates with sources): its own research + data session after the
  talent session (it changes which races careers run, so it is measured too); ROADMAP backlog "More meets in the
  calendar".
- **Minigames:** D1 / D2 stay (no dexterity; played-through sessions with decisions are fine), but the user is still
  interested in light minigames if a proper, realistic form is found: the Coaching + School design brings 2–3
  concrete ideas to judge.
- **Rival churn split:** growth (late bloomers, plateaus) in the talent session; dropouts and rivals' life events with
  the rival profiles and the "Never stale" storylets.
- **Small fixes now:** done (above).
- **Order of work:** (1) the talent balance session; (2) Coaching + School designed together (with "Never stale",
  mental training and moods, the written coach dialogue, the minigame ideas); (3) more meets (research + data; may
  run beside the design since it is independent); the race-controls idea in its own design session; then reputation,
  statistics, studios, audio.
- **Next check-in:** at the end of M2 (after Coaching + School are built), or whenever the user asks.

## Sources (this check-in)

- SUL, *SM-kisojen tulosrajat ulkoratakaudella 2025* (vahvistettu 25.2.2025),
  yleisurheilu.fi/wp-content/uploads/2025/02/SM-tulosrajat-2025.pdf.
- Tønnessen E et al. 2015, Performance development in adolescent track and field athletes according to age, sex and
  sport discipline, PLoS ONE 10(6): e0129014 (PMC4456243), Table 1.
- Haugen TA et al. 2018, Peak age and performance progression in world-class track-and-field athletes, IJSPP.
- Hopkins WG 2005, Competitive performance of elite track-and-field athletes: variability and smallest worthwhile
  enhancements, Sportscience 9: 17–20; Hopkins WG & Hewson DJ 2001, Variability of competitive performance of
  distance runners, MSSE 33(9): 1588–1592.
- Kearney PE & Hayes PR 2018, Excelling at youth level in competitive track and field athletics is not a prerequisite
  for later success, J Sports Sci 36(21): 2502–2509; Brustio PR et al. 2024, Performance pathways in elite middle- and
  long-distance track and field athletes: the influence of a successful youth, J Sci Med Sport.
- Beunen G et al. 1988 (adolescent growth and motor performance, Belgian boys); Muscular strength spurts in adolescent
  male basketball players: the INEX study, 2021 (PMC7831329).
- Athletics abbreviations (PB, SB, "sh" = short track), Wikipedia; World Athletics athlete profiles (short-track events
  listed apart).
- Our tools: `run_all_checks.bat` (twice), `career_check.gd` (11 seasons), `season_plan_check.gd` alone,
  `training_balance.gd -- 0` and `race_shape.gd -- 30` before / after; a rank-stability scratch tool.
