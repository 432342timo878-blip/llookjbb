class_name RomanceCard
extends CalloutCard
## "Someone on your mind" (GDD 4.10 decision 6, session P2b): the card on the Sunday planner when a crush may begin. Up to three
## people you know well enough, one 44 px button each (the player picks who the character is interested in), and "Nobody right
## now". Never a stop and not one of "N choices waiting": it stays on the planner for a few weeks and Play week never asks about it.
## Reading and answering through RomanceSystem only. Texts: data/romance.json ui. Help: the screen "romance".

signal changed

const HELP := "romance"


## The card, or null when there is none (the relationship system is off, something is going on, or no card has come).
static func build() -> RomanceCard:
	if not RomanceSystem.active():
		return null
	var rs := RomanceSystem.sys()
	var pack := rs.card()
	if pack.is_empty():
		return null
	var u: Dictionary = Data.romance.ui
	var card := RomanceCard.new(Palette.PEOPLE, "heart", str(u.card_title), str(u.card_text))
	var box := UIKit.vbox(6)
	for p in pack.cands:
		var pid := str(p.id)
		var b := UIKit.button(rs.candidate_line(p), false, 0.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.set_meta("crush_pick", pid)
		b.pressed.connect(func():
			rs.choose(pid)
			card.changed.emit())
		box.add_child(b)
	var none := UIKit.button(str(u.card_none), false, 0.0)
	none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	none.custom_minimum_size = Vector2(0, 44)
	none.set_meta("crush_none", true)
	none.pressed.connect(func():
		rs.decline()
		card.changed.emit())
	box.add_child(none)
	var foot := UIKit.hbox(8)
	var hint := UIKit.wrapped(str(u.card_hint), "WhyLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var help := HelpButton.new(HELP)
	help.pressed.connect(func(): HelpOverlay.open(card._screen(), HELP))
	foot.add_child(help)
	box.add_child(foot)
	card.add_row(box)
	return card


## The screen this card is on (the hub: the child of the ScreenHost), where the help opens.
func _screen() -> Control:
	var n: Node = self
	while n.get_parent() != null and str(n.get_parent().name) != "ScreenHost":
		n = n.get_parent()
	return n as Control
