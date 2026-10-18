# Playtests

The user's playtests: their notes, sorted, and what the save files showed. The decisions they led to are in the
roadmap and the GDD; this file keeps the raw picture so it isn't lost in a chat.

## Season playtest 1 (2026-10-10)

**What was fixed (quick-fix session, 2026-10-10; GDD 4.3.1 "Built (playtest fixes)"):** the race-time swings (no bug: a wide
race-day form for a low consistency, plus racing injured; narrowed by 25 % for everyone), the kick (Wait never starts it by
itself, Kick now at any distance, a kick plan for Quick result), the "too far out" coach line after a 100 m kick, contradicting
coach shouts, PB / SB in the verdicts and in every result list, the monthly record (Progress page), the Report tab (summary
first, days folded), the Rankings tab (YOU box, highlighted row, a line on what it is). Not fixed here: the notes marked
step 7, Coaching, School, rival profiles and the race-controls idea (see the table below).

**Step 7 (the multi-year check, 2026-10-10; GDD 4.2 "Multi-year check"):** "last in almost every race" had its cause in the
rivals: they grew about twice as fast as real juniors and never stopped (the best of a birth year at 1:43 by 21), so every kind
of player was last in about half the races from 16 on. Now the rivals follow real Finnish levels (a birth year's 1st / 8th /
20th best within about 1–2 s of the 2026 championships), and random players were last in 7 of 95 races at 17 instead of 48 of
94. "One warning all season, no injuries": per week the game has a substantial health problem 10–14 % of the time, as real
adolescent runners (11 %, Mann 2021), so no change; one player's season can be lucky. "How fast should attributes grow": young
athletes grow fastest, from about 16 (girls 15) the yearly gains shrink, and a beginner catches a trained athlete at about 17.

