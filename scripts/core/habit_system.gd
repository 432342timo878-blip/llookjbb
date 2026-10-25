class_name HabitSystem
extends GameSystem
## The free-time slots and the standing habits (GDD 4.10 decision 6, session L1b). GameSystem id "habits".
## A week has 9 free-time slots: every school-day evening (Mon-Fri) and the free part of Saturday and Sunday (after training);
## here they are 7 entries, index = weekday (0 = Monday). Each holds an activity: study / rest / friends / family
## (data/habits.json; a partner and a hobby come with P2). They are state the week plays, never questions:
##   - The standing HABITS (`habits`) fill every week's slots. The player sets them in the Season tab.
##   - A slot can be changed for THIS week only (`week_slots`) on the planner or in the day editor; the planner never changes
##     itself and a habit fills a slot only as the player set it.
##   - An INVITATION (StoryletSystem, a storylet with an `invite` part) lands in a slot of the coming week; Go makes the slot the
##     invitation (`activity_on` reads it from the moments).
## What the slots do replaces the school's two old weekly settings (study effort, free time): the grade target (grade_shift),
## the life load of school days (load_parts: extra study, a late night after friends, an early night after rest), the motivation
## and stress pulls (MindSystem.pulls). The default habit (study Mon-Thu, friends Fri + Sat, family Sun) is the neutral one: every
## effect is exactly 0 there, so the game is the old Normal / Normal to the last digit (and `lab` keeps every fingerprint).
## The life load and the moods follow the school's switches (`effects_on`: off with the school model off or neutral, like the
## old settings); the grade shift works whenever the school does (grades drift in the neutral school too, as before).
## No dice. Saved since save version 5; an older save's two settings become the nearest habits (`from_old`, Game.from_dict).

const ACTIVITIES := ["study", "rest", "friends", "family"]
const KEEP_HISTORY := 9

var habits: Array = []        # 7 activity ids, Monday .. Sunday
var week_key := 0             # the date key of the Monday whose one-week changes `week_slots` holds
var week_slots := {}          # day index -> activity id: this week's changes (the planner, the day editor)
var history := {}             # day number (as text) -> the activity the slot of that played day had ("last night" on Monday)

## A week's 7 activities by "monday key|today key|revision" (the life load asks for them many times a day: the day, the health
## model, the moods, the coach's simulations). Anything that can change a slot calls touch(); StoryletSystem does when an
## invitation is posted, planned or settled. Not saved.
static var _rev := 0
var _week_cache := {}          # monday date key -> {acts, went, study}, valid for `_stamp`
var _stamp := Vector2i(-1, -1) # (today's date key, _rev) the cache was made for
var _days := {}                # date key -> [weekday, its Monday, the Monday before] (pure calendar: kept)


static func touch() -> void:
	_rev += 1


func _init() -> void:
	id = "habits"
	habits = default_habit()


static func cfg() -> Dictionary:
	return Data.habits


## The career's habit system (null before a career has its systems).
static func sys() -> HabitSystem:
	return Game.get_system("habits") as HabitSystem


static func default_habit() -> Array:
	return (cfg().default as Array).duplicate()


## The slots' life load and mood pulls count (the school model on and not neutral; the old settings worked the same way).
static func effects_on() -> bool:
	return SchoolSystem.model_enabled and not SchoolSystem.neutral and Game.athlete != null


static func activity_name(act: String) -> String:
	return str(cfg().activities.get(act, {}).get("name", act))


static func activity_icon(act: String) -> String:
	return str(cfg().activities.get(act, {}).get("icon", "moon"))


static func slot_name(i: int) -> String:
	return str(cfg().slots[i].name)


static func slot_short(i: int) -> String:
	return str(cfg().slots[i].short)


## "evening" (Mon-Fri) / "day" (Saturday, Sunday).
static func slot_kind(i: int) -> String:
	return str(cfg().slots[i].kind)


# --- The habits (the Season tab) -------------------------------------------------------------------------------------------

func habit(i: int) -> String:
	return str(habits[i]) if i >= 0 and i < habits.size() else str(cfg().default[i])


func set_habit(i: int, act: String) -> bool:
	if i < 0 or i > 6 or not act in ACTIVITIES:
		return false
	habits[i] = act
	if week_slots.get(i, "") == act:   # (a one-week change that the habit now matches is no change any more)
		week_slots.erase(i)
	touch()
	return true


