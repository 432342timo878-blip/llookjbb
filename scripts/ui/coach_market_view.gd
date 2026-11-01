class_name CoachMarketView
extends VBoxContainer
## Find a coach (GDD 4.9.7 "UI", session C6; session P2a added search, sort, filters and a comparison with your own coach): the
## coaches the athlete can see now, each as a card (name, kind and town, cost, level range, group, whether the coach could take you
## and how well you know them). Tapping a card opens the coach's page (CoachProfile, where you can also talk to the coach).
## On top: your situation (age, town, family budget) and a change of coach waiting for Monday. Then a SEARCH box, a SORT menu (the
## section the coach is in, name, overall level, cost, group size, or any one of the 11 skills) and FILTERS (kind, has a group, within
## the budget, could take me); under them the COMPARISON of your coach with up to two coaches you ticked (the 11 skills as ranges, the
## group, the cost, what would be better or weaker) and the list. 44 px everything, no hover info; on a phone the comparison keeps
## three narrow columns. Its help is the hub header's "?" (entry "market", career_hub._help_entry).

signal coach_requested(coach_id: String)
signal changed

var _query := ""
var _sort := "section"
var _kind := "all"
var _only_group := false
var _only_budget := false
var _only_take := false
var _compare: Array = []       # up to two coach ids
var _list_box: VBoxContainer
var _compare_box: VBoxContainer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_build()


func _build() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	var mk := CoachMarket.sys()
	var cs := Game.get_system("coach") as CoachSystem
	if mk == null or cs == null:
		return
	var ui: Dictionary = Data.market.ui
	add_child(UIKit.label(str(ui.find_head), "HeadingLabel"))
	var town := CoachSystem.home_town(Game.athlete)
	var size_name := ""
	for c in Data.towns.size_classes:
		if str(c.id) == Data.town_size(town):
			size_name = str(c.name).to_lower()
	add_child(UIKit.wrapped(str(ui.situation).format({"age": CoachMarket.age(), "town": town, "size": size_name,
			"budget": mk.budget()}), "MutedLabel"))

	add_child(_open_switch(mk))

	if not mk.pending.is_empty():
		var box := UIKit.vbox(8)
		var newc: Dictionary = cs.coaches.get(str(mk.pending.coach), {})
		box.add_child(UIKit.wrapped(str(ui.pending_line).format({"new": str(newc.get("name", "")),
				"date": Calendar.format_day(mk.pending.date)}), ""))
		if str(mk.pending.get("why", "")) != "ended":
			var stay := UIKit.button(str(ui.pending_cancel).format({"old": str(cs.head().get("name", ""))}), false, 200)
			stay.pressed.connect(func():
				mk.cancel_pending()
				_build()
				changed.emit())
			box.add_child(stay)
		add_child(UIKit.alert_panel(box, Palette.ACCENT, 12))

	add_child(_toolbar(mk))
	_compare_box = UIKit.vbox(8)
	add_child(_compare_box)
	_list_box = UIKit.vbox(10)
	add_child(_list_box)
	_refresh_compare(mk)
	_refresh_list(mk)
	add_child(UIKit.wrapped(str(ui.more_seen if mk.seen_tf else ui.more_later), "CaptionLabel"))


# --- Search, sort, filters ---------------------------------------------------------------------------------------------------------

func _toolbar(mk: CoachMarket) -> Control:
	var f: Dictionary = Data.market.ui.find
	var ui: Dictionary = Data.market.ui
	var box := UIKit.vbox(8)
	var search := LineEdit.new()
	search.placeholder_text = str(f.search)
	search.text = _query
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(0, 44)
	search.set_meta("find_search", true)
	search.text_changed.connect(func(t: String):
		_query = t
		_refresh_list(mk))
	box.add_child(search)
	var row := UIKit.flex(8)
	# Sort: a menu of the sections, name, level, cost, group size and each of the 11 skills.
	var sort := OptionButton.new()
	sort.custom_minimum_size = Vector2(0, 44)
	sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort.set_meta("find_sort", true)
	var keys := []
	for k in f.sorts:
		sort.add_item("%s: %s" % [str(f.sort_head).capitalize(), CoachSystem.words(str(f.sorts[k]))])
		keys.append(str(k))
	for at in Data.coaching.attributes:
		sort.add_item("%s: %s" % [str(f.sort_head).capitalize(), str(at.name)])
		keys.append("attr:" + str(at.id))
	sort.selected = maxi(0, keys.find(_sort))
	sort.item_selected.connect(func(i: int):
		_sort = str(keys[i])
		_refresh_list(mk))
	row.add_child(sort)
	var kind := OptionButton.new()
	kind.custom_minimum_size = Vector2(0, 44)
	kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind.set_meta("find_kind", true)
	var kinds := ["all"]
	kind.add_item(str(f.all_kinds))
	for k in ui.kinds:
		kind.add_item(str(ui.kinds[k]))
		kinds.append(str(k))
	kind.selected = maxi(0, kinds.find(_kind))
	kind.item_selected.connect(func(i: int):
		_kind = str(kinds[i])
		_refresh_list(mk))
	row.add_child(kind)
	box.add_child(row)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for t in [["group", str(f.only_group), _only_group], ["budget", str(f.only_budget), _only_budget], ["take", str(f.only_take), _only_take]]:
		var b := Button.new()
		b.text = str(t[1])
		b.toggle_mode = true
		b.theme_type_variation = "ToggleButton"
		b.button_pressed = bool(t[2])
		b.custom_minimum_size = Vector2(0, 44)
		b.set_meta("find_filter", str(t[0]))
		var which := str(t[0])
		b.toggled.connect(func(on: bool):
			match which:
				"group": _only_group = on
				"budget": _only_budget = on
				"take": _only_take = on
			_refresh_list(mk))
		flow.add_child(b)
	box.add_child(flow)
	return box


