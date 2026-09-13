class_name ComboSolver
extends RefCounted
## 开发期 Combo Solver：地面接续验证与循环报告（issue 06）。
## 只读招式数据，用一次性 CombatSession 探针得出与运行时一致的接续结论——
## 前摇、等待时间、取消窗口、木桩硬直与地面姿态都在真实结算中检验，
## 而不是在 Solver 里复刻第二套帧物理。
## 约束：不修改任何运行时战斗状态（所有探针使用私有会话，与训练场会话无关）；
## 不设全局命中数或总时长上限——循环以「逐圈模拟 + 木桩时序状态重现」证明，
## 观测上限内不断链的回边保守上报为循环，不会被上限掩盖。
## 几何接触是假设不是证明：探针把木桩钉在命中范围内，不证明空间/中立/碰撞连接。
## 方向派生、浮空后续与空中接续（jump cancel、落地接续）由 issue 07 覆盖。

## 探针站位：玩家中心与木桩中心的横向间距（命中框中段，几何接触假设）。
const PIN_DX := 70.0
## 逐圈模拟的观测上限（圈数/帧数）。仅用于防止死循环，不是连段语义的一部分；
## 达到上限仍未断链的回边保守上报为循环（宁可误报，不可掩盖）。
const MAX_CYCLE_LAPS := 8
const MAX_CYCLE_FRAMES := 2400
## 单招探针观测木桩恢复的帧数上限。
const RECOVER_HORIZON := 240

const SCOPE_TEXT := "证明范围：仅覆盖招式表配置的确定性命中确认取消——前摇、等待时间、取消窗口、木桩硬直与地面姿态都在真实 CombatSession 结算中检验；不证明任意空间、中立或碰撞连接（探针把木桩钉在命中范围内，几何接触是假设）；方向派生、浮空后续与空中接续由 07 覆盖；循环判定不设全局命中数或总时长上限，以逐圈模拟加木桩时序状态重现为证明。"


## 一条候选接续边：from 招式命中确认后取消进 to 招式。
class SolverEdge extends RefCounted:
	var from_id := ""
	var to_id := ""
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

	func label() -> String:
		return "%s → %s" % [from_id, to_id]


## 一条经逐帧模拟验证的可读路线（合法接续链，含命中帧与伤害）。
class SolverRoute extends RefCounted:
	var move_ids: Array[String] = []
	var hit_frames: Array[int] = []
	var combo_hits := 0
	var total_damage := 0.0
	var note := ""

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


## 分析报告：接续边、可读路线、循环与可读文本。
class SolverReport extends RefCounted:
	var safe := true
	var summary := ""
	var scope := ""
	var edges: Array[SolverEdge] = []
	var routes: Array[SolverRoute] = []
	var cycles: Array[SolverCycle] = []
	var notes: Array[String] = []

	func to_lines() -> Array[String]:
		var lines: Array[String] = []
		lines.append("=== Combo Solver：地面接续验证 ===")
		lines.append(summary)
		lines.append(scope)
		lines.append("--- 接续边 ---")
		if edges.is_empty():
			lines.append("（招式表中没有可分析的地面接续边）")
		for edge in edges:
			lines.append("%s：%s｜%s" % [edge.label(), "有效" if edge.valid else "排除", edge.reason])
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


## 分析招式表：生成确定性接续边、可读路线与循环报告。不修改任何运行时战斗状态。
static func analyze(move_table: Dictionary = {}) -> SolverReport:
	var table := move_table if not move_table.is_empty() else MoveData.default_table()
	return ComboSolver.new(table)._analyze()


# --- 分析主体 ---

func _analyze() -> SolverReport:
	var report := SolverReport.new()
	report.scope = SCOPE_TEXT
	## 图节点：可用普通动作键（5X）起手、无方向派生的地面招式（按表内顺序，确定性枚举）。
	var sources: Array[String] = []
	for move_id in _table:
		if _is_plain_ground_id(move_id):
			sources.append(move_id)
	var timing_cache := {}
	var valid_adj := {}
	for from_id in sources:
		for to_id in (_table[from_id] as MoveData).cancel_targets:
			var edge := _build_edge(from_id, to_id, timing_cache)
			report.edges.append(edge)
			if edge.valid:
				if not valid_adj.has(from_id):
					valid_adj[from_id] = [] as Array[String]
				var targets: Array[String] = valid_adj[from_id]
				if not targets.has(to_id):
					targets.append(to_id)
	for start_id in sources:
		_walk_routes(start_id, [start_id], valid_adj, report.routes)
	for cycle_ids in _elementary_cycles(valid_adj):
		var cycle := _simulate_cycle(cycle_ids)
		if cycle.sustained:
			report.cycles.append(cycle)
		else:
			report.notes.append("结构性循环 %s 在逐圈模拟中断开，不构成有效循环：%s" % [
				" → ".join(cycle_ids) + " → 回到 " + cycle_ids[0], cycle.reason,
			])
	report.safe = report.cycles.is_empty()
	report.summary = _build_summary(report)
	return report


