class_name CoachProfile
extends VBoxContainer
## The head coach's profile card (GDD 4.9.1 "Shown and scouted", session C3): who he is (club, qualification, event focus,
## weeks together), his character in words (style, what he leans to, how you fit, how much you trust each other), what he is
## good at (his 11 attributes: exact after `profile.exact_weeks` weeks together, before that a range around the value) and
## his training group. Reading only (CoachSystem's record from C1). Texts: data/coach_talk.json `profile`, data/coaching.json.

signal messages_requested   # the "Messages" button: back to the thread


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var cs := Game.get_system("coach") as CoachSystem
	var c: Dictionary = cs.head() if cs else {}
	if c.is_empty():
		return
	var cfg: Dictionary = Data.coach_talk.profile
	var voice: Dictionary = Data.coaches.coaches.get(str(c.voice), {})
	var weeks := int(cs.relation().get("weeks", 0))

	# Header: who he is, and the way back to the messages.
	var head := UIKit.hbox(12)
	head.add_child(PeopleUI.avatar(str(c.name), 48.0))
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.wrapped(str(c.name), "HeadingLabel"))
	titles.add_child(UIKit.wrapped("%s · %s" % [str(voice.get("title", "")), str(cfg.kinds.get(str(c.kind), c.kind))], "MutedLabel"))
	head.add_child(titles)
	add_child(head)
	var back := UIKit.button(PeopleUI.ui("messages_button"), false, 140)
	back.pressed.connect(func(): messages_requested.emit())
	add_child(back)

	# About him.
	var facts := UIKit.vbox(6)
	facts.add_child(UIKit.label(str(cfg.facts_head), "CaptionLabel"))
	var labels: Dictionary = cfg.labels
	var f: Dictionary = c.facts
	var club := Data.get_club(str(f.club_id))
	var qualification := ""
	for q in Data.coaching.club.qualifications:
		if q.id == f.qualification:
			qualification = str(q.name)
	var focus := str(Data.coaching.club.event_focus.get(str(f.event_focus), {}).get("name", ""))
	for row in [[labels.club, str(club.get("name", ""))], [labels.town, str(f.town)], [labels.qualification, qualification],
			[labels.focus, focus], [labels.age, str(int(Game.date.year) - int(f.birth_year))],
			[labels.together, str(cfg.together).format({"weeks": weeks})]]:
		if str(row[1]) != "":
			facts.add_child(UIKit.fact_row(str(row[0]), _value(str(row[1]))))
	add_child(UIKit.panel(facts, 14))

	# Character in words (tap = what it means).
	var character := UIKit.vbox(6)
	character.add_child(UIKit.label(str(cfg.character_head), "CaptionLabel"))
	if str(voice.get("blurb", "")) != "":
		character.add_child(UIKit.wrapped(str(voice.blurb), ""))
	var ex: Dictionary = cfg.explain
	var style_word := ""
	for s in Data.coaching.styles:
		if int(s.value) == int(c.style):
			style_word = str(s.word)
	var fit := cs.fit_word()
	var fit_color := Palette.TEXT_MUTED
	if weeks >= int(Data.coaching.fit.reveal_weeks):
		fit_color = {"click": Palette.RISK_LOW, "friction": Palette.RISK_MODERATE}.get(cs.fit(), Palette.TEXT)
	var trust_color: Color = {"strong": Palette.RISK_LOW, "strained": Palette.RISK_HIGH, "new": Palette.TEXT_MUTED}.get(cs.trust_level(), Palette.TEXT)
	for row in [[labels.style, style_word, Palette.TEXT, ex.style], [labels.demands, str(Data.coaching.demands.get(str(c.demands), "")), Palette.TEXT, ex.demands],
			[labels.fit, fit, fit_color, ex.fit], [labels.trust, cs.trust_word(), trust_color, ex.trust]]:
		character.add_child(UIKit.tap_to_explain(UIKit.fact_row(str(row[0]), _value(str(row[1]), row[2])), str(row[3])))
	add_child(UIKit.panel(character, 14))

	# What he is good at.
	var attrs := UIKit.vbox(2)
	attrs.add_child(UIKit.label(str(cfg.attributes_head), "CaptionLabel"))
	var exact := weeks >= int(cfg.exact_weeks)
	for at in Data.coaching.attributes:
		var v := int(c.attributes.get(str(at.id), 10))
		var row := UIKit.hbox(8)
		row.custom_minimum_size.y = 34
		var n := UIKit.label(str(at.name))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.clip_text = true
		row.add_child(n)
		if exact:
			row.add_child(UIKit.attr_value_label(v))
		else:
			var pad := int(cfg.range_pad)
			var l := UIKit.label("%d–%d" % [maxi(1, v - pad), mini(20, v + pad)], "AttrValueLabel")
			l.add_theme_color_override("font_color", UIKit.attr_color(v))
			l.custom_minimum_size.x = 56
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
		attrs.add_child(UIKit.tap_to_explain(row, str(at.description)))
	attrs.add_child(UIKit.wrapped(str(cfg.exact_note).format({"weeks": int(cfg.exact_weeks)}) if exact
			else str(cfg.range_note).format({"weeks": weeks, "need": int(cfg.exact_weeks)}), "CaptionLabel"))
	add_child(UIKit.panel(attrs, 14))

	# His training group.
	var group: Array = c.get("group", [])
	if not group.is_empty():
		var g := UIKit.vbox(8)
		g.add_child(UIKit.label(str(cfg.group_head), "CaptionLabel"))
		var roles: Dictionary = Data.coaching.club.group.roles
		for t in group:
			var line := UIKit.vbox(0)
			line.add_child(UIKit.label("%s %s" % [t.first_name, t.last_name]))
			var text := str(cfg.group_line).format({"age": int(Game.date.year) - int(t.birth_year),
					"event": str(Data.get_event(str(t.event)).get("name", t.event)),
					"role": str(roles.get(str(t.role), {}).get("word", ""))})
			line.add_child(UIKit.wrapped(text, "MutedLabel"))
			g.add_child(line)
		add_child(UIKit.panel(g, 14))


func _value(text: String, color := Palette.TEXT) -> Label:
	var l := UIKit.wrapped(text, "")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", color)
	return l
