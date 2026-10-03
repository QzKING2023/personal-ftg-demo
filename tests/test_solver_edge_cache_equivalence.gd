extends SceneTree

## P2（perf-edge-cache）：接续探针精确结果缓存（edge/gap/source-timing）的
## 等价性与隔离性差分门。缓存值是完整不可变快照（SolverEdge 全字段 / timing
## 三字段），键含表语义摘要、facing、pin_dx、起始状态、from/to/kind、上下文
## 签名、模式（配置边/缺口探针+接种）与弹地/落地配置摘要。
## 门：
##   1. 键完整性与隔离：_edge_probe_key 稳定；facing/pin_dx/kind/mode/上下文/
##      表内容任一维变化都是不同键（绝不互相命中）。
##   2. 冷/热等价：同一 solve 两跑（完整结果缓存旁路），冷跑全 miss、热跑命中
##      且全语义指纹全等、session_steps 严格下降（探针重放被真实消去）。
##   3. Tier A/B 差分（旧路径保留）：legacy 枚举/索引路径 × 探针缓存关/开
##     （冷/热）四形态指纹全等；结构判定层抽出零语义变化。
##   4. facing 隔离：面向 -1 不吃面向 +1 的条目（命中不增、miss 增），报告与
##      无缓存路径全等。
##   5. 返回值不可变：改写命中解冻的边/时序字典不回写缓存，后续命中逐字段复原。
##   6. 跨入口复用：solve 之后 analyze（同表同面向、不同请求 descriptor）探针
##      全命中，报告与无缓存 analyze 全等。
##   7. 注入无残留：注入表 canonical 文本跑前跑后全等（显式注入零 _table 写入）。
## 运行：godot --headless --path . -s res://tests/test_solver_edge_cache_equivalence.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const Fixture = preload("res://tests/solver_growth_fixture.gd")

const DIFF_STEPS := [1, 2, 4, 8]

var _failures := 0
var _metrics = AcceptanceSolverMetrics.new()
var _payload := {}


func _initialize() -> void:
	print("")
	ComboSolver.set_result_cache_enabled(false)
	_test_key_integrity()
	_test_cold_hot_equivalence()
	_test_tier_differential()
	_test_facing_isolation()
	_test_return_immutability()
	_test_cross_entrypoint_reuse()
	_test_context_candidates_no_pollution()
	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	print("")
	print("SOLVER_EDGE_CACHE_EQUIV_JSON=" + JSON.stringify(_payload))
	if _failures == 0:
		print("ALL SOLVER EDGE CACHE EQUIV TESTS PASSED")
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


# --- 门 1：键完整性与维度隔离 ---


func _test_key_integrity() -> void:
	var solver := ComboSolver.new(Fixture.new().table(2))
	var context: Array[ComboSolver.ChainLink] = []
	var link := ComboSolver.ChainLink.new()
	link.move_id = "L0"
	link.key = "LA"
	link.trigger = ComboSolver.ChainLink.Trigger.START
	context.append(link)
	var base: String = solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false)
	_check(base != "", "key builds and is non-empty")
	_check(solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) == base,
		"key is stable across repeated calls")
	solver._facing = -1
	_check(solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) != base,
		"facing is a key dimension (mirror probe never cross-served)")
	solver._facing = 1
	solver._pin_dx = 48.0
	_check(solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) != base,
		"pin_dx is a key dimension (spatial distances never cross-served)")
	solver._pin_dx = ComboSolver.PIN_DX
	_check(solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.LANDING_CANCEL, context, false) != base,
		"edge_kind is a key dimension")
	_check(solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, true) != base,
		"solver mode is a key dimension (gap probe never serves the configured edge)")
	var link2 := ComboSolver.ChainLink.new()
	link2.move_id = "Q1"
	link2.key = "QA"
	link2.trigger = ComboSolver.ChainLink.Trigger.JUMP_FRAME
	context.append(link2)
	_check(solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) != base,
		"context signature is a key dimension")
	context.remove_at(context.size() - 1)
	_check(solver._edge_probe_key("L0", "Q2", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) != base,
		"to_id is a key dimension")
	var solver_start := ComboSolver.new(Fixture.new().table(2))
	solver_start._start = ComboSolver.SolverStartState.new()
	var start_key: String = solver_start._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false)
	solver_start._start.stance = MoveData.Stance.AIR
	_check(solver_start._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) != start_key,
		"explicit start state is a key dimension")
	var other_table := Fixture.new().table(2)
	(other_table["L0"] as MoveData).startup_frames += 1
	var mutated_solver := ComboSolver.new(other_table)
	_check(mutated_solver._edge_probe_key("L0", "Q1", ComboSolver.EdgeKind.JUMP_CANCEL, context, false) != base,
		"table semantic digest is a key dimension (content change invalidates)")
	_check(ComboSolver._bounce_landing_signature() != "" \
		and ComboSolver._bounce_landing_signature() == ComboSolver._sha256_text(
			ComboSolver._canonical_variant(ComboSolver._bounce_landing_values())),
		"bounce/landing config digest is stable and carried inside the key text")


