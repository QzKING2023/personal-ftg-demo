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
	AIR_HITSTUN,      ## 浮空受击硬直（滞空期间逐帧消耗，归零即浮空受身）
	AIR_RECOVERED,    ## 空中已受身（连段已结束，落地后才恢复中立）
}

# --- 可观察的玩家状态 ---
var player_position: Vector2
var player_velocity: Vector2
var player_facing := 1
var player_phase: PlayerPhase = PlayerPhase.NEUTRAL
var player_on_ground := true
## 当前执行的招式 id（空闲时为空串）。
var player_move_id := ""

# --- 可观察的木桩状态 ---
var dummy_position: Vector2
var dummy_velocity: Vector2
var dummy_hp := 0.0
var dummy_state: DummyState = DummyState.NEUTRAL
var dummy_on_ground := true
## 剩余地面受击硬直帧数（含当前帧；归零即自然受身）。
var dummy_hitstun_left := 0

# --- 可观察的连段状态 ---
## 当前/最近一段连段的命中数；连段结束后保留，直到下一段首击重新计数。
var combo_hits := 0
## 连段是否仍在继续（收尾、取消窗口关闭、招式收招未接续或木桩自然受身时结束）。
var combo_active := false
## 当前/最近一段连段的累计伤害。
var combo_total_damage := 0.0
## 最近一次命中的伤害倍率与实际伤害。
var combo_last_scale := 1.0
var combo_last_damage := 0.0

var _moves: Dictionary = {}
var _current_move: MoveData = null
var _move_frame := 0
var _hit_once_this_move := false
## 本招是否已命中确认（命中确认取消的必要条件；挥空永远为 false）。
var _move_hit_confirmed := false
var _hit_confirm_frame := 0
## 本招是否为连段内的合法接续（决定能否命中仍在受击中的木桩）。
var _move_is_followup := false
var _frame_input := FrameInput.new()
var _pending_hit: MoveData = null
## 本帧刚应用过受击硬直：命中的当帧不消耗新硬直（先刷新、后落地/自然受身）。
var _dummy_fresh_hitstun := false

## 会话帧计数（从 1 开始）：同时为动作缓存与取消窗口计龄。
var _frame_index := 0

# --- 动作键单槽缓存（年龄 0–5 有效，年龄 6 先过期，最新输入覆盖旧输入）---
var _buffered_key := ""
var _buffered_move_id := ""
var _buffered_at := 0

# --- 方向输入历史（独立于动作键缓存：年龄 0–23 有效，年龄 24 先过期）---
## Vector2i(小键盘方向, 输入帧)：方向按面向折算（前 6 / 后 4 / 下 2 / 斜 1、3 / 中立 5），
## 只在发生变化时入历史；识别方向派生后整段消费。
var _direction_history: Array[Vector2i] = []
var _last_direction_digit := 5

## 本帧开放的命中确认取消目标（招式 id）。
var _cancel_targets: Array[String] = []


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
	player_move_id = ""
	dummy_position = Vector2(GameParams.DUMMY_SPAWN_X, GameParams.ground_stand_y())
	dummy_velocity = Vector2.ZERO
	dummy_hp = GameParams.DUMMY_MAX_HP
	dummy_state = DummyState.NEUTRAL
	dummy_on_ground = true
	dummy_hitstun_left = 0
	combo_hits = 0
	combo_active = false
	combo_total_damage = 0.0
	combo_last_scale = 1.0
	combo_last_damage = 0.0
	_current_move = null
	_move_frame = 0
	_hit_once_this_move = false
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_is_followup = false
	_pending_hit = null
	_dummy_fresh_hitstun = false
	_frame_input = FrameInput.new()
	_frame_index = 0
	_clear_buffer()
	_direction_history.clear()
	_last_direction_digit = 5
	_cancel_targets.clear()


