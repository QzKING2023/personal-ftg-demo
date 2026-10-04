extends SceneTree

## P5 探针：按测试顺序复现——先 fixture-E4 分析 + 随机图枚举，再小分支表
## off/on solve，逐节 diff 指纹定位分歧。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const GrowthFixture = preload("res://tests/solver_growth_fixture.gd")

var _metrics := AcceptanceSolverMetrics.new()
var _fixture := GrowthFixture.new()


func _initialize() -> void:
	var solver := ComboSolver.new({})
	ComboSolver._cycle_enum_legacy = false
	var fresh: Array = solver._elementary_cycles({"a": ["b", "c", "d"], "b": ["a", "c", "d"], "c": ["a", "b", "d"], "d": ["a", "b", "c"]})
	ComboSolver._cycle_enum_legacy = true
	var legacy: Array = solver._elementary_cycles({"a": ["b", "c", "d"], "b": ["a", "c", "d"], "c": ["a", "b", "d"], "d": ["a", "b", "c"]})
	ComboSolver._cycle_enum_legacy = false
	print("enum identical: ", str(fresh) == str(legacy), " cycles=", fresh.size())
	var t4 := _fixture.table(4)
	print("t4 size: ", t4.size())
	var pre := ComboSolver.new(t4)._analyze(1, null, false, null)
	print("pre analyze routes: ", pre.routes.size())
	var table := _small_branch_table()
	print("branch size: ", table.size())
	ComboSolver._route_leaf_memo_disabled = true
	var off := _solve(table)
	ComboSolver._route_leaf_memo_disabled = false
	var on := _solve(table)
	_diff_sections("off", "on", off, on)
	quit(0)


func _solve(table: Dictionary) -> ComboSolver.SolverReport:
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.facings = [1]
	opts.spatial = ComboSolver.SolverSpatialData.new()
	return ComboSolver.solve(opts)


func _diff_sections(a_name: String, b_name: String, a: ComboSolver.SolverReport, b: ComboSolver.SolverReport) -> void:
	var fields := {
		"safe": str(a.safe) + "|" + str(b.safe),
		"summary": a.summary + "||" + b.summary,
		"scope": str(a.scope == b.scope),
		"incomplete_cycle_count": str(a.incomplete_cycle_count) + "|" + str(b.incomplete_cycle_count),
		"notes": str(a.notes) + "||" + str(b.notes),
		"table_lines": str(a.table_lines == b.table_lines),
		"start_lines": str(a.start_lines == b.table_lines),
		"first_candidates": str(a.first_candidates == b.first_candidates),
		"binding_lines": str(a.binding_lines == b.binding_lines),
		"spatial_lines": str(a.spatial_lines == b.spatial_lines),
		"guide_lines": str(a.guide_lines == b.guide_lines),
		"verified_facings": str(a.verified_facings == b.verified_facings),
	}
	for key in fields:
		var value := str(fields[key])
		if "||" in value:
			var parts := value.split("||")
			_check(parts[0] == parts[1], key, parts[0], parts[1])
		else:
			_check(not ("false" in value), key, value, value)
	var sa := ComboSolver._signature_sections(a, 1)
	var sb := ComboSolver._signature_sections(b, 1)
	for section in ["edges", "gaps", "routes", "cycles"]:
		_check(sa[section] == sb[section], "section:" + section, sa[section], sb[section])
	print("fingerprint equal: ", _metrics._fingerprint(a) == _metrics._fingerprint(b))


func _check(equal: bool, label: String, a_text: String, b_text: String) -> void:
	if not equal:
		print("DIFF  ", label)
		print("  A: ", a_text.substr(0, 400))
		print("  B: ", b_text.substr(0, 400))
	else:
		print("same  ", label)


func _small_branch_table() -> Dictionary:
	if not _fixture._ready_base():
		return {}
	var table := {}
	var spec := {"S": ["L1a", "L1b"], "L1a": ["L2a", "L2b"], "L1b": ["L2a", "L2b"]}
	var index := 0
	for node_id in spec.keys():
		var move := MoveTable._fresh_copy(_fixture._base["5A"] as MoveData)
		move.move_id = node_id
		move.action_key = "V%d" % index
		move.direction_derivation = ""
		var empty: Array[String] = []
		move.input_alternatives = empty.duplicate()
		var targets: Array[String] = []
		for target in spec[node_id]:
			targets.append(target)
		move.cancel_targets = targets
		table[node_id] = move
		index += 1
	return table
