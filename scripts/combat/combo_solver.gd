class_name ComboSolver
extends RefCounted
## 开发期 Combo Solver：地面与空中接续验证、有限资源区分与循环报告（旧 ftg-combo issue 06 + 07）。
## 只读招式数据，用一次性 CombatSession 探针得出与运行时一致的接续结论——
## 前摇、等待时间、取消窗口、木桩硬直、地面/空中姿态、方向派生、jump cancel 与
## 落地接缝都在真实结算中检验，不在 Solver 里复刻第二套帧物理。
## 约束：不修改任何运行时战斗状态（所有探针使用私有会话，与训练场会话无关）；
## 不设全局命中数或总时长上限——循环以「逐圈模拟 + 木桩时序状态重现」证明，
## 观测上限内不断链的回边保守上报为循环，不会被上限掩盖。
## 有限资源不被视为可自动续期：玩家滞空固定且空中无二段跳，木桩浮空不被普通命中
## 刷新——只有每圈由真实命中重建资源的回边才能通过逐圈模拟。
## 几何接触是假设不是证明：探针把木桩钉在玩家面前（面向侧），不证明空间/中立/
## 碰撞连接；空中段只能经配置的 jump cancel 进入，普通跳跃/中立空中起手不在证明范围。

## 探针站位：玩家中心与木桩中心的横向间距（命中框中段，面向侧，几何接触假设）。
const PIN_DX := 70.0
## 逐圈模拟的观测上限（圈数/帧数）。仅用于防止死循环，不是连段语义的一部分；
## 达到上限仍未断链的回边保守上报为循环（宁可误报，不可掩盖）。
const MAX_CYCLE_LAPS := 8
const MAX_CYCLE_FRAMES := 2400
## 单招探针观测木桩恢复的帧数上限。
const RECOVER_HORIZON := 240
## 空中段首按延迟（相对起跳后第 1 帧）的扫描上限；超过玩家滞空的延迟必然失效。
const MAX_AIR_DELAY := GameParams.PLAYER_JUMP_AIRTIME_FRAMES

const SCOPE_TEXT := "证明范围：仅覆盖招式表配置的确定性命中确认接续——前摇、等待时间、取消窗口、木桩硬直、地面/空中姿态、方向派生、jump cancel 与落地接缝都在真实 CombatSession 结算中检验；不证明任意空间、中立或碰撞连接（探针把木桩钉在玩家面前，几何接触是假设）；空中段只能经配置的 jump cancel 进入，普通跳跃/中立空中起手不在证明范围；玩家滞空与木桩浮空是有限资源（普通命中不刷新木桩滞空、空中无二段跳），不会被当作可自动续期；循环判定不设全局命中数或总时长上限，以逐圈模拟加木桩时序状态重现证明。报告帧号与年龄按正常战斗帧计：命中后的 Hitstop 冻结物理帧不消耗窗口，回放时以空输入跳过（issue 14）。"

## 接续边类型：普通命中确认取消 / jump cancel / 显式落地接续。
enum EdgeKind {
	CANCEL,          ## cancel_targets：同姿态命中确认取消（地面→地面、空中→空中）
	JUMP_CANCEL,     ## jump_cancel_targets：地面招式命中确认后 Space 起跳接空中起手
	LANDING_CANCEL,  ## landing_cancel_targets：空中招式命中确认后，取消窗口内的落地帧接地面招式
}


## 输入表中的一条按帧输入（方向喂入、Space、动作键可共存于同一帧）。
class ScheduledInput extends RefCounted:
	var frame := 0
	var axis := 0
	var down := false
	var jump := false
	var key := ""

	func to_frame_input() -> FrameInput:
		return FrameInput.make(axis, jump, key, down)


## 接续链中的一段：某招式如何被按出来。触发点决定按键帧——
## START 从第 1 帧起手（方向派生先喂方向序列）；PREV_HIT 在上一招命中确认后
## 第 wait 帧按键（命中确认取消）；JUMP_FRAME 在 Space 起跳后第 wait 帧按键
## （jump cancel 空中起手，wait = 1 + 空中延迟 d）；LAND_FRAME 在预测的落地帧
## 按键（显式落地接续：落地当帧把缓存键按地面姿态重解析并消费）。
class ChainLink extends RefCounted:
	enum Trigger { START, PREV_HIT, JUMP_FRAME, LAND_FRAME }

	var move_id := ""
	var key := ""
	var trigger: Trigger = Trigger.START
	var wait := 0
	var press_space := false
	var feed := ""


## 一条候选接续边：from 招式命中确认后接续进 to 招式。
class SolverEdge extends RefCounted:
	var from_id := ""
	var to_id := ""
	var kind: EdgeKind = EdgeKind.CANCEL
	var valid := false
	var reason := ""
	## 有效等待范围（命中确认后第 wait_from–wait_to 帧取消，含两端）：
	## 取消须在窗口内、且目标命中（等待 + 目标前摇）不晚于木桩恢复。无效边为空（wait_to < 0）。
	var wait_from := 0
	var wait_to := -1
	## 目标最早命中落在命中确认后第几帧（最早取消 w=0 + 目标前摇）。
	var hit_age := -1
	## 木桩可追击至命中确认后第几帧（含；命中判定先于当帧恢复结算）。
	var recover_age := -1
	## 落地接续专用：空中命中允许落在落地帧前 align_from–align_to 帧
	## （align_from = 0 即命中恰在落地帧当帧——临界帧规则）。
	var align_from := -1
	var align_to := -1
	## 落地接续专用：最晚对齐档（命中恰在落地帧或最接近）的完整输入表，供与运行时对拍。
	var align_inputs: Array[ScheduledInput] = []

	func label() -> String:
		return "%s → %s" % [from_id, to_id]

	func kind_text() -> String:
		match kind:
			EdgeKind.JUMP_CANCEL:
				return "jump cancel"
			EdgeKind.LANDING_CANCEL:
				return "落地接续"
		return "取消"


## 一条经逐帧模拟验证的可读路线（合法接续链，含命中帧、伤害与完整输入表）。
class SolverRoute extends RefCounted:
	var move_ids: Array[String] = []
	var hit_frames: Array[int] = []
	var combo_hits := 0
	var total_damage := 0.0
	var note := ""
	## 本路线的逐帧输入表（含方向喂入、Space 与落地帧按键），回放到全新
	## CombatSession 应逐帧复现 hit_frames / combo_hits / total_damage。
	var inputs: Array[ScheduledInput] = []

	func label() -> String:
		return " → ".join(move_ids)


## 一个经逐圈模拟验证的循环。
class SolverCycle extends RefCounted:
	var route: Array[String] = []
	## 一圈的帧数；仅 proven 时有意义。
	var period_frames := -1
	## 木桩时序状态在两圈之间完全重现（循环可无限重复的证明）。
	var proven := false
	## 是否上报为有效循环（proven，或观测上限内未断链的保守上报）。
	var sustained := false
	var laps_observed := 0
	var reason := ""

	func label() -> String:
		return " → ".join(route) + " → 回到 " + route[0]