## 结算一个物理帧，返回该帧产生的战斗事件（按结算发生顺序排列）。
func step(input: FrameInput) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	_frame_index += 1
	_frame_input = input
	_phase_input()
	_phase_hit_detection()
	_phase_apply_hits(events)
	_phase_motion(events)
	_phase_cancel()
	_phase_consume_buffer(events)
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
	## 1. 记录输入：到期的缓存先过期，再记录本帧方向与动作键（最新输入覆盖旧输入）。
	##    动作键在输入帧按姿态与方向历史锁定为具体招式；跳跃与移动在运动阶段生效，
	##    Space 与方向输入不占动作键缓存。
	if _buffered_key != "" and _frame_index - _buffered_at >= GameParams.ACTION_BUFFER_FRAMES:
		_clear_buffer()
	_record_direction()
	if _frame_input.action_key != "":
		_buffered_key = _frame_input.action_key
		_buffered_at = _frame_index
		_buffered_move_id = _resolve_action(_frame_input.action_key)
		if _buffered_move_id != "" and (_moves[_buffered_move_id] as MoveData).direction_derivation != "":
			## 识别方向派生：消费整段方向历史，招式已在输入帧锁定。
			_direction_history.clear()


func _record_direction() -> void:
	## 方向历史只记录变化：先把（水平轴、下方向、面向）折算成小键盘数字，
	## 与上一帧不同才入历史；过期条目（年龄 ≥ 方向窗口）先清理。
	_direction_history = _direction_history.filter(
		func(entry: Vector2i) -> bool: return _frame_index - entry.y < GameParams.DIRECTION_BUFFER_FRAMES
	)
	var digit := _direction_digit()
	if digit != _last_direction_digit:
		_direction_history.append(Vector2i(digit, _frame_index))
		_last_direction_digit = digit


func _direction_digit() -> int:
	## 面向相对的小键盘方向（输入阶段先于运动，用翻转前的面向折算）：
	## 前 6 / 后 4 / 下 2 / 斜 1、3；无输入为 5。
	var horizontal := 0
	if _frame_input.move_axis == player_facing:
		horizontal = 1
	elif _frame_input.move_axis == -player_facing:
		horizontal = -1
	return 5 + horizontal - (3 if _frame_input.down_held else 0)


func _phase_hit_detection() -> void:
	## 2. 命中判定：判定帧内检查命中框与木桩身体的几何重叠。
	##    木桩中立时可被任何招式命中；受击中只有连段内的合法接续招式可以继续命中，
	##    没有取消资格的独立招式不能绕过取消条件追击。同一次出招最多命中一次。
	_pending_hit = null
	if player_phase != PlayerPhase.ACTIVE or _hit_once_this_move:
		return
	if not player_attack_rect().intersects(_dummy_body_rect()):
		return
	if not _can_hit_dummy():
		return
	_hit_once_this_move = true
	_pending_hit = _current_move


func _phase_apply_hits(events: Array[CombatEvent]) -> void:
	## 3. 受击应用：结算连段伤害递减、受击状态、硬直与击退。
	if _pending_hit == null:
		return
	var move := _pending_hit
	if not combo_active or dummy_state == DummyState.NEUTRAL:
		combo_hits = 0
		combo_total_damage = 0.0
	combo_active = true
	combo_hits += 1
	combo_last_scale = snappedf(
		maxf(GameParams.COMBO_DAMAGE_FLOOR, 1.0 - (combo_hits - 1) * GameParams.COMBO_DAMAGE_DECAY),
		0.000001
	)
	combo_last_damage = snappedf(move.base_damage * combo_last_scale, 0.1)
	combo_total_damage = snappedf(combo_total_damage + combo_last_damage, 0.1)
	dummy_hp = maxf(dummy_hp - combo_last_damage, 0.0)
	match move.hit_result:
		MoveData.HitResult.GROUND_HITSTUN:
			dummy_state = DummyState.GROUND_HITSTUN
			dummy_hitstun_left = move.hitstun_frames
		MoveData.HitResult.LAUNCH:
			dummy_state = DummyState.AIR_HITSTUN
			dummy_hitstun_left = move.hitstun_frames
		_:
			push_error("未支持的命中结果类型: %d" % move.hit_result)
	_dummy_fresh_hitstun = true
	dummy_velocity.x = player_facing * move.knockback
	if move.hit_result == MoveData.HitResult.LAUNCH:
		## 浮空命中必定重起跳：即使木桩仍在上一击的微浮中也给予完整滞空；
		## 普通命中只在地面附带击飞，追击不会刷新滞空。
		dummy_velocity.y = -move.knockback_up
	elif dummy_on_ground:
		dummy_velocity.y = -move.knockback_up
	_move_hit_confirmed = true
	_hit_confirm_frame = _frame_index
	events.append(CombatEvent.hit(combo_last_damage, player_facing, combo_hits))
	if move.is_finisher:
		## 收尾结束连段路线，但不主动清除木桩的受击/倒地处理。
		_end_combo(CombatEvent.ComboEndReason.FINISHER, events)
	_pending_hit = null


