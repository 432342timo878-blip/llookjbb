class_name StandingOrders
extends RefCounted
## "Standing orders" at the bottom of the Training tab (GDD 4.9.2 / 4.9.5, session C3): the setting "Play week stops for:
## Important only / Every moment", the coach-proposal setting "Let the coach adjust my days: Ask me first / Always, tell me /
## Never" (session C4; CoachProposals.setting / set_setting, texts in data/coach_talk.json proposal.settings) and the rules saved
## from repeated answers, each with Remove. Reads and changes StoryletSystem (stop_mode / set_stop_mode, standing_orders /
## clear_rule) and CoachProposals only.


static func build() -> Control:
	var ms := PeopleUI.system()
	var box := UIKit.vbox(12)
	if ms == null:
		return box
	box.add_child(UIKit.label(PeopleUI.ui("standing_head"), "CaptionLabel"))
	box.add_child(UIKit.label(PeopleUI.ui("standing_stops"), "SubheadingLabel"))
	var text := UIKit.wrapped(str(Data.moments.settings.stops[ms.stop_mode()].text))
	var group := ButtonGroup.new()
	var row := UIKit.flex(8)
	for mode in Data.moments.settings.stops:
		var b := UIKit.toggle(str(Data.moments.settings.stops[mode].name), group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = ms.stop_mode() == mode
		b.pressed.connect(func():
			ms.set_stop_mode(str(mode))
			text.text = str(Data.moments.settings.stops[str(mode)].text))
		row.add_child(b)
	box.add_child(row)
	box.add_child(text)

	var cp := Game.get_system("proposals") as CoachProposals
	if cp != null:
		box.add_child(_coach_setting(cp))

	box.add_child(UIKit.label(PeopleUI.ui("standing_rules"), "SubheadingLabel"))
	var rules := UIKit.vbox(8)
	box.add_child(rules)
	_fill_rules(ms, rules)
	return UIKit.panel(box, 16)


## "Let the coach adjust my days": three toggles (a row on PC, a column on a phone) and what the chosen one means.
static func _coach_setting(cp: CoachProposals) -> Control:
	var s: Dictionary = Data.coach_talk.proposal.settings
	var col := UIKit.vbox(8)
	col.add_child(UIKit.label(str(s.head), "SubheadingLabel"))
	var text := UIKit.wrapped(str(s[cp.setting()].text))
	var group := ButtonGroup.new()
	var row := UIKit.flex(8)
	for mode in Data.coaching.proposals.modes:
		var b := UIKit.toggle(str(s[mode].name), group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = cp.setting() == mode
		b.pressed.connect(func():
			cp.set_setting(str(mode))
			text.text = str(s[str(mode)].text))
		row.add_child(b)
	col.add_child(row)
	col.add_child(text)
	return col


static func _fill_rules(ms: StoryletSystem, rules: VBoxContainer) -> void:
	for c in rules.get_children():
		rules.remove_child(c)
		c.queue_free()
	var list := ms.standing_orders()
	if list.is_empty():
		rules.add_child(UIKit.wrapped(PeopleUI.ui("standing_none")))
		return
	for o in list:
		var row := UIKit.flex(8)
		var label := UIKit.wrapped(str(o.rule), "")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var remove := UIKit.button(PeopleUI.ui("standing_remove"), false, 110)
		remove.pressed.connect(func():
			ms.clear_rule(str(o.group))
			_fill_rules(ms, rules))
		row.add_child(remove)
		rules.add_child(row)
