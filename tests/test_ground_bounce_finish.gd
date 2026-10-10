extends SceneTree
## 连段路线票据 01：6A 对地起手经弹地追击完成六击倒地（R4-G）。
## 覆盖父规格 R4-G 与本票共用行为：12×20 身体尺度、D74 时序选值
## （jC 4 / j214D 1、j214D 触地前 32/32、5B 弹地 19/25）、动作键 D 招式
## 实际接地零水平矩阵、取消一次弹地继续上限与 A 起手强制终点（自然接续、
## 可再次弹地、修正不重置）、准确六击参考路线、保证域有限扫描（整数 g 全量
## + r 分层 + 非整数样点，如实记录步长、不称数学穷尽）、关键键连续成功区间
## 与联合扰动记录、以及相关负例。运行：
##   godot --headless --path . -s res://tests/test_ground_bounce_finish.gd
## 窗口/联合/扫描结果按 D72 只记录不设旧 7F/244 门槛。

const ENGINE_LOG_PREFIX := "R4G"

## R4-G 固定参考（物理帧 F，E44/D80 已选 G 节奏）：6A F1–2、8 跳消 F11、
## jC F34、j214D 末键 F47（前 3/2/1 帧依次下/下后/后）、5B F78、214C 末键
## F90（前 3/2/1 帧同序）、~C F114。未列帧中立；单键 1F 后松开；左右镜像。
const F_SIX_A := 1
const F_JC_CANCEL := 11
const F_JC := 34
const F_J214D := 47
const F_FIVE_B := 78
const F_214C := 90
const F_TILDE_C := 114
const HORIZON := 160

var _failures := 0


func _initialize() -> void:
	_test_shared_body_scale()
	_test_d_grounded_zero_matrix()
	_test_d_zero_exceptions()
	_test_forced_bounce_end_removed()
	_test_rebounce_natural_continuation()
	_test_r4g_reference_route(1)
	_test_r4g_reference_route(-1)
	_test_r4g_domain_sweep()
	_test_r4g_key_windows()
	_test_r4g_joint_perturbation()
	_test_r4g_negatives()
	print("")
	if _failures == 0:
		print("ALL GROUND BOUNCE FINISH TESTS PASSED")
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


# --- 布置：g 为双方身体横向边缘间距，r 为目标身体边缘到其身后指定墙的距离 ---

func _place(g: float, r: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dummy_x := wall - r * facing
	var player_x := dummy_x - facing * (GameParams.BODY_SIZE.x + g)
	session.player_position = Vector2(player_x, GameParams.ground_stand_y())
	session.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y())
	session.player_facing = facing
	return session


# --- 输入构造（世界轴，由 facing 镜像）---

