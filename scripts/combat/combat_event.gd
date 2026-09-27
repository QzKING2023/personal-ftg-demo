class_name CombatEvent
extends RefCounted
## 单个物理帧结算中产生的战斗事件，供训练场反馈与测试断言使用。
## 事件只描述已经发生的结算结果，不携带后续行为指令。

enum Type {
	HIT,               ## 招式命中木桩
	HIT_MISS,          ## 命中框已连接但 (target_state, hit_context) 无匹配 HitProfile：不造成伤害、不改变受击状态、不取得命中确认
	BLOCKED,           ## 玩家以防御姿态挡下一次木桩打击（方向见 direction）
	ATTACK_BLOCKED,    ## 玩家攻击被木桩防御挡下（方向见 direction；木桩姿态见 guard_posture，取值同 CombatSession.GuardPosture；票据 03）
	DUMMY_GUARD_REJECTED, ## 木桩防御请求不成立（原因见 DummyGuardRejectReason；不回退为其他防御）
	PLAYER_HIT,        ## 玩家被木桩打击命中（未防御或姿态漏防；方向见 direction）
	HITSTOP_STARTED,   ## 命中帧结算完毕，后续 HITSTOP_FRAMES 个物理帧冻结（Hitstop 开始边界）
	HITSTOP_ENDED,     ## 冻结结束，本帧起恢复正常结算（Hitstop 结束边界 = 恢复首个正常帧）
	COMBO_ENDED,       ## 当前连段结束（原因见 ComboEndReason）
	DUMMY_RECOVERED,   ## 木桩受击硬直归零，自然受身回到中立
	THROW_HIT,         ## 普通投结果成立（未被拆投；投向见 direction）
	THROW_TECHED,      ## 拆投成立：投结果被阻止
	THROW_FAILED,      ## 已配齐的普通投尝试被拒绝（原因见 ThrowFailReason）
	DASH_STARTED,      ## 66 前冲 / 44 后撤启动（世界方向见 direction；issue 18）
	LINK_FAILED,       ## 普通连接（目押）尝试失败或已消费的连接招挥空（原因见 LinkFailReason）
	LOW_FLOAT_LANDED,  ## 低浮空扫倒触地：同帧转普通倒地并结束连段（票据 02）
	REKKA_BRANCH_LOCKED, ## Rekka 派生窗口内第一个 B/C 新按下锁定分支（见 rekka_branch/rekka_move_id；票据 04）
	SPIKE_LANDED,      ## 向下击落触地：同帧转普通倒地（票据 04）
	SLIDE_STARTED,     ## 击飞触地转地面滑行：进入 GROUND_SLIDE 可追击窗口（票据 05；计时自下一正常帧倒数）
	CHARGE_COMMITTED,  ## 动作内蓄力分支提交：active 边界处按住年龄/松键判定为普通版或蓄力版（见 charge_* 字段；票据 06）
	SWITCHED_SIDES,    ## 换边：面向按玩家与木桩真实横向关系翻转（新面向见 direction；票据 06，下一物理帧起生效）
}

## 连段结束原因：收尾、取消窗口关闭、招式收招未接续、木桩自然受身/恢复、
## 普通倒地反应（进入倒地即结束当前连段）。
enum ComboEndReason {
	FINISHER,
	CANCEL_WINDOW_CLOSED,
	MOVE_RECOVERED,
	DUMMY_RECOVERED,
	KNOCKDOWN,
}

## 普通投尝试被拒绝的原因：状态禁用（蹲下/pre-jump/空中/招式阶段/受击硬直/
## 落地恢复）或投距外（水平距离超限或身体矩形垂直不重叠）。
enum ThrowFailReason {
	STATE = 1,
	RANGE = 2,
}

## 普通连接失败原因（I-06）：消费时目标已不可追击、目标状态不接受该招、
## 前招未声明该普通连接边，或已消费的连接招判定窗口结束仍无接触（距离不足）。
enum LinkFailReason {
	TARGET_RECOVERED = 1,    ## 目标已自然受身/恢复，连段资格已消失
	STATE_INCOMPATIBLE = 2,  ## 目标处于不接受该招的状态（普通倒地/空中已受身等）
	DISTANCE_INSUFFICIENT = 3, ## 连接招已起手但判定窗口结束仍无真实接触
	CONFIGURATION_GAP = 4,   ## 前招未声明到该招的普通连接边（输入按独立招式处理）
}

## 木桩防御请求不成立的原因（D-01）：姿态与地面/空中状态不符（不静默回退），
## 或木桩被受击/倒地/自身招式占用（本帧无法进入任何防御）。
enum DummyGuardRejectReason {
	STATE = 1,
	BUSY = 2,
}

