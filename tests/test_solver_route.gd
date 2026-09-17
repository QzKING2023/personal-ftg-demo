extends SceneTree
## Combo Solver 完整路线与时序验证（ftg-combat-foundation issue 20）：
## 配置缺口——时序成立但缺 cancel_targets / jump_cancel_targets / landing_cancel_targets
## 配置的候选只用一次性探针表验证并报告为缺口，不宣布为合法连段；输入绑定与方向
## variant（派生记法 + 显式替代串）逐条在真实结算中验证；挥空、自然受身与恢复的
## 失败原因可区分；缺口枚举保持稳定排序、确定性与运行时隔离。
## 运行：godot --headless --path . -s res://tests/test_solver_route.gd

var _failures := 0


func _initialize() -> void:
	print("")
	_test_default_table_reports_config_gaps()
	_test_gaps_are_never_claimed_as_legal()
	_test_timing_invalid_or_structural_pairs_not_gaps()
	_test_gap_becomes_valid_edge_once_configured()
	_test_landing_gap_from_direct_jump_entry()
	_test_pairing_wait_landing_target_not_a_gap()
	_test_binding_and_variant_lines()
	_test_inexpressible_variant_reported()
	_test_whiff_reason_distinguishable()
	_test_recovery_and_tech_reasons_stay_distinct()
	_test_gaps_sorted_deterministic_and_isolated()
	print("")
	if _failures == 0:
		print("ALL SOLVER ROUTE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 配置缺口：时序成立但缺配置 ---


func _test_default_table_reports_config_gaps() -> void:
	var report := ComboSolver.solve()
	var cancel_gap := _find_gap(report, "5A", "5D", ComboSolver.EdgeKind.CANCEL)
	_check(cancel_gap != null, "5A → 5D is reported as a cancel config gap (timing holds, cancel_targets lacks it)")
	if cancel_gap != null:
		_check("缺配置" in cancel_gap.reason and "cancel_targets" in cancel_gap.reason,
			"the cancel gap names the missing configuration field")
		_check(cancel_gap.hit_age == 5 and cancel_gap.recover_age == 21,
			"the gap carries the verified timing (earliest hit age 5 <= dummy recover age 21)")
	var jump_gap := _find_gap(report, "5A", "jA", ComboSolver.EdgeKind.JUMP_CANCEL)
	_check(jump_gap != null, "5A → jA is reported as a jump-cancel config gap")
	if jump_gap != null:
		_check("缺配置" in jump_gap.reason and "jump_cancel_targets" in jump_gap.reason,
			"the jump-cancel gap names the missing configuration field")
	var landing_gap := _find_gap(report, "jB", "5A", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(landing_gap != null, "jB → 5A is reported as a landing config gap (it proves a cycle once configured)")
	if landing_gap != null:
		_check("缺配置" in landing_gap.reason and "landing_cancel_targets" in landing_gap.reason,
			"the landing gap names the missing configuration field")
	_check(_find_gap(report, "5A", "5B", ComboSolver.EdgeKind.CANCEL) == null,
		"configured pairs never appear as gaps")
	_check(_find_gap(report, "5C", "jA", ComboSolver.EdgeKind.JUMP_CANCEL) == null,
		"configured jump-cancel pairs never appear as gaps")
	_check(_find_gap(report, "jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL) == null,
		"configured landing pairs never appear as gaps")


func _test_gaps_are_never_claimed_as_legal() -> void:
	var report := ComboSolver.solve()
	_check(report.edges.size() == 9, "gap enumeration leaves the configured edge set untouched (still 9 edges)")
	for edge in report.edges:
		_check(not (edge.from_id == "5A" and edge.to_id == "5D"),
			"no 5A → 5D edge is invented for the timing-valid unconfigured pair")
	var uses_gap_pair := false
	for route in report.routes:
		for i in range(1, route.move_ids.size()):
			var pair := "%s|%s" % [route.move_ids[i - 1], route.move_ids[i]]
			if pair == "5A|5D" or pair == "5A|5C" or pair == "jA|5D":
				uses_gap_pair = true
	_check(not uses_gap_pair, "no route walks through an unconfigured pair (gaps never become routes)")
	_check(report.cycles.is_empty() and report.safe, "gaps never create cycles")
	for gap in report.gaps:
		_check(not gap.valid, "a gap entry is never flagged as a valid edge")
	var text := "\n".join(report.to_lines())
	_check("配置缺口" in text, "the report has a config-gap section")
	_check("缺配置" in text, "gap lines state the missing configuration")
	_check("配置缺口" in report.summary, "the summary counts the config gaps")


func _test_timing_invalid_or_structural_pairs_not_gaps() -> void:
	# 时序不成立（命中晚于木桩恢复）、收尾来源（补配置也不开放）与姿态不符的
	# 未配置对都不构成配置缺口——缺口只报告「补上配置即可成立」的时序。
	var table := MoveData.default_table()
	var quick := _injected_move("5F", "F")
	quick.startup_frames = 2
	quick.active_frames = 2
	quick.recovery_frames = 3
	quick.hitstun_frames = 4
	quick.knockback = 0.0
	quick.knockback_up = 0.0
	table["5F"] = quick
	var slow := _injected_move("5H", "H")
	slow.startup_frames = 25
	slow.active_frames = 2
	slow.recovery_frames = 8
	table["5H"] = slow
	var report := ComboSolver.solve(_options(table))
	_check(_find_gap(report, "5F", "5H", ComboSolver.EdgeKind.CANCEL) == null,
		"a pair whose hit lands after dummy recovery is not a gap")
	_check(_find_gap(report, "5F", "5A", ComboSolver.EdgeKind.CANCEL) == null,
		"the 4-frame stun admits no cancel-gap followup either")
	_check(_find_gap(report, "5D", "5A", ComboSolver.EdgeKind.CANCEL) == null,
		"a finisher source is never a gap (configuring it would not open the cancel)")
	_check(_find_gap(report, "5B", "jA", ComboSolver.EdgeKind.CANCEL) == null,
		"stance-mismatched cancel pairs are not gaps")


func _test_gap_becomes_valid_edge_once_configured() -> void:
	# 双端一致性：把缺口补进配置后，同一对成为合法边并从缺口列表消失；
	# 缺口探针使用一次性注入表，调用方传入的招式表不被改写。
	var table := MoveData.default_table()
	(table["5A"] as MoveData).cancel_targets = ["5B", "236C", "5D"]
	var before := (table["5A"] as MoveData).cancel_targets.duplicate()
	var report := ComboSolver.solve(_options(table))
	var edge := _find_edge(report, "5A", "5D", ComboSolver.EdgeKind.CANCEL)
	_check(edge != null and edge.valid, "configuring the gap turns 5A → 5D into a valid edge")
	_check(_find_gap(report, "5A", "5D", ComboSolver.EdgeKind.CANCEL) == null,
		"the configured pair no longer appears as a gap")
	_check((table["5A"] as MoveData).cancel_targets == before,
		"gap probes never mutate the caller's move table")


# --- 落地接缝：直接经 jump cancel 进入的空中来源 ---


func _test_landing_gap_from_direct_jump_entry() -> void:
	# jA 由 jump cancel 直接进入（上下文不含空中取消链）：落地接缝枚举同样覆盖
	# 这种来源；对齐受 5C 浮空硬直约束（36f 自然受身先于滞空耗尽），有效档为
	# 落地帧前 6–8 帧；补配置后接缝成为合法边并验证同一范围。
	var report := ComboSolver.solve()
	var gap := _find_gap(report, "jA", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(gap != null, "jA → 5D is reported as a landing config gap (jA entered directly via jump cancel)")
	if gap != null:
		_check(gap.align_from == 6,
			"the gap reports the earliest workable alignment (lead 6 — the 5C float stun expires before later air hits)")
	var table := MoveData.default_table()
	(table["jA"] as MoveData).landing_cancel_targets = ["5D"]
	var configured := ComboSolver.solve(_options(table))
	var edge := _find_edge(configured, "jA", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(edge != null and edge.valid, "configuring the direct-entry landing seam makes it a valid edge")
	if edge != null:
		_check(edge.align_from == 6 and edge.align_to == 8,
			"the direct-entry seam verifies alignments 6–8 frames before the landing frame")
		_check(not edge.align_inputs.is_empty(), "the seam carries a replayable alignment schedule")
		var replay := _replay_landing(edge, table)
		_check(replay.hits == 3 and replay.landing_move_5d,
			"replaying the schedule lands 3 hits and the buffered D starts 5D on the landing frame")


func _test_pairing_wait_landing_target_not_a_gap() -> void:
	# 诚实缺口：B/C 是投组合成员键，落地帧前的按下要吃 3f 组合等待，落地恢复
	# 锁定使消费不可达——时序不成立的落地对不报告为缺口。
	var report := ComboSolver.solve()
	_check(_find_gap(report, "jA", "5B", ComboSolver.EdgeKind.LANDING_CANCEL) == null,
		"a B-target landing seam whose pairing wait eats the landing frame is not a gap")


# --- 输入绑定与方向 variant 枚举 ---


func _test_binding_and_variant_lines() -> void:
	var report := ComboSolver.solve()
	var text := "\n".join(report.binding_lines)
	var lines := "\n".join(report.to_lines())
	_check("输入绑定" in lines and "variant" in lines, "the report has a binding/variant section")
	_check("5A｜U 键（A）｜无方向指令" in text, "plain binding moves are listed without a direction command")
	_check("236C｜K 键（C）｜variant 236（严格，3 步，窗口 30 帧）：验证成立" in text,
		"the 236C variant is enumerated with its strict notation, step count and window, and verified")
	_check("214D｜J 键（D）｜variant 214（严格，3 步，窗口 30 帧）：验证成立" in text,
		"the 214D variant is enumerated and verified")
	# 宽松指令与显式替代串：每个声明 variant 独立验证（窗口按实际步数计）。
	var table := MoveData.default_table()
	var lenient := _injected_move("623A", "A")
	lenient.direction_derivation = "623A"
	lenient.lenient_command = true
	lenient.command_tier = MoveData.CommandTier.SPECIAL
	lenient.priority = 2
	table["623A"] = lenient
	var super_move := _injected_move("632146D", "D")
	super_move.direction_derivation = "236236D"
	super_move.input_alternatives = ["23626D", "26236D"]
	super_move.command_tier = MoveData.CommandTier.SUPER
	super_move.priority = 2
	table["632146D"] = super_move
	var enriched := ComboSolver.solve(_options(table))
	var enriched_text := "\n".join(enriched.binding_lines)
	_check("623A｜U 键（A）｜variant 623（宽松，3 步，窗口 30 帧）：验证成立" in enriched_text,
		"the lenient 623 variant is labeled lenient and verified")
	_check("variant 236236（严格，6 步，窗口 60 帧）：验证成立" in enriched_text,
		"the six-step super notation verifies with its 60-frame window")
	_check("variant 23626（严格，5 步，窗口 50 帧）：验证成立" in enriched_text \
		and "variant 26236（严格，5 步，窗口 50 帧）：验证成立" in enriched_text,
		"each declared alternative string verifies as its own variant with the step-count window")


func _test_inexpressible_variant_reported() -> void:
	# 声明了方向段 7/8/9 的替代串：方向历史只产生 1/2/3/4/6（严格记法无段可匹配），
	# 该 variant 无法被任何地面方向喂入达成——如实报告为不可表达，不静默跳过。
	var table := MoveData.default_table()
	var odd := _injected_move("9D9D", "D")
	odd.direction_derivation = "236236D"
	odd.input_alternatives = ["999D"]
	odd.command_tier = MoveData.CommandTier.SUPER
	odd.priority = 2
	table["9D9D"] = odd
	var report := ComboSolver.solve(_options(table))
	var text := "\n".join(report.binding_lines)
	_check("variant 999" in text and "不可表达" in text,
		"an alternative whose direction steps cannot be expressed is reported as inexpressible")


# --- 失败原因区分：挥空 / 自然受身 / 恢复 ---


func _test_whiff_reason_distinguishable() -> void:
	# 目标已起手但判定从未连接（命中框在探针几何之外）＝挥空；与「未能在窗口内
	# 起手」及「命中晚于木桩恢复」区分开。
	var table := MoveData.default_table()
	var whiffy := _injected_move("5W", "W")
	whiffy.hitbox_size = Vector2(8, 8)
	whiffy.hitbox_gap = 500.0
	table["5W"] = whiffy
	var whiffy_two := _injected_move("5V", "V")
	whiffy_two.hitbox_size = Vector2(8, 8)
	whiffy_two.hitbox_gap = 500.0
	table["5V"] = whiffy_two
	(table["5A"] as MoveData).cancel_targets = ["5W"]
	(table["5B"] as MoveData).cancel_targets = ["5D", "214D", "5V"]
	var report := ComboSolver.solve(_options(table))
	var edge := _find_edge(report, "5A", "5W", ComboSolver.EdgeKind.CANCEL)
	_check(edge != null and not edge.valid, "the whiffed target edge is excluded")
	if edge != null:
		_check("挥空" in edge.reason, "the exclusion reason names the whiff (started but never connected)")
	var route := _find_route(report, ["5A", "5B"])
	if route != null:
		_check("挥空" in route.note, "the route breakpoint names the whiff")


func _test_recovery_and_tech_reasons_stay_distinct() -> void:
	# 命中晚于木桩恢复（等待超时＝恢复原因）点名自然受身与连段重置；挥空措辞
	# 不与之混淆。三类失败原因（挥空 / 未起手 / 自然受身恢复）在边排除理由中可区分。
	var table := MoveData.default_table()
	var slow := _injected_move("5H", "H")
	slow.startup_frames = 25
	slow.active_frames = 2
	slow.recovery_frames = 8
	table["5H"] = slow
	(table["5A"] as MoveData).cancel_targets = ["5H"]
	var report := ComboSolver.solve(_options(table))
	var edge := _find_edge(report, "5A", "5H", ComboSolver.EdgeKind.CANCEL)
	_check(edge != null and not edge.valid, "the slow-target edge is excluded")
	if edge != null:
		_check("恢复" in edge.reason and "自然受身" in edge.reason and "挥空" not in edge.reason,
			"the wait-timeout exclusion names dummy recovery and the natural tech, not a whiff")


# --- 稳定排序、确定性与运行时隔离 ---


func _test_gaps_sorted_deterministic_and_isolated() -> void:
	var first := ComboSolver.solve()
	var keys: Array[String] = []
	for gap in first.gaps:
		keys.append("%s|%s|%d" % [gap.from_id, gap.to_id, gap.kind])
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	_check(keys == sorted_keys, "gaps are stably sorted by from → to → kind")
	_check(first.mirror_consistent, "gap enumeration stays mirror-consistent across both facings")
	_check(ComboSolver.solve().to_lines() == first.to_lines(),
		"solving twice yields identical reports, gaps included")
	# 运行时隔离：缺口探针同样不触碰活动会话。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	session.step(FrameInput.make(0, false, "A"))
	for i in range(5):
		session.step(FrameInput.new())
	var before := _snapshot_session(session)
	ComboSolver.solve()
	var after := _snapshot_session(session)
	_check(before == after, "running solve() with gap enumeration leaves a live session untouched")
	_check(session.player_move_id == "5A" and session.combo_hits == 1,
		"the live session is still inside its 5A hit-confirmed combo")


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


func _find_gap(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int = -1) -> ComboSolver.SolverEdge:
	for gap in report.gaps:
		if gap.from_id == from_id and gap.to_id == to_id and (kind < 0 or gap.kind == kind):
			return gap
	return null


func _find_route(report: ComboSolver.SolverReport, move_ids: Array[String]) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


## 落地接缝对齐样本回放：按正常帧推进（停顿以空输入跳过），断言总命中数与
## 落地帧当帧缓存的 D 被重解析为 5D 起手。回放会话使用同一份注入表——落地
## 接续是运行时硬约束，默认表不会执行未配置的接缝。
func _replay_landing(edge: ComboSolver.SolverEdge, table: Dictionary) -> Dictionary:
	var by_frame := {}
	var last := 0
	for spec in edge.align_inputs:
		by_frame[spec.frame] = spec
		last = maxi(last, spec.frame)
	last += 1 + GameParams.MOVE_5D_STARTUP_FRAMES
	var session := CombatSession.new(table)
	var hits := 0
	var landing_move_5d := false
	var frame := 0
	while frame < last:
		frame += 1
		var input := FrameInput.new()
		if by_frame.has(frame):
			input = by_frame[frame].to_frame_input()
		var was_airborne := not session.player_on_ground
		var events := _step_logical(session, input)
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits += 1
		if was_airborne and session.player_on_ground:
			landing_move_5d = session.player_move_id == "5D"
	return {"hits": hits, "landing_move_5d": landing_move_5d}


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
