class_name HealthEventPanel
extends RefCounted
## The health system's stop events as proper panels (GDD 4.6 "Warning signs & UI"), shown by the career hub in the
## dimmed full-screen decision layer:
##   - diagnosis (event.kind "diagnosis"): a new injury or illness: name, plain explanation, expected time,
##     what's allowed now, racing, and whether it is locked or can be trained through;
##   - "sore" (kind "sore"): an area turned sore for the first time in a while: the sore areas (tap for why and
##     what helps) and the decision keep going / take it easy today / rest day.
## Both use the same look: coloured edge + caption, heading, explanation, facts, 44 px buttons.

const KINDS := ["diagnosis", "sore"]


## Is this one of the health events this class can draw?
static func handles(e: Dictionary) -> bool:
	return e.get("source", "") == "health" and e.get("kind", "") in KINDS and HealthUI.system() != null


## The panel content for event `e`, `width` px wide. `on_answer(choice_id)` is called with the player's answer.
static func build(e: Dictionary, width: float, on_answer: Callable) -> Control:
	if e.kind == "diagnosis":
		return _diagnosis(e, width, on_answer)
	return _sore(e, width, on_answer)


# --- Diagnosis -----------------------------------------------------------------------------------------

static func _diagnosis(e: Dictionary, width: float, on_answer: Callable) -> Control:
	var h := HealthUI.system()
	var x := _find_active(h, e)
	var box := UIKit.vbox(10)
	box.custom_minimum_size.x = width
	if x.is_empty():   # healed again already: just the text
		box.add_child(UIKit.label(Calendar.format_day(e.date).to_upper(), "CaptionLabel"))
		box.add_child(UIKit.wrapped(e.title, "HeadingLabel"))
		box.add_child(UIKit.wrapped(e.text, ""))
		box.add_child(_ok_button(on_answer))
		return box

	var color := HealthUI.tier_color(x.tier)
	var tag := ("IT GOT WORSE" if x.escalated else "DIAGNOSIS") + " · " + Calendar.format_day(e.date).to_upper()
	box.add_child(UIKit.label(tag, "CaptionLabel"))
	var kind := UIKit.label(HealthUI.TIER_NAMES[x.tier] + (" · " + str(x.area_name).to_upper() if x.area_name != "" else ""), "CaptionLabel")
	kind.add_theme_color_override("font_color", color)
	box.add_child(kind)
	box.add_child(UIKit.wrapped(x.name, "HeadingLabel"))
	box.add_child(UIKit.wrapped(x.description, ""))

	var facts := UIKit.vbox(8)
	facts.add_child(_fact("EXPECTED TIME", x.range))
	facts.add_child(_fact("ALLOWED NOW", HealthUI.capitalise(x.allowed)))
	facts.add_child(_fact("RACING", _racing_text(x)))
	facts.add_child(HealthUI.through_line(x))
	box.add_child(UIKit.alert_panel(facts, color))
	box.add_child(UIKit.wrapped("The limits are already in this week's plan. You'll see them in the week strip, and in the day editor you can change what you do.", "MutedLabel"))
	box.add_child(_ok_button(on_answer))
	return box


## The active injury a diagnosis event is about: by the injury id stored on the event. (Events saved before
## the id was stored fall back to the name at the end of the title, "Injury: Shin splints".)
static func _find_active(h: HealthSystem, e: Dictionary) -> Dictionary:
	var title: String = e.title
	var name_part := title.substr(title.find(": ") + 2) if ": " in title else title
	for x in h.active():
		if (e.has("injury") and x.id == e.injury) or (not e.has("injury") and x.name == name_part):
			return x
	return {}


static func _racing_text(x: Dictionary) -> String:
	if x.locked:
		return "You can't race until the lock ends."
	var slow := float(Data.get_injury(x.id).get("race_slowdown", 0.0))
	var text := "You can race, but you'd be slower"
	if slow > 0.0:
		text += " (about %s)" % HealthUI.percent_text(slow)
	return text + ", and it may get worse."


# --- "Sore" warning --------------------------------------------------------------------------------------

static func _sore(e: Dictionary, width: float, on_answer: Callable) -> Control:
	var h := HealthUI.system()
	var box := UIKit.vbox(10)
	box.custom_minimum_size.x = width
	box.add_child(UIKit.label("WARNING · " + Calendar.format_day(e.date).to_upper(), "CaptionLabel"))
	box.add_child(UIKit.wrapped(e.title, "HeadingLabel"))
	box.add_child(UIKit.wrapped(e.text, ""))

	var sore := HealthUI.sore_areas().filter(func(x): return int(x.level) >= HealthSystem.SORE)
	if not sore.is_empty():
		var rows := UIKit.vbox(6)
		rows.add_child(UIKit.label("TAP AN AREA TO SEE WHY, AND WHAT HELPS" if sore.size() > 1 else "WHY, AND WHAT HELPS", "CaptionLabel"))
		for x in sore:
			rows.add_child(HealthUI.soreness_row(h, x, {}, sore.size() == 1))
		box.add_child(rows)

	for c in e.choices:
		var b := UIKit.button(c.label, c.id == "easy", 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): on_answer.call(c.id))
		box.add_child(b)
		if c.get("detail", "") != "":
			box.add_child(UIKit.wrapped(c.detail))
	return box


# --- Pieces ------------------------------------------------------------------------------------------------

static func _fact(caption: String, text: String) -> Control:
	var col := UIKit.vbox(1)
	col.add_child(UIKit.label(caption, "CaptionLabel"))
	col.add_child(UIKit.wrapped(text, ""))
	return col


static func _ok_button(on_answer: Callable) -> Button:
	var b := UIKit.button("OK", true, 200)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): on_answer.call("ok"))
	return b
