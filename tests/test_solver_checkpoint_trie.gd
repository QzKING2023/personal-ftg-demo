extends SceneTree

## P3（solver-checkpoint）：从零重放 vs checkpoint 恢复的差分 harness。
## 三层对拍：
##   1) 叶子级——旧路径（_delay_prefix_restore_disabled 强制逐叶从零全量重放，
##      oracle）vs 新路径（每层 DFS 节点捕获 checkpoint + trie 恢复）按访问序
##      逐叶子比较完整 run 投影（字典序/断链文案/计数器/快照/末态 settlement，
##      口径同 tests/test_delay_prefix_restore.gd）；
##   2) 热确定性——同一搜索连跑两遍（第二遍 trie 已热、全部从 checkpoint 恢复），
##      叶子日志逐字节相同；
##   3) 搜索级——proof 模式（snapshot_every）下新旧路径的最终搜索结果投影相等。
## 样本覆盖（票据要求）：hitstop（一切带命中的链）、landing（LANDING_CANCEL
## 落地接续）、air exit（AIR_EXIT 空中出口）、bounce（GROUND_BOUNCE 反应的
## j214D 追击链）、charge（charge_only 蓄力目标链接）、side swap（面向 -1 全套
## 复跑）、失败断点（frozen 前缀区断链 / 超长链 ended / 预算耗尽 / 观测上限
## horizon / 空中起始 prologue-skip）。
## 附加不变量：checkpoint 深冻结纪律（构造后源 dict 改写不影响）、共享 trie 的
## 跨搜索不干扰（无关搜索写过分支后复跑逐字节相同）、pin_dx scope 隔离、
## 深层 pivot 变异被抓（mutator 只腐蚀 frame>30 的深 checkpoint）。
## 运行：godot --headless --path . -s res://tests/test_solver_checkpoint_trie.gd

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
	_test_checkpoint_freeze_discipline()
	_test_hitstop_jump_chain()
	_test_landing_cancel_chain()
	_test_air_exit_chain()
	_test_bounce_chain()
	_test_charge_chain()
	_test_side_swap_facing()
	_test_failure_frozen_prefix()
	_test_failure_over_extended()
	_test_failure_budget()
	_test_failure_horizon()
	_test_air_start_prologue_skip()
	_test_warm_determinism_and_stats()
	_test_cross_search_noninterference()
	_test_scope_isolation_pin_dx()
	_test_deep_pivot_mutation()
	print("TOTAL failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


# ---------------------------------------------------------------------------
# 不可变纪律
# ---------------------------------------------------------------------------

func _test_checkpoint_freeze_discipline() -> void:
	var source := {
		"session_state": {"combo": {"hits": 3}, "clock": {"frame": 12}},
		"frame": 5, "physics": 9, "verified": 2,
		"ended_reasons": [1] as Array[int], "snapshots": [[4, {"a": 1}]] as Array,
		"extra_hit_frames": [] as Array[int], "extra_hit_moves": [] as Array[String],
		"extra_hit_counts": [] as Array[int], "proven_period": -1, "laps_observed": 0,
		"boundary": 6,
	}
	var checkpoint := ComboSolver.SessionCheckpoint.capture(source)
	source["frame"] = 99
	(source["session_state"]["combo"])["hits"] = 7
	_check(checkpoint.frame == 5 and int(checkpoint.session_state["combo"]["hits"]) == 3,
		"freeze: checkpoint deep-copies source (post-construction mutation invisible)")
	var projection := checkpoint.as_prefix()
	projection["frame"] = 42
	(projection["snapshots"] as Array).append([9, {}])
	_check(checkpoint.frame == 5 and checkpoint.snapshots.size() == 1,
		"freeze: as_prefix hands out a fresh projection (writes cannot reach checkpoint)")
	var restored := ComboSolver.SessionCheckpoint.capture(checkpoint.as_prefix())
	_check(restored.session_state == checkpoint.session_state,
		"freeze: round-trip capture keeps content identical")


# ---------------------------------------------------------------------------
# 样本链：hitstop / landing / air exit / bounce / charge
# ---------------------------------------------------------------------------

func _test_hitstop_jump_chain() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "hitstop: jump-cancel sample unavailable on this table")
		return
	_check_leaf_triple("hitstop/jump-cancel depth2", links, {})
	_check_restore_engaged("hitstop/jump-cancel depth2", links, {})


