extends SceneTree

## 票据 04：_delay_dfs 前缀快照恢复的逐叶子差分 harness（ADR-0006 机械等价纪律）。
## 样本链上新旧两条路径并跑（隐藏开关 _delay_prefix_restore_disabled 强制旧路径），
## 按访问序逐叶子比较完整 run dict 投影——ok/break_kind/断链文案/verified/hit 与
## extra 序列/snapshots/proven_period/laps_observed/last_frame/末态 settlement，
## 叶子访问顺序（字典序）一致由 delays 向量逐项相等证明。样例覆盖：
##   路线模式（budget=64）jump cancel 链 / 空中起始纯取消链 / 单可调链接；
##   proof 模式（snapshot_every 逐圈快照，无预算全枚举）；
##   unpredicted_tail（票据 08 尾部放行）与恢复机制的直接兼容对拍。
## 先证 harness 在旧路径上自洽（旧对旧逐字节相同；比较器对损坏录制敏感），
## 再证恢复路径逐叶子等价；最后两轮变异验证——会话状态字段（combo.hits）与
## 求解器侧计数器（verified）各损坏一次，必须被叶子差分当场抓到（先例：seam
## 差分测试的两轮变异）。
## 运行：godot --headless --path . -s res://tests/test_delay_prefix_restore.gd
## 阶段验证（仅旧路径自洽，不测恢复）：追加参数 -- stage-a

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
	var stage_a_only := "stage-a" in OS.get_cmdline_user_args()
	_test_old_path_self_consistent()
	_test_comparator_sensitivity()
	if not stage_a_only:
		_test_route_mode_jump_chain()
		_test_route_mode_over_extended_chain()
		_test_single_adjustable()
		_test_proof_mode_snapshots()
		_test_air_start_cancel_chain()
		_test_unpredicted_tail_compat()
		_test_frozen_prefix_path()
		_test_prefix_shape()
		_test_mutation_session_state()
		_test_mutation_solver_counter()
	print("TOTAL failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


# ---------------------------------------------------------------------------
# 阶段一：旧路径自洽 + 比较器灵敏度（先于恢复路径验证）
# ---------------------------------------------------------------------------

func _test_old_path_self_consistent() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "selfcheck: jump-cancel sample unavailable on this table")
		return
	var first := _leaf_log(links, {}, false)
	var second := _leaf_log(links, {}, false)
	_check(first.size() > 0, "selfcheck: old path records %d leaves" % first.size())
	_check(first.size() == second.size(), "selfcheck: old path leaf count stable (%d == %d)" % [first.size(), second.size()])
	var identical := first.size() == second.size()
	for i in range(mini(first.size(), second.size())):
		if first[i] != second[i]:
			identical = false
			_check(false, "selfcheck: old path leaf %d not deterministic" % i)
			break
	if identical:
		_check(true, "selfcheck: old-vs-old leaf projections identical (deterministic replay)")


func _test_comparator_sensitivity() -> void:
	var links := _chain_jump_cancel(2)
	var log := _leaf_log(links, {}, false)
	if log.is_empty():
		_check(false, "sensitivity: no leaves recorded")
		return
	var corrupted_verified: Dictionary = log[0].duplicate(true)
	corrupted_verified["verified"] = int(corrupted_verified["verified"]) + 1
	_check(corrupted_verified != log[0], "sensitivity: corrupted recording caught (solver counter verified)")
	var corrupted_reason: Dictionary = log[0].duplicate(true)
	corrupted_reason["reason"] = String(corrupted_reason["reason"]) + "×"
	_check(corrupted_reason != log[0], "sensitivity: corrupted recording caught (break text)")
	var corrupted_snapshot: Dictionary = log[0].duplicate(true)
	if not (corrupted_snapshot["snapshots"] as Array).is_empty():
		corrupted_snapshot["snapshots"][0][0] = int(corrupted_snapshot["snapshots"][0][0]) + 1
		_check(corrupted_snapshot != log[0], "sensitivity: corrupted recording caught (snapshot frame)")
	else:
		_check(true, "sensitivity: sample leaf has no snapshots (skip snapshot-field probe)")