## 分析报告：接续边、可读路线、循环与可读文本。refused = 招式表未通过校验，
## Solver 拒绝分析且不产出任何结论（与训练场观察同一拒绝原因，issue 11）。
class SolverReport extends RefCounted:
	var safe := true
	var summary := ""
	var scope := ""
	var edges: Array[SolverEdge] = []
	var routes: Array[SolverRoute] = []
	var cycles: Array[SolverCycle] = []
	var notes: Array[String] = []
	var refused := false
	var refusal_reason := ""
	## 共享招式表摘要行（设计者核对资源编辑是否进入报告，issue 11）。
	var table_lines: Array[String] = []

	func to_lines() -> Array[String]:
		var lines: Array[String] = []
		lines.append("=== Combo Solver：地面与空中接续验证 ===")
		if refused:
			lines.append("拒绝分析：招式表未通过校验——" + refusal_reason)
			lines.append("修改招式资源后重新分析；Solver 与训练场使用同一份 manifest，两处会同步拒绝。")
			return lines
		lines.append(summary)
		lines.append(scope)
		lines.append("--- 共享招式表 ---")
		if table_lines.is_empty():
			lines.append("（招式表为程序注入，无共享资源摘要）")
		for line in table_lines:
			lines.append(line)
		lines.append("--- 接续边 ---")
		if edges.is_empty():
			lines.append("（招式表中没有可分析的接续边）")
		for edge in edges:
			lines.append("%s（%s）：%s｜%s" % [edge.label(), edge.kind_text(), "有效" if edge.valid else "排除", edge.reason])
		lines.append("--- 可读路线 ---")
		if routes.is_empty():
			lines.append("（无可读路线）")
		for route in routes:
			var frames := ", ".join(route.hit_frames.map(func(frame: int) -> String: return str(frame)))
			var suffix := "（%s）" % route.note if route.note != "" else ""
			lines.append("%s：命中帧 %s，%d hit，伤害 %.1f%s" % [route.label(), frames, route.combo_hits, route.total_damage, suffix])
		lines.append("--- 循环 ---")
		if cycles.is_empty():
			lines.append("未发现可无限重复的有效循环。")
		for cycle in cycles:
			var period := ("周期 %d 帧，" % cycle.period_frames) if cycle.period_frames > 0 else ""
			lines.append("%s：%s%s" % [cycle.label(), period, cycle.reason])
		for note in notes:
			lines.append("注：%s" % note)
		return lines


var _table: Dictionary = {}


func _init(move_table: Dictionary) -> void:
	_table = move_table


## 分析共享 manifest 指向的招式表；表未通过校验时拒绝分析并报告同一原因。
static func analyze_manifest(manifest_path: String) -> SolverReport:
	var result := MoveTable.load_manifest(manifest_path)
	if not result.ok:
		return _refused_report(result)
	return ComboSolver.new(result.moves)._analyze()


## 分析招式表：生成确定性接续边、可读路线与循环报告。不修改任何运行时战斗状态。
## 默认分析共享 manifest（与训练场同一份已校验数据）；显式传入字典用于注入实验表。
static func analyze(move_table: Dictionary = {}) -> SolverReport:
	var table := move_table
	if table.is_empty():
		var result := MoveTable.load_default()
		if not result.ok:
			return _refused_report(result)
		table = result.moves
	return ComboSolver.new(table)._analyze()


static func _refused_report(result) -> SolverReport:
	var report := SolverReport.new()
	report.refused = true
	report.refusal_reason = result.first_error()
	report.summary = "招式表未通过校验，拒绝分析：%s" % report.refusal_reason
	report.scope = SCOPE_TEXT
	return report


# --- 分析主体 ---

func _analyze() -> SolverReport:
	var report := SolverReport.new()
	report.scope = SCOPE_TEXT
	report.table_lines = _table_summary_lines()
	var contexts := _build_contexts()
	var timing_cache := {}
	var valid_adj := {}
	var edge_kinds := {}
	for from_id in _table:
		var from_move := _table[from_id] as MoveData
		## 投技不走单键/取消链起手（投技行为在后续 issue 实装），不进入接续图。
		if from_move == null or from_move.is_throw():
			continue
		var kinds_and_targets := [
			[EdgeKind.CANCEL, from_move.cancel_targets],
			[EdgeKind.JUMP_CANCEL, from_move.jump_cancel_targets],
			[EdgeKind.LANDING_CANCEL, from_move.landing_cancel_targets],
		]
		for pair in kinds_and_targets:
			var kind: EdgeKind = pair[0]
			for to_id in pair[1]:
				var edge := _build_edge(from_id, to_id, kind, contexts, timing_cache)
				report.edges.append(edge)
				if edge.valid:
					if not valid_adj.has(from_id):
						valid_adj[from_id] = [] as Array[String]
					var targets: Array[String] = valid_adj[from_id]
					if not targets.has(to_id):
						targets.append(to_id)
					# 同一 (from, to) 配置了多种接续时，路线/循环按首先验证成立的接缝出链：
					# 枚举顺序固定为 取消 > jump cancel > 落地接续，确定性且优先普通取消。
					var key := "%s|%s" % [from_id, to_id]
					if not edge_kinds.has(key):
						edge_kinds[key] = kind
	## 图的路线起点：可用普通动作键（5X）起手、无方向派生的地面招式（按表内顺序，确定性枚举）。
	var sources: Array[String] = []
	for move_id in _table:
		if _is_plain_ground_id(move_id):
			sources.append(move_id)
	for start_id in sources:
		_walk_routes(start_id, [start_id], valid_adj, report.routes, contexts, edge_kinds)
	for cycle_ids in _elementary_cycles(valid_adj):
		var cycle := _simulate_cycle(cycle_ids, contexts, edge_kinds)
		if cycle.sustained:
			report.cycles.append(cycle)
		else:
			report.notes.append("结构性循环 %s 在逐圈模拟中断开，不构成有效循环：%s" % [
				" → ".join(cycle_ids) + " → 回到 " + cycle_ids[0], cycle.reason,
			])
	report.safe = report.cycles.is_empty()
	report.summary = _build_summary(report)
	return report


## 共享招式表摘要行：设计者编辑资源（帧数/伤害/属性/优先级）后可直接在报告中核对。
func _table_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for move_id in _table:
		var move := _table[move_id] as MoveData
		if move == null:
			continue
		var stance_text := "地面" if move.stance == MoveData.Stance.GROUND else "空中"
		var kind_text := "投技" if move.is_throw() else "打击"
		var binding := "组合 B+C" if move.is_throw() else "%s键" % move.action_key
		if move.direction_derivation != "":
			binding += " 派生 %s" % move.direction_derivation
		lines.append("%s｜%s%s %s｜%d/%d/%d 帧｜伤害 %d｜属性 %s｜优先级 %d" % [
			move_id, stance_text, kind_text, binding,
			move.startup_frames, move.active_frames, move.recovery_frames,
			move.base_damage, move.attribute_label(), move.priority,
		])
	return lines


