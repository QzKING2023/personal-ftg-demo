extends SceneTree

## P0：combo solver 连段边增长夹具（1/2/4/8 条边）与语义指纹 oracle 门。
## 每档夹具双跑：
##   - 旧路径（_delay_prefix_restore_disabled=true，延迟叶子逐叶全量重放）产出
##     完整语义 fingerprint（acceptance 口径，全部报告节 + 逐帧输入）；
##   - 当前路径（前缀恢复启用）产出同一指纹——机械等价在增长曲线上逐档复验；
##   - 旧路径指纹与入库 oracle（tests/oracle/solver_growth_oracle.json）全等——
##     语义漂移（搜索语义/顺序/报告字段/招式数据的任何变更）在门上直接 FAIL。
## 增长回归门：搜索形状计数（结构候选/上下文尝试/edge/gap 构造/delay DFS
## 节点/叶子）跨路径相等且随边数单调增长；基线数值以 stdout 的
## SOLVER_GROWTH_JSON 行归档（.scratch/solver-scalability/perf-gate-01/）。
## 运行：godot --headless --path . -s res://tests/test_solver_growth.gd
## oracle 重生成（语义变更获準后人工执行，不进验收）：-- --regen-oracle

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const Fixture = preload("res://tests/solver_growth_fixture.gd")

const ORACLE_PATH := "res://tests/oracle/solver_growth_oracle.json"
const ORACLE_SCHEMA := "solver-growth-oracle-v1"
const EDGE_STEPS := [1, 2, 4, 8]
## 搜索形状量：与重放实现无关（前缀恢复是机械等价变换），新旧路径必须逐项相等。
const SHAPE_KEYS := [
	"structure_candidates", "context_attempts", "edge_built", "gap_built",
	"delay_dfs_nodes", "delay_dfs_leaves",
]
## 增长基线量：随边数单调不减（重放实现相关量 session_steps/prefix_* 只归档，
## 不作跨路径相等断言——恢复路径按设计少喂物理帧）。
const GROWTH_KEYS := [
	"structure_candidates", "context_attempts", "edge_built", "gap_built",
	"delay_dfs_nodes", "delay_dfs_leaves", "session_steps",
	"prefix_restores", "prefix_frozen_returns",
]

var _failures := 0
var _metrics = AcceptanceSolverMetrics.new()


func _initialize() -> void:
	print("")
	var rows := {}
	for edges in EDGE_STEPS:
		rows[edges] = _run_fixture(edges)
	if "--regen-oracle" in OS.get_cmdline_user_args():
		_write_oracle(rows)
		print("oracle regenerated -> " + ORACLE_PATH)
	_test_fixture_sanity(rows)
	_test_old_path_equivalence(rows)
	_test_shape_frozen_across_paths(rows)
	_test_candidate_identity(rows)
	_test_growth_monotone(rows)
	_test_oracle_matches(rows)
	print("")
	print("SOLVER_GROWTH_JSON=" + JSON.stringify(_growth_payload(rows)))
	if _failures == 0:
		print("ALL SOLVER GROWTH TESTS PASSED")
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


## 一档夹具的新旧双跑（各清缓存，指纹与 v2 计数随行返回）。
func _run_fixture(edges: int) -> Dictionary:
	var table := Fixture.new().table(edges)
	var row := {"table": table, "old": {}, "new": {}}
	if table.is_empty():
		return row
	row["old"] = _solve_recorded(table, true)
	row["new"] = _solve_recorded(table, false)
	return row


func _solve_recorded(table: Dictionary, old_path: bool) -> Dictionary:
	ComboSolver.clear_result_cache()
	ComboSolver._delay_prefix_restore_disabled = old_path
	var report := ComboSolver.solve(_options(table))
	ComboSolver._delay_prefix_restore_disabled = false
	return {
		"report": report,
		"fingerprint": _metrics._fingerprint(report),
		"counts": ComboSolver.last_request_profile_v2(),
	}


func _options(table: Dictionary) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	return opts


# --- 门 1：夹具有效（失败即 FAIL，杜绝静默空转的恒绿）---


func _test_fixture_sanity(rows: Dictionary) -> void:
	for edges in EDGE_STEPS:
		var row: Dictionary = rows[edges]
		if row["table"].is_empty():
			_check(false, "E=%d fixture builds from the shared manifest" % edges)
			continue
		var report: ComboSolver.SolverReport = row["old"]["report"]
		var valid_routes := 0
		for route in report.routes:
			if route.timing_valid:
				valid_routes += 1
		_check(not report.refused and valid_routes >= 1,
			"E=%d fixture yields >= 1 timing-valid route under the old path (%d routes, %d valid)" % [
				edges, report.routes.size(), valid_routes])
		_check(int(row["old"]["counts"]["edge_built"]) == edges * 2,
			"E=%d fixture builds exactly %d configured edges (x2 facings)" % [edges, edges])


# --- 门 2：旧路径 == 当前路径（机械等价在增长曲线上复验）---


