extends SceneTree

func _initialize() -> void:
	var result := MoveTable.load_default()
	print("ok=", result.ok, " moves=", result.moves.size() if result.ok else -1, " err=", result.first_error() if not result.ok else "")
	quit(0)
