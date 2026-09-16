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

## 防御姿态：地面 4 为站防、1 为蹲防；真正离地后 4/1 均为空防。
## pre-jump、落地恢复首帧与空技恢复全程不进入防御（issue 16）。
enum GuardPosture {
	NONE = 0,     ## 未防御
	STANDING = 1, ## 站防：挡 high/mid/overhead，漏 low
	CROUCH = 2,   ## 蹲防：挡 high/mid/low，漏 overhead
	AIR = 3,      ## 空防：默认挡带 air 的打击（正交 air 类别）
}

# --- 可观察的玩家状态 ---
var player_position: Vector2
var player_velocity: Vector2
var player_facing := 1
var player_phase: PlayerPhase = PlayerPhase.NEUTRAL
var player_on_ground := true
## 当前执行的招式 id（空闲时为空串）。
var player_move_id := ""
## 是否处于蹲下姿态（地面自由行动时 1/2/3 当帧进入；水平分量照常保留）。
var player_crouching := false
## 当前防御姿态（站防/蹲防/空防；受限阶段冻结，不因下方向强行切换）。
var player_guard: GuardPosture = GuardPosture.NONE
## 剩余防御硬直帧数（防御命中后按打击数据 hitstun_frames 计，含当前帧）。
var player_guard_stun_left := 0
## 剩余玩家受击硬直帧数（未防御命中后按打击数据 hitstun_frames 计；滞空暂停消耗）。
var player_hitstun_left := 0

# --- 可观察的木桩状态 ---
var dummy_position: Vector2
var dummy_velocity: Vector2
var dummy_hp := 0.0
var dummy_state: DummyState = DummyState.NEUTRAL
var dummy_on_ground := true
## 剩余地面受击硬直帧数（含当前帧；归零即自然受身）。
var dummy_hitstun_left := 0

# --- 木桩确定性攻击（issue 16：属性矩阵与防御观察用）---
## 木桩当前执行的招式 id（空闲时为空串）。木桩无自主决策，招式经 FrameInput
## 的确定性请求启动（训练场不设置；测试/验证驱动）。
var dummy_move_id := ""
## 木桩招式阶段（与玩家共用同一套阶段枚举；空闲为 NEUTRAL）。
var dummy_phase: PlayerPhase = PlayerPhase.NEUTRAL
var _dummy_move: MoveData = null
var _dummy_move_frame := 0
## 本次木桩招式是否已连接过玩家身体（每次挥击至多一次防御/命中结算）。
var _dummy_hit_once := false
## 本帧待应用的木桩命中（命中判定阶段捕获，受击应用阶段结算）。
var _pending_dummy_hit: MoveData = null
## 本帧刚对玩家应用过防御硬直或受击硬直：当帧不消耗新硬直（与木桩受击同口径）。
var _player_fresh_stun := false

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

# --- 显式组合与普通投（issue 17）---
## 表内是否含普通投（B+C 显式组合存在时，成员键 B/C 的单键输入有 3f 组合等待）。
var _table_has_throw := false
## 投技资源（表内至多一个，MoveTable 校验拒绝多个投技；注入表取首个）。
var _throw_move: MoveData = null
## 动作键原始按下记录：键 → [按下物理帧, 是否已被组合消费]。配对容差按物理帧
## 推进（Hitstop 不合并相隔超过 3 帧的两键）；长期按住无新按下不构成配对。
var _key_presses := {}
## 本帧按住的动作键集合（原始按下/按住/松开的可观察口径，不参与单键选择）。
var _key_held: Array[String] = []
## 单键缓存的组合等待：成员键按下后配对窗口内只是候选，窗口末帧起按单键处理。
var _buffer_waiting := false
## 等待候选锁定的方向消费终点（识别在按下帧锚点完成，消费推迟到按单键处理时）。
var _buffered_endpoint := -1
## 已配齐待执行的投组合意图（配齐物理帧；0 = 无）。Hitstop 中配齐只记录意图，
## 恢复首个正常帧尝试一次；更新的动作输入会将其覆盖。
var _pending_throw_physics := 0
## 投结果是否已应用（拆投窗口关闭时一次性成立；有效拆投阻止）。
var _throw_result_applied := false

## 会话帧计数（从 1 开始）：物理帧号，Hitstop 中也递增（事件与诊断的时间轴）。
var _frame_index := 0

## 正常战斗帧时钟（从 1 开始，冻结帧不递增）：动作缓存、方向窗口与取消窗口
## 的年龄一律按本时钟计——Hitstop 不消耗这些窗口（issue 14）。
var _normal_frame_index := 0

# --- Hitstop（issue 14）---
## 剩余冻结物理帧数：命中帧完整结算后置为 HITSTOP_FRAMES，此后每物理帧递减；
## 大于 0 的帧只采样记录输入（物理键、方向历史与动作键事件），不推进任何结算。
var _hitstop_left := 0
## 下一帧是冻结结束后的首个正常帧：先输出 HITSTOP_ENDED 边界事件再正常结算。
var _hitstop_resume_pending := false

# --- 动作键单槽缓存（年龄 0–5 有效，年龄 6 先过期，最新输入覆盖旧输入）---
var _buffered_key := ""
var _buffered_move_id := ""
var _buffered_at := 0
## 动作键按下的物理帧号：jump 与动作缓存同帧竞争时比较原始请求物理帧。
var _buffered_physics := 0

# --- 跳跃输入槽（独立于动作键缓存；issue 15）---
## Space 按下的单槽记录：保留按下帧的世界水平跳向，最新按下覆盖旧请求，
## 按住不重复；年龄只按正常战斗帧计（停顿中暂停，恢复首个正常帧为年龄 0），
## 年龄 6 在消费前过期。消费前松键、反向输入或面向变化不重写请求。
var _jump_slot_active := false
var _jump_slot_at := 0
var _jump_slot_physics := 0
var _jump_slot_axis := 0

# --- 跳跃状态机（issue 15）---
## 剩余起跳准备帧（含当帧，正常帧倒数）：>0 表示处于 pre-jump，按地面姿态处理。
var player_prejump_left := 0
## 剩余落地恢复帧（含当帧，正常帧倒数）：>0 表示落地恢复受限。
var player_landing_recovery_left := 0
## 本次跳跃是否启动过空中招式 startup（决定默认 +1f 落地恢复，每跳一次）。
var _air_move_started := false
## 本次跳跃启动过的空中招式显式额外落地恢复累计帧数。
var _air_extra_recovery := 0
## 起跳准备期间生效的世界水平跳向（消费跳跃输入槽时冻结；0 为垂直跳，
## 准备期内仍可用当前方向输入改成斜跳，不重置准备计时）。
var _jump_direction := 0

# --- 缓存消费结果（诊断口径：最近一次真正从缓存起手的招式与物理帧）---
var _buffer_consumed_move_id := ""
var _buffer_consumed_frame := 0

