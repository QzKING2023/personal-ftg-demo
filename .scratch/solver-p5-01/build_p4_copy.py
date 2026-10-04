# -*- coding: utf-8 -*-
# Build a P4-equivalent copy of combo_solver.gd for fingerprint comparison:
# revert the executing replacements of P5 (_analyze restructure, solve loop,
# _verify_routes_spatial extraction), strip class_name, keep inert additions.
import io

src = io.open(r"D:\Godot\Program\ftgdemo\scripts\combat\combo_solver.gd", encoding="utf-8").read()

# 1) strip class_name line
assert src.startswith("class_name ComboSolver\n")
out = "extends RefCounted\n" + src[len("class_name ComboSolver\n"):]

# internal self-references to ComboSolver.* inside the copy still resolve to the
# REAL ComboSolver (global class) — fine for _fingerprint-free usage, but
# CycleInvariant.evaluate references ComboSolver.MAX_CYCLE_LAPS: constant equal
# in both. SolverOptions/SolverReport referenced in copy's signatures resolve to
# the real classes (same shape superset). solve() returns real SolverReport.

def replace_once(old, new, what):
    global out
    assert out.count(old) == 1, (what, out.count(old))
    out = out.replace(old, new)

# 2) revert solve() facing loop to original
new_solve_loop = '''	var mode := {"complete": opts.complete, "watchdog_ms": opts.watchdog_ms, "resume_path": opts.resume_path}
	var primary := ComboSolver.new(table)._analyze(facings[0], opts.start, true, opts.spatial, mode)
	var facing_texts: Array[String] = []
	for facing in facings:
		facing_texts.append(_facing_text(facing))
	primary.start_lines.append("验证面向：%s" % "、".join(facing_texts))
	if primary.paused_incomplete:
		return _solve_paused_return(primary, null, facings, 0, mode, {})
	var primary_sections := _signature_sections(primary, facings[0])
	for i in range(1, facings.size()):
		var run := ComboSolver.new(table)._analyze(facings[i], opts.start, true, opts.spatial, mode)
		if run.paused_incomplete:
			return _solve_paused_return(run, primary, facings, i, mode, primary_sections)
		_merge_facing_run(primary, run, facings[i], primary_sections)
	if facings.size() > 1:
		primary.summary += "左右面向分别验证%s。" % ("，镜像一致" if primary.mirror_consistent else "，但结果不一致（见注）")
	primary.spatial_lines = _spatial_report_lines(primary, facings, opts.spatial != null)
	if bool(request.get("cacheable", false)) and result_cache_enabled() and not primary.refused and not primary.paused_incomplete:
		return _cache_store(request, primary)
	return primary
'''
old_solve_loop = '''	var primary := ComboSolver.new(table)._analyze(facings[0], opts.start, true, opts.spatial)
	var facing_texts: Array[String] = []
	for facing in facings:
		facing_texts.append(_facing_text(facing))
	primary.start_lines.append("验证面向：%s" % "、".join(facing_texts))
	var primary_sections := _signature_sections(primary, facings[0])
	for i in range(1, facings.size()):
		var run := ComboSolver.new(table)._analyze(facings[i], opts.start, true, opts.spatial)
		primary.verified_facings.append(facings[i])
		var sections := _signature_sections(run, facings[i])
		var diff: Array[String] = []
		for section in ["edges", "gaps", "routes", "cycles"]:
			if sections[section] != primary_sections[section]:
				diff.append(_SECTION_LABELS[section])
		if diff.is_empty():
			primary.notes.append("面向 %s 镜像验证一致：接续边/配置缺口/路线/循环与相对输入在两侧完全对称" % _facing_text(facings[i]))
		else:
			primary.mirror_consistent = false
			primary.notes.append("面向 %s 与面向 %s 的%s结果不一致——镜像对称被打破，请回报该差异" % [
				_facing_text(facings[i]), _facing_text(facings[0]), "、".join(diff),
			])
		_merge_route_spatial(primary, run)
		primary.guide_lines.append_array(run.guide_lines)
	if facings.size() > 1:
		primary.summary += "左右面向分别验证%s。" % ("，镜像一致" if primary.mirror_consistent else "，但结果不一致（见注）")
	primary.spatial_lines = _spatial_report_lines(primary, facings, opts.spatial != null)
	if bool(request.get("cacheable", false)) and result_cache_enabled() and not primary.refused:
		return _cache_store(request, primary)
	return primary
'''
replace_once(new_solve_loop, old_solve_loop, "solve loop")