func set_habits(list: Array) -> void:
	for i in 7:
		if i < list.size() and str(list[i]) in ACTIVITIES:
			set_habit(i, str(list[i]))


func reset_habits() -> void:
	set_habits(default_habit())


func is_default() -> bool:
	return habits == default_habit()


## An older save's two settings (study effort, free time) as habits (data/habits.json from_old).
func from_old(effort: String, free_time: String) -> void:
	var table: Dictionary = cfg().from_old
	var key := "%s|%s" % [effort, free_time]
	set_habits(table.get(key, cfg().default))


# --- This week's slots (the planner, the day editor) -----------------------------------------------------------------------

func _sync_week() -> void:
	if Game.athlete == null:
		return
	var k := Calendar.date_key(Game.week_monday())
	if k != week_key:
		week_key = k
		week_slots = {}
		touch()


func on_week_start(w: WeekSim) -> void:
	week_key = Calendar.date_key(w.monday)
	week_slots = {}
	touch()


## Day `i` of this week: the one-week change, else the habit (an invitation is not counted here: see activity_on).
func week_slot(i: int) -> String:
	_sync_week()
	return str(week_slots.get(i, habit(i)))


func changed(i: int) -> bool:
	_sync_week()
	return week_slots.has(i)


## A slot of this week can change while its day is not played (today's evening still can).
func can_change(i: int) -> bool:
	return Game.athlete != null and i >= Game.current_week().day and i < 7


## This week only: day `i`'s slot becomes `act` (the habit's own activity = back to the habit). False when not allowed.
func set_slot(i: int, act: String) -> bool:
	if not act in ACTIVITIES or not can_change(i):
		return false
	_sync_week()
	if act == habit(i):
		week_slots.erase(i)
	else:
		week_slots[i] = act
	touch()
	return true


func reset_slot(i: int) -> bool:
	if not can_change(i):
		return false
	_sync_week()
	week_slots.erase(i)
	touch()
	return true


# --- The slot of a date --------------------------------------------------------------------------------------------------------

## The activity a date's slot has: a played day as it was (history), this week's with its changes and an invitation you go to,
## a later week's from the habits.
func activity_on(d: Dictionary) -> String:
	if Game.athlete == null:
		return habit(Calendar.weekday(d))
	var di := _day(d)
	return str(_week_entry(di[1]).acts[int(di[0])])


## [weekday, the Monday of its week, the Monday of the week before] of a date (cached: the calendar's helpers convert dates
## through the clock, and the life load asks this many times a day).
func _day(d: Dictionary) -> Array:
	var k := Calendar.date_key(d)
	if not _days.has(k):
		if _days.size() > 800:
			_days.clear()
		var wd := Calendar.weekday(d)
		var monday := Game.add_days(d, -wd)
		_days[k] = [wd, monday, Game.add_days(monday, -7)]
	return _days[k]


## The week starting `monday` as 7 activities, cached (see `_week_cache`).
func _week_list(monday: Dictionary) -> Array:
	return _week_entry(monday).acts


## The cached week: {acts (7 activities), went (7 bools: an invitation you went to / are going to), study (the study count)}.
func _week_entry(monday: Dictionary) -> Dictionary:
	var stamp := Vector2i(Calendar.date_key(Game.date), _rev)
	if stamp != _stamp:
		_stamp = stamp
		_week_cache = {}
	var key := Calendar.date_key(monday)
	if _week_cache.has(key):
		return _week_cache[key]
	var acts := []
	var went := []
	for i in 7:
		var d := Game.add_days(monday, i)
		acts.append(_activity_now(d))
		var inv := invitation_on(d)
		went.append(not inv.is_empty() and going(inv))
	var entry := {"acts": acts, "went": went, "study": int(counts(acts).study)}
	_week_cache[key] = entry
	return entry


func _activity_now(d: Dictionary) -> String:
	var wd := Calendar.weekday(d)
	var n := StoryletSystem.day_no(d)
	if n < StoryletSystem.day_no(Game.date):
		return str(history.get(str(n), habit(wd)))
	if Calendar.date_key(Calendar.monday_of(d)) == Calendar.date_key(Game.week_monday()):
		var away := away_on(d)
		if not away.is_empty():   # (session L3a: a story beat's days, the confirmation camp)
			return str(away.activity)
		var inv := invitation_on(d)
		if not inv.is_empty() and going(inv):
			return str(inv.invite.activity)
		return week_slot(wd)
	return habit(wd)


