extends SceneTree

## P4（solver-delay-dp）：旧 DFS vs 精确 delay state DP 的 Tier A 差分 harness。
## DP 唯一启用域是证明模式（snapshot_every>0，循环证明搜索）；路线模式的延迟
## 预算按叶子执行扣减、与「哪些向量被验证过」耦合，合并会移动 64 向量观测
## 上限的截断点与最远失败归属——路线模式保持旧 DFS（专项断言钉死 DP 开关不
## 影响路线结果与逐叶日志）。对拍三面：
##   1) 搜索级——proof 模式同一链 _delay_dp_disabled=true/false 两跑，最终搜索
##      结果投影（_test_leaf_projection 口径：ok/断链文案/计数器/快照/末态
##      settlement/compiled hit_frames）全等；
##   2) 计量级——DP 路径的 delay_dfs_nodes / delay_dfs_leaves 相对旧 DFS 不增
##      （合并只减不增；相等=该样本无合并发生，如实计数不强充）；
##   3) 确定性——DP 连跑两遍投影全等（备忘录为确定性数据结构，访问序确定）。
## 样本覆盖（票据要求）：hitstop 跳链、landing 接缝、air exit、bounce 追击、
## charge 蓄力、side swap（面向 -1）、多段命中（表内可达时）、失败域（frozen
## 前缀断链、超长链、观测上限截断、预算耗尽、全失败延迟向量）。
## 附加：DP 计账非空洞（证明搜索确实建键），实例级 stats 如实累计。
## 运行：godot --headless --path . -s res://tests/test_solver_delay_dp.gd

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
	_test_hitstop_jump_chains()
	_test_landing_cancel_chain()
	_test_air_exit_chain()
	_test_bounce_chain()
	_test_charge_chain()
	_test_side_swap_facing()
	_test_multisegment_chain()
	_test_air_start_chain()
	_test_failure_frozen_prefix()
	_test_failure_over_extended()
	_test_failure_horizon()
	_test_route_mode_untouched()
	_test_dp_accounting()
	print("TOTAL failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


# ---------------------------------------------------------------------------
# proof 模式样本（DP 域）
# ---------------------------------------------------------------------------

func _test_hitstop_jump_chains() -> void:
	for depth in [1, 2, 3]:
		var links := _chain_jump_cancel(depth)
		if links.is_empty():
			_check(false, "hitstop: jump-cancel depth%d sample unavailable" % depth)
			continue
		_check_proof_search("hitstop/jump-cancel depth%d" % depth, links, {"snapshot_every": 2})


func _test_landing_cancel_chain() -> void:
	var links := _chain_via_configured_edge(ComboSolver.EdgeKind.LANDING_CANCEL, "landing_cancel_targets")
	if links.is_empty():
		_check(false, "landing: LANDING_CANCEL sample unavailable")
		return
	_check_proof_search("landing/cancel-seam", links, {"snapshot_every": 2})


func _test_air_exit_chain() -> void:
	var links := _chain_via_configured_edge(ComboSolver.EdgeKind.AIR_EXIT, "air_exit_targets")
	if links.is_empty():
		_check(false, "air-exit: AIR_EXIT sample unavailable")
		return
	_check_proof_search("air-exit/seam", links, {"snapshot_every": 2})


func _test_bounce_chain() -> void:
	var move_id := _discover_bounce_move()
	if move_id == "":
		_check(false, "bounce: no GROUND_BOUNCE first-profile move in table")
		return
	var contexts := _solver._build_contexts()
	if not contexts.has(move_id):
		_check(false, "bounce: %s has no arrival context" % move_id)
		return
	var move := _solver._table[move_id] as MoveData
	if move.link_targets.is_empty() and move.cancel_targets.is_empty():
		_check(false, "bounce: %s has no followup target" % move_id)
		return
	var kind := ComboSolver.EdgeKind.NORMAL_LINK if not move.link_targets.is_empty() else ComboSolver.EdgeKind.CANCEL
	var target: String = move.link_targets[0] if not move.link_targets.is_empty() else move.cancel_targets[0]
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[move_id])
	links.append_array(_solver._links_for_edge(move_id, target, kind))
	_check_proof_search("bounce/%s followup" % move_id, links, {"snapshot_every": 2})


