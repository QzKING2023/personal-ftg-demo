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
