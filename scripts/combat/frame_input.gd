class_name FrameInput
extends RefCounted
## 单个物理帧的玩家输入快照。
## 训练场从 Input 适配生成；测试直接构造后喂给 CombatSession.step。

## 水平方向：-1 左 / 1 右 / 0 无。键盘语义，取整数。
var move_axis := 0
## 本帧是否按住下方方向（S/↓）。方向输入只进方向历史，不进入动作键缓存。
var down_held := false
## 上方向持有（Space/↑），与下方向中和；按下边沿仍由 jump_pressed 独立承载。
var up_held := false
## 本帧是否刚按下跳跃（Space 独立输入，不进入动作键缓存）。
var jump_pressed := false
## 本帧新按下的动作键集合（可能同帧多键，如 B+C 组合；顺序无关）。
## 显式组合的配对容差与“配齐帧仍全部按住”都以本集合与 held 集合为准，
## 不以单键选择结果为准。
var pressed_action_keys: Array[String] = []
## 本帧按住的动作键集合（含本帧新按下）。原始按下/按住/松开记录的可观察来源。
var held_action_keys: Array[String] = []
## 木桩拆投请求：玩家普通投的拆投窗口内为真时拆投成立（测试/验证驱动；
## 训练场不设置——木桩无自主决策，与 dummy_move_request 同一口径）。
var dummy_tech_request := false
## 木桩确定性攻击请求（招式表内打击招式 id）：测试与验证驱动属性矩阵/防御
## 观察用；训练场不设置（木桩无自主决策）。会话在木桩空闲时按请求起手。
var dummy_move_request := ""


## 同帧单键选择（无显式组合完成时按 D>C>B>A）：读取方沿用的兼容口径，
## 与旧版单键字段语义一致；赋值等价于“本帧只按下并按住该键”。
## 表内四键之外的动作键（注入测试表的 E/F/G 等）原样透传，保持单一按下语义。
var action_key: String:
	get:
		for key in ["D", "C", "B", "A"]:
			if pressed_action_keys.has(key):
				return key
		for key in pressed_action_keys:
			return key
		return ""
	set(value):
		pressed_action_keys.clear()
		held_action_keys.clear()
		if value != "":
			pressed_action_keys.append(value)
			held_action_keys.append(value)


static func make(move_axis: int = 0, jump_pressed: bool = false, action_key: String = "", down_held: bool = false, dummy_move_request: String = "") -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = move_axis
	input.jump_pressed = jump_pressed
	input.up_held = jump_pressed
	input.action_key = action_key
	input.down_held = down_held
	input.dummy_move_request = dummy_move_request
	return input
