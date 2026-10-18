class_name CoachProfile
extends VBoxContainer
## A coach's page (GDD 4.9.1 "Shown and scouted"; session C3 for the head coach, session C6 for every coach of the market):
## who the coach is (club, town, qualification, event focus, reputation, cost, how far away and what that would change, the
## training group, a real coach's senior athletes and sources), the character in words (style and what the coach leans to
## once known, the fit and trust with the head coach), the 11 skills as ranges (exact after `scouting.together_weeks` weeks
## together; CoachMarket.range_of) and, for another coach, how to find out more (results, asking around, a visit) and how to
## ask to be coached and start on Monday (two steps). Texts: data/coach_talk.json `profile`, data/market.json `ui`.
## Pronouns come from the record's gender (they / them when unknown).

signal messages_requested   # the head coach's "Messages" button: back to the thread
signal back_requested       # another coach: back to Find a coach
signal changed              # something was done (asked, a visit planned, a change of coach): the hub redraws its marks

var coach_id := ""
var _confirm := false       # "Start on Monday" pressed once: the warning and the confirm button show
var _visit_open := false    # the visit's day picker is open
var _note := ""             # the line of the last scouting step (results / asking around)


func _init(id := "") -> void:
	coach_id = id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_build()


func _build() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	var cs := Game.get_system("coach") as CoachSystem
	var mk := CoachMarket.sys()
	if cs == null:
		return
	var head_id := Game.athlete.coach_id
	var cid := coach_id if coach_id != "" else head_id
	var c: Dictionary = cs.coaches.get(cid, {})
	if c.is_empty():
		return
	var is_head := cid == head_id
	var cfg: Dictionary = Data.coach_talk.profile
	var mui: Dictionary = Data.market.ui
	var voice: Dictionary = Data.coaches.coaches.get(str(c.voice), {})
	var rel: Dictionary = cs.relations.get(cid, {})
	var weeks := int(rel.get("weeks", 0))
	var fill := {"he": CoachSystem.pronoun(c, "he"), "him": CoachSystem.pronoun(c, "him"), "his": CoachSystem.pronoun(c, "his")}

	# Header: who, and the way back.
	var head := UIKit.hbox(12)
	head.add_child(PeopleUI.avatar(str(c.name), 48.0))
	var titles := UIKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.wrapped(str(c.name), "HeadingLabel"))
	var kind_word := str(mui.kinds.get(str(c.kind), cfg.kinds.get(str(c.kind), c.kind)))
	var sub := kind_word if bool(c.get("real", false)) else "%s · %s" % [str(voice.get("title", "")), kind_word]
	titles.add_child(UIKit.wrapped(sub, "MutedLabel"))
	head.add_child(titles)
	add_child(head)
	var back := UIKit.button(PeopleUI.ui("messages_button") if is_head else str(mui.back_market), false, 160)
	back.pressed.connect(func(): (messages_requested if is_head else back_requested).emit())
	add_child(back)

	if mk != null and not mk.pending.is_empty() and (is_head or str(mk.pending.coach) == cid):
		add_child(_pending_panel(mk, cs))

	# What you can do about another coach, on top (the answer, the change, finding out more).
	if not is_head and mk != null:
		if mk.offer_via_parent(cid):
			add_child(_offer_panel(mk, c, cid))
		add_child(_actions(mk, c, fill))

	# About.
	var facts := UIKit.vbox(6)
	facts.add_child(UIKit.label(str(cfg.facts_head), "CaptionLabel"))
	var labels: Dictionary = cfg.labels
	var f: Dictionary = c.facts
	var club := Data.get_club(str(f.get("club_id", "")))
	var qualification := str(f.get("qualification", ""))
	for q in Data.coaching.club.qualifications:
		if q.id == qualification:
			qualification = str(q.name)
	var focus := str(Data.coaching.club.event_focus.get(str(f.get("event_focus", "")), {}).get("name", ""))
	var age_text := str(int(Game.date.year) - int(f.birth_year)) if int(f.get("birth_year", 0)) > 0 else ""
	var rows := [[labels.club, str(club.get("name", ""))], [labels.town, str(f.get("town", ""))], [labels.qualification, qualification],
			[labels.focus, focus], [labels.age, age_text], [labels.reputation, str(Data.market.reputations.get(str(f.get("reputation", "")), ""))]]
	if mk != null:
		var co := mk.cost_of(c)
		rows.append([labels.cost, str(mui.cost[str(co.kind)]).format({"cost": co.cost})])
	if weeks > 0:
		rows.append([labels.together, str(cfg.together).format({"weeks": weeks})])
	for row in rows:
		if str(row[1]) != "":
			facts.add_child(UIKit.fact_row(str(row[0]), _value(str(row[1]))))
	var dist := CoachSystem.distance_of(c, Game.athlete)
	var dist_key := "home" if str(c.kind) == "parent" else ("remote" if str(c.kind) == "remote" else dist)
	facts.add_child(UIKit.wrapped(str(mui.distance[dist_key]).format({"town": str(f.get("town", "")),
			"days": int(Data.market.distance.region.days_with)}.merged(fill)), ""))
	var group: Array = c.get("group", [])
	var m: Dictionary = c.get("market", {})
	if group.is_empty() and int(m.get("group_size", 0)) > 0:
		var gl := float(m.get("group_level", -1.0))
		var mine := CoachSystem.athlete_level(Game.athlete)
		var lvl := "same" if gl < 0.0 or absf(gl - mine) <= 1.0 else ("stronger" if gl > mine else "weaker")
		facts.add_child(UIKit.wrapped(str(mui.group_line).format({"n": int(m.group_size), "level": str(mui.group_level[lvl])}), "MutedLabel"))
	add_child(UIKit.panel(facts, 14))

	# A real coach: the senior athletes and the sources (facts only from those pages).
	if bool(c.get("real", false)):
		var rc := UIKit.vbox(6)
		rc.add_child(UIKit.wrapped(str(mui.real_note), "MutedLabel"))
		var athletes: Array = c.get("athletes_coached", [])
		if not athletes.is_empty():
			rc.add_child(UIKit.label(str(mui.athletes_head), "CaptionLabel"))
			for x in athletes:
				rc.add_child(UIKit.wrapped("· " + str(x), ""))
		rc.add_child(UIKit.label(str(mui.sources_head), "CaptionLabel"))
		for s in c.get("sources", []):
			rc.add_child(UIKit.wrapped(str(mui.source_line).format({"facts": s.get("facts", ""), "url": s.get("url", ""), "read": s.get("read", "")}), "CaptionLabel"))
		add_child(UIKit.panel(rc, 14))

	# Character in words (tap = what it means).
	var character := UIKit.vbox(6)
	character.add_child(UIKit.label(str(cfg.character_head), "CaptionLabel"))
	if str(voice.get("blurb", "")) != "" and not bool(c.get("real", false)):
		character.add_child(UIKit.wrapped(str(voice.blurb), ""))
	var ex: Dictionary = cfg.explain
	var style_word := str(mui.unknown_word)
	var demands_word := str(mui.unknown_word)
	if mk == null or mk.knows(c, "style"):
		for s in Data.coaching.styles:
			if int(s.value) == int(c.style):
				style_word = str(s.word)
	if mk == null or mk.knows(c, "demands"):
		demands_word = str(Data.coaching.demands.get(str(c.demands), ""))
	var char_rows := [[labels.style, style_word, Palette.TEXT, ex.style], [labels.demands, demands_word, Palette.TEXT, ex.demands]]
	if is_head:
		var fit := cs.fit_word()
		var fit_color := Palette.TEXT_MUTED
		if weeks >= int(Data.coaching.fit.reveal_weeks):
			fit_color = {"click": Palette.RISK_LOW, "friction": Palette.RISK_MODERATE}.get(cs.fit(), Palette.TEXT)
		var trust_color: Color = {"strong": Palette.RISK_LOW, "strained": Palette.RISK_HIGH, "new": Palette.TEXT_MUTED}.get(cs.trust_level(), Palette.TEXT)
		char_rows.append([labels.fit, fit, fit_color, ex.fit])
		char_rows.append([labels.trust, cs.trust_word(), trust_color, ex.trust])
	else:
		char_rows.append([labels.fit, str(mui.fit_later), Palette.TEXT_MUTED, ex.fit])
	for row in char_rows:
		character.add_child(UIKit.tap_to_explain(UIKit.fact_row(str(row[0]), _value(str(row[1]), row[2])), str(row[3])))
	add_child(UIKit.panel(character, 14))

	# The skills: ranges until known.
	var attrs := UIKit.vbox(2)
	attrs.add_child(UIKit.label(str(cfg.attributes_head), "CaptionLabel"))
	var exact := true
	for at in Data.coaching.attributes:
		var v := int(c.attributes.get(str(at.id), 10))
		var r: Array = mk.range_of(c, str(at.id)) if mk != null else [v, v]
		var row := UIKit.hbox(8)
		row.custom_minimum_size.y = 34
		var n := UIKit.label(str(at.name))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.clip_text = true
		row.add_child(n)
		if int(r[0]) == int(r[1]):
			row.add_child(UIKit.attr_value_label(v))
		else:
			exact = false
			var l := UIKit.label("%d–%d" % [int(r[0]), int(r[1])], "AttrValueLabel")
			l.add_theme_color_override("font_color", UIKit.attr_color((float(r[0]) + float(r[1])) / 2.0))
			l.custom_minimum_size.x = 56
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
		attrs.add_child(UIKit.tap_to_explain(row, str(at.description)))
	var need := int(Data.market.scouting.together_weeks)
	var note := str(cfg.exact_note).format({"weeks": weeks}) if exact else (str(cfg.range_note).format({"weeks": weeks, "need": need})
			if is_head or weeks > 0 else str(mui.scout_note).format({"weeks": need}))
	attrs.add_child(UIKit.wrapped(note, "CaptionLabel"))
	add_child(UIKit.panel(attrs, 14))

	# The training group (the head coach's people).
	if not group.is_empty() and is_head:
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

	# Your coaches so far (the head coach's page).
	if is_head and mk != null and mk.history.size() > 1:
		var h := UIKit.vbox(4)
		h.add_child(UIKit.label(str(mui.history_head), "CaptionLabel"))
		for e in mk.history:
			var hc: Dictionary = cs.coaches.get(str(e.coach), {})
			h.add_child(UIKit.wrapped(str(mui.history_line).format({"coach": str(hc.get("name", "?")),
					"from": UIKit.format_date(e.from), "to": UIKit.format_date(e.to) if not (e.to as Dictionary).is_empty() else "…"}), ""))
		add_child(UIKit.panel(h, 14))


