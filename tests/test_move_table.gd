extends SceneTree
## 共享招式表 seam 测试（issue 11）：本地类型化资源 + manifest 统一加载 + 整表校验。
## 覆盖：两处消费者（CombatSession/训练场 与 Combo Solver）读同一份已校验数据、
## 修改代表字段后行为与报告同步变化、非法表整表拒绝且错误可定位（资源来源、
## 招式 id、字段、冲突原因）、不静默修正/跳过/回退旧 GameParams。
## 运行：godot --headless --path . -s res://tests/test_move_table.gd

var _failures := 0


func _initialize() -> void:
	_test_default_manifest_loads_shared_table()
	_test_default_table_entries_match_manifest()
	_test_loads_return_fresh_copies()
	_test_missing_strike_fields_reject_whole_table()
	_test_throw_requires_range_and_fixed_startup()
	_test_negative_frames_rejected()
	_test_unknown_enum_rejected()
	_test_illegal_direction_predicate_rejected()
	_test_contradictory_fields_rejected()
	_test_cross_move_references_rejected()
	_test_same_binding_different_priority_allowed()
	_test_command_tier_and_lenient_validation()
	_test_hand_edited_tres_missing_field_rejected()
	_test_tres_type_error_rejected()
	_test_manifest_errors_rejected()
	_test_no_gameparams_fallback_on_rejection()
	_test_startup_edit_syncs_session_and_solver()
	_test_damage_edit_syncs_session_and_solver()
	_test_attribute_edit_syncs_session_and_solver()
	_test_cancel_edit_syncs_session_and_solver()
	_test_solver_refuses_invalid_manifest_with_same_reason()
	print("")
	if _failures == 0:
		print("ALL MOVE TABLE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 共享资源加载 ---

func _test_default_manifest_loads_shared_table() -> void:
	var result := MoveTable.load_default()
	_check(result.ok, "default manifest loads and validates")
	_check(result.errors.is_empty(), "default manifest reports no errors")
	var expected_ids := ["5A", "5B", "5C", "236C", "jA", "jB", "jD", "5D", "214D"]
	_check(result.moves.keys() == expected_ids, "table preserves manifest order and ids (stable enumeration)")
	for move_id in expected_ids:
		var move := result.moves[move_id] as MoveData
		_check(move != null and move.move_id == move_id, "%s carries its own stable id, not the file name" % move_id)


func _test_default_table_entries_match_manifest() -> void:
	# 首版冻结数值（spec：招式数据边界与校验）：startup/active/recovery 与基础伤害。
	var result := MoveTable.load_default()
	var expected := {
		"5A": [5, 7, 13, 10], "5B": [4, 6, 13, 12], "5C": [6, 5, 16, 14],
		"236C": [6, 5, 18, 18], "5D": [5, 7, 15, 18], "214D": [7, 5, 20, 22],
		"jA": [4, 6, 10, 8], "jB": [4, 6, 12, 12], "jD": [4, 7, 14, 20],
	}
	for move_id in expected:
		var move := result.moves[move_id] as MoveData
		var values: Array = expected[move_id]
		_check([move.startup_frames, move.active_frames, move.recovery_frames, move.base_damage] == values,
			"%s carries the frozen first-edition windows and damage" % move_id)
	var launcher := result.moves["236C"] as MoveData
	_check(launcher.direction_derivation == "236C" and launcher.hit_result == MoveData.HitResult.LAUNCH,
		"236C declares its direction derivation and launch result")
	_check(launcher.jump_cancel_targets == ["jA"], "236C declares its jump cancel target")
	var air := result.moves["jD"] as MoveData
	_check(air.stance == MoveData.Stance.AIR and air.is_finisher, "jD is an air finisher")
	for move_id in result.moves:
		var move := result.moves[move_id] as MoveData
		_check(move.move_kind == MoveData.MoveKind.STRIKE, "%s declares move kind strike" % move_id)
		_check(move.action_key != "" and move.priority >= 0, "%s declares input binding and priority" % move_id)
		_check(move.attack_attribute != MoveData.AttackAttribute.UNSET, "%s declares an attack attribute" % move_id)


func _test_loads_return_fresh_copies() -> void:
	# 多次加载返回独立副本：修改一份不会污染其他消费者（运行时与 Solver 同表不同实例）。
	var first := MoveTable.load_default()
	var second := MoveTable.load_default()
	_check(first.moves["5A"] != second.moves["5A"], "two loads return distinct move instances")
	(first.moves["5A"] as MoveData).base_damage = 999
	_check((second.moves["5A"] as MoveData).base_damage == 10, "mutating one copy does not leak into other loads")


# --- 整表校验：打击/投技必填字段 ---

func _test_missing_strike_fields_reject_whole_table() -> void:
	for field in ["base_damage", "attack_attribute", "hitbox_size", "hit_result", "hitstun_frames", "knockback", "knockback_up", "action_key"]:
		var moves := _valid_strike_list()
		var move: MoveData = moves[0]
		if field == "attack_attribute":
			move.set("attack_attribute", MoveData.AttackAttribute.UNSET)
		elif field == "hit_result":
			move.set("hit_result", MoveData.HitResult.UNSET)
		elif field == "hitbox_size":
			move.hitbox_size = Vector2.ZERO
		elif field == "action_key":
			move.action_key = ""
		elif field == "base_damage":
			move.base_damage = 0
		elif field == "hitstun_frames":
			move.hitstun_frames = 0
		else:
			move.set(field, -1)
		var errors := MoveTable.validate(moves)
		_check(not errors.is_empty(), "strike missing %s rejects the table" % field)
		if not errors.is_empty():
			_check(errors[0].contains("5A") and errors[0].contains(field),
				"rejection for %s names the move id and field" % field)
	# 同表的合法招式不因另一招非法而被跳过修正——整表拒绝、不返回部分表。
	var broken := _valid_strike_list()
	(broken[0] as MoveData).base_damage = 0
	var result := _validate_to_result(broken)
	_check(not result.ok and result.moves.is_empty(), "rejected table exposes no partial move table")


func _test_throw_requires_range_and_fixed_startup() -> void:
	var throw := _valid_throw()
	var errors := MoveTable.validate([throw])
	_check(errors.is_empty(), "throw with throw_range and startup 5 is legal")
	var no_range := _valid_throw()
	no_range.throw_range = 0
	errors = MoveTable.validate([no_range])
	_check(not errors.is_empty() and errors[0].contains("throw_range"),
		"throw without throw_range is rejected on the throw_range field")
	var slow_throw := _valid_throw()
	slow_throw.startup_frames = 7
	errors = MoveTable.validate([slow_throw])
	_check(not errors.is_empty() and errors[0].contains("startup_frames") and errors[0].contains("5"),
		"throw startup must stay the fixed 5f domain rule, not resource-overridable")


# --- 类型/帧数/枚举/方向谓词/矛盾字段 ---

func _test_negative_frames_rejected() -> void:
	for field in ["startup_frames", "active_frames", "recovery_frames", "cancel_window_frames", "hitstun_frames"]:
		var moves := _valid_strike_list()
		(moves[0] as MoveData).set(field, -3)
		var errors := MoveTable.validate(moves)
		_check(not errors.is_empty() and errors[0].contains(field),
			"negative %s is rejected naming the field" % field)


func _test_unknown_enum_rejected() -> void:
	var moves := _valid_strike_list()
	(moves[0] as MoveData).set("attack_attribute", 99)
	var errors := MoveTable.validate(moves)
	_check(not errors.is_empty(), "unknown attack attribute enum value is rejected")
	if not errors.is_empty():
		_check(errors[0].contains("attack_attribute") and errors[0].contains("99"),
			"unknown enum error names the field and the offending value")
	var bad_result := _valid_strike_list()
	(bad_result[0] as MoveData).set("hit_result", 42)
	errors = MoveTable.validate(bad_result)
	_check(not errors.is_empty() and errors[0].contains("hit_result"), "unknown hit result enum value is rejected")


func _test_illegal_direction_predicate_rejected() -> void:
	for derivation in ["25C", "056C", "236", "236CC", "235"]:
		var moves := _valid_strike_list()
		(moves[0] as MoveData).direction_derivation = derivation
		var errors := MoveTable.validate(moves)
		_check(not errors.is_empty() and errors[0].contains("direction_derivation"),
			"illegal direction predicate %s is rejected on the derivation field" % derivation)
	# 末位键与声明的输入绑定矛盾也是非法派生。
	var mismatch := _valid_strike_list()
	(mismatch[0] as MoveData).direction_derivation = "236D"
	var errors := MoveTable.validate(mismatch)
	_check(not errors.is_empty() and errors[0].contains("direction_derivation"),
		"derivation key mismatching the declared action key is rejected")


func _test_contradictory_fields_rejected() -> void:
	# 收尾招式声明取消目标。
	var finisher := _valid_strike_list()
	(finisher[0] as MoveData).is_finisher = true
	(finisher[0] as MoveData).cancel_targets = ["5B"]
	var errors := MoveTable.validate(finisher)
	_check(not errors.is_empty() and errors[0].contains("cancel_targets"),
		"finisher with cancel targets is a contradictory field combination")
	# 空中招式声明 jump cancel 目标。
	var air_jump := _valid_strike_list()
	(air_jump[0] as MoveData).stance = MoveData.Stance.AIR
	(air_jump[0] as MoveData).jump_cancel_targets = ["jA"]
	errors = MoveTable.validate(air_jump)
	_check(not errors.is_empty() and errors[0].contains("jump_cancel_targets"),
		"air move declaring jump cancel targets is contradictory")
	# 地面招式声明落地接续/额外落地恢复。
	var ground_landing := _valid_strike_list()
	(ground_landing[0] as MoveData).landing_cancel_targets = ["5D"]
	errors = MoveTable.validate(ground_landing)
	_check(not errors.is_empty() and errors[0].contains("landing_cancel_targets"),
		"ground move declaring landing continuation is contradictory")
	# 打击招式声明投距。
	var strike_range := _valid_strike_list()
	(strike_range[0] as MoveData).throw_range = 64.0
	errors = MoveTable.validate(strike_range)
	_check(not errors.is_empty() and errors[0].contains("throw_range"),
		"strike declaring throw_range is contradictory")
	# 投技声明单键绑定。
	var throw_key := _valid_throw()
	throw_key.action_key = "B"
	errors = MoveTable.validate([throw_key])
	_check(not errors.is_empty() and errors[0].contains("action_key"),
		"throw declaring a single action key is contradictory (B+C combo is the domain rule)")


func _test_cross_move_references_rejected() -> void:
	# 取消目标引用不存在的招式。
	var dangling := _valid_strike_list()
	(dangling[0] as MoveData).cancel_targets = ["ZZ"]
	var errors := MoveTable.validate(dangling)
	_check(not errors.is_empty() and errors[0].contains("cancel_targets") and errors[0].contains("ZZ"),
		"dangling cancel target is rejected naming the missing move id")
	# 稳定 id 重复。
	var dup := _valid_strike_list()
	dup.append(_valid_strike("5A", "A"))
	errors = MoveTable.validate(dup)
	_check(not errors.is_empty() and errors[0].contains("重复"),
		"duplicate stable ids across resources are rejected")
	# 同姿态同输入绑定同优先级并列。
	var tie := _valid_strike_list()
	var rival := _valid_strike("5H", "A")
	tie.append(rival)
	errors = MoveTable.validate(tie)
	_check(not errors.is_empty() and errors[0].contains("并列"),
		"two moves sharing stance+binding+priority are an illegal tie")
	_check(errors[0].contains("5A") and errors[0].contains("5H"), "tie error names both conflicting moves")


func _test_same_binding_different_priority_allowed() -> void:
	# 同绑定不同优先级是可解析配置（CONTEXT：同层按优先级选择，仍并列才非法）。
	var moves := _valid_strike_list()
	var rival := _valid_strike("5H", "A")
	rival.priority = 3
	moves.append(rival)
	var errors := MoveTable.validate(moves)
	_check(errors.is_empty(), "same binding with distinct priorities is a legal, resolvable table")
	# 运行时按优先级选招：同帧按 A 应选中优先级更高的 5H。
	if errors.is_empty():
		var table := {}
		for move in moves:
			table[(move as MoveData).move_id] = move
		var session := CombatSession.new(table)
		session.dummy_position = session.player_position + Vector2(70, 0)
		session.step(FrameInput.make(0, false, "A"))
		_check(session.player_move_id == "5H", "runtime resolves the same binding by declared priority")


func _test_command_tier_and_lenient_validation() -> void:
	# 指令分层校验（issue 13）：同姿态+同绑定+同层级+同优先级仍是并列——不同方向
	# 记法也不放开（宽松/严格记法可能同时命中同一输入，无确定性选择）；同绑定同
	# 优先级不同层级由「超必杀 > 普通必杀 > 普通拳脚」解析，是合法配置；未知层级
	# 枚举值拒绝；宽松声明挂在没有任何方向记法的招式上属于矛盾字段。
	var tiered := _valid_strike_list()
	var super_move := _valid_strike("SD", "A")
	super_move.direction_derivation = "236236A"
	super_move.command_tier = MoveData.CommandTier.SUPER
	tiered.append(super_move)
	var errors := MoveTable.validate(tiered)
	_check(errors.is_empty(), "same binding and priority across different tiers is resolvable and legal")

	var tier_tie := _valid_strike_list()
	var lenient := _valid_strike("623A", "A")
	lenient.direction_derivation = "623A"
	lenient.lenient_command = true
	lenient.command_tier = MoveData.CommandTier.SPECIAL
	var strict := _valid_strike("236A", "A")
	strict.direction_derivation = "236A"
	strict.command_tier = MoveData.CommandTier.SPECIAL
	tier_tie.append(lenient)
	tier_tie.append(strict)
	errors = MoveTable.validate(tier_tie)
	_check(not errors.is_empty() and errors[0].contains("并列"),
		"same stance+binding+tier+priority with different notations is still an illegal tie")
	_check(errors[0].contains("623A") and errors[0].contains("236A"), "tier tie error names both conflicting moves")

	var bad_tier := _valid_strike_list()
	(bad_tier[0] as MoveData).command_tier = 99
	errors = MoveTable.validate(bad_tier)
	_check(not errors.is_empty() and errors[0].contains("command_tier"),
		"unknown command tier enum value is rejected naming the field")

	var lenient_plain := _valid_strike_list()
	(lenient_plain[0] as MoveData).lenient_command = true
	errors = MoveTable.validate(lenient_plain)
	_check(not errors.is_empty() and errors[0].contains("lenient_command"),
		"lenient command without any direction notation is a contradictory field")


# --- 文件级加载与手改资源 ---

func _test_hand_edited_tres_missing_field_rejected() -> void:
	# 设计者手改 .tres 删掉伤害行：加载后是哨兵缺省值，整表拒绝并指出字段。
	var paths := _write_valid_table("mt_hand_edit", 1)
	var move_path: String = paths["moves"][0]
	_remove_property_line(move_path, "base_damage")
	var result := MoveTable.load_manifest(paths["manifest"])
	_check(not result.ok, "hand-edited tres missing a core field rejects the whole table")
	if not result.ok:
		_check(result.errors[0].contains(move_path) and result.errors[0].contains("5A") and result.errors[0].contains("base_damage"),
			"rejection reports resource source, move id and field for the hand edit")


func _test_tres_type_error_rejected() -> void:
	# .tres 内类型错误（字符串写进帧数字段）：加载失败或按缺省处理，两种都必须拒绝。
	var paths := _write_valid_table("mt_type_error", 1)
	var move_path: String = paths["moves"][0]
	_replace_property_line(move_path, "startup_frames", "startup_frames = \"five\"")
	var result := MoveTable.load_manifest(paths["manifest"])
	_check(not result.ok, "tres with a type error in a frame field rejects the table")
	if not result.ok:
		_check(result.errors[0].contains(move_path) or result.errors[0].contains(paths["manifest"]),
			"type-error rejection names the resource source")


func _test_manifest_errors_rejected() -> void:
	# 清单本身不存在。
	var missing := MoveTable.load_manifest("user://mt_missing_manifest.tres")
	_check(not missing.ok and missing.errors[0].contains("user://mt_missing_manifest.tres"),
		"missing manifest path is rejected naming the manifest source")
	# 清单引用不存在的招式资源。
	var empty_ref := _write_valid_table("mt_missing_move", 1)
	var manifest_path: String = empty_ref["manifest"]
	_replace_property_line(manifest_path, "move_paths",
		"move_paths = Array[String]([\"user://mt_no_such_move.tres\"])")
	var result := MoveTable.load_manifest(manifest_path)
	_check(not result.ok, "manifest referencing a missing move file is rejected")
	if not result.ok:
		_check(result.errors[0].contains(manifest_path) and result.errors[0].contains("user://mt_no_such_move.tres"),
			"missing-move rejection names manifest source and the missing path")
	# 清单为空。
	var manifest := MoveManifest.new()
	var empty_path := "user://mt_empty_manifest.tres"
	ResourceSaver.save(manifest, empty_path)
	result = MoveTable.load_manifest(empty_path)
	_check(not result.ok and result.errors[0].contains("未引用"),
		"manifest without any move reference is rejected")
	# 清单资源类型错误（被 MoveData 顶替）。
	var not_manifest := "user://mt_not_a_manifest.tres"
	ResourceSaver.save(_valid_strike("5A", "A"), not_manifest)
	result = MoveTable.load_manifest(not_manifest)
	_check(not result.ok and result.errors[0].contains("MoveManifest"),
		"wrong manifest resource type is rejected naming the expected type")


func _test_no_gameparams_fallback_on_rejection() -> void:
	# 非法表拒绝时不回退旧 GameParams 数值：不产出任何可用表，也不静默修正字段。
	var paths := _write_valid_table("mt_no_fallback", 1)
	var move_path: String = paths["moves"][0]
	_remove_property_line(move_path, "hitbox_size")
	var result := MoveTable.load_manifest(paths["manifest"])
	_check(not result.ok and result.moves.is_empty(), "rejected table never yields a runnable move table")
	_check(not result.ok and not result.errors[0].contains("GameParams"),
		"rejection does not silently substitute GameParams values")


# --- 修改代表字段：两处同步变化 ---

func _test_startup_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).startup_frames += 3
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var session_hit := -1
	for frame in range(1, 30):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				session_hit = frame
	_check(session_hit == 9, "session hit frame follows the edited startup (6 -> 9)")
	var report := ComboSolver.analyze(moves)
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null and route.hit_frames == [9, 13, 18],
		"solver report follows the same edited startup (route hit frames 9/13/18)")
	var baseline := ComboSolver.analyze()
	var baseline_route := _find_route(baseline, ["5A", "5B", "5D"])
	_check(baseline_route != null and baseline_route.hit_frames == [6, 10, 15],
		"unmodified shared table keeps the baseline route (6/10/15)")