# 3) revert _analyze to the original body (signature 4 params, no mode/progress)
i = out.index("func _analyze(facing := 1, start: SolverStartState = null, sort_outputs := false, spatial: SolverSpatialData = null, mode := {}) -> SolverReport:")
tail = out.index("## 一条验证完的接续边入报告与路线图", i)
original_analyze = '''func _analyze(facing := 1, start: SolverStartState = null, sort_outputs := false, spatial: SolverSpatialData = null) -> SolverReport:
\t_route_search_truncated = false
\t_facing = facing
\t_start = start
\t_pin_dx = PIN_DX
\tvar report := SolverReport.new()
\treport.scope = SCOPE_TEXT
\treport.verified_facings = [facing]
\treport.table_lines = _table_summary_lines()
\treport.start_lines = _start_state_lines()
\tif spatial != null:
\t\treport.start_lines.append("空间验证：已提供空间数据——地面站位 × 48/64/80 px 身体中心水平距离网格（验证面向与结果见空间分层节）")
\treport.first_candidates = _first_candidates()
\treport.binding_lines = _binding_variant_lines()
\tif _table_has_throw:
\t\treport.notes.append("普通投是 B+C 组合输入，无单键起手，不在首招候选（组合输入调度不在本入口范围）")
\tvar contexts := _build_contexts()
\tvar timing_cache := {}
\tvar valid_adj := {}
\tvar edge_kinds := {}
\t_profile_enter(_PROFILE_EDGE)
\tif _index != null:
\t\t## 索引路径（P1）：配置边候选在 _init 时已按旧循环的完整枚举序冻结成
\t\t## 描述符（from 表序 × kind 固定序 × 目标声明序，含蓄力变体派生边）。
\t\tfor descriptor in _index.configured_edges:
\t\t\t_profile_v2_bump("structure_candidates")
\t\t\tvar edge := _build_edge(descriptor.from_id, descriptor.to_id, descriptor.kind, contexts, timing_cache)
\t\t\t_register_edge(edge, report, valid_adj, edge_kinds)
\telse:
\t\tfor from_id in _table:
\t\t\tvar from_move := _table[from_id] as MoveData
\t\t\t## 投技不走单键/取消链起手（投技行为在后续 issue 实装），不进入接续图。
\t\t\tif from_move == null or from_move.is_throw():
\t\t\t\tcontinue
\t\t\tvar kinds_and_targets := [
\t\t\t\t[EdgeKind.CANCEL, from_move.cancel_targets],
\t\t\t\t[EdgeKind.CHAIN_CANCEL, from_move.chain_cancel_targets],
\t\t\t\t[EdgeKind.SPECIAL_CANCEL, from_move.special_cancel_targets],
\t\t\t\t[EdgeKind.JUMP_CANCEL, from_move.jump_cancel_targets],
\t\t\t\t[EdgeKind.LANDING_CANCEL, from_move.landing_cancel_targets],
\t\t\t\t[EdgeKind.NORMAL_LINK, from_move.link_targets],
\t\t\t\t[EdgeKind.REKKA_DERIVE, _rekka_targets_of(from_move)],
\t\t\t\t[EdgeKind.SPECIAL_ENTRY, from_move.special_entry_targets],
\t\t\t\t[EdgeKind.SPECIAL_ENTRY_LINK, from_move.special_entry_link_targets],
\t\t\t\t[EdgeKind.AIR_EXIT, from_move.air_exit_targets],
\t\t\t\t[EdgeKind.HIT_LANDING_CANCEL, from_move.hit_landing_cancel_targets],
\t\t\t]
\t\t\tfor pair in kinds_and_targets:
\t\t\t\tvar kind: EdgeKind = pair[0]
\t\t\t\tfor to_id in pair[1]:
\t\t\t\t\t_profile_v2_bump("structure_candidates")
\t\t\t\t\tvar edge := _build_edge(from_id, to_id, kind, contexts, timing_cache)
\t\t\t\t\t_register_edge(edge, report, valid_adj, edge_kinds)
\t\t\t\t\t## 蓄力变体（票据 06）：目标声明蓄力时，同一接缝另验证按住至阈值
\t\t\t\t\t## 的蓄力版提交（to 换为 charge_only 目标，独立成边、独立验证）。
\t\t\t\t\tvar pair_to := _table.get(to_id) as MoveData
\t\t\t\t\tif pair_to != null and pair_to.is_chargeable() and _table.has(pair_to.charge_move_id):
\t\t\t\t\t\t_profile_v2_bump("structure_candidates")
\t\t\t\t\t\t\tvar charged_edge := _build_edge(from_id, pair_to.charge_move_id, kind, contexts, timing_cache)
\t\t\t\t\t\t\t_register_edge(charged_edge, report, valid_adj, edge_kinds)
\t_profile_exit()
\t_profile_enter(_PROFILE_GAP)
\t_enumerate_gaps(contexts, timing_cache, report)
\t_profile_exit()
\tif report.edges.any(func(edge: SolverEdge) -> bool: return edge.blocked_valid):
\t\treport.notes.append("被防取消边只在固定探针姿态下验证取消时序（被防是独立接触结果，不产生命中，不入路线/循环图）；被防安全性（指定反击招式、时机、距离、版中/版边与左右面向）必须真实空间回放（replay-required），静态报告不下结论")
\t## 图的路线起点：起始姿态下单键可起手、无方向派生的打击招式（按表内顺序，确定性枚举）。
\tvar sources: Array[String] = []
\tfor move_id in _table:
\t\tif _is_plain_start_id(move_id):
\t\t\tsources.append(move_id)
\t_profile_enter(_PROFILE_ROUTE)
\tfor start_id in sources:
\t\t_walk_routes(start_id, [start_id], valid_adj, report.routes, contexts, edge_kinds)
\t\tif _route_search_truncated:
\t\t\tbreak
\t_profile_exit()
\tif _route_search_truncated:
\t\treport.notes.append("可读路线枚举达到 %d 条报告上限，路线集合未完成；已输出的路线仍逐帧验证，接续边与循环结论不受该报告上限影响" % MAX_ROUTE_REPORTS)
\t_profile_enter(_PROFILE_ROUTE)
\tfor cycle_ids in _elementary_cycles(valid_adj):
\t\tvar cycle := _simulate_cycle(cycle_ids, contexts, edge_kinds)
\t\tif cycle.outcome == SolverCycle.Outcome.PROVEN:
\t\t\treport.cycles.append(cycle)
\t\telse:
\t\t\tvar label: String = " → ".join(cycle_ids) + " → 回到 " + cycle_ids[0]
\t\t\tif cycle.outcome == SolverCycle.Outcome.HORIZON_TRUNCATED \\
\t\t\t\t\tor cycle.outcome == SolverCycle.Outcome.LAPS_EXHAUSTED:
\t\t\t\treport.incomplete_cycle_count += 1
\t\t\t\treport.notes.append("结构性循环 %s：%s" % [label, cycle.reason])
\t\t\telse:
\t\t\t\treport.notes.append("结构性循环 %s 在逐圈模拟中断开，不构成有效循环：%s" % [label, cycle.reason])
\t_profile_exit()
\tif spatial != null:
\t\t_profile_enter(_PROFILE_ROUTE)
\t\t_verify_routes_spatial(report, contexts, edge_kinds)
\t\t_profile_exit()
\treport.safe = report.cycles.is_empty()
\tif sort_outputs:
\t\t## 稳定排序（issue 19）：排序键含全部并列维度（from/to/kind 唯一、路线标签唯一），
\t\t## 与枚举顺序无关的确定输出，供跨运行/跨面向对拍。
\t\treport.edges.sort_custom(func(a: SolverEdge, b: SolverEdge) -> bool:
\t\t\treturn _edge_sort_key(a) < _edge_sort_key(b))
\t\treport.gaps.sort_custom(func(a: SolverEdge, b: SolverEdge) -> bool:
\t\t\treturn _edge_sort_key(a) < _edge_sort_key(b))
\t\treport.routes.sort_custom(func(a: SolverRoute, b: SolverRoute) -> bool:
\t\t\treturn a.label() < b.label())
\t\treport.cycles.sort_custom(func(a: SolverCycle, b: SolverCycle) -> bool:
\t\t\treturn a.label() < b.label())
\treport.summary = _build_summary(report)
\treport.guide_lines = _guide_lines(report)
\treturn report


'''
out = out[:i] + original_analyze + out[tail:]