# --- 方向输入历史（独立于动作键缓存；窗口按各指令 variant 步数 × 每方向步长计）---
## Vector2i(小键盘方向, 输入帧)：方向按面向折算（前 6 / 后 4 / 下 2 / 斜 1、3 / 中立 5），
## 只在发生变化时入历史；条目保留至表内最长指令窗口（过期段不可能再参与匹配）。
var _direction_history: Array[Vector2i] = []
var _last_direction_digit := 5
## 方向历史的保留时长：表内全部指令记法的最长窗口（步数 × DIRECTION_STEP_FRAMES）。
var _direction_retention := GameParams.DIRECTION_STEP_FRAMES

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
	_direction_retention = _max_direction_window(_moves)
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move != null and move.is_throw():
			_table_has_throw = true
			_throw_move = move
			break
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
	player_crouching = false
	player_guard = GuardPosture.NONE
	player_guard_stun_left = 0
	player_hitstun_left = 0
	_dummy_move = null
	dummy_move_id = ""
	dummy_phase = PlayerPhase.NEUTRAL
	_dummy_move_frame = 0
	_dummy_hit_once = false
	_pending_dummy_hit = null
	_player_fresh_stun = false
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
	_normal_frame_index = 0
	_buffer_consumed_move_id = ""
	_buffer_consumed_frame = 0
	_hitstop_left = 0
	_hitstop_resume_pending = false
	_player_just_landed = false
	_jump_slot_active = false
	_jump_slot_at = 0
	_jump_slot_physics = 0
	_jump_slot_axis = 0
	player_prejump_left = 0
	player_landing_recovery_left = 0
	_air_move_started = false
	_air_extra_recovery = 0
	_jump_direction = 0
	_key_presses.clear()
	_key_held.clear()
	_buffer_waiting = false
	_buffered_endpoint = -1
	_pending_throw_physics = 0
	_throw_result_applied = false
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
	if _hitstop_left > 0:
		## 冻结帧：只采样记录输入，不推进动作、位置、速度、受击、落地与受身计时。
		_phase_input()
		_hitstop_left -= 1
		if _hitstop_left == 0:
			_hitstop_resume_pending = true
		return events
	if _hitstop_resume_pending:
		## 恢复首个正常帧：输出停顿结束边界后照常结算（缓存消费在本帧发生）。
		_hitstop_resume_pending = false
		events.append(CombatEvent.hitstop_ended())
	_normal_frame_index += 1
	_player_just_landed = false
	_phase_input()
	_phase_hit_detection()
	_phase_apply_hits(events)
	_phase_motion(events)
	_phase_cancel()
	_phase_consume_buffer(events)
	return events


## 当前是否处于 Hitstop 冻结帧（本帧 step 只采样记录输入、不推进结算）。
## Solver 探针用它跳过冻结帧、按正常战斗帧推进自己的时间轴。
func hitstop_active() -> bool:
	return _hitstop_left > 0


## 当前招式的命中框（世界坐标）；没有进行中的打击招式时返回空矩形（投技无
## 命中框）。判定阶段与非判定阶段共用同一几何，是否生效由 player_phase 决定。
func player_attack_rect() -> Rect2:
	if _current_move == null or not _current_move.is_strike():
		return Rect2()
	var center := player_position + Vector2(player_facing * _current_move.hitbox_offset(), 0.0)
	return Rect2(center - _current_move.hitbox_size * 0.5, _current_move.hitbox_size)


## 木桩当前招式的命中框（世界坐标，朝玩家一侧）；没有进行中的招式时返回空矩形。
func dummy_attack_rect() -> Rect2:
	if _dummy_move == null:
		return Rect2()
	var facing := _dummy_attack_direction()
	var center := dummy_position + Vector2(facing * _dummy_move.hitbox_offset(), 0.0)
	return Rect2(center - _dummy_move.hitbox_size * 0.5, _dummy_move.hitbox_size)


## 玩家身体矩形（防御/受击判定用；蹲下不改变受击几何——规格未定义蹲姿受击框）。
func _player_body_rect() -> Rect2:
	return Rect2(player_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)


## 开发期诊断只读快照：面向、相对方向序列、识别招式、缓存剩余、取消资格与
## 姿态/速度等复现记录口径（执行路径阶段 1 的输入记录要求）。只读，不参与结算。
func debug_snapshot() -> Dictionary:
	var buffer_age := -1
	if _buffered_key != "":
		## 停顿中记录的输入尚未经历任何正常帧：原始年龄为负，按 0 显示。
		buffer_age = maxi(0, _normal_frame_index - _buffered_at)
	var cancel_age := -1
	if _current_move != null and _move_hit_confirmed:
		cancel_age = _normal_frame_index - _hit_confirm_frame
	var jump_slot_age := -1
	if _jump_slot_active:
		## 停顿中记录的 jump 尚未经历任何正常帧：原始年龄为负，按 0 显示。
		jump_slot_age = maxi(0, _normal_frame_index - _jump_slot_at)
	var throw_window_left := -1
	if _current_move != null and _current_move.is_throw() and not _throw_result_applied:
		throw_window_left = _current_move.active_to() - _move_frame + 1
	return {
		"frame": _frame_index,
		"facing": player_facing,
		"on_ground": player_on_ground,
		"phase": player_phase,
		"move_id": player_move_id,
		"move_attribute": _current_move.attribute_label() if _current_move != null else "",
		"crouching": player_crouching,
		"guard": player_guard,
		"guard_stun_left": player_guard_stun_left,
		"hitstun_left": player_hitstun_left,
		"dummy_move_id": dummy_move_id,
		"dummy_phase": dummy_phase,
		"hitstop_left": _hitstop_left,
		"prejump_left": player_prejump_left,
		"landing_recovery_left": player_landing_recovery_left,
		"jump_slot_direction": _jump_slot_axis if _jump_slot_active else null,
		"jump_slot_age": jump_slot_age,
		"buffered_key": _buffered_key,
		"buffered_move_id": _buffered_move_id,
		"buffer_age": buffer_age,
		"held_action_keys": _key_held.duplicate(),
		"pending_combination": _pending_throw_physics > 0,
		"throw_window_left": throw_window_left,
		"buffer_consumed_move_id": _buffer_consumed_move_id,
		"buffer_consumed_frame": _buffer_consumed_frame,
		"direction_sequence": _collapsed_direction_sequence(),
		"direction_locks": _direction_lock_entries(),
		"cancel_targets": _cancel_targets.duplicate(),
		"cancel_age": cancel_age,
		"cancel_open": _cancel_window_open(),
		"velocity": player_velocity,
	}


# --- 结算管线（顺序不可调换）---

