class_name DevTools
extends RefCounted
## What the Dev menu does (debug builds only: the menu is not offered in an exported game, see DevMenu).
##   - start_test_race: a SEPARATE test career is made and played to a race of the kind asked for (indoor / outdoor,
##     sections / heats / any, a meet level, a boy or a girl); the race screen is opened by the Dev menu. Nothing of it is
##     saved (Game.dev_test: SaveGame.save does nothing), so the player's own saves are never touched. The same as
##     tools/watch_race.gd, for people who do not use a command line.
##   - jump: plays the CURRENT career forward to a date, the next race day or the next stop event, saving once at the end.


## The kinds of meet level a test race can be asked for ("" = any).
const LEVELS := ["", "local", "district", "national", "international"]


static func available() -> bool:
	return OS.is_debug_build()


## → {ok, message}. opts: indoor (bool), round ("" any / "sections" / "heats"), level (see LEVELS), female (bool), ability
## (0 = as created, about 5-6 for a 14-year-old; 9 = a youth finalist, 12 = a strong senior).
## The race waits in Game.race_day: open the race screen with Router.go("race").
static func start_test_race(opts: Dictionary) -> Dictionary:
	var indoor: bool = opts.get("indoor", true)
	var round_kind: String = str(opts.get("round", ""))
	var level: String = str(opts.get("level", ""))
	var female: bool = opts.get("female", false)
	var ability := float(opts.get("ability", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var choices := {
		"first_name": "Aino" if female else "Eetu", "last_name": "Testaaja", "gender": "female" if female else "male",
		"hometown": "Sastamala", "club_id": "", "main_event": "800m", "answers": {},
		"birth_date": {"year": int(Game.START_DATE.year) - 14, "month": 3, "day": 14},
	}
	var athlete := AthleteFactory.create(choices, rng)
	var autosave_before := Game.autosave
	Game.autosave = false   # (start_career would otherwise overwrite the player's autosave)
	Game.start_career(athlete)
	Game.dev_test = true
	Game.autosave = autosave_before
	GameConfig.set_option("health", false)   # (no injury gets in the way of the race; Game leaves test mode on a new or loaded career)
	if ability > 0.0:
		for id in Data.races.ability_weights:
			if not str(id).begins_with("_"):
				Game.athlete.set_attr(id, ability)
	for m in Calendar.meets_between(Game.date, Game.add_days(Game.date, 330)):
		if Calendar.can_enter(Game.athlete, m, Game.date).ok:
			Game.enter(m.key)
	if round_kind == "heats":
		RaceDay.format_override = "heats"   # (no youth meet is run with heats: forced, to try them)
	var skipped := 0
	var found := false
	while true:
		if not _to_race():
			break
		var rd := Game.race_day
		if rd.meet.get("indoor", false) == indoor and (round_kind == "" or rd.format == round_kind) \
				and (level == "" or str(rd.meet.level) == level):
			found = true
			break
		while not rd.is_done():   # not the kind asked for: run it quickly and go on
			rd.start_round(false, "pack").run()
			rd.finish_round()
		Game.finish_race()
		skipped += 1
	RaceDay.format_override = ""
	if not found:
		return {"ok": false, "message": "No %s race%s%s came up in a season of the test career (skipped %d races). Try another mix." % [
				"indoor" if indoor else "outdoor", "" if round_kind == "" else " run in " + round_kind,
				"" if level == "" else " at " + level + " level", skipped]}
	return {"ok": true, "message": "%s, %s (%s): the race is yours." % [Game.race_day.meet.name, Calendar.format_day(Game.date),
			", ".join(Game.race_day.rounds)]}


## Plays weeks until a race day (stop events answered "ok" = later). False when the season ends first.
static func _to_race() -> bool:
	for i in 60:   # (60 weeks: past the end of the season's meets)
		var r: String = Game.advance_week()
		while r == Game.STOP:
			Game.answer_event(Game.pending_event().id, "ok")
			r = Game.advance_week()
		if r == Game.RACE:
			return true
	return false


## Plays the current career forward, a day at a time, until `until` (a date; {} = no date) is today, or until a race day
## (the race screen is next) comes first. Session F1 (playtest 2: "the messages always interrupt", the school years could not be
## reached): every stop event on the way is answered with its default (default_answer) and the jump goes on; with `pass_races`
## a race day is run as a quick race in the pack (the Dev menu's date jumps) instead of ending the jump. The autosave is
## written once at the end. → {result (Game.DAY_DONE / WEEK_DONE / RACE), days, stops (answered), races (run)}
static func jump(until: Dictionary, pass_races := false) -> Dictionary:
	var result := Game.DAY_DONE
	var autosave_before := Game.autosave
	Game.autosave = false
	var first := Game.date.duplicate()
	var stops := 0
	var races := 0
	var limit := 800   # (more than two years: a jump with no date and no race in sight ends anyway)
	var guard := 0
	while Calendar.days_between(first, Game.date) < limit and guard < limit * 4:
		guard += 1
		if not until.is_empty() and Calendar.date_key(Game.date) >= Calendar.date_key(until):
			break
		result = Game.advance_day()
		if result == Game.STOP:
			var n := 0
			while not Game.pending_event().is_empty() and n < 50:
				var e := Game.pending_event()
				Game.answer_event(e.id, default_answer(e))
				stops += 1
				n += 1
			continue
		if result == Game.RACE:
			if not pass_races:
				break
			var rd := Game.race_day
			while not rd.is_done():
				rd.start_round(false, "pack").run()
				rd.finish_round()
			result = Game.finish_race()
			races += 1
	Game.autosave = autosave_before
	if autosave_before:
		SaveGame.save(SaveGame.AUTOSAVE)
	return {"result": result, "days": Calendar.days_between(first, Game.date), "stops": stops, "races": races}


## The answer a jump gives a stop event: the event's own `default` when it has one, else a message's first reply (answering
## nothing would cost trust week after week), else "ok" (every system reads "ok" as its default or "later").
static func default_answer(e: Dictionary) -> String:
	if str(e.get("default", "")) != "":
		return str(e.default)
	var choices: Array = e.get("choices", [])
	if str(e.get("kind", "")) == "moment" and not choices.is_empty():
		return str(choices[0].id)
	return "ok"


## The next 1st of `month` (1-12) after today, as a date.
static func next_first_of(month: int) -> Dictionary:
	var year := int(Game.date.year)
	if month <= int(Game.date.month):
		year += 1
	return {"year": year, "month": month, "day": 1}


## The 1st of `month` in the year `years` after the next one (next_first_of moved on by `years - 1` years): 1 Aug, 2 years on.
static func first_of_after(month: int, years: int) -> Dictionary:
	var d := next_first_of(month)
	d.year = int(d.year) + years - 1
	return d
