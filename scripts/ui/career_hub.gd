extends Control
## Career home screen. For now: the athlete profile (Football Manager-style attribute panels).

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	%MenuButton.pressed.connect(Router.go.bind("main_menu"))
	var a := Game.athlete
	var club := Data.get_club(a.club_id)
	%NameLabel.text = a.full_name()
	%InfoLabel.text = "%s · %d years · %s · %s" % [
		Data.get_event(a.main_event).name, a.age_on(Game.date), club.get("name", ""), a.hometown]
	%DateLabel.text = "%d %s %d" % [Game.date.day, MONTHS[Game.date.month - 1], Game.date.year]
	_build_profile(a)


func _build_profile(a: Athlete) -> void:
	var columns := UIKit.hbox(16)
	for category in ["physical", "technical", "mental"]:
		var col := UIKit.vbox(6)
		col.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		for attr in Data.attributes_in(category):
			var row := UIKit.attr_row(attr.name, a.get_attr(attr.id))
			row.tooltip_text = attr.description
			col.add_child(row)
		columns.add_child(_column_panel(col))

	var body := UIKit.vbox(6)
	body.add_child(UIKit.label("BODY", "CaptionLabel"))
	for f in [
		["Height", "%d cm" % a.height_cm],
		["Weight", "%d kg" % a.weight_kg],
		["Development", {"early": "Early", "average": "Average", "late": "Late"}[a.maturation]],
		["Born", UIKit.format_date(a.birth_date)],
	]:
		var row := UIKit.hbox()
		var key := UIKit.label(f[0], "MutedLabel")
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key)
		row.add_child(UIKit.label(f[1]))
		body.add_child(row)
	body.add_child(UIKit.label(" "))
	body.add_child(UIKit.label("PERSONAL BESTS", "CaptionLabel"))
	body.add_child(UIKit.wrapped("No races yet. Your first season starts soon.", "MutedLabel"))
	columns.add_child(_column_panel(body))
	_content.add_child(columns)

	var next := UIKit.wrapped(
			"Next up in development: weekly training, the season calendar and your first 800 m race.",
			"MutedLabel")
	_content.add_child(next)


func _column_panel(content: Control) -> PanelContainer:
	var p := UIKit.panel(content, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return p