## Session L3a: the slot a story beat you said yes to, or the confirmation camp, takes on date `d` ({activity, chip, title,
## moment}) or {}.
static func away_on(d: Dictionary) -> Dictionary:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return {}
	return ms.away_on(d)


## The invitation in a date's slot (a moment of StoryletSystem with an `invite` part, waiting or answered), or {}.
static func invitation_on(d: Dictionary) -> Dictionary:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return {}
	return ms.invitation_on(d)


## The player said Go to the invitation (its planned reply is one of the accepting ones).
static func going(inv: Dictionary) -> bool:
	var reply := str(inv.get("planned", ""))
	if reply == "" and str(inv.get("answer", "")) != "" and str(inv.answer) != StoryletSystem.NONE:
		reply = str(inv.answer)
	return reply != "" and reply in inv.invite.get("go", [])


## The week's 7 activities (Mon..Sun) of the week starting `monday`.
func week_activities(monday: Dictionary) -> Array:
	return _week_list(monday).duplicate()


static func counts(list: Array) -> Dictionary:
	var out := {"study": 0, "rest": 0, "friends": 0, "family": 0}
	for act in list:
		out[str(act)] = int(out.get(str(act), 0)) + 1
	return out


# --- What the slots do ---------------------------------------------------------------------------------------------------------

## The grade target's shift on a school day of the week of `d` (exactly 0.0 at the neutral number of study slots).
func grade_shift(d: Dictionary) -> float:
	return shift_for(int(_week_entry(_day(d)[1]).study))


static func shift_for(study: int) -> float:
	var e: Dictionary = cfg().effects
	var x := float(study - int(cfg().neutral.study)) * float(e.study_grade_per_slot)
	return clampf(x, -float(e.study_grade_max), float(e.study_grade_max))


## The slots' parts of a SCHOOL day's life load ([{id, value, n?}], positive parts x the stage's `scale`): extra study in the week,
## a late night after a friends evening, an early night after a rest evening. An invitation you went to brings its own late night
## (its `sleep` effect, StoryletSystem.late_nights), so its slot adds nothing here. Empty when the effects are off.
func load_parts(d: Dictionary, scale: float, school_day := false) -> Array:
	var out := []
	if not effects_on():
		return out
	if not school_day:   # (SchoolSystem.load_parts calls it on school days only and says so: no second calendar lookup)
		var ss := SchoolSystem.sys()
		if ss == null or str(SchoolCalendar.day(ss.town(), d).get("kind", "")) != "school":
			return out
	var e: Dictionary = cfg().effects
	var di := _day(d)
	var wd := int(di[0])
	var study := int(_week_entry(di[1]).study)
	var extra := study - int(cfg().neutral.study)
	if extra > 0:
		out.append({"id": "slot_study", "value": extra * float(e.study_load_per_slot) * scale, "n": study})
	var be := _week_entry(di[1] if wd > 0 else di[2])   # (the evening before: Monday's is last Sunday)
	var bi := wd - 1 if wd > 0 else 6
	if bool(be.went[bi]):
		return out
	match str(be.acts[bi]):
		"friends":
			out.append({"id": "slot_friends", "value": float(e.late_friends) * scale})
		"rest":
			out.append({"id": "slot_rest", "value": float(e.early_rest)})
	return out


## Motivation's pull from the slots of the week starting `monday`: [{text, delta}] (empty at the neutral count).
func motivation_pulls(monday: Dictionary) -> Array:
	if not effects_on():
		return []
	var n := int(counts(week_activities(monday)).friends)
	var delta := float(n - int(cfg().neutral.friends)) * float(cfg().effects.motivation_per_friend)
	if delta == 0.0:
		return []
	var t: Dictionary = cfg().texts
	return [{"text": str(t.motivation_up if delta > 0.0 else t.motivation_down).format({"n": n}), "delta": delta}]


