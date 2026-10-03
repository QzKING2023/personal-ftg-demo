extends SceneTree

## P0：solver_profile_v2 确定性计数插桩的观测测试（字段 schema、请求级语义、
## 不变量与确定性）。插桩只计数不改搜索——本测试同时钉住两件事：
##   1. v1 耗时分解（last_request_profile）的字段集不被 v2 污染（验收 summary
##      的 profile_totals 契约冻结）；
##   2. v2 计数按调用点口径可复现：同型请求逐字段相等、缓存命中请求零计数、
##      拒绝请求只计 bypass、结构候选恒等式与空间复验精确账面成立。
## 运行：godot --headless --path . -s res://tests/test_solver_perf_profile.gd
## 基线采集：stdout 的 SOLVER_PROFILE_V2_JSON 行即夹具档的完整计数样例。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const Fixture = preload("res://tests/solver_growth_fixture.gd")

const V2_COUNT_KEYS := [
	"structure_candidates", "context_attempts", "edge_built", "gap_built",
	"delay_dfs_nodes", "delay_dfs_leaves", "prefix_restores", "prefix_frozen_returns",
	"session_steps", "cycle_state_snapshots", "spatial_rechecks",
]
const V1_PROFILE_KEYS := [
	"total_ms", "delay_leaf_ms", "delay_leaf_runs", "edge_probe_ms", "edge_probe_runs",
	"gap_enum_ms", "gap_enum_runs", "route_walk_ms", "route_walk_runs",
	"other_ms", "other_runs",
]

var _failures := 0
var _metrics = AcceptanceSolverMetrics.new()


