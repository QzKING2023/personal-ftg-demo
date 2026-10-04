# -*- coding: utf-8 -*-
# P5: solve() threading + _walk_routes cap + _verify_route_spatial + freeze/thaw.
import io

path = r"D:\Godot\Program\ftgdemo\scripts\combat\combo_solver.gd"
src = io.open(path, encoding="utf-8").read()


def replace_once(old, new, what):
    global src
    assert src.count(old) == 1, (what, src.count(old))
    src = src.replace(old, new)


# 1) solve() facing loop threading with mode/pause
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
replace_once(old_solve_loop, new_solve_loop, "solve facing loop")

# 2) _walk_routes cap
replace_once(
    "\t\tif routes.size() >= MAX_ROUTE_REPORTS:\n",
    "\t\tif routes.size() >= _route_report_cap:\n",
    "walk_routes cap",
)

# 3) _verify_route_spatial extraction
old_spatial = '''func _verify_routes_spatial(report: SolverReport, contexts: Dictionary, edge_kinds: Dictionary) -> void:
	for route in report.routes:
		if not route.timing_valid:
			continue
		var failures: Array[String] = []
		for distance in SPATIAL_PROBE_DISTANCES:
			_profile_v2_bump("spatial_rechecks")
			_pin_dx = distance
			var run := _route_run(route.move_ids, contexts, edge_kinds)
			if not run["ok"]:
				failures.append("%d px：%s" % [distance, _spatial_failure_text(run)])
		_pin_dx = PIN_DX
		route.spatial_state = SolverRoute.SpatialState.VALID if failures.is_empty() \\
			else SolverRoute.SpatialState.INVALID
		route.spatial_failures = failures
'''
new_spatial = '''func _verify_routes_spatial(report: SolverReport, contexts: Dictionary, edge_kinds: Dictionary) -> void:
	for route in report.routes:
		_verify_route_spatial(route, contexts, edge_kinds)


## 单条路线的空间复验（P5 抽出，_verify_routes_spatial/_analyze 空间阶段共用）：
## 换入 48/64/80 px 钉位重跑同一套逐帧结算——相交判定由真实 CombatSession 承担
##（不做纯几何近似）；P5 起路线叶执行的 trie 登记（scope 含 facing/pin_dx）使
## 同档兄弟路线只重放输入分歧后的 suffix。时序未成立的路线不作空间复验。
func _verify_route_spatial(route: SolverRoute, contexts: Dictionary, edge_kinds: Dictionary) -> void:
	if not route.timing_valid:
		return
	var failures: Array[String] = []
	for distance in SPATIAL_PROBE_DISTANCES:
		_profile_v2_bump("spatial_rechecks")
		_pin_dx = distance
		var run := _route_run(route.move_ids, contexts, edge_kinds)
		if not run["ok"]:
			failures.append("%d px：%s" % [distance, _spatial_failure_text(run)])
	_pin_dx = PIN_DX
	route.spatial_state = SolverRoute.SpatialState.VALID if failures.is_empty() \\
		else SolverRoute.SpatialState.INVALID
	route.spatial_failures = failures
'''
replace_once(old_spatial, new_spatial, "verify_route_spatial extraction")

# 4) freeze/thaw paused_incomplete
replace_once(
    '\t\t"mirror_consistent": report.mirror_consistent,\n\t}\n\n\nstatic func _freeze_edge',
    '\t\t"mirror_consistent": report.mirror_consistent,\n\t\t"paused_incomplete": report.paused_incomplete,\n\t}\n\n\nstatic func _freeze_edge',
    "freeze paused flag",
)
replace_once(
    '\treport.mirror_consistent = snapshot.get("mirror_consistent", true)\n',
    '\treport.mirror_consistent = snapshot.get("mirror_consistent", true)\n\treport.paused_incomplete = bool(snapshot.get("paused_incomplete", false))\n',
    "thaw paused flag",
)

io.open(path, "w", encoding="utf-8", newline="").write(src)
print("solve/spatial/freeze patches ok")