## Stress's pull from the family slots of the week starting `monday` (only above the neutral count).
func stress_pulls(monday: Dictionary) -> Array:
	if not effects_on():
		return []
	var n := int(counts(week_activities(monday)).family)
	var over := n - int(cfg().neutral.family)
	if over <= 0:
		return []
	return [{"text": str(cfg().texts.stress_family).format({"n": n}), "delta": -float(over) * float(cfg().effects.stress_per_family)}]


## The school's old words for what the habits amount to (SchoolSystem.to_dict keeps its "effort" / "free_time" keys with these,
## so a career's school state saves exactly as before): light / normal / heavy by the grade shift, little / normal / lots by the
## friends slots.
func effort_word() -> String:
	var k := _old_key()
	if k != "":
		return k.get_slice("|", 0)
	var s := shift_for(int(counts(habits).study))
	return "heavy" if s > 0.0 else ("light" if s < 0.0 else "normal")


func free_word() -> String:
	var k := _old_key()
	if k != "":
		return k.get_slice("|", 1)
	var n := int(counts(habits).friends)
	var neutral := int(cfg().neutral.friends)
	return "lots" if n > neutral else ("little" if n < neutral else "normal")


## "effort|free_time" when the habits are exactly one of from_old's (so an old setting reads back as itself), else "".
func _old_key() -> String:
	var table: Dictionary = cfg().from_old
	for k in table:
		if k != "_note" and habits == table[k]:
			return str(k)
	return ""


## What the habits weigh on an ordinary school week, per school day on average (the habits alone, the stage's scale).
func habit_load(scale := 1.0) -> float:
	var e: Dictionary = cfg().effects
	var total := 0.0
	var extra := int(counts(habits).study) - int(cfg().neutral.study)
	for i in 5:
		if extra > 0:
			total += extra * float(e.study_load_per_slot) * scale
		match habit((i + 6) % 7):   # the evening before (Monday: Sunday)
			"friends":
				total += float(e.late_friends) * scale
			"rest":
				total += float(e.early_rest)
	return total / 5.0


## The one line under the habits: "Grades hold · motivation steady · school days normal" (+ "stress ▼").
func summary() -> String:
	var s: Dictionary = cfg().summary
	var c := counts(habits)
	var shift := shift_for(int(c.study))
	var parts := [str(s.grades_up if shift > 0.0 else (s.grades_down if shift < 0.0 else s.grades_hold))]
	var f := int(c.friends) - int(cfg().neutral.friends)
	parts.append(str(s.motivation_up if f > 0 else (s.motivation_down if f < 0 else s.motivation_hold)))
	if int(c.family) > int(cfg().neutral.family):
		parts.append(str(s.stress_down))
	var ss := SchoolSystem.sys()
	var scale := float(ss.stage_of(Game.date).get("scale", 1.0)) if ss != null and Game.athlete != null else 1.0
	parts.append(str(s.school_days).format({"word": SchoolSystem.life_word(habit_load(scale))}))
	return " · ".join(parts)


## The grades part alone ("Grades hold"), for the School page.
func grades_word() -> String:
	var s: Dictionary = cfg().summary
	var shift := shift_for(int(counts(habits).study))
	return str(s.grades_up if shift > 0.0 else (s.grades_down if shift < 0.0 else s.grades_hold))


# --- The report card's choice (S2's keep / harder / ease edit the habits by one slot) ----------------------------------------

## The slot "One more study evening" would change: {i, from} or {} (every slot is study already).
func more_study() -> Dictionary:
	for sid in cfg().card.more_from:
		var i := _slot_index(str(sid))
		if habit(i) != "study":
			return {"i": i, "from": habit(i)}
	return {}


## The slot "One study evening fewer" would change: {i} or {} (no study slot).
func less_study() -> Dictionary:
	for sid in cfg().card.less_from:
		var i := _slot_index(str(sid))
		if habit(i) == "study":
			return {"i": i}
	return {}


static func _slot_index(slot_id: String) -> int:
	var list: Array = cfg().slots
	for i in list.size():
		if str(list[i].id) == slot_id:
			return i
	return -1


# --- The slot as the planner shows it ------------------------------------------------------------------------------------------