## Does the coach pass the search and the filters?
func _passes(mk: CoachMarket, c: Dictionary) -> bool:
	if _query.strip_edges() != "":
		var hay := ("%s %s %s" % [str(c.name), str(c.facts.get("town", "")), str(Data.get_club(str(c.facts.get("club_id", ""))).get("name", ""))]).to_lower()
		for part in _query.to_lower().split(" ", false):
			if not hay.contains(part):
				return false
	if _kind != "all" and str(c.kind) != _kind:
		return false
	if _only_group and (c.get("group", []) as Array).is_empty():
		return false
	if _only_budget and not mk.fits_budget(c):
		return false
	if _only_take and not mk.can_take(c) and str(c.id) != Game.athlete.coach_id:
		return false
	return true


## The sort value of a coach for the current sort (bigger sorts later; name and cost ascending, the others descending).
func _key(mk: CoachMarket, c: Dictionary):
	match _sort:
		"name":
			return str(c.name)
		"cost":
			return float(mk.cost_of(c).cost)
		"group":
			return -float((c.get("group", []) as Array).size())
		"level":
			return -_level(mk, c)
	if _sort.begins_with("attr:"):
		var r := mk.range_of(c, _sort.trim_prefix("attr:"))
		return -(float(r[0]) + float(r[1])) / 2.0
	return 0.0


## The mean of the 11 skills' ranges: [low, high].
func _level_range(mk: CoachMarket, c: Dictionary) -> Array:
	var lo := 0.0
	var hi := 0.0
	var n := 0
	for at in Data.coaching.attributes:
		var r := mk.range_of(c, str(at.id))
		lo += float(r[0])
		hi += float(r[1])
		n += 1
	return [lo / maxf(n, 1), hi / maxf(n, 1)]


func _level(mk: CoachMarket, c: Dictionary) -> float:
	var r := _level_range(mk, c)
	return (float(r[0]) + float(r[1])) / 2.0


func _refresh_list(mk: CoachMarket) -> void:
	for ch in _list_box.get_children():
		_list_box.remove_child(ch)
		ch.queue_free()
	var f: Dictionary = Data.market.ui.find
	var ui: Dictionary = Data.market.ui
	var lists := mk.listing()
	var all := []
	for sec in CoachMarket.SECTIONS:
		for c in lists.get(sec, []):
			if _passes(mk, c):
				all.append(c)
	if all.is_empty():
		_list_box.add_child(UIKit.wrapped(str(f.count_none), "BodyLabel"))
		return
	_list_box.add_child(UIKit.label(str(f.count).format({"n": all.size()}), "CaptionLabel"))
	if _sort == "section":
		for sec in CoachMarket.SECTIONS:
			var rows := all.filter(func(c): return mk.section(c) == sec)
			if rows.is_empty():
				continue
			var col := UIKit.vbox(8)
			col.add_child(UIKit.label(str(ui.sections[sec]), "CaptionLabel"))
			for c in rows:
				col.add_child(_row(mk, c))
			_list_box.add_child(col)
		return
	var sorted := all.duplicate()
	sorted.sort_custom(func(x, y):
		var kx = _key(mk, x)
		var ky = _key(mk, y)
		if kx != ky:
			return kx < ky
		return str(x.name) < str(y.name))
	var col := UIKit.vbox(8)
	for c in sorted:
		col.add_child(_row(mk, c))
	_list_box.add_child(col)


# --- The comparison ---------------------------------------------------------------------------------------------------------------

