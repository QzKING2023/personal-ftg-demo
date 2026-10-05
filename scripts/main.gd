extends Node2D
## 训练场主场景：搭建舞台、驱动战斗会话、呈现状态反馈并处理重置。
## 职责限定为输入适配、呈现与重置；战斗结算全部在 CombatSession 中完成。
## 舞台按 960x540 固定镜头设计，不放相机，世界坐标即视口坐标。

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DummyScene: PackedScene = preload("res://scenes/dummy.tscn")

const HINT_TEXT := "移动 A/D 或 ←/→    下 S/↓ 蹲下    防御 按住后方向 4/1    跳跃 Space    重置 R\n动作 U/I/K/J = A/B/C/D    派生 236+C / 214+C（方向按面向折算）
236C 两段判定：命中当下按 J 经来源资格进入 5D（窗口 16 帧，被防不开放）\n214+C 分支：命中或被防后首按 I/K 锁定 ~B/~C（同帧 I+K 固定 ~C）\n冲刺 双击 →/←（66/44，中间松开一帧）    投 I+K = B+C（≤3帧内同按，投距内成立）\n木桩防御 G 循环：无 → 站防 → 蹲防 → 空防（逐帧确定性请求，木桩无自主决策）\n短刀/徒手：C/D 系与 6A 出刀（刀姿+收刀卡点），A/B 系拳形，位移残影"

## 动作键 A/B/C/D 对应的输入动作名（物理键 U/I/K/J）；C/D 配合方向序列触发派生。
const ACTION_KEYS: Array[String] = ["A", "B", "C", "D"]

## 动作键 → 物理键（诊断行展示用，与 project.godot 输入映射保持一致）。
const ACTION_PHYSICAL_KEYS := {"A": "U", "B": "I", "C": "K", "D": "J"}

## 本局战斗会话（战斗状态的唯一来源）；招式表校验失败时为 null，训练场拒绝运行。
var session: CombatSession
## 共享招式表 manifest 路径（训练场与 Combo Solver 读同一份已校验数据，issue 11）。
var manifest_path := MoveTable.DEFAULT_MANIFEST_PATH
## 非空 = 招式表被拒绝的原因（与 Solver 观察到的同一拒绝原因）。
var table_error := ""

var _player: Player
var _dummy: Dummy
var _dummy_status: Label
var _debug_line: Label
## 最近一次普通连接失败的可读原因（LINK_FAILED 事件驱动；重置清空）。
var _last_link_fail := ""
## 最近一次低浮空触地/连段结束的可读事件注记（票据 02 训练场反馈）。
var _last_state_note := ""
## 木桩防御训练模式（票据 03）：G 键循环 无→站防→蹲防→空防，每帧作为确定性
## 防御请求喂给会话——玩家驱动的训练设置，木桩本身无自主决策。
var _dummy_guard_mode := 0


func _ready() -> void:
	var table := MoveTable.load_manifest(manifest_path)
	if table.ok:
		session = CombatSession.new(table.moves)
	else:
		session = null
		table_error = table.first_error()
	_build_arena()
	_spawn_fighters()
	_add_hint_label()
	_add_dummy_status()
	_add_debug_line()
	_sync_views()


