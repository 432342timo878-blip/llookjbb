class_name PeopleView
extends VBoxContainer
## The People tab (GDD 4.9.7, session C3): the threads (coach, training group, family, friends, school), the open thread and
## the coach's profile. PC: the list on the left and the open thread (or the profile) beside it, in the tab itself (user
## 2026-10-11), the coach's thread open at first. Phone: the list first, then the thread as a page of its own with a back
## button. Newest exchange first, and what waits for an answer on top, so nothing needs scrolling down to be found.
## A thread is marked read when it is opened (the dot goes). Answers go through StoryletSystem.answer, which also answers
## the stop event of a moment. Every control is at least 44 px; nothing needs hovering.
## `page`: "" = the list (phone) / the coach thread (PC), a thread id, "profile" (the head coach), "market" (Find a coach,
## session C6) or "coach:<id>" (another coach's page).

signal page_changed(page: String)
signal changed   # something was answered or read: the hub redraws its marks and the stop panel

var page := ""

var _ms: StoryletSystem


func _init(open_page := "") -> void:
	page = open_page
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms = PeopleUI.system()
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if _ms == null:
		return
	var shown := page
	if shown == "" and not Layout.stacked():
		shown = "coach"   # (PC: something is always open beside the list)
	if Layout.stacked():   # a phone, or PC beside the hub's side panel (the day editor / help): pages instead of two columns
		if shown == "":
			add_child(_list(false))
		else:
			add_child(_page(shown))
		return
	var row := UIKit.hbox(16)
	var content := _page(shown)   # (built first: opening a thread marks it read, so the list shows it as read)
	var list := _list(true)
	list.custom_minimum_size.x = 300
	list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(list)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(content)
	add_child(row)


func _go(p: String) -> void:
	page = p
	page_changed.emit(p)
	_build()


# --- The list ---------------------------------------------------------------------------------------------------

func _list(with_selection: bool) -> Control:
	var col := UIKit.vbox(10)
	col.add_child(UIKit.label(PeopleUI.ui("list_head"), "CaptionLabel"))
	if not with_selection:
		col.add_child(UIKit.wrapped(PeopleUI.ui("list_note")))
	var current := page if page != "" else "coach"
	for t in StoryletSystem.thread_ids():   # (a thread opened beside the list is marked; stacked pages have no selection)
		if t == "coaches" and not CoachMarket.enabled and _ms.thread("coaches").is_empty():
			continue   # (the coach market is off: tools)
		col.add_child(_thread_row(str(t), with_selection and (current == t or (current == "profile" and t == "coach"))))
	if CoachMarket.enabled:   # Find a coach (session C6)
		col.add_child(_find_row(with_selection and (current == "market" or current.begins_with("coach:"))))
	return col


## The row that opens Find a coach.
func _find_row(selected: bool) -> Control:
	var ui: Dictionary = Data.market.ui
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeBuilder.card_box(selected))
	card.custom_minimum_size.y = 64
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var col := UIKit.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in [[str(ui.find_button), "SubheadingLabel"], [str(ui.find_sub), "MutedLabel"]]:
		var lab := UIKit.wrapped(str(l[0]), str(l[1]))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lab)
	margin.add_child(col)
	card.add_child(margin)
	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_go.bind("market"))
	card.add_child(button)
	return card


func _thread_row(thread_id: String, selected: bool) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeBuilder.card_box(selected))
	card.custom_minimum_size.y = 64
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var row := UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := UIKit.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := StoryletSystem.thread_name(thread_id)
	if thread_id == "group":
		var coach := _ms.people_for("teammate")
		if not coach.is_empty():
			head += " (%d)" % coach.size()
	var title := UIKit.label(head, "SubheadingLabel")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var last := _ms.last_message(thread_id)
	var waiting := _waiting(thread_id).size()
	var text := ""
	if waiting > 0:
		text = str(_waiting(thread_id)[0].text)
	elif not last.is_empty():
		text = str(last.text)
	var sub := UIKit.label(PeopleUI.preview(text, 60) if text != "" else str(Data.moments.threads[thread_id].empty), "MutedLabel")
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if last.is_empty() and waiting == 0:
		sub.modulate = Color(1, 1, 1, 0.7)
	col.add_child(sub)
	row.add_child(col)
	var unread := _ms.unread(thread_id)
	if waiting > 0 or unread > 0:
		var badge := UIKit.badge(str(maxi(waiting, unread)), Palette.ACCENT, 22.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
	margin.add_child(row)
	card.add_child(margin)
	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_go.bind(thread_id))
	card.add_child(button)
	return card