func _test_damage_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).base_damage = 25
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(70, 0)
	for frame in range(1, 12):
		session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
	_check(absf(session.dummy_hp - (GameParams.DUMMY_MAX_HP - 25.0)) < 0.05,
		"session damage follows the edited base damage")
	var report := ComboSolver.analyze(moves)
	var route := _find_route(report, ["5A", "5B", "5D"])
	_check(route != null and _approx(route.total_damage, 50.2),
		"solver route total damage follows the same edit (25 + decayed 5B/5D = 50.2)")


func _test_attribute_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).attack_attribute = MoveData.AttackAttribute.LOW
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(70, 0)
	session.step(FrameInput.make(0, false, "A"))
	var snap := session.debug_snapshot()
	_check(String(snap["move_attribute"]) == "low",
		"session diagnostics expose the edited attack attribute of the active move")
	var report := ComboSolver.analyze(moves)
	var line := _move_table_line(report, "5A")
	_check(line != "" and line.contains("low"), "solver move-table summary reflects the edited attribute")


func _test_cancel_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).cancel_targets = ["236C"]
	var report := ComboSolver.analyze(moves)
	_check(_find_edge(report, "5A", "5B") == null, "removing the configured cancel drops the solver edge")
	_check(_find_edge(report, "5A", "236C") != null, "the remaining configured cancel is still analyzed")
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var saw_cancel := false
	for frame in range(1, 12):
		var key := "A" if frame == 1 else ("B" if frame == 7 else "")
		session.step(FrameInput.make(0, false, key))
		if session.player_move_id == "5B":
			saw_cancel = true
	_check(not saw_cancel, "session no longer cancels 5A into 5B without the configured target")


