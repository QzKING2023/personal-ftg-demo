extends SceneTree
## Combo Solver 时序与空间证明分层（ftg-combat-foundation issue 22）：
## 无空间数据的路线只标记 timing-valid——固定探针接触位是几何假设，不构成
## 空间证明；调用方提供空间数据（SolverOptions.spatial）后，空间探针在地面、
## 左右镜像的 48/64/80 px 三组身体中心水平距离上逐条复验 timing-valid 路线并
## 附 spatial-valid；报告明确不搜索走位、中立、墙角、推挤、跨身或屏幕边界；
## 空间失败点名具体站位与碰撞条件，配置缺口与时序失败不作空间失败上报。
## 运行：godot --headless --path . -s res://tests/test_solver_spatial.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0


func _initialize() -> void:
	print("")
	_test_without_spatial_data_routes_are_timing_valid_only()
	_test_spatial_data_verifies_distance_grid_both_facings()
	_test_spatial_failure_names_standing_and_collision()
	_test_gaps_and_timing_exclusions_never_become_spatial()
	_test_mismatched_body_rect_refused()
	_test_air_start_with_spatial_refused()
	_test_report_declares_no_search_scope()
	_test_spatial_deterministic_and_isolated()
	print("")
	_metrics.emit("test_solver_spatial")
	if _failures == 0:
		print("ALL SOLVER SPATIAL TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 分层一：无空间数据 → 仅 timing-valid ---


func _test_without_spatial_data_routes_are_timing_valid_only() -> void:
	var report := _default_solve()
	_check(report.routes.size() > 0, "the default table reports routes to layer")
	## 票据 02 起默认表含诚实截断路线（A 起手时间层衰减使部分第三击不成立）：
	## 截断条目不冒充 timing-valid，必须带断点注记；成立路线仍逐条 timing-valid。
	var truncated_count := 0
	for route in report.routes:
		if not route.timing_valid:
			truncated_count += 1
			_check("断开" in route.note, "a truncated default route carries its break note")
		_check(route.spatial_state == ComboSolver.SolverRoute.SpatialState.UNVERIFIED,
			"without spatial data every route stays spatially unverified")
		_check(route.spatial_failures.is_empty(),
			"no spatial failure is invented without spatial data")
	_check(truncated_count > 0, "the A-starter decay produces at least one honestly truncated default route")
	var route_lines := _route_lines(report)
	_check(route_lines.size() == report.routes.size(),
		"every route has a readable line in the report")
	for line in route_lines:
		if "timing 未成立" in line:
			_check(not ("spatial-valid" in line),
				"a truncated route line never claims spatial-valid")
		else:
			_check("timing-valid" in line and "空间未验证" in line,
				"each verified route line is marked timing-valid with the spatial layer unverified")
			_check(not ("spatial-valid" in line),
				"no route line claims spatial-valid without spatial data")
	var section := "\n".join(report.spatial_lines)
	_check("未提供空间数据" in section and "不构成空间证明" in section,
		"the spatial section states that no spatial data was provided and the fixed contact is not a spatial proof")


# --- 分层二：提供空间数据 → 48/64/80 px × 左右镜像复验 ---


func _test_spatial_data_verifies_distance_grid_both_facings() -> void:
	var report := _spatial_solve()
	## 新基线调校命中框更短：5A（30×24、gap 2）的远缘恰为 56 px、票据 02 的 2A
	## （30×20、gap 1）远缘 55 px——80 px 站位与身体矩形相邻（Godot 相邻矩形不算
	## 相交），5A/2A 起手的路线在 80 px 空间失败、其余站位与其余起手（2B/2C/5B/5C/
	## 5D/6A/236C…）路线空间成立。失败被诚实上报，不隐藏也不升级为时序结论。
	for route in report.routes:
		if not route.timing_valid:
			_check(route.spatial_state == ComboSolver.SolverRoute.SpatialState.UNVERIFIED,
				"a truncated route is not spatially re-verified (timing failure is not a spatial claim)")
			continue
		if route.move_ids[0] == "5A" or route.move_ids[0] == "2A":
			_check(route.spatial_state == ComboSolver.SolverRoute.SpatialState.INVALID,
				"with spatial data a 5A/2A-started route honestly fails the 80 px standing (tuning hitbox reach 55–56 px, boundary touch does not intersect)")
			var joined := "；".join(route.spatial_failures)
			_check("80 px" in joined and not ("48 px" in joined) and not ("64 px" in joined),
				"the short-reach boundary failure names only the 80 px standing")
		else:
			_check(route.spatial_state == ComboSolver.SolverRoute.SpatialState.VALID,
				"with spatial data every other verified default route still connects at 48/64/80 px")
	var route_lines := _route_lines(report)
	for line in route_lines:
		if line.begins_with("5A ") or line.begins_with("2A "):
			_check("空间失败" in line or "timing 未成立" in line,
				"5A/2A-started route lines keep the honest spatial-failure (or truncation) mark, never spatial-valid")
		else:
			## 票据 05：非 5A/2A 起手的走查也可能经来源限定 5D > 5B 断链截断——
			## 截断行保留诚实的 timing 未成立标记，不计入 spatial-valid。
			_check("spatial-valid" in line or "timing 未成立" in line,
				"each verified route line carries the spatial-valid mark (truncated walks keep the honest timing-failure mark)")
	var section := "\n".join(report.spatial_lines)
	for token in ["48", "64", "80", "+1", "-1", "spatial-valid"]:
		_check(token in section, "the spatial section documents the grid item %s" % token)
	_check(report.mirror_consistent, "spatial verification stays mirror-consistent across both facings")


# --- 分层三：空间失败点名站位与碰撞条件 ---


func _test_spatial_failure_names_standing_and_collision() -> void:
	# 5R 的命中框够到 72 px（48 + gap 4 + 宽 20）：timing 探针 70 px 能命中
	# （timing-valid 保持），空间网格 48/64 px 成立、80 px 失败——空间失败
	# 点名 80 px 与「命中框 × 身体矩形」碰撞条件，不改判 timing 结论。
	var table := MoveData.default_table()
	var short_reach := _injected_move("5R", "R")
	short_reach.hitbox_size = Vector2(20, 60)
	short_reach.hitbox_gap = 4.0
	table["5R"] = short_reach
	(table["5A"] as MoveData).cancel_targets.append("5R")
	var report := _metrics.solve(_spatial_options(table))
	var route := _find_route(report, ["5A", "5R"])
	_check(route != null, "the short-reach route is walked from the configured cancel")
	if route != null:
		_check(route.timing_valid, "the route stays timing-valid at the fixed 70 px contact")
		_check(route.spatial_state == ComboSolver.SolverRoute.SpatialState.INVALID,
			"the route fails the spatial grid at 80 px while 48/64 px hold")
		var joined := "；".join(route.spatial_failures)
		_check("80 px" in joined and "命中框" in joined and "身体矩形" in joined,
			"the spatial failure names the standing (80 px) and the collision condition (hitbox vs body rect)")
		_check(not ("48 px" in joined) and not ("64 px" in joined),
			"the nearer standings are not reported as failures")
		for line in _route_lines(report):
			if line.begins_with("5A → 5R："):
				_check("timing-valid" in line and "空间失败" in line,
					"the route line keeps timing-valid while flagging the spatial failure")
	# 对照：同表的非 5A 起手默认路线不受短 reach 影响（仍然 spatial-valid）。
	## 可读路线报告上限（票据 09 起 16 条）触顶后代表路线不再保证入默认报告；
	## 该路线经精确路线查询解析并按同一空间网格复验（票据 09 验收尾巴）。
	var full_ids: Array[String] = ["5B", "5D"]
	var full_report := _metrics.route_report(full_ids, _spatial_options(table))
	var full := _find_route(full_report, full_ids)
	_check(full != null and full.spatial_state == ComboSolver.SolverRoute.SpatialState.VALID,
		"the default-reach route on the same table stays spatial-valid")


# --- 分层四：配置缺口与时序失败不作空间失败 ---


func _test_gaps_and_timing_exclusions_never_become_spatial() -> void:
	var plain := _default_solve()
	var spatial := _spatial_solve()
	_check(spatial.gaps.size() == plain.gaps.size() and spatial.gaps.size() > 0,
		"providing spatial data does not change the config-gap set")
	for i in range(spatial.gaps.size()):
		_check(spatial.gaps[i].reason == plain.gaps[i].reason,
			"gap reasons keep their missing-configuration wording under spatial verification")
	# 时序失败（挥空 / 命中晚于木桩恢复）的排除理由保持时序措辞，不转述为空间失败；
	# 被排除的招式不出现在任何空间失败里。
	var table := MoveData.default_table()
	var whiffy := _injected_move("5W", "W")
	whiffy.hitbox_size = Vector2(8, 8)
	whiffy.hitbox_gap = 500.0
	table["5W"] = whiffy
	var slow := _injected_move("5H", "H")
	slow.startup_frames = 25
	slow.active_frames = 2
	slow.recovery_frames = 8
	table["5H"] = slow
	(table["5A"] as MoveData).cancel_targets.append("5W")
	(table["5A"] as MoveData).cancel_targets.append("5H")
	var report := _metrics.solve(_spatial_options(table))
	var whiff_edge := _find_edge(report, "5A", "5W")
	_check(whiff_edge != null and not whiff_edge.valid, "the whiffed pair stays excluded")
	if whiff_edge != null:
		_check("挥空" in whiff_edge.reason and "空间" not in whiff_edge.reason,
			"the whiff exclusion keeps its timing wording, with no spatial wording")
	var slow_edge := _find_edge(report, "5A", "5H")
	_check(slow_edge != null and not slow_edge.valid, "the slow pair stays excluded")
	if slow_edge != null:
		_check("自然受身" in slow_edge.reason and "空间" not in slow_edge.reason,
			"the recovery-timeout exclusion keeps its timing wording")
	for route in report.routes:
		for failure in route.spatial_failures:
			_check(not ("5W" in failure) and not ("5H" in failure),
				"excluded moves never appear inside spatial failures")


# --- 空间数据非法：拒绝分析 ---


func _test_mismatched_body_rect_refused() -> void:
	var opts := _spatial_options()
	opts.spatial.body_size = Vector2(40, 70)
	var report := _metrics.solve(opts)
	_check(report.refused, "a body rect differing from the runtime geometry refuses the analysis")
	_check("身体矩形" in report.refusal_reason and "运行时" in report.refusal_reason,
		"the refusal names the mismatch against the runtime geometry")
	_check(report.routes.is_empty() and report.edges.is_empty() and report.cycles.is_empty(),
		"the refused spatial data produces no routes, edges or cycles")


func _test_air_start_with_spatial_refused() -> void:
	var opts := _spatial_options()
	opts.start = ComboSolver.SolverStartState.new()
	opts.start.stance = MoveData.Stance.AIR
	var report := _metrics.solve(opts)
	_check(report.refused and "地面" in report.refusal_reason,
		"spatial verification with an explicit air start is refused — the v1 grid is ground-only")
	_check(report.routes.is_empty() and report.first_candidates.is_empty(),
		"the refused combination produces no routes or candidates")


# --- 范围声明 ---


func _test_report_declares_no_search_scope() -> void:
	for report in [_default_solve(), _spatial_solve()]:
		var text := "\n".join(report.to_lines())
		_check("不搜索" in text, "the report declares what the spatial layer does not search")
		for term in ["走位", "中立", "墙角", "推挤", "跨身", "屏幕边界"]:
			_check(term in text, "the report names %s as outside the spatial search scope" % term)


# --- 确定性与运行时隔离 ---


func _test_spatial_deterministic_and_isolated() -> void:
	var first := _spatial_solve()
	_check(_spatial_solve().to_lines() == first.to_lines(),
		"solving twice with spatial data yields identical reports")
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	session.step(FrameInput.make(0, false, "A"))
	for i in range(5):
		session.step(FrameInput.new())
	var before := _snapshot_session(session)
	_spatial_solve()
	var after := _snapshot_session(session)
	_check(before == after, "spatial probes leave every observable field of a live session untouched")
	_check(session.player_move_id == "5A" and session.combo_hits == 1,
		"the live session is still inside its 5A hit-confirmed combo, unbothered by spatial probes")


# --- 辅助 ---


func _spatial_options(table: Dictionary = {}) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.spatial = ComboSolver.SolverSpatialData.new()
	if not table.is_empty():
		opts.move_table = table
	return opts


func _route_lines(report: ComboSolver.SolverReport) -> Array[String]:
	var lines: Array[String] = []
	for line in report.to_lines():
		# 可读路线行以「标签：命中帧 …」开头；空间分层的失败明细也以标签开头，
		# 以「命中帧 」限定只取路线行本身。
		if not ("命中帧 " in line):
			continue
		for route in report.routes:
			if line.begins_with(route.label() + "："):
				lines.append(line)
				break
	return lines


func _find_route(report: ComboSolver.SolverReport, move_ids: Array[String]) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int = -1) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id and (kind < 0 or edge.kind == kind):
			return edge
	return null


func _snapshot_session(session: CombatSession) -> Array:
	return [
		session.player_position, session.player_velocity, session.player_facing,
		session.player_phase, session.player_on_ground, session.player_move_id,
		session.dummy_position, session.dummy_velocity, session.dummy_hp,
		session.dummy_state, session.dummy_on_ground, session.dummy_hitstun_left,
		session.combo_hits, session.combo_active, session.combo_total_damage,
		session.combo_last_scale, session.combo_last_damage,
	]


## 测试注入招式：字段齐全的合法打击招式（注入表只喂给 Solver 探针，不经过
## MoveTable 校验，键名可超出 A–D）。
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

func _default_solve() -> ComboSolver.SolverReport:
	return _metrics.solve_reused("default")

func _spatial_solve() -> ComboSolver.SolverReport:
	return _metrics.solve_reused("spatial", _spatial_options())

