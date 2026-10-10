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
	NEUTRAL,            ## 中立
	GROUND_HITSTUN,     ## 地面受击硬直
	AIR_HITSTUN,        ## 浮空受击硬直（滞空期间逐帧消耗，归零即浮空受身）
	AIR_RECOVERED,      ## 空中已受身（连段已结束，落地后才恢复中立）
	KNOCKED_DOWN,       ## 普通倒地（独立倒地计时；期间不可命中，计时结束自然恢复）
	LOW_FLOAT_SWEEP,    ## 低浮空扫倒（短暂滞空的有限受击窗口；触地同帧转普通倒地）
	SPIKE_FALL,         ## 向下击落坠落（票据 04：无空中计时，触地同帧转普通倒地）
	LOW_FLOAT_TO_SLIDE, ## 击飞触地滑行前滞空（票据 05：触地转 GROUND_SLIDE，不经过倒地）
	GROUND_SLIDE,       ## 地面滑行（独立计时；仅显式 slide 资料的招式可命中覆盖，归零自然回中立）
	GROUND_BOUNCE,      ## 统一弹地（票据 09，B-01/B-02：grounded/airborne 命中都进入本状态；
	                    ## 触地前按资料运动，首次触地记 bounce_contact 并反弹一次、开放追击
	                    ## 窗口；归零自然回中立，不转普通倒地、不接受 OTG）
}

## 防御姿态：地面 4 为站防、1 为蹲防；真正离地后 4/1 均为空防。
## pre-jump、落地恢复首帧与空技恢复全程不进入防御（issue 16）。
enum GuardPosture {
	NONE = 0,     ## 未防御
	STANDING = 1, ## 站防：挡 high/mid/overhead，漏 low
	CROUCH = 2,   ## 蹲防：挡 high/mid/low，漏 overhead
	AIR = 3,      ## 空防：默认挡带 air 的打击（正交 air 类别）
}

## Versioned format for the execution seam.  This is deliberately separate from
## settlement_state(): settlement_state() is a compact solver key, while this
## format contains every mutable value that can affect the next step().
const STATE_FORMAT := "CombatSessionState/v1"

# --- 可观察的玩家状态 ---
var player_position: Vector2
var player_velocity: Vector2
var player_facing := 1
var player_phase: PlayerPhase = PlayerPhase.NEUTRAL
var player_on_ground := true
## 当前执行的招式 id（空闲时为空串）。
var player_move_id := ""
## 是否处于蹲下姿态（地面自由行动时 1/2/3 当帧进入并停止主动水平移动）。
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
## 剩余普通倒地帧数（含当前帧；独立于受击硬直计时，归零自然恢复回中立）。
var dummy_knockdown_left := 0
## 剩余地面滑行帧数（票据 05：触地转换起自下一正常帧倒数，含当前帧；归零自然
## 回中立并结束连段。命中当帧按时间层预先换算，滑行中的有效命中整体覆盖）。
var dummy_slide_left := 0
## 弹地首次触地是否已发生（票据 09，B-02：bounce_contact——从该事件起开放统一
## 追击窗口；一次弹地流程至多一次反弹，第二次触地不再反弹）。触地前不可追击。
var dummy_bounce_contacted := false
## 剩余弹地追击窗口帧数（票据 09：bounce_contact 当帧按时间层预先换算，触地当帧
## 不消耗，自下一正常帧倒数；归零自然恢复（空中则空中受身），不转普通倒地）。
var dummy_bounce_left := 0
## 木桩当前防御姿态（票据 03：由逐帧显式请求驱动；被防硬直期间冻结保持）。
var dummy_guard: GuardPosture = GuardPosture.NONE
## 剩余被防硬直帧数（含当前帧；停顿结束后按正常帧倒数，木桩期间不可出招）。
var dummy_blockstun_left := 0

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
## 起手等级（C-01）：首次实际 HIT 锁定首击招式声明的 starter grade；被防、挥空
## 与状态转换不锁定、不提升、不重置；连段结束清除回 UNSET。
var combo_starter_grade: MoveData.StarterGrade = MoveData.StarterGrade.UNSET
## 三层累计修正（C-02）：首击乘 starter 倍率初始化，后续每击乘普通命中倍率；
## 每层独立舍入输出（伤害 0.1、时间整数帧、轨迹 1px/s），互不反推；跨状态保留。
var combo_damage_scale := 1.0
var combo_time_scale := 1.0
var combo_trajectory_scale := 1.0

var _moves: Dictionary = {}
var _current_move: MoveData = null
var _move_frame := 0
var _hit_once_this_move := false
## 多段招式（票据 05）：当前帧所属判定段索引与逐段命中标记（每段对同一目标
## 至多命中一次；单段招式恒为 [x] 一项）。
var _current_segment := 0
var _segment_hit_done: Array[bool] = []
## 本帧待应用命中的判定段索引（与 _pending_hit 配对）。
var _pending_hit_segment := 0
## 本招是否已命中确认（命中确认取消的必要条件；挥空永远为 false）。
var _move_hit_confirmed := false
var _hit_confirm_frame := 0
## 本招是否已发生接触（命中或被防，票据 03）：链式/必杀取消的资格来源；
## 挥空永远为 false，不产生接触年龄。
var _move_contact_confirmed := false
var _contact_frame := 0
## 本次接触是否为被防（区分命中与被防两类接触年龄的开放分支）。
var _move_blocked := false
## 本招是否为连段内的合法接续（决定能否命中仍在受击中的木桩）。
var _move_is_followup := false
var _frame_input := FrameInput.new()
var _pending_hit: MoveData = null
## 本帧刚应用过受击或被防结果：当帧不消耗新硬直/被防硬直（先刷新、后落地/受身）。
var _dummy_fresh_reaction := false

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

# --- 冲刺状态机（issue 18）---
## 剩余冲刺帧数（含当帧，正常帧在运动阶段倒数）：>0 表示 66 前冲 / 44 后撤
## 进行中。触发帧的输入阶段置为 PLAYER_DASH_FRAMES + 1——同帧运动倒数吸收一帧，
## 帧末可观察值从 12 递减到 1，归零后的下一帧起回到地面自由行动（与准备/落地
## 恢复的"运动归零当帧即自由帧"同一口径）。
var player_dash_left := 0
## 冲刺世界方向（触发时面向 × 前(+1)/后(-1)；冲刺期间面向锁定，不受击打断
## 不改写）。
var _dash_direction := 0

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

# --- 普通连接（目押，I-06）---
## 本帧运动阶段自然收招的招式（同帧消费阶段评估普通连接缓存）。
var _finished_move: MoveData = null
## 收招当帧存在可消费的声明普通连接候选：连段不在运动阶段结束，消费阶段
## 按合法接续起手或报告失败原因。
var _pending_link_check := false
## 当前招式是否经普通连接起手（判定窗口结束无接触时报 DISTANCE_INSUFFICIENT）。
var _move_via_link := false
## 当前招式是否经空技延迟普通连接起手（票据 09：落地恢复后首个合法帧消费的
## j6D/j214D 目押——该招命中使用落地普通连接的分层每击倍率，与地面目押分层）。
var _move_via_air_link := false

# --- Rekka 派生（票据 04，I-04/S-07）---
## 首段命中或被防接触后派生窗口打开；窗口只属于当前执行的首段招式——
## 派生起手、首段被打断或自然收招时随招式清除。挥空无接触不开放窗口。
var _rekka_window_open := false
## 打开窗口的接触帧（正常帧时钟：Hitstop 不计龄，与取消窗口同口径）。
var _rekka_contact_frame := 0
## 已锁定的分支键（"" / "B" / "C"）：窗口内第一个 B/C 新按下立即锁定，
## 同帧 B+C 固定 C > B 优先级；锁定后另一键不改写、不升级、不补发普通投。
var _rekka_branch := ""

# --- 特殊进入资格（票据 05，I-05：SPECIAL_D_ENTRY_FROM_236C）---
## 声明了 special_entry_targets 的招式（236C）在实际 HIT 的命中应用阶段授予
## 一次性资格；只在授予招式仍在执行、窗口（special_entry_window_frames，正常帧
## 计龄）内且连段仍活跃时开放取消目标。启动目标招式（普通 5D/5[D]）时消费；
## 资格绑定本次连段与当前目标——被防、挥空、缺失 profile 不授予，连段结束、
## 授予招式结束或窗口关闭即失效，不跨连段/跨目标继承。
var _special_entry_open := false
## 授予帧（正常帧时钟；停顿不计龄——Hitstop 中资格保持不老化）。
var _special_entry_frame := 0
## 授予资格的招式（资格只在授予招式自身的特殊取消窗口内可消费）。
var _special_entry_move: MoveData = null
## 当前招式是否经特殊进入资格起手（来源限定普通连接边的资格来源；D 保持
## 普通招式身份，本标记只用于 5D → 5B 目押边的来源限定）。
var _move_via_special_entry := false
## 收招当帧快照的命中与来源标记（收招后 _move_* 已清零，普通连接消费阶段读取）。
var _finished_move_hit := false
var _finished_move_via_entry := false

# --- 空技落地接缝（票据 08，L-01 / j6D 普通落地连接）---
## 命中落地取消资格：声明 hit_landing_cancel_targets 的空中招式（j2D）在实际
## HIT 的命中应用阶段授予一次；被防、挥空、缺失 profile 不授予。资格绑定本次
## 连段与当前目标——连段结束即清除；落地事件确认后的首个可行动帧消费（例外
## 仅对声明的目标开放，跳过其余空技恢复，不改变落地首帧统一锁）。
var _hit_landing_open := false
## 授予资格的招式（窗口与目标列表的唯一来源）。
var _hit_landing_move: MoveData = null
## 资格开放期间记录的目标输入（专用槽）：-1 = 尚无输入。正常帧时钟计龄，
## Hitstop 不增龄（停顿中按下按恢复首个正常帧起算，与动作缓存同一口径）；
## 最新输入覆盖旧输入。命中前的按下不记录——预存输入不得自动补发。
var _hit_landing_input_at := -1
## 已记录的目标招式 id（消费时按合法接续起手）。
var _hit_landing_input_move_id := ""
## 资格落地确认帧（物理帧号；-1 = 尚未落地）。落地当帧不消费（首帧锁），
## 之后的第一个到达消费阶段的正常帧尝试一次性消费，失败即资格失效。
var _hit_landing_landed_frame := -1
## 空技延迟普通连接挂起：声明了 link_targets 的空招在空中收招或被落地截断时
## 不结束连段，连接评估推迟到攻击者完全落地恢复后的首个合法帧——按缓存消费、
## 目标剩余硬直、姿态与 active 重叠重新判定（与地面普通连接同一口径，不借用
## j2D 例外、不跳过落地首帧锁）。
var _pending_air_link := false

# --- 蓄力、计划位移与换边（票据 06，I-01..I-03 / M-01..M-04）---
## 本招启动时锁定的动作轨迹世界方向（±1；0 = 无进行中招式）。当前招式的
## hitbox、位移与扫掠方向贯穿本招不反向；player_facing 每帧在运动结算后按
## 横向关系另行更新，两者互不重解释。
var _move_direction := 0
## 动作内蓄力：自本招启动起按住动作键的正常帧计数（停顿帧不计；松开的帧
## 不积攒）。提交后冻结，仅供观测。
var _charge_age := 0
## 蓄力分支是否已提交：未提交且仍按住时 active 边界延长 startup，达阈值自动
## 提交蓄力版，松开提交普通版（提交帧钟回卷至提交版的 active_from）。
var _charge_committed := false
## 本招位移的身体穿越许可（M-02）：实际 HIT 授予，仅限本动作的位移段；被防、
## 挥空、缺失资料不授予。招式结束或被打断即清零，不传给下一招。
var _cross_ok := false
## 本招计划位移是否被版边截断（观测标记：墙截断不换边由位置自然表达）。
var _motion_wall_clamped := false
## 本帧计划位移（M-01：输入后、命中判定前生成，命中读取计划姿态；运动阶段
## 提交并清零。冻结帧不生成）。
var _planned_step := Vector2.ZERO
## 计划位移累计锚点（首个位移帧的正式位置）：累计目标按比例自锚点推算，
## 逐帧步长=目标-当前，避免逐帧累加的浮点漂移。
var _motion_anchor_x := 0.0
var _motion_anchor_y := 0.0
## 已提交计划位移的 active 帧数（累计分布分子）。
var _motion_frames_done := 0
## 方向候选参考面向（M-04）：方向历史为空（无进行中候选）时重锁帧首面向；
## 候选进行中保持首次输入时锁定的相对面向，不因换边重解释后续方向段。
var _direction_ref_facing := 1


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
	dummy_knockdown_left = 0
	dummy_slide_left = 0
	dummy_bounce_contacted = false
	dummy_bounce_left = 0
	dummy_guard = GuardPosture.NONE
	dummy_blockstun_left = 0
	combo_hits = 0
	combo_active = false
	combo_total_damage = 0.0
	combo_last_scale = 1.0
	combo_last_damage = 0.0
	combo_starter_grade = MoveData.StarterGrade.UNSET
	combo_damage_scale = 1.0
	combo_time_scale = 1.0
	combo_trajectory_scale = 1.0
	_current_move = null
	_move_frame = 0
	_hit_once_this_move = false
	_current_segment = 0
	_segment_hit_done.clear()
	_pending_hit_segment = 0
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_contact_confirmed = false
	_contact_frame = 0
	_move_blocked = false
	_move_is_followup = false
	_pending_hit = null
	_dummy_fresh_reaction = false
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
	player_dash_left = 0
	_dash_direction = 0
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
	_finished_move = null
	_pending_link_check = false
	_move_via_link = false
	_move_via_air_link = false
	_rekka_window_open = false
	_rekka_contact_frame = 0
	_rekka_branch = ""
	_special_entry_open = false
	_special_entry_frame = 0
	_special_entry_move = null
	_move_via_special_entry = false
	_finished_move_hit = false
	_finished_move_via_entry = false
	_hit_landing_open = false
	_hit_landing_move = null
	_hit_landing_input_at = -1
	_hit_landing_input_move_id = ""
	_hit_landing_landed_frame = -1
	_pending_air_link = false
	_reset_move_tracking()
	_direction_ref_facing = 1


