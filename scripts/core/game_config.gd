class_name GameConfig
extends RefCounted
## The one place that says which parts of the game are on (fix session after the check-in 2026-10-18). Before this, 18 static
## switches were set one by one: seven systems were OFF unless main.gd switched them on, and every balance tool pinned four
## "neutral" switches of its own, so the tools measured a game the player never plays. Now there are two named presets and every
## program picks one in one line:
##
##   real = the game the player plays (what main.gd switched on): every system on, the coach and the moods and the school
##          free, the talks, proposals, goals, suggestions, the market, the school's decisions and the people on.
##   lab  = the neutral game of the fingerprints: a club coach of 10s, the moods in the middle, the school's life load 0,
##          no injuries, and none of the systems that stop Play week or need an answer (no talk, proposals, goals,
##          suggestions, market, school decisions, people). `training_balance -- 0`, `quick_fingerprint` and
##          `school_fingerprint` are measured in lab.
##
## A tool that needs something else says so in the same line: `GameConfig.use("lab", {"health": true})`. A tool that
## flips one option in the middle of its run (to compare with and without) uses `GameConfig.set_option("mind", false)`.
## The options are the names in OPTIONS below; each maps to a static variable of a system, so a system's own default is only
## what it has before any preset is chosen.
##
## A `-s` tool script cannot name classes that use the autoloads at compile time: load this file instead, e.g.
##   var GC = load("res://scripts/core/game_config.gd")
##   GC.use("lab")
## (This file itself never names another class, so it loads fine that way.)

## option name -> [script, static variable]. (Session notes: `moments` = the moments engine at all, `test_moments` = the test
## storylets of data/storylets, `season_offers` = the coach's "three plans" stop, `form` = the race-day Form.)
const OPTIONS := {
	"health": ["res://scripts/core/health_system.gd", "model_enabled"],
	"coach_model": ["res://scripts/core/coach_system.gd", "model_enabled"],
	"coach_neutral": ["res://scripts/core/coach_system.gd", "neutral_club"],
	"mind": ["res://scripts/core/mind_system.gd", "model_enabled"],
	"mind_neutral": ["res://scripts/core/mind_system.gd", "neutral"],
	"school": ["res://scripts/core/school_system.gd", "model_enabled"],
	"school_neutral": ["res://scripts/core/school_system.gd", "neutral"],
	"school_decisions": ["res://scripts/core/school_system.gd", "decisions_enabled"],
	"form": ["res://scripts/core/form_system.gd", "enabled"],
	"moments": ["res://scripts/core/storylet_system.gd", "enabled"],
	"test_moments": ["res://scripts/core/storylet_system.gd", "include_test"],
	"talks": ["res://scripts/core/storylet_system.gd", "talks_enabled"],
	"people": ["res://scripts/core/storylet_system.gd", "people_enabled"],
	"proposals": ["res://scripts/core/coach_proposals.gd", "enabled"],
	"suggests": ["res://scripts/core/coach_suggests.gd", "enabled"],
	"goals": ["res://scripts/core/season_goals.gd", "enabled"],
	"market": ["res://scripts/core/coach_market.gd", "enabled"],
	"season_offers": ["res://scripts/core/season_system.gd", "offers_enabled"],
}

const PRESETS := {
	"real": {
		"health": true, "coach_model": true, "coach_neutral": false, "mind": true, "mind_neutral": false,
		"school": true, "school_neutral": false, "school_decisions": true, "form": true, "moments": true,
		"test_moments": false, "talks": true, "people": true, "proposals": true, "suggests": true, "goals": true,
		"market": true, "season_offers": true,
	},
	"lab": {
		"health": false, "coach_model": true, "coach_neutral": true, "mind": true, "mind_neutral": true,
		"school": true, "school_neutral": true, "school_decisions": false, "form": true, "moments": true,
		"test_moments": false, "talks": false, "people": false, "proposals": false, "suggests": false, "goals": false,
		"market": false, "season_offers": true,
	},
}

## Fixed dice for the tools (fix session 2026-10-18): 0 = the real game, every career gets its own random dice. A tool that wants the
## SAME career every run (so a check cannot fail by chance) sets `GameConfig.fixed_seed = N`: then the dice a career draws from the
## clock (its rivals, the health, moments and proposals dice, each race's dice) are seeded from N and the order in which they were
## asked instead. The rest of the game already seeds its dice from the career's name and date.
static var fixed_seed := 0
static var _dice_count := 0


## Seeds `rng` from the clock (the real game) or, with `fixed_seed`, from the fixed seed + what it is for + how many were asked.
static func randomize_dice(rng: RandomNumberGenerator, label: String) -> void:
	if fixed_seed == 0:
		rng.randomize()
		return
	_dice_count += 1
	rng.seed = ("%d|%s|%d" % [fixed_seed, label, _dice_count]).hash()


## The preset last chosen with use() ("" = none yet: every system has its own default) and what was changed after it.
static var current := ""
static var changed := {}


## Chooses a preset and sets every option to it, then applies `overrides` ({option: value}). Returns the preset name.
static func use(preset: String, overrides := {}) -> String:
	assert(PRESETS.has(preset), "GameConfig: unknown preset '%s' (real / lab)" % preset)
	var values: Dictionary = PRESETS[preset]
	for name in OPTIONS:
		_write(str(name), bool(values[name]))
	current = preset
	changed = {}
	for name in overrides:
		set_option(str(name), bool(overrides[name]))
	return preset


## Changes one option (it stays in `changed` so describe() tells it).
static func set_option(name: String, value: bool) -> void:
	assert(OPTIONS.has(name), "GameConfig: unknown option '%s'" % name)
	_write(name, value)
	changed[name] = value


## The value of an option right now (read from the system).
static func get_option(name: String) -> bool:
	var o: Array = OPTIONS[name]
	var script = load(str(o[0]))
	return bool(script.get(str(o[1])))


## One line for a tool's output: the preset and what differs from it.
static func describe() -> String:
	var out := "config: %s" % (current if current != "" else "(no preset: each system's own default)")
	if not changed.is_empty():
		var parts := []
		for name in changed:
			parts.append("%s=%s" % [name, "on" if changed[name] else "off"])
		out += " + " + ", ".join(parts)
	return out


static func _write(name: String, value: bool) -> void:
	var o: Array = OPTIONS[name]
	var script = load(str(o[0]))
	script.set(str(o[1]), value)
