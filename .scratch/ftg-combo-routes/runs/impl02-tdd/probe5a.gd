extends SceneTree
func _initialize() -> void:
	var table := MoveData.default_table()
	# 复刻 test 的注入表（借 hit_profiles 的构造方式过于复杂，直接最小注入）
	var launcher: MoveData = MoveData.new()
	launcher.move_id = "PL"
	launcher.move_kind = MoveData.MoveKind.STRIKE
	launcher.stance = MoveData.Stance.GROUND
	launcher.action_key = "L"
	launcher.startup_frames = 3
	launcher.active_frames = 3
	launcher.recovery_frames = 10
	launcher.base_damage = 10
	launcher.attack_attribute = 1
	launcher.hitbox_size = Vector2(40, 30)
	launcher.hitbox_gap = 2.0
	var p := HitProfile.new()
	p.target_state = HitProfile.TargetState.GROUNDED
	p.hit_context = HitProfile.HitContext.NORMAL
	p.reaction = HitProfile.Reaction.LAUNCH
	p.air_untech_frames = 40
	p.horizontal_speed_px_s = 0.0
	p.upward_speed_px_s = 300.0
	launcher.hit_profiles = [p]
	launcher.cancel_targets = ["5A"]
	launcher.priority = 1
	table["PL"] = launcher
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(26, 0)
	for frame in range(1, 34):
		var input := FrameInput.new()
		if frame == 1:
			input.pressed_action_keys = ["L"]
			input.held_action_keys = ["L"]
		elif frame == 13:
			input.pressed_action_keys = ["A"]
			input.held_action_keys = ["A"]
		var m := session.player_move_id
		for e in session.step(input):
			print("F%-2d %-8s -> %s" % [frame, m, CombatEvent.Type.keys()[e.type]])
		if frame >= 12 and frame <= 24:
			print("   F%-2d end: move=%s phase=%s buf=%s lr=%d ong=%s" % [frame, session.player_move_id, session.player_phase, session.get("_buffered_move_id"), session.player_landing_recovery_left, session.player_on_ground])
	quit(0)
