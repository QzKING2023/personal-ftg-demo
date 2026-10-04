extends SceneTree

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics := AcceptanceSolverMetrics.new()


func _parts(report: ComboSolver.SolverReport) -> Dictionary:
	var parts := {}
	parts["safe"] = str(report.safe)
	parts["summary"] = report.summary
	parts["scope"] = report.scope
	parts["incomplete"] = str(report.incomplete_cycle_count)
	parts["refused"] = str(report.refused) + report.refusal_reason + report.refusal_advice
	parts["mirror"] = str(report.mirror_consistent)
	parts["notes"] = str(report.notes)
	parts["table_lines"] = str(report.table_lines)
	parts["start_lines"] = str(report.start_lines)
	parts["first_candidates"] = str(report.first_candidates)
	parts["binding_lines"] = str(report.binding_lines)
	parts["spatial_lines"] = str(report.spatial_lines)
	parts["guide_lines"] = str(report.guide_lines)
	parts["verified_facings"] = str(report.verified_facings)
	parts["edges"] = str(report.edges.size())
	for e_idx in range(report.edges.size()):
		parts["edge%d" % e_idx] = _metrics._edge_signature(report.edges[e_idx])
	for g_idx in range(report.gaps.size()):
		parts["gap%d" % g_idx] = _metrics._edge_signature(report.gaps[g_idx])
	for r_idx in range(report.routes.size()):
		var r: ComboSolver.SolverRoute = report.routes[r_idx]
		var inputs := []
		for input in r.inputs:
			inputs.append(_metrics._input_signature(input))
		parts["route%d" % r_idx] = "%s:%s:%d:%.9f:%s:%s:%d:%s" % [
			str(r.move_ids), str(r.hit_frames), r.combo_hits, r.total_damage,
			r.note, str(r.timing_valid), r.spatial_state, ";".join(inputs)]
	for c_idx in range(report.cycles.size()):
		parts["cycle%d" % c_idx] = str(report.cycles[c_idx].route)
	return parts


func _initialize() -> void:
	ComboSolver.set_result_cache_enabled(false)
	var on := ComboSolver.solve(null)
	ComboSolver._delay_prefix_restore_disabled = true
	var off := ComboSolver.solve(null)
	ComboSolver._delay_prefix_restore_disabled = false
	var a := _parts(on)
	var b := _parts(off)
	var diff_count := 0
	for key in a:
		if str(a[key]) != str(b.get(key, "<missing>")):
			diff_count += 1
			print("DIFF ", key)
			if key == "notes":
				var na: Array = on.notes
				var nb: Array = off.notes
				for idx in range(maxi(na.size(), nb.size())):
					var va := str(na[idx]) if idx < na.size() else "<none>"
					var vb := str(nb[idx]) if idx < nb.size() else "<none>"
					if va != vb:
						print("  note#", idx)
						print("  on : ", va)
						print("  off: ", vb)
	print("total differing parts: ", diff_count, " of ", a.size())
	quit(0)
