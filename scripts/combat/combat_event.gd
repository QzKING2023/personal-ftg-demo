class_name CombatEvent
extends RefCounted
## 单个物理帧结算中产生的战斗事件，供训练场反馈与测试断言使用。
## 事件只描述已经发生的结算结果，不携带后续行为指令。

enum Type {
	HIT,               ## 招式命中木桩
	COMBO_ENDED,       ## 当前连段结束（原因见 ComboEndReason）
	DUMMY_RECOVERED,   ## 木桩受击硬直归零，自然受身回到中立
}

## 连段结束原因：收尾、取消窗口关闭、招式收招未接续、木桩自然受身/恢复。
enum ComboEndReason {
	FINISHER,
	CANCEL_WINDOW_CLOSED,
	MOVE_RECOVERED,
	DUMMY_RECOVERED,
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


static func hit(damage: float, direction: int, combo_hits: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HIT
	event.damage = damage
	event.direction = direction
	event.combo_hits = combo_hits
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
