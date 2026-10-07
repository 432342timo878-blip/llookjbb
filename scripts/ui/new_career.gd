extends Control
## Character creation wizard: identity → main event → background → attribute points → summary.

const STEPS := ["Identity", "Main event", "Background", "Attributes", "Summary"]
## Events playable in the current version (M1).
const PLAYABLE_EVENTS := ["800m"]
const ATTRIBUTE_CATEGORIES := ["physical", "technical", "mental"]
const HELP := "new_career"   # the wizard's help entry in data/help.json

var _step := 0
var _choices := {
	"first_name": "", "last_name": "", "gender": "male",
	"hometown": "Helsinki", "club_id": "", "main_event": "800m", "answers": {},
}
var _points := {}           # attribute id -> points added in the Attributes step
var _seed := randi()        # fixed per wizard so the base athlete doesn't re-roll
var _base: Athlete          # athlete before points are added

var _margin: MarginContainer
var _step_label: Label
var _status_label: Label     # "Points left" on the attributes step, pinned above the scrolling content
var _scroll: ScrollContainer
var _content: VBoxContainer
var _back: Button
var _next: Button


func _ready() -> void:
	_choices.birth_date = _random_birth_date()
	Router.layout_changed.connect(func(_c): _build_shell(); _show_step())
	_build_shell()
	_show_step()


