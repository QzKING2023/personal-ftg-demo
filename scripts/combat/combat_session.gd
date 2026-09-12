class_name CombatSession
extends RefCounted
## 确定性战斗会话：运行时最高测试 seam。
## 每个物理帧喂入一份 FrameInput，按固定顺序结算——
## 输入 → 命中判定 → 受击应用 → 运动/落地/自然受身 → 取消判定 → 消费缓存——
## 输出该帧产生的战斗事件，并维护可观察的玩家状态与木桩状态。
## 时间一律以物理帧（整数）为单位；速度/重力仍以 px/s 计，按 PHYSICS_TICK 换算。
## 训练场只负责输入适配、呈现与重置；本类不依赖任何场景节点。

enum PlayerPhase {
	NEUTRAL,   ## 中立（地面或空中均可自由行动）
	STARTUP,   ## 招式前摇
	ACTIVE,    ## 招式判定
	RECOVERY,  ## 招式后摇
}

enum DummyState {
	NEUTRAL,          ## 中立
	GROUND_HITSTUN,   ## 地面受击硬直
}

# --- 可观察的玩家状态 ---
var player_position: Vector2
var player_velocity: Vector2
var player_facing := 1
var player_phase: PlayerPhase = PlayerPhase.NEUTRAL
var player_on_ground := true

# --- 可观察的木桩状态 ---
var dummy_position: Vector2
var dummy_velocity: Vector2
var dummy_hp := 0.0
var dummy_state: DummyState = DummyState.NEUTRAL
var dummy_on_ground := true
## 剩余地面受击硬直帧数（含当前帧；归零即自然受身）。
var dummy_hitstun_left := 0

var _moves: Dictionary = {}
var _current_move: MoveData = null
var _move_frame := 0
var _hit_once_this_move := false
var _frame_input := FrameInput.new()
var _pending_hit: MoveData = null


func _init(move_table: Dictionary = {}) -> void:
	_moves = move_table if not move_table.is_empty() else MoveData.default_table()
	reset_to_initial_state()


## 恢复到初始状态。训练场通过重载场景重建会话；测试也可直接调用。
func reset_to_initial_state() -> void:
	player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	player_velocity = Vector2.ZERO
	player_facing = 1
	player_phase = PlayerPhase.NEUTRAL
	player_on_ground = true
	dummy_position = Vector2(GameParams.DUMMY_SPAWN_X, GameParams.ground_stand_y())
	dummy_velocity = Vector2.ZERO
	dummy_hp = GameParams.DUMMY_MAX_HP
	dummy_state = DummyState.NEUTRAL
	dummy_on_ground = true
	dummy_hitstun_left = 0
	_current_move = null
	_move_frame = 0
	_hit_once_this_move = false
	_pending_hit = null


## 结算一个物理帧，返回该帧产生的战斗事件（按结算发生顺序排列）。
func step(input: FrameInput) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	_frame_input = input
	_phase_input()
	_phase_hit_detection()
	_phase_apply_hits(events)
	_phase_motion(events)
	_phase_cancel()
	_phase_consume_buffer()
	return events


## 当前招式的命中框（世界坐标）；没有进行中的招式时返回空矩形。
## 判定阶段与非判定阶段共用同一几何，是否生效由 player_phase 决定。
func player_attack_rect() -> Rect2:
	if _current_move == null:
		return Rect2()
	var center := player_position + Vector2(player_facing * _current_move.hitbox_offset(), 0.0)
	return Rect2(center - _current_move.hitbox_size * 0.5, _current_move.hitbox_size)


# --- 结算管线（顺序不可调换）---

func _phase_input() -> void:
	## 1. 记录输入：缓存本帧输入并按输入起手招式；跳跃与移动在运动阶段生效。
	if _frame_input.attack_pressed and player_phase == PlayerPhase.NEUTRAL:
		_start_move(_moves["A"])


func _phase_hit_detection() -> void:
	## 2. 命中判定：判定帧内检查命中框与木桩身体的几何重叠。
	## 同一次出招对同一木桩最多命中一次；命中的应用推迟到下一阶段。
	_pending_hit = null
	if player_phase != PlayerPhase.ACTIVE or _hit_once_this_move:
		return
	if player_attack_rect().intersects(_dummy_body_rect()):
		_hit_once_this_move = true
		_pending_hit = _current_move


func _phase_apply_hits(events: Array[CombatEvent]) -> void:
	## 3. 受击应用：结算伤害、受击状态、硬直与击退。
	if _pending_hit == null:
		return
	dummy_hp = maxf(dummy_hp - _pending_hit.base_damage, 0.0)
	match _pending_hit.hit_result:
		MoveData.HitResult.GROUND_HITSTUN:
			dummy_state = DummyState.GROUND_HITSTUN
			dummy_hitstun_left = _pending_hit.hitstun_frames
		_:
			push_error("未支持的命中结果类型: %d" % _pending_hit.hit_result)
	dummy_velocity.x = player_facing * _pending_hit.knockback
	if dummy_on_ground:
		dummy_velocity.y = -_pending_hit.knockback_up
	events.append(CombatEvent.hit(_pending_hit.base_damage, player_facing))
	_pending_hit = null


