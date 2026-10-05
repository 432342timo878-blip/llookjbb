extends Control
## Lists save slots: load or delete. Built in code like the career hub content.

var _list: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [["left", 48], ["right", 48], ["top", 32], ["bottom", 24]]:
		margin.add_theme_constant_override("margin_" + side[0], side[1])
	add_child(margin)
	var column := UIKit.vbox(20)
	margin.add_child(column)

	var header := UIKit.hbox(16)
	var title := UIKit.label("Load Career", "TitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := UIKit.button("Main menu")
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(Router.go.bind("main_menu"))
	header.add_child(back)
	column.add_child(header)
	column.add_child(UIKit.wrapped(
			"The autosave is updated every week. Saves you make with the Save button stay exactly as they were, so you can load them again and again."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill()


func _fill() -> void:
	for child in _list.get_children():
		child.queue_free()
	for s in SaveGame.list():
		var row := UIKit.hbox(16)
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(s.summary, "SubheadingLabel"))
		info.add_child(UIKit.label(("Autosave · " if s.auto else "") + "saved " + s.saved_at, "MutedLabel"))
		row.add_child(info)
		var load_button := UIKit.button("Load", true)
		load_button.pressed.connect(func():
			if SaveGame.load_slot(s.slot):
				Router.go("career_hub"))
		row.add_child(load_button)
		var del := UIKit.button("Delete")
		del.pressed.connect(func(): SaveGame.delete(s.slot); _fill())
		row.add_child(del)
		_list.add_child(UIKit.panel(row, 16))
