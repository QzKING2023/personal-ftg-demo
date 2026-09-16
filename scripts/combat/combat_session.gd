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
## jump cancel 开放的空中追击起手招式（Space 取消命中确认招式后保留连段；
## 落地仍未接续时资格作废并结束连段）。
var _jump_cancel_followups: Array[String] = []
## 本帧玩家刚从空中落地（运动阶段置位；取消与消费阶段据此开放落地接续）。
var _player_just_landed := false


func _init(move_table: Dictionary = {}) -> void:
	## 空表默认加载共享 manifest（训练场与 Solver 同一份已校验数据）；
	## 不回退代码内建的 GameParams 招式表——共享资源是唯一数据源（issue 11）。
	_moves = move_table if not move_table.is_empty() else MoveData.default_table()
	reset_to_initial_state()


## 会话运行的共享招式表（稳定 id → MoveData；只读快照口径，修改应通过编辑
## 共享资源并重新加载，不要在运行中改写会话表）。
func move_table() -> Dictionary:
	return _moves


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
	_player_just_landed = false
	_clear_buffer()
	_direction_history.clear()
	_last_direction_digit = 5
	_cancel_targets.clear()
	_jump_cancel_followups.clear()


## 结算一个物理帧，返回该帧产生的战斗事件（按结算发生顺序排列）。
func step(input: FrameInput) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	_frame_index += 1
	_frame_input = input
	_player_just_landed = false
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


## 开发期诊断只读快照：面向、相对方向序列、识别招式、缓存剩余、取消资格与
## 姿态/速度等复现记录口径（执行路径阶段 1 的输入记录要求）。只读，不参与结算。
func debug_snapshot() -> Dictionary:
	var buffer_age := -1
	if _buffered_key != "":
		buffer_age = _frame_index - _buffered_at
	return {
		"frame": _frame_index,
		"facing": player_facing,
		"on_ground": player_on_ground,
		"phase": player_phase,
		"move_id": player_move_id,
		"move_attribute": _current_move.attribute_label() if _current_move != null else "",
		"buffered_key": _buffered_key,
		"buffered_move_id": _buffered_move_id,
		"buffer_age": buffer_age,
		"direction_sequence": _collapsed_direction_sequence(),
		"cancel_targets": _cancel_targets.duplicate(),
		"velocity": player_velocity,
	}


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
	_motion_player(events)
	_motion_dummy(events)
	_update_free_action_facing()
	_resolve_body_overlap()
	_advance_move(events)


func _phase_cancel() -> void:
	## 5. 取消判定：只有已命中确认、仍在取消窗口内且木桩仍处于可追击的受击状态时，
	##    才开放本招配置的取消目标；挥空不产生任何取消资格。
	##    普通取消要求目标与当前招式同姿态（空中招式不会因落地姿态翻转而获得
	##    地面取消目标）；空中招式在本帧刚落地时，额外开放显式配置的落地接续
	##    目标——落地接续是空中 → 地面的唯一合法接缝。
	_cancel_targets.clear()
	if not _cancel_window_open():
		return
	_append_stance_matching_targets(_current_move.cancel_targets, _current_move.stance)
	if _player_just_landed and _current_move.stance == MoveData.Stance.AIR:
		_append_stance_matching_targets(_current_move.landing_cancel_targets, MoveData.Stance.GROUND)


func _append_stance_matching_targets(move_ids: Array[String], stance: MoveData.Stance) -> void:
	## 把姿态一致的接续目标并入取消目标（重复条目只保留一个）。
	for move_id in move_ids:
		if _cancel_targets.has(move_id):
			continue
		var target := _moves.get(move_id) as MoveData
		if target != null and target.stance == stance and _stance_matches(target):
			_cancel_targets.append(move_id)


func _phase_consume_buffer(events: Array[CombatEvent]) -> void:
	## 6. 消费缓存：空闲时按缓存起手独立招式；命中确认取消窗口内按取消资格
	##    转入下一招。jump cancel 后的空中追击起手按合法接续起手（只有配置的
	##    起手招式获得资格，普通跳跃后的空中招式仍是独立招式）。
	##    落地接续只在本帧刚落地、且当前空中招式显式配置了落地接续目标时，
	##    把缓存的动作键按地面姿态重解析后消费（如 jB 的 D → 5D）；
	##    落地本身不授予任何普通取消资格。取消资格不足或缓存已过期时输入作废。
	if _buffered_move_id != "":
		var consumed := false
		if _player_just_landed:
			consumed = _try_start_cancel(_resolve_action(_buffered_key))
		if not consumed and not _try_start_cancel(_buffered_move_id):
			var buffered := _moves.get(_buffered_move_id) as MoveData
			if buffered != null and _stance_matches(buffered) and _current_move == null:
				var is_followup := combo_active and _jump_cancel_followups.has(_buffered_move_id)
				_start_move(_buffered_move_id, buffered, is_followup)
				_clear_buffer()
				if is_followup:
					_jump_cancel_followups.clear()
	## 空中招式落地：本帧没有配置的落地接续发生时，滞留地面姿态的空中招式作废
	## （空中路线不因落地延续），连段以收招未接续结束。
	if _current_move != null and _current_move.stance == MoveData.Stance.AIR and player_on_ground:
		_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
		_clear_current_move()
	## 命中确认取消窗口关闭且没有接续时连段结束；木桩受击处理不受影响。
	if _current_move != null and _move_hit_confirmed and combo_active \
			and _frame_index - _hit_confirm_frame > _current_move.cancel_window_frames:
		_end_combo(CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED, events)


