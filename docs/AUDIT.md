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
