extends SceneTree

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics := AcceptanceSolverMetrics.new()


func _initialize() -> void:
	ComboSolver.set_result_cache_enabled(false)
	var live := ComboSolver.solve(null)
	var live_fp := _metrics._fingerprint(live)
	print("live(cache-off) ", live_fp.substr(0, 16))
	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	var thawed := ComboSolver.solve(null)
	print("thawed(cache-on) ", _metrics._fingerprint(thawed).substr(0, 16))
	print("P4 baseline      e071fdc661bffe47")
	quit(0)
