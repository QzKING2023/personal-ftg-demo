extends SceneTree

## P5 探针：默认表单面向 _analyze（含空间）在叶登记开关两侧的确定性计数
## 与指纹对比——默认域「重复遍历减少量」的证据口径。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics := AcceptanceSolverMetrics.new()


func _initialize() -> void:
	var loaded := MoveTable.load_default()
	if not loaded.ok:
		print("FAIL manifest load")
		quit(1)
		return
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	ComboSolver._route_leaf_memo_disabled = true
	var off := ComboSolver.new(loaded.moves)._analyze(1, null, true, ComboSolver.SolverSpatialData.new())
	var off_counts := ComboSolver.last_request_profile_v2()
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	ComboSolver._route_leaf_memo_disabled = false
	var on := ComboSolver.new(loaded.moves)._analyze(1, null, true, ComboSolver.SolverSpatialData.new())
	var on_counts := ComboSolver.last_request_profile_v2()
	print("fingerprint_equal=", _metrics._fingerprint(off) == _metrics._fingerprint(on))
	for key in ["session_steps", "prefix_restores", "prefix_frozen_returns", "spatial_rechecks", "delay_dfs_leaves"]:
		print("%s: off=%d on=%d" % [key, int(off_counts[key]), int(on_counts[key])])
	quit(0)
