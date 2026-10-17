class_name CoachMarketView
extends VBoxContainer
## Find a coach (GDD 4.9.7 "UI", session C6): the coaches the athlete can see now, by section (your club, at home, your
## town, region, the athletics centre, national, remote, world level), each as a card: name, kind and town, cost, whether
## the coach could take you (or why not) and how well you know them. Tapping a card opens the coach's page (CoachProfile).
## On top: your situation (age, town, family budget) and a change of coach waiting for Monday. 44 px cards, no hover info.
## Its help is the hub header's "?" (entry "market", career_hub._help_entry).

signal coach_requested(coach_id: String)
signal changed


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

	var lists := mk.listing()
	for sec in CoachMarket.SECTIONS:
		var list: Array = lists.get(sec, [])
		if list.is_empty():
			continue
		var col := UIKit.vbox(8)
		col.add_child(UIKit.label(str(ui.sections[sec]), "CaptionLabel"))
		for c in list:
			col.add_child(_card(mk, c))
		add_child(col)
	add_child(UIKit.wrapped(str(ui.more_seen if mk.seen_tf else ui.more_later), "CaptionLabel"))


## A coach as a card: tap = the coach's page.
func _card(mk: CoachMarket, c: Dictionary) -> Control:
	var ui: Dictionary = Data.market.ui
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
	lines.append([str(ui.cost[str(co.kind)]).format({"cost": co.cost}), "CaptionLabel"])
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
