extends SceneTree
## Combo Solver seam 测试（旧 ftg-combo issue 06 + 07）：地面/空中路线、jump cancel、落地接续、
## 有限滞空资源区分与循环报告。
## 运行：godot --headless --path . -s res://tests/test_combo_solver.gd
## Solver 只用私有 CombatSession 探针；本文件同时打印默认招式表的可读报告供设计者查阅。

var _failures := 0


func _initialize() -> void:
	print("")
	for line in ComboSolver.analyze().to_lines():
		print("  " + line)
	print("")
	_test_default_table_reports_ground_route()
	_test_default_table_air_edges()
	_test_numbers_match_runtime_session()
	_test_full_air_route_matches_runtime()
	_test_landing_route_and_critical_frame()
	_test_jump_cancel_config_gates()
	_test_landing_seam_requires_alignment()
	_test_finite_air_resources_not_renewed()
	_test_injected_valid_back_edge_reports_cycle()
	_test_injected_landing_back_edge_reports_cycle()
	_test_injected_slow_back_edge_not_misreported()
	_test_injected_stance_back_edge_not_misreported()
	_test_finisher_back_edge_not_misreported()
	_test_wait_window_clamped_by_window_and_hitstun()
	_test_solver_claims_only_configured_connections()
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


# --- 测试用例（旧 ftg-combo issue 06：地面接续）---

func _test_default_table_reports_ground_route() -> void:
	var report := ComboSolver.analyze()
	_check(report.safe and report.cycles.is_empty(), "default table reports no valid cycle")
	_check(report.edges.size() == 9, "default table enumerates 9 edges (4 ground cancels incl. 2 derivatives, 2 jump cancels, 2 air cancels, 1 landing continuation)")
	var ab := _find_edge(report, "5A", "5B")
	_check(ab != null and ab.valid, "5A -> 5B is a valid continuation")
	if ab != null:
		_check(ab.valid and ab.hit_age == 5 and ab.recover_age == 21, "5A -> 5B timing: earliest hit at age 5 (B pairing wait 1 + startup 4), dummy recoverable through age 21 (airtime 10 + hitstun 12 - 1)")
		_check(ab.valid and ab.wait_from == 0 and ab.wait_to == GameParams.CANCEL_WINDOW_FRAMES - GameParams.THROW_COMBINATION_TOLERANCE, "5A -> 5B valid wait range 0-5 (cancel window minus the B pairing wait binds; stun would allow 16)")
	var bd := _find_edge(report, "5B", "5D")
	_check(bd != null and bd.valid and bd.hit_age == 5 and bd.recover_age == 21, "5B -> 5D valid: earliest hit at age 5, recover age 21")
	var derivative := _find_edge(report, "5A", "236C")
	_check(derivative != null and derivative.valid, "derivative edge 5A -> 236C is validated by feeding 236 before the cancel frame")
	if derivative != null:
		_check(derivative.valid and derivative.hit_age == 7, "236C connects 7 frames after 5A's confirm (pairing wait 1 + its own startup 6)")
	var derivative_two := _find_edge(report, "5B", "214D")
	_check(derivative_two != null and derivative_two.valid and derivative_two.hit_age == 7, "derivative edge 5B -> 214D is valid (feed 214 during 5B)")
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null, "report contains the readable 5A -> 5B -> 5D route")
	if route != null:
		_check(route.hit_frames == [6, 11, 16], "route hit frames are 6/11/16 (B cancels land one normal frame after each confirm)")
		_check(route.combo_hits == 3, "route counts 3 hits")
		_check(_approx(route.total_damage, 35.2), "route total damage is 35.2 with decay applied")
		_check("收尾" in route.note, "route notes the finisher ending while keeping the knockdown handling")
	_check(report.summary != "" and "未发现" in report.summary, "summary states no cycle was found")
	_check("不证明" in report.scope, "scope statement disclaims spatial/neutral/collision proofs")


