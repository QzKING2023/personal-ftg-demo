extends SceneTree
## 票据 02 基线前置探针:实测默认表边数与空中 D 终段路线的回放终局,
## 为 test_combo_solver 两条票据 08 遗留期望(55 边计数、jD FINISHER 终局)
## 提供权威新值。代码路径镜像 tests/test_combo_solver.gd 的同名助手。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")


func _initialize() -> void:
	var metrics := AcceptanceSolverMetrics.new()
	var report := metrics.analyze_reused("default")
	print("PROBE edges=%d routes=%d" % [report.edges.size(), report.routes.size()])
	for edge in report.edges:
		if edge.from_id in ["j5D", "j6D", "j2D"] or edge.to_id in ["j5D", "j6D", "j2D"]:
			print("PROBE edge %s->%s kind=%s valid=%s" % [edge.from_id, edge.to_id,
				ComboSolver.EdgeKind.keys()[edge.kind], str(edge.valid)])
	var want: Array[String] = ["5A", "5B", "6A", "jA", "jB", "j5D"]
	var route: ComboSolver.SolverRoute = null
	for r in report.routes:
		if r.move_ids == want:
			route = r
			break
	print("PROBE route_found=%s" % str(route != null))
	if route != null:
		var replay := _replay_inputs(route.inputs, route.hit_frames[route.hit_frames.size() - 1])
		var names: Array[String] = []
		for reason in replay.end_reasons:
			names.append(CombatEvent.ComboEndReason.keys()[reason])
		print("PROBE end_reasons=%s hit_frames=%s combo_hits=%d total_damage=%s" % [
			str(names), str(replay.hit_frames), replay.combo_hits, str(replay.total_damage)])
	quit(0)


## 以下两助手逐字复制自 tests/test_combo_solver.gd,保持同一回放口径。

func _replay_inputs(inputs: Array, until := 0) -> Dictionary:
	var by_frame := {}
	var last := 0
	for spec in inputs:
		by_frame[spec.frame] = spec
		last = maxi(last, spec.frame)
	last = maxi(last, until)
	var session := CombatSession.new()
	var hit_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var air_hits_all_airborne := true
	var air_started := false
	var frame := 0
	while frame < last:
		frame += 1
		var input := FrameInput.new()
		if by_frame.has(frame):
			input = by_frame[frame].to_frame_input()
		if not session.player_on_ground:
			air_started = true
		var events := _step_logical(session, input)
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		var hit_now := false
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_now = true
			elif event.type == CombatEvent.Type.COMBO_ENDED:
				end_reasons.append(event.combo_end_reason)
		if hit_now:
			hit_frames.append(frame)
			if air_started and session.player_on_ground:
				air_hits_all_airborne = false
	return {
		"hit_frames": hit_frames,
		"combo_hits": session.combo_hits,
		"total_damage": session.combo_total_damage,
		"end_reasons": end_reasons,
		"air_hits_all_airborne": air_hits_all_airborne,
		"session": session,
	}


func _step_logical(session: CombatSession, input: FrameInput) -> Array[CombatEvent]:
	while session.hitstop_active():
		session.step(FrameInput.new())
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
	return session.step(input)
