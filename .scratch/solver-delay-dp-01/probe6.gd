extends SceneTree

func _initialize() -> void:
	var result := MoveTable.load_default()
	var solver := ComboSolver.new(result.moves)
	for move_id in solver._table:
		var move := solver._table[move_id] as MoveData
		if move == null or move.segment_count() < 2:
			continue
		print("multiseg=", move_id, " stance=", move.stance, " segs=", move.segment_count())
		print("  cancel=", move.cancel_targets, " chain=", move.chain_cancel_targets, " special=", move.special_cancel_targets, " jump=", move.jump_cancel_targets, " link=", move.link_targets, " landing=", move.landing_cancel_targets)
	## 谁指向多段招式？
	var contexts := solver._build_contexts()
	for from_id in solver._table:
		var move := solver._table[from_id] as MoveData
		if move == null or not contexts.has(from_id):
			continue
		for field in ["cancel_targets", "chain_cancel_targets", "special_cancel_targets", "link_targets"]:
			var targets = move.get(field)
			if targets == null:
				continue
			for to_id in targets:
				var target := solver._table[to_id] as MoveData
				if target != null and target.segment_count() >= 2:
					print("into multiseg: ", from_id, " --", field, "--> ", to_id, " from_stance=", move.stance)
	quit(0)
