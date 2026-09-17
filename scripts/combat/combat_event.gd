class_name CombatEvent
extends RefCounted
## 单个物理帧结算中产生的战斗事件，供训练场反馈与测试断言使用。
## 事件只描述已经发生的结算结果，不携带后续行为指令。

enum Type {
	HIT,               ## 招式命中木桩
	BLOCKED,           ## 玩家以防御姿态挡下一次木桩打击（方向见 direction）
	PLAYER_HIT,        ## 玩家被木桩打击命中（未防御或姿态漏防；方向见 direction）
	HITSTOP_STARTED,   ## 命中帧结算完毕，后续 HITSTOP_FRAMES 个物理帧冻结（Hitstop 开始边界）
	HITSTOP_ENDED,     ## 冻结结束，本帧起恢复正常结算（Hitstop 结束边界 = 恢复首个正常帧）
	COMBO_ENDED,       ## 当前连段结束（原因见 ComboEndReason）
	DUMMY_RECOVERED,   ## 木桩受击硬直归零，自然受身回到中立
	THROW_HIT,         ## 普通投结果成立（未被拆投；投向见 direction）
	THROW_TECHED,      ## 拆投成立：投结果被阻止
	THROW_FAILED,      ## 已配齐的普通投尝试被拒绝（原因见 ThrowFailReason）
	DASH_STARTED,      ## 66 前冲 / 44 后撤启动（世界方向见 direction；issue 18）
}

## 连段结束原因：收尾、取消窗口关闭、招式收招未接续、木桩自然受身/恢复。
enum ComboEndReason {
	FINISHER,
	CANCEL_WINDOW_CLOSED,
	MOVE_RECOVERED,
	DUMMY_RECOVERED,
}

## 普通投尝试被拒绝的原因：状态禁用（蹲下/pre-jump/空中/招式阶段/受击硬直/
## 落地恢复）或投距外（水平距离超限或身体矩形垂直不重叠）。
enum ThrowFailReason {
	STATE = 1,
	RANGE = 2,
}

var type: Type = Type.HIT
## 命中方向（攻击方朝向，1 向右 / -1 向左），仅 HIT 使用。
var direction := 1
## 实际造成的伤害（已按连段命中数递减），仅 HIT 使用。
var damage := 0.0
## 本次命中是当前连段的第几击（从 1 开始），仅 HIT 使用。
var combo_hits := 0
## 连段结束原因，仅 COMBO_ENDED 使用。
var combo_end_reason: ComboEndReason = ComboEndReason.FINISHER
## 普通投失败原因，仅 THROW_FAILED 使用。
var throw_fail_reason: ThrowFailReason = ThrowFailReason.STATE


static func hit(damage: float, direction: int, combo_hits: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HIT
	event.damage = damage
	event.direction = direction
	event.combo_hits = combo_hits
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
