extends SceneTree

## P5（solver-routes-cycles）：路线/循环/空间验证层重构的差分门。
##   1) 环枚举：SCC 预处理 + Johnson 风格去重 vs 旧全起点 DFS + canonical 去重
##      ——合成图（含 K4/桥接双 SCC/插入序≠字典序/自环/DAG）+ 确定性随机图 +
##      夹具表真实邻接图，顺序敏感逐字节对拍；canonical 旋转与无重复断言。
##   2) 路线叶 trie 登记（prefix/suffix memo）：开关两跑全语义指纹全等、
##      session_steps 不增；memo scope 含编译调度语义（compiled-scope），
##      兄弟路线的跨调度共享被安全阻断（本夹具 prefix_restores==0）；
##      空间多钉位（12/24/44）复验同档只重放输入分歧后的 suffix，
##      spatial_failures 逐条相等。
##   3) complete 模式：MAX_ROUTE_REPORTS 不作语义剪枝——分支夹具上默认截断 16
##      条 + 注记，完整模式枚举全部叶路线（== 邻接图暴力计数）且无截断注记。
##   4) 中断恢复：看门狗暂停 → 持久化快照 → resume_analysis 续算（多次暂停），
##      最终指纹与不中断路径全等；暂停报告如实标记、坏快照拒绝。
## 运行：godot --headless --path . -s res://tests/test_solver_routes_cycles_refactor.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const GrowthFixture = preload("res://tests/solver_growth_fixture.gd")

var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0
var _fixture := GrowthFixture.new()