# ---------------------------------------------------------------------------
# 阶段二：新旧路径逐叶子等价
# ---------------------------------------------------------------------------

func _test_route_mode_jump_chain() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "route jump chain unavailable")
		return
	_check_leaf_equality("route/jump-cancel depth2", links, {})
	_check_restore_engaged("route/jump-cancel depth2", links, {})


func _test_route_mode_over_extended_chain() -> void:
	var links := _chain_jump_cancel(4)
	if links.size() < 4:
		_check(false, "over-extended chain unavailable (table lacks 4-deep air cancels)")
		return
	_check_leaf_equality("route/over-extended depth4", links, {})


func _test_single_adjustable() -> void:
	var links := _chain_jump_cancel(0)
	if links.is_empty():
		_check(false, "single-adjustable chain unavailable")
		return
	var adjustable := _solver._adjustable_indices(links)
	_check(adjustable.size() == 1, "single-adjustable sample has exactly one slot (got %d)" % adjustable.size())
	_check_leaf_equality("route/single-adjustable", links, {})


func _test_proof_mode_snapshots() -> void:
	var links := _chain_jump_cancel(1)
	if links.is_empty():
		_check(false, "proof-mode chain unavailable")
		return
	var opts := {"snapshot_every": 2, "max_frames": 2400}
	_check_leaf_equality("proof/snapshot-every-2", links, opts)


func _test_air_start_cancel_chain() -> void:
	var pair := _begin_air_start_chain()
	if pair.is_empty():
		_check(false, "air-start cancel chain unavailable")
		return
	var contexts := _solver._build_contexts()
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[pair[0]])
	links.append_array(_solver._links_for_edge(pair[0], pair[1], ComboSolver.EdgeKind.CANCEL))
	var deeper := _solver._table[pair[1]] as MoveData
	for candidate in deeper.cancel_targets:
		var target := _solver._table[candidate] as MoveData
		if target != null and target.stance == MoveData.Stance.AIR:
			links.append_array(_solver._links_for_edge(pair[1], candidate, ComboSolver.EdgeKind.CANCEL))
			break
	## 对拍期间保持显式空中起始——恢复叶子跳过起始探针序（prologue-skip），
	## 旧路径叶子每次全量重放探针序，直接证明两者等价。
	_check_leaf_equality("route/air-start cancels", links, {})
	_check_restore_engaged("route/air-start cancels", links, {})
	_solver._start = null


func _test_unpredicted_tail_compat() -> void:
	var links := _chain_jump_cancel(2)
	var adjustable := _solver._adjustable_indices(links)
	var prefix := _solver._capture_delay_prefix(links, adjustable, {})
	if prefix.is_empty() or prefix.has("frozen_run"):
		_check(false, "unpredicted-tail sample has no live prefix")
		return
	for j in adjustable:
		var base := 1 if links[j].trigger == ComboSolver.ChainLink.Trigger.JUMP_FRAME else 0
		links[j].wait = base
	var compiled := _solver._compile_chain(links)
	var opts := {"unpredicted_tail": true, "tail_frames": 90}
	var full_run := _solver._run_schedule(compiled, opts.duplicate())
	var restored_run := _solver._run_schedule(compiled, opts.duplicate(), prefix)
	_check(ComboSolver._test_leaf_projection(full_run) == ComboSolver._test_leaf_projection(restored_run),
		"unpredicted_tail: restored run == full-replay run (tail release + extra-hit recording intact)")


func _test_frozen_prefix_path() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "frozen sample unavailable")
		return
	## 超远钉位使基线探测在前缀区间断链（launcher 挥空、断点先于任何可调输入）
	## ——捕获返回 frozen，全部叶子按本叶子编译表替换后同值返回。
	var saved_pin: float = _solver._pin_dx
	_solver._pin_dx = 480.0
	var adjustable := _solver._adjustable_indices(links)
	var prefix := _solver._capture_delay_prefix(links, adjustable, {})
	_check(prefix.has("frozen_run"), "frozen sample: prefix-region break freezes the search")
	_check_leaf_equality("route/frozen prefix break", links, {})
	_solver._pin_dx = saved_pin


