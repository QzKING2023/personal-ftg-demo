extends SceneTree

## CombatSession 前缀恢复 seam 的差分证明。
## 对每条输入序列的每个切分帧：clone_state → restore_state → 继续喂入剩余
## 输入，与从头运行逐帧对比事件签名、伤害、命中数、结束原因、settlement_state
## 与完整 clone 状态。settlement_state 只参与等价性判断；恢复格式以
## clone_state 的版本化字典为准。恢复目标分三种：
##   fresh——全新会话（最常见口径）；
##   dirty——先跑过一段无关输入、带有残留历史的会话（暴露忘记重置的字段）；
##   self ——快照来源会话自身（Solver 复用会话对象的口径）。
## 序列覆盖：普通链、236C 两段/特殊进入/目押、214C Rekka 两分支、投技
## 成立/拆投/投距外/组合等待、跳跃与空中技落地、冲刺、蹲姿、木桩攻击与
## 双方防御分支、多种子随机短序列。
## 运行：Godot --headless --path . -s res://tests/test_combat_session_restore.gd

const MODE_FRESH := 0
const MODE_DIRTY := 1
const MODE_SELF := 2
const MODE_NAMES := ["fresh", "dirty", "self"]

var _failures := 0
var _dirty_inputs: Array[FrameInput] = []


