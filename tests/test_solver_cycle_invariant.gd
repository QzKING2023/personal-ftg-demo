extends SceneTree

## P4（solver-delay-dp）：CycleInvariant 前置条件矩阵 + _simulate_cycle 回退端到端。
## 四项声明前置条件逐一驱动（每圈有效 HIT / 倍率有限且严格小于 1 /
## time_scale 在完整循环键中 / 无浮点下溢），任一不满足必须回退精确逐圈状态
## 复现；APPLY 文案与票据 09 起的报告逐字节一致（指纹不漂移）。覆盖：bounce、
## slide、倍率=1、非法倍率（0/负/inf/nan）、浮点下溢边界（每圈命中数参与指数，
## 多 HIT 圈先于单 HIT 圈触发回退）、settlement 键漂移、普通循环域外回退、
## 端到端回退确实执行搜索（cycle_state_snapshots>0）而 APPLY 时为 0。
## 运行：godot --headless --path . -s res://tests/test_solver_cycle_invariant.gd

const MONOTONIC_REASON := "逐圈证明被单调时间修正排除：每圈至少一次有效 HIT，time_scale 严格递减并属于 settlement_state，回边不可能重现；未执行延迟笛卡尔积"

var _failures := 0
var _solver: ComboSolver


func _initialize() -> void:
	var load_result := MoveTable.load_default()
	if not load_result.ok:
		print("FAIL  manifest load refused: " + load_result.first_error())
		_failures += 1
		quit(1)
		return
	_solver = ComboSolver.new(load_result.moves)
	_test_bounce_cycle_applies()
	_test_slide_cycle_applies()
	_test_ordinary_cycle_out_of_scope()
	_test_factor_one_falls_back()
	_test_illegal_factors_fall_back()
	_test_underflow_boundary()
	_test_multihit_exponent()
	_test_settlement_key_drift()
	_test_lap_hit_precondition()
	_test_end_to_end_fallback_runs_search()
	print("TOTAL failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


func _discover_first_profile_reaction(reaction: int) -> String:
	for move_id in _solver._table:
		var move := _solver._table[move_id] as MoveData
		if move == null or move.hit_profiles.is_empty():
			continue
		if move.hit_profiles[0].reaction == reaction:
			return move_id
	return ""


func _plain_strike_id() -> String:
	for move_id in _solver._table:
		var move := _solver._table[move_id] as MoveData
		if move != null and move.is_strike() and move.stance == MoveData.Stance.GROUND \
				and move.hit_profiles.size() > 0 and not move.hit_profiles.is_empty() \
				and move.hit_profiles[0].reaction != HitProfile.Reaction.GROUND_BOUNCE \
				and move.hit_profiles[0].reaction != HitProfile.Reaction.LOW_FLOAT_TO_SLIDE:
			return move_id
	return ""


# --- APPLY 域（默认调校：全部倍率严格 (0,1)、键覆盖、视野内无下溢）---


func _test_bounce_cycle_applies() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	if move_id == "":
		_check(false, "bounce: no GROUND_BOUNCE first-profile move in default table")
		return
	var invariant := _solver._cycle_invariant([move_id])
	_check(invariant.applies(), "bounce: default factors apply the monotonic invariant (%s)" % move_id)
	_check(invariant.reason == MONOTONIC_REASON,
		"bounce: APPLY reason byte-identical to the ticket-09 exclusion text")
	_check(invariant.failed_precondition == "", "bounce: no failed precondition on APPLY")


func _test_slide_cycle_applies() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.LOW_FLOAT_TO_SLIDE)
	if move_id == "":
		## 默认表无首资料滑行招式时以注入克隆补位：适用域判定只读表数据。
		var table := _injected_slide_table()
		if table.is_empty():
			_check(false, "slide: injected LOW_FLOAT_TO_SLIDE clone unavailable")
			return
		var solver := ComboSolver.new(table)
		var invariant := solver._cycle_invariant(["S0"])
		_check(invariant.applies(), "slide: injected LOW_FLOAT_TO_SLIDE clone applies the invariant")
		_check(invariant.reason == MONOTONIC_REASON, "slide: APPLY reason byte-identical")
		return
	var invariant := _solver._cycle_invariant([move_id])
	_check(invariant.applies(), "slide: default factors apply the monotonic invariant (%s)" % move_id)
	_check(invariant.reason == MONOTONIC_REASON, "slide: APPLY reason byte-identical")


func _test_ordinary_cycle_out_of_scope() -> void:
	var a := _plain_strike_id()
	var b := _plain_strike_id()
	if a == "":
		_check(false, "scope: no plain strike in default table")
		return
	## 域外（无弹地/滑行首资料）：精确逐圈模拟口径不变，回退且不携带失败前置条件。
	var invariant := _solver._cycle_invariant([a, b])
	_check(not invariant.applies() and invariant.failed_precondition == "",
		"scope: ordinary cycle falls back without a failed precondition (exact replay preserved)")


