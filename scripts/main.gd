extends Node2D
## 训练场主场景：搭建舞台（背景、地面、左右边界、中心标记），生成玩家与木桩，并处理重置。
## 舞台按 960x540 固定镜头设计，不放相机，世界坐标即视口坐标。

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DummyScene: PackedScene = preload("res://scenes/dummy.tscn")

const HINT_TEXT := "A/D or Arrows: Move    Space: Jump    J: Attack    R: Reset"


func _ready() -> void:
	_build_arena()
	_spawn_fighters()
	_add_hint_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()


func _build_arena() -> void:
	add_child(NativeShapes.make_rect(
		Vector2(GameParams.STAGE_WIDTH, GameParams.STAGE_HEIGHT),
		GameParams.BACKDROP_COLOR,
		Vector2(GameParams.STAGE_WIDTH * 0.5, GameParams.STAGE_HEIGHT * 0.5)
	))
	_add_static_block(
		Rect2(Vector2(0, GameParams.GROUND_Y), Vector2(GameParams.STAGE_WIDTH, GameParams.FLOOR_THICKNESS)),
		GameParams.GROUND_COLOR
	)
	var wall_height := GameParams.GROUND_Y
	_add_static_block(
		Rect2(Vector2(0, 0), Vector2(GameParams.WALL_THICKNESS, wall_height)),
		GameParams.WALL_COLOR
	)
	_add_static_block(
		Rect2(Vector2(GameParams.STAGE_WIDTH - GameParams.WALL_THICKNESS, 0), Vector2(GameParams.WALL_THICKNESS, wall_height)),
		GameParams.WALL_COLOR
	)
	add_child(NativeShapes.make_rect(
		Vector2(GameParams.CENTER_MARK_WIDTH, GameParams.FLOOR_THICKNESS),
		GameParams.CENTER_MARK_COLOR,
		Vector2(GameParams.STAGE_WIDTH * 0.5, GameParams.GROUND_Y + GameParams.FLOOR_THICKNESS * 0.5)
	))


func _add_static_block(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = GameParams.layer_bit(GameParams.LAYER_WORLD)
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.add_child(shape)
	body.add_child(NativeShapes.make_rect(rect.size, color))
	add_child(body)


func _spawn_fighters() -> void:
	var floor_y := GameParams.ground_stand_y()
	var player := PlayerScene.instantiate()
	player.position = Vector2(GameParams.PLAYER_SPAWN_X, floor_y)
	add_child(player)
	var dummy := DummyScene.instantiate()
	dummy.position = Vector2(GameParams.DUMMY_SPAWN_X, floor_y)
	add_child(dummy)


func _add_hint_label() -> void:
	var label := Label.new()
	label.text = HINT_TEXT
	label.position = GameParams.HINT_OFFSET
	label.add_theme_color_override("font_color", GameParams.HINT_COLOR)
	add_child(label)