func _phase_input() -> void:
	## 1. 记录输入：到期的缓存先过期，再记录本帧方向与动作键（最新输入覆盖旧输入）。
	##    动作键在输入帧（匹配锚点）按姿态与方向历史锁定为具体招式；跳跃与移动在
	##    运动阶段生效，Space 与方向输入不占动作键缓存。指令识别成功时消费所选
	##    终点及之前的全部方向历史，终点后的历史保留。
	##    显式组合（B+C 投，issue 17）在单键写入前配对：配齐即消费两个按下事件并
	##    记录组合意图（配齐帧为组合输入时点），本帧不再写单键缓存；参与组合的
	##    成员单键在配对窗口内只是候选，窗口末帧起按单键处理（保留原按下帧的
	##    姿态、方向匹配与缓存起龄点，此时才消费锁定的方向历史）。
	##    冻结帧也走本函数：正常帧时钟暂停使到期检查成为空操作，方向与动作键
	##    照常采样记录（最新覆盖旧输入），只是不起动、不取消、不消费；组合配对
	##    与等待按物理帧推进（Hitstop 不合并相隔超过 3 帧的两键）。停顿中记录的
	##    输入按恢复首个正常帧起算年龄（恢复帧年龄 0，与跳跃槽同一口径）。
	var input_stamp := _input_stamp()
	if _buffered_key != "" and _normal_frame_index - _buffered_at >= GameParams.ACTION_BUFFER_FRAMES:
		_clear_buffer()
	if _jump_slot_active and _normal_frame_index - _jump_slot_at >= GameParams.ACTION_BUFFER_FRAMES:
		_jump_slot_active = false
	_record_direction()
	_record_action_key_events()
	var combination_completed := false
	if _table_has_throw:
		combination_completed = _check_throw_combination()
	## 更新的动作输入覆盖停顿中记录的投组合意图（同帧配齐的按键不视为“更新”）。
	if not combination_completed and not _frame_input.pressed_action_keys.is_empty() \
			and _pending_throw_physics > 0 and _frame_index > _pending_throw_physics:
		_pending_throw_physics = 0
	if not combination_completed and _frame_input.action_key != "":
		_buffered_key = _frame_input.action_key
		_buffered_at = input_stamp
		_buffered_physics = _frame_index
		_buffer_waiting = _table_has_throw and _is_combination_member(_buffered_key)
		var selected := _select_move_for_key(_frame_input.action_key, _current_stance(), input_stamp)
		_buffered_move_id = selected["move_id"]
		_buffered_endpoint = int(selected["endpoint"])
		if not _buffer_waiting and _buffered_move_id != "" and _buffered_endpoint >= 0:
			_consume_direction_history_through(_buffered_endpoint)
	## 组合等待到期：配对窗口末帧（按下 + 3 个物理帧）起按单键处理。
	if _buffer_waiting and _frame_index >= _buffered_physics + GameParams.THROW_COMBINATION_TOLERANCE:
		_buffer_waiting = false
		if _buffered_move_id != "" and _buffered_endpoint >= 0:
			_consume_direction_history_through(_buffered_endpoint)
	## 跳跃输入槽独立记录：Space+下不触发跳跃（下方向优先），按下即冻结
	## 当帧世界水平跳向；最新按下覆盖旧请求，按住不重复。
	if _frame_input.jump_pressed and not _frame_input.down_held:
		_jump_slot_active = true
		_jump_slot_at = input_stamp
		_jump_slot_physics = _frame_index
		_jump_slot_axis = _frame_input.move_axis
	if _hitstop_left > 0:
		## 冻结帧到此为止：姿态与木桩请求属于结算，停顿中不推进。
		return
	_update_posture()
	_process_dummy_request()


## 原始动作键事件记录（issue 17）：新按下写入按下记录（最新覆盖，标记未消费），
## 按住集合直接快照。记录只描述输入，不参与单键选择；组合配对与“配齐帧仍全部
## 按住”从这里读取。
func _record_action_key_events() -> void:
	_key_held = _frame_input.held_action_keys.duplicate()
	for key in _frame_input.pressed_action_keys:
		_key_presses[key] = [_frame_index, false]


func _is_combination_member(key: String) -> bool:
	return MoveData.is_throw_combination_member(key)


## B+C 显式组合配对（issue 17）：本帧有成员键新按下时，检查搭档是否有 ≤3 个
## 物理帧内未消费的新按下、且两键本帧都按住——配齐即消费两个按下事件、记录
## 组合意图（消费阶段尝试执行）；等待中的成员单键候选随之作废（组成按下事件
## 只贡献这一次组合，不能补发单键）。首键提前松开、仅有长期按住或超出容差的
## 按下都不配对。
func _check_throw_combination() -> bool:
	for key in _frame_input.pressed_action_keys:
		if not _is_combination_member(key):
			continue
		var partner := "C" if key == "B" else "B"
		if not _key_held.has(key) or not _key_held.has(partner):
			continue
		if not _key_presses.has(partner):
			continue
		var partner_press: Array = _key_presses[partner]
		if bool(partner_press[1]) or _frame_index - int(partner_press[0]) > GameParams.THROW_COMBINATION_TOLERANCE:
			continue
		(_key_presses[key] as Array)[1] = true
		partner_press[1] = true
		_pending_throw_physics = _frame_index
		if _is_combination_member(_buffered_key):
			_clear_buffer()
		return true
	return false


## 木桩确定性攻击请求：仅在木桩空闲（中立、落地、无进行中招式）时按请求起手，
## 请求帧为该招式第 1 帧；其余状态静默忽略（木桩无自主决策，不排队、不补发）。
func _process_dummy_request() -> void:
	if _frame_input.dummy_move_request == "" or _dummy_move != null:
		return
	if dummy_state != DummyState.NEUTRAL or not dummy_on_ground:
		return
	var move := _moves.get(_frame_input.dummy_move_request) as MoveData
	if move == null or not move.is_strike():
		return
	_dummy_move = move
	dummy_move_id = move.move_id
	## 起始记 0：本帧运动阶段推进为第 1 帧——请求帧即该招式 F1，判定最早出现
	## 在请求 + startup 帧（与玩家消费起手的帧序同一口径）。
	_dummy_move_frame = 0
	_dummy_hit_once = false
	dummy_phase = PlayerPhase.STARTUP


## 姿态解析（蹲下与防御，issue 16）：先于命中判定，使当帧进入的蹲下/防御
## 参与同帧的防御判定。地面自由行动时 1/2/3 当帧蹲下（水平分量照常保留）、
## 4 站防、1 蹲防；真正离地后 4/1 均为空防、下方向只保留运动输入。
## 招式阶段、受击/防御硬直、pre-jump 与空技落地恢复中姿态冻结——防御硬直
## 冻结即保持原防御姿态（连防），受击硬直冻结即不因下方向强行改姿态。
## 空跳落地恢复第 2、3 帧与自由行动同门（可蹲可防）。
func _update_posture() -> void:
	if not _posture_reeval_open():
		return
	if not player_on_ground:
		player_crouching = false
		player_guard = GuardPosture.AIR if _holding_back() else GuardPosture.NONE
		return
	player_crouching = _frame_input.down_held
	if _holding_back():
		player_guard = GuardPosture.CROUCH if player_crouching else GuardPosture.STANDING
	else:
		player_guard = GuardPosture.NONE