func _refresh_compare(mk: CoachMarket) -> void:
	for ch in _compare_box.get_children():
		_compare_box.remove_child(ch)
		ch.queue_free()
	var f: Dictionary = Data.market.ui.find
	var cs := Game.get_system("coach") as CoachSystem
	var head: Dictionary = cs.head()
	var others := []
	for cid in _compare:
		var c: Dictionary = cs.coaches.get(str(cid), {})
		if not c.is_empty() and str(cid) != str(head.get("id", "")):
			others.append(c)
	if others.is_empty() or head.is_empty():
		_compare_box.add_child(UIKit.wrapped(str(f.compare_hint), "CaptionLabel"))
		return
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(f.compare_head), "SectionLabel"))
	var grid := GridContainer.new()
	grid.columns = 2 + others.size()
	grid.add_theme_constant_override("h_separation", 10 if Layout.compact else 18)
	grid.add_theme_constant_override("v_separation", 4)
	var names := [str(f.col_you)] + others.map(func(c): return str(c.name).split(" ")[0])
	grid.add_child(Control.new())
	for n in names:
		var l := UIKit.label(str(n), "ItemLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(l)
	var coaches := [head] + others
	_cell_row(grid, str(f.row_level), coaches.map(func(c):
		var r := _level_range(mk, c)
		return {"text": "%.1f–%.1f" % [float(r[0]), float(r[1])], "mid": (float(r[0]) + float(r[1])) / 2.0}), true)
	for at in Data.coaching.attributes:
		var cells := coaches.map(func(c):
			var r := mk.range_of(c, str(at.id))
			var lo := int(r[0])
			var hi := int(r[1])
			return {"text": str(lo) if lo == hi else "%d–%d" % [lo, hi], "mid": (float(lo) + float(hi)) / 2.0})
		_cell_row(grid, str(at.name), cells, true)
	var gcells := coaches.map(func(c): return {"text": _group_cell(c), "mid": 0.0})
	_cell_row(grid, str(f.row_group), gcells, false)
	_cell_row(grid, str(f.row_cost), coaches.map(func(c):
		var co := mk.cost_of(c)
		return {"text": str(ui_cost(co)), "mid": 0.0}), false)
	box.add_child(grid)
	# What would be better, what weaker (per coach, against yours).
	for c in others:
		var up := []
		var down := []
		for at in Data.coaching.attributes:
			var a := mk.range_of(head, str(at.id))
			var b := mk.range_of(c, str(at.id))
			var diff := (float(b[0]) + float(b[1])) / 2.0 - (float(a[0]) + float(a[1])) / 2.0
			if diff >= 1.5:
				up.append(str(at.name))
			elif diff <= -1.5:
				down.append(str(at.name))
		var line := "%s: " % str(c.name).split(" ")[0]
		var parts := []
		if not up.is_empty():
			parts.append(str(f.better).format({"list": ", ".join(up.slice(0, 3))}))
		if not down.is_empty():
			parts.append(str(f.worse).format({"list": ", ".join(down.slice(0, 3))}))
		if parts.is_empty():
			parts.append(str(f.similar))
		box.add_child(UIKit.wrapped(line + " ".join(parts), "WhyLabel"))
		var open := UIKit.button(str(f.compare_open).format({"name": str(c.name).split(" ")[0]}), false, 0.0)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid := str(c.id)
		open.pressed.connect(func(): coach_requested.emit(cid))
		box.add_child(open)
	var clear := UIKit.button(str(f.compare_close), false, 0.0)
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func():
		_compare = []
		_refresh_compare(mk)
		_refresh_list(mk))
	box.add_child(clear)
	_compare_box.add_child(UIKit.panel(box, 14))
	_compare_box.set_meta("comparing", others.size())


func ui_cost(co: Dictionary) -> String:
	return str(Data.market.ui.cost[str(co.kind)]).format({"cost": co.cost})


