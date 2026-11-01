class_name PlaytestNotes
extends RefCounted
## The in-game playtest notes (session K1c): the answers to the questions of data/playtest.json and the player's quick notes, saved on
## every change in `DIR`/<run>.json (never in the career's save: they belong to the tester, not to the career) and written out as text to
## paste into docs/PLAYTESTS.md. Each answer and note is stamped with where the game was (the game's date, the age, the player's name
## step, the page). Tools set `DIR` to their own folder. No dice, no effect on the game.

static var DIR := ""   # "" = the player's notes (user://playtest/), or the tools' own folder when a tool uses its own saves (see dir())

## {answers: {question id: {pick, note, at, context}}, notes: [{text, at, context}], on (the cards appear), skipped {question id: true}}
var data := {"answers": {}, "notes": [], "on": true, "skipped": {}}


static func cfg() -> Dictionary:
	return Data.playtest


## The folder of the notes: the player's, unless a tool set its own DIR or uses its own save folder (then user://tool_playtest/).
static func dir() -> String:
	if DIR != "":
		return DIR
	return "user://playtest/" if SaveGame.DIR == "user://saves/" else "user://tool_playtest/"


static func path() -> String:
	return dir() + str(cfg().run) + ".json"


## The notes saved for this run (an empty one when there is none).
static func open() -> PlaytestNotes:
	var n := PlaytestNotes.new()
	if FileAccess.file_exists(path()):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path()))
		if parsed is Dictionary:
			n.data = {"answers": parsed.get("answers", {}), "notes": parsed.get("notes", []), "on": bool(parsed.get("on", true)),
					"skipped": parsed.get("skipped", {})}
	return n


# --- Which questions are asked where -------------------------------------------------------------------------------------------

## Whole weeks played in the career (from the start date).
static func weeks_played() -> int:
	if Game.athlete == null:
		return 0
	return floori(Calendar.days_between(Game.START_DATE, Game.date) / 7.0)


## Does the question's `needs` hold now? goals_set: this season's goals have been set; goal_news: a goal was met, missed, adjusted or dropped.
static func _needs(need: String) -> bool:
	if need == "":
		return true
	var sg := SeasonGoals.sys()
	if sg == null or not SeasonGoals.enabled:
		return false
	match need:
		"goals_set":
			return sg.has_goals(sg.current_year())
		"goal_news":
			return not sg.news.filter(func(e): return str(e.what) in ["met", "missed", "adjusted", "dropped"]).is_empty()
	return false


## The questions the card of `page` asks now: not answered, not skipped, enough weeks played, its needs met; at most `card_max`.
func due(page: String) -> Array:
	var out := []
	if not bool(data.on) or Game.athlete == null:
		return out
	var weeks := weeks_played()
	for s in cfg().sections:
		for q in s.questions:
			var qid := str(q.id)
			if str(q.get("where", "")) != page or data.answers.has(qid) or data.skipped.has(qid):
				continue
			if weeks < int(q.get("min_weeks", 0)) or not _needs(str(q.get("needs", ""))):
				continue
			out.append(q)
			if out.size() >= int(cfg().card_max):
				return out
	return out


## The shown questions that got no answer are not asked again (Done / Skip these); they stay on the notes page.
func skip(questions: Array) -> void:
	for q in questions:
		if not data.answers.has(str(q.id)):
			data.skipped[str(q.id)] = true
	save()


func set_on(value: bool) -> void:
	data.on = value
	save()


func save() -> void:
	DirAccess.make_dir_recursive_absolute(dir())
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## Where the game is now, for the stamp of an answer or a note. `page` = the hub page the player came from.
static func context(page: String) -> Dictionary:
	var out := {"page": page, "date": "", "age": 0, "name": "", "season": ""}
	if Game.athlete == null:
		return out
	out.date = Calendar.format_day(Game.date)
	out.age = Game.athlete.age_on(Game.date)
	out.season = SeasonSystem.season_label(SeasonPlan.year_of(Game.date))
	var cs := CareerSystem.sys()
	if cs != null:
		out.name = str(cs.reputation(Game.date).name)
	return out


func answer_of(qid: String) -> Dictionary:
	return data.answers.get(qid, {})


## Sets the pick of a question ("" = cleared) and/or its note; an answer with neither is removed.
func set_answer(qid: String, pick: String, note: String, page: String) -> void:
	if pick == "" and note.strip_edges() == "":
		data.answers.erase(qid)
	else:
		data.answers[qid] = {"pick": pick, "note": note, "at": Time.get_datetime_string_from_system(), "context": context(page)}
	save()


func add_note(text: String, page: String) -> void:
	if text.strip_edges() == "":
		return
	data.notes.append({"text": text.strip_edges(), "at": Time.get_datetime_string_from_system(), "context": context(page)})
	save()


func remove_note(index: int) -> void:
	if index >= 0 and index < data.notes.size():
		data.notes.remove_at(index)
		save()


func total() -> int:
	var n := 0
	for s in cfg().sections:
		n += s.questions.size()
	return n


## How many questions have an answer (a pick or a note).
func answered() -> int:
	var n := 0
	for s in cfg().sections:
		for q in s.questions:
			if data.answers.has(str(q.id)):
				n += 1
	return n


## The whole thing as text (markdown), ready to paste: the answers by section, then the quick notes.
func to_markdown() -> String:
	var u: Dictionary = cfg().ui
	var lines := ["## %s" % str(cfg().title).capitalize(), ""]
	var ctx := context("")
	lines.append("_%s_" % str(u.md_context).format({"date": ctx.date, "age": ctx.age, "name": ctx.name, "season": ctx.season, "at": Time.get_datetime_string_from_system()}))
	lines.append("")
	for s in cfg().sections:
		lines.append("### %s" % str(s.title).capitalize())
		for q in s.questions:
			var a := answer_of(str(q.id))
			var what := "%s %s" % [str(a.get("pick", "")), ("— " + str(a.note)) if str(a.get("note", "")).strip_edges() != "" else ""]
			if a.is_empty():
				what = str(u.md_none)
			var stamp := ""
			if not a.is_empty() and not a.context.is_empty() and str(a.context.get("date", "")) != "":
				stamp = " _(%s, %s)_" % [str(a.context.date), str(a.context.page)]
			lines.append("- **%s** %s%s" % [str(q.text), what.strip_edges(), stamp])
		lines.append("")
	lines.append("### %s" % str(u.notes_head).capitalize())
	if data.notes.is_empty():
		lines.append("- " + str(u.notes_none))
	for n in data.notes:
		var c: Dictionary = n.context
		lines.append("- %s _(%s, %s)_" % [str(n.text), str(c.get("date", "")), str(c.get("page", ""))])
	return "\n".join(lines) + "\n"


## Writes the text beside the json (playtest3_<time>.md) and returns its absolute path.
func save_text() -> String:
	DirAccess.make_dir_recursive_absolute(dir())
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file := "%s%s_%s.md" % [dir(), str(cfg().run), stamp]
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f != null:
		f.store_string(to_markdown())
	return ProjectSettings.globalize_path(file)