**Setup (user):** new career, the coach's plan, nothing changed in training, every race entered (targets Nuorten
SM-hallit, Tampere Junior Indoor Games, Nuorten SM), the Balanced plan, 12 points on determination, race tactics,
pain tolerance and professionalism; races watched and quick-simmed. Background: early developer ("Taller and
stronger"), "Nowhere yet" to train.

**What the save showed (`user://saves/`, 2 Nov 2026 → 11 Oct 2027):**
- 18 races, **last in 12**, best place 4th of 6.
- PB 2:44.26 (Dec) → 2:39.89 (Jan) → 2:37.75 (Feb, SM-hallit) → 2:33.40 (Mar, TJIG) → 2:28.57 (May) → 2:25.71 (Jul).
- **Swings between races far beyond a real youth runner's few seconds:** 2:49.80 (15 May) → 2:28.57 (29 May);
  2:25.71 (20 Jul) → 2:45.00 at Nuorten SM (6 Aug); 2:49.58 (10 Jul). Cause not yet known (quick fix before step 7).
- Attributes start → end: aerobic 4.4 → 7.6, economy 6.8 → 8.0, speed endurance 5.4 → 6.5, strength 5.6 → 6.8,
  technique 3.6 → 4.8, threshold 6.2 → 7.0, speed 5.1 → 5.7; the mental attributes the points went into hardly
  moved. Hidden potential 13.2 (the early-developer answer cost 1.5). Monthly values can't be recovered: the game
  keeps only 28 days of log (a monthly record is a quick fix).
- 800 m ability ~5.8 at the start = bottom quarter of the 150-boy rival pool; ~7.0 at the end = bottom tenth (the
  rivals' middle grew 7.3 → 9.1, the player +1.2). Step 7.
- The 12 points on mental attributes were worth ~0.25 ability; on the four key 800 m attributes ~1.9 (~11 s). Led to
  the points pool (GDD 4.1.1 "Built (points pool)").

**The notes, sorted:**

| Note | Kind | Where |
|---|---|---|
| Coach says "kicked too far out" after a kick at ~100 m | bug | quick fixes |
| "Wait for the home straight" starts the kick at exactly 100 m; Kick now can't be used later; "I want to decide when I kick" | bug / missing control | quick fixes |
| Coach shouts contradict ("you're drifting, wake up!" / "your own pace!", "too far back! move it" / "back off a bit!") | bug | quick fixes; personalities in Coaching |
| Coach unhappy after a 2 s PB, "not good enough" after a 4 s PB | feels wrong | quick fixes |
| Never see a PB / SB in results | missing | quick fixes |
| Huge time swings between races (from the save) | bug? | quick fixes |
| One warning all season, no injuries | feels wrong | step 7: the health model matches real runners per week (no change) |
| Can't tell how fast attributes should grow, or whether training works; training runs "in the background" | missing feedback | step 7 (growth by age, done) + monthly record (quick fixes) + Statistics |
| Last in almost every race | feels wrong | points pool (done) + step 7 (rivals' growth fixed, done) |
| "How should I know my potential / what times / what makes the coach happy?" | missing | points pool (the coach's guess, done) + Coaching |
| Don't know why I train what I train, wouldn't know what to change | missing | Coaching |
| Day by day is redundant, the days feel empty | feels wrong | Coaching + School |
| Report tab long, wants a neater format + coach comments | feels wrong | quick fixes + Coaching |
| Rivals are just random names | missing | rival profiles (backlog) |
| Rankings tab: "don't know" | unclear | quick fixes |
| The coach's "stopwatch" threat: does it matter? | feels wrong | words only today; Coaching |
| Drop the cards, control the whole race with buttons / a slider | big design change | backlog "Race controls", own design session |
| "More depth… repetitive… not immersive… I wouldn't return after one season" | the big one | Coaching + School |
| Liked: the races are the most interesting part | | |

**Follow-up answers (user, 2026-10-10):** best moment of the season: "when the season was over". What would make a
weekday worth playing: school, coach talk, friends and small choices, all of them: "it needs to be more interactive
with the coaches and everyone around me". Where the quick fixes go: Claude's call (before step 7).

## Season playtest 2: the guide (written 2026-10-18, after the fix session)

**Why:** the last real playtest was playtest 1; since then ~27 000 lines of coaching, school and people have been built and only
tools have played it. The question only you can answer: **is it fun, and do the stops feel right?** (Tools measured 3.1-3.2 stops a
week with no quiet week: the Sunday talk about 1.0, the coach's proposals about 1.0, the people about 0.8.)

**How (about 45-60 minutes for a season; stop whenever you are bored, that is the data):**
1. Open the project in Godot and press F5 (run). Start a **new career** (an old save was made before the new systems; a new one has them all).
2. Play a season the way you would really play: Play week, answer what you want, ignore what you don't. The default setting is
   "Play week stops for: Important only".
3. To see the school years without waiting: main menu > **Dev menu (test build)** > **Jump the career forward** (targets: 1 Jan, 1 Mar,
   1 May, 1 Jul, 1 Sep, 1 Nov; it stops at a race or at anything that needs an answer: answer it and jump again). For a born-2012
   career: jump to **1 Mar 2028** (on the way the joint application opens in mid-February: make your list or ask the counsellor), then
   **1 May** (the test day comes in mid-May), then **1 Jul** (the results on 11 June; a rejection offers a **TUVA year**), then **1 Sep
   2028** (the first lukio day: the maths / language / years choices, then the first period's courses).
4. Things worth trying once: the People tab (read the coach thread, the family, friends; **Find a coach**); say "Ask me first" vs "Always" to
   the coach's proposals (Training tab, Standing orders); from grade 9 the new standing order **Lukio courses** (ask me every period / let the
   counsellor plan them) and how a period's results arrive (a message unless a course failed).

**What to write down (a line each is enough, paste them into the chat and I sort them into this file):**
- The first moment you were **bored**, and the first moment something made you **want to play on**.
- Every stop you wished had been a message, and any message you wished had been a stop. How many stops a week felt right?
- Anything that **sounded wrong** (a coach, a parent, a teacher, a friend) or looked wrong on screen. On a phone-sized window too, if you try it.
- The Sunday talk: useful, too long, too often?
- The coach's proposals: did you ever say no? Did one ever feel like a real decision?
- Were the **race** parts still the best part? Did anything outside the races pull you in?
- Whether you would come back tomorrow, and what would make you.

**What was changed just before this playtest (look for it):** the TUVA wording after a rejected application; a coach's offer to someone
under 18 coming as a message from a parent (the offer waits on the coach's page; offers are rare and need a reason, so you may not see
one); remote coaches only from 16; the coach's reason for a lighter day ("you'll get more out of the week"); the goals offer no longer
says "Far away" twice.

## Season playtest 2 (2026-10-18): the user's notes, sorted, and what the save showed

**Verdict (user):** "a bit tedious micromanagement clicker with a boring, non-immersive racing. Got bored at the start of the year. I
don't know why things are happening, what is affecting what, does anything really matter. We have somewhat lost the essence of being a
career simulator." Tried the Dev jump to reach the school choices and could not (the messages always interrupted).

**What the save showed** (`autosave.json`, Nooa Toivonen, 2 Nov 2026 → 9 Sep 2027, 44 weeks; read-only copy):
- **The year is realistic as a career:** 17 races, PB 2:33.5 (Jan) → 2:20.06 (17 Jun, Youth Athletics Games);
  places 1-6 at local meets, 15th of 16 at the hall SM and 14th of 15 at the summer SM (time 2:24, the SM limit 2:21 was reached on 17 Jun:
  goal "met"); one obstruction DQ (Lajikarnevaalit, 23rd of 23). Ability 6.77 → 8.46 (+1.7 in 10 months: an early developer with
  trainability 12.7 and an athletics parent; playtest 1's +1.2 was a weaker start). Attributes grew 1-3 points in the trained ones, the
  mental ones and `starts` hardly moved. Health: one foot niggle (14 days), two colds (8 days) = 22 days of 310, a little under real
  adolescent runners. School: grade average 9.1 (the "top of the class" answer), two report cards.
- **Not realistic / not working:**
  1. **Too many moments, from too small a pool:** 240 moments in 36 weeks (6.7 a week counting the talk's "ack" messages: 24) from
     only 101 different storylets; 25 of them came 3-7 times; the same ones recur (fam_athlete_tips 6, gr_talker_gossip 7, fr_cinema 5);
     **35 were never answered**. (The user: "the same interactions and chats start popping up".)
  2. **Coach proposals: 40 in 44 weeks, 38 of them "lighter"**; the coach called every one "Good idea" while the model's own truth said
     "Fine" for 31 of 40 (the audit's finding, now seen in a real save); 14 vetoed. 16 had the reason "work" on a LIGHTER change.
  3. **The habit goal is always met:** "92 % of the sessions in your plan: 352 of 352 (100 %)" while the Sunday talk said "8 of 11 done
     this week". The goal counter counts a day the coach or an injury lightened as done, the talk counts it as missed.
  4. Content that contradicts the player's own choices (see the table: the rippi question after "I don't want to go"; the phone at one
     o'clock after "phone off at ten" and a standing rule; a protein-powder question that offers no powder).
  5. The coach says "he" about Marja (a woman): the texts hard-code "he" in about 300 places.

**Questions the user asked, answered (Claude, from the code and data):**
- *Can you make new friends / a relationship?* No. The cast is made at the start (parents, 2-3 friends, partners, teachers, rivals who
  became people); nothing adds a friend or a romance later. P2 / later.
- *The training group: where is its benefit, can I opt out?* There is none yet: the group is flavour (names, a few messages and the fit
  calculation of the coach). "The training group's pull in hard sessions" is on the backlog for B1. You cannot opt out.
- *Are there camps (leirit) at this age?* Yes: SUL's Pajulahti "Yläkoululeiritys, Yleisurheilu" for grades 7-9 (four Monday-Friday camps in
  2026-27, 355 euros each, you apply by 31 Aug and SUL picks) plus district and club camps; the game shows the four on the Calendar as
  information only. The camp week itself is session G3.
- *What is focusing on subjects / grades for?* The final certificate's average decides the lukio application (grade 9); in grade 8-9 it also
  feeds your life load and the coach's view of you. The School page does not say it clearly.
- *Does an easy day carry into next week?* No: a day change belongs to that week; every Monday the week is built again from the plan.
- *"Tell me if your shins are sore on Wednesday": why no event?* It is only a closing line of the Sunday talk. The game itself watches the
  shins and posts a warning when they get sore; the sentence promises something the player cannot do.
- *What does it mean when my motivation goes up from the answers?* A small mood point: motivation moves training quality between x0.92
  and x1.05 (mostly the middle) and nothing else you can see. The same is true for "Eino ▼ a little": a relationship number that changes
  which moments can come and the mood pulls a little. The UI never shows the effect.

**The notes, sorted** (Verified: B = a bug confirmed in code or data, D = a design gap, F = a feature request, ? = could not reproduce):

| Note | Kind | Verified |
|---|---|---|
| "Marja" is not a he (the coach's texts) | bug | B: "he / his / him" hard-coded in the coach's UI and data texts (~300) |
| "Confidence confident: you race a little faster at a meet like this" | text bug | B: the mood name and the word are glued |
| Rippikoulu question though "I don't want to go" was answered | bug | B: `fr_rippi_together` has no `!rippi_none` condition |
| Phone until 1 o'clock though phone off at ten / early sleep | bug | B: `fam_screen` states a fact the game never simulated, repeats 4x after the rule |
| "It's a bit too much for your shins" after adding mobility & stretching | bug | B: mobility has no strain; his noise (`perceive`) made a risk out of nothing |
| "Fresh enough" to go from Normal to Easy | bug | B: the reason `work` is used for lighter changes too (my fix of 2026-10-18 only softened the words) |
| Asked the coach about my edit, she said fine, then proposed a change to that very day | bug | B: proposals do not remember "Ask the coach" |
| Niggle before the race, skipped it, the coach said nothing before or after | gap | B: `Game.scratch_race` posts no coach reaction |
| "Tell me if ... on Wednesday", nothing happens | text bug | B: a closing line with no mechanism |
| 8/11 done this week vs 352 of 352 planned sessions | bug | B: two definitions of "done" (above) |
| Dev jump cannot pass the school years, messages always interrupt | tool bug | B: `DevTools.jump` stops at every stop event |
| School test results never pop up (only on the School page) | gap | D |
| Messages and school grades in one view: cluttered | UI | D |
| Click-heavy, clutter, "what do my answers change?", repetitive options, texty, not pretty, "the coach's block of text" | the big one | D: consequences are small and invisible; the content pool is small and canned (the save: 101 variants, 240 moments) |
| Wayyy too many events with "stop for every event" | setting | D: by design (every moment is a stop); the default is Important only |
| I can't see if I'm too tired; want the whole week block when the coach suggests a change | missing | D / F |
| "You see it in the day view" breaks the fourth wall | text | D |
| "Listen to your shins" but I only see a popup | missing | D: the body is only visible in the Overview / day editor |
| Season goals: what does met / missed mean; more milestone and habit options; a mid-season review | missing | D / F (met: +trust and a message; missed: a talk, no loss; there is no review before the end of the season) |
| Compare my coach with the offered coaches (like FM) | missing | F |
| "Mental training" feels rushed, no options | thin | D (M1 was kept small on purpose) |
| New friends, a relationship | missing | F (P2+) |
| Training group: benefit visible, opt out | missing | D / F (backlog B1) |
| Camps at this age (leirit) | question | answered above; G3 |
| What subject focus means (the lukio application) | unclear | D (School page needs one line) |
| Race: why "swing wide and go round" here? | unclear | D: the card does not say what each choice costs or why it is offered |
| Race: "Wait at the back" is called Hold, why not Ease? | naming | D |
| Race: no way back to the inside line, only out | missing | F |
| Race: everything slows down when everyone kicks | design | D (R3's "drop to 1x" moments; make it optional or shorter) |
| Race: 2D blobs on a horrible-looking track; bigger arenas need zoom; realistic graphics (needs research) | big | F: race presentation |
| Race: effects on me, my attributes, my relationships; pre-race warm-up and post-race cool-down | missing | F |
| All my race results in one list (the Overview skims it) | missing | F |
| In race season the Training tab and the day-by-day view differ | ? | to check (the week's changes and the race day replace sessions in the day view) |
| In People I cannot choose any option in the chats | ? | could not reproduce: waiting moments show their reply buttons on top of the thread; maybe answered ones were meant (needs the user's example) |
| A deep skill tree; "we have lost the essence of a career simulator"; the training is monotonous | direction | D: for a design session |
| Wants "see from the save how my year went": done above | | |