# --- 前置条件 2：倍率有限且严格小于 1 ---


func _test_factor_one_falls_back() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	if move_id == "":
		_check(false, "factor-one: no bounce move in default table")
		return
	for key in ["NORMAL_HIT_TIME_SCALE", "SLIDE_HIT_TIME_SCALE", "BOUNCE_HIT_TIME_SCALE",
			"LANDING_LINK_HIT_TIME_SCALE", "STARTER_TIME_SCALE[3]"]:
		ComboSolver._test_cycle_factor_override = {key: 1.0}
		var invariant := _solver._cycle_invariant([move_id])
		_check(not invariant.applies() and invariant.failed_precondition == "倍率有限且严格小于 1",
			"factor-one: %s = 1.0 falls back to exact replay (snapshots can repeat verbatim)" % key)
	ComboSolver._test_cycle_factor_override = {}


func _test_illegal_factors_fall_back() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	if move_id == "":
		_check(false, "illegal-factor: no bounce move in default table")
		return
	for value in [0.0, -0.5, INF, NAN]:
		ComboSolver._test_cycle_factor_override = {"NORMAL_HIT_TIME_SCALE": value}
		var invariant := _solver._cycle_invariant([move_id])
		_check(not invariant.applies() and invariant.failed_precondition == "倍率有限且严格小于 1",
			"illegal-factor: NORMAL_HIT_TIME_SCALE = %s falls back (no monotonic argument)" % str(value))
	ComboSolver._test_cycle_factor_override = {}


# --- 前置条件 4：无浮点下溢（正规数域边界）---


func _test_underflow_boundary() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	if move_id == "":
		_check(false, "underflow: no bounce move in default table")
		return
	## 安全侧：最小倍率 0.5、视野内指数有限——保持 APPLY。
	ComboSolver._test_cycle_factor_override = {"BOUNCE_HIT_TIME_SCALE": 0.5}
	var safe := _solver._cycle_invariant([move_id])
	_check(safe.applies(), "underflow: moderate factor (0.5) stays in the normal-number domain (APPLY)")
	## 下溢侧：1e-200 的任意次幂直接冲破正规数下界——回退。
	ComboSolver._test_cycle_factor_override = {"BOUNCE_HIT_TIME_SCALE": 1e-200}
	var tiny := _solver._cycle_invariant([move_id])
	_check(not tiny.applies() and tiny.failed_precondition == "无浮点下溢",
		"underflow: 1e-200 factor underflows within the horizon (strict decrease no longer provable)")
	ComboSolver._test_cycle_factor_override = {}


## 多 HIT 参与指数：同一极小倍率下，每圈命中数更多的循环先触发下溢回退。
## 直接以注入 factors 驱动 evaluate（隔离数学面），并断言 hits_per_lap 如实计数。
func _test_multihit_exponent() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	var strike := _plain_strike_id()
	if move_id == "" or strike == "":
		_check(false, "multihit: bounce move or plain strike unavailable")
		return
	var settlement := _solver._new_session(true).settlement_state()
	var single := ComboSolver.CycleInvariant.evaluate([move_id], _solver._table, {"F": 1e-200}, settlement)
	var pair := ComboSolver.CycleInvariant.evaluate([move_id, strike], _solver._table, {"F": 1e-200}, settlement)
	_check(single.hits_per_lap >= 1 and pair.hits_per_lap > single.hits_per_lap,
		"multihit: hits_per_lap counts segments (%d vs %d after adding one strike)" % [
			single.hits_per_lap, pair.hits_per_lap])
	_check(not pair.applies() and pair.failed_precondition == "无浮点下溢",
		"multihit: multi-hit lap hits the underflow precondition")
	## 指数自校准的安全侧：单圈指数下仍处正规数域、双圈指数越界。
	var calibrate := ComboSolver.CycleInvariant.evaluate([move_id], _solver._table, {"F": 0.5}, settlement)
	_check(calibrate.applies(), "multihit: single-lap exponent stays afloat at 0.5")


# --- 前置条件 3：time_scale 属于完整循环键 ---


func _test_settlement_key_drift() -> void:
	_check(ComboSolver.CycleInvariant.settlement_covers_time_scale({"time_scale": 1.0}),
		"key-drift: settlement carrying float time_scale passes")
	_check(not ComboSolver.CycleInvariant.settlement_covers_time_scale({}),
		"key-drift: settlement without time_scale is rejected")
	_check(not ComboSolver.CycleInvariant.settlement_covers_time_scale({"time_scale": 1}),
		"key-drift: non-float time_scale is rejected")
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	if move_id == "":
		_check(false, "key-drift: no bounce move in default table")
		return
	var invariant := ComboSolver.CycleInvariant.evaluate([move_id], _solver._table,
		_solver._cycle_time_factors(), {})
	_check(not invariant.applies() and invariant.failed_precondition == "time_scale 在完整循环键中",
		"key-drift: evaluate with drifted settlement falls back (exclusion loses its basis)")
	var live := _solver._cycle_invariant([move_id])
	_check(live.applies(), "key-drift: live settlement probe carries time_scale (no drift)")