func _physics_process(_delta: float) -> void:
	if session == null:
		return
	if Input.is_action_just_pressed("dummy_guard"):
		_dummy_guard_mode = (_dummy_guard_mode + 1) % 4
	var events: Array[CombatEvent] = session.step(_read_frame_input())
	_player.apply_session(session)
	_dummy.apply_session(session)
	for event in events:
		if event.type == CombatEvent.Type.HIT or event.type == CombatEvent.Type.THROW_HIT:
			_dummy.flash()
		if event.type == CombatEvent.Type.LINK_FAILED:
			_last_link_fail = "%s：%s" % [event.link_move_id, _link_fail_text(event.link_fail_reason)]
		if event.type == CombatEvent.Type.LOW_FLOAT_LANDED:
			_last_state_note = "低浮空触地 → 普通倒地"
		if event.type == CombatEvent.Type.REKKA_BRANCH_LOCKED:
			_last_state_note = "Rekka 分支锁定 ~%s（%s）——首个 %s 新按下锁定，同帧 B+C 固定 ~C" % [
				event.rekka_branch, event.rekka_move_id, event.rekka_branch]
		if event.type == CombatEvent.Type.SPIKE_LANDED:
			_last_state_note = "向下击落触地 → 普通倒地"
		if event.type == CombatEvent.Type.SLIDE_STARTED:
			_last_state_note = "击飞触地 → 地面滑行（%d 帧，可被 5D 捞起）" % session.dummy_slide_left
		if event.type == CombatEvent.Type.BOUNCE_CONTACT:
			_last_state_note = "弹地触地 → 反弹一次，追击窗口 %d 帧（起手 %s：%s）" % [
				session.dummy_bounce_left, _starter_grade_text(session.combo_starter_grade),
				"一次性追击" if session.combo_bounce_followup > 0 else "无追击资格，命中即收尾"]
		if event.type == CombatEvent.Type.CHARGE_COMMITTED:
			_last_state_note = "蓄力提交 %s → %s（按住 %d 帧%s）" % [
				event.charge_from_move_id, event.charge_to_move_id, event.charge_age,
				"，阈值自动触发" if event.charged else "，松开走普通版"]
		if event.type == CombatEvent.Type.SWITCHED_SIDES:
			_last_state_note = "换边：命中穿越，下一帧面向 %s" % ("→" if event.direction == 1 else "←")
		if event.type == CombatEvent.Type.ATTACK_BLOCKED:
			_last_state_note = "攻击被%s挡下（被防硬直 %d）" % [
				_guard_posture_text(event.guard_posture), session.dummy_blockstun_left]
		if event.type == CombatEvent.Type.DUMMY_GUARD_REJECTED:
			_last_state_note = "木桩防御请求不成立：%s" % _guard_reject_text(event.guard_reject_reason)
		if event.type == CombatEvent.Type.COMBO_ENDED:
			_last_state_note = "连段结束：%s" % _combo_end_text(event.combo_end_reason)
	_update_dummy_status()
	_update_debug_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()


func _read_frame_input() -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = roundi(Input.get_axis("move_left", "move_right"))
	input.down_held = Input.is_action_pressed("move_down")
	input.up_held = Input.is_action_pressed("jump")
	input.jump_pressed = Input.is_action_just_pressed("jump")
	# 全部新按下与按住的动作键都进入会话（B+C 组合按配对容差与持键判定，
	# 同帧单键选择由会话按 D>C>B>A 折算，issue 17）。
	for key in ACTION_KEYS:
		if Input.is_action_just_pressed("attack_" + key.to_lower()):
			input.pressed_action_keys.append(key)
		if Input.is_action_pressed("attack_" + key.to_lower()):
			input.held_action_keys.append(key)
	# 木桩防御训练模式：当前模式作为逐帧确定性请求喂给会话（票据 03）。
	input.dummy_guard_request = _dummy_guard_mode
	return input


func _build_arena() -> void:
	add_child(NativeShapes.make_rect(
		Vector2(GameParams.STAGE_WIDTH, GameParams.STAGE_HEIGHT),
		GameParams.BACKDROP_COLOR,
		Vector2(GameParams.STAGE_WIDTH * 0.5, GameParams.STAGE_HEIGHT * 0.5)
	))
	# 地面与墙体只做视觉；边界约束由战斗会话结算。
	_add_static_rect(
		Rect2(Vector2(0, GameParams.GROUND_Y), Vector2(GameParams.STAGE_WIDTH, GameParams.FLOOR_THICKNESS)),
		GameParams.GROUND_COLOR
	)
	var wall_height := GameParams.GROUND_Y
	_add_static_rect(
		Rect2(Vector2(0, 0), Vector2(GameParams.WALL_THICKNESS, wall_height)),
		GameParams.WALL_COLOR
	)
	_add_static_rect(
		Rect2(Vector2(GameParams.STAGE_WIDTH - GameParams.WALL_THICKNESS, 0), Vector2(GameParams.WALL_THICKNESS, wall_height)),
		GameParams.WALL_COLOR
	)
	add_child(NativeShapes.make_rect(
		Vector2(GameParams.CENTER_MARK_WIDTH, GameParams.FLOOR_THICKNESS),
		GameParams.CENTER_MARK_COLOR,
		Vector2(GameParams.STAGE_WIDTH * 0.5, GameParams.GROUND_Y + GameParams.FLOOR_THICKNESS * 0.5)
	))


func _add_static_rect(rect: Rect2, color: Color) -> void:
	add_child(NativeShapes.make_rect(rect.size, color, rect.position + rect.size * 0.5))


func _spawn_fighters() -> void:
	var floor_y := GameParams.ground_stand_y()
	_player = PlayerScene.instantiate()
	_player.position = Vector2(GameParams.PLAYER_SPAWN_X, floor_y)
	add_child(_player)
	_dummy = DummyScene.instantiate()
	_dummy.position = Vector2(GameParams.DUMMY_SPAWN_X, floor_y)
	add_child(_dummy)