## Capture the complete mutable execution state. MoveData resources are kept in
## the session's immutable move table and are represented by their stable ids.
## The returned dictionary owns all arrays/dictionaries it exposes.
## Completeness contract: every member that can affect a future step() must be
## captured here — tests/test_combat_session_restore.gd enforces this by
## diffing from-scratch runs against restored runs (settlement_state() alone is
## not a sufficient key for that; it omits HP, positions and input history).
func clone_state() -> Dictionary:
	return {
		"format": STATE_FORMAT,
		"config": {
			"direction_retention": _direction_retention,
			"table_has_throw": _table_has_throw,
			"throw_move_id": _move_id(_throw_move),
		},
		"player": {
			"position": player_position,
			"velocity": player_velocity,
			"facing": player_facing,
			"phase": player_phase,
			"on_ground": player_on_ground,
			"move_id": player_move_id,
			"crouching": player_crouching,
			"guard": player_guard,
			"guard_stun_left": player_guard_stun_left,
			"hitstun_left": player_hitstun_left,
			"prejump_left": player_prejump_left,
			"landing_recovery_left": player_landing_recovery_left,
			"air_move_started": _air_move_started,
			"air_extra_recovery": _air_extra_recovery,
			"jump_direction": _jump_direction,
			"dash_left": player_dash_left,
			"dash_direction": _dash_direction,
			"direction_ref_facing": _direction_ref_facing,
			"move_direction": _move_direction,
			"planned_step": _planned_step,
		},
		"dummy": {
			"position": dummy_position,
			"velocity": dummy_velocity,
			"hp": dummy_hp,
			"state": dummy_state,
			"on_ground": dummy_on_ground,
			"hitstun_left": dummy_hitstun_left,
			"knockdown_left": dummy_knockdown_left,
			"slide_left": dummy_slide_left,
			"bounce_contacted": dummy_bounce_contacted,
			"bounce_left": dummy_bounce_left,
			"guard": dummy_guard,
			"blockstun_left": dummy_blockstun_left,
			"move_id": dummy_move_id,
			"phase": dummy_phase,
			"move_frame": _dummy_move_frame,
			"hit_once": _dummy_hit_once,
			"pending_move_id": _move_id(_pending_dummy_hit),
			"fresh_reaction": _dummy_fresh_reaction,
		},
		"combo": {
			"hits": combo_hits,
			"active": combo_active,
			"total_damage": combo_total_damage,
			"last_scale": combo_last_scale,
			"last_damage": combo_last_damage,
			"starter_grade": combo_starter_grade,
			"damage_scale": combo_damage_scale,
			"time_scale": combo_time_scale,
			"trajectory_scale": combo_trajectory_scale,
		},
		"player_move": {
			"move_id": _move_id(_current_move),
			"frame": _move_frame,
			"hit_once": _hit_once_this_move,
			"segment": _current_segment,
			"segment_hit_done": _segment_hit_done.duplicate(),
			"pending_hit_segment": _pending_hit_segment,
			"hit_confirmed": _move_hit_confirmed,
			"hit_confirm_frame": _hit_confirm_frame,
			"contact_confirmed": _move_contact_confirmed,
			"contact_frame": _contact_frame,
			"blocked": _move_blocked,
			"is_followup": _move_is_followup,
			"pending_hit_id": _move_id(_pending_hit),
			"via_link": _move_via_link,
			"via_air_link": _move_via_air_link,
			"finished_move_id": _move_id(_finished_move),
			"pending_link_check": _pending_link_check,
			"finished_move_hit": _finished_move_hit,
			"finished_move_via_entry": _finished_move_via_entry,
			"pending_air_link": _pending_air_link,
			"hit_landing_open": _hit_landing_open,
			"hit_landing_move_id": _move_id(_hit_landing_move),
			"hit_landing_input_at": _hit_landing_input_at,
			"hit_landing_input_move_id": _hit_landing_input_move_id,
			"hit_landing_landed_frame": _hit_landing_landed_frame,
			"via_special_entry": _move_via_special_entry,
			"charge_age": _charge_age,
			"charge_committed": _charge_committed,
			"cross_ok": _cross_ok,
			"motion_wall_clamped": _motion_wall_clamped,
			"motion_frames_done": _motion_frames_done,
			"motion_anchor": Vector2(_motion_anchor_x, _motion_anchor_y),
		},
		"input": _clone_frame_input(_frame_input),
		"keys": {
			"presses": _key_presses.duplicate(true),
			"held": _key_held.duplicate(),
		},
		"action_buffer": {
			"waiting": _buffer_waiting,
			"endpoint": _buffered_endpoint,
			"pending_throw_physics": _pending_throw_physics,
			"throw_result_applied": _throw_result_applied,
			"key": _buffered_key,
			"move_id": _buffered_move_id,
			"at": _buffered_at,
			"physics": _buffered_physics,
			"consumed_move_id": _buffer_consumed_move_id,
			"consumed_frame": _buffer_consumed_frame,
		},
		"jump_slot": {
			"active": _jump_slot_active,
			"at": _jump_slot_at,
			"physics": _jump_slot_physics,
			"axis": _jump_slot_axis,
		},
		"direction": {
			"history": _direction_history.duplicate(),
			"last_digit": _last_direction_digit,
		},
		"cancel": {
			"targets": _cancel_targets.duplicate(),
			"jump_cancel_followups": _jump_cancel_followups.duplicate(),
			"just_landed": _player_just_landed,
		},
		"rekka": {
			"window_open": _rekka_window_open,
			"contact_frame": _rekka_contact_frame,
			"branch": _rekka_branch,
		},
		"special_entry": {
			"open": _special_entry_open,
			"frame": _special_entry_frame,
			"move_id": _move_id(_special_entry_move),
		},
		"clock": {
			"frame": _frame_index,
			"normal_frame": _normal_frame_index,
			"hitstop_left": _hitstop_left,
			"hitstop_resume_pending": _hitstop_resume_pending,
		},
		"flags": {
			"player_fresh_stun": _player_fresh_stun,
		},
	}


## Restore a state produced by clone_state(). The move table is immutable for a
## session, so move references are resolved by id. Returning false keeps a bad
## state from partially mutating the session.
func restore_state(state: Dictionary) -> bool:
	if state.get("format", "") != STATE_FORMAT:
		return false
	var player: Dictionary = state.get("player", {})
	var config: Dictionary = state.get("config", {})
	var dummy: Dictionary = state.get("dummy", {})
	var combo: Dictionary = state.get("combo", {})
	var move_state: Dictionary = state.get("player_move", {})
	var input_state: Dictionary = state.get("input", {})
	var keys: Dictionary = state.get("keys", {})
	var buffer: Dictionary = state.get("action_buffer", {})
	var jump_slot: Dictionary = state.get("jump_slot", {})
	var direction: Dictionary = state.get("direction", {})
	var cancel: Dictionary = state.get("cancel", {})
	var rekka: Dictionary = state.get("rekka", {})
	var special: Dictionary = state.get("special_entry", {})
	var clock: Dictionary = state.get("clock", {})
	var flags: Dictionary = state.get("flags", {})
	if int(config.get("direction_retention", _direction_retention)) != _direction_retention:
		return false
	if bool(config.get("table_has_throw", _table_has_throw)) != _table_has_throw:
		return false
	var state_throw_id := String(config.get("throw_move_id", _move_id(_throw_move)))
	if state_throw_id != _move_id(_throw_move):
		return false
	var ids := [
		String(player.get("move_id", "")), String(dummy.get("move_id", "")),
		String(dummy.get("pending_move_id", "")), String(move_state.get("move_id", "")),
		String(move_state.get("pending_hit_id", "")), String(move_state.get("finished_move_id", "")),
		String(special.get("move_id", "")), String(buffer.get("move_id", "")),
		String(move_state.get("hit_landing_move_id", "")),
		String(move_state.get("hit_landing_input_move_id", "")),
		state_throw_id,
	]
	for id in ids:
		if id != "" and not _moves.has(id):
			return false

	player_position = player.get("position", Vector2.ZERO)
	player_velocity = player.get("velocity", Vector2.ZERO)
	player_facing = int(player.get("facing", 1))
	player_phase = int(player.get("phase", PlayerPhase.NEUTRAL))
	player_on_ground = bool(player.get("on_ground", true))
	player_move_id = String(player.get("move_id", ""))
	player_crouching = bool(player.get("crouching", false))
	player_guard = int(player.get("guard", GuardPosture.NONE))
	player_guard_stun_left = int(player.get("guard_stun_left", 0))
	player_hitstun_left = int(player.get("hitstun_left", 0))
	player_prejump_left = int(player.get("prejump_left", 0))
	player_landing_recovery_left = int(player.get("landing_recovery_left", 0))
	_air_move_started = bool(player.get("air_move_started", false))
	_air_extra_recovery = int(player.get("air_extra_recovery", 0))
	_jump_direction = int(player.get("jump_direction", 0))
	player_dash_left = int(player.get("dash_left", 0))
	_dash_direction = int(player.get("dash_direction", 0))
	_direction_ref_facing = int(player.get("direction_ref_facing", 1))
	_move_direction = int(player.get("move_direction", 0))
	_planned_step = player.get("planned_step", Vector2.ZERO)

	dummy_position = dummy.get("position", Vector2.ZERO)
	dummy_velocity = dummy.get("velocity", Vector2.ZERO)
	dummy_hp = float(dummy.get("hp", 0.0))
	dummy_state = int(dummy.get("state", DummyState.NEUTRAL))
	dummy_on_ground = bool(dummy.get("on_ground", true))
	dummy_hitstun_left = int(dummy.get("hitstun_left", 0))
	dummy_knockdown_left = int(dummy.get("knockdown_left", 0))
	dummy_slide_left = int(dummy.get("slide_left", 0))
	dummy_bounce_contacted = bool(dummy.get("bounce_contacted", false))
	dummy_bounce_left = int(dummy.get("bounce_left", 0))
	dummy_guard = int(dummy.get("guard", GuardPosture.NONE))
	dummy_blockstun_left = int(dummy.get("blockstun_left", 0))
	dummy_move_id = String(dummy.get("move_id", ""))
	dummy_phase = int(dummy.get("phase", PlayerPhase.NEUTRAL))
	_dummy_move = _move_from_id(dummy_move_id)
	_dummy_move_frame = int(dummy.get("move_frame", 0))
	_dummy_hit_once = bool(dummy.get("hit_once", false))
	_pending_dummy_hit = _move_from_id(String(dummy.get("pending_move_id", "")))
	_dummy_fresh_reaction = bool(dummy.get("fresh_reaction", false))

	combo_hits = int(combo.get("hits", 0))
	combo_active = bool(combo.get("active", false))
	combo_total_damage = float(combo.get("total_damage", 0.0))
	combo_last_scale = float(combo.get("last_scale", 1.0))
	combo_last_damage = float(combo.get("last_damage", 0.0))
	combo_starter_grade = int(combo.get("starter_grade", MoveData.StarterGrade.UNSET))
	combo_damage_scale = float(combo.get("damage_scale", 1.0))
	combo_time_scale = float(combo.get("time_scale", 1.0))
	combo_trajectory_scale = float(combo.get("trajectory_scale", 1.0))

	_current_move = _move_from_id(String(move_state.get("move_id", "")))
	_move_frame = int(move_state.get("frame", 0))
	_hit_once_this_move = bool(move_state.get("hit_once", false))
	_current_segment = int(move_state.get("segment", 0))
	_segment_hit_done = []
	for value in move_state.get("segment_hit_done", []):
		_segment_hit_done.append(bool(value))
	_pending_hit_segment = int(move_state.get("pending_hit_segment", 0))
	_move_hit_confirmed = bool(move_state.get("hit_confirmed", false))
	_hit_confirm_frame = int(move_state.get("hit_confirm_frame", 0))
	_move_contact_confirmed = bool(move_state.get("contact_confirmed", false))
	_contact_frame = int(move_state.get("contact_frame", 0))
	_move_blocked = bool(move_state.get("blocked", false))
	_move_is_followup = bool(move_state.get("is_followup", false))
	_pending_hit = _move_from_id(String(move_state.get("pending_hit_id", "")))
	_move_via_link = bool(move_state.get("via_link", false))
	_move_via_air_link = bool(move_state.get("via_air_link", false))
	_finished_move = _move_from_id(String(move_state.get("finished_move_id", "")))
	_pending_link_check = bool(move_state.get("pending_link_check", false))
	_finished_move_hit = bool(move_state.get("finished_move_hit", false))
	_finished_move_via_entry = bool(move_state.get("finished_move_via_entry", false))
	_pending_air_link = bool(move_state.get("pending_air_link", false))
	_hit_landing_open = bool(move_state.get("hit_landing_open", false))
	_hit_landing_move = _move_from_id(String(move_state.get("hit_landing_move_id", "")))
	_hit_landing_input_at = int(move_state.get("hit_landing_input_at", -1))
	_hit_landing_input_move_id = String(move_state.get("hit_landing_input_move_id", ""))
	_hit_landing_landed_frame = int(move_state.get("hit_landing_landed_frame", -1))
	_move_via_special_entry = bool(move_state.get("via_special_entry", false))
	_charge_age = int(move_state.get("charge_age", 0))
	_charge_committed = bool(move_state.get("charge_committed", false))
	_cross_ok = bool(move_state.get("cross_ok", false))
	_motion_wall_clamped = bool(move_state.get("motion_wall_clamped", false))
	_motion_frames_done = int(move_state.get("motion_frames_done", 0))
	var motion_anchor: Vector2 = move_state.get("motion_anchor", Vector2.ZERO)
	_motion_anchor_x = motion_anchor.x
	_motion_anchor_y = motion_anchor.y
	_frame_input = _restore_frame_input(input_state)
	_key_presses = keys.get("presses", {}).duplicate(true)
	_key_held = (keys.get("held", []) as Array).duplicate()
	_buffer_waiting = bool(buffer.get("waiting", false))
	_buffered_endpoint = int(buffer.get("endpoint", -1))
	_pending_throw_physics = int(buffer.get("pending_throw_physics", 0))
	_throw_result_applied = bool(buffer.get("throw_result_applied", false))
	_buffered_key = String(buffer.get("key", ""))
	_buffered_move_id = String(buffer.get("move_id", ""))
	_buffered_at = int(buffer.get("at", 0))
	_buffered_physics = int(buffer.get("physics", 0))
	_buffer_consumed_move_id = String(buffer.get("consumed_move_id", ""))
	_buffer_consumed_frame = int(buffer.get("consumed_frame", 0))
	_jump_slot_active = bool(jump_slot.get("active", false))
	_jump_slot_at = int(jump_slot.get("at", 0))
	_jump_slot_physics = int(jump_slot.get("physics", 0))
	_jump_slot_axis = int(jump_slot.get("axis", 0))
	_direction_history = []
	for entry in direction.get("history", []):
		_direction_history.append(Vector2i(entry.x, entry.y) if entry is Vector2i else Vector2i(int(entry[0]), int(entry[1])))
	_last_direction_digit = int(direction.get("last_digit", 5))
	_cancel_targets = (cancel.get("targets", []) as Array).duplicate()
	_jump_cancel_followups = (cancel.get("jump_cancel_followups", []) as Array).duplicate()
	_player_just_landed = bool(cancel.get("just_landed", false))
	_rekka_window_open = bool(rekka.get("window_open", false))
	_rekka_contact_frame = int(rekka.get("contact_frame", 0))
	_rekka_branch = String(rekka.get("branch", ""))
	_special_entry_open = bool(special.get("open", false))
	_special_entry_frame = int(special.get("frame", 0))
	_special_entry_move = _move_from_id(String(special.get("move_id", "")))
	_frame_index = int(clock.get("frame", 0))
	_normal_frame_index = int(clock.get("normal_frame", 0))
	_hitstop_left = int(clock.get("hitstop_left", 0))
	_hitstop_resume_pending = bool(clock.get("hitstop_resume_pending", false))
	_player_fresh_stun = bool(flags.get("player_fresh_stun", false))
	return true


func _move_id(move: MoveData) -> String:
	return move.move_id if move != null else ""


func _move_from_id(move_id: String) -> MoveData:
	return _moves.get(move_id) as MoveData if move_id != "" else null


func _clone_frame_input(input: FrameInput) -> Dictionary:
	return {
		"move_axis": input.move_axis,
		"down_held": input.down_held,
		"up_held": input.up_held,
		"jump_pressed": input.jump_pressed,
		"pressed_action_keys": input.pressed_action_keys.duplicate(),
		"held_action_keys": input.held_action_keys.duplicate(),
		"dummy_tech_request": input.dummy_tech_request,
		"dummy_move_request": input.dummy_move_request,
		"dummy_guard_request": input.dummy_guard_request,
	}