## One row of the comparison: the name and a cell per coach; with `colour` the cell is green/red against the first (yours).
func _cell_row(grid: GridContainer, name: String, cells: Array, colour: bool) -> void:
	var l := UIKit.wrapped(name, "WhyLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	for i in cells.size():
		var cell := UIKit.wrapped(str(cells[i].text), "BodyLabel")
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if colour and i > 0:
			var d := float(cells[i].mid) - float(cells[0].mid)
			if d >= 1.0:
				cell.add_theme_color_override("font_color", Palette.GOOD)
			elif d <= -1.0:
				cell.add_theme_color_override("font_color", Palette.BAD)
		grid.add_child(cell)


# --- A coach's row ------------------------------------------------------------------------------------------------------------------

## "Group of 7, a bit stronger" / "No group you know of".
func _group_cell(c: Dictionary) -> String:
	var f: Dictionary = Data.market.ui.find
	var members: Array = c.get("group", [])
	if members.is_empty():
		return str(f.group_none)
	var sum := 0.0
	for m in members:
		sum += float(m.level)
	var gap := sum / members.size() - CoachSystem.athlete_level(Game.athlete)
	var w: Dictionary = Data.circle.group.words
	var word := str(w.much_stronger if gap >= 2.0 else (w.stronger if gap >= 0.7 else (w.level if gap > -0.7 else (w.weaker if gap > -2.0 else w.much_weaker))))
	return str(f.group_line).format({"n": members.size(), "word": word.to_lower()})


## A card and its Compare toggle.
func _row(mk: CoachMarket, c: Dictionary) -> Control:
	var f: Dictionary = Data.market.ui.find
	var row := UIKit.hbox(6)
	var card := _card(mk, c)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	if str(c.id) != Game.athlete.coach_id:
		var cid := str(c.id)
		var b := Button.new()
		b.text = str(f.compare)
		b.toggle_mode = true
		b.theme_type_variation = "ToggleButton"
		b.custom_minimum_size = Vector2(76 if Layout.compact else 100, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.button_pressed = cid in _compare
		b.set_meta("compare_coach", cid)
		b.toggled.connect(func(on: bool):
			if on and not cid in _compare:
				_compare.append(cid)
				if _compare.size() > 2:
					_compare.pop_front()
			elif not on:
				_compare.erase(cid)
			_refresh_compare(mk)
			_refresh_list(mk))
		row.add_child(b)
	return row


## "Open to offers from other coaches: Yes / No" (user 2026-10-17): two 44 px toggles and what it means.
func _open_switch(mk: CoachMarket) -> Control:
	var ui: Dictionary = Data.market.ui
	var col := UIKit.vbox(6)
	col.add_child(UIKit.label(str(ui.open_head), "CaptionLabel"))
	var row := UIKit.hbox(8)
	var group := ButtonGroup.new()
	for v in [true, false]:
		var b := UIKit.toggle(str(ui.open_yes if v else ui.open_no), group)
		b.custom_minimum_size = Vector2(110, 44)
		b.button_pressed = mk.open_offers == v
		b.pressed.connect(func():
			mk.open_offers = v
			_build()
			changed.emit())
		row.add_child(b)
	col.add_child(row)
	col.add_child(UIKit.wrapped(str(ui.open_note_yes if mk.open_offers else ui.open_note_no), "CaptionLabel"))
	return UIKit.panel(col, 12)


## A coach as a card: tap = the coach's page.
func _card(mk: CoachMarket, c: Dictionary) -> Control:
	var ui: Dictionary = Data.market.ui
	var f: Dictionary = ui.find
	var card := PanelContainer.new()
	var is_head := str(c.id) == Game.athlete.coach_id
	card.add_theme_stylebox_override("panel", ThemeBuilder.card_box(is_head))
	card.custom_minimum_size.y = 64
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var row := UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av := PeopleUI.avatar(str(c.name), 36.0)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(av)
	var col := UIKit.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines := [[str(c.name), "SubheadingLabel"]]
	var kind := str(ui.kinds.get(str(c.kind), c.kind))
	var rep := str(Data.market.reputations.get(str(c.facts.get("reputation", "")), ""))
	lines.append(["%s · %s · %s" % [kind, str(c.facts.get("town", "")), rep], "MutedLabel"])
	var co := mk.cost_of(c)
	var lr := _level_range(mk, c)
	lines.append(["%s · %s" % [str(ui.cost[str(co.kind)]).format({"cost": co.cost}),
			str(f.level_line).format({"lo": "%.1f" % float(lr[0]), "hi": "%.1f" % float(lr[1])})], "CaptionLabel"])
	lines.append([_group_cell(c), "CaptionLabel"])
	for l in lines:
		var lab := UIKit.wrapped(str(l[0]), str(l[1]))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lab)
	var st := mk.status(c)
	var st_color: Color = {"ok": Palette.RISK_LOW, "offer": Palette.RISK_LOW, "head": Palette.ACCENT, "pending": Palette.ACCENT,
			"budget": Palette.RISK_HIGH, "ended": Palette.RISK_HIGH}.get(str(st.id), Palette.RISK_MODERATE)
	var st_label := UIKit.wrapped("%s · %s" % [str(st.text), str(ui.known).format({"word": mk.known_word(c)})], "")
	st_label.add_theme_color_override("font_color", st_color)
	st_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(st_label)
	row.add_child(col)
	margin.add_child(row)
	card.add_child(margin)
	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): coach_requested.emit(str(c.id)))
	card.add_child(button)
	return card
