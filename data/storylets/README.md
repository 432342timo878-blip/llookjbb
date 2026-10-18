# Moments (storylets)

Every `.json` file in this folder is read by `Data` (sorted by name) and holds `{"storylets": [...]}`. A file with
`"test": true` holds **test moments** (session C2): only the check tools and the Dev menu's *Test moments* switch use
them, never a normal career. Rules, rates and shared texts are in `data/moments.json`; the engine is
`scripts/core/storylet_system.gd` (GDD 4.9.5). Check with `tools/storylet_check.gd`.

## A storylet

| Field | Meaning |
|---|---|
| `id` | unique id (across all files) |
| `thread` | `coach` / `family` / `friends` / `group` / `school` / `rivals` (the threads of `moments.json`) |
| `from` | who writes: `coach` (the head coach), `teammate` (anyone in the coach's training group), `teammate:<role>` (e.g. `teammate:joker`, roles in `coaching.json club.group.roles`). Session P1 (the cast, `data/cast.json`): `partner` / `partner:<role>` (the close training partners), `family` (anyone in the family), `parent` / `parent:mum` / `parent:dad` / `parent:athlete` (the parent who ran), `sibling`, `best_friend`, `friend` (the other friends), `friends` (any friend), `school` / `school:class_teacher` / `school:pe_teacher` / `school:counsellor`, `rival`. No such person = the moment can't come. |
| `slot` | `morning` (before the day is played) / `evening` (after it; default) / `any` |
| `when` | conditions, all must hold (below) |
| `weight` | how likely it is picked among the moments that fit (default 1) |
| `cooldown_days` | at least this many days before it can come again (default 14) |
| `once` | comes only once in a career |
| `important` | the reply changes something: Play week stops for it with the setting *Important only* (it then needs a stop token, `moments.json rate`) |
| `expires_days` | days it waits for an answer (default `moments.json expires_days`); then "you didn't answer" |
| `chain_only` | comes only as a chain follow-up (a reply's `next`) |
| `dated` | (session P1) a moment of a day of the year (Christmas Eve, vappu, the birthday, the camp week): it comes whenever it fits, before the day's roll, inside the day's and the week's limits (it counts in the 3-5) |
| `topic` | `week` / `race` / `ack` (session C3): a topic of the coach's Sunday talk or of his message after a race (`week_talk.json`), never picked by the scheduler; `ack` is the talk without a topic (one reply, "Thanks, coach"); `mood` (session M1, `mind_talk.json`): his "how are you?" topic, put FIRST in the Sunday talk whenever one fits (its `mood` condition). Session P1: `card` (the family's talk the evening after a report card, queued and posted like a chain follow-up: a moment of the week), `app` (the same after the application's results), `rival` (a rival who ran the race writes that evening, `cast.json rivals.note_chance`; never a stop, outside the 3-5) |
| `standing` | a group name for a recurring choice: the same reply twice in a row offers a rule (the reply needs a `rule` text) |
| `text` | the text variants: strings, or `{"text": ..., "when": {...}}`; never the same variant twice in a row |
| `replies` | 2–4 replies (below) |
| `no_answer` | optional `{result, effects, next}` instead of `moments.json no_answer` |

## A reply

`{"id", "label", "hint", "effects", "result", "rule", "next", "when"}`: `label` is the button, `hint` the cost hint under it
("tired tomorrow", "{from} will remember"), `result` the line shown after, `rule` the standing-order text ("Always say no
to weekday parties before a hard session"), `next` a chain follow-up `{"id": storylet, "days": [min, max]}`, `when` makes the
reply appear only when its conditions hold (at least two replies must remain).

`remember` (true) makes the result card say "{from} will remember this"; `result_from` ("sender") makes the `result` line a message
from the sender instead of a line of the game. After an answer the **result card** (session C3) lists what really changed, in
words with ▲ / ▼ and no numbers: the coach's trust or the sender's relationship (`moments.json changes`); the prepared effects
appear there when their systems exist.

**Effects** (`moments.json effects`): `trust` (the head coach's trust, `CoachSystem.add_trust`), `relation` (the sender's
relationship; for the coach it is his trust), `flag` (a name or a list: remembered with the date and a counter), `unflag`,
`count` (`{"name": +1}`), `proposal` (session C4: "lighter_week" / "more", the coach looks at it the next morning),
`confidence` / `motivation` / `stress` (session M1: points on the mood, each x `mind.json news.moment_point` 5; from the coach
also x his Motivating and the trust factor; listed on the result card as "Confidence ▲ a little"). Session P1: `sleep`
(negative = a late night: life load on the NEXT day, `cast.json sleep`, shown in the day's blocks as "A late night yesterday"),
`grades` (every academic subject's level moves by points x `cast.json grades.grades_per_point`; school drifts it back),
`attitude` (the family's attitude, `cast.json attitudes`), `memory` / `forget` (the SENDER remembers a name with the day:
conditions `memory` / `memory_days`), `relation_thread` ({"friends": -1}: everyone else in that thread). Prepared for later
systems (recorded, no effect yet): `life_load`, `budget`.

## Conditions (`when`)

`age` [min, max] (whole years; `null` = open) · `month` [1–12, ...] · `weekday` [0 = Mon … 6 = Sun, ...] ·
`day_type` "weekday" / "weekend" · `weeks_in_career` [min, max] · `phase` [season phase ids] · `race_today` /
`race_tomorrow` true / false · `race_in_days` [min, max] (the next entered race, today = 0) · `raced_days_ago` [min, max] ·
`pb_days_ago` [min, max] · `injured` / `ill` / `sore` true / false · `today_tags` / `tomorrow_tags` [session tags: any
matches] · `tomorrow_rest` true / false · `flags` ["name", "!name"] · `flag_days` {"name": [min, max]} (days since it was
last set) · `counters` {"name": [min, max]} · `seen` / `not_seen` [storylet ids] · `answered` {"storylet": "reply" or
["reply", ...]} (its last answer; "_none" = not answered) · `trust` ["new", "good", "strong", "strained"] · `relation`
[min, max] (with the sender) · `fatigue` [min, max] (the athlete's fatigue now, 0–100) · `race_outcome` ["pb", "good", "bad",
"hurt"] (how the race that just finished went: the evening after a race only, see CoachTalk.race_outcome) · `mood`
{"motivation": ["flat", "low"], "confidence": [...], "stress": [...]} (session M1: each named mood's word id is one of those;
never true with the mind model off; word ids in data/mind.json) · `chance` 0–1.

Session P1: `family` [attitude ids] · `has` [sender selectors that must exist, e.g. ["sibling"]] · `turns` [min, max] (the
age the athlete turns this calendar year) · `days_to` / `days_after` {event: [min, max]} (days to the next / since the last
event of `cast.json life`: vappu, valentine, christmas, new_year, independence, juhannus, easter, school_start,
school_end, birthday, kalevan_kisat, ruotsi_ottelu, rippileiri; 0 = today) · `school_day` true / false · `break` [break
ids: autumn, christmas, winter, easter, public, summer] · `stage` [school stage ids: grade_8, grade_9, ...] ·
`test_today` / `test_tomorrow` true / false · `tests_week` [min, max] · `cards` [min, max] (report cards so far) ·
`card_days_ago` / `card_avg` / `card_change` [min, max] (the latest report card, its academic average, the change from the
card before) · `app` [before, open, locked, done] (the joint application of grade 9) · `app_result` [first, other, none] ·
`origin` [creation answer ids: pe_teacher, friends, parents, old_coach, tv, international, own] · `old_sport` true / false.
**About the sender** (checked per person): `relation`, `memory` ["name", "!name"], `memory_days` {"name": [min, max]},
`trait` [friend traits], `rival_race` ["beat", "lost"] (the race that just ended), `rival_streak` / `rival_wins` [min,
max] (their / your wins in a row).

## Placeholders

`{name}` (the athlete's first name), `{full_name}`, `{from}` (the sender's first name), `{coach}` (the coach's full
name), `{coach_first}`, `{teammate}` (another teammate's first name), `{club}`, `{meet}` (the next entered race),
`{race_days}`, `{pb}`, `{weekday}` / `{tomorrow}` (day names). Session P1 (with the people on): `{from}` is what the athlete
calls the sender ("Mum"), `{mum}`, `{dad}`, `{parent}` (another parent when a parent writes), `{sibling}`, `{best}`,
`{friend}`, `{partner}` (a close training partner other than the sender), `{rival}`, `{class_teacher}`, `{pe_teacher}`,
`{counsellor}`, `{town}`, `{test_subject}` (tomorrow's test, else today's), `{avg}` (the latest report card's academic
average), `{old_sport}`, `{family_word}`.

The people's moments (every real storylet that is not a coach topic) come only with `StoryletSystem.people_enabled`, which only
the app shell (`main.gd`) switches on: the tools that play days never see them.
