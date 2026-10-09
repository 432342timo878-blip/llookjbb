class_name RaceStoryView
extends RefCounted
## The Race story panel of the result screen (GDD 4.3.1, step R4): the splits at 200 / 400 / 600 m and the finish for the
## player and the winner (or the runner-up when the player won), the key moments, and the coach's one-line verdict in the
## accent colour. Made from RaceStory.build().


static func build(story: Dictionary) -> Control:
	var cfg: Dictionary = Data.race_commentary.story
	var col := UIKit.vbox(10)
	col.add_child(UIKit.label(str(story.title), "CaptionLabel"))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for h in [str(cfg.splits_head[0]), str(cfg.splits_head[1]), str(story.other_head)]:
		var l := UIKit.label(h, "CaptionLabel")
		if h == str(cfg.splits_head[1]):
			l.add_theme_color_override("font_color", Palette.ACCENT)
		grid.add_child(l)
	for s in story.splits:
		var name_l := UIKit.label(str(s.label), "MutedLabel")
		name_l.custom_minimum_size.x = 70
		grid.add_child(name_l)
		var you := UIKit.label(str(s.you))
		you.add_theme_color_override("font_color", Palette.ACCENT)
		you.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(you)
		var other := UIKit.label(str(s.winner))
		other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(other)
	col.add_child(grid)

	col.add_child(UIKit.label(str(cfg.moments_head), "CaptionLabel"))
	if story.moments.is_empty():
		col.add_child(UIKit.wrapped(str(cfg.empty)))
	for m in story.moments:
		var row := UIKit.hbox(10)
		var at := UIKit.label(str(cfg.at).format({"m": m.m}), "MutedLabel")
		at.custom_minimum_size.x = 64
		at.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(at)
		var text := UIKit.wrapped(str(m.text), "")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		col.add_child(row)

	if str(story.coach) != "":
		var shout := UIKit.vbox(2)
		var tag := UIKit.label("%s · %s" % [cfg.coach_head, story.coach_name], "CaptionLabel")
		tag.add_theme_color_override("font_color", Palette.ACCENT)
		shout.add_child(tag)
		shout.add_child(UIKit.wrapped("“%s”" % story.coach, ""))
		col.add_child(UIKit.alert_panel(shout, Palette.ACCENT))
	return UIKit.panel(col, 16)