# --- Solver 拒绝 ---

func _test_solver_refuses_invalid_manifest_with_same_reason() -> void:
	var paths := _write_valid_table("mt_solver_refuse", 1)
	var move_path: String = paths["moves"][0]
	_remove_property_line(move_path, "hit_result")
	var load_result := MoveTable.load_manifest(paths["manifest"])
	_check(not load_result.ok, "invalid table is rejected by the loader")
	var report := ComboSolver.analyze_manifest(paths["manifest"])
	_check(report.refused, "solver refuses to analyze the invalid manifest")
	_check(report.refusal_reason == load_result.first_error(),
		"solver refusal carries the same observable reason as the loader")
	_check(report.edges.is_empty() and report.cycles.is_empty(),
		"refused solver report claims no analysis results")
	var lines := report.to_lines()
	_check(lines.any(func(line: String) -> bool: return line.contains("拒绝") and line.contains("hit_result")),
		"refused report lines expose the refusal and the offending field")


# --- 辅助 ---

## 一个字段齐全、校验合法的打击招式。
func _valid_strike(id: String, key: String) -> MoveData:
	var move := MoveData.new()
	move.move_id = id
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = key
	move.startup_frames = 5
	move.active_frames = 7
	move.recovery_frames = 13
	move.cancel_window_frames = 8
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.HIGH
	move.hitbox_size = Vector2(64, 60)
	move.hitbox_gap = 4.0
	move.hit_result = MoveData.HitResult.GROUND_HITSTUN
	move.hitstun_frames = 12
	move.knockback = 160.0
	move.knockback_up = 110.0
	return move