# --- 门 2：冷/热等价（完整结果缓存旁路，搜索真实重跑）---


func _test_cold_hot_equivalence() -> void:
	var table := Fixture.new().table(4)
	ComboSolver.clear_edge_probe_cache()
	var cold := _solve_recorded(table, false, false)
	var hot := _solve_recorded(table, false, false)
	_check(int(cold["stats"]["edge_hits"]) == 0 and int(cold["stats"]["timing_hits"]) == 0,
		"cold run: no probe cache hits (all misses populate)")
	_check(int(cold["stats"]["edge_misses"]) > 0 and int(cold["stats"]["timing_misses"]) > 0,
		"cold run: probes populated the cache (%d edge / %d timing misses)" % [
			int(cold["stats"]["edge_misses"]), int(cold["stats"]["timing_misses"])])
	_check(int(hot["stats"]["edge_hits"]) == int(cold["stats"]["edge_misses"]) - int(hot["stats"]["edge_misses"]),
		"hot run: edge probes served from cache (%d hits / %d residual misses)" % [
			int(hot["stats"]["edge_hits"]), int(hot["stats"]["edge_misses"])])
	_check(int(hot["stats"]["edge_hits"]) > 0 \
		and int(hot["stats"]["timing_hits"]) + int(hot["stats"]["timing_misses"]) == 0,
		"hot run: edge probes all served from cache, timing layer fully subsumed (no queries)")
	_check(cold["fingerprint"] == hot["fingerprint"],
		"cold and hot runs produce identical full semantic fingerprints")
	_check(int(hot["counts"]["session_steps"]) < int(cold["counts"]["session_steps"]),
		"hot run replays strictly fewer session steps (%d < %d)" % [
			int(hot["counts"]["session_steps"]), int(cold["counts"]["session_steps"])])
	_check(_edge_sequence(cold["report"]) == _edge_sequence(hot["report"]) \
		and _gap_sequence(cold["report"]) == _gap_sequence(hot["report"]),
		"edge/gap sequences identical in report order across cold/hot")
	_payload["cold_hot"] = {
		"cold": _stats_of(cold), "hot": _stats_of(hot),
		"fingerprint_equal": cold["fingerprint"] == hot["fingerprint"],
		"session_steps": {"cold": int(cold["counts"]["session_steps"]), "hot": int(hot["counts"]["session_steps"])},
	}


# --- 门 3：Tier A/B 差分（legacy 枚举 / 索引 × 缓存关 / 开）---