func _initialize() -> void:
	print("")
	_test_cycle_enum_synthetic_graphs()
	_test_cycle_enum_random_graphs()
	_test_cycle_enum_fixture_adj()
	_test_route_leaf_memo_differential()
	_test_complete_mode_full_route_set()
	_test_interrupt_resume_analysis()
	_test_interrupt_resume_solve()
	_test_interrupt_resume_solve_spatial()
	_test_resume_failures_refused()
	print("")
	_metrics.emit("test_solver_routes_cycles_refactor")
	if _failures == 0:
		print("ALL SOLVER ROUTES-CYCLES REFACTOR TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


# --- 1) 环枚举差分 ---------------------------------------------------------


func _cycle_graphs() -> Array:
	return [
		{},
		{"a": ["a"]},
		{"a": ["b"], "b": ["c"]},
		{"a": ["b"], "b": ["a"]},
		{"z": ["y"], "y": ["z"], "a": ["z"]},
		{"a": ["b", "c"], "b": ["a"], "c": ["a"]},
		{"a": ["b", "c", "d"], "b": ["a", "c", "d"], "c": ["a", "b", "d"], "d": ["a", "b", "c"]},
		{"a": ["b"], "c": ["d"], "d": ["c"], "b": ["b", "c"]},
		{"s1": ["s2"], "s2": ["s1", "t"], "t": ["u"], "u": []},
		{"m3": ["m1"], "m1": ["m2"], "m2": ["m3"], "m0": ["m1"], "m4": ["m3", "m5"], "m5": ["m4"]},
	]


func _assert_cycle_enum_identical(adj: Dictionary, label: String) -> void:
	var solver := ComboSolver.new({})
	ComboSolver._cycle_enum_legacy = false
	var fresh: Array = solver._elementary_cycles(adj)
	ComboSolver._cycle_enum_legacy = true
	var legacy: Array = solver._elementary_cycles(adj)
	ComboSolver._cycle_enum_legacy = false
	_check(str(fresh) == str(legacy), "%s: Johnson 枚举与旧路径同序同集（%d 环）" % [label, fresh.size()])
	var keys := {}
	var canonical_ok := true
	for cycle in fresh:
		var key := ",".join(cycle)
		if keys.has(key):
			canonical_ok = false
		keys[key] = true
		if str(solver._canonical_cycle(cycle)) != str(cycle):
			canonical_ok = false
	_check(canonical_ok, "%s: 每环恰一次且为字典序最小起点旋转" % label)


func _test_cycle_enum_synthetic_graphs() -> void:
	var graphs := _cycle_graphs()
	for i in range(graphs.size()):
		_assert_cycle_enum_identical(graphs[i], "synthetic-%d" % i)
	## 插入序敏感：同一图换键插入序，新旧两路径的输出都随之等价变化（对拍口径）。
	var reversed_adj := {}
	var keys := ["m3", "m1", "m2", "m0", "m4", "m5"]
	for key in keys:
		reversed_adj[key] = _cycle_graphs()[9][key]
	_assert_cycle_enum_identical(reversed_adj, "synthetic-reversed-insertion")


func _test_cycle_enum_random_graphs() -> void:
	## 确定性 LCG 随机有向图（9 顶点，p≈0.28）：批量 hammered 对拍。
	var seed_value := 20261004
	var mismatch := 0
	for graph_index in range(120):
		var adj := {}
		var nodes: Array[String] = []
		for i in range(9):
			nodes.append("n%d" % i)
			adj[nodes[i]] = [] as Array[String]
		for i in range(9):
			for j in range(9):
				seed_value = (seed_value * 1103515245 + 12345) % 2147483648
				if (seed_value >> 16) % 100 < 28:
					(adj[nodes[i]] as Array[String]).append(nodes[j])
		var solver := ComboSolver.new({})
		ComboSolver._cycle_enum_legacy = false
		var fresh: Array = solver._elementary_cycles(adj)
		ComboSolver._cycle_enum_legacy = true
		var legacy: Array = solver._elementary_cycles(adj)
		ComboSolver._cycle_enum_legacy = false
		if str(fresh) != str(legacy):
			mismatch += 1
	_check(mismatch == 0, "120 张确定性随机图全部同序同集（mismatch=%d）" % mismatch)


func _test_cycle_enum_fixture_adj() -> void:
	## 夹具表（E=4）真实邻接图：跑一次单面向分析，从冻结边序重建 valid_adj。
	var table := _fixture.table(4)
	if table.is_empty():
		_check(false, "fixture E=4 table available")
		return
	var report := ComboSolver.new(table)._analyze(1, null, false, null)
	var adj := {}
	for edge in report.edges:
		if not edge.valid:
			continue
		if not adj.has(edge.from_id):
			adj[edge.from_id] = [] as Array[String]
		var targets: Array[String] = adj[edge.from_id]
		if not targets.has(edge.to_id):
			targets.append(edge.to_id)
	_assert_cycle_enum_identical(adj, "fixture-E4-adj")


# --- 2) 路线叶 trie 登记（prefix/suffix memo）差分 --------------------------


func _fresh_solve(table: Dictionary, spatial: bool) -> ComboSolver.SolverReport:
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.facings = [1]
	if spatial:
		opts.spatial = ComboSolver.SolverSpatialData.new()
	return ComboSolver.solve(opts)


func _small_branch_table() -> Dictionary:
	## 小分支夹具：S → L1a/L1b，L1* → L2a/L2b——兄弟路线共享 [S, L1*] 前缀，
	## 供叶登记差分观察「只重放分歧后 suffix」的确定性收益。
	if not _fixture._ready_base():
		return {}
	var table := {}
	var spec := {"S": ["L1a", "L1b"], "L1a": ["L2a", "L2b"], "L1b": ["L2a", "L2b"], "L2a": [], "L2b": []}
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


func _test_route_leaf_memo_differential() -> void:
	var table := _small_branch_table()
	if table.is_empty():
		_check(false, "small branch fixture table available")
		return
	ComboSolver._route_leaf_memo_disabled = true
	var off_report := _fresh_solve(table, true)
	var off_counts := ComboSolver.last_request_profile_v2()
	ComboSolver._route_leaf_memo_disabled = false
	var on_report := _fresh_solve(table, true)
	var on_counts := ComboSolver.last_request_profile_v2()
	var off_fp := _metrics._fingerprint(off_report)
	var on_fp := _metrics._fingerprint(on_report)
	if off_fp != on_fp:
		_dump_report_json("res://.scratch/solver-p5-01/memo-off.json", off_report)
		_dump_report_json("res://.scratch/solver-p5-01/memo-on.json", on_report)
	_check(off_report.routes.size() >= 8 and off_fp == on_fp,
		"spatial solve 全语义指纹在叶登记开关两侧全等（%d 条路线）" % off_report.routes.size())
	## compiled-scope 契约（恢复等价票据，2026-10-04）：memo scope 并入编译调度
	## 预期命中语义后，兄弟路线的共享全部是跨调度共享，被安全阻断——本夹具
	## 上叶登记不再产生恢复、steps 不降。要重新打开跨调度共享，必须先给出
	## restore on/off 逐字节等价证明并更新本组断言。
	_check(int(on_counts["session_steps"]) <= int(off_counts["session_steps"]),
		"叶登记后 session_steps 不增（%d → %d，trie 记账零重放放大）" % [
			int(off_counts["session_steps"]), int(on_counts["session_steps"])])
	_check(int(on_counts["prefix_restores"]) == 0,
		"全跨调度夹具上无恢复发生（prefix_restores=%d，跨调度共享在等价证明前保持阻断）" % int(on_counts["prefix_restores"]))
	_check(int(off_counts["spatial_rechecks"]) == int(on_counts["spatial_rechecks"]),
		"空间复验次数不受叶登记影响（%d）" % int(on_counts["spatial_rechecks"]))
	## 空间失败逐条相等（几何结论只出自真实结算）。
	var off_failures := {}
	for route in off_report.routes:
		off_failures[route.label()] = str(route.spatial_failures)
	var on_failures := {}
	for route in on_report.routes:
		on_failures[route.label()] = str(route.spatial_failures)
	_check(str(off_failures) == str(on_failures), "多钉位空间失败按路线逐条相等")


func _dump_report_json(path: String, report: ComboSolver.SolverReport) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(ComboSolver._freeze_report(report), "  "))
		file.close()


