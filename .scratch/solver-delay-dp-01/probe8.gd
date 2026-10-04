extends SceneTree

func _initialize() -> void:
	var result := MoveTable.load_default()
	var solver := ComboSolver.new(result.moves)
	for move_id in ["5D", "2C", "214C"]:
		var move := solver._table[move_id] as MoveData
		if move == null:
			continue
		print(move_id, " special=", move.special_cancel_targets, " cancel=", move.cancel_targets, " chain=", move.chain_cancel_targets, " jump=", move.jump_cancel_targets)
	quit(0)