func _initialize() -> void:
	_dirty_inputs = _seq_throw_in_range(false)
	_test_format_contract()
	_test_rejects_bad_state()
	_test_all_sequences()
	_test_coverage_gate()
	_test_random_seeds()
	print("TOTAL failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# 序列差分主体
# ---------------------------------------------------------------------------

func _test_all_sequences() -> void:
	_check_sequence("fixed mixed (jump/guard/dummy)", _fixed_inputs(), func() -> CombatSession:
		return _setup(26.0, 1))
	_check_sequence("236C two-segment > special-entry 5D > link 5B (facing 1)",
		_seq_236c_entry(1), func() -> CombatSession: return _setup(26.0, 1))
	_check_sequence("236C two-segment > special-entry 5D > link 5B (facing -1)",
		_seq_236c_entry(-1), func() -> CombatSession: return _setup(26.0, -1))
	_check_sequence("2C > 214C > ~B extended float > 5B link",
		_seq_rekka("B", 95), func() -> CombatSession: return _setup(12.0, 1))
	_check_sequence("2C > 214C > ~C spike fall",
		_seq_rekka("C", 75), func() -> CombatSession: return _setup(12.0, 1))
	_check_sequence("214C ground > ~B knockdown (facing -1)",
		_seq_214c_ground_b(), func() -> CombatSession: return _setup(26.0, -1))
	_check_sequence("throw B+C lands", _seq_throw_in_range(false), func() -> CombatSession:
		return _setup(12.0, 1))
	_check_sequence("throw B+C teched", _seq_throw_in_range(true), func() -> CombatSession:
		return _setup(12.0, 1))
	_check_sequence("236C seg1 whiff > seg2 grounded > GROUND_SLIDE > slide 5D",
		_seq_236c_slide(), func() -> CombatSession: return _setup(60.0, 1))
	_check_sequence("5D into slide with no slide profile (HIT_MISS, injected table)",
		_seq_236c_slide(), _setup_injected_slide_gap)
	_check_sequence("5A > 5B chain > 5D normal source > 5B link gap (LINK_FAILED)",
		_seq_link_fail(), func() -> CombatSession: return _setup(26.0, 1))
	_check_sequence("crouch 2C low-float sweep", _seq_low_float(), func() -> CombatSession:
		return _setup(14.0, 1))
	_check_sequence("6A launcher > dummy air recovers", _seq_air_recover(), func() -> CombatSession:
		return _setup(26.0, 1))
	_check_sequence("player standing guard blocks dummy 5A (+ guard rejects)",
		_seq_block_dummy(), func() -> CombatSession: return _setup(26.0, 1))
	_check_sequence("dummy 5A hits neutral player", _seq_player_hit(), func() -> CombatSession:
		return _setup(26.0, 1))
	_check_sequence("player 5A/5B blocked by dummy guard (+ link gap)",
		_seq_attack_blocked(), func() -> CombatSession: return _setup(26.0, 1))
	_check_sequence("throw B+C out of range", _seq_throw_far(), func() -> CombatSession:
		return _setup(130.0, 1))
	_check_sequence("throw delayed B..C combination wait", _seq_throw_delayed(),
		func() -> CombatSession: return _setup(12.0, 1))
	_check_sequence("jump > jC > land > jump > j2D > 214C", _seq_air_route(),
		func() -> CombatSession: return _setup(26.0, 1))
	_check_sequence("dash 66/44 + crouch 2B", _seq_dash_crouch(), func() -> CombatSession:
		return _setup(26.0, 1))
	## 连段路线票据 01：R4-G 六击弹地倒地路线、再弹地链与 D 接地零水平——
	## 弹地窗口/触地/消费与恢复边界的快照续跑等价（每帧切点差分）。
	_check_sequence("R4-G 6A>jc.jC>j214D>5B>214C~C (facing 1)", _seq_r4g(1),
		func() -> CombatSession: return _setup(14.0, 1))
	_check_sequence("R4-G 6A>jc.jC>j214D>5B>214C~C (facing -1)", _seq_r4g(-1),
		func() -> CombatSession: return _setup(14.0, -1))
	_check_sequence("rebounce 5B>5C>6A>jc.jB>j214D>6A>jc.jC>j214D", _seq_rebounce(),
		func() -> CombatSession: return _setup(26.0, 1))
	_check_sequence("grounded D zero-horizontal 5D + j214D dive", _seq_d_zero(),
		func() -> CombatSession: return _setup(40.0, 1))
	_check_sequence("dummy attacks vs player guard + dummy guard block branch",
		_seq_guard_mixup(), func() -> CombatSession: return _setup(26.0, 1))


func _test_random_seeds() -> void:
	for seed_value in [0x5EED_2026, 7, 1234, 0xBEEF]:
		var label := "random seed 0x%X" % seed_value
		var inputs := _random_inputs(seed_value)
		_check_sequence(label, inputs, func() -> CombatSession: return _setup(26.0, 1))


## 每个切分帧（0..N 含两端）× 三种恢复目标；长序列的 dirty/self 按步幅采样。
func _check_sequence(label: String, inputs: Array[FrameInput], setup: Callable) -> void:
	var reference: CombatSession = setup.call()
	var expected: Array[Dictionary] = []
	for input in inputs:
		expected.append(_observe(reference, input))

	var checks := 0
	var failures := 0
	var lines: Array[String] = []
	var alt_stride := 1 if inputs.size() <= 60 else 3
	for split in range(inputs.size() + 1):
		var branch: CombatSession = setup.call()
		for i in range(split):
			branch.step(inputs[i])
		var snapshot := branch.clone_state()
		for mode in range(3):
			if mode != MODE_FRESH and alt_stride > 1 and split % alt_stride != 0:
				continue
			var target: CombatSession
			match mode:
				MODE_FRESH:
					target = setup.call()
				MODE_DIRTY:
					target = setup.call()
					for i in range(mini(16, _dirty_inputs.size())):
						target.step(_dirty_inputs[i])
				MODE_SELF:
					target = branch
			if not target.restore_state(snapshot):
				failures += 1
				lines.append("split=%d mode=%s restore_state returned false" % [split, MODE_NAMES[mode]])
				continue
			checks += 1
			if target.clone_state() != snapshot:
				failures += 1
				lines.append("split=%d mode=%s round-trip clone mismatch" % [split, MODE_NAMES[mode]])
			for i in range(split, inputs.size()):
				var actual := _observe(target, inputs[i])
				var exp: Dictionary = expected[i]
				var dims: Array[String] = []
				if actual["events"] != exp["events"]:
					dims.append("events")
				if not is_equal_approx(float(actual["damage"]), float(exp["damage"])):
					dims.append("damage")
				if int(actual["hits"]) != int(exp["hits"]):
					dims.append("hits")
				if actual["end_reasons"] != exp["end_reasons"]:
					dims.append("end_reasons")
				if actual["settlement"] != exp["settlement"]:
					dims.append("settlement")
				if actual["state"] != exp["state"]:
					dims.append("state")
				checks += 6
				if not dims.is_empty():
					failures += dims.size()
					lines.append("split=%d mode=%s frame=%d dims=%s" % [
						split, MODE_NAMES[mode], i + 1, ",".join(dims)])

	if failures == 0:
		print("PASS  %s: splits=%d checks=%d" % [label, inputs.size() + 1, checks])
	else:
		_failures += failures
		print("FAIL  %s: %d/%d checks failed" % [label, failures, checks])
		for line in lines.slice(0, 10):
			print("      " + line)
		if lines.size() > 10:
			print("      ... and %d more" % (lines.size() - 10))


func _observe(session: CombatSession, input: FrameInput) -> Dictionary:
	var events := session.step(input)
	var damage := 0.0
	var hits := 0
	var end_reasons: Array[int] = []
	var event_signatures: Array[Dictionary] = []
	for event in events:
		event_signatures.append(_event_signature(event))
		if event.type == CombatEvent.Type.HIT:
			damage += event.damage
			hits += 1
		elif event.type == CombatEvent.Type.COMBO_ENDED:
			end_reasons.append(event.combo_end_reason)
	return {
		"events": event_signatures,
		"damage": damage,
		"hits": hits,
		"end_reasons": end_reasons,
		"settlement": session.settlement_state(),
		"state": session.clone_state(),
	}


func _event_signature(event: CombatEvent) -> Dictionary:
	return {
		"type": event.type,
		"direction": event.direction,
		"damage": event.damage,
		"combo_hits": event.combo_hits,
		"is_counter": event.is_counter,
		"combo_end_reason": event.combo_end_reason,
		"throw_fail_reason": event.throw_fail_reason,
		"link_fail_reason": event.link_fail_reason,
		"link_move_id": event.link_move_id,
		"guard_posture": event.guard_posture,
		"block_freeze_frames": event.block_freeze_frames,
		"block_stun_frames": event.block_stun_frames,
		"block_pushback_px_s": event.block_pushback_px_s,
		"guard_reject_reason": event.guard_reject_reason,
		"rekka_branch": event.rekka_branch,
		"rekka_move_id": event.rekka_move_id,
		"move_segment": event.move_segment,
	}


# ---------------------------------------------------------------------------
# 格式契约与拒绝路径
# ---------------------------------------------------------------------------

func _test_format_contract() -> void:
	var session := _setup(26.0, 1)
	session.step(FrameInput.make(0, false, "A"))
	var snapshot := session.clone_state()
	_check(snapshot.get("format", "") == "CombatSessionState/v1", "format: versioned clone format")
	for domain in ["player", "dummy", "combo", "player_move", "input", "keys", "action_buffer",
			"jump_slot", "direction", "cancel", "rekka", "special_entry", "clock", "flags"]:
		_check(snapshot.has(domain), "format: includes domain '%s'" % domain)
	var restored := _setup(130.0, -1)
	_check(restored.restore_state(snapshot), "format: restores into a differently-configured session of the same table")


func _test_rejects_bad_state() -> void:
	var session := _setup(26.0, 1)
	session.step(FrameInput.make(0, false, "A"))
	var snapshot := session.clone_state()

	var bad_format := snapshot.duplicate(true)
	bad_format["format"] = "CombatSessionState/v0"
	var rejects_bad_format := not session.restore_state(bad_format)
	_check(rejects_bad_format, "reject: wrong format string returns false")

	var bad_move := snapshot.duplicate(true)
	var player_state: Dictionary = bad_move["player"]
	player_state["move_id"] = "NO_SUCH_MOVE"
	_check(not session.restore_state(bad_move), "reject: unknown move id returns false")

	## 拒绝路径不得留下半恢复状态：会话仍按原历史继续。
	var untouched := _setup(26.0, 1)
	untouched.step(FrameInput.make(0, false, "A"))
	var bad_table := snapshot.duplicate(true)
	var config: Dictionary = bad_table["config"]
	config["direction_retention"] = 999
	untouched.restore_state(bad_table)
	var clean := _setup(26.0, 1)
	clean.step(FrameInput.make(0, false, "A"))
	untouched.step(FrameInput.new())
	clean.step(FrameInput.new())
	_check(_observe(untouched, FrameInput.new())["events"] == _observe(clean, FrameInput.new())["events"],
		"reject: failed restore leaves session on its original timeline")


# ---------------------------------------------------------------------------
# 输入序列构造（纯帧号函数，参考运行与恢复运行喂完全相同的输入流）
# ---------------------------------------------------------------------------

func _setup(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(dx * facing, 0.0)
	if facing == -1:
		session.player_facing = -1
	return session


## 注入表：私有化的 5D 副本去掉 GROUND_SLIDE 资料（N3 口径）。ResourceLoader
## 返回共享缓存实例，必须 duplicate 后再改，避免污染同进程其他会话的表。
func _setup_injected_slide_gap() -> CombatSession:
	var table := MoveData.default_table()
	var five_d := (table["5D"] as MoveData).duplicate(true)
	var kept: Array[HitProfile] = []
	for profile in five_d.hit_profiles:
		if profile.target_state != HitProfile.TargetState.GROUND_SLIDE:
			kept.append(profile)
	five_d.hit_profiles = kept
	table["5D"] = five_d
	var session := CombatSession.new(table)
	## 12×20 尺度：滑行入口间距 60（段1触及外/段2触及内）。
	session.dummy_position = session.player_position + Vector2(60.0, 0.0)
	return session


func _rel(digit: int, key: String, facing: int, guard: int = 0, dummy_req := "", tech := false) -> FrameInput:
	var axis := 0
	if digit == 3 or digit == 6 or digit == 9:
		axis = facing
	elif digit == 1 or digit == 4 or digit == 7:
		axis = -facing
	var input := FrameInput.make(axis, false, key, digit >= 1 and digit <= 3, dummy_req, guard)
	input.dummy_tech_request = tech
	return input


func _multi_key(keys: Array, guard: int = 0, tech := false) -> FrameInput:
	var input := FrameInput.new()
	for key in keys:
		input.pressed_action_keys.append(key)
		input.held_action_keys.append(key)
	input.dummy_guard_request = guard
	input.dummy_tech_request = tech
	return input


func _fixed_inputs() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 73):
		var input := FrameInput.new()
		if frame == 1:
			input = FrameInput.make(0, false, "A")
		elif frame == 7:
			input = FrameInput.make(1, true)
		elif frame == 12:
			input = FrameInput.make(-1, false, "B", true)
		elif frame == 18:
			input = FrameInput.make(1, false, "C")
		elif frame == 26:
			input = FrameInput.make(0, false, "D")
		elif frame == 42:
			input = FrameInput.make(0, false, "", false, "5A")
		elif frame >= 43 and frame <= 46:
			input = FrameInput.make(1 if frame % 2 == 0 else -1, false, "", frame == 44)
		elif frame == 55:
			input = FrameInput.make(0, false, "A", false, "", CombatSession.GuardPosture.STANDING)
		inputs.append(input)
	return inputs


## 236C 两段命中 → 特殊进入 5D → 收招后目押 5B（票据 05 R1 时间轴）。
func _seq_236c_entry(facing: int) -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 111):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 3
		elif frame == 3:
			digit = 6
		elif frame == 4:
			key = "C"
		elif frame == 26:
			key = "D"
		elif frame == 66:
			key = "B"
		inputs.append(_rel(digit, key, facing))
	return inputs