func _restore_frame_input(state: Dictionary) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = int(state.get("move_axis", 0))
	input.down_held = bool(state.get("down_held", false))
	input.up_held = bool(state.get("up_held", false))
	input.jump_pressed = bool(state.get("jump_pressed", false))
	input.pressed_action_keys = (state.get("pressed_action_keys", []) as Array).duplicate()
	input.held_action_keys = (state.get("held_action_keys", []) as Array).duplicate()
	input.dummy_tech_request = bool(state.get("dummy_tech_request", false))
	input.dummy_move_request = String(state.get("dummy_move_request", ""))
	input.dummy_guard_request = int(state.get("dummy_guard_request", 0))
	return input


## 结算一个物理帧，返回该帧产生的战斗事件（按结算发生顺序排列）。
func step(input: FrameInput) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	_frame_index += 1
	_frame_input = input
	if _hitstop_left > 0:
		## 冻结帧：只采样记录输入，不推进动作、位置、速度、受击、落地与受身计时。
		_phase_input(events)
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
	_phase_input(events)
	_phase_plan_motion()
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


## 空输入步进是否仍可能自主产生事件：进行中招式（命中/收招/取消窗关闭）、
## 待决命中（多段/延迟落地连接）、缓存等待消费、投技待结算、特殊进入窗口、
## 木桩待决攻击与 Hitstop 冻结都是无输入事件源。Solver checkpoint 前缀转移的
## 「可证明无事件区间」批量推进用它做保守判定（P3）；连段活跃期间另有取消/
## 恢复窗口到期的 COMBO_ENDED 源不在此列——调用方须自行把 combo_active 区间
## 排除在批量推进之外。取消窗口是只读判定面：与 clone_state 的完整性契约
## 同步维护（新事件源字段加入时两处都要带上）。
func has_deferred_event_sources() -> bool:
	return _current_move != null \
			or _pending_hit != null \
			or _pending_link_check \
			or _pending_air_link \
			or _hit_landing_open \
			or _buffer_waiting \
			or _pending_throw_physics > 0 \
			or _special_entry_open \
			or _dummy_move != null \
			or _pending_dummy_hit != null \
			or _hitstop_left > 0 \
			or _hitstop_resume_pending


## 当前招式当前判定段的命中框（世界坐标）；没有进行中的打击招式时返回空矩形
## （投技无命中框）。判定阶段与非判定阶段共用同一几何，是否生效由 player_phase
## 决定；多段招式按当前段声明取段命中框（票据 05）。方向取本招启动时锁定的
## 动作方向（M-04：跨身当帧面向更新不影响本招 hitbox）。声明计划位移的招式
## 在 active 帧返回当前姿态到本帧计划姿态的扫掠覆盖（M-03：轴对齐平移的扫掠
## 区域恰为两姿态矩形的包络，无细分采样误差；startup/recovery 步长为零不扫掠）。
func player_attack_rect() -> Rect2:
	if _current_move == null or not _current_move.is_strike():
		return Rect2()
	var size := _current_move.segment_hitbox_size(_current_segment)
	var center := player_position + Vector2(
		_attack_direction() * _current_move.segment_hitbox_offset(_current_segment),
		_current_move.hitbox_y_offset_px)
	var rect := Rect2(center - size * 0.5, size)
	if _planned_step == Vector2.ZERO:
		return rect
	var near := rect.position
	var far := rect.position + rect.size
	var moved_near := near + _planned_step
	var moved_far := far + _planned_step
	return Rect2(Vector2(minf(near.x, moved_near.x), minf(near.y, moved_near.y)),
		Vector2(maxf(far.x, moved_far.x), maxf(far.y, moved_far.y)) - Vector2(minf(near.x, moved_near.x), minf(near.y, moved_near.y)))


## 攻击方向：进行中招式用启动时锁定的动作轨迹方向，否则用当前面向
## （命中应用、击退与事件方向共用同一口径）。
func _attack_direction() -> int:
	return _move_direction if _current_move != null and _move_direction != 0 else player_facing


## 木桩当前招式的命中框（世界坐标，朝玩家一侧）；没有进行中的招式时返回空矩形。
func dummy_attack_rect() -> Rect2:
	if _dummy_move == null:
		return Rect2()
	var facing := _dummy_attack_direction()
	var center := dummy_position + Vector2(facing * _dummy_move.hitbox_offset(), _dummy_move.hitbox_y_offset_px)
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
		"dummy_guard": dummy_guard,
		"dummy_blockstun_left": dummy_blockstun_left,
		"blocked_contact": _move_contact_confirmed and _move_blocked,
		"blocked_age": (maxi(0, _normal_frame_index - _contact_frame)
			if _move_contact_confirmed and _move_blocked else -1),
		"hitstop_left": _hitstop_left,
		"prejump_left": player_prejump_left,
		"landing_recovery_left": player_landing_recovery_left,
		"dash_left": player_dash_left,
		"dash_direction": (_dash_direction if player_dash_left > 0 else null),
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
		"starter_grade": combo_starter_grade,
		"damage_scale": combo_damage_scale,
		"time_scale": combo_time_scale,
		"trajectory_scale": combo_trajectory_scale,
		"dummy_bounce_left": dummy_bounce_left,
		"dummy_bounce_contacted": dummy_bounce_contacted,
		"rekka_branch": _rekka_branch,
		"special_entry_open": _special_entry_open,
		"special_entry_age": (maxi(0, _normal_frame_index - _special_entry_frame) if _special_entry_open else -1),
		"move_via_special_entry": _move_via_special_entry,
		"dummy_slide_left": dummy_slide_left,
		"rekka_window_left": (maxi(0, _current_move.rekka_window_frames - (_normal_frame_index - _rekka_contact_frame))
			if _rekka_window_active() else -1),
		"velocity": player_velocity,
		"charge_age": (_charge_age if _current_move != null and _current_move.is_chargeable() and not _charge_committed else -1),
		"charged_active": (_current_move != null and _current_move.charge_only),
		"move_direction": _move_direction,
		"direction_ref_facing": _direction_ref_facing,
		"cross_ok": _cross_ok,
		"motion_wall_clamped": _motion_wall_clamped,
		"planned_step": _planned_step,
		"air_exit_open": (_current_move != null and not _current_move.air_exit_targets.is_empty()
			and not player_on_ground and _cancel_window_open()),
		"hitbox_y_offset": (_current_move.hitbox_y_offset_px if _current_move != null else 0.0),
		"dummy_air_height_px": maxf(0.0, GameParams.ground_stand_y() - dummy_position.y),
		"hit_landing_cancel_open": _hit_landing_open,
		"hit_landing_input_age": (maxi(0, _normal_frame_index - _hit_landing_input_at) if _hit_landing_input_at >= 0 else -1),
		"hit_landing_input_move_id": _hit_landing_input_move_id,
		"hit_landing_landed": _hit_landing_landed_frame >= 0,
		"air_link_pending": _pending_air_link,
	}


## 影响未来结算的会话状态快照（只读，issue 21）。Combo Solver 用它做循环的逐圈
## 状态去重与重现证明：两次快照相等 ⇔ 从该时刻起喂入相同输入必然产生完全相同
## 的未来结算。口径：
## - 绝对帧号（物理帧、正常帧、各记录时间戳）一律换算为相对年龄，纯调试帧号
##   不入快照——否则逐圈快照因帧号递增永不相等；年龄本身参与结算（缓存/窗口/
##   历史的过期），故以年龄形式入快照。
## - 纯报告量（连段命中数、累计伤害、HP、最近伤害倍率）不影响任何结算分支，
##   不入快照；连段存续标记 combo_active 是取消与命中的资格门，入快照。
## - 动作键原始按下记录只在与新按下配对（≤3 物理帧）时影响结算，等待中的候选
##   与投意图经缓存/投字段入快照；按住集合是输入历史的确定函数，入快照。
## - 方向候选（指令锁定）由方向历史 + 姿态 + 招式表在识别时确定派生，历史
##   （年龄化）与姿态入快照即覆盖，不重复入快照。参考面向（候选锁定的相对
##   面向，票据 06 M-04）影响后续段的折算，入快照。
## - 横向位置（票据 06 起）入快照：D 系计划位移使双方横向几何成为真实结算量
##   （后续命中框接触与版边截断都依赖它）；Solver 探针的钉位是几何接触假设，
##   位置仍在每帧结算后如实入键。
func settlement_state() -> Dictionary:
	var buffer_age := -1
	if _buffered_key != "":
		buffer_age = _normal_frame_index - _buffered_at
	var buffer_physics_age := -1
	if _buffered_key != "":
		buffer_physics_age = _frame_index - _buffered_physics
	var buffered_endpoint_age := -1
	if _buffered_endpoint >= 0:
		buffered_endpoint_age = _normal_frame_index - _buffered_endpoint
	var cancel_age := -1
	if _current_move != null and _move_hit_confirmed:
		cancel_age = _normal_frame_index - _hit_confirm_frame
	var jump_slot := {"active": false, "age": -1, "axis": 0, "physics_age": -1}
	if _jump_slot_active:
		jump_slot = {
			"active": true,
			"age": _normal_frame_index - _jump_slot_at,
			"axis": _jump_slot_axis,
			"physics_age": _frame_index - _jump_slot_physics,
		}
	var pending_throw_age := -1
	if _pending_throw_physics > 0:
		pending_throw_age = _frame_index - _pending_throw_physics
	var direction_history: Array = []
	for entry in _direction_history:
		direction_history.append(Vector2i(entry.x, _normal_frame_index - entry.y))
	return {
		# 玩家姿态/阶段
		"phase": player_phase,
		"on_ground": player_on_ground,
		"crouching": player_crouching,
		"guard": player_guard,
		"hitstun_left": player_hitstun_left,
		"guard_stun_left": player_guard_stun_left,
		"dash_left": player_dash_left,
		"dash_direction": _dash_direction,
		# 当前招式及招式帧（多段：段索引与逐段命中标记影响后续命中资格）
		"move_id": player_move_id,
		"move_frame": _move_frame,
		"hit_once": _hit_once_this_move,
		"current_segment": _current_segment,
		"segment_hit_done": _segment_hit_done.duplicate(),
		"hit_confirmed": _move_hit_confirmed,
		"cancel_age": cancel_age,
		"move_is_followup": _move_is_followup,
		"move_via_link": _move_via_link,
		"move_via_air_link": _move_via_air_link,
		"move_via_special_entry": _move_via_special_entry,
		"finished_move_hit": _finished_move_hit,
		"finished_move_via_entry": _finished_move_via_entry,
		# 面向与速度
		"facing": player_facing,
		"velocity": player_velocity,
		"position_y": player_position.y,
		"position_x": player_position.x,
		"dummy_position_x": dummy_position.x,
		"direction_ref_facing": _direction_ref_facing,
		# 蓄力、计划位移与换边（票据 06）：动作方向、蓄力年龄/开闭、穿越许可与
		# 横向位置影响未来结算（命中几何、身体约束、版边截断、面向更新）。
		"move_direction": _move_direction,
		"charge_age": _charge_age,
		"charge_open": (_current_move != null and _current_move.is_chargeable() and not _charge_committed),
		"cross_ok": _cross_ok,
		# 落地和 jump 标记
		"prejump_left": player_prejump_left,
		"landing_recovery_left": player_landing_recovery_left,
		"just_landed": _player_just_landed,
		"air_move_started": _air_move_started,
		"air_extra_recovery": _air_extra_recovery,
		"jump_direction": _jump_direction,
		"jump_slot": jump_slot,
		"jump_cancel_followups": _jump_cancel_followups.duplicate(),
		# 动作缓存与投意图
		"buffered_key": _buffered_key,
		"buffered_move_id": _buffered_move_id,
		"buffer_age": buffer_age,
		"buffer_physics_age": buffer_physics_age,
		"buffer_waiting": _buffer_waiting,
		"buffered_endpoint_age": buffered_endpoint_age,
		"pending_throw_age": pending_throw_age,
		"held_action_keys": _key_held.duplicate(),
		# 方向候选与历史（年龄化条目）
		"direction_history": direction_history,
		"last_direction_digit": _last_direction_digit,
		# 连段资源（结算资格门；伤害等纯报告量见上文口径）。起手等级与三层累计
		# 修正影响后续命中的伤害/计时/轨迹，是真实结算量，入快照。
		"combo_active": combo_active,
		"starter_grade": combo_starter_grade,
		"damage_scale": combo_damage_scale,
		"time_scale": combo_time_scale,
		"trajectory_scale": combo_trajectory_scale,
		# Rekka 派生（票据 04）：分支锁定与窗口开闭影响后续起手资格，是真实结算量。
		"rekka_branch": _rekka_branch,
		"rekka_window_open": _rekka_window_open,
		"rekka_contact_age": (_normal_frame_index - _rekka_contact_frame if _rekka_window_open else -1),
		# 特殊进入资格（票据 05）：授予开闭与年龄影响 D 取消起手资格与来源限定
		# 普通连接边，是真实结算量（授予招式由 move_id 表达）。
		"special_entry_open": _special_entry_open,
		"special_entry_age": (_normal_frame_index - _special_entry_frame if _special_entry_open else -1),
		# 空技落地接缝（票据 08）：j2D 命中落地取消资格（授予招式、专用输入年龄、
		# 落地确认）与 j6D 延迟普通连接挂起（含收招快照标记）影响后续起手资格，
		# 是真实结算量——帧号换算为年龄/布尔，纯调试帧号不入键。
		"hit_landing_open": _hit_landing_open,
		"hit_landing_move_id": _move_id(_hit_landing_move),
		"hit_landing_input_age": (_normal_frame_index - _hit_landing_input_at if _hit_landing_input_at >= 0 else -1),
		"hit_landing_input_move_id": _hit_landing_input_move_id,
		"hit_landing_landed": _hit_landing_landed_frame >= 0,
		"pending_air_link": _pending_air_link,
		"air_link_move_id": (_move_id(_finished_move) if _pending_air_link else ""),
		# 木桩姿态/阶段、受击计时与速度（滑行计时影响追击窗口与自然恢复时点；
		# 弹地触地标记与追击窗口计时影响可追击域与弹地分支——票据 09）
		"dummy_state": dummy_state,
		"dummy_on_ground": dummy_on_ground,
		"dummy_hitstun_left": dummy_hitstun_left,
		"dummy_knockdown_left": dummy_knockdown_left,
		"dummy_slide_left": dummy_slide_left,
		"dummy_bounce_contacted": dummy_bounce_contacted,
		"dummy_bounce_left": dummy_bounce_left,
		"dummy_velocity": dummy_velocity,
		"dummy_position_y": dummy_position.y,
		"dummy_move_id": dummy_move_id,
		"dummy_phase": dummy_phase,
		"dummy_move_frame": _dummy_move_frame,
		"dummy_hit_once": _dummy_hit_once,
		# 木桩防御与被防接触（影响未来结算：姿态挡住后续攻击、被防硬直锁出招、
		# 被防接触开放链式/必杀取消窗口）。
		"dummy_guard": dummy_guard,
		"dummy_blockstun_left": dummy_blockstun_left,
		"move_contact": _move_contact_confirmed,
		"move_blocked": _move_blocked,
		"contact_age": (_normal_frame_index - _contact_frame if _move_contact_confirmed else -1),
		# Hitstop 冻结
		"hitstop_left": _hitstop_left,
		"hitstop_resume_pending": _hitstop_resume_pending,
	}


# --- 结算管线（顺序不可调换）---

