class_name SeasonView
extends VBoxContainer
## The Training tab in season-plan mode (GDD 4.8 "UI", M2 step 6e): the coach's plan (one line + "Change plan",
## which opens the three plan cards), the season (PC: the SeasonBar and the phases in two columns; phone: a list of
## the phases), the target meets (change / remove / add, max 3) and this week. Tapping a phase emits
## `phase_opened` (the hub opens the PhaseEditor in the tab). Every change emits `plan_changed`; the hub then puts
## the plan into this week, refreshes the strip and rebuilds the tab.

signal phase_opened(phase_id: String)
signal plan_changed

static var cards_open := false       # the three plan cards are shown (kept while the tab is rebuilt)
static var pending_variant := ""     # a plan card waiting for "This replaces your changes to N phases"

var year := 0


func _init() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	year = SeasonUI.current_year()
	_build()


func _build() -> void:
	add_child(UIKit.label("Season plan %d–%s" % [year, str(year + 1).right(2)], "HeadingLabel"))
	add_child(UIKit.wrapped("Your club coach's training year: phases that build up to your target meets, a lighter "
			+ "week every so often, an easy day before races and a taper before each target. Tap a phase to see or change it."))
	add_child(_plan_section())
	add_child(_season_section())
	add_child(_targets_section())
	_this_week()


# --- The coach's plans -----------------------------------------------------------------------------------

func _plan_section() -> Control:
	var s := Game.season
	var a := Game.athlete
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label("COACH'S PLAN", "CaptionLabel"))
	var current := s.variant(year)
	var pick := SeasonPlan.coach_pick(a, Game.date, HealthUI.system())
	var v: Dictionary = Data.periodization.variants[current]
	var head := UIKit.flex(10)
	var line := UIKit.wrapped("%s%s: %s" % [v.name, " ★" if current == pick else "", v.text], "")
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(line)
	var toggle := UIKit.button("Hide plans" if cards_open else "Change plan", false, 160)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(toggle)
	box.add_child(head)

	var cards := UIKit.vbox(10)
	cards.visible = cards_open
	toggle.pressed.connect(func():
		cards_open = not cards_open
		pending_variant = ""
		cards.visible = cards_open
		toggle.text = "Hide plans" if cards_open else "Change plan")
	var row := UIKit.flex(10)
	var group := ButtonGroup.new()
	var by_id := {}
	for id in ["steady", "balanced", "ambitious"]:
		var var_data: Dictionary = Data.periodization.variants[id]
		var card_info: Dictionary = var_data.get("card", {})
		var detail := "Weekly load about %d · typical risk %s\nFocus: %s\n%s" % [
				roundi(SeasonUI.variant_load(a, id, year)),
				HealthSystem.RISK_NAMES.get(str(card_info.get("risk", "low")), "Low"),
				card_info.get("focus", ""), var_data.text]
		var title: String = var_data.name + (" ★" if id == pick else "") + ("  ·  in use" if id == current else "")
		var card := ChoiceCard.new(title, detail, group)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		card.custom_minimum_size.y = 120 if not Layout.compact else 52
		card.selected = id == (pending_variant if pending_variant != "" else current)
		by_id[id] = card
		card.button.pressed.connect(func(): _choose(id))
		row.add_child(card)
	cards.add_child(row)
	cards.add_child(UIKit.wrapped("★ = your coach's pick for you now (from your durability, professionalism and injuries "
			+ "in the last year). Weekly load is the season's average week; the risk word is what most weeks of the plan read."))
	if pending_variant != "":
		var n := s.edited_phases(year)
		var confirm := UIKit.vbox(8)
		confirm.add_child(UIKit.wrapped("This replaces your changes to %d phase%s with the coach's %s plan. Your targets and moved edges stay."
				% [n, "" if n == 1 else "s", Data.periodization.variants[pending_variant].name], ""))
		var buttons := UIKit.hbox(8)
		var yes := UIKit.button("Use %s" % Data.periodization.variants[pending_variant].name, true, 180)
		yes.pressed.connect(func():
			s.set_variant(year, pending_variant)
			pending_variant = ""
			plan_changed.emit())
		var no := UIKit.button("Keep my plan", false, 160)
		no.pressed.connect(func():
			pending_variant = ""
			plan_changed.emit())
		for b in [yes, no]:
			if Layout.compact:
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons.add_child(b)
		confirm.add_child(buttons)
		cards.add_child(UIKit.alert_panel(confirm, Palette.RISK_MODERATE))
	box.add_child(cards)
	return UIKit.panel(box, 16)


