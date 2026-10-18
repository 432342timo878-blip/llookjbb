class_name CoachAsk
extends VBoxContainer
## "Ask the coach" (GDD 4.9.2, session C4): a button that shows the head coach's verdict on a day, a race or a weekly plan
## right there, as a message from him (user 2026-10-11: a card in place; nothing is written into the thread). The verdict is
## CoachVerdict.judge of the change `make_change` builds when the button is pressed: his word (Good idea / Fine / Pointless /
## Risky) and his reason in his voice and detail, what was compared, and a note that his view is only as good as he is. Hide
## goes back to the button. Used by the day editor (day / race), the Training tab (week) and the phase editor (phase).
## Every text in data/coach_talk.json `verdict` (`ask`, `words`, `compare`).

signal toggled   # the button became the card or back (the phone's day sheet re-fits its height)

const COLORS := {"good": Palette.RISK_LOW, "fine": Palette.TEXT_MUTED, "pointless": Palette.RISK_MODERATE, "risky": Palette.RISK_HIGH}

var kind := ""        # "day" / "race" / "week" / "phase": the key of the button's text (verdict.ask)
var _make: Callable
var last := {}        # the verdict shown ({} while the button shows; for the tools)


func _init(ask_kind: String, make_change: Callable) -> void:
	kind = ask_kind
	_make = make_change
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_show_button()


## There is someone to ask: the career has a head coach.
static func available() -> bool:
	return not _head().is_empty()


static func _head() -> Dictionary:
	var cs := Game.get_system("coach") as CoachSystem
	return cs.head() if cs else {}


static func _fill() -> Dictionary:
	var first := str(_head().get("name", "")).split(" ")[0]
	return {"coach_first": first, "COACH": first.to_upper()}


static func texts() -> Dictionary:
	return Data.coach_talk.verdict.ask


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _show_button() -> void:
	_clear()
	last = {}
	var b := UIKit.button(str(texts().get(kind, texts().day)).format(_fill()), false, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(press)
	add_child(b)


## Asks him (the tools call this too).
func press() -> void:
	var change: Dictionary = _make.call()
	last = CoachVerdict.judge(change)
	var cp := Game.get_system("proposals") as CoachProposals
	if cp != null:
		cp.note_asked(change)   # (session F1: no proposal of his on a day you just asked him about)
	_clear()
	add_child(card(last, func():
		_show_button()
		toggled.emit()))
	toggled.emit()


## His answer as a card: a caption, what was compared, his word, his message with his initial, the note, Hide.
static func card(j: Dictionary, on_hide: Callable) -> Control:
	var head := _head()
	var name := str(head.get("name", ""))
	var col := UIKit.vbox(8)
	col.add_child(UIKit.label(str(texts().head).format(_fill()).to_upper(), "CaptionLabel"))
	if str(j.get("compare", "")) != "":
		col.add_child(UIKit.wrapped(str(j.compare), "MutedLabel"))
	var word := UIKit.label(str(j.word), "SubheadingLabel")
	word.add_theme_color_override("font_color", COLORS.get(str(j.verdict), Palette.TEXT))
	col.add_child(word)
	var row := UIKit.hbox(8)
	row.add_child(PeopleUI.avatar(name))
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", ThemeBuilder.card_box(false))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 12)
	var text := UIKit.wrapped(str(j.text), "")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(text)
	bubble.add_child(inner)
	row.add_child(bubble)
	col.add_child(row)
	col.add_child(UIKit.wrapped(str(texts().note), "CaptionLabel"))
	var hide := UIKit.button(str(texts().hide), false, 120)
	hide.size_flags_horizontal = Control.SIZE_SHRINK_END
	hide.pressed.connect(func(): on_hide.call())
	col.add_child(hide)
	return UIKit.alert_panel(col, COLORS.get(str(j.verdict), Palette.BORDER), 12)