## 2C 起手 → 214C → 接续窗口内按 branch 键（~B 延长浮空 / ~C 向下击落）→ 尾段目押。
func _seq_rekka(branch: String, length: int) -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, length + 1):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		elif frame == 15 or frame == 16 or frame == 17:
			digit = [2, 1, 4][frame - 15]
		elif frame == 19:
			key = "C"
		elif frame == 32:
			key = branch
		elif frame == 70:
			key = "B"
		inputs.append(_rel(digit, key, 1))
	return inputs


func _seq_214c_ground_b() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 57):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 1
		elif frame == 3:
			digit = 4
		elif frame == 4:
			key = "C"
		elif frame == 16:
			key = "B"
		inputs.append(_rel(digit, key, -1))
	return inputs


## 236C 段 1 挥空、段 2 命中地面目标 → 击飞触地 GROUND_SLIDE → 窗口内按 D 捞起。
func _seq_236c_slide() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 91):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 3
		elif frame == 3:
			digit = 6
		elif frame == 4:
			key = "C"
		elif frame == 30:
			key = "D"
		inputs.append(_rel(digit, key, 1))
	return inputs


## 普通来源 5D 不取得反向 5B 连接边：5A > 5B > 5D(链式) > 后摇末按 B 报 CONFIGURATION_GAP。
func _seq_link_fail() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 81):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 5:
			key = "B"
		elif frame == 21:
			key = "D"
		elif frame == 62:
			key = "B"
		inputs.append(_rel(5, key, 1))
	return inputs


