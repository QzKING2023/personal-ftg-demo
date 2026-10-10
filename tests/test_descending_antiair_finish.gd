extends SceneTree
## 连段路线票据 02：6A 下落对空首击，按三档参考完成六击倒地（R4-A）。
## 覆盖父规格 R4-A 与 D81–D85：6A AIRBORNE normal/counter 显式资料（LAUNCH、
## 不可受身 30/36N、水平150/向上460px/s；对地 36/42N、向上560 保持）、未受击
## 空中木桩按跳跃者真实运动（保持水平速度、重力/墙限照常）、D82 三档 R/T28
## 预生成固定计划回放（δ 只加六个时点、轴不平移、axis∈{-1,0,1} 自检）、
## 保证域（k20–30 成对 h/vy × 水平初速连续域采样 × g 含负/非整数 × r 分层
## × 双面向）有限扫描（如实记录步长与接触失败，不称数学穷尽）、保存续跑
## 等价、关键键连续区间与联合扰动记录（D72 允许 1F，不设旧 7F/244 门槛）
## 及相关负例与范围外对照。运行：
##   godot --headless --path . -s res://tests/test_descending_antiair_finish.gd

const ENGINE_LOG_PREFIX := "R4A"

var _failures := 0


func _initialize() -> void:
	_test_6a_airborne_profiles()
	_test_airborne_neutral_motion()
	_test_r4a_reference_route(1)
	_test_r4a_reference_route(-1)
	_test_r4a_tier_references()
	_test_r4a_front_gap_boundary()
	_test_r4a_domain_sweep()
	_test_r4a_save_restore_equivalence()
	_test_r4a_key_windows()
	_test_r4a_joint_perturbation()
	_test_r4a_negatives()
	print("")
	if _failures == 0:
		print("ALL DESCENDING ANTIAIR FINISH TESTS PASSED")
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


