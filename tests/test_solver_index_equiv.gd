extends SceneTree

## P1（perf-index）：CompiledMoveIndex 索引路径 vs 旧路径（_compiled_index_disabled
## =true：全表扫描 + 逐缺口探针表深拷贝）的等价性差分门。
## 夹具：solver_growth_fixture 的 1/2/4/8 边注入表 + 两招互取消循环表，每路径
## 独立重建（索引路径的 staged 接种只允许触碰 solve 内部克隆，注入表不得有
## 任何残留）；另附 analyze() 入口（sort_outputs=false，报告序 = 枚举序）的
## 顺序敏感差分——solve() 的稳定排序会掩盖枚举序差异，analyze 不会。
## 门：
##   1. 索引结构防漂移：GAP_FIELD_BY_KIND/KIND_ORDER/GAP_WINDOW_PADS 与
##      ComboSolver._GAP_CONFIG_FIELDS/_analyze 枚举序/_gap_injected_move 垫值一致。
##   2. 全语义指纹相等（acceptance 口径：全部报告节 + 逐帧输入）。
##   3. edges/gaps 逐条 (from,to,kind,valid) 序列相等（报告序 = 搜索序）。
##   4. 搜索形状冻结：context_attempts/edge_built/delay_dfs_nodes/delay_dfs_leaves
##      跨路径相等（索引不改变尝试序列与选择时机）。
##   5. 恒等式 structure_candidates == edge_built + gap_built（两路径各自成立）。
##   6. gap_built(索引) <= gap_built(旧)：LANDING_CANCEL 结构死候选在索引期
##      剔除，探针与计数不再为其付费；报告输出零变化（门 2/3 已证）。
##   7. 接种无残留：索引路径跑完后注入表的 canonical 文本与跑前全等。
## 说明：差分开关不进语义签名/请求键，每路径跑前必须清结果缓存（否则第二
## 路径命中缓存，差分恒绿）。rekka/charge/air_exit 反向表的默认表级差分由
## .scratch 证据运行承载（perf-index-01），不入本快速门。
## 运行：godot --headless --path . -s res://tests/test_solver_index_equiv.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const Fixture = preload("res://tests/solver_growth_fixture.gd")

const EDGE_STEPS := [1, 2, 4, 8]
## 搜索形状量：索引是机械等价变换，这些计数必须逐项相等。
const SHAPE_KEYS := [
	"context_attempts", "edge_built", "delay_dfs_nodes", "delay_dfs_leaves",
	"prefix_restores", "prefix_frozen_returns",
]

var _failures := 0
var _metrics = AcceptanceSolverMetrics.new()
var _payload := {}


func _initialize() -> void:
	print("")
	_test_index_structure_pinned()
	for edges in EDGE_STEPS:
		_run_solve_differential("E=%d" % edges, Fixture.new().table(edges), Fixture.new().table(edges))
	_run_solve_differential("cycle", Fixture.new().cycle_table(), Fixture.new().cycle_table())
	_run_analyze_differential()
	print("")
	print("SOLVER_INDEX_EQUIV_JSON=" + JSON.stringify(_payload))
	if _failures == 0:
		print("ALL SOLVER INDEX EQUIV TESTS PASSED")
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


# --- 门 1：索引结构常量与 ComboSolver 源常量一致（漂移定位用）---


func _test_index_structure_pinned() -> void:
	_check(CompiledMoveIndex.KIND_ORDER == [
		ComboSolver.EdgeKind.CANCEL, ComboSolver.EdgeKind.CHAIN_CANCEL,
		ComboSolver.EdgeKind.SPECIAL_CANCEL, ComboSolver.EdgeKind.JUMP_CANCEL,
		ComboSolver.EdgeKind.LANDING_CANCEL, ComboSolver.EdgeKind.NORMAL_LINK,
		ComboSolver.EdgeKind.REKKA_DERIVE, ComboSolver.EdgeKind.SPECIAL_ENTRY,
		ComboSolver.EdgeKind.SPECIAL_ENTRY_LINK, ComboSolver.EdgeKind.AIR_EXIT,
		ComboSolver.EdgeKind.HIT_LANDING_CANCEL,
	], "KIND_ORDER mirrors the _analyze kinds_and_targets enumeration order")
	var fields_match := true
	for kind in ComboSolver._GAP_CONFIG_FIELDS:
		if CompiledMoveIndex.GAP_FIELD_BY_KIND.get(int(kind), "") != ComboSolver._GAP_CONFIG_FIELDS[kind]["field"]:
			fields_match = false
	_check(fields_match, "GAP_FIELD_BY_KIND mirrors _GAP_CONFIG_FIELDS field names")
	_check(CompiledMoveIndex.GAP_WINDOW_PADS == {
		ComboSolver.EdgeKind.CHAIN_CANCEL: {"field": "chain_cancel_window_frames", "value": 3},
		ComboSolver.EdgeKind.SPECIAL_CANCEL: {"field": "special_cancel_window_frames", "value": 5},
		ComboSolver.EdgeKind.HIT_LANDING_CANCEL: {"field": "hit_landing_cancel_window_frames", "value": 24},
	}, "GAP_WINDOW_PADS mirrors the _gap_probe_table injection defaults")


# --- solve() 入口差分（双面向、稳定排序输出）---


