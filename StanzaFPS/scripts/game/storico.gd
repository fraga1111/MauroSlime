extends RefCounted
## STORICO DELLE PARTITE e RECORD, salvati su questo computer (user://storico.json, cioè
## %APPDATA%\Godot\app_userdata\StanzaFPS\storico.json). Ogni partita finita (offline o co-op) aggiunge
## una voce con la classifica di tutti i giocatori (game/punteggi.gd); il menu (STORICO, tasto H)
## mostra i record, la classifica di tutti i tempi per nome del giocatore e le ultime partite.
##
## Una voce: {"data", "modo" ("offline"/"coop"/"tutti contro tutti"), "ondata", "io" (il mio nome),
##            "personaggio", "durata" (secondi), "ondata_top" (i miei punti nella mia ondata migliore),
##            "righe": [{name, char, points, damage, kills, assists, heads, deaths}, ...]}

const FILE := "user://storico.json"
const MAX_ENTRIES := 300


static func load_all() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return data if data is Array else []


static func add(entry: Dictionary) -> void:
	var all := load_all()
	all.append(entry)
	while all.size() > MAX_ENTRIES:
		all.pop_front()
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all, "\t"))


## Partite d'esempio (screenshot e test: tools/check.sh --solo=storico, tools/test_novita.gd).
static func example() -> Array:
	return [
		{"data": "2026-11-01T20:00:00", "modo": "coop", "ondata": 6, "io": "Mauro", "ondata_top": 400,
			"righe": [{"name": "Mauro", "char": 0, "points": 900, "damage": 90.0, "kills": 9, "assists": 2, "heads": 3, "deaths": 1},
					{"name": "Matteo", "char": 3, "points": 700, "damage": 70.0, "kills": 7, "assists": 5, "heads": 1, "deaths": 1}]},
		{"data": "2026-11-02T20:00:00", "modo": "offline", "ondata": 4, "io": "Matteo", "ondata_top": 500,
			"righe": [{"name": "Matteo", "char": 3, "points": 1200, "damage": 120.0, "kills": 12, "assists": 0, "heads": 4, "deaths": 1}]},
	]


## Classifica di tutti i tempi: una riga per nome di giocatore, ordinata per uccisioni.
## [{name, partite, points, kills, assists, damage, heads, best, best_wave}, ...]
static func leaderboard(all: Array) -> Array:
	var by := {}
	for e in all:
		for r in e.get("righe", []):
			var n := String(r.get("name", "?"))
			if not by.has(n):
				by[n] = {"name": n, "partite": 0, "points": 0, "kills": 0, "assists": 0, "damage": 0.0,
						"heads": 0, "best": 0, "best_wave": 0}
			var b: Dictionary = by[n]
			b["partite"] += 1
			b["points"] += int(r.get("points", 0))
			b["kills"] += int(r.get("kills", 0))
			b["assists"] += int(r.get("assists", 0))
			b["damage"] += float(r.get("damage", 0.0))
			b["heads"] += int(r.get("heads", 0))
			b["best"] = maxi(int(b["best"]), int(r.get("points", 0)))
			b["best_wave"] = maxi(int(b["best_wave"]), int(e.get("ondata", 0)))
	var out := by.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kills"] != b["kills"]:
			return a["kills"] > b["kills"]
		return a["points"] > b["points"])
	return out


## Record: [[titolo, valore, chi / quando], ...]
static func records(all: Array) -> Array:
	var out := []
	var best_wave := {"v": 0, "who": ""}
	var best_pts := {"v": 0, "who": ""}
	var best_kills := {"v": 0, "who": ""}
	var best_assists := {"v": 0, "who": ""}
	var best_heads := {"v": 0, "who": ""}
	var best_team := {"v": 0, "who": ""}
	var best_wave_pts := {"v": 0, "who": ""}
	var kills := 0
	for e in all:
		var when := String(e.get("data", "")).substr(0, 10)
		var w := int(e.get("ondata", 0))
		var names := []
		var team := 0
		for r in e.get("righe", []):
			names.append(String(r.get("name", "?")))
			team += int(r.get("points", 0))
			kills += int(r.get("kills", 0))
			_better(best_pts, int(r.get("points", 0)), "%s · %s" % [r.get("name", "?"), when])
			_better(best_kills, int(r.get("kills", 0)), "%s · %s" % [r.get("name", "?"), when])
			_better(best_assists, int(r.get("assists", 0)), "%s · %s" % [r.get("name", "?"), when])
			_better(best_heads, int(r.get("heads", 0)), "%s · %s" % [r.get("name", "?"), when])
		_better(best_wave, w, "%s · %s" % [", ".join(names), when])
		_better(best_team, team, "%s · %s" % [", ".join(names), when])
		_better(best_wave_pts, int(e.get("ondata_top", 0)), "%s · %s" % [e.get("io", "?"), when])
	out.append(["Ondata più alta", str(best_wave["v"]), best_wave["who"]])
	out.append(["Più punti in una partita", str(best_pts["v"]), best_pts["who"]])
	out.append(["Più punti in una sola ondata", str(best_wave_pts["v"]), best_wave_pts["who"]])
	out.append(["Più punti di squadra", str(best_team["v"]), best_team["who"]])
	out.append(["Più uccisioni in una partita", str(best_kills["v"]), best_kills["who"]])
	out.append(["Più assist in una partita", str(best_assists["v"]), best_assists["who"]])
	out.append(["Più colpi in testa in una partita", str(best_heads["v"]), best_heads["who"]])
	out.append(["Partite giocate · uccisioni totali", "%d · %d" % [all.size(), kills], ""])
	return out


static func _better(rec: Dictionary, v: int, who: String) -> void:
	if v > int(rec["v"]):
		rec["v"] = v
		rec["who"] = who