func _build_summary(report: SolverReport) -> String:
	var valid_count := 0
	for edge in report.edges:
		if edge.valid:
			valid_count += 1
	if report.safe:
		return "未发现可无限重复的有效循环：接续边 %d 条（有效 %d、排除 %d），可读路线 %d 条。" % [
			report.edges.size(), valid_count, report.edges.size() - valid_count, report.routes.size(),
		]
	var parts: Array[String] = []
	for cycle in report.cycles:
		var period := ("，周期 %d 帧" % cycle.period_frames) if cycle.period_frames > 0 else ""
		parts.append(cycle.label() + period)
	return "检测到 %d 个有效循环：%s；命中确认取消链可在木桩自然受身前无限重复，请调整招式数据。" % [
		report.cycles.size(), "；".join(parts),
	]


# --- 上下文：如何从中立地面按出某招 ---

## 每个可达招式的入口接续链：地面普通招式/方向派生直接起手；空中招式优先经
## 表内第一个可达 launcher 的 jump cancel 进入，其次经已可达空中招式的取消进入。
func _build_contexts() -> Dictionary:
	var contexts := {}
	for move_id in _table:
		var move := _table[move_id] as MoveData
		if move == null or move.stance != MoveData.Stance.GROUND:
			continue
		var key := _start_key_for(move_id)
		if key == "":
			continue
		var start := ChainLink.new()
		start.move_id = move_id
		start.key = key
		start.feed = _feed_for(move_id)
		start.trigger = ChainLink.Trigger.START
		var links: Array[ChainLink] = [start]
		contexts[move_id] = links
	var grew := true
	while grew:
		grew = false
		for move_id in _table:
			if contexts.has(move_id):
				continue
			var move := _table[move_id] as MoveData
			if move == null or move.stance != MoveData.Stance.AIR or _start_key_for(move_id) == "":
				continue
			var links := _air_context_via_jump(move_id, contexts)
			if links.is_empty():
				links = _air_context_via_cancel(move_id, contexts)
			if not links.is_empty():
				contexts[move_id] = links
				grew = true
	return contexts


