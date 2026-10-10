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
