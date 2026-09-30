extends SceneTree
## Combo Solver seam 测试（旧 ftg-combo issue 06 + 07）：地面/空中路线、jump cancel、落地接续、
## 有限滞空资源区分与循环报告。
## 运行：godot --headless --path . -s res://tests/test_combo_solver.gd
## Solver 只用私有 CombatSession 探针；本文件同时打印默认招式表的可读报告供设计者查阅。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0


func _initialize() -> void:
	print("")
	for line in _default_analyze().to_lines():
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
	_test_crouch_moves_and_low_float()
	_test_rekka_derive_edges_and_routes()
	_test_special_entry_edges_and_slide_scope()
	_test_blocked_cancel_edge_variants()
	_test_blocked_contact_not_treated_as_hit()
	_test_solver_claims_only_configured_connections()
	_test_solver_does_not_modify_runtime_state()
	_test_report_lines_readable()
	_test_analysis_is_deterministic()
	print("")
	_metrics.emit("test_combo_solver")
	if _failures == 0:
		print("ALL SOLVER TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 测试用例（旧 ftg-combo issue 06：地面接续）---

func _test_default_table_reports_ground_route() -> void:
	var report := _default_analyze()
	_check(report.safe and report.cycles.is_empty(), "default table reports no valid cycle")
	_check(report.edges.size() == 55, "default table enumerates 55 edges (ticket 05 基线 36：15 chain + 8 special + 4 link + 1 jump + 2 air cancels + 1 landing + 2 Rekka derives + 1 ~B link + 1 special D entry + 1 source-limited 5B link；ticket 06 增 7 条（6 蓄力变体 + 5[D]→5B 来源限定）；ticket 07 增 12 条：6A jc jB/jC（2 jump）+ jA/jB→jC（2 空中取消）+ 2C→6D/2D（2 链式）+ 6D/2D→jA/jB/jC（6 空中出口）)")
	var ab := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(ab != null and ab.valid, "5A -> 5B is a valid chain continuation")
	if ab != null:
		_check(ab.valid and ab.hit_age == 7 and ab.recover_age == 9, "5A -> 5B chain timing: earliest hit at age 7 (resume age 1 + B startup 6), dummy recoverable through age 9 (A-starter time layer floor(14x0.70))")
		_check(ab.valid and ab.wait_from == 0 and ab.wait_to == 0, "5A -> 5B valid wait range is 0-0 (chain window 3 admits only the hit-frame press once the B pairing wait resolves)")
	var bd := _find_edge(report, "5B", "5D", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(bd != null and bd.valid and bd.hit_age == 7 and bd.recover_age == 11, "5B -> 5D chain valid: earliest hit at age 7, recover age 11")
	var derivative := _find_edge(report, "5A", "236C", ComboSolver.EdgeKind.SPECIAL_CANCEL)
	_check(derivative != null and derivative.valid, "special-cancel edge 5A -> 236C is validated by feeding 236 before the cancel frame")
	if derivative != null:
		_check(derivative.valid and derivative.hit_age == 12, "236C's second segment connects 12 frames after 5A's confirm (seg1 at 7 + the 5-normal-frame inter-segment gap)")
	var derivative_two := _find_edge(report, "5B", "6A", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(derivative_two != null and derivative_two.valid and derivative_two.hit_age == 8, "derivative chain edge 5B -> 6A is valid (feed 6 during 5B)")
	var link := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.NORMAL_LINK)
	_check(link != null and not link.valid and "目押超时" in link.reason,
		"the declared normal-link edge 5A -> 5B is reported as its own type and honestly excluded (dummy recovers at 9 before full recovery at 14)")
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null, "report contains the readable 5A -> 5B -> 5D route")
	if route != null:
		_check(route.hit_frames == [6, 13, 20], "route hit frames are 6/13/20 (B cancels land one normal frame after each confirm)")
		_check(route.combo_hits == 3, "route counts 3 hits")
		_check(_approx(route.total_damage, 24.1), "route total damage is 24.1 with the three-layer corrections applied")
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
	var report := _default_analyze()
	var ab := _find_edge(report, "5A", "5B")
	_check(hit_frame == 6 and recover_frame == 6 + GameParams.HITSTOP_FRAMES + 9, "runtime 5A hits on frame 6 and naturally recovers after the freeze plus the A-starter-scaled hitstun (floor(14x0.70) = 9)")
	_check(ab != null and ab.valid and ab.recover_age == recover_frame - hit_frame - GameParams.HITSTOP_FRAMES, "solver recover age (9 normal frames) matches the runtime session minus the frozen frames")
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null and route.hit_frames == [6, 13, 20], "solver route hit frames follow the B pairing-wait timing (w=0 cancels resume on the first normal frame)")