func _air_context_via_jump(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	for launcher_id in _table:
		var launcher := _table[launcher_id] as MoveData
		if launcher == null or launcher.stance != MoveData.Stance.GROUND:
			continue
		if not (launcher.jump_cancel_targets as Array[String]).has(move_id):
			continue
		if not contexts.has(launcher_id):
			continue
		var links: Array[ChainLink] = (contexts[launcher_id] as Array[ChainLink]).duplicate()
		links.append_array(_links_for_edge(launcher_id, move_id, EdgeKind.JUMP_CANCEL))
		return links
	return []


func _air_context_via_cancel(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	for source_id in _table:
		var source := _table[source_id] as MoveData
		if source == null or source.stance != MoveData.Stance.AIR:
			continue
		if not (source.cancel_targets as Array[String]).has(move_id):
			continue
		if not contexts.has(source_id):
			continue
		var links: Array[ChainLink] = (contexts[source_id] as Array[ChainLink]).duplicate()
		links.append_array(_links_for_edge(source_id, move_id, EdgeKind.CANCEL))
		return links
	return []


# --- 接续边 ---


## 一条接续边对应的输入链接：普通取消在来源命中帧按键（方向派生先喂方向序列）；
## jump cancel 是 Space + 空中起手（延迟由搜索指定）；落地接续在预测落地帧按键。
func _links_for_edge(from_id: String, to_id: String, kind: EdgeKind) -> Array[ChainLink]:
	var links: Array[ChainLink] = []
	var key := _start_key_for(to_id)
	match kind:
		EdgeKind.JUMP_CANCEL:
			var space_link := ChainLink.new()
			space_link.trigger = ChainLink.Trigger.PREV_HIT
			space_link.press_space = true
			links.append(space_link)
			var followup := ChainLink.new()
			followup.move_id = to_id
			followup.key = key
			followup.trigger = ChainLink.Trigger.JUMP_FRAME
			followup.wait = 1
			links.append(followup)
		EdgeKind.LANDING_CANCEL:
			var landing := ChainLink.new()
			landing.move_id = to_id
			landing.key = key
			landing.feed = _feed_for(to_id)
			landing.trigger = ChainLink.Trigger.LAND_FRAME
			links.append(landing)
		_:
			var cancel_link := ChainLink.new()
			cancel_link.move_id = to_id
			cancel_link.key = key
			cancel_link.feed = _feed_for(to_id)
			cancel_link.trigger = ChainLink.Trigger.PREV_HIT
			links.append(cancel_link)
	return links


func _build_edge(from_id: String, to_id: String, kind: EdgeKind, contexts: Dictionary, timing_cache: Dictionary) -> SolverEdge:
	var edge := SolverEdge.new()
	edge.from_id = from_id
	edge.to_id = to_id
	edge.kind = kind
	var from_move := _table.get(from_id) as MoveData
	var to_move := _table.get(to_id) as MoveData
	if to_move == null:
		edge.reason = "目标招式不在招式表中"
		return edge
	match kind:
		EdgeKind.CANCEL:
			if to_move.stance != from_move.stance:
				if to_move.stance == MoveData.Stance.AIR:
					edge.reason = "姿态不符：地面招式只能取消进地面目标，地面 → 空中只有配置的 jump cancel"
				else:
					edge.reason = "姿态不符：空中招式只能取消进空中目标，空中 → 地面只有显式落地接续"
				return edge
		EdgeKind.JUMP_CANCEL:
			if from_move.stance != MoveData.Stance.GROUND:
				edge.reason = "jump cancel 只能从地面招式命中确认后起跳（空中无二段跳，滞空资源不可刷新）"
				return edge
			if to_move.stance != MoveData.Stance.AIR:
				edge.reason = "jump cancel 目标必须是空中招式（%s 是地面招式）" % to_id
				return edge
		EdgeKind.LANDING_CANCEL:
			if from_move.stance != MoveData.Stance.AIR:
				edge.reason = "落地接续只属于空中招式（%s 是地面招式）" % from_id
				return edge
			if to_move.stance != MoveData.Stance.GROUND:
				edge.reason = "落地接续目标必须是地面招式（落地帧按地面姿态重解析；%s 是空中招式）" % to_id
				return edge
	if from_move.is_finisher:
		edge.reason = "收尾招式命中即结束连段，不开放命中确认取消"
		return edge
	if _start_key_for(to_id) == "":
		edge.reason = "目标无法由动作键起手，超出本 Solver 的输入表达范围"
		return edge
	var context: Array[ChainLink] = contexts.get(from_id, [])
	if context.is_empty():
		edge.reason = "无法从中立地面构造到达 %s 的合法上下文（jump cancel / 取消链不可达）" % from_id
		return edge
	match kind:
		EdgeKind.JUMP_CANCEL:
			_fill_jump_edge(edge, context)
		EdgeKind.LANDING_CANCEL:
			_fill_landing_edge(edge, context)
		_:
			_fill_cancel_edge(edge, context, timing_cache)
	return edge


func _fill_cancel_edge(edge: SolverEdge, context: Array[ChainLink], timing_cache: Dictionary) -> void:
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	var timing := _source_timing(edge.from_id, context, timing_cache)
	if timing.is_empty():
		edge.reason = "起手招式未在首个判定帧命中（探针几何假设被打破）"
		return
	edge.recover_age = timing["recover_age"]
	var links: Array[ChainLink] = context.duplicate()
	links.append_array(_links_for_edge(edge.from_id, edge.to_id, EdgeKind.CANCEL))
	var run := _run_schedule(_compile_chain(links), {})
	if run["ok"]:
		edge.valid = true
		edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - timing["hit_frame"]
		edge.wait_from = 0
		# 有效等待 = 取消仍在窗口内，且目标命中（等待 + 目标前摇）不晚于木桩恢复。
		# recover_age 在来源招式的规范入口上下文中测量；路线/循环里的真实可行性
		# 总是由逐帧模拟复验，这里只影响报告标注。
		edge.wait_to = mini(from_move.cancel_window_frames, edge.recover_age - to_move.startup_frames)
		var prefix := ""
		if to_move.direction_derivation != "":
			prefix = "（方向派生 %s：取消帧前喂入方向序列）" % to_move.direction_derivation
		elif from_move.stance == MoveData.Stance.AIR:
			prefix = "（空中取消）"
		edge.reason = "%s有效等待 0–%d 帧 + 目标前摇 %d 帧：最早命中在命中确认后第 %d 帧，不晚于木桩恢复（第 %d 帧），余量 %d 帧" % [
			prefix, edge.wait_to, to_move.startup_frames, edge.hit_age, edge.recover_age, edge.recover_age - edge.hit_age,
		]
		return
	var last_end: int = run["ended_reasons"][run["ended_reasons"].size() - 1] if not run["ended_reasons"].is_empty() else -1
	var timed_out: bool = run["break_kind"] == "count" \
		or (run["break_kind"] == "ended" and last_end == CombatEvent.ComboEndReason.DUMMY_RECOVERED)
	if timed_out:
		edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - timing["hit_frame"]
		edge.reason = "等待超时：目标命中落在命中确认后第 %d 帧，晚于木桩恢复（第 %d 帧）——木桩已自然受身，连段重新计数" % [
			edge.hit_age, edge.recover_age,
		]
		return
	var next_move := _table.get(run.get("next_expected_move", "")) as MoveData
	if run["break_kind"] == "ended" and next_move != null and next_move.stance == MoveData.Stance.AIR \
			and run["session"] != null and run["session"].player_on_ground:
		edge.reason = "取消追击未成立：空中目标在落地帧作废，未能在玩家滞空内命中（滞空资源有限，落地不授予普通取消资格）"
		return
	edge.reason = "取消未成立：目标未在取消窗口内起手或命中（未观测到第二次命中）"


func _fill_jump_edge(edge: SolverEdge, context: Array[ChainLink]) -> void:
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	var links: Array[ChainLink] = context.duplicate()
	links.append_array(_links_for_edge(edge.from_id, edge.to_id, EdgeKind.JUMP_CANCEL))
	var run := _run_schedule(_compile_chain(links), {})
	if not run["ok"]:
		edge.reason = "jump cancel 追击未成立：%s" % run["reason"]
		return
	edge.valid = true
	edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - run["hit_frames"][context.size() - 1]
	edge.wait_from = 0
	edge.wait_to = from_move.cancel_window_frames
	# 窗口边界档：Space 延迟到取消窗口末帧再起跳——窗口声明须经验证，不是外推。
	# 边界不成立时（如木桩浮空受身先于追击）有效等待收窄到 0 并如实说明。
	var boundary_links: Array[ChainLink] = context.duplicate()
	boundary_links.append_array(_links_for_edge(edge.from_id, edge.to_id, EdgeKind.JUMP_CANCEL))
	for i in range(context.size(), boundary_links.size()):
		if boundary_links[i].press_space:
			boundary_links[i] = _clone_link_with_wait(boundary_links[i], from_move.cancel_window_frames)
	var boundary := _run_schedule(_compile_chain(boundary_links), {})
	var boundary_note := "；窗口末帧（w=%d）起跳亦经模拟验证" % from_move.cancel_window_frames
	if not boundary["ok"]:
		edge.wait_to = 0
		boundary_note = "；Space 延迟到窗口末帧（w=%d）追击不成立（%s），有效等待收窄为仅 w=0" % [
			from_move.cancel_window_frames, boundary["reason"],
		]
	edge.reason = "Space 在命中确认后第 %d–%d 帧起跳，空中起手最早在起跳后第 1 帧出招、第 %d 帧命中（前摇 %d）%s；空中起手可在滞空内延迟，用于对齐落地接缝（见落地接续边）" % [
		edge.wait_from, edge.wait_to, edge.hit_age, to_move.startup_frames, boundary_note,
	]


func _fill_landing_edge(edge: SolverEdge, context: Array[ChainLink]) -> void:
	var to_move := _table[edge.to_id] as MoveData
	var followup_idx := -1
	for i in range(context.size()):
		if context[i].trigger == ChainLink.Trigger.JUMP_FRAME:
			followup_idx = i
			break
	if followup_idx < 0:
		edge.reason = "落地接续上下文不包含 jump cancel 空中段（探针构造失败）"
		return
	## 来源空中招式（如 jB）在上下文中的取消链位置：issue 15 起临界帧对齐
	## （命中恰在落地帧当帧）需要同时延迟空中起手与取消等待——起跳准备占用
	## 4 个正常帧后，单靠起手延迟不足以把命中压回落地帧（木桩浮空硬直先耗尽）。
	var from_link_idx := -1
	for i in range(context.size()):
		if context[i].move_id == edge.from_id and context[i].trigger == ChainLink.Trigger.PREV_HIT:
			from_link_idx = i
	if from_link_idx < 0:
		edge.reason = "落地接续上下文不包含来源空中招式的取消链（探针构造失败）"
		return
	# 来源空中招式的命中序号：Space 链接不产生命中，按有招式的链接计数。
	var from_hit_idx := -1
	for i in range(context.size()):
		if context[i].move_id != "":
			from_hit_idx += 1
	var valid_trials := []
	var latest_hit_trial := {}
	for d in range(0, MAX_AIR_DELAY + 1):
		for v in range(0, GameParams.CANCEL_WINDOW_FRAMES + 1):
			var links: Array[ChainLink] = context.duplicate()
			links[followup_idx] = _clone_link_with_wait(context[followup_idx], 1 + d)
			links[from_link_idx] = _clone_link_with_wait(context[from_link_idx], v)
			links.append_array(_links_for_edge(edge.from_id, edge.to_id, EdgeKind.LANDING_CANCEL))
			var compiled := _compile_chain(links)
			if compiled.is_empty():
				continue
			var run := _run_schedule(compiled, {})
			if run["ok"]:
				var from_hit: int = run["hit_frames"][from_hit_idx]
				valid_trials.append({
					"d": d,
					"lead": compiled["land_frame"] - from_hit,
					"to_hit": run["hit_frames"][run["hit_frames"].size() - 1],
					"from_hit": from_hit,
					"inputs": compiled["inputs"],
				})
			elif run["verified"] > from_hit_idx and (latest_hit_trial.is_empty()
					or d > latest_hit_trial["d"] or (d == latest_hit_trial["d"] and v > latest_hit_trial["v"])):
				latest_hit_trial = {
					"d": d,
					"v": v,
					"from_hit": run["hit_frames"][from_hit_idx],
					"land": compiled["land_frame"],
				}
	if valid_trials.is_empty():
		if latest_hit_trial.is_empty():
			var earliest := _compile_chain(context)
			if earliest.is_empty():
				edge.reason = "落地接续上下文无法编译（输入表冲突），接缝不可验证"
				return
			edge.reason = "落地接缝不可用：空中招式无法在落地前命中（最早命中第 %d 帧，晚于落地帧第 %d 帧——空中招式落地即作废）" % [
				earliest["hit_frames"][from_hit_idx], earliest["land_frame"],
			]
		else:
			var lead: int = latest_hit_trial["land"] - latest_hit_trial["from_hit"]
			edge.reason = "落地接缝关闭：最近可行命中距落地 %d 帧，超过取消窗口 %d 帧（命中第 %d 帧 / 落地第 %d 帧）——落地帧落在窗口外，落地不授予普通取消资格" % [
				lead, (_table[edge.from_id] as MoveData).cancel_window_frames, latest_hit_trial["from_hit"], latest_hit_trial["land"],
			]
		return
	# 最晚对齐档（lead 最小，最接近/恰为临界帧）作为回放样本。
	var critical_trial: Dictionary = valid_trials[0]
	for trial in valid_trials:
		if trial["lead"] < critical_trial["lead"]:
			critical_trial = trial
	edge.valid = true
	for trial in valid_trials:
		if trial["lead"] < edge.align_from or edge.align_from < 0:
			edge.align_from = trial["lead"]
		if trial["lead"] > edge.align_to or edge.align_to < 0:
			edge.align_to = trial["lead"]
	edge.hit_age = critical_trial["to_hit"] - critical_trial["from_hit"]
	edge.align_inputs = critical_trial["inputs"]
	edge.reason = "有效对齐：空中命中落在落地帧前 %d–%d 帧（0 即命中恰在落地帧当帧——同帧顺序为命中刷新硬直 → 落地 → 取消 → 消费，临界帧规则成立）；落地帧把缓存键按地面姿态重解析为 %s 并按合法接续起手" % [
		edge.align_from, edge.align_to, edge.to_id,
	]


func _clone_link_with_wait(link: ChainLink, wait: int) -> ChainLink:
	var clone := ChainLink.new()
	clone.move_id = link.move_id
	clone.key = link.key
	clone.trigger = link.trigger
	clone.wait = wait
	clone.press_space = link.press_space
	clone.feed = link.feed
	return clone


## 单招探针：起手命中帧与木桩恢复年龄（可追击的最后一帧相对命中的年龄），按上下文进入。
## 年龄按正常战斗帧计：命中后的 Hitstop 冻结帧以空输入步过、不占正常帧号。
func _source_timing(move_id: String, context: Array[ChainLink], cache: Dictionary) -> Dictionary:
	if cache.has(move_id):
		return cache[move_id]
	var timing := {}
	var compiled := _compile_chain(context)
	if not compiled.is_empty():
		var run := _run_schedule(compiled, {})
		if run["verified"] == run["hit_frames"].size():
			var hit_frame: int = run["hit_frames"][run["hit_frames"].size() - 1]
			var session: CombatSession = run["session"]
			var frame: int = run["last_frame"]
			var recover_age := -1
			while frame < RECOVER_HORIZON:
				if session.hitstop_active():
					session.step(FrameInput.new())
					_pin_dummy(session)
					continue
				frame += 1
				session.step(FrameInput.new())
				_pin_dummy(session)
				if not _dummy_pursuable(session):
					# 命中判定先于当帧恢复结算：离开可追击状态的帧即恢复帧。
					recover_age = frame - hit_frame
					break
			if recover_age == -1:
				recover_age = RECOVER_HORIZON - hit_frame
			timing = { "hit_frame": hit_frame, "recover_age": recover_age }
	cache[move_id] = timing
	return timing


# --- 接续链编译与模拟 ---


## 把接续链编译成逐帧输入表与预期命中帧。同帧互斥输入（两个动作键、两次 Space、
## 相反方向）返回空表——该等待/延迟组合不可调度。
func _compile_chain(links: Array[ChainLink]) -> Dictionary:
	var inputs := {}
	var hit_frames: Array[int] = []
	var hit_moves: Array[String] = []
	var last_hit := 0
	var jump_frame := -1
	var land_frame := -1
	var facing := 1
	for link in links:
		var press := -1
		match link.trigger:
			ChainLink.Trigger.START:
				press = 1 + link.feed.length()
			ChainLink.Trigger.PREV_HIT:
				press = last_hit + link.wait
			ChainLink.Trigger.JUMP_FRAME:
				if jump_frame < 0:
					return {}
				## issue 15 起 Space 请求先经 4f 起跳准备：wait=1 对应离地后的
				## 首个可按空中键帧（准备帧按地面姿态解析，不能承载空中起手）。
				press = jump_frame + GameParams.PLAYER_PREJUMP_FRAMES + link.wait
			ChainLink.Trigger.LAND_FRAME:
				if land_frame < 0:
					return {}
				## issue 15 落地恢复首帧锁定：落地当帧的新按下不进可执行缓存——
				## 接续键安排在落地前一帧按下（空中进入缓存），落地帧经重解析消费。
				press = land_frame - 1 + link.wait
		if press < 1:
			return {}
		for i in range(link.feed.length()):
			var digit := int(link.feed[i])
			var axis := _feed_axis(digit, facing)
			if not _merge_input(inputs, press - link.feed.length() + i, axis, _feed_down(digit), false, ""):
				return {}
			# 面向镜像运行时（issue 12 起）：地面自由行动的面向每帧指向木桩，
			# 水平输入不再翻转面向；探针按面向钉住木桩，喂入全程面向恒定。
			# 取消/落地喂入发生在招式或空中阶段，面向同样锁定。
		if not _merge_input(inputs, press, 0, false, link.press_space, link.key):
			return {}
		if link.press_space:
			jump_frame = press
			# 落地帧按 GameParams 的分期不变量预测（准备 4f + 滞空 38f，往返对称）——
			# 这是镜像运行时文档化的常量，不是第二套物理；空中命中的停顿会顺延真实
			# 落地，预测失误只会让探针在真实结算中落空该接缝（宁可漏报，不会误报）。
			land_frame = press + GameParams.PLAYER_PREJUMP_FRAMES + GameParams.PLAYER_JUMP_AIRTIME_FRAMES
		if link.move_id != "":
			var move := _table.get(link.move_id) as MoveData
			if move == null:
				return {}
			## 落地接续的起手帧是落地帧本身（前一帧按下、落地帧消费起手）。
			var start_delay := 1 if link.trigger == ChainLink.Trigger.LAND_FRAME else 0
			last_hit = press + start_delay + move.startup_frames
			hit_frames.append(last_hit)
			hit_moves.append(link.move_id)
	var specs: Array[ScheduledInput] = []
	var frames := inputs.keys()
	frames.sort()
	for frame in frames:
		var spec: Dictionary = inputs[frame]
		var scheduled := ScheduledInput.new()
		scheduled.frame = frame
		scheduled.axis = spec["axis"]
		scheduled.down = spec["down"]
		scheduled.jump = spec["jump"]
		scheduled.key = spec["key"]
		specs.append(scheduled)
	return { "inputs": specs, "hit_frames": hit_frames, "hit_moves": hit_moves, "jump_frame": jump_frame, "land_frame": land_frame }


func _merge_input(inputs: Dictionary, frame: int, axis: int, down: bool, jump: bool, key: String) -> bool:
	if not inputs.has(frame):
		inputs[frame] = { "axis": axis, "down": down, "jump": jump, "key": key }
		return true
	var spec: Dictionary = inputs[frame]
	if (spec["key"] != "" and key != "") or (spec["jump"] and jump):
		return false
	if spec["axis"] != 0 and axis != 0 and spec["axis"] != axis:
		return false
	if axis != 0:
		spec["axis"] = axis
	spec["down"] = spec["down"] or down
	spec["jump"] = spec["jump"] or jump
	if key != "":
		spec["key"] = key
	return true


func _feed_axis(digit: int, facing: int) -> int:
	if digit == 6 or digit == 3:
		return facing
	if digit == 4 or digit == 1:
		return -facing
	return 0


func _feed_down(digit: int) -> bool:
	return digit == 1 or digit == 2 or digit == 3


## 在真实 CombatSession 中逐帧执行输入表：每次命中须落在预期帧且连段计数递增；
## 连段提前结束、预期帧落空或预期之外的命中都断链。snapshot_every > 0 时在每
## 第 N 次命中（循环起点）快照木桩时序状态，快照完全重现即证明循环可无限重复。
## 时间轴口径（issue 14 起）：输入表与预期命中帧都按正常战斗帧编排——命中后的
## 8 帧 Hitstop 由会话冻结，探针以空输入跳过、不占用正常帧号；因此取消等待、
## 命中年龄与回放帧全部与规格的正常帧语义一致。观测上限按物理帧计（含冻结帧）。
func _run_schedule(compiled: Dictionary, opts: Dictionary) -> Dictionary:
	if compiled.is_empty():
		return _empty_run("输入表冲突：同一物理帧需要两个互斥输入")
	var inputs := {}
	for spec in compiled["inputs"]:
		inputs[spec.frame] = spec
	var hit_frames: Array[int] = compiled["hit_frames"]
	var hit_moves: Array[String] = compiled["hit_moves"]
	var total := hit_frames.size()
	var snapshot_every: int = opts.get("snapshot_every", 0)
	var max_frames: int = opts.get("max_frames", 0)
	var session := _new_session()
	var verified := 0
	var break_reason := ""
	var break_kind := ""
	var ended_reasons: Array[int] = []
	var snapshots: Array = []
	var proven_period := -1
	var laps_observed := 0
	var frame := 0
	var physics := 0
	var last_frame := hit_frames[total - 1] if total > 0 else 0
	while frame < last_frame:
		if session.hitstop_active():
			## 命中停顿：以空输入步过冻结帧，不推进正常帧号、不喂入计划输入。
			physics += 1
			if max_frames > 0 and physics > max_frames:
				break_reason = "观测帧数达到上限（%d 帧）" % max_frames
				break_kind = "horizon"
				break
			session.step(FrameInput.new())
			_pin_dummy(session)
			continue
		frame += 1
		physics += 1
		if max_frames > 0 and physics > max_frames:
			break_reason = "观测帧数达到上限（%d 帧）" % max_frames
			break_kind = "horizon"
			break
		var input := FrameInput.new()
		if inputs.has(frame):
			input = (inputs[frame] as ScheduledInput).to_frame_input()
		var events := session.step(input)
		_pin_dummy(session)
		var hit_now := _hit_count(events) > 0
		var ended_now := _ended_count(events) > 0
		if verified < total and frame == hit_frames[verified]:
			if not hit_now:
				break_reason = "第 %d 次命中未在预期帧（第 %d 帧）发生" % [verified + 1, frame]
				break_kind = "miss"
				break
			var event_hits := 0
			for event in events:
				if event.type == CombatEvent.Type.HIT:
					event_hits = event.combo_hits
			if event_hits != verified + 1:
				break_reason = "第 %d 次命中的连段计数为 %d（预期 %d），链条已断" % [verified + 1, event_hits, verified + 1]
				break_kind = "count"
				break
			verified += 1
			if snapshot_every > 0 and (verified - 1) % snapshot_every == 0:
				laps_observed = (verified - 1) / snapshot_every + 1
				var state := _dummy_timing_state(session)
				for previous in snapshots:
					if previous[1] == state:
						proven_period = frame - previous[0]
						break
				if proven_period > 0:
					break
				snapshots.append([frame, state])
		elif hit_now:
			break_reason = "命中发生在预期之外的第 %d 帧" % frame
			break_kind = "unexpected"
			break
		if ended_now:
			for event in events:
				if event.type == CombatEvent.Type.COMBO_ENDED:
					ended_reasons.append(event.combo_end_reason)
			if verified < total:
				var next_move := hit_moves[verified] if verified < hit_moves.size() else ""
				break_reason = "第 %d 次命中前连段结束（%s%s）" % [
					verified + 1, _end_reason_text(events), _landing_note(events, session, next_move),
				]
				break_kind = "ended"
				break
	# 木桩时序状态重现即成功：循环模拟在证明成立时提前停止（verified < total）。
	var ok := proven_period > 0 or (break_reason == "" and verified == total)
	return {
		"ok": ok,
		"reason": break_reason,
		"break_kind": break_kind,
		"verified": verified,
		"hit_frames": hit_frames,
		"next_expected_move": hit_moves[verified] if verified < hit_moves.size() else "",
		"ended_reasons": ended_reasons,
		"proven_period": proven_period,
		"snapshots": snapshots,
		"laps_observed": laps_observed,
		"session": session,
		"compiled": compiled,
		"last_frame": frame,
	}


func _empty_run(reason: String) -> Dictionary:
	return {
		"ok": false, "reason": reason, "break_kind": "conflict", "verified": 0,
		"hit_frames": [] as Array[int], "next_expected_move": "", "ended_reasons": [] as Array[int],
		"proven_period": -1, "snapshots": [] as Array, "laps_observed": 0,
		"session": null, "compiled": {}, "last_frame": 0,
	}


## 断链补充说明：下一招是空中招式且玩家已落地时，指出有限滞空资源是断链原因。
func _landing_note(events: Array[CombatEvent], session: CombatSession, next_move_id: String) -> String:
	var recovered_move := false
	for event in events:
		if event.type == CombatEvent.Type.COMBO_ENDED and event.combo_end_reason == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			recovered_move = true
	if not recovered_move or session == null or not session.player_on_ground:
		return ""
	var next := _table.get(next_move_id) as MoveData
	if next != null and next.stance == MoveData.Stance.AIR:
		return "；空中招式落地作废，滞空资源耗尽"
	return ""


# --- 空中延迟搜索 ---


## 上下文链接的私有副本：空中取消链接（PREV_HIT → 空中招式）被克隆并计入
## 可调延迟——issue 15 起落地接缝的临界对齐需要同时延迟空中起手与取消等待
## （起跳准备占 4 个正常帧后，单靠起手延迟无法把命中压回落地帧）。缓存上下文
## 里的原链接绝不进入搜索（`_delay_dfs` 会原地改写 wait）。
func _cloned_context_links(context: Array[ChainLink]) -> Array[ChainLink]:
	var links: Array[ChainLink] = []
	for link in context:
		if link.trigger == ChainLink.Trigger.PREV_HIT and _is_air_move_link(link):
			links.append(_clone_link_with_wait(link, link.wait))
		else:
			links.append(link)
	return links


## 可调延迟链接：空中段起手（JUMP_FRAME）与空中取消（PREV_HIT → 空中招式）。
## 上下文里的空中取消已由 `_cloned_context_links` 克隆，追加链接由 `_links_for_edge`
## 新建——全部可原地改写 wait。
func _adjustable_indices(links: Array[ChainLink]) -> Array[int]:
	var result: Array[int] = []
	for i in range(links.size()):
		if links[i].trigger == ChainLink.Trigger.JUMP_FRAME \
				or (links[i].trigger == ChainLink.Trigger.PREV_HIT and _is_air_move_link(links[i])):
			result.append(i)
	return result


func _is_air_move_link(link: ChainLink) -> bool:
	if link.move_id == "":
		return false
	var move := _table.get(link.move_id) as MoveData
	return move != null and move.stance == MoveData.Stance.AIR


## 空中段首按延迟搜索：按字典序枚举延迟向量（每个空中段 0..MAX_AIR_DELAY），
## 第 j 个可调链接取 delays[j % 向量长度]（循环按圈重复同一延迟）。返回首个完整
## 成立的运行；全部失败时返回走得最远的失败运行（供截断/排除文案）。
## 不变量：可调链接必须是本次调用新建（或克隆）的对象——搜索会原地改写 wait；
## 缓存上下文里的链接绝不能进入 adjustable（`_fill_landing_edge` 用克隆替换）。
func _delay_search(links: Array[ChainLink], adjustable: Array[int], delays_per_lap: int, opts: Dictionary) -> Dictionary:
	if adjustable.is_empty():
		return _run_schedule(_compile_chain(links), opts)
	var size := maxi(1, delays_per_lap)
	var delays: Array[int] = []
	for i in range(size):
		delays.append(0)
	return _delay_dfs(links, adjustable, _delay_caps(links, adjustable, size), delays, 0, opts)


## 每个延迟槽的枚举上限：槽里有空中段起手（JUMP_FRAME）按 MAX_AIR_DELAY，
## 只有空中取消（PREV_HIT）按取消窗口封顶——窗口外等待必然失败，不枚举。
func _delay_caps(links: Array[ChainLink], adjustable: Array[int], vector_size: int) -> Array[int]:
	var caps: Array[int] = []
	for depth in range(vector_size):
		var any_jump := false
		for j in range(adjustable.size()):
			if j % vector_size == depth and links[adjustable[j]].trigger == ChainLink.Trigger.JUMP_FRAME:
				any_jump = true
				break
		caps.append(MAX_AIR_DELAY if any_jump else GameParams.CANCEL_WINDOW_FRAMES)
	return caps


func _delay_dfs(links: Array[ChainLink], adjustable: Array[int], caps: Array[int], delays: Array[int], depth: int, opts: Dictionary) -> Dictionary:
	if depth == delays.size():
		for j in range(adjustable.size()):
			## JUMP_FRAME 的 wait 1 = 离地后首个可按空中键帧（issue 15 起跳准备）；
			## PREV_HIT 取消的 wait 0 = 命中确认当帧消费——两者都从最早的合法
			## 等待起按字典序搜索。
			var base := 1 if links[adjustable[j]].trigger == ChainLink.Trigger.JUMP_FRAME else 0
			links[adjustable[j]].wait = base + delays[j % delays.size()]
		return _run_schedule(_compile_chain(links), opts)
	var best := {}
	for d in range(0, caps[depth] + 1):
		delays[depth] = d
		var run := _delay_dfs(links, adjustable, caps, delays, depth + 1, opts)
		if run["ok"]:
			return run
		if best.is_empty() or run["verified"] > best["verified"]:
			best = run
	return best


# --- 路线 ---


func _walk_routes(node_id: String, path: Array[String], adj: Dictionary, routes: Array[SolverRoute], contexts: Dictionary, edge_kinds: Dictionary) -> void:
	var extended := false
	if adj.has(node_id):
		for next_id in adj[node_id]:
			if path.has(next_id):
				continue
			var next_path: Array[String] = path.duplicate()
			next_path.append(next_id)
			_walk_routes(next_id, next_path, adj, routes, contexts, edge_kinds)
			extended = true
	if not extended:
		var route := _simulate_route(path, contexts, edge_kinds)
		if not route.move_ids.is_empty():
			routes.append(route)


## 路线模拟：搜索一组空中段延迟，使整条链的每次接续都在真实结算中成立；
## 每次取消都在命中确认当帧（w=0）消费，落地接续键压在预测的落地帧上。
func _simulate_route(route_ids: Array[String], contexts: Dictionary, edge_kinds: Dictionary) -> SolverRoute:
	var route := SolverRoute.new()
	route.move_ids = route_ids.duplicate()
	var context: Array[ChainLink] = contexts.get(route_ids[0], [])
	if context.is_empty():
		route.move_ids = []
		return route
	var links := _cloned_context_links(context)
	for i in range(1, route_ids.size()):
		var kind: EdgeKind = edge_kinds.get("%s|%s" % [route_ids[i - 1], route_ids[i]], EdgeKind.CANCEL)
		links.append_array(_links_for_edge(route_ids[i - 1], route_ids[i], kind))
	var adjustable := _adjustable_indices(links)
	var run := _delay_search(links, adjustable, adjustable.size(), {})
	if run["ok"]:
		route.hit_frames = run["hit_frames"]
		route.inputs = run["compiled"]["inputs"]
		route.combo_hits = run["session"].combo_hits
		route.total_damage = run["session"].combo_total_damage
		if not run["ended_reasons"].is_empty() \
				and run["ended_reasons"][run["ended_reasons"].size() - 1] == CombatEvent.ComboEndReason.FINISHER:
			route.note = "收尾结束路线，保留木桩倒地处理"
	else:
		var verified: int = run["verified"]
		route.move_ids = route_ids.slice(0, verified)
		route.note = "路线在第 %d 招后断开（%s），路线在此截断" % [mini(verified + 1, route_ids.size()), run["reason"]]
	return route


# --- 循环 ---


func _elementary_cycles(adj: Dictionary) -> Array[Array]:
	var found: Array[Array] = []
	var seen := {}
	for start_id in adj.keys():
		_walk_cycles(start_id, start_id, [start_id], adj, seen, found)
	return found


func _walk_cycles(start_id: String, node_id: String, path: Array[String], adj: Dictionary, seen: Dictionary, found: Array[Array]) -> void:
	if not adj.has(node_id):
		return
	for next_id in adj[node_id]:
		if next_id == start_id:
			var canonical := _canonical_cycle(path)
			var key := ",".join(canonical)
			if not seen.has(key):
				seen[key] = true
				found.append(canonical)
		elif not path.has(next_id):
			var next_path: Array[String] = path.duplicate()
			next_path.append(next_id)
			_walk_cycles(start_id, next_id, next_path, adj, seen, found)


## 同一循环的不同起点归一：旋转到字典序最小的招式 id 开头。
func _canonical_cycle(path: Array[String]) -> Array[String]:
	var best := 0
	for i in range(1, path.size()):
		if path[i] < path[best]:
			best = i
	var rotated: Array[String] = []
	for i in range(path.size()):
		rotated.append(path[(best + i) % path.size()])
	return rotated


## 循环模拟：入口上下文把会话带到起点招式的命中，随后逐圈按固定接续链出招
## （每圈同一组空中延迟），每圈回到起点招式命中时快照木桩时序状态；
## 快照完全重现即证明循环可无限重复。空中延迟逐向量搜索——只有存在一组延迟
## 使链条逐圈不断，循环才成立（有限滞空资源的回边在此被区分出来）。
func _simulate_cycle(cycle_ids: Array[String], contexts: Dictionary, edge_kinds: Dictionary) -> SolverCycle:
	var cycle := SolverCycle.new()
	cycle.route = cycle_ids.duplicate()
	var size := cycle_ids.size()
	var context: Array[ChainLink] = contexts.get(cycle_ids[0], [])
	if context.is_empty():
		cycle.reason = "无法构造循环起点 %s 的合法入口上下文" % cycle_ids[0]
		return cycle
	var lap_links: Array[ChainLink] = []
	for i in range(size):
		var kind: EdgeKind = edge_kinds.get("%s|%s" % [cycle_ids[i], cycle_ids[(i + 1) % size]], EdgeKind.CANCEL)
		lap_links.append_array(_links_for_edge(cycle_ids[i], cycle_ids[(i + 1) % size], kind))
	var links := _cloned_context_links(context)
	for lap in range(MAX_CYCLE_LAPS):
		# 同一圈的链接对象按引用重复：延迟按圈取模一致，多圈共享同一等待值。
		for lap_link in lap_links:
			links.append(lap_link)
	var adjustable := _adjustable_indices(links)
	## 每圈的延迟槽包含空中段起手与空中取消（结构按圈重复，模长对齐交替取槽）：
	## issue 15 起落地接缝循环的证明需要每圈同时延迟两者。
	var per_lap := _adjustable_indices(lap_links).size()
	var opts := { "snapshot_every": size, "max_frames": MAX_CYCLE_FRAMES }
	var run := _delay_search(links, adjustable, per_lap if per_lap > 0 else adjustable.size(), opts)
	if not run.get("ok", false):
		# 观测帧数达到上限仍未见断链：保守上报为有效循环——宁可误报，不可用上限掩盖
		# （长周期循环的 8 圈可能超出 MAX_CYCLE_FRAMES，这与逐圈断链是两种情形）。
		if run.get("break_kind", "") == "horizon":
			cycle.sustained = true
			cycle.reason = "观测帧数达到上限（%d 帧）仍未见断链，保守上报为有效循环（未以命中数/时长上限掩盖；周期过长未能完成 8 圈对拍）" % MAX_CYCLE_FRAMES
			return cycle
		cycle.reason = run.get("reason", "逐圈模拟中断链")
		return cycle
	cycle.sustained = true
	cycle.laps_observed = run["laps_observed"]
	if run["proven_period"] > 0:
		cycle.proven = true
		cycle.period_frames = run["proven_period"]
		cycle.reason = "逐圈模拟中木桩时序状态完全重现，循环可无限重复（每圈由真实命中重建受击/浮空资源，无自然受身断点）"
	else:
		cycle.reason = "观测 %d 帧 / %d 圈内全部预期命中成立、未见断链，保守上报为有效循环（未以命中数/时长上限掩盖）" % [run["last_frame"], cycle.laps_observed]
	return cycle


# --- 探针基础设施 ---


## 私有一次性会话：与训练场会话无关，Solver 不修改任何运行时战斗状态。
func _new_session() -> CombatSession:
	var session := CombatSession.new(_table)
	session.dummy_position = session.player_position + Vector2(PIN_DX, 0.0)
	return session


## 几何接触是求解前提而非证明对象：每帧把木桩钉回玩家面前的横向间距（面向侧），
## 只保留垂直方向的真实浮空/落地物理。
func _pin_dummy(session: CombatSession) -> void:
	session.dummy_position.x = session.player_position.x + session.player_facing * PIN_DX


## 木桩时序状态：决定后续命中/恢复演化的全部可观察量（横向被钉住，不参与比较；
## 含会话级 Hitstop 冻结标记——快照点恒为命中当帧，但冻结状态影响未来时间轴）。
func _dummy_timing_state(session: CombatSession) -> Array:
	return [
		session.dummy_state,
		session.dummy_hitstun_left,
		session.dummy_velocity.y,
		session.dummy_position.y,
		session.dummy_on_ground,
		session.hitstop_active(),
	]


func _dummy_pursuable(session: CombatSession) -> bool:
	return session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN \
		or session.dummy_state == CombatSession.DummyState.AIR_HITSTUN


func _is_plain_ground_id(move_id: String) -> bool:
	## 路线起点：地面、无方向派生、可由动作键起手的打击招式（按表内顺序，确定性枚举）。
	var move := _table.get(move_id) as MoveData
	if move == null or move.stance != MoveData.Stance.GROUND or move.direction_derivation != "":
		return false
	return move.is_strike() and move.action_key != ""


## 招式的起手动作键：取招式数据声明的输入绑定（issue 11 起绑定是数据字段）；
## 空中方向派生在运行时按锁定面向生效（issue 12），但 Solver 首版不调度空中
## 派生的方向喂入（喂入仅地面），故带派生的空中招式不可单键起手；投技不可单键起手。
func _start_key_for(move_id: String) -> String:
	var move := _table.get(move_id) as MoveData
	if move == null or move.is_throw():
		return ""
	if move.stance == MoveData.Stance.AIR and move.direction_derivation != "":
		return ""
	return move.action_key


## 起手前需要喂入的方向序列（方向派生记法去掉末位动作键）。
func _feed_for(move_id: String) -> String:
	var move := _table.get(move_id) as MoveData
	if move == null or move.stance == MoveData.Stance.AIR:
		return ""
	if move.direction_derivation.length() < 2:
		return ""
	return move.direction_derivation.left(move.direction_derivation.length() - 1)


func _hit_count(events: Array[CombatEvent]) -> int:
	var count := 0
	for event in events:
		if event.type == CombatEvent.Type.HIT:
			count += 1
	return count


func _ended_count(events: Array[CombatEvent]) -> int:
	var count := 0
	for event in events:
		if event.type == CombatEvent.Type.COMBO_ENDED:
			count += 1
	return count


func _end_reason_text(events: Array[CombatEvent]) -> String:
	for event in events:
		if event.type != CombatEvent.Type.COMBO_ENDED:
			continue
		match event.combo_end_reason:
			CombatEvent.ComboEndReason.FINISHER:
				return "收尾"
			CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED:
				return "取消窗口关闭"
			CombatEvent.ComboEndReason.MOVE_RECOVERED:
				return "招式收招未接续"
			CombatEvent.ComboEndReason.DUMMY_RECOVERED:
				return "木桩自然受身"
	return ""