func _test_landing_cancel_chain() -> void:
	var links := _chain_via_configured_edge(ComboSolver.EdgeKind.LANDING_CANCEL, "landing_cancel_targets")
	if links.is_empty():
		_check(false, "landing: LANDING_CANCEL sample unavailable on this table")
		return
	_check_leaf_triple("landing/cancel-seam", links, {})
	_check_restore_engaged("landing/cancel-seam", links, {})


func _test_air_exit_chain() -> void:
	var links := _chain_via_configured_edge(ComboSolver.EdgeKind.AIR_EXIT, "air_exit_targets")
	if links.is_empty():
		_check(false, "air-exit: AIR_EXIT sample unavailable on this table")
		return
	_check_leaf_triple("air-exit/seam", links, {})
	_check_restore_engaged("air-exit/seam", links, {})


func _test_bounce_chain() -> void:
	var move_id := _discover_bounce_move()
	if move_id == "":
		_check(false, "bounce: no GROUND_BOUNCE reaction move in table")
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
	_check_leaf_triple("bounce/%s followup" % move_id, links, {})
	_check_restore_engaged("bounce/%s followup" % move_id, links, {})


func _test_charge_chain() -> void:
	var pair := _discover_charge_pair()
	var jump_pair := _discover_jump_pair()
	if pair.is_empty() or jump_pair.is_empty():
		_check(false, "charge: charge variant or jump chain unavailable")
		return
	## 蓄力链接挂在空中链尾部：蓄力按住帧与预期命中都进每张叶子编译表——
	## 链条在蓄力处断（no_start/ended，作失败断点样本）同样覆盖恢复路径。
	var contexts := _solver._build_contexts()
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[jump_pair[0]])
	links.append_array(_solver._links_for_edge(jump_pair[0], jump_pair[1], ComboSolver.EdgeKind.JUMP_CANCEL))
	links.append_array(_solver._links_for_edge(jump_pair[1], pair[1], ComboSolver.EdgeKind.CANCEL))
	_check_leaf_triple("charge/hold-after-air", links, {})
	_check_restore_engaged("charge/hold-after-air", links, {})


func _test_side_swap_facing() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "side-swap: sample unavailable")
		return
	_solver._facing = -1
	_check_leaf_triple("side-swap/facing-1 jump-cancel", links, {})
	_solver._facing = 1


# ---------------------------------------------------------------------------
# 失败断点
# ---------------------------------------------------------------------------

func _test_failure_frozen_prefix() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "failure/frozen: sample unavailable")
		return
	## 超远钉位使前缀区间内断链（launcher 挥空，先于任何可调输入）——全部叶子
	## 同值 frozen 返回；对拍保证 frozen 投影与从零重放逐叶相等。
	var saved_pin: float = _solver._pin_dx
	_solver._pin_dx = 480.0
	_check_leaf_triple("failure/frozen prefix break", links, {})
	_solver._pin_dx = saved_pin


func _test_failure_over_extended() -> void:
	var links := _chain_jump_cancel(4)
	if links.size() < 4:
		_check(false, "failure/over-extended: 4-deep chain unavailable")
		return
	_check_leaf_triple("failure/over-extended depth4", links, {})


func _test_failure_budget() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "failure/budget: sample unavailable")
		return
	_check_leaf_triple("failure/delay budget 1", links, {"delay_budget": 1})


func _test_failure_horizon() -> void:
	var links := _chain_jump_cancel(2)
	if links.is_empty():
		_check(false, "failure/horizon: sample unavailable")
		return
	_check_leaf_triple("failure/max_frames 60", links, {"max_frames": 60})
	_check_search_projection("failure/proof horizon search", links, {"snapshot_every": 2, "max_frames": 48})


