class_name PlaytestCard
extends RefCounted
## The playtest's card (session K1c): a few questions about the page you are on, at the top of that page, while the playtest is on
## (data/playtest.json, PlaytestNotes.due). Never a stop, never a choice waiting, Play week is unaffected. Answers are saved at once;
## Done removes the card and does not ask the unanswered ones again (they stay on the Playtest notes page). `page` = a key of the
## data's `pages` ("week", "career:now", ...). Returns null when nothing is due.


static func build(page: String) -> Control:
	if Game.athlete == null or not Data.playtest.pages.has(page):
		return null
	var notes := PlaytestNotes.open()
	var questions := notes.due(page)
	if questions.is_empty():
		return null
	var u: Dictionary = Data.playtest.ui
	var box := UIKit.vbox(10)
	box.add_child(UIKit.label(str(u.card_head).format({"page": str(Data.playtest.pages[page])}), "CaptionLabel"))
	for q in questions:
		box.add_child(PlaytestView.question_box(q, notes, page, func(): pass, false))
	var done := UIKit.button(str(u.card_done), true, 120)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(done)
	var panel := UIKit.alert_panel(box, Palette.PEOPLE, 14)
	done.pressed.connect(func():
		notes.skip(questions)   # (what was left unanswered is not asked again; it stays on the Playtest notes page)
		if is_instance_valid(panel):
			panel.queue_free())
	return panel
