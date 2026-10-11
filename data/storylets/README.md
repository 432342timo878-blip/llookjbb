# Moments (storylets)

Every `.json` file in this folder is read by `Data` (sorted by name) and holds `{"storylets": [...]}`. A file with
`"test": true` holds **test moments** (session C2): only the check tools and the Dev menu's *Test moments* switch use
them, never a normal career. Rules, rates and shared texts are in `data/moments.json`; the engine is
`scripts/core/storylet_system.gd` (GDD 4.9.5). Check with `tools/storylet_check.gd`.

## A storylet

| Field | Meaning |
|---|---|
| `id` | unique id (across all files) |
| `thread` | `coach` / `family` / `friends` / `group` / `school` (the threads of `moments.json`) |
| `from` | who writes: `coach` (the head coach), `teammate` (anyone in the coach's training group), `teammate:<role>` (e.g. `teammate:joker`, roles in `coaching.json club.group.roles`). Family, friends and school people come with P1. No such person = the moment can't come. |
| `slot` | `morning` (before the day is played) / `evening` (after it; default) / `any` |
| `when` | conditions, all must hold (below) |
| `weight` | how likely it is picked among the moments that fit (default 1) |
| `cooldown_days` | at least this many days before it can come again (default 14) |
| `once` | comes only once in a career |
| `important` | the reply changes something: Play week stops for it with the setting *Important only* (it then needs a stop token, `moments.json rate`) |
| `expires_days` | days it waits for an answer (default `moments.json expires_days`); then "you didn't answer" |
| `chain_only` | comes only as a chain follow-up (a reply's `next`) |
| `topic` | `week` / `race` / `ack` (session C3): a topic of the coach's Sunday talk or of his message after a race (`week_talk.json`), never picked by the scheduler; `ack` is the talk without a topic (one reply, "Thanks, coach") |
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
`count` (`{"name": +1}`). Prepared for later systems (recorded, no effect yet): `confidence`, `motivation`, `stress`,
`sleep`, `life_load`, `grades`, `budget`, `proposal`.

## Conditions (`when`)

`age` [min, max] (whole years; `null` = open) · `month` [1–12, ...] · `weekday` [0 = Mon … 6 = Sun, ...] ·
`day_type` "weekday" / "weekend" · `weeks_in_career` [min, max] · `phase` [season phase ids] · `race_today` /
`race_tomorrow` true / false · `race_in_days` [min, max] (the next entered race, today = 0) · `raced_days_ago` [min, max] ·
`pb_days_ago` [min, max] · `injured` / `ill` / `sore` true / false · `today_tags` / `tomorrow_tags` [session tags: any
matches] · `tomorrow_rest` true / false · `flags` ["name", "!name"] · `flag_days` {"name": [min, max]} (days since it was
last set) · `counters` {"name": [min, max]} · `seen` / `not_seen` [storylet ids] · `answered` {"storylet": "reply" or
["reply", ...]} (its last answer; "_none" = not answered) · `trust` ["new", "good", "strong", "strained"] · `relation`
[min, max] (with the sender) · `fatigue` [min, max] (the athlete's fatigue now, 0–100) · `race_outcome` ["pb", "good", "bad",
"hurt"] (how the race that just finished went: the evening after a race only, see CoachTalk.race_outcome) · `chance` 0–1.

## Placeholders

`{name}` (the athlete's first name), `{full_name}`, `{from}` (the sender's first name), `{coach}` (the coach's full
name), `{coach_first}`, `{teammate}` (another teammate's first name), `{club}`, `{meet}` (the next entered race),
`{race_days}`, `{pb}`, `{weekday}` / `{tomorrow}` (day names).