## 蹲姿 2C 低浮空扫倒：命中地面目标 → LOW_FLOAT_SWEEP → 触地同帧转普通倒地。
func _seq_low_float() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 61):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		inputs.append(_rel(digit, key, 1))
	return inputs


## 6A 专用击飞：上抛 560 px/s 飞行约 48 帧 > untech 36 → 木桩空中受身。
func _seq_air_recover() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 71):
		var digit := 6 if frame == 1 else 5
		var key := "A" if frame == 1 else ""
		inputs.append(_rel(digit, key, 1))
	return inputs


## 玩家站防挡下木桩 5A：BLOCKED + 防御硬直 + 推退；出招中的防御请求按 BUSY 拒绝。
func _seq_block_dummy() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 31):
		var digit := 4 if frame >= 3 and frame <= 14 else 5
		var guard := CombatSession.GuardPosture.STANDING if frame >= 6 and frame <= 9 else 0
		var dummy_req := "5A" if frame == 4 else ""
		inputs.append(_rel(digit, "", 1, guard, dummy_req))
	return inputs


## 木桩 5A 命中中立玩家：PLAYER_HIT + 玩家受击硬直。
func _seq_player_hit() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 31):
		var dummy_req := "5A" if frame == 4 else ""
		inputs.append(_rel(5, "", 1, 0, dummy_req))
	return inputs