# --- 前置条件 1：每圈有效 HIT ---


func _test_lap_hit_precondition() -> void:
	var move_id := _discover_first_profile_reaction(HitProfile.Reaction.GROUND_BOUNCE)
	if move_id == "":
		_check(false, "lap-hit: no bounce move in default table")
		return
	var invariant := _solver._cycle_invariant([move_id, "NO_SUCH_MOVE"])
	_check(not invariant.applies() and invariant.failed_precondition == "每圈有效 HIT",
		"lap-hit: cycle member missing from the table falls back (no guaranteed HIT per lap)")


# --- 端到端：回退确实执行精确逐圈搜索 ---


func _test_end_to_end_fallback_runs_search() -> void:
	var table := _bounce_cycle_table()
	if table.is_empty():
		_check(false, "end-to-end: bounce cycle fixture unavailable")
		return
	var solver := ComboSolver.new(table)
	var contexts := solver._build_contexts()
	var kinds := {"C0|C1": ComboSolver.EdgeKind.CANCEL, "C1|C0": ComboSolver.EdgeKind.CANCEL}
	## 默认倍率：APPLY——不上搜索，快照计数为零。
	ComboSolver._profile_v2_reset()
	var excluded := solver._simulate_cycle(["C0", "C1"], contexts, kinds)
	var counts := ComboSolver.last_request_profile_v2()
	_check(excluded.outcome == ComboSolver.SolverCycle.Outcome.BROKEN and excluded.reason == MONOTONIC_REASON,
		"end-to-end: default factors exclude the bounce cycle with the proof-level reason")
	_check(int(counts["cycle_state_snapshots"]) == 0,
		"end-to-end: APPLY performs no lap snapshots (search skipped, count=%d)" % int(counts["cycle_state_snapshots"]))
	## 倍率=1：前置条件失败——回退精确逐圈复现，快照真实发生。
	ComboSolver._test_cycle_factor_override = {"NORMAL_HIT_TIME_SCALE": 1.0}
	ComboSolver._profile_v2_reset()
	var replayed := solver._simulate_cycle(["C0", "C1"], contexts, kinds)
	var replay_counts := ComboSolver.last_request_profile_v2()
	ComboSolver._test_cycle_factor_override = {}
	var monotonic_shortcut := replayed.outcome == ComboSolver.SolverCycle.Outcome.BROKEN \
			and replayed.reason == MONOTONIC_REASON
	_check(not monotonic_shortcut,
		"end-to-end: factor==1 falls back to exact replay (not the monotonic shortcut)")
	_check(int(replay_counts["cycle_state_snapshots"]) > 0,
		"end-to-end: fallback search really snapshots lap states (count=%d)" % int(replay_counts["cycle_state_snapshots"]))


# --- 注入表构造 ---


## 滑行首资料克隆（默认表无首资料滑行招式时的补位样本）。
func _injected_slide_table() -> Dictionary:
	var result := MoveTable.load_default()
	if not result.ok:
		return {}
	var move := MoveTable._fresh_copy(result.moves["5A"] as MoveData)
	move.move_id = "S0"
	move.action_key = "Z0"
	move.direction_derivation = ""
	for profile in move.hit_profiles:
		profile.reaction = HitProfile.Reaction.LOW_FLOAT_TO_SLIDE
	return {"S0": move}


## 双招弹地循环夹具：5A 克隆加长硬直、C0 首资料改弹地、互为取消目标——
## 适用域命中且端到端搜索可跑（真实 GameParams 倍率驱动运行时结算）。
func _bounce_cycle_table() -> Dictionary:
	var result := MoveTable.load_default()
	if not result.ok:
		return {}
	var c0 := MoveTable._fresh_copy(result.moves["5A"] as MoveData)
	var c1 := MoveTable._fresh_copy(result.moves["5A"] as MoveData)
	c0.move_id = "C0"
	c0.action_key = "X0"
	c0.direction_derivation = ""
	c1.move_id = "C1"
	c1.action_key = "X1"
	c1.direction_derivation = ""
	for move in [c0, c1]:
		for profile in move.hit_profiles:
			profile.ground_stun_frames = 30
	c0.hit_profiles[0].reaction = HitProfile.Reaction.GROUND_BOUNCE
	c0.cancel_targets = ["C1"]
	c1.cancel_targets = ["C0"]
	return {"C0": c0, "C1": c1}
