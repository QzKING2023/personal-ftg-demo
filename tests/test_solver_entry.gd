extends SceneTree
## Combo Solver 入口与操作说明（ftg-combat-foundation issue 19）：
## solve() 正式入口——共享招式表、可选显式起始战斗状态与搜索选项；缺省起始为
## 地面中立（空缓存/方向历史、地面中立木桩、固定接触位），默认左右面向分别验证
## 并镜像对拍；首招只枚举当前可执行的地面招式，空中招式须显式中间状态才可起手；
## 输出稳定排序的候选、起始状态说明与真实键位操作说明；一次性探针不修改活动会话，
## 非法表与训练场观察同一拒绝原因。
## 运行：godot --headless --path . -s res://tests/test_solver_entry.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0


func _initialize() -> void:
	print("")
	_test_solve_defaults_document_start_state()
	_test_default_run_verifies_both_facings()
	_test_first_candidates_ground_only_sorted()
	_test_routes_start_from_ground_moves_only()
	_test_guide_uses_real_keys_for_both_facings()
	_test_explicit_air_start_switches_candidates()
	_test_explicit_air_start_reports_air_route()
	_test_explicit_air_start_guide_documents_prologue()
	_test_explicit_air_start_landing_seam_not_claimed()
	_test_out_of_range_air_frames_refused()
	_test_outputs_are_stably_sorted()
	_test_solve_is_deterministic()
	_test_solve_does_not_modify_runtime_session()
	_test_solve_refuses_invalid_manifest_with_shared_reason()
	_test_solve_reflects_resource_changes()
	_test_key_map_matches_training_ground()
	print("")
	_metrics.emit("test_solver_entry")
	if _failures == 0:
		print("ALL SOLVER ENTRY TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 入口契约与起始状态说明 ---

func _test_solve_defaults_document_start_state() -> void:
	var report := _default_solve()
	_check(not report.refused, "solve() without arguments analyzes the shared manifest")
	var text := "\n".join(report.start_lines)
	_check("地面中立" in text and "空输入缓存" in text and "方向历史" in text,
		"start lines document the default ground-neutral start with empty buffer and direction history")
	_check("木桩地面中立" in text and "固定探针接触位" in text and ("%d px" % ComboSolver.PIN_DX) in text,
		"start lines document the neutral dummy and the fixed probe contact position")


func _test_default_run_verifies_both_facings() -> void:
	var report := _default_solve()
	_check(report.verified_facings == [1, -1], "the default run verifies right then left facing")
	_check(report.mirror_consistent, "both facings yield mirrored results on the default table")
	var mirror_note := ""
	for note in report.notes:
		if "镜像验证一致" in note:
			mirror_note = note
	_check(mirror_note != "", "a note records the successful facing-mirror verification")
	var start_text := "\n".join(report.start_lines)
	_check("+1" in start_text and "-1" in start_text, "start lines list both verified facings")
	# 搜索选项：只要单面向时不作镜像宣称。
	var opts := ComboSolver.SolverOptions.new()
	opts.facings = [1]
	var single := _metrics.solve(opts)
	_check(single.verified_facings == [1], "the facings option restricts verification to the requested facing")
	var mirror_claimed := false
	for note in single.notes:
		if "镜像" in note:
			mirror_claimed = true
	_check(not mirror_claimed, "a single-facing run makes no mirror claim")
	_check(not ("-1" in "\n".join(single.start_lines)), "a single-facing run lists only its own facing")


# --- 首招候选与起手约束 ---

func _test_first_candidates_ground_only_sorted() -> void:
	var report := _default_solve()
	var ids: Array[String] = []
	for line in report.first_candidates:
		ids.append(line.split("｜")[0])
	_check(ids == ["214C", "214D", "236C", "2A", "2B", "2C", "2D", "5A", "5B", "5C", "5D", "6A", "6D"],
		"first-move candidates enumerate the executable ground moves (standing and crouch) in stable id order (ticket 04 adds 214C; ticket 07 adds 2D and the 6D derivation)")
	var text := "\n".join(report.first_candidates)
	_check("方向 236 + K 键" in text and "方向 214 + J 键" in text and "方向 214 + K 键" in text,
		"derivative candidates spell out the direction notation and the real key")
	for air_or_throw in ["jA", "jB", "jC", "j5D", "j6D", "j2D", "BC"]:
		_check(not ids.has(air_or_throw),
			"air moves and the B+C throw never enumerate as first moves from the ground start")


func _test_routes_start_from_ground_moves_only() -> void:
	var report := _default_solve()
	var table := MoveData.default_table()
	var all_ground := true
	for route in report.routes:
		var move := table.get(route.move_ids[0]) as MoveData
		if move == null or move.stance != MoveData.Stance.GROUND:
			all_ground = false
	_check(all_ground, "every reported route starts from an executable ground move — air moves only enter via configured jump cancel")


# --- 操作说明（真实键位、双面向、等待帧）---

func _test_guide_uses_real_keys_for_both_facings() -> void:
	var report := _default_solve()
	var guide := "\n".join(report.guide_lines)
	_check("面向右" in guide and "面向左" in guide, "the guide covers both facings")
	_check("前=D/→ 后=A/←" in guide and "前=A/← 后=D/→" in guide,
		"each facing header maps forward/back onto the real direction keys")
	var route_line := ""
	for line in report.guide_lines:
		if line.begins_with("5A → 5B → 5D"):
			route_line = line
			break
	_check(route_line != "", "the 5A → 5B → 5D route has an operation guide")
	if route_line != "":
		_check("F1 按 U" in route_line and "F6 按 I" in route_line and "F13 按 J" in route_line,
			"guide presses use the real action keys U/I/J at the scheduled frames")
		_check("等 4 帧" in route_line and "等 6 帧" in route_line, "the guide states the wait frames between presses")
	## 票据 05：有效 236C 入口路线改经链式取消（如 2A/5A > … > 236C > 5D），
	## 直接 5A > 236C 前缀只剩断链残根（无回放输入）；折叠断言改为定位任一
	## 含 236C 按键的有效指南行。
	var derivative_line := ""
	for line in report.guide_lines:
		if "按 K（236C）" in line and "↓[S]" in line and not line.contains("断链路线"):
			derivative_line = line
			break
	_check(derivative_line != "", "a valid 236C-entry route has an operation guide with the quarter-circle fold")
	if derivative_line != "":
		_check("↓+前[S+D]" in derivative_line and "前[D]" in derivative_line,
			"the right-facing guide folds 236 into the real keys S, S+D, D")
	# 面向左分节：同一相对输入折叠为镜像物理键。
	var in_left_section := false
	var left_feed := false
	for line in report.guide_lines:
		if "面向左" in line:
			in_left_section = true
		elif in_left_section and "按 K（236C）" in line and not line.contains("断链路线"):
			left_feed = "↓+前[S+A]" in line and "前[A]" in line
			break
	_check(in_left_section and left_feed,
		"the left-facing guide mirrors the physical direction keys for the same relative input")


# --- 显式中间状态（空中起始）---

func _explicit_air_options() -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.start = ComboSolver.SolverStartState.new()
	opts.start.stance = MoveData.Stance.AIR
	return opts


func _test_explicit_air_start_switches_candidates() -> void:
	var report := _explicit_air_solve()
	var ids: Array[String] = []
	for line in report.first_candidates:
		ids.append(line.split("｜")[0])
	_check(ids == ["j2D", "j5D", "j6D", "jA", "jB", "jC"],
		"an explicitly provided air start enumerates only the currently executable air moves in lexicographic order (air D series with ticket 08: j2D/j5D/j6D on J-key D notations, jC delivered with ticket 07)")
	var text := "\n".join(report.start_lines)
	_check("空中" in text and "第 1 个空中帧" in text,
		"start lines describe the explicitly provided air state and its probe prologue")


func _test_explicit_air_start_reports_air_route() -> void:
	var report := _explicit_air_solve()
	var route := _find_route(report, ["jA", "jB", "j5D"])
	_check(route == null,
		"the jA → jB → j5D chain is not claimed from the explicit air start (ticket 08: j5D startup 6 lands its 3rd hit past the dummy's natural recovery that the old jD frame-14 hit barely beat)")
	var dive := _find_route(report, ["jA", "j6D"])
	_check(dive != null and dive.timing_valid,
		"the dive chain jA → j6D is verified from the explicit air start (ticket 08)")
	if dive != null:
		_check(dive.hit_frames == [5, 12],
			"dive route hits on frames 5/12 measured from the first air frame")
		_check(dive.combo_hits == 2, "dive route counts 2 hits")
		_check(not dive.inputs.is_empty(), "the explicit-state route still carries frame-by-frame replay inputs")


func _test_explicit_air_start_guide_documents_prologue() -> void:
	var report := _explicit_air_solve()
	var guide := "\n".join(report.guide_lines)
	_check("Space 垂直起跳" in guide and "起跳准备" in guide,
		"the air-start guide documents the Space prologue its route frames are measured from")


func _test_explicit_air_start_landing_seam_not_claimed() -> void:
	var report := _explicit_air_solve()
	var edge := _find_edge(report, "jB", "5D", ComboSolver.EdgeKind.LANDING_CANCEL)
	_check(edge != null and not edge.valid,
		"the landing seam is not claimed as valid from an explicit air start")
	if edge != null:
		_check("落地恢复" in edge.reason,
			"the exclusion reason names the recovery lock regardless of starting stance")


# --- 稳定排序与确定性 ---

func _test_out_of_range_air_frames_refused() -> void:
	# 空中起始的 air_frames 超出滞空（落地后不再是空中姿态）：拒绝分析并指出
	# 修正方向，不静默钳制成别的起始条件。
	var opts := ComboSolver.SolverOptions.new()
	opts.start = ComboSolver.SolverStartState.new()
	opts.start.stance = MoveData.Stance.AIR
	opts.start.air_frames = GameParams.PLAYER_JUMP_AIRTIME_FRAMES
	var report := _metrics.solve(opts)
	_check(report.refused and "滞空" in report.refusal_reason,
		"an air start at or beyond the airtime is refused with a locatable reason")
	_check(report.edges.is_empty() and report.routes.is_empty() and report.first_candidates.is_empty(),
		"the refused start state produces no candidates, routes or edges")


func _test_outputs_are_stably_sorted() -> void:
	var report := _default_solve()
	var edge_keys: Array[String] = []
	for edge in report.edges:
		edge_keys.append("%s|%s|%d" % [edge.from_id, edge.to_id, edge.kind])
	var sorted_edges := edge_keys.duplicate()
	sorted_edges.sort()
	_check(edge_keys == sorted_edges, "edges are stably sorted by from → to → kind")
	var route_keys: Array[String] = []
	for route in report.routes:
		route_keys.append(route.label())
	var sorted_routes := route_keys.duplicate()
	sorted_routes.sort()
	_check(route_keys == sorted_routes, "routes are stably sorted by their labels")


func _test_solve_is_deterministic() -> void:
	_check(_default_solve().to_lines() == _default_solve().to_lines(),
		"solving the same table twice yields identical reports, guide included")


# --- 一次性探针与共享资源一致性 ---

func _test_solve_does_not_modify_runtime_session() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(ComboSolver.PIN_DX, 0)
	session.step(FrameInput.make(0, false, "A"))
	for i in range(5):
		session.step(FrameInput.new())
	var before := _snapshot_session(session)
	_default_solve()
	_explicit_air_solve()
	var after := _snapshot_session(session)
	_check(before == after, "running solve() leaves every observable field of a live session untouched")
	_check(session.player_move_id == "5A" and session.combo_hits == 1,
		"the live session is still inside its 5A hit-confirmed combo, unbothered by probes")


func _test_solve_refuses_invalid_manifest_with_shared_reason() -> void:
	var broken := MoveData.default_table()["5A"] as MoveData
	broken.base_damage = -1
	ResourceSaver.save(broken, "user://solver_entry_bad_move.tres")
	var manifest := MoveManifest.new()
	manifest.move_paths = ["user://solver_entry_bad_move.tres"]
	ResourceSaver.save(manifest, "user://solver_entry_bad_manifest.tres")
	var opts := ComboSolver.SolverOptions.new()
	opts.manifest_path = "user://solver_entry_bad_manifest.tres"
	var report := _metrics.solve(opts)
	var loaded := MoveTable.load_manifest("user://solver_entry_bad_manifest.tres")
	_check(report.refused, "solve() refuses the invalid manifest instead of analyzing it")
	_check(report.refusal_reason == loaded.first_error(),
		"the refusal reason is exactly the shared loader's reason (the training ground shows the same)")
	_check(report.edges.is_empty() and report.routes.is_empty() and report.first_candidates.is_empty(),
		"a refused report claims no candidates, routes or cycles")


func _test_solve_reflects_resource_changes() -> void:
	var table := MoveData.default_table()
	(table["5B"] as MoveData).startup_frames = 4
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	var report := _metrics.solve(opts)
	var ab := _find_edge(report, "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(ab != null and ab.valid, "the edited table still yields the 5A → 5B edge")
	if ab != null:
		_check(ab.hit_age == 5, "editing the shared move's startup moves the timing report (earliest hit age 7 → 5)")
		_check("前摇 4 帧" in ab.reason, "the edge reason quotes the edited startup value")
	var default_ab := _find_edge(_default_solve(), "5A", "5B", ComboSolver.EdgeKind.CHAIN_CANCEL)
	_check(default_ab != null and default_ab.hit_age == 7,
		"the default manifest still reports the untouched baseline")


func _test_key_map_matches_training_ground() -> void:
	_check(ComboSolver.ACTION_PHYSICAL_KEYS == preload("res://scripts/main.gd").ACTION_PHYSICAL_KEYS,
		"the guide's action-key map matches the training ground layout")


# --- 辅助 ---

func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int = -1) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id and (kind < 0 or edge.kind == kind):
			return edge
	return null


func _find_route(report: ComboSolver.SolverReport, move_ids: Array[String]) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
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


func _approx(value: float, expected: float, tolerance := 0.05) -> bool:
	return absf(value - expected) < tolerance


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1

func _default_solve() -> ComboSolver.SolverReport:
	return _metrics.solve_reused("default")

func _explicit_air_solve() -> ComboSolver.SolverReport:
	return _metrics.solve_reused("explicit-air", _explicit_air_options())