func _try_start_cancel(move_id: String) -> bool:
	## 命中确认取消：目标在开放名单内且姿态一致时按合法接续起手并消费缓存。
	var move := _moves.get(move_id) as MoveData
	if move == null or not _stance_matches(move) or _current_move == null or not _cancel_targets.has(move_id):
		return false
	_start_move(move_id, move, true)
	_clear_buffer()
	return true


# --- 运动细节 ---

func _motion_player(events: Array[CombatEvent]) -> void:
	## 跳跃与 jump cancel 都在运动阶段起跳：起跳帧当帧不加重力（与木桩浮空同一积分
	## 方式，滞空恰为 PLAYER_JUMP_AIRTIME_FRAMES 帧）。jump cancel 需要招式配置、
	## 命中确认、取消窗口与可追击木桩同时成立；起跳取消当前招式、保留连段并开放
	## 配置的空中追击起手；普通跳跃只有地面中立姿态可用（空中 Space 一律无效）。
	var jumped_this_frame := false
	if _frame_input.jump_pressed and player_on_ground:
		if player_phase == PlayerPhase.NEUTRAL:
			player_velocity.y = -GameParams.jump_velocity()
			player_on_ground = false
			jumped_this_frame = true
		elif _can_jump_cancel():
			player_velocity.y = -GameParams.jump_velocity()
			player_on_ground = false
			jumped_this_frame = true
			_jump_cancel_followups.clear()
			_jump_cancel_followups.append_array(_current_move.jump_cancel_targets)
			_clear_current_move()
	if player_phase == PlayerPhase.NEUTRAL:
		if player_on_ground:
			if _frame_input.move_axis != 0:
				player_velocity.x = move_toward(player_velocity.x, _frame_input.move_axis * GameParams.PLAYER_MOVE_SPEED, GameParams.PLAYER_ACCELERATION * GameParams.PHYSICS_TICK)
			else:
				player_velocity.x = move_toward(player_velocity.x, 0.0, GameParams.PLAYER_FRICTION * GameParams.PHYSICS_TICK)
		# 普通空中运动保留起跳横向速度：方向输入不加速、不减速、也不翻转面向
		# （已明确规则，见执行路径；招式配置的运动效果按招式规则另行处理）。
	else:
		# 出招期间水平输入失效，只保留摩擦减速（地面/空中一致）。
		player_velocity.x = move_toward(player_velocity.x, 0.0, GameParams.PLAYER_FRICTION * GameParams.PHYSICS_TICK)
	if not player_on_ground and not jumped_this_frame:
		player_velocity.y = minf(player_velocity.y + GameParams.GRAVITY * GameParams.PHYSICS_TICK, GameParams.MAX_FALL_SPEED)
	player_position += player_velocity * GameParams.PHYSICS_TICK
	player_position.x = clampf(player_position.x, GameParams.stage_left_limit(), GameParams.stage_right_limit())
	if player_position.y >= GameParams.ground_stand_y():
		player_position.y = GameParams.ground_stand_y()
		if player_velocity.y > 0.0:
			player_velocity.y = 0.0
		var just_landed := not player_on_ground
		player_on_ground = true
		_player_just_landed = just_landed
		if just_landed and not _jump_cancel_followups.is_empty():
			# jump cancel 后落地仍未接续空中追击：追击资格作废，连段以收招未接续结束。
			_jump_cancel_followups.clear()
			if combo_active and _current_move == null:
				_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
	else:
		player_on_ground = false


func _can_jump_cancel() -> bool:
	## jump cancel 资格：与动作键取消共用同一命中确认取消窗口，外加本招配置了
	## 空中追击起手。（判定发生在运动阶段——起跳当帧就要积分位置；与第 5 阶段的
	## 取消判定在受身边界帧可能相差一帧，但连段与追击资格的最终语义一致。）
	return _cancel_window_open() and not _current_move.jump_cancel_targets.is_empty()