func _test_numbers_match_runtime_session() -> void:
	# 与真实 CombatSession 对拍：同一站位下 5A 的命中帧与木桩恢复帧必须一致。
	# 运行时按物理帧计数（命中后 8 帧 Hitstop 顺延恢复帧）；Solver 的年龄按
	# 正常战斗帧计——两者相差恰为一次命中的停顿帧数。
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
	_check(hit_frame == 6 and recover_frame == 6 + 10 + GameParams.HITSTOP_FRAMES + GameParams.HITSTUN_FRAMES - 1, "runtime 5A hits on frame 6 and naturally recovers after the freeze-extended knockdown")
	_check(ab != null and ab.valid and ab.recover_age == recover_frame - hit_frame - GameParams.HITSTOP_FRAMES, "solver recover age (21 normal frames) matches the runtime session minus the frozen frames")
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null and route.hit_frames == [6, 11, 16], "solver route hit frames follow the new B pairing-wait timing (w=0 cancels resume on the first normal frame)")


func _test_injected_valid_back_edge_reports_cycle() -> void:
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	var report := ComboSolver.analyze(table)
	_check(not report.safe, "report is unsafe after injecting the valid 5B -> 5A back edge")
	_check(report.cycles.size() == 1, "exactly one valid cycle is detected")
	if report.cycles.size() == 1:
		var cycle := report.cycles[0]
		_check(cycle.route == ["5A", "5B"], "cycle route is 5A -> 5B -> back to 5A")
		_check(cycle.proven, "cycle is proven by lap simulation with settlement-state recurrence")
		_check(cycle.period_frames == 30, "cycle period is 30 frames (B pairing wait included)")
		_check(cycle.laps_observed == 5, "state recurrence is observed at the start of lap 5: the full settlement-state key (issue 21) needs the steady-state laps — the 5th starter hit recurs the 2nd exactly, one lap later than the dummy-only timing key did")
	var ba := _find_edge(report, "5B", "5A")
	_check(ba != null and ba.valid and ba.hit_age == 5 and ba.recover_age == 21, "back edge 5B -> 5A is valid: earliest hit age 5 <= recover age 21")
	_check("有效循环" in report.summary, "summary reports the effective cycle")


func _test_injected_slow_back_edge_not_misreported() -> void:
	# 结构上存在 5A → 5B → 5E → 5A 回路，但 5B → 5E 的目标前摇 25 帧
	# 晚于木桩恢复（第 21 帧）——等待超时的回边不得被误报为循环。
	var table := MoveData.default_table()
	var slow := _injected_move("5E", "E")
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
	# 有效等待范围由取消窗口与「命中不晚于木桩恢复」共同收窄（B 是投组合成员键，
	# 表内含 BC 投：命中当帧按下 w=0 于恢复首个正常帧消费，其余等待档 +3）：
	# 5F（硬直 4、无击飞、窗口 8）→ 5B（前摇 4 + 等待 1）：最早命中第 5 帧已过恢复——
	# 与 5F → 5A（前摇 5）同样等待超时排除。
	# 5G（硬直 12、无击飞、窗口 2）→ 5B：只有 w=0 的消费年龄落在窗口 2 内。
	var table := MoveData.default_table()
	var quick := _injected_move("5F", "F")
	quick.startup_frames = 2
	quick.active_frames = 2
	quick.recovery_frames = 3
	quick.base_damage = 10
	quick.hitstun_frames = 4
	quick.knockback = 0.0
	quick.knockback_up = 0.0
	quick.cancel_targets = ["5A", "5B"]
	table["5F"] = quick
	var wide := _injected_move("5G", "G")
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
	_check(fb != null and not fb.valid, "5F -> 5B is now excluded too: the B pairing wait pushes the earliest hit one frame past the 4-frame stun")
	if fb != null:
		_check("等待超时" in fb.reason, "exclusion reason is the wait timeout (earliest hit age 5 > recover age 4)")
	var fa := _find_edge(report, "5F", "5A")
	_check(fa != null and not fa.valid, "5F -> 5A with startup 5 exceeding the stun is excluded")
	if fa != null:
		_check("等待超时" in fa.reason, "exclusion reason is the wait timeout")
	var gb := _find_edge(report, "5G", "5B")
	_check(gb != null and gb.valid, "5G -> 5B is valid (earliest hit age 4 <= recover age 12)")
	if gb != null:
		_check(gb.valid and gb.wait_from == 0 and gb.wait_to == 0, "5G -> 5B valid wait range is clamped by the cancel window to 0-0 (window 2 only admits the hit-frame press; stun would allow 7)")


# --- 测试用例（旧 ftg-combo issue 07：空中接续与有限资源）---