func _test_tier_differential() -> void:
	for edges in DIFF_STEPS:
		var table := Fixture.new().table(edges)
		var canonical_before := ComboSolver._canonical_variant(table)
		ComboSolver.clear_edge_probe_cache()
		var legacy_cold := _solve_recorded(table, true, false)
		var index_reuse := _solve_recorded(table, false, false)
		ComboSolver.clear_edge_probe_cache()
		var index_cold := _solve_recorded(table, false, false)
		var index_hot := _solve_recorded(table, false, false)
		var fingerprint: String = legacy_cold["fingerprint"]
		var all_equal: bool = index_reuse["fingerprint"] == fingerprint \
			and index_cold["fingerprint"] == fingerprint \
			and index_hot["fingerprint"] == fingerprint
		_check(all_equal, "E=%d: fingerprints identical across legacy/index x cold/reuse/hot" % edges)
		_check(int(index_reuse["stats"]["edge_hits"]) > 0,
			"E=%d: index path safely reuses legacy-computed entries (cross-path namespace)" % edges)
		_check(_edge_sequence(legacy_cold["report"]) == _edge_sequence(index_hot["report"]) \
			and _gap_sequence(legacy_cold["report"]) == _gap_sequence(index_hot["report"]),
			"E=%d: edge/gap sequences identical legacy vs hot-cache" % edges)
		_check(ComboSolver._canonical_variant(table) == canonical_before,
			"E=%d: injected table byte-identical before/after (explicit injection, zero _table writes)" % edges)
		_payload["tier_E%d" % edges] = {
			"legacy_cold": _stats_of(legacy_cold), "index_reuse": _stats_of(index_reuse),
			"index_cold": _stats_of(index_cold), "index_hot": _stats_of(index_hot),
			"fingerprint_equal": all_equal,
		}
	var cycle_table := Fixture.new().cycle_table()
	var cycle_legacy := _solve_recorded(cycle_table, true, false)
	ComboSolver.clear_edge_probe_cache()
	var cycle_hot_1 := _solve_recorded(cycle_table, false, false)
	var cycle_hot_2 := _solve_recorded(cycle_table, false, false)
	_check(cycle_legacy["fingerprint"] == cycle_hot_1["fingerprint"] and cycle_hot_1["fingerprint"] == cycle_hot_2["fingerprint"],
		"cycle table: fingerprints identical across paths and cache states")


# --- 门 4：facing 隔离 ---


func _test_facing_isolation() -> void:
	var table := Fixture.new().table(4)
	ComboSolver.clear_edge_probe_cache()
	var right := _solve_recorded(table, false, false, [1])
	var before := ComboSolver.edge_probe_cache_stats()
	var left := _solve_recorded(table, false, false, [-1])
	var after := ComboSolver.edge_probe_cache_stats()
	_check(int(after["edge_hits"]) == int(before["edge_hits"]),
		"facing -1 run consumes no facing +1 entries (hits unchanged)")
	_check(int(after["edge_misses"]) > int(before["edge_misses"]),
		"facing -1 run repopulates its own namespace (%d new misses)" % [
			int(after["edge_misses"]) - int(before["edge_misses"])])
	var left_uncached := _solve_recorded(table, true, false, [-1])
	_check(left["fingerprint"] == left_uncached["fingerprint"],
		"facing -1 report identical to the uncached path")
	_payload["facing"] = {
		"right_hits": int(right["stats"]["edge_hits"]),
		"left_hits_delta": int(after["edge_hits"]) - int(before["edge_hits"]),
		"left_misses_delta": int(after["edge_misses"]) - int(before["edge_misses"]),
	}


# --- 门 5：返回值不可变 ---