func _run_solve_differential(label: String, old_table: Dictionary, new_table: Dictionary) -> void:
	if old_table.is_empty() or new_table.is_empty():
		_check(false, "%s fixture builds from the shared manifest" % label)
		return
	var canonical_before := ComboSolver._canonical_variant(new_table)
	_check(canonical_before != "", "%s: canonical table text is non-empty (residue check is meaningful)" % label)
	var old_run := _solve_recorded(old_table, true)
	var new_run := _solve_recorded(new_table, false)
	_check(ComboSolver._canonical_variant(new_table) == canonical_before,
		"%s: injected table byte-identical before/after the index path (no probe residue)" % label)
	_compare_runs(label, old_run, new_run)


func _solve_recorded(table: Dictionary, legacy_path: bool) -> Dictionary:
	ComboSolver.clear_result_cache()
	ComboSolver._compiled_index_disabled = legacy_path
	var report := ComboSolver.solve(_options(table))
	ComboSolver._compiled_index_disabled = false
	return {
		"report": report,
		"fingerprint": _metrics._fingerprint(report),
		"counts": ComboSolver.last_request_profile_v2(),
	}


func _options(table: Dictionary) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	return opts


# --- analyze() 入口差分（表序枚举输出——顺序敏感面）---


func _run_analyze_differential() -> void:
	var label := "analyze-E2"
	var old_table: Dictionary = Fixture.new().table(2)
	var new_table: Dictionary = Fixture.new().table(2)
	if old_table.is_empty() or new_table.is_empty():
		_check(false, "analyze fixture builds from the shared manifest")
		return
	## analyze() 对注入表不做入口克隆：staged 接种若回退不净，canonical 文本
	## 与指纹都会漂移——这是接种无残留的最强单点检验。
	var canonical_before := ComboSolver._canonical_variant(new_table)
	ComboSolver.clear_result_cache()
	ComboSolver._compiled_index_disabled = true
	var old_report := ComboSolver.analyze(old_table)
	ComboSolver._compiled_index_disabled = false
	ComboSolver.clear_result_cache()
	var new_report := ComboSolver.analyze(new_table)
	_check(ComboSolver._canonical_variant(new_table) == canonical_before,
		"%s: injected table byte-identical before/after staged probing (no residue)" % label)
	_check(_metrics._fingerprint(old_report) == _metrics._fingerprint(new_report),
		"%s: full semantic fingerprint identical across paths (enumeration-order sensitive entry)" % label)
	_check(_edge_sequence(old_report) == _edge_sequence(new_report) and _gap_sequence(old_report) == _gap_sequence(new_report),
		"%s: edge/gap sequences identical in report order" % label)


# --- 共用比较 ---


func _compare_runs(label: String, old_run: Dictionary, new_run: Dictionary) -> void:
	var old_counts: Dictionary = old_run["counts"]
	var new_counts: Dictionary = new_run["counts"]
	_check(old_run["fingerprint"] == new_run["fingerprint"],
		"%s: full semantic fingerprint identical across old scan path and index path" % label)
	var old_report: ComboSolver.SolverReport = old_run["report"]
	var new_report: ComboSolver.SolverReport = new_run["report"]
	_check(_edge_sequence(old_report) == _edge_sequence(new_report),
		"%s: edge sequence identical in report order (%d edges)" % [label, old_report.edges.size()])
	_check(_gap_sequence(old_report) == _gap_sequence(new_report),
		"%s: gap sequence identical in report order (%d gaps)" % [label, old_report.gaps.size()])
	for key in SHAPE_KEYS:
		_check(int(old_counts[key]) == int(new_counts[key]),
			"%s: shape count %s frozen across paths (%d == %d)" % [label, key, old_counts[key], new_counts[key]])
	for side in [["old", old_run], ["new", new_run]]:
		var counts: Dictionary = side[1]["counts"]
		_check(int(counts["structure_candidates"]) == int(counts["edge_built"]) + int(counts["gap_built"]),
			"%s/%s: structure_candidates == edge_built + gap_built (%d == %d + %d)" % [
				label, side[0], counts["structure_candidates"], counts["edge_built"], counts["gap_built"]])
	_check(int(new_counts["gap_built"]) <= int(old_counts["gap_built"]),
		"%s: index path probes no more gap candidates (%d <= %d, LANDING_CANCEL structurally dead dropped)" % [
			label, new_counts["gap_built"], old_counts["gap_built"]])
	_payload[label] = {
		"fingerprint_equal": old_run["fingerprint"] == new_run["fingerprint"],
		"old": _counts_of(old_counts),
		"new": _counts_of(new_counts),
	}


func _counts_of(counts: Dictionary) -> Dictionary:
	var picked := {}
	for key in ["structure_candidates", "context_attempts", "edge_built", "gap_built",
			"delay_dfs_nodes", "delay_dfs_leaves", "session_steps", "prefix_restores"]:
		picked[key] = int(counts[key])
	return picked


func _edge_sequence(report: ComboSolver.SolverReport) -> Array[String]:
	var triples: Array[String] = []
	for edge in report.edges:
		triples.append("%s>%s:%d:%s" % [edge.from_id, edge.to_id, edge.kind, str(edge.valid)])
	return triples


func _gap_sequence(report: ComboSolver.SolverReport) -> Array[String]:
	var triples: Array[String] = []
	for gap in report.gaps:
		triples.append("%s>%s:%d" % [gap.from_id, gap.to_id, gap.kind])
	return triples