func _build_summary(report: SolverReport) -> String:
	var valid_count := 0
	for edge in report.edges:
		if edge.valid:
			valid_count += 1
	if report.safe:
		return "未发现可无限重复的有效地面循环：接续边 %d 条（有效 %d、排除 %d），可读路线 %d 条。" % [
			report.edges.size(), valid_count, report.edges.size() - valid_count, report.routes.size(),
		]
	var parts: Array[String] = []
	for cycle in report.cycles:
		var period := ("，周期 %d 帧" % cycle.period_frames) if cycle.period_frames > 0 else ""
		parts.append(cycle.label() + period)
	return "检测到 %d 个有效循环：%s；命中确认取消链可在木桩自然受身前无限重复，请调整招式数据。" % [
		report.cycles.size(), "；".join(parts),
	]


# --- 接续边 ---

func _build_edge(from_id: String, to_id: String, timing_cache: Dictionary) -> SolverEdge:
	var edge := SolverEdge.new()
	edge.from_id = from_id
	edge.to_id = to_id
	var from_move := _table.get(from_id) as MoveData
	var to_move := _table.get(to_id) as MoveData
	if to_move == null:
		edge.reason = "目标招式不在招式表中"
		return edge
	if from_move.hit_result == MoveData.HitResult.LAUNCH:
		edge.reason = "浮空命中的后续接续属于空中路线，由 07 覆盖"
		return edge
	if to_move.stance == MoveData.Stance.AIR:
		edge.reason = "姿态不符：目标 %s 是空中招式，地面命中确认取消只能接入地面姿态目标" % to_id
		return edge
	if to_move.direction_derivation != "":
		edge.reason = "方向派生接续（%s）由 07 覆盖" % to_move.direction_derivation
		return edge
	if _plain_key_for(to_id) == "":
		edge.reason = "目标无法以普通动作键（5X）在地面接续，超出本 Solver 证明范围"
		return edge
	var timing := _source_timing(from_id, timing_cache)
	if timing.is_empty():
		edge.reason = "起手招式未在首个判定帧命中（探针几何假设被打破）"
		return edge
	edge.recover_age = timing["recover_age"]
	var probe := _probe_edge(from_id, to_id)
	if probe["ok"]:
		edge.valid = true
		edge.hit_age = probe["to_hit_frame"] - probe["from_hit_frame"]
		edge.wait_from = 0
		# 有效等待 = 取消仍在窗口内，且目标命中（等待 + 目标前摇）不晚于木桩恢复。
		edge.wait_to = mini(from_move.cancel_window_frames, edge.recover_age - to_move.startup_frames)
		edge.reason = "有效等待 0–%d 帧 + 目标前摇 %d 帧：最早命中在命中确认后第 %d 帧，不晚于木桩恢复（第 %d 帧），余量 %d 帧" % [
			edge.wait_to, to_move.startup_frames, edge.hit_age, edge.recover_age, edge.recover_age - edge.hit_age,
		]
	elif from_move.is_finisher:
		edge.reason = "收尾招式命中即结束连段，不开放命中确认取消"
	elif probe["to_hit_frame"] >= 0:
		edge.hit_age = probe["to_hit_frame"] - probe["from_hit_frame"]
		edge.reason = "等待超时：目标命中落在命中确认后第 %d 帧，晚于木桩恢复（第 %d 帧）——木桩已自然受身，连段重新计数" % [
			edge.hit_age, edge.recover_age,
		]
	else:
		edge.reason = "取消未成立：目标未在取消窗口内起手或命中（未观测到第二次命中）"
	return edge


## 单招探针：起手命中帧与木桩恢复年龄（可追击的最后一帧相对命中的年龄）。
func _source_timing(move_id: String, cache: Dictionary) -> Dictionary:
	if cache.has(move_id):
		return cache[move_id]
	var session := _new_session()
	var key := _plain_key_for(move_id)
	var hit_frame := -1
	var recover_age := -1
	var frame := 0
	while frame < RECOVER_HORIZON:
		frame += 1
		var events := session.step(FrameInput.make(0, false, key if frame == 1 else ""))
		_pin_dummy(session)
		if hit_frame == -1:
			if _hit_count(events) > 0:
				hit_frame = frame
		elif not _dummy_pursuable(session):
			# 命中判定先于当帧恢复结算：恢复帧当帧仍可被追击，离开可追击状态的帧即恢复帧。
			recover_age = frame - hit_frame
			break
	if recover_age == -1 and hit_frame != -1:
		recover_age = RECOVER_HORIZON - hit_frame
	var timing := {} if hit_frame == -1 else { "hit_frame": hit_frame, "recover_age": recover_age }
	cache[move_id] = timing
	return timing