func _phase_input(events: Array[CombatEvent]) -> void:
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
	## 方向候选参考面向（票据 06，M-04）：默认每帧重锁帧首面向；存在已开始、
	## 未完成的 214/236 指令候选时保持首次输入时锁定的相对面向，换边不重解释
	## 候选的后续方向段。
	if not _command_candidate_active():
		_direction_ref_facing = player_facing
	_record_direction()
	_record_action_key_events()
	## Rekka 派生仲裁（I-04）先于普通投组合：派生窗口内的 B/C 新按下立即锁分支
	## 并消费按键——不进入 B+C 组合等待、不写单键缓存；同帧 B+C 固定 ~C 优先。
	## 冻结帧也采样：停顿中按下同样锁分支，恢复首个正常帧起手派生。
	var rekka_consumed := _check_rekka_derivation(events)
	var combination_completed := false
	if not rekka_consumed and _table_has_throw:
		combination_completed = _check_throw_combination()
	## 更新的动作输入覆盖停顿中记录的投组合意图（同帧配齐的按键不视为“更新”）。
	if not rekka_consumed and not combination_completed and not _frame_input.pressed_action_keys.is_empty() \
			and _pending_throw_physics > 0 and _frame_index > _pending_throw_physics:
		_pending_throw_physics = 0
	if not rekka_consumed and not combination_completed and _frame_input.action_key != "":
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
	## 命中落地取消的专用输入记录（票据 08，L-01）：资格开放期间的按下额外按
	## 地面姿态解析——空中按 C 的常规选招只会命中空技，承载不了 214 这类地面
	## 指令。仲裁先于 B+C 组合等待（与 Rekka 派生同口径）；只有解析结果落在
	## 授予招式声明的目标内才记录，命中前（资格未开）的按下不记录，预存输入
	## 不得自动补发。方向历史按识别终点消费（与常规选招同一规则）。
	if _hit_landing_open and _hit_landing_move != null and not rekka_consumed \
			and _frame_input.action_key != "":
		var landing_selected := _select_move_for_key(_frame_input.action_key, MoveData.Stance.GROUND, input_stamp)
		var landing_selected_id := String(landing_selected["move_id"])
		if _hit_landing_move.hit_landing_cancel_targets.has(landing_selected_id):
			_hit_landing_input_move_id = landing_selected_id
			_hit_landing_input_at = input_stamp
			if int(landing_selected["endpoint"]) >= 0:
				_consume_direction_history_through(int(landing_selected["endpoint"]))
	## 跳跃输入槽独立记录：Space+下中和，不触发跳跃；按下即冻结
	## 当帧世界水平跳向；最新按下覆盖旧请求，按住不重复。
	if _frame_input.jump_pressed and not _frame_input.down_held:
		_jump_slot_active = true
		_jump_slot_at = input_stamp
		_jump_slot_physics = _frame_index
		_jump_slot_axis = _frame_input.move_axis
	if _hitstop_left > 0:
		## 冻结帧到此为止：姿态、冲刺触发与木桩请求属于结算，停顿中不推进。
		return
	_check_dash_start(events)
	_update_posture()
	_update_dummy_guard(events)
	_process_dummy_request()


## 木桩防御姿态解析（票据 03，D-01）：逐帧由显式请求驱动，先于命中判定使当帧
## 进入的防御参与同帧的攻击结算。被防硬直期间姿态冻结（连防，与玩家防御硬直
## 同口径）；NONE 不防御。请求不成立时不静默回退为其他防御，按原因可观察拒绝：
## 姿态与地面/空中状态不符为 STATE；木桩处于受击/倒地/自身招式中为 BUSY。
func _update_dummy_guard(events: Array[CombatEvent]) -> void:
	if dummy_blockstun_left > 0:
		return
	var request := _frame_input.dummy_guard_request
	if request == GuardPosture.NONE:
		dummy_guard = GuardPosture.NONE
		return
	var state_ok := false
	match request:
		GuardPosture.STANDING, GuardPosture.CROUCH:
			state_ok = dummy_on_ground
		GuardPosture.AIR:
			state_ok = not dummy_on_ground
	if not state_ok:
		dummy_guard = GuardPosture.NONE
		events.append(CombatEvent.dummy_guard_rejected(CombatEvent.DummyGuardRejectReason.STATE))
		return
	if dummy_state != DummyState.NEUTRAL or _dummy_move != null:
		dummy_guard = GuardPosture.NONE
		events.append(CombatEvent.dummy_guard_rejected(CombatEvent.DummyGuardRejectReason.BUSY))
		return
	dummy_guard = request


## 66 前冲 / 44 后撤触发（issue 18）：方向历史只在变化时记录条目，因此"两个独立
## 同向方向段 + 中间至少一个逻辑中立帧"恰是紧邻的 [同向段, 中立, 新同向段] 三条
## 历史——新段的上一条是中立、再上一条与它同数字。第二段到来当帧触发；冻结帧
## 只记录不触发（停顿中的段与恢复首帧同时间戳，同一配对口径）。旧段仍受方向
## 历史保留窗口约束；冲刺不消费方向历史（与指令识别的独立规则，236C/214D 等
## 指令不受冲刺影响）。
func _check_dash_start(events: Array[CombatEvent]) -> void:
	if _direction_history.size() < 3:
		return
	var last: Vector2i = _direction_history[_direction_history.size() - 1]
	if (last.x != 6 and last.x != 4) or last.y != _input_stamp():
		return
	if _direction_history[_direction_history.size() - 2].x != 5:
		return
	if _direction_history[_direction_history.size() - 3].x != last.x:
		return
	if not _dash_start_allowed():
		return
	player_dash_left = GameParams.PLAYER_DASH_FRAMES + 1
	_dash_direction = player_facing if last.x == 6 else -player_facing
	## 冲刺是承诺性的地面位移状态：进入时清姿态，期间不蹲不防。
	_clear_posture()
	events.append(CombatEvent.dash_started(_dash_direction))


## 冲刺识别门：仅地面自由行动（中立/移动/蹲下）——出招、受击/防御硬直、
## pre-jump、空中、任意落地恢复与冲刺进行中都不识别。落地恢复按输入阶段口径
## 以 >1 判受限（本帧运动归零 = 首个自由帧，与姿态重解析门同一时序）。
func _dash_start_allowed() -> bool:
	if player_dash_left > 0 or _current_move != null or _player_stunned():
		return false
	if not player_on_ground:
		return false
	if player_prejump_left > 0 or player_landing_recovery_left > 1:
		return false
	return true


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


## Rekka 派生仲裁（票据 04，I-04）：派生窗口活跃时拦截本帧的 B/C 新按下——
## 第一个有效新按下立即锁定分支（同帧两键同按固定 C > B），并把参与的按键标记
## 为已消费（不再进入普通投配对、不写单键缓存）。窗口内后续 B/C 新按下同样被
## 消费但不改写分支。返回 true 表示本帧新按下全部属于 B/C 且已被消费（调用方
## 据此跳过投配对与单键缓存写入）；同帧夹带的其他按键（如 D）照常走既有规则。
func _check_rekka_derivation(events: Array[CombatEvent]) -> bool:
	if not _rekka_window_active():
		return false
	var pressed := _frame_input.pressed_action_keys
	var pressed_any := false
	var branch := ""
	for key in ["C", "B"]:
		if not pressed.has(key):
			continue
		pressed_any = true
		if branch == "":
			branch = key
		if _key_presses.has(key):
			(_key_presses[key] as Array)[1] = true
	if not pressed_any:
		return false
	if branch != "" and _rekka_branch == "":
		_rekka_branch = branch
		var target := _rekka_target_for(branch)
		if target != "":
			events.append(CombatEvent.rekka_branch_locked(branch, target))
	for key in pressed:
		if key != "B" and key != "C":
			return false
	return true


## 派生窗口当前是否活跃：已打开、首段仍在执行、接触年龄仍在窗口内
## （正常帧计龄，停顿不计——与链式/必杀取消窗口同口径；过期即关闭，不再拦截）。
func _rekka_window_active() -> bool:
	if not _rekka_window_open or _current_move == null:
		return false
	return _normal_frame_index - _rekka_contact_frame <= _current_move.rekka_window_frames


func _rekka_target_for(branch: String) -> String:
	if _current_move == null:
		return ""
	if branch == "B":
		return _current_move.rekka_b_target
	if branch == "C":
		return _current_move.rekka_c_target
	return ""


## 已锁分支的派生起手：窗口仍开、首段仍在执行时按合法接续起手派生招式并
## 关闭窗口（停顿中锁定的分支在恢复首个正常帧起手——消费阶段只在正常帧运行）。
func _start_locked_rekka() -> bool:
	if _rekka_branch == "" or not _rekka_window_active():
		return false
	var target_id := _rekka_target_for(_rekka_branch)
	var target := _moves.get(target_id) as MoveData
	if target == null:
		return false
	_start_move(target_id, target, true)
	_note_buffer_consumed(target_id)
	_clear_rekka_window()
	return true


func _clear_rekka_window() -> void:
	_rekka_window_open = false
	_rekka_contact_frame = 0
	_rekka_branch = ""


## 首段接触（命中或被防）打开派生窗口；接触前已有的锁定/窗口状态随前招清除。
func _open_rekka_window(move: MoveData) -> void:
	_clear_rekka_window()
	if move.rekka_window_frames < 0:
		return
	_rekka_window_open = true
	_rekka_contact_frame = _normal_frame_index


## 木桩确定性攻击请求：仅在木桩空闲（中立、落地、无进行中招式、不在被防硬直）
## 时按请求起手，请求帧为该招式第 1 帧；其余状态静默忽略（木桩无自主决策，
## 不排队、不补发）。被防硬直结束后的首个输入帧即合法反击时点（R-02 观察口）。
func _process_dummy_request() -> void:
	if _frame_input.dummy_move_request == "" or _dummy_move != null:
		return
	if dummy_state != DummyState.NEUTRAL or not dummy_on_ground:
		return
	if dummy_blockstun_left > 0:
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
	## 出招替换姿态（与玩家 _start_move 同口径）：木桩攻击期间不保持防御。
	dummy_guard = GuardPosture.NONE


## 姿态解析（蹲下与防御，issue 16）：先于命中判定，使当帧进入的蹲下/防御
## 参与同帧的防御判定。地面自由行动时 1/2/3 当帧蹲下并停止主动移动、
## 4 站防、1 蹲防；真正离地后 4/1 均为空防，下方向不形成蹲姿。
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
	player_crouching = _down_held()
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


## 姿态重解析门：出招、受击/防御硬直、pre-jump、冲刺与空技落地恢复关闭；
## 空跳落地恢复第 2、3 帧开放（与独立起手同一口径）。输入阶段读到的是含当帧
## 的恢复倒计时（本帧运动归零 = 首个自由帧），因此以 >1 判受限，与消费阶段
## 的起手门时序一致；冲刺倒计时同口径（>1 时本帧仍是冲刺帧）。
func _posture_reeval_open() -> bool:
	if _current_move != null:
		return false
	if _player_stunned():
		return false
	if player_prejump_left > 0:
		return false
	if player_dash_left > 1:
		return false
	if player_landing_recovery_left > 1 and _air_move_started:
		return false
	return true


## 是否按住“后”（相对帧首面向折算；与方向历史同一口径）。
func _holding_back() -> bool:
	return _direction_digit() in [1, 4]


## 当帧输入是否按住下方向（含斜下 1/2/3）：蹲姿姿态与蹲姿选招共用同一口径。
func _down_held() -> bool:
	return _direction_digit() in [1, 2, 3]


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
	## 参考面向相对的小键盘方向（输入阶段先于运动，用翻转前的面向折算；
	## 候选进行中参考 _direction_ref_facing——首次输入时锁定，不被换边重解释，
	## 票据 06 M-04）：前6/后4/下2/上8及斜向1/3/7/9；上下中和，无输入为5。
	var horizontal := 0
	if _frame_input.move_axis == _direction_ref_facing:
		horizontal = 1
	elif _frame_input.move_axis == -_direction_ref_facing:
		horizontal = -1
	var up := _frame_input.up_held or _frame_input.jump_pressed
	var vertical := int(up) - int(_frame_input.down_held)
	return 5 + horizontal + 3 * vertical


## 是否存在已开始、未完成的指令候选（票据 06，M-04）：方向段（过滤中立 5，
## 与识别器同口径）的某个后缀与表内某指令变体的前 k 段按谓词严格连续匹配
##（k ≥ 1 且 k < 变体段数）。此时新方向段按候选首次输入时锁定的相对面向
## 折算，不被换边重解释；无候选的普通移动/蹲防方向照常按当前面向折算。
## 宽松指令的段间跳跃不参与本判定（当前表内指令均为严格记法，连续匹配与
## 真实识别一致）。
func _command_candidate_active() -> bool:
	var segments := _direction_segments()
	if segments.is_empty():
		return false
	for move_id in _moves:
		var move := _moves[move_id] as MoveData
		if move == null or not move.is_strike() or not _has_direction_notation(move):
			continue
		if move.rekka_only or move.charge_only:
			continue
		for notation in _move_notations(move):
			var digits := notation.substr(0, notation.length() - 1)
			for start in range(segments.size()):
				var matched := 0
				while matched < digits.length() and start + matched < segments.size():
					var want := int(digits[matched])
					var got: int = segments[start + matched].x
					if move.lenient_command:
						if not _lenient_set(want).has(got):
							break
					elif got != want:
						break
					matched += 1
				if matched > 0 and matched < digits.length() \
						and start + matched == segments.size():
					return true
	return false


func _phase_plan_motion() -> void:
	## 1.5 计划位移（票据 06，M-01）：声明位移的招式在每个 active 帧生成本帧
	##     计划步长——累计目标按"锚点 + 总位移 × 已完成比例"推算，逐帧步长取
	##     目标与当前位置之差（墙/身体截断造成的落后在后续帧追赶，不重置锚点）。
	##     计划只供命中判定读取，正式位置在运动阶段提交；冻结帧不生成。
	_planned_step = Vector2.ZERO
	if _current_move == null or not _current_move.has_motion():
		return
	if player_phase != PlayerPhase.ACTIVE:
		return
	if _motion_frames_done == 0:
		_motion_anchor_x = player_position.x
		_motion_anchor_y = player_position.y
	var total := _current_move.total_active_frames()
	var done := _motion_frames_done + 1
	var target_x := _motion_anchor_x + _move_direction * _current_move.motion_x_px * float(done) / float(total)
	var target_y := _motion_anchor_y + _current_move.motion_y_px * float(done) / float(total)
	_planned_step = Vector2(target_x - player_position.x, target_y - player_position.y)


