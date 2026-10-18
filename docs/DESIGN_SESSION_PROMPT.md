# Prompt for the design session after season playtest 2

Paste the part between the two lines into a NEW conversation (Opus, high effort). The appendix at the end holds the user's raw
playtest notes word for word; the prompt tells the session to read this file.

---

You are the design lead for **Track & Field Career**, a Godot career-mode game about a Finnish 800 m runner (14 years old and up), which
I (the user, no programming experience) am building together with you. **This session is a DESIGN session: no code and no data edits.**
Talk to me in plain language, give honest opinions, and ask me before deciding anything that changes how the game plays.

**Read first** (in this order): `CLAUDE.md` (rules and the map of systems); `docs/PLAYTESTS.md` (the section "Season playtest 2": the
sorted notes, what my save showed, the answers I already got); the appendix of `docs/DESIGN_SESSION_PROMPT.md` (my raw notes, word for
word, with screenshots described); `docs/AUDIT.md` "Check-in (2026-10-18)" part 3 (your own review: "we are building blind"); `docs/GDD.md`
sections 1-2 (the vision) and 4.9 (coaching, school, the mind, people and moments, minigames); `docs/ROADMAP.md`. Read `docs/CODEMAP.md`
only for the system you are talking about.

**Where we are.** About 27 000 lines of coaching, school, mind, people and moments were built in a week (sessions C1-P1) and checked only
by tools. My first real playtest of them was yesterday. My verdict: *"a bit tedious micromanagement clicker with a boring, non-immersive
racing. I got bored at the start of the year. I don't know why things are happening, what is affecting what, does anything really matter.
We have somewhat lost the essence of being a career simulator."* The races (before the new systems) were the part I liked most in
playtest 1; now even they feel like "2D blobs on a horrible-looking track".

**The core problem, in my words:** it is too much clicking on **nonsense answers to nonsense questions** that become repetitive after a
while. I click an option hoping it goes right, I do not know what it changed, and the same chats come back. "It is not interactive in the
way I want it to be." Everything is a block of text; I want things sleeker, prettier, easier to read, more refined, "informative yet
easy to read".

**What my save showed (facts, so you do not have to guess):** 44 weeks, 240 moments from only 101 different storylets (some 6-7 times),
35 never answered; 40 coach proposals, 38 of them "lighter", all called "Good idea" while the game's own check rated 31 "Fine"; the habit
goal "92 % of the sessions" read 352 of 352 while the Sunday talk said 8 of 11; events that contradict my own choices (a rippikoulu
question after "I don't want to go", "phone until one" after "phone off at ten"); the coach (Marja) is called "he" in about 300 texts;
a Dev jump that cannot get through a school year because every message stops it. The career itself was realistic (PB 2:33.5 to 2:20.06,
17 races, plausible placings, light health). So the *simulation* is fine and the *game around it* is the problem.

**What I want from this session:** decide what a week and a season should FEEL like before anything else is built. Work it as a
conversation: propose, argue with me, ask 2-4 focused questions at a time (each with your recommendation), show a mock-up when a screen
matters. Do not write the GDD until we agree; then write the decisions into the GDD and reorder the ROADMAP.

**The questions to settle** (with your own opinion on each):
1. **The loop.** What is one week of play, and who drives it: me through decisions about training and life, or the world through
   events? Which of today's systems earn their place and which should be cut, merged or made passive background: the coach's Sunday talk,
   the coach's proposals and Veto, the people's Q&A moments, season goals, the mind (moods), school stops, the coach market? Be willing to
   cut things we built. The rule I suggest, for you to improve: **a stop only for a real decision whose consequence I can see afterwards;
   everything else is visible state or a quiet feed, not a question.**
2. **Causes made visible.** A "why" view for my body (am I too tired? what is the strain?), form, mood and the week's result; what every
   answer changed (a "Eino ▼ a little" tells me nothing); the effects of a race on me, my attributes and my relationships; a week
   block shown whenever the coach suggests a change; a mid-season review of the goals.
