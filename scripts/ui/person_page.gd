class_name PersonPage
extends VBoxContainer
## A person's page (GDD 4.10 decision 6, session P2a): how close they are (a bar and a word, the numbers and causes behind a tap),
## what they give, what they cost, what the last week did to it, the standing free evenings you spend with them and the recent
## causes of the closeness. Read from StoryletSystem.people and CircleSystem.page_of; the only things it changes are the habits'
## companions (HabitSystem.set_companion) and, to meet someone on a day that is not a friends slot, that day's habit.
## 44 px for everything tappable, nothing needs hovering. Its help is the hub header's "?" (entry "person").

signal back_requested
signal changed

var _pid := ""
var _back_text := ""
var _ending := false   # "End it" was pressed and its confirm is showing (session P2b)


func _init(person_id: String, back_text := "") -> void:
	_pid = person_id
	_back_text = back_text
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var ms := PeopleUI.system()
	var circle := CircleSystem.sys()
	var u: Dictionary = Data.circle.ui
	var p: Dictionary = ms.people.get(_pid, {}) if ms != null else {}
	if p.is_empty() or circle == null:
		return
	if _back_text != "":
		var back := UIKit.button(_back_text, false, 200)
		back.pressed.connect(func(): back_requested.emit())
		add_child(back)
	var page := circle.page_of(p)
	var fill := {"name": StoryletSystem.short_name(p)}
	var name := StoryletSystem.person_name(p)

	# The head: who, and how they are known.
	var head := UIKit.hbox(12)
	head.add_child(PeopleUI.avatar(name, 44.0))
	var titles := UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.wrapped(name, "HeadingLabel"))
	var sub := [str(p.get("word", ""))]
	if str(p.get("trait", "")) != "":
		sub.append(str(Data.cast.friends.trait_words.get(str(p.trait), "")))
	titles.add_child(UIKit.wrapped(" · ".join(sub.filter(func(x): return str(x) != "")), "MutedLabel"))
	head.add_child(titles)
	add_child(head)

	var together := _together_box(p)   # (session P2b: a crush, the relationship, an ex)
	if together != null:
		add_child(together)

	# How close: the bar, its word, the numbers behind a tap.
	var close := VBoxContainer.new()
	close.add_theme_constant_override("separation", 6)
	var bar := StatBar.new(str(u.page_close), float(page.rel), -1.0, _close_why(page), str(page.word))
	close.add_child(bar)
	var lines: Array = WeekCauses.person_lines(ms, p, p.get("log", []))
	var tapped := CausesUI.tappable(close, "\n".join(lines))
	tapped.set_meta("cause_row", "person:" + _pid)
	add_child(UIKit.panel(tapped, 14))

	# Last week.
	var last: Dictionary = page.last
	if not last.is_empty():
		var change := float(last.gain) - float(last.fade)
		var change_text := str(u.page_closer).format({"n": "%.1f" % change}) if change > 0.05 else (str(u.page_further).format({"n": "%.1f" % absf(change)}) if change < -0.05 else str(u.page_same))
		var slots_text := ("%.1f" % float(last.slots)).trim_suffix(".0")
		var week_key := "page_week_none" if float(last.slots) <= 0.0 else ("page_week_one" if absf(float(last.slots) - 1.0) < 0.05 else "page_week")
		add_child(UIKit.wrapped(str(u[week_key]).format({"slots": slots_text, "change": change_text}), "WhyLabel"))

	# What they give and cost.
	if not page.gives.is_empty():
		add_child(UIKit.panel(_lines_box(str(u.page_gives).format({"name": str(fill.name).to_upper()}), page.gives), 14))
	if not page.costs.is_empty():
		add_child(UIKit.panel(_lines_box(str(u.page_costs).format({"name": str(fill.name).to_upper()}), page.costs), 14))
	if bool(page.quiet):
		add_child(UIKit.panel(_lines_box("", [str(u.page_quiet).format(fill)]), 14))
	if str(page.kind) == "acquaintance" and int(page.to_friend) > 0:
		add_child(UIKit.wrapped(str(u.page_to_friend).format({"n": int(page.to_friend), "name": fill.name}), "WhyLabel"))

	# Meet: the standing free evenings.
	if str(page.kind) in ["best_friend", "friend", "acquaintance", "teammate", "former"]:
		add_child(_meet_box(p))


