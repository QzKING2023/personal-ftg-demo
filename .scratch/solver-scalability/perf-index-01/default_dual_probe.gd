extends SceneTree
## P1（perf-index）默认表（共享 manifest）双路径差分探针：
##   - 索引路径（当前默认）与旧路径（_compiled_index_disabled=true）各跑一次
##     冷缓存 solve()，断言全语义指纹全等——rekka/charge/air_exit/命中落地等
##     增长夹具未覆盖的反向表与枚举路径在真实表上对拍；
##   - 归档两路径的 v1/v2 profile、边/缺口/路线计数与墙钟（增长口径对照
##     perf-gate-01/default-table-profile.json）。
## 运行：godot --headless --path . -s res://.scratch/solver-scalability/perf-index-01/default_dual_probe.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

func _initialize() -> void:
	print("")
	var metrics = AcceptanceSolverMetrics.new()
	var index_run := _run_path(metrics, false)
	var legacy_run := _run_path(metrics, true)
	var equal: bool = index_run["fingerprint"] == legacy_run["fingerprint"]
	print("INDEX_DEFAULT_DUAL_JSON=" + JSON.stringify({
		"fingerprint_equal": equal,
		"fingerprint_index": index_run["fingerprint"],
		"fingerprint_legacy": legacy_run["fingerprint"],
		"index": index_run["payload"],
		"legacy": legacy_run["payload"],
	}))
	if not equal:
		print("DIFFERENTIAL FAILED: index path is not report-identical to the legacy scan path")
		quit(1)
	quit(0)


func _run_path(metrics, legacy_path: bool) -> Dictionary:
	ComboSolver.clear_result_cache()
	ComboSolver._compiled_index_disabled = legacy_path
	var started := Time.get_ticks_usec()
	var report: ComboSolver.SolverReport = metrics.solve(null)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	ComboSolver._compiled_index_disabled = false
	var payload := {
		"elapsed_ms": elapsed_ms,
		"v1": ComboSolver.last_request_profile(),
		"v2": ComboSolver.last_request_profile_v2(),
		"edges": report.edges.size(),
		"gaps": report.gaps.size(),
		"routes": report.routes.size(),
		"cycles": report.cycles.size(),
	}
	return {"fingerprint": metrics._fingerprint(report), "payload": payload}
