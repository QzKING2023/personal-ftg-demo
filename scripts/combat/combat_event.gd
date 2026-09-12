class_name CombatEvent
extends RefCounted
## 单个物理帧结算中产生的战斗事件，供训练场反馈与测试断言使用。
## 事件只描述已经发生的结算结果，不携带后续行为指令。

enum Type {
	HIT,               ## 招式命中木桩
	DUMMY_RECOVERED,   ## 木桩受击硬直归零，自然受身回到中立
}

var type: Type = Type.HIT
## 命中方向（攻击方朝向，1 向右 / -1 向左），仅 HIT 使用。
var direction := 1
## 实际造成的伤害，仅 HIT 使用。
var damage := 0


static func hit(damage: int, direction: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.HIT
	event.damage = damage
	event.direction = direction
	return event


static func dummy_recovered() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = Type.DUMMY_RECOVERED
	return event
