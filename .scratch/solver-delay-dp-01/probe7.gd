extends SceneTree

func _initialize() -> void:
	var result := MoveTable.load_default()
	var solver := ComboSolver.new(result.moves)
	for move_id in solver._table:
		var move := solver._table[move_id] as MoveData
		if move == null or move.stance != MoveData.Stance.AIR:
			continue
		print("air=", move_id, " landing=", move.landing_cancel_targets, " cancel=", move.cancel_targets, " hit_landing=", move.hit_landing_cancel_targets)
	quit(0)
