class_name GoalsUI
extends RefCounted
## The season goals where the player looks at them (GDD 4.9.2 "Season goals with times", session C5): a panel on the Career tab (the
## goals of this season: a mark, what each asks, how it stands; or, with none set, a button to ask the coach for them) and a section
## on the Progress page (this season's goals and a line for each earlier season). Session L3b2: every goal also says what met and
## missed mean (open) or what it opened (met), and a review's change; the button makes the coach's card on This week (GoalsCard).
## Reading only, but for the button. Texts: data/goals.json ui.


## Is there a goals system to show (the app shell switched it on)?
static func available() -> bool:
	return SeasonGoals.enabled and SeasonGoals.sys() != null and Game.athlete != null


## The Overview panel, or null when there is nothing to show: goals that exist are always shown, the button to ask for some only in a
## career on the season plan (the goals belong to it). `on_ask` is called after the offer was posted (the hub then shows it).
static func overview_panel(on_ask: Callable) -> Control:
	if not available():
		return null
	var gs := SeasonGoals.sys()
	var year := gs.current_year()
	if year < Game.season.first_season or (not gs.has_goals(year) and Game.season.mode != SeasonPlan.PHASES):
		return null
	var ui: Dictionary = Data.goals.ui
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(ui.overview_head).format({"season": SeasonGoals.season_label(year)}), "CaptionLabel"))
	if gs.has_goals(year):
		for g in gs.goals_of(year):
			box.add_child(goal_row(gs, g, year))
	elif gs.offers.has(year):   # (session L3b2: the card waits on the planner)
		box.add_child(UIKit.wrapped(str(ui.ask_card)))
		var open := UIKit.button(str(ui.open_card), false, 220)
		open.pressed.connect(func(): on_ask.call())
		box.add_child(open)
	else:
		box.add_child(UIKit.wrapped(str(ui.overview_none)))
		var cs := Game.get_system("coach") as CoachSystem
		var first := str(cs.head().get("name", "")).split(" ")[0] if cs != null else ""
		var ask := UIKit.button(str(ui.overview_ask).format({"coach_first": first}), false, 220)
		ask.pressed.connect(func():
			if gs.offer(year).is_empty():
				return
			on_ask.call())
		box.add_child(ask)
		box.add_child(UIKit.wrapped(str(ui.overview_ask_hint)))
	return UIKit.panel(box, 16)


## One goal: its mark (○ open, ✓ met, ✗ missed), what it asks, and how it stands.
static func goal_row(gs: SeasonGoals, g: Dictionary, year: int) -> Control:
	var ui: Dictionary = Data.goals.ui
	var row := UIKit.hbox(10)
	var mark := UIKit.label(str(ui.marks.get(str(g.status), "–")), "SubheadingLabel")
	mark.custom_minimum_size.x = 24
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	match str(g.status):
		"met":
			mark.add_theme_color_override("font_color", Palette.RISK_LOW)
		"missed":
			mark.add_theme_color_override("font_color", Palette.RISK_HIGH)
		_:
			mark.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	row.add_child(mark)
	var col := UIKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var what := UIKit.wrapped(SeasonGoals.goal_text(g, year), "")
	what.custom_minimum_size.x = 120
	col.add_child(what)
	var note := UIKit.wrapped(gs.progress_text(g, year), "MutedLabel")
	note.custom_minimum_size.x = 120
	col.add_child(note)
	# (session L3b2: what met / missed means where the goal is shown; a met one says what it opened; a review's change)
	var stakes := ""
	match str(g.status):
		"open":
			stakes = SeasonGoals.stakes_text(g)
		"met":
			stakes = SeasonGoals.opened_text(g) if g.has("opened") else ""
	for h in g.get("history", []):
		if str(h.what) == "adjusted" and str(h.was) != "":
			col.add_child(_muted(str(ui.adjusted_from).format({"goal": str(h.was)})))
	if stakes != "":
		col.add_child(_muted(stakes))
	row.add_child(col)
	return row


static func _muted(text: String) -> Label:
	var l := UIKit.wrapped(CoachSystem.words(text), "WhyLabel")
	l.custom_minimum_size.x = 120
	return l


## The Progress page's section: this season's goals in full, an earlier season as one line (and its goals under it).
static func progress_section() -> Control:
	if not available():
		return null
	var gs := SeasonGoals.sys()
	var ui: Dictionary = Data.goals.ui
	var years := gs.seasons.keys().filter(func(y): return gs.has_goals(int(y)))
	if years.is_empty():
		return null
	years.sort()
	years.reverse()
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(ui.progress_head), "CaptionLabel"))
	for y in years:
		var year := int(y)
		var goals: Array = gs.goals_of(year)
		if year == gs.current_year():
			box.add_child(UIKit.label(SeasonGoals.season_label(year), "SubheadingLabel"))
			for g in goals:
				box.add_child(goal_row(gs, g, year))
		else:
			var met := goals.filter(func(g): return str(g.status) == "met").size()
			box.add_child(UIKit.wrapped(str(ui.past_line).format({"season": SeasonGoals.season_label(year), "met": met, "total": goals.size()}), ""))
			for g in goals:
				box.add_child(goal_row(gs, g, year))
	return UIKit.panel(box, 16)
