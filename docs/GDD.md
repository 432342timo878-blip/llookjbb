# Game Design Document — Track & Field Career (working title)

Version 0.2 — 2026-10-05. Living document: updated after each design discussion.

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

## 3. Open questions (round 2)

See chat; answers will be merged into sections below.

## 4. Systems (to be designed)

- 4.1 Athlete model (attributes, potential, physiology)
- 4.2 Training & progression
- 4.3 Competition simulation & in-event decisions
- 4.4 Season calendar & competition structure
- 4.5 Injuries, health, nutrition, sleep
- 4.6 Mental side, motivation, relationships
- 4.7 Coaching
- 4.8 Money, sponsors, equipment
- 4.9 Fame, media, rivals
- 4.10 School / work–life balance
- 4.11 Doping / anti-doping
- 4.12 World simulation (other athletes, records, rankings)

## 5. Presentation

- 2D stadium view during meets: track, crowd, simultaneous events.
- Modern, sleek, responsive UI (desktop + mobile).

## 6. Data

- Real-world database: athletes, records, competitions, venues, qualification standards.
- Stored as editable data files (so it can be corrected and updated without touching code).