# --- 3) complete 模式：报告上限不作语义剪枝 ---------------------------------


func _branch_table() -> Dictionary:
	## 分支夹具：S → 两叉五层（S,L1a,L1b,…,L5a,L5b），每层节点取消进下一层全部
	## 节点——叶路线 2^5=32 条（从 S），加各层起点共 192 条（全部 ≤8 招）。
	if not _fixture._ready_base():
		return {}
	var table := {}
	var levels: Array = [["S"]]
	for level in range(1, 6):
		levels.append(["L%da" % level, "L%db" % level])
	var index := 0
	for level in range(levels.size()):
		for node_id in levels[level]:
			var move := MoveTable._fresh_copy(_fixture._base["5A"] as MoveData)
			move.move_id = node_id
			move.action_key = "W%d" % index
			move.direction_derivation = ""
			var empty: Array[String] = []
			move.input_alternatives = empty.duplicate()
			if level + 1 < levels.size():
				var targets: Array[String] = []
				for next_id in levels[level + 1]:
					targets.append(next_id)
				move.cancel_targets = targets
			table[node_id] = move
			index += 1
	return table


func _brute_force_leaf_routes(adj: Dictionary) -> int:
	var count := {"leaves": 0}
	var nodes := {}
	for from_id in adj.keys():
		nodes[from_id] = true
		for to_id in adj[from_id]:
			nodes[to_id] = true
	for start_id in nodes.keys():
		_brute_walk(str(start_id), [str(start_id)], adj, count)
	return int(count["leaves"])


func _brute_walk(node_id: String, path: Array, adj: Dictionary, count: Dictionary) -> void:
	var extended := false
	if adj.has(node_id) and path.size() < ComboSolver.MAX_ROUTE_NODES:
		for next_id in adj[node_id]:
			if path.has(next_id):
				continue
			var next_path: Array = path.duplicate()
			next_path.append(next_id)
			_brute_walk(str(next_id), next_path, adj, count)
			extended = true
	if not extended:
		count["leaves"] = int(count["leaves"]) + 1


