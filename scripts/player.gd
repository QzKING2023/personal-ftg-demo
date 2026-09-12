class_name Player
extends CharacterBody2D
## 玩家角色：左右移动、跳跃、朝向，以及一种固定 startup/active/recovery 窗口的招式。
## 一次按键发起的攻击对同一目标最多命中一次。

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/AttackShape

var facing := 1

var _phase: AttackPhase = AttackPhase.NONE
var _phase_time := 0.0
var _hit_targets: Array[Node] = []
var _visuals: Node2D
var _attack_visual: Polygon2D


func _ready() -> void:
	collision_layer = GameParams.layer_bit(GameParams.LAYER_PLAYER)
	collision_mask = GameParams.layer_bit(GameParams.LAYER_WORLD) | GameParams.layer_bit(GameParams.LAYER_DUMMY)
	($CollisionShape2D.shape as RectangleShape2D).size = GameParams.BODY_SIZE
	attack_area.collision_mask = GameParams.layer_bit(GameParams.LAYER_DUMMY)
	(attack_shape.shape as RectangleShape2D).size = GameParams.ATTACK_HITBOX_SIZE
	_visuals = NativeShapes.make_character(GameParams.PLAYER_COLOR)
	add_child(_visuals)
	_attack_visual = NativeShapes.make_rect(GameParams.ATTACK_HITBOX_SIZE, GameParams.HITBOX_COLOR)
	_attack_visual.visible = false
	attack_area.add_child(_attack_visual)
	_set_hitbox_active(false)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y = minf(velocity.y + GameParams.GRAVITY * delta, GameParams.MAX_FALL_SPEED)
	if _phase == AttackPhase.NONE:
		_process_free_movement(delta, on_floor)
	else:
		_process_attack(delta, on_floor)
	_visuals.scale.x = facing
	move_and_slide()


func _process_free_movement(delta: float, on_floor: bool) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
		var accel := GameParams.PLAYER_ACCELERATION
		if not on_floor:
			accel *= GameParams.PLAYER_AIR_CONTROL
		velocity.x = move_toward(velocity.x, axis * GameParams.PLAYER_MOVE_SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GameParams.PLAYER_FRICTION * delta)
	if on_floor and Input.is_action_just_pressed("jump"):
		velocity.y = GameParams.JUMP_VELOCITY
	if Input.is_action_just_pressed("attack"):
		_start_attack()


func _start_attack() -> void:
	_phase = AttackPhase.STARTUP
	_phase_time = 0.0
	_hit_targets.clear()
	attack_area.position = Vector2(
		facing * (GameParams.BODY_SIZE.x * 0.5 + GameParams.ATTACK_HITBOX_GAP + GameParams.ATTACK_HITBOX_SIZE.x * 0.5),
		0.0
	)


func _process_attack(delta: float, on_floor: bool) -> void:
	if on_floor:
		velocity.x = move_toward(velocity.x, 0.0, GameParams.PLAYER_FRICTION * delta)
	_phase_time += delta
	if _phase_time < _phase_duration(_phase):
		if _phase == AttackPhase.ACTIVE:
			_check_attack_hits()
		return
	match _phase:
		AttackPhase.STARTUP:
			_enter_phase(AttackPhase.ACTIVE)
		AttackPhase.ACTIVE:
			_enter_phase(AttackPhase.RECOVERY)
		AttackPhase.RECOVERY:
			_enter_phase(AttackPhase.NONE)


func _enter_phase(next: AttackPhase) -> void:
	_phase = next
	_phase_time = 0.0
	if next == AttackPhase.ACTIVE:
		_set_hitbox_active(true)
	else:
		_set_hitbox_active(false)
		if next == AttackPhase.NONE:
			_hit_targets.clear()


func _phase_duration(phase: AttackPhase) -> float:
	match phase:
		AttackPhase.STARTUP:
			return GameParams.ATTACK_STARTUP_TIME
		AttackPhase.ACTIVE:
			return GameParams.ATTACK_ACTIVE_TIME
		AttackPhase.RECOVERY:
			return GameParams.ATTACK_RECOVERY_TIME
	return 0.0


func _set_hitbox_active(active: bool) -> void:
	attack_shape.disabled = not active
	_attack_visual.visible = active


func _check_attack_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		_try_hit_body(body)


## 同一次攻击内每个目标只结算一次；目标必须实现 receive_hit。
func _try_hit_body(body: Node) -> bool:
	if body in _hit_targets or not body.has_method("receive_hit"):
		return false
	_hit_targets.append(body)
	body.receive_hit(GameParams.ATTACK_DAMAGE, facing)
	return true