## 接续探针：起手在首个判定帧命中（几何假设），当帧（w=0，最早取消）按目标键，
## 验证第二次命中链条完整（无连段结束、连段计数递增到 2）。
func _probe_edge(from_id: String, to_id: String) -> Dictionary:
	var from_move := _table[from_id] as MoveData
	var to_move := _table[to_id] as MoveData
	var session := _new_session()
	var press_at := 1 + from_move.startup_frames
	var horizon := press_at + from_move.cancel_window_frames + to_move.total_frames() + 10
	var from_hit_frame := -1
	var to_hit_frame := -1
	var to_combo_hits := 0
	var ended_between := false
	var frame := 0
	while frame < horizon:
		frame += 1
		var key := ""
		if frame == 1:
			key = _plain_key_for(from_id)
		elif frame == press_at:
			key = _plain_key_for(to_id)
		var events := session.step(FrameInput.make(0, false, key))
		_pin_dummy(session)
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				if from_hit_frame == -1:
					from_hit_frame = frame
				elif to_hit_frame == -1:
					to_hit_frame = frame
					to_combo_hits = event.combo_hits
			elif event.type == CombatEvent.Type.COMBO_ENDED and from_hit_frame != -1 and to_hit_frame == -1:
				ended_between = true
		if to_hit_frame != -1:
			break
	var ok := to_hit_frame != -1 and not ended_between and to_combo_hits == 2
	return {
		"ok": ok,
		"from_hit_frame": from_hit_frame,
		"to_hit_frame": to_hit_frame,
		"to_combo_hits": to_combo_hits,
		"ended_between": ended_between,
	}


# --- 路线 ---

func _walk_routes(node_id: String, path: Array[String], adj: Dictionary, routes: Array[SolverRoute]) -> void:
	var extended := false
	if adj.has(node_id):
		for next_id in adj[node_id]:
			if path.has(next_id):
				continue
			var next_path: Array[String] = path.duplicate()
			next_path.append(next_id)
			_walk_routes(next_id, next_path, adj, routes)
			extended = true
	if not extended:
		var route := _simulate_route(path)
		if not route.move_ids.is_empty():
			routes.append(route)


## 路线模拟：每次取消都在命中确认当帧（w=0）消费，逐帧核对命中帧与连段计数。
func _simulate_route(route_ids: Array[String]) -> SolverRoute:
	var route := SolverRoute.new()
	route.move_ids = route_ids.duplicate()
	var session := _new_session()
	var presses := {}
	var expected_hits: Array[int] = []
	var cursor := 1
	presses[1] = _plain_key_for(route_ids[0])
	for i in range(route_ids.size()):
		var move := _table[route_ids[i]] as MoveData
		var hit_at: int = cursor + move.startup_frames
		expected_hits.append(hit_at)
		if i + 1 < route_ids.size():
			presses[hit_at] = _plain_key_for(route_ids[i + 1])
		cursor = hit_at
	var verified := 0
	var frame := 0
	var last_frame: int = expected_hits[expected_hits.size() - 1]
	while frame < last_frame:
		frame += 1
		var events := session.step(FrameInput.make(0, false, presses.get(frame, "")))
		_pin_dummy(session)
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				if verified < expected_hits.size() and frame == expected_hits[verified] and event.combo_hits == verified + 1:
					verified += 1
					route.hit_frames.append(frame)
					route.combo_hits = session.combo_hits
					route.total_damage = session.combo_total_damage
				elif route.note == "":
					route.note = "第 %d 招未按预期命中（连段计数 %d），路线在此截断" % [verified + 1, event.combo_hits]
			elif event.type == CombatEvent.Type.COMBO_ENDED and route.note == "":
				if verified == route_ids.size() and event.combo_end_reason == CombatEvent.ComboEndReason.FINISHER:
					route.note = "收尾结束路线，保留木桩倒地处理"
				else:
					route.note = "路线在第 %d 招后断开（连段结束），路线在此截断" % [mini(verified + 1, route_ids.size())]
	if verified < route_ids.size():
		route.move_ids = route_ids.slice(0, verified)
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