func _test_complete_mode_full_route_set() -> void:
	var table := _branch_table()
	if table.is_empty():
		_check(false, "branch fixture table available")
		return
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var default_opts := ComboSolver.SolverOptions.new()
	default_opts.move_table = table
	default_opts.facings = [1]
	var default_report := ComboSolver.solve(default_opts)
	_check(default_report.routes.size() == ComboSolver.MAX_ROUTE_REPORTS,
		"默认模式在 %d 条报告上限截断（实际 %d）" % [ComboSolver.MAX_ROUTE_REPORTS, default_report.routes.size()])
	var truncated_note := false
	for note in default_report.notes:
		if "报告上限" in note:
			truncated_note = true
	_check(truncated_note, "默认模式如实注记路线集合未完成")
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var complete_opts := ComboSolver.SolverOptions.new()
	complete_opts.move_table = table
	complete_opts.facings = [1]
	complete_opts.complete = true
	var complete_report := ComboSolver.solve(complete_opts)
	var adj := {}
	for edge in complete_report.edges:
		if not edge.valid:
			continue
		if not adj.has(edge.from_id):
			adj[edge.from_id] = [] as Array[String]
		var targets: Array[String] = adj[edge.from_id]
		if not targets.has(edge.to_id):
			targets.append(edge.to_id)
	var brute := _brute_force_leaf_routes(adj)
	_check(complete_report.routes.size() > ComboSolver.MAX_ROUTE_REPORTS,
		"complete 模式不按报告上限剪枝（%d 条）" % complete_report.routes.size())
	var complete_truncated := false
	for note in complete_report.notes:
		if "报告上限" in note:
			complete_truncated = true
	_check(not complete_truncated, "complete 模式不携带截断注记")
	_check(complete_report.routes.size() == brute,
		"complete 路线数 == 邻接图暴力叶计数（%d == %d）" % [complete_report.routes.size(), brute])
	var complete_labels := {}
	for route in complete_report.routes:
		complete_labels[route.label()] = true
	var contained := true
	for route in default_report.routes:
		if not complete_labels.has(route.label()):
			contained = false
			break
	_check(contained and default_report.routes.size() <= complete_report.routes.size(),
		"默认截断集合是完整集合的子集")


# --- 4) 中断恢复差分 --------------------------------------------------------


func _test_interrupt_resume_analysis() -> void:
	var table := _fixture.table(2)
	if table.is_empty():
		_check(false, "fixture E=2 table available")
		return
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var plain := ComboSolver.new(table)._analyze(1, null, true, null)
	var plain_fp := _metrics._fingerprint(plain)
	_check(not plain.paused_incomplete, "无看门狗的分析不暂停")
	var resume_path := "res://.scratch/solver-p5-01/resume-analysis.json"
	var mode := {"complete": false, "watchdog_ms": 1, "resume_path": resume_path}
	var paused_reports := 0
	var report := ComboSolver.new(table)._analyze(1, null, true, null, mode)
	while report.paused_incomplete and paused_reports < 200:
		paused_reports += 1
		_check(FileAccess.file_exists(resume_path), "暂停腿 %d 持久化了快照" % paused_reports)
		var noted := false
		for note in report.notes:
			if note.begins_with("资源看门狗暂停："):
				noted = true
		if not noted:
			_check(false, "暂停腿 %d 如实注记暂停" % paused_reports)
			break
		report = ComboSolver.resume_analysis(resume_path)
	_check(not report.paused_incomplete, "续算最终完成（暂停 %d 次）" % paused_reports)
	_check(paused_reports > 0, "看门狗确实触发过暂停")
	_check(_metrics._fingerprint(report) == plain_fp, "续算完成报告与不中断路径指纹全等")


