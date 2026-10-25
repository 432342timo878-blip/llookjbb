class_name MentalPlanUI
extends RefCounted
## The weekly mental plan in the Training tab (GDD 4.9.4, session M1): a 44 px switch for each kind (imagery, relaxation and
## breathing, self-talk: one short session of each a week) with what it does. Changes MindSystem.plan only. Nothing with the mind
## model off. Texts: data/mind.json. Session L3a cut the cue word (it did nothing the player could see); L3b turns the mental
## plan into sessions in the week.


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
			none.visible = ms.plan.is_empty())
		col.add_child(b)
		col.add_child(UIKit.wrapped(str(kind.text), "MutedLabel"))
		box.add_child(col)
	box.add_child(none)
	return UIKit.panel(box, 16)


## "✓ Imagery" when the kind is in the plan, else just its name.
static func _label(kind_name: String, on: bool) -> String:
	return ("✓ " + kind_name) if on else kind_name