func _cancel_window_open() -> bool:
	## 命中确认取消窗口：已命中确认、连段仍活跃、木桩仍可追击，且命中后年龄
	## 仍在窗口内（0–N 帧含两端）。动作键取消与 jump cancel 共用本判定。
	if _current_move == null or not _move_hit_confirmed or not combo_active:
		return false
	if not _dummy_pursuable():
		return false
	var age := _frame_index - _hit_confirm_frame
	return age >= 0 and age <= _current_move.cancel_window_frames


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


## 地面自由行动（中立/移动；蹲下并入待蹲下 issue 落地，出招、受击与空中除外）
## 时每帧面向木桩：在双方运动与位置更新后、身体重叠推出前重新指向，本帧的
## 面向变化从下一物理帧的方向折算生效；后退不翻面，与木桩横向重合时保持当前
## 面向。出招、受击硬直、倒地处理和空中阶段不进入本函数，保持进入该阶段时的
## 面向；落地完成后的首个地面自由行动帧由本函数重新面向木桩。
func _update_free_action_facing() -> void:
	if player_phase != PlayerPhase.NEUTRAL or not player_on_ground:
		return
	if is_equal_approx(dummy_position.x, player_position.x):
		return
	player_facing = 1 if dummy_position.x > player_position.x else -1


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
	player_phase = PlayerPhase.NEUTRAL


func _clear_buffer() -> void:
	_buffered_key = ""
	_buffered_move_id = ""


func _resolve_action(action_key: String) -> String:
	## 动作键在输入帧锁定为具体招式 id：按招式数据声明的输入绑定解析（issue 11 起
	## 绑定是数据字段，不再按 id 命名约定推断）。当前姿态先匹配方向派生（方向历史
	## 按该姿态锁定的面向折算，issue 12 起空中派生同样生效），无派生再取同键
	## 无派生招式。同绑定并列时取优先级最高者（校验保证合法表无并列；
	## 投技不走单键解析）。
	if action_key == "":
		return ""
	var stance := MoveData.Stance.AIR if not player_on_ground else MoveData.Stance.GROUND
	var derivative_id := _match_direction_derivation(action_key, stance)
	if derivative_id != "":
		return derivative_id
	return _best_by_priority(_binding_candidates(action_key, stance, true))


## 声明了指定姿态、绑定该动作键且（plain 时）无方向派生的打击招式 id 列表。
func _binding_candidates(action_key: String, stance: MoveData.Stance, plain_only: bool) -> Array[String]:
	var ids: Array[String] = []
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move == null or move.stance != stance or not move.is_strike():
			continue
		if move.action_key != action_key:
			continue
		if plain_only and move.direction_derivation != "":
			continue
		ids.append(move_id)
	return ids


## 同绑定并列时按声明优先级选招（大者优先）。仍并列取表序首个只是未校验注入表
## 的兜底——共享 manifest 已把同绑定同优先级并列拒绝为非法数据，不按表序猜测。
func _best_by_priority(move_ids: Array[String]) -> String:
	var best_id := ""
	var best_priority := -999999
	for move_id in move_ids:
		var priority := (_moves[move_id] as MoveData).priority
		if priority > best_priority:
			best_id = move_id
			best_priority = priority
	return best_id


func _match_direction_derivation(action_key: String, stance: MoveData.Stance) -> String:
	## 方向派生匹配：方向历史滤除过期与中立条目并折叠相邻重复后，用序列尾部
	## 匹配招式数据声明的 direction_derivation（"方向序列+动作键"），只考察
	## 与当前姿态一致的招式（空中派生按空中锁定的面向折算）。多个派生同时
	## 命中时取方向序列最长者；同长并列按优先级。
	var sequence := _collapsed_direction_sequence()
	if sequence == "":
		return ""
	var best_id := ""
	var best_length := 0
	var best_priority := -999999
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move == null or move.stance != stance or not move.is_strike():
			continue
		if move.direction_derivation.length() < 2 or move.direction_derivation.length() < best_length:
			continue
		if not move.direction_derivation.ends_with(action_key):
			continue
		if not sequence.ends_with(move.direction_derivation.left(move.direction_derivation.length() - 1)):
			continue
		if move.direction_derivation.length() > best_length or (move.direction_derivation.length() == best_length and move.priority > best_priority):
			best_id = move_id
			best_length = move.direction_derivation.length()
			best_priority = move.priority
	return best_id


## 方向历史的可读折叠：滤除中立与相邻重复条目后的相对方向序列（如 "236"/"214"）。
## 匹配与诊断共用同一折叠口径。
func _collapsed_direction_sequence() -> String:
	var sequence := ""
	var last_digit := 0
	for entry in _direction_history:
		if entry.x == 5 or entry.x == last_digit:
			continue
		last_digit = entry.x
		sequence += str(entry.x)
	return sequence


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