## Step title, scrolling content and Back / Next. Rebuilt when the layout switches (wide <-> phone).
func _build_shell() -> void:
	if _margin:
		_margin.queue_free()
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	Layout.page_margin(_margin, 1000.0)   # the steps are forms: keep them from stretching across a wide window
	add_child(_margin)
	var column := UIKit.vbox(12 if Layout.compact else 16)
	_margin.add_child(column)

	var top := UIKit.hbox(12)
	_step_label = UIKit.label("", "CaptionLabel")
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label = UIKit.label("", "SubheadingLabel")
	_status_label.add_theme_color_override("font_color", Palette.ACCENT)
	_step_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_step_label)
	top.add_child(_status_label)
	var help := HelpButton.new(HELP)   # "How this works" (GDD 5 "Help")
	help.pressed.connect(func(): HelpOverlay.open(self, HELP))
	top.add_child(help)
	column.add_child(top)
	column.add_child(UIKit.label("New Career", "HeadingLabel"))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = UIKit.vbox(14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	column.add_child(_scroll)

	var footer := UIKit.hbox(12)
	_back = UIKit.button("Back", false, 160)
	_back.custom_minimum_size.y = 48
	_next = UIKit.button("Next", true, 200)
	_next.custom_minimum_size.y = 48
	_back.pressed.connect(_on_back)
	_next.pressed.connect(_on_next)
	if Layout.compact:
		_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_next.size_flags_stretch_ratio = 1.5
		footer.add_child(_back)
		footer.add_child(_next)
	else:
		footer.add_child(_back)
		footer.add_child(UIKit.spacer())
		footer.add_child(_next)
	column.add_child(footer)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F1:
		HelpOverlay.open(self, HELP)
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	if _step == 0:
		Router.go("main_menu")
	else:
		_step -= 1
		_show_step()


func _on_next() -> void:
	if _step == STEPS.size() - 1:
		Game.start_career(_build_athlete())
		Router.go("career_hub")
		return
	_step += 1
	_show_step()


func _show_step() -> void:
	for child in _content.get_children():
		child.queue_free()
	_step_label.text = "STEP %d OF %d · %s" % [_step + 1, STEPS.size(), STEPS[_step].to_upper()]
	_status_label.text = ""
	_back.text = "Main menu" if _step == 0 else "Back"
	_next.text = "Start career" if _step == STEPS.size() - 1 else "Next"
	match _step:
		0: _build_identity()
		1: _build_event()
		2: _build_background()
		3: _build_attributes()
		4: _build_summary()
	_validate()


func _validate() -> void:
	var ok := true
	match _step:
		0: ok = _choices.first_name.strip_edges() != "" and _choices.last_name.strip_edges() != ""
		1: ok = _choices.main_event in PLAYABLE_EVENTS
		2: ok = _choices.answers.size() == Data.background_questions.size()
	_next.disabled = not ok


# --- Step 1: identity -------------------------------------------------------------

func _build_identity() -> void:
	_content.add_child(UIKit.label("Who are you?", "HeadingLabel"))

	_content.add_child(UIKit.label("GENDER", "CaptionLabel"))
	var genders := UIKit.hbox()
	var group := ButtonGroup.new()
	for g in [["male", "Boy"], ["female", "Girl"]]:
		var b := UIKit.toggle(g[1], group)
		b.custom_minimum_size.x = 160
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if Layout.compact else Control.SIZE_FILL
		b.button_pressed = _choices.gender == g[0]
		b.pressed.connect(func(): _choices.gender = g[0])
		genders.add_child(b)
	_content.add_child(genders)

	_content.add_child(UIKit.label("NAME", "CaptionLabel"))
	var names := UIKit.flex(12)
	var first := _line_edit("First name", _choices.first_name)
	var last := _line_edit("Last name", _choices.last_name)
	first.text_changed.connect(func(t): _choices.first_name = t; _validate())
	last.text_changed.connect(func(t): _choices.last_name = t; _validate())
	var random_name := UIKit.button("Random name")
	random_name.pressed.connect(func():
		var pool: Array = Data.names[_choices.gender]
		first.text = pool.pick_random()
		last.text = Data.names.surnames.pick_random()
		_choices.first_name = first.text
		_choices.last_name = last.text
		_validate())
	names.add_child(first)
	names.add_child(last)
	names.add_child(random_name)
	_content.add_child(names)

	var row := UIKit.flex(12 if Layout.compact else 24)
	var town_col := UIKit.vbox(8)
	town_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	town_col.add_child(UIKit.label("HOMETOWN", "CaptionLabel"))
	var towns := OptionButton.new()
	towns.custom_minimum_size = Vector2(260, 44)
	towns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in Data.hometowns.size():
		towns.add_item(Data.hometowns[i])
		if Data.hometowns[i] == _choices.hometown:
			towns.select(i)
	town_col.add_child(towns)
	row.add_child(town_col)

	var club_col := UIKit.vbox(8)
	club_col.add_child(UIKit.label("CLUB", "CaptionLabel"))
	var clubs := OptionButton.new()
	clubs.custom_minimum_size = Vector2(360, 44)
	clubs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clubs.clip_text = true
	club_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	club_col.add_child(clubs)
	row.add_child(club_col)
	_content.add_child(row)

	var hint := UIKit.wrapped("")
	_content.add_child(hint)

	var fill_clubs := func():
		clubs.clear()
		var ordered := _clubs_for(_choices.hometown)
		for club in ordered:
			clubs.add_item("%s (%s)" % [club.name, club.city])
			clubs.set_item_metadata(clubs.item_count - 1, club.id)
		var ids := ordered.map(func(c): return c.id)
		var index := maxi(ids.find(_choices.club_id), 0)
		clubs.select(index)
		_choices.club_id = ids[index]
		var local: bool = ordered[0].city == _choices.hometown
		hint.text = "" if local else "No club in the list for %s yet: pick the one you'll travel to." % _choices.hometown
	fill_clubs.call()
	towns.item_selected.connect(func(i):
		_choices.hometown = Data.hometowns[i]
		_choices.club_id = ""
		fill_clubs.call())
	clubs.item_selected.connect(func(i): _choices.club_id = clubs.get_item_metadata(i))


## Clubs in the hometown first, then the rest alphabetically.
func _clubs_for(town: String) -> Array:
	var sorted := Data.clubs.duplicate()
	sorted.sort_custom(func(a, b):
		var a_local: bool = a.city == town
		var b_local: bool = b.city == town
		if a_local != b_local:
			return a_local
		return a.name < b.name)
	return sorted


func _line_edit(placeholder: String, text: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(0 if Layout.compact else 220, 44)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.max_length = 24
	return e


# --- Step 2: main event ---------------------------------------------------------------

func _build_event() -> void:
	_content.add_child(UIKit.label("Choose your main event", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"You can add or switch events later in your career. In this version only the 800 m is playable."))

	var group := ButtonGroup.new()
	var groups := {}   # group id -> GridContainer
	for event in Data.events:
		if not event.outdoor or not _choices.gender in event.genders:
			continue
		if not groups.has(event.group):
			_content.add_child(UIKit.label(event.group.replace("_", " ").to_upper(), "CaptionLabel"))
			var grid := GridContainer.new()
			grid.columns = 2 if Layout.compact else 4
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			_content.add_child(grid)
			groups[event.group] = grid
		var b := UIKit.toggle(event.name, group)
		b.custom_minimum_size.x = 0 if Layout.compact else 210
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var playable: bool = event.id in PLAYABLE_EVENTS
		b.disabled = not playable
		b.tooltip_text = "" if playable else "Coming in a later version"
		b.button_pressed = event.id == _choices.main_event
		b.pressed.connect(func(): _choices.main_event = event.id; _validate())
		groups[event.group].add_child(b)


# --- Step 3: background ---------------------------------------------------------------

func _build_background() -> void:
	_content.add_child(UIKit.label("Your background", "HeadingLabel"))
	_content.add_child(UIKit.wrapped("Your answers shape your starting attributes and hidden traits."))
	for question in Data.background_questions:
		var box := UIKit.vbox(8)
		box.add_child(UIKit.wrapped(question.question, "SubheadingLabel"))
		var group := ButtonGroup.new()
		for i in question.answers.size():
			var answer: Dictionary = question.answers[i]
			var card := ChoiceCard.new(answer.text, answer.detail, group)
			card.selected = _choices.answers.get(question.id, -1) == i
			card.button.pressed.connect(func(): _choices.answers[question.id] = i; _validate())
			box.add_child(card)
		_content.add_child(UIKit.panel(box, 16))


# --- Step 4: attribute points ---------------------------------------------------------

func _build_attributes() -> void:
	_base = _create_base_athlete()
	_content.add_child(UIKit.label("Fine-tune your attributes", "HeadingLabel"))
	_content.add_child(UIKit.wrapped(
			"Spend %d points to shape your athlete (max +%d per attribute). Attributes are on a 1–20 scale; a 20 is world class. Tap an attribute to see what it does."
			% [AthleteFactory.POINT_POOL, AthleteFactory.MAX_POINTS_PER_ATTRIBUTE]))
	var columns := UIKit.flex(16)
	var refresh := []   # callables that update the value labels
	var update_left := func():
		_status_label.text = "Points left: %d" % _points_left()
	for category in ATTRIBUTE_CATEGORIES:
		var col := UIKit.vbox(2 if Layout.compact else 6)
		col.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		for attr in Data.attributes_in(category):
			col.add_child(_point_row(attr, refresh, update_left))
		var p := UIKit.panel(col, 16)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		columns.add_child(p)
	_content.add_child(columns)
	update_left.call()


func _point_row(attr: Dictionary, refresh: Array, update_left: Callable) -> Control:
	var row := UIKit.hbox(6)
	var name_label := UIKit.label(attr.name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var bonus := UIKit.label("", "MutedLabel")
	bonus.custom_minimum_size.x = 26
	row.add_child(bonus)
	var value := UIKit.attr_value_label(_base.get_attr(attr.id))
	row.add_child(value)
	var minus := _small_button("−")
	var plus := _small_button("+")
	row.add_child(minus)
	row.add_child(plus)

	var update := func():
		var added: int = _points.get(attr.id, 0)
		var total: float = _base.get_attr(attr.id) + added
		value.text = str(roundi(total))
		value.add_theme_color_override("font_color", UIKit.attr_color(total))
		bonus.text = "+%d" % added if added > 0 else ""
		minus.disabled = added == 0
		plus.disabled = added >= AthleteFactory.MAX_POINTS_PER_ATTRIBUTE or _points_left() == 0 \
				or _base.get_attr(attr.id) + added >= Athlete.MAX_VALUE
	refresh.append(update)
	var change := func(delta: int):
		_points[attr.id] = _points.get(attr.id, 0) + delta
		for f in refresh:
			f.call()
		update_left.call()
	minus.pressed.connect(change.bind(-1))
	plus.pressed.connect(change.bind(1))
	update.call()
	return UIKit.tap_to_explain(row, attr.description)   # tap the row to read what the attribute does


## +/- button: 44x44 so it is easy to hit with a thumb.
func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(44, 44)
	return b


func _points_left() -> int:
	var used := 0
	for id in _points:
		used += _points[id]
	return AthleteFactory.POINT_POOL - used


# --- Step 5: summary ------------------------------------------------------------------

func _build_summary() -> void:
	var a := _build_athlete()
	_content.add_child(UIKit.label(a.full_name(), "TitleLabel"))
	var club := Data.get_club(a.club_id)
	var facts := [
		["Born", "%s (age %d)" % [UIKit.format_date(a.birth_date), a.age_on(Game.START_DATE)]],
		["Hometown", a.hometown],
		["Club", club.get("name", "")],
		["Main event", Data.get_event(a.main_event).name],
		["Height / weight", "%d cm / %d kg" % [a.height_cm, a.weight_kg]],
		["Development", {"early": "Early developer", "average": "Average", "late": "Late developer"}[a.maturation]],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 8)
	for f in facts:
		grid.add_child(UIKit.label(f[0], "MutedLabel"))
		grid.add_child(UIKit.label(f[1]))
	_content.add_child(UIKit.panel(grid))

	var columns := UIKit.flex(16)
	for category in ATTRIBUTE_CATEGORIES:
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(category.to_upper(), "CaptionLabel"))
		for attr in Data.attributes_in(category):
			col.add_child(UIKit.attr_row(attr.name, a.get_attr(attr.id), 0, attr.description))
		var p := UIKit.panel(col, 16)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		columns.add_child(p)
	_content.add_child(columns)


# --- Athlete building -------------------------------------------------------------------

func _create_base_athlete() -> Athlete:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	return AthleteFactory.create(_choices, rng)


func _build_athlete() -> Athlete:
	var a := _create_base_athlete()
	for id in _points:
		a.set_attr(id, a.get_attr(id) + _points[id])
	return a


## A birthday that makes the athlete 14 on the career start date (born Jan–Oct 2012).
func _random_birth_date() -> Dictionary:
	var year: int = Game.START_DATE.year - 14
	return {"year": year, "month": randi_range(1, Game.START_DATE.month - 1), "day": randi_range(1, 28)}
