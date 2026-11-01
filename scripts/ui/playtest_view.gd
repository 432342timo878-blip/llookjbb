class_name PlaytestView
extends VBoxContainer
## The Playtest notes page (session K1c; the hub's menu, top right): a structured playtest inside the game. Questions with a few answers
## to tap and a line for a few words (data/playtest.json), a quick-note box for jotting down while playing, and Copy everything / Save as a
## text file to hand the notes over. Everything is saved the moment it changes (PlaytestNotes), stamped with where the game was. It does
## not touch the career. `page` = the hub page the player came from (for the stamp). Help entry: "playtest".

signal back_pressed

var _page := ""
var _notes: PlaytestNotes
var _progress: Label
var _list: VBoxContainer
var _status: Label


func _init(page: String) -> void:
	_page = page
	_notes = PlaytestNotes.open()
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()


static func ui() -> Dictionary:
	return Data.playtest.ui


func _build() -> void:
	var u := ui()
	var top := UIKit.hbox(12)
	var back := UIKit.button(str(u.back), false, 120)
	back.pressed.connect(func(): back_pressed.emit())
	top.add_child(back)
	var title := UIKit.label(str(Data.playtest.title), "CardHeading")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	add_child(top)
	var intro := UIKit.wrapped(str(Data.playtest.intro), "BodyLabel")
	intro.custom_minimum_size.x = 120
	add_child(intro)
	add_child(_switch())
	_progress = UIKit.label("", "ItemLabel")
	add_child(_progress)
	_update_progress()
	add_child(_quick_note())
	for s in Data.playtest.sections:
		var head := UIKit.wrapped(str(s.title), "SectionLabel")   # (a long title wraps instead of widening the page)
		head.custom_minimum_size.x = 120
		add_child(head)
		for q in s.questions:
			add_child(question_box(q, _notes, _page, _update_progress))
	add_child(_export())


func _update_progress() -> void:
	if is_instance_valid(_progress):
		_progress.text = str(ui().progress).format({"n": _notes.answered(), "total": _notes.total()})


## Whether the cards appear on the pages (on by default) and the button that turns them off or on.
func _switch() -> Control:
	var u := ui()
	var box := UIKit.vbox(6)
	var state := UIKit.wrapped(str(u.on if _notes.data.on else u.off), "BodyLabel")
	state.custom_minimum_size.x = 120
	box.add_child(state)
	var b := UIKit.button(str(u.turn_off if _notes.data.on else u.turn_on), false, 0.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		_notes.set_on(not bool(_notes.data.on))
		state.text = str(u.on if _notes.data.on else u.off)
		b.text = str(u.turn_off if _notes.data.on else u.turn_on))
	box.add_child(b)
	return UIKit.panel(box, 14)


# --- The quick note -----------------------------------------------------------------------------------------------------------

func _quick_note() -> Control:
	var u := ui()
	var box := UIKit.vbox(8)
	var hint := UIKit.wrapped(str(u.quick_hint), "WhyLabel")
	hint.custom_minimum_size.x = 120
	box.add_child(hint)
	var edit := TextEdit.new()
	edit.placeholder_text = str(u.quick_placeholder)
	edit.custom_minimum_size = Vector2(0, 84)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(edit)
	var add := UIKit.button(str(u.quick_add), true, 160)
	_list = UIKit.vbox(6)   # (made before the closure that fills it)
	add.pressed.connect(func():
		_notes.add_note(edit.text, _page)
		edit.text = ""
		_fill_notes())
	box.add_child(add)
	box.add_child(_list)
	_fill_notes()
	return CareerView.card(str(u.quick_head), box)


func _fill_notes() -> void:
	for c in _list.get_children():
		c.queue_free()
	var u := ui()
	if _notes.data.notes.is_empty():
		_list.add_child(UIKit.wrapped(str(u.notes_none), "WhyLabel"))
		return
	for i in range(_notes.data.notes.size() - 1, -1, -1):
		var n: Dictionary = _notes.data.notes[i]
		var row := UIKit.hbox(8)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UIKit.wrapped(str(n.text), "BodyLabel")
		t.custom_minimum_size.x = 100
		col.add_child(t)
		var c: Dictionary = n.context
		col.add_child(UIKit.wrapped("%s · %s" % [str(c.get("date", "")), str(c.get("page", ""))], "WhyLabel"))
		row.add_child(col)
		var x := UIKit.button("✕", false, 44)
		x.custom_minimum_size = Vector2(44, 44)
		var index := i
		x.pressed.connect(func():
			_notes.remove_note(index)
			_fill_notes())
		row.add_child(x)
		_list.add_child(row)


# --- A question ------------------------------------------------------------------------------------------------------------------------

## One question as a block (the text, the answers to tap, a line for a few words), saved at once; `on_change` is called after each save.
## Used by this page and by the cards (PlaytestCard).
static func question_box(q: Dictionary, notes: PlaytestNotes, page: String, on_change: Callable, framed := true) -> Control:
	var u := ui()
	var qid := str(q.id)
	var saved := notes.answer_of(qid)
	var box := UIKit.vbox(8)
	var text := UIKit.wrapped(str(q.text), "ItemLabel")
	text.custom_minimum_size.x = 120
	box.add_child(text)
	var state := {"pick": str(saved.get("pick", "")), "note": str(saved.get("note", ""))}
	var save := func():
		notes.set_answer(qid, str(state.pick), str(state.note), page)
		on_change.call()
	if str(q.kind) == "pick":
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		var group := ButtonGroup.new()
		group.allow_unpress = true
		for opt in q.options:
			var b := UIKit.toggle(str(opt), group)
			b.custom_minimum_size = Vector2(0, 44)
			b.button_pressed = str(opt) == str(state.pick)
			var option: String = str(opt)
			b.pressed.connect(func():
				state.pick = option if b.button_pressed else ""
				save.call())
			flow.add_child(b)
		box.add_child(flow)
		var line := LineEdit.new()
		line.placeholder_text = str(q.get("note", u.placeholder_note))
		line.text = str(state.note)
		line.custom_minimum_size = Vector2(0, 44)
		line.text_changed.connect(func(t: String):
			state.note = t
			save.call())
		box.add_child(line)
	else:
		var edit := TextEdit.new()
		edit.placeholder_text = str(u.placeholder_text)
		edit.text = str(state.note)
		edit.custom_minimum_size = Vector2(0, 84)
		edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		edit.text_changed.connect(func():
			state.note = edit.text
			save.call())
		box.add_child(edit)
	return UIKit.panel(box, 14) if framed else box


# --- Handing the notes over ------------------------------------------------------------------------------------------------------------------

func _export() -> Control:
	var u := ui()
	var box := UIKit.vbox(8)
	_status = UIKit.wrapped("", "WhyLabel")
	_status.custom_minimum_size.x = 120
	var copy := UIKit.button(str(u.copy), true, 0.0)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(_notes.to_markdown())
		_status.text = str(u.copied))
	box.add_child(copy)
	var save := UIKit.button(str(u.save), false, 0.0)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func(): _status.text = str(u.saved).format({"path": _notes.save_text()}))
	box.add_child(save)
	var folder := UIKit.button(str(u.folder), false, 0.0)
	folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute(PlaytestNotes.dir())
		OS.shell_open(ProjectSettings.globalize_path(PlaytestNotes.dir())))
	box.add_child(folder)
	box.add_child(_status)
	return UIKit.panel(box, 14)