func _test_return_immutability() -> void:
	var table := Fixture.new().table(2)
	ComboSolver.clear_edge_probe_cache()
	var first := _solve_recorded(table, false, false)
	var edge: ComboSolver.SolverEdge = first["report"].edges[0]
	var pristine := {
		"valid": edge.valid, "reason": edge.reason, "wait_to": edge.wait_to,
		"hit_age": edge.hit_age, "recover_age": edge.recover_age,
	}
	edge.valid = not edge.valid
	edge.reason = "污染尝试"
	edge.wait_to = 12345
	edge.hit_age = -999
	var second := _solve_recorded(table, false, false)
	var served: ComboSolver.SolverEdge = second["report"].edges[0]
	_check(bool(served.valid) == bool(pristine["valid"]) and served.reason == pristine["reason"] \
		and served.wait_to == pristine["wait_to"] and served.hit_age == pristine["hit_age"] \
		and served.recover_age == pristine["recover_age"],
		"mutating a thawed edge does not leak into the cache snapshot")
	_check(first["fingerprint"] == second["fingerprint"],
		"fingerprint stable across a pollution attempt")
	var solver := ComboSolver.new(Fixture.new().table(2))
	var contexts: Dictionary = solver._build_contexts()
	var context_ids: Array = contexts.keys()
	if context_ids.is_empty() or (contexts[context_ids[0]] as Array).is_empty():
		_check(false, "fixture exposes a context-reachable starter for the timing probe")
		return
	var move_id: String = context_ids[0]
	var context: Array[ComboSolver.ChainLink] = contexts[move_id]
	## timing 命名空间的独立冷/热/污染三连（局部字典每次全新，强制走静态层）。
	ComboSolver.clear_edge_probe_cache()
	var before_miss := ComboSolver.edge_probe_cache_stats()
	var cold_timing: Dictionary = solver._source_timing(move_id, context, {})
	var after_miss := ComboSolver.edge_probe_cache_stats()
	_check(cold_timing.is_empty() == false \
		and int(after_miss["timing_misses"]) == int(before_miss["timing_misses"]) + 1,
		"timing namespace: first query is a cold miss that populates")
	var before_hit := ComboSolver.edge_probe_cache_stats()
	var hit_timing: Dictionary = solver._source_timing(move_id, context, {})
	var after_hit := ComboSolver.edge_probe_cache_stats()
	_check(int(after_hit["timing_hits"]) == int(before_hit["timing_hits"]) + 1 \
		and int(hit_timing["recover_age"]) == int(cold_timing["recover_age"]) \
		and int(hit_timing["hit_frame"]) == int(cold_timing["hit_frame"]),
		"timing namespace: second query hits with identical values")
	hit_timing["recover_age"] = 999999
	hit_timing["hit_frame"] = -999
	hit_timing["recover_truncated"] = not bool(hit_timing["recover_truncated"])
	var again: Dictionary = solver._source_timing(move_id, context, {})
	_check(int(again["recover_age"]) == int(cold_timing["recover_age"]) \
		and int(again["hit_frame"]) == int(cold_timing["hit_frame"]) \
		and bool(again["recover_truncated"]) == bool(cold_timing["recover_truncated"]),
		"mutating a thawed timing dict does not leak into the cache snapshot")


# --- 门 6：跨入口复用（solve 之后 analyze）---


func _test_cross_entrypoint_reuse() -> void:
	var table := Fixture.new().table(2)
	var uncached_analyze := _analyze_recorded(table, true)
	ComboSolver.clear_edge_probe_cache()
	_solve_recorded(table, false, false)
	var before := ComboSolver.edge_probe_cache_stats()
	var cached_analyze := _analyze_recorded(table, false)
	var after := ComboSolver.edge_probe_cache_stats()
	_check(uncached_analyze["fingerprint"] == cached_analyze["fingerprint"],
		"analyze after solve produces the identical fingerprint (entrypoint ordering face)")
	_check(int(after["edge_hits"]) > int(before["edge_hits"]),
		"analyze reuses solve's probe entries (%d edge hits; timing %d — subsumed while edges hit)" % [
			int(after["edge_hits"]) - int(before["edge_hits"]),
			int(after["timing_hits"]) - int(before["timing_hits"])])
	_payload["cross_entry"] = {
		"edge_hits": int(after["edge_hits"]) - int(before["edge_hits"]),
		"timing_hits": int(after["timing_hits"]) - int(before["timing_hits"]),
		"session_steps_uncached": int(uncached_analyze["counts"]["session_steps"]),
		"session_steps_cached": int(cached_analyze["counts"]["session_steps"]),
	}