func _phase_hit_detection() -> void:
	## 2. 命中判定：判定帧内检查命中框与木桩身体的几何重叠。
	##    木桩中立时可被任何招式命中；受击中只有连段内的合法接续招式可以继续命中，
	##    没有取消资格的独立招式不能绕过取消条件追击。同一次出招最多命中一次；
	##    多段招式按段计——每段对同一目标至多命中一次（票据 05，S-02）。
	_pending_hit = null
	if player_phase == PlayerPhase.ACTIVE and _current_move != null \
			and _current_move.is_strike() and not _segment_hit_done[_current_segment] \
			and player_attack_rect().intersects(_dummy_body_rect()) and _can_hit_dummy():
		_segment_hit_done[_current_segment] = true
		_hit_once_this_move = true
		_pending_hit = _current_move
		_pending_hit_segment = _current_segment
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
	## 玩家命中木桩的结算：先看木桩防御是否挡下（被防是独立接触结果，票据 03），
	## 未挡住时按命中判定前的目标状态与 Counter 窗口精确选择当前判定段的
	## HitProfile（多段招式逐段独立选择，票据 05；无匹配 = MISS_NO_PROFILE，
	## 不造成任何受击效果），再连段伤害递减、按 reaction 应用受击状态、计时与速度。
	var move := _pending_hit
	if _dummy_blocks_attack(move):
		_apply_player_blocked(move, events)
		_pending_hit = null
		return
	var context := _dummy_hit_context()
	var target_state_before := _dummy_target_state()
	var profile := move.segment_profile_for(_pending_hit_segment, target_state_before, context)
	if profile == null:
		## 缺失不回退：不借用 grounded/normal 资料（或其他段的资料），不造成伤害、
		## 不改变受击状态、不刷新倒地/滑行计时，也不取得命中确认或取消资格。
		events.append(CombatEvent.hit_miss(_attack_direction(), _pending_hit_segment + 1))
		_pending_hit = null
		return
	if not combo_active or dummy_state == DummyState.NEUTRAL:
		combo_hits = 0
		combo_total_damage = 0.0
	combo_active = true
	combo_hits += 1
	## 起手修正（C-01/C-02）：首击锁定 starter grade 并以 starter 倍率初始化三层；
	## 后续每击把命中倍率乘入各层——命中滑行目标使用 slide 倍率（票据 05，S-05）、
	## 命中弹地目标使用 bounce 追击倍率（票据 09，B-03）、经空技延迟普通连接起手的
	## 招式使用落地连接倍率（票据 09），其余按普通命中倍率。三层独立舍入，互不反推。
	if combo_hits == 1:
		combo_starter_grade = move.starter_grade
		combo_damage_scale = float(GameParams.STARTER_DAMAGE_SCALE[move.starter_grade])
		combo_time_scale = float(GameParams.STARTER_TIME_SCALE[move.starter_grade])
		combo_trajectory_scale = float(GameParams.STARTER_TRAJECTORY_SCALE[move.starter_grade])
	elif target_state_before == HitProfile.TargetState.GROUND_BOUNCE:
		combo_damage_scale *= GameParams.BOUNCE_HIT_DAMAGE_SCALE
		combo_time_scale *= GameParams.BOUNCE_HIT_TIME_SCALE
		combo_trajectory_scale *= GameParams.BOUNCE_HIT_TRAJECTORY_SCALE
	elif target_state_before == HitProfile.TargetState.GROUND_SLIDE:
		combo_damage_scale *= GameParams.SLIDE_HIT_DAMAGE_SCALE
		combo_time_scale *= GameParams.SLIDE_HIT_TIME_SCALE
		combo_trajectory_scale *= GameParams.SLIDE_HIT_TRAJECTORY_SCALE
	elif _move_via_link and _move_via_air_link:
		combo_damage_scale *= GameParams.LANDING_LINK_HIT_DAMAGE_SCALE
		combo_time_scale *= GameParams.LANDING_LINK_HIT_TIME_SCALE
		combo_trajectory_scale *= GameParams.LANDING_LINK_HIT_TRAJECTORY_SCALE
	else:
		combo_damage_scale *= GameParams.NORMAL_HIT_DAMAGE_SCALE
		combo_time_scale *= GameParams.NORMAL_HIT_TIME_SCALE
		combo_trajectory_scale *= GameParams.NORMAL_HIT_TRAJECTORY_SCALE
	combo_last_scale = maxf(GameParams.COMBO_DAMAGE_FLOOR, combo_damage_scale)
	var damage_base := move.segment_base_damage(_pending_hit_segment) if profile.damage_override < 0 else profile.damage_override
	combo_last_damage = snappedf(damage_base * combo_last_scale, 0.1)
	combo_total_damage = snappedf(combo_total_damage + combo_last_damage, 0.1)
	dummy_hp = maxf(dummy_hp - combo_last_damage, 0.0)
	match profile.reaction:
		HitProfile.Reaction.GROUND_HITSTUN:
			dummy_state = DummyState.GROUND_HITSTUN
			dummy_hitstun_left = _scaled_timer_frames(profile.ground_stun_frames)
		HitProfile.Reaction.LAUNCH:
			dummy_state = DummyState.AIR_HITSTUN
			dummy_hitstun_left = _scaled_timer_frames(profile.air_untech_frames)
		HitProfile.Reaction.GROUND_KNOCKDOWN:
			dummy_state = DummyState.KNOCKED_DOWN
			dummy_knockdown_left = _scaled_timer_frames(profile.knockdown_frames)
		HitProfile.Reaction.LOW_FLOAT_SWEEP:
			## 低浮空扫倒：受击窗口计时入 hitstun 计数；触地后的倒地计时在命中
			## 当帧按同一时间层预先换算（转换前修正层不会再变化——期间的新命中
			## 会整体覆盖状态），触地转换时直接取用。
			dummy_state = DummyState.LOW_FLOAT_SWEEP
			dummy_hitstun_left = _scaled_timer_frames(profile.air_untech_frames)
			dummy_knockdown_left = _scaled_timer_frames(profile.knockdown_frames)
		HitProfile.Reaction.DOWNWARD_SLAM:
			## 向下击落（票据 04）：无空中受击计时——立即获得向下速度坠落，
			## 触地同帧转普通倒地；倒地计时按命中当帧时间层预先换算（同低浮空口径）。
			dummy_state = DummyState.SPIKE_FALL
			dummy_knockdown_left = _scaled_timer_frames(profile.knockdown_frames)
		HitProfile.Reaction.LOW_FLOAT_TO_SLIDE:
			## 击飞触地滑行（票据 05，S-04）：受击窗口计时入 hitstun 计数；触地后
			## 的滑行持续在命中当帧按同一时间层预先换算（期间的新命中会整体覆盖
			## 状态），触地转换时直接取用。有效命中覆盖既有 slide，不叠加计时。
			dummy_state = DummyState.LOW_FLOAT_TO_SLIDE
			dummy_hitstun_left = _scaled_timer_frames(profile.air_untech_frames)
			dummy_slide_left = _scaled_timer_frames(profile.slide_frames)
			dummy_knockdown_left = 0
		HitProfile.Reaction.GROUND_BOUNCE:
			## 统一弹地（票据 09，B-01/B-02；连段路线票据 01 修订）：grounded/
			## airborne 命中都进入同一 GROUND_BOUNCE——profile 只声明进入运动（初
			## 速度）与触地前窗口；追击窗口按统一流程参数在命中当帧按时间层预先
			## 换算（触地事件起倒数）。弹地不重置 starter grade 与三层修正，不刷新
			## 空中资源；再次有效命中正常再次产生弹地反应（无按起手等级的一次性
			## 次数上限），能否延长由窗口、资料、累计修正与真实时空决定。
			dummy_state = DummyState.GROUND_BOUNCE
			dummy_hitstun_left = _scaled_timer_frames(profile.air_untech_frames)
			dummy_bounce_left = _scaled_timer_frames(GameParams.GROUND_BOUNCE_FOLLOWUP_WINDOW_FRAMES)
			dummy_bounce_contacted = false
			dummy_knockdown_left = 0
			dummy_slide_left = 0
	_dummy_fresh_reaction = true
	## 实际命中覆盖被防硬直：连防姿态让位给受击状态，残留被防计时随之作废。
	dummy_blockstun_left = 0
	## 木桩受击打断其进行中的攻击（本帧已捕获的连接仍按互换命中结算）。
	_clear_dummy_move()
	## 实际接地 D 零水平（连段路线票据 01，规则 6）：全部动作键 D 招式（含蓄力与
	## 空中指令技）在命中资料与资格已验证、本次反应施加之前按目标实际接地（空间
	## 上与地面接触，滑地/接地弹地按实际接地判定，离地弹地不算）把合法 normal/
	## counter HIT 的水平受击速度置 0 并覆盖原水平惯性；反应类型、垂直值、计时与
	## 资格保持。被防、挥空、缺失资料不进入本分支，普通倒地不因此新增命中能力。
	if move.action_key == "D" and dummy_on_ground:
		dummy_velocity.x = 0.0
	else:
		dummy_velocity.x = _attack_direction() * roundf(profile.horizontal_speed_px_s * combo_trajectory_scale)
	if profile.reaction == HitProfile.Reaction.LAUNCH or profile.reaction == HitProfile.Reaction.LOW_FLOAT_SWEEP \
			or profile.reaction == HitProfile.Reaction.LOW_FLOAT_TO_SLIDE \
			or profile.reaction == HitProfile.Reaction.GROUND_BOUNCE:
		## 浮空、低浮空与击飞触地滑行命中必定重起跳：即使木桩仍在上一击的微浮中
		## 也按 profile 的垂直初速度重置滞空；普通地面命中保持接地，垂直速度不动。
		## 弹地进入同口径（票据 09，B-02）：grounded 命中立即按初速度离地上弹，
		## airborne 命中沿 profile 轨迹落向地面（覆盖既有浮空速度）；触地反弹速度
		## 在 bounce_contact 时按当时轨迹层换算施加。
		dummy_velocity.y = -roundf(profile.upward_speed_px_s * combo_trajectory_scale)
	if profile.reaction == HitProfile.Reaction.DOWNWARD_SLAM:
		dummy_velocity.y = roundf(profile.downward_speed_px_s * combo_trajectory_scale)

	_move_hit_confirmed = true
	_hit_confirm_frame = _normal_frame_index
	_move_contact_confirmed = true
	_contact_frame = _normal_frame_index
	_move_blocked = false
	_open_rekka_window(move)
	## 身体穿越许可（票据 06，M-02）：实际 HIT 授予本动作位移段的穿越资格——
	## 被防、挥空、缺失资料不授予；许可随本招结束清零，不传给下一招。
	if move.has_motion():
		_cross_ok = true
	## 特殊进入资格授予（票据 05，I-05）：实际 HIT 当下取得（被防、挥空、缺失
	## profile 都不授予）；多段招式每段命中各自授予并重置窗口。
	if not move.special_entry_targets.is_empty():
		_special_entry_open = true
		_special_entry_frame = _normal_frame_index
		_special_entry_move = move
	## 命中落地取消资格授予（票据 08，L-01）：实际 HIT 当下取得，绑定本次连段
	## 与当前目标；被防、挥空、缺失 profile 不授予。资格跨过授予招式的落地截断
	## 存活，落地事件确认后的首个可行动帧一次性消费（见 _try_consume_hit_landing）。
	if not move.hit_landing_cancel_targets.is_empty() and move.stance == MoveData.Stance.AIR:
		_hit_landing_open = true
		_hit_landing_move = move
		_hit_landing_input_at = -1
		_hit_landing_input_move_id = ""
		_hit_landing_landed_frame = -1
	events.append(CombatEvent.hit(combo_last_damage, _attack_direction(), combo_hits,
		context == HitProfile.HitContext.COUNTER, _pending_hit_segment + 1))
	## 命中帧完成命中与受击应用后开始 Hitstop：冻结后续 8 个物理帧（双方动作、
	## 位置、速度、受击、落地与受身计时暂停；物理帧号照常递增，输入仍被采样记录）。
	_hitstop_left = GameParams.HITSTOP_FRAMES
	events.append(CombatEvent.hitstop_started())
	## 命中弹地目标不再有一次性资格/强制终点（连段路线票据 01）：该命中按所选
	## profile 正常结算并开放后续取消/连接，连段是否延续由自然恢复、窗口、资料
	## 与累计修正决定。
	if profile.reaction == HitProfile.Reaction.GROUND_KNOCKDOWN:
		## 普通倒地进入即结束当前连段；倒地处理本身继续独立计时。
		_end_combo(CombatEvent.ComboEndReason.KNOCKDOWN, events)
	if move.is_finisher:
		## 收尾结束连段路线，但不主动清除木桩的受击/倒地处理。
		_end_combo(CombatEvent.ComboEndReason.FINISHER, events)
	_pending_hit = null



## 时间层修正输出（C-02）：floor(声明计时 × time_scale)，夹到最小合法计时 1；
## 不使用伤害值或命中数反推。适用于受击/受身/倒地三种计时。
func _scaled_timer_frames(declared_frames: int) -> int:
	return maxi(1, int(floor(declared_frames * combo_time_scale)))


## 命中判定前的木桩目标状态：接地且非倒地为 GROUNDED，真正离地为 AIRBORNE，
## 地面滑行为 GROUND_SLIDE（票据 05，S-05），弹地为 GROUND_BOUNCE（票据 09，
## B-01）——均只有显式声明该状态资料的招式能命中，缺失即 MISS_NO_PROFILE，
## 不回退 grounded/airborne。倒地不可命中（_can_hit_dummy 已排除）。
func _dummy_target_state() -> HitProfile.TargetState:
	if dummy_state == DummyState.GROUND_SLIDE:
		return HitProfile.TargetState.GROUND_SLIDE
	if dummy_state == DummyState.GROUND_BOUNCE:
		return HitProfile.TargetState.GROUND_BOUNCE
	return HitProfile.TargetState.GROUNDED if dummy_on_ground else HitProfile.TargetState.AIRBORNE


## 木桩侧 Counter Hit 上下文：木桩自身招式处于 startup 或 recovery 的显式
## 易受击窗口时为 COUNTER；active 不在窗口内。窗口随目标状态派生——命中被
## 应用（打断招式）或目标离开窗口后，下一次命中自然回到 NORMAL。
func _dummy_hit_context() -> HitProfile.HitContext:
	if _dummy_move != null and (dummy_phase == PlayerPhase.STARTUP or dummy_phase == PlayerPhase.RECOVERY):
		return HitProfile.HitContext.COUNTER
	return HitProfile.HitContext.NORMAL


## 玩家侧目标状态与 Counter 上下文（木桩攻击命中玩家时与木桩侧同构）。
func _player_target_state() -> HitProfile.TargetState:
	return HitProfile.TargetState.GROUNDED if player_on_ground else HitProfile.TargetState.AIRBORNE


func _player_hit_context() -> HitProfile.HitContext:
	if _current_move != null and (player_phase == PlayerPhase.STARTUP or player_phase == PlayerPhase.RECOVERY):
		return HitProfile.HitContext.COUNTER
	return HitProfile.HitContext.NORMAL


## 木桩打击对玩家的结算（issue 16 + 命中资料）：与木桩侧同一套 profile 精确
## 选择——目标状态按玩家接地/离地，Counter 窗口按玩家自身招式阶段。防御姿态
## 按显式属性矩阵判定。挡下 → 防御硬直（= 所选 profile 的反应计时）+ BLOCKED
## 事件 + Hitstop；漏防或无姿态 → 玩家受击硬直 + 水平击退 + PLAYER_HIT 事件 +
## Hitstop（进行中的招式被打断，连段以收招未接续结束）。无匹配 profile 时与
## 木桩侧同口径：HIT_MISS，不造成硬直或位移。玩家无生命值系统，打击数据对
## 玩家只作用硬直与水平位移（玩家的浮空/倒地受击不在本切片范围）。
func _phase_apply_dummy_hit(events: Array[CombatEvent]) -> void:
	if _pending_dummy_hit == null:
		return
	var move := _pending_dummy_hit
	var direction := _dummy_attack_direction()
	var profile := MoveData.profile_for(move, _player_target_state(), _player_hit_context())
	if profile == null:
		events.append(CombatEvent.hit_miss(direction))
		_pending_dummy_hit = null
		return
	if _blocks_attack(move):
		player_guard_stun_left = profile.reaction_timer_frames()
		events.append(CombatEvent.blocked(direction))
	else:
		if _current_move != null:
			_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
			_clear_current_move()
		## 受击打断进行中的冲刺（issue 18）：硬直与击退接管运动，冲刺计数清零。
		player_dash_left = 0
		_dash_direction = 0
		player_hitstun_left = profile.reaction_timer_frames()
		player_velocity.x = direction * profile.horizontal_speed_px_s
		events.append(CombatEvent.player_hit(direction))
	_player_fresh_stun = true
	if _hitstop_left == 0:
		## 同帧互换命中（玩家先命中木桩）只开启一个停顿窗口、只报一次边界事件。
		_hitstop_left = GameParams.HITSTOP_FRAMES
		events.append(CombatEvent.hitstop_started())
	_pending_dummy_hit = null