3. **People: friends, relationships, the training group.** I asked why I cannot make new friends or go into a relationship. There is no
   rule against it: the cast is fixed at the start (parents, 2-3 friends, teachers, partners from the group) because only the first part
   of the people content (P1) was built. Real life at 14-17 is full of new people: a new class and school, new teammates, rivals who become
   friends, camps, the first crush or girlfriend / boyfriend (keep that age-appropriate: texting, time together, what it does to my time,
   mood and sleep; nothing more). But **adding them as more question popups would make the problem worse.** Design them as persistent state
   plus shared time instead: a person page that shows the relationship and what it gives or costs, free-time slots in the week (friends,
   family, rest, a hobby) that compete with training, events that come from the calendar and the state (a party on the Saturday before a
   race is a real conflict), and a question only when there is a real conflict with a visible price. The training group needs a real,
   visible effect (and the option to leave it) too.
4. **Depth and variety.** The training feels monotonous. Is there room for a development / skill tree or specialisation, camps (the
   Pajulahti camps for grades 7-9 are researched), warm-up and cool-down before and after races, test days, the training group's effect?
5. **Racing and presentation.** The race screen: immersion, graphics (research what real race graphics could look like and what Godot can
   do), zoom for bigger arenas, the slow-down when everyone kicks (make it optional or shorter), a way back to the inside line, plain
   labels ("Wait at the back" should say what it does), a place that lists all my race results. The race engine itself I liked: keep it.
6. **The look.** The roadmap already has a UI overhaul after M2 ("too AI"); my notes say sleeker, prettier, more refined, less text.
   Decide whether to pull it forward, and what visual direction I should choose between (references and screenshots, my pick).
7. **The career-simulator essence.** What is the long arc that makes me want to play tomorrow: seasons, milestones, reputation, a
   story of a career? What is missing against the vision in GDD 1-2?

**Constraints (from CLAUDE.md, do not re-litigate without a reason):** the race engine stays untouched unless we decide otherwise in a
race session; the neutral "lab" setting keeps the fingerprints identical; realism over neat balance; world data lives in data files with a
source; no real people below senior level; the player decides, the game does not (no automatic decisions in races); I have no programming
experience, so explain in plain steps; ask me before anything that changes how the game plays beyond what we agree. The Sunday talk
always stopping Play week and the coach's proposals stay as they are until we decide here; I said "keep as it is" for now.

**Output of the session:** (a) the decisions, written into the GDD as a dated section, after my OK; (b) a short list of what to CUT or
turn into background; (c) a reordered ROADMAP with the next sessions, each with a model recommendation (Opus / Sonnet) and what done
looks like, including the 11 confirmed bugs of the playtest 2 table (coach pronouns, the rippi / phone / "confidence confident" texts, the
lighter-day reason, ask-then-propose, the scratch reaction, the habit counter, the Dev jump); (d) a list of research I should let you do
(race graphics, real camps, whatever you need). Commit the docs at the end and tell me to press "Push origin".

---

## Appendix: the user's raw playtest notes (2026-10-18), word for word

