extends Node2D
## 训练场主场景：搭建舞台、驱动战斗会话、呈现状态反馈并处理重置。
## 职责限定为输入适配、呈现与重置；战斗结算全部在 CombatSession 中完成。
## 舞台按 960x540 固定镜头设计，不放相机，世界坐标即视口坐标。

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DummyScene: PackedScene = preload("res://scenes/dummy.tscn")

const HINT_TEXT := "移动 A/D 或 ←/→    下 S/↓    跳跃 Space    重置 R\n动作 U/I/K/J = A/B/C/D    派生 236+C / 214+D（方向按面向折算）"

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
	var events: Array[CombatEvent] = session.step(_read_frame_input())
	_player.apply_session(session)
	_dummy.apply_session(session)
	for event in events:
		if event.type == CombatEvent.Type.HIT:
			_dummy.flash()
	_update_dummy_status()
	_update_debug_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()


func _read_frame_input() -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = roundi(Input.get_axis("move_left", "move_right"))
	input.down_held = Input.is_action_pressed("move_down")
	input.jump_pressed = Input.is_action_just_pressed("jump")
	for key in ACTION_KEYS:
		if Input.is_action_just_pressed("attack_" + key.to_lower()):
			input.action_key = key
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
	if int(snap["prejump_left"]) > 0:
		posture = "准备" + str(int(snap["prejump_left"]))
	elif int(snap["landing_recovery_left"]) > 0:
		posture = "落地" + str(int(snap["landing_recovery_left"]))
	if int(snap["hitstop_left"]) > 0:
		posture = "停顿" + posture + str(int(snap["hitstop_left"]))
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
	var sequence := String(snap["direction_sequence"])
	if sequence == "":
		sequence = "—"
	var cancels := "/".join(PackedStringArray(snap["cancel_targets"]))
	if cancels == "":
		cancels = "—"
	if bool(snap["cancel_open"]):
		# 取消资格开放时同时显示正常帧年龄（停顿帧不计龄，issue 14）。
		cancels += " 龄%d" % int(snap["cancel_age"])
	var attribute := String(snap["move_attribute"])
	if attribute != "":
		attribute = " 属性" + attribute
	_debug_line.text = "诊断 帧%d 面向%s %s 招式%s%s 缓存%s 跳槽%s 方向%s 取消%s" % [
		int(snap["frame"]), facing_text, posture, move_text, attribute, buffer_text, jump_text, sequence, cancels,
	]


func _update_dummy_status() -> void:
	var state_text := "中立"
	if session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN:
		state_text = "地面受击（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.AIR_HITSTUN:
		state_text = "浮空受击（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.AIR_RECOVERED:
		state_text = "空中已受身"
	var posture := "空中" if not session.player_on_ground else "地面"
	# 两行布局：第一行姿态与血量，第二行受击状态与连段；避免与左侧键位提示重叠。
	_dummy_status.text = "玩家 %s  木桩 HP %d/%d\n状态 %s  连段 %d hit · %.1f" % [
		posture,
		roundi(session.dummy_hp),
		GameParams.DUMMY_MAX_HP,
		state_text,
		session.combo_hits,
		session.combo_total_damage,
	]