## 玩家 5A/5B 被木桩站防挡下：ATTACK_BLOCKED + 木桩被防硬直；后摇中目押 B 报连接缺口。
func _seq_attack_blocked() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 41):
		var key := ""
		if frame == 2:
			key = "A"
		elif frame == 25:
			key = "B"
		var guard := CombatSession.GuardPosture.STANDING if frame <= 38 else 0
		inputs.append(_rel(5, key, 1, guard))
	return inputs


func _seq_throw_in_range(tech: bool) -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 31):
		if frame == 1:
			inputs.append(_multi_key(["B", "C"], 0, tech))
		else:
			inputs.append(_rel(5, "", 1, 0, "", tech))
	return inputs


func _seq_throw_far() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 25):
		if frame == 1:
			inputs.append(_multi_key(["B", "C"]))
		else:
			inputs.append(_rel(5, "", 1))
	return inputs


## B 先按住 4 帧、第 3 帧补按 C：组合配对成立走普通投；对照组合等待路径。
func _seq_throw_delayed() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 25):
		if frame == 1 or frame == 2:
			inputs.append(_rel(5, "B", 1))
		elif frame == 3 or frame == 4:
			inputs.append(_rel(5, "C", 1))
		else:
			inputs.append(_rel(5, "", 1))
	return inputs


## 第一跳 jC 空中技落地恢复；第二跳 j2D（下+D）→ 落地后搓 214C。
func _seq_air_route() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 81):
		var digit := 5
		var key := ""
		var jump := false
		if frame == 2 or frame == 36:
			jump = true
		elif frame == 12:
			key = "C"
		elif frame == 45:
			digit = 2
			key = "D"
		elif frame == 70 or frame == 71 or frame == 72:
			digit = [2, 1, 4][frame - 70]
		elif frame == 73:
			key = "C"
		var input := _rel(digit, key, 1)
		if jump:
			input.jump_pressed = true
			input.up_held = true
		inputs.append(input)
	return inputs


func _seq_dash_crouch() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 41):
		var digit := 5
		var key := ""
		if frame == 1 or frame == 3:
			digit = 6
		elif frame == 16 or frame == 18:
			digit = 4
		elif frame == 24:
			digit = 2
		elif frame == 26:
			digit = 2
			key = "B"
		inputs.append(_rel(digit, key, 1))
	return inputs


