extends SceneTree
## 搓招与空中运动诊断回路（执行路径阶段 1 的反馈回路）。
## 按用户症状构造确定性 FrameInput 序列（物理键语义与训练场适配一致：
## A/D=横轴、S=下、Space=跳跃、U/I/K/J=动作 A/B/C/D），逐帧喂给 CombatSession，
## 打印诊断记录——物理键、相对方向序列、面向、识别招式、缓存剩余、取消资格、
## 姿态、横向速度与命中结果——并按用户期望给出红/绿判定。
## 失败阶段区分：未识别 / 识别后未能接续 / 成功出招但未命中（见各场景断言与备注）。
## 运行：Godot --headless --path . -s res://tests/diagnose_inputs.gd
## 退出码非 0 = 仍有未修复的用户症状。面向规则（地面自由行动每帧面向木桩、
## 后退不翻面、空中按锁定面向折算）已随 issue 12 落地，本回路应为全绿基线。

const NEAR_OFFSET := 70.0   ## 木桩放在命中范围内的身前偏移
const FAR_OFFSET := 400.0   ## 木桩放在射程外

var _failures := 0
var _red_lines: Array[String] = []


func _initialize() -> void:
	_s1_qcf_facing_right()
	_s2_qcf_facing_left()
	_s3_qcb_ground_neutral()
	_s4_qcb_during_move()
	_s5_jump_reverse_input()
	_s6_air_direction_sequence()
	_s7_qcf_after_walkback()
	print("")
	if _failures == 0:
		print("ALL DIAGNOSIS CHECKS GREEN")
		quit(0)
	else:
		print(str(_failures) + " DIAGNOSIS CHECK(S) RED")
		for line in _red_lines:
			print("RED> " + line)
		quit(1)


# --- 场景 ---