func _phase_motion(events: Array[CombatEvent]) -> void:
	## 4. 运动/落地/自然受身：先按已应用的速度积分位置，再处理落地、
	## 身体重叠与木桩自然受身；招式帧计数也在本阶段末尾推进。
	_motion_player()
	_motion_dummy(events)
	_resolve_body_overlap()
	_advance_move(events)


func _phase_cancel() -> void:
	## 5. 取消判定：只有已命中确认、仍在取消窗口内且木桩仍处于可追击的受击状态时，
	##    才开放本招配置的取消目标；挥空不产生任何取消资格。
	_cancel_targets.clear()
	if _current_move == null or not _move_hit_confirmed or not combo_active:
		return
	if not _dummy_pursuable():
		return
	var age := _frame_index - _hit_confirm_frame
	if age < 0 or age > _current_move.cancel_window_frames:
		return
	for move_id in _current_move.cancel_targets:
		var target := _moves.get(move_id) as MoveData
		if target != null and _stance_matches(target):
			_cancel_targets.append(move_id)


func _phase_consume_buffer(events: Array[CombatEvent]) -> void:
	## 6. 消费缓存：空闲时按缓存起手独立招式；命中确认取消窗口内按取消资格
	##    转入下一招。取消资格不足或缓存已过期时输入作废。
	if _buffered_move_id != "":
		var buffered := _moves.get(_buffered_move_id) as MoveData
		if buffered != null and _stance_matches(buffered):
			if _current_move != null and _cancel_targets.has(_buffered_move_id):
				_start_move(_buffered_move_id, buffered, true)
				_clear_buffer()
			elif _current_move == null:
				_start_move(_buffered_move_id, buffered, false)
				_clear_buffer()
	## 命中确认取消窗口关闭且没有接续时连段结束；木桩受击处理不受影响。
	if _current_move != null and _move_hit_confirmed and combo_active \
			and _frame_index - _hit_confirm_frame > _current_move.cancel_window_frames:
		_end_combo(CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED, events)


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


func _tick_ground_hitstun(events: Array[CombatEvent]) -> void:
	## 地面硬直逐帧消耗：归零即自然受身，回到中立并结束连段。
	dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
	if dummy_hitstun_left == 0:
		dummy_state = DummyState.NEUTRAL
		events.append(CombatEvent.dummy_recovered())
		_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)


func _motion_dummy(events: Array[CombatEvent]) -> void:
	var friction := GameParams.DUMMY_FRICTION
	if dummy_state == DummyState.GROUND_HITSTUN or dummy_state == DummyState.AIR_HITSTUN:
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
	match dummy_state:
		DummyState.GROUND_HITSTUN:
			if dummy_on_ground and not _dummy_fresh_hitstun:
				# 自然受身：地面硬直归零即回到中立并结束受击。
				# 落地保留剩余受击硬直——滞空期间硬直帧数暂停消耗。
				_tick_ground_hitstun(events)
		DummyState.AIR_HITSTUN:
			if dummy_on_ground:
				# 落地保留剩余浮空硬直：未耗尽就落地时转为地面硬直，
				# 落地当帧起按地面规则继续消耗（与地面受击的落地帧一致）。
				dummy_state = DummyState.GROUND_HITSTUN
				if not _dummy_fresh_hitstun:
					_tick_ground_hitstun(events)
			elif not _dummy_fresh_hitstun:
				# 浮空受身：浮空硬直归零当帧立即结束连段；落地后才恢复中立。
				dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
				if dummy_hitstun_left == 0:
					dummy_state = DummyState.AIR_RECOVERED
					_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
		DummyState.AIR_RECOVERED:
			if dummy_on_ground:
				dummy_state = DummyState.NEUTRAL
				events.append(CombatEvent.dummy_recovered())
		_:
			pass
	_dummy_fresh_hitstun = false


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