## 防御姿态 × 攻击属性矩阵（玩家与木桩共用同一领域规则）：站防挡
## high/mid/overhead、漏 low；蹲防挡 high/mid/low、漏 overhead；空防默认可挡
## 带 air 的打击（正交类别；纯地面属性不在空防默认域内，未来例外须显式声明）；
## 无姿态不挡。
static func _posture_blocks(posture: GuardPosture, move: MoveData) -> bool:
	match posture:
		GuardPosture.STANDING:
			return move.attack_attribute != MoveData.AttackAttribute.LOW
		GuardPosture.CROUCH:
			return move.attack_attribute != MoveData.AttackAttribute.OVERHEAD
		GuardPosture.AIR:
			return move.air_attack
		_:
			return false


## 玩家侧挡下判定：受击硬直中被打破的防御不提供保护——硬直期间一律不挡
## （姿态可观测量冻结只是"不改姿态"，不代表仍在防御）。
func _blocks_attack(move: MoveData) -> bool:
	if player_hitstun_left > 0:
		return false
	return _posture_blocks(player_guard, move)


## 木桩是否挡下玩家攻击（票据 03）：被防结果三字段未声明的招式默认不可被防
## （默认禁止，无全局回退）；受击/倒地/受身状态不挡；被防硬直期间姿态冻结
## 保持（连防）。挡下走独立被防结算，不读命中资料。
func _dummy_blocks_attack(move: MoveData) -> bool:
	if move.block_freeze_frames < 0 or move.block_stun_frames < 0 or move.block_pushback_px_s < 0.0:
		return false
	if dummy_state != DummyState.NEUTRAL:
		return false
	return _posture_blocks(dummy_guard, move)


## 玩家攻击被木桩挡下的独立结算（D-02/D-03）：记录被防接触（链式/必杀取消的
## 资格来源，不产生命中确认），施加被防停顿、被防硬直与双方被防推退；不造成
## 伤害、不改受击状态、不锁 starter、不累计修正、不续连段。停顿期间一切计时
## 冻结，被防硬直自恢复后的首个正常帧起倒数。
## 多段招式段 1 被防立即终止整招（票据 05，S-02）：只产生段 1 的被防结果，
## 后续段与后摇不再执行——停顿结束后玩家直接回中立。
func _apply_player_blocked(move: MoveData, events: Array[CombatEvent]) -> void:
	_move_contact_confirmed = true
	_contact_frame = _normal_frame_index
	_move_blocked = true
	_open_rekka_window(move)
	dummy_blockstun_left = move.block_stun_frames
	_dummy_fresh_reaction = true
	dummy_velocity.x = _attack_direction() * move.block_pushback_px_s
	player_velocity.x = -_attack_direction() * move.block_pushback_px_s
	_hitstop_left = move.block_freeze_frames
	events.append(CombatEvent.attack_blocked(_attack_direction(), dummy_guard,
		move.block_freeze_frames, move.block_stun_frames, move.block_pushback_px_s, _pending_hit_segment + 1))
	if move.block_freeze_frames > 0:
		events.append(CombatEvent.hitstop_started())
	if _pending_hit_segment == 0 and move.segment_count() > 1:
		_clear_current_move()


func _phase_motion(events: Array[CombatEvent]) -> void:
	## 4. 运动/落地/自然受身：先按已应用的速度积分位置，再处理落地、
	## 身体重叠与木桩自然受身；招式帧计数也在本阶段末尾推进。
	_motion_player(events)
	_motion_dummy(events)
	_update_facing_after_motion(events)
	_resolve_body_overlap()
	_advance_move(events)
	_advance_dummy_move()


func _phase_cancel() -> void:
	## 5. 取消判定：链式取消、必杀取消、命中确认取消是三种独立窗口（B7）。
	##    链式/必杀按接触结果开放——实际 HIT 与被防（BLOCKED）接触都成立，窗口
	##    自接触帧计龄（票据 03）；命中确认与 jump cancel 只在实际 HIT 且连段仍
	##    活跃、木桩仍可追击时成立；挥空不产生接触、取消年龄或连段延续。
	##    状态锁同时约束独立起手与取消；显式目标不能绕过落地首帧或空技恢复。
	##    目标必须与当前招式同姿态，落地不把空中缓存重解释为地面技。
	_cancel_targets.clear()
	if _current_move == null or not _independent_start_allowed():
		return
	if _move_hit_confirmed and combo_active and _dummy_pursuable():
		var age := _normal_frame_index - _hit_confirm_frame
		if age < 0:
			return
		for pair in [
				[_current_move.cancel_targets, _current_move.cancel_window_frames],
				[_current_move.chain_cancel_targets, _current_move.chain_cancel_window_frames],
				[_current_move.special_cancel_targets, _current_move.special_cancel_window_frames]]:
			if age <= pair[1]:
				_append_stance_matching_targets(pair[0], _current_move.stance)
		## 空中出口（票据 07）：声明 air_exit_targets 的地面招式在实际 HIT 后，若
		## 本招计划位移已使玩家真实离地，开放空中姿态起手的目标（沿用命中确认窗口；
		## 被防接触不开本分支——_append_stance_matching_targets 按玩家当前姿态过滤，
		## 着地时目标自然不匹配）。
		if age <= _current_move.cancel_window_frames and not player_on_ground:
			_append_stance_matching_targets(_current_move.air_exit_targets, MoveData.Stance.AIR)
		## 特殊进入资格（票据 05，I-05）：仅实际 HIT 授予，不开放于被防接触；
		## 资格属于授予招式且仍在自身消费窗口内时开放其声明目标（如 236C → 5D）。
		if _special_entry_live():
			_append_stance_matching_targets(_special_entry_move.special_entry_targets, _current_move.stance)
		return
	if _move_contact_confirmed and _move_blocked:
		var contact_age := _normal_frame_index - _contact_frame
		if contact_age < 0:
			return
		for pair in [
				[_current_move.chain_cancel_targets, _current_move.chain_cancel_window_frames],
				[_current_move.special_cancel_targets, _current_move.special_cancel_window_frames]]:
			if contact_age <= pair[1]:
				_append_stance_matching_targets(pair[0], _current_move.stance)


func _append_stance_matching_targets(move_ids: Array[String], stance: MoveData.Stance) -> void:
	## 把姿态一致的接续目标并入取消目标（重复条目只保留一个）。
	for move_id in move_ids:
		if _cancel_targets.has(move_id):
			continue
		var target := _moves.get(move_id) as MoveData
		if target != null and target.stance == stance and _stance_matches(target):
			_cancel_targets.append(move_id)


## 特殊进入资格当前是否可消费：资格开放、授予招式仍在执行且接触年龄仍在
## special_entry_window_frames 内（正常帧计龄，Hitstop 不计——停顿中资格保持）。
func _special_entry_live() -> bool:
	if not _special_entry_open or _special_entry_move == null or _special_entry_move != _current_move:
		return false
	var age := _normal_frame_index - _special_entry_frame
	return age >= 0 and age <= _special_entry_move.special_entry_window_frames


func _phase_consume_buffer(events: Array[CombatEvent]) -> void:
	## 6. 消费缓存：空闲时按缓存起手独立招式；命中确认取消窗口内按取消资格
	##    转入下一招。jump cancel 后的空中追击起手按合法接续起手（只有配置的
	##    起手招式获得资格，普通跳跃后的空中招式仍是独立招式）。
	##    落地恢复锁先于取消资格；旧空中缓存不跨姿态补发地面招式。
	##    跳跃输入槽独立消费（issue 15）：地面中立普通跳或命中确认 jump cancel
	##    都转入 4f 起跳准备。显式组合（B+C 投，issue 17）优先级最高：先尝试
	##    已配齐的投意图、结算拆投与投结果，之后 jump 与动作缓存同时合法时比较
	##    原始请求物理帧——较新者优先、同一物理帧攻击优先，每帧最多启动一个
	##    新动作；未选中的槽保留原年龄，后续帧按新状态重查。
	_attempt_pending_throw(events)
	_start_locked_rekka()
	_evaluate_throw_tech(events)
	_apply_throw_result(events)
	_resolve_pending_link(events)
	_resolve_air_link(events)
	_try_consume_hit_landing(events)
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
	## 空中招式落地：滞留地面姿态的空中招式作废（空中路线不因落地延续，剩余
	## active 不延续到落地后）。声明了普通连接边（j6D）或命中落地资格开放
	## （j2D，L-01）的空招把连段存续推迟到落地接缝，其余以收招未接续结束。
	if _current_move != null and _current_move.stance == MoveData.Stance.AIR and player_on_ground:
		if _air_move_defers_end(_current_move):
			_pending_air_link = _pending_air_link or (combo_active and not _current_move.link_targets.is_empty())
			_finished_move = _current_move
			_finished_move_hit = _move_hit_confirmed
			_finished_move_via_entry = _move_via_special_entry
		else:
			_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
		_clear_current_move()
	## 命中确认取消窗口关闭且没有接续时连段结束；木桩受击处理不受影响。
	## 窗口年龄按正常战斗帧计：Hitstop 之后关闭帧相应后移。声明了普通连接边的
	## 招式不在此结束——连接评估保留到完全恢复后的首个合法帧（I-06）。特殊进入
	## 资格仍在消费窗口内（票据 05：命中当下取得、Hitstop 与 slide 期间保留），
	## 本招经资格起手且声明了来源限定连接边，或命中落地资格开放（票据 08：j2D
	## 的落地消费在落地接缝结算）时，同样推迟到窗口关闭/完全恢复/落地。
	if _current_move != null and _move_hit_confirmed and combo_active \
			and _current_move.link_targets.is_empty() \
			and not _special_entry_live() \
			and not (_move_via_special_entry and not _current_move.special_entry_link_targets.is_empty()) \
			and not _hit_landing_open \
			and _normal_frame_index - _hit_confirm_frame > _current_move.cancel_window_frames:
		_report_undeclared_link_gap(_current_move, events)
		_end_combo(CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED, events)


## 收招当帧的普通连接消费（I-06）：前招完全恢复后的首个合法帧按合法接续起手
## 缓存目标（连段延续，产生接触前不中断、不产生取消年龄）；门不满足时报告
## 可读失败原因并结束连段。缓存由此消费失败作废，不转为独立起手。
func _resolve_pending_link(events: Array[CombatEvent]) -> void:
	if not _pending_link_check:
		return
	_pending_link_check = false
	if _link_candidate_available(_finished_move):
		var target := _moves.get(_buffered_move_id) as MoveData
		_start_move(_buffered_move_id, target, true)
		_move_via_link = true
		_note_buffer_consumed(_buffered_move_id)
		_clear_buffer()
		_finished_move = null
		return
	events.append(CombatEvent.link_failed(_link_fail_reason(_moves.get(_buffered_move_id) as MoveData), _buffered_move_id))
	_clear_buffer()
	_finished_move = null
	_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)


## 空技收招/落地截断是否把连段存续推迟到落地接缝（票据 08）：命中落地资格
## 开放时（j2D 实际 HIT，L-01），或声明了普通连接边且连段仍活跃时（j6D）。
## 挥空且无连接边的空招照常在截断/收招帧结束连段——空技落地恢复仍全程承担。
func _air_move_defers_end(move: MoveData) -> bool:
	if move.stance != MoveData.Stance.AIR:
		return false
	if _hit_landing_open and _hit_landing_move == move:
		return true
	return combo_active and not move.link_targets.is_empty()


## 弹地等待（票据 09，B-02/B-03）：前招（j214D）实际命中把木桩送入弹地且尚未
## 触地时，延迟普通连接的评估推迟到 bounce_contact 打开追击窗口——「触地后按
## 剩余硬直继续」的目押语义。等待有界：触地前受身/窗口关闭按既有失败口径
## 结束连段；等待期间动作缓存不被独立起手窃取（保持连接评估的输入资格）。
func _bounce_wait_active() -> bool:
	return _pending_air_link and _finished_move != null and _finished_move_hit \
		and dummy_state == DummyState.GROUND_BOUNCE and not dummy_bounce_contacted


## 空技延迟普通连接消费（票据 08：j6D）：攻击者完全落地恢复后的首个合法帧
## 按缓存消费声明目标——与地面普通连接同一口径（合法接续起手、不产生取消
## 年龄、不跳过落地首帧锁），目标剩余硬直、姿态与 active 重叠重新判定；
## 无可消费候选时按目押失败/配置缺口报告并结束连段。弹地等待中（前招命中
## 弹地、触地未发生）评估推迟到追击窗口打开（票据 09）。
func _resolve_air_link(events: Array[CombatEvent]) -> void:
	if not _pending_air_link:
		return
	if _current_move != null or not player_on_ground or _player_stunned():
		return
	if not _independent_start_allowed():
		return
	if _bounce_wait_active():
		return
	_pending_air_link = false
	var finished := _finished_move
	_finished_move = null
	if _link_candidate_available(finished):
		var target := _moves.get(_buffered_move_id) as MoveData
		_start_move(_buffered_move_id, target, true)
		_move_via_link = true
		_move_via_air_link = true
		_note_buffer_consumed(_buffered_move_id)
		_clear_buffer()
		return
	if _link_declared_but_gated(finished):
		events.append(CombatEvent.link_failed(_link_fail_reason(_moves.get(_buffered_move_id) as MoveData), _buffered_move_id))
		_clear_buffer()
	else:
		_report_undeclared_link_gap(finished, events)
	_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)


## j2D 命中落地取消的一次性消费（票据 08，L-01）：落地事件确认后的首个到达
## 消费阶段的正常帧尝试——落地首帧统一锁保持（落地当帧不消费），例外仅对
## 授予招式声明的目标开放并跳过其余空技恢复（其他输入仍按普通落地恢复门）。
## 输入未记录、窗口过期、连段已结束或木桩不可追击时资格就地失效，连段按
## 收招未接续结束；消费成功则目标以合法接续起手并清除资格。
func _try_consume_hit_landing(events: Array[CombatEvent]) -> void:
	if not _hit_landing_open:
		return
	if _hit_landing_landed_frame < 0 or _frame_index <= _hit_landing_landed_frame:
		return
	var consumed := false
	if _hit_landing_input_at >= 0 and _hit_landing_move != null and combo_active \
			and _dummy_pursuable() and not _player_stunned() and _current_move == null:
		var age := _normal_frame_index - _hit_landing_input_at
		if age >= 0 and age <= _hit_landing_move.hit_landing_cancel_window_frames:
			var target_id := _hit_landing_input_move_id
			var target := _moves.get(target_id) as MoveData
			if target != null and _stance_matches(target):
				consumed = true
				_close_hit_landing()
				_start_move(target_id, target, true)
				_note_buffer_consumed(target_id)
				## 同一输入不再作为独立起手补发：专用槽与常规缓存一并清空。
				_clear_buffer()
	if not consumed:
		_close_hit_landing()
		_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)


## 清除命中落地取消资格与专用输入槽（消费、失效或连段结束共用）。
func _close_hit_landing() -> void:
	_hit_landing_open = false
	_hit_landing_move = null
	_hit_landing_input_at = -1
	_hit_landing_input_move_id = ""
	_hit_landing_landed_frame = -1


