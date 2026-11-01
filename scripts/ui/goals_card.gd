class_name GoalsCard
extends CalloutCard
## The season goals on the Sunday planner (GDD 4.10 decision 3, "L3b2's questions", session L3b2), never a stop. Three kinds:
## - "offer": the coach's card for a season: the TIME goal (◀ ▶ through its levels), then the MENU (any two more: a 44 px toggle per
##   family, ◀ ▶ on the chosen ones; his ★ on each), what met and missed mean, the places it enters you in, Set these goals and what
##   leaving it does (SeasonGoals.apply on the date it names).
## - "review": the week after the indoor target and the juhannus week: each open goal with his view now and its stakes, On track /
##   Adjust (its own list and, for a milestone, a swap; the stakes follow the new level) / Drop; left open = on track.
## - "end": the first planner of the next season: each goal ✓ / ✗ / – with what it opened, his comment, the replies (lean).
## Reading the goals and answering through SeasonGoals only. Texts: data/goals.json card / reviews / end.

signal changed

const HELP := "season_goals"

var _kind := ""
var _data: Dictionary
var _content: VBoxContainer
var _time := 0             # offer: the time goal's chosen option
var _chosen := {}          # offer: family key -> option index
var _note := ""            # offer: why a toggle was refused
var _adjusting := ""       # review: the goal being adjusted
var _adj := {}             # review: {key, idx} picked to change to


static func gs() -> SeasonGoals:
	return SeasonGoals.sys()


static func cfg() -> Dictionary:
	return Data.goals


## The card of a season's goals offer (SeasonGoals.card()).
static func offer(pack: Dictionary) -> GoalsCard:
	var c: Dictionary = cfg().card
	var voice := Coaches.id_of(Game.athlete)
	var card := GoalsCard.new(Palette.WARN, "crosshair", str(c.title).format({"season": SeasonGoals.season_label(int(pack.year))}),
			CoachSystem.words(str(cfg().offer.intro.get(voice, cfg().offer.intro.calm))))
	card._kind = "offer"
	card._data = pack
	card._time = int(pack.pick.time)
	card._chosen = pack.pick.chosen.duplicate()
	card._start()
	return card


## The review section of this week ({year, review} of SeasonGoals.review_card()).
static func review(rc: Dictionary) -> GoalsCard:
	var r: Dictionary = cfg().reviews
	var rv: Dictionary = rc.review
	var voice := Coaches.id_of(Game.athlete)
	var card := GoalsCard.new(Palette.WARN, "crosshair", str(r.title[str(rv.id)]), CoachSystem.words(str(r.intro.get(voice, r.intro.calm))))
	card._kind = "review"
	card._data = rc
	card._start()
	return card


## The season's end on the next season's first planner ({year, end} of SeasonGoals.end_card()).
static func season_end(ec: Dictionary) -> GoalsCard:
	var e: Dictionary = cfg().end
	var voice := Coaches.id_of(Game.athlete)
	var rv: Dictionary = cfg().review
	var text := str(rv.text.get(voice, rv.text.calm))
	var card := GoalsCard.new(Palette.WARN, "trophy", str(e.title).format({"season": SeasonGoals.season_label(int(ec.year))}), CoachSystem.words(text))
	card._kind = "end"
	card._data = ec
	card._start()
	return card


func _start() -> void:
	_content = UIKit.vbox(8)
	add_row(_content)
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match _kind:
		"offer":
			_build_offer()
		"review":
			_build_review()
		"end":
			_build_end()


static func _wrapped(text: String, variation: String) -> Label:
	var l := UIKit.wrapped(CoachSystem.words(text), variation)
	l.custom_minimum_size.x = 120
	return l


