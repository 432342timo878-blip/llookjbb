class_name RacePerformance
## Turns attributes into 800 m race ability and times. Tuning lives in data/races.json.


## 800 m ability on the 1–20 scale: weighted mix of the attributes that matter for the event.
static func ability(a: Athlete) -> float:
	var weights: Dictionary = Data.races.ability_weights
	var total := 0.0
	for id in weights:
		if id.begins_with("_"):
			continue
		total += a.get_attr(id) * float(weights[id])
	return total


## Even-effort 800 m time (seconds) for an ability level, interpolated between the data anchors.
static func time_for(ability_value: float, gender: String) -> float:
	var anchors: Array = Data.races.time_anchors[gender]
	if ability_value <= anchors[0][0]:
		return float(anchors[0][1])
	for i in range(1, anchors.size()):
		var lo: Array = anchors[i - 1]
		var hi: Array = anchors[i]
		if ability_value <= hi[0]:
			var t: float = (ability_value - lo[0]) / (hi[0] - lo[0])
			return lerpf(lo[1], hi[1], t)
	return float(anchors.back()[1])


## Inverse of time_for: the ability that runs this time.
static func ability_for_time(seconds: float, gender: String) -> float:
	var lo := 1.0
	var hi := 20.0
	for i in 30:
		var mid := (lo + hi) / 2.0
		if time_for(mid, gender) > seconds:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


## Everything the race engine needs to know about the player.
static func player_profile(a: Athlete) -> Dictionary:
	return {
		"ability": ability(a),
		"speed": a.get_attr("speed"),
		# Fast-twitch runners carry a bigger anaerobic reserve relative to their engine.
		"anaerobic": clampf((a.get_attr("speed_endurance") + a.get_attr("speed")) / 2.0
				- (a.get_attr("aerobic_capacity") + a.get_attr("lactate_threshold")) / 2.0, -6.0, 6.0),
		"tactics": a.get_attr("race_tactics"),
		"consistency": a.get_attr("consistency"),
		"composure": a.get_attr("composure"),
		"competitiveness": a.get_attr("competitiveness"),
		"determination": a.get_attr("determination"),   # how deep you dig to hang on (rivals: competitiveness)
	}
