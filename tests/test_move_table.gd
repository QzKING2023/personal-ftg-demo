extends SceneTree
## 共享招式表 seam 测试（issue 11）：本地类型化资源 + manifest 统一加载 + 整表校验。
## 覆盖：两处消费者（CombatSession/训练场 与 Combo Solver）读同一份已校验数据、
## 修改代表字段后行为与报告同步变化、非法表整表拒绝且错误可定位（资源来源、
## 招式 id、字段、冲突原因）、不静默修正/跳过/回退旧 GameParams。
## 运行：godot --headless --path . -s res://tests/test_move_table.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
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
	_test_low_float_profile_validation()
	_test_low_float_to_slide_profile_validation()
	_test_slide_target_state_validation()
	_test_segment_fields_validation()
	_test_special_entry_fields_validation()
	_test_requires_crouch_validation()
	_test_command_tier_and_lenient_validation()
	_test_block_result_fields_validation()
	_test_default_table_block_values()
	_test_rekka_fields_validation()
	_test_default_table_rekka_values()
	_test_hand_edited_tres_missing_field_rejected()
	_test_tres_type_error_rejected()
	_test_manifest_errors_rejected()
	_test_no_gameparams_fallback_on_rejection()
	_test_startup_edit_syncs_session_and_solver()
	_test_damage_edit_syncs_session_and_solver()
	_test_attribute_edit_syncs_session_and_solver()
	_test_cancel_edit_syncs_session_and_solver()
	_test_solver_refuses_invalid_manifest_with_same_reason()
	_test_analyze_manifest_cache_roundtrip_and_invalidation()
	print("")
	_metrics.emit("test_move_table")
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
	var expected_ids := ["5A", "2A", "5B", "2B", "5C", "2C", "6A", "236C", "214C", "214C~B", "214C~C", "jA", "jB", "jC", "j5D", "j6D", "j2D", "j214D", "5D", "5[D]", "6D", "2D", "BC"]
	_check(result.moves.keys() == expected_ids, "table preserves manifest order and ids (stable enumeration)")
	for move_id in expected_ids:
		var move := result.moves[move_id] as MoveData
		_check(move != null and move.move_id == move_id, "%s carries its own stable id, not the file name" % move_id)