func _test_default_table_air_edges() -> void:
	# 验收 1：空中姿态取消、jump cancel 配置与显式落地接续都进入接续图，并在真实结算中验证。
	var report := ComboSolver.analyze()
	var jump_5c := _find_edge(report, "5C", "jA", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(jump_5c != null and jump_5c.valid, "5C -> jA is a valid jump-cancel edge")
	if jump_5c != null:
		_check(jump_5c.valid and jump_5c.hit_age == 5 + GameParams.PLAYER_PREJUMP_FRAMES, "jump-canceled jA hits 9 frames after 5C's confirm (Space on the hit frame, prep 4, press at takeoff+1, startup 4)")
	var jump_236c := _find_edge(report, "236C", "jA", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(jump_236c != null and jump_236c.valid and jump_236c.hit_age == 5 + GameParams.PLAYER_PREJUMP_FRAMES, "236C -> jA is a valid jump-cancel edge from the derivative launcher")
	var air_cancel := _find_edge(report, "jA", "jB", ComboSolver.EdgeKind.CANCEL)
	_check(air_cancel != null and air_cancel.valid, "jA -> jB is a valid air cancel")
	if air_cancel != null:
		_check(air_cancel.valid and air_cancel.hit_age == 5 and air_cancel.wait_to == GameParams.CANCEL_WINDOW_FRAMES - GameParams.THROW_COMBINATION_TOLERANCE, "jA -> jB hits at age 5 (B pairing wait 1 + startup 4); the cancel window minus the wait binds, not the dummy recovery")
	var air_finisher := _find_edge(report, "jB", "jD", ComboSolver.EdgeKind.CANCEL)
	_check(air_finisher != null and air_finisher.valid and air_finisher.hit_age == 4, "jB -> jD is a valid air cancel into the finisher")
	var landing := _find_edge(report, "jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(landing != null and landing.valid, "jB -> 5D is a valid explicit landing continuation")
	if landing != null:
		_check(landing.valid and landing.align_from == 0 and landing.align_to == 0, "landing seam accepts the jB hit exactly on the landing frame (critical-frame rule); earlier leads are unreachable because the followup key must be pressed before jB's confirm (a press inside jB's open window consumes as the configured jD air cancel) and buffer ages cap at 5")


func _test_full_air_route_matches_runtime() -> void:
	# 验收 2：完整空中路线的合法接续与运行时一致——把 Solver 发现的输入表回放到
	# 真实 CombatSession（同一几何假设：木桩钉在玩家面前），命中帧/连段数/伤害逐项对拍。
	var report := ComboSolver.analyze()
	var route := _find_route(report, ["5A", "236C", "jA", "jB", "jD"])
	_check(route != null, "the full air route 5A -> 236C -> Space -> jA -> jB -> jD is reported")
	if route == null:
		return
	_check(route.hit_frames == [6, 13, 22, 27, 31], "air route hits on frames 6/13/22/27/31 (w=0 cancels with the B pairing wait, earliest air press after pre-jump)")
	_check(route.combo_hits == 5 and _approx(route.total_damage, 53.0), "air route counts 5 hits for 53.0 total, matching the runtime air-route test")
	var replay := _replay_inputs(route.inputs, route.hit_frames[route.hit_frames.size() - 1])
	_check(replay.hit_frames == route.hit_frames, "replaying the solver schedule on a fresh CombatSession reproduces every hit frame")
	_check(replay.combo_hits == 5 and _approx(replay.total_damage, route.total_damage), "replay matches combo count and decayed damage")
	_check(replay.air_hits_all_airborne, "every air-segment hit lands while the player is airborne")
	_check(replay.end_reasons == [CombatEvent.ComboEndReason.FINISHER], "the route ends only on the jD finisher hit")


func _test_landing_route_and_critical_frame() -> void:
	# 验收 2/3：显式落地接续路线，以及 jB 命中优先于落地的临界帧规则。
	var report := ComboSolver.analyze()
	var route := _find_route(report, ["5A", "236C", "jA", "jB", "5D"])
	_check(route != null, "the landing-continuation route 5A -> 236C -> jA -> jB -> 5D is reported")
	if route != null:
		_check(route.hit_frames == [6, 13, 43, 55, 60], "landing route delays the air cancel so jB hits exactly on the landing frame (critical alignment, with the B pairing wait)")
		_check(route.combo_hits == 5 and _approx(route.total_damage, 51.8), "landing route totals 51.8, matching the runtime same-frame landing test")
		var route_replay := _replay_inputs(route.inputs, route.hit_frames[route.hit_frames.size() - 1])
		_check(route_replay.hit_frames == route.hit_frames and route_replay.combo_hits == 5, "the landing route's own schedule replays identically on a fresh session")
	# 临界帧回放：落地接续边的最晚对齐档——jB 命中恰在落地帧当帧，同帧产生命中
	# 与停顿开始两个事件，落地随后开放接续，缓存的 D 在当帧消费为 5D（与运行时
	# 临界测试同序）。输入表按正常战斗帧编排，回放跳过冻结帧。
	var edge := _find_edge(report, "jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(edge != null and edge.valid and not edge.align_inputs.is_empty(), "landing edge carries the latest-alignment schedule for replay")
	if edge == null or edge.align_inputs.is_empty():
		return
	var by_frame := {}
	for spec in edge.align_inputs:
		by_frame[spec.frame] = spec
	var session := CombatSession.new()
	var last := 0
	for spec in edge.align_inputs:
		last = maxi(last, spec.frame)
	# 最后一次按键在落地前一帧（issue 15 首帧锁定），5D 于落地帧起手、命中在
	# 前摇之后——观测窗覆盖到该帧。
	last += 1 + GameParams.MOVE_5D_STARTUP_FRAMES
	var landing_frame := -1
	var hit_frames: Array[int] = []
	var critical_state_ok := false
	var frame := 0
	while frame < last:
		frame += 1
		var input := FrameInput.new()
		if by_frame.has(frame):
			input = by_frame[frame].to_frame_input()
		var was_airborne := not session.player_on_ground
		var events := _step_logical(session, input)
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		var hit_now := false
		var stop_started := false
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_now = true
			elif event.type == CombatEvent.Type.HITSTOP_STARTED:
				stop_started = true
		if hit_now:
			hit_frames.append(frame)
		if was_airborne and session.player_on_ground:
			landing_frame = frame
			critical_state_ok = hit_now and stop_started and events.size() == 2 and session.player_move_id == "5D"
	_check(landing_frame > 0 and hit_frames.has(landing_frame), "the latest alignment lands the jB hit exactly on the landing frame")
	_check(critical_state_ok, "critical frame order holds: hit then hitstop-start are the only events; landing then lets the buffered D start 5D on that same frame")
	_check(hit_frames.size() == 4, "critical replay verifies the four hits 5C -> jA -> jB -> 5D")


func _test_jump_cancel_config_gates() -> void:
	# 验收 1：jump cancel 只认招式配置与空中姿态——空中招式配置 jump cancel（二段跳）
	# 与地面目标都被结构性排除，不会进入循环图。
	var table := MoveData.default_table()
	(table["jA"] as MoveData).jump_cancel_targets = ["jB"]
	(table["5A"] as MoveData).jump_cancel_targets = ["5B"]
	var report := ComboSolver.analyze(table)
	var air_jump := _find_edge(report, "jA", "jB", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(air_jump != null and not air_jump.valid, "an air move cannot jump-cancel (no double jump; airtime is not refreshable)")
	if air_jump != null:
		_check("二段跳" in air_jump.reason or "滞空" in air_jump.reason, "exclusion reason cites the no-double-jump rule")
	var ground_target := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(ground_target != null and not ground_target.valid, "a jump-cancel target must be an air move")
	var cancel_still := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.CANCEL)
	_check(cancel_still != null and cancel_still.valid, "the plain 5A -> 5B cancel is unaffected by jump-cancel misuse")
	_check(report.safe and report.cycles.is_empty(), "misconfigured jump cancels never create cycles")


func _test_landing_seam_requires_alignment() -> void:
	# 验收 1/3：落地接缝不只是配置——空中命中必须能落在落地帧前的取消窗口内。
	# jE（前摇 36）经 jB 取消后最早命中已晚于落地帧：空中招式落地即作废，接缝不可用。
	var table := MoveData.default_table()
	var late := _injected_move("jE", "E")
	late.stance = MoveData.Stance.AIR
	late.startup_frames = 36
	late.active_frames = 2
	late.recovery_frames = 6
	late.base_damage = 10
	late.knockback = 0.0
	late.knockback_up = 0.0
	late.hitstun_frames = GameParams.HITSTUN_FRAMES
	late.landing_cancel_targets = ["5D"]
	table["jE"] = late
	(table["jB"] as MoveData).cancel_targets = ["jD", "jE"]
	var report := ComboSolver.analyze(table)
	var seam := _find_edge(report, "jE", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(seam != null and not seam.valid, "jE -> 5D is excluded: the air move cannot even hit before landing")
	if seam != null:
		_check("落地" in seam.reason and ("作废" in seam.reason or "晚于落地" in seam.reason), "exclusion reason says the hit lands after the landing frame and the air move is invalidated")
	var chain := _find_edge(report, "jB", "jE", ComboSolver.EdgeKind.CANCEL)
	_check(chain != null and not chain.valid, "jB -> jE is likewise excluded: the followup never hits inside the airtime")
	if chain != null:
		_check("落地" in chain.reason, "exclusion reason cites the landing invalidation")
	_check(report.safe and report.cycles.is_empty(), "a seam that cannot close never becomes a cycle")


func _test_finite_air_resources_not_renewed() -> void:
	# 验收 3：有限滞空资源（玩家 40 帧滞空、木桩浮空不被普通命中刷新）不会被当作
	# 可自动续期——注入 jB -> jA 空中回边只在滞空内成立，逐圈模拟在落地时断链。
	var table := MoveData.default_table()
	(table["jB"] as MoveData).cancel_targets = ["jD", "jA"]
	var report := ComboSolver.analyze(table)
	var back := _find_edge(report, "jB", "jA", ComboSolver.EdgeKind.CANCEL)
	_check(back != null and back.valid, "the injected jB -> jA air back edge is valid while airborne")
	_check(report.safe and report.cycles.is_empty(), "the air back edge over finite airtime is never reported as a cycle")
	var noted := false
	for note in report.notes:
		if "jA → jB" in note and "落地" in note:
			noted = true
	_check(noted, "the structural cycle is reported as broken by the landing (finite air resources)")


func _test_injected_landing_back_edge_reports_cycle() -> void:
	# 验收 4：注入显式落地接续回边 jB -> 5A 后，5A -> 236C -> jA -> jB -> 落地 -> 5A
	# 每圈由 236C 重建木桩浮空、由 jump cancel 重建玩家滞空——真实可重复的循环被证明并上报；
	# 默认表的有限空中路线（jD 收尾）仍以普通路线报告，两者明确区分。
	var table := MoveData.default_table()
	(table["jB"] as MoveData).landing_cancel_targets = ["5D", "5A"]
	var report := ComboSolver.analyze(table)
	_check(not report.safe and report.cycles.size() == 1, "exactly one valid cycle after injecting the landing back edge")
	if report.cycles.size() == 1:
		var cycle := report.cycles[0]
		_check(cycle.route == ["236C", "jA", "jB", "5A"], "cycle route is 236C -> jA -> jB -> 5A -> back to 236C (canonical rotation)")
		_check(cycle.proven, "the cycle is proven by settlement-state recurrence across laps")
		_check(cycle.period_frames == 54, "cycle period is 54 frames per lap (jump cancel spends 4 pre-jump normal frames; the B pairing wait re-aligns the landing seam)")
		_check(cycle.laps_observed == 3, "recurrence is observed at the start of lap 3: the entry lap differs from steady laps in player-side state (no mid-chain Space slot yet, no previous-lap air-move marks), so the full settlement-state key (issue 21) only matches steady laps against each other")
	var finite := _find_route(report, ["5A", "236C", "jA", "jB", "jD"])
	_check(finite != null and finite.combo_hits == 5, "the finite jD-finisher air route is still reported as a plain route, distinct from the cycle")
	_check("有效循环" in report.summary, "summary reports the effective cycle")


func _test_solver_claims_only_configured_connections() -> void:
	# 验收 5：Solver 只主张招式数据配置过的连接——边集等于配置关系集，
	# 空中段只能经配置的 jump cancel 进入，路线只从地面普通动作键起手。
	var report := ComboSolver.analyze()
	var pairs := [
		["5A", "5B"], ["5A", "236C"], ["5B", "5D"], ["5B", "214D"],
		["5C", "jA"], ["236C", "jA"], ["jA", "jB"], ["jB", "jD"], ["jB", "5D"],
	]
	_check(report.edges.size() == pairs.size(), "the default report enumerates exactly the configured continuation relations")
	var reported := {}
	for edge in report.edges:
		var key := "%s|%s" % [edge.from_id, edge.to_id]
		_check(not reported.has(key), "no duplicated edge for %s" % key)
		reported[key] = true
	var all_configured := true
	for pair in pairs:
		if not reported.has("%s|%s" % [pair[0], pair[1]]):
			all_configured = false
	_check(all_configured, "every configured relation appears exactly once (no 5A -> 5D, no unconfigured jA -> jD, nothing invented)")
	var into_ja: Array[String] = []
	for edge in report.edges:
		if edge.to_id == "jA":
			into_ja.append(edge.from_id)
	_check(into_ja == ["5C", "236C"], "jA is reached only through the configured jump-cancel launchers — no neutral-jump or spatial claim")
	var starts_plain := true
	for route in report.routes:
		var first: String = route.move_ids[0]
		if not (first.length() == 2 and first.begins_with("5")):
			starts_plain = false
	_check(starts_plain, "every readable route starts from a plain ground action key — no neutral-jump air starts")
	_check("空中段只能经" in report.scope, "scope states air segments enter only via configured jump cancel")
	_check("不证明" in report.scope, "scope keeps the spatial/neutral/collision disclaimer")


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
	_check("236C → jA" in text and "jB → 5D" in text, "air seams appear in the edge report")
	_check("接续边" in text and "可读路线" in text and "循环" in text, "report sections are complete")
	_check("jump cancel" in text and "落地接续" in text, "edge kinds are labeled")
	_check("不证明" in text, "report carries the proof-scope disclaimer")


func _test_analysis_is_deterministic() -> void:
	var first := ComboSolver.analyze()
	var second := ComboSolver.analyze()
	var signature := func(report: ComboSolver.SolverReport) -> String:
		var parts: Array[String] = []
		for edge in report.edges:
			parts.append("%s:%d:%s:%s" % [edge.label(), edge.kind, str(edge.valid), edge.reason])
		for route in report.routes:
			parts.append(route.label() + ":" + str(route.hit_frames) + ":" + str(route.inputs.size()))
		for cycle in report.cycles:
			parts.append(cycle.label() + ":" + str(cycle.period_frames))
		return "|".join(parts)
	_check(signature.call(first) == signature.call(second), "analyzing the same table twice yields identical results (deterministic graph)")


# --- 辅助 ---

func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int = -1) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id and (kind < 0 or edge.kind == kind):
			return edge
	return null


func _find_route(report: ComboSolver.SolverReport, move_ids: Array[String]) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


## 把 Solver 发现的输入表回放到全新 CombatSession（木桩按同一几何假设钉在玩家面前）。
## until 指定观测截止帧（默认最后一个输入帧；命中可能晚于最后一次按键，需显式给到最后一击）。
## 输入表按正常战斗帧编排：会话进入 Hitstop 冻结时以空输入步过、不消耗计划帧号（issue 14）。
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


## 按正常战斗帧推进回放一步：会话处于 Hitstop 冻结时先以空输入步过全部冻结帧
## （木桩按探针几何钉回玩家面前），再在恢复后的正常帧喂入计划输入。
func _step_logical(session: CombatSession, input: FrameInput) -> Array[CombatEvent]:
	while session.hitstop_active():
		session.step(FrameInput.new())
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
	return session.step(input)


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


## 测试注入招式：字段齐全的合法打击招式（值取旧 GameParams 运行时默认，
## issue 11 起核心字段缺省是“未声明”哨兵值，程序内构造必须显式补齐；
## 注入表只喂给 Solver 探针，不经过 MoveTable 校验，键名可超出 A–D）。
func _injected_move(id: String, key: String) -> MoveData:
	var move := MoveData.new()
	move.move_id = id
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = key
	move.startup_frames = 5
	move.active_frames = 7
	move.recovery_frames = 13
	move.cancel_window_frames = GameParams.CANCEL_WINDOW_FRAMES
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.HIGH
	move.hitbox_size = GameParams.ATTACK_HITBOX_SIZE
	move.hitbox_gap = GameParams.ATTACK_HITBOX_GAP
	move.hit_result = MoveData.HitResult.GROUND_HITSTUN
	move.hitstun_frames = GameParams.HITSTUN_FRAMES
	move.knockback = GameParams.MOVE_5A_KNOCKBACK
	move.knockback_up = GameParams.ATTACK_KNOCKBACK_UP
	return move


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1
