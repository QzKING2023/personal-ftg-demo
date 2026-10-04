extends SceneTree


func _fp(report) -> String:
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
			parts.append("%d:%d:%s:%s:%s" % [input.frame, input.axis, str(input.down), str(input.jump), input.key])
	for gap in report.gaps:
		var gap_parts := [
			gap.from_id, gap.to_id, str(gap.kind), str(gap.valid), gap.reason,
			str(gap.wait_from), str(gap.wait_to), str(gap.hit_age), str(gap.recover_age),
			str(gap.recover_truncated), str(gap.align_from), str(gap.align_to),
			str(gap.blocked_valid), gap.blocked_reason,
		]
		for input in gap.align_inputs:
			gap_parts.append("%d:%d:%s:%s:%s" % [input.frame, input.axis, str(input.down), str(input.jump), input.key])
		parts.append("gap:" + ":".join(gap_parts))
	for route in report.routes:
		parts.append("route:%s:%s:%d:%.9f:%s:%s:%d:%s" % [
			str(route.move_ids), str(route.hit_frames), route.combo_hits, route.total_damage,
			route.note, str(route.timing_valid), route.spatial_state, str(route.spatial_failures),
		])
		for input in route.inputs:
			parts.append("%d:%d:%s:%s:%s" % [input.frame, input.axis, str(input.down), str(input.jump), input.key])
	for cycle in report.cycles:
		parts.append("cycle:%s:%d:%s:%d:%s:%s" % [
			str(cycle.route), cycle.period_frames, str(cycle.proven), cycle.outcome,
			str(cycle.laps_observed), cycle.reason + cycle.start_text,
		])
		for input in cycle.inputs:
			parts.append("%d:%d:%s:%s:%s" % [input.frame, input.axis, str(input.down), str(input.jump), input.key])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("\n".join(parts)).to_utf8_buffer())
	return ctx.finish().hex_encode()

func _initialize() -> void:
	ComboSolver.set_result_cache_enabled(false)
	var report = ComboSolver.solve(null)
	print("P4-copy solve(null) ", _fp(report).substr(0, 16))
	print("P4 baseline         e071fdc661bffe47")
	quit(0)
