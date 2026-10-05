class_name Rankings
## Season ranking list of the player's age class: season bests of the player and the fictional rivals.
## A season is a training year, 1 Nov – 31 Oct (the career starts on 2 Nov), so indoor and outdoor
## results of the same winter + summer count together.


## 2026 for any date from 1 Nov 2026 to 31 Oct 2027.
static func season_of(d: Dictionary) -> int:
	return int(d.year) if int(d.month) >= 11 else int(d.year) - 1


## "2026–27"
static func season_label(season: int) -> String:
	return "%d–%02d" % [season, (season + 1) % 100]


## The player's best time of the season in their main event, or 0.0.
static func player_season_best(a: Athlete, season: int) -> float:
	var best := 0.0
	for r in a.results:
		if r.event == a.main_event and season_of(Game.int_date(r.date)) == season:
			if best == 0.0 or float(r.time) < best:
				best = float(r.time)
	return best


## Everyone with a season best, fastest first: [{rank, name, club, time, is_player}].
static func season_list(a: Athlete, rivals: Array, season: int) -> Array:
	var rows := []
	for r in rivals:
		if int(r.get("sb_season", -1)) == season:
			rows.append({"name": Rivals.full_name(r), "club": Data.get_club(r.club_id).get("name", ""),
					"time": float(r.sb), "is_player": false})
	var mine := player_season_best(a, season)
	if mine > 0.0:
		rows.append({"name": a.full_name(), "club": Data.get_club(a.club_id).get("name", ""),
				"time": mine, "is_player": true})
	rows.sort_custom(func(x, y): return x.time < y.time)
	for i in rows.size():
		rows[i].rank = i + 1
	return rows