func _test_charge_chain() -> void:
	var pair := _discover_charge_pair()
	var jump_pair := _discover_jump_pair()
	if pair.is_empty() or jump_pair.is_empty():
		_check(false, "charge: charge variant or jump chain unavailable")
		return
	var contexts := _solver._build_contexts()
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[jump_pair[0]])
	links.append_array(_solver._links_for_edge(jump_pair[0], jump_pair[1], ComboSolver.EdgeKind.JUMP_CANCEL))
	links.append_array(_solver._links_for_edge(jump_pair[1], pair[1], ComboSolver.EdgeKind.CANCEL))
	_check_proof_search("charge/hold-after-air", links, {"snapshot_every": 2})


func _test_side_swap_facing() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "side-swap: sample unavailable")
		return
	_solver._facing = -1
	_check_proof_search("side-swap/facing-1 jump-cancel", links, {"snapshot_every": 2})
	_solver._facing = 1


func _test_air_start_chain() -> void:
	var pair := _begin_air_start_chain()
	if pair.is_empty():
		_check(false, "air-start: chain unavailable")
		return
	var contexts := _solver._build_contexts()
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[pair[0]])
	links.append_array(_solver._links_for_edge(pair[0], pair[1], ComboSolver.EdgeKind.CANCEL))
	_check_proof_search("air-start/cancels prologue-skip", links, {"snapshot_every": 2})
	_solver._start = null


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


func _test_multisegment_chain() -> void:
	var links := _chain_into_multisegment()
	if not links.is_empty():
		_check_proof_search("multisegment/proof", links, {"snapshot_every": 3})
		return
	## 默认表的多段招式（236C）只能从地面普通技必杀取消进入、且无出边——空中
	## 链与多段命中无法共存于同一配置链。注入 jB 落地接缝指向 236C 构造样本
	##（6A jump cancel → jB → 落地取消 236C），两种路径看同一张注入表。
	var injected := _multisegment_table()
	if injected.is_empty():
		_check(false, "multisegment: multi-segment sample unavailable even with injection")
		return
	var solver := ComboSolver.new(injected)
	var contexts := solver._build_contexts()
	var pair := []
	for launcher_id in injected:
		var launcher := injected[launcher_id] as MoveData
		if launcher == null or launcher.stance != MoveData.Stance.GROUND:
			continue
		if launcher.jump_cancel_targets.is_empty() or not contexts.has(launcher_id):
			continue
		pair = [launcher_id, launcher.jump_cancel_targets[0]]
		break
	if pair.is_empty():
		_check(false, "multisegment: injected table has no jump-cancel launcher")
		return
	var ms_links: Array[ComboSolver.ChainLink] = solver._cloned_context_links(contexts[pair[0]])
	ms_links.append_array(solver._links_for_edge(pair[0], pair[1], ComboSolver.EdgeKind.JUMP_CANCEL))
	ms_links.append_array(solver._links_for_edge(pair[1], "236C", ComboSolver.EdgeKind.LANDING_CANCEL))
	_check_proof_search_on(solver, "multisegment/jB-landing-into-236C", ms_links, {"snapshot_every": 3})


func _multisegment_table() -> Dictionary:
	var result := MoveTable.load_default()
	if not result.ok:
		return {}
	var table := {}
	for move_id in result.moves:
		table[move_id] = result.moves[move_id]
	var jb := MoveTable._fresh_copy(table["jB"] as MoveData)
	jb.landing_cancel_targets = ["236C"]
	table["jB"] = jb
	return table


# ---------------------------------------------------------------------------
# 失败域
# ---------------------------------------------------------------------------

func _test_failure_frozen_prefix() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "failure/frozen: sample unavailable")
		return
	## 超远钉位：前缀区间内断链（launcher 挥空，先于任何可调输入）——frozen
	## 短路在 DP 之前发生，两种路径都必须逐字节相同。
	var saved_pin: float = _solver._pin_dx
	_solver._pin_dx = 480.0
	_check_proof_search("failure/frozen prefix break", links, {"snapshot_every": 2})
	_solver._pin_dx = saved_pin


func _test_failure_over_extended() -> void:
	var links := _chain_jump_cancel(4)
	if links.size() < 4:
		_check(false, "failure/over-extended: 4-deep chain unavailable")
		return
	_check_proof_search("failure/over-extended depth4", links, {"snapshot_every": 3, "max_frames": 96})


func _test_failure_horizon() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "failure/horizon: sample unavailable")
		return
	_check_proof_search("failure/proof horizon", links, {"snapshot_every": 2, "max_frames": 48})


# ---------------------------------------------------------------------------
# 路线模式不受 DP 影响
# ---------------------------------------------------------------------------

