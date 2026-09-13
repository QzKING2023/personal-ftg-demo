class_name FrameInput
extends RefCounted
## 单个物理帧的玩家输入快照。
## 训练场从 Input 适配生成；测试直接构造后喂给 CombatSession.step。

## 水平方向：-1 左 / 1 右 / 0 无。键盘语义，取整数。
var move_axis := 0
## 本帧是否刚按下跳跃（Space 独立输入，不进入动作键缓存）。
var jump_pressed := false
## 本帧刚按下的动作键："A"/"B"/"C"/"D" 之一，空串表示无。
## 动作键进入单槽缓存，由会话在消费阶段统一处理。
var action_key := ""


static func make(move_axis: int = 0, jump_pressed: bool = false, action_key: String = "") -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = move_axis
	input.jump_pressed = jump_pressed
	input.action_key = action_key
	return input
