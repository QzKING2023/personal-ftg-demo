extends SceneTree

func _initialize() -> void:
	ComboSolver.set_result_cache_enabled(false)
	var report := ComboSolver.solve(null)
	print("safe=", report.safe, " incomplete_cycles=", report.incomplete_cycle_count)
	print("summary=", report.summary)
	print("verified_facings=", report.verified_facings)
	print("NOTES:")
	for n in report.notes:
		print("  N|", n)
	print("START_LINES:")
	for l in report.start_lines:
		print("  S|", l)
	print("SPATIAL_LINES:")
	for l in report.spatial_lines:
		print("  P|", l)
	print("first_candidates=", report.first_candidates)
	print("ROUTES(", report.routes.size(), "):")
	for r in report.routes:
		print("  R|", r.label(), "|valid=", r.timing_valid, "|hits=", str(r.hit_frames), "|inputs=", r.inputs.size())
	print("GUIDE_LINES(", report.guide_lines.size(), "):")
	for l in report.guide_lines:
		print("  G|", l)
	quit(0)
