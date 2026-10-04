extends SceneTree

func _initialize() -> void:
	print("pow(1e-200,7)=", pow(1e-200, 7))
	print("pow(1e-200,15)=", pow(1e-200, 15))
	print("min_normal=", 2.2250738585072014e-308)
	print("lt=", pow(1e-200, 7) < 2.2250738585072014e-308)
	var load_result := MoveTable.load_default()
	var solver := ComboSolver.new(load_result.moves)
	var move_id := ""
	for id in solver._table:
		var move := solver._table[id] as MoveData
		if move != null and not move.hit_profiles.is_empty() and move.hit_profiles[0].reaction == HitProfile.Reaction.GROUND_BOUNCE:
			move_id = id
			break
	print("bounce=", move_id)
	ComboSolver._test_cycle_factor_override = {"BOUNCE_HIT_TIME_SCALE": 1e-200}
	var inv := solver._cycle_invariant([move_id])
	print("applies=", inv.applies(), " failed=", inv.failed_precondition, " hits=", inv.hits_per_lap)
	var factors := solver._cycle_time_factors()
	for k in factors:
		print("factor ", k, " = ", factors[k])
	quit(0)
