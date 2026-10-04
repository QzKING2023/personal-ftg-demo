extends SceneTree

func _initialize() -> void:
	var loaded := MoveTable.load_default()
	var solver := ComboSolver.new(loaded.moves)
	var contexts := solver._build_contexts()
	var ids: Array[String] = ["2C", "6D", "jC", "j6D", "5B"]
	var kinds := {"6D|jC": ComboSolver.EdgeKind.AIR_EXIT, "j6D|5B": ComboSolver.EdgeKind.NORMAL_LINK}
	var results := []
	for disabled in [false, true]:
		ComboSolver._delay_prefix_restore_disabled = disabled
		solver.clear_transition_memo()
		var t := Time.get_ticks_msec()
		var cycle := solver._simulate_cycle(ids, contexts, kinds)
		print("disabled=", disabled, " ms=", Time.get_ticks_msec()-t, " reason=", cycle.reason)
		results.append(ComboSolver._freeze_cycle(cycle))
	var equal: bool = results[0] == results[1]
	print("PASS cycle equality" if equal else "FAIL cycle equality")
	quit(0 if equal else 1)

