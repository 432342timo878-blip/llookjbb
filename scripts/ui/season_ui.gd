class_name SeasonUI
extends RefCounted
## Shared words and numbers of the season-plan UI (GDD 4.8 "UI", M2 step 6e): the week strip caption, phase
## dates and states, the plan cards' weekly load, and the lead-in for a future phase (cached).

const TARGET_MARK := "◆"   # target meets (★ stays "the coach suggests", user decision 2026-10-07)

static var _lead_in_key := ""
static var _lead_in := {}


## The caption above the week strip for this week, or "" in repeat mode:
## "General base · week 3 of 10 · lighter week", "Taper: Nuorten SM 14-15 in 9 days".
static func week_caption() -> String:
	var s := Game.season
	var w := s.return_week_on(Game.date)
	if w > 0:   # easing back in (both modes): "Easing back in · week 1 of 3"
		return str(Data.periodization.return_block.ui.caption).format({"week": w, "weeks": s.return_weeks()})
	if s.mode != SeasonPlan.PHASES:
		return ""
	var plan := s.week_for(Game.week_monday())
	if plan.kind == "return":   # the block starts later this week, or ended earlier in it: today is the phase's
		plan = plan.duplicate()
		plan.kind = "normal"
	if plan.kind == "taper" and plan.target != "":
		var meet := Calendar.get_meet(plan.target)
		var days := Calendar.days_between(Game.date, meet.date)
		if days > 0:
			return "Taper: %s in %d day%s" % [meet.name, days, "" if days == 1 else "s"]
		if days == 0:
			return "Race day: %s" % meet.name
	return week_text(plan)


## "General base · week 3 of 10 · lighter week" for a week_for() result (or a saved report's `plan`).
static func week_text(plan: Dictionary) -> String:
	if str(plan.get("kind", "")) == "return":
		return str(Data.periodization.return_block.ui.caption).format({"week": int(plan.return_week),
				"weeks": int(plan.return_weeks)})
	var text :="%s · week %d of %d" % [SeasonPlan.phase_type(plan.phase).get("name", plan.phase),
			int(plan.phase_week), int(plan.phase_weeks)]
	match str(plan.kind):
		"lighter": text += " · lighter week"
		"taper": text += " · taper" + (" for " + Calendar.get_meet(plan.target).get("name", "") if plan.get("target", "") != "" else "")
	return text


## Easing back in (GDD 4.8 "Return block"): one row per week of a block that starts on `start`, "Week 1 · 22–28 Mar"
## with what it means; weeks before `today` dimmed.
static func return_rows(start: Dictionary, kinds: Array, today := {}) -> Control:
	var cfg: Dictionary = Data.periodization.return_block
	var rows := UIKit.vbox(6)
	for w in kinds.size():
		var first := Game.add_days(start, 7 * w)
		var last := Game.add_days(first, 6)
		var col := UIKit.vbox(1)
		col.add_child(UIKit.label(str(cfg.ui.week_row).format({"week": w + 1, "dates": range_text(first, last)}).to_upper(), "CaptionLabel"))
		col.add_child(UIKit.wrapped(str(cfg.kinds[kinds[w]].text) + ".", ""))
		if not today.is_empty() and Calendar.date_key(last) < Calendar.date_key(today):
			col.modulate.a = 0.5
		rows.add_child(col)
	return rows


## The Training tab's box while easing back in (running or starting tomorrow), with "Stop easing back in…" (asks once
## more); null when there is none. `on_changed` after the player stopped it.
static func return_box(on_changed: Callable) -> Control:
	var s := Game.season
	if not s.return_ahead(Game.date):
		return null
	var ui: Dictionary = Data.periodization.return_block.ui
	var box := UIKit.vbox(10)
	var w := s.return_week_on(Game.date)
	box.add_child(UIKit.label(str(ui.box_caption).format({"week": w, "weeks": s.return_weeks()}) if w > 0
			else str(ui.box_coming).format({"date": Calendar.format_day(s.return_block.start).to_upper()}), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(ui.box_text).format({"days": int(s.return_block.days_out)}), ""))
	var kinds: Array = s.return_block.kinds
	var weeks := kinds.size()
	if s.return_block.has("end"):
		weeks = mini(weeks, Calendar.days_between(s.return_block.start, s.return_block.end) / 7 + 1)
	box.add_child(return_rows(s.return_block.start, kinds.slice(0, weeks), Game.date))
	box.add_child(return_stop_control(on_changed))
	return UIKit.alert_panel(box, Palette.ACCENT, 14)


