class_name MentalPlanUI
extends RefCounted
## The weekly mental plan in the Training tab (GDD 4.9.4, session M1): a 44 px switch for each kind (imagery, relaxation and
## breathing, self-talk: one short session of each a week) with what it does, and the cue word for self-talk (◀ word ▶),
## which the race cards show. Changes MindSystem.plan / cue only. Nothing with the mind model off. Texts: data/mind.json.


static func build() -> Control:
	var ms := MindSystem.sys()
	if ms == null:
		return null
	var u: Dictionary = Data.mind.ui
	var mp: Dictionary = Data.mind.mental_plan
	var box := UIKit.vbox(10)
	var head := UIKit.hbox(8)
	var title := UIKit.label(str(u.plan_head), "CaptionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	box.add_child(head)
	box.add_child(UIKit.wrapped(str(u.plan_text), "MutedLabel"))
	var none := UIKit.wrapped(str(u.plan_off), "MutedLabel")
	none.visible = ms.plan.is_empty()
	var cue_row := _cue_row(ms)
	cue_row.visible = "self_talk" in ms.plan
	for k in mp.kinds:
		var kind: Dictionary = mp.kinds[k]
		var col := UIKit.vbox(2)
		var b := Button.new()
		b.toggle_mode = true
		b.theme_type_variation = "ToggleButton"   # (the accent edge when on, as the other toggles)
		b.text = _label(str(kind.name), k in ms.plan)
		b.custom_minimum_size = Vector2(200, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = k in ms.plan
		b.toggled.connect(func(on: bool):
			ms.toggle_kind(str(k), on)
			b.text = _label(str(kind.name), on)
			none.visible = ms.plan.is_empty()
			cue_row.visible = "self_talk" in ms.plan)
		col.add_child(b)
		col.add_child(UIKit.wrapped(str(kind.text), "MutedLabel"))
		box.add_child(col)
	box.add_child(cue_row)
	box.add_child(none)
	return UIKit.panel(box, 16)


## "✓ Imagery" when the kind is in the plan, else just its name.
static func _label(kind_name: String, on: bool) -> String:
	return ("✓ " + kind_name) if on else kind_name


## "Cue word  ◀ Smooth ▶" (44 px buttons).
static func _cue_row(ms: MindSystem) -> Control:
	var u: Dictionary = Data.mind.ui
	var words: Array = Data.mind.mental_plan.cue_words
	var row := UIKit.hbox(8)
	var l := UIKit.label(str(u.plan_cue), "SubheadingLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var prev := UIKit.button("◀", false, 44)
	prev.custom_minimum_size = Vector2(44, 44)
	var word := UIKit.label(ms.cue if ms.cue != "" else str(Data.mind.mental_plan.default_cue), "HeadingLabel")
	word.custom_minimum_size.x = 110
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var next := UIKit.button("▶", false, 44)
	next.custom_minimum_size = Vector2(44, 44)
	var step := func(d: int):
		var i := words.find(word.text)
		i = (i + d + words.size()) % words.size()
		ms.set_cue(str(words[i]))
		word.text = str(words[i])
	prev.pressed.connect(func(): step.call(-1))
	next.pressed.connect(func(): step.call(1))
	row.add_child(prev)
	row.add_child(word)
	row.add_child(next)
	return row