Screenshots described: (1) the season goals offer ("Goals for 2026-27": a time 2:18.50, "Reach the SM limit (2:21.00)", "Do 92 % of the
sessions in your plan"); (2) the coach's verdict "Pointless: I wouldn't bother. It's a bit much for your shins, and it doesn't give you
much" after the user added mobility & stretching; (3) the coach's proposal "You asked for more training. Tuesday: Club group session +
Strength & core at Hard instead of Normal. It makes the week better training, and you're fresh enough for it. OK with you?" with the
buttons OK / Veto: I'm too tired / Veto: Not this week / Veto, no reason; (4) the answered card "Good question. Every session has a
reason, and I will tell you what it is. You can see it in the day view." with "Trust in Marja ▲ somewhat"; (5) the Sunday talk ("One
thing this week: Listen to your shins. Tell me if it gets worse.", "I noticed you were not moving freely this week. Is anything
hurting?" with three answers); (6) a race card "Home straight: Iiro Kinnunen is right in front of you. Your word: Strong. Coach: Go wide.
Clear space." with "Swing wide and go round" / "Wait for a gap on the inside"; (7) the line "CONFIDENCE CONFIDENT: you race a little
faster at a meet like this."; (8) Dad: "I read that athletes need more protein. Is that true? Should I buy that powder?" with Normal food /
I'll ask Marja / Pasta every day; (9) Dad: "You were on your phone until one o'clock. You have a hard session tomorrow, don't you?" with
OK, phone off at ten / Just one more video; (10) the goal row "Do 92 % of the sessions in your plan: 352 of 352 planned sessions done
(100 %)".

general notes:

* season goals: what does it mean if a goal is accomplished or if it's not? milestone and habit could use more options
* can you make new friends or are you locked with the ones you start with? what about a relationship?
* training group: where do i see the benefit of this exact training group? could you opt out of being in a training group if you deem them ineffective for your development?
* in real life, is there camps (leirit) at this age?
* what is the meaning of focusing on some subjects and the grades overall? to apply for lukio etc. right?
* in "find a coach", there should be a way to compare your now-coach and the coaches that offer their services to you (like in FM)
* "mental training" portion seems a bit rushed and void of options
* i added a "mobility and stretching" - "it's a bit too much for your shins" sounds weird
* why would I care if "eino (down icon) a little" when I answer no? what is the damage done?
* "Marja" is not a he
* I can't see anywhere if I'm too tired, I'd like to see the whole week training block when she suggests me the changes
* "you see it in the day view" seems very arbitrary and breaking the 4th wall
* it's too much that the messages and the school grades are in the exact same view, too cluttered
* are you sure that if the coach turns something easy for the day in 1 week that it doesn't carry over to the next week? if tuesday was easy but normally normal, next week it's not still easy?
* again, "listen to your shins", ok but I don't know how they're feeling because I'm just inside this one popup window
* "tell me if your shins are sore on wednesday" -> wednesday passes, no event?
* what does it mean when my motivation goes up from the answers?
* i don't understand how i can be "fresh enough" to go from normal -> easy
* I got a niggle just before the race (even though we switched to easy) and I skipped the race but the coach said absolutely nothing about it before or after the race
* wayyyy too many events when i choose "stop for every event"
* is the week before a race (or the race week) really ever planned? the coach seems to ask the easing questions that week when I feel these should kind of automatically be in the training regime when I have selected the races from the calendar or smth
* why would i swing wide and go round in this situation? wtf?
* it all feels too click-heavy, way too much like clutter, and I feel like what real effect or consequence my answers really have on anything?
* maybe implement a deep skill tree or something?
* the races feel just like 2d blobs running around a horrible looking track - it's very uninteresting and rather unimmersive experience which is a huge shame
* i want to see what effects the race had on me and my attributes, my relationships etc.
* pre-race warmups, post-race cooldowns are needed
* why does wait at the back automatically mean hold? why isn't it "ease"?
* "confidence confident"?
* why couldn't i choose "powder"
* the answering options just become repetitive after a while and I'm irritated of seeing them, it's not interactive in the way I want it to be
* got a rippikoulu question even though i'm not attending one
* how can i be on my phone until 1 o'clock when i have set it so i go to sleep early
* the same interactions and chats start popping up
* i don't understand why the coach does what things, this is all just a block of text to me and i click some option hoping it goes right but like i need something informative yet easy-to-read
* everything is very texty: i want things to be sleeker, prettier, easier to read, like more refined
* the school test results just never pop up, am i supposed to go to the school screen every single time
* there needs to be a zoom option in bigger and smaller meets, i can't see shit in the bigger arenas
* i don't understand when i chose the mental word or whatever, i see it in the race (strong) but what the hell does it mean
* season goals - shouldn't there be a review at some point about if we are going to achieve them or not?
* we have somewhat lost the essence of being a career simulator
* the training feels somewhat monotonous (maybe the options?)
* i don't understand these random events, they just feel so off
* how can i have "done all planned sessions" when the coach has at times been like "8/11 done this week"
* maybe if the race screen was overhauled it would feel more interactive? like real, realistic graphics (this needs research)
* i'd like to see all my race results (in overview you just kind of overlook it), and like a proper
* in race season, the training seen in training and day-by-day seem to be quite different
* i don't like it how everything slows down when everyone kicks, that just slows the gameplay down too much
* when you go into the chats in people, you can't choose any of the options
* i modify the training, she says it's fine, immediately when i try to advance day, she tries to edit just the day i had changed and she confirmed it was good
* why can't there be an option to "go back to inside line", only to go out?

+see from the save file how my year went and see if all things were realistic

all in all, just a bit tedious micromanagement clicker with a boring, non-immersive racing. got bored at the start of the year, wanted to play through to the school choosing phase, couldn't do it through dev (i think the messages always interrupted). i don't know why things are happening, what is affecting what, does anything really matter.