## 玩家是否处于受击/防御硬直（姿态冻结、不可出招/起跳/移动的共同判式）。
func _player_stunned() -> bool:
	return player_hitstun_left > 0 or player_guard_stun_left > 0


## 清空蹲下/防御姿态（出招、起跳准备与落地首帧统一入口）。
func _clear_posture() -> void:
	player_crouching = false
	player_guard = GuardPosture.NONE


## 木桩攻击方向：木桩指向玩家一侧的水平符号（与玩家攻击用 player_facing 同构；
## 木桩无面向状态，按双方位置即时折算，确定性成立）。
func _dummy_attack_direction() -> int:
	return 1 if player_position.x >= dummy_position.x else -1


## 姿态重解析门：出招、受击/防御硬直、pre-jump 与空技落地恢复关闭；
## 空跳落地恢复第 2、3 帧开放（与独立起手同一口径）。输入阶段读到的是含当帧
## 的恢复倒计时（本帧运动归零 = 首个自由帧），因此以 >1 判受限，与消费阶段
## 的起手门时序一致。
func _posture_reeval_open() -> bool:
	if _current_move != null:
		return false
	if _player_stunned():
		return false
	if player_prejump_left > 0:
		return false
	if player_landing_recovery_left > 1 and _air_move_started:
		return false
	return true


## 是否按住“后”（相对帧首面向折算；与方向历史同一口径）。
func _holding_back() -> bool:
	return _frame_input.move_axis == -player_facing


## 输入记录时间戳（正常帧时钟口径）：正常帧记当前时钟；冻结帧记恢复首个正常帧
## 的时钟值——停顿中按下的输入在恢复帧年龄为 0，之后才按正常帧递增。
func _input_stamp() -> int:
	return _normal_frame_index + (1 if _hitstop_left > 0 else 0)


func _record_direction() -> void:
	## 方向历史只记录变化：先把（水平轴、下方向、面向）折算成小键盘数字，
	## 与上一帧不同才入历史；先清理超过表内最长指令窗口的过期条目（各指令自己的
	## 窗口在识别时按实际 variant 步数检查，这里只保证可能仍被需要的段不被丢弃）。
	## 条目时间戳与过滤都用正常帧时钟：Hitstop 不消耗方向窗口；停顿中记录的
	## 段同样按恢复首个正常帧起算年龄。
	_direction_history = _direction_history.filter(
		func(entry: Vector2i) -> bool: return _normal_frame_index - entry.y < _direction_retention
	)
	var digit := _direction_digit()
	if digit != _last_direction_digit:
		_direction_history.append(Vector2i(digit, _input_stamp()))
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
	if player_phase == PlayerPhase.ACTIVE and not _hit_once_this_move and _current_move != null \
			and _current_move.is_strike() \
			and player_attack_rect().intersects(_dummy_body_rect()) and _can_hit_dummy():
		_hit_once_this_move = true
		_pending_hit = _current_move
	## 木桩打击的对称判定：判定帧内检查木桩命中框与玩家身体的几何重叠，
	## 每次挥击至多连接一次（防御或命中在受击应用阶段结算）。同帧双方都在
	## 判定时按先玩家、后木桩的固定顺序应用（互换命中有效）。
	_pending_dummy_hit = null
	if dummy_phase == PlayerPhase.ACTIVE and not _dummy_hit_once \
			and dummy_attack_rect().intersects(_player_body_rect()):
		_dummy_hit_once = true
		_pending_dummy_hit = _dummy_move


func _phase_apply_hits(events: Array[CombatEvent]) -> void:
	## 3. 受击应用：先结算玩家对木桩的命中，再结算木桩对玩家的连接（防御或
	## 命中）。两侧各自独立判定是否存在，不能因一侧无命中而跳过另一侧。
	if _pending_hit != null:
		_apply_player_hit(events)
	_phase_apply_dummy_hit(events)


func _apply_player_hit(events: Array[CombatEvent]) -> void:
	## 玩家命中木桩的结算：连段伤害递减、受击状态、硬直与击退。
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
	## 木桩受击打断其进行中的攻击（本帧已捕获的连接仍按互换命中结算）。
	_clear_dummy_move()
	dummy_velocity.x = player_facing * move.knockback
	if move.hit_result == MoveData.HitResult.LAUNCH:
		## 浮空命中必定重起跳：即使木桩仍在上一击的微浮中也给予完整滞空；
		## 普通命中只在地面附带击飞，追击不会刷新滞空。
		dummy_velocity.y = -move.knockback_up
	elif dummy_on_ground:
		dummy_velocity.y = -move.knockback_up
	_move_hit_confirmed = true
	_hit_confirm_frame = _normal_frame_index
	events.append(CombatEvent.hit(combo_last_damage, player_facing, combo_hits))
	## 命中帧完成命中与受击应用后开始 Hitstop：冻结后续 8 个物理帧（双方动作、
	## 位置、速度、受击、落地与受身计时暂停；物理帧号照常递增，输入仍被采样记录）。
	_hitstop_left = GameParams.HITSTOP_FRAMES
	events.append(CombatEvent.hitstop_started())
	if move.is_finisher:
		## 收尾结束连段路线，但不主动清除木桩的受击/倒地处理。
		_end_combo(CombatEvent.ComboEndReason.FINISHER, events)
	_pending_hit = null


## 木桩打击对玩家的结算（issue 16）：防御姿态按显式属性矩阵判定。挡下 →
## 防御硬直（= 打击 hitstun）+ BLOCKED 事件 + Hitstop；漏防或无姿态 → 玩家
## 受击硬直 + 水平击退 + PLAYER_HIT 事件 + Hitstop（进行中的招式被打断，连段
## 以收招未接续结束）。玩家无生命值系统，打击数据对玩家只作用硬直与位移。
func _phase_apply_dummy_hit(events: Array[CombatEvent]) -> void:
	if _pending_dummy_hit == null:
		return
	var move := _pending_dummy_hit
	var direction := _dummy_attack_direction()
	if _blocks_attack(move):
		player_guard_stun_left = move.hitstun_frames
		events.append(CombatEvent.blocked(direction))
	else:
		if _current_move != null:
			_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
			_clear_current_move()
		player_hitstun_left = move.hitstun_frames
		player_velocity.x = direction * move.knockback
		events.append(CombatEvent.player_hit(direction))
	_player_fresh_stun = true
	if _hitstop_left == 0:
		## 同帧互换命中（玩家先命中木桩）只开启一个停顿窗口、只报一次边界事件。
		_hitstop_left = GameParams.HITSTOP_FRAMES
		events.append(CombatEvent.hitstop_started())
	_pending_dummy_hit = null


