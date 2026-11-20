extends SceneTree
const Leaderboard = preload("res://src/leaderboard.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Expected an output path")
		quit(2)
		return
	var board := Leaderboard.new()
	var error := Leaderboard.write(args[0], board.entries())
	if error != OK:
		printerr(error_string(error))
	quit(0 if error == OK else 1)
