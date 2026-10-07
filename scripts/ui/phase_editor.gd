class_name PhaseEditor
extends VBoxContainer
## One phase of the season plan (GDD 4.8 "UI", M2 step 6e), opened by tapping it in the Training tab; it fills
## the tab on PC and phone alike (user decision 2026-10-07) with "◀ Season plan" to go back. It edits the phase's
## week (sessions + Easy / Normal / Hard per day), lighter weeks on/off, the ramp ("easing in") weeks, the phase's
## edges (◀ ▶ by a week) and "Back to coach's", and shows the plan summary with the body strain: for the phase
## running now from today's body, for a future phase after the lead-in (HealthSystem.projected via SeasonUI.lead_in).
## A phase that is over is shown read-only.
## Day edits emit `plan_changed` (the hub puts the plan into this week and redraws the strip; the summary here
## follows); edges, lighter weeks, ramp and "Back to coach's" emit `rebuild` (the hub rebuilds the tab).

signal back_pressed
signal plan_changed
signal rebuild

const MAX_RAMP := 4

static var note := ""   # a message for the next build ("Can't move it further…")

var year := 0
var phase_id := ""
var _summary: VBoxContainer
var _p := {}


func _init(season_year: int, id: String) -> void:
	year = season_year
	phase_id = id
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	var back := UIKit.button("◀  Season plan", false, 190)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
	for p in Game.season.phase_dates(year):
		if p.id == phase_id:
			_p = p
	if _p.is_empty():   # e.g. its target was removed and the phase left out
		add_child(UIKit.wrapped("This phase is not in your season plan any more.", ""))
		return
	var s := Game.season
	var type := SeasonPlan.phase_type(phase_id)
	var state := SeasonUI.phase_state(_p)

	var head := UIKit.hbox(10)
	head.add_child(UIKit.dot(Color(str(type.get("color", "#888888"))), 16))
	head.add_child(UIKit.label(type.get("name", phase_id), "HeadingLabel"))
	add_child(head)
	var when := "%s %d · %d week%s" % [SeasonUI.range_text(_p.first, _p.last), int(_p.last.year), _p.weeks, "" if _p.weeks == 1 else "s"]
	match state:
		"now": when += " · now: week %d" % SeasonUI.phase_week_now(_p)
		"past": when += " · over"
		"future":
			var weeks := Calendar.days_between(Game.week_monday(), _p.first) / 7
			when += " · starts in %d week%s" % [weeks, "" if weeks == 1 else "s"]
	add_child(UIKit.wrapped(when, "SubheadingLabel"))
	add_child(UIKit.wrapped(str(type.get("text", ""))))

	if state == "past":
		var col := UIKit.vbox(8)
		col.add_child(UIKit.label("THE PHASE'S WEEK", "CaptionLabel"))
		col.add_child(PlanUI.days_list(Game.season.edit_phase(year, phase_id) if s.is_edited(year, phase_id) else _coach_week()))
		col.add_child(UIKit.wrapped("This phase is over, so it can't be changed any more.", ""))
		add_child(UIKit.panel(col, 16))
		return

	if s.is_edited(year, phase_id):
		add_child(_reset_box())
	if note != "":
		add_child(UIKit.alert_panel(UIKit.wrapped(note, ""), Palette.RISK_MODERATE))
		note = ""
	add_child(_week_box())
	add_child(_rules_box())
	add_child(_edges_box())
	_summary = UIKit.vbox(8)
	add_child(UIKit.panel(_summary, 16))
	_refresh_summary()


func _coach_week() -> Dictionary:
	return Data.periodization.variants[Game.season.variant(year)].templates[phase_id]


func _month() -> int:
	return Game.add_days(_p.first, int(_p.weeks) * 7 / 2).month


# --- The week ----------------------------------------------------------------------------------------------

func _week_box() -> Control:
	var week: Dictionary = Game.season.edit_phase(year, phase_id)   # edited in place
	var a := Game.athlete
	var box := UIKit.vbox(14 if Layout.compact else 8)
	box.add_child(UIKit.label("THE PHASE'S WEEK", "CaptionLabel"))
	box.add_child(UIKit.wrapped("Every week of the phase starts from this week. The season plan then adds its rules: "
			+ "easing in from the phase before, lighter weeks, an easy day before a race and the taper before a target."))
	var on_change := func():
		_refresh_summary()
		plan_changed.emit()
	for d in 7:
		if d > 0 and Layout.compact:
			box.add_child(HSeparator.new())
		box.add_child(PlanUI.day_row(week, d, a, _month(), on_change, Training.DAY_NAMES[d]))
	return UIKit.panel(box, 16)


func _reset_box() -> Control:
	var col := UIKit.vbox(8)
	col.add_child(UIKit.wrapped("Your changes: this phase differs from the coach's %s plan."
			% Data.periodization.variants[Game.season.variant(year)].name, ""))
	var reset := UIKit.button("Back to coach's", false, 190)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
	var stage := [0]
	reset.pressed.connect(func():
		if stage[0] == 0:
			stage[0] = 1
			reset.text = "Tap again to confirm"
			return
		Game.season.reset_phase(year, phase_id)
		rebuild.emit())
	col.add_child(reset)
	return UIKit.alert_panel(col, Palette.ACCENT)


# --- Lighter weeks and easing in -----------------------------------------------------------------------------

