extends SceneTree
## 票据 02 基线前置探针(二):实测显式空中起始的首招候选与 jA→jB→j5D 路线,
## 为 test_solver_entry 两条 08 期望债提供权威值。镜像测试同代码路径
## (solve_reused("explicit-air", _explicit_air_options()))。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")


func _initialize() -> void:
	var metrics := AcceptanceSolverMetrics.new()
	var opts := ComboSolver.SolverOptions.new()
	opts.start = ComboSolver.SolverStartState.new()
	opts.start.stance = MoveData.Stance.AIR
	var report := metrics.solve_reused("explicit-air", opts)
	print("PROBE first_candidates_count=%d" % report.first_candidates.size())
	for line in report.first_candidates:
		print("PROBE cand %s" % line)
	var want: Array[String] = ["jA", "jB", "j5D"]
	var found := false
	for r in report.routes:
		if r.move_ids == want:
			found = true
			print("PROBE route_jA_jB_j5D FOUND hit_frames=%s combo_hits=%d damage=%s" % [
				str(r.hit_frames), r.combo_hits, str(r.total_damage)])
	if not found:
		print("PROBE route_jA_jB_j5D NOT_FOUND")
	var pair: ComboSolver.SolverRoute = null
	for r in report.routes:
		if r.move_ids == ["jA", "jB"]:
			pair = r
			break
	if pair != null:
		print("PROBE route_jA_jB_only hit_frames=%s combo_hits=%d damage=%s inputs=%d timing_valid=%s" % [
			str(pair.hit_frames), pair.combo_hits, str(pair.total_damage), pair.inputs.size(), str(pair.timing_valid)])
		print("PROBE route_jA_jB_note %s" % pair.note)
	else:
		print("PROBE route_jA_jB_only MISSING")
	var with_hits := 0
	for r in report.routes:
		if r.combo_hits > 0:
			with_hits += 1
	print("PROBE routes_total=%d routes_with_hits=%d" % [report.routes.size(), with_hits])
	for r in report.routes:
		if r.combo_hits > 0 and r.move_ids[0] == "jA":
			print("PROBE hit_route %s hits=%s combo=%d" % [str(r.move_ids), str(r.hit_frames), r.combo_hits])
	for r in report.routes:
		print("PROBE all_route %s hits=%s combo=%d timing=%s" % [str(r.move_ids), str(r.hit_frames), r.combo_hits, str(r.timing_valid)])
	quit(0)