## 防御姿态 × 攻击属性矩阵：站防挡 high/mid/overhead、漏 low；蹲防挡
## high/mid/low、漏 overhead；空防默认可挡带 air 的打击（正交类别；纯地面
## 属性不在空防默认域内，未来例外须显式声明）；无姿态不挡。
## 受击硬直中被打破的防御不提供保护——硬直期间一律不挡（姿态可观测量冻结
## 只是"不改姿态"，不代表仍在防御）。
func _blocks_attack(move: MoveData) -> bool:
	if player_hitstun_left > 0:
		return false
	match player_guard:
		GuardPosture.STANDING:
			return move.attack_attribute != MoveData.AttackAttribute.LOW
		GuardPosture.CROUCH:
			return move.attack_attribute != MoveData.AttackAttribute.OVERHEAD
		GuardPosture.AIR:
			return move.air_attack
		_:
			return false


func _phase_motion(events: Array[CombatEvent]) -> void:
	## 4. 运动/落地/自然受身：先按已应用的速度积分位置，再处理落地、
	## 身体重叠与木桩自然受身；招式帧计数也在本阶段末尾推进。
	_motion_player(events)
	_motion_dummy(events)
	_update_free_action_facing()
	_resolve_body_overlap()
	_advance_move(events)
	_advance_dummy_move()


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
	##    跳跃输入槽独立消费（issue 15）：地面中立普通跳或命中确认 jump cancel
	##    都转入 4f 起跳准备。显式组合（B+C 投，issue 17）优先级最高：先尝试
	##    已配齐的投意图、结算拆投与投结果，之后 jump 与动作缓存同时合法时比较
	##    原始请求物理帧——较新者优先、同一物理帧攻击优先，每帧最多启动一个
	##    新动作；未选中的槽保留原年龄，后续帧按新状态重查。
	_attempt_pending_throw(events)
	_evaluate_throw_tech(events)
	_apply_throw_result(events)
	var action := _buffer_action_candidate()
	if not action.is_empty() and _jump_slot_ready():
		if _jump_slot_physics > _buffered_physics:
			_consume_jump()
		else:
			_consume_action_candidate(action)
	elif not action.is_empty():
		_consume_action_candidate(action)
	elif _jump_slot_ready():
		_consume_jump()
	## 空中招式落地：本帧没有配置的落地接续发生时，滞留地面姿态的空中招式作废
	## （空中路线不因落地延续），连段以收招未接续结束。
	if _current_move != null and _current_move.stance == MoveData.Stance.AIR and player_on_ground:
		_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
		_clear_current_move()
	## 命中确认取消窗口关闭且没有接续时连段结束；木桩受击处理不受影响。
	## 窗口年龄按正常战斗帧计：Hitstop 之后关闭帧相应后移。
	if _current_move != null and _move_hit_confirmed and combo_active \
			and _normal_frame_index - _hit_confirm_frame > _current_move.cancel_window_frames:
		_end_combo(CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED, events)


func _buffer_action_candidate() -> Dictionary:
	## 动作缓存的当帧可消费候选（判据唯一来源，仲裁与执行共用）：
	## {"move_id": 起手招式, "is_followup": 合法接续起手, "relanded": 落地重解析路径}。
	## 无候选返回空表。组合等待中的成员单键只是候选，不参与消费（issue 17）。
	if _buffered_key == "" and _buffered_move_id == "":
		return {}
	if _buffer_waiting:
		return {}
	if _player_just_landed:
		var relanded := _select_move_for_key(_buffered_key, _current_stance(), _buffered_at)
		if _startable_cancel(String(relanded["move_id"])):
			return {"move_id": relanded["move_id"], "is_followup": true, "relanded": true}
	if _startable_cancel(_buffered_move_id):
		return {"move_id": _buffered_move_id, "is_followup": true}
	if _current_move != null or not _independent_start_allowed():
		return {}
	var buffered := _moves.get(_buffered_move_id) as MoveData
	if buffered != null and _stance_matches(buffered):
		return {"move_id": _buffered_move_id, "is_followup": combo_active and _jump_cancel_followups.has(_buffered_move_id)}
	return {}


func _consume_action_candidate(action: Dictionary) -> void:
	## 执行 `_buffer_action_candidate` 给出的候选：取消路径按合法接续起手并
	## 消费缓存；独立起手走空闲起手。落地重解析路径先按锚点消费方向历史。
	if bool(action.get("relanded", false)):
		var relanded := _select_move_for_key(_buffered_key, _current_stance(), _buffered_at)
		if relanded["move_id"] != "" and int(relanded["endpoint"]) >= 0:
			## 落地重解析识别出方向指令：与输入帧锚点同一消费口径，终点及之前
			## 的历史一并消费（识别即消费，与是否真正起手无关）。
			_consume_direction_history_through(int(relanded["endpoint"]))
	var move_id := String(action["move_id"])
	if _try_start_cancel(move_id):
		return
	var is_followup := bool(action["is_followup"])
	_start_move(move_id, _moves.get(move_id) as MoveData, is_followup)
	_note_buffer_consumed(move_id)
	_clear_buffer()
	if is_followup:
		_jump_cancel_followups.clear()


func _independent_start_allowed() -> bool:
	## 缓存独立起手的状态门：pre-jump 四帧只可取消到显式配置的地面必杀——
	## 当前数据模型未定义该配置位（spec 可选字段清单不含 pre-jump 取消目标），
	## 因此准备期间一律只记录不消费。落地恢复首帧完全锁定（配置的落地接续走
	## 取消路径，不受影响）；空跳恢复第 2、3 帧可取消为合法攻击；启动过空中
	## 招式的落地恢复基础及额外恢复全程不可取消（挥空同样受限）。
	## 受击硬直与防御硬直期间不可独立起手；投与蹲下/防御的姿态门各自独立判定。
	if _player_stunned():
		return false
	if player_prejump_left > 0:
		return false
	if _player_just_landed:
		return false
	if player_landing_recovery_left > 0:
		return not _air_move_started
	return true


func _jump_slot_ready() -> bool:
	## 跳跃输入槽的当帧合法性：起跳准备、落地恢复、受击/防御硬直与空中一律
	## 不可消费（无二段跳；受限恢复期不重新起跳）。地面中立是普通跳；招式阶段
	## 需要 jump cancel 配置 + 命中确认 + 取消窗口 + 可追击木桩同时成立。
	if not _jump_slot_active:
		return false
	if _player_stunned():
		return false
	if player_prejump_left > 0 or player_landing_recovery_left > 0:
		return false
	if not player_on_ground:
		return false
	if _current_move == null:
		return player_phase == PlayerPhase.NEUTRAL
	return _can_jump_cancel()


func _consume_jump() -> void:
	## 消费跳跃请求：冻结按下帧世界跳向并进入 4f 起跳准备（请求接受帧为
	## 准备第 1 帧，倒数在运动阶段推进）。jump cancel 起跳取消当前招式、保留
	## 连段并开放配置的空中追击起手；不重置原取消窗口或跳跃计时。
	_jump_slot_active = false
	_jump_direction = _jump_slot_axis
	player_prejump_left = GameParams.PLAYER_PREJUMP_FRAMES
	## pre-jump 不新进入防御/蹲下：起跳准备期间姿态为空。
	_clear_posture()
	if _current_move != null:
		_jump_cancel_followups.clear()
		_jump_cancel_followups.append_array(_current_move.jump_cancel_targets)
		_clear_current_move()


