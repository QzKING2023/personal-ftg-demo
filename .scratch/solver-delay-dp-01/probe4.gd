extends SceneTree

func _initialize() -> void:
	var load_result := MoveTable.load_default()
	var solver := ComboSolver.new(load_result.moves)
	var edges := {}
	for from_id in solver._table:
		var move := solver._table[from_id] as MoveData
		if move == null:
			continue
		var kinds := {
			"cancel_targets": ComboSolver.EdgeKind.CANCEL,
			"chain_cancel_targets": ComboSolver.EdgeKind.CHAIN_CANCEL,
			"jump_cancel_targets": ComboSolver.EdgeKind.JUMP_CANCEL,
			"landing_cancel_targets": ComboSolver.EdgeKind.LANDING_CANCEL,
			"link_targets": ComboSolver.EdgeKind.NORMAL_LINK,
		}
		for field in kinds:
			var targets = move.get(field)
			if targets == null:
				continue
			for to_id in targets:
				edges["%s|%s" % [from_id, to_id]] = kinds[field]
	var cycles := []
	for key in edges:
		var parts: PackedStringArray = key.split("|")
		var back := "%s|%s" % [parts[1], parts[0]]
		if edges.has(back) and parts[0] < parts[1]:
			cycles.append([parts[0], parts[1], edges[key], edges[back]])
	print("two-move configured cycles=", cycles.size())
	for c in cycles:
		var kind_a: int = c[2]
		var kind_b: int = c[3]
		var has_air_seam: bool = kind_a == ComboSolver.EdgeKind.JUMP_CANCEL or kind_b == ComboSolver.EdgeKind.JUMP_CANCEL \
				or kind_a == ComboSolver.EdgeKind.LANDING_CANCEL or kind_b == ComboSolver.EdgeKind.LANDING_CANCEL
		if has_air_seam:
			print("AIR cycle: ", c)
	quit(0)
