class_name NativeShapes
## 用 Godot 原生 Polygon2D 绘制矩形与角色，不依赖任何外部美术资源。
## 玩家与木桩共用 make_character 的同一套形状结构，只通过颜色区分。

static func make_rect(size: Vector2, color: Color, offset := Vector2.ZERO) -> Polygon2D:
	var polygon := Polygon2D.new()
	var half := size * 0.5
	polygon.polygon = PackedVector2Array([
		offset + Vector2(-half.x, -half.y),
		offset + Vector2(half.x, -half.y),
		offset + Vector2(half.x, half.y),
		offset + Vector2(-half.x, half.y),
	])
	polygon.color = color
	return polygon


## 角色头部中心的 y 偏移（头顶以上的元素按它推算）。
static func head_center_offset() -> float:
	return -(GameParams.BODY_SIZE.y * 0.5 + GameParams.HEAD_GAP + GameParams.HEAD_SIZE.y * 0.5)


## 身体 + 头 + 朝向眼罩；返回的 Node2D 可用 scale.x 翻转朝向。
static func make_character(main_color: Color) -> Node2D:
	var root := Node2D.new()
	root.add_child(make_rect(GameParams.BODY_SIZE, main_color))
	var head_y := head_center_offset()
	root.add_child(make_rect(GameParams.HEAD_SIZE, main_color.darkened(0.25), Vector2(0, head_y)))
	root.add_child(make_rect(GameParams.VISOR_SIZE, GameParams.VISOR_COLOR, Vector2(GameParams.VISOR_OFFSET_X, head_y)))
	return root


## 武器语义（票据 10，设计基线 §1 家族表与 §5）：A/B 系普通技徒手，C 系与
## D 系出刀，6A 是 A 键上的出刀型专用 launcher；214C 的 Rekka 派生（~B/~C）
## 是 C 系必杀的分支——~B 虽按 B 键仍按出刀呈现；投（无动作键）按徒手呈现。
## 纯呈现规则，不参与任何结算。
static func is_knife_move(move_id: String, action_key: String) -> bool:
	return action_key == "C" or action_key == "D" or move_id == "6A" or move_id.begins_with("214C")


## 短刀：细长刀身 + 柄，原点在握把处、刀尖朝 +x——由调用方旋转/翻转。
static func make_knife() -> Node2D:
	var root := Node2D.new()
	root.name = "Knife"
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(6, -3), Vector2(26, -1), Vector2(30, 0), Vector2(26, 1), Vector2(6, 3),
	])
	blade.color = GameParams.KNIFE_COLOR
	root.add_child(blade)
	root.add_child(make_rect(Vector2(8, 6), GameParams.VISOR_COLOR, Vector2(2, 0)))
	return root


## 徒手拳形：出招时以小方块标记打击手的位置。
static func make_fist() -> Polygon2D:
	var fist := make_rect(Vector2(10, 10), GameParams.FIST_COLOR)
	fist.name = "Fist"
	return fist


## 收刀锚点：持刀侧前臂的固定结构（暗红小条），收刀卡点期间改亮色。
static func make_sheath_anchor() -> Polygon2D:
	var anchor := make_rect(Vector2(6, 14), GameParams.KNIFE_SHEATH_COLOR, Vector2.ZERO)
	anchor.name = "SheathAnchor"
	return anchor