func _test_prefix_shape() -> void:
	var links := _chain_jump_cancel(2)
	var adjustable := _solver._adjustable_indices(links)
	var prefix := _solver._capture_delay_prefix(links, adjustable, {})
	if prefix.is_empty():
		_check(false, "prefix captured for jump-cancel sample")
		return
	if prefix.has("frozen_run"):
		_check(false, "prefix unexpectedly frozen (sample should replay past the boundary)")
		return
	_check(int(prefix.get("boundary", 0)) >= 2, "boundary frame >= 2 (prefix owns at least one replayed frame)")
	_check(int(prefix.get("frame", -1)) == int(prefix.get("boundary", 0)) - 1,
		"prefix frame == boundary - 1 (resume point right before the boundary)")
	_check(prefix["session_state"].get("format", "") == "CombatSessionState/v1",
		"prefix carries CombatSessionState/v1 clone")
	for key in ["frame", "physics", "verified", "ended_reasons", "snapshots",
			"extra_hit_frames", "extra_hit_moves", "extra_hit_counts",
			"proven_period", "laps_observed"]:
		_check(prefix.has(key), "prefix carries solver-side state: " + key)
	_check(int(prefix["verified"]) >= 1, "prefix verified the launcher hit (boundary past it)")
	_check(int(prefix["proven_period"]) == -1 and int(prefix["laps_observed"]) == 0,
		"prefix has no premature proof state")


# ---------------------------------------------------------------------------
# 阶段三：变异验证（损坏必须被叶子差分抓到）
# ---------------------------------------------------------------------------

func _test_mutation_session_state() -> void:
	var links := _chain_jump_cancel(2)
	ComboSolver._test_prefix_mutator = func(prefix: Dictionary) -> void:
		var combo: Dictionary = prefix["session_state"]["combo"]
		combo["hits"] = int(combo["hits"]) + 1
	_check_mutation_caught("mutation/session combo.hits", links, {},
		"corrupted session combo counter")
	ComboSolver._test_prefix_mutator = Callable()


func _test_mutation_solver_counter() -> void:
	var links := _chain_jump_cancel(2)
	ComboSolver._test_prefix_mutator = func(prefix: Dictionary) -> void:
		prefix["verified"] = int(prefix["verified"]) + 1
	_check_mutation_caught("mutation/solver verified", links, {},
		"corrupted solver-side verified counter")
	ComboSolver._test_prefix_mutator = Callable()


# ---------------------------------------------------------------------------
# 样本构造与对拍基建
# ---------------------------------------------------------------------------

## 地面 launcher（带 jump cancel 目标且可达）与其首个空中目标——表序发现，确定性。
func _discover_jump_pair() -> Array:
	var contexts := _solver._build_contexts()
	for launcher_id in _solver._table:
		var launcher := _solver._table[launcher_id] as MoveData
		if launcher == null or launcher.stance != MoveData.Stance.GROUND:
			continue
		if launcher.jump_cancel_targets.is_empty() or not contexts.has(launcher_id):
			continue
		return [launcher_id, launcher.jump_cancel_targets[0]]
	return []


## launcher 上下文 + jump cancel 空中起手 + 追加 extra_cancellels 个空中取消（表序）。
func _chain_jump_cancel(extra_cancels: int) -> Array[ComboSolver.ChainLink]:
	var pair := _discover_jump_pair()
	if pair.is_empty():
		return []
	var contexts := _solver._build_contexts()
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[pair[0]])
	links.append_array(_solver._links_for_edge(pair[0], pair[1], ComboSolver.EdgeKind.JUMP_CANCEL))
	var current: String = pair[1]
	for i in range(extra_cancels):
		var move := _solver._table[current] as MoveData
		var next := ""
		for candidate in move.cancel_targets:
			var target := _solver._table[candidate] as MoveData
			if target != null and target.stance == MoveData.Stance.AIR:
				next = candidate
				break
		if next == "":
			break
		links.append_array(_solver._links_for_edge(current, next, ComboSolver.EdgeKind.CANCEL))
		current = next
	return links


