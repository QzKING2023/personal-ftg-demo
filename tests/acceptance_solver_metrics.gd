extends RefCounted

## Acceptance-only request timing. Every call delegates to the production
## ComboSolver entry and its complete-request result cache; the label-only
## acceptance reuse layer was rolled back after isolation probes proved it
## used incomplete keys and returned shared mutable reports.

var _next_call := 0
var _calls := 0
var _underlying_calls := 0
var _reuse_hits := 0
var _elapsed_ms := 0.0
var _fingerprints: Dictionary = {}
var _reuse_enabled := false


func solve(options: ComboSolver.SolverOptions = null) -> ComboSolver.SolverReport:
	return _run_solve(options)


func solve_reused(_key: String, options: ComboSolver.SolverOptions = null) -> ComboSolver.SolverReport:
	return _run_solve(options)


func analyze(table: Dictionary = {}) -> ComboSolver.SolverReport:
	return _run_analyze(table)


func analyze_manifest(path: String) -> ComboSolver.SolverReport:
	_calls += 1
	_next_call += 1
	_underlying_calls += 1
	var started := Time.get_ticks_usec()
	var report := ComboSolver.analyze_manifest(path)
	_elapsed_ms += float(Time.get_ticks_usec() - started) / 1000.0
	_record("analyze-manifest-%d" % _next_call, report)
	return report


func analyze_reused(_key: String, table: Dictionary = {}) -> ComboSolver.SolverReport:
	return _run_analyze(table)


func reuse_stats() -> Dictionary:
	return {"reuse_hits": _reuse_hits, "reuse_enabled": _reuse_enabled}


func emit(test_name: String) -> void:
	var fingerprints: Array = []
	for entry in _fingerprints.values():
		fingerprints.append(entry)
	fingerprints.sort_custom(func(a, b): return str(a["fingerprint"]) < str(b["fingerprint"]))
	var total_requests := _calls
	var hit_rate := float(_reuse_hits) / float(total_requests) if total_requests > 0 else 0.0
	print("ACCEPTANCE_SOLVER_METRICS_JSON=" + JSON.stringify({
		"test": test_name,
		"calls": total_requests,
		"underlying_calls": _underlying_calls,
		"reuse_hits": _reuse_hits,
		"reuse_hit_rate": hit_rate,
		"elapsed_ms": _elapsed_ms,
		"unique_reports": fingerprints.size(),
		"reuse_enabled": _reuse_enabled,
		"combo_cache": ComboSolver.result_cache_stats(),
		"reports": fingerprints,
	}))


func _run_solve(options: ComboSolver.SolverOptions) -> ComboSolver.SolverReport:
	_calls += 1
	_next_call += 1
	_underlying_calls += 1
	var started := Time.get_ticks_usec()
	var report := ComboSolver.solve(options)
	_elapsed_ms += float(Time.get_ticks_usec() - started) / 1000.0
	_record("solve-%d" % _next_call, report)
	return report


func _run_analyze(table: Dictionary) -> ComboSolver.SolverReport:
	_calls += 1
	_next_call += 1
	_underlying_calls += 1
	var started := Time.get_ticks_usec()
	var report := ComboSolver.analyze(table)
	_elapsed_ms += float(Time.get_ticks_usec() - started) / 1000.0
	_record("analyze-%d" % _next_call, report)
	return report


func _record(key: String, report: ComboSolver.SolverReport) -> void:
	var fingerprint := _fingerprint(report)
	if not _fingerprints.has(fingerprint):
		_fingerprints[fingerprint] = {"fingerprint": fingerprint, "calls": 0, "keys": []}
	_fingerprints[fingerprint]["calls"] += 1
	_fingerprints[fingerprint]["keys"].append(key)


func _fingerprint(report: ComboSolver.SolverReport) -> String:
	var parts: Array[String] = []
	parts.append(str(report.safe))
	parts.append(report.summary)
	parts.append(report.scope)
	parts.append(str(report.incomplete_cycle_count))
	parts.append(str(report.refused))
	parts.append(report.refusal_reason)
	parts.append(report.refusal_advice)
	parts.append(str(report.mirror_consistent))
	for values in [report.notes, report.table_lines, report.start_lines, report.first_candidates,
			report.binding_lines, report.spatial_lines, report.guide_lines, report.verified_facings]:
		parts.append(str(values))
	for edge in report.edges:
		parts.append("edge:%s:%s:%d:%s:%s:%d:%d:%d:%d:%s:%d:%d:%s:%s" % [
			edge.from_id, edge.to_id, edge.kind, str(edge.valid), edge.reason,
			edge.wait_from, edge.wait_to, edge.hit_age, edge.recover_age,
			str(edge.recover_truncated), edge.align_from, edge.align_to,
			str(edge.blocked_valid), edge.blocked_reason,
		])
		for input in edge.align_inputs:
			parts.append(_input_signature(input))
	for gap in report.gaps:
		parts.append("gap:" + _edge_signature(gap))
	for route in report.routes:
		parts.append("route:%s:%s:%d:%.9f:%s:%s:%d:%s" % [
			str(route.move_ids), str(route.hit_frames), route.combo_hits, route.total_damage,
			route.note, str(route.timing_valid), route.spatial_state, str(route.spatial_failures),
		])
		for input in route.inputs:
			parts.append(_input_signature(input))
	for cycle in report.cycles:
		parts.append("cycle:%s:%d:%s:%d:%s:%s" % [
			str(cycle.route), cycle.period_frames, str(cycle.proven), cycle.outcome,
			str(cycle.laps_observed), cycle.reason + cycle.start_text,
		])
		for input in cycle.inputs:
			parts.append(_input_signature(input))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("\n".join(parts)).to_utf8_buffer())
	return context.finish().hex_encode()


func _input_signature(input: ComboSolver.ScheduledInput) -> String:
	return "%d:%d:%s:%s:%s" % [input.frame, input.axis, str(input.down), str(input.jump), input.key]


func _edge_signature(edge: ComboSolver.SolverEdge) -> String:
	var parts := [
		edge.from_id, edge.to_id, str(edge.kind), str(edge.valid), edge.reason,
		str(edge.wait_from), str(edge.wait_to), str(edge.hit_age), str(edge.recover_age),
		str(edge.recover_truncated), str(edge.align_from), str(edge.align_to),
		str(edge.blocked_valid), edge.blocked_reason,
	]
	for input in edge.align_inputs:
		parts.append(_input_signature(input))
	return ":".join(parts)
