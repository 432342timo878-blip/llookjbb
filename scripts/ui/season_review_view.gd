class_name SeasonReviewView
extends VBoxContainer
## The season review chapter (GDD 4.10 decision 10, session K1b): one reading page for a season that has ended, from CareerSystem.reviews
## (SeasonReview.build): the season in numbers, what grew, the goals met and missed with what they opened, the season list, the best race
## (its card opens), the coach's verdict, what changed in your life, and on to the next season (its targets; the goals card and the
## plan are on This week). Reading only. Texts: data/season_review.json `ui`. Opened from the planner's strap or Career -> Seasons.

signal back_pressed
signal card_pressed(id: String)
signal week_pressed

var _year := 0


func _init(year: int) -> void:
	_year = year
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()


static func ui() -> Dictionary:
	return Data.season_review.ui


func _build() -> void:
	var u := ui()
	var cs := CareerSystem.sys()
	var r: Dictionary = cs.reviews.get(_year, {}) if cs != null else {}
	var top := UIKit.hbox(12)
	var back := UIKit.button(str(u.back), false, 120)
	back.pressed.connect(func(): back_pressed.emit())
	top.add_child(back)
	var title := UIKit.label(str(u.page_title).format({"season": str(r.get("label", ""))}), "CardHeading")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	add_child(top)
	if r.is_empty():
		add_child(UIKit.wrapped("No review for this season."))
		return
	var playtest := PlaytestCard.build("review")   # (session K1c: the playtest's questions about this page, while it is on)
	if playtest != null:
		add_child(playtest)
	add_child(_numbers(r))
	var verdict := _verdict(r)
	add_child(verdict)
	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_goals(r))
	left.add_child(_attrs(r))
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_best_race(r))
	right.add_child(_ranks(r))
	right.add_child(_life(r))
	if Layout.compact:
		add_child(left)
		add_child(right)
	else:
		var row := UIKit.hbox(12)
		row.add_child(left)
		row.add_child(right)
		add_child(row)
	add_child(_next(r))


static func _tile(value: String, label: String, sub := "") -> Control:
	var box := UIKit.vbox(0)
	box.custom_minimum_size.x = 96
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(UIKit.label(value, "BigNumber"))
	var l := UIKit.wrapped(label, "ItemLabel")
	l.custom_minimum_size.x = 80
	box.add_child(l)
	if sub != "":
		var s := UIKit.wrapped(sub, "WhyLabel")
		s.custom_minimum_size.x = 80
		box.add_child(s)
	return box


func _numbers(r: Dictionary) -> Control:
	var u := ui()
	var n: Dictionary = r.numbers
	var nu: Dictionary = u.numbers
	var grid := GridContainer.new()
	grid.columns = 2 if Layout.compact else 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_tile(str(int(n.races)), str(nu.races), "%d %s" % [int(n.pbs), str(nu.pbs).to_lower()]))
	var best := Calendar.format_time(float(n.best)) if float(n.best) > 0.0 else "–"
	var best_sub := str(u.best_line).format({"from": Calendar.format_time(float(n.best_before)), "to": best}) if float(n.best_before) > 0.0 and float(n.best) > 0.0 else ""
	grid.add_child(_tile(best, str(nu.best), best_sub))
	grid.add_child(_tile("%d · %d" % [int(n.wins), int(n.medals)], "%s · %s" % [str(nu.wins), str(nu.medals).to_lower()],
			"%d × %s" % [int(n.scoring), str(nu.scoring).to_lower()] if int(n.scoring) > 0 else ""))
	grid.add_child(_tile(str(n.name1), str(nu.name), ("from %s" % str(n.name0)) if str(n.name0) != str(n.name1) else ""))
	if not n.sessions.is_empty():
		grid.add_child(_tile("%d / %d" % [int(n.sessions.done), int(n.sessions.planned)], str(nu.sessions)))
	if int(n.injured) > 0:
		grid.add_child(_tile(str(int(n.injured)), str(nu.injury)))
	return CareerView.card(str(u.numbers_head), grid)


func _verdict(r: Dictionary) -> Control:
	var box := UIKit.vbox(6)
	var l := UIKit.wrapped(str(r.verdict), "BodyLabel")
	l.custom_minimum_size.x = 120
	box.add_child(l)
	var cs := Game.get_system("coach") as CoachSystem
	var name := str(cs.head().get("name", "")) if cs != null else ""
	if name != "":
		box.add_child(UIKit.label("— " + name, "WhyLabel"))
	return CareerView.card(str(ui().verdict_head), box)


