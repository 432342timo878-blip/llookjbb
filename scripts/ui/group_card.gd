class_name GroupCard
extends RefCounted
## The training group's card (GDD 4.10 decision 6, session P2a): its size and coach, its level against yours, the pull it gives your
## hard sessions (or takes), its fixed days and sessions, and the two choices: leave it (train alone) or rejoin. Leaving asks once
## and says what it costs. Read from CircleSystem.group_info; the only things it changes are CircleSystem.leave_group / join_group.
## 44 px buttons, no hover. Used by the People tab's group page; the day editor and the week report refer to it by name.


## The card. `on_change` after leaving or rejoining (the page redraws, the planner follows), `on_find` opens Find a coach.
static func build(on_change: Callable, on_find: Callable) -> Control:
	var circle := CircleSystem.sys()
	if circle == null or not CircleSystem.active():
		return null
	var u: Dictionary = Data.circle.ui
	var info := circle.group_info()
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(u.group_head), "SectionLabel"))
	var coach := str(info.coach)
	if not bool(info.has):
		box.add_child(UIKit.wrapped(str(u.group_none).format({"coach": coach}), "BodyLabel"))
		box.set_meta("group_card", "none")
		return UIKit.panel(box, 14)
	box.add_child(UIKit.wrapped(str(u.group_size).format({"n": int(info.size), "coach": coach}), "ItemLabel"))
	var days := []
	for d in info.days:
		days.append("%s (%s)" % [str(d.name), str(d.session)])
	if bool(info["in"]):
		box.add_child(UIKit.wrapped(str(u.group_level).format({"group": "%.1f" % float(info.level), "mine": "%.1f" % float(info.mine), "word": str(info.word)}), "BodyLabel"))
		box.add_child(UIKit.wrapped(_pull_text(float(info.pull)), "WhyLabel"))
		box.add_child(UIKit.wrapped(str(u.group_days).format({"days": ", ".join(days), "sessions": ""}).strip_edges(), "BodyLabel"))
		var confirm := UIKit.vbox(6)
		confirm.visible = false
		confirm.add_child(UIKit.wrapped(str(u.group_leave_note).format({"coach": coach}), "BodyLabel"))
		var yes := UIKit.button(str(u.group_leave_confirm), false, 0.0)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes.pressed.connect(func():
			circle.leave_group()
			if on_change.is_valid():
				on_change.call())
		confirm.add_child(yes)
		var leave := UIKit.button(str(u.group_leave), false, 0.0)
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave.set_meta("group_leave", true)
		leave.pressed.connect(func(): confirm.visible = not confirm.visible)
		var row := UIKit.flex(8)
		row.add_child(leave)
		var find := UIKit.button(str(u.group_find), false, 0.0)
		find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		find.pressed.connect(func():
			if on_find.is_valid():
				on_find.call())
		row.add_child(find)
		box.add_child(row)
		box.add_child(confirm)
		box.set_meta("group_card", "in")
	else:
		box.add_child(UIKit.wrapped(str(u.group_alone).format({"coach": coach}), "BodyLabel"))
		box.add_child(UIKit.wrapped(str(u.group_join_note).format({"coach": coach, "days": ", ".join(days)}), "WhyLabel"))
		var join := UIKit.button(str(u.group_join), false, 0.0)
		join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		join.set_meta("group_join", true)
		join.pressed.connect(func():
			circle.join_group()
			if on_change.is_valid():
				on_change.call())
		box.add_child(join)
		box.set_meta("group_card", "alone")
	return UIKit.panel(box, 14)


## "Pull: your group's hard sessions come out about 3% better." / worse / none to speak of.
static func _pull_text(pull: float) -> String:
	var u: Dictionary = Data.circle.ui
	var pct := "%.1f" % (absf(pull) * 100.0)
	if pull >= 0.0025:
		return str(u.group_pull_up).format({"pct": pct})
	if pull <= -0.0025:
		return str(u.group_pull_down).format({"pct": pct})
	return str(u.group_pull_none)
