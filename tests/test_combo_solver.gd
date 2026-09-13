extends SceneTree
## Combo Solver seam 测试（issue 06）：默认表地面路线、注入的有效/无效回边与报告内容。
## 运行：godot --headless --path . -s res://tests/test_combo_solver.gd
## Solver 只用私有 CombatSession 探针；本文件同时打印默认招式表的可读报告供设计者查阅。

var _failures := 0


func _initialize() -> void:
	print("")
	for line in ComboSolver.analyze().to_lines():
		print("  " + line)
	print("")
	_test_default_table_reports_ground_route()
	_test_numbers_match_runtime_session()
	_test_injected_valid_back_edge_reports_cycle()
	_test_injected_slow_back_edge_not_misreported()
	_test_injected_stance_back_edge_not_misreported()
	_test_finisher_back_edge_not_misreported()
	_test_wait_window_clamped_by_window_and_hitstun()
	_test_solver_does_not_modify_runtime_state()
	_test_report_lines_readable()
	_test_analysis_is_deterministic()
	print("")
	if _failures == 0:
		print("ALL SOLVER TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 测试用例 ---

func _test_default_table_reports_ground_route() -> void:
	var report := ComboSolver.analyze()
	_check(report.safe and report.cycles.is_empty(), "default table reports no valid cycle")
	_check(report.edges.size() == 4, "default table enumerates 4 edges (5A->5B, 5A->236C, 5B->5D, 5B->214D)")
	var ab := _find_edge(report, "5A", "5B")
	_check(ab != null and ab.valid, "5A -> 5B is a valid continuation")
	if ab != null:
		_check(ab.valid and ab.hit_age == 4 and ab.recover_age == 21, "5A -> 5B timing: earliest hit at age 4 (startup 4), dummy recoverable through age 21 (airtime 10 + hitstun 12 - 1)")
		_check(ab.valid and ab.wait_from == 0 and ab.wait_to == GameParams.CANCEL_WINDOW_FRAMES, "5A -> 5B valid wait range 0-8 (cancel window binds, stun would allow 17)")
	var bd := _find_edge(report, "5B", "5D")
	_check(bd != null and bd.valid and bd.hit_age == 5 and bd.recover_age == 21, "5B -> 5D valid: earliest hit at age 5, recover age 21")
	var derivative := _find_edge(report, "5A", "236C")
	_check(derivative != null and not derivative.valid and "07" in derivative.reason, "derivative edge 5A -> 236C is marked as issue-07 scope")
	var derivative_two := _find_edge(report, "5B", "214D")
	_check(derivative_two != null and not derivative_two.valid, "derivative edge 5B -> 214D is excluded")
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null, "report contains the readable 5A -> 5B -> 5D route")
	if route != null:
		_check(route.hit_frames == [6, 10, 15], "route hit frames are 6/10/15, matching the runtime ground route")
		_check(route.combo_hits == 3, "route counts 3 hits")
		_check(_approx(route.total_damage, 35.2), "route total damage is 35.2 with decay applied")
		_check("收尾" in route.note, "route notes the finisher ending while keeping the knockdown handling")
	var launcher_route := _find_route(report, ["5C"])
	_check(launcher_route != null and launcher_route.combo_hits == 1 and _approx(launcher_route.total_damage, GameParams.MOVE_5C_DAMAGE), "5C appears as a single-move route with no ground followup")
	_check(report.summary != "" and "未发现" in report.summary, "summary states no cycle was found")
	_check("不证明" in report.scope, "scope statement disclaims spatial/neutral/collision proofs")


func _test_numbers_match_runtime_session() -> void:
	# 与真实 CombatSession 对拍：同一站位下 5A 的命中帧与木桩恢复帧必须一致。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	var hit_frame := -1
	var recover_frame := -1
	for frame in range(1, 60):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frame = frame
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recover_frame = frame
	var report := ComboSolver.analyze()
	var ab := _find_edge(report, "5A", "5B")
	_check(hit_frame == 6 and recover_frame == 27, "runtime 5A hits on frame 6 and naturally recovers on frame 27")
	_check(ab != null and ab.valid and ab.recover_age == recover_frame - hit_frame, "solver recover age matches the runtime session (21)")
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null and route.hit_frames == [6, 10, 15], "solver route hit frames match the runtime ground-route test")