# --- 普通投结算（issue 17）---

## 普通投执行门：仅地面站立、可自由行动可投（蹲下、pre-jump、空中、招式阶段、
## 受击/防御硬直与落地恢复一律禁用——空跳恢复第 2、3 帧的攻击例外不适用于投）。
## 投距 = 身体中心水平距离 ≤ 投技 throw_range 且身体矩形垂直重叠。
## 返回 0（可执行）、ThrowFailReason.STATE 或 ThrowFailReason.RANGE。
func _throw_start_gate() -> int:
	if _current_move != null or _player_stunned() or not player_on_ground \
			or player_prejump_left > 0 or player_landing_recovery_left > 0 or player_crouching:
		return CombatEvent.ThrowFailReason.STATE
	if absf(player_position.x - dummy_position.x) > _throw_move.throw_range:
		return CombatEvent.ThrowFailReason.RANGE
	if absf(player_position.y - dummy_position.y) >= GameParams.BODY_SIZE.y:
		return CombatEvent.ThrowFailReason.RANGE
	return 0


## 已配齐的投组合意图：配齐当帧（或停顿后恢复首个正常帧）尝试一次。状态或
## 投距不满足即拒绝并结束请求——不等待之后收招或进入投距，也不回退 B/C；
## 重新尝试必须有新组合输入。投起手走与独立招式同一口径（F1 = 配齐帧）。
func _attempt_pending_throw(events: Array[CombatEvent]) -> void:
	if _pending_throw_physics == 0 or _throw_move == null:
		return
	_pending_throw_physics = 0
	var gate := _throw_start_gate()
	if gate != 0:
		events.append(CombatEvent.throw_failed(gate))
		return
	_start_move(_throw_move.move_id, _throw_move, false)
	_throw_result_applied = false
	_note_buffer_consumed(_throw_move.move_id)
	## 无关的更新输入（如同帧前的 D）不因投起手被丢弃：单槽缓存按自身年龄
	## 继续存在，投进行中不可消费、之后按正常规则过期或起手。


## 拆投：窗口从首个 startup 帧到投发生后延续 10f 的末帧（active_to，含两端）。
## 窗口内的木桩拆投请求阻止投结果——投被当帧打破，玩家回中立、木桩不受任何
## 投结果影响；结果已成立或窗口已关的请求无效。
func _evaluate_throw_tech(events: Array[CombatEvent]) -> void:
	if not _frame_input.dummy_tech_request:
		return
	if _current_move == null or not _current_move.is_throw() or _throw_result_applied:
		return
	if _move_frame > _current_move.active_to():
		return
	_clear_current_move()
	events.append(CombatEvent.throw_teched())


## 投结果：拆投窗口关闭当帧一次性成立——木桩沿投向击退并进入地面受击硬直
## （投不造成 HP 伤害、不进入连段计数）；投结果打断木桩进行中的攻击（与玩家
## 命中木桩同一口径）。同帧拆投先于本判定，窗口末帧拆投仍然成立。
func _apply_throw_result(events: Array[CombatEvent]) -> void:
	if _current_move == null or not _current_move.is_throw() or _throw_result_applied:
		return
	if _move_frame < _current_move.active_to():
		return
	_throw_result_applied = true
	dummy_state = DummyState.GROUND_HITSTUN
	dummy_hitstun_left = GameParams.THROW_HITSTUN_FRAMES
	_dummy_fresh_hitstun = true
	_clear_dummy_move()
	dummy_velocity.x = player_facing * GameParams.THROW_KNOCKBACK
	events.append(CombatEvent.throw_hit(player_facing))


func _startable_cancel(move_id: String) -> bool:
	## 命中确认取消的资格判据（无副作用）：目标在开放名单内、姿态一致且
	## 当前有招式在执行。
	var move := _moves.get(move_id) as MoveData
	return move != null and _stance_matches(move) and _current_move != null and _cancel_targets.has(move_id)


func _try_start_cancel(move_id: String) -> bool:
	## 命中确认取消：目标在开放名单内且姿态一致时按合法接续起手并消费缓存。
	if not _startable_cancel(move_id):
		return false
	_start_move(move_id, _moves.get(move_id) as MoveData, true)
	_note_buffer_consumed(move_id)
	_clear_buffer()
	return true


## 诊断记录：缓存被真正消费（起手）的结果与所在物理帧（issue 14 可观察性口径）。
func _note_buffer_consumed(move_id: String) -> void:
	_buffer_consumed_move_id = move_id
	_buffer_consumed_frame = _frame_index


# --- 运动细节 ---

func _motion_player(events: Array[CombatEvent]) -> void:
	## 起跳准备与落地恢复都在运动阶段按正常帧倒数（停顿帧不推进）：消费阶段
	## 把 pre-jump 置为 4，倒数到 0 的当帧离地——首个空中帧当帧不加重力
	## （与木桩浮空同一积分方式，滞空恰为 PLAYER_JUMP_AIRTIME_FRAMES 帧）。
	## 出招期间水平输入失效，只保留摩擦减速（地面/空中一致）；普通空中运动
	## 保留起跳横向速度：方向输入不加速、不减速、也不翻转面向。
	var takeoff_this_frame := false
	if _player_fresh_stun:
		## 命中/防御帧不消耗新硬直（与木桩受击同口径）；停顿帧不进入本函数，
		## 硬直倒数自然冻结。受击硬直滞空暂停消耗（与木桩地面硬直同口径）；
		## 防御硬直无滞空变体（空防在空中挡下），落地与否都逐帧倒数。
		_player_fresh_stun = false
	elif player_hitstun_left > 0 and player_on_ground:
		player_hitstun_left -= 1
	elif player_guard_stun_left > 0:
		player_guard_stun_left -= 1
	if player_prejump_left > 0:
		player_prejump_left -= 1
		takeoff_this_frame = player_prejump_left == 0
	elif player_landing_recovery_left > 0:
		player_landing_recovery_left -= 1
	var axis := _frame_input.move_axis
	if (player_prejump_left > 0 or takeoff_this_frame) and _jump_direction != 0:
		## 起跳准备按消费时冻结的世界跳向移动（含离地当帧——首个空中帧前方向
		## 仍属准备期）：反向输入不重写斜跳请求；原始 8 请求（冻结方向为 0）
		## 仍用当前输入改成斜跳，不重置准备计时。
		axis = _jump_direction
	## 出招与受击/防御硬直期间水平输入失效，只保留摩擦减速（地面/空中一致）；
	## 普通空中运动保留起跳横向速度：方向输入不加速、不减速、也不翻转面向。
	var stunned := _player_stunned()
	if player_phase == PlayerPhase.NEUTRAL and not stunned:
		if player_on_ground:
			if axis != 0:
				player_velocity.x = move_toward(player_velocity.x, axis * GameParams.PLAYER_MOVE_SPEED, GameParams.PLAYER_ACCELERATION * GameParams.PHYSICS_TICK)
			else:
				player_velocity.x = move_toward(player_velocity.x, 0.0, GameParams.PLAYER_FRICTION * GameParams.PHYSICS_TICK)
	else:
		player_velocity.x = move_toward(player_velocity.x, 0.0, GameParams.PLAYER_FRICTION * GameParams.PHYSICS_TICK)
	if not player_on_ground:
		player_velocity.y = minf(player_velocity.y + GameParams.GRAVITY * GameParams.PHYSICS_TICK, GameParams.MAX_FALL_SPEED)
	if takeoff_this_frame:
		_takeoff()
	player_position += player_velocity * GameParams.PHYSICS_TICK
	player_position.x = clampf(player_position.x, GameParams.stage_left_limit(), GameParams.stage_right_limit())
	if player_position.y >= GameParams.ground_stand_y():
		player_position.y = GameParams.ground_stand_y()
		if player_velocity.y > 0.0:
			player_velocity.y = 0.0
		var just_landed := not player_on_ground
		player_on_ground = true
		_player_just_landed = just_landed
		if just_landed:
			_begin_landing_recovery()
			## 落地恢复首帧统一不可蹲/不可防御：当帧钳掉空中姿态，下一帧起按
			## 落地恢复门重解析（空跳第 2、3 帧恢复，空技恢复全程关闭）。
			_clear_posture()
			if not _jump_cancel_followups.is_empty():
				# jump cancel 后落地仍未接续空中追击：追击资格作废，连段以收招未接续结束。
				_jump_cancel_followups.clear()
				if combo_active and _current_move == null:
					_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
	else:
		player_on_ground = false


