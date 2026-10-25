# L3: the sort of the moments (approved by the user and applied in L3a, 2026-10-25)

Every storylet in `data/storylets/` sorted into **delete / feed / invitation / story beat** (GDD 4.10 decision 6 and the cut
list), with the reason. **Approved as drafted and applied in session L3a** (GDD 4.10 "Built (step L3a)"); `talk_ack` turned out
unused by the code, so it went too (43 deleted).

## The four kinds

- **Feed** = a message without buttons. It never stops Play week, never waits for an answer and never shows "N choices waiting".
  It reads as a statement (no question it cannot let you answer). Each one is rewritten from its old question.
- **Invitation** = lands in one of the 9 free-time slots on Sunday (L1b's mechanism): Go / Stay home, with its visible price
  (a late night before a race or a hard session, grades, the friendship). It happens on its evening.
- **Story beat** = a rare real choice with a visible price, shown as a card on the Sunday planner. The price is something the game
  really simulates: mostly **the free-time slots it takes** (a week at the cottage = those evenings and weekend days with the
  family, not with friends), plus the relationship. Training stays yours to plan (as P1 decided for the confirmation camp); no text
  says otherwise.
- **Delete** = a question with no consequence that does not work as a statement either; or it is about something the game does
  not simulate yet (money, who comes to watch a race, a summer job, relays, an extra school race), so it waits for the session
  that builds it.

## Criteria (how each was decided)

1. **Does it happen on a particular evening or weekend day, and would you give up something for it?** → invitation.
2. **Is it a big life choice that takes several days, or a relationship crisis, with a price the game simulates?** → story beat.
3. **Is it the world reacting to something that really happened** (a PB, a bad race, an injury, a report card, a test tomorrow),
   **or colour from the person's own life?** → feed, rewritten as a statement.
4. **Is it a question whose only point was the question** (which snack, which spikes, copy my homework), or does it state or need
   something the game does not simulate? → delete (with the session it waits for, if any).

## Counts

| | Family | Friends | Group | School | Rivals | Coach topics | All |
|---|---|---|---|---|---|---|---|
| Feed | 30 | 9 | 24 | 16 | 9 | 2 | **90** |
| Invitation | 5 | 18 | 2 | 1 | 0 | 0 | **26** (3 exist already) |
| Story beat | 6 | 1 | 0 | 0 | 0 | 0 | **7** |
| Delete | 7 | 9 | 4 | 7 | 1 | 14 | **42** |
| Kept as engine plumbing | | | | | | 1 (`talk_ack`) | 1 |
| **Total** | 48 | 37 | 30 | 24 | 10 | 17 | **166** |

How often, as a season (my recommendation; question 3 below): feed 2–4 messages a week, invitations up to 2 a week, story beats
about 5–7 a year and at most 1 a week.

## Story beats (7)

| Storylet | Who | What | The price you see | Why a beat |
|---|---|---|---|---|
| `fam_rippi_choice` | parent | Confirmation school: June camp / July camp / day school / not at all (Feb, the year you turn 15) | camp: that week's evenings and weekend go to the camp (friends); day school: none; the relationship | a real once-in-a-life choice |
| `fam_juhannus` | parent | Midsummer at the cottage, Thu–Sun | those four slots with the family | real Finnish clash with the summer season |
| `fam_cottage_week` | parent | A week at the cottage in July / just the weekend / stay home | 7 slots (or 2) with the family | as above |
| `fam_summer_trip` | parent | A week in Tallinn and Pärnu in July (a week without an entered race) | 7 slots with the family | as above |
| `fam_ski_trip` | parent | Lapland for four days in the winter break | four slots with the family | as above |
| `fam_autumn_break` | parent | Grandma's in the country for the autumn break | the break's slots with the family | as above |
| `fr_left_out` | best friend | "You never have time any more" (only when the friendship has fallen below Fine) | "Saturday, just us" = this Saturday's slot becomes friends; "It's important to me" / "You don't understand" = the friendship | the relationship crisis P1 built; its follow-up `fr_left_out_saturday` becomes this slot |

The away-trips give no training message: your plan stays as you set it. GDD 4.10 also names "a friend quits", "a fight at home",
"the first crush" and "the rival chain" as story beats. The first three do not exist yet (P2 builds them). The rival chain becomes
**feed** here (see Rivals): its replies only changed small mood points, so there is no real choice to make.

## Invitations (26)

Activity = what the slot becomes if you go. Day = which slot it can land in.

| Storylet | Who | Day | Activity | Notes |
|---|---|---|---|---|
| `fr_party_race` | friends | Fri / Sat before a race | friends | exists (L1b) |
| `fr_party_weekend` | friends | Fri / Sat before a long / hard day | friends | exists |
| `sch_group_work` | class teacher | Thu | study | exists |
| `fam_grandparents` | parent | Sun | family | was a Q&A |
| `fam_against_tests` | parent (family against / coming round) | Mon–Thu in a test week | study | "study tonight" instead of a question |
| `fam_sporty_trip` | parent (sporty family) | Sat | family | ✎ drop "your legs may feel it" (skiing is not simulated as load) |
| `fam_sibling_race` | sibling | Sat | family | watch the sibling race |
| `fam_tv_athletics` | parent | an evening in a championship month | family | the 800 m final on TV |
| `fr_gaming` | gamer friend | a school evening | friends | late night |
| `fr_gig` | musician friend | Fri | friends | `fr_gig_missed` goes; staying home says what missing it costs |
| `fr_scout` | scout friend | Sat | friends | ✎ one night in a tent (one slot) |
| `fr_old_team` | old-team friend | Sat | friends | ✎ "play one match" goes (a football match is not simulated) |
| `fr_study_together` | friends | the evening before a test | study | |
| `fr_vappu` | friends | vappu | friends | |
| `fr_school_end` | friends | the last school day | friends | |
| `fr_new_year` | friends | New Year's Eve | friends | |
| `fr_pikkujoulu` | friends | Fri before Christmas | friends | |
| `fr_injured` | best friend | an evening while injured | friends | no clash: you are not training hard |
| `fr_sleepover` | friends | Sat | friends | a very late night |
| `fr_swim` | friends | Sun | friends | |
| `fr_snow` | friends | Sat / Sun in winter | friends | |
| `fr_ice_cream` | friends | a summer evening | friends | |
| `fr_app_stress` | best friend | a school evening, grade 9 spring | study | study together |
| `fr_cinema` | best friend | Fri / Sat | friends | |
| `gr_kalevan` | training partner | the Kalevan kisat weekend | friends | watch the final at the clubhouse |
| `gr_ruotsi` | training partner | the Finland–Sweden weekend | friends | |

## Feed (90), by person

✎ = the text needs more than turning a question into a statement; **guard** = a condition it must get so it never contradicts you.

**Family (30):** `fam_dinner_late`, `fam_race_good`, `fam_race_bad`, `fam_athlete_tips`, `fam_athlete_expects`,
`fam_top_standards`, `fam_against_waste` (✎ the family's "good signs" counter now moves with real things: a PB, a good report
card), `fam_against_softens` (the family comes round; its attitude changes with the message), `fam_coming_round`, `fam_puzzled`,
`fam_ill`, `fam_injured`, `fam_sibling_pb`, `fam_sibling_advice`, `fam_birthday`, `fam_christmas` (✎ "you're not going running
today, are you?" goes), `fam_new_year`, `fam_cottage_there` (guard: you went to the cottage), `fam_rippi_leaving` (guard: a camp
was chosen), `fam_rippijuhlat` (guard: not "I don't want to go"), `fam_application_talk`, `fam_card_good`, `fam_card_same`,
`fam_card_down` (the report card's own choice is the decision), `fam_card_first`, `fam_app_first`, `fam_app_other`,
`fam_app_none`, `fam_sauna`, `fam_grandma_call`.

**Friends (9):** `fr_why_running`, `fr_art`, `fr_race_pb`, `fr_race_bad`, `fr_secret`, `fr_valentine`, `fr_rippi_camp`
(guard: a camp was chosen), `fr_application`, `fr_app_moving`.

**Training group (24):** `gr_hello`, `gr_joker`, `gr_joker_cold`, `gr_racer`, `gr_racer_count` (comes after `gr_racer`; it no
longer needs your reply), `gr_veteran_sm` (guard: the next race is your first national championship; today it can say "first big
meet?" before any race), `gr_veteran_hurt` (✎ "tell the coach" goes: you cannot), `gr_newcomer`, `gr_newcomer_thanks`,
`gr_quiet_long`, `gr_leader_pace`, `gr_talker_gossip`, `gr_ride`, `gr_pb`, `gr_bad_race`, `gr_injured_mate`, `gr_autumn_start`,
`gr_birthday_mate`, `gr_camp_dream`, `gr_dark`, `gr_indoor`, `gr_hills`, `gr_moose`, `gr_coach_birthday`.

**School (16):** `sch_spotted`, `sch_move`, `sch_winter_day`, `sch_tired` (✎ "tell your coach too" goes), `sch_test_reminder`,
`sch_busy_week`, `sch_praise`, `sch_concern`, `sch_pe_grade` (guard: the card's PE grade really is 10; today it says "a 10 in PE,
of course" whatever the grade), `sch_counsellor_intro`, `sch_counsellor_grades` (guard by the average only; the flag from the
deleted Q&A goes), `sch_counsellor_window` (✎ "on the School page" goes: no UI names), `sch_spring_party`, `sch_swedish_oral`,
`sch_floorball`, `sch_counsellor_stress`.

**Rivals (9):** `rv_first`, `rv_nod_beat`, `rv_nod_lost`, `rv_nemesis`, `rv_nemesis_again`, `rv_nemesis_beaten`,
`rv_streak_win`, `rv_pb`, `rv_injured`. The chain keeps working: the rival's memory ("met", "nemesis") is set by the message
itself, and the Rivals thread can show "your nemesis" as state.

**Coach (2):** `wt_first` (his first Sunday: how the weeks go), `wt_pb` (after a PB).

## Delete (42)

| Storylet | Why | Waits for |
|---|---|---|
| `fam_lift` | bus or bike to practice: not simulated, no consequence | |
| `fam_shoes` | money | M4 (money) |
| `fam_race_watch` | who comes to watch a race | P2 (L2a decision 4) |
| `fam_screen` | late nights now come from your evening slots; "phone off at ten" duplicates a rest evening | |
| `fam_chores` | a Q&A with no consequence | |
| `fam_food` | a Q&A with no consequence | |
| `fam_summer_job` | the summer job is not simulated | P2 |
| `fr_gig_missed` | the gig invitation comes again; its stay-home price says what missing it costs | |
| `fr_watch_race` | who comes to watch | P2 |
| `fr_left_out_saturday` | becomes the beat's Saturday slot | |
| `fr_homework_help` | a Q&A with no consequence | |
| `fr_summer_plans` | a Q&A with no consequence | |
| `fr_rippi_together` | a Q&A after the real choice; nothing follows from it | |
| `fr_hangout` | an afternoon before practice is not a slot | |
| `fr_moped` | money and the licence | P2 / M4 |
| `fr_video` | a Q&A with no consequence | |
| `gr_chat` | a snack poll | |
| `gr_quitting` | a teammate who never quits | P2 (a teammate really quitting) |
| `gr_spikes` | a Q&A with no consequence | |
| `gr_relay` | relays are not in the game | |
| `sch_xc` | "an extra race for your legs" that the game never runs | a later meets session |
| `sch_pe_help` | narrates what you did | |
| `sch_test_after` | the test result shows in the week report | |
| `sch_absence` | "leave early on Friday" for a meet that may be on Saturday | |
| `sch_homework` | "three assignments missing": not simulated | |
| `sch_tet` | the work-experience place is not simulated | P2 / a school session |
| `sch_class_trip` | two days away the game does not simulate | P2 |
| `rv_training_q` | a Q&A with no consequence | |
| `wt_sore`, `wt_tired`, `wt_fresh`, `wt_easy_weeks` | already unused since L1a: the coach's notes on the planner do this | |
| `wt_race_week` | "how do you feel about the race?": nothing follows | |
| `wt_goal` | the goals at the season start replace it | |
| `wt_injured` | the injury block and his notes say it | |
| `rt_pb`, `rt_good`, `rt_bad`, `rt_hurt` | his message after the race and the race card's line say it; any reply gave +1 trust | |
| `mood_flat`, `mood_doubt`, `mood_stress` | his planner line already speaks about the mood; you lighten the week yourself on the planner | |

## Engine plumbing

`talk_ack` (the week talk without a topic) stays if the code still needs it, else it goes.

## Not in this sort (L3b)

The coach's own messages that are not storylets: the goal-met message (its replies set next season's goals), the review, the
market's offers, the "coach suggests" cards. They change with L3b's goals menu and reviews.