## 切到显式空中起始（air_frames=5）并返回 [空中起始招式, 首个空中取消目标]；
## 调用方负责用后把 _start 置回 null。
func _begin_air_start_chain() -> Array:
	var start := ComboSolver.SolverStartState.new()
	start.stance = MoveData.Stance.AIR
	start.air_frames = 5
	_solver._start = start
	_solver._facing = 1
	var contexts := _solver._build_contexts()
	for move_id in contexts:
		var move := _solver._table[move_id] as MoveData
		if move == null:
			continue
		for candidate in move.cancel_targets:
			var target := _solver._table[candidate] as MoveData
			if target != null and target.stance == MoveData.Stance.AIR:
				return [move_id, candidate]
	_solver._start = null
	return []


func _leaf_log(links: Array[ComboSolver.ChainLink], opts: Dictionary, restore: bool) -> Array:
	var adjustable := _solver._adjustable_indices(links)
	ComboSolver._test_delay_leaf_log = []
	ComboSolver._delay_prefix_restore_disabled = not restore
	_solver._delay_search(links, adjustable, adjustable.size(), opts.duplicate())
	var log: Array = ComboSolver._test_delay_leaf_log.duplicate()
	ComboSolver._test_delay_leaf_log = null
	ComboSolver._delay_prefix_restore_disabled = false
	return log


func _check_leaf_equality(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	var old_log := _leaf_log(links, opts, false)
	var new_log := _leaf_log(links, opts, true)
	if old_log.is_empty():
		_check(false, name + ": sample produced no leaves (no adjustable links?)")
		return
	if old_log.size() != new_log.size():
		_check(false, name + ": leaf count %d != %d (visit order diverged)" % [old_log.size(), new_log.size()])
		return
	for i in range(old_log.size()):
		if old_log[i]["delays"] != new_log[i]["delays"]:
			_check(false, name + ": leaf %d delay vector differs (%s vs %s) — lexicographic order broken" % [
				i, str(old_log[i]["delays"]), str(new_log[i]["delays"])])
			return
		if old_log[i] != new_log[i]:
			var diff_keys: Array[String] = []
			for key in old_log[i]:
				if old_log[i][key] != new_log[i].get(key):
					diff_keys.append(String(key))
			_check(false, name + ": leaf %d (delays %s) differs in [%s] — old %s / new %s" % [
				i, str(old_log[i]["delays"]), ",".join(diff_keys),
				str(old_log[i]).substr(0, 360), str(new_log[i]).substr(0, 360)])
			return
	_check(true, name + ": %d leaves identical (lexicographic order + full run dict)" % old_log.size())


## 恢复路径确实启用（否则新旧同路对拍是空洞的恒真）：样本必须捕获到活前缀。
func _check_restore_engaged(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	var adjustable := _solver._adjustable_indices(links)
	var prefix := _solver._capture_delay_prefix(links, adjustable, opts.duplicate())
	_check(not prefix.is_empty() and not prefix.has("frozen_run"),
		name + ": live prefix captured (restore path exercised, boundary=%s)" % str(prefix.get("boundary", "-")))


func _check_mutation_caught(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary, label: String) -> void:
	var old_log := _leaf_log(links, opts, false)
	var new_log := _leaf_log(links, opts, true)
	var caught := old_log.size() != new_log.size()
	if not caught:
		for i in range(mini(old_log.size(), new_log.size())):
			if old_log[i] != new_log[i]:
				caught = true
				break
	_check(caught, name + ": " + label + " detected by per-leaf diff")