func _sync_views() -> void:
	if session == null:
		return
	_player.apply_session(session)
	_dummy.apply_session(session)
	_update_dummy_status()


func _add_hint_label() -> void:
	var label := Label.new()
	if table_error != "":
		# 招式表被整表拒绝：训练场保持拒绝状态并显示可定位原因，不回退旧参数。
		# 资源缓存按路径驻留：修复文件后需重新运行项目才会重新加载（R 只重载场景）。
		label.text = "招式表校验失败，训练场拒绝运行\n%s\n修复资源后重新运行项目验证" % table_error
	else:
		label.text = HINT_TEXT
	label.position = GameParams.HINT_OFFSET
	label.add_theme_font_size_override("font_size", GameParams.HUD_FONT_SIZE)
	label.add_theme_color_override("font_color", GameParams.HINT_COLOR)
	label.add_theme_color_override("font_outline_color", GameParams.HINT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", GameParams.HUD_OUTLINE_SIZE)
	label.name = "Hint"
	add_child(label)


func _add_dummy_status() -> void:
	_dummy_status = Label.new()
	_dummy_status.position = GameParams.STATUS_OFFSET
	_dummy_status.add_theme_font_size_override("font_size", GameParams.HUD_FONT_SIZE)
	_dummy_status.add_theme_color_override("font_color", GameParams.HINT_COLOR)
	_dummy_status.add_theme_color_override("font_outline_color", GameParams.HINT_OUTLINE_COLOR)
	_dummy_status.add_theme_constant_override("outline_size", GameParams.HUD_OUTLINE_SIZE)
	_dummy_status.name = "DummyStatus"
	add_child(_dummy_status)


func _add_debug_line() -> void:
	# 诊断行（执行路径阶段 1 的输入记录要求）：面向、姿态、当前招式、
	# 缓存剩余、方向序列与取消资格——供实机搓招问题的人工复现核对。
	_debug_line = Label.new()
	_debug_line.position = GameParams.DEBUG_OFFSET
	_debug_line.add_theme_font_size_override("font_size", GameParams.HUD_SMALL_FONT_SIZE)
	_debug_line.add_theme_color_override("font_color", GameParams.HINT_COLOR)
	_debug_line.add_theme_color_override("font_outline_color", GameParams.HINT_OUTLINE_COLOR)
	_debug_line.add_theme_constant_override("outline_size", GameParams.HUD_OUTLINE_SIZE)
	_debug_line.name = "DebugLine"
	add_child(_debug_line)


func _update_debug_line() -> void:
	var snap := session.debug_snapshot()
	var facing_text := "→" if int(snap["facing"]) == 1 else "←"
	var posture := "空中" if not bool(snap["on_ground"]) else "地面"
	if bool(snap["crouching"]):
		posture = "蹲下"
	if int(snap["prejump_left"]) > 0:
		posture = "准备" + str(int(snap["prejump_left"]))
	elif int(snap["landing_recovery_left"]) > 0:
		posture = "落地" + str(int(snap["landing_recovery_left"]))
	# 冲刺（issue 18）：前冲/后撤以启动时锁定的面向区分（方向与面向同向为前冲）。
	if int(snap["dash_left"]) > 0:
		posture = ("冲" if int(snap["dash_direction"]) == int(snap["facing"]) else "撤") + str(int(snap["dash_left"]))
	if int(snap["hitstop_left"]) > 0:
		posture = "停顿" + posture + str(int(snap["hitstop_left"]))
	# 防御姿态与硬直（issue 16）：站防/蹲防/空防 + 防御硬直/受击硬直剩余帧。
	var guard_text := "—"
	match snap["guard"]:
		CombatSession.GuardPosture.STANDING:
			guard_text = "站防"
		CombatSession.GuardPosture.CROUCH:
			guard_text = "蹲防"
		CombatSession.GuardPosture.AIR:
			guard_text = "空防"
	if int(snap["guard_stun_left"]) > 0:
		guard_text += "·防僵" + str(int(snap["guard_stun_left"]))
	if int(snap["hitstun_left"]) > 0:
		guard_text += "·受击" + str(int(snap["hitstun_left"]))
	var move_text := String(snap["move_id"])
	if move_text == "":
		move_text = "—"
	var buffer_text := "—"
	if int(snap["buffer_age"]) >= 0:
		var physical := String(ACTION_PHYSICAL_KEYS.get(String(snap["buffered_key"]), "?"))
		buffer_text = "%s[%s] 余%d帧" % [
			String(snap["buffered_move_id"]), physical,
			maxi(GameParams.ACTION_BUFFER_FRAMES - int(snap["buffer_age"]), 0),
		]
	# 跳跃输入槽独立于动作键缓存（issue 15）：显示冻结的世界跳向与正常帧年龄。
	var jump_text := "—"
	if int(snap["jump_slot_age"]) >= 0:
		var dir_text := "8"
		match int(snap["jump_slot_direction"]):
			-1:
				dir_text = "←"
			1:
				dir_text = "→"
		jump_text = "%s龄%d" % [dir_text, int(snap["jump_slot_age"])]
	# 按住的动作键（issue 17 原始按键记录）：组合配对与持键规则的可观察口径。
	var held_text := "—"
	var held_keys: Array = snap["held_action_keys"]
	if not held_keys.is_empty():
		held_text = "+".join(PackedStringArray(held_keys))
	# 普通投拆投窗口剩余帧（投进行中且结果未成立时可观察）。
	var throw_text := "—"
	if int(snap["throw_window_left"]) >= 0:
		throw_text = "余%d" % int(snap["throw_window_left"])
	var pending_text := "待投" if bool(snap["pending_combination"]) else ""
	var sequence := String(snap["direction_sequence"])
	if sequence == "":
		sequence = "—"
	var cancels := "/".join(PackedStringArray(snap["cancel_targets"]))
	if cancels == "":
		cancels = "—"
	if bool(snap["cancel_open"]):
		# 取消资格开放时同时显示正常帧年龄（停顿帧不计龄，issue 14）。
		cancels += " 龄%d" % int(snap["cancel_age"])
	# Rekka 派生窗口（票据 04）：分支锁定与窗口剩余（正常帧口径）。
	var derive_text := "—"
	if int(snap["rekka_window_left"]) >= 0:
		var branch := String(snap["rekka_branch"])
		derive_text = "余%d%s" % [int(snap["rekka_window_left"]), "·锁~" + branch if branch != "" else ""]
	var attribute := String(snap["move_attribute"])
	if attribute != "":
		attribute = " 属性" + attribute
	# 蓄力与换边观测（票据 06）：蓄力龄/蓄力版、锁定动作方向、穿越许可与墙截断。
	var charge_text := "—"
	if int(snap["charge_age"]) >= 0:
		charge_text = "龄%d" % int(snap["charge_age"])
	elif bool(snap["charged_active"]):
		charge_text = "蓄力版"
	var motion_text := "—"
	var move_direction := int(snap["move_direction"])
	if move_direction != 0:
		motion_text = "%s%s%s" % [
			"→" if move_direction == 1 else "←",
			"·穿越" if bool(snap["cross_ok"]) else "",
			"·墙截" if bool(snap["motion_wall_clamped"]) else "",
		]
	# 空技落地接缝（票据 08）：j2D 命中落地取消资格（含专用输入年龄与落地确认）
	# 与 j6D 延迟普通连接挂起的可观察口径。
	var landing_seam_text := "—"
	if bool(snap["hit_landing_cancel_open"]):
		landing_seam_text = "落地取消"
		if int(snap["hit_landing_input_age"]) >= 0:
			landing_seam_text += "·%s龄%d" % [String(snap["hit_landing_input_move_id"]), int(snap["hit_landing_input_age"])]
		if bool(snap["hit_landing_landed"]):
			landing_seam_text += "·已落地"
	elif bool(snap["air_link_pending"]):
		landing_seam_text = "待目押"
	_debug_line.text = "诊断 帧%d 面向%s %s 防御%s 招式%s%s 蓄力%s 位移%s 缓存%s 跳槽%s 按住%s 投窗%s%s 方向%s 取消%s 派生%s 接缝%s" % [
		int(snap["frame"]), facing_text, posture, guard_text, move_text, attribute, charge_text, motion_text,
		buffer_text, jump_text, held_text, throw_text, pending_text, sequence, cancels, derive_text,
		landing_seam_text,
	]


func _update_dummy_status() -> void:
	var state_text := "中立"
	if session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN:
		state_text = "地面受击（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.AIR_HITSTUN:
		state_text = "浮空受击（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.AIR_RECOVERED:
		state_text = "空中已受身"
	elif session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
		state_text = "普通倒地（%d）" % session.dummy_knockdown_left
	elif session.dummy_state == CombatSession.DummyState.LOW_FLOAT_SWEEP:
		state_text = "低浮空（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.SPIKE_FALL:
		state_text = "向下击落坠落"
	elif session.dummy_state == CombatSession.DummyState.LOW_FLOAT_TO_SLIDE:
		state_text = "击飞触地前（%d→滑行%d）" % [session.dummy_hitstun_left, session.dummy_slide_left]
	elif session.dummy_state == CombatSession.DummyState.GROUND_SLIDE:
		state_text = "地面滑行（%d）" % session.dummy_slide_left
	elif session.dummy_state == CombatSession.DummyState.GROUND_BOUNCE:
		state_text = "弹地（%s，追击窗%d）" % ["已触地反弹" if session.dummy_bounce_contacted else "触地前", session.dummy_bounce_left]
	if not session.dummy_on_ground:
		# 空中高度（票据 07）：对空判定与高度失配的可观察口径（0.0 为贴地）。
		state_text += "·空中%.1fpx" % maxf(0.0, GameParams.ground_stand_y() - session.dummy_position.y)
	if session.dummy_guard != CombatSession.GuardPosture.NONE:
		state_text += "·%s" % _guard_posture_text(session.dummy_guard)
		if session.dummy_blockstun_left > 0:
			state_text += "（防僵%d）" % session.dummy_blockstun_left
	var posture := "空中" if not session.player_on_ground else "地面"
	# 起手等级与三层累计修正（C-01/C-02）：连段内的可观察反馈。
	var combo_text := "无"
	if session.combo_active:
		combo_text = "%s起手 修正 伤%.2f/时%.2f/轨%.2f" % [
			_starter_grade_text(session.combo_starter_grade),
			session.combo_damage_scale,
			session.combo_time_scale,
			session.combo_trajectory_scale,
		]
		# 弹地追击资格（票据 09）：弹地进入后的一次性继续资格可观察口径。
		if session.dummy_state == CombatSession.DummyState.GROUND_BOUNCE or session.combo_bounce_followup > 0:
			combo_text += " 弹地追击%s" % ("可用" if session.combo_bounce_followup > 0 else "已耗尽")
	var link_text := _last_link_fail if _last_link_fail != "" else "—"
	var state_note := _last_state_note if _last_state_note != "" else "—"
	# 两行布局：第一行姿态与血量，第二行受击状态与连段；连接失败原因与状态事件第三行。
	_dummy_status.text = "玩家 %s  木桩 HP %d/%d\n状态 %s  连段 %d hit · %.1f  %s\n连接 %s  事件 %s" % [
		posture,
		roundi(session.dummy_hp),
		GameParams.DUMMY_MAX_HP,
		state_text,
		session.combo_hits,
		session.combo_total_damage,
		combo_text,
		link_text,
		state_note,
	]


func _starter_grade_text(grade: MoveData.StarterGrade) -> String:
	match grade:
		MoveData.StarterGrade.A:
			return "A"
		MoveData.StarterGrade.B:
			return "B"
		MoveData.StarterGrade.C:
			return "C"
		MoveData.StarterGrade.D:
			return "D"
	return "未锁定"


func _link_fail_text(reason: CombatEvent.LinkFailReason) -> String:
	match reason:
		CombatEvent.LinkFailReason.TARGET_RECOVERED:
			return "目标已恢复"
		CombatEvent.LinkFailReason.STATE_INCOMPATIBLE:
			return "目标状态不接受该招"
		CombatEvent.LinkFailReason.DISTANCE_INSUFFICIENT:
			return "距离不足（判定窗口无接触）"
		CombatEvent.LinkFailReason.CONFIGURATION_GAP:
			return "未声明该普通连接边"
	return "未知"


func _guard_posture_text(posture: int) -> String:
	match posture:
		CombatSession.GuardPosture.STANDING:
			return "站防"
		CombatSession.GuardPosture.CROUCH:
			return "蹲防"
		CombatSession.GuardPosture.AIR:
			return "空防"
	return "未防御"


func _guard_reject_text(reason: CombatEvent.DummyGuardRejectReason) -> String:
	match reason:
		CombatEvent.DummyGuardRejectReason.STATE:
			return "姿态与地面/空中状态不符（不回退其他防御）"
		CombatEvent.DummyGuardRejectReason.BUSY:
			return "木桩受击/倒地/出招中，本帧无法进入防御"
	return "未知"


func _combo_end_text(reason: CombatEvent.ComboEndReason) -> String:
	match reason:
		CombatEvent.ComboEndReason.FINISHER:
			return "收尾招式"
		CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED:
			return "取消窗口关闭"
		CombatEvent.ComboEndReason.MOVE_RECOVERED:
			return "收招未接续"
		CombatEvent.ComboEndReason.DUMMY_RECOVERED:
			return "木桩自然受身"
		CombatEvent.ComboEndReason.KNOCKDOWN:
			return "普通倒地"
		CombatEvent.ComboEndReason.BOUNCE_END:
			return "弹地后收尾（无追击资格）"
	return "未知"