## "X becomes your coach on Monday", with the way back.
func _pending_panel(mk: CoachMarket, cs: CoachSystem) -> Control:
	var mui: Dictionary = Data.market.ui
	var box := UIKit.vbox(8)
	var newc: Dictionary = cs.coaches.get(str(mk.pending.coach), {})
	box.add_child(UIKit.wrapped(str(mui.pending_line).format({"new": str(newc.get("name", "")), "date": Calendar.format_day(mk.pending.date)}), ""))
	if str(mk.pending.get("why", "")) != "ended":
		var stay := UIKit.button(str(mui.pending_cancel).format({"old": str(cs.head().get("name", ""))}), false, 200)
		stay.pressed.connect(func():
			mk.cancel_pending()
			_build()
			changed.emit())
		box.add_child(stay)
	return UIKit.alert_panel(box, Palette.ACCENT, 12)


## The offer a coach made through a parent (the athlete is under 18, user 2026-10-18): his words and the facts, with "Not now".
func _offer_panel(mk: CoachMarket, c: Dictionary, cid: String) -> Control:
	var mui: Dictionary = Data.market.ui
	var offer: Dictionary = mk.offers[cid]
	var ms := Game.get_system("moments") as StoryletSystem
	var parent := ""
	if ms != null and ms.people.has(str(offer.get("parent", ""))):
		parent = StoryletSystem.short_name(ms.people[str(offer.parent)])
	var fill := {"parent": parent, "coach_first": str(c.name).split(" ")[0]}
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(mui.offer_parent_head if parent != "" else mui.offer_family_head).format(fill), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(offer.get("text", "")), ""))
	box.add_child(UIKit.wrapped(str(mui.offer_parent_note if parent != "" else mui.offer_family_note).format(fill), "CaptionLabel"))
	var no := UIKit.button(str(mui.offer_decline), false, 200)
	no.pressed.connect(func():
		mk.decline_offer(cid)
		_build()
		changed.emit())
	box.add_child(no)
	box.add_child(UIKit.wrapped(str(mui.offer_decline_hint), "CaptionLabel"))
	return UIKit.panel(box, 14)


