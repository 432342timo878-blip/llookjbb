class_name PeopleUI
extends RefCounted
## Small builders for the people around the athlete (GDD 4.9.5 / 4.9.7, session C3): a message as a bubble with a round
## initial, a moment waiting for an answer with its reply buttons (44 px, the cost hint under each), a block of one exchange
## (his question, your answer, his reply). Used by the People tab (PeopleView), the Today card and the hub's stop panel for
## moments, so a message looks the same everywhere. Reading and answering go through StoryletSystem's UI API only.

const COLORS := [Color("#4f8fbf"), Color("#5a9e6f"), Color("#c9a63c"), Color("#7a6bb0"), Color("#d9774a"), Color("#8a8fa8")]


static func system() -> StoryletSystem:
	return Game.get_system("moments") as StoryletSystem


## The name shown for a message's sender ("you", "system" or a person id).
static func name_of(ms: StoryletSystem, from: String) -> String:
	if from == "you":
		return Game.athlete.first_name
	return StoryletSystem.person_name(ms.people.get(from, {}))


static func ui(key: String) -> String:
	return str(Data.moments.ui[key])


static func color_of(name: String) -> Color:
	return COLORS[posmod(name.hash(), COLORS.size())]


## The round initial of a person.
static func avatar(name: String, size := 36.0) -> Control:
	var initial := name.left(1).to_upper() if name != "" else "?"
	var a := UIKit.badge(initial, color_of(name), size)
	a.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return a


## One message. `unread` gives it the accent edge. A message of the player is on the right (tinted), the game's own lines
## ("You didn't answer.", rules) are centred and muted, everything else is a person's bubble with their initial and name.
static func message(ms: StoryletSystem, msg: Dictionary, show_name := true) -> Control:
	var from := str(msg.from)
	if from == "system":
		var line := UIKit.wrapped(str(msg.text), "MutedLabel")
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return line
	var text := UIKit.wrapped(str(msg.text), "")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if from == "you":
		var box := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Palette.ACCENT, 0.22)
		style.set_corner_radius_all(Palette.RADIUS)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		box.add_theme_stylebox_override("panel", style)
		box.add_child(text)
		var row := UIKit.hbox(0)
		var pad := Control.new()
		pad.custom_minimum_size.x = 36 if Layout.compact else 120
		row.add_child(pad)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(box)
		return row
	var who := name_of(ms, from)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if show_name:
		col.add_child(UIKit.label("%s · %s" % [who, DayInfo.short_day(msg.date)], "CaptionLabel"))
	var bubble := PanelContainer.new()
	var unread := not bool(msg.read)
	bubble.add_theme_stylebox_override("panel", UIKit.alert_style(Palette.ACCENT, 10) if unread else ThemeBuilder.card_box(false))
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 10 if unread else 12)
	inner.add_child(text)
	bubble.add_child(inner)
	col.add_child(bubble)
	var row := UIKit.hbox(8)
	row.add_child(avatar(who))
	row.add_child(col)
	return row


## The messages of a thread grouped in exchanges (a question, the player's answer and the reply share a moment id; a plain
## message is its own exchange), newest exchange first, each in the order it was written: [[message, ...], ...]. Messages
## of a moment that still waits for an answer are left out (they are shown with their reply buttons).
static func exchanges(ms: StoryletSystem, thread_id: String) -> Array:
	var waiting := {}
	for m in ms.pending():
		waiting[m.id] = true
	var blocks := []
	var by_moment := {}
	var list := ms.thread(thread_id)
	for i in list.size():
		var x: Dictionary = list[i]
		var mid := str(x.moment)
		if mid != "" and waiting.has(mid):
			continue
		if mid != "" and by_moment.has(mid):
			var b: Dictionary = by_moment[mid]
			b.msgs.append(x)
			b.last = i
		else:
			var b2 := {"msgs": [x], "last": i}
			blocks.append(b2)
			if mid != "":
				by_moment[mid] = b2
	blocks.sort_custom(func(a, b): return int(a.last) > int(b.last))
	return blocks.map(func(b): return b.msgs)


