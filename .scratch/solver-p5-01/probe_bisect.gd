extends SceneTree

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics := AcceptanceSolverMetrics.new()


func _fp(tag: String) -> String:
	ComboSolver.clear_result_cache()
	var report := ComboSolver.solve(null)
	var fp := _metrics._fingerprint(report)
	print(tag, " ", fp.substr(0, 16))
	return fp


func _initialize() -> void:
	var base := _fp("default        ")
	ComboSolver._route_leaf_memo_disabled = true
	var no_leaf := _fp("leaf-off       ")
	ComboSolver._route_leaf_memo_disabled = false
	ComboSolver._cycle_enum_legacy = true
	var legacy_enum := _fp("cycle-legacy   ")
	ComboSolver._cycle_enum_legacy = false
	ComboSolver._delay_prefix_restore_disabled = true
	var no_restore := _fp("restore-off    ")
	ComboSolver._delay_prefix_restore_disabled = false
	print("P4 baseline solve-1 = e071fdc661bffe47")
	quit(0)
