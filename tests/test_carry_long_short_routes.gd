extends SceneTree
## 连段路线票据 03：B/C 搬运长短路线（R1/R2）与 D 来源/停止/M 规则。
## 覆盖父规格规则 2/3/4/5/7/8 与数值表（D 恢复 6/10、蓄力 D 位移 640、
## 蓄力 D 空中上速 380、236C 第二段对空水平 3200、5B→6D 必杀取消出口、
## D→5B 命中限定普通连接）、地面稍晚普通连接 M 及其资格存续/清理、
## 蓄力 D 身后停止 / 交界 2px 正面停止 / 墙分支、墙边分离（原侧钳制改放
## 合法场内侧）、四样本准确路线与保证域、关键键窗口与负例。
## 运行：godot --headless --path . -s res://tests/test_carry_long_short_routes.gd
## 窗口/联合/扫描按 D72 只记录，不设旧 7F/244 门槛。

const HORIZON := 160


var _failures := 0


func _initialize() -> void:
	_test_ticket_resources()
	_test_move_table_new_field_validation()
	_test_d_to_5b_source_opening_entry_and_plain()
	_test_d_whiff_keeps_no_link()
	_test_m_wait_late_link()
	_test_m_wait_walk_crouch_jump_preserve()
	_test_m_wait_undeclared_attack_clears()
	_test_m_wait_early_expiry_and_recovery_close()
	_test_charge_stop_behind_target()
	_test_charge_stop_no_follow()
	_test_charge_stop_wall_branch()
	_test_y2_front_stop_margin()
	_test_x_in_field_separation()
	_test_route_samples()
	_test_route_junction()
	_test_route_domain_sweep()
	_test_route_negatives()
	_test_route_save_restore()
	_test_route_windows()
	print("")
	if _failures == 0:
		print("ALL CARRY LONG SHORT ROUTES TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


func _approx(a: float, b: float, tolerance := 0.01) -> bool:
	return absf(a - b) <= tolerance


# --- 布置与输入构造（固定帧计划；未列帧中立）---

## g 为双方身体横向边缘间距，r 为目标身体边缘到其身后指定墙的距离。
func _place(g: float, r: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dummy_x := wall - r * facing
	var player_x := dummy_x - facing * (GameParams.BODY_SIZE.x + g)
	session.player_position = Vector2(player_x, GameParams.ground_stand_y())
	session.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y())
	session.player_facing = facing
	return session


func _hold(key: String, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	input.held_action_keys = [key]
	input.move_axis = axis
	return input


func _press(key: String, axis := 0, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	input.move_axis = axis
	input.down_held = down
	return input


func _direction(axis: int, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	input.down_held = down
	return input


func _vertical_jump() -> FrameInput:
	var input := FrameInput.new()
	input.jump_pressed = true
	input.up_held = true
	return input


func _neutral() -> FrameInput:
	return FrameInput.new()


## 逐帧喂入固定计划；收集事件（含帧号）与逐帧状态快照。
func _run(session: CombatSession, plan: Dictionary, horizon := HORIZON) -> Dictionary:
	var events: Array = []
	var frames: Array = []
	for frame in range(1, horizon + 1):
		var input: FrameInput = plan.get(frame, _neutral())
		for event in session.step(input):
			events.append({"frame": frame, "event": event})
		frames.append(session.clone_state())
	return {"session": session, "events": events, "frames": frames}


func _event_of(entry: Dictionary) -> CombatEvent:
	return entry["event"]


func _event_type(entry: Dictionary) -> int:
	return _event_of(entry).type


func _find_events(events: Array, type: CombatEvent.Type) -> Array:
	var result: Array = []
	for entry in events:
		if _event_type(entry) == type:
			result.append(entry)
	return result


## 5[D] 完整恢复（收招）物理帧：最后一次 5[D] 帧之后的首个中立帧。
func _d_finish_frame(frames: Array) -> int:
	var last_d := -1
	for i in range(frames.size()):
		if frames[i].player_move.move_id == "5[D]":
			last_d = i
		elif last_d >= 0 and frames[i].player.phase == CombatSession.PlayerPhase.NEUTRAL:
			return i + 1
	return -1


func _started_via_link(frames: Array, move_id: String) -> bool:
	for state in frames:
		if state.player_move.move_id == move_id and bool(state.player_move.via_link):
			return true
	return false


## 236C（末键 F4，两段命中：seg1 F13、seg2 F25——B/C 单键经 3 帧组合等待后
## F7 起手）后于 d_press 按下并按住 D 至 +17 的固定前缀。d_press=27：第二段
## 判定帧之后的恢复窗口内，特殊进入资格仍开放且不砍掉第二段。
func _entry_prefix(d_press := 27) -> Dictionary:
	var plan := {}
	plan[1] = _direction(0, true)
	plan[2] = _direction(1, true)
	plan[3] = _direction(1)
	plan[4] = _press("C", 1)
	if d_press > 0:
		plan[d_press] = _press("D")
		for frame in range(d_press + 1, d_press + 18):
			plan[frame] = _hold("D")
	return plan


## 5B（F1）→ F8 链式取消点按 D 的固定前缀（普通来源普通 5D；接地硬直余量
## 只够普通版恢复 6N 内的当帧连接）。
func _plain_prefix() -> Dictionary:
	var plan := {}
	plan[1] = _press("B")
	plan[8] = _press("D")
	return plan


## 探测前缀运行：返回蓄力 D 命中帧与完整恢复帧（确定性两遍：先探后续接固定帧）。
## 探测前缀运行：返回 D 命中帧（D 的那一击）与完整恢复帧（确定性两遍：先探
## 后续接固定帧计划）。d_move_ids 区分蓄力/普通版。
func _probe(prefix: Dictionary, g: float, r: float, facing: int, d_move_ids := ["5[D]"], horizon := 140) -> Dictionary:
	var result := _run(_place(g, r, facing), prefix, horizon)
	var d_hit := -1
	var d_finish := -1
	var last_d_index := -1
	for entry in result.events:
		if _event_type(entry) == CombatEvent.Type.HIT:
			d_hit = entry.frame
	for i in range(result.frames.size()):
		var move_id: String = result.frames[i].player_move.move_id
		if d_move_ids.has(move_id):
			last_d_index = i
		elif last_d_index >= 0 and result.frames[i].player.phase == CombatSession.PlayerPhase.NEUTRAL:
			d_finish = i + 1
			break
	return {"d_hit": d_hit, "d_finish": d_finish, "result": result}


# --- 1. 票据资源与数值表 ---

func _test_ticket_resources() -> void:
	var table := MoveData.default_table()
	var d5 := table["5D"] as MoveData
	var d5c := table["5[D]"] as MoveData
	var c236 := table["236C"] as MoveData
	var b5 := table["5B"] as MoveData
	_check(d5.recovery_frames == 6, "普通 5D 恢复 6N（当前 %d）" % d5.recovery_frames)
	_check(d5c.recovery_frames == 10, "蓄力 5[D] 恢复 10N（当前 %d）" % d5c.recovery_frames)
	_check(_approx(d5c.motion_x_px, 640.0), "蓄力 5[D] 首次 active 锚点最大计划位移 640px（当前 %.1f）" % d5c.motion_x_px)
	_check(_approx(d5.motion_x_px, 72.0), "普通 5D 位移 72px 保持（当前 %.1f）" % d5.motion_x_px)
	_check(d5c.active_frames == 4, "蓄力 5[D] active 仍 4N（当前 %d）" % d5c.active_frames)
	var charged_air_n := MoveData.profile_for(d5c, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL)
	_check(charged_air_n != null and _approx(charged_air_n.upward_speed_px_s, 380.0) and _approx(charged_air_n.horizontal_speed_px_s, 80.0) and charged_air_n.air_untech_frames == 32,
		"蓄力 D AIRBORNE×NORMAL 上速 380、水平 80、不可受身 32N 保持")
	var plain_air_n := MoveData.profile_for(d5, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL)
	_check(plain_air_n != null and _approx(plain_air_n.upward_speed_px_s, 170.0), "普通 5D 空中资料不随蓄力版改写（上速保持 170）")
	var seg2_air_n: HitProfile = null
	for profile in (c236.segments[0] as MoveSegment).hit_profiles:
		if profile.target_state == HitProfile.TargetState.AIRBORNE and profile.hit_context == HitProfile.HitContext.NORMAL:
			seg2_air_n = profile
	_check(seg2_air_n != null and _approx(seg2_air_n.horizontal_speed_px_s, 3200.0) and _approx(seg2_air_n.upward_speed_px_s, 180.0) and seg2_air_n.air_untech_frames == 30,
		"236C 第二段 AIRBORNE×NORMAL 水平 3200、上速 180/不可受身 30 不改写")
	var seg1_air_n := MoveData.profile_for(c236, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL)
	_check(seg1_air_n != null and _approx(seg1_air_n.horizontal_speed_px_s, 40.0), "236C 第一段空中水平 40 保持")
	var seg2_gnd_n: HitProfile = null
	for profile in (c236.segments[0] as MoveSegment).hit_profiles:
		if profile.target_state == HitProfile.TargetState.GROUNDED and profile.hit_context == HitProfile.HitContext.NORMAL:
			seg2_gnd_n = profile
	_check(seg2_gnd_n != null and _approx(seg2_gnd_n.horizontal_speed_px_s, 100.0) and _approx(seg2_gnd_n.upward_speed_px_s, 120.0) and seg2_gnd_n.slide_frames == 18,
		"236C 第二段对地 slide 资料不改写")
	_check(b5.special_cancel_targets.has("6D"), "5B 必杀取消出口包含 6D")
	_check(d5.hit_link_targets == ["5B"] and d5c.hit_link_targets == ["5B"],
		"普通/蓄力 D 声明命中限定普通连接 5B")
	_check(d5.special_entry_link_targets.is_empty() and d5c.special_entry_link_targets.is_empty(),
		"D 系来源限定连接边已由命中限定边取代（不再按 236C 进入来源限制）")
	_check(d5c.stop_behind_target and not d5.stop_behind_target,
		"身后停止声明只在蓄力 D 上")


# --- 2. 新字段校验（注入表拒绝非法组合）---

func _test_move_table_new_field_validation() -> void:
	var base := MoveData.default_table()
	var moves: Array = []
	for move_id in base:
		moves.append(base[move_id])
	# 1) hit_link_targets 引用不存在的目标。
	var bad_ref: MoveData = (base["5D"] as MoveData).duplicate()
	bad_ref.hit_link_targets = ["NOPE"]
	var errors := MoveTable.validate(_replace_move(moves, "5D", bad_ref))
	_check(not errors.is_empty(), "hit_link_targets 引用不在表内的目标整表拒绝")
	# 2) 同一目标同时出现在 link_targets 与 hit_link_targets。
	var dup: MoveData = (base["5D"] as MoveData).duplicate()
	dup.link_targets = ["5B"]
	dup.hit_link_targets = ["5B"]
	errors = MoveTable.validate(_replace_move(moves, "5D", dup))
	_check(not errors.is_empty(), "同一普通连接目标在两类边中重复声明整表拒绝")
	# 3) stop_behind_target 声明在非蓄力版招式上。
	var stop_plain: MoveData = (base["5D"] as MoveData).duplicate()
	stop_plain.stop_behind_target = true
	errors = MoveTable.validate(_replace_move(moves, "5D", stop_plain))
	_check(not errors.is_empty(), "stop_behind_target 只属于 charge_only 蓄力版")
	# 4) stop_behind_target 但未声明计划位移。
	var stop_no_motion: MoveData = (base["5[D]"] as MoveData).duplicate()
	stop_no_motion.stop_behind_target = true
	stop_no_motion.motion_x_px = NAN
	stop_no_motion.motion_y_px = NAN
	errors = MoveTable.validate(_replace_move(moves, "5[D]", stop_no_motion))
	_check(not errors.is_empty(), "stop_behind_target 缺少计划位移整表拒绝")
	# 5) 合法默认表通过。
	errors = MoveTable.validate(moves)
	_check(errors.is_empty(), "默认表通过新字段校验（实际：%s）" % str(errors.slice(0, 2)))


func _replace_move(moves: Array, move_id: String, crafted: MoveData) -> Array:
	var result: Array = []
	for move in moves:
		if (move as MoveData).move_id == move_id:
			result.append(crafted)
		else:
			result.append(move)
	return result


# --- 3. D→5B 来源开放（命中限定普通连接，规则 2）---

func _test_d_to_5b_source_opening_entry_and_plain() -> void:
	# 经 236C 特殊进入的蓄力 D 实际命中后，完整恢复即可普通连接 5B
	#（恢复前预存的缓存消费仍直接成立）。
	var probe := _probe(_entry_prefix(), 6, 300, 1)
	_check(probe.d_hit > 0 and probe.d_finish > probe.d_hit, "特殊进入蓄力 D 命中并完整恢复（F%d → F%d）" % [probe.d_hit, probe.d_finish])
	var plan := _entry_prefix()
	plan[probe.d_finish - 4] = _press("B")
	var result := _run(_place(6, 300, 1), plan)
	var hits := _find_events(result.events, CombatEvent.Type.HIT)
	_check(hits.size() >= 3 and _event_of(hits[2]).combo_hits == 3, "236C 两段 + 蓄力 D 共 3 击（实际 %d）" % hits.size())
	_check(_started_via_link(result.frames, "5B"), "特殊进入蓄力 D 命中后 5B 经普通连接起手（来源开放；当帧起手后的接触由几何另行判定）")
	# 普通来源（5B 链式取消进入 D，无 236C）同样开放：蓄力命中后 5B 连接。
	var plain_probe := _probe(_plain_prefix(), 6, 60, 1, ["5D"])
	_check(plain_probe.d_hit > 0 and plain_probe.d_finish > plain_probe.d_hit, "普通来源蓄力 D 命中并完整恢复（F%d → F%d）" % [plain_probe.d_hit, plain_probe.d_finish])
	var plain_plan := _plain_prefix()
	plain_plan[plain_probe.d_finish - 4] = _press("B")
	var plain := _run(_place(6, 60, 1), plain_plan)
	_check(_find_events(plain.events, CombatEvent.Type.HIT).size() == 3, "普通来源：5B + 蓄力 D + 5B 三击（实际 %d）" % _find_events(plain.events, CombatEvent.Type.HIT).size())
	_check(_started_via_link(plain.frames, "5B"), "普通来源蓄力 D 命中后 5B 经普通连接起手（不再要求 236C 进入来源）")


func _test_d_whiff_keeps_no_link() -> void:
	# 挥空的 D 不获得命中限定连接：236C 两段把木桩大推离到墙，特殊进入窗口
	# 末点按普通 5D 追不上（挥空），随后按 B 不得经普通连接补入旧连段。
	var plan := {}
	plan[1] = _direction(0, true)
	plan[2] = _direction(1, true)
	plan[3] = _direction(1)
	plan[4] = _press("C", 1)
	plan[40] = _press("D")
	plan[60] = _press("B")
	var result := _run(_place(6, 400, 1), plan)
	var hits := _find_events(result.events, CombatEvent.Type.HIT)
	_check(hits.size() == 2, "236C 两段命中、其后的普通 5D 挥空（HIT 共 %d）" % hits.size())
	_check(not _started_via_link(result.frames, "5B"), "挥空 D 不产生 5B 普通连接资格")
	var combo_ended := _find_events(result.events, CombatEvent.Type.COMBO_ENDED)
	_check(not combo_ended.is_empty() and result.session.combo_hits == 2,
		"挥空后连段按收招/自然恢复结束，combo_hits 停在 2（实际 %d）" % result.session.combo_hits)


# --- 4. M 稍晚普通连接（规则 7/8：无固定等待上限，自然截止清理）---

func _test_m_wait_late_link() -> void:
	# D 命中后完整恢复，之后较晚（超过旧收招当帧口径）按 B 仍可普通连接。
	var probe := _probe(_entry_prefix(), 6, 300, 1)
	var plan := _entry_prefix()
	plan[probe.d_finish + 5] = _press("B")
	var result := _run(_place(6, 300, 1), plan, probe.d_finish + 40)
	_check(_started_via_link(result.frames, "5B"), "恢复后第 5 帧按 B 仍经 M 普通连接起手（无固定上限）")
	var hits := _find_events(result.events, CombatEvent.Type.HIT)
	_check(hits.size() == 4 and _event_of(hits[3]).combo_hits == 4, "稍晚 5B 为同连段第 4 击（HIT 共 %d）" % hits.size())


func _test_m_wait_walk_crouch_jump_preserve() -> void:
	# 走动 / 蹲下 / 实际跳跃（含落地恢复）期间 M 资格保留；随后按 B 连接。
	var modes := [
		{"name": "walk", "keys": "walk"},
		{"name": "crouch", "keys": "crouch"},
		{"name": "jump", "keys": "jump"},
	]
	for mode in modes:
		var probe := _probe(_entry_prefix(), 6, 300, 1)
		var plan := _entry_prefix()
		var finish: int = probe.d_finish
		if mode.keys == "walk":
			for frame in range(finish + 1, finish + 7):
				plan[frame] = _direction(1)
			plan[finish + 10] = _press("B")
		elif mode.keys == "crouch":
			for frame in range(finish + 1, finish + 5):
				plan[frame] = _direction(0, true)
			plan[finish + 8] = _press("B")
		else:
			plan[finish + 2] = _vertical_jump()
			plan[finish + 10] = _press("B")
		var result := _run(_place(6, 300, 1), plan, finish + 70)
		if mode.keys == "jump":
			## 整跳耗时超过目标剩余恢复（E42：跳/冲刺追击一例都没接上）——
			## 按状态断言资格跨 pre-jump/滞空保留，落地前后照常按自然截止清理。
			var wait_midair := false
			var wait_cleared := false
			for state in result.frames:
				if state.player.prejump_left > 0 or not state.player.on_ground:
					wait_midair = wait_midair or bool(state.player_move.link_wait)
				elif state.player_move.link_wait:
					wait_midair = true
			for state in result.frames:
				if not state.combo.active and state.player_move.link_wait:
					wait_cleared = true
			_check(wait_midair and not wait_cleared, "M 资格跨实际跳跃保留（pre-jump/滞空等待开放，连段结束即清理）")
		else:
			_check(_started_via_link(result.frames, "5B"), "M 资格跨%s保留，之后按 B 仍普通连接" % mode.name)


func _test_m_wait_undeclared_attack_clears() -> void:
	# 等待期间可执行的未声明攻击（5C）是独立新动作：清理 M 资格，不补入旧连段；
	# 旧连段最终按自然恢复结束。
	var probe := _probe(_entry_prefix(), 6, 300, 1)
	var plan := _entry_prefix()
	plan[probe.d_finish + 3] = _press("C")
	var result := _run(_place(6, 300, 1), plan, HORIZON)
	var started_5c := false
	for state in result.frames:
		if state.player_move.move_id == "5C":
			started_5c = true
			break
	_check(started_5c, "等待中的 5C 按独立新动作起手")
	_check(not _started_via_link(result.frames, "5C"), "5C 不经普通连接补入旧连段")
	var ended := _find_events(result.events, CombatEvent.Type.COMBO_ENDED)
	var old_combo_intact := true
	for entry in result.events:
		if _event_type(entry) == CombatEvent.Type.HIT and _event_of(entry).combo_hits > 3:
			old_combo_intact = false
	_check(old_combo_intact, "未声明攻击不并入旧连段（无第 4 击计入原连段）")
	_check(not ended.is_empty() and _event_of(ended[0]).combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED,
		"旧连段最终按自然恢复结束")


func _test_m_wait_early_expiry_and_recovery_close() -> void:
	# 命中当帧的过早 B 随缓存正常老化过期，不复活；无有效接续时连段按自然恢复
	# 结束；结束后的 B 是独立新连段首击。
	var probe := _probe(_entry_prefix(), 6, 300, 1)
	var plan := _entry_prefix()
	plan[probe.d_hit] = _press("B")
	var result := _run(_place(6, 300, 1), plan, HORIZON)
	_check(not _started_via_link(result.frames, "5B"), "命中当帧的过早 B 随缓存过期，不形成普通连接")
	var ended := _find_events(result.events, CombatEvent.Type.COMBO_ENDED)
	_check(not ended.is_empty() and _event_of(ended[0]).combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED,
		"无有效接续时连段按自然恢复结束（%s）" % str(_event_of(ended[0]).combo_end_reason if not ended.is_empty() else -1))
	var recovered_frame: int = ended[0].frame if not ended.is_empty() else -1
	# 结束后的 B 是独立新起手（新连段计数从 1 开始）。
	var plan2 := _entry_prefix()
	plan2[probe.d_hit] = _press("B")
	plan2[recovered_frame + 3] = _press("B")
	var second := _run(_place(6, 300, 1), plan2, HORIZON)
	var hits := _find_events(second.events, CombatEvent.Type.HIT)
	_check(hits.size() == 4 and _event_of(hits[3]).combo_hits == 1,
		"资格清理后的 B 为独立新连段首击（HIT %d，末击计数 %d）" % [hits.size(), _event_of(hits[3]).combo_hits if hits.size() >= 4 else -1])


# --- 5. 蓄力 D 身后停止 / 交界余量 / 墙分支 / 墙边分离（规则 3/4/5）---

func _charged_d_plan() -> Dictionary:
	var plan := {}
	plan[1] = _press("D")
	for frame in range(2, 19):
		plan[frame] = _hold("D")
	return plan


func _test_charge_stop_behind_target() -> void:
	# 板中接地目标：HIT 许可后本帧运动越过后方贴身停点时截在停点（身体边缘
	# 刚好分离），结束余下 active 并完整恢复；不追随。
	var result := _run(_place(6, 44, 1), _charged_d_plan(), 120)
	var session: CombatSession = result.session
	var swaps := _find_events(result.events, CombatEvent.Type.SWITCHED_SIDES)
	var hits := _find_events(result.events, CombatEvent.Type.HIT)
	_check(hits.size() == 1, "蓄力 D 单击命中（%d）" % hits.size())
	_check(swaps.size() == 1 and _event_of(swaps[0]).direction == -1, "身后停止产生恰一次换边且新面向背向原方向（%d 次）" % swaps.size())
	var dummy_x := session.dummy_position.x
	_check(_approx(session.player_position.x, dummy_x + GameParams.BODY_SIZE.x, 0.01),
		"停在目标身后身体边缘刚分离处（player=%.3f, dummy=%.3f）" % [session.player_position.x, dummy_x])
	# 停止帧之后玩家 x 不再变化（结束余下 active，不追随）。
	var stop_frame := -1
	var frozen := true
	var stop_x := 0.0
	for i in range(result.frames.size()):
		var state: Dictionary = result.frames[i]
		if state.player_move.move_id == "5[D]":
			if stop_frame < 0 and _approx(state.player.position.x, dummy_x + 12.0, 0.01):
				stop_frame = i + 1
				stop_x = state.player.position.x
			elif stop_frame >= 0 and not _approx(state.player.position.x, stop_x, 0.001):
				frozen = false
	_check(stop_frame > 0 and frozen, "停止后余下 active 不再位移（停止帧 F%d）" % stop_frame)
	var phase_after_stop: int = result.frames[stop_frame].player.phase if stop_frame < result.frames.size() else -1
	_check(phase_after_stop == CombatSession.PlayerPhase.RECOVERY, "停止后下一帧即进入完整恢复")
	var stop_finish: int = _d_finish_frame(result.frames)
	_check(stop_finish > 0, "身后停止后完整恢复（接地目标硬直在恢复帧前自然截止，M 由入口用例覆盖；恢复帧 F%d）" % stop_finish)


func _test_charge_stop_no_follow() -> void:
	# 停止只看停止当刻：之后 M 等待中按 B 命中把目标击退，玩家也不重启位移。
	var probe := _probe(_charged_d_plan(), 6, 44, 1, ["5[D]"], 120)
	var plan := _charged_d_plan()
	plan[probe.d_finish + 2] = _press("B")
	var result := _run(_place(6, 44, 1), plan, probe.d_finish + 30)
	var session: CombatSession = result.session
	_check(_find_events(result.events, CombatEvent.Type.HIT).size() == 2, "M 等待中的 5B 追加命中（%d）" % _find_events(result.events, CombatEvent.Type.HIT).size())
	var stop_x_at_finish: float = result.frames[probe.d_finish - 1].player.position.x
	_check(_approx(session.player_position.x, stop_x_at_finish, 0.01),
		"目标被后续命中移动后玩家不追随（stop=%.3f → %.3f）" % [stop_x_at_finish, session.player_position.x])


func _test_charge_stop_wall_branch() -> void:
	# 身后停点已在场外（目标贴墙）：沿用原墙分支——位移被墙截断且身体约束把
	# 玩家留在场内侧原侧，不换边。
	var result := _run(_place(6, 0, 1), _charged_d_plan(), 120)
	var session: CombatSession = result.session
	var swaps := _find_events(result.events, CombatEvent.Type.SWITCHED_SIDES)
	var hits := _find_events(result.events, CombatEvent.Type.HIT)
	_check(hits.size() == 1, "贴墙目标仍被蓄力 D 命中（%d）" % hits.size())
	_check(swaps.is_empty(), "场外停点沿原墙分支：零换边")
	_check(_approx(session.player_position.x, session.dummy_position.x - GameParams.BODY_SIZE.x, 0.01),
		"玩家留在场内侧贴身（player=%.3f, dummy=%.3f）" % [session.player_position.x, session.dummy_position.x])


func _test_y2_front_stop_margin() -> void:
	# HIT 许可后到达正面贴身时，身后停点在场内但距前进墙不足 2px：改在正面
	# 停止、终止余下运动/active 并完整恢复；零换边。
	var session := _place(6, 7, 1)
	var dummy_x := session.dummy_position.x
	var result := _run(session, _charged_d_plan(), 120)
	var swaps := _find_events(result.events, CombatEvent.Type.SWITCHED_SIDES)
	var hits := _find_events(result.events, CombatEvent.Type.HIT)
	_check(hits.size() == 1, "交界内侧仍命中（%d）" % hits.size())
	_check(swaps.is_empty(), "2px 余量内正面停止：零换边")
	_check(_approx(result.session.player_position.x, dummy_x - GameParams.BODY_SIZE.x, 0.01),
		"停在正面贴身位置（player=%.3f, 预期 %.3f）" % [result.session.player_position.x, dummy_x - GameParams.BODY_SIZE.x])
	var y2_finish: int = _d_finish_frame(result.frames)
	_check(y2_finish > 0, "正面停止后完整恢复（恢复帧 F%d）" % y2_finish)


func _test_x_in_field_separation() -> void:
	# 真实需要分离且原侧被墙钳制：玩家放到合法场内侧（不移动目标）；中场重合
	# 不启用场内侧改放（保持原方向推出）。
	var session := CombatSession.new()
	session.dummy_position = Vector2(930.0, GameParams.ground_stand_y())
	session.player_position = Vector2(930.0, GameParams.ground_stand_y())
	session.player_facing = 1
	session.step(_neutral())
	_check(_approx(session.player_position.x, 930.0 - GameParams.BODY_SIZE.x, 0.01),
		"墙钳制的重合分离把玩家放到合法场内侧（%.3f）" % session.player_position.x)
	_check(_approx(session.dummy_position.x, 930.0, 0.001), "分离不移动目标")
	var mid := CombatSession.new()
	mid.dummy_position = Vector2(480.0, GameParams.ground_stand_y())
	mid.player_position = Vector2(480.0, GameParams.ground_stand_y())
	mid.step(_neutral())
	_check(_approx(mid.player_position.x, 480.0 + GameParams.BODY_SIZE.x, 0.01),
		"中场重合不启用场内侧改放（保持原方向推出，%.3f）" % mid.player_position.x)

# --- 6. 四样本准确路线（R1/R2，父规格固定输入表）---

## 路线输入计划（物理帧，父规格 R1/R2 固定参考）：B 起手 5B F1/5C F16/
## 236C末键29/D60(保持18帧)/D后B90；C 为 5C F1/236C末键14/D44/B77；短后缀
## 214C末键/~C 101/124（B）、91/115（C）；长后缀 6D/jB/jC/j214D末键/弹地后B/
## 214C末键/~C 97/120/127/143/158/168/193（B）、92/110/121/137/153/167/190（C）。
## 236/214 末键前 3/2/1 帧依次下/下前(后)/前(后)，末键+攻击；长线 6D 相对初始
## 面向反向输入、第二次换边后指令按恢复面向；短线方向不变。全部为预先固定的
## 世界方向，左右镜像。
func _route_plan(kind: String, facing: int, long_suffix: bool, tweaks := {}) -> Dictionary:
	var plan := {}
	var back := -facing
	var f236 := 29 if kind == "B" else 14
	plan[f236 - 3] = _direction(0, true)
	plan[f236 - 2] = _direction(facing, true)
	plan[f236 - 1] = _direction(facing)
	plan[f236] = _press("C", facing)
	var f_d := 60 if kind == "B" else 44
	plan[f_d] = _press("D")
	var d_hold := int(tweaks.get("d_hold", 18))
	for f in range(f_d + 1, f_d + d_hold):
		plan[f] = _hold("D")
	if kind == "B":
		plan[1] = _press("B")
		plan[16] = _press("C")
	else:
		plan[1] = _press("C")
	var f_b := 90 if kind == "B" else 77
	plan[int(tweaks.get("b_after_d", f_b))] = _press("B")
	if long_suffix:
		var f6d := 97 if kind == "B" else 92
		plan[f6d] = _press("D", back)
		plan[f6d + 1] = _hold("D", back)
		if not tweaks.get("drop_jb", false):
			plan[120 if kind == "B" else 110] = _press("B")
		if not tweaks.get("drop_jc", false):
			plan[127 if kind == "B" else 121] = _press("C")
		var f214 := 143 if kind == "B" else 137
		plan[f214 - 3] = _direction(0, true)
		plan[f214 - 2] = _direction(back, true)
		plan[f214 - 1] = _direction(back)
		plan[f214] = _press("D", back)
		plan[158 if kind == "B" else 153] = _press("B")
		var f214c := 168 if kind == "B" else 167
		plan[f214c - 3] = _direction(0, true)
		plan[f214c - 2] = _direction(back, true)
		plan[f214c - 1] = _direction(back)
		plan[f214c] = _press("C", back)
		plan[193 if kind == "B" else 190] = _press("C")
	else:
		var f214c := 101 if kind == "B" else 91
		plan[f214c - 3] = _direction(0, true)
		plan[f214c - 2] = _direction(back, true)
		plan[f214c - 1] = _direction(back)
		plan[f214c] = _press("C", back)
		plan[124 if kind == "B" else 115] = _press("C")
	return plan


const ROUTE_HORIZON := 250


## 运行一条路线计划并汇总证据：首段连段结束前的逐击招式序、换边表、首次
## 实际普通倒地帧末位置与净推进。
func _run_route(kind: String, facing: int, long_suffix: bool, g: float, r: float, tweaks := {}, horizon := ROUTE_HORIZON) -> Dictionary:
	var session := _place(g, r, facing)
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var plan := _route_plan(kind, facing, long_suffix, tweaks)
	var hit_moves: Array[String] = []
	var swaps: Array[int] = []
	var end_frame := -1
	var end_reason := -1
	var hits_before_end := 0
	var knock_frame := -1
	var knock_dummy_x := 0.0
	for frame in range(1, horizon + 1):
		var before_move := session.player_move_id
		var input: FrameInput = plan.get(frame, _neutral())
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT and end_frame < 0:
				hit_moves.append(before_move)
				hits_before_end += 1
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swaps.append(event.direction)
			elif event.type == CombatEvent.Type.COMBO_ENDED and end_frame < 0:
				end_frame = frame
				end_reason = event.combo_end_reason
		if knock_frame < 0 and session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			knock_frame = frame
			knock_dummy_x = session.dummy_position.x
	var net := r - absf(knock_dummy_x - wall) if knock_frame > 0 else -1.0
	return {
		"session": session, "hit_moves": hit_moves, "swaps": swaps,
		"end_frame": end_frame, "end_reason": end_reason,
		"hits_before_end": hits_before_end, "knock_frame": knock_frame,
		"knock_dummy_x": knock_dummy_x, "wall": wall, "net": net,
	}


func _route_ok(kind: String, result: Dictionary, long_suffix: bool, r: float) -> bool:
	var want_hits := (13 if kind == "B" else 12) if long_suffix else (8 if kind == "B" else 7)
	var want_swaps := 2 if long_suffix else 0
	if result.hits_before_end != want_hits or result.swaps.size() != want_swaps:
		return false
	if result.knock_frame <= 0 or result.end_frame <= 0:
		return false
	if result.net < minf(450.0, r) - 0.01:
		return false
	if r < 450.0 and absf(result.knock_dummy_x - result.wall) > 0.01:
		return false
	var player_x: float = result.session.player_position.x
	if player_x < GameParams.stage_left_limit() - 0.01 or player_x > GameParams.stage_right_limit() + 0.01:
		return false
	return true


const ROUTE_SEQ_LONG_B := ["5B", "5C", "236C", "236C", "5[D]", "5B", "6D", "jB", "jC", "j214D", "5B", "214C", "214C~C"]
const ROUTE_SEQ_LONG_C := ["5C", "236C", "236C", "5[D]", "5B", "6D", "jB", "jC", "j214D", "5B", "214C", "214C~C"]
const ROUTE_SEQ_SHORT_B := ["5B", "5C", "236C", "236C", "5[D]", "5B", "214C", "214C~C"]
const ROUTE_SEQ_SHORT_C := ["5C", "236C", "236C", "5[D]", "5B", "214C", "214C~C"]


func _test_route_samples() -> void:
	# 长参照：目标初始中心 x264/x330 及镜像（r=666/600），g2/g10，双面向；
	# 短参照：r0/100/234/450，g2/g10，双面向。序列/击数/换边/倒地/净推进全查。
	for kind in ["B", "C"]:
		var seq_l = ROUTE_SEQ_LONG_B if kind == "B" else ROUTE_SEQ_LONG_C
		var seq_s = ROUTE_SEQ_SHORT_B if kind == "B" else ROUTE_SEQ_SHORT_C
		for facing in [1, -1]:
			for g in [2.0, 10.0]:
				for r in [600.0, 666.0]:
					var res := _run_route(kind, facing, true, g, r)
					_check(_route_ok(kind, res, true, r),
						"%s 长线 facing=%d g=%g r=%g：13/12 击、双换边、倒地与净推进（击 %d、换边 %d、净 %.1f）" % [kind, facing, g, r, res.hits_before_end, res.swaps.size(), res.net])
					_check(res.hit_moves == seq_l and res.swaps == ([-1, 1] if facing == 1 else [1, -1]),
						"%s 长线 facing=%d g=%g r=%g 准确序列与两种侧别（%s）" % [kind, facing, g, r, str(res.hit_moves)])
				for r in [0.0, 100.0, 234.0, 450.0]:
					var res := _run_route(kind, facing, false, g, r)
					_check(_route_ok(kind, res, false, r) and res.hit_moves == seq_s,
						"%s 短线 facing=%d g=%g r=%g：8/7 击、零换边、抵墙倒地（击 %d、净 %.1f）" % [kind, facing, g, r, res.hits_before_end, res.net])


func _test_route_junction() -> void:
	# 交界（采样结构 B≈495.5/C≈548.9，按实际几何逐 1px 验证）：两侧各恰一条
	# 正确分支，交界不得两者皆失败。
	for facing in [1, -1]:
		var b_short := _run_route("B", facing, false, 2.0, 495.0)
		var b_long := _run_route("B", facing, true, 2.0, 496.0)
		_check(_route_ok("B", b_short, false, 495.0) and not _route_ok("B", b_short, true, 495.0),
			"B 交界 facing=%d r=495 短分支恰一成立（击 %d/换边 %d）" % [facing, b_short.hits_before_end, b_short.swaps.size()])
		_check(_route_ok("B", b_long, true, 496.0) and not _route_ok("B", b_long, false, 496.0),
			"B 交界 facing=%d r=496 长分支恰一成立（击 %d/换边 %d）" % [facing, b_long.hits_before_end, b_long.swaps.size()])
		var c_short := _run_route("C", facing, false, 2.0, 548.0)
		var c_long := _run_route("C", facing, true, 2.0, 549.0)
		_check(_route_ok("C", c_short, false, 548.0) and not _route_ok("C", c_short, true, 548.0),
			"C 交界 facing=%d r=548 短分支恰一成立（击 %d/换边 %d）" % [facing, c_short.hits_before_end, c_short.swaps.size()])
		_check(_route_ok("C", c_long, true, 549.0) and not _route_ok("C", c_long, false, 549.0),
			"C 交界 facing=%d r=549 长分支恰一成立（击 %d/换边 %d）" % [facing, c_long.hits_before_end, c_long.swaps.size()])


func _test_route_domain_sweep() -> void:
	# 保证域有限扫描：g 全整数 0–18 × r 步长 10（0–700）双面向 B/C，每个起点
	# 长/短恰一条正确分支；交界带（B488–502、C542–556 逐 1px × g{0,9,18}）；
	# 非整数样点。如实记录步长，不称数学穷尽（D76 补验的采样部分）。
	var checked := 0
	var long_ok := 0
	var short_ok := 0
	var dual_fail_points: Array[String] = []
	var dual_ok_points: Array[String] = []
	for kind in ["B", "C"]:
		for facing in [1, -1]:
			for gi in range(19):
				var g := float(gi)
				for ri in range(0, 701, 10):
					var r := float(ri)
					var res_l := _run_route(kind, facing, true, g, r)
					var res_s := _run_route(kind, facing, false, g, r)
					var ok_l := _route_ok(kind, res_l, true, r)
					var ok_s := _route_ok(kind, res_s, false, r)
					checked += 1
					if ok_l:
						long_ok += 1
					if ok_s:
						short_ok += 1
					if not ok_l and not ok_s:
						dual_fail_points.append("%s/%d/g%g/r%g" % [kind, facing, g, r])
					elif ok_l and ok_s:
						dual_ok_points.append("%s/%d/g%g/r%g" % [kind, facing, g, r])
	_check(dual_fail_points.is_empty(), "整数网格无交界双失败（%d 点，首个失败：%s）" % [checked, dual_fail_points[0] if not dual_fail_points.is_empty() else "无"])
	_check(dual_ok_points.is_empty(), "整数网格长/短不并存成功（首个并存：%s）" % [dual_ok_points[0] if not dual_ok_points.is_empty() else "无"])
	var band_fail := ""
	for kind in ["B", "C"]:
		var bands := range(488, 503) if kind == "B" else range(542, 557)
		for facing in [1, -1]:
			for g in [0.0, 9.0, 18.0]:
				for ri in bands:
					var r := float(ri)
					var ok_l := _route_ok(kind, _run_route(kind, facing, true, g, r), true, r)
					var ok_s := _route_ok(kind, _run_route(kind, facing, false, g, r), false, r)
					if not (ok_l or ok_s) or (ok_l and ok_s):
						band_fail = "%s/%d/g%g/r%d" % [kind, facing, g, ri]
	_check(band_fail == "", "交界带逐 1px 各恰一分支（首个反例：%s）" % band_fail)
	var frac_fail := ""
	for kind in ["B", "C"]:
		for facing in [1, -1]:
			for g in [0.5, 9.37, 17.83]:
				for r in [0.3, 123.456, 450.02, 495.5, 548.9, 699.7]:
					var ok_l := _route_ok(kind, _run_route(kind, facing, true, g, r), true, r)
					var ok_s := _route_ok(kind, _run_route(kind, facing, false, g, r), false, r)
					if not (ok_l or ok_s) or (ok_l and ok_s):
						frac_fail = "%s/%d/g%g/r%g" % [kind, facing, g, r]
	_check(frac_fail == "", "非整数样点（g×r 18 组双面向）各恰一分支（首个反例：%s）" % frac_fail)
	print("  域扫描覆盖：整数网格 %d 起点（长 %d / 短 %d）+ 交界带 900 点 + 非整数 72 点；步长 g=1px、r=10px，有限采样非连续穷尽" % [checked, long_ok, short_ok])


func _test_route_negatives() -> void:
	# 错分支：短区（r=100）强行输入长后缀——诚实失败，不产生准确样本。
	var wrong := _run_route("B", 1, true, 2.0, 100.0)
	_check(not _route_ok("B", wrong, true, 100.0), "短区强行长后缀不成立（击 %d/换边 %d/倒地帧 %d）" % [wrong.hits_before_end, wrong.swaps.size(), wrong.knock_frame])
	var wrong2 := _run_route("B", 1, false, 2.0, 600.0)
	_check(not _route_ok("B", wrong2, false, 600.0), "长区强行短后缀不成立（击 %d/换边 %d）" % [wrong2.hits_before_end, wrong2.swaps.size()])
	# D 按得不足出普通版（蓄力阈值 8 帧内松开）：序列中 5D 取代 5[D]，样本失败。
	var weak := _run_route("B", 1, true, 2.0, 666.0, {"d_hold": 4})
	_check(not weak.hit_moves.has("5[D]") and not _route_ok("B", weak, true, 666.0),
		"早松 D 提交普通 5D，不构成蓄力样本（序列 %s）" % str(weak.hit_moves))
	# 删 jC：空中链缺一击，样本失败。
	var no_jc := _run_route("B", 1, true, 2.0, 666.0, {"drop_jc": true})
	_check(not _route_ok("B", no_jc, true, 666.0), "删 jC 的长线不成立（击 %d）" % no_jc.hits_before_end)
	# 删 jB：同上。
	var no_jb := _run_route("B", 1, true, 2.0, 666.0, {"drop_jb": true})
	_check(not _route_ok("B", no_jb, true, 666.0), "删 jB 的长线不成立（击 %d）" % no_jb.hits_before_end)
	# 缺 236C 第二段：D 在第一段判定后、第二段判定前消费（特殊进入窗口内），
	# 236C 只有一击，样本失败（保留为诊断对照，不升级必保）。
	var one_seg_plan := _route_plan("B", 1, true)
	one_seg_plan.erase(60)
	one_seg_plan.erase(61)
	one_seg_plan[38] = _press("D")
	for f in range(39, 56):
		one_seg_plan[f] = _hold("D")
	var one_seg_session := _place(2.0, 666.0, 1)
	var one_seg_hits: Array[String] = []
	var one_seg_ended := false
	for frame in range(1, ROUTE_HORIZON + 1):
		var before_move := one_seg_session.player_move_id
		for event in one_seg_session.step(one_seg_plan.get(frame, _neutral())):
			if event.type == CombatEvent.Type.HIT and not one_seg_ended:
				one_seg_hits.append(before_move)
			elif event.type == CombatEvent.Type.COMBO_ENDED:
				one_seg_ended = true
	_check(one_seg_hits.count("236C") == 1 and not (one_seg_hits == ROUTE_SEQ_LONG_B),
		"缺第二段的 236C 单击诊断对照保留（236C 击数 %d）" % one_seg_hits.count("236C"))
	# 只完成 D 或 B 后停止：无规定 ~C 倒地。
	var d_only_plan := _route_plan("B", 1, false, {})
	for f in [101, 100, 99, 98, 124, 123, 122, 121, 120, 119, 118, 117, 116, 115, 114, 90]:
		d_only_plan.erase(f)
	var d_only := _run_route("B", 1, false, 2.0, 100.0)
	# 重新构造：只保留前缀到 5B。
	var prefix_only := _route_plan("B", 1, false)
	for f in prefix_only.keys():
		if f >= 101:
			prefix_only.erase(f)
	var po_session := _place(2.0, 100.0, 1)
	var po_knock := false
	for frame in range(1, ROUTE_HORIZON + 1):
		po_session.step(prefix_only.get(frame, _neutral()))
		if po_session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			po_knock = true
	_check(not po_knock, "只完成前缀（无 214C~C）不产生规定倒地")
	# 恢复前请求：D 命中当帧立即按 B（过期，单元已证）；路线级过晚 B——
	# 目标恢复后按 B 是独立新起手，不并入旧连段。
	var late_b := _run_route("B", 1, false, 2.0, 100.0, {"b_after_d": 130})
	_check(not _route_ok("B", late_b, false, 100.0), "过晚 B（F130）不构成同连段样本（击 %d/换边 %d）" % [late_b.hits_before_end, late_b.swaps.size()])
	# 额外插入收尾前 5C：短样本序列被破坏。
	var extra_c_plan := _route_plan("B", 1, false)
	extra_c_plan[95] = _press("C")
	var extra_session := _place(2.0, 100.0, 1)
	var extra_hits: Array[String] = []
	var extra_ended := false
	for frame in range(1, ROUTE_HORIZON + 1):
		var before_move := extra_session.player_move_id
		for event in extra_session.step(extra_c_plan.get(frame, _neutral())):
			if event.type == CombatEvent.Type.HIT and not extra_ended:
				extra_hits.append(before_move)
			elif event.type == CombatEvent.Type.COMBO_ENDED:
				extra_ended = true
	_check(extra_hits != ROUTE_SEQ_SHORT_B, "收尾前额外 5C 破坏准确样本（序列 %s）" % str(extra_hits))


func _test_route_save_restore() -> void:
	# R1-B 代表点，逐切点保存恢复与不中断回放逐事件等价：停止前后、M 等待中、
	# Hitstop、弹地等待、落地前后、消费当帧。
	var facing := 1
	var g := 2.0
	var r := 666.0
	var plan := _route_plan("B", facing, true)
	var baseline_session := _place(g, r, facing)
	var baseline_events: Array = []
	for frame in range(1, ROUTE_HORIZON + 1):
		for event in baseline_session.step(plan.get(frame, _neutral())):
			baseline_events.append([frame, event.type, event.combo_hits, event.direction, event.combo_end_reason, event.link_fail_reason, event.damage])
	var cuts := [55, 74, 76, 90, 100, 120, 130, 150, 160, 166, 175, 195, 210]
	var mismatch := ""
	for cut in cuts:
		var session := _place(g, r, facing)
		var events: Array = []
		for frame in range(1, cut):
			for event in session.step(plan.get(frame, _neutral())):
				events.append([frame, event.type, event.combo_hits, event.direction, event.combo_end_reason, event.link_fail_reason, event.damage])
		var state := session.clone_state()
		var restored := CombatSession.new()
		if not restored.restore_state(state):
			mismatch = "cut %d restore_state 拒绝" % cut
			break
		for frame in range(cut, ROUTE_HORIZON + 1):
			for event in restored.step(plan.get(frame, _neutral())):
				events.append([frame, event.type, event.combo_hits, event.direction, event.combo_end_reason, event.link_fail_reason, event.damage])
		if events != baseline_events or not _approx(restored.player_position.x, baseline_session.player_position.x, 0.001) or not _approx(restored.dummy_position.x, baseline_session.dummy_position.x, 0.001):
			mismatch = "cut %d 事件流/终态不等价" % cut
			break
	_check(mismatch == "", "R1-B 逐切点保存续跑与不中断回放逐事件等价（%s）" % mismatch)


func _test_route_windows() -> void:
	# 关键键连续成功区间（其余输入固定，±5F 扫描；D72 只记录不设门槛）与
	# 64 向量联合 ±1 扰动记录。B 长线代表点。
	var facing := 1
	var g := 2.0
	var r := 666.0
	var keys := {"236C": 29, "5B_after_D": 90, "6D": 97, "jC": 127, "j214D": 143, "pursuit_5B": 158, "214C": 168, "tildeC": 193}
	for key in keys:
		var base_frame: int = keys[key]
		var window: Array[int] = []
		for delta in range(-5, 6):
			var tweaks := {}
			match key:
				"236C":
					tweaks = {"shift_236": delta}
				"5B_after_D":
					tweaks = {"b_after_d": base_frame + delta}
				"6D":
					tweaks = {"shift_6d": delta}
				"jC":
					tweaks = {"shift_jc": delta}
				"j214D":
					tweaks = {"shift_j214d": delta}
				"pursuit_5B":
					tweaks = {"shift_pursuit": delta}
				"214C":
					tweaks = {"shift_214c": delta}
				_:
					tweaks = {"shift_tc": delta}
			var plan := _route_plan_shifted("B", facing, true, tweaks)
			var res := _run_route_plan(plan, facing, g, r)
			if _route_ok("B", res, true, r):
				window.append(delta)
		if window.is_empty():
			_check(false, "关键键 %s 在 ±5F 内存在成功帧（基线本身应成功）" % key)
		else:
			var contiguous := true
			for i in range(1, window.size()):
				if window[i] != window[i - 1] + 1:
					contiguous = false
			_check(contiguous, "关键键 %s 成功偏移为连续区间（%s）" % [key, str(window)])
			print("  窗口记录 %s: [%d, %d]（其余输入固定，±5F 扫描）" % [key, window[0], window[window.size() - 1]])
	# 联合扰动：六键（236C/D后B/6D/jC/j214D/214C）各 ±1 的 64 向量。
	var joint_pass := 0
	var joint_total := 0
	for mask in range(64):
		var tweaks := {
			"shift_236": 1 if (mask & 1) else -1,
			"b_after_d": 91 if (mask & 2) else 89,
			"shift_6d": 1 if (mask & 4) else -1,
			"shift_jc": 1 if (mask & 8) else -1,
			"shift_j214d": 1 if (mask & 16) else -1,
			"shift_214c": 1 if (mask & 32) else -1,
		}
		var plan := _route_plan_shifted("B", facing, true, tweaks)
		var res := _run_route_plan(plan, facing, g, r)
		joint_total += 1
		if _route_ok("B", res, true, r):
			joint_pass += 1
	print("  联合扰动记录：64 向量 ±1 成功 %d/64（难度资料，不作准入门槛）" % joint_pass)
	_check(joint_total == 64, "联合扰动计划/分母完整（64 向量全部运行）")


## 带平移的路线计划：shift_* 把对应键及其方向三帧整体平移。
func _route_plan_shifted(kind: String, facing: int, long_suffix: bool, tweaks: Dictionary) -> Dictionary:
	var plan := _route_plan(kind, facing, long_suffix)
	var back := -facing
	var shifts := [
		["shift_236", 29 if kind == "B" else 14, "236"],
		["shift_6d", 97 if kind == "B" else 92, "6d"],
		["shift_jc", 127 if kind == "B" else 121, "plain"],
		["shift_j214d", 143 if kind == "B" else 137, "214"],
		["shift_pursuit", 158 if kind == "B" else 153, "plain"],
		["shift_214c", 168 if kind == "B" else 167, "214"],
		["shift_tc", 193 if kind == "B" else 190, "plain"],
	]
	for entry in shifts:
		var key: String = entry[0]
		var base: int = entry[1]
		var mode: String = entry[2]
		if not tweaks.has(key):
			continue
		var delta := int(tweaks[key])
		var frames_to_move: Array = []
		match mode:
			"236":
				frames_to_move = [base - 3, base - 2, base - 1, base]
			"214":
				frames_to_move = [base - 3, base - 2, base - 1, base]
			"6d":
				frames_to_move = [base, base + 1]
			_:
				frames_to_move = [base]
		var carried := {}
		for f in frames_to_move:
			if plan.has(f):
				carried[f] = plan[f]
				plan.erase(f)
		for f in carried.keys():
			plan[int(f) + delta] = carried[f]
	return plan


func _run_route_plan(plan: Dictionary, facing: int, g: float, r: float, horizon := ROUTE_HORIZON) -> Dictionary:
	var session := _place(g, r, facing)
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var hit_moves: Array[String] = []
	var swaps: Array[int] = []
	var end_frame := -1
	var end_reason := -1
	var hits_before_end := 0
	var knock_frame := -1
	var knock_dummy_x := 0.0
	for frame in range(1, horizon + 1):
		var before_move := session.player_move_id
		for event in session.step(plan.get(frame, _neutral())):
			if event.type == CombatEvent.Type.HIT and end_frame < 0:
				hit_moves.append(before_move)
				hits_before_end += 1
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swaps.append(event.direction)
			elif event.type == CombatEvent.Type.COMBO_ENDED and end_frame < 0:
				end_frame = frame
				end_reason = event.combo_end_reason
		if knock_frame < 0 and session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			knock_frame = frame
			knock_dummy_x = session.dummy_position.x
	var net := r - absf(knock_dummy_x - wall) if knock_frame > 0 else -1.0
	return {
		"session": session, "hit_moves": hit_moves, "swaps": swaps,
		"end_frame": end_frame, "end_reason": end_reason,
		"hits_before_end": hits_before_end, "knock_frame": knock_frame,
		"knock_dummy_x": knock_dummy_x, "wall": wall, "net": net,
	}