func _buffer_action_candidate() -> Dictionary:
	## 动作缓存的当帧可消费候选（判据唯一来源，仲裁与执行共用）：
	## {"move_id": 起手招式, "is_followup": 合法接续起手}。
	## 无候选返回空表。组合等待中的成员单键只是候选，不参与消费（issue 17）。
	if _buffered_key == "" and _buffered_move_id == "":
		return {}
	if _buffer_waiting:
		return {}
	if _bounce_wait_active():
		## 弹地等待中缓存不作为独立起手消费（票据 09）：留给触地后的延迟连接
		## 评估；年龄照常增长，过早输入会自然过期并按目押失败上报。
		return {}
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
	## 消费缓存；独立起手走空闲起手。
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
	## 因此准备期间一律只记录不消费。落地恢复首帧完全锁定，取消路径共用此门；
	## 空跳恢复第 2、3 帧可取消为合法攻击；启动过空中
	## 招式的落地恢复基础及额外恢复全程不可取消（挥空同样受限）。
	## 受击硬直与防御硬直期间不可独立起手；冲刺是承诺性位移状态，期间不可
	## 起手（缓存的输入保留原龄，冲刺结束按新状态重查）；投与蹲下/防御的姿态
	## 门各自独立判定。
	if _player_stunned():
		return false
	if player_prejump_left > 0 or player_dash_left > 0:
		return false
	if _player_just_landed:
		return false
	if player_landing_recovery_left > 0:
		return not _air_move_started
	return true


func _jump_slot_ready() -> bool:
	## 跳跃输入槽的当帧合法性：起跳准备、落地恢复、冲刺、受击/防御硬直与空中
	## 一律不可消费（无二段跳；受限恢复期不重新起跳）。地面中立是普通跳；招式
	## 阶段需要 jump cancel 配置 + 命中确认 + 取消窗口 + 可追击木桩同时成立。
	if not _jump_slot_active:
		return false
	if _player_stunned():
		return false
	if player_prejump_left > 0 or player_landing_recovery_left > 0 or player_dash_left > 0:
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

## 普通投执行门：仅地面站立、可自由行动可投（蹲下、pre-jump、冲刺、空中、招式
## 阶段、受击/防御硬直与落地恢复一律禁用——空跳恢复第 2、3 帧的攻击例外不适用
## 于投）。投距 = 身体中心水平距离 ≤ 投技 throw_range 且身体矩形垂直重叠。
## 返回 0（可执行）、ThrowFailReason.STATE 或 ThrowFailReason.RANGE。
func _throw_start_gate() -> int:
	if _current_move != null or _player_stunned() or not player_on_ground \
			or player_prejump_left > 0 or player_landing_recovery_left > 0 or player_dash_left > 0 or player_crouching:
		return CombatEvent.ThrowFailReason.STATE
	if dummy_state == DummyState.KNOCKED_DOWN:
		## 倒地处理期间不可被抓：投结果会改写独立倒地计时，普通倒地的恢复
		## 语义（计时结束才自然恢复）优先（OTG 不在本切片范围）。
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
	dummy_blockstun_left = 0
	_dummy_fresh_reaction = true
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
	elif player_dash_left > 0:
		player_dash_left -= 1
	var axis := _frame_input.move_axis
	if (player_prejump_left > 0 or takeoff_this_frame) and _jump_direction != 0:
		## 起跳准备按消费时冻结的世界跳向移动（含离地当帧——首个空中帧前方向
		## 仍属准备期）：反向输入不重写斜跳请求；原始 8 请求（冻结方向为 0）
		## 仍用当前输入改成斜跳，不重置准备计时。
		axis = _jump_direction
	## 出招与受击/防御硬直期间水平输入失效，只保留摩擦减速（地面/空中一致）；
	## 普通空中运动保留起跳横向速度：方向输入不改变普通空中速度或面向。
	## 冲刺期间（含触发当帧——输入阶段已置计数）水平速度锁定为冲刺速度：
	## 不响应方向输入也不衰减，恰持续 PLAYER_DASH_FRAMES 帧后交回普通移动。
	var stunned := _player_stunned()
	if player_dash_left > 0:
		player_velocity.x = _dash_direction * GameParams.PLAYER_DASH_SPEED
	elif player_phase == PlayerPhase.NEUTRAL and not stunned:
		if player_on_ground:
			if player_crouching:
				# 入蹲当帧清除行走惯性；保留原始方向供蹲防和指令匹配。
				# 仅约束自由行动，受击硬直中的击退仍走下方摩擦分支。
				player_velocity.x = 0.0
			elif axis != 0:
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
		if not player_on_ground:
			_handle_landing(events)
	else:
		player_on_ground = false
	if _planned_step != Vector2.ZERO:
		## 计划位移提交（票据 06，M-01）：速度积分与落地之后提交本帧计划步长
		##（先版边截断，再身体穿越约束），与普通运动共用同一运动阶段收尾。
		var grounded_before_commit := player_on_ground
		_commit_planned_step()
		if not grounded_before_commit and player_on_ground:
			## 计划位移造成的真实落地（票据 08：j6D/j2D 的向下位移段）与速度积分
			## 落地同一处理——首帧锁、落地恢复与落地接缝确认不因位移来源而绕过。
			_handle_landing(events)


## 落地结算（速度积分与计划位移两个入口共用）：落地首帧统一锁（不可蹲/不可
## 防御/不可行动）、落地恢复计数、jump cancel 追击资格作废与空技落地接缝的
## 落地确认（票据 08）。
func _handle_landing(events: Array[CombatEvent]) -> void:
	player_on_ground = true
	player_velocity.y = 0.0
	_player_just_landed = true
	_begin_landing_recovery()
	_clear_posture()
	if not _jump_cancel_followups.is_empty():
		# jump cancel 后落地仍未接续空中追击：追击资格作废，连段以收招未接续结束。
		_jump_cancel_followups.clear()
		if combo_active and _current_move == null:
			_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
	if _hit_landing_open:
		## 落地事件确认（L-01）：落地当帧记录但不消费——首帧锁之后的第一个到达
		## 消费阶段的正常帧尝试一次性消费。
		_hit_landing_landed_frame = _frame_index


func _commit_planned_step() -> void:
	## 提交本帧计划位移：正式位置在此改变（M-01 步骤 3）。版边截断优先——被
	## 墙截断的位移照常结算命中但不换边（实际终点未越过目标）；随后按 M-02 处
	## 理身体约束：无命中穿越许可（被防/挥空/缺失资料）时位移不得越过目标到
	## 另一侧，垂直重叠时截在移动前所在侧的身体边界；有许可但终点仍与目标
	## 重叠（轨迹不足以到达另一侧合法位置）时同样保留原侧。
	var target := player_position + _planned_step
	_planned_step = Vector2.ZERO
	_motion_frames_done += 1
	var clamped_x := clampf(target.x, GameParams.stage_left_limit(), GameParams.stage_right_limit())
	if not is_equal_approx(clamped_x, target.x):
		_motion_wall_clamped = true
	target.x = clamped_x
	## 向下的计划位移段（票据 08：j2D/j6D）不越过地面——钳到站地高度，
	## 是否构成落地由 _motion_player 的落地结算判定。
	target.y = minf(target.y, GameParams.ground_stand_y())
	if absf(target.y - dummy_position.y) < GameParams.BODY_SIZE.y:
		var origin_side := 1.0 if player_position.x >= dummy_position.x else -1.0
		var dx := target.x - dummy_position.x
		if absf(dx) < GameParams.BODY_SIZE.x or (signf(dx) != origin_side and not _cross_ok):
			target.x = clampf(dummy_position.x + GameParams.BODY_SIZE.x * origin_side,
				GameParams.stage_left_limit(), GameParams.stage_right_limit())
	player_position = target
	## 计划位移造成的真实离地（票据 07）：声明向上位移的招式（6D/2D）在位移提交
	## 当帧真实转为空中姿态——后续帧自然受重力回落；这不是姿态瞬移，空中出口、
	## 空中姿态解析与有限滞空都以此真实状态为前提。
	player_on_ground = player_position.y >= GameParams.ground_stand_y()


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
	if dummy_state == DummyState.GROUND_HITSTUN or dummy_state == DummyState.AIR_HITSTUN \
			or dummy_state == DummyState.KNOCKED_DOWN or dummy_state == DummyState.LOW_FLOAT_SWEEP \
			or dummy_state == DummyState.SPIKE_FALL or dummy_state == DummyState.LOW_FLOAT_TO_SLIDE \
			or dummy_state == DummyState.GROUND_SLIDE or dummy_state == DummyState.GROUND_BOUNCE:
		friction = GameParams.DUMMY_HITSTUN_FRICTION
	## 未受击且真正离地的木桩按跳跃者运动（票据 02，D84）：对空初态来自普通
	## 跳跃的成对状态，其空中段保持水平速度（与真实跳跃一致，E45 jumps 记录
	## 为常 vx），重力、墙限与落地照常；首次被命中或被防后回到标准木桩物理。
	## 离地判定按位置导出（含外部注入初态的首帧；判定完全由已序列化状态
	## 组成，保存/续跑无需新增字段）。
	var unhit_airborne := dummy_state == DummyState.NEUTRAL and dummy_blockstun_left == 0 \
		and dummy_position.y < GameParams.ground_stand_y() - 0.001
	if not unhit_airborne:
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
	if dummy_state == DummyState.NEUTRAL and dummy_blockstun_left > 0 and not _dummy_fresh_reaction:
		## 被防硬直：停顿结束后按正常帧倒数（被防当帧不消耗，冻结帧不推进）；
		## 期间姿态冻结（连防）、不可按请求出招，倒数归零后的下一输入帧恢复自由。
		dummy_blockstun_left = maxi(dummy_blockstun_left - 1, 0)
	match dummy_state:
		DummyState.GROUND_HITSTUN:
			if dummy_on_ground and not _dummy_fresh_reaction:
				# 自然受身：地面硬直归零即回到中立并结束受击。
				# 落地保留剩余受击硬直——滞空期间硬直帧数暂停消耗。
				_tick_ground_hitstun(events)
		DummyState.AIR_HITSTUN:
			if dummy_on_ground:
				# 落地保留剩余浮空硬直：未耗尽就落地时转为地面硬直，
				# 落地当帧起按地面规则继续消耗（与地面受击的落地帧一致）。
				dummy_state = DummyState.GROUND_HITSTUN
				if not _dummy_fresh_reaction:
					_tick_ground_hitstun(events)
			elif not _dummy_fresh_reaction:
				# 浮空受身：浮空硬直归零当帧立即结束连段；落地后才恢复中立。
				dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
				if dummy_hitstun_left == 0:
					dummy_state = DummyState.AIR_RECOVERED
					_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
		DummyState.AIR_RECOVERED:
			if dummy_on_ground:
				dummy_state = DummyState.NEUTRAL
				events.append(CombatEvent.dummy_recovered())
		DummyState.LOW_FLOAT_SWEEP:
			if dummy_on_ground:
				## 低浮空触地：同帧转普通倒地并结束连段（运动阶段先于取消窗口
				## 关闭结算——同帧两者都到时以倒地原因报告）；倒地计时取命中当帧
				## 按时间层预先换算的值，本帧不消耗（下一帧起按倒地规则倒数）。
				dummy_state = DummyState.KNOCKED_DOWN
				events.append(CombatEvent.low_float_landed())
				_end_combo(CombatEvent.ComboEndReason.KNOCKDOWN, events)
			elif not _dummy_fresh_reaction:
				## 滞空期间消耗受击窗口：调校初值下触地先于窗口耗尽；窗口先
				## 耗尽时按浮空受身处理（同样结束连段），不产生倒地。
				dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
				if dummy_hitstun_left == 0:
					dummy_state = DummyState.AIR_RECOVERED
					_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
		DummyState.SPIKE_FALL:
			if dummy_on_ground:
				## 向下击落触地：同帧转普通倒地（倒地计时为命中当帧预先换算值，
				## 本帧不消耗）；连段若仍活跃（非收尾配置的向下击落）以倒地结束。
				dummy_state = DummyState.KNOCKED_DOWN
				events.append(CombatEvent.spike_landed())
				_end_combo(CombatEvent.ComboEndReason.KNOCKDOWN, events)
		DummyState.LOW_FLOAT_TO_SLIDE:
			if dummy_on_ground:
				## 击飞触地滑行（票据 05，S-04/S-05）：同帧转 GROUND_SLIDE；滑行
				## 计时为命中当帧预先换算值，自下一正常帧起倒数（本帧 match 已
				## 分发，不重复消耗）。连段继续——slide 是可追击窗口，不是倒地。
				dummy_state = DummyState.GROUND_SLIDE
				dummy_hitstun_left = 0
				events.append(CombatEvent.slide_started())
			elif not _dummy_fresh_reaction:
				## 滞空期间消耗击飞受击窗口：调校初值下触地先于窗口耗尽；窗口先
				## 耗尽时按浮空受身处理（结束连段），不产生滑行。
				dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
				if dummy_hitstun_left == 0:
					dummy_state = DummyState.AIR_RECOVERED
					_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
		DummyState.GROUND_SLIDE:
			## 地面滑行：独立计时逐帧倒数（触地转换当帧不消耗，停顿帧不推进）；
			## 归零自然回中立并结束连段，不转普通倒地、不接受 OTG。滑行期间只有
			## 显式声明 slide 资料的招式能命中（资料门由 profile 精确匹配承担），
			## 有效命中整体覆盖本状态与计时。
			if not _dummy_fresh_reaction:
				dummy_slide_left = maxi(dummy_slide_left - 1, 0)
				if dummy_slide_left == 0:
					dummy_state = DummyState.NEUTRAL
					events.append(CombatEvent.dummy_recovered())
					_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
		DummyState.GROUND_BOUNCE:
			if not dummy_bounce_contacted:
				if dummy_on_ground:
					## 弹地首次触地（票据 09，B-02）：记录 bounce_contact，按反弹速度
					## （轨迹层换算）进入上升阶段，统一追击窗口自本事件起倒数（当帧
					## 不消耗，与 slide 转换同口径）；从该事件起开放追击。
					dummy_bounce_contacted = true
					dummy_hitstun_left = 0
					dummy_velocity.y = -roundf(GameParams.GROUND_BOUNCE_REBOUND_SPEED_PX_S * combo_trajectory_scale)
					events.append(CombatEvent.bounce_contact())
				elif not _dummy_fresh_reaction:
					## 触地前窗口（资料声明，时间层换算）：调校初值下触地先于窗口耗尽；
					## 窗口先耗尽时按浮空受身处理（结束连段），不产生弹地。
					dummy_hitstun_left = maxi(dummy_hitstun_left - 1, 0)
					if dummy_hitstun_left == 0:
						dummy_state = DummyState.AIR_RECOVERED
						_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
			elif not _dummy_fresh_reaction:
				## 弹地追击窗口（bounce_contact 当帧按时间层预先换算，触地当帧不消耗）：
				## 上升/下降滞空照常倒数（停顿帧不进入本函数）；归零自然恢复——空中
				## 则空中受身，落地则回中立，不转普通倒地。一次弹地至多一次反弹：
				## 再次触地不重置窗口、不再反弹。
				dummy_bounce_left = maxi(dummy_bounce_left - 1, 0)
				if dummy_bounce_left == 0:
					if dummy_on_ground:
						dummy_state = DummyState.NEUTRAL
						events.append(CombatEvent.dummy_recovered())
					else:
						dummy_state = DummyState.AIR_RECOVERED
					_end_combo(CombatEvent.ComboEndReason.DUMMY_RECOVERED, events)
		DummyState.KNOCKED_DOWN:
			## 普通倒地：独立倒地计时逐帧消耗（命中当帧不消耗，停顿帧不推进）；
			## 倒地期间不接受主动受身，计时结束自然恢复回中立并开启新连段的资格。
			if not _dummy_fresh_reaction:
				dummy_knockdown_left = maxi(dummy_knockdown_left - 1, 0)
				if dummy_knockdown_left == 0:
					dummy_state = DummyState.NEUTRAL
					events.append(CombatEvent.dummy_recovered())
		_:
			pass
	_dummy_fresh_reaction = false


