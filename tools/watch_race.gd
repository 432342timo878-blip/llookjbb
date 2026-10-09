extends SceneTree
## Dev tool for playtests (R5): jumps straight to a race to watch and play by hand. Needs a window:
##   godot --path . --rendering-driver opengl3 -s res://tools/watch_race.gd -- [indoor|outdoor] [heats|any] [female] [ability=N] [quit]
## Add `--resolution 390x844` before `-s` for the phone layout.
## Makes a new career (saves go to user://tool_saves/, never over your own), enters every meet the athlete may
## enter, plays the weeks (the health model off, so no injury gets in the way) and quick-runs every race until one
## of the kind asked for: indoor or outdoor, and with `heats` a championship with heats and a final. Then it opens
## the race screen and leaves the rest to you; after the race the game goes on as usual. `ability=N` sets the
## athlete's 800 m attributes to about N (default: as created, about 5-6 for a 14-year-old; 9 = a youth finalist).

var _indoor := true
var _heats := false
var _gender := "male"
var _ability := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		match a:
			"indoor": _indoor = true
			"outdoor": _indoor = false
			"heats": _heats = true
			"any": _heats = false
			"female": _gender = "female"
			"male": _gender = "male"
			_:
				if a.begins_with("ability="):
					_ability = float(a.substr(8))
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	load("res://scripts/core/save_game.gd").DIR = "user://tool_saves/"
	load("res://scripts/core/health_system.gd").model_enabled = false
	await _frames(10)
	var main := current_scene
	var router = main.get_node("/root/Router")
	var game = main.get_node("/root/Game")
	var data = main.get_node("/root/Data")
	router.go("new_career")
	await _frames(5)
	var wizard: Control = main.get_node("ScreenHost").get_child(-1)
	wizard._choices.first_name = "Aino" if _gender == "female" else "Eetu"
	wizard._choices.last_name = "Virtanen"
	wizard._choices.gender = _gender
	wizard._choices.hometown = "Sastamala"
	wizard._choices.club_id = ""
	wizard._show_step()
	for i in range(5):
		wizard._on_next()
		await _frames(3)
	game.autosave = false
	if _ability > 0.0:
		for id in data.races.ability_weights:
			if not str(id).begins_with("_"):
				game.athlete.set_attr(id, _ability)
	var cal = load("res://scripts/core/calendar.gd")
	for m in cal.meets_between(game.date, game.add_days(game.date, 330)):
		if cal.can_enter(game.athlete, m, game.date).ok:
			game.enter(m.key)
	var skipped := 0
	while true:
		if not _to_race(game):
			print("watch_race: no %s race%s found this season (skipped %d races)" % ["indoor" if _indoor else "outdoor",
					" with heats" if _heats else "", skipped])
			quit()
			return
		var rd = game.race_day
		var indoor: bool = rd.meet.get("indoor", false)
		if indoor == _indoor and (not _heats or rd.rounds.size() > 1):
			break
		while not rd.is_done():   # not the kind asked for: quick-run it
			rd.start_round(false, "pack").run()
			rd.finish_round()
		game.finish_race()
		skipped += 1
	print("watch_race: %s, %s (%s) - the race is yours" % [game.race_day.meet.name, cal.format_day(game.date),
			", ".join(game.race_day.rounds)])
	router.go("race")
	if OS.get_cmdline_user_args().has("quit"):   # (the tool's own test: open the race screen, then stop)
		await _frames(30)
		print("watch_race: race screen open: ", main.get_node("ScreenHost").get_child(-1).name)
		var rd = game.race_day
		if rd.rounds.size() > 1:   # (the heats: how many, and the final's size, never more than the lanes)
			rd.start_round(false, "pack").run()
			rd.finish_round()
			print("watch_race: %d heats, %d automatic places each, final of %d (lanes %d)" % [rd.heats.size(),
					rd._auto_per_heat(), rd.final_entrants.size(), 6 if rd.meet.get("indoor", false) else 8])
		quit()


## Plays weeks until a race day (stop events answered "ok" = later). False when the season ends first.
func _to_race(game) -> bool:
	for i in 60:   # (60 weeks: past the end of the season's meets)
		var r: String = game.advance_week()
		while r == game.STOP:
			game.answer_event(game.pending_event().id, "ok")
			r = game.advance_week()
		if r == game.RACE:
			return true
	return false
