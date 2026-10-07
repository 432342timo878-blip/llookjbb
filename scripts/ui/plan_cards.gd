class_name PlanCards
extends RefCounted
## The coach's three season plans as ChoiceCards (GDD 4.8 "UI"): name, ★ on the coach's pick, "in use", weekly load,
## typical risk, focus and the plan's sentence; a row on PC, stacked on a phone or beside the side panel. Used by the
## Training tab (this season and next season) and the coach's offer event.

## `year` = the season the loads are worked out for; `selected` = the card shown as chosen; `pick` = the ★;
## `in_use` = the plan the season runs on now ("" = don't say); `on_choose(id)` when a card is pressed.
## `stacked` puts the cards under each other (narrow places).
static func build(year: int, selected: String, pick: String, in_use: String, on_choose: Callable, stacked := false) -> Control:
	var a := Game.athlete
	var box := UIKit.vbox(10)
	var row: BoxContainer = UIKit.vbox(10) if stacked else UIKit.flex(10)
	var group := ButtonGroup.new()
	for id in ["steady", "balanced", "ambitious"]:
		var v: Dictionary = Data.periodization.variants[id]
		var card_info: Dictionary = v.get("card", {})
		var detail := "Weekly load about %d · typical risk %s\nFocus: %s\n%s" % [
				roundi(SeasonUI.variant_load(a, id, year)),
				HealthSystem.RISK_NAMES.get(str(card_info.get("risk", "low")), "Low"),
				card_info.get("focus", ""), v.text]
		var title: String = v.name + (" ★" if id == pick else "") + ("  ·  in use" if id == in_use else "")
		var card := ChoiceCard.new(title, detail, group)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		card.custom_minimum_size.y = 120 if not (stacked or Layout.stacked()) else 52
		card.selected = id == selected
		card.button.pressed.connect(func(): on_choose.call(id))
		row.add_child(card)
	box.add_child(row)
	box.add_child(UIKit.wrapped(str(Data.periodization.offer.star_note)))
	return box


## "This replaces your changes to N phases…" with Use X / Keep my plan, for a season with edited phases.
static func replace_warning(n: int, variant_id: String, on_use: Callable, on_keep: Callable) -> Control:
	var cfg: Dictionary = Data.periodization.offer
	var name: String = Data.periodization.variants[variant_id].name
	var confirm := UIKit.vbox(8)
	confirm.add_child(UIKit.wrapped(str(cfg.replace).format({"n": n, "s": "" if n == 1 else "s", "plan": name}), ""))
	var buttons := UIKit.hbox(8)
	var yes := UIKit.button(str(cfg.use).format({"plan": name}), true, 180)
	yes.pressed.connect(func(): on_use.call())
	var no := UIKit.button(str(cfg.keep), false, 160)
	no.pressed.connect(func(): on_keep.call())
	for b in [yes, no]:
		if Layout.stacked():
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	confirm.add_child(buttons)
	return UIKit.alert_panel(confirm, Palette.RISK_MODERATE)