func _test_injected_valid_back_edge_reports_cycle() -> void:
	# C-01 起手修正模型下的循环边界：注入有效的 5B -> 5A 命中确认回边后，
	# 5A ↔ 5B 结构回路存在，但三层修正使每次命中的受击计时逐击缩短
	# （A 起手 0.70 × 0.94^(n-1)），逐圈模拟在受击时间不足以容纳下一击时
	# 自然断链——不设全局命中数上限，也不把衰减断链误报为可证明循环。
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	var report := _metrics.analyze(table)
	_check(report.safe and report.cycles.is_empty(), "the decayed-stun loop breaks naturally instead of being proven (corrections change the settlement state every lap)")
	var ba := _find_edge(report, "5B", "5A")
	_check(ba != null and ba.valid and ba.hit_age == 5 and ba.recover_age == 11, "back edge 5B -> 5A is itself valid: earliest hit age 5 <= recover age 11")
	var broken := false
	for note in report.notes:
		if "5A → 5B" in note and "断开" in note:
			broken = true
	_check(broken, "the structural loop is reported as broken by the lap simulation (hitstun decay)")


func _test_injected_slow_back_edge_not_misreported() -> void:
	# 结构上存在 5A → 5B → 5E → 5A 回路，但 5B → 5E 的目标前摇 25 帧
	# 晚于木桩恢复（第 21 帧）——等待超时的回边不得被误报为循环。
	var table := MoveData.default_table()
	var slow := _injected_move("5E", "E")
	slow.startup_frames = 25
	slow.active_frames = 2
	slow.recovery_frames = 8
	slow.base_damage = 10
	_set_probe_stun(slow, GameParams.HITSTUN_FRAMES)
	_set_probe_horizontal(slow, 0.0)
	slow.cancel_targets = ["5A"]
	table["5E"] = slow
	(table["5B"] as MoveData).cancel_targets = ["5D", "5E"]
	var report := _metrics.analyze(table)
	var be := _find_edge(report, "5B", "5E")
	_check(be != null and not be.valid, "timeout back edge 5B -> 5E is excluded")
	if be != null:
		_check("等待超时" in be.reason and "恢复" in be.reason, "exclusion reason says the hit lands after dummy recovery")
		_check(be.hit_age == 25 and be.recover_age == 11, "timing: earliest hit age 26 > recover age 11 (5B solo B-starter stun floor(14x0.82))")
	var ea := _find_edge(report, "5E", "5A")
	_check(ea != null and ea.valid, "the structural edge 5E -> 5A is itself still valid")
	_check(report.safe and report.cycles.is_empty(), "a timing-insufficient back edge is never misreported as a cycle")


func _test_injected_stance_back_edge_not_misreported() -> void:
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "jA"]
	var report := _metrics.analyze(table)
	var edge := _find_edge(report, "5B", "jA")
	_check(edge != null and not edge.valid, "stance-mismatched back edge 5B -> jA is excluded")
	if edge != null:
		_check("姿态" in edge.reason and "空中" in edge.reason, "exclusion reason says the stance mismatches (air move)")
	_check(report.safe and report.cycles.is_empty(), "a stance-mismatched back edge is never misreported as a cycle")


