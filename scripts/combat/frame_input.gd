class_name FrameInput
extends RefCounted
## 单个物理帧的玩家输入快照。
## 训练场从 Input 适配生成；测试直接构造后喂给 CombatSession.step。

## 水平方向：-1 左 / 1 右 / 0 无。键盘语义，取整数。
var move_axis := 0
## 本帧是否刚按下跳跃（Space 独立输入，不进入动作键缓存）。
var jump_pressed := false
## 本帧是否刚按下攻击（首版只有一个基础招式键）。
var attack_pressed := false


static func make(move_axis: int = 0, jump_pressed: bool = false, attack_pressed: bool = false) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = move_axis
	input.jump_pressed = jump_pressed
	input.attack_pressed = attack_pressed
	return input
