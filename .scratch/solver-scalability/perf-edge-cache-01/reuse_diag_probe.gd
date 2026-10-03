extends SceneTree

## P2 证据补充探针：跨入口复用（solve → analyze）命中率与「热跑 4 个残留 miss」
## 的键级诊断。完整结果缓存全程旁路。运行（独立 APPDATA）：
## godot --headless --path . -s res://.scratch/solver-scalability/perf-edge-cache-01/reuse_diag_probe.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics = AcceptanceSolverMetrics.new()


func _initialize() -> void:
	print("")
	ComboSolver.set_result_cache_enabled(false)

	ComboSolver._edge_probe_cache_disabled = true
	var analyze_ref_fingerprint := _metrics._fingerprint(ComboSolver.analyze())
	ComboSolver._edge_probe_cache_disabled = false

	ComboSolver.clear_edge_probe_cache()
	var solve_a := _logged(ComboSolver.solve)
	var solve_b := _logged(ComboSolver.solve)
	var analyze_c := _logged(ComboSolver.analyze)

	var a_keys := _key_set(solve_a)
	var b_missing: Array = []
	for record in solve_b:
		if not a_keys.has(record["key"]):
			b_missing.append(record)
	var c_missing: Array = []
	var c_keys := _key_set(analyze_c)
	for record in analyze_c:
		if not a_keys.has(record["key"]):
			c_missing.append(record)

	print("solve A probes: %d  solve B probes: %d  analyze C probes: %d" % [solve_a.size(), solve_b.size(), analyze_c.size()])
	print("analyze ref fingerprint: %s" % analyze_ref_fingerprint)
	print("solve B keys missing from A: %d" % b_missing.size())
	for record in b_missing:
		print("  B-MISS %s>%s kind=%d gap=%s" % [record["from"], record["to"], record["kind"], record["gap"]])
	print("analyze C keys missing from A: %d" % c_missing.size())
	for record in c_missing:
		print("  C-MISS %s>%s kind=%d gap=%s" % [record["from"], record["to"], record["kind"], record["gap"]])
	print("stats: %s" % JSON.stringify(ComboSolver.edge_probe_cache_stats()))
	ComboSolver._test_edge_probe_log = null
	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	quit(0)


func _logged(callable: Callable) -> Array:
	ComboSolver._test_edge_probe_log = []
	var result = callable.call()
	var records: Array = ComboSolver._test_edge_probe_log
	ComboSolver._test_edge_probe_log = null
	print("fingerprint %s" % _metrics._fingerprint(result))
	print("  counts %s" % JSON.stringify(ComboSolver.last_request_profile_v2()))
	return records


func _key_set(records: Array) -> Dictionary:
	var keys := {}
	for record in records:
		keys[record["key"]] = true
	return keys