## 面向更新（票据 06，M-04）：每个正常物理帧在计划位移提交与身体约束之后，
## 按玩家与木桩的真实横向关系朝向木桩；横向重合保持上一帧面向。换边命中
## 当帧已按锁定动作方向完成攻击与位移，面向翻转自下一物理帧的输入折算与
## 新招式起手生效；当前招式的 hitbox/位移/扫掠方向由 _move_direction 锁定，
## 不受本更新影响。已开始的方向候选经 _direction_ref_facing 保持首次相对
## 面向，不被翻转重解释。
func _update_facing_after_motion(events: Array[CombatEvent]) -> void:
	if is_equal_approx(dummy_position.x, player_position.x):
		return
	var facing := 1 if dummy_position.x > player_position.x else -1
	if facing != player_facing:
		player_facing = facing
		events.append(CombatEvent.switched_sides(facing))


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
	## 多段招式按段窗口推导阶段（票据 05）：段间隔算后续段的前摇，只有各段
	## active 窗口内是判定帧。
	## 动作内蓄力（票据 06，I-01..I-03）：可蓄力招式每次推进都先按本帧按住
	## 与否累计蓄力年龄（自启动起的正常帧计龄；停顿帧不进入本函数，松开的帧
	## 不积攒）；推进将首次进入 active 时仲裁——按住且未满阈值延长 startup
	##（帧钟停在 active_from-1），达阈值自动提交蓄力版、松开提交普通版，提交
	## 后帧钟回卷至提交版的 active_from，提交版完整走自己声明的 active/recovery。
	if _current_move == null:
		return
	if _current_move.is_chargeable() and not _charge_committed:
		var held := _frame_input.held_action_keys.has(_current_move.action_key)
		if held:
			_charge_age += 1
		if _move_frame >= _current_move.active_from() - 1:
			if held and _charge_age < _current_move.charge_threshold_frames:
				## 仍按住且未满阈值：帧钟停在 active_from-1，阶段保持 startup。
				return
			_commit_charge(held, events)
			return
	var was_active := player_phase == PlayerPhase.ACTIVE
	_move_frame += 1
	_current_segment = _current_move.segment_index_for_frame(_move_frame)
	match _current_move.segment_phase_code(_move_frame):
		0:
			player_phase = PlayerPhase.STARTUP
		1:
			player_phase = PlayerPhase.ACTIVE
		_:
			if _move_frame < _current_move.total_frames():
				player_phase = PlayerPhase.RECOVERY
				if was_active and not _hit_once_this_move and _move_via_link:
					## 普通连接起手的招式判定窗口结束仍无接触：按目标当下状态区分
					## 已恢复与距离不足的可读原因（连段按原规则到收招/恢复时结束）。
					events.append(CombatEvent.link_failed(
						CombatEvent.LinkFailReason.TARGET_RECOVERED if not _dummy_pursuable() \
							else CombatEvent.LinkFailReason.DISTANCE_INSUFFICIENT,
						_current_move.move_id))
			else:
				_finish_move(events)


## 蓄力分支提交（票据 06，I-02/I-03）：达阈值（held=true 且年龄满）提交蓄力版
## 资源，否则提交普通版。提交是同一次动作的换轨，不是新起手——来源标记
##（特殊进入/普通连接）、命中与取消状态保持；帧钟回卷至提交版的 active_from，
## 下一物理帧起按提交版 hitbox/伤害/位移/后摇结算。
func _commit_charge(charged: bool, events: Array[CombatEvent]) -> void:
	_charge_committed = true
	var from_id := _current_move.move_id
	if charged:
		var target := _moves.get(_current_move.charge_move_id) as MoveData
		if target != null:
			_current_move = target
			player_move_id = target.move_id
			_current_segment = 0
			_segment_hit_done.clear()
			for i in target.segment_count():
				_segment_hit_done.append(false)
		else:
			## 蓄力目标不在表内只可能来自未经校验的注入表——如实按普通版
			## 提交（charged=false），不谎报蓄力结果。
			charged = false
	_move_frame = _current_move.active_from()
	player_phase = PlayerPhase.ACTIVE
	events.append(CombatEvent.charge_committed(from_id, _current_move.move_id, _charge_age, charged))


func _finish_move(events: Array[CombatEvent]) -> void:
	## 自然收招：缓存持有可消费的声明普通连接候选时，连段不在运动阶段结束——
	## 消费阶段按合法接续起手（连段延续）或报告失败原因后结束；否则收招未接续
	## 结束连段。声明了普通连接边的招式不因取消窗口关闭提前结束连段（连接评估
	## 推迟到完全恢复后的首个合法帧）。
	_finished_move = _current_move
	## 收招当帧快照命中与来源标记：清招后普通连接消费阶段仍需区分来源限定边
	## （票据 05：5D → 5B 只对经特殊进入起手且实际命中的 D 开放）。
	_finished_move_hit = _move_hit_confirmed
	_finished_move_via_entry = _move_via_special_entry
	## 空技落地接缝（票据 08）：空中收招时地面连接姿态尚未成立——声明了普通
	## 连接边（或命中落地资格开放）的空招把连段存续与连接评估推迟到落地恢复
	## 完成后的首个合法帧（_resolve_air_link / _try_consume_hit_landing）。
	if _current_move.stance == MoveData.Stance.AIR and _air_move_defers_end(_current_move):
		_pending_air_link = not _current_move.link_targets.is_empty()
		_clear_current_move()
		return
	_pending_link_check = _link_candidate_available(_current_move)
	if _pending_link_check:
		_clear_current_move()
		return
	if _link_declared_but_gated(_current_move):
		## 声明了普通连接边但消费门不满足：按 I-06 缓存消费失败，记录原因并作废。
		events.append(CombatEvent.link_failed(_link_fail_reason(_moves.get(_buffered_move_id) as MoveData), _buffered_move_id))
		_clear_buffer()
	## 配置缺口诊断读取连段结束前的可追击状态，须先于结束结算。
	_report_undeclared_link_gap(_finished_move, events)
	_end_combo(CombatEvent.ComboEndReason.MOVE_RECOVERED, events)
	_clear_current_move()


## 普通连接候选是否可消费（收招当帧评估）：缓存目标在前招声明的 link_targets
## 内（或前招经特殊进入起手且实际命中时的 special_entry_link_targets 内，票据 05）、
## 未处于组合等待、连段仍活跃、目标仍可追击且玩家可独立起手。
func _link_candidate_available(finished: MoveData) -> bool:
	if finished == null:
		return false
	if _buffered_move_id == "" or _buffer_waiting:
		return false
	if not _link_edge_declared(finished):
		return false
	var target := _moves.get(_buffered_move_id) as MoveData
	if target == null or not _stance_matches(target):
		return false
	return combo_active and _dummy_pursuable() and _independent_start_allowed()


## 缓存是否持有前招声明的普通连接目标（无论消费门是否满足）。
func _link_declared_but_gated(finished: MoveData) -> bool:
	if finished == null:
		return false
	if _buffered_move_id == "" or _buffer_waiting:
		return false
	return _link_edge_declared(finished)


## 缓存目标是否落在前招声明的普通连接边上：无条件 link_targets，或前招经特殊
## 进入资格起手且实际命中时的来源限定 special_entry_link_targets（票据 05，I-05：
## 普通来源起手的同一招式不取得这些边，不构成全局反向取消）。
func _link_edge_declared(finished: MoveData) -> bool:
	if finished.link_targets.has(_buffered_move_id):
		return true
	return _finished_move_via_entry and _finished_move_hit \
		and finished.special_entry_link_targets.has(_buffered_move_id)


## 普通连接失败原因：目标已自然恢复（连段资格消失）为已恢复；不可追击的
## 受击状态、姿态不符或玩家侧起手锁为状态不兼容。
func _link_fail_reason(target: MoveData) -> CombatEvent.LinkFailReason:
	if dummy_state == DummyState.KNOCKED_DOWN or dummy_state == DummyState.AIR_RECOVERED:
		return CombatEvent.LinkFailReason.STATE_INCOMPATIBLE
	if target == null or not _stance_matches(target) or not _independent_start_allowed():
		return CombatEvent.LinkFailReason.STATE_INCOMPATIBLE
	return CombatEvent.LinkFailReason.TARGET_RECOVERED


## 配置缺口诊断：连段结束时缓存仍持有姿态匹配的地面打击、目标仍可追击，但
## 前招未声明到该招的普通连接边——报告后输入按独立招式继续（不作废缓存）。
## 来源限定边（special_entry_link_targets）不算已声明：普通来源起手的招式不
## 取得这些边，如实报配置缺口（票据 05：普通 5D → 5B 的可观察负例）。
func _report_undeclared_link_gap(source: MoveData, events: Array[CombatEvent]) -> void:
	if _buffered_move_id == "" or _buffer_waiting:
		return
	if not combo_active or not _dummy_pursuable():
		return
	var buffered := _moves.get(_buffered_move_id) as MoveData
	if buffered == null or buffered.stance != MoveData.Stance.GROUND:
		return
	if source != null and source.link_targets.has(_buffered_move_id):
		return
	events.append(CombatEvent.link_failed(CombatEvent.LinkFailReason.CONFIGURATION_GAP, _buffered_move_id))


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
	_current_segment = 0
	_segment_hit_done.clear()
	for i in move.segment_count():
		_segment_hit_done.append(false)
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_contact_confirmed = false
	_contact_frame = 0
	_move_blocked = false
	_move_is_followup = is_followup
	_move_via_link = false
	_move_via_air_link = false
	## 新招式起手即取代前招的空技落地接缝（票据 08）：延迟连接挂起与收招
	## 快照随接缝终结——资格（若有）由自身的消费/失效路径管理。
	_pending_air_link = false
	_finished_move = null
	## 特殊进入消费（票据 05，I-05）：资格开放中且本招是其声明目标时，本招经
	## 来源资格起手——消费资格（一次性），标记来源限定普通连接边可用。
	_move_via_special_entry = _special_entry_open and _special_entry_move != null \
		and _special_entry_move.special_entry_targets.has(move_id)
	if _move_via_special_entry:
		_close_special_entry()
	## 新招式接管：前招的 Rekka 派生窗口随招式结束（派生起手路径在调用前已
	## 自行关闭窗口，此处兜底其它起手来源）。
	_clear_rekka_window()
	## 动作轨迹方向与位移/蓄力跟踪（票据 06，M-01/M-04）：方向在启动时锁定并
	## 贯穿本招；蓄力年龄自本招起算；穿越许可与墙截断标记逐招清零。
	_reset_move_tracking()
	_move_direction = player_facing
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
	_current_segment = 0
	_segment_hit_done.clear()
	_move_hit_confirmed = false
	_hit_confirm_frame = 0
	_move_contact_confirmed = false
	_contact_frame = 0
	_move_blocked = false
	_move_is_followup = false
	_move_via_link = false
	_move_via_air_link = false
	_move_via_special_entry = false
	## 招式被打断或自然结束：派生窗口与特殊进入资格只属于该招，随之关闭
	## （未消费的资格不能跨招式补发）。
	_clear_rekka_window()
	_close_special_entry()
	## 轨迹方向、蓄力与位移跟踪随本招结束；穿越许可不传给下一招（M-02）。
	_reset_move_tracking()
	player_move_id = ""
	player_phase = PlayerPhase.NEUTRAL


## 蓄力/位移/穿越的逐招跟踪统一清零（启动、清招与重置共用同一口径）。
func _reset_move_tracking() -> void:
	_move_direction = 0
	_charge_age = 0
	_charge_committed = false
	_cross_ok = false
	_motion_wall_clamped = false
	_motion_frames_done = 0
	_motion_anchor_x = 0.0
	_motion_anchor_y = 0.0
	_planned_step = Vector2.ZERO


func _close_special_entry() -> void:
	_special_entry_open = false
	_special_entry_frame = 0
	_special_entry_move = null


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
		## Rekka 派生与蓄力版只经各自仲裁起手（票据 04/06）：不参与单键/指令
		## 输入选择。
		if move.rekka_only or move.charge_only:
			continue
		## 蹲姿限定按当帧输入状态判定（下方向 ∈ {1,2,3}，斜下含）：持续按住下
		## 连续按键不依赖方向历史重新建段——与蹲姿的可观察输入一致。
		if move.requires_crouch and not _down_held():
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
		if move.rekka_only or move.charge_only:
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
	## 木桩中立时可被任何招式命中；受击中只有连段内的合法接续招式可以继续命中
	## （多段招式段 1 实际命中后，后续段是本招自身的连段延续，票据 05 S-02）；
	## 空中已受身与普通倒地不可追击（倒地期间任何打击都不命中、不刷新计时），
	## 恢复中立后才能开启新一段连段。
	if dummy_state == DummyState.NEUTRAL:
		return true
	if not _dummy_pursuable():
		return false
	return combo_active and (_move_is_followup or _move_hit_confirmed)


func _dummy_pursuable() -> bool:
	## 可追击的受击状态：地面硬直、浮空硬直、低浮空、击飞触地滑行前滞空或
	## 地面滑行（连段仍活跃时合法接续可继续命中；低浮空的追击窗口由触地转换
	## 关闭，滑行的追击窗口由滑行计时关闭——S-05）。弹地（票据 09，B-02）只在
	## 首次触地（bounce_contact）后才可追击——触地前沿资料运动、不开完整地面追击。
	## 普通倒地与空中已受身不在可追击域内；滑行/弹地目标能否被某招命中另由该招
	## 的对应目标状态资料门决定。
	if dummy_state == DummyState.GROUND_BOUNCE:
		return dummy_bounce_contacted
	return dummy_state == DummyState.GROUND_HITSTUN or dummy_state == DummyState.AIR_HITSTUN \
		or dummy_state == DummyState.LOW_FLOAT_SWEEP or dummy_state == DummyState.LOW_FLOAT_TO_SLIDE \
		or dummy_state == DummyState.GROUND_SLIDE


func _stance_matches(move: MoveData) -> bool:
	## 招式姿态要求与玩家当前姿态一致（地面招式须在地面，空中招式须在空中）。
	return (move.stance == MoveData.Stance.AIR) == (not player_on_ground)


func _end_combo(reason: CombatEvent.ComboEndReason, events: Array[CombatEvent]) -> void:
	if not combo_active:
		return
	combo_active = false
	## 连段结束清除起手等级与三层累计修正（自然恢复/普通倒地/收尾同口径）；
	## 下一段连段首击重新锁定。特殊进入资格绑定本次连段，随之清除（I-05.3）；
	## 命中落地资格与空技延迟连接同样绑定本次连段（票据 08，L-01）。
	combo_starter_grade = MoveData.StarterGrade.UNSET
	combo_damage_scale = 1.0
	combo_time_scale = 1.0
	combo_trajectory_scale = 1.0
	_close_special_entry()
	_close_hit_landing()
	_pending_air_link = false
	_finished_move = null
	events.append(CombatEvent.combo_ended(reason))


func _dummy_body_rect() -> Rect2:
	return Rect2(dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE)
