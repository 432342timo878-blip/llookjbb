class_name Rankings
## Season ranking list of the player's age class: season bests of the player and the fictional rivals.
## A statistics season is the calendar year, as in real result lists, season bests and the SM standards (GDD 4.3.1
## decision 30): the indoor season of Jan–Mar and the summer after it count together. (The training year still
## starts on 1 Nov: SeasonPlan.)


## 2027 for any date in 2027.
static func season_of(d: Dictionary) -> int:
	return int(d.year)


## "2027"
static func season_label(season: int) -> String:
	return str(season)


## The player's best time of the season in their main event, or 0.0 (races without a time don't count).
static func player_season_best(a: Athlete, season: int) -> float:
	var best := 0.0
	for r in a.results:
		if r.get("status", "") != "" or float(r.time) <= 0.0:
			continue
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