func _can_jump_cancel() -> bool:
	## jump cancel 资格：与动作键取消共用同一命中确认取消窗口，外加本招配置了
	## 空中追击起手。
	return _cancel_window_open() and not _current_move.jump_cancel_targets.is_empty()


func _takeoff() -> void:
	## 离地：首个空中帧，起跳速度按滞空帧数换算；空中招式跟踪复位——本次
	## 跳跃尚未启动任何空中招式。空中阶段保留此刻的横向速度。
	player_velocity.y = -GameParams.jump_velocity()
	player_on_ground = false
	_air_move_started = false
	_air_extra_recovery = 0


func _begin_landing_recovery() -> void:
	## 落地恢复：基础 3f；本次跳跃启动过空中招式 startup 默认 +1f（每跳一次，
	## 挥空同样计入），空中招式资源的 extra_landing_recovery_frames 显式叠加。
	## 延长不改变空中阶段或 active 长度；按正常帧倒数（停顿帧不推进），恢复
	## 结束才回到地面自由行动。恢复期间的动作限制在消费阶段判定。
	var total := GameParams.PLAYER_LANDING_RECOVERY_BASE_FRAMES
	if _air_move_started:
		total += GameParams.PLAYER_AIR_ATTACK_LANDING_PENALTY_FRAMES + _air_extra_recovery
	player_landing_recovery_left = total
	## 落地恢复首帧的攻击只保留原始输入、不进入可执行缓存：落地当帧新按下的
	## 动作键从缓存移除（更早的按下保留原龄，恢复结束后按新状态重查）。
	if _buffered_key != "" and _buffered_physics == _frame_index:
		_clear_buffer()


func _cancel_window_open() -> bool:
	## 命中确认取消窗口：已命中确认、连段仍活跃、木桩仍可追击，且命中后年龄
	## 仍在窗口内（0–N 正常战斗帧含两端；Hitstop 帧不计龄）。动作键取消与
	## jump cancel 共用本判定。
	if _current_move == null or not _move_hit_confirmed or not combo_active:
		return false
	if not _dummy_pursuable():
		return false
	var age := _normal_frame_index - _hit_confirm_frame
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


## 地面自由行动（中立/移动/蹲下；出招、受击/防御硬直与空中除外）时每帧面向
## 木桩：在双方运动与位置更新后、身体重叠推出前重新指向，本帧的面向变化从下
## 一物理帧的方向折算生效；后退不翻面，与木桩横向重合时保持当前面向。出招、
## 受击硬直、倒地处理和空中阶段不进入本函数，保持进入该阶段时的面向；防御
## 硬直与受击硬直同口径冻结。落地完成后的首个地面自由行动帧由本函数重新面向木桩。
func _update_free_action_facing() -> void:
	if player_phase != PlayerPhase.NEUTRAL or not player_on_ground:
		return
	if _player_stunned():
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


## 木桩招式帧计数在运动阶段末尾推进（与玩家同一口径；停顿帧不推进）。
func _advance_dummy_move() -> void:
	if _dummy_move == null:
		return
	_dummy_move_frame += 1
	if _dummy_move_frame < _dummy_move.active_from():
		dummy_phase = PlayerPhase.STARTUP
	elif _dummy_move_frame <= _dummy_move.active_to():
		dummy_phase = PlayerPhase.ACTIVE
	elif _dummy_move_frame < _dummy_move.total_frames():
		dummy_phase = PlayerPhase.RECOVERY
	else:
		_clear_dummy_move()


func _clear_dummy_move() -> void:
	_dummy_move = null
	dummy_move_id = ""
	dummy_phase = PlayerPhase.NEUTRAL
	_dummy_move_frame = 0
	_dummy_hit_once = false


func _start_move(move_id: String, move: MoveData, is_followup: bool) -> void:
	_current_move = move
	player_move_id = move_id
	_move_frame = 1
	_hit_once_this_move = false
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_is_followup = is_followup
	player_phase = PlayerPhase.STARTUP
	## 招式阶段替换姿态：出招期间不蹲不防，收招后按输入重解析。
	_clear_posture()
	if move.stance == MoveData.Stance.AIR and not player_on_ground:
		## 空中招式启动即计入本次跳跃的着地惩罚（默认 +1f 一次）与显式额外恢复。
		_air_move_started = true
		_air_extra_recovery += move.extra_landing_recovery_frames


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
	_buffer_waiting = false
	_buffered_endpoint = -1


# --- 指令输入规则（issue 13：宽松谓词、候选锁定、variant 计窗与分层选招）---

## 动作键解析使用的姿态：空中按 AIR、地面按 GROUND（识别在输入帧按此锁定）。
## 离地当帧也按 AIR——输入阶段仍踩地、运动阶段才离地，但 spec 规定下一个
## 正常帧"离地并按空中姿态解析"（起跳准备剩余计数 1 即离地当帧；准备四帧
## 本身仍全部按地面姿态）。
func _current_stance() -> MoveData.Stance:
	if not player_on_ground or player_prejump_left == 1:
		return MoveData.Stance.AIR
	return MoveData.Stance.GROUND