func _test_old_path_equivalence(rows: Dictionary) -> void:
	for edges in EDGE_STEPS:
		var row: Dictionary = rows[edges]
		if row["table"].is_empty():
			continue
		_check(row["old"]["fingerprint"] == row["new"]["fingerprint"],
			"E=%d: full semantic fingerprint identical across old path and current path" % edges)


# --- 门 3：搜索形状冻结（形状量与重放实现无关）---


func _test_shape_frozen_across_paths(rows: Dictionary) -> void:
	for edges in EDGE_STEPS:
		var row: Dictionary = rows[edges]
		if row["table"].is_empty():
			continue
		for key in SHAPE_KEYS:
			var old_value := int(row["old"]["counts"][key])
			var new_value := int(row["new"]["counts"][key])
			_check(old_value == new_value,
				"E=%d: shape count %s frozen across paths (%d == %d)" % [edges, key, old_value, new_value])


# --- 门 4：结构候选恒等式（配置候选 + 缺口候选 == 全部构造）---


func _test_candidate_identity(rows: Dictionary) -> void:
	for edges in EDGE_STEPS:
		var row: Dictionary = rows[edges]
		if row["table"].is_empty():
			continue
		for side in ["old", "new"]:
			var counts: Dictionary = row[side]["counts"]
			_check(int(counts["structure_candidates"]) == int(counts["edge_built"]) + int(counts["gap_built"]),
				"E=%d/%s: structure_candidates == edge_built + gap_built (%d == %d + %d)" % [
					edges, side, counts["structure_candidates"], counts["edge_built"], counts["gap_built"]])


# --- 门 5：随边数单调增长（增长回归门的确定性形态）---


func _test_growth_monotone(rows: Dictionary) -> void:
	for key in GROWTH_KEYS:
		var monotone := true
		var detail := ""
		for i in range(1, EDGE_STEPS.size()):
			var smaller: Dictionary = rows[EDGE_STEPS[i - 1]]["new"]["counts"]
			var larger: Dictionary = rows[EDGE_STEPS[i]]["new"]["counts"]
			if rows[EDGE_STEPS[i - 1]]["table"].is_empty() or rows[EDGE_STEPS[i]]["table"].is_empty():
				monotone = false
				detail = "fixture missing"
				break
			if int(larger[key]) < int(smaller[key]):
				monotone = false
				detail = "%s: E=%d gives %d < %d at E=%d" % [key, EDGE_STEPS[i], larger[key], smaller[key], EDGE_STEPS[i - 1]]
				break
		_check(monotone, "growth key %s non-decreasing across E=1/2/4/8%s" % [key, " (" + detail + ")" if detail != "" else ""])
	var strictly := true
	for i in range(EDGE_STEPS.size()):
		var counts: Dictionary = rows[EDGE_STEPS[i]]["new"]["counts"]
		if counts.is_empty() or int(counts["edge_built"]) != EDGE_STEPS[i] * 2:
			strictly = false
	_check(strictly, "edge_built grows exactly with configured edges (2/4/8/16 across facings)")


# --- 门 6：旧路径指纹 == 入库 oracle（语义冻结基线）---


func _test_oracle_matches(rows: Dictionary) -> void:
	var oracle := _read_oracle()
	if oracle.is_empty():
		_check(false, "oracle file readable at " + ORACLE_PATH + " (regenerate with -- --regen-oracle after an approved semantic change)")
		return
	_check(str(oracle.get("schema", "")) == ORACLE_SCHEMA, "oracle schema is " + ORACLE_SCHEMA)
	var fingerprints: Dictionary = oracle.get("fingerprints", {})
	for edges in EDGE_STEPS:
		var row: Dictionary = rows[edges]
		if row["table"].is_empty():
			continue
		var want := str(fingerprints.get(str(edges), ""))
		_check(want != "" and want == row["old"]["fingerprint"],
			"E=%d old-path fingerprint matches the pinned oracle (%s)" % [edges, str(row["old"]["fingerprint"]).substr(0, 12)])


# --- oracle 与基线 IO ---


func _read_oracle() -> Dictionary:
	if not FileAccess.file_exists(ORACLE_PATH):
		return {}
	var file := FileAccess.open(ORACLE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return parsed


func _write_oracle(rows: Dictionary) -> void:
	var fingerprints := {}
	for edges in EDGE_STEPS:
		fingerprints[str(edges)] = rows[edges]["old"]["fingerprint"]
	var payload := {
		"schema": ORACLE_SCHEMA,
		"entrypoint": "solve/injected-growth-fixture/default-facings/old-path",
		"edges": EDGE_STEPS,
		"fingerprints": fingerprints,
	}
	var dir := ORACLE_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(ORACLE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _growth_payload(rows: Dictionary) -> Dictionary:
	var payload := {}
	for edges in EDGE_STEPS:
		var row: Dictionary = rows[edges]
		if row["table"].is_empty():
			continue
		var entry := {}
		for key in GROWTH_KEYS + ["cycle_state_snapshots", "spatial_rechecks"]:
			entry[key] = int(row["new"]["counts"][key])
		entry["fingerprint"] = row["old"]["fingerprint"]
		entry["fingerprint_path_equal"] = row["old"]["fingerprint"] == row["new"]["fingerprint"]
		payload[str(edges)] = entry
	return payload