func _test_route_mode_untouched() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "route-untouched: sample unavailable")
		return
	var adjustable := _solver._adjustable_indices(links)
	## 预算语义：64 向量观测上限按叶子执行扣减——DP 开关不得改变路线结果。
	ComboSolver._delay_dp_disabled = true
	var old_run := _solver._delay_search(_clone_links(links), adjustable, adjustable.size(), {})
	ComboSolver._delay_dp_disabled = false
	var new_run := _solver._delay_search(_clone_links(links), adjustable, adjustable.size(), {})
	ComboSolver._delay_dp_disabled = false
	_check(ComboSolver._test_leaf_projection(old_run) == ComboSolver._test_leaf_projection(new_run),
		"route-untouched: route-mode search projection identical with DP switch off/on")
	## 逐叶日志（访问序/字典序/预算截断点）：DP 开关前后逐字节相同。
	var log_off := _route_leaf_log(links, {}, true)
	var log_on := _route_leaf_log(links, {}, false)
	_check(log_off.size() > 0 and log_off == log_on,
		"route-untouched: route-mode leaf log identical with DP switch (%d leaves)" % log_off.size())
	## 预算截断点：全部失败的路线（超远钉位使链条在前缀区间断链、逐叶如实执行）
	## 在 3 向量预算处截断——DP 开关不得移动截断点。
	var saved_pin: float = _solver._pin_dx
	_solver._pin_dx = 480.0
	var budget_off := _route_leaf_log(links, {"delay_budget": 3}, true)
	var budget_on := _route_leaf_log(links, {"delay_budget": 3}, false)
	_solver._pin_dx = saved_pin
	_check(budget_off.size() == 3 and budget_off == budget_on,
		"route-untouched: budget-truncated leaf log identical (%d vectors executed)" % budget_off.size())


func _route_leaf_log(links: Array[ComboSolver.ChainLink], opts: Dictionary, dp_disabled: bool) -> Array:
	var adjustable := _solver._adjustable_indices(links)
	ComboSolver._test_delay_leaf_log = []
	ComboSolver._delay_dp_disabled = dp_disabled
	_solver._delay_search(_clone_links(links), adjustable, adjustable.size(), opts.duplicate())
	var log: Array = ComboSolver._test_delay_leaf_log.duplicate()
	ComboSolver._test_delay_leaf_log = null
	ComboSolver._delay_dp_disabled = false
	return log


# ---------------------------------------------------------------------------
# DP 计账
# ---------------------------------------------------------------------------

func _test_dp_accounting() -> void:
	var stats := _solver.delay_dp_stats()
	_check(int(stats["searches"]) > 0 and int(stats["nodes"]) > 0,
		"dp-accounting: proof searches keyed DP nodes (searches=%d nodes=%d stores=%d hits=%d)" % [
			int(stats["searches"]), int(stats["nodes"]), int(stats["stores"]), int(stats["hits"]),
		])
	_solver.reset_delay_dp_stats()
	var after := _solver.delay_dp_stats()
	_check(int(after["searches"]) == 0 and int(after["nodes"]) == 0,
		"dp-accounting: reset clears totals")
	var links := _chain_jump_cancel(1)
	if links.is_empty():
		return
	_solver._delay_search(_clone_links(links), _solver._adjustable_indices(links), 1, {"snapshot_every": 2})
	var refilled := _solver.delay_dp_stats()
	_check(int(refilled["searches"]) == 1 and int(refilled["nodes"]) > 0,
		"dp-accounting: single proof search books one DP context")


# ---------------------------------------------------------------------------
# 对拍基建
# ---------------------------------------------------------------------------

