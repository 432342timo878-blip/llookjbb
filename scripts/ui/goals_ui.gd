class_name GoalsUI
extends RefCounted
## The season goals where the player looks at them (GDD 4.9.2 "Season goals with times", session C5): a panel on the Overview (the
## goals of this season: a mark, what each asks, how it stands; or, with none set, a button to ask the coach for them) and a section
## on the Progress page (this season's goals and a line for each earlier season). Reading only, but for the button, which asks
## SeasonGoals to post the offer. Texts: data/goals.json ui.


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
	var mark := UIKit.label(str(ui.marks[str(g.status)]), "SubheadingLabel")
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
	row.add_child(col)
	return row


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