func _rules_box() -> Control:
	var s := Game.season
	var box := UIKit.vbox(12)
	box.add_child(UIKit.label("WEEKS OF THE PHASE", "CaptionLabel"))

	var lighter := UIKit.vbox(6)
	var lrow := UIKit.flex(10)
	var ltext := UIKit.label("Lighter weeks", "SubheadingLabel")
	ltext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(ltext)
	var group := ButtonGroup.new()
	var buttons := UIKit.hbox(6)
	for on in [true, false]:
		var b := UIKit.toggle("On" if on else "Off", group)
		b.custom_minimum_size.x = 0 if Layout.compact else 80
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_END
		b.button_pressed = s.lighter_on(year, phase_id) == on
		b.pressed.connect(func():
			if s.lighter_on(year, phase_id) != on:
				s.set_lighter(year, phase_id, on)
				rebuild.emit())
		buttons.add_child(b)
	lrow.add_child(buttons)
	lighter.add_child(lrow)
	lighter.add_child(UIKit.wrapped("Every %s week of the phase is one step easier on every day (Hard → Normal → Easy), "
			% _ordinal(int(Data.periodization.lighter.every)) + "so the body can catch up. Not in a taper week."))
	box.add_child(lighter)

	var ramp := s.ramp_of(year, phase_id)
	var limit := mini(MAX_RAMP, int(_p.weeks))
	var rcol := UIKit.vbox(6)
	var rrow := UIKit.flex(10)
	var rtext := UIKit.label("Easing in: %d week%s" % [ramp, "" if ramp == 1 else "s"], "SubheadingLabel")
	rtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rtext)
	var steps := UIKit.hbox(6)
	for delta in [-1, 1]:
		var b := UIKit.button("Fewer" if delta < 0 else "More", false, 100)
		b.disabled = ramp + delta < 1 or ramp + delta > maxi(limit, ramp)
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			s.set_ramp_weeks(year, phase_id, ramp + delta)
			rebuild.emit())
		steps.add_child(b)
	rrow.add_child(steps)
	rcol.add_child(rrow)
	rcol.add_child(UIKit.wrapped("The first weeks mix in the days of the phase before, a few more days each week, so your "
			+ "body gets used to the new work. 1 week = straight in. (Coach's: %d.)" % _coach_ramp()))
	box.add_child(rcol)
	return UIKit.panel(box, 16)


func _coach_ramp() -> int:
	return int(Data.periodization.variants[Game.season.variant(year)].ramp_weeks.get(phase_id, 1))


static func _ordinal(n: int) -> String:
	match n:
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


# --- Edges ---------------------------------------------------------------------------------------------------

func _edges_box() -> Control:
	var s := Game.season
	var lay := s.phase_dates(year)
	var idx := -1
	for i in lay.size():
		if lay[i].id == phase_id:
			idx = i
	var box := UIKit.vbox(12)
	box.add_child(UIKit.label("WHEN IT RUNS", "CaptionLabel"))
	# The start of this phase (not the season's first), and its end = the start of the next one (not the last).
	if idx > 0:
		box.add_child(_edge_row("Starts %s" % Calendar.format_day(_p.first), phase_id, int(_p.start)))
	else:
		box.add_child(UIKit.wrapped("Starts %s, with the season." % Calendar.format_day(_p.first), ""))
	if idx >= 0 and idx < lay.size() - 1:
		box.add_child(_edge_row("Ends %s" % Calendar.format_day(_p.last), str(lay[idx + 1].id), int(lay[idx + 1].start)))
	else:
		box.add_child(UIKit.wrapped("Ends %s, with the season." % Calendar.format_day(_p.last), ""))
	box.add_child(UIKit.wrapped("Edges move by whole weeks, at most %d weeks from the coach's dates, and every phase keeps at "
			% int(Data.periodization.season.shift_limit) + "least a week. Moving a target meet moves its phases with it."))
	return UIKit.panel(box, 16)


## One edge: the start of phase `moves` (week `start` of the season). ◀ = a week earlier, ▶ = a week later. An
## edge in the past or this week can't move (this week's plan is already running).
func _edge_row(text: String, moves: String, start: int) -> Control:
	var s := Game.season
	var this_week := SeasonPlan.week_no(year, Game.week_monday())
	var label := UIKit.label(text, "SubheadingLabel")
	if start <= this_week:
		# Text only, stacked: a wrapping label beside an expanding one gets no width (it wrapped letter by letter).
		var col := UIKit.vbox(2)
		col.add_child(label)
		col.add_child(UIKit.wrapped("Already started, so this edge can't move.", "MutedLabel"))
		return col
	var row := UIKit.flex(10)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var buttons := UIKit.hbox(6)
	for delta in [-1, 1]:
		var b := UIKit.button("◀  Earlier" if delta < 0 else "Later  ▶", false, 130)
		b.disabled = delta < 0 and start - 1 <= this_week
		if Layout.compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			var want: int = s.shift_of(year, moves) + delta
			if s.set_shift(year, moves, want) != want:
				note = "Can't move it further: every phase keeps at least a week, and an edge moves at most %d weeks from the coach's date." \
						% int(Data.periodization.season.shift_limit)
			rebuild.emit())
		buttons.add_child(b)
	row.add_child(buttons)
	return row


# --- Summary -------------------------------------------------------------------------------------------------

func _refresh_summary() -> void:
	if _summary == null:
		return
	var week: Dictionary = Game.season.edit_phase(year, phase_id)
	var future := SeasonUI.phase_state(_p) == "future"
	var strain: Control
	if future:
		strain = HealthUI.plan_section(week, null, SeasonUI.lead_in(year, phase_id, _p.first))
	else:
		strain = HealthUI.plan_section(week)
	PlanUI.fill_summary(_summary, Game.athlete, week, _p.first if future else Game.week_monday(), strain)