func _test_finisher_back_edge_not_misreported() -> void:
	# 收尾招式命中即结束连段、不开放命中确认取消：5D 不再是收尾（新基线），
	# 仍为收尾的 214D 的结构回边不可行。
	var table := MoveData.default_table()
	(table["214D"] as MoveData).cancel_targets = ["5A"]
	var report := _metrics.analyze(table)
	var edge := _find_edge(report, "214D", "5A")
	_check(edge != null and not edge.valid, "finisher back edge 214D -> 5A is excluded")
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
	_set_probe_stun(quick, 4)
	_set_probe_horizontal(quick, 0.0)
	quick.cancel_targets = ["5A", "5B"]
	table["5F"] = quick
	var wide := _injected_move("5G", "G")
	wide.startup_frames = 2
	wide.active_frames = 2
	wide.recovery_frames = 3
	wide.base_damage = 10
	_set_probe_stun(wide, 12)
	_set_probe_horizontal(wide, 0.0)
	wide.cancel_window_frames = 2
	wide.cancel_targets = ["5B"]
	table["5G"] = wide
	var report := _metrics.analyze(table)
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
	var report := _default_analyze()
	var jump_6a := _find_edge(report, "6A", "jA", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(jump_6a != null and jump_6a.valid, "6A -> jA is a valid jump-cancel edge (5C no longer launches: baseline)")
	if jump_6a != null:
		_check(jump_6a.valid and jump_6a.hit_age == 5 + GameParams.PLAYER_PREJUMP_FRAMES, "jump-canceled jA hits 9 frames after 6A's confirm (Space on the hit frame, prep 4, press at takeoff+1, startup 4)")
	_check(_find_edge(report, "236C", "jA", ComboSolver.EdgeKind.JUMP_CANCEL) == null, "236C no longer declares jump cancel (ticket 05: the D special entry replaces the retired launcher role)")
	var air_cancel := _find_edge(report, "jA", "jB", ComboSolver.EdgeKind.CANCEL)
	_check(air_cancel != null and air_cancel.valid, "jA -> jB is a valid air cancel")
	if air_cancel != null:
		_check(air_cancel.valid and air_cancel.hit_age == 5 and air_cancel.wait_to == 3, "jA -> jB hits at age 5 (resume age 1 + startup 4); the time-decayed dummy recovery binds the wait range to 0-3")
	var air_finisher := _find_edge(report, "jB", "j5D", ComboSolver.EdgeKind.CANCEL)
	_check(air_finisher != null and air_finisher.valid and air_finisher.hit_age == 6, "jB -> j5D is a valid air cancel into the closer (startup 6)")
	var landing := _find_edge(report, "jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(landing != null and not landing.valid, "jB -> 5D is excluded by the landing recovery lock")
	if landing != null:
		_check(landing.align_inputs.is_empty(), "excluded landing edge has no successful alignment input")


func _test_full_air_route_matches_runtime() -> void:
	# 验收 2：完整空中路线的合法接续与运行时一致——把 Solver 发现的输入表回放到
	# 真实 CombatSession（同一几何假设：木桩钉在玩家面前），命中帧/连段数/伤害逐项对拍。
	var report := _default_analyze()
	var route := _find_route(report, ["5A", "5B", "6A", "jA", "jB", "j5D"])
	_check(route != null, "the full air route 5A -> 5B -> 6A -> Space -> jA -> jB -> jD is reported")
	if route == null:
		return
	_check(route.hit_frames == [6, 13, 21, 30, 35, 41], "air route hits on frames 6/13/21/30/35/41 (w=0 cancels with the B pairing wait, earliest air press after pre-jump, j5D startup 6)")
	_check(route.combo_hits == 6 and _approx(route.total_damage, 39.6), "air route counts 6 hits for 39.6 total (three-layer corrections, j5D base 16), matching the runtime air-route test")
	var replay := _replay_inputs(route.inputs, route.hit_frames[route.hit_frames.size() - 1])
	_check(replay.hit_frames == route.hit_frames, "replaying the solver schedule on a fresh CombatSession reproduces every hit frame")
	_check(replay.combo_hits == 6 and _approx(replay.total_damage, route.total_damage), "replay matches combo count and decayed damage")
	_check(replay.air_hits_all_airborne, "every air-segment hit lands while the player is airborne")
	_check(replay.end_reasons == [CombatEvent.ComboEndReason.FINISHER], "the route ends only on the jD finisher hit")


func _test_landing_route_and_critical_frame() -> void:
	var report := _default_analyze()
	_check(_find_route(report, ["5A", "5B", "6A", "jA", "jB", "5D"]) == null,
		"forbidden landing-frame route is absent from legal routes")
	var edge := _find_edge(report, "jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(edge != null and not edge.valid and edge.align_inputs.is_empty(),
		"landing edge is excluded and carries no successful replay")
	_check(edge != null and "落地恢复" in edge.reason, "landing exclusion names the recovery lock")


func _test_jump_cancel_config_gates() -> void:
	# 验收 1：jump cancel 只认招式配置与空中姿态——空中招式配置 jump cancel（二段跳）
	# 与地面目标都被结构性排除，不会进入循环图。
	var table := MoveData.default_table()
	(table["jA"] as MoveData).jump_cancel_targets = ["jB"]
	(table["5A"] as MoveData).jump_cancel_targets = ["5B"]
	var report := _metrics.analyze(table)
	var air_jump := _find_edge(report, "jA", "jB", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(air_jump != null and not air_jump.valid, "an air move cannot jump-cancel (no double jump; airtime is not refreshable)")
	if air_jump != null:
		_check("二段跳" in air_jump.reason or "滞空" in air_jump.reason, "exclusion reason cites the no-double-jump rule")
	var ground_target := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(ground_target != null and not ground_target.valid, "a jump-cancel target must be an air move")
	var cancel_still := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(cancel_still != null and cancel_still.valid, "the plain 5A -> 5B chain cancel is unaffected by jump-cancel misuse")
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
	_set_probe_stun(late, GameParams.HITSTUN_FRAMES)
	_set_probe_horizontal(late, 0.0)
	_add_probe_airborne(late, GameParams.HITSTUN_FRAMES, 0.0, 40.0)
	late.landing_cancel_targets = ["5D"]
	table["jE"] = late
	(table["jB"] as MoveData).cancel_targets = ["j5D", "jE"]
	MoveData.profile_for(table["jB"], HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL).air_untech_frames = 40
	var report := _metrics.analyze(table)
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
	(table["jB"] as MoveData).cancel_targets = ["j5D", "jA"]
	var report := _metrics.analyze(table)
	var back := _find_edge(report, "jB", "jA", ComboSolver.EdgeKind.CANCEL)
	_check(back != null and back.valid, "the injected jB -> jA air back edge is valid while airborne")
	_check(report.safe and report.cycles.is_empty(), "the air back edge over finite airtime is never reported as a cycle")
	var noted := false
	for note in report.notes:
		if "jA → jB" in note and "落地" in note:
			noted = true
	_check(noted, "the structural cycle is reported as broken by the landing (finite air resources)")


func _test_injected_landing_back_edge_reports_cycle() -> void:
	var table := MoveData.default_table()
	(table["jB"] as MoveData).landing_cancel_targets = ["5D", "5A"]
	var report := _metrics.analyze(table)
	_check(report.safe and report.cycles.is_empty(), "configured landing back edge cannot bypass recovery or prove a cycle")
	var edge := _find_edge(report, "jB", "5A", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(edge != null and not edge.valid, "landing back edge is excluded")
	var finite := _find_route(report, ["5A", "5B", "6A", "jA", "jB", "j5D"])
	_check(finite != null and finite.combo_hits == 6, "finite air route remains available (six hits after the 6A launcher migration)")


# --- 票据 02：蹲姿招式输入表达与低浮空状态 ---

func _test_crouch_moves_and_low_float() -> void:
	# 蹲姿招式的按下帧必须携带下方向（ScheduledInput.down），否则会话把同一键
	# 解析为站立变体；2C 命中后进入 LOW_FLOAT_SWEEP，Solver 的可追击观测覆盖
	# 到触地转普通倒地为止（timing 层结论，空间仍按声明边界）。
	var report := _default_analyze()
	var crouch_chain := _find_edge(report, "2A", "2B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(crouch_chain != null and crouch_chain.valid,
		"the 2A -> 2B crouch chain is validated by pressing B with the down state held")
	if crouch_chain != null and crouch_chain.valid:
		_check(crouch_chain.hit_age == 8 and crouch_chain.recover_age == 9,
			"2A -> 2B timing: earliest hit at age 8 (resume 1 + 2B startup 7) inside the A-starter recovery 9")
	var stand_into_crouch := _find_edge(report, "5A", "2B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(stand_into_crouch != null and stand_into_crouch.valid,
		"5A -> 2B requires the solver to synthesize the crouch press during 5A's cancel window")
	var sweep_edge := _find_edge(report, "2B", "2C", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(sweep_edge != null and sweep_edge.valid,
		"2B -> 2C is validated and puts the dummy into the low float on hit")
	var route := _find_route(report, ["2B", "2C", "214C", "214C~B"])
	_check(route != null and route.timing_valid and route.combo_hits == 4,
		"the readable 2B -> 2C -> 214C -> 214C~B sweep route replays with both crouch presses carrying down (ticket 04 extends the dead end into the rekka route)")
	if route != null:
		var down_presses := 0
		for spec in route.inputs:
			if spec.key != "" and spec.down:
				down_presses += 1
		_check(down_presses == 2, "only the two crouch press frames (2B/2C) carry the down state; 214C and ~B presses do not")
	## 票据 05 起 5D → 5B 是来源限定边：普通来源 5D 的延长（如 2A > 2B > 5C > 5D
	## 之后接 5B）在逐帧模拟中如实断链，路线记录截断为四招前缀——四招本身仍经
	## 上面 2A > 2B > 214C > 214C~B 的可读路线证明蹲姿→站立链可用。
	var crouch_route := _find_route(report, ["2A", "2B", "5C", "5D"])
	_check(crouch_route != null and not crouch_route.timing_valid and "在此截断" in crouch_route.note,
		"the 2A > 2B > 5C > 5D walk is recorded truncated at the source-limited 5B extension (normal-source 5D keeps no reverse link)")
	## A 起手时间层衰减的诚实截断：2A > 2B 后接 2C 的第三击因 2B 受击窗口
	## （floor(14×0.658)=9）短于 2C 前摇到达而不成立——按截断路线如实报告，
	## 不伪装成时序成立。
	var truncated := _find_route(report, ["2A", "2B"])
	if truncated != null:
		_check(not truncated.timing_valid and "断开" in truncated.note,
			"the truncated 2A -> 2B entry (2C too slow behind the A-starter-decayed 2B stun) is honestly reported as broken")
	# 2C 的有效出边只有声明的 214C 必杀取消（票据 04）与 6D 链式（票据 07；
	# 2D 链式在钉位下按高度失配挥空排除）：报告不得发明其他接续。
	for edge in report.edges:
		if edge.from_id == "2C" and edge.valid:
			_check((edge.to_id == "214C" and edge.kind == ComboSolver.EdgeKind.SPECIAL_CANCEL)
				or (edge.to_id == "6D" and edge.kind == ComboSolver.EdgeKind.CHAIN_CANCEL),
				"the only valid continuations out of 2C are the declared 214C special cancel and the 6D air-chase chain")
		if edge.from_id == "2C" and edge.to_id == "2D":
			_check(not edge.valid and edge.kind == ComboSolver.EdgeKind.CHAIN_CANCEL,
				"the 2C -> 2D chain stays excluded (raised hitbox whiffs over the pinned low float)")


func _test_rekka_derive_edges_and_routes() -> void:
	# 票据 04：Rekka 派生边在真实结算中验证——首段接触起的派生窗口、首个
	# B/C 新按下锁分支、派生按键无组合等待、被防接触同样开放派生；
	# ~B/~C 不出现在首招候选；正例路线 2C > 214C > ~B 计 3 击、~C 收尾。
	var report := _default_analyze()
	var derive_b := _find_edge(report, "214C", "214C~B", ComboSolver.EdgeKind.REKKA_DERIVE)
	_check(derive_b != null and derive_b.valid,
		"the 214C -> 214C~B derivation edge is validated in real settlement")
	if derive_b != null and derive_b.valid:
		_check(derive_b.wait_from == 1 and derive_b.wait_from <= derive_b.wait_to,
			"the derivation wait range starts at 1 (the contact frame itself has not opened the window at input time yet)")
		_check(derive_b.reason.contains("branch-locked"),
			"the valid edge reason carries the branch-locked classification")
	var derive_c := _find_edge(report, "214C", "214C~C", ComboSolver.EdgeKind.REKKA_DERIVE)
	_check(derive_c != null and derive_c.valid,
		"the 214C -> 214C~C derivation edge is validated in real settlement")
	if derive_c != null:
		_check(derive_c.blocked_valid and derive_c.blocked_reason.contains("再次被防"),
			"the ~C derivation from a blocked opener is probed and blocked again by the standing guard (overhead)")
	if derive_b != null and derive_b.blocked_valid:
		_check(derive_b.blocked_reason.contains("命中") and derive_b.blocked_reason.contains("漏出"),
			"the ~B derivation from a blocked opener leaks through the standing guard (low) and is reported as a mixed start")
	for line in report.first_candidates:
		_check(not line.begins_with("214C~"),
			"rekka-only derived moves never appear as first candidates (%s)" % line)
	var route_b := _find_route(report, ["2C", "214C", "214C~B"])
	_check(route_b != null and route_b.timing_valid and route_b.combo_hits == 3,
		"the canonical 2C > 214C > 214C~B route replays with three real hits")
	var route_c := _find_route(report, ["5B", "2C", "214C", "214C~C"])
	_check(route_c != null and route_c.timing_valid and route_c.combo_hits == 4
		and route_c.note.contains("收尾"),
		"the 5B > 2C > 214C > 214C~C route ends as a finisher with four hits")
	for route in report.routes:
		_check(not (route.move_ids.has("214C~B") and route.move_ids.has("5B") and route.move_ids.find("5B") > route.move_ids.find("214C~B") and route.combo_hits >= 5),
			"no route claims the airborne ~B > 5B link as a fifth hit (canonical-context link edge stays excluded; the airborne link is replay-required)")
	var link_edge := _find_edge(report, "214C~B", "5B", ComboSolver.EdgeKind.NORMAL_LINK)
	_check(link_edge != null and not link_edge.valid,
		"the ~B > 5B link edge is honestly reported invalid in its canonical grounded context (knockdown ends the combo)")


func _test_special_entry_edges_and_slide_scope() -> void:
	# 票据 05：特殊进入边与来源限定连接在真实结算中验证；slide 捞起与段间
	# 距离明确 replay-required；普通来源 5D 不取得反向 5B；结构性循环只允许
	# 断链/未完成观测，不产生有效循环证明。
	var report := _default_analyze()
	var entry := _find_edge(report, "236C", "5D", ComboSolver.EdgeKind.SPECIAL_ENTRY)
	_check(entry != null and entry.valid, "the 236C -> 5D special entry edge is timing-valid on the pinned grid")
	if entry != null and entry.valid:
		_check("replay-required" in entry.reason and "slide" in entry.reason,
			"the entry edge marks slide pickup and inter-segment reachability as replay-required (pins never produce the slide)")
		_check("airborne" in entry.reason and "grounded-stun" in entry.reason,
			"the entry edge reports the target states observed across its valid wait range")
	var link := _find_edge(report, "5D", "5B", ComboSolver.EdgeKind.SPECIAL_ENTRY_LINK)
	_check(link != null and link.valid, "the source-limited 5D -> 5B link edge validates in the special-entry context (solo 236C start, D starter)")
	if link != null and link.valid:
		_check("来源限定" in link.reason and "直接起手" in link.reason,
			"the link edge names its entry context and the source limitation")
	_check(_find_edge(report, "5D", "5B", ComboSolver.EdgeKind.NORMAL_LINK) == null,
		"no unconditional 5D -> 5B link edge exists (normal-source 5D keeps no reverse link)")
	var route := _find_route(report, ["5B", "236C", "5D"])
	_check(route != null and route.timing_valid and route.combo_hits == 4,
		"the 5B > 236C(both segments) > 5D route is timing-valid with all four hits predicted")
	var cycle_route := _find_route(report, ["5B", "236C", "5D", "5B"])
	if cycle_route != null and cycle_route.timing_valid:
		_check(report.safe and report.cycles.is_empty(),
			"the 5B > 236C > 5D > 5B structural cycle never becomes a proven loop (bounded by corrections and real hitstun)")
	_check(report.safe, "the default table still reports no proven cycle after the special-entry family")

func _test_blocked_cancel_edge_variants() -> void:
	# 被防接触变体（票据 03）：链式/必杀边附「被防路径」标注——来源被站防/蹲防
	# 挡下时取消仍能在窗口内起手；目标自身接触如实入注；来源未声明被防结果的
	# 注入边默认不可被防；报告显式声明安全性 replay-required。
	var report := _default_analyze()
	var chain := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(chain != null and chain.blocked_valid, "5A -> 5B has a validated blocked-contact variant (cancelled while the dummy stands guard)")
	if chain != null and chain.blocked_valid:
		_check(chain.blocked_reason.contains("站防") and chain.blocked_reason.contains("再次被防"),
			"the blocked variant reports the standing-guard probe and the target being blocked again")
	var special := _find_edge(report, "5A", "236C", ComboSolver.EdgeKind.SPECIAL_CANCEL)
	_check(special != null and special.blocked_valid,
		"the special-cancel 5A -> 236C also opens on a blocked contact")
	var low_source := _find_edge(report, "2A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(low_source != null and low_source.blocked_valid and low_source.blocked_reason.contains("蹲防"),
		"a low source (2A) probes with the crouch guard that can actually block it")
	var leak := _find_edge(report, "5A", "2B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(leak != null and leak.blocked_valid and leak.blocked_reason.contains("命中"),
		"the blocked 5A cancelled into the low 2B hits through the standing guard (attribute leak reported as a hit, not as a blocked hit)")
	var has_note := false
	for note in report.notes:
		has_note = has_note or (note.contains("replay-required") and note.contains("被防"))
	_check(has_note, "the report notes declare block safety conclusions replay-required")
	var unblockable_table := _blocked_probe_table(false)
	var unblockable_report := _metrics.analyze(unblockable_table)
	var unblockable := _find_edge(unblockable_report, "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(unblockable != null and not unblockable.blocked_valid and unblockable.blocked_reason.contains("未声明被防结果"),
		"an injected source without declared block result denies the blocked variant (default deny, no global fallback)")


func _test_blocked_contact_not_treated_as_hit() -> void:
	# 被防不产生命中：被防路径标注不改变路线图——路线的 combo_hits 只统计 HIT；
	# 被防变体成立的边不因此出现以被防为起点的「路线」。
	var report := _default_analyze()
	for route in report.routes:
		_check(route.combo_hits == route.hit_frames.size(),
			"every route counts exactly its HIT events (blocked contacts never inflate hit counts)")
	var chain := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(chain != null and chain.valid and chain.blocked_valid,
		"the blocked variant annotates the same configured edge without replacing the hit-path validation")


## 被防探针注入表：A 键探针 5A（可配置是否声明被防结果）链式取消 B 键 5B。
func _blocked_probe_table(blockable: bool) -> Dictionary:
	var five_a := _probe_strike("5A", "A")
	var five_b := _probe_strike("5B", "B")
	five_a.chain_cancel_targets = ["5B"]
	five_a.chain_cancel_window_frames = 5
	if blockable:
		five_a.block_freeze_frames = 8
		five_a.block_stun_frames = 9
		five_a.block_pushback_px_s = 45.0
	return {"5A": five_a, "5B": five_b}

func _test_solver_claims_only_configured_connections() -> void:
	# 验收 5：Solver 只主张招式数据配置过的连接——边集等于配置关系集，
	# 空中段只能经配置的 jump cancel 进入，路线只从地面普通动作键起手。
	var report := _default_analyze()
	## 配置关系集 = 声明的取消/连接边：6 条链式、3 条必杀、4 条普通连接
	## （5A→5B、5B→5C、5B→5D、5C→5D）、2 条 jump cancel、2 条空中取消、1 条落地接续。
	var pairs := [
		["5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL], ["5A", "2B", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["5B", "5C", ComboSolver.EdgeKind.CHAIN_CANCEL], ["5B", "2C", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["5B", "6A", ComboSolver.EdgeKind.CHAIN_CANCEL], ["5B", "5D", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["5C", "6A", ComboSolver.EdgeKind.CHAIN_CANCEL], ["5C", "5D", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["2A", "5A", ComboSolver.EdgeKind.CHAIN_CANCEL], ["2A", "2A", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["2A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL], ["2A", "2B", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["2B", "5C", ComboSolver.EdgeKind.CHAIN_CANCEL], ["2B", "2C", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["2B", "6A", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["5A", "236C", ComboSolver.EdgeKind.SPECIAL_CANCEL], ["5B", "236C", ComboSolver.EdgeKind.SPECIAL_CANCEL],
		["5C", "236C", ComboSolver.EdgeKind.SPECIAL_CANCEL],
		["5A", "214C", ComboSolver.EdgeKind.SPECIAL_CANCEL], ["2A", "214C", ComboSolver.EdgeKind.SPECIAL_CANCEL],
		["5B", "214C", ComboSolver.EdgeKind.SPECIAL_CANCEL], ["5C", "214C", ComboSolver.EdgeKind.SPECIAL_CANCEL],
		["2C", "214C", ComboSolver.EdgeKind.SPECIAL_CANCEL],
		["214C", "214C~B", ComboSolver.EdgeKind.REKKA_DERIVE], ["214C", "214C~C", ComboSolver.EdgeKind.REKKA_DERIVE],
		["214C~B", "5B", ComboSolver.EdgeKind.NORMAL_LINK],
		["5A", "5B", ComboSolver.EdgeKind.NORMAL_LINK], ["5B", "5C", ComboSolver.EdgeKind.NORMAL_LINK],
		["5B", "5D", ComboSolver.EdgeKind.NORMAL_LINK], ["5C", "5D", ComboSolver.EdgeKind.NORMAL_LINK],
		["6A", "jA", ComboSolver.EdgeKind.JUMP_CANCEL],
		["jA", "jB", ComboSolver.EdgeKind.CANCEL], ["jB", "j5D", ComboSolver.EdgeKind.CANCEL],
		["jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL],
		["236C", "5D", ComboSolver.EdgeKind.SPECIAL_ENTRY],
		["5D", "5B", ComboSolver.EdgeKind.SPECIAL_ENTRY_LINK],
		## 票据 06：目标声明蓄力的接缝另枚举蓄力变体（to=5[D]），以及 5[D]
		## 自身的来源限定出边。
		["236C", "5[D]", ComboSolver.EdgeKind.SPECIAL_ENTRY],
		["5B", "5[D]", ComboSolver.EdgeKind.CHAIN_CANCEL], ["5C", "5[D]", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["5B", "5[D]", ComboSolver.EdgeKind.NORMAL_LINK], ["5C", "5[D]", ComboSolver.EdgeKind.NORMAL_LINK],
		["jB", "5[D]", ComboSolver.EdgeKind.LANDING_CANCEL],
		["5[D]", "5B", ComboSolver.EdgeKind.SPECIAL_ENTRY_LINK],
		## 票据 07：6A 的 jump cancel 扩展到 jB/jC，jA/jB 接 jC，2C 链式进入
		## 6D/2D，6D/2D 的空中出口（air_exit_targets）。
		["6A", "jB", ComboSolver.EdgeKind.JUMP_CANCEL], ["6A", "jC", ComboSolver.EdgeKind.JUMP_CANCEL],
		["jA", "jC", ComboSolver.EdgeKind.CANCEL], ["jB", "jC", ComboSolver.EdgeKind.CANCEL],
		["2C", "6D", ComboSolver.EdgeKind.CHAIN_CANCEL], ["2C", "2D", ComboSolver.EdgeKind.CHAIN_CANCEL],
		["6D", "jA", ComboSolver.EdgeKind.AIR_EXIT], ["6D", "jB", ComboSolver.EdgeKind.AIR_EXIT],
		["6D", "jC", ComboSolver.EdgeKind.AIR_EXIT],
		["2D", "jA", ComboSolver.EdgeKind.AIR_EXIT], ["2D", "jB", ComboSolver.EdgeKind.AIR_EXIT],
		["2D", "jC", ComboSolver.EdgeKind.AIR_EXIT],
	]
	_check(report.edges.size() == pairs.size(), "the default report enumerates exactly the configured continuation relations")
	var reported := {}
	for edge in report.edges:
		var key := "%s|%s|%d" % [edge.from_id, edge.to_id, edge.kind]
		_check(not reported.has(key), "no duplicated edge for %s" % key)
		reported[key] = true
	var all_configured := true
	for pair in pairs:
		if not reported.has("%s|%s|%d" % [pair[0], pair[1], pair[2]]):
			all_configured = false
	_check(all_configured, "every configured relation appears exactly once (no 5A -> 6A cancel, no unconfigured jA -> jD, nothing invented)")
	var into_ja: Array[String] = []
	for edge in report.edges:
		if edge.to_id == "jA" and edge.kind == ComboSolver.EdgeKind.JUMP_CANCEL:
			into_ja.append(edge.from_id)
	_check(into_ja == ["6A"], "jA is reached only through the configured 6A jump cancel — no neutral-jump or spatial claim")
	var starts_plain := true
	for route in report.routes:
		var first: String = route.move_ids[0]
		if not (first.length() == 2 and (first.begins_with("5") or first.begins_with("2"))):
			starts_plain = false
	_check(starts_plain, "every readable route starts from a plain ground action key (standing or crouch) — no neutral-jump air starts")
	_check("空中段只能经" in report.scope, "scope states air segments enter only via configured jump cancel")
	_check("不证明" in report.scope, "scope keeps the spatial/neutral/collision disclaimer")


func _test_solver_does_not_modify_runtime_state() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	session.step(FrameInput.make(0, false, "A"))
	for i in range(5):
		session.step(FrameInput.new())
	var before := _snapshot_session(session)
	_default_analyze()
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	_metrics.analyze(table)
	var after := _snapshot_session(session)
	_check(before == after, "running the solver leaves every observable field of a live session untouched")
	_check(session.player_move_id == "5A" and session.combo_active and session.combo_hits == 1, "the live session is still inside its 5A hit-confirmed combo, unbothered by probes")


func _test_report_lines_readable() -> void:
	var report := _default_analyze()
	var lines := report.to_lines()
	var text := "\n".join(lines)
	_check(lines.size() >= 8, "report has enough lines (summary/scope/edges/routes/cycles sections)")
	_check("5A → 5B → 5D" in text, "report contains the 5A -> 5B -> 5D route text")
	_check("236C → jA" in text and "jB → 5D" in text, "air seams appear in the edge report")
	_check("接续边" in text and "可读路线" in text and "循环" in text, "report sections are complete")
	_check("jump cancel" in text and "落地接续" in text, "edge kinds are labeled")
	_check("不证明" in text, "report carries the proof-scope disclaimer")


func _test_analysis_is_deterministic() -> void:
	var first := _default_analyze()
	var second := _default_analyze()
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

## 探针打击招式（字段齐全的合法构造，票据 03 被防探针用）。
func _probe_strike(id: String, key: String) -> MoveData:
	var move := MoveData.new()
	move.move_id = id
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = key
	move.startup_frames = 5
	move.active_frames = 4
	move.recovery_frames = 10
	move.cancel_window_frames = 8
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.MID
	move.hitbox_size = Vector2(64, 60)
	move.hitbox_gap = 4.0
	move.starter_grade = MoveData.StarterGrade.A
	var normal := HitProfile.new()
	normal.target_state = HitProfile.TargetState.GROUNDED
	normal.hit_context = HitProfile.HitContext.NORMAL
	normal.reaction = HitProfile.Reaction.GROUND_HITSTUN
	normal.ground_stun_frames = 14
	normal.horizontal_speed_px_s = 160.0
	normal.upward_speed_px_s = 0.0
	var counter := normal.duplicate() as HitProfile
	counter.hit_context = HitProfile.HitContext.COUNTER
	move.hit_profiles = [normal, counter]
	return move


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
	move.hit_profiles = _probe_profiles(GameParams.HITSTUN_FRAMES, GameParams.MOVE_5A_KNOCKBACK)
	move.starter_grade = MoveData.StarterGrade.D
	return move


## 探针命中资料（上下文命中资料迁移）：grounded normal/counter 同值——既有回归
## 不区分 counter 变体，只要求上下文匹配不落空。
func _probe_profiles(stun: int, horizontal: float) -> Array[HitProfile]:
	var normal := HitProfile.new()
	normal.target_state = HitProfile.TargetState.GROUNDED
	normal.hit_context = HitProfile.HitContext.NORMAL
	normal.reaction = HitProfile.Reaction.GROUND_HITSTUN
	normal.ground_stun_frames = stun
	normal.horizontal_speed_px_s = horizontal
	normal.upward_speed_px_s = 0.0
	var counter := normal.duplicate() as HitProfile
	counter.hit_context = HitProfile.HitContext.COUNTER
	return [normal, counter]


func _set_probe_stun(move: MoveData, frames: int) -> void:
	for profile in move.hit_profiles:
		profile.ground_stun_frames = frames


func _set_probe_horizontal(move: MoveData, speed: float) -> void:
	for profile in move.hit_profiles:
		profile.horizontal_speed_px_s = speed


## 把探针的全部 profile 改写为 LAUNCH（旧 hit_result=LAUNCH + hitstun + 击退
## 三件套的等价迁移：受身计时、水平幅值与垂直初速度进入每个 profile）。
func _set_probe_launch(move: MoveData, untech: int, horizontal: float, upward: float) -> void:
	for profile in move.hit_profiles:
		profile.reaction = HitProfile.Reaction.LAUNCH
		profile.ground_stun_frames = -1
		profile.air_untech_frames = untech
		profile.horizontal_speed_px_s = horizontal
		profile.upward_speed_px_s = upward


## 给探针追加 airborne normal LAUNCH profile（旧 hit_result 语义下空中命中无
## 目标状态维度；迁移后空中命中需要显式 airborne 资料，缺失即 MISS_NO_PROFILE）。
func _add_probe_airborne(move: MoveData, untech: int, horizontal: float, upward: float) -> void:
	var airborne := HitProfile.new()
	airborne.target_state = HitProfile.TargetState.AIRBORNE
	airborne.hit_context = HitProfile.HitContext.NORMAL
	airborne.reaction = HitProfile.Reaction.LAUNCH
	airborne.air_untech_frames = untech
	airborne.horizontal_speed_px_s = horizontal
	airborne.upward_speed_px_s = upward
	move.hit_profiles.append(airborne)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1

func _default_analyze() -> ComboSolver.SolverReport:
	return _metrics.analyze_reused("default")

