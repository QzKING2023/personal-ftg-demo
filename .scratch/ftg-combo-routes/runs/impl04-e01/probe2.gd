extends SceneTree
func _initialize() -> void:
	var s := CombatSession.new()
	s.dummy_position = s.player_position + Vector2(14.0, 0)
	for frame in range(1, 40):
		var input := FrameInput.new()
		if frame == 1:
			input.down_held = true
			input.pressed_action_keys = ["C"]
			input.held_action_keys = ["C"]
		for event in s.step(input):
			if event.type == CombatEvent.Type.COMBO_ENDED:
				print("F%d END reason=%d" % [frame, event.combo_end_reason])
	quit(0)