func _check_proof_search(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	_check_proof_search_on(_solver, name, links, opts)


func _check_proof_search_on(solver: ComboSolver, name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	var adjustable := solver._adjustable_indices(links)
	if adjustable.is_empty():
		_check(false, name + ": sample has no adjustable links (DP domain empty)")
		return
	var old_result := _search_recorded_on(solver, links, opts, true)
	var dp_result := _search_recorded_on(solver, links, opts, false)
	var dp_again := _search_recorded_on(solver, links, opts, false)
	var old_projection := ComboSolver._test_leaf_projection(old_result["run"])
	var dp_projection := ComboSolver._test_leaf_projection(dp_result["run"])
	if old_projection != dp_projection:
		var diff_keys: Array[String] = []
		for key in old_projection:
			if old_projection[key] != dp_projection.get(key):
				diff_keys.append(String(key))
		_check(false, name + ": old DFS vs DP differ in [%s] — old %s / dp %s" % [
			",".join(diff_keys), str(old_projection).substr(0, 300), str(dp_projection).substr(0, 300)])
		return
	_check(true, name + ": final search projection identical (old DFS vs DP, %d leaves old / %d dp)" % [
		int(old_result["leaves"]), int(dp_result["leaves"])])
	_check(ComboSolver._test_leaf_projection(dp_result["run"]) == ComboSolver._test_leaf_projection(dp_again["run"]),
		name + ": DP deterministic across repeats")
	_check(int(dp_result["nodes"]) <= int(old_result["nodes"]) and int(dp_result["leaves"]) <= int(old_result["leaves"]),
		name + ": DP search shape not larger (nodes %d<=%d, leaves %d<=%d)" % [
			int(dp_result["nodes"]), int(old_result["nodes"]), int(dp_result["leaves"]), int(old_result["leaves"])])


func _search_recorded_on(solver: ComboSolver, links: Array[ComboSolver.ChainLink], opts: Dictionary, old_path: bool) -> Dictionary:
	ComboSolver._delay_dp_disabled = old_path
	ComboSolver._profile_v2_reset()
	var adjustable := solver._adjustable_indices(links)
	var run := solver._delay_search(_clone_links(links), adjustable, adjustable.size(), opts.duplicate())
	var counts := ComboSolver.last_request_profile_v2()
	ComboSolver._delay_dp_disabled = false
	return {
		"run": run,
		"nodes": int(counts["delay_dfs_nodes"]),
		"leaves": int(counts["delay_dfs_leaves"]),
	}


func _clone_links(links: Array[ComboSolver.ChainLink]) -> Array[ComboSolver.ChainLink]:
	var copy: Array[ComboSolver.ChainLink] = []
	for link in links:
		var cloned := ComboSolver.ChainLink.new()
		cloned.move_id = link.move_id
		cloned.key = link.key
		cloned.trigger = link.trigger
		cloned.wait = link.wait
		cloned.press_space = link.press_space
		cloned.feed = link.feed
		cloned.rekka = link.rekka
		cloned.charged = link.charged
		cloned.via_text = link.via_text
		copy.append(cloned)
	return copy


# ---------------------------------------------------------------------------
# 样本构造（表序发现，确定性；与 test_solver_checkpoint_trie 同口径）
# ---------------------------------------------------------------------------

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


func _chain_via_configured_edge(kind: ComboSolver.EdgeKind, config_field: String) -> Array[ComboSolver.ChainLink]:
	var contexts := _solver._build_contexts()
	for from_id in _solver._table:
		var move := _solver._table[from_id] as MoveData
		if move == null or not contexts.has(from_id):
			continue
		var targets = move.get(config_field)
		if targets == null or targets.is_empty():
			continue
		var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[from_id])
		links.append_array(_solver._links_for_edge(from_id, targets[0], kind))
		return links
	return []


func _discover_charge_pair() -> Array:
	for from_id in _solver._table:
		var base := _solver._table[from_id] as MoveData
		if base != null and base.charge_move_id != "" and _solver._table.has(base.charge_move_id):
			return [from_id, base.charge_move_id]
	return []


func _discover_bounce_move() -> String:
	for move_id in _solver._table:
		var move := _solver._table[move_id] as MoveData
		if move == null or move.hit_profiles.is_empty():
			continue
		if move.hit_profiles[0].reaction == HitProfile.Reaction.GROUND_BOUNCE:
			return move_id
	return ""


## 可达的多段招式样本：任一配置接缝指向 segment_count()>1 的目标（表序首个），
## 且链上须含空中链（可调延迟槽）——否则不在 DP 域内，交给注入样本。
func _chain_into_multisegment() -> Array[ComboSolver.ChainLink]:
	var contexts := _solver._build_contexts()
	var kinds := {
		"cancel_targets": ComboSolver.EdgeKind.CANCEL,
		"chain_cancel_targets": ComboSolver.EdgeKind.CHAIN_CANCEL,
		"special_cancel_targets": ComboSolver.EdgeKind.SPECIAL_CANCEL,
		"link_targets": ComboSolver.EdgeKind.NORMAL_LINK,
	}
	for from_id in _solver._table:
		var move := _solver._table[from_id] as MoveData
		if move == null or not contexts.has(from_id):
			continue
		for field in kinds:
			var targets = move.get(field)
			if targets == null or targets.is_empty():
				continue
			for candidate in targets:
				var target := _solver._table[candidate] as MoveData
				if target == null or target.segment_count() < 2:
					continue
				var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[from_id])
				links.append_array(_solver._links_for_edge(from_id, candidate, kinds[field]))
				if not _solver._adjustable_indices(links).is_empty():
					return links
	return []