## A plan card was pressed: switch at once, or ask first when phases were edited.
func _choose(id: String) -> void:
	var s := Game.season
	if id == s.variant(year) and pending_variant == "":
		return
	if id == s.variant(year):
		pending_variant = ""
	elif s.edited_phases(year) > 0:
		pending_variant = id
	else:
		s.set_variant(year, id)
	plan_changed.emit()


# --- The season: bar (PC) and the phases -------------------------------------------------------------------

func _season_section() -> Control:
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label("THE SEASON", "CaptionLabel"))
	if not Layout.compact:
		var bar := SeasonBar.new(year)
		bar.phase_pressed.connect(func(id): phase_opened.emit(id))
		box.add_child(bar)
		box.add_child(UIKit.wrapped("Blue weeks under the bar are lighter weeks, orange ones a taper; %s = a target meet, "
				% SeasonUI.TARGET_MARK + "the white line = today, a dark dot = your changes."))
	var list: Container
	if Layout.compact:
		list = UIKit.vbox(8)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		list = grid
	for p in Game.season.phase_dates(year):
		list.add_child(_phase_row(p))
	box.add_child(list)
	return UIKit.panel(box, 16)


## One phase: colour edge, name, dates and weeks, and now / over / your changes. Tap = the phase editor.
func _phase_row(p: Dictionary) -> Control:
	var type := SeasonPlan.phase_type(p.id)
	var col := UIKit.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UIKit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UIKit.label(type.get("name", p.id), "SubheadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	top.add_child(title)
	top.add_child(UIKit.label("›", "SubheadingLabel"))
	col.add_child(top)
	col.add_child(UIKit.label("%s · %d week%s" % [SeasonUI.range_text(p.first, p.last), p.weeks, "" if p.weeks == 1 else "s"], "MutedLabel"))
	var notes := []
	var state := SeasonUI.phase_state(p)
	if state == "now":
		notes.append("Now: week %d" % SeasonUI.phase_week_now(p))
	elif state == "past":
		notes.append("Over")
	if Game.season.is_edited(year, p.id):
		notes.append("your changes")
	if not notes.is_empty():
		var note := UIKit.label(" · ".join(notes), "CaptionLabel")
		if state == "now":
			note.add_theme_color_override("font_color", Palette.ACCENT)
		col.add_child(note)
	for c in col.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := UIKit.alert_panel(col, Color(str(type.get("color", "#888888"))), 10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 56
	if state == "past":
		card.modulate = Color(1, 1, 1, 0.6)
	var button := Button.new()
	button.theme_type_variation = "CardOverlay"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): phase_opened.emit(p.id))
	card.add_child(button)
	return card


# --- Targets ---------------------------------------------------------------------------------------------

