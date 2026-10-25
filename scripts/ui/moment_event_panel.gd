class_name MomentEventPanel
extends RefCounted
## A moment that stops Play week (StoryletSystem, event.kind "moment": the coach's Sunday week talk, an important moment, a
## rule offer, a proposal of the coach (session C4)) as a MESSAGE in the career hub's dimmed decision layer (GDD 4.9.7, session C3): a caption with the date and a
## "?", the sender's round initial and name, the text in a bubble, the replies as 44 px buttons with the cost hint under
## each. The same builders as the People tab (PeopleUI), so a message looks the same wherever it shows up.

const HELP := "moment"   # the help entry (data/help.json), opened by the "?" in the caption row


static func handles(e: Dictionary) -> bool:
	return e.get("source", "") == "moments" and str(e.get("kind", "")) == "moment" and PeopleUI.system() != null \
			and not PeopleUI.system().moment(str(e.get("moment", ""))).is_empty()


## The panel content for event `e`, `width` px wide. `on_answer(reply_id)` is called with the player's answer; `on_help`
## is called by the "?".
static func build(e: Dictionary, width: float, on_answer: Callable, on_help := Callable()) -> Control:
	var ms := PeopleUI.system()
	var m := ms.moment(str(e.moment))
	var box := UIKit.vbox(12)
	box.custom_minimum_size.x = width
	var head := PeopleUI.ui("stop_head")
	if bool(m.get("talk", false)):
		head = PeopleUI.ui("stop_head_talk")
	elif str(m.get("kind", "")) == "proposal":
		head = PeopleUI.ui("stop_head_proposal")
	elif StoryletSystem.CUSTOM_SYSTEMS.has(str(m.get("kind", ""))):   # a goal talk, a meet or target he suggests (session C5)
		head = PeopleUI.ui("stop_head_" + str(m.kind))
	var caption := UIKit.label("%s · %s" % [head, Calendar.format_day(e.date).to_upper()], "CaptionLabel")
	if on_help.is_valid():
		var row := UIKit.hbox(8)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caption.clip_text = true
		row.add_child(caption)
		var help := HelpButton.new(HELP)
		help.pressed.connect(func(): on_help.call())
		row.add_child(help)
		box.add_child(row)
	else:
		box.add_child(caption)
	box.add_child(PeopleUI.moment_card(ms, m, on_answer))
	return box


## Is there something to show after the answer to the stop event `e`: the other person's reply and / or what changed?
static func has_result(e: Dictionary) -> bool:
	var ms := PeopleUI.system()
	if ms == null or str(e.get("kind", "")) != "moment":
		return false
	var m := ms.moment(str(e.get("moment", "")))
	return not m.is_empty() and m.answer != "" and (not PeopleUI.result_messages(ms, m).is_empty() or PeopleUI.has_changes(m))


## The result card (GDD 4.9.5 "Consequences shown"): the reply that came back, what changed in words with ▲ / ▼, Continue.
static func result(e: Dictionary, width: float, on_continue: Callable, on_help := Callable()) -> Control:
	var ms := PeopleUI.system()
	var m := ms.moment(str(e.moment))
	var cfg: Dictionary = Data.moments.changes
	var box := UIKit.vbox(12)
	box.custom_minimum_size.x = width
	var caption := UIKit.label("%s · %s" % [str(cfg.result_head), Calendar.format_day(e.date).to_upper()], "CaptionLabel")
	if on_help.is_valid():
		var row := UIKit.hbox(8)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caption.clip_text = true
		row.add_child(caption)
		var help := HelpButton.new(HELP)
		help.pressed.connect(func(): on_help.call())
		row.add_child(help)
		box.add_child(row)
	else:
		box.add_child(caption)
	for x in PeopleUI.result_messages(ms, m):
		box.add_child(PeopleUI.message(ms, x))
	if PeopleUI.has_changes(m):
		box.add_child(PeopleUI.changes_panel(m.get("changes", []), m))
	var go := UIKit.button(str(cfg["continue"]), true, 200)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): on_continue.call())
	box.add_child(go)
	return box