## The first section label with the card's "?" (the season goals' help) on the right.
func _head_row(text: String) -> Control:
	var row := UIKit.hbox(8)
	var l := UIKit.label(text, "SectionLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	row.add_child(l)
	var help := HelpButton.new(HELP)
	help.pressed.connect(func(): HelpOverlay.open(_screen(), HELP))
	row.add_child(help)
	return row


## The screen this card is on (the hub: the child of the ScreenHost), where the help opens.
func _screen() -> Control:
	var n: Node = self
	while n.get_parent() != null and str(n.get_parent().name) != "ScreenHost":
		n = n.get_parent()
	return n as Control


static func _arrow_button(text: String, enabled: bool) -> Button:
	var b := UIKit.button(text, false, 44)
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not enabled
	return b


# --- The offer -----------------------------------------------------------------------------------------------------------------

func _build_offer() -> void:
	var c: Dictionary = cfg().card
	var pack := _data
	var year := int(pack.year)
	_content.add_child(_head_row(str(c.time_head)))
	_content.add_child(_offer_row(pack.time, _time, true, false, year))
	var extras := int(cfg().menu.extras)
	if pack.menu.is_empty():
		_content.add_child(_wrapped(str(c.none_more), "WhyLabel"))
	else:
		_content.add_child(UIKit.label(str(c.more_head).format({"n": extras, "chosen": _chosen.size()}), "SectionLabel"))
		_content.add_child(_wrapped(str(c.more_hint), "WhyLabel"))
		for fam in pack.menu:
			_content.add_child(_offer_row(fam, int(_chosen.get(fam.key, fam.pick)), _chosen.has(fam.key), true, year))
		if _note != "":
			var n := _wrapped(_note, "WhyLabel")
			n.add_theme_color_override("font_color", Palette.WARN)
			_content.add_child(n)
	_content.add_child(UIKit.label(str(c.stakes_head), "SectionLabel"))
	_content.add_child(_wrapped(SeasonGoals.stakes_general(), "WhyLabel"))
	for line in _enters_lines():
		_content.add_child(_wrapped(line, "WhyLabel"))
	var set_b := UIKit.button(str(c.set), true, 0.0)
	set_b.custom_minimum_size = Vector2(0, 44)
	set_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
	var sel := {"time": _time, "chosen": _chosen.duplicate()}
	set_b.pressed.connect(func():
		gs().apply(year, sel)
		HealthUI.refresh()
		changed.emit())
	_content.add_child(set_b)
	_content.add_child(_wrapped(str(c.left).format({"date": _until_text(int(pack.until))}), "WhyLabel"))


## "Sun 8 Nov" from a date key.
static func _until_text(key: int) -> String:
	var d := {"year": key / 10000, "month": (key / 100) % 100, "day": key % 100}
	return DayInfo.short_day(d)


## The meets a chosen place goal enters you in ("Setting it enters you in …").
func _enters_lines() -> Array:
	var out := []
	var fams := [[_data.time, _time]]
	for fam in _data.menu:
		if _chosen.has(fam.key):
			fams.append([fam, int(_chosen[fam.key])])
	for pair in fams:
		var o: Dictionary = pair[0].options[clampi(int(pair[1]), 0, pair[0].options.size() - 1)]
		if str(o.get("sub", "")) == "place" and not str(o.meet) in Game.entries:
			out.append(str(cfg().stakes.enters).format({"meet": str(Calendar.get_meet(str(o.meet)).get("name", ""))}))
	return out


## One family: [toggle] what it asks · its level and his words (★ on his pick) [◀ ▶ when chosen].
func _offer_row(fam: Dictionary, idx: int, chosen: bool, toggle: bool, year: int) -> Control:
	var opts: Array = fam.options
	idx = clampi(idx, 0, opts.size() - 1)
	var o: Dictionary = opts[idx]
	var row := UIKit.hbox(8)
	var key := str(fam.key)
	if toggle:
		var t := UIKit.button("✓" if chosen else "+", chosen, 44)
		t.custom_minimum_size = Vector2(44, 44)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.pressed.connect(func(): _toggle(key, int(fam.pick)))
		row.add_child(t)
	var col := UIKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if toggle:
		col.add_child(_wrapped(str(fam.name), "WhyLabel"))
	var what := _wrapped(SeasonGoals.goal_text(o, year), "ItemLabel")
	if toggle and not chosen:
		what.modulate = Color(1, 1, 1, 0.75)
	col.add_child(what)
	var words := "%s · %s" % [str(o.level_name), str(o.chance)]
	if idx == int(fam.pick):
		words += "  " + str(cfg().card.pick_mark)
	var meta := _wrapped(words, "WhyLabel")
	if idx == int(fam.pick):
		meta.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(meta)
	row.add_child(col)
	if chosen and opts.size() > 1:
		var left := _arrow_button("◀", idx > 0)
		left.pressed.connect(func(): _step(key, idx - 1))
		var right := _arrow_button("▶", idx < opts.size() - 1)
		right.pressed.connect(func(): _step(key, idx + 1))
		row.add_child(left)
		row.add_child(right)
	return row


func _step(key: String, idx: int) -> void:
	if key == "time":
		_time = idx
	else:
		_chosen[key] = idx
	_note = ""
	_rebuild()


## A family on / off: at most two extras, one habit (the card says why a toggle was refused).
func _toggle(key: String, pick: int) -> void:
	_note = ""
	if _chosen.has(key):
		_chosen.erase(key)
	else:
		var trial := _chosen.duplicate()
		trial[key] = pick
		if SeasonGoals.allowed(_data, trial):
			_chosen = trial
		elif trial.size() > int(cfg().menu.extras):
			_note = str(cfg().card.full)
		else:
			_note = str(cfg().card.habit_full)
	_rebuild()


# --- A review -------------------------------------------------------------------------------------------------------------------

func _build_review() -> void:
	var r: Dictionary = cfg().reviews
	var year := int(_data.year)
	var rv: Dictionary = _data.review
	_content.add_child(_head_row(str(r.head).format({"when": str(r.when[str(rv.id)])})))
	for gid in rv.goals:
		var g := gs().goal(year, str(gid))
		if g.is_empty():
			continue
		var box := UIKit.vbox(4)
		box.add_child(_wrapped(SeasonGoals.goal_text(g, year), "ItemLabel"))
		box.add_child(_wrapped(gs().progress_text(g, year), "WhyLabel"))
		var answered := str(rv.answers.get(str(gid), ""))
		if answered != "":
			var line := str(r.answered_track)
			match answered:
				"adjust":
					line = str(r.answered_adjust).format({"goal": SeasonGoals.goal_text(g, year)}) + " " + str(r.stakes_follow)
				"drop":
					line = str(r.answered_drop)
			var l := _wrapped(line, "WhyLabel")
			l.add_theme_color_override("font_color", Palette.TEXT_MUTED)
			box.add_child(l)
			if answered == "adjust":
				box.add_child(_wrapped(SeasonGoals.stakes_text(g), "WhyLabel"))
			_content.add_child(box)
			continue
		var now := gs().view_now(rv, g)
		if not now.is_empty():
			box.add_child(_wrapped(str(r.now).format({"level": str(now.level_name), "chance": str(now.chance)}), "WhyLabel"))
		box.add_child(_wrapped(SeasonGoals.stakes_text(g), "WhyLabel"))
		var fams := gs().adjust_families(year, rv, g)
		if _adjusting == str(gid):
			box.add_child(_adjust_box(year, rv, g, fams))
		else:
			box.add_child(_review_buttons(year, rv, str(gid), not fams.is_empty()))
		_content.add_child(box)
		_content.add_child(HSeparator.new())
	_content.add_child(_wrapped(str(r.left), "WhyLabel"))


func _review_buttons(year: int, rv: Dictionary, gid: String, can_adjust: bool) -> Control:
	var r: Dictionary = cfg().reviews
	var row := UIKit.hbox(8)
	var track := UIKit.button(str(r.track), false, 0.0)
	var adjust := UIKit.button(str(r.adjust), false, 0.0)
	var drop := UIKit.button(str(r.drop), false, 0.0)
	adjust.disabled = not can_adjust
	for b in [track, adjust, drop]:
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var rid := str(rv.id)
	track.pressed.connect(func():
		gs().answer_review(year, rid, gid, "track")
		changed.emit())
	adjust.pressed.connect(func():
		_adjusting = gid
		_adj = {}
		_rebuild())
	drop.pressed.connect(func():
		gs().answer_review(year, rid, gid, "drop")
		changed.emit())
	return row


## Adjusting a goal: its own list (and for a milestone the families it can be swapped for), each option a 44 px button with its level
## (★ = his view now); Change it / Cancel.
func _adjust_box(year: int, rv: Dictionary, g: Dictionary, fams: Array) -> Control:
	var r: Dictionary = cfg().reviews
	var box := UIKit.vbox(6)
	if fams.is_empty():
		box.add_child(_wrapped(str(r.nothing), "WhyLabel"))
	var first := true
	for fam in fams:
		var head := str(fam.name).to_upper() if first else "%s · %s" % [str(r.swap_head), str(fam.name).to_upper()]
		box.add_child(_wrapped(head, "SectionLabel"))
		first = false
		for i in fam.options.size():
			var o: Dictionary = fam.options[i]
			var text := "%s · %s" % [SeasonGoals.goal_text(o, year), str(o.level_name)]
			if i == int(fam.pick):
				text += "  " + str(cfg().card.pick_mark)
			var selected: bool = str(_adj.get("key", "")) == str(fam.key) and int(_adj.get("idx", -1)) == i
			var b := UIKit.button(text, selected, 0.0)
			b.custom_minimum_size = Vector2(0, 44)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var key := str(fam.key)
			b.pressed.connect(func():
				_adj = {"key": key, "idx": i}
				_rebuild())
			box.add_child(b)
	box.add_child(_wrapped(str(r.stakes_follow), "WhyLabel"))
	var row := UIKit.hbox(8)
	var ok := UIKit.button(str(r.confirm), true, 0.0)
	ok.disabled = _adj.is_empty()
	var cancel := UIKit.button(str(r.cancel), false, 0.0)
	for b in [ok, cancel]:
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var rid := str(rv.id)
	var gid := str(g.id)
	var pick := _adj.duplicate()
	ok.pressed.connect(func():
		if pick.is_empty():
			return
		gs().answer_review(year, rid, gid, "adjust", str(pick.key), int(pick.idx))
		_adjusting = ""
		_adj = {}
		HealthUI.refresh()
		changed.emit())
	cancel.pressed.connect(func():
		_adjusting = ""
		_adj = {}
		_rebuild())
	box.add_child(row)
	return box


# --- The season's end ---------------------------------------------------------------------------------------------------------------

func _build_end() -> void:
	var year := int(_data.year)
	var e: Dictionary = _data.end
	var ui: Dictionary = cfg().ui
	var rv: Dictionary = cfg().review
	_content.add_child(_head_row(str(cfg().end.head).format({"season": SeasonGoals.season_label(year)})))
	for g in gs().goals_of(year):
		var line := ""
		match str(g.status):
			"met":
				line = str(rv.line_met).format({"goal": SeasonGoals.goal_text(g, year)})
			"missed":
				line = SeasonGoals.missed_line(g, year)
			_:
				line = "%s %s" % [str(ui.marks.get(str(g.status), "–")), SeasonGoals.goal_text(g, year)]
				if str(g.detail) != "":
					line += " (%s)" % str(g.detail)
		var l := _wrapped(line, "ItemLabel")
		if str(g.status) == "met":
			l.add_theme_color_override("font_color", Palette.GOOD)
		_content.add_child(l)
		if str(g.status) == "met":
			_content.add_child(_wrapped(SeasonGoals.opened_text(g), "WhyLabel"))
	var voice := Coaches.id_of(Game.athlete)
	if int(e.missed) > 0:
		_content.add_child(_wrapped(str(rv.comment.get(voice, rv.comment.calm)), "BodyLabel"))
	var box := UIKit.vbox(6)
	for r in gs().end_replies(e):
		var b := UIKit.button(CoachSystem.words(str(r.label)), false, 0.0)
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rid := str(r.id)
		b.pressed.connect(func():
			gs().answer_end(year, rid)
			changed.emit())
		box.add_child(b)
		if str(r.hint) != "":
			box.add_child(_wrapped(str(r.hint), "WhyLabel"))
	_content.add_child(box)
	_content.add_child(_wrapped(str(cfg().end.left if int(e.missed) > 0 else cfg().end.left_met), "WhyLabel"))