func _seq_guard_mixup() -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	for frame in range(1, 51):
		var digit := 5
		var key := ""
		var dummy_req := ""
		var guard := 0
		if frame == 5 or frame == 25:
			dummy_req = "5A"
		if frame >= 4 and frame <= 12:
			digit = 4
		elif frame == 20:
			key = "A"
		elif frame == 32:
			key = "A"
		elif frame == 40:
			key = "B"
		if frame >= 30 and frame <= 48:
			guard = CombatSession.GuardPosture.STANDING
		inputs.append(_rel(digit, key, 1, guard, dummy_req))
	return inputs


func _random_inputs(seed_value: int) -> Array[FrameInput]:
	var inputs: Array[FrameInput] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for frame in range(36):
		var axis := rng.randi_range(-1, 1)
		var jump := rng.randf() < 0.08
		var keys: Array = []
		if rng.randf() < 0.16:
			keys = [ ["A", "B", "C", "D"][rng.randi_range(0, 3)] ]
			if rng.randf() < 0.2:
				keys = ["B", "C"]
		var down := rng.randf() < 0.22
		var dummy_request := "5A" if frame == 20 else ""
		var guard := 0
		var guard_roll := rng.randf()
		if frame >= 25 and frame <= 28:
			guard = CombatSession.GuardPosture.STANDING if guard_roll < 0.5 else CombatSession.GuardPosture.CROUCH
		var input := FrameInput.make(axis, jump, "", down, dummy_request, guard)
		for key in keys:
			input.pressed_action_keys.append(key)
			input.held_action_keys.append(key)
		inputs.append(input)
	return inputs


# ---------------------------------------------------------------------------
# 覆盖门控：差分通过 ≠ 证明有效。断言序列集合确实到达全部异态状态与事件，
# 防止未来改输入时把证明空洞化。
# ---------------------------------------------------------------------------