## "Stop easing back in…": a warning first, then SeasonPlan.stop_return from today and `on_changed`.
static func return_stop_control(on_changed: Callable) -> Control:
	var ui: Dictionary = Data.periodization.return_block.ui
	var box := UIKit.vbox(8)
	var start := UIKit.button(str(ui.stop), false, 220)
	if Layout.stacked():
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ask := UIKit.vbox(8)
	ask.visible = false
	ask.add_child(UIKit.wrapped(str(ui.stop_ask), ""))
	var row := HealthUI._button_row()
	var yes := UIKit.button(str(ui.stop_yes), false, 140)
	var no := UIKit.button(str(ui.stop_no), true, 200)
	row.add_child(yes)
	row.add_child(no)
	ask.add_child(row)
	start.pressed.connect(func():
		start.visible = false
		ask.visible = true)
	no.pressed.connect(func():
		ask.visible = false
		start.visible = true)
	yes.pressed.connect(func():
		Game.season.stop_return(Game.date)
		Game.current_week()
		HealthUI.refresh()
		on_changed.call())
	box.add_child(start)
	box.add_child(ask)
	return box


## The season shown in the Training tab (the one this week belongs to).
static func current_year() -> int:
	return Game.season.plan_year(Game.week_monday())


## "2 Nov – 10 Jan" (the year only when the two differ from the season's own).
static func range_text(first: Dictionary, last: Dictionary) -> String:
	return "%d %s – %d %s" % [first.day, Calendar.MONTHS_SHORT[int(first.month) - 1], last.day,
			Calendar.MONTHS_SHORT[int(last.month) - 1]]


## "past" / "now" / "future" for a phase of phase_dates().
static func phase_state(p: Dictionary) -> String:
	var today := Calendar.date_key(Game.date)
	if Calendar.date_key(p.last) < today:
		return "past"
	return "now" if Calendar.date_key(p.first) <= today else "future"


## The week of a phase today is in (1-based), or 0.
static func phase_week_now(p: Dictionary) -> int:
	if phase_state(p) != "now":
		return 0
	return Calendar.days_between(p.first, Calendar.monday_of(Game.date)) / 7 + 1


## Average planned weekly load of one of the coach's plans over a season: each phase's week (session load ×
## intensity) weighted by its weeks in the season's current layout. No ramp, lighter weeks or taper.
static func variant_load(a: Athlete, variant_id: String, year: int) -> float:
	var templates: Dictionary = Data.periodization.variants[variant_id].templates
	var total := 0.0
	var weeks := 0
	for p in Game.season.layout(year):
		var plan: Dictionary = templates[p.id]
		var week_load := 0.0
		for d in 7:
			var mult := float(Training.intensity(plan.intensity[d]).load)
			for sid in plan.days[d]:
				week_load += Training.session_load(a, Data.get_session(sid)) * mult
		total += week_load * int(p.weeks)
		weeks += int(p.weeks)
	return total / maxf(1.0, weeks)


## The lead-in to a future phase that starts on `first` (HealthSystem.projected), cached until the season plan,
## the entries or the date change (edits of the phase itself don't change what comes before it).
static func lead_in(year: int, phase_id: String, first: Dictionary) -> Dictionary:
	var h := HealthUI.system()
	if h == null:
		return {}
	var plan := Game.season.to_dict()
	var records: Dictionary = plan.seasons.duplicate()
	var key_year := str(year)
	if records.has(key_year):
		var rec: Dictionary = records[key_year].duplicate(true)
		rec.phases.erase(phase_id)
		records[key_year] = rec
	plan.seasons = records
	var key := JSON.stringify([plan, Game.entries, Game.date, first, h.day_no])
	if key != _lead_in_key:
		_lead_in = h.projected(first)
		_lead_in_key = key
	return _lead_in