func _s1_qcf_facing_right() -> void:
	# 右面向 236C：面向右、木桩在右，S → S+D → D 再按 K（动作 C）。
	# 期望：识别 236C、成功出招并命中（用户症状的镜像基线，应当为绿）。
	var session := CombatSession.new()
	_place_dummy(session, NEAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(session, [
		_step("S", 0, true),
		_step("S+D", 1, true, "", false, 2),
		_step("D", 1, false, "", false, 2),
		_step("D+K", 1, false, "C"),
		_step("—", 0, false, "", false, 20),
	], trace)
	_print_scenario("S1 右面向 236C（S → S+D → D → K）", trace)
	_expect(run["move_ids"].has("236C"), "S1: 236C 被识别并起手（识别阶段）")
	_expect(int(run["hits"]) == 1, "S1: 236C 命中一次（命中阶段）")


func _s2_qcf_facing_left() -> void:
	# 左面向 236C：木桩在左，先向左走使面向翻为 -1，再按面向相对的
	# S → S+A → A（前 = A 键）加 K（动作 C）。
	# 期望：识别 236C、成功出招并命中。
	var session := CombatSession.new()
	_place_dummy(session, -NEAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(session, [
		_step("A", -1, false, "", false, 10),
		_step("—", 0),
		_step("S", 0, true),
		_step("S+A", -1, true, "", false, 2),
		_step("A", -1, false, "", false, 2),
		_step("A+K", -1, false, "C"),
		_step("—", 0, false, "", false, 20),
	], trace)
	_print_scenario("S2 左面向 236C（面向 -1：S → S+A → A → K）", trace)
	_expect(run["move_ids"].has("236C"), "S2: 左面向下 236C 被识别并起手")
	_expect(int(run["hits"]) == 1, "S2: 左面向下 236C 命中一次")


func _s3_qcb_ground_neutral() -> void:
	# 地面中立的 214D：面向右、木桩在右，S → S+A → A（后 = A 键）再按 J（动作 D）。
	# 期望：识别 214D、成功出招并命中。怀疑：按住“后”一帧后面向翻转为 -1，
	# 后续同键输入被折算成“前”，方向序列被污染（见逐帧行的面向与序列列）。
	var session := CombatSession.new()
	_place_dummy(session, NEAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(session, [
		_step("S", 0, true),
		_step("S+A", -1, true, "", false, 2),
		_step("A", -1, false, "", false, 4),
		_step("A+J", -1, false, "D"),
		_step("—", 0, false, "", false, 25),
	], trace)
	_print_scenario("S3 地面中立 214D（S → S+A → A → J）", trace)
	_expect(run["move_ids"].has("214D"), "S3: 214D 被识别并起手（识别阶段）")
	_expect(int(run["hits"]) == 1, "S3: 214D 命中一次（命中阶段）")
	if not run["move_ids"].has("214D"):
		var fallback: bool = run["move_ids"].has("5D")
		_note("S3 分类：未识别——实际回落 %s（识别阶段失败，非接续或命中问题）" % ("5D" if fallback else "空"))

	# 最小化变体：逐帧紧凑输入（S 一帧、S+A 一帧、当帧 A+J），证明即使帧级精确
	# 搓招也无法录得 “4”——按住“后”的下一帧它已被折算为“前”。
	var tight := CombatSession.new()
	_place_dummy(tight, NEAR_OFFSET)
	var tight_trace: Array[String] = []
	var tight_run := _play(tight, [
		_step("S", 0, true),
		_step("S+A", -1, true),
		_step("A+J", -1, false, "D"),
		_step("—", 0, false, "", false, 25),
	], tight_trace)
	_print_scenario("S3m 最小化：逐帧紧凑 214（S → S+A → A+J 同帧起手）", tight_trace)
	_expect(tight_run["move_ids"].has("214D"), "S3m: 帧级紧凑 214D 仍应被识别（证明“4”不可达）")


func _s4_qcb_during_move() -> void:
	# 出招期间的 214D：5A 命中确认 → 取消进 5B → 5B 出招期间搓 214 按 J。
	# 出招期间运动阶段不改面向，方向序列应稳定录得 214 → 经取消窗口接续 214D。
	# 该场景与 S3 的对照用于证伪/证实“面向翻转污染”假设。
	# 新基线（2026-09-24）：214D 不再是 5B 的取消目标。B@F12 在停顿内按下、等待
	# 到期，恢复首帧 F15 以链式取消起手 5B（F21 命中）；214 于 F38–F40 搓入、
	# D@F40 缓存（6 帧缓存覆盖 5B 完全恢复的 F45），5B 收招后作为独立招式起手
	# 214D（F52 以新连段命中中立木桩）。
	var session := CombatSession.new()
	_place_dummy(session, NEAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(session, [
		_step("U", 0, false, "A"),
		_step("—", 0, false, "", false, 10),
		_step("I", 0, false, "B"),
		_step("—", 0, false, "", false, 25),
		_step("S", 0, true),
		_step("S+A", -1, true),
		_step("A+J", -1, false, "D"),
		_step("—", 0, false, "", false, 30),
	], trace)
	_print_scenario("S4 出招期间 214D（U → I → S → S+A → A+J，命中确认取消）", trace)
	_expect(run["move_ids"].has("214D"), "S4: 出招期间 214D 被识别并起手（识别阶段；已废弃取消路线改为收招后独立起手）")
	_expect(int(run["hits"]) == 3, "S4: 5A → 5B 两击经链式取消命中，214D 于 5B 完全恢复后独立命中（新连段）")

	# 挥空变体：木桩在射程外，同样的输入。挥空不产生取消资格，缓存按年龄过期——
	# 这是现行设计（挥空不产生命中确认取消），记录为“识别后未能接续”的预期行为。
	var whiff := CombatSession.new()
	_place_dummy(whiff, FAR_OFFSET)
	var whiff_trace: Array[String] = []
	var whiff_run := _play(whiff, [
		_step("U", 0, false, "A"),
		_step("—", 0, false, "", false, 10),
		_step("I", 0, false, "B"),
		_step("—", 0, false, "", false, 25),
		_step("S", 0, true),
		_step("S+A", -1, true),
		_step("A+J", -1, false, "D"),
		_step("—", 0, false, "", false, 30),
	], whiff_trace)
	_print_scenario("S4w 挥空时的出招期间 214D（现行设计：无取消资格，缓存过期）", whiff_trace)
	_expect(whiff_run["move_ids"].has("214D") and int(whiff_run["hits"]) == 0,
		"S4w: 挥空时 214D 识别并独立起手，但木桩在射程外挥空零命中（现行设计的预期行为）")
	_note("S4w 分类：识别后按独立招式起手，无取消资格、无命中（挥空不产生连段）")


func _s5_jump_reverse_input() -> void:
	# 起跳后按反方向 / 松开水平键：已明确的规则——普通空中运动保留起跳横向速度，
	# 玩家方向输入不能主动改变空中横向速度或面向。
	var reverse := CombatSession.new()
	_place_dummy(reverse, FAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(reverse, [
		_step("D", 1, false, "", false, 20),
		_step("Space+D", 1, false, "", true),
		_step("A", -1, false, "", false, 40),
		_step("—", 0, false, "", false, 5),
	], trace)
	_print_scenario("S5a 起跳后按反方向（D 走 → Space+D 跳 → 按住 A）", trace)
	var snaps: Array = run["snaps"]
	var takeoff_vx: float = snaps[20]["velocity"].x
	_expect(takeoff_vx > 300.0, "S5a: 前跳起跳时横向速度达到行走速度（前提）")
	_expect((snaps[24]["velocity"] as Vector2).x > 300.0, "S5a: 按反方向 4 帧后横向速度仍保留起跳速度")
	_expect(int(snaps[24]["facing"]) == 1, "S5a: 按反方向不改变空中面向")
	_expect((snaps[60]["velocity"] as Vector2).x > 300.0, "S5a: 落地前横向速度仍保留起跳速度")
	_expect(int(snaps[60]["facing"]) == 1, "S5a: 全程空中面向不变")
	_expect(bool(snaps[65]["on_ground"]), "S5a: 玩家正常落地（跳跃弧线不受影响）")

	var release := CombatSession.new()
	_place_dummy(release, FAR_OFFSET)
	var release_trace: Array[String] = []
	var release_run := _play(release, [
		_step("D", 1, false, "", false, 20),
		_step("Space+D", 1, false, "", true),
		_step("—", 0, false, "", false, 40),
	], release_trace)
	_print_scenario("S5b 起跳后松开水平键（D 走 → Space+D 跳 → 松开）", release_trace)
	var rel_snaps: Array = release_run["snaps"]
	_expect((rel_snaps[30]["velocity"] as Vector2).x > 300.0, "S5b: 松开 9 帧后横向速度仍保留起跳速度（无空中摩擦衰减）")
	_expect((rel_snaps[58]["velocity"] as Vector2).x > 300.0, "S5b: 落地前横向速度不衰减")


func _s6_air_direction_sequence() -> void:
	# 空中输入方向序列：空中搓 2 → 1 → 4（S → S+A → A）后按 K / J。
	# 已明确的规则：空中方向输入不改变横向速度或面向（与 S5 同一回归）。
	# 现状记录：空中方向历史按锁定面向折算；共享表未配置空中派生，C 无 jC
	# 配置不起手，D 回落解析为无派生 jD——空中派生的识别路径由注入表的
	# session 测试与 smoke 临时 manifest 用例覆盖，此处保持现状基线。
	var session := CombatSession.new()
	_place_dummy(session, FAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(session, [
		_step("D", 1, false, "", false, 15),
		_step("Space+D", 1, false, "", true),
		_step("D", 1, false, "", false, 1),
		_step("S", 0, true, "", false, 2),
		_step("S+A", -1, true, "", false, 2),
		_step("A", -1, false, "", false, 4),
		_step("A+K", -1, false, "C"),
		_step("A", -1, false, "", false, 1),
		_step("A+J", -1, false, "D"),
		_step("—", 0, false, "", false, 30),
	], trace)
	_print_scenario("S6 空中方向序列（空中 S → S+A → A → K / J）", trace)
	var snaps: Array = run["snaps"]
	_expect((snaps[25]["velocity"] as Vector2).x > 300.0, "S6: 空中搓招期间横向速度保留起跳速度（方向输入不改变速度）")
	_expect(int(snaps[25]["facing"]) == 1, "S6: 空中搓招期间面向不变")
	var move_ids: Array = run["move_ids"]
	_expect(not move_ids.has("jC") and not move_ids.has("236C") and not move_ids.has("214D"),
		"S6: 空中按 K 不起手任何招式（无 jC 配置，现状）")
	_expect(move_ids.has("jD"), "S6: 空中按 J 回落解析为 jD（共享表未配置空中派生，现状记录）")
	_note("S6 分类：空中方向序列按锁定面向记录；未配置空中派生时回落无派生招式，属数据配置而非能力缺口")


func _s7_qcf_after_walkback() -> void:
	# 后退后的 236C（实机路径）：先按 A 后退（面向随移动翻转为 -1），再朝木桩方向
	# 搓物理 236（S → S+D → D → K）。用户视角“面向木桩搓 236”，引擎却在序列中途
	# 把同一物理方向从“后”重释为“前”——序列内解释不一致，236C 无法识别。
	var right := CombatSession.new()
	_place_dummy(right, NEAR_OFFSET)
	var trace: Array[String] = []
	var run := _play(right, [
		_step("A", -1, false, "", false, 4),
		_step("—", 0),
		_step("S", 0, true, "", false, 2),
		_step("S+D", 1, true, "", false, 2),
		_step("D", 1, false, "", false, 2),
		_step("D+K", 1, false, "C"),
		_step("—", 0, false, "", false, 25),
	], trace)
	_print_scenario("S7a 后退后朝木桩搓 236C（A 后退 → S → S+D → D → K）", trace)
	_expect(run["move_ids"].has("236C"), "S7a: 后退后朝木桩搓 236C 应被识别")
	if not run["move_ids"].has("236C"):
		_note("S7a 分类：未识别——面向在序列中途翻转，同一段输入被两种面向解释")

	var left := CombatSession.new()
	_place_dummy(left, -NEAR_OFFSET)
	var left_trace: Array[String] = []
	var left_run := _play(left, [
		_step("D", 1, false, "", false, 4),
		_step("—", 0),
		_step("S", 0, true, "", false, 2),
		_step("S+A", -1, true, "", false, 2),
		_step("A", -1, false, "", false, 2),
		_step("A+K", -1, false, "C"),
		_step("—", 0, false, "", false, 25),
	], left_trace)
	_print_scenario("S7b 镜像：后退后朝木桩搓 236C（D 后退 → S → S+A → A → K）", left_trace)
	_expect(left_run["move_ids"].has("236C"), "S7b: 镜向后退后朝木桩搓 236C 应被识别")


# --- 基础设施 ---


func _step(label: String, axis: int, down: bool = false, action: String = "", jump: bool = false, frames: int = 1) -> Dictionary:
	return {"label": label, "axis": axis, "down": down, "action": action, "jump": jump, "frames": frames}


func _place_dummy(session: CombatSession, offset: float) -> void:
	session.dummy_position = session.player_position + Vector2(offset, 0.0)


func _play(session: CombatSession, steps: Array, trace: Array[String]) -> Dictionary:
	var hits := 0
	var move_ids: Array[String] = []
	var snaps: Array = []
	for step in steps:
		for i in range(int(step["frames"])):
			var input := FrameInput.new()
			input.move_axis = int(step["axis"])
			input.down_held = bool(step["down"])
			input.jump_pressed = bool(step["jump"])
			input.action_key = String(step["action"])
			var events: Array[CombatEvent] = session.step(input)
			var snap := session.debug_snapshot()
			for event in events:
				if event.type == CombatEvent.Type.HIT:
					hits += 1
			snaps.append(snap)
			move_ids.append(String(snap["move_id"]))
			trace.append(_trace_line(String(step["label"]), snap, hits))
	return {"hits": hits, "move_ids": move_ids, "snaps": snaps}


func _trace_line(keys: String, snap: Dictionary, hits: int) -> String:
	var phase_text := "中立"
	match snap["phase"]:
		CombatSession.PlayerPhase.STARTUP:
			phase_text = "前摇"
		CombatSession.PlayerPhase.ACTIVE:
			phase_text = "判定"
		CombatSession.PlayerPhase.RECOVERY:
			phase_text = "后摇"
	var posture := "空" if not bool(snap["on_ground"]) else "地"
	var sequence := String(snap["direction_sequence"])
	if sequence == "":
		sequence = "—"
	var buffer_text := "—"
	if int(snap["buffer_age"]) >= 0:
		var left := maxi(GameParams.ACTION_BUFFER_FRAMES - int(snap["buffer_age"]), 0)
		buffer_text = "%s余%d" % [String(snap["buffered_move_id"]), left]
	var move_text := String(snap["move_id"])
	if move_text == "":
		move_text = "—"
	var velocity: Vector2 = snap["velocity"]
	return "F%03d 键[%s] 面向%+d %s 序列%s 缓存%s 招式%s 取消[%s] vx%+4.0f 命中%d" % [
		int(snap["frame"]), keys, int(snap["facing"]), posture, sequence, buffer_text,
		move_text, "/".join(PackedStringArray(snap["cancel_targets"])), velocity.x, hits,
	]


func _print_scenario(title: String, trace: Array[String]) -> void:
	print("")
	print("== " + title + " ==")
	for line in trace:
		print("  " + line)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		_red_lines.append(label)
		print("  RED   " + label)


func _note(text: String) -> void:
	print("  NOTE  " + text)
