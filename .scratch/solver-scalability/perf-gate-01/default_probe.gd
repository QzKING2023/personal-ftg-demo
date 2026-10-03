extends SceneTree
## P0 默认表（共享 manifest）单请求 v1/v2 profile 基线采样。
const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

func _initialize() -> void:
	var metrics = AcceptanceSolverMetrics.new()
	var started := Time.get_ticks_usec()
	ComboSolver.clear_result_cache()
	var report := metrics.solve(null)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	print("DEFAULT_TABLE_PROFILE_JSON=" + JSON.stringify({
		"elapsed_ms": elapsed_ms,
		"v1": ComboSolver.last_request_profile(),
		"v2": ComboSolver.last_request_profile_v2(),
		"fingerprint_sha256": metrics._fingerprint(report),
		"edges": report.edges.size(),
		"routes": report.routes.size(),
		"gaps": report.gaps.size(),
		"cycles": report.cycles.size(),
	}))
	quit(0)