## A moment waiting for an answer: who asks, what, the reply buttons (44 px) with the hint under each.
## `on_pick` is called with the reply id. `head` = a caption above (e.g. "WEEK TALK").
static func moment_card(ms: StoryletSystem, m: Dictionary, on_pick: Callable, head := "") -> Control:
	var col := UIKit.vbox(10)
	if head != "":
		col.add_child(UIKit.label(head, "CaptionLabel"))
	var from := str(m.from)
	var msg := {"from": from, "text": m.text, "date": m.date, "read": true, "moment": m.id}
	if from == "system":   # a rule offer
		col.add_child(UIKit.wrapped(str(m.text), ""))
	else:
		col.add_child(message(ms, msg))
	col.add_child(replies(m, on_pick))
	return col


## The reply buttons of a moment: a full-width 44 px button per reply with its cost hint under it.
static func replies(m: Dictionary, on_pick: Callable) -> Control:
	var col := UIKit.vbox(6)
	for r in m.replies:
		var b := Button.new()
		b.text = str(r.label)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# An answer is something to tap: a raised button with an accent edge (the panels around it are the same dark grey).
		b.add_theme_stylebox_override("normal", _reply_style(Palette.SURFACE_3, Color(Palette.ACCENT, 0.5)))
		b.add_theme_stylebox_override("hover", _reply_style(Color("#363c4c"), Palette.ACCENT))
		b.add_theme_stylebox_override("pressed", _reply_style(Palette.SURFACE_2, Palette.ACCENT))
		b.pressed.connect(on_pick.bind(str(r.id)))
		col.add_child(b)
		if str(r.hint) != "":
			var hint := UIKit.wrapped(str(r.hint), "CaptionLabel")
			hint.add_theme_font_size_override("font_size", 14)
			col.add_child(hint)
	return col


static func _reply_style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(Palette.RADIUS)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## One exchange: its messages with a date line when it started (the person's name is on their bubble), and under them the
## result card of the answer when it changed something.
static func exchange(ms: StoryletSystem, msgs: Array) -> Control:
	var col := UIKit.vbox(6)
	for x in msgs:
		col.add_child(message(ms, x, x == msgs[0]))
	var m := ms.moment(str(msgs[0].moment)) if str(msgs[0].moment) != "" else {}
	if not m.is_empty() and not m.get("changes", []).is_empty():
		col.add_child(changes_panel(m.changes))
	return col


## What came back after the player's answer to moment `m`: the messages written after their reply (the sender's answer or the
## game's result line), oldest first. [] when there is none (a plain "Thanks, coach").
static func result_messages(ms: StoryletSystem, m: Dictionary) -> Array:
	var out := []
	var seen_you := false
	for x in ms.thread(str(m.thread)):
		if str(x.moment) != str(m.id):
			continue
		if x.from == "you":
			seen_you = true
		elif seen_you:
			out.append(x)
	return out


## The result card of an answer: what changed, in words with an arrow (data/moments.json `changes`), green for ▲, red for ▼.
static func changes_panel(lines: Array) -> Control:
	var cfg: Dictionary = Data.moments.changes
	var col := UIKit.vbox(2)
	col.add_child(UIKit.label(str(cfg.head), "CaptionLabel"))
	for line in lines:
		var l := UIKit.wrapped(str(line), "")
		if str(cfg.up) in str(line):
			l.add_theme_color_override("font_color", Palette.RISK_LOW)
		elif str(cfg.down) in str(line):
			l.add_theme_color_override("font_color", Palette.RISK_HIGH)
		col.add_child(l)
	return UIKit.alert_panel(col, Palette.BORDER, 10)


## A short text for a list row or the Today card: the first line, cut after `n` characters.
static func preview(text: String, n := 90) -> String:
	var t := text.replace("\n\n", " ").replace("\n", " ").strip_edges()
	return t if t.length() <= n else t.left(n - 1).strip_edges() + "…"