func _test_default_table_entries_match_manifest() -> void:
	# 新基线调校初值（frame-data.md v0.2 TUNING_INITIAL；连段路线票据 01 起
	# jC 7→4、j214D 9→1，D74 选值）：startup/active/recovery 与基础伤害。
	var result := MoveTable.load_default()
	var expected := {
		"5A": [5, 4, 10, 8], "2A": [5, 4, 10, 8], "5B": [6, 5, 12, 12], "2B": [7, 5, 12, 11],
		"5C": [8, 5, 16, 16], "2C": [9, 3, 18, 14], "236C": [6, 2, 22, 8],
		"5D": [7, 4, 18, 18],
		"jA": [4, 6, 10, 8], "jB": [4, 6, 12, 12], "jC": [4, 5, 14, 14],
		"j5D": [6, 4, 16, 16], "j6D": [7, 4, 18, 17], "j2D": [8, 4, 20, 18],
		"6D": [9, 4, 20, 18], "2D": [8, 4, 18, 17],
		"BC": [5, 11, 10, -1],
	}
	for move_id in expected:
		var move := result.moves[move_id] as MoveData
		var values: Array = expected[move_id]
		_check([move.startup_frames, move.active_frames, move.recovery_frames, move.base_damage] == values,
			"%s carries the baseline tuning windows and damage" % move_id)
	var launcher := result.moves["236C"] as MoveData
	var launch_profile := MoveData.profile_for(launcher, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(launcher.direction_derivation == "236C" and launch_profile != null
		and launch_profile.reaction == HitProfile.Reaction.LAUNCH and launch_profile.upward_speed_px_s > 0.0,
		"236C declares its direction derivation and a grounded launch profile")
	# 票据 05 迁移：236C 不再承担专用 launcher/jump cancel（6A 承担），改为两段
	# 判定 + 特殊进入 D 资格；jump cancel 声明移除是负例（不再开放 jc 边）。
	_check(launcher.jump_cancel_targets.is_empty(), "236C no longer declares jump cancel (6A owns the launcher role)")
	_check(launcher.segment_count() == 2 and launcher.segment_active_from(1) == 11 and launcher.segment_active_to(1) == 12
		and launcher.total_frames() == 35,
		"236C declares its second segment (gap 3f, active F11-12, total 35 frames)")
	var seg2_grounded := launcher.segment_profile_for(1, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(seg2_grounded != null and seg2_grounded.reaction == HitProfile.Reaction.LOW_FLOAT_TO_SLIDE
		and seg2_grounded.slide_frames == 18,
		"236C segment 2 grounded hit launches into a ground slide (LOW_FLOAT_TO_SLIDE)")
	_check(launcher.special_entry_targets == ["5D"] and launcher.special_entry_window_frames == 16,
		"236C declares its special D entry qualification with the 16f window")
	var j2d_entry := result.moves["j2D"] as MoveData
	_check(j2d_entry.stance == MoveData.Stance.AIR and j2d_entry.hit_landing_cancel_targets == ["214C"]
		and j2d_entry.hit_landing_cancel_window_frames > 0,
		"j2D is the air move carrying the 214C hit-landing cancel qualification")
	# 阶段 3 新职责：5C 是普通地面重攻击（不再是专用 launcher，无 jump cancel），
	# 5D 不再是收尾；四招显式声明起手等级、链式/必杀取消与普通连接边。
	var five_c := result.moves["5C"] as MoveData
	var five_c_profile := MoveData.profile_for(five_c, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(five_c_profile != null and five_c_profile.reaction == HitProfile.Reaction.GROUND_HITSTUN
		and five_c_profile.ground_stun_frames == 14,
		"5C grounded hit is a normal ground hitstun profile (no longer a dedicated launcher)")
	_check(five_c.jump_cancel_targets.is_empty(), "5C no longer declares jump cancel")
	var five_d := result.moves["5D"] as MoveData
	_check(not five_d.is_finisher and five_d.link_targets.is_empty() and five_d.cancel_targets.is_empty(),
		"5D is no longer a finisher and declares no reverse 5B link or cancel edge")
	var five_a := result.moves["5A"] as MoveData
	_check(five_a.chain_cancel_targets == ["5B", "2B"] and five_a.chain_cancel_window_frames == 3,
		"5A declares its chain cancel edges to 5B and the crouch 2B with the 3f window")
	_check(five_a.special_cancel_targets == ["236C", "214C"] and five_a.special_cancel_window_frames == 5,
		"5A declares its special cancel edges to 236C and 214C with the 5f window")
	_check(five_a.link_targets == ["5B"], "5A declares the normal link edge to 5B")
	var five_b := result.moves["5B"] as MoveData
	_check(five_b.chain_cancel_targets == ["5C", "2C", "6A", "5D"] and five_b.link_targets == ["5C", "5D"],
		"5B declares its chain cancel and link edges per the baseline matrix")
	_check(five_c.chain_cancel_targets == ["6A", "5D"] and five_c.link_targets == ["5D"],
		"5C declares its chain cancel and link edges per the baseline matrix")
	# 票据 02：蹲姿普通技按姿态限定声明；2C 声明 LOW_FLOAT_SWEEP 资料（仅 grounded
	# 键，缺失 airborne 键由精确匹配拒绝，不回退）；214C 出口待票据 04 接通。
	var two_a := result.moves["2A"] as MoveData
	var two_b := result.moves["2B"] as MoveData
	var two_c := result.moves["2C"] as MoveData
	_check(two_a.requires_crouch and two_b.requires_crouch and two_c.requires_crouch,
		"the crouch normals declare the crouch requirement from the resource")
	_check(two_a.chain_cancel_targets == ["5A", "2A", "5B", "2B"],
		"2A chains within the A system and into the B system per the matrix")
	_check(two_b.chain_cancel_targets == ["5C", "2C", "6A"],
		"2B chains into the C system and 6A per the matrix")
	_check(two_c.chain_cancel_targets == ["6D", "2D"] and two_c.chain_cancel_window_frames == 3
		and two_c.special_cancel_targets == ["214C"]
		and two_c.link_targets.is_empty(),
		"2C declares its 6D/2D air-chase chain edges (ticket 07) and the 214C special cancel from ticket 04")
	var sweep := MoveData.profile_for(two_c, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(sweep != null and sweep.reaction == HitProfile.Reaction.LOW_FLOAT_SWEEP
		and sweep.air_untech_frames == 20 and sweep.upward_speed_px_s == 120.0
		and sweep.knockdown_frames == 30,
		"2C declares the LOW_FLOAT_SWEEP profile (window 20f, lift 120px/s, knockdown 30f)")
	_check(MoveData.profile_for(two_c, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) == null,
		"2C declares no AIRBORNE key: the exact-match selector must not fall back to grounded")
	_check(MoveData.profile_for(two_c, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER) != null
		and two_c.starter_grade == MoveData.StarterGrade.C,
		"2C declares its counter pair and the C starter grade")
	# 票据 07：6A 唯一专用击飞入口（jump cancel 开 jA/jB/jC）；jA/jB/jC 空中普通链；
	# 6D/2D 对空限定（无 grounded 键）、计划位移真实上升、命中后空中出口。
	var six_a := result.moves["6A"] as MoveData
	_check(six_a.jump_cancel_targets == ["jA", "jB", "jC"],
		"6A declares jump cancel into the delivered air normals (jA/jB/jC)")
	var ja := result.moves["jA"] as MoveData
	var jb := result.moves["jB"] as MoveData
	var jc := result.moves["jC"] as MoveData
	_check(ja.cancel_targets == ["jB", "jC", "j5D", "j6D", "j2D", "j214D"]
		and jb.cancel_targets == ["jC", "j5D", "j6D", "j2D", "j214D"]
		and jc.cancel_targets == ["j5D", "j6D", "j2D", "j214D"],
		"the air normals cancel into the air D series and j214D (ticket 09)")
	var six_d := result.moves["6D"] as MoveData
	var two_d := result.moves["2D"] as MoveData
	_check(six_d.direction_derivation == "6D" and two_d.requires_crouch,
		"6D derives from 6+D and 2D requires the crouch stance at input")
	_check(six_d.motion_x_px == 88.0 and six_d.motion_y_px == -48.0
		and two_d.motion_x_px == 0.0 and two_d.motion_y_px == -64.0,
		"6D/2D declare their planned motion (diagonal rise / vertical rise)")
	_check(MoveData.profile_for(six_d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL) == null
		and MoveData.profile_for(two_d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL) == null
		and MoveData.profile_for(six_d, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) != null
		and MoveData.profile_for(two_d, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) != null,
		"6D/2D declare airborne-only profiles: grounded targets report no-profile, never a fallback")
	_check(six_d.air_exit_targets == ["jA", "jB", "jC", "j5D", "j6D", "j2D", "j214D"]
		and two_d.air_exit_targets == ["jA", "jB", "jC", "j5D", "j6D", "j2D", "j214D"],
		"6D/2D declare their air exits into the delivered air moves (normals + ticket 08 air D series + ticket 09 j214D)")
	_check(two_d.hitbox_y_offset_px == -70.0 and six_d.hitbox_y_offset_px == 0.0,
		"2D declares the raised vertical hitbox while 6D stays centered")
	var grades := {
		"5A": MoveData.StarterGrade.A, "2A": MoveData.StarterGrade.A,
		"5B": MoveData.StarterGrade.B, "2B": MoveData.StarterGrade.B,
		"5C": MoveData.StarterGrade.C, "2C": MoveData.StarterGrade.C,
		"5D": MoveData.StarterGrade.D,
	}
	for move_id in grades:
		_check((result.moves[move_id] as MoveData).starter_grade == grades[move_id],
			"%s explicitly declares its starter grade" % move_id)
	for move_id in result.moves:
		var move := result.moves[move_id] as MoveData
		if move.is_throw():
			_check(move.action_key == "" and move.throw_range == 64.0, "BC stays the B+C combination throw with its range (no single-key binding)")
			continue
		_check(move.move_kind == MoveData.MoveKind.STRIKE, "%s declares move kind strike" % move_id)
		_check(move.action_key != "" and move.priority >= 0, "%s declares input binding and priority" % move_id)
		_check(move.attack_attribute != MoveData.AttackAttribute.UNSET, "%s declares an attack attribute" % move_id)
		_check(move.starter_grade != MoveData.StarterGrade.UNSET, "%s declares a starter grade" % move_id)


func _test_loads_return_fresh_copies() -> void:
	# 多次加载返回独立副本：修改一份不会污染其他消费者（运行时与 Solver 同表不同实例）。
	var first := MoveTable.load_default()
	var second := MoveTable.load_default()
	_check(first.moves["5A"] != second.moves["5A"], "two loads return distinct move instances")
	(first.moves["5A"] as MoveData).base_damage = 999
	_check((second.moves["5A"] as MoveData).base_damage == 8, "mutating one copy does not leak into other loads")


# --- 整表校验：打击/投技必填字段 ---

func _test_missing_strike_fields_reject_whole_table() -> void:
	for field in ["base_damage", "attack_attribute", "hitbox_size", "hit_profiles", "action_key", "starter_grade"]:
		var moves := _valid_strike_list()
		var move: MoveData = moves[0]
		if field == "attack_attribute":
			move.set("attack_attribute", MoveData.AttackAttribute.UNSET)
		elif field == "hitbox_size":
			move.hitbox_size = Vector2.ZERO
		elif field == "action_key":
			move.action_key = ""
		elif field == "hit_profiles":
			move.hit_profiles = []
		elif field == "base_damage":
			move.base_damage = -1
		else:
			move.set(field, -1)
		var errors := MoveTable.validate(moves)
		_check(not errors.is_empty(), "strike missing %s rejects the table" % field)
		if not errors.is_empty():
			_check(errors[0].contains("5A") and errors[0].contains(field),
				"rejection for %s names the move id and field" % field)
	# 同表的合法招式不因另一招非法而被跳过修正——整表拒绝、不返回部分表。
	var broken := _valid_strike_list()
	(broken[0] as MoveData).base_damage = -1
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
	var short_window := _valid_throw()
	short_window.active_frames = 3
	errors = MoveTable.validate([short_window])
	_check(not errors.is_empty() and errors[0].contains("active_frames") and errors[0].contains("10"),
		"throw active must stay the grab frame plus the ten tech-window frames (about-15f domain rule)")
	var doubled := [_valid_throw(), _valid_throw()]
	(doubled[1] as MoveData).move_id = "BC2"
	errors = MoveTable.validate(doubled)
	_check(not errors.is_empty() and errors[0].contains("并列"),
		"two throws in one table are an illegal tie for the single B+C combination")


# --- 类型/帧数/枚举/方向谓词/矛盾字段 ---

func _test_negative_frames_rejected() -> void:
	for field in ["startup_frames", "active_frames", "recovery_frames", "cancel_window_frames"]:
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
	var bad_profile := _valid_strike_list()
	(bad_profile[0] as MoveData).hit_profiles[0].set("target_state", 42)
	errors = MoveTable.validate(bad_profile)
	_check(not errors.is_empty() and errors[0].contains("target_state"), "unknown profile target_state enum value is rejected")


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
		session.dummy_position = session.player_position + Vector2(26, 0)
		session.step(FrameInput.make(0, false, "A"))
		_check(session.player_move_id == "5H", "runtime resolves the same binding by declared priority")


# --- 票据 02：低浮空资料与蹲姿限定校验 ---

func _valid_low_float_profile() -> HitProfile:
	var profile := HitProfile.new()
	profile.target_state = HitProfile.TargetState.GROUNDED
	profile.hit_context = HitProfile.HitContext.NORMAL
	profile.reaction = HitProfile.Reaction.LOW_FLOAT_SWEEP
	profile.air_untech_frames = 20
	profile.upward_speed_px_s = 120.0
	profile.horizontal_speed_px_s = 140.0
	profile.knockdown_frames = 30
	return profile


func _test_low_float_profile_validation() -> void:
	var move := _valid_strike("2C", "C")
	move.hit_profiles = [_valid_low_float_profile()]
	_check(MoveTable.validate([move]).is_empty(), "a grounded LOW_FLOAT_SWEEP profile with window, lift and knockdown timers is legal")
	var cases := [
		["target_state", HitProfile.TargetState.AIRBORNE, "低浮空"],
		["knockdown_frames", -1, "knockdown_frames"],
		["air_untech_frames", -1, "air_untech_frames"],
		["ground_stun_frames", 12, "ground_stun_frames"],
	]
	for entry in cases:
		var broken := _valid_strike("2C", "C")
		var profile := _valid_low_float_profile()
		profile.set(entry[0], entry[1])
		broken.hit_profiles = [profile]
		var errors := MoveTable.validate([broken])
		_check(not errors.is_empty() and errors[0].contains(entry[2]),
			"LOW_FLOAT_SWEEP profile with illegal %s is rejected naming the field" % entry[0])
	var no_lift := _valid_strike("2C", "C")
	var flat := _valid_low_float_profile()
	flat.upward_speed_px_s = 0.0
	no_lift.hit_profiles = [flat]
	var errors := MoveTable.validate([no_lift])
	_check(not errors.is_empty() and errors[0].contains("upward_speed_px_s"),
		"LOW_FLOAT_SWEEP must declare a positive lift speed (it leaves the ground by design)")
	var counter_only := _valid_strike("2C", "C")
	var counter := _valid_low_float_profile()
	counter.hit_context = HitProfile.HitContext.COUNTER
	counter_only.hit_profiles = [counter]
	errors = MoveTable.validate([counter_only])
	_check(not errors.is_empty() and errors[0].contains("counter"),
		"a LOW_FLOAT counter without its same-state normal pair is rejected")


func _valid_to_slide_profile() -> HitProfile:
	var profile := HitProfile.new()
	profile.target_state = HitProfile.TargetState.GROUNDED
	profile.hit_context = HitProfile.HitContext.NORMAL
	profile.reaction = HitProfile.Reaction.LOW_FLOAT_TO_SLIDE
	profile.air_untech_frames = 16
	profile.upward_speed_px_s = 120.0
	profile.horizontal_speed_px_s = 100.0
	profile.slide_frames = 18
	return profile


func _valid_segment() -> MoveSegment:
	var segment := MoveSegment.new()
	segment.startup_frames = 3
	segment.active_frames = 2
	segment.base_damage = 12
	segment.hitbox_size = Vector2(46, 30)
	segment.hitbox_gap = 3.0
	segment.hit_profiles = [_valid_to_slide_profile()]
	return segment


func _valid_two_segment_strike() -> MoveData:
	var move := _valid_strike("236X", "C")
	move.special_entry_targets = ["5D"]
	move.special_entry_window_frames = 16
	return move


func _test_low_float_to_slide_profile_validation() -> void:
	# 击飞触地滑行（票据 05，S-04）：仅 grounded 目标；滞空窗口、离地速度与
	# 滑行持续必填；不携带倒地/地面硬直计时（不经过普通倒地）。
	var move := _valid_strike("236X", "C")
	move.hit_profiles = [_valid_to_slide_profile()]
	_check(MoveTable.validate([move]).is_empty(), "a grounded LOW_FLOAT_TO_SLIDE profile with window, lift and slide duration is legal")
	var cases := [
		["target_state", HitProfile.TargetState.AIRBORNE, "击飞触地滑行只允许 grounded"],
		["slide_frames", -1, "slide_frames"],
		["air_untech_frames", -1, "air_untech_frames"],
		["knockdown_frames", 30, "knockdown_frames"],
		["ground_stun_frames", 12, "ground_stun_frames"],
	]
	for entry in cases:
		var broken := _valid_strike("236X", "C")
		var profile := _valid_to_slide_profile()
		profile.set(entry[0], entry[1])
		broken.hit_profiles = [profile]
		var errors := MoveTable.validate([broken])
		_check(not errors.is_empty() and errors[0].contains(entry[2]),
			"LOW_FLOAT_TO_SLIDE profile with illegal %s is rejected naming the field" % entry[0])
	var no_lift := _valid_strike("236X", "C")
	var flat := _valid_to_slide_profile()
	flat.upward_speed_px_s = 0.0
	no_lift.hit_profiles = [flat]
	_check(not MoveTable.validate([no_lift]).is_empty() and MoveTable.validate([no_lift])[0].contains("upward_speed_px_s"),
		"LOW_FLOAT_TO_SLIDE must declare a positive lift speed")


func _test_slide_target_state_validation() -> void:
	# slide 目标资料门（S-05）：GROUND_SLIDE 键上的合法 reaction 目前只有捞起
	# （LAUNCH）；地面硬直/倒地/低浮空资料在 slide 键上整表拒绝，缺失即无命中。
	var cases := [
		[HitProfile.Reaction.GROUND_HITSTUN, {"ground_stun_frames": 12, "upward_speed_px_s": 0.0}, "grounded"],
		[HitProfile.Reaction.GROUND_KNOCKDOWN, {"knockdown_frames": 30, "upward_speed_px_s": 0.0}, "grounded"],
		[HitProfile.Reaction.LOW_FLOAT_SWEEP, {"air_untech_frames": 20, "upward_speed_px_s": 120.0, "knockdown_frames": 30}, "grounded"],
	]
	for entry in cases:
		var broken := _valid_strike("5X", "D")
		var profile := HitProfile.new()
		profile.target_state = HitProfile.TargetState.GROUND_SLIDE
		profile.hit_context = HitProfile.HitContext.NORMAL
		profile.reaction = entry[0]
		profile.horizontal_speed_px_s = 60.0
		for field in entry[1]:
			profile.set(field, entry[1][field])
		broken.hit_profiles = [profile]
		var errors := MoveTable.validate([broken])
		_check(not errors.is_empty(), "a %s profile on the GROUND_SLIDE key is rejected (only the scoop LAUNCH is legal there)" % entry[0])
	var scoop := _valid_strike("5X", "D")
	var profile := HitProfile.new()
	profile.target_state = HitProfile.TargetState.GROUND_SLIDE
	profile.hit_context = HitProfile.HitContext.NORMAL
	profile.reaction = HitProfile.Reaction.LAUNCH
	profile.air_untech_frames = 30
	profile.horizontal_speed_px_s = 60.0
	profile.upward_speed_px_s = 180.0
	scoop.hit_profiles = [profile]
	_check(MoveTable.validate([scoop]).is_empty(), "a scoop LAUNCH profile on the GROUND_SLIDE key is legal")


func _test_segment_fields_validation() -> void:
	# 附加判定段（票据 05）：每段显式声明间隔/active/伤害/命中框/资料；投技
	# 不得声明段；段内非法资料整表拒绝并定位到段。
	var legal := _valid_two_segment_strike()
	legal.segments = [_valid_segment()]
	var entry := _valid_strike("5D", "D")
	entry.stance = MoveData.Stance.GROUND
	var table := [legal, entry]
	_check(MoveTable.validate(table).is_empty(), "a strike with a fully declared second segment keeps the table legal")
	var cases := [
		["startup_frames", -1, "startup_frames"],
		["active_frames", 0, "active_frames"],
		["base_damage", -1, "base_damage"],
		["hitbox_gap", -1.0, "hitbox_gap"],
	]
	for entry2 in cases:
		var broken := _valid_two_segment_strike()
		var segment := _valid_segment()
		segment.set(entry2[0], entry2[1])
		broken.segments = [segment]
		var errors := MoveTable.validate([broken, entry])
		_check(not errors.is_empty() and errors[0].contains(entry2[2]),
			"a segment with illegal %s is rejected naming the field" % entry2[0])
	var no_profiles := _valid_two_segment_strike()
	var empty_seg := _valid_segment()
	empty_seg.hit_profiles = []
	no_profiles.segments = [empty_seg]
	var errors := MoveTable.validate([no_profiles, entry])
	_check(not errors.is_empty() and errors[0].contains("hit_profiles"),
		"a segment without hit profiles is rejected")
	var airborne_slide := _valid_two_segment_strike()
	var bad_seg := _valid_segment()
	var bad_profile := _valid_to_slide_profile()
	bad_profile.target_state = HitProfile.TargetState.AIRBORNE
	bad_seg.hit_profiles = [bad_profile]
	airborne_slide.segments = [bad_seg]
	errors = MoveTable.validate([airborne_slide, entry])
	_check(not errors.is_empty() and errors[0].contains("击飞触地滑行只允许 grounded"),
		"an illegal profile inside a segment is rejected with the segment-scoped label")
	var throw_segment := _valid_throw()
	throw_segment.segments = [_valid_segment()]
	errors = MoveTable.validate([throw_segment])
	_check(not errors.is_empty() and errors[0].contains("segments"),
		"a throw declaring segments is rejected")


func _test_special_entry_fields_validation() -> void:
	# 特殊进入资格（票据 05，I-05）：目标与窗口成对声明；目标必须在表中、与
	# 来源同姿态；来源限定连接边同样做跨招式引用校验。
	var five_d := _valid_strike("5D", "D")
	var legal := _valid_two_segment_strike()
	legal.segments = [_valid_segment()]
	_check(MoveTable.validate([legal, five_d]).is_empty(), "a declared special entry target with its window keeps the table legal")
	var no_window := _valid_two_segment_strike()
	no_window.special_entry_window_frames = -1
	var errors := MoveTable.validate([no_window, five_d])
	_check(not errors.is_empty() and errors[0].contains("special_entry_window_frames"),
		"special entry targets without a window are rejected naming the field")
	var no_targets := _valid_two_segment_strike()
	no_targets.special_entry_targets = [] as Array[String]
	errors = MoveTable.validate([no_targets, five_d])
	_check(not errors.is_empty() and errors[0].contains("special_entry_window_frames"),
		"a special entry window without targets is rejected")
	var ghost := _valid_two_segment_strike()
	ghost.segments = [_valid_segment()]
	ghost.special_entry_targets = ["ghost"]
	errors = MoveTable.validate([ghost, five_d])
	_check(not errors.is_empty() and errors[0].contains("ghost"),
		"a special entry target missing from the table is rejected naming the id")
	var stance_mismatch := _valid_two_segment_strike()
	stance_mismatch.segments = [_valid_segment()]
	var air_target := _valid_strike("jD2", "D")
	air_target.stance = MoveData.Stance.AIR
	stance_mismatch.special_entry_targets = ["jD2"]
	errors = MoveTable.validate([stance_mismatch, air_target])
	_check(not errors.is_empty() and errors[0].contains("姿态不一致"),
		"a special entry target with a mismatched stance is rejected")
	var link_ghost := _valid_strike("5D2", "D")
	link_ghost.special_entry_link_targets = ["ghostB"]
	errors = MoveTable.validate([link_ghost])
	_check(not errors.is_empty() and errors[0].contains("ghostB"),
		"a source-limited link target missing from the table is rejected naming the id")


func _test_requires_crouch_validation() -> void:
	var air_crouch := _valid_strike("jX", "A")
	air_crouch.stance = MoveData.Stance.AIR
	air_crouch.requires_crouch = true
	var errors := MoveTable.validate([air_crouch])
	_check(not errors.is_empty() and errors[0].contains("requires_crouch"),
		"an air move declaring the crouch requirement is rejected (crouch is ground-only)")
	var ground := _valid_strike("2A", "A")
	ground.requires_crouch = true
	ground.priority = 2
	_check(MoveTable.validate([ground, _valid_strike("5B", "B")]).is_empty(),
		"a ground move with the crouch requirement validates next to other bindings")
	# 蹲姿限定不是并列破除器：同姿态+同键+同层级+同优先级仍属无确定性选择。
	var tied := _valid_strike("5A2", "A")
	tied.requires_crouch = true
	errors = MoveTable.validate([_valid_strike("5A", "A"), tied])
	_check(not errors.is_empty() and errors[0].contains("优先级并列"),
		"same key + tier + priority stays an illegal tie even when one side requires crouch")


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

func _test_block_result_fields_validation() -> void:
	# 被防是独立于 HitProfile 的接触结果（D-02/D-03）：停顿/硬直/推退逐招显式声明，
	# 未声明哨兵拒绝（默认禁止，无全局回退）；投技不得声明被防结果。
	var legal := _valid_strike_list()
	_check(MoveTable.validate(legal).is_empty(), "declared block result fields keep the table legal")
	for field in ["block_freeze_frames", "block_stun_frames"]:
		var moves := _valid_strike_list()
		(moves[0] as MoveData).set(field, -1)
		var errors := MoveTable.validate(moves)
		_check(not errors.is_empty() and errors[0].contains("5A") and errors[0].contains(field),
			"strike missing %s rejects the table naming the move id and field" % field)
	var no_pushback := _valid_strike_list()
	(no_pushback[0] as MoveData).block_pushback_px_s = -1.0
	var pushback_errors := MoveTable.validate(no_pushback)
	_check(not pushback_errors.is_empty() and pushback_errors[0].contains("block_pushback_px_s"),
		"strike missing block_pushback_px_s is rejected naming the field")
	var negative := _valid_strike_list()
	(negative[0] as MoveData).block_stun_frames = -3
	var negative_errors := MoveTable.validate(negative)
	_check(not negative_errors.is_empty() and negative_errors[0].contains("block_stun_frames"),
		"negative block_stun_frames is rejected naming the field")
	var throwing := [_valid_throw()]
	(throwing[0] as MoveData).block_freeze_frames = 8
	var throw_errors := MoveTable.validate(throwing)
	_check(not throw_errors.is_empty() and throw_errors[0].contains("block_freeze_frames"),
		"throw declaring block result fields is a contradiction rejected on the field")


func _test_rekka_fields_validation() -> void:
	# Rekka 派生字段组合（票据 04）：窗口与目标成对声明、目标必须 rekka_only、
	# 分支键一致、派生招式不出现在任何取消/连接目标列表中。
	var legal := _rekka_strike_list()
	_check(MoveTable.validate(legal).is_empty(), "a declared rekka opener with rekka-only targets keeps the table legal")
	var no_targets := _rekka_strike_list()
	(no_targets[0] as MoveData).rekka_b_target = ""
	(no_targets[0] as MoveData).rekka_c_target = ""
	_check(not MoveTable.validate(no_targets).is_empty(),
		"declaring a derivation window without any branch target rejects the table")
	var no_window := _rekka_strike_list()
	(no_window[0] as MoveData).rekka_window_frames = -1
	var no_window_errors := MoveTable.validate(no_window)
	_check(not no_window_errors.is_empty() and no_window_errors[0].contains("rekka_b_target"),
		"declaring branch targets without a window is rejected naming the field")
	var same_branch := _rekka_strike_list()
	(same_branch[0] as MoveData).rekka_c_target = "rkB"
	_check(not MoveTable.validate(same_branch).is_empty(),
		"pointing both branches at the same derived move is rejected")
	var not_only := _rekka_strike_list()
	(not_only[1] as MoveData).rekka_only = false
	var not_only_errors := MoveTable.validate(not_only)
	_check(not not_only_errors.is_empty() and not_only_errors[0].contains("rekka_only"),
		"a branch target without rekka_only is rejected (derivation is the only entry)")
	var key_mismatch := _rekka_strike_list()
	(key_mismatch[1] as MoveData).action_key = "C"
	var key_errors := MoveTable.validate(key_mismatch)
	_check(not key_errors.is_empty() and key_errors[0].contains("rekka_b_target"),
		"a B-branch target bound to another key is rejected naming the branch field")
	var in_cancel := _rekka_strike_list()
	(in_cancel[0] as MoveData).cancel_targets = ["rkB"]
	var in_cancel_errors := MoveTable.validate(in_cancel)
	_check(not in_cancel_errors.is_empty() and in_cancel_errors[0].contains("rekka_only"),
		"referencing a rekka-only move from cancel targets is rejected")
	var notation := _rekka_strike_list()
	(notation[1] as MoveData).direction_derivation = "236B"
	_check(not MoveTable.validate(notation).is_empty(),
		"a rekka-only move declaring a command notation is rejected (not input-selectable)")
	var missing := _rekka_strike_list()
	(missing[0] as MoveData).rekka_b_target = "ghost"
	var missing_errors := MoveTable.validate(missing)
	_check(not missing_errors.is_empty() and missing_errors[0].contains("ghost"),
		"a branch target missing from the table is rejected naming the id")


func _test_default_table_rekka_values() -> void:
	# 票据 04 迁移：214C 首段（窗口 12、~B/~C 目标）与两个 rekka_only 派生在表；
	# 2C/5A/2A/5B/5C 声明 214C 必杀取消边。
	var result := MoveTable.load_default()
	_check(result.ok, "default manifest loads with the rekka moves")
	var opener := result.moves.get("214C") as MoveData
	_check(opener != null and opener.rekka_window_frames == 12
		and opener.rekka_b_target == "214C~B" and opener.rekka_c_target == "214C~C",
		"214C declares the TUNING_INITIAL window 12 and both branch targets")
	var branch_b := result.moves.get("214C~B") as MoveData
	var branch_c := result.moves.get("214C~C") as MoveData
	_check(branch_b != null and branch_b.rekka_only and branch_c != null and branch_c.rekka_only,
		"both derived moves are rekka_only (not input-selectable)")
	_check(not branch_c.link_targets.is_empty() or branch_c.is_finisher,
		"the ~C finisher keeps no link edges while ~B carries the 5B link")
	_check((result.moves["2C"] as MoveData).special_cancel_targets.has("214C"),
		"2C declares the 214C special cancel edge (the 2C > 214C~B route)")
	for id in ["5A", "2A", "5B", "5C"]:
		_check((result.moves[id] as MoveData).special_cancel_targets.has("214C"),
			"%s declares the 214C special cancel edge per the cancel matrix" % id)


## 票据 04 校验探针表：一个 Rekka 首段 + 两个 rekka_only 派生目标。
func _rekka_strike_list() -> Array:
	var opener := _valid_strike("rk0", "C")
	opener.rekka_window_frames = 12
	opener.rekka_b_target = "rkB"
	opener.rekka_c_target = "rkC"
	var branch_b := _valid_strike("rkB", "B")
	branch_b.rekka_only = true
	var branch_c := _valid_strike("rkC", "C")
	branch_c.rekka_only = true
	return [opener, branch_b, branch_c]


func _test_default_table_block_values() -> void:
	# 票据 03 迁移：全部打击招式按 frame-data.md v0.5 落表被防初值 8/9/45；
	# BC 投不声明被防结果（保持未声明哨兵）。
	var result := MoveTable.load_default()
	_check(result.ok, "default manifest still loads after the block-result migration")
	for move_id in result.moves:
		var move := result.moves[move_id] as MoveData
		if move.is_throw():
			_check(move.block_freeze_frames == -1 and move.block_stun_frames == -1 and move.block_pushback_px_s < 0.0,
				"%s is a throw and keeps block result fields undeclared" % move_id)
		else:
			_check(move.block_freeze_frames == 8 and move.block_stun_frames == 9 and is_equal_approx(move.block_pushback_px_s, 45.0),
				"%s declares the TUNING_INITIAL block result 8/9/45" % move_id)


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
	session.dummy_position = session.player_position + Vector2(26, 0)
	var session_hit := -1
	for frame in range(1, 30):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				session_hit = frame
	_check(session_hit == 9, "session hit frame follows the edited startup (6 -> 9)")
	## 可读路线报告上限（票据 09 起 16 条）触顶后代表路线不再保证入默认报告；
	## 路线断言经精确路线查询解析（与枚举报告同一套模拟，票据 09 验收尾巴）。
	var route := _query_route(["5A", "5B", "5D"], moves)
	_check(route != null and route.hit_frames == [9, 16, 23],
		"solver report follows the same edited startup (route hit frames 9/16/23; the B chain cancel lands one normal frame after the confirm)")
	var baseline_route := _query_route(["5A", "5B", "5D"], null)
	_check(baseline_route != null and baseline_route.hit_frames == [6, 13, 20],
		"unmodified shared table keeps the baseline route (6/13/20 with the B pairing wait)")


func _test_damage_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).base_damage = 25
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(26, 0)
	for frame in range(1, 12):
		session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
	## A 起手首击：round0.1(25 × 0.72) = 18.0。
	_check(absf(session.dummy_hp - (GameParams.DUMMY_MAX_HP - 18.0)) < 0.05,
		"session damage follows the edited base damage through the A starter scale")
	var route := _query_route(["5A", "5B", "5D"], moves)
	## 18.0 + round0.1(12 × 0.72×0.90) + round0.1(18 × 0.72×0.90×0.90) = 18.0 + 7.8 + 10.5。
	_check(route != null and _approx(route.total_damage, 36.3),
		"solver route total damage follows the same edit (25 scaled by the three-layer corrections: 18.0 + 7.8 + 10.5)")


func _test_attribute_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).attack_attribute = MoveData.AttackAttribute.LOW
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(26, 0)
	session.step(FrameInput.make(0, false, "A"))
	var snap := session.debug_snapshot()
	_check(String(snap["move_attribute"]) == "low",
		"session diagnostics expose the edited attack attribute of the active move")
	var report := _metrics.analyze(moves)
	var line := _move_table_line(report, "5A")
	_check(line != "" and line.contains("low"), "solver move-table summary reflects the edited attribute")


func _test_cancel_edit_syncs_session_and_solver() -> void:
	var moves := MoveTable.load_default().moves
	(moves["5A"] as MoveData).chain_cancel_targets = []
	(moves["5A"] as MoveData).chain_cancel_window_frames = -1
	(moves["5A"] as MoveData).link_targets = []
	var report := _metrics.analyze(moves)
	_check(_find_edge(report, "5A", "5B") == null, "removing the configured chain cancel and link drops the solver edges")
	_check(_find_edge(report, "5A", "236C") != null, "the remaining configured special cancel is still analyzed")
	var session := CombatSession.new(moves)
	session.dummy_position = session.player_position + Vector2(26, 0)
	var saw_cancel := false
	for frame in range(1, 12):
		var key := "A" if frame == 1 else ("B" if frame == 7 else "")
		session.step(FrameInput.make(0, false, key))
		if session.player_move_id == "5B":
			saw_cancel = true
	_check(not saw_cancel, "session no longer cancels 5A into 5B without the configured chain target")


# --- Solver 拒绝 ---

func _test_solver_refuses_invalid_manifest_with_same_reason() -> void:
	var paths := _write_valid_table("mt_solver_refuse", 1)
	var move_path: String = paths["moves"][0]
	_remove_property_line(move_path, "hit_profiles")
	var load_result := MoveTable.load_manifest(paths["manifest"])
	_check(not load_result.ok, "invalid table is rejected by the loader")
	var report := _metrics.analyze_manifest(paths["manifest"])
	_check(report.refused, "solver refuses to analyze the invalid manifest")
	_check(report.refusal_reason == load_result.first_error(),
		"solver refusal carries the same observable reason as the loader")
	_check(report.edges.is_empty() and report.cycles.is_empty(),
		"refused solver report claims no analysis results")
	var lines := report.to_lines()
	_check(lines.any(func(line: String) -> bool: return line.contains("拒绝") and line.contains("hit_profiles")),
		"refused report lines expose the refusal and the offending field")


## 票据 06：analyze_manifest() 入口接入结果缓存。断言模式无关（冷跑首调未命中、
## 热跑首调命中持久化条目都成立）且取计数差值——本 job 的累计账面
## （hits+misses+bypasses==calls，Tier B 不变量）不得被本测试重置，全程不清缓存。
func _test_analyze_manifest_cache_roundtrip_and_invalidation() -> void:
	var paths := _write_valid_table("mt_solver_cache", 1)
	var before := ComboSolver.result_cache_stats()
	var first := _metrics.analyze_manifest(paths["manifest"])
	var stats1 := ComboSolver.result_cache_stats()
	var d1 := int(stats1.get("hits", 0)) - int(before.get("hits", 0)) 			+ int(stats1.get("misses", 0)) - int(before.get("misses", 0))
	_check(not first.refused and d1 == 1,
		"the first manifest analysis consults the cache exactly once (miss when cold, hit when warm)")
	var second := _metrics.analyze_manifest(paths["manifest"])
	var stats2 := ComboSolver.result_cache_stats()
	_check(int(stats2.get("hits", 0)) - int(stats1.get("hits", 0)) == 1
			and int(stats2.get("misses", 0)) == int(stats1.get("misses", 0)),
		"an identical manifest analysis hits the cache without recomputing (cold or warm)")
	_check("
".join(first.to_lines()) == "
".join(second.to_lines()),
		"manifest cache hit preserves the complete report")
	_replace_property_line(paths["moves"][0], "base_damage", "base_damage = 19")
	var after_edit := _metrics.analyze_manifest(paths["manifest"])
	var stats3 := ComboSolver.result_cache_stats()
	var d3 := int(stats3.get("hits", 0)) - int(stats2.get("hits", 0)) 			+ int(stats3.get("misses", 0)) - int(stats2.get("misses", 0))
	_check(d3 == 1 and "
".join(after_edit.to_lines()) != "
".join(second.to_lines()),
		"editing a move resource file never reuses the stale entry: the request resolves to a different report (semantic signature)")


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
	move.starter_grade = MoveData.StarterGrade.A
	move.block_freeze_frames = 8
	move.block_stun_frames = 9
	move.block_pushback_px_s = 45.0
	var normal := HitProfile.new()
	normal.target_state = HitProfile.TargetState.GROUNDED
	normal.hit_context = HitProfile.HitContext.NORMAL
	normal.reaction = HitProfile.Reaction.GROUND_HITSTUN
	normal.ground_stun_frames = 12
	normal.horizontal_speed_px_s = 160.0
	normal.upward_speed_px_s = 0.0
	move.hit_profiles = [normal]
	return move


## 一个字段齐全、校验合法的普通投（startup 固定 5f 领域规则）。
func _valid_throw() -> MoveData:
	var move := _valid_strike("throw", "B")
	move.move_kind = MoveData.MoveKind.THROW
	move.action_key = ""
	move.hit_profiles = []
	move.startup_frames = 5
	move.active_frames = GameParams.THROW_TECH_WINDOW_AFTER_GRAB + 1
	move.throw_range = 64.0
	move.block_freeze_frames = -1
	move.block_stun_frames = -1
	move.block_pushback_px_s = -1.0
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


## 可读路线报告上限（票据 09 起 16 条）触顶后代表路线不再保证入默认报告；
## 路线断言经精确路线查询解析（与枚举报告同一套模拟，票据 09 验收尾巴）。
## table 为 null 时查询共享 manifest 默认表，否则作为注入表查询。
func _query_route(move_ids: Array, table) -> ComboSolver.SolverRoute:
	var ids: Array[String] = []
	for id in move_ids:
		ids.append(str(id))
	if table == null:
		var plain := ComboSolver.route_report(ids)
		return plain.routes[0] if not plain.refused and not plain.routes.is_empty() else null
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	var report := ComboSolver.route_report(ids, opts)
	return report.routes[0] if not report.refused and not report.routes.is_empty() else null

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
