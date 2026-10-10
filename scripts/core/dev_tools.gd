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
	HealthSystem.model_enabled = false   # (no injury gets in the way of the race; Game leaves test mode on a new or loaded career)
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
## (the race screen is next) or a stop event (the hub shows it) comes first. The autosave is written once at the end.
## → {result (Game.DAY_DONE / WEEK_DONE / RACE / STOP), days}
static func jump(until: Dictionary) -> Dictionary:
	var days := 0
	var result := Game.DAY_DONE
	var autosave_before := Game.autosave
	Game.autosave = false
	var limit := 800   # (more than two years: a jump with no date and no race in sight ends anyway)
	while days < limit:
		if not until.is_empty() and Calendar.date_key(Game.date) >= Calendar.date_key(until):
			break
		result = Game.advance_day()
		days += 1
		if result == Game.RACE or result == Game.STOP:
			break
	Game.autosave = autosave_before
	if autosave_before:
		SaveGame.save(SaveGame.AUTOSAVE)
	return {"result": result, "days": days}


## The next 1st of `month` (1-12) after today, as a date.
static func next_first_of(month: int) -> Dictionary:
	var year := int(Game.date.year)
	if month <= int(Game.date.month):
		year += 1
	return {"year": year, "month": month, "day": 1}