# --- 门 8：候选构造不污染 canonical 上下文（共享链 via_text 就地改写回归门）---


func _test_context_candidates_no_pollution() -> void:
	var loaded := MoveTable.load_default()
	if not loaded.ok:
		_check(false, "default manifest loads for the context pollution gate")
		return
	var solver := ComboSolver.new(loaded.moves)
	var contexts: Dictionary = solver._build_contexts()
	var before := _context_signatures(solver, contexts)
	var candidates: Array = []
	candidates.append_array(solver._air_exit_context_candidates("6D", contexts))
	candidates.append_array(solver._landing_seam_context_candidates("jA", contexts))
	candidates.append_array(solver._special_entry_context_candidates("5D", contexts))
	_check(_context_signatures(solver, contexts) == before,
		"candidate construction leaves every cached context signature unchanged (no shared-link via_text writes)")
	var polluted := ""
	for move_id in contexts:
		for link in contexts[move_id]:
			if link.via_text != "" and link.trigger == ComboSolver.ChainLink.Trigger.START:
				polluted = "%s(%s)" % [move_id, link.via_text]
				break
		if polluted != "":
			break
	_check(polluted == "", "canonical START links keep pristine via_text (was: %s)" % polluted)


func _context_signatures(solver: ComboSolver, contexts: Dictionary) -> Dictionary:
	var signatures := {}
	for move_id in contexts:
		signatures[move_id] = solver._context_signature(contexts[move_id])
	return signatures


# --- 录制与序列工具 ---


func _solve_recorded(table: Dictionary, legacy_path: bool, probe_cache_off: bool, facings: Array[int] = [1, -1]) -> Dictionary:
	ComboSolver.clear_result_cache()
	ComboSolver._compiled_index_disabled = legacy_path
	ComboSolver._edge_probe_cache_disabled = probe_cache_off
	if probe_cache_off:
		ComboSolver.clear_edge_probe_cache()
	var stats_before := ComboSolver.edge_probe_cache_stats()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.facings = facings
	var report := ComboSolver.solve(opts)
	var stats_after := ComboSolver.edge_probe_cache_stats()
	ComboSolver._compiled_index_disabled = false
	ComboSolver._edge_probe_cache_disabled = false
	return {
		"report": report,
		"fingerprint": _metrics._fingerprint(report),
		"counts": ComboSolver.last_request_profile_v2(),
		"stats": stats_after if probe_cache_off else _stats_delta(stats_before, stats_after),
	}


func _analyze_recorded(table: Dictionary, probe_cache_off: bool) -> Dictionary:
	ComboSolver.clear_result_cache()
	ComboSolver._edge_probe_cache_disabled = probe_cache_off
	if probe_cache_off:
		ComboSolver.clear_edge_probe_cache()
	var report := ComboSolver.analyze(table)
	ComboSolver._edge_probe_cache_disabled = false
	return {
		"report": report,
		"fingerprint": _metrics._fingerprint(report),
		"counts": ComboSolver.last_request_profile_v2(),
	}


func _stats_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"edge_hits": int(after["edge_hits"]) - int(before["edge_hits"]),
		"edge_misses": int(after["edge_misses"]) - int(before["edge_misses"]),
		"timing_hits": int(after["timing_hits"]) - int(before["timing_hits"]),
		"timing_misses": int(after["timing_misses"]) - int(before["timing_misses"]),
	}


func _stats_of(run: Dictionary) -> Dictionary:
	return {
		"stats": run["stats"],
		"session_steps": int(run["counts"]["session_steps"]),
		"edge_built": int(run["counts"]["edge_built"]),
		"gap_built": int(run["counts"]["gap_built"]),
	}


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
