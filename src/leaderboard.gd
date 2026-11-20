extends RefCounted

var path: String

func _init(storage_path: String = "user://leaderboard.json") -> void:
	path = storage_path

static func valid_name(value: String) -> bool:
	var pattern := RegEx.create_from_string("^[A-Za-z0-9_]{3,12}$")
	var result := pattern.search(value)
	return result != null and result.get_string() == value

func entries() -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return []
	var data: Variant = parser.data
	if not data is Dictionary or not data.get("entries") is Array:
		return []
	var ranking: Array = []
	for entry in data.entries:
		if entry is Dictionary and valid_name(str(entry.get("name", ""))) and entry.has("score") and entry.has("achieved_at"):
			ranking.append(entry)
	return ranking

func record(name: String, points: int, nights: int, seed_value: int) -> Error:
	if not valid_name(name):
		return ERR_INVALID_PARAMETER
	var ranking := entries()
	var entry := {"name": name, "score": points, "nights_won": nights,
		"achieved_at": Time.get_datetime_string_from_system(true) + "Z", "seed": seed_value}
	var index := 0
	while index < ranking.size() and (ranking[index].score > points or (
		ranking[index].score == points and ranking[index].achieved_at <= entry.achieved_at
	)):
		index += 1
	ranking.insert(index, entry)
	if ranking.size() > 10:
		ranking.resize(10)
	var tmp := path + ".tmp"
	var error := write(tmp, ranking)
	if error != OK:
		return error
	return DirAccess.rename_absolute(tmp, path)

static func write(destination: String, ranking: Array) -> Error:
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"entries": ranking}, "  ") + "\n")
	var error := file.get_error()
	file.close()
	return error
