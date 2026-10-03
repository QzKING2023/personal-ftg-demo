extends SceneTree

## 夹具级空间分层差分：spatial solve 在探针缓存关/开(冷/热)三形态下指纹全等。
## godot --headless --path . -s res://.scratch/solver-scalability/perf-edge-cache-01/spatial_diff_probe.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const Fixture = preload("res://tests/solver_growth_fixture.gd")

var _metrics = AcceptanceSolverMetrics.new()


func _initialize() -> void:
	ComboSolver.set_result_cache_enabled(false)
	var table := Fixture.new().table(4)
	var fingerprints := []
	for mode in ["off", "cold", "hot"]:
		ComboSolver._edge_probe_cache_disabled = mode == "off"
		if mode == "cold":
			ComboSolver.clear_edge_probe_cache()
		var opts := ComboSolver.SolverOptions.new()
		opts.move_table = table
		opts.spatial = ComboSolver.SolverSpatialData.new()
		var report := ComboSolver.solve(opts)
		fingerprints.append(_metrics._fingerprint(report))
		print("%s: %s spatial_rechecks=%d" % [mode, fingerprints[fingerprints.size() - 1],
			int(ComboSolver.last_request_profile_v2()["spatial_rechecks"])])
	ComboSolver._edge_probe_cache_disabled = false
	var equal: bool = fingerprints[0] == fingerprints[1] and fingerprints[1] == fingerprints[2]
	if equal:
		print("PASS  spatial solve fingerprints identical across cache off/cold/hot")
	else:
		print("FAIL  spatial solve fingerprint mismatch")
	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	quit(0 if equal else 1)