## Day `d` of week `w` for the planner and the day editor: {i, date, played, habit, activity (with an invitation you go to),
## changed (this week only), invite (the moment or {}), late (the evening costs sleep: friends before a school day, or an
## invitation with a late night that is open or accepted), clash ("" / "race" / "hard": a late night before a race or a hard
## session), next (the next day: {date, race, sessions, intensity, school}), highlight (something landed on it)}.
func slot_info(w: WeekSim, d: int) -> Dictionary:
	var date := Game.add_days(w.monday, d)
	var played := d < w.day
	var inv := invitation_on(date)
	var away := away_on(date) if Calendar.date_key(w.monday) == Calendar.date_key(Game.week_monday()) else {}
	var info := {"i": d, "date": date, "played": played, "habit": habit(d), "activity": activity_on(date),
			"changed": not played and changed(d), "invite": inv, "away": away, "late": false, "clash": "", "highlight": false}
	var nx := _next_day(w, d)
	info.next = nx
	var sleep := 0.0
	if not inv.is_empty() and (going(inv) or str(inv.get("planned", "")) == "" and str(inv.answer) == ""):
		sleep = invite_sleep(inv)
	info.late = sleep < 0.0 or (str(info.activity) == "friends" and inv.is_empty() and bool(nx.school))
	if bool(info.late) and not played:
		if not nx.race.is_empty():
			info.clash = "race"
		elif nx.hard:
			info.clash = "hard"
	info.highlight = not played and (not inv.is_empty() or not away.is_empty() or str(info.clash) != "")
	return info


## The `sleep` effect of an invitation's accepting reply (negative = a late night), 0.0 without one.
static func invite_sleep(inv: Dictionary) -> float:
	var ms := Game.get_system("moments") as StoryletSystem
	if ms == null:
		return 0.0
	var s := ms.storylet(str(inv.get("storylet", "")))
	for r in s.get("replies", []):
		if str(r.id) in inv.invite.get("go", []):
			return float(r.get("effects", {}).get("sleep", 0.0))
	return 0.0


## The day after day `d` of week `w` (Sunday: next week's Monday from the season plan): {date, race (meet or {}), sessions,
## intensity, hard (intensity hard or a session tagged hard), school (a school day)}.
func _next_day(w: WeekSim, d: int) -> Dictionary:
	var date := Game.add_days(w.monday, d + 1)
	var out := {"date": date, "race": {}, "sessions": [], "intensity": WeekSim.NORMAL, "hard": false, "school": false}
	if d + 1 < 7:
		if w.is_race_day(d + 1):
			out.race = w.races[d + 1]
		else:
			out.sessions = w.session_ids(d + 1)
			out.intensity = w.intensity(d + 1)
	else:
		var races := Calendar.races_in_week(Game.entries, date)
		if races.has(0):
			out.race = races[0]
		else:
			var plan := WeekPlan.of(Game.season.week_for(date))
			out.sessions = plan.days[0]
			out.intensity = plan.intensity[0]
	out.hard = str(out.intensity) == "hard" or StoryletSystem._has_tag(out.sessions, ["hard"])
	var ss := SchoolSystem.sys()
	out.school = ss != null and str(SchoolCalendar.day(ss.town(), date).get("kind", "")) == "school"
	return out


# --- The day loop and saving -----------------------------------------------------------------------------------------------------

## Evening: remember what tonight's slot was (the next day's "last night"; Monday reads Sunday's from here).
func on_day_end(ctx: Dictionary) -> void:
	var n := StoryletSystem.day_no(ctx.date)
	history[str(n)] = activity_on(ctx.date)
	for k in history.keys():
		if int(k) < n - KEEP_HISTORY:
			history.erase(k)
	touch()


func to_dict() -> Dictionary:
	var slots := {}
	for i in week_slots:
		slots[str(i)] = week_slots[i]
	return {"habits": habits.duplicate(), "week": week_key, "slots": slots, "history": history.duplicate()}


## An empty state = the default habit (a new career, or a save from before version 5: Game.from_dict then sets the habits from
## the school's old settings).
func from_dict(d: Dictionary) -> void:
	habits = default_habit()
	week_key = 0
	week_slots = {}
	history = {}
	_week_cache = {}
	touch()
	if d.is_empty():
		return
	set_habits(d.get("habits", []))
	week_key = int(d.get("week", 0))
	for k in d.get("slots", {}):
		if str(d.slots[k]) in ACTIVITIES:
			week_slots[int(k)] = str(d.slots[k])
	for k in d.get("history", {}):
		history[str(int(float(k)))] = str(d.history[k])
