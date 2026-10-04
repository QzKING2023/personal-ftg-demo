extends SceneTree

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

## The old P5 probe read profile counters after two direct _analyze calls.
## _analyze is an internal phase and does not reset request counters; solve()
## does. Reset explicitly here so each side is an independent measurement.

func _initialize() -> void:
	var loaded := MoveTable.load_default()
	if not loaded.ok:
		print("FAIL manifest load")
		quit(1)
		return
	var solver := ComboSolver.new(loaded.moves)
	var values := []
	for disabled in [true, false]:
		solver.clear_transition_memo()
		ComboSolver.clear_edge_probe_cache()
		ComboSolver._route_leaf_memo_disabled = disabled
		ComboSolver._profile_v2_reset()
		var report := solver._analyze(1, null, true, ComboSolver.SolverSpatialData.new())
		var profile := ComboSolver.last_request_profile_v2()
		values.append(profile)
		print("disabled=", disabled, " fingerprint=", AcceptanceSolverMetrics.new()._fingerprint(report))
		for key in ["session_steps", "prefix_restores", "spatial_rechecks", "delay_dfs_leaves"]:
			print(key, "=", int(profile[key]))
	var equal_counts := true
	for key in ["session_steps", "spatial_rechecks", "delay_dfs_leaves"]:
		if int(values[0][key]) != int(values[1][key]):
			equal_counts = false
	print("PASS independent measurement" if equal_counts else "FAIL independent measurement")
	quit(0 if equal_counts else 1)
