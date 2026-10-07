class_name SeasonEventPanel
extends VBoxContainer
## The club coach's stop events (SeasonSystem, GDD 4.8, M2 step 6f) as panels in the career hub's dimmed decision layer,
## in the same look as the health panels (caption with the date and a "?", heading, text, cards, 44 px buttons):
##   - the offer (event.kind "offer"): the three plans as cards (a row on PC, stacked on a phone), the ★ chosen
##     at first; "Use <plan>" (after "This replaces your changes to N phases" when that season has edited phases)
##     and "Decide later in the Training tab";
##   - easing back in (kind "return"): the block's weeks, what comes after, the plan risk with and without it,
##     entered races in the block, Accept / No thanks.
## All texts come from data/periodization.json ("offer", "return_block.ui"). Rebuilds itself when a card is
## chosen (`rebuilt`, so the hub fits the card's height again).

signal rebuilt

const KINDS := ["offer", "return"]
const HELP := {"offer": "season_offer", "return": "return_block"}   # entries in data/help.json "screens"

var _e: Dictionary
var _width := 480.0
var _on_answer: Callable
var _on_help: Callable
var _selected := ""
var _confirm := false   # the replace warning is shown


static func handles(e: Dictionary) -> bool:
	return e.get("source", "") == "season" and str(e.get("kind", "")) in KINDS


static func help_id(e: Dictionary) -> String:
	return HELP.get(str(e.get("kind", "")), "")


## The offer's three cards need a wide panel on PC; everything else is as narrow as the other stop panels.
static func max_width(e: Dictionary) -> float:
	return 860.0 if str(e.get("kind", "")) == "offer" and not Layout.compact else 520.0


func _init(e: Dictionary, width: float, on_answer: Callable, on_help := Callable()) -> void:
	_e = e
	_width = width
	_on_answer = on_answer
	_on_help = on_help
	_selected = str(e.get("pick", Data.periodization.season.default_variant))
	add_theme_constant_override("separation", 10)
	custom_minimum_size.x = width
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(_caption())
	if str(_e.kind) == "offer":
		_offer()
	else:
		_return()
	rebuilt.emit()


func _caption() -> Control:
	var caption := UIKit.label("%s · %s" % [Calendar.format_day(_e.date).to_upper(), Data.periodization.offer.source], "CaptionLabel")
	if not _on_help.is_valid():
		return caption
	var row := UIKit.hbox(8)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.clip_text = true
	row.add_child(caption)
	var help := HelpButton.new(help_id(_e))
	help.pressed.connect(func(): _on_help.call())
	row.add_child(help)
	return row


# --- The offer ---------------------------------------------------------------------------------------------------

func _offer() -> void:
	var cfg: Dictionary = Data.periodization.offer
	var year := int(_e.year)
	var first := bool(_e.get("first", false))
	add_child(UIKit.wrapped(_e.title, "HeadingLabel"))
	add_child(UIKit.wrapped(_e.text, ""))
	var in_use := Game.season.variant(year) if first else ""
	add_child(PlanCards.build(year, _selected, str(_e.pick), in_use, func(id: String):
		_selected = id
		_confirm = false
		_build(), _width < 700.0))
	var name: String = Data.periodization.variants[_selected].name
	if _confirm:
		add_child(PlanCards.replace_warning(Game.season.edited_phases(year), _selected,
				func(): _on_answer.call(_selected),
				func():
					_confirm = false
					_build()))
		return
	var row: BoxContainer = UIKit.vbox(8) if Layout.compact else UIKit.hbox(8)
	var use := UIKit.button(str(cfg.use).format({"plan": name + (" ★" if _selected == str(_e.pick) else "")}), true, 220)
	use.pressed.connect(func():
		var edited := Game.season.edited_phases(year)
		if edited > 0 and _selected != Game.season.variant(year):
			_confirm = true
			_build()
		else:
			_on_answer.call(_selected))
	var later := UIKit.button(str(cfg.later), false, 260)
	later.pressed.connect(func(): _on_answer.call("later"))
	for b in [use, later]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	add_child(row)
	var pick_name: String = Data.periodization.variants[str(_e.pick)].name
	add_child(UIKit.wrapped(str(cfg.later_first if first else cfg.later_next).format({"plan": pick_name,
			"date": Calendar.format_day(SeasonPlan.season_start(year))})))


# --- Easing back in ----------------------------------------------------------------------------------------------

func _return() -> void:
	var ui: Dictionary = Data.periodization.return_block.ui
	add_child(UIKit.wrapped(_e.title, "HeadingLabel"))
	add_child(UIKit.wrapped(_e.text, ""))
	var start := Game.int_date(_e.start)
	add_child(UIKit.alert_panel(SeasonUI.return_rows(start, _e.kinds), Palette.ACCENT))
	var phase := str(_e.get("phase_after", ""))
	if phase != "":
		add_child(UIKit.wrapped(str(ui.then_season).format({"phase": SeasonPlan.phase_type(phase).get("name", phase)}), ""))
	else:
		add_child(UIKit.wrapped(str(ui.then_repeat), ""))

	var risk := UIKit.vbox(6)
	risk.add_child(UIKit.label(str(ui.risk_caption), "CaptionLabel"))
	risk.add_child(_risk_row(str(ui.risk_full), str(_e.risk_full)))
	risk.add_child(_risk_row(str(ui.risk_block), str(_e.risk_block)))
	var full := str(_e.risk_full)
	if full == str(_e.risk_block):   # the same word: say what still differs
		var same: String = ui.risk_same_low if full == "low" else (ui.risk_same_safer if _e.get("much_safer", false) else ui.risk_same)
		risk.add_child(UIKit.wrapped(same.format({"risk": HealthSystem.RISK_NAMES.get(full, full)}), ""))
	risk.add_child(UIKit.wrapped(str(ui.risk_note)))
	add_child(UIKit.alert_panel(risk, HealthUI.risk_color(str(_e.risk_full))))

	var races := []
	for key in _e.get("races", []):
		var m := Calendar.get_meet(str(key))
		if not m.is_empty():
			races.append("%s (%s)" % [m.name, DayInfo.short_day(m.date)])
	if not races.is_empty():
		add_child(UIKit.wrapped(str(ui.races).format({"races": ", ".join(races)}), ""))

	var row: BoxContainer = UIKit.vbox(8) if Layout.compact else UIKit.hbox(8)
	for c in _e.choices:
		var b := UIKit.button(c.label, c.id == "accept", 180)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _on_answer.call(c.id))
		row.add_child(b)
	add_child(row)
	add_child(UIKit.wrapped(str(ui.accept_detail)))


func _risk_row(key: String, risk: String) -> Control:
	var value := UIKit.label(HealthSystem.RISK_NAMES.get(risk, risk))
	value.add_theme_color_override("font_color", HealthUI.risk_color(risk))
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UIKit.fact_row(key, value)
	(row.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return row
