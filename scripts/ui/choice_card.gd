class_name ChoiceCard
extends PanelContainer
## A selectable option with a title and a wrapping description (character creation answers, race plans).
## Works like a toggle button in a ButtonGroup; `button` is the invisible button laid over the card,
## so use `card.button.pressed` / `card.selected`.

var button: Button

var selected: bool:
	get:
		return button.button_pressed
	set(value):
		button.button_pressed = value


func _init(title: String, detail: String, group: ButtonGroup) -> void:
	add_theme_stylebox_override("panel", ThemeBuilder.card_box(false))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	var column := UIKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_label := UIKit.label(title, "SubheadingLabel")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)
	if detail != "":
		column.add_child(UIKit.wrapped(detail))
	margin.add_child(column)
	add_child(margin)

	button = Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = "CardOverlay"
	button.toggled.connect(func(on: bool):
		add_theme_stylebox_override("panel", ThemeBuilder.card_box(on)))
	add_child(button)
	custom_minimum_size.y = 52
