class_name CalloutCard
extends PanelContainer
## A callout (GDD 5 "Panels and cards", session L1a): a panel with a 3 px left edge in its meaning colour (WARN = the coach's note,
## PEOPLE = an invitation or a person waiting for an answer, ACCENT = needs you). The only cards with buttons: a title ("Thu: tempo →
## easy run?"), one line with the number and the cost, and its buttons (44 px; the first `primary` one in ACCENT). After an answer
## the card can show what happened instead of its buttons (`show_answer`).
## `buttons`: [{label, primary (bool), id}]; a press emits `chosen(id)`.

signal chosen(id: String)

var edge := Palette.WARN
var _body: VBoxContainer
var _buttons: BoxContainer


func _init(edge_color: Color, icon: String, title: String, text: String, buttons := []) -> void:
	edge = edge_color
	add_theme_stylebox_override("panel", ThemeBuilder.callout_box(edge_color, 12))
	_body = UIKit.vbox(6)
	var head := UIKit.hbox(8)
	if icon != "":
		head.add_child(Icons.rect(icon, 16.0, edge_color))
	var t := UIKit.wrapped(title, "CardHeading")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_body.add_child(head)
	if text != "":
		var line := UIKit.wrapped(text, "WhyLabel")
		line.add_theme_font_size_override("font_size", 16 if Layout.compact else 13)
		_body.add_child(line)
	_buttons = UIKit.hbox(8)
	for b in buttons:
		var button := UIKit.button(str(b.label), bool(b.get("primary", false)), 0.0)
		button.custom_minimum_size = Vector2(0, 44)
		if Layout.compact:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): chosen.emit(str(b.id)))
		_buttons.add_child(button)
	if not buttons.is_empty():
		_body.add_child(_buttons)
	add_child(_body)


## The rows a caller adds under the text (e.g. the veto reasons after "Keep mine").
func add_row(c: Control) -> void:
	_body.add_child(c)


func button_row() -> BoxContainer:
	return _buttons


## Replaces the buttons with one muted line of what happened ("You kept your plan.").
func show_answer(text: String) -> void:
	_buttons.visible = false
	var l := UIKit.wrapped(text, "WhyLabel")
	_body.add_child(l)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 3, size.y), edge)
