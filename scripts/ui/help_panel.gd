class_name HelpPanel
extends VBoxContainer
## The help for one screen (GDD 5 "Help"), built from `data/help.json`: "HOW THIS WORKS", the title and Close, then
## the sections (a heading and a few plain sentences each), all open, with "See also: …" buttons that open a topic
## entry ("◀ Back" returns). The host puts it in a container: the hub's side slot on PC (shared with the day editor),
## or a HelpOverlay (a bottom sheet on a phone, a panel over the right side on PC). 44 px buttons, nothing on hover.

signal close_requested
signal navigated   # another entry was opened (a topic, or back): `stack` changed
signal rebuilt     # the content was redrawn (a sheet re-fits its height)

## Entry ids, the last one shown: [screen entry, topic, topic…]. Kept by the host across layout switches.
var stack: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func current() -> String:
	return "" if stack.is_empty() else str(stack.back())


func show_entry(id: String) -> void:
	show_stack([id])


func show_stack(ids: Array) -> void:
	stack = ids.duplicate()
	_build()


func _open(id: String) -> void:
	stack.append(id)
	_build()
	navigated.emit()


func _back() -> void:
	if stack.size() > 1:
		stack.pop_back()
	_build()
	navigated.emit()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var id := current()
	var e := Help.entry(id)
	Help.mark_seen(id)

	var head := UIKit.hbox(8)
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.label("SEE ALSO" if Help.is_topic(id) and stack.size() > 1 else "HOW THIS WORKS", "CaptionLabel"))
	titles.add_child(UIKit.wrapped(e.get("title", "Help"), "HeadingLabel"))
	head.add_child(titles)
	var close := UIKit.button("Close", false, 90)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): close_requested.emit())
	head.add_child(close)
	add_child(head)

	if stack.size() > 1:
		var back := _link_button("◀  Back to " + str(Help.entry(str(stack[-2])).get("title", "")))
		back.pressed.connect(_back)
		add_child(back)

	if e.is_empty():
		add_child(UIKit.wrapped("No help for this screen yet.", ""))
	for s in e.get("sections", []):
		var col := UIKit.vbox(4)
		col.add_child(UIKit.wrapped(str(s.get("heading", "")), "SubheadingLabel"))
		col.add_child(UIKit.wrapped(str(s.get("text", "")), ""))
		for topic in s.get("see", []):
			if str(topic) in stack:
				continue   # already open further back: "Back" gets there
			var b := _link_button("See also: %s  ›" % Help.entry(str(topic)).get("title", topic))
			b.pressed.connect(_open.bind(str(topic)))
			col.add_child(b)
		add_child(col)
	rebuilt.emit()


## A full-width 44 px button with left-aligned text that is cut short (…) rather than pushing the panel wider.
func _link_button(text: String) -> Button:
	var b := UIKit.button(text, false, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
