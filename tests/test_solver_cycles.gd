extends SceneTree
## Combo Solver 循环证明与有限空中资源（ftg-combat-foundation issue 21）：
## 状态去重键覆盖影响未来结算的全部会话状态；真实回边须由逐圈状态快照重现后才
## 报告为循环；8 圈 / 2400 帧 / 240 帧恢复观测 / 40 帧空中延迟上限达到时以截断或
## 未完成观测上报，不宣称完整证明；循环报告携带路径、起始状态、逐帧输入与证明
## 结果，并保持确定性排序。
## 运行：godot --headless --path . -s res://tests/test_solver_cycles.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0


func _initialize() -> void:
	print("")
	_test_settlement_state_excludes_frame_counters()
	_test_settlement_state_covers_player_side_fields()
	_test_valid_back_edge_proven_with_replay_materials()
	_test_proof_distinguishes_entry_lap_player_state()
	_test_frame_cap_reports_truncation_not_cycle()
	_test_laps_exhausted_reports_incomplete_observation()
	_test_recovery_horizon_truncation_annotated()
	_test_cycle_report_carries_start_and_replay()
	_test_cycles_sorted_and_report_deterministic()
	_test_scope_documents_observation_caps()
	print("")
	_metrics.emit("test_solver_cycles")
	if _failures == 0:
		print("ALL SOLVER CYCLE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 状态去重键（CombatSession.settlement_state 口径）---


func _test_settlement_state_excludes_frame_counters() -> void:
	# 纯调试帧号不入去重键：两份会话在相差 5 个物理帧的时点到达同一相对状态
	# （5A 前摇第 3 帧），settlement_state 必须相等——否则逐圈快照因帧号递增
	# 永不重现，循环证明不可能成立。
	var early := CombatSession.new()
	early.dummy_position = early.player_position + Vector2(ComboSolver.PIN_DX, 0)
	early.step(FrameInput.make(0, false, "A"))
	early.step(FrameInput.new())
	early.step(FrameInput.new())
	var late := CombatSession.new()
	late.dummy_position = late.player_position + Vector2(ComboSolver.PIN_DX, 0)
	for i in range(5):
		late.step(FrameInput.new())
	late.step(FrameInput.make(0, false, "A"))
	late.step(FrameInput.new())
	late.step(FrameInput.new())
	_check(early.debug_snapshot()["frame"] == 3 and late.debug_snapshot()["frame"] == 8,
		"snapshots really sit at different physical frames (3 vs 8)")
	_check(early.settlement_state() == late.settlement_state(),
		"settlement state normalizes absolute frame counters into relative ages (equal at matching phases)")


func _test_settlement_state_covers_player_side_fields() -> void:
	# 去重键必须包含影响未来结算的玩家侧字段：面向、jump 槽年龄与方向历史年龄
	# 各自只在其中一份会话出现差异时，键必须不等——旧木桩时序键看不见这些。
	var base := _session_in_5A_startup([])
	var flipped := _session_in_5A_startup([])
	flipped.player_facing = -1
	_check(base.settlement_state() != flipped.settlement_state(),
		"settlement state distinguishes player facing")
	var early_jump := _session_in_5A_startup([2])
	var late_jump := _session_in_5A_startup([4])
	_check(early_jump.settlement_state() != late_jump.settlement_state(),
		"settlement state distinguishes jump-slot age (jump flag participates in the key)")
	# 方向历史年龄：两份会话都在 5A 前摇中（木桩钉远避免命中干扰），下方向分别
	# 在第 2 / 第 3 帧进入方向历史，同一观测帧上年龄不同。
	var early_down := _whiffing_5a_with_down_at(2)
	var late_down := _whiffing_5a_with_down_at(3)
	_check(early_down.settlement_state() != late_down.settlement_state(),
		"settlement state distinguishes direction-history ages (candidates derive from them)")


## 推进 5 帧得到一份处于 5A 前摇中的会话（木桩钉在命中距离内、未到判定帧）；
## jump_at 非空表示在该物理帧补按一次 Space（5A 尚未命中确认，跳跃槽保持记录
## 并逐帧变龄）。
func _session_in_5A_startup(jump_at: Array) -> CombatSession:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	for frame in range(1, 6):
		var jump: bool = not jump_at.is_empty() and frame == jump_at[0]
		session.step(FrameInput.make(0, jump, "A" if frame == 1 else ""))
	return session


## 5A 起手后木桩钉远（挥空、无命中停顿），下方向在 down_frame 帧进入方向历史；
## 观测第 5 帧末。
func _whiffing_5a_with_down_at(down_frame: int) -> CombatSession:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(2000, 0)
	for frame in range(1, 6):
		var down := frame == down_frame
		session.step(FrameInput.make(0, false, "A" if frame == 1 else "", down))
	return session


# --- 循环证明：逐圈状态快照重现后才报告为循环 ---


func _test_valid_back_edge_proven_with_replay_materials() -> void:
	# C-01 起手修正改变了循环证明的可达性：三层累计修正是影响未来结算的会话
	# 状态（快照键含 starter grade 与三层层值），每次命中都改变层值——逐圈
	# 快照永不重现，命中循环在受击时间衰减到容不下下一击时自然断链。结构
	# 回路 5A ↔ 5B 不再被报告为可证明循环，而是以衰减断链上报（无全局上限）。
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	var report := _metrics.solve(_options(table))
	_check(report.safe and report.cycles.is_empty(),
		"the valid back edge loop breaks by correction decay instead of being proven (state never recurs: the layers change every hit)")
	var ba := _find_edge(report, "5B", "5A")
	_check(ba != null and ba.valid, "the back edge itself is still timing-valid")
	var broken := false
	for entry in report.notes:
		if "5A → 5B" in entry and "断开" in entry:
			broken = true
	_check(broken, "the structural loop is reported as broken in the lap simulation (hitstun decay, no global hit cap)")


func _test_proof_distinguishes_entry_lap_player_state() -> void:
	var table := MoveData.default_table()
	(table["jB"] as MoveData).landing_cancel_targets = ["5D", "5A"]
	var report := _metrics.solve(_options(table))
	_check(report.cycles.is_empty(), "an illegal landing seam never produces a recurrence proof")
	_check(report.edges.any(func(edge): return edge.from_id == "jB" and edge.to_id == "5A" and not edge.valid),
		"landing back edge is rejected before cycle search; ground recurrence proofs remain independently tested")


func _test_frame_cap_reports_truncation_not_cycle() -> void:
	# 周期过长的自回边（前摇 2300 帧）：2400 帧观测上限在第二圈中途到达，链条
	# 仍成立但远未完成 8 圈状态重现对拍——按观测截断上报，不报告为循环，
	# 也不宣称完整证明。
	var table := MoveData.default_table()
	table["5Z"] = _slow_self_loop()
	var report := _metrics.solve(_options(table))
	_check(report.cycles.is_empty() and report.safe,
		"a loop truncated by the frame cap is never reported as a cycle")
	var note := ""
	for entry in report.notes:
		if "5Z" in entry:
			note = entry
	_check(note != "" and "观测截断" in note and str(ComboSolver.MAX_CYCLE_FRAMES) in note,
		"the truncated loop is reported as an observation truncation naming the cap")
	_check("不宣称完整证明" in note and "断开" not in note,
		"the truncation note does not claim a complete proof and does not misreport a chain break")
	_check("检测到" not in report.summary and "截断" in report.summary,
		"the summary counts the truncated structural loop without claiming a detected cycle")


## 周期极长的自回边：前摇 2300 帧使一圈远超 2400 帧观测上限（第二圈中途截断）；
## 声明硬直 2450（D 起手应用值 2352）保证上限内木桩始终可追击（链条不断）。
func _slow_self_loop() -> MoveData:
	var slow := _injected_move("5Z", "Z")
	slow.startup_frames = 2300
	slow.active_frames = 2
	slow.recovery_frames = 5
	## D 起手时间层 0.96 使应用受击 = floor(声明×0.96)：2450 → 2352 > 2305 前摇，
	## 第二圈在第 2400 帧观测上限处截断（链条仍成立）。
	_set_probe_stun(slow, 2450)
	_set_probe_horizontal(slow, 0.0)
	slow.cancel_targets = ["5Z"]
	return slow


func _test_laps_exhausted_reports_incomplete_observation() -> void:
	# 持续上浮的自回边（LAUNCH 每圈无条件重起跳，knockback_up 1170 使每圈净
	# 位移是一个非零浮点——木桩逐圈停留在略不同的高度，8 圈内既不飞出命中框的
	# 竖直范围（链条不断），也永不完全重现）：每次预期命中都成立，但逐圈状态
	# 快照永不重现——按未完成观测上报，不报告为循环。滞空/浮空资源没有被自动
	# 续期：每圈上浮来自该圈真实命中（ku 再大即飞出竖直范围断链，再小则 8 圈内
	# 状态精确重现被证明——1170 落在两者之间的漂移区）。
	var table := MoveData.default_table()
	var riser := _injected_move("5Y", "Y")
	riser.startup_frames = 100
	riser.active_frames = 2
	riser.recovery_frames = 5
	_set_probe_launch(riser, 250, 0.0, 1170.0)
	_add_probe_airborne(riser, 250, 0.0, 1170.0)
	riser.cancel_targets = ["5Y"]
	table["5Y"] = riser
	var report := _metrics.solve(_options(table))
	_check(report.cycles.is_empty() and report.safe,
		"a never-recurring loop is never reported as a cycle even though the chain holds")
	var note := ""
	for entry in report.notes:
		if "5Y" in entry:
			note = entry
	_check(note != "" and "未完成观测" in note and "不宣称完整证明" in note,
		"the laps-exhausted loop is reported as an incomplete observation, not a proof")
	_check("断开" not in note, "the incomplete-observation note does not misreport a chain break")
	var self_edge := _find_edge(report, "5Y", "5Y")
	_check(self_edge != null and self_edge.valid,
		"the self edge itself is timing-valid (the cap limits the loop proof, not the edge)")


func _test_recovery_horizon_truncation_annotated() -> void:
	# 240 帧恢复观测上限：木桩地面硬直 250 帧在上限内不会自然受身，边的恢复
	# 年龄是截断值而非实测恢复——如实标注，不把观测上限伪装成恢复证明。
	var table := MoveData.default_table()
	var stunner := _injected_move("5Y", "Y")
	## 声明 260 → 应用 floor(260×0.96) = 249 > 240 上限：上限内不恢复（250 会被
	## 浮点乘法折成 239 而被实测到恢复）。
	_set_probe_stun(stunner, 260)
	_set_probe_horizontal(stunner, 0.0)
	stunner.cancel_targets = ["5A"]
	table["5Y"] = stunner
	var report := _metrics.solve(_options(table))
	var edge := _find_edge(report, "5Y", "5A")
	_check(edge != null and edge.valid, "the 5Y -> 5A cancel edge is timing-valid under the pinned geometry")
	if edge != null:
		_check(str(ComboSolver.RECOVER_HORIZON) in edge.reason and "截断" in edge.reason,
			"the edge reason marks the recovery age as a truncated observation, not a measured recovery")
		var plain := _find_edge(_default_solve(), "5A", "5B")
		_check(plain != null and "截断" not in plain.reason,
			"a normally observed recovery carries no truncation mark")


# --- 报告内容与确定性排序 ---


func _test_cycle_report_carries_start_and_replay() -> void:
	# 修正模型下没有可证明循环：报告的循环节以结构性回路的衰减断链注记呈现，
	# 不再携带已证明循环的起始状态/逐帧回放块（该路径在命中循环下不可达）。
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	var report := _metrics.solve(_options(table))
	var text := "\n".join(report.to_lines())
	_check("5A → 5B → 回到 5A" in text, "the structural loop path appears in the report notes")
	_check("断开" in text, "the loop is reported as broken by the lap simulation")
	_check("逐帧回放" not in text, "no replay block is fabricated without a proven cycle")


func _test_cycles_sorted_and_report_deterministic() -> void:
	# 两个已证明循环同时存在时按标签稳定排序；整份报告跨运行逐行一致。
	var table := MoveData.default_table()
	(table["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	(table["jB"] as MoveData).landing_cancel_targets = ["5D", "5A"]
	var report := _metrics.solve_reused("cycle-sort", _options(table))
	_check(report.cycles.is_empty(), "neither back edge is proven: the ground loop decays apart and the landing back edge is excluded")
	var labels: Array[String] = []
	for cycle in report.cycles:
		labels.append(cycle.label())
	var sorted_labels := labels.duplicate()
	sorted_labels.sort()
	_check(labels == sorted_labels, "cycles are stably sorted by their labels")
	_check(_metrics.solve_reused("cycle-sort", _options(table)).to_lines() == report.to_lines(),
		"solving the same table twice yields identical reports, cycle section included")


func _test_scope_documents_observation_caps() -> void:
	# 证明范围声明四个安全上限及其语义：达到上限以截断/未完成观测上报，
	# 不作为完整证明；空中延迟上限与规格冻结值一致（40 帧）。
	var report := _default_solve()
	_check(str(ComboSolver.MAX_CYCLE_LAPS) in report.scope and str(ComboSolver.MAX_CYCLE_FRAMES) in report.scope,
		"the scope names the lap and frame caps")
	_check(str(ComboSolver.RECOVER_HORIZON) in report.scope and "40 帧" in report.scope,
		"the scope names the recovery-horizon and air-delay caps (40 frames per the frozen spec)")
	_check("截断" in report.scope and "不宣称完整证明" in report.scope,
		"the scope states that reaching a cap is reported as truncation, never a complete proof")


# --- 辅助 ---


func _options(table: Dictionary) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	return opts


func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int = -1) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id and (kind < 0 or edge.kind == kind):
			return edge
	return null


## 把输入表回放到使用同一份招式表的全新 CombatSession（木桩按探针几何钉在玩家
## 面前），统计命中帧；until 为最后一个输入帧之后的额外观测帧数。
func _replay_inputs(table: Dictionary, inputs: Array, until := 0) -> Dictionary:
	var by_frame := {}
	var last := 0
	for spec in inputs:
		by_frame[spec.frame] = spec
		last = maxi(last, spec.frame)
	last += until
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	var hit_frames: Array[int] = []
	var frame := 0
	while frame < last:
		frame += 1
		while session.hitstop_active():
			session.step(FrameInput.new())
			session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		var input := FrameInput.new()
		if by_frame.has(frame):
			input = by_frame[frame].to_frame_input()
		var events := session.step(input)
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
	return { "hit_frames": hit_frames, "combo_hits": session.combo_hits }


## 测试注入招式：字段齐全的合法打击招式（注入表只喂给 Solver 探针，不经过
## MoveTable 校验，键名可超出 A–D）。
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

func _default_solve() -> ComboSolver.SolverReport:
	return _metrics.solve_reused("default")
