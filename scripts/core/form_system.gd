class_name FormSystem
extends GameSystem
## Race-day form (GDD 4.8 "Form"). Keeps sharpness 0-100: each played day it fades by `decay` and gains the
## `sharp` value of the sessions done (times the day's intensity effect; a race counts its own `sharp`).
## On race morning, form = a sharpness term + a freshness term (from fatigue), as a share of race time
## (+ = faster). No dice. All numbers are in data/form.json. `enabled` switches it all off (form 0).

static var enabled := true

var sharpness := 0.0
var started := false   # false until the first played day; an old save (or a new career) starts at `start`


func _init() -> void:
	id = "form"
	sharpness = float(Data.form.sharpness.start)


func on_health(ctx: Dictionary) -> void:
	if not enabled:
		return
	started = true
	var rec: Dictionary = ctx.record
	var cfg: Dictionary = Data.form.sharpness
	var gain := 0.0
	if rec.race != "":
		gain = float(Data.competitions.race_session.get("sharp", 0.0))
	else:
		var effect := float(Training.intensity(rec.intensity).effect)
		for sid in rec.sessions:
			gain += float(Data.get_session(sid).get("sharp", 0.0)) * effect
	sharpness = clampf(sharpness * float(cfg.decay) + gain, 0.0, float(cfg.max))


# --- The numbers ---------------------------------------------------------------------------------

## The sharpness part of form (a share of race time, + = faster) for a sharpness value.
static func sharp_term(s: float) -> float:
	var cfg: Dictionary = Data.form.sharp_term
	var neutral := float(Data.form.sharpness.neutral)
	var low := float(cfg.at_zero)
	var cap := float(cfg.cap)
	if s <= neutral:
		return lerpf(low, 0.0, s / neutral)
	return minf(cap, cap * (s - neutral) / (neutral * (float(cfg.cap_at) - 1.0)))


## The freshness part of form for a fatigue value.
static func fresh_term(fatigue: float) -> float:
	var cfg: Dictionary = Data.form.fresh_term
	var full := float(cfg.full_below)
	var zero := float(cfg.zero_at)
	if fatigue <= full:
		return float(cfg.max)
	if fatigue >= zero:
		return 0.0
	return float(cfg.max) * (zero - fatigue) / (zero - full)


## Form for a sharpness and fatigue (a share of race time, capped; + = faster).
static func form_for(s: float, fatigue: float) -> float:
	var total: Dictionary = Data.form.total
	return clampf(sharp_term(s) + fresh_term(fatigue), float(total.min), float(total.max))


## Form if the athlete raced now (the state after the last played day). 0 when the model is off.
func race_form(fatigue: float) -> float:
	if not enabled:
		return 0.0
	return form_for(sharpness, fatigue)


## The word for a form share and fatigue: {id, name, color, text, helps}. "Tired" wins when fatigue is high.
static func word_for(share: float, fatigue: float) -> Dictionary:
	if fatigue > float(Data.form.tired_above):
		return Data.form.tired
	for w in Data.form.words:
		if share >= float(w.min):
			return w
	return Data.form.words[-1]


## What the Today card and the race cards show: {word, share, sharp, fresh, color, text, helps}. Empty when off.
func info(fatigue: float) -> Dictionary:
	if not enabled:
		return {}
	var share := form_for(sharpness, fatigue)
	var w := word_for(share, fatigue)
	return {"word": w.name, "id": w.id, "share": share, "sharp": sharp_term(sharpness), "fresh": fresh_term(fatigue),
			"color": Color(str(w.color)), "text": w.text, "helps": w.helps}


# --- Save / load ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not started:
		return {}
	return {"started": true, "sharpness": sharpness}


## An empty state (an old save) starts at the neutral sharpness on the next played day.
func from_dict(d: Dictionary) -> void:
	if not d.get("started", false):
		return
	started = true
	sharpness = float(d.sharpness)