## 一个字段齐全、校验合法的普通投（startup 固定 5f 领域规则）。
func _valid_throw() -> MoveData:
	var move := _valid_strike("throw", "B")
	move.move_kind = MoveData.MoveKind.THROW
	move.action_key = ""
	move.startup_frames = 5
	move.throw_range = 64.0
	return move


func _valid_strike_list() -> Array:
	return [_valid_strike("5A", "A"), _valid_strike("5B", "B")]


## 把校验结果包成 Result 形状，断言“整表拒绝不产出部分表”。
func _validate_to_result(moves: Array) -> MoveTable.Result:
	var errors := MoveTable.validate(moves)
	var result := MoveTable.Result.new()
	result.ok = errors.is_empty()
	result.errors = errors
	return result


## 在 user:// 写一套合法的清单+招式资源；tag 用于隔离资源缓存路径。
func _write_valid_table(tag: String, move_count: int) -> Dictionary:
	var move_paths: Array[String] = []
	var keys := ["A", "B", "C", "D"]
	for i in range(move_count):
		var move := _valid_strike("5A" if i == 0 else "5B", keys[i])
		var path := "user://%s_move_%d.tres" % [tag, i]
		ResourceSaver.save(move, path)
		move_paths.append(path)
	var manifest := MoveManifest.new()
	manifest.move_paths = move_paths
	var manifest_path := "user://%s_manifest.tres" % tag
	ResourceSaver.save(manifest, manifest_path)
	return {"manifest": manifest_path, "moves": move_paths}


func _remove_property_line(path: String, property: String) -> void:
	## 删除 .tres 中以该属性名开头的属性行（模拟设计者手改资源删掉字段）。
	var lines := _read_text(path).split("\n")
	var kept := PackedStringArray()
	for line in lines:
		if line.begins_with(property + " "):
			continue
		kept.append(line)
	_write_text(path, "\n".join(kept))


func _replace_property_line(path: String, property: String, new_line: String) -> void:
	## 把 .tres 中该属性的整行替换为 new_line。
	var lines := _read_text(path).split("\n")
	for i in lines.size():
		if lines[i].begins_with(property + " "):
			lines[i] = new_line
			break
	_write_text(path, "\n".join(lines))


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _find_route(report, move_ids: Array) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


func _find_edge(report, from_id: String, to_id: String) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id:
			return edge
	return null


func _move_table_line(report, move_id: String) -> String:
	for line in report.to_lines():
		if line.contains(move_id) and (line.contains("属性") or line.contains("招式表")):
			return line
	return ""


func _approx(value: float, expected: float) -> bool:
	return absf(value - expected) < 0.05


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)
