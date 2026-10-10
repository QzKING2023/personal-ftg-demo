extends SceneTree
## 负例校准探针：错档/错方向/早晚偏移/对地接触起点各会怎样（只观察，不写断言）。
const TIERS := {"G": {"jc": 11, "jC": 34, "j214D": 47, "5B": 78, "214C": 90, "~C": 114},
	"H38": {"jc": 11, "jC": 31, "j214D": 45, "5B": 75, "214C": 87, "~C": 111},
	"H21": {"jc": 11, "jC": 29, "j214D": 42, "5B": 70, "214C": 82, "~C": 106}}
func _key(key: String, axis := 0) -> FrameInput:
	var i := FrameInput.new()
	i.pressed_action_keys = [key]; i.held_action_keys = [key]; i.move_axis = axis
	return i
func place(k: int, vx: float, g: float, r: float, facing := 1) -> CombatSession:
	var s := CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dx := wall - r * facing
	var step := GameParams.GRAVITY * GameParams.PHYSICS_TICK
	var h := 0.0
	for j in range(1, k + 1):
		h -= step * (j - 20) * GameParams.PHYSICS_TICK
	s.player_position = Vector2(dx - facing * (GameParams.BODY_SIZE.x + g), GameParams.ground_stand_y())
	s.dummy_position = Vector2(dx, GameParams.ground_stand_y() - h)
	s.dummy_velocity = Vector2(facing * vx, step * (k - 20))
	s.dummy_on_ground = false
	s.player_facing = facing
	return s
func probe(k: int, vx: float, g: float, r: float) -> Dictionary:
	var s := place(k, vx, g, r)
	for frame in range(1, 60):
		var input := _key("A", 1) if frame == 1 else (FrameInput.make(1) if frame == 2 else FrameInput.new())
		var m := s.player_move_id
		var pos := s.dummy_position
		var ong := s.dummy_on_ground
		var vy := s.dummy_velocity.y
		for e in s.step(input):
			if e.type in [CombatEvent.Type.HIT, CombatEvent.Type.HIT_MISS, CombatEvent.Type.ATTACK_BLOCKED] and m == "6A":
				return {"f": frame, "type": CombatEvent.Type.keys()[e.type], "h": GameParams.ground_stand_y() - pos.y, "air": not ong, "vy": vy, "gap": (pos.x - s.player_position.x) - GameParams.BODY_SIZE.x}
	return {}
func run_with(k: int, vx: float, g: float, r: float, tier: String, force_eight: bool, offs: Dictionary) -> Array:
	var c := probe(k, vx, g, r)
	if c.is_empty() or c["type"] != "HIT":
		return ["no-contact", str(c)]
	var delta := int(c["f"]) - 9
	var t: Dictionary = TIERS[tier]
	var back := -1
	var plan := {}
	plan[1] = _key("A", 1)
	plan[2] = FrameInput.make(1)
	var jump := FrameInput.make(0, true)
	if not force_eight:
		jump.move_axis = 1
	plan[int(t["jc"]) + delta + int(offs.get("jc", 0))] = jump
	plan[int(t["jC"]) + delta + int(offs.get("jC", 0))] = _key("C")
	for o in [3, 2, 1, 0]:
		var axis := 0 if o == 3 else back
		var ii := FrameInput.make(axis, false, "", o >= 2)
		if o == 0:
			ii = _key("D", back)
		plan[int(t["j214D"]) - o + delta + int(offs.get("j214D", 0))] = ii
	plan[int(t["5B"]) + delta + int(offs.get("5B", 0))] = _key("B")
	for o in [3, 2, 1, 0]:
		var axis := 0 if o == 3 else back
		var ii := FrameInput.make(axis, false, "", o >= 2)
		if o == 0:
			ii = _key("C", back)
		plan[int(t["214C"]) - o + delta + int(offs.get("214C", 0))] = ii
	plan[int(t["~C"]) + delta + int(offs.get("~C", 0))] = _key("C")
	var s := place(k, vx, g, r)
	var moves: Array = []
	var ends := 0
	for frame in range(1, 180):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var m := s.player_move_id
		for e in s.step(input):
			if e.type == CombatEvent.Type.HIT:
				moves.append(m)
			elif e.type == CombatEvent.Type.COMBO_ENDED:
				ends += 1
	return moves
func _initialize() -> void:
	print("grounded-contact probe (k30 vx-200 g100): ", str(probe(30, -200.0, 100.0, 350.0)))
	print("k30 vx0 g2 probe: ", str(probe(30, 0.0, 2.0, 350.0)))
	print("k26 wrong tier G: ", str(run_with(26, 0.0, 2.0, 350.0, "G", true, {})))
	print("k26 wrong dir 9 (gap~2): ", str(run_with(26, 0.0, 2.0, 350.0, "H38", false, {})))
	print("k24 wrong dir 8 (gap 28+): ", str(run_with(24, 178.4, 2.0, 350.0, "G", true, {})))
	print("k24 jc-10: ", str(run_with(24, 0.0, 2.0, 350.0, "G", true, {"jc": -10})))
	print("k24 jc+25: ", str(run_with(24, 0.0, 2.0, 350.0, "G", true, {"jc": 25})))
	print("k24 5B-12: ", str(run_with(24, 0.0, 2.0, 350.0, "G", true, {"5B": -12})))
	print("k24 5B+8: ", str(run_with(24, 0.0, 2.0, 350.0, "G", true, {"5B": 8})))
	print("k24 j214D+7: ", str(run_with(24, 0.0, 2.0, 350.0, "G", true, {"j214D": 7})))
	print("k26 H21 wrong low tier: ", str(run_with(26, 0.0, 2.0, 350.0, "H21", true, {})))
	quit(0)
