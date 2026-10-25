class_name MindUI
extends RefCounted
## The moods where the player sees them (GDD 4.9.4 / 4.9.7, session M1): the Overview's MIND panel (three rows, each a word in
## its colour with an arrow since last week; tap a row = what it does now, the recent news that moved it, what pulls it, what
## helps), the confidence line on the race-day card, and the cue word on the race cards. Reading only. With the mind model off
## (MindSystem.model_enabled) every piece shows nothing. Texts: data/mind.json ui / causes / pulls.

## Which rows are open (mood -> bool), kept while the hub redraws.
static var open := {}


static func system() -> MindSystem:
	return MindSystem.sys()


static func ui() -> Dictionary:
	return Data.mind.ui


## The Overview panel, or null with the model off.
static func overview_panel() -> Control:
	var ms := system()
	if ms == null or Game.athlete == null:
		return null
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(ui().head), "CaptionLabel"))
	for m in MindSystem.MOODS:
		box.add_child(mood_row(ms, m))
	box.add_child(UIKit.wrapped(str(ui().hint), "MutedLabel"))
	return UIKit.panel(box, 16)


## One mood: a dot, its name, the arrow and the word; tap for the detail.
static func mood_row(ms: MindSystem, mood: String) -> Control:
	var w := ms.word(mood)
	var color: Color = w.color
	var head := UIKit.hbox(8)
	head.add_child(UIKit.dot(color, 12))
	var name_label := UIKit.label(str(Data.mind.moods[mood].name), "SubheadingLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	head.add_child(name_label)
	var arrow := ms.arrow(mood)
	if arrow != 0:
		var a := UIKit.label(str(ui().arrow_up if arrow > 0 else ui().arrow_down))
		# (an arrow is good or bad by the mood: stress going up is bad)
		var good := arrow > 0 if mood != "stress" else arrow < 0
		a.add_theme_color_override("font_color", Palette.ATTR_EXCELLENT if good else Palette.ATTR_POOR)
		head.add_child(a)
	var word := UIKit.label(str(w.name))
	word.add_theme_color_override("font_color", color)
	head.add_child(word)
	return HealthUI.expandable(head, null, detail(ms, mood), color, bool(open.get(mood, false)),
			func(is_open): open[mood] = is_open)


## What the mood does now, what moved it lately, what pulls it, what helps (and, for motivation, the ambition hint).
static func detail(ms: MindSystem, mood: String) -> Control:
	var u := ui()
	var box := UIKit.vbox(4)
	var eff: Dictionary = u.effects[mood]
	var s := ms.side(mood)
	var effect_text := str(eff.get(s, eff.get("low", "")))
	if mood == "stress":
		effect_text = str(eff.low) if s == "middle" else str(eff.high)
	box.add_child(UIKit.wrapped(effect_text, ""))
	box.add_child(UIKit.label(str(u.recent), "CaptionLabel"))
	var recent := ms.recent(mood)
	if recent.is_empty():
		box.add_child(UIKit.wrapped(str(u.no_causes), "MutedLabel"))
	for c in recent:
		box.add_child(UIKit.wrapped("%s  %s %s" % [_short_date(c.date), str(c.text), _mark(float(c.delta), mood)], ""))
	box.add_child(UIKit.label(str(u.pulls), "CaptionLabel"))
	var pulls := ms.pulls(mood, Game.current_week())
	if pulls.is_empty():
		box.add_child(UIKit.wrapped(str(u.no_pulls), "MutedLabel"))
	for p in pulls:
		box.add_child(UIKit.wrapped("• %s %s" % [str(p.text), _mark(float(p.delta), mood)], ""))
	box.add_child(UIKit.label(str(u.helps), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.helps_text[mood]), ""))
	if mood == "motivation":
		var amb := ambition_line()
		if amb != "":
			box.add_child(UIKit.wrapped(amb, "MutedLabel"))
	return box


## "You dream big" / "You're content" / "" from the hidden ambition.
static func ambition_line() -> String:
	if Game.athlete == null:
		return ""
	var v := Game.athlete.get_attr("ambition")
	var u := ui()
	if v >= float(u.ambition_high_from):
		return str(u.ambition_high)
	if v < float(u.ambition_low_below):
		return str(u.ambition_low)
	return ""


static func _mark(delta: float, _mood: String) -> String:
	return str(ui().arrow_up if delta > 0.0 else ui().arrow_down)


static func _short_date(d: Dictionary) -> String:
	return "%d.%d." % [int(d.day), int(d.month)]


## The race-day card's confidence line for a meet, or null when confidence does nothing there (the middle word, model off).
static func race_line(meet: Dictionary) -> Control:
	var ms := system()
	if ms == null or meet.is_empty():
		return null
	var t := ms.race_term(meet)
	if t == 0.0:
		return null
	var w := ms.word("confidence")
	# (session F1, playtest 2: "Confidence confident" read as one glued phrase; now the mood, its word, then the effect)
	var l := UIKit.wrapped(race_text(str(w.name), t), "")
	l.add_theme_color_override("font_color", w.color)
	return l


## The confidence line's text: "Confidence: Confident. You race a little faster at a meet like this." (`term` > 0 = faster).
static func race_text(word_name: String, term: float) -> String:
	return str(ui().race_line).format({"word": word_name, "effect": str(ui().race_faster if term > 0.0 else ui().race_slower)})