func _test_interrupt_resume_solve() -> void:
	var table := _fixture.table(2)
	if table.is_empty():
		_check(false, "fixture E=2 table available")
		return
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var plain_opts := ComboSolver.SolverOptions.new()
	plain_opts.move_table = table
	var plain_report := ComboSolver.solve(plain_opts)
	var plain_fp := _metrics._fingerprint(plain_report)
	var resume_path := "res://.scratch/solver-p5-01/resume-solve.json"
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.watchdog_ms = 1
	opts.resume_path = resume_path
	var paused := ComboSolver.solve(opts)
	var rounds := 0
	var report := paused
	while report.paused_incomplete and rounds < 200:
		rounds += 1
		report = ComboSolver.resume_analysis(resume_path)
	_check(not report.paused_incomplete, "solve 级续算最终完成（轮次 %d）" % rounds)
	_check(rounds > 0, "solve 级看门狗确实触发（暂停或换面向持久化）")
	_check(_metrics._fingerprint(report) == plain_fp, "solve 级续算完成报告与不中断路径指纹全等")


## solve 级中断续算的空间开关保持（09-full-01 回归）：带空间数据的 solve 暂停
## 后续算，完成报告必须与不中断路径指纹全等。曾因 solve 级快照丢失线程载荷
##（spatial 开关/看门狗/进度游标），续算把空间验证整段丢掉——all-UNVERIFIED
## 路线进结果缓存，污染同型请求。
func _test_interrupt_resume_solve_spatial() -> void:
	var table := _fixture.table(2)
	if table.is_empty():
		_check(false, "fixture E=2 table available")
		return
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var plain_opts := ComboSolver.SolverOptions.new()
	plain_opts.move_table = table
	plain_opts.spatial = ComboSolver.SolverSpatialData.new()
	var plain_report := ComboSolver.solve(plain_opts)
	var plain_fp := _metrics._fingerprint(plain_report)
	_check(not plain_report.paused_incomplete, "无看门狗的空间 solve 不暂停")
	var timing_valid := 0
	for route in plain_report.routes:
		if route.timing_valid and route.spatial_state != 0:
			timing_valid += 1
	_check(timing_valid > 0, "不中断空间 solve 有过验路线（回归断言前提）")
	var resume_path := "res://.scratch/solver-p5-01/resume-solve-spatial.json"
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.spatial = ComboSolver.SolverSpatialData.new()
	opts.watchdog_ms = 1
	opts.resume_path = resume_path
	var rounds := 0
	var report := ComboSolver.solve(opts)
	while report.paused_incomplete and rounds < 200:
		rounds += 1
		report = ComboSolver.resume_analysis(resume_path)
	_check(not report.paused_incomplete, "空间 solve 级续算最终完成（轮次 %d）" % rounds)
	_check(rounds > 0, "空间 solve 级看门狗确实触发")
	var unverified := 0
	for route in report.routes:
		if route.timing_valid and route.spatial_state == 0:
			unverified += 1
	_check(unverified == 0, "续算报告无 timing-valid 路线缺空间验证（%d 条缺失）" % unverified)
	_check(_metrics._fingerprint(report) == plain_fp, "空间 solve 续算完成报告与不中断路径指纹全等")


func _test_resume_failures_refused() -> void:
	var missing := ComboSolver.resume_analysis("res://.scratch/solver-p5-01/definitely-missing.json")
	_check(missing.refused and "恢复快照加载失败" in missing.refusal_reason,
		"缺失快照文件被拒绝并说明原因")
	var garbage_path := "res://.scratch/solver-p5-01/resume-garbage.json"
	var file := FileAccess.open(garbage_path, FileAccess.WRITE)
	file.store_line("this is not json {")
	file.close()
	var garbage := ComboSolver.resume_analysis(garbage_path)
	_check(garbage.refused and "恢复快照加载失败" in garbage.refusal_reason,
		"损坏快照文件被拒绝并说明原因")