func _key(key: String, axis := 0, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	input.move_axis = axis
	input.down_held = down
	return input


# --- 6A AIRBORNE 资料（票据 02 数值表）---

func _test_6a_airborne_profiles() -> void:
	print("=== 6A AIRBORNE N/C 资料：精确匹配；对地与弹地保持 ===")
	var table := MoveData.default_table()
	var six_a: MoveData = table["6A"]
	var air_n := MoveData.profile_for(six_a, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL)
	var air_c := MoveData.profile_for(six_a, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.COUNTER)
	_check(air_n != null and air_n.reaction == HitProfile.Reaction.LAUNCH
		and air_n.air_untech_frames == 30
		and is_equal_approx(air_n.horizontal_speed_px_s, 150.0)
		and is_equal_approx(air_n.upward_speed_px_s, 460.0),
		"6A AIRBORNE normal: LAUNCH, untech 30N, horizontal 150 / upward 460 (ticket 02 value table)")
	_check(air_c != null and air_c.reaction == HitProfile.Reaction.LAUNCH
		and air_c.air_untech_frames == 36
		and is_equal_approx(air_c.horizontal_speed_px_s, 150.0)
		and is_equal_approx(air_c.upward_speed_px_s, 460.0),
		"6A AIRBORNE counter: LAUNCH, untech 36N, same speeds (counter not shorter than normal)")
	var gnd_n := MoveData.profile_for(six_a, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	var gnd_c := MoveData.profile_for(six_a, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	_check(gnd_n != null and gnd_n.air_untech_frames == 36 and is_equal_approx(gnd_n.upward_speed_px_s, 560.0),
		"6A GROUNDED normal unchanged (untech 36N, upward 560)")
	_check(gnd_c != null and gnd_c.air_untech_frames == 42 and is_equal_approx(gnd_c.upward_speed_px_s, 560.0),
		"6A GROUNDED counter unchanged (untech 42N, upward 560)")
	_check(MoveData.profile_for(six_a, HitProfile.TargetState.GROUND_SLIDE, HitProfile.HitContext.NORMAL) == null,
		"6A still declares no GROUND_SLIDE profile (no fallback expansion)")
	_check(MoveData.profile_for(six_a, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) != null
		and MoveData.profile_for(six_a, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.COUNTER) != null,
		"both AIRBORNE contexts are explicit keys on the shared manifest resource")


# --- 未受击空中木桩的真实运动（D84：初态之后真实运动，不悬空钉位）---

func _test_airborne_neutral_motion() -> void:
	print("=== 未受击空中木桩：保持水平速度、重力/墙限照常、落地回标准物理 ===")
	## 与真实玩家跳跃一致的空中段：水平速度不衰减（E45 jumps 记录为常 vx），
	## 重力逐帧累积，触地回 NEUTRAL 地面并恢复标准摩擦。
	var session := CombatSession.new()
	session.dummy_position = Vector2(480.0, GameParams.ground_stand_y() - 60.0)
	session.dummy_velocity = Vector2(200.0, 0.0)
	var vx_seen: Array[float] = []
	var landed_frame := -1
	var state_after_landing := CombatSession.DummyState.NEUTRAL
	for frame in range(1, 80):
		var events := session.step(FrameInput.new())
		if session.dummy_on_ground:
			if landed_frame < 0:
				landed_frame = frame
				state_after_landing = session.dummy_state
		else:
			vx_seen.append(session.dummy_velocity.x)
	var vx_const := true
	for vx in vx_seen:
		if not is_equal_approx(vx, 200.0):
			vx_const = false
	_check(landed_frame > 0 and vx_seen.size() > 4,
		"airborne neutral dummy falls under gravity and lands (landed F%d, %d airborne frames)" % [landed_frame, vx_seen.size()])
	_check(vx_const,
		"while un-hit and airborne the dummy keeps its horizontal speed like a real jump (no ground friction)")
	_check(state_after_landing == CombatSession.DummyState.NEUTRAL,
		"an un-hit landing keeps the dummy NEUTRAL (no invented stun)")
	## 落地后恢复标准木桩摩擦：200px/s 以 2000px/s² 摩擦 6 帧内归零。
	var vx_decayed_to_zero := false
	for frame in range(landed_frame + 1, landed_frame + 10):
		session.step(FrameInput.new())
		if is_equal_approx(session.dummy_velocity.x, 0.0):
			vx_decayed_to_zero = true
			break
	_check(vx_decayed_to_zero,
		"standard dummy friction resumes after landing (vx decays to 0 within ~6 frames)")
	## 墙限：朝墙水平运动的未受击空中木桩被钳制在合法中心墙限。
	var wall_case := CombatSession.new()
	wall_case.dummy_position = Vector2(920.0, GameParams.ground_stand_y() - 50.0)
	wall_case.dummy_velocity = Vector2(340.0, 0.0)
	var clamped := true
	for frame in range(1, 30):
		wall_case.step(FrameInput.new())
		if wall_case.dummy_position.x > GameParams.stage_right_limit() + 0.001:
			clamped = false
	_check(clamped and is_equal_approx(wall_case.dummy_position.x, GameParams.stage_right_limit()),
		"an airborne neutral dummy is clamped to the legal wall limit while moving")


# --- R4-A：声明初态、探针定档、预生成固定计划、严格回放 ---

## D82 三档参考时点（F9 接触锚定）：δ=接触F−9 只加到六个时点。
const R4A_TIERS := {
	"G": {"jc": 11, "jC": 34, "j214D": 47, "5B": 78, "214C": 90, "~C": 114},
	"H38": {"jc": 11, "jC": 31, "j214D": 45, "5B": 75, "214C": 87, "~C": 111},
	"H21": {"jc": 11, "jC": 29, "j214D": 42, "5B": 70, "214C": 82, "~C": 106},
}
const R4A_MOVES := ["6A", "jC", "j214D", "5B", "214C", "214C~C"]
const AIR_HORIZON := 180


## 普通跳跃 k 帧的成对垂直状态（E45 jumps 记录的精确重现）：k=1 起跳，
## vy(k)=23.333×(k−20)、h(k)=−Σ_{j≤k} vy(j)/60；k20–30 为下落域。
func _jump_state(k: int) -> Dictionary:
	var step := GameParams.GRAVITY * GameParams.PHYSICS_TICK
	var h := 0.0
	for j in range(1, k + 1):
		h -= step * (j - 20) * GameParams.PHYSICS_TICK
	return {"h": h, "vy": step * (k - 20)}


## 布置声明初态：玩家地面中立，目标取 k 的成对状态、相对面向水平初速
## vx_rel（正=沿面向远离玩家）、边缘间距 g（负=横向重叠，仅纵向分离合法）、
## 目标到其身后指定墙限 r。返回会话与声明元数据。
func _place_air(k: int, vx_rel: float, g: float, r: float, facing: int) -> Dictionary:
	var session := CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dummy_x := wall - r * facing
	var player_x := dummy_x - facing * (GameParams.BODY_SIZE.x + g)
	var jump := _jump_state(k)
	session.player_position = Vector2(player_x, GameParams.ground_stand_y())
	session.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y() - jump["h"])
	session.dummy_velocity = Vector2(facing * vx_rel, jump["vy"])
	# 与 E45 相同：注入空中初态时同步离地标志，首帧即按真实跳跃续算
	#（否则首帧漏一次重力增量，轨迹滞后成对状态一个步长）。
	session.dummy_on_ground = false
	session.player_facing = facing
	return {"session": session, "k": k, "vx_rel": vx_rel, "g": g, "r": r, "facing": facing}


## 探针：只按 6A（F1–2，与正式计划相同），其余中立，寻找首个接触。
## 接触帧与档位选择是声明初态的确定函数——计划据此预生成，回放中不读状态。
func _probe_contact(setup: Dictionary) -> Dictionary:
	var session: CombatSession = setup["session"]
	var facing: int = setup["facing"]
	var initial_side: int = 1 if session.dummy_position.x > session.player_position.x else -1
	for frame in range(1, 80):
		var input := _key("A", facing) if frame == 1 else (FrameInput.make(facing) if frame == 2 else FrameInput.new())
		var move_at_start := session.player_move_id
		var dummy_pos_at_start := session.dummy_position
		var dummy_on_ground_at_start := session.dummy_on_ground
		var dummy_vy_at_start := session.dummy_velocity.y
		var side_at_start: int = 1 if session.dummy_position.x > session.player_position.x else -1
		for event in session.step(input):
			if event.type in [CombatEvent.Type.HIT, CombatEvent.Type.HIT_MISS, CombatEvent.Type.ATTACK_BLOCKED] \
					and move_at_start == "6A":
				var h := GameParams.ground_stand_y() - dummy_pos_at_start.y
				return {
					"contact": event.type == CombatEvent.Type.HIT, "frame": frame, "h": h,
					"front_gap": (dummy_pos_at_start.x - session.player_position.x) * facing - GameParams.BODY_SIZE.x,
					"airborne": not dummy_on_ground_at_start, "descending": dummy_vy_at_start >= 0.0,
					"crossed": side_at_start != initial_side,
				}
	return {}


## 由声明初态预生成 R/T28 计划：档按接触 h（≥36 G / [30,36) H38 / <30 H21）、
## 方向按接触 front gap（<28 用 8，否则 9）；δ 只加到六个时点，6A 与方向轴
## 不平移；全部轴取世界 ±facing/0（axis∈{−1,0,1} 断言——E44 教训）。
func _r4a_plan(facing: int, contact: Dictionary, offsets := {}) -> Dictionary:
	var h: float = contact["h"]
	var tier: String = "G" if h >= 36.0 else ("H38" if h >= 30.0 else "H21")
	var use_eight: bool = contact["front_gap"] < 28.0
	var delta := int(contact["frame"]) - 9
	var t: Dictionary = R4A_TIERS[tier]
	var d_jc := int(offsets.get("jc", 0))
	var d_c := int(offsets.get("jC", 0))
	var d_d := int(offsets.get("j214D", 0))
	var d_b := int(offsets.get("5B", 0))
	var d_k := int(offsets.get("214C", 0))
	var d_t := int(offsets.get("~C", 0))
	var back := -facing
	var plan := {}
	# 6A F1–2：前方向两帧，A 首帧按下（不平移）。
	plan[1] = _key("A", facing)
	plan[2] = FrameInput.make(facing)
	# 跳消：8（垂直）或 9（沿面向前跳）。
	var jump := FrameInput.make(0, true)
	if not use_eight:
		jump.move_axis = facing
	plan[int(t["jc"]) + delta + d_jc] = jump
	# jC。
	plan[int(t["jC"]) + delta + d_c] = _key("C")
	# j214D：下 / 下后 / 后 / 后+D。
	plan[int(t["j214D"]) - 3 + delta + d_d] = FrameInput.make(0, false, "", true)
	plan[int(t["j214D"]) - 2 + delta + d_d] = FrameInput.make(back, false, "", true)
	plan[int(t["j214D"]) - 1 + delta + d_d] = FrameInput.make(back)
	plan[int(t["j214D"]) + delta + d_d] = _key("D", back)
	# 弹地追击 5B。
	plan[int(t["5B"]) + delta + d_b] = _key("B")
	# 214C：下 / 下后 / 后 / 后+C。
	plan[int(t["214C"]) - 3 + delta + d_k] = FrameInput.make(0, false, "", true)
	plan[int(t["214C"]) - 2 + delta + d_k] = FrameInput.make(back, false, "", true)
	plan[int(t["214C"]) - 1 + delta + d_k] = FrameInput.make(back)
	plan[int(t["214C"]) + delta + d_k] = _key("C", back)
	# ~C 派生。
	plan[int(t["~C"]) + delta + d_t] = _key("C")
	# 合法轴自检（E44 教训：帧偏移不得混入方向轴值）。
	for frame in plan:
		var axis: int = plan[frame].move_axis
		assert(axis in [-1, 0, 1], "R4A plan axis must be -1/0/1, got %d at F%d" % [axis, frame])
	return plan


## 严格回放：同连段逐 HIT、首击为 6A 对空未受击下落目标且未越身、jC 为跳消
## 追击（玩家空中）、j214D→5B 间真实弹地、5B 完整落地恢复后启动、首次实际
## 普通倒地前无 END（FINISHER 除外）/无补击、终点双方墙限与二维身体合法。
func _run_air(plan: Dictionary, setup: Dictionary, verbose := false) -> Dictionary:
	var session: CombatSession = setup["session"]
	var evidence := preload("res://tests/replay_combo_evidence.gd").new()
	var bounce_contacts: Array[int] = []
	var swaps := 0
	var j214d_hit_frame := -1
	var five_b_hit_frame := -1
	var knockdown_frame := -1
	var knockdown_state_ok := false
	var rect_overlap_frames: Array[int] = []
	var first_contact: Dictionary = {}
	var jc_airborne := false
	var five_b_start: Dictionary = {}
	var landings: Array[int] = []
	var prev_move := ""
	var prev_on_ground := true
	var prev_landing_recovery := 0
	var initial_side: int = 1 if session.dummy_position.x > session.player_position.x else -1
	for frame in range(1, AIR_HORIZON + 1):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		var dummy_pos_at_start := session.dummy_position
		var dummy_grounded_at_start := session.dummy_on_ground
		var dummy_vy_at_start := session.dummy_velocity.y
		var player_on_ground_at_start := session.player_on_ground
		var state_at_start := session.dummy_state
		var side_at_start: int = 1 if session.dummy_position.x > session.player_position.x else -1
		var events := session.step(input)
		for order in events.size():
			var event: CombatEvent = events[order]
			evidence.record(frame, order, move_at_start, order, event)
			match event.type:
				CombatEvent.Type.BOUNCE_CONTACT:
					bounce_contacts.append(frame)
				CombatEvent.Type.SWITCHED_SIDES:
					swaps += 1
				CombatEvent.Type.SPIKE_LANDED:
					if knockdown_frame < 0:
						knockdown_frame = frame
						knockdown_state_ok = session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
				CombatEvent.Type.COMBO_ENDED:
					if event.combo_end_reason == CombatEvent.ComboEndReason.KNOCKDOWN and knockdown_frame < 0:
						knockdown_frame = frame
						knockdown_state_ok = session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
				CombatEvent.Type.HIT, CombatEvent.Type.HIT_MISS, CombatEvent.Type.ATTACK_BLOCKED:
					if first_contact.is_empty():
						first_contact = {"type": event.type, "move": move_at_start, "frame": frame,
							"airborne": not dummy_grounded_at_start, "descending": dummy_vy_at_start >= 0.0,
							"neutral": state_at_start == CombatSession.DummyState.NEUTRAL,
							"crossed": side_at_start != initial_side}
					if event.type == CombatEvent.Type.HIT:
						if move_at_start == "jC":
							jc_airborne = not player_on_ground_at_start
						elif move_at_start == "j214D":
							j214d_hit_frame = frame
						elif move_at_start == "5B":
							five_b_hit_frame = frame
		# 落地帧与二维身体相交检查（至首次倒地为止）。
		if prev_on_ground and not session.player_on_ground:
			pass
		elif not prev_on_ground and session.player_on_ground:
			landings.append(frame)
		if knockdown_frame < 0 or frame <= knockdown_frame:
			var p_rect := Rect2(session.player_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
			var d_rect := Rect2(session.dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
			if p_rect.intersects(d_rect):
				rect_overlap_frames.append(frame)
		# 5B 启动帧：本帧结束时 move id 变为 5B；恢复判定按生产顺序（运动阶段
		# 先于缓存消费——起点帧 recovery≤1 即视为消费时已完整恢复）。
		if session.player_move_id == "5B" and move_at_start != "5B" and five_b_start.is_empty():
			five_b_start = {"frame": frame, "plr_before": prev_landing_recovery,
				"plr": session.player_landing_recovery_left,
				"pg": session.player_on_ground, "pg_before": player_on_ground_at_start}
		prev_move = session.player_move_id
		prev_on_ground = session.player_on_ground
		prev_landing_recovery = session.player_landing_recovery_left
		if verbose:
			print("    F%-3d %-6s p(%.1f,%.1f) d(%.1f,%.1f) dst=%s" % [frame, prev_move,
				session.player_position.x, session.player_position.y,
				session.dummy_position.x, session.dummy_position.y,
				CombatSession.DummyState.keys()[session.dummy_state]])
	return {
		"session": session, "moves": evidence.moves, "hits": evidence.hits,
		"hits_after_end": evidence.hits_after_end, "ends": evidence.ends,
		"bounce_contacts": bounce_contacts, "swaps": swaps,
		"knockdown_frame": knockdown_frame, "knockdown_state_ok": knockdown_state_ok,
		"rect_overlap_frames": rect_overlap_frames, "first_contact": first_contact,
		"jc_airborne": jc_airborne, "five_b_start": five_b_start, "landings": landings,
		"j214d_hit_frame": j214d_hit_frame, "five_b_hit_frame": five_b_hit_frame,
	}


## 严格判据：返回失败原因列表（空=通过）。
func _r4a_strict_failures(run: Dictionary, tag: String) -> Array[String]:
	var why: Array[String] = []
	if run["moves"] != R4A_MOVES:
		why.append("moves=%s" % str(run["moves"]))
	if not run["hits_after_end"].is_empty():
		why.append("hits_after_end=%s" % str(run["hits_after_end"]))
	var fc: Dictionary = run["first_contact"]
	if fc.is_empty() or fc["type"] != CombatEvent.Type.HIT or fc["move"] != "6A":
		why.append("first_contact=%s" % str(fc))
	else:
		if not fc["airborne"]:
			why.append("6A_target_grounded")
		if not fc["descending"]:
			why.append("6A_target_rising")
		if not fc["neutral"]:
			why.append("6A_target_not_unhit")
		if fc["crossed"]:
			why.append("6A_target_crossed")
	if not run["jc_airborne"]:
		why.append("jC_not_air_started")
	if run["bounce_contacts"].size() != 1:
		why.append("bounce_contacts=%s" % str(run["bounce_contacts"]))
	elif not (int(run["j214d_hit_frame"]) > 0 and int(run["j214d_hit_frame"]) < int(run["bounce_contacts"][0]) and int(run["bounce_contacts"][0]) < int(run["five_b_hit_frame"])):
		why.append("bounce_order j214D@%d bounce@%d 5B@%d" % [int(run["j214d_hit_frame"]), int(run["bounce_contacts"][0]), int(run["five_b_hit_frame"])])
	if int(run["knockdown_frame"]) < 0:
		why.append("no_knockdown")
	else:
		if not bool(run["knockdown_state_ok"]):
			why.append("knockdown_state")
		var first_end: Dictionary = run["ends"][0] if not run["ends"].is_empty() else {}
		if first_end.is_empty() or int(first_end.get("reason", -1)) != CombatEvent.ComboEndReason.FINISHER:
			why.append("first_end=%s" % str(first_end))
		var s: CombatSession = run["session"]
		if s.dummy_position.x < GameParams.stage_left_limit() - 0.001 or s.dummy_position.x > GameParams.stage_right_limit() + 0.001 \
				or s.player_position.x < GameParams.stage_left_limit() - 0.001 or s.player_position.x > GameParams.stage_right_limit() + 0.001:
			why.append("endpoint_bounds")
	if not run["rect_overlap_frames"].is_empty():
		why.append("rect_overlap=%s" % str(run["rect_overlap_frames"]))
	var s5: Dictionary = run["five_b_start"]
	if s5.is_empty():
		why.append("5B_not_started")
	elif not s5["pg"] or int(s5["plr"]) != 0 or not s5["pg_before"] or int(s5["plr_before"]) > 1:
		why.append("5B_recovery=%s" % str(s5))
	return why


func _test_r4a_reference_route(facing: int) -> void:
	print("=== R4-A 参考路线 k=24 vx=0 g=2 r=350 | 面向 %+d（探针定档 + 固定计划）===" % facing)
	var setup := _place_air(24, 0.0, 2.0, 350.0, facing)
	var probe := _probe_contact(_place_air(24, 0.0, 2.0, 350.0, facing))
	_check(probe.get("contact", false) and probe.get("airborne", false) and probe.get("descending", false),
		"probe: 6A reaches a descending un-hit airborne target (%s)" % str(probe))
	if probe.is_empty():
		return
	var plan := _r4a_plan(facing, probe)
	var run := _run_air(plan, setup)
	var why := _r4a_strict_failures(run, "ref%+d" % facing)
	if why.is_empty():
		var tier: String = "G" if float(probe["h"]) >= 36.0 else ("H38" if float(probe["h"]) >= 30.0 else "H21")
		_check(true, "R4-A reference six-hit + first knockdown lands exactly (facing %+d, tier %s, contact h=%.3f F%d, KD F%d)" % [
			facing, tier, float(probe["h"]), int(probe["frame"]), int(run["knockdown_frame"])])
	else:
		_check(false, "R4-A reference route strict failures (facing %+d): %s" % [facing, " | ".join(PackedStringArray(why))])


## 通用：声明初态 → 探针 → 计划 → 严格回放；返回 {probe, run, why}。
func _r4a_attempt(k: int, vx_rel: float, g: float, r: float, facing: int, offsets := {}) -> Dictionary:
	var setup := _place_air(k, vx_rel, g, r, facing)
	var probe := _probe_contact(_place_air(k, vx_rel, g, r, facing))
	if probe.is_empty() or not probe["contact"]:
		return {"probe": probe, "run": {}, "why": ["no_contact"]}
	var plan := _r4a_plan(facing, probe, offsets)
	var run := _run_air(plan, setup)
	return {"probe": probe, "run": run, "why": _r4a_strict_failures(run, "k%d vx%+.1f g%.1f r%.1f f%+d" % [k, vx_rel, g, r, facing])}


func _test_r4a_tier_references() -> void:
	print("=== R4-A 三档参考：G 迟接触（δ=+4）、H38、H21（含最低档）===")
	## k20–25 接触高度 38.5（G，接触 F13–F8→δ 随 k 变化）；k26 33.06（H38）；
	## k27+ 27.22 以下（H21）。逐档验证 δ 平移后的准确全链。
	var cases := [
		{"k": 20, "vx": 0.0, "g": 2.0, "r": 350.0, "facing": 1, "tier": "G"},
		{"k": 26, "vx": 0.0, "g": 2.0, "r": 350.0, "facing": 1, "tier": "H38"},
		{"k": 26, "vx": 0.0, "g": 2.0, "r": 350.0, "facing": -1, "tier": "H38"},
		{"k": 27, "vx": 0.0, "g": 2.0, "r": 350.0, "facing": 1, "tier": "H21"},
		{"k": 29, "vx": 0.0, "g": 2.0, "r": 350.0, "facing": 1, "tier": "H21"},
	]
	for case in cases:
		var out := _r4a_attempt(case["k"], case["vx"], case["g"], case["r"], case["facing"])
		var tier: String = "G" if float(out["probe"].get("h", 0.0)) >= 36.0 else ("H38" if float(out["probe"].get("h", 0.0)) >= 30.0 else "H21")
		if out["why"].is_empty():
			_check(tier == case["tier"],
				"tier %s: k%d f%+d completes exactly (contact h=%.3f F%d tier %s, KD F%d)" % [
					case["tier"], case["k"], case["facing"], float(out["probe"]["h"]), int(out["probe"]["frame"]), tier, int(out["run"]["knockdown_frame"])])
		else:
			_check(false, "tier %s k%d f%+d strict failures: %s" % [case["tier"], case["k"], case["facing"], " | ".join(PackedStringArray(out["why"]))])


func _test_r4a_front_gap_boundary() -> void:
	print("=== R4-A 28px 方向分界：front gap 27.99 用 8 / 28.0 用 9 ===")
	## k24 接触 F10（9 帧位移）：gap@接触 = g + vx×9/60。g=2 时 vx=(28−2)/0.15
	## 得 gap 恰 28.0（用 9）；略小得 27.99（用 8）。两侧都要求准确全链。
	for sample in [{"vx": 177.8, "tag": "gap<28→8"}, {"vx": 178.4, "tag": "gap≥28→9"}]:
		var out := _r4a_attempt(24, sample["vx"], 2.0, 350.0, 1)
		var gap: float = float(out["probe"].get("front_gap", -1.0)) if not out["probe"].is_empty() else -1.0
		if out["why"].is_empty():
			_check(true, "front-gap boundary %s (gap=%.4f, vx=%.1f) completes the exact route" % [sample["tag"], gap, sample["vx"]])
		else:
			_check(false, "front-gap boundary %s (gap=%.4f) strict failures: %s" % [sample["tag"], gap, " | ".join(PackedStringArray(out["why"]))])
	## 分界判据本身：计划生成对 27.99/28.0 选择不同跳消方向。
	var below := _r4a_plan(1, {"h": 38.5, "front_gap": 27.999, "frame": 10})
	var at := _r4a_plan(1, {"h": 38.5, "front_gap": 28.0, "frame": 10})
	_check(below[12].move_axis == 0 and at[12].move_axis == 1,
		"plan generation picks 8 below 28px and 9 at/above (axis %d vs %d)" % [below[12].move_axis, at[12].move_axis])


# --- 保证域有限扫描（D84 域：k20–30 × 连续水平速度采样 × g 含负/非整数 × r 分层 × 双面向）---

## 单点分类：no_contact（挥空）/ grounded（接触前落地，对地）/ crossed（首击前
## 越身，范围外）/ rising（上升，范围外）之外，凡实际对空首击且未越身者必须
## 完成严格全链。返回 {category, why}。
func _sweep_point(k: int, vx_rel: float, g: float, r: float, facing: int) -> Dictionary:
	## D84：仅取双方合法起点（玩家也须在场内）；非法起点不进入任何类别计数。
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dummy_x := wall - r * facing
	var player_x := dummy_x - facing * (GameParams.BODY_SIZE.x + g)
	if player_x < GameParams.stage_left_limit() - 0.001 or player_x > GameParams.stage_right_limit() + 0.001:
		return {"category": "illegal_start", "why": [] as Array[String]}
	if dummy_x < GameParams.stage_left_limit() - 0.001 or dummy_x > GameParams.stage_right_limit() + 0.001:
		return {"category": "illegal_start", "why": [] as Array[String]}
	var probe := _probe_contact(_place_air(k, vx_rel, g, r, facing))
	if probe.is_empty():
		return {"category": "no_contact", "why": [] as Array[String]}
	if not probe["contact"]:
		return {"category": "no_contact", "why": [] as Array[String]}
	if not probe["airborne"]:
		return {"category": "grounded", "why": [] as Array[String]}
	if probe["crossed"]:
		return {"category": "crossed", "why": [] as Array[String]}
	if not probe["descending"]:
		return {"category": "rising", "why": [] as Array[String]}
	var out := _r4a_attempt(k, vx_rel, g, r, facing)
	return {"category": "guarantee", "why": out["why"]}


func _sweep_case(k: int, vx: float, g: float, r: float, facing: int, categories: Dictionary, failures: Array[String], no_contact_tags: Dictionary = {}) -> void:
	var res := _sweep_point(k, vx, g, r, facing)
	var cat: String = res["category"]
	categories[cat] = int(categories.get(cat, 0)) + 1
	if cat == "no_contact":
		no_contact_tags["k%d" % k] = int(no_contact_tags.get("k%d" % k, 0)) + 1
		no_contact_tags["vx%+.0f" % vx] = int(no_contact_tags.get("vx%+.0f" % vx, 0)) + 1
	if cat == "guarantee" and not (res["why"] as Array[String]).is_empty():
		failures.append("k%d vx%+.1f g%.2f r%.1f f%+d: %s" % [k, vx, g, r, facing, " | ".join(PackedStringArray(res["why"]))])


func _test_r4a_domain_sweep() -> void:
	print("=== R4-A 保证域扫描：k×水平速度(含中间值) × g(负/零/非整数) × r(含墙钳制) × 双面向 ===")
	## 覆盖方法（如实）：k20–30 全量；vx 取 −340/−216.67/−100/0/+100/+216.67/+340
	##（D84 连续域的代表采样，非穷尽）；g −11/−5.5/0/9.25/17.75/40/120；r 0/12/
	## 100.5/450/900；各维单扫 + 代表组合。范围外类别（挥空/对地/越身/上升）
	## 如实记录，不冒充失败也不据此筛掉域内点。
	var categories := {}
	var failures: Array[String] = []
	var total := 0
	var no_contact_tags := {}
	# 1) k × 水平速度（g2/r350，双面向）。
	for k in range(20, 31):
		for vx in [-340.0, -216.67, -100.0, 0.0, 100.0, 216.67, 340.0]:
			for facing in [1, -1]:
				total += 1
				_sweep_case(k, vx, 2.0, 350.0, facing, categories, failures, no_contact_tags)
	# 2) g 维（k26/vx0/r350，双面向）：负 g 由纵向分离合法。
	for g in [-11.0, -5.5, 0.0, 9.25, 17.75, 40.0, 120.0]:
		for facing in [1, -1]:
			total += 1
			_sweep_case(26, 0.0, g, 350.0, facing, categories, failures, no_contact_tags)
	# 3) r 维（k26，vx 0 与 +340，g2，双面向）：含近墙钳制与远端。
	for r in [0.0, 12.0, 100.5, 450.0, 900.0]:
		for vx in [0.0, 340.0]:
			for facing in [1, -1]:
				total += 1
				_sweep_case(26, vx, 2.0, r, facing, categories, failures, no_contact_tags)
	# 4) 代表组合（非整数多维混合 + 近墙远速 + 背墙玩家）。
	for combo in [[24, -173.33, 9.25, 100.5, 1], [27, 255.5, -3.75, 899.25, -1], [29, -70.7, 118.5, 0.0, 1], [21, 340.0, 2.0, 900.0, -1]]:
		total += 1
		_sweep_case(combo[0], combo[1], combo[2], combo[3], combo[4], categories, failures, no_contact_tags)
	print("  sweep points=%d categories=%s no_contact_breakdown=%s" % [total, str(categories), str(no_contact_tags)])
	if failures.is_empty():
		_check(true, "domain sweep: every in-guarantee contact completes the exact six-hit route (%d guarantee points; out-of-scope categories recorded above, not failures)" % int(categories.get("guarantee", 0)))
	else:
		for entry in failures.slice(0, 12):
			print("  SWEEP-FAIL %s" % entry)
		_check(false, "domain sweep: %d/%d in-guarantee points failed (list above; fix or escalate, never shrink)" % [failures.size(), int(categories.get("guarantee", 0))])


# --- 保存/续跑等价（对空首击、跳消、Hitstop、弹地与落地边界）---

func _test_r4a_save_restore_equivalence() -> void:
	print("=== 保存/续跑等价：对空参考路线逐切点 clone→restore→续算 ===")
	## 参考路线的完整基线事件流与终点；每 5 帧一刀（另加首击/弹地/落地边界
	## 帧），切点处 clone_state → 新会话 restore_state → 续喂剩余输入，事件流
	## 与终点必须与不中断回放逐项一致（跳跃运动判定由已序列化状态导出）。
	var setup := _place_air(24, 0.0, 2.0, 350.0, 1)
	var probe := _probe_contact(_place_air(24, 0.0, 2.0, 350.0, 1))
	var plan := _r4a_plan(1, probe)
	# 基线：不中断回放。
	var base_session: CombatSession = setup["session"]
	var base_events: Array = []
	for frame in range(1, AIR_HORIZON + 1):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := base_session.player_move_id
		for event in base_session.step(input):
			base_events.append([frame, event.type, move_at_start, event.combo_hits, event.combo_end_reason])
	var base_final := {
		"player_position": base_session.player_position, "dummy_position": base_session.dummy_position,
		"dummy_state": base_session.dummy_state, "dummy_velocity": base_session.dummy_velocity,
	}
	# 边界帧：首击帧、弹地触点、玩家落地帧、倒地帧。
	var boundary_frames: Array[int] = [int(probe["frame"])]
	for entry in base_events:
		if entry[1] == CombatEvent.Type.BOUNCE_CONTACT or entry[1] == CombatEvent.Type.SPIKE_LANDED:
			boundary_frames.append(int(entry[0]))
	var splits: Array[int] = []
	for frame in range(5, AIR_HORIZON, 5):
		splits.append(frame)
	for extra in boundary_frames:
		if not splits.has(extra - 1) and not splits.has(extra) and extra > 1:
			splits.append(extra - 1)
	splits.sort()
	var mismatches: Array[String] = []
	for split in splits:
		var cut := _place_air(24, 0.0, 2.0, 350.0, 1)
		var cut_session: CombatSession = cut["session"]
		for frame in range(1, split + 1):
			var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
			cut_session.step(input)
		var snapshot := cut_session.clone_state()
		var branch := CombatSession.new()
		if not branch.restore_state(snapshot):
			mismatches.append("split %d: restore rejected" % split)
			continue
		var branch_events: Array = []
		for frame in range(split + 1, AIR_HORIZON + 1):
			var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
			var move_at_start := branch.player_move_id
			for event in branch.step(input):
				branch_events.append([frame, event.type, move_at_start, event.combo_hits, event.combo_end_reason])
		# 事件流逐项比较（切点之后部分）。
		var base_tail: Array = []
		for entry in base_events:
			if int(entry[0]) > split:
				base_tail.append(entry)
		if str(branch_events) != str(base_tail):
			mismatches.append("split %d: event stream diverges (%d vs %d events)" % [split, branch_events.size(), base_tail.size()])
		if branch.player_position != base_final["player_position"] or branch.dummy_position != base_final["dummy_position"] \
				or branch.dummy_state != base_final["dummy_state"] or branch.dummy_velocity != base_final["dummy_velocity"]:
			mismatches.append("split %d: endpoint state diverges" % split)
	if mismatches.is_empty():
		_check(true, "save/restore: %d cut points reproduce the uninterrupted replay event-for-event and endpoint-exact" % splits.size())
	else:
		for entry in mismatches.slice(0, 8):
			print("  RESTORE-FAIL %s" % entry)
		_check(false, "save/restore: %d/%d cut points diverged (list above)" % [mismatches.size(), splits.size()])


# --- 关键键连续成功区间（D72：只记录，不设旧 7F 门槛）---

func _test_r4a_key_windows() -> void:
	print("=== R4-A 关键键连续成功区间（±4F 逐帧，其余固定，k24 vx0 g2 r350 双面向）===")
	var keys := ["jc", "jC", "j214D", "5B", "214C", "~C"]
	for key in keys:
		var intervals: Array[String] = []
		for facing in [1, -1]:
			var hits: Array[int] = []
			for delta in range(-4, 5):
				var out := _r4a_attempt(24, 0.0, 2.0, 350.0, facing, {key: delta})
				if out["why"].is_empty():
					hits.append(delta)
			var text := ""
			var prev := -99
			for delta in hits:
				if prev == -99:
					text += "[%d" % delta
				elif delta > prev + 1:
					text += ",%d] ∪ [%d" % [prev, delta]
				prev = delta
			if prev == -99:
				text = "∅"
			else:
				text += ",%d]" % prev
			intervals.append("f%+d %s" % [facing, text])
		print("  key %-6s windows: %s" % [key, " | ".join(PackedStringArray(intervals))])
		_check(true, "window scan for %s recorded (continuous intervals above; local windows, not a full-route tolerance claim)" % key)


# --- 联合扰动（记录，不设旧 244 门槛）---

func _test_r4a_joint_perturbation() -> void:
	print("=== R4-A 六键联合 ±1F 扰动（64 向量 × 双面向 = 128）===")
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
			var out := _r4a_attempt(24, 0.0, 2.0, 350.0, facing, offsets)
			total += 1
			if out["why"].is_empty():
				success += 1
			else:
				var broken := "-"
				for hit in out["run"].get("hits", []):
					if not R4A_MOVES.has(str(hit["move"])):
						broken = str(hit["move"])
						break
				breakpoints[broken] = int(breakpoints.get(broken, 0)) + 1
	print("  joint ±1: %d/%d (denominator 64 vectors × 2 facings; breakpoints by first off-route hit: %s)" % [success, total, str(breakpoints)])
	_check(true, "joint perturbation recorded honestly (D72: 1F accepted, old 244/256 gate not applied)")


# --- 负例与范围外对照 ---

func _test_r4a_negatives() -> void:
	print("=== R4-A 负例：错档 / 错方向 / 早晚输入 / 对地接触 / 范围外对照 ===")
	## 错档：H38 起点用 G 时点（k26 接触 33.06 应选 H38）——诚实失败。
	var wrong_tier := _r4a_attempt_tier(26, "G")
	_check(wrong_tier.has("6A") and wrong_tier != R4A_MOVES,
		"negative: wrong tier (G timing on an H38 contact) breaks the route honestly (%s)" % str(wrong_tier))
	## 错方向：近距起点用 9（应 8）——诚实失败（出现 j6D 旁路）。
	var wrong_dir := _r4a_attempt_dir(26, false)
	_check(wrong_dir != R4A_MOVES,
		"negative: forward jump cancel on a close contact breaks the exact route (%s)" % str(wrong_dir))
	## 远距起点用 8（应 9）仍可成立——T28 是参考方法不是可行性分界，如实记录
	## 为合法成功，不冒充失败（D82/T28 语义）。
	var far_wrong_dir := _r4a_attempt_dir(24, true, 178.4)
	if far_wrong_dir == R4A_MOVES:
		_check(true, "observation: 8 on a far contact (gap≈28) may still complete legally (T28 is a reference, not a feasibility boundary)")
	## 跳消过早/过晚：脱离准确六击。
	var early_jc := _r4a_attempt(24, 0.0, 2.0, 350.0, 1, {"jc": -10})
	_check((early_jc["run"].get("moves", []) as Array) != R4A_MOVES,
		"negative: jump cancel 10F early breaks the route honestly (%s)" % str(early_jc["run"].get("moves", [])))
	var late_jc := _r4a_attempt(24, 0.0, 2.0, 350.0, 1, {"jc": 25})
	_check((late_jc["run"].get("moves", []) as Array) != R4A_MOVES,
		"negative: jump cancel 25F late breaks the route honestly (%s)" % str(late_jc["run"].get("moves", [])))
	## 5B 过早（弹地/恢复前缓存过期）与过晚（追击窗关闭）。
	var early_b := _r4a_attempt(24, 0.0, 2.0, 350.0, 1, {"5B": -12})
	_check(((early_b["run"].get("moves", []) as Array).size() < 6),
		"negative: 5B pressed 12F early never lands in-combo (%s)" % str(early_b["run"].get("moves", [])))
	var late_b := _r4a_attempt(24, 0.0, 2.0, 350.0, 1, {"5B": 8})
	_check((late_b["run"].get("moves", []) as Array) != R4A_MOVES,
		"negative: 5B pressed 8F late does not complete the six-hit route (%s)" % str(late_b["run"].get("moves", [])))
	## j214D 过晚：弹地窗口过期前 5B 无法命中。
	var late_d := _r4a_attempt(24, 0.0, 2.0, 350.0, 1, {"j214D": 7})
	_check((late_d["run"].get("moves", []) as Array) != R4A_MOVES,
		"negative: j214D final key 7F late breaks the route honestly (%s)" % str(late_d["run"].get("moves", [])))
	## 对地接触：k30 快速接近起点在接触前落地（探针报 grounded）——不得记为
	## 对空成功；严格判据拒绝其为六击对空路线。
	var grounded_probe := _probe_contact(_place_air(30, -200.0, 100.0, 350.0, 1))
	_check(grounded_probe.get("contact", false) and not grounded_probe.get("airborne", true),
		"negative: a start that lands before contact is probed as a grounded contact (对地), not anti-air (%s)" % str(grounded_probe))
	var grounded_run := _run_air(_r4a_plan(1, grounded_probe), _place_air(30, -200.0, 100.0, 350.0, 1))
	var grounded_why := _r4a_strict_failures(grounded_run, "grounded")
	_check(not grounded_why.is_empty(),
		"negative: the strict judge refuses the grounded-contact start as an anti-air route (%s)" % " | ".join(PackedStringArray(grounded_why.slice(0, 3))))
	## 范围外对照：上升起点（k19，越出 D84 域）与超域间距（g140）均如实挥空，
	## 不伪造成对空失败或成功。
	var rising_probe := _probe_contact(_place_air(19, 0.0, 2.0, 350.0, 1))
	_check(rising_probe.is_empty(),
		"contrast: a rising start (k19, out of domain) whiffs honestly (no fabricated contact)")
	var far_probe := _probe_contact(_place_air(24, 0.0, 140.0, 350.0, 1))
	_check(far_probe.is_empty(),
		"contrast: an out-of-domain gap (g=140 > 120) whiffs honestly")


## 强制档/强制方向的回放（负例用）：绕过探针自动选择。
func _r4a_attempt_tier(k: int, tier: String) -> Array:
	var probe := _probe_contact(_place_air(k, 0.0, 2.0, 350.0, 1))
	var plan := _r4a_plan_forced(1, probe, tier, null)
	return _run_air(plan, _place_air(k, 0.0, 2.0, 350.0, 1))["moves"]


func _r4a_attempt_dir(k: int, use_eight: bool, vx := 0.0) -> Array:
	var probe := _probe_contact(_place_air(k, vx, 2.0, 350.0, 1))
	var plan := _r4a_plan_forced(1, probe, null, use_eight)
	return _run_air(plan, _place_air(k, vx, 2.0, 350.0, 1))["moves"]


## _r4a_plan 的受控变体：tier/eight 传 null 时按探针结果自动选择。
func _r4a_plan_forced(facing: int, contact: Dictionary, force_tier: Variant, force_eight: Variant) -> Dictionary:
	var h: float = contact["h"]
	var tier: String = force_tier if force_tier != null else ("G" if h >= 36.0 else ("H38" if h >= 30.0 else "H21"))
	var use_eight: bool = force_eight if force_eight != null else contact["front_gap"] < 28.0
	var probe_override := {
		"h": (100.0 if tier == "G" else (35.0 if tier == "H38" else 5.0)) if force_tier != null else h,
		"front_gap": (1.0 if use_eight else 100.0) if force_eight != null else contact["front_gap"],
		"frame": contact["frame"],
	}
	return _r4a_plan(facing, probe_override)