func _phase_motion(events: Array[CombatEvent]) -> void:
	## 4. 运动/落地/自然受身：先按已应用的速度积分位置，再处理落地、
	## 身体重叠与木桩自然受身；招式帧计数也在本阶段末尾推进。
	_motion_player()
	_motion_dummy(events)
	_resolve_body_overlap()
	_advance_move()


func _phase_cancel() -> void:
	## 5. 取消判定：命中确认取消的资格与窗口检查属于后续 issue，当前无操作。
	pass


func _phase_consume_buffer() -> void:
	## 6. 消费缓存：动作键缓存的消费属于后续 issue，当前无操作。
	pass


# --- 运动细节 ---

func _motion_player() -> void:
	if player_on_ground and player_phase == PlayerPhase.NEUTRAL and _frame_input.jump_pressed:
		player_velocity.y = GameParams.JUMP_VELOCITY
		player_on_ground = false
	if player_phase == PlayerPhase.NEUTRAL:
		var accel := GameParams.PLAYER_ACCELERATION
		if not player_on_ground:
			accel *= GameParams.PLAYER_AIR_CONTROL
		if _frame_input.move_axis != 0:
			player_facing = 1 if _frame_input.move_axis > 0 else -1
			player_velocity.x = move_toward(player_velocity.x, _frame_input.move_axis * GameParams.PLAYER_MOVE_SPEED, accel * GameParams.PHYSICS_TICK)
		else:
			player_velocity.x = move_toward(player_velocity.x, 0.0, GameParams.PLAYER_FRICTION * GameParams.PHYSICS_TICK)
	else:
		# 出招期间水平输入失效，只保留摩擦减速。
		player_velocity.x = move_toward(player_velocity.x, 0.0, GameParams.PLAYER_FRICTION * GameParams.PHYSICS_TICK)
	if not player_on_ground:
		player_velocity.y = minf(player_velocity.y + GameParams.GRAVITY * GameParams.PHYSICS_TICK, GameParams.MAX_FALL_SPEED)
	player_position += player_velocity * GameParams.PHYSICS_TICK
	player_position.x = clampf(player_position.x, GameParams.stage_left_limit(), GameParams.stage_right_limit())
	if player_position.y >= GameParams.ground_stand_y():
		player_position.y = GameParams.ground_stand_y()
		if player_velocity.y > 0.0:
			player_velocity.y = 0.0
		player_on_ground = true
	else:
		player_on_ground = false


func _motion_dummy(events: Array[CombatEvent]) -> void:
	var friction := GameParams.DUMMY_FRICTION
	if dummy_state == DummyState.GROUND_HITSTUN:
		friction = GameParams.DUMMY_HITSTUN_FRICTION
	dummy_velocity.x = move_toward(dummy_velocity.x, 0.0, friction * GameParams.PHYSICS_TICK)
	if not dummy_on_ground:
		dummy_velocity.y = minf(dummy_velocity.y + GameParams.GRAVITY * GameParams.PHYSICS_TICK, GameParams.MAX_FALL_SPEED)
	dummy_position += dummy_velocity * GameParams.PHYSICS_TICK
	dummy_position.x = clampf(dummy_position.x, GameParams.stage_left_limit(), GameParams.stage_right_limit())
	if dummy_position.y >= GameParams.ground_stand_y():
		dummy_position.y = GameParams.ground_stand_y()
		if dummy_velocity.y > 0.0:
			dummy_velocity.y = 0.0
		dummy_on_ground = true
	else:
		dummy_on_ground = false
	if dummy_state == DummyState.GROUND_HITSTUN and dummy_on_ground:
		# 自然受身：地面硬直归零即回到中立并结束受击。
		# 落地保留剩余受击硬直——滞空期间硬直帧数暂停消耗。
		dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
		if dummy_hitstun_left == 0:
			dummy_state = DummyState.NEUTRAL
			events.append(CombatEvent.dummy_recovered())


## 玩家与木桩身体不互相穿透：垂直重叠时把玩家沿水平方向推出木桩（木桩不动）。
func _resolve_body_overlap() -> void:
	var dx := player_position.x - dummy_position.x
	if absf(dx) >= GameParams.BODY_SIZE.x:
		return
	if absf(player_position.y - dummy_position.y) >= GameParams.BODY_SIZE.y:
		return
	var side := 1.0 if dx >= 0.0 else -1.0
	player_position.x = dummy_position.x + GameParams.BODY_SIZE.x * side
	player_position.x = clampf(player_position.x, GameParams.stage_left_limit(), GameParams.stage_right_limit())
	if is_equal_approx(signf(player_velocity.x), -side):
		player_velocity.x = 0.0


func _advance_move() -> void:
	## 招式帧计数在运动阶段末尾推进：按下攻击的当帧为第 0 帧。
	if _current_move == null:
		return
	_move_frame += 1
	if _move_frame < _current_move.active_from():
		player_phase = PlayerPhase.STARTUP
	elif _move_frame <= _current_move.active_to():
		player_phase = PlayerPhase.ACTIVE
	elif _move_frame < _current_move.total_frames():
		player_phase = PlayerPhase.RECOVERY
	else:
		player_phase = PlayerPhase.NEUTRAL
		_current_move = null
		_move_frame = 0
		_hit_once_this_move = false


func _start_move(move: MoveData) -> void:
	_current_move = move
	_move_frame = 0
	_hit_once_this_move = false
	player_phase = PlayerPhase.STARTUP


func _dummy_body_rect() -> Rect2:
	return Rect2(dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