func _test_injected_valid_back_edge_reports_cycle() -> void:
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	var report := ComboSolver.analyze(table)
	_check(not report.safe, "report is unsafe after injecting the valid 5B -> 5A back edge")
	_check(report.cycles.size() == 1, "exactly one valid cycle is detected")
	if report.cycles.size() == 1:
		var cycle := report.cycles[0]
		_check(cycle.route == ["5A", "5B"], "cycle route is 5A -> 5B -> back to 5A")
		_check(cycle.sustained and cycle.proven, "cycle is proven by lap simulation with dummy-state recurrence")
		_check(cycle.period_frames == 27, "cycle period is 27 frames (4th starter hit recurs the 1st exactly)")
		_check(cycle.laps_observed == 4, "state recurrence is observed at the start of lap 4")
	var ba := _find_edge(report, "5B", "5A")
	_check(ba != null and ba.valid and ba.hit_age == 5 and ba.recover_age == 21, "back edge 5B -> 5A is valid: earliest hit age 5 <= recover age 21")
	_check("有效循环" in report.summary, "summary reports the effective cycle")


func _test_injected_slow_back_edge_not_misreported() -> void:
	# 结构上存在 5A → 5B → 5E → 5A 回路，但 5B → 5E 的目标前摇 25 帧
	# 晚于木桩恢复（第 21 帧）——等待超时的回边不得被误报为循环。
	var table := MoveData.default_table()
	var slow := MoveData.new()
	slow.move_name = "5E"
	slow.startup_frames = 25
	slow.active_frames = 2
	slow.recovery_frames = 8
	slow.base_damage = 10
	slow.hitstun_frames = GameParams.HITSTUN_FRAMES
	slow.knockback = 0.0
	slow.knockback_up = GameParams.ATTACK_KNOCKBACK_UP
	slow.cancel_targets = ["5A"]
	table["5E"] = slow
	(table["5B"] as MoveData).cancel_targets = ["5D", "5E"]
	var report := ComboSolver.analyze(table)
	var be := _find_edge(report, "5B", "5E")
	_check(be != null and not be.valid, "timeout back edge 5B -> 5E is excluded")
	if be != null:
		_check("等待超时" in be.reason and "恢复" in be.reason, "exclusion reason says the hit lands after dummy recovery")
		_check(be.hit_age == 25 and be.recover_age == 21, "timing: earliest hit age 25 > recover age 21")
	var ea := _find_edge(report, "5E", "5A")
	_check(ea != null and ea.valid, "the structural edge 5E -> 5A is itself still valid")
	_check(report.safe and report.cycles.is_empty(), "a timing-insufficient back edge is never misreported as a cycle")


func _test_injected_stance_back_edge_not_misreported() -> void:
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "jA"]
	var report := ComboSolver.analyze(table)
	var edge := _find_edge(report, "5B", "jA")
	_check(edge != null and not edge.valid, "stance-mismatched back edge 5B -> jA is excluded")
	if edge != null:
		_check("姿态" in edge.reason and "空中" in edge.reason, "exclusion reason says the stance mismatches (air move)")
	_check(report.safe and report.cycles.is_empty(), "a stance-mismatched back edge is never misreported as a cycle")


func _test_finisher_back_edge_not_misreported() -> void:
	# 收尾招式命中即结束连段、不开放命中确认取消：5D → 5A 结构回边不可行。
	var table := MoveData.default_table()
	(table["5D"] as MoveData).cancel_targets = ["5A"]
	var report := ComboSolver.analyze(table)
	var edge := _find_edge(report, "5D", "5A")
	_check(edge != null and not edge.valid, "finisher back edge 5D -> 5A is excluded")
	if edge != null:
		_check("收尾" in edge.reason, "exclusion reason says the finisher ends the combo and opens no cancel")
	_check(report.safe and report.cycles.is_empty(), "a finisher back edge is never misreported as a cycle")


