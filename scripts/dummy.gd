class_name Dummy
extends CharacterBody2D
## 木桩的呈现层：位置与血条来自战斗会话，受击闪白由训练场按命中事件触发。
## 掉血、硬直与击退的结算全部在 CombatSession 中完成；
## 物理层不再参与结算，碰撞体仅保留结构。

var hp: float = GameParams.DUMMY_MAX_HP

var _flash_timer := 0.0
var _visuals: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	($CollisionShape2D.shape as RectangleShape2D).size = GameParams.BODY_SIZE
	_visuals = NativeShapes.make_character(GameParams.DUMMY_COLOR)
	add_child(_visuals)


## 受击闪白反馈（纯视觉计时，由训练场在命中事件时调用）。
func flash() -> void:
	_flash_timer = GameParams.HIT_FLASH_TIME
	modulate = GameParams.HIT_FLASH_COLOR


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(_flash_timer - delta, 0.0)
		if _flash_timer == 0.0:
			modulate = Color.WHITE


## 从战斗会话同步本帧的呈现状态（位置、血条）。
func apply_session(session: CombatSession) -> void:
	position = session.dummy_position
	if hp != session.dummy_hp:
		hp = session.dummy_hp
		queue_redraw()


func _draw() -> void:
	var head_top := NativeShapes.head_center_offset() - GameParams.HEAD_SIZE.y * 0.5
	var bar_position := Vector2(-GameParams.HP_BAR_SIZE.x * 0.5, head_top - GameParams.HP_BAR_GAP - GameParams.HP_BAR_SIZE.y)
	draw_rect(Rect2(bar_position, GameParams.HP_BAR_SIZE), GameParams.HP_BAR_BG_COLOR)
	if hp > 0.0:
		var ratio := hp / float(GameParams.DUMMY_MAX_HP)
		var fill := Rect2(bar_position, Vector2(GameParams.HP_BAR_SIZE.x * ratio, GameParams.HP_BAR_SIZE.y))
		draw_rect(fill, GameParams.HP_BAR_FILL_COLOR.lerp(GameParams.HP_BAR_LOW_COLOR, 1.0 - ratio))