var type: Type = Type.HIT
## 命中方向（攻击方朝向，1 向右 / -1 向左），仅 HIT/HIT_MISS 使用。
var direction := 1
## 实际造成的伤害（已按连段命中数递减），仅 HIT 使用。
var damage := 0.0
## 本次命中是当前连段的第几击（从 1 开始），仅 HIT 使用。
var combo_hits := 0
## 本次命中选择的命中上下文是否为 Counter Hit（事件/回放区分所选 profile），仅 HIT 使用。
var is_counter := false
## 连段结束原因，仅 COMBO_ENDED 使用。
var combo_end_reason: ComboEndReason = ComboEndReason.FINISHER
## 普通投失败原因，仅 THROW_FAILED 使用。
var throw_fail_reason: ThrowFailReason = ThrowFailReason.STATE
## 普通连接失败原因，仅 LINK_FAILED 使用。
var link_fail_reason: LinkFailReason = LinkFailReason.TARGET_RECOVERED
## 普通连接尝试涉及的招式 id（前招完全恢复后的目标普通技），仅 LINK_FAILED 使用。
var link_move_id := ""
## 被挡下的防御姿态（取值同 CombatSession.GuardPosture：1 站 / 2 蹲 / 3 空），
## 仅 ATTACK_BLOCKED 使用。
var guard_posture := 0
## 被防结果三值（票据 03，事件自带完整被防记录）：停顿（冻结物理帧）、
## 硬直（防守方停顿后不可行动正常帧）、推退（停顿后施加双方的水平速度 px/s）。
var block_freeze_frames := -1
var block_stun_frames := -1
var block_pushback_px_s := -1.0
## 木桩防御请求不成立的原因，仅 DUMMY_GUARD_REJECTED 使用。
var guard_reject_reason: DummyGuardRejectReason = DummyGuardRejectReason.STATE
## 锁定的 Rekka 分支键（"B"/"C"）与派生招式 id，仅 REKKA_BRANCH_LOCKED 使用。
var rekka_branch := ""
var rekka_move_id := ""
## 本次接触来自多段招式的第几段（1 基；单段招式恒为 1），仅 HIT/HIT_MISS/
## ATTACK_BLOCKED 使用（票据 05：两段判定的可观察段标识）。
var move_segment := 1
## 蓄力提交（票据 06）：提交前招式 id、提交后招式 id、按住正常帧年龄与是否
## 蓄力版，仅 CHARGE_COMMITTED 使用。
var charge_from_move_id := ""
var charge_to_move_id := ""
var charge_age := 0
var charged := false


static func hit(damage: float, direction: int, combo_hits: int, is_counter := false, move_segment := 1) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HIT
	event.damage = damage
	event.direction = direction
	event.combo_hits = combo_hits
	event.is_counter = is_counter
	event.move_segment = move_segment
	return event


## 命中框已连接但目标状态 × 命中上下文无匹配 profile（MISS_NO_PROFILE）：
## 不造成伤害、不改变受击状态、不取得任何命中确认或取消资格。
static func hit_miss(direction: int, move_segment := 1) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HIT_MISS
	event.direction = direction
	event.move_segment = move_segment
	return event


static func hitstop_started() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HITSTOP_STARTED
	return event


static func blocked(direction: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.BLOCKED
	event.direction = direction
	return event


static func attack_blocked(direction: int, guard_posture: int, freeze: int, stun: int, pushback: float, move_segment := 1) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.ATTACK_BLOCKED
	event.direction = direction
	event.guard_posture = guard_posture
	event.block_freeze_frames = freeze
	event.block_stun_frames = stun
	event.block_pushback_px_s = pushback
	event.move_segment = move_segment
	return event


static func dummy_guard_rejected(reason: DummyGuardRejectReason) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.DUMMY_GUARD_REJECTED
	event.guard_reject_reason = reason
	return event


static func player_hit(direction: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.PLAYER_HIT
	event.direction = direction
	return event


static func hitstop_ended() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HITSTOP_ENDED
	return event


static func combo_ended(reason: ComboEndReason) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.COMBO_ENDED
	event.combo_end_reason = reason
	return event


static func dummy_recovered() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.DUMMY_RECOVERED
	return event


static func throw_hit(direction: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.THROW_HIT
	event.direction = direction
	return event


static func throw_teched() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.THROW_TECHED
	return event


static func throw_failed(reason: ThrowFailReason) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.THROW_FAILED
	event.throw_fail_reason = reason
	return event


static func dash_started(direction: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.DASH_STARTED
	event.direction = direction
	return event


static func link_failed(reason: LinkFailReason, move_id: String) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.LINK_FAILED
	event.link_fail_reason = reason
	event.link_move_id = move_id
	return event


static func low_float_landed() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.LOW_FLOAT_LANDED
	return event


static func rekka_branch_locked(branch: String, move_id: String) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.REKKA_BRANCH_LOCKED
	event.rekka_branch = branch
	event.rekka_move_id = move_id
	return event


static func spike_landed() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.SPIKE_LANDED
	return event


static func slide_started() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.SLIDE_STARTED
	return event


## 动作内蓄力提交（票据 06）：age 为提交时按住的正常帧年龄；charged=false 表示
## 松键/未满阈值的普通版提交（含延迟后摇的普通提交）。
static func charge_committed(from_move_id: String, to_move_id: String, age: int, charged: bool) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.CHARGE_COMMITTED
	event.charge_from_move_id = from_move_id
	event.charge_to_move_id = to_move_id
	event.charge_age = age
	event.charged = charged
	return event


## 换边（票据 06，M-04）：本帧运动与碰撞结算后面向按真实横向关系翻转；
## 当帧攻击已按锁定动作方向完成，新面向自下一物理帧的输入折算生效。
static func switched_sides(direction: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.SWITCHED_SIDES
	event.direction = direction
	return event