## 动作键事件选招：同一绑定的当前姿态招式中，按「指令层级（超必杀 > 普通必杀 >
## 普通拳脚）→ 同层 priority」的确定性顺序选择。方向指令招式需要有效窗口内的
## 完成候选，无方向记法的招式恒可匹配。同层同优先级并列属于非法数据（共享表由
## MoveTable 校验拒绝）；注入表自负其稳定性，先到者保留。
## 返回 {"move_id": 招式 id, "endpoint": 识别候选的终点帧（无方向匹配为 -1）}。
func _select_move_for_key(action_key: String, stance: MoveData.Stance, anchor_frame: int) -> Dictionary:
	var best := {"move_id": "", "endpoint": -1}
	if action_key == "":
		return best
	var best_tier := -1
	var best_priority := -1
	var segments := _direction_segments(anchor_frame)
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move == null or move.stance != stance or not move.is_strike() or move.action_key != action_key:
			continue
		var endpoint := -1
		if _has_direction_notation(move):
			var candidate := _best_valid_candidate(move, anchor_frame, segments)
			if candidate.is_empty():
				continue
			endpoint = candidate["endpoint"]
		if move.command_tier > best_tier or (move.command_tier == best_tier and move.priority > best_priority):
			best_tier = move.command_tier
			best_priority = move.priority
			best = {"move_id": move_id, "endpoint": endpoint}
	return best


## 招式在当前方向段中的最佳候选：全部记法（基础派生 + 显式替代串）逐一匹配，
## 输入窗口按各记法实际步数计（步数 × 每方向步长，含首段帧）。候选选择：
## 最近完成者优先；终点同帧选起点更近者（起点更近窗口更晚到期，旧候选过期
## 不阻塞新候选）。
func _best_valid_candidate(move: MoveData, anchor_frame: int, segments: Array[Vector2i]) -> Dictionary:
	var best := {}
	for notation in _move_notations(move):
		var digits := notation.left(notation.length() - 1)
		var window := digits.length() * GameParams.DIRECTION_STEP_FRAMES
		for i in range(segments.size()):
			var candidate := _match_direction_from(digits, move.lenient_command, segments, i)
			if candidate.is_empty():
				continue
			if anchor_frame - int(candidate["start"]) >= window:
				continue
			if best.is_empty() or int(candidate["endpoint"]) > int(best["endpoint"]) \
					or (int(candidate["endpoint"]) == int(best["endpoint"]) and int(candidate["start"]) > int(best["start"])):
				best = candidate
	return best


## 从第 start_index 个方向段起匹配谓词序列，返回 {"start": 帧, "endpoint": 帧}。
## 严格（默认）：连续方向段精确等于记法数字，且终点必须是最后一个方向段——
## 段间或终点后插入其他非中立方向都会使候选失败；终点前的旧段不阻塞（后退后
## 搓招），中立只占窗口不成段。宽松：每段按轴谓词集合匹配，不满足当前谓词的
## 段作为额外段跳过；一个段最多推进一个谓词步骤，不能同时满足相邻步骤；
## 完成前置谓词后在第一个满足终点谓词的段锁定（后续段不改写终点）。
func _match_direction_from(digits: String, lenient: bool, segments: Array[Vector2i], start_index: int) -> Dictionary:
	if lenient:
		if not _lenient_set(digits[0].to_int()).has(segments[start_index].x):
			return {}
		var start_frame := segments[start_index].y
		var pending := 1
		for j in range(start_index + 1, segments.size()):
			if _lenient_set(digits[pending].to_int()).has(segments[j].x):
				pending += 1
				if pending >= digits.length():
					return {"start": start_frame, "endpoint": segments[j].y}
		return {}
	var end_index := start_index + digits.length() - 1
	if end_index != segments.size() - 1:
		return {}
	for offset in digits.length():
		if digits[offset].to_int() != segments[start_index + offset].x:
			return {}
	return {"start": segments[start_index].y, "endpoint": segments[end_index].y}


## 宽松谓词的轴集合：前 {3,6,9}、后 {1,4,7}、下 {1,2,3}、上 {7,8,9}——
## 记法数字按其轴分量归入集合（6 与 3 同为前谓词），斜方向随水平分量。
func _lenient_set(digit: int) -> Array[int]:
	match digit:
		1, 4, 7:
			return [1, 4, 7]
		3, 6, 9:
			return [3, 6, 9]
		2:
			return [1, 2, 3]
		8:
			return [7, 8, 9]
		_:
			return [digit]


## 方向段视图：方向历史滤除中立（5 不成段但占窗口）及 through_frame 之后的条目
## （锚点绑定重解析只看按下时点及之前的历史）。
func _direction_segments(through_frame := -1) -> Array[Vector2i]:
	var segments: Array[Vector2i] = []
	for entry in _direction_history:
		if entry.x == 5:
			continue
		if through_frame >= 0 and entry.y > through_frame:
			continue
		segments.append(entry)
	return segments


## 招式的全部指令记法：基础方向派生 + 显式输入替代串（每个替代串是独立 variant）。
func _move_notations(move: MoveData) -> Array[String]:
	var notations: Array[String] = []
	if move.direction_derivation != "":
		notations.append(move.direction_derivation)
	notations.append_array(move.input_alternatives)
	return notations


func _has_direction_notation(move: MoveData) -> bool:
	return move.direction_derivation != "" or not move.input_alternatives.is_empty()


## 指令识别成功后的方向消费：移除所选终点及之前的全部方向历史（含宽松匹配跳过
## 的额外段）；终点后的历史保留。消费不把持续按住的同一逻辑方向变成新段——
## 新段必须离开再进入；中立不成段，但会打断同一方向的连续按住。
func _consume_direction_history_through(frame: int) -> void:
	_direction_history = _direction_history.filter(
		func(entry: Vector2i) -> bool: return entry.y > frame
	)


## 方向历史的保留时长：表内全部指令记法的最长窗口。超过所有可能窗口的旧段
## 不可能再参与匹配，未识别输入只保留有效尾部。
func _max_direction_window(moves: Dictionary) -> int:
	var retention := GameParams.DIRECTION_STEP_FRAMES
	for move_id in moves:
		var move := moves[move_id] as MoveData
		if move == null:
			continue
		for notation in _move_notations(move):
			retention = maxi(retention, (notation.length() - 1) * GameParams.DIRECTION_STEP_FRAMES)
	return retention


## 诊断只读快照：当前姿态下各方向指令招式已锁定、且仍在自身窗口内的候选
## （宽松首个终点锁定的可观察口径）。不参与结算。
func _direction_lock_entries() -> Array[Dictionary]:
	var segments := _direction_segments(_input_stamp())
	var locks: Array[Dictionary] = []
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move == null or move.stance != _current_stance() or not move.is_strike() or not _has_direction_notation(move):
			continue
		var candidate := _best_valid_candidate(move, _normal_frame_index, segments)
		if candidate.is_empty():
			continue
		locks.append({"move_id": move_id, "start": candidate["start"], "endpoint": candidate["endpoint"]})
	return locks


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
