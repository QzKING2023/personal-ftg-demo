extends SceneTree
## 票据 01 验收回放：普通地面链 5A > 5B > 5C > 5D 与 5B > 5D。
## 记录真实起始间距（60 px 身体中心水平距离）、左右面向、逐帧输入、
## 命中/受击/连段/修正事件与双方位置——供 acceptance/01/ 证据归档。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_01.gd

const START_DX := 60.0


func _initialize() -> void:
	var routes := [
		{"name": "5A>5B>5C>5D", "keys": {1: "A", 5: "B", 21: "C", 36: "D"}},
		{"name": "5B>5D", "keys": {1: "B", 10: "D"}},
	]
	for route in routes:
		_replay(String(route["name"]), route["keys"], 1)
		_replay(String(route["name"]), route["keys"], -1)
	quit(0)


func _replay(route_name: String, keys: Dictionary, facing: int) -> void:
	print("=== 路线 %s | 面向 %d | 起始间距 %.0f px（身体中心水平） ===" % [route_name, facing, START_DX])
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(START_DX, 0)
	else:
		session.dummy_position = session.player_position - Vector2(START_DX, 0)
		session.player_facing = -1
	var frames := 80
	for frame in range(1, frames + 1):
		var input := FrameInput.new()
		if keys.has(frame):
			input.action_key = String(keys[frame])
		var events := session.step(input)
		for event in events:
			match event.type:
				CombatEvent.Type.HIT:
					print("F%-3d HIT    第%d击 伤害%.1f | 修正 伤%.4f/时%.4f/轨%.4f | starter %s" % [
						frame, event.combo_hits, event.damage, session.combo_damage_scale,
						session.combo_time_scale, session.combo_trajectory_scale,
						_starter_label(session.combo_starter_grade)])
				CombatEvent.Type.COMBO_ENDED:
					print("F%-3d COMBO_ENDED 原因%s" % [frame, CombatEvent.ComboEndReason.keys()[event.combo_end_reason]])
				CombatEvent.Type.DUMMY_RECOVERED:
					print("F%-3d DUMMY_RECOVERED" % frame)
				CombatEvent.Type.LINK_FAILED:
					print("F%-3d LINK_FAILED %s：%s" % [frame, event.link_move_id,
						CombatEvent.LinkFailReason.keys()[event.link_fail_reason]])
		if keys.has(frame) or _count_hits(events) > 0:
			print("F%-3d 输入[%s] 玩家(%.1f,%.1f) 面向%d 招式%s | 木桩(%.1f,%.1f) 状态%s 剩余硬直%d" % [
				frame, String(keys.get(frame, "")), session.player_position.x, session.player_position.y,
				session.player_facing, session.player_move_id, session.dummy_position.x, session.dummy_position.y,
				CombatSession.DummyState.keys()[session.dummy_state], session.dummy_hitstun_left])
	print("结果：连段 %d hit · 总伤害 %.1f · HP %.1f" % [
		session.combo_hits, session.combo_total_damage, session.dummy_hp])
	print("")


func _count_hits(events: Array[CombatEvent]) -> int:
	var total := 0
	for event in events:
		if event.type == CombatEvent.Type.HIT:
			total += 1
	return total


func _starter_label(grade: MoveData.StarterGrade) -> String:
	match grade:
		MoveData.StarterGrade.A:
			return "A"
		MoveData.StarterGrade.B:
			return "B"
		MoveData.StarterGrade.C:
			return "C"
		MoveData.StarterGrade.D:
			return "D"
	return "未锁定"
