extends "res://tests/acceptance_replay_10.gd"
## Fixed physical-frame plans only. State is read for evidence, never for inputs.
const PLAN_PATH := "res://.scratch/ftg-combo-routes/inputs.json"
var _trace_dir := "res://.scratch/ftg-combo-routes/logs"
var _trace_moves: Dictionary = MoveTable.load_default().moves

func _initialize() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	var args := OS.get_cmdline_user_args()
	var selected := args[0] if not args.is_empty() else "all"
	if args.size() > 1:
		_trace_dir = args[1]
	var count := 0
	for entry in cases:
		if selected != "all" and selected != entry.id:
			continue
		for facing in [1, -1]:
			_diagnose(entry, facing)
			count += 1
	_check(count > 0, "selected at least one fixed input plan")
	print("TARGET FAILURES=%d (known failures remain failures)" % _failures)
	quit(0 if _failures == 0 else 1)

func _fixed_input(entry: Dictionary, frame: int, facing: int) -> FrameInput:
	var input := FrameInput.new()
	for row in entry.inputs:
		if frame < int(row[0]) or frame > int(row[1]):
			continue
		input.move_axis = int(row[2]) * facing
		input.down_held = bool(row[3])
		input.up_held = bool(row[4])
		input.jump_pressed = bool(row[4]) and frame == int(row[0])
		if row[5] != "":
			input.held_action_keys.append(str(row[5]))
			if frame == int(row[0]):
				input.pressed_action_keys.append(str(row[5]))
	return input

func _observe(session: CombatSession) -> Dictionary:
	var state := session.clone_state()
	var debug := session.debug_snapshot()
	var snap := {}
	for key in ["frame", "facing", "on_ground", "phase", "move_id", "hitstop_left",
		"landing_recovery_left", "buffered_move_id", "buffer_age", "buffer_consumed_frame",
		"pending_combination", "direction_sequence", "direction_locks", "cancel_targets",
		"cancel_age", "cancel_open", "starter_grade", "time_scale", "trajectory_scale",
		"bounce_followup", "dummy_bounce_left", "dummy_bounce_contacted", "special_entry_open",
		"move_via_special_entry", "dummy_slide_left", "charge_age", "move_direction",
		"cross_ok", "motion_wall_clamped", "dummy_air_height_px", "air_link_pending"]:
		snap[key] = debug[key]
	snap["normal_frame"] = state.clock.normal_frame
	snap["player_position"] = [session.player_position.x, session.player_position.y]
	snap["dummy_position"] = [session.dummy_position.x, session.dummy_position.y]
	snap["dummy_velocity"] = [session.dummy_velocity.x, session.dummy_velocity.y]
	snap["dummy_state"] = CombatSession.DummyState.keys()[session.dummy_state]
	snap["dummy_hitstun_left"] = session.dummy_hitstun_left
	snap["combo_active"] = session.combo_active
	snap["combo_hits"] = session.combo_hits
	snap["move_frame"] = state.player_move.frame
	snap["finished_move_id"] = state.player_move.finished_move_id
	snap["pending_link_check"] = state.player_move.pending_link_check
	snap["finished_move_via_entry"] = state.player_move.finished_move_via_entry
	snap["dummy_on_ground"] = session.dummy_on_ground
	snap["motion_frames_done"] = state.player_move.motion_frames_done
	snap["motion_anchor"] = state.player_move.motion_anchor
	var move: MoveData = _trace_moves.get(session.player_move_id)
	if move != null:
		snap["move_frames_remaining_if_uninterrupted"] = move.total_frames() - int(state.player_move.frame)
	return snap

func _diagnose(entry: Dictionary, facing: int) -> void:
	var session := _spawn(float(entry.dx), facing)
	if entry.get("corner", false):
		var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
		session.player_position.x = wall - float(entry.dx) * facing
		session.dummy_position.x = wall
	var trace := FileAccess.open("%s/%s-%s.jsonl" % [_trace_dir, entry.id, "right" if facing == 1 else "left"], FileAccess.WRITE)
	if trace == null:
		_check(false, "cannot open trace output: " + _trace_dir)
		return
	trace.store_line(JSON.stringify({"case": entry, "facing": facing, "initial": _observe(session)}))
	var evidence := preload("res://tests/replay_combo_evidence.gd").new()
	var action := 0
	var actions: Array[Dictionary] = []
	var swaps := 0
	var previous_held: Array[String] = []
	print("=== %s facing=%d dx=%s ===" % [entry.id, facing, entry.dx])
	for frame in range(1, int(entry.horizon) + 1):
		var input := _fixed_input(entry, frame, facing)
		var released: Array[String] = []
		for key in previous_held:
			if not input.held_action_keys.has(key):
				released.append(key)
		previous_held = input.held_action_keys.duplicate()
		var before := _observe(session)
		var events := session.step(input)
		var records: Array = []
		for event in events:
			evidence.record(frame, records.size(), before.move_id, action, event)
			var record := {"order": records.size(), "type": CombatEvent.Type.keys()[event.type], "move": before.move_id, "segment": event.move_segment, "combo_hits": event.combo_hits}
			if event.type == CombatEvent.Type.COMBO_ENDED:
				record["reason"] = CombatEvent.ComboEndReason.keys()[event.combo_end_reason]
			if event.type == CombatEvent.Type.LINK_FAILED:
				record["reason"] = CombatEvent.LinkFailReason.keys()[CombatEvent.LinkFailReason.values().find(event.link_fail_reason)]
				record["link_move"] = event.link_move_id
			if event.type == CombatEvent.Type.SWITCHED_SIDES:
				swaps += 1
			records.append(record)
			if event.type in [CombatEvent.Type.HIT, CombatEvent.Type.COMBO_ENDED, CombatEvent.Type.BOUNCE_CONTACT, CombatEvent.Type.SWITCHED_SIDES, CombatEvent.Type.HIT_MISS, CombatEvent.Type.LINK_FAILED]:
				print("F%d N%d %s" % [frame, int(session.clone_state().clock.normal_frame), JSON.stringify(record)])
		var after := _observe(session)
		if after.move_id != before.move_id or int(after.move_frame) < int(before.move_frame):
			action += 1
			if after.move_id != "":
				actions.append({"frame": frame, "normal_frame": after.normal_frame,
					"move": after.move_id, "action": action,
					"charge_branch": before.move_id == "5D" and after.move_id == "5[D]"})
		trace.store_line(JSON.stringify({"frame": frame, "input": {"axis": input.move_axis, "down": input.down_held, "up": input.up_held, "jump_pressed": input.jump_pressed, "pressed": input.pressed_action_keys, "held": input.held_action_keys, "released": released}, "before": before, "events": records, "after": after}))
	trace.store_line(JSON.stringify({"actions": actions, "move_sequence": evidence.move_sequence, "hits": evidence.hits,
		"hits_after_end": evidence.hits_after_end, "ends": evidence.ends, "swaps": swaps}))
	trace.close()
	_check(evidence.moves == entry.expected_hits, "%s continuous hits=%s late=%s" % [entry.id, str(evidence.moves), str(evidence.hits_after_end)])
	if entry.get("require_swap", false):
		_check(swaps > 0, "%s actual crossing swaps=%d" % [entry.id, swaps])