## 循环模拟：逐圈按固定时刻表出招（每次取消都在命中确认当帧），
## 每圈回到起点招式命中时快照木桩时序状态；快照完全重现即证明循环可无限重复。
func _simulate_cycle(cycle_ids: Array[String]) -> SolverCycle:
	var cycle := SolverCycle.new()
	cycle.route = cycle_ids.duplicate()
	var size := cycle_ids.size()
	var startups: Array[int] = []
	var lap_advance := 0
	for move_id in cycle_ids:
		var startup: int = (_table[move_id] as MoveData).startup_frames
		startups.append(startup)
		lap_advance += startup
	var presses := {}
	var hit_frames: Array[int] = []
	for lap in range(MAX_CYCLE_LAPS):
		var cursor := 1 + lap * lap_advance
		if lap == 0:
			presses[1] = _plain_key_for(cycle_ids[0])
		for i in range(size):
			var hit_at: int = cursor + startups[i]
			hit_frames.append(hit_at)
			presses[hit_at] = _plain_key_for(cycle_ids[(i + 1) % size])
			cursor = hit_at
	var session := _new_session()
	var snapshots: Array[Array] = []
	var verified := 0
	var frame := 0
	var broken_reason := ""
	while frame < MAX_CYCLE_FRAMES and verified < hit_frames.size():
		frame += 1
		var events := session.step(FrameInput.make(0, false, presses.get(frame, "")))
		_pin_dummy(session)
		var hit_now := _hit_count(events) > 0
		if _ended_count(events) > 0:
			broken_reason = "第 %d 次命中前连段结束（%s）" % [verified + 1, _end_reason_text(events)]
			break
		if frame == hit_frames[verified]:
			if not hit_now:
				broken_reason = "第 %d 次命中未在预期帧（第 %d 帧）发生" % [verified + 1, frame]
				break
			var event_hits := 0
			for event in events:
				if event.type == CombatEvent.Type.HIT:
					event_hits = event.combo_hits
			if event_hits != verified + 1:
				broken_reason = "第 %d 次命中的连段计数为 %d（预期 %d），链条已断" % [verified + 1, event_hits, verified + 1]
				break
			verified += 1
			if (verified - 1) % size == 0:
				var laps_seen := (verified - 1) / size + 1
				cycle.laps_observed = laps_seen
				var state := _dummy_timing_state(session)
				for previous in snapshots:
					if previous[1] == state:
						cycle.proven = true
						cycle.period_frames = frame - previous[0]
						break
				if cycle.proven:
					break
				snapshots.append([frame, state])
				if laps_seen >= MAX_CYCLE_LAPS:
					break
		elif hit_now:
			broken_reason = "命中发生在预期之外的第 %d 帧" % frame
			break
	if broken_reason != "":
		cycle.reason = broken_reason
		return cycle
	cycle.sustained = true
	if cycle.proven:
		cycle.reason = "逐圈模拟中木桩时序状态完全重现，循环可无限重复（无自然受身断点）"
	else:
		cycle.reason = "观测 %d 帧 / %d 圈内全部预期命中成立、未见断链，保守上报为有效循环（未以命中数/时长上限掩盖）" % [frame, cycle.laps_observed]
	return cycle


# --- 探针基础设施 ---

## 私有一次性会话：与训练场会话无关，Solver 不修改任何运行时战斗状态。
func _new_session() -> CombatSession:
	var session := CombatSession.new(_table)
	session.dummy_position = session.player_position + Vector2(PIN_DX, 0.0)
	return session


## 几何接触是求解前提而非证明对象：每帧把木桩钉回命中范围内的横向间距，
## 只保留垂直方向的真实浮空/落地物理。
func _pin_dummy(session: CombatSession) -> void:
	session.dummy_position.x = session.player_position.x + PIN_DX


## 木桩时序状态：决定后续命中/恢复演化的全部可观察量（横向被钉住，不参与比较）。
func _dummy_timing_state(session: CombatSession) -> Array:
	return [
		session.dummy_state,
		session.dummy_hitstun_left,
		session.dummy_velocity.y,
		session.dummy_position.y,
		session.dummy_on_ground,
	]


func _dummy_pursuable(session: CombatSession) -> bool:
	return session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN \
		or session.dummy_state == CombatSession.DummyState.AIR_HITSTUN


func _is_plain_ground_id(move_id: String) -> bool:
	var move := _table.get(move_id) as MoveData
	if move == null or move.stance != MoveData.Stance.GROUND or move.direction_derivation != "":
		return false
	return _plain_key_for(move_id) != ""


## 普通动作键映射：5X 形态的地面招式由 "5"+键 起手；其余（派生/空中）不可由此起手。
func _plain_key_for(move_id: String) -> String:
	if move_id.length() == 2 and move_id[0] == "5":
		return move_id[1]
	return ""


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