func _targets_section() -> Control:
	var s := Game.season
	var a := Game.athlete
	var max_targets := int(Data.periodization.season.max_targets)
	var list := s.targets(year)
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label("TARGET MEETS (%d OF %d)" % [list.size(), max_targets], "CaptionLabel"))
	box.add_child(UIKit.wrapped("The meets your season builds up to. The first indoor and the first outdoor target set "
			+ "the dates of the phases; every target gets a %d-day taper. You can also mark targets in the Calendar."
			% int(Data.periodization.taper.days)))
	var first := {}
	for key in list:
		var m := Calendar.get_meet(key)
		var kind := "indoor" if m.get("indoor", false) else "outdoor"
		if not first.has(kind):
			first[kind] = key
	for key in list:
		var m := Calendar.get_meet(key)
		if m.is_empty():
			continue
		var kind := "indoor" if m.get("indoor", false) else "outdoor"
		var row := UIKit.flex(10)
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.wrapped("%s %s" % [SeasonUI.TARGET_MARK, m.name], "SubheadingLabel"))
		var details := [Calendar.format_meet_date(m), "sets the %s phases" % kind if first.get(kind) == key else "taper only"]
		var past := Calendar.date_key(m.date) < Calendar.date_key(Game.date)
		var check := Calendar.can_enter(a, m, Game.date)
		if past:
			details.append("done" if key in Game.entries else "over")
		elif key in Game.entries:
			details.append("entered")
		info.add_child(UIKit.wrapped(" · ".join(details)))
		if not past and not key in Game.entries:
			info.add_child(UIKit.wrapped("Not entered yet." if check.ok else "Not entered: " + str(check.reason), ""))
		row.add_child(info)
		if not past:
			var buttons := UIKit.hbox(8)
			if not key in Game.entries and check.ok:
				var enter := UIKit.button("Enter", true, 110)
				enter.pressed.connect(func():
					Game.enter(key)
					plan_changed.emit())
				buttons.add_child(enter)
			var remove := UIKit.button("Remove", false, 110)
			remove.pressed.connect(func():
				s.remove_target(year, key)
				plan_changed.emit())
			buttons.add_child(remove)
			for b in buttons.get_children():
				b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				if Layout.compact:
					b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(buttons)
		box.add_child(row)
	if list.is_empty():
		box.add_child(UIKit.wrapped("No targets: the phases follow the main championships of your age class, with no taper.", ""))

	if list.size() >= max_targets:
		box.add_child(UIKit.wrapped("%d targets is the most for a season. Remove one to add another." % max_targets, ""))
	else:
		var candidates := s.target_candidates(year, Game.date)
		if candidates.is_empty():
			box.add_child(UIKit.wrapped("No other meets this season that you could make a target.", ""))
		else:
			var add := OptionButton.new()
			add.custom_minimum_size = Vector2(0 if Layout.compact else 360, 44)
			add.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_SHRINK_BEGIN
			add.fit_to_longest_item = false
			add.clip_text = true
			add.add_item("Add a target meet…")
			add.set_item_metadata(0, "")
			for m in candidates:
				add.add_item("%s · %s" % [DayInfo.short_day(m.date), m.name])
				add.set_item_metadata(add.item_count - 1, m.key)
			add.item_selected.connect(func(i: int):
				var key: String = add.get_item_metadata(i)
				if key == "":
					return
				s.add_target(year, key)
				if Calendar.can_enter(a, Calendar.get_meet(key), Game.date).ok:
					Game.enter(key)   # marking a target enters the meet when allowed (GDD 4.8)
				plan_changed.emit())
			box.add_child(add)
	return UIKit.panel(box, 16)


# --- This week -------------------------------------------------------------------------------------------

func _this_week() -> void:
	var plan := Game.season.week_for(Game.week_monday())
	var days := PlanUI.days_list(plan, plan.why)
	days.add_child(UIKit.wrapped("To change a single day of this week, tap it in the week strip above.", "MutedLabel"))
	var col := UIKit.vbox(8)
	col.add_child(UIKit.label("THIS WEEK · " + SeasonUI.week_text(plan).to_upper(), "CaptionLabel"))
	col.add_child(days)
	add_child(UIKit.panel(col, 16))
	var summary := UIKit.vbox(8)
	add_child(UIKit.panel(summary, 16))
	PlanUI.fill_summary(summary, Game.athlete, plan, Game.week_monday(), HealthUI.plan_section(plan, Game.current_week()))
