class_name CommentaryBox
extends VBoxContainer
## The COMMENTARY box of a watched race on PC (GDD 4.3.1, step R4): a header with the crew, then a box of fixed height
## with the newest line on top (scrolls for older ones). Every line has a small tag for its voice (COMMENTATOR, EXPERT,
## ANNOUNCER, COACH, YOU, FAN); the coach's lines are in the accent colour. Also makes the rows of the phone's log sheet
## (CommentaryLog) through make_row().

const HEIGHT := 190.0   # (fixed: the right column of a 1280x720 window has room for about this much under the positions)
const KEEP := 60   # rows kept

var _rows: VBoxContainer
var _scroll: ScrollContainer


## `crew`: who is talking ("Olli Vartiainen & Satu Rinne", or "the stadium announcer").
func _init(crew: String) -> void:
	name = "CommentaryBox"
	add_theme_constant_override("separation", 4)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.label("COMMENTARY", "CaptionLabel"))
	var who := UIKit.label(crew, "MutedLabel")
	who.clip_text = true
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = HEIGHT
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = UIKit.vbox(6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	add_child(_scroll)


## A line {voice, text, ...} on top; the oldest rows go when there are more than KEEP.
func add_line(line: Dictionary) -> void:
	var row := make_row(line)
	_rows.add_child(row)
	_rows.move_child(row, 0)
	while _rows.get_child_count() > KEEP:
		var old := _rows.get_child(_rows.get_child_count() - 1)
		_rows.remove_child(old)
		old.queue_free()
	_scroll.scroll_vertical = 0


## The tag (voice label) beside the text; the coach's row in the accent colour.
static func make_row(line: Dictionary) -> Control:
	var voice := str(line.voice)
	var row := UIKit.hbox(6)
	var tag := UIKit.label(tag_text(voice), "CaptionLabel")
	tag.custom_minimum_size.x = 82.0
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var text := UIKit.wrapped(str(line.text), "")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if voice == "coach":
		tag.add_theme_color_override("font_color", Palette.ACCENT)
		text.add_theme_color_override("font_color", Palette.ACCENT)
	elif voice in ["you", "fan"]:
		text.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	row.add_child(tag)
	row.add_child(text)
	return row


static func tag_text(voice: String) -> String:
	return str(Data.race_commentary.voices.get(voice, {}).get("label", voice.to_upper()))