func _test_coverage_gate() -> void:
	var cases := [
		["fixed", _fixed_inputs(), func() -> CombatSession: return _setup(26.0, 1)],
		["236c-entry", _seq_236c_entry(1), func() -> CombatSession: return _setup(26.0, 1)],
		["236c-slide", _seq_236c_slide(), func() -> CombatSession: return _setup(60.0, 1)],
		["slide-gap", _seq_236c_slide(), _setup_injected_slide_gap],
		["rekka-b", _seq_rekka("B", 95), func() -> CombatSession: return _setup(12.0, 1)],
		["rekka-c", _seq_rekka("C", 75), func() -> CombatSession: return _setup(12.0, 1)],
		["214c-ground", _seq_214c_ground_b(), func() -> CombatSession: return _setup(26.0, -1)],
		["throw", _seq_throw_in_range(false), func() -> CombatSession: return _setup(12.0, 1)],
		["throw-tech", _seq_throw_in_range(true), func() -> CombatSession: return _setup(12.0, 1)],
		["throw-far", _seq_throw_far(), func() -> CombatSession: return _setup(130.0, 1)],
		["throw-delayed", _seq_throw_delayed(), func() -> CombatSession: return _setup(12.0, 1)],
		["air-route", _seq_air_route(), func() -> CombatSession: return _setup(26.0, 1)],
		["dash-crouch", _seq_dash_crouch(), func() -> CombatSession: return _setup(26.0, 1)],
		["guard-mixup", _seq_guard_mixup(), func() -> CombatSession: return _setup(26.0, 1)],
		["link-fail", _seq_link_fail(), func() -> CombatSession: return _setup(26.0, 1)],
		["low-float", _seq_low_float(), func() -> CombatSession: return _setup(14.0, 1)],
		["air-recover", _seq_air_recover(), func() -> CombatSession: return _setup(26.0, 1)],
		["block-dummy", _seq_block_dummy(), func() -> CombatSession: return _setup(26.0, 1)],
		["player-hit", _seq_player_hit(), func() -> CombatSession: return _setup(26.0, 1)],
		["attack-blocked", _seq_attack_blocked(), func() -> CombatSession: return _setup(26.0, 1)],
	]
	var seen := _empty_coverage()
	for case in cases:
		var merged := _collect_coverage(case[1], case[2])
		for group in seen.keys():
			for item in merged[group]:
				seen[group][item] = true

	var required_events: Array = [
		CombatEvent.Type.HIT, CombatEvent.Type.HIT_MISS, CombatEvent.Type.BLOCKED,
		CombatEvent.Type.ATTACK_BLOCKED, CombatEvent.Type.DUMMY_GUARD_REJECTED,
		CombatEvent.Type.PLAYER_HIT,
		CombatEvent.Type.HITSTOP_STARTED, CombatEvent.Type.HITSTOP_ENDED,
		CombatEvent.Type.COMBO_ENDED, CombatEvent.Type.DUMMY_RECOVERED,
		CombatEvent.Type.THROW_HIT, CombatEvent.Type.THROW_TECHED, CombatEvent.Type.THROW_FAILED,
		CombatEvent.Type.DASH_STARTED, CombatEvent.Type.LINK_FAILED,
		CombatEvent.Type.LOW_FLOAT_LANDED, CombatEvent.Type.REKKA_BRANCH_LOCKED,
		CombatEvent.Type.SPIKE_LANDED, CombatEvent.Type.SLIDE_STARTED,
	]
	var required_states: Array = [
		CombatSession.DummyState.GROUND_HITSTUN, CombatSession.DummyState.AIR_HITSTUN,
		CombatSession.DummyState.AIR_RECOVERED, CombatSession.DummyState.KNOCKED_DOWN,
		CombatSession.DummyState.LOW_FLOAT_SWEEP, CombatSession.DummyState.SPIKE_FALL,
		CombatSession.DummyState.LOW_FLOAT_TO_SLIDE, CombatSession.DummyState.GROUND_SLIDE,
	]
	var required_phases: Array = [
		CombatSession.PlayerPhase.STARTUP, CombatSession.PlayerPhase.ACTIVE,
		CombatSession.PlayerPhase.RECOVERY,
	]
	var required_flags: Array = [
		"hitstop_active", "player_airborne", "player_crouching", "player_guarding",
		"player_guard_stun", "player_hitstun", "prejump", "landing_recovery", "dash",
		"combo_active", "dummy_guarding", "dummy_blockstun", "dummy_airborne",
		"knockdown_timer", "slide_timer", "buffered_key", "jump_slot", "cancel_open",
		"rekka_window", "special_entry", "direction_history", "starter_grade_set",
		"damage_scale_below_one", "dummy_move_active",
	]
	for item in required_events:
		_check(seen["events"].has(item), "coverage: event %s observed" % item)
	for item in required_states:
		_check(seen["dummy_states"].has(item), "coverage: dummy state %s observed" % item)
	for item in required_phases:
		_check(seen["player_phases"].has(item), "coverage: player phase %s observed" % item)
	for item in required_flags:
		_check(seen["flags"].has(item), "coverage: flag %s observed" % item)


func _empty_coverage() -> Dictionary:
	return {"events": {}, "dummy_states": {}, "player_phases": {}, "flags": {}}


func _collect_coverage(inputs: Array[FrameInput], setup: Callable) -> Dictionary:
	var session: CombatSession = setup.call()
	var seen := _empty_coverage()
	for input in inputs:
		for event in session.step(input):
			seen["events"][event.type] = true
		seen["dummy_states"][session.dummy_state] = true
		seen["player_phases"][session.player_phase] = true
		_mark_flags(seen, session)
	return seen