func _test_wait_window_clamped_by_window_and_hitstun() -> void:
	# 有效等待范围由取消窗口与「命中不晚于木桩恢复」共同收窄：
	# 5F（硬直 4、无击飞、窗口 8）→ 5B（前摇 4）：最早命中恰在恢复帧当帧（判定先于恢复结算），
	# 边界有效但只有 w=0 可用；5F → 5A（前摇 5）：命中晚于恢复——等待超时排除。
	# 5G（硬直 12、无击飞、窗口 2）→ 5B：硬直允许到 w=8，窗口 2 是收窄方。
	var table := MoveData.default_table()
	var quick := MoveData.new()
	quick.move_name = "5F"
	quick.startup_frames = 2
	quick.active_frames = 2
	quick.recovery_frames = 3
	quick.base_damage = 10
	quick.hitstun_frames = 4
	quick.knockback = 0.0
	quick.knockback_up = 0.0
	quick.cancel_targets = ["5A", "5B"]
	table["5F"] = quick
	var wide := MoveData.new()
	wide.move_name = "5G"
	wide.startup_frames = 2
	wide.active_frames = 2
	wide.recovery_frames = 3
	wide.base_damage = 10
	wide.hitstun_frames = 12
	wide.knockback = 0.0
	wide.knockback_up = 0.0
	wide.cancel_window_frames = 2
	wide.cancel_targets = ["5B"]
	table["5G"] = wide
	var report := ComboSolver.analyze(table)
	var fb := _find_edge(report, "5F", "5B")
	_check(fb != null and fb.valid, "boundary edge 5F -> 5B is valid: earliest hit lands exactly on the recovery frame (detection precedes the tick)")
	if fb != null:
		_check(fb.valid and fb.hit_age == 4 and fb.recover_age == 4, "timing: earliest hit age 4 = recover age 4")
		_check(fb.valid and fb.wait_from == 0 and fb.wait_to == 0, "5F -> 5B valid wait range is only 0-0 (hitstun 4 minus startup 4; configured window 8)")
	var fa := _find_edge(report, "5F", "5A")
	_check(fa != null and not fa.valid, "5F -> 5A with startup 5 exceeding the stun is excluded")
	if fa != null:
		_check("等待超时" in fa.reason, "exclusion reason is the wait timeout")
	var gb := _find_edge(report, "5G", "5B")
	_check(gb != null and gb.valid, "5G -> 5B is valid (earliest hit age 4 <= recover age 12)")
	if gb != null:
		_check(gb.valid and gb.wait_from == 0 and gb.wait_to == 2, "5G -> 5B valid wait range is clamped by the cancel window to 0-2 (stun would allow 8)")


func _test_solver_does_not_modify_runtime_state() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	session.step(FrameInput.make(0, false, "A"))
	for i in range(5):
		session.step(FrameInput.new())
	var before := _snapshot_session(session)
	ComboSolver.analyze()
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	ComboSolver.analyze(table)
	var after := _snapshot_session(session)
	_check(before == after, "running the solver leaves every observable field of a live session untouched")
	_check(session.player_move_id == "5A" and session.combo_active and session.combo_hits == 1, "the live session is still inside its 5A hit-confirmed combo, unbothered by probes")


func _test_report_lines_readable() -> void:
	var report := ComboSolver.analyze()
	var lines := report.to_lines()
	var text := "\n".join(lines)
	_check(lines.size() >= 8, "report has enough lines (summary/scope/edges/routes/cycles sections)")
	_check("5A → 5B → 5D" in text, "report contains the 5A -> 5B -> 5D route text")
	_check("接续边" in text and "可读路线" in text and "循环" in text, "report sections are complete")
	_check("不证明" in text, "report carries the proof-scope disclaimer")


func _test_analysis_is_deterministic() -> void:
	var first := ComboSolver.analyze()
	var second := ComboSolver.analyze()
	var signature := func(report: ComboSolver.SolverReport) -> String:
		var parts: Array[String] = []
		for edge in report.edges:
			parts.append("%s:%s:%s" % [edge.label(), str(edge.valid), edge.reason])
		for route in report.routes:
			parts.append(route.label() + ":" + str(route.hit_frames))
		for cycle in report.cycles:
			parts.append(cycle.label() + ":" + str(cycle.period_frames))
		return "|".join(parts)
	_check(signature.call(first) == signature.call(second), "analyzing the same table twice yields identical results (deterministic graph)")


# --- 辅助 ---

func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id:
			return edge
	return null


func _find_route(report: ComboSolver.SolverReport, move_ids: Array[String]) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


func _snapshot_session(session: CombatSession) -> Array:
	return [
		session.player_position, session.player_velocity, session.player_facing,
		session.player_phase, session.player_on_ground, session.player_move_id,
		session.dummy_position, session.dummy_velocity, session.dummy_hp,
		session.dummy_state, session.dummy_on_ground, session.dummy_hitstun_left,
		session.combo_hits, session.combo_active, session.combo_total_damage,
		session.combo_last_scale, session.combo_last_damage,
	]


func _approx(value: float, expected: float, tolerance := 0.05) -> bool:
	return absf(value - expected) < tolerance


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1
