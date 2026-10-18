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
