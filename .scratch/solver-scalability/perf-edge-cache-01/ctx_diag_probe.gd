extends SceneTree

## 定位 6D/2D AIR_EXIT 探针键在两次同型 solve 间的漂移源：单面向双跑，dump
## from∈{6D,2D} 的全部探针记录（键摘要 + 完整上下文签名文本）。
## godot --headless --path . -s res://.scratch/solver-scalability/perf-edge-cache-01/ctx_diag_probe.gd

func _initialize() -> void:
	ComboSolver.set_result_cache_enabled(false)
	ComboSolver.clear_edge_probe_cache()
	var run_a := _logged_solve()
	var run_b := _logged_solve()
	_dump("A", run_a)
	_dump("B", run_b)
	var a_keys := {}
	for record in run_a:
		a_keys[record["key"]] = record
	for record in run_b:
		if not a_keys.has(record["key"]):
			print("=== B-MISS %s>%s kind=%d" % [record["from"], record["to"], record["kind"]])
			print("  B ctxsig: %s" % record["ctxsig"])
			for other in run_a:
				if other["from"] == record["from"] and other["to"] == record["to"] and other["kind"] == record["kind"]:
					print("  A ctxsig: %s" % other["ctxsig"])
					break
	ComboSolver._test_edge_probe_log = null
	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	quit(0)


func _logged_solve() -> Array:
	ComboSolver._test_edge_probe_log = []
	var opts := ComboSolver.SolverOptions.new()
	opts.facings = [1]
	ComboSolver.solve(opts)
	var records: Array = ComboSolver._test_edge_probe_log
	ComboSolver._test_edge_probe_log = null
	return records


func _dump(label: String, records: Array) -> void:
	var count := 0
	for record in records:
		if record["from"] == "6D" or record["from"] == "2D":
			count += 1
	print("%s: %d probes total, %d from 6D/2D" % [label, records.size(), count])