func _mark_flags(seen: Dictionary, session: CombatSession) -> void:
	var direct := {
		"hitstop_active": session.hitstop_active(),
		"player_airborne": not session.player_on_ground,
		"player_crouching": session.player_crouching,
		"player_guarding": session.player_guard != CombatSession.GuardPosture.NONE,
		"player_guard_stun": session.player_guard_stun_left > 0,
		"player_hitstun": session.player_hitstun_left > 0,
		"prejump": session.player_prejump_left > 0,
		"landing_recovery": session.player_landing_recovery_left > 0,
		"dash": session.player_dash_left > 0,
		"combo_active": session.combo_active,
		"dummy_guarding": session.dummy_guard != CombatSession.GuardPosture.NONE,
		"dummy_blockstun": session.dummy_blockstun_left > 0,
		"dummy_airborne": not session.dummy_on_ground,
		"knockdown_timer": session.dummy_knockdown_left > 0,
		"slide_timer": session.dummy_slide_left > 0,
		"dummy_move_active": session.dummy_move_id != "",
	}
	for key in direct:
		if direct[key]:
			seen["flags"][key] = true
	var snap := session.debug_snapshot()
	if String(snap.get("buffered_key", "")) != "":
		seen["flags"]["buffered_key"] = true
	if snap.get("jump_slot_age", -1) >= 0:
		seen["flags"]["jump_slot"] = true
	if bool(snap.get("cancel_open", false)):
		seen["flags"]["cancel_open"] = true
	if int(snap.get("rekka_window_left", -1)) >= 0:
		seen["flags"]["rekka_window"] = true
	if bool(snap.get("special_entry_open", false)):
		seen["flags"]["special_entry"] = true
	if String(snap.get("direction_sequence", "")) != "":
		seen["flags"]["direction_history"] = true
	if int(snap.get("starter_grade", 0)) != MoveData.StarterGrade.UNSET:
		seen["flags"]["starter_grade_set"] = true
	if float(snap.get("damage_scale", 1.0)) < 1.0:
		seen["flags"]["damage_scale_below_one"] = true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


## 连段路线票据 01：R4-G 固定参考（与 test_ground_bounce_finish 同一 G 节奏）。
func _r4g_key(key: String, axis := 0, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	input.move_axis = axis
	input.down_held = down
	return input


func _seq_r4g(facing: int) -> Array[FrameInput]:
	var back := -facing
	var steps := {
		1: _r4g_key("A", facing),
		2: FrameInput.make(facing),
		11: FrameInput.make(0, true),
		34: _r4g_key("C"),
		44: FrameInput.make(0, false, "", true),
		45: FrameInput.make(back, false, "", true),
		46: FrameInput.make(back),
		47: _r4g_key("D", back),
		78: _r4g_key("B"),
		87: FrameInput.make(0, false, "", true),
		88: FrameInput.make(back, false, "", true),
		89: FrameInput.make(back),
		90: _r4g_key("C", back),
		114: _r4g_key("C"),
	}
	var inputs: Array[FrameInput] = []
	for frame in range(1, 150):
		inputs.append(steps[frame] if steps.has(frame) else FrameInput.new())
	return inputs


## 再弹地链（6A 弹地追击 > jc.jC > 第二次 j214D）。
func _seq_rebounce() -> Array[FrameInput]:
	var steps := {
		1: _r4g_key("B"), 16: _r4g_key("C"),
		30: _r4g_key("A", 1), 31: FrameInput.make(1),
		48: FrameInput.make(0, true),
		62: _r4g_key("B"),
		76: FrameInput.make(0, false, "", true), 77: FrameInput.make(-1, false, "", true),
		78: FrameInput.make(-1), 79: _r4g_key("D", -1),
		105: _r4g_key("A", 1),
		126: FrameInput.make(0, true),
		131: _r4g_key("C"),
		145: FrameInput.make(0, false, "", true), 146: FrameInput.make(-1, false, "", true),
		147: FrameInput.make(-1), 148: _r4g_key("D", -1),
	}
	var inputs: Array[FrameInput] = []
	for frame in range(1, 200):
		inputs.append(steps[frame] if steps.has(frame) else FrameInput.new())
	return inputs


## D 接地零水平：地面 5D 与独立跳 j214D 的对地命中（零水平 + 弹地入口）。
func _seq_d_zero() -> Array[FrameInput]:
	var steps := {
		1: _r4g_key("D"),
		2: FrameInput.make(0, true),
		13: FrameInput.make(0, false, "", true),
		14: FrameInput.make(-1, false, "", true),
		15: FrameInput.make(-1),
		16: _r4g_key("D", -1),
	}
	var inputs: Array[FrameInput] = []
	for frame in range(1, 130):
		inputs.append(steps[frame] if steps.has(frame) else FrameInput.new())
	return inputs
