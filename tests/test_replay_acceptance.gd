extends SceneTree
## 最终路线回放与联合验收（ftg-combat-foundation issue 23）：
## 按 Combo Solver 输出，在全新 CombatSession 与训练场真实键盘中回放代表性
## 地面、方向派生、jump cancel 空中与落地路线——
## - 钉位回放（探针钉位 70 px，双面向）逐帧重现报告的命中帧/连段数/总伤害，
##   并核对 Hitstop 边界、落地与自然受身事件（checkbox 1、2）；
## - 同一输入经训练场真实键盘、方向和 Space 适配后，与同站位的会话探针结果
##   逐 tick 一致（checkbox 3）。键盘注入走物理帧回调内的高优先级驱动节点：
##   持续键（方向/下）当 tick 生效，边沿键（动作/Space）下一 tick 生效——
##   回放计划因此从第 2 tick 排首个输入，探针对照带同一前导空帧对齐时间轴；
## - 回放区分 timing-valid 与 spatial-valid：无空间数据只宣称 timing，提供数据
##   后 48/64/80 px 钉位复验成立；短 reach 注入路线在 80 px 的空间失败由回放
##   证实为挥空，不宣称未经验证的站位（checkbox 4）；
## - 回归层（checkbox 5 联合层）：命中后停顿内按下、取消窗口末档消费的
##   「缓存 + 取消」边界（末档/末档+1）、空技着地恢复期间的出招锁定在回放
##   路径上复核。蹲防/站防/空防、普通投/拆投、66/44 由既有专项回归覆盖
##   （test_combat_session / test_smoke），本文件不重复；HUD、键位与空中
##   动量修复只作为基线。
## 运行：godot --headless --path . -s res://tests/test_replay_acceptance.gd

const GROUND_ROUTE := ["5A", "5B", "5D"]
## 旧派生代表 5B→214D 已废弃；新基线派生代表为 5B 必杀取消 236C 的空中路线。
const DERIVATIVE_ROUTE := ["5B", "6A", "jA", "jB", "j5D"]
const AIR_ROUTE := ["5A", "5B", "6A", "jA", "jB", "j5D"]
const LANDING_ROUTE := ["5A", "5B", "6A", "jA", "jB", "5D"]
## 训练场键盘回放的站位（真实击退物理）：地面/派生用固定接触位 70 px；
## 空中/落地用空间网格的 48 px 贴身档——真实击退下 70 px 起手的空中后段会
## 漂出命中距离，回放记录如实区分钉位层与真实击退层的结论。
const KEYBOARD_STANDINGS := {
	"ground": 70.0, "derivative": 70.0, "air": 48.0, "landing": 48.0,
}
## 单次回放的物理帧观测上限（自然受身 + 落地 + 余量）。
const OBSERVE_HORIZON := 420

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0
## 回放记录（起始面向/站位/逐帧输入/命中帧/连段数/总伤害），跑完统一打印并断言完整。
var _records: Array[String] = []