func _test_air_start_prologue_skip() -> void:
	var pair := _begin_air_start_chain()
	if pair.is_empty():
		_check(false, "air-start: chain unavailable")
		return
	var contexts := _solver._build_contexts()
	var links: Array[ComboSolver.ChainLink] = _solver._cloned_context_links(contexts[pair[0]])
	links.append_array(_solver._links_for_edge(pair[0], pair[1], ComboSolver.EdgeKind.CANCEL))
	_check_leaf_triple("air-start/cancels prologue-skip", links, {})
	_solver._start = null


# ---------------------------------------------------------------------------
# 热确定性 / 跨搜索不干扰 / scope 隔离 / 深层变异
# ---------------------------------------------------------------------------

func _test_warm_determinism_and_stats() -> void:
	var links := _chain_jump_cancel(1)
	if links.is_empty():
		_check(false, "warm: sample unavailable")
		return
	_solver.clear_transition_memo()
	var first := _leaf_log(links, {}, true)
	_solver.clear_transition_memo()
	var second := _leaf_log(links, {}, true)
	_check(first.size() > 0 and first == second, "warm: cold and warm-search leaf logs identical")
	_check(int(_solver.transition_memo_stats()["nodes"]) > 0,
		"warm: trie recorded nodes (stats=%s)" % str(_solver.transition_memo_stats()))


func _test_cross_search_noninterference() -> void:
	var links := _chain_jump_cancel(2)
	var other := _chain_via_configured_edge(ComboSolver.EdgeKind.AIR_EXIT, "air_exit_targets")
	if links.is_empty() or other.is_empty():
		_check(false, "noninterference: samples unavailable")
		return
	var first := _leaf_log(links, {}, true)
	_leaf_log(other, {}, true)
	var again := _leaf_log(links, {}, true)
	_check(first == again,
		"noninterference: re-run identical after unrelated search wrote trie branches")


func _test_scope_isolation_pin_dx() -> void:
	var links := _chain_jump_cancel(1)
	if links.is_empty():
		_check(false, "scope: sample unavailable")
		return
	var base := _leaf_log(links, {}, true)
	_solver._pin_dx = 64.0
	_leaf_log(links, {}, true)
	_solver._pin_dx = ComboSolver.PIN_DX
	var after := _leaf_log(links, {}, true)
	_check(base == after, "scope: pin_dx change isolates trie scopes (no cross-scope graft)")


func _test_deep_pivot_mutation() -> void:
	var links := _chain_jump_cancel(3)
	if links.size() < 3:
		_check(false, "mutation: 3-deep chain unavailable")
		return
	## 只腐蚀深层 pivot 的捕获（根捕获帧最小、不受影响）——深层 checkpoint 计数器
	## 被腐蚀必须被叶子差分当场抓到。阈值先干跑记录实际捕获帧再取根帧（12×20
	## 尺度 + jC 4 后深 pivot 落在 18–28，旧 48×80 时代的 frame>30 不再命中）。
	var probe_frames := []
	ComboSolver._test_prefix_mutator = func(prefix: Dictionary) -> void:
		probe_frames.append(int(prefix["frame"]))
	_leaf_log(links, {}, true)
	ComboSolver._test_prefix_mutator = Callable()
	probe_frames.sort()
	if probe_frames.size() < 2 or probe_frames[0] == probe_frames[probe_frames.size() - 1]:
		_check(false, "mutation: deep/shallow capture frames not distinguishable on this table")
		return
	var deep_threshold: int = probe_frames[0]
	ComboSolver._test_prefix_mutator = func(prefix: Dictionary) -> void:
		if int(prefix["frame"]) > deep_threshold:
			prefix["verified"] = int(prefix["verified"]) + 1
	var old_log := _leaf_log(links, {}, false)
	var new_log := _leaf_log(links, {}, true)
	ComboSolver._test_prefix_mutator = Callable()
	var caught := old_log.size() != new_log.size()
	if not caught:
		for i in range(mini(old_log.size(), new_log.size())):
			if old_log[i] != new_log[i]:
				caught = true
				break
	_check(caught, "mutation: corrupted deep pivot checkpoint (frame > root capture %d) detected by per-leaf diff" % deep_threshold)


# ---------------------------------------------------------------------------
# 对拍基建
# ---------------------------------------------------------------------------