## TOGETHER (session P2b): a crush waiting for its answer, the relationship (how long, last week's partner slots, how neglected they
## feel, the texting setting, End it with one confirm), or an ex. Null for everyone else.
func _together_box(p: Dictionary) -> Control:
	if not RomanceSystem.active():
		return null
	var rs := RomanceSystem.sys()
	var info := rs.box_of(_pid)
	if info.is_empty():
		return null
	var u: Dictionary = Data.romance.ui
	var name := StoryletSystem.short_name(p)
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(u.box_head), "SectionLabel"))
	match str(info.mode):
		"crush":
			box.add_child(UIKit.wrapped(str(u.box_crush).format({"name": name}), "BodyLabel"))
		"ex":
			var ex: Dictionary = StoryletSystem._date_of(int(info.ex_day))
			box.add_child(UIKit.wrapped(str(u.ex_note).format({"date": DayInfo.short_day(ex)}), "BodyLabel"))
		"dating":
			var weeks := int(info.weeks)
			box.add_child(UIKit.wrapped(str(u.box_week_one if weeks == 1 else u.box_weeks).format({"n": weeks}), "BodyLabel"))
			var last := ""
			if int(info.slots_last) > 0:
				last = str(u.box_slots_last_one if int(info.slots_last) == 1 else u.box_slots_last).format({"n": int(info.slots_last)})
			else:
				var neglect := ""
				if int(info.neglect) >= 2:
					neglect = str(u.box_neglect_2).format({"name": name})
				elif int(info.neglect) == 1:
					neglect = str(u.box_neglect_1).format({"name": name})
				last = str(u.box_slots_none).format({"neglect": neglect}).strip_edges()
			box.add_child(UIKit.wrapped(last, "WhyLabel"))
			if int(rs.dip.get("weeks", 0)) > 0:
				box.add_child(UIKit.wrapped(str(u.dip_note).format({"n": int(rs.dip.weeks)}), "WhyLabel"))
			box.add_child(UIKit.label(str(u.box_texting), "CaptionLabel"))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			var group := ButtonGroup.new()
			var opts: Dictionary = Data.romance.texting.options
			for key in opts:
				var b := UIKit.toggle(str(opts[key].name), group)
				b.custom_minimum_size = Vector2(150, 44)
				b.button_pressed = rs.texting == str(key)
				b.set_meta("texting", str(key))
				var option := str(key)
				b.pressed.connect(func():
					rs.set_texting(option)
					_build()
					changed.emit())
				flow.add_child(b)
			box.add_child(flow)
			box.add_child(UIKit.wrapped(str(opts[rs.texting].does), "WhyLabel"))
			box.add_child(_end_row(name, rs))
	return UIKit.panel(box, 14)


## End it: one button, then one confirm (it is your call; the next weeks weigh on the mood).
func _end_row(name: String, rs: RomanceSystem) -> Control:
	var u: Dictionary = Data.romance.ui
	var col := UIKit.vbox(6)
	if not _ending:
		var b := UIKit.button(str(u.box_end), false, 140)
		b.set_meta("end_it", true)
		b.pressed.connect(func():
			_ending = true
			_build())
		col.add_child(b)
		return col
	col.add_child(UIKit.wrapped(str(u.box_end_note), "WhyLabel"))
	var row := UIKit.flex(8)
	var sure := UIKit.button(str(u.box_end_sure).format({"name": name}), true, 0.0)
	sure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sure.set_meta("end_confirm", true)
	sure.pressed.connect(func():
		_ending = false
		rs.end_it()
		_build()
		changed.emit())
	row.add_child(sure)
	var keep := UIKit.button(str(u.box_end_cancel), false, 0.0)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(func():
		_ending = false
		_build())
	row.add_child(keep)
	col.add_child(row)
	return col


func _close_why(page: Dictionary) -> String:
	if str(page.kind) == "acquaintance":
		return str(Data.circle.ui.page_close_acq).format({"at": int(Data.circle.status.friend_at), "min": int(Data.circle.status.min_slots)})
	return ""


func _lines_box(head: String, lines: Array) -> Control:
	var box := UIKit.vbox(6)
	if head != "":
		box.add_child(UIKit.label(head, "SectionLabel"))
	for l in lines:
		box.add_child(UIKit.wrapped(str(l), "BodyLabel"))
	return box


## MEET {name}: a toggle per slot; on = this slot is a friends slot you spend with them every week.
func _meet_box(p: Dictionary) -> Control:
	var u: Dictionary = Data.circle.ui
	var hs := HabitSystem.sys()
	var box := UIKit.vbox(8)
	if hs == null:
		return box
	box.add_child(UIKit.label(str(u.page_meet).format({"name": StoryletSystem.short_name(p).to_upper()}), "SectionLabel"))
	box.add_child(UIKit.wrapped(str(u.page_meet_hint).format({"name": StoryletSystem.short_name(p)}), "WhyLabel"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for i in 7:
		var on := str(hs.habit_with.get(i, "")) == _pid and hs.habit(i) in HabitSystem.WITH_ACTIVITIES
		var b := Button.new()
		b.toggle_mode = true
		b.theme_type_variation = "ToggleButton"
		b.text = str(u.page_slot_with).format({"slot": HabitSystem.slot_short(i), "name": StoryletSystem.short_name(p)}) if on \
				else str(u.page_slot_plain).format({"slot": HabitSystem.slot_short(i), "activity": HabitSystem.activity_name(hs.habit(i))})
		b.button_pressed = on
		b.custom_minimum_size = Vector2(120, 44)
		b.set_meta("meet_slot", i)
		var slot := i
		b.pressed.connect(func():
			if on:
				hs.set_companion(slot, "", true)
			else:
				if not hs.habit(slot) in HabitSystem.WITH_ACTIVITIES:
					hs.set_habit(slot, "friends")
				hs.set_companion(slot, _pid, true)
			_build()
			changed.emit())
		flow.add_child(b)
	box.add_child(flow)
	return UIKit.panel(box, 14)