func _initialize() -> void:
	print("")
	_test_schema_stable()
	_test_fixture_counts()
	_test_counts_deterministic()
	_test_cache_hit_request_counts_zero()
	_test_refused_request_counts_bypass_only()
	_test_cycle_snapshots_counted()
	_test_spatial_rechecks_exact()
	print("")
	if _failures == 0:
		print("ALL SOLVER PERF PROFILE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1


# --- 字段契约 ---


func _test_schema_stable() -> void:
	var v2 := ComboSolver.last_request_profile_v2()
	var v2_keys: Array = v2.keys()
	v2_keys.sort()
	var want_v2: Array = (V2_COUNT_KEYS + ["cache_hits", "cache_misses", "cache_bypasses"]).duplicate()
	want_v2.sort()
	_check(v2_keys == want_v2, "profile v2 exposes exactly the documented count fields (%d)" % v2_keys.size())
	var v1 := ComboSolver.last_request_profile()
	var v1_keys: Array = v1.keys()
	v1_keys.sort()
	var want_v1: Array = V1_PROFILE_KEYS.duplicate()
	want_v1.sort()
	_check(v1_keys == want_v1, "profile v1 field set unchanged (acceptance profile_totals contract)")
	_check(not v2_keys.has("total_ms") and not v1_keys.has("structure_candidates"),
		"v1 and v2 profiles stay disjoint (no timing fields in v2, no count fields in v1)")


# --- 夹具请求的计数口径 ---


func _test_fixture_counts() -> void:
	var table := Fixture.new().table(2)
	_check(not table.is_empty(), "growth fixture E=2 builds from the shared manifest")
	if table.is_empty():
		return
	var report := _solve(table)
	var counts := ComboSolver.last_request_profile_v2()
	print("SOLVER_PROFILE_V2_JSON=" + JSON.stringify(counts))
	_check(not report.refused, "fixture E=2 analysis is not refused")
	_check(counts["edge_built"] == 4,
		"edge_built == configured candidates x 2 facings (2 edges x [1,-1] = 4, got %d)" % counts["edge_built"])
	_check(counts["structure_candidates"] == counts["edge_built"] + counts["gap_built"],
		"structure_candidates == edge_built + gap_built (config + gap candidates cover all builds: %d == %d + %d)" % [
			counts["structure_candidates"], counts["edge_built"], counts["gap_built"]])
	_check(counts["gap_built"] > 0, "unconfigured pairs probe gap candidates (gap_built=%d)" % counts["gap_built"])
	_check(counts["context_attempts"] > 0, "context growth attempts counted (%d)" % counts["context_attempts"])
	_check(counts["delay_dfs_nodes"] >= counts["delay_dfs_leaves"] and counts["delay_dfs_leaves"] > 0,
		"delay DFS exercised by the jump-cancel route (nodes=%d >= leaves=%d > 0)" % [
			counts["delay_dfs_nodes"], counts["delay_dfs_leaves"]])
	_check(counts["prefix_restores"] > 0,
		"prefix restore engaged on the air seam (prefix_restores=%d)" % counts["prefix_restores"])
	_check(counts["session_steps"] > 0, "session physics steps counted (%d)" % counts["session_steps"])
	var any_route := false
	for route in report.routes:
		any_route = any_route or route.timing_valid
	_check(any_route, "fixture E=2 produces at least one timing-valid route (fixture stays meaningful)")
	_check(counts["cache_misses"] == 1 and counts["cache_hits"] == 0 and counts["cache_bypasses"] == 0,
		"cold cacheable request books exactly one miss (miss=%d hit=%d bypass=%d)" % [
			counts["cache_misses"], counts["cache_hits"], counts["cache_bypasses"]])


func _test_counts_deterministic() -> void:
	var table := Fixture.new().table(4)
	if table.is_empty():
		_check(false, "growth fixture E=4 builds from the shared manifest")
		return
	_solve(table)
	var counts_first := ComboSolver.last_request_profile_v2()
	_solve(table)
	var counts_second := ComboSolver.last_request_profile_v2()
	_check(counts_first == counts_second,
		"same fixture solved twice (cache cleared) yields identical v2 counts (deterministic search shape)")


# --- 请求级缓存账面 ---


func _test_cache_hit_request_counts_zero() -> void:
	var table := Fixture.new().table(1)
	if table.is_empty():
		_check(false, "growth fixture E=1 builds from the shared manifest")
		return
	ComboSolver.clear_result_cache()
	var first := ComboSolver.solve(_options(table))
	var second := ComboSolver.solve(_options(table))
	var counts := ComboSolver.last_request_profile_v2()
	var zero := true
	for key in V2_COUNT_KEYS:
		zero = zero and int(counts[key]) == 0
	_check(zero, "cache-hit request performs no search work (all eleven counts zero)")
	_check(counts["cache_hits"] == 1 and counts["cache_misses"] == 0 and counts["cache_bypasses"] == 0,
		"cache-hit request books exactly one hit")
	_check(_metrics._fingerprint(first) == _metrics._fingerprint(second),
		"cache-hit report is semantically identical to the computed report")


func _test_refused_request_counts_bypass_only() -> void:
	var report := ComboSolver.analyze_manifest("res://tests/no-such-manifest.tres")
	var counts := ComboSolver.last_request_profile_v2()
	_check(report.refused, "missing manifest path is refused")
	var zero := true
	for key in V2_COUNT_KEYS:
		zero = zero and int(counts[key]) == 0
	_check(zero, "refused request does no search work (all counts zero)")
	_check(counts["cache_hits"] == 0 and counts["cache_misses"] == 0 and counts["cache_bypasses"] == 1,
		"refused request books exactly one bypass (hits+misses+bypasses==calls stays auditable)")


# --- 循环快照与空间复验 ---


func _test_cycle_snapshots_counted() -> void:
	var table := Fixture.new().cycle_table()
	if table.is_empty():
		_check(false, "cycle fixture builds from the shared manifest")
		return
	var report := _solve(table)
	var counts := ComboSolver.last_request_profile_v2()
	_check(not report.refused, "cycle fixture analysis is not refused")
	_check(counts["cycle_state_snapshots"] > 0,
		"two-move cancel cycle drives per-lap settlement snapshots (snapshots=%d)" % counts["cycle_state_snapshots"])


func _test_spatial_rechecks_exact() -> void:
	var table := Fixture.new().table(2)
	if table.is_empty():
		_check(false, "growth fixture E=2 builds from the shared manifest")
		return
	var opts := _options(table)
	opts.spatial = ComboSolver.SolverSpatialData.new()
	var report := ComboSolver.solve(opts)
	var counts := ComboSolver.last_request_profile_v2()
	var valid_routes := 0
	for route in report.routes:
		if route.timing_valid:
			valid_routes += 1
	var expected := valid_routes * SPATIAL_DISTANCES * 2
	_check(valid_routes > 0 and counts["spatial_rechecks"] == expected,
		"spatial_rechecks == timing-valid routes x 3 distances x 2 facings (%d x 3 x 2 == %d)" % [
			valid_routes, counts["spatial_rechecks"]])


const SPATIAL_DISTANCES := 3


func _options(table: Dictionary) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	return opts


func _solve(table: Dictionary) -> ComboSolver.SolverReport:
	## 确定性门的本意是「缓存全清后同请求同计数」——P2 探针缓存是第二层
	## 进程内缓存，与完整结果缓存一同清理。
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	return ComboSolver.solve(_options(table))