## The status, the answer, "Start on Monday" (two steps) and finding out more.
func _actions(mk: CoachMarket, c: Dictionary, fill: Dictionary) -> Control:
	var mui: Dictionary = Data.market.ui
	var col := UIKit.vbox(8)
	var st := mk.status(c)
	var st_color: Color = {"ok": Palette.RISK_LOW, "offer": Palette.RISK_LOW, "pending": Palette.ACCENT, "budget": Palette.RISK_HIGH,
			"ended": Palette.RISK_HIGH}.get(str(st.id), Palette.RISK_MODERATE)
	var status_label := UIKit.wrapped(str(st.text), "")
	status_label.add_theme_color_override("font_color", st_color)
	col.add_child(status_label)
	# His answer, when asked.
	var ans: Dictionary = mk.answers.get(str(c.id), {})
	if not ans.is_empty():
		var key := str({"ok": "yes", "offer": "yes", "no_time": "no_time", "not_yet": "not_yet"}.get(str(ans.status), "full"))
		var a_box := UIKit.vbox(4)
		a_box.add_child(UIKit.label(str(mui.ask_head), "CaptionLabel"))
		a_box.add_child(PeopleUI.message(PeopleUI.system(), {"from": str(c.id), "text": mk.line(c, key,
				{"time": Calendar.format_time(CoachMarket.required_time(c))}), "date": Game.date, "read": true}, false))
		col.add_child(a_box)
	if mk.may_start(c) and mk.pending.is_empty():
		if _confirm:
			var old := str((Game.get_system("coach") as CoachSystem).head().get("name", ""))
			col.add_child(UIKit.wrapped(str(mui.start_warn).format({"old": old}), ""))
			var row := HealthUI._button_row()
			var yes := UIKit.button(str(mui.start_confirm), true, 200)
			yes.pressed.connect(func():
				mk.start(c)
				_confirm = false
				_build()
				changed.emit())
			var no := UIKit.button(str(mui.cancel_button), false, 120)
			no.pressed.connect(func():
				_confirm = false
				_build())
			row.add_child(yes)
			row.add_child(no)
			col.add_child(row)
		else:
			var start := UIKit.button(str(mui.start_button), true, 200)
			start.pressed.connect(func():
				_confirm = true
				_build())
			col.add_child(start)
	elif str(st.id) in ["ok", "offer", "not_yet", "full", "no_time"] and mk.pending.is_empty():
		var ask := UIKit.button(str(mui.ask_button), true, 200)
		ask.pressed.connect(func():
			mk.ask(c)
			_build()
			changed.emit())
		col.add_child(ask)
	# Find out more.
	var more := UIKit.vbox(6)
	more.add_child(UIKit.label(str(mui.scout_head), "CaptionLabel"))
	more.add_child(UIKit.label(str(mui.known).format({"word": mk.known_word(c)}), "MutedLabel"))
	if _note != "":
		more.add_child(UIKit.wrapped(_note, ""))
	if mk.done(c, "results"):
		if _note == "":
			more.add_child(UIKit.wrapped(str(mui.results_done), "CaptionLabel"))
	else:
		var b := PeopleUI.reply_button(str(mui.results_button))
		b.pressed.connect(func():
			_note = mk.look_results(c)
			_build())
		more.add_child(b)
	if mk.done(c, "asked"):
		more.add_child(UIKit.wrapped(str(mui.asked_done), "CaptionLabel"))
	else:
		var b := PeopleUI.reply_button(str(mui.asked_button))
		b.pressed.connect(func():
			_note = mk.ask_around(c)
			_build()
			changed.emit())
		more.add_child(b)
		more.add_child(UIKit.wrapped(str(mui.asked_hint), "CaptionLabel"))
	if mk.done(c, "visited"):
		more.add_child(UIKit.wrapped(str(mui.visit_done), "CaptionLabel"))
	elif not mk.visit.is_empty() and str(mk.visit.coach) == str(c.id):
		more.add_child(UIKit.wrapped(str(mui.visit_set).format({"day": Calendar.format_day(mk.visit.date)}), ""))
		var cancel := UIKit.button(str(mui.visit_cancel), false, 180)
		cancel.pressed.connect(func():
			mk.cancel_visit()
			_build()
			changed.emit())
		more.add_child(cancel)
	else:
		var far := CoachSystem.distance_of(c, Game.athlete) != "same"
		var b := PeopleUI.reply_button(str(mui.visit_button))
		b.pressed.connect(func():
			_visit_open = not _visit_open
			_build())
		more.add_child(b)
		more.add_child(UIKit.wrapped(str(mui.visit_hint_far if far else mui.visit_hint_near), "CaptionLabel"))
		if _visit_open:
			more.add_child(UIKit.label(str(mui.visit_pick), "CaptionLabel"))
			var days := GridContainer.new()
			days.columns = 2 if Layout.compact else 4
			days.add_theme_constant_override("h_separation", 6)
			days.add_theme_constant_override("v_separation", 6)
			for d in mk.visit_days():
				var db := UIKit.button(str(d.label), false, 0)
				db.custom_minimum_size = Vector2(0, 44)
				db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				db.pressed.connect(func():
					mk.plan_visit(c, d.date)
					_visit_open = false
					_build()
					changed.emit())
				days.add_child(db)
			more.add_child(days)
	col.add_child(more)
	return UIKit.panel(col, 14)


func _value(text: String, color := Palette.TEXT) -> Label:
	var l := UIKit.wrapped(text, "")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", color)
	return l