func _advance_move(events: Array[CombatEvent]) -> void:
	## 招式帧计数在运动阶段末尾推进。招式在消费阶段起手，起手帧即第 1 帧。
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
		## 招式收招：没有通过命中确认取消接续时连段结束。
		player_phase = PlayerPhase.NEUTRAL
		_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
		_clear_current_move()


func _start_move(move_id: String, move: MoveData, is_followup: bool) -> void:
	_current_move = move
	player_move_id = move_id
	_move_frame = 1
	_hit_once_this_move = false
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_is_followup = is_followup
	player_phase = PlayerPhase.STARTUP


func _clear_current_move() -> void:
	_current_move = null
	_move_frame = 0
	_hit_once_this_move = false
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_is_followup = false
	player_move_id = ""


func _clear_buffer() -> void:
	_buffered_key = ""
	_buffered_move_id = ""


func _resolve_action(action_key: String) -> String:
	## 动作键在输入帧锁定为具体招式 id：空中查 "j"+键；地面先用方向历史尾部
	## 匹配招式数据里的方向派生（如 236C/214D），无派生再查 "5"+键；未配置返回空串。
	if not player_on_ground:
		var air_id := "j" + action_key
		return air_id if _moves.has(air_id) else ""
	var move_id := _match_direction_derivation(action_key)
	if move_id == "":
		move_id = "5" + action_key
	return move_id if _moves.has(move_id) else ""


func _match_direction_derivation(action_key: String) -> String:
	## 方向派生匹配（只在地面）：方向历史滤除过期与中立条目并折叠相邻重复后，
	## 用序列尾部匹配招式数据的 direction_derivation（"方向序列+动作键"）。
	## 多个派生同时命中时取方向序列最长者；无匹配返回空串。
	var sequence := ""
	var last_digit := 0
	for entry in _direction_history:
		if entry.x == 5 or entry.x == last_digit:
			continue
		last_digit = entry.x
		sequence += str(entry.x)
	if sequence == "":
		return ""
	var best_id := ""
	var best_length := 0
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move == null or move.direction_derivation.length() <= best_length:
			continue
		if not move.direction_derivation.ends_with(action_key):
			continue
		if not sequence.ends_with(move.direction_derivation.left(move.direction_derivation.length() - 1)):
			continue
		best_id = move_id
		best_length = move.direction_derivation.length()
	return best_id


func _can_hit_dummy() -> bool:
	## 木桩中立时可被任何招式命中；受击中只有连段内的合法接续招式可以继续命中；
	## 空中已受身不可追击，落地恢复中立后才能开启新一段连段。
	if dummy_state == DummyState.NEUTRAL:
		return true
	if not _dummy_pursuable():
		return false
	return combo_active and _move_is_followup


func _dummy_pursuable() -> bool:
	## 可追击的受击状态：地面硬直或浮空硬直（连段仍活跃时合法接续可继续命中）。
	return dummy_state == DummyState.GROUND_HITSTUN or dummy_state == DummyState.AIR_HITSTUN


func _stance_matches(move: MoveData) -> bool:
	## 招式姿态要求与玩家当前姿态一致（地面招式须在地面，空中招式须在空中）。
	return (move.stance == MoveData.Stance.AIR) == (not player_on_ground)


func _end_combo(reason: CombatEvent.ComboEndReason, events: Array[CombatEvent]) -> void:
	if not combo_active:
		return
	combo_active = false
	events.append(CombatEvent.combo_ended(reason))


func _dummy_body_rect() -> Rect2:
	return Rect2(dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