# 4) revert _verify_routes_spatial extraction (original single function)
new_spatial = '''func _verify_routes_spatial(report: SolverReport, contexts: Dictionary, edge_kinds: Dictionary) -> void:
\tfor route in report.routes:
\t\t_verify_route_spatial(route, contexts, edge_kinds)
'''
# keep the extracted helper too (harmless); just ensure wrapper unchanged from P4
# P4 body:
old_spatial_body = '''func _verify_routes_spatial(report: SolverReport, contexts: Dictionary, edge_kinds: Dictionary) -> void:
\tfor route in report.routes:
\t\tif not route.timing_valid:
\t\t\tcontinue
\t\tvar failures: Array[String] = []
\t\tfor distance in SPATIAL_PROBE_DISTANCES:
\t\t\t_profile_v2_bump("spatial_rechecks")
\t\t\t_pin_dx = distance
\t\t\tvar run := _route_run(route.move_ids, contexts, edge_kinds)
\t\t\tif not run["ok"]:
\t\t\t\tfailures.append("%d px：%s" % [distance, _spatial_failure_text(run)])
\t\t_pin_dx = PIN_DX
\t\troute.spatial_state = SolverRoute.SpatialState.VALID if failures.is_empty() \\
\t\t\telse SolverRoute.SpatialState.INVALID
\t\troute.spatial_failures = failures
'''
replace_once(new_spatial, old_spatial_body, "verify_routes_spatial")

# 5) _route_run: drop the record flag (P4 form)
new_route_run = '''\tvar opts := {}
\tif not _route_leaf_memo_disabled:
\t\topts["record_checkpoints"] = true
\treturn _delay_search(links, adjustable, adjustable.size(), opts)'''
old_route_run = '''\treturn _delay_search(links, adjustable, adjustable.size(), {})'''
replace_once(new_route_run, old_route_run, "route_run opts")

io.open(r"D:\Godot\Program\ftgdemo\.scratch\solver-p5-01\combo_solver_p4.gd", "w", encoding="utf-8", newline="").write(out)
print("p4 copy written, lines:", out.count("\n"))