## 三连对拍：从零重放（oracle）→ 新路径冷跑（填 trie）→ 新路径热跑（全 checkpoint
## 恢复）。三者叶子日志必须逐字节相同。
func _check_leaf_triple(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	var old_log := _leaf_log(links, opts, false)
	var cold_log := _leaf_log(links, opts, true)
	var warm_log := _leaf_log(links, opts, true)
	if old_log.is_empty():
		_check(false, name + ": sample produced no leaves (no adjustable links?)")
		return
	if old_log.size() != cold_log.size() or old_log.size() != warm_log.size():
		_check(false, name + ": leaf count %d/%d/%d diverged (visit order broken)" % [
			old_log.size(), cold_log.size(), warm_log.size()])
		return
	for i in range(old_log.size()):
		if old_log[i]["delays"] != cold_log[i]["delays"] or old_log[i]["delays"] != warm_log[i]["delays"]:
			_check(false, name + ": leaf %d delay vector differs — lexicographic order broken" % i)
			return
		if old_log[i] != cold_log[i] or cold_log[i] != warm_log[i]:
			var diff_keys: Array[String] = []
			for key in old_log[i]:
				if old_log[i][key] != cold_log[i].get(key) or cold_log[i][key] != warm_log[i].get(key):
					diff_keys.append(String(key))
			_check(false, name + ": leaf %d (delays %s) differs in [%s] — zero %s / cold %s / warm %s" % [
				i, str(old_log[i]["delays"]), ",".join(diff_keys),
				str(old_log[i]).substr(0, 300), str(cold_log[i]).substr(0, 300), str(warm_log[i]).substr(0, 300)])
			return
	_check(true, name + ": %d leaves identical across zero-replay / cold-restore / warm-restore" % old_log.size())


## 恢复路径确实启用（恒真对拍是空洞的）：样本必须捕获到活前缀。
func _check_restore_engaged(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	var adjustable := _solver._adjustable_indices(links)
	var prefix := _solver._capture_delay_prefix(links, adjustable, opts.duplicate())
	_check(not prefix.is_empty() and not prefix.has("frozen_run"),
		name + ": live prefix captured (restore path exercised, boundary=%s)" % str(prefix.get("boundary", "-")))


## proof 模式的最终搜索结果投影对拍（叶子日志在 proof 下会因 pivot frozen 短路
## 不可比，票据 04 同款限制；搜索结果经投影比较）。
func _check_search_projection(name: String, links: Array[ComboSolver.ChainLink], opts: Dictionary) -> void:
	var adjustable := _solver._adjustable_indices(links)
	ComboSolver._delay_prefix_restore_disabled = true
	var old_run := _solver._delay_search(_clone_links(links), adjustable, adjustable.size(), opts.duplicate())
	ComboSolver._delay_prefix_restore_disabled = false
	var new_run := _solver._delay_search(_clone_links(links), adjustable, adjustable.size(), opts.duplicate())
	_check(ComboSolver._test_leaf_projection(old_run) == ComboSolver._test_leaf_projection(new_run),
		name + ": final search result projection identical (old path vs checkpoint path)")


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


func _leaf_log(links: Array[ComboSolver.ChainLink], opts: Dictionary, restore: bool) -> Array:
	var adjustable := _solver._adjustable_indices(links)
	ComboSolver._test_delay_leaf_log = []
	ComboSolver._delay_prefix_restore_disabled = not restore
	_solver._delay_search(_clone_links(links), adjustable, adjustable.size(), opts.duplicate())
	var log: Array = ComboSolver._test_delay_leaf_log.duplicate()
	ComboSolver._test_delay_leaf_log = null
	ComboSolver._delay_prefix_restore_disabled = false
	return log


# ---------------------------------------------------------------------------
# 样本构造（表序发现，确定性）
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


## 配置了指定接缝目标的可达招式：[from, to]；from 的上下文 + 该接缝边构成样本链。
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
		if move == null:
			continue
		for profile in move.hit_profiles:
			if profile.reaction == HitProfile.Reaction.GROUND_BOUNCE:
				return move_id
	return ""


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
