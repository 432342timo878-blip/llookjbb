class_name StatBar
extends VBoxContainer
## A state as a bar (GDD 5 "Numbers, bars and warnings", session L1a): the name on the left and the big number right-aligned
## above a 7 px track (BAR_TRACK, radius 4), the fill coloured by band (below the warning line - 15: GOOD; up to the line: WARN; at
## or over it: BAD), a 2 px light tick at the warning line, and one why line under it ("Near the line · warning at 70 % · hard
## Tue"). With a `detail`, a tap on the bar shows it underneath (the exact factors; no hover).

var title := ""
var value := 0.0          # 0-100 (the bar's scale)
var warning := -1.0       # the warning line on the same scale (-1 = none: the fill is GOOD)
var value_text := ""      # the big number ("62 %"); "" = the value as a whole percent
var why := ""
var compact_head := false # the phone's body strip: the name above the number, no why line

var _track: Control


func _init(bar_title := "", bar_value := 0.0, warning_line := -1.0, why_line := "", text := "") -> void:
	title = bar_title
	value = bar_value
	warning = warning_line
	why = why_line
	value_text = text
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var number := UIKit.label(value_text if value_text != "" else "%d %%" % roundi(value), "BigNumber")
	number.add_theme_color_override("font_color", Palette.TEXT)
	if compact_head:
		var name_label := UIKit.label(title, "WhyLabel")
		add_child(name_label)
		add_child(number)
	else:
		var head := UIKit.hbox(8)
		var name_label := UIKit.label(title, "ItemLabel")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(name_label)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(number)
		add_child(head)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 7)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	add_child(_track)
	if why != "" and not compact_head:
		add_child(UIKit.wrapped(why, "WhyLabel"))


## The fill colour: three bands against the warning line (GOOD without one).
func fill_color() -> Color:
	if warning < 0.0:
		return Palette.GOOD
	return Palette.band(value, warning)


func _draw_track() -> void:
	var w := _track.size.x
	var h := _track.size.y
	var back := StyleBoxFlat.new()
	back.bg_color = Palette.BAR_TRACK
	back.set_corner_radius_all(4)
	_track.draw_style_box(back, Rect2(0, 0, w, h))
	var share := clampf(value / 100.0, 0.0, 1.0)
	if share > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = fill_color()
		fill.set_corner_radius_all(4)
		_track.draw_style_box(fill, Rect2(0, 0, maxf(w * share, h), h))
	if warning >= 0.0:
		var x := w * clampf(warning / 100.0, 0.0, 1.0)
		_track.draw_rect(Rect2(x - 1.0, -2.0, 2.0, h + 4.0), Palette.TEXT)
