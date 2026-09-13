extends Node2D
## 训练场主场景：搭建舞台、驱动战斗会话、呈现状态反馈并处理重置。
## 职责限定为输入适配、呈现与重置；战斗结算全部在 CombatSession 中完成。
## 舞台按 960x540 固定镜头设计，不放相机，世界坐标即视口坐标。

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DummyScene: PackedScene = preload("res://scenes/dummy.tscn")

const HINT_TEXT := "A/D or Arrows: Move    S or Down: Direction    Space: Jump    J/K/L/U: 5A/5B/5C/5D    236+C / 214+D: Derivatives    R: Reset"

## 动作键 A/B/C/D 对应的输入动作名（J/K/L/U）；C/D 配合方向序列触发派生。
const ACTION_KEYS: Array[String] = ["A", "B", "C", "D"]

## 本局战斗会话（战斗状态的唯一来源）。
var session: CombatSession

var _player: Player
var _dummy: Dummy
var _dummy_status: Label


func _ready() -> void:
	session = CombatSession.new()
	_build_arena()
	_spawn_fighters()
	_add_hint_label()
	_add_dummy_status()
	_sync_views()


func _physics_process(_delta: float) -> void:
	var events: Array[CombatEvent] = session.step(_read_frame_input())
	_player.apply_session(session)
	_dummy.apply_session(session)
	for event in events:
		if event.type == CombatEvent.Type.HIT:
			_dummy.flash()
	_update_dummy_status()


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
	_player.apply_session(session)
	_dummy.apply_session(session)
	_update_dummy_status()


func _add_hint_label() -> void:
	var label := Label.new()
	label.text = HINT_TEXT
	label.position = GameParams.HINT_OFFSET
	label.add_theme_color_override("font_color", GameParams.HINT_COLOR)
	label.name = "Hint"
	add_child(label)


func _add_dummy_status() -> void:
	_dummy_status = Label.new()
	_dummy_status.position = GameParams.STATUS_OFFSET
	_dummy_status.add_theme_color_override("font_color", GameParams.HINT_COLOR)
	_dummy_status.name = "DummyStatus"
	add_child(_dummy_status)


func _update_dummy_status() -> void:
	var state_text := "中立"
	if session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN:
		state_text = "地面受击（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.AIR_HITSTUN:
		state_text = "浮空受击（%d）" % session.dummy_hitstun_left
	elif session.dummy_state == CombatSession.DummyState.AIR_RECOVERED:
		state_text = "空中已受身"
	var posture := "空中" if not session.player_on_ground else "地面"
	_dummy_status.text = "玩家 %s  木桩 HP %d/%d  状态 %s  连段 %d hit · %.1f" % [
		posture,
		roundi(session.dummy_hp),
		GameParams.DUMMY_MAX_HP,
		state_text,
		session.combo_hits,
		session.combo_total_damage,
	]