func _key(key: String, axis := 0, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	input.move_axis = axis
	input.down_held = down
	return input


func _vertical_jump() -> FrameInput:
	var input := FrameInput.new()
	input.jump_pressed = true
	input.up_held = true
	return input


## R4-G 参考计划；offsets 对六个关键键施加帧偏移（正=延后），214 的方向三帧
## 随各自末键平移，方向本身保持相对初始面向的镜像世界方向。
func _r4g_plan(facing: int, offsets := {}) -> Dictionary:
	var d_jc := int(offsets.get("jc", 0))
	var d_c := int(offsets.get("jC", 0))
	var d_d := int(offsets.get("j214D", 0))
	var d_b := int(offsets.get("5B", 0))
	var d_k := int(offsets.get("214C", 0))
	var d_t := int(offsets.get("~C", 0))
	var back := -facing
	var plan := {}
	# 6A F1–2：前方向按住两帧，A 于首帧按下。
	plan[F_SIX_A] = _key("A", facing)
	var hold_a := FrameInput.new()
	hold_a.move_axis = facing
	plan[F_SIX_A + 1] = hold_a
	# 8 跳消。
	plan[F_JC_CANCEL + d_jc] = _vertical_jump()
	# jC。
	plan[F_JC + d_c] = _key("C")
	# j214D：下 / 下后 / 后 / 后+D。
	plan[F_J214D - 3 + d_d] = FrameInput.make(0, false, "", true)
	plan[F_J214D - 2 + d_d] = FrameInput.make(back, false, "", true)
	plan[F_J214D - 1 + d_d] = FrameInput.make(back)
	plan[F_J214D + d_d] = _key("D", back)
	# 弹地追击 5B。
	plan[F_FIVE_B + d_b] = _key("B")
	# 214C：下 / 下后 / 后 / 后+C。
	plan[F_214C - 3 + d_k] = FrameInput.make(0, false, "", true)
	plan[F_214C - 2 + d_k] = FrameInput.make(back, false, "", true)
	plan[F_214C - 1 + d_k] = FrameInput.make(back)
	plan[F_214C + d_k] = _key("C", back)
	# ~C 派生。
	plan[F_TILDE_C + d_t] = _key("C")
	return plan


## 运行一条固定计划并收集证据：首连段逐 HIT 投影、结束后命中、结束原因、
## 弹地触点、换边计数与首次实际普通倒地帧（~C 向下击落触地转普通倒地；空中
## 末击先 FINISHER 结束、再自然落地成主终点——同帧 HIT→END 保留末击的既定口径）。
func _run(plan: Dictionary, session: CombatSession, horizon := HORIZON, verbose := false) -> Dictionary:
	var evidence := preload("res://tests/replay_combo_evidence.gd").new()
	var bounce_contacts: Array[int] = []
	var swaps := 0
	var knockdown_frame := -1
	var knockdown_state_ok := false
	var first_miss: Dictionary = {}
	for frame in range(1, horizon + 1):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		var events := session.step(input)
		for order in events.size():
			var event: CombatEvent = events[order]
			evidence.record(frame, order, move_at_start, order, event)
			if verbose:
				_log_event(frame, event, session, move_at_start)
			match event.type:
				CombatEvent.Type.BOUNCE_CONTACT:
					bounce_contacts.append(frame)
				CombatEvent.Type.SWITCHED_SIDES:
					swaps += 1
				CombatEvent.Type.HIT_MISS:
					if first_miss.is_empty():
						first_miss = {"frame": frame, "move": move_at_start}
				CombatEvent.Type.SPIKE_LANDED:
					if knockdown_frame < 0:
						knockdown_frame = frame
						knockdown_state_ok = session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
				CombatEvent.Type.COMBO_ENDED:
					if event.combo_end_reason == CombatEvent.ComboEndReason.KNOCKDOWN and knockdown_frame < 0:
						knockdown_frame = frame
						knockdown_state_ok = session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
	return {
		"session": session, "moves": evidence.moves, "move_sequence": evidence.move_sequence,
		"hits": evidence.hits, "hits_after_end": evidence.hits_after_end, "ends": evidence.ends,
		"bounce_contacts": bounce_contacts, "swaps": swaps,
		"knockdown_frame": knockdown_frame, "knockdown_state_ok": knockdown_state_ok,
		"first_miss": first_miss,
	}


func _log_event(frame: int, event: CombatEvent, session: CombatSession, move_id: String) -> void:
	match event.type:
		CombatEvent.Type.HIT:
			print("    F%-3d HIT %s seg%d 第%d击 | 修正 时%.3f 轨%.3f | 玩家x=%.2f 木桩x=%.2f y=%.2f vx=%+.0f" % [
				frame, move_id, event.move_segment, event.combo_hits,
				session.combo_time_scale, session.combo_trajectory_scale,
				session.player_position.x, session.dummy_position.x, session.dummy_position.y,
				session.dummy_velocity.x])
		CombatEvent.Type.COMBO_ENDED:
			print("    F%-3d COMBO_ENDED %s" % [frame, CombatEvent.ComboEndReason.keys()[event.combo_end_reason]])
		CombatEvent.Type.BOUNCE_CONTACT:
			print("    F%-3d BOUNCE_CONTACT 窗%d" % [frame, session.dummy_bounce_left])
		CombatEvent.Type.HIT_MISS:
			print("    F%-3d HIT_MISS %s" % [frame, move_id])
		CombatEvent.Type.LINK_FAILED:
			print("    F%-3d LINK_FAILED %s %s" % [frame, CombatEvent.LinkFailReason.keys()[event.link_fail_reason], event.link_move_id])


const R4G_MOVES := ["6A", "jC", "j214D", "5B", "214C", "214C~C"]


# --- 尺度 ---

func _test_shared_body_scale() -> void:
	print("=== 尺度：12×20 身体与呈现 ===")
	_check(GameParams.BODY_SIZE == Vector2(12.0, 20.0),
		"scale: BODY_SIZE is 12×20 (D74 shared body)")
	_check(GameParams.HEAD_SIZE == Vector2(9.0, 6.0) and is_equal_approx(GameParams.HEAD_GAP, 0.5)
		and GameParams.VISOR_SIZE == Vector2(2.5, 1.5) and is_equal_approx(GameParams.VISOR_OFFSET_X, 2.5),
		"scale: head/visor appearance follows the same quarter proportion")
	_check(is_equal_approx(GameParams.stage_left_limit(), 30.0) and is_equal_approx(GameParams.stage_right_limit(), 930.0),
		"scale: legal center wall limits are 30/930 (wall 24 + half body 6)")
	_check(is_equal_approx(GameParams.ground_stand_y(), 470.0),
		"scale: ground stand y is 480 - 10")
	var session := _place(2.0, 350.0, 1)
	var player_body := Rect2(session.player_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
	var dummy_body := Rect2(session.dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
	_check(player_body.size == Vector2(12.0, 20.0) and dummy_body.size == Vector2(12.0, 20.0),
		"scale: session body/hurt rects are 12×20 for both fighters")


# --- 动作键 D 招式实际接地零水平矩阵 ---

func _hit_grounded_and_get_vx(move_plan: Dictionary, dx: float, facing := 1, guard := 0) -> Dictionary:
	## 通用：按计划起手一招 D 系并对地面中立木桩命中，返回命中帧后木桩速度与状态。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(dx * facing, 0)
	session.player_facing = facing
	var hit_vx := 0.0
	var hit_vy := 0.0
	var hit_state := -1
	var hit_timer := -1
	var blocked := false
	for frame in range(1, 80):
		var input: FrameInput = move_plan[frame] if move_plan.has(frame) else FrameInput.new()
		if guard != 0:
			input.dummy_guard_request = guard
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				hit_vx = session.dummy_velocity.x
				hit_vy = session.dummy_velocity.y
				hit_state = session.dummy_state
				hit_timer = session.dummy_hitstun_left
			elif event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = true
	return {"vx": hit_vx, "vy": hit_vy, "state": hit_state, "timer": hit_timer,
		"blocked": blocked, "session": session}


func _hold_only_d(frame: int) -> FrameInput:
	## 按住 D 的单帧输入（第 frame 帧为新按下）。
	var input := FrameInput.new()
	input.held_action_keys = ["D"]
	if frame == 1:
		input.pressed_action_keys = ["D"]
	return input


func _d_move_hit_row(tag: String, plan: Dictionary, dx: float, expect_reaction_state: int) -> void:
	var out := _hit_grounded_and_get_vx(plan, dx)
	if out["blocked"] or out["state"] == -1:
		_check(false, "%s: grounded hit lands (blocked=%s state=%d)" % [tag, str(out["blocked"]), int(out["state"])])
		return
	_check(is_equal_approx(float(out["vx"]), 0.0),
		"%s: grounded normal HIT zeroes horizontal velocity (vx=%+.1f, overrides inertia)" % [tag, float(out["vx"])])
	_check(int(out["state"]) == expect_reaction_state,
		"%s: reaction/timer state preserved (%d)" % [tag, int(out["state"])])


func _test_d_grounded_zero_matrix() -> void:
	print("=== 全 D 接地矩阵：normal/counter × 接地/离地（含 slide/bounce 入口）===")
	## 地面 D 系对地面目标：5D / 5[D]（grounded 资料）。
	_d_move_hit_row("5D grounded", {1: _key("D")}, 40.0, CombatSession.DummyState.GROUND_HITSTUN)
	var charge := {}
	for frame in range(1, 17):
		charge[frame] = _hold_only_d(frame)
	_d_move_hit_row("5[D] grounded (charge commit)", charge, 40.0, CombatSession.DummyState.GROUND_HITSTUN)
	## 空中 D 系对地面目标：j2D grounded 资料、j214D 接地弹地入口。
	## j5D/j6D 虽声明 grounded 资料，普通跳跃探针下无可达的接地接触（按帧扫描
	## F14–F26 全部无接触；判框随空中高度不重叠）——如实记为覆盖缺口，不伪造
	## 接地命中；零水平规则按 action_key 判定，已落地的接地行足以覆盖行为。
	var air_common := func(start: int, key_input: FrameInput) -> Dictionary:
		var plan := {start: _vertical_jump()}
		plan[start + 14] = key_input
		return plan
	_d_move_hit_row("j2D grounded", air_common.call(2, _key("D", 0, true)), 30.0, CombatSession.DummyState.GROUND_HITSTUN)
	## j214D 接地命中：零水平 + 保留进入上弹（GROUND_BOUNCE、vy<0）。
	var j214d_plan := {2: _vertical_jump()}
	j214d_plan[13] = FrameInput.make(0, false, "", true)
	j214d_plan[14] = FrameInput.make(-1, false, "", true)
	j214d_plan[15] = FrameInput.make(-1)
	j214d_plan[16] = _key("D", -1)
	var out := _hit_grounded_and_get_vx(j214d_plan, 40.0)
	_check(not out["blocked"] and int(out["state"]) == CombatSession.DummyState.GROUND_BOUNCE,
		"j214D grounded: bounce entry preserved (state GROUND_BOUNCE)")
	if int(out["state"]) == CombatSession.DummyState.GROUND_BOUNCE:
		_check(is_equal_approx(float(out["vx"]), 0.0) and float(out["vy"]) < 0.0,
			"j214D grounded: horizontal zeroed, upward pop velocity preserved (vx=%+.1f vy=%+.1f)" % [float(out["vx"]), float(out["vy"])])
	## counter 上下文：木桩 startup 窗口内命中的 5D 同样零水平（规则按
	## action_key×实际接地判定，不按命中上下文分支——counter 与 normal 共用
	## 同一结算路径）。探针经帧扫描校准：请求 F3 使 5A startup 与 5D active 重叠。
	var counter := {1: _key("D")}
	counter[3] = FrameInput.new()
	counter[3].dummy_move_request = "5A"
	var counter_out := _hit_grounded_and_get_vx(counter, 40.0)
	_check(not counter_out["blocked"] and int(counter_out["state"]) != -1 and is_equal_approx(float(counter_out["vx"]), 0.0),
		"5D hit on the dummy's startup also zeroes horizontal (counter context, vx=%+.1f)" % float(counter_out["vx"]))
	## slide 目标（实际接地）：236C 段1挥空>段2滑行（dx60：段1边缘触及外、
	## 段2触及内），5D 以 slide 资料捞起。
	var slide := CombatSession.new()
	slide.dummy_position = slide.player_position + Vector2(60.0, 0)
	var slide_vx := 0.0
	var slide_hit := false
	var slide_plan := {
		1: FrameInput.make(0, false, "", true), 2: FrameInput.make(1, false, "", true),
		3: FrameInput.make(1), 4: _key("C", 1),
		36: _key("D"),
	}
	for frame in range(1, 90):
		var input: FrameInput = slide_plan[frame] if slide_plan.has(frame) else FrameInput.new()
		var move_at_start := slide.player_move_id
		for event in slide.step(input):
			if event.type == CombatEvent.Type.HIT and move_at_start == "5D":
				slide_hit = true
				slide_vx = slide.dummy_velocity.x
	_check(slide_hit and is_equal_approx(slide_vx, 0.0),
		"5D slide pickup on a grounded sliding target zeroes horizontal (vx=%+.1f)" % slide_vx)
	## 离地目标不受零水平规则：R4-G 前缀（6A>jc.jC>j214D）中 j214D 对空命中
	## （h40）保留水平速度——同一物理帧读回木桩受击 vx 非零。
	var air_case := _place(2.0, 350.0, 1)
	var air_vx := 0.0
	var air_hit := false
	var prefix := _r4g_plan(1)
	for frame in range(1, 60):
		var input: FrameInput = prefix[frame] if prefix.has(frame) else FrameInput.new()
		var move_at_start := air_case.player_move_id
		for event in air_case.step(input):
			if event.type == CombatEvent.Type.HIT and move_at_start == "j214D":
				air_hit = true
				air_vx = air_case.dummy_velocity.x
	_check(air_hit and absf(air_vx) > 1.0,
		"j214D airborne HIT keeps its declared horizontal velocity (vx=%+.1f, rule is grounded-only)" % air_vx)


func _test_d_zero_exceptions() -> void:
	print("=== 全 D 零水平例外面 ===")
	## 6D/2D 无 grounded 资料：对地 HIT_MISS（零水平规则不给新命中能力）。
	var six_d := CombatSession.new()
	six_d.dummy_position = six_d.player_position + Vector2(40.0, 0)
	var six_d_miss := false
	for frame in range(1, 60):
		var input := _key("D", 1) if frame == 1 else FrameInput.new()
		for event in six_d.step(input):
			if event.type == CombatEvent.Type.HIT_MISS:
				six_d_miss = true
	_check(six_d_miss and not six_d.combo_active,
		"6D grounded target stays MISS_NO_PROFILE (no new capability from the zero rule)")
	## 被防不适用：站防挡下 5D，被防推退照常（非零）。
	var blocked := _hit_grounded_and_get_vx({1: _key("D")}, 40.0, 1, CombatSession.GuardPosture.STANDING)
	_check(bool(blocked["blocked"]),
		"5D into standing guard is a blocked contact (zero rule is HIT-only)")
	var pushback_seen := false
	var guard_session := CombatSession.new()
	guard_session.dummy_position = guard_session.player_position + Vector2(40.0, 0)
	var vx_after_blockstop := 0.0
	var blockstop_left := -1
	for frame in range(1, 40):
		var input := _key("D") if frame == 1 else FrameInput.new()
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in guard_session.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				pushback_seen = true
		if pushback_seen and blockstop_left < 0:
			blockstop_left = frame
		if blockstop_left >= 0 and frame == blockstop_left + 8:
			vx_after_blockstop = guard_session.dummy_velocity.x
	_check(pushback_seen and absf(vx_after_blockstop) > 1.0,
		"blocked D keeps its declared pushback after the blockstop (vx=%+.1f)" % vx_after_blockstop)
	## 普通倒地不可追击保持：~C 击倒后 D 招不获得命中（倒地不可命中既有门）。
	var knockdown := CombatSession.new()
	knockdown.dummy_position = knockdown.player_position + Vector2(36.0, 0)
	var kd := false
	var post_kd_hit := false
	for frame in range(1, 130):
		var input := FrameInput.new()
		match frame:
			1:
				input = _key("C", 0, true)
			9:
				input = FrameInput.make(0, false, "", true)
			10:
				input = FrameInput.make(-1, false, "", true)
			11:
				input = FrameInput.make(-1)
			12:
				input = _key("C", -1)
			34:
				input = _key("C")
			62:
				input = _key("D")
		for event in knockdown.step(input):
			if event.type == CombatEvent.Type.SPIKE_LANDED:
				kd = true
			elif event.type == CombatEvent.Type.HIT and frame >= 62:
				post_kd_hit = true
	_check(kd and not post_kd_hit,
		"after the ~C knockdown (spike lands) a D press inside the knockdown gains no hit (OTG gate unchanged)")


# --- 取消一次弹地继续上限 / A 起手强制终点 ---

func _a_route_plan(b_frame: int, facing := 1) -> Dictionary:
	## A 起手 juggle 至 j214D 弹地，弹地窗口内按 5B：旧行为是命中即 BOUNCE_END
	## （A 起手资格 0），新行为是自然接续——资格/次数不再由起手等级决定。
	## 帧号经真实回放校准（12×20 尺度 + jC 4 / j214D 1 选值）；5B 的弹地目押窗
	## 为 1F（D72 允许），按 F99 与触地 F100 的配对等待/缓存年龄共同决定。
	var back := -facing
	return {
		1: _key("A"), 9: _key("B"),
		24: _key("A", facing), 25: FrameInput.make(facing),
		48: _vertical_jump(),
		58: _key("C"),
		71: FrameInput.make(0, false, "", true), 72: FrameInput.make(back, false, "", true),
		73: FrameInput.make(back), 74: _key("D", back),
		b_frame: _key("B"),
	}


func _test_forced_bounce_end_removed() -> void:
	print("=== 取消 BOUNCE_END：A 起手弹地命中自然接续 ===")
	_check(CombatEvent.ComboEndReason.keys().find("BOUNCE_END") == -1,
		"BOUNCE_END is no longer a combo end reason (cap removed with the rule)")
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(26.0, 0)
	var plan := _a_route_plan(99, 1)
	var b_hit_frame := -1
	var end_at_b_hit := -1
	var recovered_end_frame := -1
	var moves: Array[String] = []
	for frame in range(1, 200):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				moves.append(move_at_start)
				if int(event.combo_hits) == 6:
					b_hit_frame = frame
			elif event.type == CombatEvent.Type.COMBO_ENDED and b_hit_frame > 0 and end_at_b_hit < 0:
				end_at_b_hit = frame
				if event.combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED:
					recovered_end_frame = frame
	_check(moves == ["5A", "5B", "6A", "jC", "j214D", "5B"],
		"A-starter route lands the juggle and the post-bounce 5B as hit 6 (%s)" % str(moves))
	_check(b_hit_frame > 0 and end_at_b_hit > b_hit_frame,
		"the combo does NOT end on the bounce-target hit itself (end F%d > hit F%d)" % [end_at_b_hit, b_hit_frame])
	_check(recovered_end_frame > 0,
		"it continues until the dummy naturally recovers (DUMMY_RECOVERED F%d)" % recovered_end_frame)


func _test_rebounce_natural_continuation() -> void:
	print("=== 再次弹地与有限性：6A 弹地追击 > jc.jC > 第二次 j214D > 第二次弹地 ===")
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(26.0, 0)
	var back := -1
	## B 起手 juggle：5B>5C>6A>jc.jB>j214D → 弹地 → 6A（弹地资料，自然接续）→
	## jc → jC（对空再挑空）→ j214D（对空资料）→ 第二次弹地。帧号经真实回放
	## 校准；6A 的弹地目押窗为 2F（D72 允许）。
	var plan := {
		1: _key("B"), 16: _key("C"),
		30: _key("A", 1), 31: FrameInput.make(1),
		48: _vertical_jump(),
		62: _key("B"),
		76: FrameInput.make(0, false, "", true), 77: FrameInput.make(back, false, "", true),
		78: FrameInput.make(back), 79: _key("D", back),
		105: _key("A", 1),
		126: _vertical_jump(),
		131: _key("C"),
		145: FrameInput.make(0, false, "", true), 146: FrameInput.make(back, false, "", true),
		147: FrameInput.make(back), 148: _key("D", back),
	}
	var moves: Array[String] = []
	var scales: Array[float] = []
	var contacts: Array[int] = []
	var combo_broken := -1
	for frame in range(1, 220):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				moves.append(move_at_start)
				scales.append(session.combo_time_scale)
			elif event.type == CombatEvent.Type.BOUNCE_CONTACT:
				contacts.append(frame)
			elif event.type == CombatEvent.Type.COMBO_ENDED and combo_broken < 0:
				combo_broken = frame
	var expected := ["5B", "5C", "6A", "jB", "j214D", "6A", "jC", "j214D"]
	_check(moves == expected,
		"rebounce route: the 6A bounce-profile hit continues naturally into jc.jC and a second j214D (%s)" % str(moves))
	_check(contacts.size() == 2,
		"a second effective j214D produces a second real GROUND_BOUNCE (contacts at %s)" % str(contacts))
	var monotone := true
	for i in range(1, scales.size()):
		if scales[i] > scales[i - 1] + 0.0001:
			monotone = false
	_check(monotone,
		"time-scale corrections only ever decrease across the two bounces (never reset/refreshed)")
	_check(combo_broken > 0,
		"the multi-bounce combo still ends naturally (finite; end F%d)" % combo_broken)


# --- R4-G 参考路线 ---

func _assert_r4g_success(run: Dictionary, tag: String) -> bool:
	var ok := true
	if run["moves"] != R4G_MOVES:
		_check(false, "%s: exact six-hit sequence %s (got %s, late %s)" % [tag, str(R4G_MOVES), str(run["moves"]), str(run["hits_after_end"])])
		ok = false
	if not run["hits_after_end"].is_empty():
		_check(false, "%s: no hits after the first combo end (%s)" % [tag, str(run["hits_after_end"])])
		ok = false
	if run["bounce_contacts"].size() != 1:
		_check(false, "%s: exactly one real bounce contact (%s)" % [tag, str(run["bounce_contacts"])])
		ok = false
	if int(run["knockdown_frame"]) < 0:
		_check(false, "%s: the route reaches the first actual normal knockdown (spike lands → KNOCKED_DOWN)" % tag)
		ok = false
	var first_end: Dictionary = run["ends"][0] if not run["ends"].is_empty() else {}
	if ok and (first_end.is_empty() or int(first_end.get("reason", -1)) != CombatEvent.ComboEndReason.FINISHER):
		_check(false, "%s: the first combo end is the ~C finisher (same-frame HIT→END keeps the final hit)" % tag)
		ok = false
	if ok:
		var session: CombatSession = run["session"]
		var body_ok := session.dummy_position.x >= GameParams.stage_left_limit() - 0.001 \
			and session.dummy_position.x <= GameParams.stage_right_limit() + 0.001 \
			and session.player_position.x >= GameParams.stage_left_limit() - 0.001 \
			and session.player_position.x <= GameParams.stage_right_limit() + 0.001
		_check(body_ok, "%s: both fighters stay inside the legal wall limits at the knockdown endpoint" % tag)
		_check(bool(run["knockdown_state_ok"]),
			"%s: the dummy is in the normal knockdown state at the endpoint frame" % tag)
	return ok


func _test_r4g_reference_route(facing: int) -> void:
	print("=== R4-G 参考路线 g=2 r=350 | 面向 %+d ===" % facing)
	var session := _place(2.0, 350.0, facing)
	var run := _run(_r4g_plan(facing), session, HORIZON, true)
	if _assert_r4g_success(run, "R4-G ref %+d" % facing):
		_check(true, "R4-G reference six-hit + first knockdown lands exactly (facing %+d, swaps=%d)" % [facing, int(run["swaps"])])


# --- 保证域有限扫描 ---

func _run_point(g: float, r: float, facing: int) -> Dictionary:
	var session := _place(g, r, facing)
	return _run(_r4g_plan(facing), session, HORIZON)


func _test_r4g_domain_sweep() -> void:
	print("=== R4-G 保证域扫描：g 全整数 × r 分层 + 端点 + 非整数样点（双面向）===")
	## 覆盖方法（如实）：g∈[0,18] 逐整数；r 主体按 35px 步长 + 端点 0/700，
	## 另对 g∈{0,18} 两条边界行 r 逐整数；非整数取 g{0.5,9.25,17.75}×
	## r{0.5,350.25,699.5}。有限采样不是连续域的数学穷尽证明。
	var failures: Array[String] = []
	var total := 0
	for g in range(0, 19):
		for r in range(0, 701, 35):
			for facing in [1, -1]:
				total += 1
				var run := _run_point(float(g), float(r), facing)
				if run["moves"] != R4G_MOVES or not run["hits_after_end"].is_empty() or int(run["knockdown_frame"]) < 0:
					failures.append("g%d r%d f%+d -> %s" % [g, r, facing, str(run["moves"])])
	for g in [0, 18]:
		for r in range(1, 700):
			for facing in [1, -1]:
				total += 1
				var run := _run_point(float(g), float(r), facing)
				if run["moves"] != R4G_MOVES or not run["hits_after_end"].is_empty() or int(run["knockdown_frame"]) < 0:
					failures.append("edge g%d r%d f%+d -> %s" % [g, r, facing, str(run["moves"])])
	for g in [0.5, 9.25, 17.75]:
		for r in [0.5, 350.25, 699.5]:
			for facing in [1, -1]:
				total += 1
				var run := _run_point(g, r, facing)
				if run["moves"] != R4G_MOVES or not run["hits_after_end"].is_empty() or int(run["knockdown_frame"]) < 0:
					failures.append("g%.2f r%.2f f%+d -> %s" % [g, r, facing, str(run["moves"])])
	print("  sweep points=%d failures=%d (integer-g full × r stride 35, edge rows r full, non-integer samples)" % [total, failures.size()])
	if failures.is_empty():
		_check(true, "domain sweep: all %d sampled points complete the exact six-hit route with the first knockdown" % total)
	else:
		for entry in failures.slice(0, 12):
			print("  SWEEP-FAIL %s" % entry)
		_check(false, "domain sweep: %d/%d sampled points failed (list above; must be fixed or escalated, not shrunk)" % [failures.size(), total])


# --- 关键键连续成功区间 ---

func _test_r4g_key_windows() -> void:
	print("=== R4-G 关键键连续成功区间（±4F 逐帧，其余固定，g2/r350 双面向）===")
	var keys := ["jc", "jC", "j214D", "5B", "214C", "~C"]
	for key in keys:
		var intervals: Array[String] = []
		for facing in [1, -1]:
			## 该键在 ±4 内的成功帧（相对参考帧的偏移）。
			var hits: Array[int] = []
			for delta in range(-4, 5):
				var session := _place(2.0, 350.0, facing)
				var plan := _r4g_plan(facing, {key: delta})
				var result := _run(plan, session, HORIZON)
				if result["moves"] == R4G_MOVES and int(result["knockdown_frame"]) > 0:
					hits.append(delta)
			## 折叠为连续闭区间的文本（∪ 分隔）。
			var text := ""
			var last := -99
			for delta in hits:
				if last == -99 or delta > last + 1:
					if text != "":
						text += " ∪ "
					text += "[%d" % delta
				last = delta
				if delta == hits[hits.size() - 1]:
					text += "]"
			if text == "":
				text = "∅"
			intervals.append("f%+d %s" % [facing, text])
		print("  key %-6s windows: %s" % [key, " | ".join(PackedStringArray(intervals))])
		_check(true, "window scan for %s recorded (continuous intervals above; not a full-route tolerance claim)" % key)


# --- 联合扰动（记录，不设旧 244 门槛）---

func _test_r4g_joint_perturbation() -> void:
	print("=== R4-G 六键联合 ±1F 扰动（64 向量 × 双面向 = 128）===")
	var keys := ["jc", "jC", "j214D", "5B", "214C", "~C"]
	var success := 0
	var total := 0
	var breakpoints := {}
	for facing in [1, -1]:
		for mask in range(64):
			var offsets := {}
			for i in keys.size():
				if mask & (1 << i):
					offsets[keys[i]] = 1
				else:
					offsets[keys[i]] = -1
			var session := _place(2.0, 350.0, facing)
			var result := _run(_r4g_plan(facing, offsets), session, HORIZON)
			total += 1
			if result["moves"] == R4G_MOVES and int(result["knockdown_frame"]) > 0:
				success += 1
			else:
				var broken := "-"
				for hit in result["hits"]:
					if not R4G_MOVES.has(str(hit["move"])):
						broken = str(hit["move"])
						break
				breakpoints[broken] = int(breakpoints.get(broken, 0)) + 1
	print("  joint ±1: %d/%d (denominator 64 vectors × 2 facings; breakpoints by first off-route hit: %s)" % [success, total, str(breakpoints)])
	_check(true, "joint perturbation recorded honestly (D72: 1F accepted, old 244/256 gate not applied)")


# --- 负例 ---

func _test_r4g_negatives() -> void:
	print("=== R4-G 负例 ===")
	## 6A 被防：无 jump cancel（不起跳）。
	var blocked := _place(2.0, 350.0, 1)
	var was_airborne := false
	var blocked_seen := false
	for frame in range(1, 40):
		var input := FrameInput.new()
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		match frame:
			1:
				input = _key("A", 1)
			2:
				input.move_axis = 1
			12:
				input.jump_pressed = true
		var on_ground_before := blocked.player_on_ground
		for event in blocked.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked_seen = true
		if not on_ground_before:
			was_airborne = true
	_check(blocked_seen and not was_airborne and blocked.player_on_ground,
		"negative: blocked 6A grants no jump cancel (never leaves the ground)")
	## 6A 挥空（射程外）：jc 后没有连段命中。
	var whiff := _place(120.0, 350.0, 1)
	var whiff_hits := 0
	var plan := _r4g_plan(1)
	for frame in range(1, 80):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		for event in whiff.step(input):
			if event.type == CombatEvent.Type.HIT:
				whiff_hits += 1
	_check(whiff_hits == 0, "negative: out-of-range 6A whiffs; no combo hits fabricate followups")
	## 跳消过早/过晚（经回放校准的失效偏移；±8 内经缓存/窗口仍成立，如实记录）。
	var early_jc := _place(2.0, 350.0, 1)
	var early_jc_run := _run(_r4g_plan(1, {"jc": -10}), early_jc, HORIZON)
	_check(early_jc_run["moves"] != R4G_MOVES,
		"negative: jump cancel 10F early breaks the route honestly (%s)" % str(early_jc_run["moves"]))
	var late_jc := _place(2.0, 350.0, 1)
	var late_jc_run := _run(_r4g_plan(1, {"jc": 25}), late_jc, HORIZON)
	_check(late_jc_run["moves"] != R4G_MOVES,
		"negative: jump cancel 25F late breaks the route honestly (%s)" % str(late_jc_run["moves"]))
	## jC 错时（过早/过晚均脱离准确路线；尾段 214C/~C ±7 内有真实容差，不选作负例）。
	var early_jc_move := _place(2.0, 350.0, 1)
	var early_jc_move_run := _run(_r4g_plan(1, {"jC": -14}), early_jc_move, HORIZON)
	_check(early_jc_move_run["moves"] != R4G_MOVES,
		"negative: jC pressed 14F early breaks the route honestly (%s)" % str(early_jc_move_run["moves"]))
	var late_jc_move := _place(2.0, 350.0, 1)
	var late_jc_move_run := _run(_r4g_plan(1, {"jC": 12}), late_jc_move, HORIZON)
	_check(late_jc_move_run["moves"] != R4G_MOVES,
		"negative: jC pressed 12F late breaks the route honestly (%s)" % str(late_jc_move_run["moves"]))
	## j214D 过晚（弹地窗口过期前 5B 无法命中）。
	var late_j214d := _place(2.0, 350.0, 1)
	var late_j214d_run := _run(_r4g_plan(1, {"j214D": 7}), late_j214d, HORIZON)
	_check(late_j214d_run["moves"] != R4G_MOVES,
		"negative: j214D final key 7F late breaks the route honestly (%s)" % str(late_j214d_run["moves"]))
	## 5B 过早（落地恢复/弹地等待中缓存过期）：不足六击。
	var early_b := _place(2.0, 350.0, 1)
	var early_b_run := _run(_r4g_plan(1, {"5B": -12}), early_b, HORIZON)
	_check(early_b_run["moves"] != R4G_MOVES and early_b_run["moves"].size() < 6,
		"negative: 5B pressed 12F early never lands in-combo (%s)" % str(early_b_run["moves"]))
	## 5B 过晚（弹地追击窗/恢复关闭后）。
	var late_b := _place(2.0, 350.0, 1)
	var late_b_run := _run(_r4g_plan(1, {"5B": 8}), late_b, HORIZON)
	_check(late_b_run["moves"] != R4G_MOVES,
		"negative: 5B pressed 8F late does not complete the six-hit route (%s)" % str(late_b_run["moves"]))
	## 滑行目标上的 6A：不产生任何命中。先前攻击产生的特殊受击状态上，6A
	## 既不是声明的接续边（合法性门先行拒绝——按帧扫描确认既无 HIT 也无
	## HIT_MISS），也没有 slide 资料——两层门共同保证“中途 6A 冒充对地首击”
	## 不可行；表级事实（6A 无 AIRBORNE 资料）由 test_hit_profiles 的 route01
	## 断言承载。
	var slide_case := CombatSession.new()
	slide_case.dummy_position = slide_case.player_position + Vector2(60.0, 0)
	var slide_started := false
	var slide_extra_contacts := 0
	for frame in range(1, 80):
		var input := FrameInput.new()
		match frame:
			1:
				input = FrameInput.make(0, false, "", true)
			2:
				input = FrameInput.make(1, false, "", true)
			3:
				input = FrameInput.make(1)
			4:
				input = _key("C", 1)
			32:
				input = _key("A", 1)
		for event in slide_case.step(input):
			if event.type == CombatEvent.Type.SLIDE_STARTED:
				slide_started = true
			elif event.type in [CombatEvent.Type.HIT, CombatEvent.Type.HIT_MISS] and frame >= 32:
				slide_extra_contacts += 1
	_check(slide_started and slide_extra_contacts == 0,
		"negative: a mid-route 6A on the sliding target produces no contact of any kind (legitimacy + profile gates)")
