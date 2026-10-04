extends SceneTree

func _initialize() -> void:
	var table := MoveData.default_table()
	(table["jB"] as MoveData).landing_cancel_targets = ["5D", "5A"]
	var solver := ComboSolver.new(table)
	solver.reset_delay_dp_stats()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	var t0 := Time.get_ticks_msec()
	var report := ComboSolver.solve(opts)
	var dt := Time.get_ticks_msec() - t0
	print("solve ms=", dt, " refused=", report.refused)
	print("dp_stats=", solver.delay_dp_stats())
	print("cycles=", report.cycles.size(), " incomplete=", report.incomplete_cycle_count)
	quit(0)