func _waiting(thread_id: String) -> Array:
	return _ms.pending().filter(func(m): return m.thread == thread_id)


# --- A thread or the profile --------------------------------------------------------------------------------

func _page(shown: String) -> Control:
	if shown == "profile":
		return _profile("")
	if shown == "market":
		return _market()
	if shown.begins_with("coach:"):
		return _profile(shown.trim_prefix("coach:"))
	return _thread(shown)


## A coach's page: the head coach's (`coach_id` "") or another coach's from Find a coach (session C6).
func _profile(coach_id: String) -> Control:
	var col := UIKit.vbox(12)
	if Layout.stacked() and coach_id == "":
		col.add_child(_back_button())
	var profile := CoachProfile.new(coach_id)
	profile.messages_requested.connect(_go.bind("coach"))
	profile.back_requested.connect(_go.bind("market"))
	profile.changed.connect(func(): changed.emit())
	col.add_child(profile)
	return col


## Find a coach (session C6).
func _market() -> Control:
	var col := UIKit.vbox(12)
	if Layout.stacked():
		col.add_child(_back_button())
	var view := CoachMarketView.new()
	view.coach_requested.connect(func(cid: String):
		_go("profile" if cid == Game.athlete.coach_id else "coach:" + cid))
	view.changed.connect(func(): changed.emit())
	col.add_child(view)
	return col


func _back_button() -> Button:
	var back := UIKit.button(PeopleUI.ui("back"), false, 140)
	back.pressed.connect(_go.bind(""))
	return back


func _thread(thread_id: String) -> Control:
	var col := UIKit.vbox(12)
	if Layout.stacked():
		col.add_child(_back_button())
	var head := UIKit.hbox(8)
	var title := UIKit.label(StoryletSystem.thread_name(thread_id), "HeadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if thread_id == "coach" and not (Game.get_system("coach") as CoachSystem).head().is_empty():
		var profile := UIKit.button(PeopleUI.ui("profile_button"), false, 160)
		profile.pressed.connect(_go.bind("profile"))
		head.add_child(profile)
	col.add_child(head)

	if thread_id == "group":
		col.add_child(_members())

	# What waits for an answer, on top.
	var waiting := _waiting(thread_id)
	if not waiting.is_empty():
		var box := UIKit.vbox(14)
		box.add_child(UIKit.label(PeopleUI.ui("waiting"), "CaptionLabel"))
		for m in waiting:
			box.add_child(PeopleUI.moment_card(_ms, m, _answer.bind(str(m.id))))
		box.add_child(UIKit.wrapped(PeopleUI.ui("reply_note"), "CaptionLabel"))
		col.add_child(UIKit.alert_panel(box, Palette.ACCENT, 14))

	var blocks := PeopleUI.exchanges(_ms, thread_id)
	if blocks.is_empty() and waiting.is_empty():
		var empty := UIKit.vbox(4)
		empty.add_child(UIKit.label(PeopleUI.ui("empty_head"), "CaptionLabel"))
		empty.add_child(UIKit.wrapped(str(Data.moments.threads[thread_id].empty), ""))
		col.add_child(UIKit.panel(empty, 14))
	for msgs in blocks:
		col.add_child(PeopleUI.exchange(_ms, msgs))
	# Opened = read (the new-message highlight shows this one time; the dot is gone when the page is shown again).
	if _ms.unread(thread_id) > 0:
		_ms.mark_read(thread_id)
		changed.emit.call_deferred()
	return col


## The training group's people: name, age, event and role.
func _members() -> Control:
	var coach := (Game.get_system("coach") as CoachSystem).head()
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(PeopleUI.ui("members_head"), "CaptionLabel"))
	var roles: Dictionary = Data.coaching.club.group.roles
	for t in coach.get("group", []):
		var line := UIKit.vbox(0)
		line.add_child(UIKit.label("%s %s" % [t.first_name, t.last_name]))
		var event_name := str(Data.get_event(str(t.event)).get("name", t.event))
		line.add_child(UIKit.wrapped(str(Data.coach_talk.profile.group_line).format({"age": int(Game.date.year) - int(t.birth_year),
				"event": event_name, "role": str(roles.get(str(t.role), {}).get("word", ""))}), "MutedLabel"))
		box.add_child(line)
	return UIKit.panel(box, 14)


## (Bound as _answer.bind(moment id), then the reply button binds the reply id: the arguments arrive in that order.)
func _answer(moment_id: String, reply_id: String) -> void:
	_ms.answer(moment_id, reply_id)
	_build()
	changed.emit()
