extends SceneTree
## Combo Solver 完整结果缓存差分测试。
## 运行：godot --headless --path . -s res://tests/test_solver_cache.gd

const Metrics = preload("res://tests/acceptance_solver_metrics.gd")

var _failures := 0


func _initialize() -> void:
	ComboSolver.clear_result_cache()
	ComboSolver.set_result_cache_enabled(false)
	_test_cache_disabled_and_enabled_reports_match()
	_test_cache_hit_returns_fresh_report_graph()
	_test_request_dimensions_are_isolated()
	ComboSolver.set_result_cache_enabled(true)
	_test_wrapper_reused_calls_delegate_fully()
	print("")
	if _failures == 0:
		print("ALL SOLVER CACHE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _test_cache_disabled_and_enabled_reports_match() -> void:
	var table := _tiny_table(12)
	var options := _options(table)
	ComboSolver.clear_result_cache()
	ComboSolver.set_result_cache_enabled(false)
	var cold := ComboSolver.solve(options)
	ComboSolver.set_result_cache_enabled(true)
	var warm := ComboSolver.solve(options)
	_check(_report_signature(cold) == _report_signature(warm), "cache disabled/enabled reports are structurally identical")
	var stats := ComboSolver.result_cache_stats()
	_check(int(stats.get("misses", 0)) == 1, "the first enabled request records one cache miss")


func _test_cache_hit_returns_fresh_report_graph() -> void:
	var table := _tiny_table(13)
	var options := _options(table)
	ComboSolver.clear_result_cache()
	ComboSolver.set_result_cache_enabled(true)
	var first := ComboSolver.solve(options)
	var second := ComboSolver.solve(options)
	_check(first != second, "cache hit returns a new SolverReport")
	_check(_report_signature(first) == _report_signature(second), "cache hit preserves the complete report")
	first.summary = "mutated"
	_check(first.summary != second.summary, "mutating one report does not mutate the other")
	if not second.edges.is_empty():
		first.edges[0].reason = "mutated"
	_check(_report_signature(first) != _report_signature(second), "mutating one report edge does not mutate the other")
	if not second.gaps.is_empty():
		first.gaps[0].reason = "mutated"
		_check(_report_signature(first) != _report_signature(second), "mutating one report gap does not mutate the other")
	if not second.routes.is_empty() and not second.routes[0].inputs.is_empty():
		first.routes[0].inputs[0].key = "mutated"
		_check(first.routes[0].inputs[0].key != second.routes[0].inputs[0].key, "scheduled inputs are not shared between reports")
	var third := ComboSolver.solve(options)
	_check(_report_signature(third) == _report_signature(second), "mutating a returned report does not poison the cached snapshot")
	var stats := ComboSolver.result_cache_stats()
	_check(int(stats.get("hits", 0)) >= 2, "repeated identical requests record cache hits")


func _test_request_dimensions_are_isolated() -> void:
	var table := _tiny_table(14)
	ComboSolver.clear_result_cache()
	ComboSolver.set_result_cache_enabled(true)
	var base := ComboSolver.solve(_options(table))
	var air_start := ComboSolver.SolverStartState.new()
	air_start.stance = MoveData.Stance.AIR
	air_start.air_frames = 0
	var air_options := _options(table)
	air_options.start = air_start
	var air := ComboSolver.solve(air_options)
	_check(_report_signature(base) != _report_signature(air), "ground and explicit air starts do not share a cache entry")
	var spatial_options := _options(table)
	spatial_options.spatial = ComboSolver.SolverSpatialData.new()
	var spatial := ComboSolver.solve(spatial_options)
	_check(_report_signature(base) != _report_signature(spatial), "timing and spatial requests do not share a cache entry")
	var single_options := _options(table)
	single_options.facings = [1]
	var single := ComboSolver.solve(single_options)
	_check(_report_signature(base) != _report_signature(single), "single-facing and dual-facing requests do not share a cache entry")
	var edited := _tiny_table(15)
	var edited_report := ComboSolver.solve(_options(edited))
	_check(_report_signature(base) != _report_signature(edited_report), "different injected table contents do not share a cache entry")
	var resource_table := _tiny_table(16)
	var resource_options := _options(resource_table)
	var resource_before := ComboSolver.solve(resource_options)
	(resource_table["cache_probe"] as MoveData).base_damage = 17
	var resource_after := ComboSolver.solve(resource_options)
	_check(_report_signature(resource_before) != _report_signature(resource_after), "editing a resource invalidates the prior cache entry")


func _options(table: Dictionary) -> ComboSolver.SolverOptions:
	var options := ComboSolver.SolverOptions.new()
	options.move_table = table
	options.facings = [1, -1]
	return options


func _tiny_table(damage: int) -> Dictionary:
	var move := MoveData.new()
	move.move_id = "cache_probe"
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = "A"
	move.startup_frames = 1
	move.active_frames = 1
	move.recovery_frames = 1
	move.base_damage = damage
	move.attack_attribute = MoveData.AttackAttribute.MID
	move.hitbox_size = Vector2(80, 80)
	move.hitbox_gap = 0.0
	move.cancel_window_frames = 0
	move.starter_grade = MoveData.StarterGrade.A
	move.block_freeze_frames = 0
	move.block_stun_frames = 1
	move.block_pushback_px_s = 0.0
	move.priority = 0
	var profile := HitProfile.new()
	profile.target_state = HitProfile.TargetState.GROUNDED
	profile.hit_context = HitProfile.HitContext.NORMAL
	profile.reaction = HitProfile.Reaction.GROUND_HITSTUN
	profile.ground_stun_frames = 1
	profile.horizontal_speed_px_s = 0.0
	profile.upward_speed_px_s = 0.0
	move.hit_profiles = [profile]
	return {"cache_probe": move}


func _report_signature(report: ComboSolver.SolverReport) -> String:
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
	return "\n".join(parts)


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


## 验收侧包装的回退保持：solve_reused/analyze_reused 只计时委托，
## 相同 label 的不同请求不得命中同一份结果，返回值也不得共享可变报告。
func _test_wrapper_reused_calls_delegate_fully() -> void:
	var table := _tiny_table(21)
	var metrics := Metrics.new()
	var ground := _options(table)
	var first := metrics.solve_reused("same-label", ground)
	var air_start := ComboSolver.SolverStartState.new()
	air_start.stance = MoveData.Stance.AIR
	air_start.air_frames = 0
	var air := _options(table)
	air.start = air_start
	var changed := metrics.solve_reused("same-label", air)
	var oracle := ComboSolver.solve(air)
	_check(_report_signature(changed) == _report_signature(oracle),
		"same label with a different start state must not reuse the earlier result")
	var original := first.summary
	first.summary = "CALLER_MUTATION"
	var second := metrics.solve_reused("same-label", ground)
	_check(first != second and second.summary == original,
		"wrapper calls return independent reports; caller mutation is not observable")
	var emitted := metrics.reuse_stats()
	_check(int(emitted.get("reuse_hits", -1)) == 0 and not bool(emitted.get("reuse_enabled", true)),
		"wrapper reports zero label reuse and reuse disabled")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		print("FAIL: " + message)