func _goals(r: Dictionary) -> Control:
	var u := ui()
	var box := UIKit.vbox(8)
	var goals: Array = r.goals
	if goals.is_empty():
		box.add_child(UIKit.wrapped(str(u.goals_none)))
		return CareerView.card(str(u.goals_head), box)
	box.add_child(UIKit.label(str(u.goals_count).format({"met": int(r.met), "total": goals.size()}), "ItemLabel"))
	for g in goals:
		var key: String = {"met": "goal_met", "missed": "goal_missed", "dropped": "goal_dropped"}.get(str(g.status), "goal_open")
		var t := UIKit.wrapped(str(u[key]).format({"goal": str(g.text)}), "BodyLabel")
		t.custom_minimum_size.x = 120
		if str(g.status) == "met":
			t.add_theme_color_override("font_color", Palette.GOOD)
		elif str(g.status) == "missed":
			t.add_theme_color_override("font_color", Palette.BAD)
		box.add_child(t)
		var why := str(g.opened) if str(g.status) == "met" else str(g.get("detail", ""))
		if why != "":
			var w := UIKit.wrapped(why, "WhyLabel")
			w.custom_minimum_size.x = 120
			box.add_child(w)
	return CareerView.card(str(u.goals_head), box)


func _attrs(r: Dictionary) -> Control:
	var u := ui()
	var box := UIKit.vbox(4)
	if r.attrs.is_empty():
		box.add_child(UIKit.wrapped(str(u.attrs_none)))
	for c in r.attrs:
		var row := UIKit.hbox(8)
		var n := UIKit.label(str(c.name), "BodyLabel")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var v := UIKit.label(("+%.1f" if float(c.change) >= 0.0 else "%.1f") % float(c.change), "ItemLabel")
		v.add_theme_color_override("font_color", Palette.GOOD if float(c.change) >= 0.0 else Palette.BAD)
		row.add_child(v)
		box.add_child(row)
	return CareerView.card(str(u.attrs_head), box)


func _best_race(r: Dictionary) -> Control:
	var u := ui()
	var box := UIKit.vbox(6)
	var b: Dictionary = r.best_race
	if b.is_empty():
		box.add_child(UIKit.wrapped(str(u.best_race_none)))
		return CareerView.card(str(u.best_race_head), box)
	var name := UIKit.wrapped(str(b.meet), "CardHeading")
	name.custom_minimum_size.x = 120
	box.add_child(name)
	box.add_child(UIKit.wrapped("%s · %s" % [Calendar.format_day(b.date), str(b.text)], "BodyLabel"))
	box.add_child(UIKit.wrapped(str(u.best_race_why).format({"points": "%.1f" % float(b.points)}), "WhyLabel"))
	if not Game.card(str(b.card)).is_empty():
		var open := UIKit.button(str(u.best_race_open), false, 0.0)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.pressed.connect(func(): card_pressed.emit(str(b.card)))
		box.add_child(open)
	return CareerView.card(str(u.best_race_head), box)


func _ranks(r: Dictionary) -> Control:
	var u := ui()
	var box := UIKit.vbox(4)
	if r.rank.is_empty():
		box.add_child(UIKit.wrapped(str(u.rank_none)))
	var rows: Array = r.rank.duplicate()
	rows.reverse()
	for row in rows:
		box.add_child(UIKit.wrapped(str(u.rank_line).format({"label": str(row.label), "rank": Race._ordinal(int(row.rank)), "of": int(row.of),
				"time": Calendar.format_time(float(row.time))}), "BodyLabel"))
	return CareerView.card(str(u.rank_head), box)


func _life(r: Dictionary) -> Control:
	var u := ui()
	var box := UIKit.vbox(8)
	var any := false
	for m in r.life:
		any = true
		var row := UIKit.hbox(10)
		var icon := Icons.rect(str(m.icon), 18.0, Palette.TEXT_MUTED)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UIKit.wrapped(str(m.title), "ItemLabel")
		t.custom_minimum_size.x = 100
		col.add_child(t)
		if str(m.text) != "":
			var s := UIKit.wrapped(str(m.text), "WhyLabel")
			s.custom_minimum_size.x = 100
			col.add_child(s)
		row.add_child(col)
		box.add_child(row)
	if float(r.school_avg) > 0.0:
		any = true
		box.add_child(UIKit.wrapped(str(u.life_school).format({"avg": "%.2f" % float(r.school_avg)}), "BodyLabel"))
	if not any:
		box.add_child(UIKit.wrapped(str(u.life_none)))
	return CareerView.card(str(u.life_head), box)


func _next(r: Dictionary) -> Control:
	var u := ui()
	var box := UIKit.vbox(8)
	var t := UIKit.wrapped(str(u.next_targets).format({"targets": str(r.next.targets)}), "BodyLabel")
	t.custom_minimum_size.x = 120
	box.add_child(t)
	var g := UIKit.wrapped(str(u.next_goals), "WhyLabel")
	g.custom_minimum_size.x = 120
	box.add_child(g)
	var go := UIKit.button(str(u.next_button), true, 0.0)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): week_pressed.emit())
	box.add_child(go)
	return CareerView.card(str(u.next_head).format({"season": str(r.next.label)}), box)
