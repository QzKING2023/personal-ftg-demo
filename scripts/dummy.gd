class_name Dummy
extends CharacterBody2D
## 木桩：静态受击目标。被招式命中后掉血、闪白并被击退，没有自主行为。

var hp: float = GameParams.DUMMY_MAX_HP

var _hitstun_timer := 0.0
var _flash_timer := 0.0
var _visuals: Node2D


func _ready() -> void:
	collision_layer = GameParams.layer_bit(GameParams.LAYER_DUMMY)
	collision_mask = GameParams.layer_bit(GameParams.LAYER_WORLD) | GameParams.layer_bit(GameParams.LAYER_PLAYER)
	($CollisionShape2D.shape as RectangleShape2D).size = GameParams.BODY_SIZE
	_visuals = NativeShapes.make_character(GameParams.DUMMY_COLOR)
	add_child(_visuals)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GameParams.GRAVITY * delta, GameParams.MAX_FALL_SPEED)
	var friction := GameParams.DUMMY_HITSTUN_FRICTION if _hitstun_timer > 0.0 else GameParams.DUMMY_FRICTION
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_hitstun_timer = maxf(_hitstun_timer - delta, 0.0)
	if _flash_timer > 0.0:
		_flash_timer = maxf(_flash_timer - delta, 0.0)
		if _flash_timer == 0.0:
			modulate = Color.WHITE
	move_and_slide()


## direction 为攻击方的朝向（1 向右 / -1 向左），木桩被推离攻击方。
func receive_hit(damage: int, direction: int) -> void:
	hp = maxf(hp - damage, 0.0)
	_hitstun_timer = GameParams.HITSTUN_TIME
	_flash_timer = GameParams.HIT_FLASH_TIME
	modulate = GameParams.HIT_FLASH_COLOR
	velocity.x = direction * GameParams.ATTACK_KNOCKBACK
	if is_on_floor():
		velocity.y = -GameParams.ATTACK_KNOCKBACK_UP
	queue_redraw()


func _draw() -> void:
	var head_top := NativeShapes.head_center_offset() - GameParams.HEAD_SIZE.y * 0.5
	var bar_position := Vector2(-GameParams.HP_BAR_SIZE.x * 0.5, head_top - GameParams.HP_BAR_GAP - GameParams.HP_BAR_SIZE.y)
	draw_rect(Rect2(bar_position, GameParams.HP_BAR_SIZE), GameParams.HP_BAR_BG_COLOR)
	if hp > 0.0:
		var ratio := hp / float(GameParams.DUMMY_MAX_HP)
		var fill := Rect2(bar_position, Vector2(GameParams.HP_BAR_SIZE.x * ratio, GameParams.HP_BAR_SIZE.y))
		draw_rect(fill, GameParams.HP_BAR_FILL_COLOR.lerp(GameParams.HP_BAR_LOW_COLOR, 1.0 - ratio))
