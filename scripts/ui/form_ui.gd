class_name FormUI
extends RefCounted
## The race-form pieces of the UI (M2 step 6c, GDD 4.8 "Form"): a row for the Today card (tap = what it means and
## what builds it) and a card for the race day (day editor, race screen). It only reads FormSystem.info();
## with the form model off (FormSystem.enabled, dev tools) system() is null and every piece shows nothing.
## Words, colours and texts are in data/form.json.


## The form system, or null when the form model is off.
static func system() -> FormSystem:
	if not FormSystem.enabled:
		return null
	return Game.get_system("form") as FormSystem


## What the form is right now (the state after the last played day, today's fatigue): FormSystem.info(), or {}.
static func info() -> Dictionary:
	var f := system()
	if f == null:
		return {}
	return f.info(Game.athlete.fatigue)


## "What it means" for the tap text: the word's own text, then what the form is and what builds it.
static func explanation(i: Dictionary) -> String:
	var ui: Dictionary = Data.form.ui
	return "%s\n%s%s" % [i.text, ui.explain, i.helps]


## The Today card row: RACE FORM, the word in its colour, a one-line hint; tap shows the explanation.
## Null when the form model is off.
static func today_row() -> Control:
	var i := info()
	if i.is_empty():
		return null
	var ui: Dictionary = Data.form.ui
	var row := UIKit.flex(6 if Layout.compact else 16)
	row.custom_minimum_size.y = 44
	row.add_child(UIKit.label(ui.title, "CaptionLabel"))
	var word := UIKit.label(i.word, "HeadingLabel")
	word.add_theme_color_override("font_color", i.color)
	row.add_child(word)
	var hint := UIKit.wrapped(ui.today_hint, "MutedLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	return UIKit.tap_to_explain(row, explanation(i))


## The card for a race day that is today: the word, what it means and what builds it, always visible.
## Null when the form model is off.
static func race_card() -> Control:
	var i := info()
	if i.is_empty():
		return null
	var ui: Dictionary = Data.form.ui
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(ui.title, "CaptionLabel"))
	var word := UIKit.label(i.word, "HeadingLabel")
	word.add_theme_color_override("font_color", i.color)
	box.add_child(word)
	box.add_child(UIKit.wrapped(ui.race_hint, "MutedLabel"))
	box.add_child(UIKit.wrapped(i.text, ""))
	box.add_child(UIKit.wrapped(ui.explain + i.helps, "MutedLabel"))
	return UIKit.panel(box, 14)