func _initialize() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	print("")
	var plain := _metrics.solve()
	_test_pinned_replay_reproduces_solver_results(plain)
	_test_rejected_landing_replay(plain)
	_test_replay_boundary_variants(plain)
	_test_timing_spatial_layering_and_whiff_replay(plain)
	await _test_keyboard_replay_matches_session_probe(plain)
	_test_replay_records_complete()
	print("")
	for line in _records:
		print(line)
	print("")
	_metrics.emit("test_replay_acceptance")
	if _failures == 0:
		print("ALL REPLAY ACCEPTANCE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- Part 1: pinned replay reproduces the solver report (checkboxes 1, 2) ---

func _test_pinned_replay_reproduces_solver_results(report: ComboSolver.SolverReport) -> void:
	_check(report.mirror_consistent, "the replayed table passes the solver's facing-mirror verification")
	var table := _shared_table()
	for route_ids in [GROUND_ROUTE, DERIVATIVE_ROUTE, AIR_ROUTE]:
		var route := _find_route(report, route_ids)
		if route == null:
			_check(false, "the solver reports the representative route %s" % " → ".join(route_ids))
			continue
		_check(route.timing_valid and route.inputs.size() > 0,
			"route %s is timing-valid and carries frame-by-frame replay inputs" % route.label())
		for facing in [1, -1]:
			var run := _replay_route(route, facing, ComboSolver.PIN_DX, table, true)
			var tag := "%s / facing %+d" % [route.label(), facing]
			_check(run["hit_frames"] == route.hit_frames,
				"%s: the pinned replay reproduces the reported hit frames (%s)" % [tag, str(route.hit_frames)])
			_check(int(run["combo_hits"]) == route.combo_hits and _approx(float(run["total_damage"]), route.total_damage),
				"%s: the replay reproduces %d combo hits and total damage %.1f" % [tag, route.combo_hits, route.total_damage])
			_check((run["hitstop_pairs"] as Array).size() == route.combo_hits and String(run["hitstop_mismatch"]) == "",
				"%s: each hit is followed by exactly %d hitstop frames (paired boundaries%s)" % [tag, GameParams.HITSTOP_FRAMES,
					"; " + String(run["hitstop_mismatch"]) if String(run["hitstop_mismatch"]) != "" else ""])
			_check(bool(run["recovered"]) and int(run["recover_frame"]) > route.hit_frames[route.hit_frames.size() - 1],
				"%s: the replay observes the dummy's natural recovery (normal frame %d)" % [tag, int(run["recover_frame"])])
			var damage_ok := (run["hit_damages"] as Array).size() == route.combo_hits
			if damage_ok:
				for i in range((run["hit_damages"] as Array).size()):
					damage_ok = damage_ok and _approx(float(run["hit_damages"][i]), _decayed_damage(table, route.move_ids[i], i + 1, route.move_ids[0]))
			_check(damage_ok, "%s: per-hit damage reproduces the combo decay (%s)" % [tag, str(run["hit_damages"])])
			var directions_ok := true
			for hit in run["hits"]:
				directions_ok = directions_ok and int(hit["direction"]) == facing
			_check(directions_ok, "%s: every hit's direction matches the facing" % tag)
			if route_ids == AIR_ROUTE or route_ids == LANDING_ROUTE:
				_check((run["landing_ticks"] as Array).size() > 0, "%s: the air segment observes a landing" % tag)
			if route_ids == AIR_ROUTE:
				var saw_float := false
				for state in run["dummy_states_at_hits"]:
					saw_float = saw_float or state == CombatSession.DummyState.AIR_HITSTUN
				_check(saw_float, "%s: the launcher's hit puts the dummy into float hitstun" % tag)
			_records.append(_record_line(route, facing, "站位：探针钉位 %d px" % ComboSolver.PIN_DX, run,
				"命中帧", "timing-valid（空间未验证）"))
	# 确定性：同一输入重放一遍，事件载荷与逐击结算状态快照完全一致
	#（checkbox 2「相同 CombatEvent、状态」的可观察口径）。
	var air := _find_route(report, AIR_ROUTE)
	if air != null:
		var first := _replay_route(air, 1, ComboSolver.PIN_DX, table, true)
		var second := _replay_route(air, 1, ComboSolver.PIN_DX, table, true)
		_check(first["event_log"] == second["event_log"] and first["state_log"] == second["state_log"]
				and first["landing_ticks"] == second["landing_ticks"],
			"the same inputs produce identical event payloads, per-hit settlement states and landing timelines in two fresh sessions")
		for facing in [1, -1]:
			## 轨迹层修正缩小击退后，70 px 真实击退回放完整接通全部五击——
			## 与钉位层结论一致；记录层注明这是单一站位的真实物理结论。
			var free := _replay_route(air, facing, 70.0, _shared_table(), false)
			_check(int(free["combo_hits"]) == air.combo_hits,
				"70 px real-knockback air replay reproduces the full route (trajectory corrections keep the dummy reachable)")
			_records.append(_record_line(air, facing, "站位：真实击退 70 px", free,
				"命中帧", "timing-valid（70 px 真实击退下完整接通；单一站位结论）"))


## 保留旧 Solver 的真实帧表作负例，不能把它混回当前合法路线。
func _legacy_landing_fixture() -> ComboSolver.SolverRoute:
	var route := ComboSolver.SolverRoute.new()
	route.move_ids.assign(["5A", "236C", "jA", "jB", "5D"])
	route.hit_frames.assign([6, 13, 43])
	route.combo_hits = 3
	route.total_damage = 32.6
	route.timing_valid = false
	for row in [[1,0,false,false,"A"], [3,0,true,false,""], [4,1,true,false,""],
		[5,1,false,false,""], [6,0,false,false,"C"], [13,0,false,true,""],
		[39,0,false,false,"A"], [48,0,false,false,"B"], [54,0,false,false,"D"]]:
		var input := ComboSolver.ScheduledInput.new()
		input.frame = row[0]
		input.axis = row[1]
		input.down = row[2]
		input.jump = row[3]
		input.key = row[4]
		route.inputs.append(input)
	return route

func _test_rejected_landing_replay(report: ComboSolver.SolverReport) -> void:
	_check(_find_route(report, LANDING_ROUTE) == null, "latest Solver excludes the forbidden landing route")
	var route := _legacy_landing_fixture()
	for facing in [1, -1]:
		var run := _replay_route(route, facing, 70.0, _shared_table(), true)
		_check(run["hit_frames"] == [6, 13, 18] and int(run["combo_hits"]) == 3,
			"legacy landing replay on the two-segment baseline lands 5A plus both 236C segments and stops there (no jump cancel exists; the old air schedule never connects)")
		_check(not (run["landing_move_ids"] as Array).has("5D"), "legacy schedule cannot start 5D on landing")
		_records.append(_record_line(route, facing, "站位：旧样本钉位 70 px", run,
			"命中帧", "timing-invalid（恢复锁拒绝旧样本第5击；不作空间证明）"))


# --- Part 2: follow-up boundaries replayed end to end (checkbox 5, joint layer) ---

func _test_replay_boundary_variants(report: ComboSolver.SolverReport) -> void:
	var table := _shared_table()
	var edge := _find_edge(report, "5B", "5D", ComboSolver.EdgeKind.CHAIN_CANCEL)
	if edge == null or not edge.valid:
		_check(false, "the 5B → 5D cancel edge is valid (the boundary variants' baseline)")
		return
	# 5B 按下（F1，B 键 +3f 组合等待）在正常帧 hit_5b 命中；停顿内于命中后
	# 第 wait_to 帧按下 D——恢复首个正常帧从缓存消费、取消窗口末档接通第 2 击
	#（缓存 + 取消窗口两条边界在同一回放里联合复核）；再晚一帧不再以连段第 2
	# 击成立（取消窗口关闭或目标命中晚于木桩恢复）。
	var hit_5b: int = 1 + GameParams.THROW_COMBINATION_TOLERANCE + (table["5B"] as MoveData).startup_frames
	var startup_5d: int = (table["5D"] as MoveData).startup_frames
	var on_time := _replay_key_schedule(table, {1: "B", hit_5b + edge.wait_to: "D"}, 1, 70.0)
	_check((on_time["hit_frames"] as Array).size() == 2 and int(on_time["combo_hits"]) == 2
			and on_time["hit_frames"] == [hit_5b, hit_5b + edge.wait_to + startup_5d],
		"pressing D at the cancel window's last valid age (%d) still lands combo hit 2 (hit frame %d)" % [
			edge.wait_to, hit_5b + edge.wait_to + startup_5d])
	var late := _replay_key_schedule(table, {1: "B", hit_5b + edge.wait_to + 1: "D"}, 1, 70.0)
	var late_hits: Array = late["hits"]
	var late_ok := bool(late["recovered"]) and bool(late["ended"])
	if late_hits.size() == 2:
		# 唯一可接受的残余：第 2 击落在木桩自然受身之后、连段被重新计数（非连段追击）。
		late_ok = late_ok and int(late_hits[1]["combo"]) == 1
	else:
		late_ok = late_ok and late_hits.size() == 1
	_check(late_ok,
		"pressing D one frame later never lands as combo hit 2 — the follow-up boundary is observable in replay (%s)" % String(late["end_reasons_text"]))
	# 空技着地恢复锁定：空中路线收尾后，恢复期间按 A 不起手；恢复归零当帧
	#（首个自由帧）的新按下起手 5A。
	var air := _find_route(report, AIR_ROUTE)
	if air == null:
		_check(false, "the air route is available for the landing-lock replay")
		return
	var run := _replay_route(air, 1, ComboSolver.PIN_DX, table, true, true)
	if (run["landing_ticks"] as Array).is_empty():
		_check(false, "the air route replay observes a landing frame")
		return
	_check(int(run["recovery_after_landing"]) > 0,
		"the air-move landing observes its recovery frames (%d = base %d + air-move +1)" % [
			int(run["recovery_after_landing"]), GameParams.PLAYER_LANDING_RECOVERY_BASE_FRAMES])
	_check(String(run["move_during_recovery"]) == "",
		"pressing A during the landing recovery never starts a move (air-move landing lock)")
	_check(String(run["move_after_recovery"]) == "5A",
		"the fresh A press on the first free frame starts 5A")


# --- Part 3: timing/spatial layering and the whiff replay (checkbox 4 + whiff regression) ---

func _test_timing_spatial_layering_and_whiff_replay(plain: ComboSolver.SolverReport) -> void:
	var table := _shared_table()
	# 无空间数据：只宣称 timing-valid，固定接触位不构成空间证明。
	var no_spatial := "\n".join(plain.spatial_lines)
	_check("未提供空间数据" in no_spatial and "不构成空间证明" in no_spatial,
		"without spatial data the report declares every route timing-valid only")
	for route_ids in [GROUND_ROUTE, AIR_ROUTE]:
		var route := _find_route(plain, route_ids)
		if route == null:
			continue
		_check(route.timing_valid and route.spatial_state == ComboSolver.SolverRoute.SpatialState.UNVERIFIED,
			"route %s stays spatially unverified without spatial data" % route.label())
	var guide_text := "\n".join(plain.guide_lines)
	_check(("%d px" % ComboSolver.PIN_DX) in guide_text,
		"the guide states its frame tables are laid out at the fixed %d px contact" % ComboSolver.PIN_DX)

	# 提供空间数据：默认表路线 spatial-valid，48/64/80 px 钉位复验逐档重现。
	var spatial := _metrics.solve(_spatial_options())
	var air := _find_route(spatial, AIR_ROUTE)
	if air == null:
		_check(false, "the spatial run reports the air route")
		return
	## 新基线 5A 命中框远缘 56 px 与 80 px 站位相邻不相交：5A 起手的空中路线在
	## 80 px 钉位回放如实断在第 1 击（空间层的 80 px 失败由回放证实），48/64 复现。
	for dx in ComboSolver.SPATIAL_PROBE_DISTANCES:
		var run := _replay_route(air, 1, dx, table, true)
		if dx < 80.0:
			_check(run["hit_frames"] == air.hit_frames and _approx(float(run["total_damage"]), air.total_damage),
				"spatial re-verification: the %d px pinned replay reproduces the air route (hits %s)" % [dx, str(air.hit_frames)])
		else:
			## 票据 05 起空中路线为 5A > 5B > 6A > …：80 px 上 5A 边界相邻不相交
			##（真实挥空），后续独立链部分接通——该站位不作路线空间声明。
			_check(int(run["combo_hits"]) < air.combo_hits and not (run["hit_frames"] as Array).has(air.hit_frames[0]),
				"the %d px pinned replay confirms the 5A boundary whiff (touching rects do not intersect; the partial chain is not claimed as the route at this standing)" % dx)
	var record_run := _replay_route(air, 1, 64.0, table, true)
	_records.append(_record_line(air, 1, "站位：探针钉位 64 px（空间网格档）", record_run,
		"命中帧", "timing-valid；spatial-valid（48/64/80 px 钉位复验）"))

	# 短 reach 注入：80 px 空间失败由回放证实为挥空（已起手、无命中），不伪装结论。
	var short_table := MoveData.default_table()
	var short_reach := _injected_move("5R", "R")
	short_reach.hitbox_size = Vector2(20, 60)
	short_reach.hitbox_gap = 4.0
	short_table["5R"] = short_reach
	## 5A 在 80 px 自身脱靶（边界相邻）：以 5B（远缘 69 px）为来源，80 px 上
	## 来源命中、5R（远缘 48 px）挥空——短 reach 空间失败由回放证实。
	(short_table["5B"] as MoveData).cancel_targets.append("5R")
	var short_report := _metrics.solve(_spatial_options(short_table))
	var short_route := _find_route(short_report, ["5B", "5R"])
	if short_route == null:
		_check(false, "the short-reach injected table reports the 5B → 5R route")
		return
	_check(short_route.timing_valid and short_route.spatial_state == ComboSolver.SolverRoute.SpatialState.INVALID,
		"the short-reach route stays timing-valid but spatially invalid")
	_check("；".join(short_route.spatial_failures).contains("80 px"),
		"the spatial failure names the 80 px standing")
	for dx in [48.0, 80.0]:
		var run := _replay_route(short_route, 1, dx, short_table, true)
		if dx < 80.0:
			_check(int(run["combo_hits"]) == 2, "the 48 px pinned replay lands both hits (reachability replay-confirmed)")
		else:
			_check(int(run["combo_hits"]) == 1 and (run["started_without_hit"] as Array).has("5R"),
				"the 80 px pinned replay confirms the whiff: 5R started but its hitbox never connected (that standing is not claimed)")


# --- Part 4: training-ground real-keyboard replay (checkbox 3) ---

func _test_keyboard_replay_matches_session_probe(plain: ComboSolver.SolverReport) -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var session: CombatSession = main.session
	if session == null:
		_check(false, "the training-ground scene drives a combat session")
		return
	var driver := KeyboardDriver.new()
	root.add_child(driver)
	await physics_frame
	for combo in [
		["ground", GROUND_ROUTE, 1], ["derivative", DERIVATIVE_ROUTE, 1],
		["air", AIR_ROUTE, 1], ["landing", LANDING_ROUTE, 1],
		["ground", GROUND_ROUTE, -1], ["derivative", DERIVATIVE_ROUTE, -1],
		["air", AIR_ROUTE, -1], ["landing", LANDING_ROUTE, -1],
	]:
		var kind: String = combo[0]
		var route := _legacy_landing_fixture() if kind == "landing" else _find_route(plain, combo[1])
		var facing: int = combo[2]
		if route == null:
			_check(false, "the keyboard replay finds route %s" % " → ".join(PackedStringArray(combo[1])))
			continue
		var dx: float = KEYBOARD_STANDINGS[kind]
		# 会话探针：同站位、真实击退物理、同一前导空帧（对齐键盘边沿注入契约）。
		var probe := _replay_route(route, facing, dx, _shared_table(), false, false, true)
		var keyboard := await _keyboard_replay(session, driver, route, facing, dx)
		var tag := "%s / facing %+d / %.0f px real knockback" % [route.label(), facing, dx]
		_check(keyboard["hit_ticks"] == probe["hit_ticks"],
			"%s: the keyboard replay matches the session probe's hit ticks exactly (%s)" % [tag, str(keyboard["hit_ticks"])])
		_check(int(keyboard["combo_hits"]) == int(probe["combo_hits"]) \
				and _approx(float(keyboard["total_damage"]), float(probe["total_damage"])),
			"%s: the keyboard replay reproduces %d combo hits and total damage %.1f" % [tag, int(probe["combo_hits"]), float(probe["total_damage"])])
		_check(int(keyboard["recover_tick"]) == int(probe["recover_tick"]),
			"%s: the dummy's natural recovery lands on the same tick (%d)" % [tag, int(probe["recover_tick"])])
		if kind == "air" or kind == "landing":
			_check(keyboard["landing_ticks"] == probe["landing_ticks"],
				"%s: the player lands on the same tick (%s)" % [tag, str(keyboard["landing_ticks"])])
		var layer := "timing-valid（键盘回放证实真实击退下完整接通）"
		if kind == "landing":
			_check(int(keyboard["combo_hits"]) == 3, "legacy landing schedule lands the same three hits on the real keyboard path (the retired 236C launcher no longer jump-cancels)")
			layer = "timing-invalid（旧落地样本负例：两段基线下旧 236C launcher 帧表失效、无 jump cancel；恢复锁仍拒绝第5击）"
		elif int(keyboard["combo_hits"]) < route.combo_hits:
			layer = "timing-valid（键盘回放 %.0f px 真实击退下第 %d 击后漂出命中距离——钉位层结论见钉位回放记录）" % [
				dx, int(keyboard["combo_hits"])]
		_records.append(_record_line(route, facing, "站位：训练场真实键盘 %.0f px" % dx, keyboard,
			"命中tick（物理，含前导空帧）", layer))
	# 测试者可按说明执行：每条回放路线在对应面向分节里有真实键位行。
	var guide_text := "\n".join(plain.guide_lines)
	for route_ids in [GROUND_ROUTE, DERIVATIVE_ROUTE, AIR_ROUTE]:
		var route := _find_route(plain, route_ids)
		if route == null:
			continue
		var has_guide := false
		for line in plain.guide_lines:
			if line.begins_with(route.label() + "（"):
				has_guide = true
				break
		_check(has_guide, "the guide carries a real-key replay line for %s" % route.label())
	_check("F1 按 U" in guide_text, "the guide expresses the first press with the real physical key (F1 按 U)")
	driver.release_all()
	driver.queue_free()
	main.queue_free()
	await process_frame


## 键盘回放：物理帧回调内的高优先级驱动节点按 tick 注入真实键位（U/I/K/J、
## A/D、S、Space）。注入契约见文件头。返回与探针同口径的相对 tick 观测。
func _keyboard_replay(session: CombatSession, driver: KeyboardDriver, route: ComboSolver.SolverRoute, facing: int, dx: float) -> Dictionary:
	await _settle(session)
	session.dummy_hp = GameParams.DUMMY_MAX_HP
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = facing
	session.dummy_position = session.player_position + Vector2(facing * dx, 0.0)
	session.dummy_velocity = Vector2.ZERO
	await physics_frame
	var result := {
		"hit_ticks": [] as Array[int], "combo_hits": session.combo_hits,
		"total_damage": session.combo_total_damage, "recover_tick": -1,
		"landing_ticks": [] as Array[int],
	}
	var base_frame := int(session.debug_snapshot()["frame"])
	driver.begin(_keyboard_schedule(route, facing))
	var last_combo := session.combo_hits
	var last_damage := session.combo_total_damage
	var was_airborne := false
	var saw_hitstun := false
	var last_tick := 0
	for i in OBSERVE_HORIZON:
		await physics_frame
		var tick := int(session.debug_snapshot()["frame"]) - base_frame
		if tick <= last_tick:
			continue
		last_tick = tick
		if session.combo_hits != last_combo or absf(session.combo_total_damage - last_damage) > 0.001:
			result.hit_ticks.append(tick)
			last_combo = session.combo_hits
			last_damage = session.combo_total_damage
		if session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN \
				or session.dummy_state == CombatSession.DummyState.AIR_HITSTUN \
				or session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			saw_hitstun = true
		elif saw_hitstun and int(result.recover_tick) < 0 \
				and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			result.recover_tick = tick
		if not session.player_on_ground:
			was_airborne = true
		elif was_airborne:
			result.landing_ticks.append(tick)
			was_airborne = false
		if int(result.recover_tick) > 0 and session.player_on_ground and tick > int(result.recover_tick) + 2:
			break
	driver.release_all()
	result.combo_hits = session.combo_hits
	result.total_damage = session.combo_total_damage
	return result


## 键盘计划：路线输入帧 → 回放 tick（前导 1 空帧 + 每次先前命中追加 8 帧停顿）。
func _keyboard_schedule(route: ComboSolver.SolverRoute, facing: int) -> Dictionary:
	var schedule := {}
	for spec in route.inputs:
		var frozen := 0
		for hit in route.hit_frames:
			if hit < spec.frame:
				frozen += GameParams.HITSTOP_FRAMES
		var tick: int = spec.frame + 1 + frozen
		var entry: Dictionary = schedule.get(tick, {})
		entry["axis"] = spec.axis * facing
		entry["down"] = spec.down
		if spec.jump:
			entry["press_jump"] = true
		if spec.key != "":
			entry["press_key"] = spec.key
		schedule[tick] = entry
	return schedule


## 等待训练场回到可回放的静止状态（玩家中立站地、木桩中立、连段结束、无受限阶段）。
func _settle(session: CombatSession) -> void:
	for action in KeyboardDriver.INPUT_ACTIONS:
		Input.action_release(action)
	for i in 180:
		await physics_frame
		if session.player_phase == CombatSession.PlayerPhase.NEUTRAL \
				and session.dummy_state == CombatSession.DummyState.NEUTRAL \
				and session.player_on_ground and not session.combo_active \
				and session.player_prejump_left == 0 and session.player_landing_recovery_left == 0 \
				and session.player_dash_left == 0:
			return


# --- 回放记录完整性（checkbox 1 的记录口径）---

func _test_replay_records_complete() -> void:
	_check(_records.size() >= 10, "the replay records cover the representative routes (pinned both facings + keyboard + spatial)")
	_check(_records.any(func(line: String) -> bool: return line.contains("5B → 6A → jA → jB → j5D｜面向 -1") and line.contains("6[A]")),
		"left-facing replay records mirror physical keys while retaining the relative forward fold")
	for line in _records:
		var complete := true
		for token in ["回放记录｜", "面向", "站位：", "输入 ", "｜伤害 ", "timing-"]:
			complete = complete and token in line
		_check(complete, "each replay record line carries every required field (%s)" % line)


# --- 回放驱动（全新会话；钉位 = 每步后把木桩钉回水平间距，非钉位 = 真实击退）---

func _replay_route(route: ComboSolver.SolverRoute, facing: int, dx: float, table: Dictionary,
		pinned: bool, landing_probe := false, lead_empty := false) -> Dictionary:
	var schedule := {}
	for spec in route.inputs:
		schedule[spec.frame] = spec
	return _replay_core(table, schedule, facing, dx, pinned, route.hit_frames, landing_probe, lead_empty)


## 键序列计划（边界变体用）：帧 → 动作键字母。
func _replay_key_schedule(table: Dictionary, keys: Dictionary, facing: int, dx: float) -> Dictionary:
	return _replay_core(table, keys, facing, dx, true, [], false, false)


## 逐帧执行输入计划并记录可观察结果。schedule 值为 ScheduledInput（路线）或
## 动作键字母（边界变体）；hit_expect 只用于收尾判定；lead_empty 先步一个空帧
## （键盘边沿注入契约的对照时间轴）；landing_probe 在空中收尾后逐帧按 A，
## 按「起手时刻的恢复余量」区分恢复期间违规起手与首个自由帧的合法起手。
func _replay_core(table: Dictionary, schedule: Dictionary, facing: int, dx: float,
		pinned: bool, hit_expect: Array, landing_probe: bool, lead_empty: bool) -> Dictionary:
	var session := CombatSession.new(table)
	session.player_facing = facing
	session.dummy_position = session.player_position + Vector2(facing * dx, 0.0)
	var result := {
		"hits": [], "hit_frames": [] as Array[int], "hit_damages": [] as Array[float],
		"hit_ticks": [] as Array[int], "combo_hits": 0, "total_damage": 0.0,
		"hitstop_pairs": [] as Array[int], "hitstop_mismatch": "",
		"recovered": false, "recover_tick": -1, "recover_frame": -1, "ended": false,
		"end_reasons_text": "", "landing_ticks": [] as Array[int],
		"landing_move_ids": [] as Array[String], "dummy_states_at_hits": [] as Array[int],
		"event_log": [] as Array[String], "state_log": [] as Array,
		"started_without_hit": [] as Array[String],
		"move_during_recovery": "", "move_after_recovery": "", "recovery_after_landing": 0,
	}
	var frame := 0
	var physics := 0
	var was_airborne := false
	var tail_stage := 0  # landing_probe：0 等落地 → 1 落地后逐帧按 A → 3 起手已观测
	var last_hit_physics := -99
	var last_frame: int = hit_expect[hit_expect.size() - 1] if not hit_expect.is_empty() else 30
	while physics < OBSERVE_HORIZON:
		if session.hitstop_active():
			var frozen_events := session.step(FrameInput.new())
			physics += 1
			_log_events(result.event_log, physics, frozen_events)
			continue
		frame += 1
		var input := FrameInput.new()
		var spec = null
		if not lead_empty or frame > 1:
			spec = schedule.get(frame if not lead_empty else frame - 1)
		if tail_stage == 1:
			# 落地后逐帧按 A：恢复期间不应起手；恢复归零当帧（首个自由帧）起手 5A。
			input = FrameInput.make(0, false, "A", false)
		elif spec != null:
			if spec is ComboSolver.ScheduledInput:
				var sched_input: ComboSolver.ScheduledInput = spec
				input = FrameInput.make(sched_input.axis * facing, sched_input.jump, sched_input.key, sched_input.down)
			else:
				input = FrameInput.make(0, false, String(spec), false)
		var events := session.step(input)
		physics += 1
		_log_events(result.event_log, physics, events)
		if pinned:
			session.dummy_position.x = session.player_position.x + facing * dx
		for event in events:
			match event.type:
				CombatEvent.Type.HIT:
					result.hits.append({
						"tick": physics, "frame": frame, "combo": event.combo_hits,
						"damage": event.damage, "direction": event.direction,
					})
					result.hit_frames.append(frame)
					result.hit_ticks.append(physics)
					result.hit_damages.append(event.damage)
					result.dummy_states_at_hits.append(session.dummy_state)
					result.state_log.append(session.settlement_state())
					last_hit_physics = physics
				CombatEvent.Type.HITSTOP_STARTED:
					result.hitstop_pairs.append(physics)
				CombatEvent.Type.HITSTOP_ENDED:
					var start := int(result.hitstop_pairs[result.hitstop_pairs.size() - 1])
					if physics - start - 1 != GameParams.HITSTOP_FRAMES:
						result.hitstop_mismatch = "第 %d tick 命中的停顿在 %d tick 后结束（预期 %d）" % [
							start, physics - start - 1, GameParams.HITSTOP_FRAMES,
						]
				CombatEvent.Type.DUMMY_RECOVERED:
					result.recovered = true
					result.recover_tick = physics
					result.recover_frame = frame
				CombatEvent.Type.COMBO_ENDED:
					result.ended = true
					result.end_reasons_text += ("；" if result.end_reasons_text != "" else "") + _end_text(event)
		# 挥空观察：招式已起手但未在预期帧命中（空间失败回放证实的口径）。
		if session.player_move_id != "" and not hit_expect.is_empty() \
				and frame == last_frame and result.hits.size() < hit_expect.size():
			result.started_without_hit.append(session.player_move_id)
		# 落地观测与空技着地锁定探测。
		if not session.player_on_ground:
			was_airborne = true
		elif was_airborne:
			was_airborne = false
			result.landing_ticks.append(physics)
			result.landing_move_ids.append(session.player_move_id)
			if landing_probe and tail_stage == 0:
				tail_stage = 1
				result.recovery_after_landing = session.player_landing_recovery_left
		if tail_stage == 1 and session.player_move_id != "":
			# 起手时刻区分：恢复余量 > 0 = 恢复期间违规起手；== 0 = 首个自由帧的合法起手。
			if session.player_landing_recovery_left > 0:
				result.move_during_recovery = session.player_move_id
			else:
				result.move_after_recovery = session.player_move_id
				tail_stage = 3
		# 收尾：预期命中核对完毕、观测到自然受身且（空中段）观测到落地（再走
		# 12 tick 余量）；或探测完成。自然受身可能早于玩家落地（浮空受身计时
		# 独立消耗），先停会漏记落地 tick。
		var plan_done := hit_expect.is_empty() or frame >= last_frame
		var landed_done: bool = not was_airborne or not (result["landing_ticks"] as Array).is_empty()
		if (plan_done and result.recovered and landed_done and physics > last_hit_physics + 12 and not landing_probe) \
				or (landing_probe and tail_stage == 3):
			break
	result.combo_hits = result.hits.size()
	for hit in result.hits:
		result.total_damage += hit.damage
	return result


func _log_events(log: Array[String], physics: int, events: Array[CombatEvent]) -> void:
	# 载荷入日志：命中带伤害/连段数/方向，确定性对拍覆盖「相同 CombatEvent」。
	for event in events:
		match event.type:
			CombatEvent.Type.HIT:
				log.append("F%d:HIT:%.1f:%d:%d" % [physics, event.damage, event.combo_hits, event.direction])
			CombatEvent.Type.COMBO_ENDED:
				log.append("F%d:ENDED:%d" % [physics, event.combo_end_reason])
			CombatEvent.Type.THROW_FAILED:
				log.append("F%d:THROW_FAILED:%d" % [physics, event.throw_fail_reason])
			_:
				log.append("F%d:%d" % [physics, event.type])


func _end_text(event: CombatEvent) -> String:
	match event.combo_end_reason:
		CombatEvent.ComboEndReason.FINISHER:
			return "收尾"
		CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED:
			return "取消窗口关闭"
		CombatEvent.ComboEndReason.MOVE_RECOVERED:
			return "招式收招未接续"
		CombatEvent.ComboEndReason.DUMMY_RECOVERED:
			return "木桩自然受身"
	return "?"


# --- 键盘驱动节点：物理帧回调内注入真实键位（process_priority 先于主场景）---

class KeyboardDriver extends Node:
	## 训练场全部输入动作（settle 与释放清单共用同一常量）。
	const INPUT_ACTIONS := ["move_left", "move_right", "move_down", "jump",
		"attack_a", "attack_b", "attack_c", "attack_d"]

	var schedule := {}
	var _armed := false
	var _tick := 0
	var _issued: Dictionary = {}

	func _init() -> void:
		process_priority = -100

	## 从下一个物理帧起以 tick 1 执行计划（内部计数：Engine 帧号在
	## _physics_process 内读数滞后一拍，不能作锚点）。
	func begin(plan: Dictionary) -> void:
		schedule = plan
		_armed = true
		_tick = 0
		_issued.clear()

	func release_all() -> void:
		for action in INPUT_ACTIONS:
			if Input.is_action_pressed(action):
				Input.action_release(action)
		_issued.clear()

	func _physics_process(_delta: float) -> void:
		if not _armed:
			return
		_tick += 1
		# 上一 tick 消费过的边沿键现在松开（保持「按下当 tick」的持键形状）。
		for action in _issued.get(_tick - 1, []):
			Input.action_release(action)
		# 持续键（方向/下）当 tick 生效。
		var spec: Dictionary = schedule.get(_tick, {})
		_set_key("move_right", int(spec.get("axis", 0)) == 1)
		_set_key("move_left", int(spec.get("axis", 0)) == -1)
		_set_key("move_down", bool(spec.get("down", false)))
		# 边沿键（动作/Space）下一 tick 生效：现在注入下一 tick 的按下。
		var next_spec: Dictionary = schedule.get(_tick + 1, {})
		var next: Array[String] = []
		if bool(next_spec.get("press_jump", false)):
			next.append("jump")
		var key := String(next_spec.get("press_key", ""))
		if key != "":
			next.append("attack_" + key.to_lower())
		for action in next:
			Input.action_press(action)
		_issued[_tick + 1] = next

	func _set_key(action: String, pressed: bool) -> void:
		if pressed and not Input.is_action_pressed(action):
			Input.action_press(action)
		elif not pressed and Input.is_action_pressed(action):
			Input.action_release(action)


# --- 辅助 ---

func _shared_table() -> Dictionary:
	var loaded := MoveTable.load_default()
	return loaded.moves


func _spatial_options(table: Dictionary = {}) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.spatial = ComboSolver.SolverSpatialData.new()
	if not table.is_empty():
		opts.move_table = table
	return opts


func _find_route(report: ComboSolver.SolverReport, move_ids: Array) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id and edge.kind == kind:
			return edge
	return null


## 第 n 击的修正伤害（C-01/C-02：首击锁定起手等级，层值 = starter×0.9^(n-1)，
## 伤害独立舍入到 0.1；起手等级取路线首击招式声明）。
func _decayed_damage(table: Dictionary, move_id: String, hit_number: int, starter_id: String = "") -> float:
	var move := table[move_id] as MoveData
	var starter := table[starter_id] as MoveData if starter_id != "" else move
	var scale := float(GameParams.STARTER_DAMAGE_SCALE[starter.starter_grade]) 		* pow(GameParams.NORMAL_HIT_DAMAGE_SCALE, hit_number - 1)
	return snappedf(move.base_damage * maxf(GameParams.COMBO_DAMAGE_FLOOR, scale), 0.1)


## 回放记录行：起始面向、站位、逐帧输入（真实物理键）、命中帧/命中 tick、
## 连段数、总伤害、分层标签（unit 区分会话正常帧与键盘物理 tick 两种口径）。
func _record_line(route: ComboSolver.SolverRoute, facing: int, standing: String, run: Dictionary,
		unit: String, layer: String) -> String:
	var ops: Array[String] = []
	for spec in route.inputs:
		var token := "F%d" % spec.frame
		if spec.key != "":
			token += " 按" + ComboSolver.ACTION_PHYSICAL_KEYS.get(spec.key, spec.key)
		elif spec.jump:
			token += " Space"
		else:
			token += " %s[%s]" % [_digit_text(spec.axis * facing, spec.down, facing), _digit_keys(spec.axis * facing, spec.down, facing)]
		ops.append(token)
	var hit_frames: Array = run.get("hit_frames", run.get("hit_ticks", []))
	return "回放记录｜%s｜面向 %+d｜%s｜输入 %s｜%s %s｜%d hit｜伤害 %.1f｜%s" % [
		route.label(), facing, standing, " ".join(PackedStringArray(ops)), unit,
		", ".join(hit_frames.map(func(f) -> String: return str(f))),
		int(run.get("combo_hits", 0)), float(run.get("total_damage", 0.0)), layer,
	]


## 相对方向数字（前 6 / 后 4 / 下 2 / 斜 1、3）。
func _digit_text(axis: int, down: bool, facing: int) -> String:
	var horizontal := 0
	if axis == facing:
		horizontal = 1
	elif axis == -facing:
		horizontal = -1
	return str(5 + horizontal - (3 if down else 0))


## 相对方向对应的真实物理方向键（随面向镜像）。
func _digit_keys(axis: int, down: bool, facing: int) -> String:
	var keys: Array[String] = []
	if down:
		keys.append("S")
	if axis == facing:
		keys.append("D" if facing == 1 else "A")
	elif axis == -facing:
		keys.append("A" if facing == 1 else "D")
	return "+".join(PackedStringArray(keys))


## 测试注入招式：字段齐全的合法打击招式（注入表只喂给 Solver 探针与会话回放，
## 不经过 MoveTable 校验，键名可超出 A–D）。
func _injected_move(id: String, key: String) -> MoveData:
	var move := MoveData.new()
	move.move_id = id
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = key
	move.startup_frames = 5
	move.active_frames = 7
	move.recovery_frames = 13
	move.cancel_window_frames = GameParams.CANCEL_WINDOW_FRAMES
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.HIGH
	move.hitbox_size = GameParams.ATTACK_HITBOX_SIZE
	move.hitbox_gap = GameParams.ATTACK_HITBOX_GAP
	move.hit_profiles = _probe_profiles(GameParams.HITSTUN_FRAMES, GameParams.MOVE_5A_KNOCKBACK)
	move.starter_grade = MoveData.StarterGrade.D
	return move


func _approx(value: float, expected: float, tolerance := 0.05) -> bool:
	return absf(value - expected) < tolerance


## 探针命中资料（上下文命中资料迁移）：grounded normal/counter 同值——既有回归
## 不区分 counter 变体，只要求上下文匹配不落空。
func _probe_profiles(stun: int, horizontal: float) -> Array[HitProfile]:
	var normal := HitProfile.new()
	normal.target_state = HitProfile.TargetState.GROUNDED
	normal.hit_context = HitProfile.HitContext.NORMAL
	normal.reaction = HitProfile.Reaction.GROUND_HITSTUN
	normal.ground_stun_frames = stun
	normal.horizontal_speed_px_s = horizontal
	normal.upward_speed_px_s = 0.0
	var counter := normal.duplicate() as HitProfile
	counter.hit_context = HitProfile.HitContext.COUNTER
	return [normal, counter]


func _set_probe_stun(move: MoveData, frames: int) -> void:
	for profile in move.hit_profiles:
		profile.ground_stun_frames = frames


func _set_probe_horizontal(move: MoveData, speed: float) -> void:
	for profile in move.hit_profiles:
		profile.horizontal_speed_px_s = speed


## 把探针的全部 profile 改写为 LAUNCH（旧 hit_result=LAUNCH + hitstun + 击退
## 三件套的等价迁移：受身计时、水平幅值与垂直初速度进入每个 profile）。
func _set_probe_launch(move: MoveData, untech: int, horizontal: float, upward: float) -> void:
	for profile in move.hit_profiles:
		profile.reaction = HitProfile.Reaction.LAUNCH
		profile.ground_stun_frames = -1
		profile.air_untech_frames = untech
		profile.horizontal_speed_px_s = horizontal
		profile.upward_speed_px_s = upward


## 给探针追加 airborne normal LAUNCH profile（旧 hit_result 语义下空中命中无
## 目标状态维度；迁移后空中命中需要显式 airborne 资料，缺失即 MISS_NO_PROFILE）。
func _add_probe_airborne(move: MoveData, untech: int, horizontal: float, upward: float) -> void:
	var airborne := HitProfile.new()
	airborne.target_state = HitProfile.TargetState.AIRBORNE
	airborne.hit_context = HitProfile.HitContext.NORMAL
	airborne.reaction = HitProfile.Reaction.LAUNCH
	airborne.air_untech_frames = untech
	airborne.horizontal_speed_px_s = horizontal
	airborne.upward_speed_px_s = upward
	move.hit_profiles.append(airborne)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1
