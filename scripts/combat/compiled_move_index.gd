class_name CompiledMoveIndex
extends RefCounted
## P1（perf-index）招式表不可变索引：请求开始时一次预处理，消除请求内重复
## 全表扫描（_charge_base_of/_start_key_for 逐次 O(N)、_build_contexts 固定点
## 每轮 × 6 个 _context_via_* × 全表、缺口枚举的 V² 重复谓词推导）。
## 索引只承载两类事实，不引入新语义：
##   - 反向表（rev_*）按表序收录全部通过对应 _context_via_* 同一结构谓词的
##     来源。消费方迭代时逐谓词复验——索引过度收录只损失性能，绝不改变选择；
##     收录顺序 = 表序，与旧路径全表扫描的首个命中选择逐字节一致。
##   - configured_edges / gap_candidates 逐条复刻 _analyze 配置边循环与
##     _enumerate_gaps 的枚举顺序（from 表序 × kind 固定序 × 目标声明序），
##     搜索顺序由此冻结在索引里。LANDING_CANCEL 缺口候选结构性死亡：
##     _build_edge 在任何 CombatSession 之前无条件拒绝（落地恢复首帧不可取消），
##     探针必然返回 null、不产生任何报告输出——索引期剔除，不付探针成本。
## kind 用裸 int 承载（ComboSolver.EdgeKind 序：CANCEL=0 … HIT_LANDING_CANCEL=10）；
## 该序已被结果缓存快照冻结，KIND_ORDER/GAP_FIELD_BY_KIND 与
## ComboSolver._GAP_CONFIG_FIELDS 的一致性由 test_solver_index_equiv.gd 断言。
## 不可变约定：build 之后不再写入；缺口探针的接种只发生在 staged 副本上
##（见 ComboSolver._enumerate_gaps），不改键空间，索引查找全程有效。

## 接续种类固定枚举序（镜像 _analyze 的 kinds_and_targets 声明序）。
const KIND_ORDER := [
	0,  # CANCEL
	1,  # CHAIN_CANCEL
	2,  # SPECIAL_CANCEL
	3,  # JUMP_CANCEL
	4,  # LANDING_CANCEL
	5,  # NORMAL_LINK
	6,  # REKKA_DERIVE
	7,  # SPECIAL_ENTRY
	8,  # SPECIAL_ENTRY_LINK
	9,  # AIR_EXIT
	10, # HIT_LANDING_CANCEL
]
## 缺口候选涉及的配置字段（镜像 ComboSolver._GAP_CONFIG_FIELDS 的 field 项）。
const GAP_FIELD_BY_KIND := {
	0: "cancel_targets",
	1: "chain_cancel_targets",
	2: "special_cancel_targets",
	3: "jump_cancel_targets",
	4: "landing_cancel_targets",
	5: "link_targets",
	6: "rekka_b_target",
	7: "special_entry_targets",
	8: "special_entry_link_targets",
	9: "air_exit_targets",
	10: "hit_landing_cancel_targets",
}
## 链式/必杀/命中落地缺口的窗口垫值（镜像 _gap_injected_move 的初值注入）。
const GAP_WINDOW_PADS := {
	1: {"field": "chain_cancel_window_frames", "value": 3},
	2: {"field": "special_cancel_window_frames", "value": 5},
	10: {"field": "hit_landing_cancel_window_frames", "value": 24},
}

## 一条候选接续的轻量描述：只携带枚举所需的最小事实，不复制任何 MoveData。
class EdgeDescriptor extends RefCounted:
	var from_id := ""
	var to_id := ""
	var kind := 0


## 表序全量有效招式 id。
var move_ids: Array[String] = []
## move_id → 起手动作键（"" = 不可单键/指令起手；镜像 _start_key_for 规则）。
var start_keys := {}
## charge_move_id → 普通版 MoveData（表序首个命中；镜像 _charge_base_of 规则）。
var charge_bases := {}
## 上下文传播的待定名单（表序；镜像 _build_contexts 固定点循环的合格过滤）。
var context_pending: Array[String] = []
## to → 声明了它的来源 id（表序；谓词镜像各 _context_via_*）。
var rev_cancel := {}
var rev_jump_cancel := {}
var rev_landing_cancel := {}
var rev_rekka := {}
var rev_air_exit := {}
## 配置边候选（镜像 _analyze 边循环的完整枚举序，含蓄力变体派生边）。
var configured_edges: Array = []
## 缺口候选（镜像 _enumerate_gaps 的枚举序；LANDING_CANCEL 已在索引期剔除）。
## from 侧 contexts.has 的运行时过滤由消费方逐候选执行。
var gap_candidates: Array = []


static func build(table: Dictionary) -> CompiledMoveIndex:
	var index := CompiledMoveIndex.new()
	index._scan_moves(table)
	index._build_reverse_indexes(table)
	index._build_configured_edges(table)
	index._build_gap_candidates(table)
	return index


func _scan_moves(table: Dictionary) -> void:
	for move_id in table:
		var move := table[move_id] as MoveData
		if move == null:
			continue
		move_ids.append(move_id)
		start_keys[move_id] = _start_key_of(move)
		if move.charge_move_id != "" and not charge_bases.has(move.charge_move_id):
			charge_bases[move.charge_move_id] = move
		if start_keys[move_id] != "" or move.rekka_only or move.charge_only:
			context_pending.append(move_id)


## 镜像 _start_key_for：投技/rekka_only/charge_only 不可单键起手。
static func _start_key_of(move: MoveData) -> String:
	if move.is_throw() or move.rekka_only or move.charge_only:
		return ""
	return move.action_key


func _build_reverse_indexes(table: Dictionary) -> void:
	for source_id in table:
		var source := table[source_id] as MoveData
		if source == null:
			continue
		if source.stance != MoveData.Stance.AIR:
			for target_id in source.jump_cancel_targets:
				_append_rev(rev_jump_cancel, target_id, source_id)
		for target_id in source.cancel_targets:
			var target := table.get(target_id) as MoveData
			if target != null and source.stance == target.stance:
				_append_rev(rev_cancel, target_id, source_id)
		if source.stance == MoveData.Stance.AIR:
			for target_id in source.landing_cancel_targets:
				_append_rev(rev_landing_cancel, target_id, source_id)
		if source.rekka_window_frames >= 0:
			for target_id in _rekka_targets_of(source):
				_append_rev(rev_rekka, target_id, source_id)
		if source.stance == MoveData.Stance.GROUND and source.has_motion() and source.motion_y_px < 0.0:
			for target_id in source.air_exit_targets:
				_append_rev(rev_air_exit, target_id, source_id)


func _append_rev(reverse: Dictionary, target_id: String, source_id: String) -> void:
	if not reverse.has(target_id):
		reverse[target_id] = [] as Array[String]
	(reverse[target_id] as Array[String]).append(source_id)


## 镜像 _rekka_targets_of：~B 在前、~C 在后，去重，仅窗口已声明时收录。
static func _rekka_targets_of(move: MoveData) -> Array[String]:
	var targets: Array[String] = []
	if move.rekka_window_frames < 0:
		return targets
	for target in [move.rekka_b_target, move.rekka_c_target]:
		if target != "" and not targets.has(target):
			targets.append(target)
	return targets


## 镜像 _analyze 配置边循环：from 表序 → KIND_ORDER 固定序 → 目标声明序，
## 每条候选后附蓄力变体派生（to 声明蓄力且表内有蓄力版目标）。
func _build_configured_edges(table: Dictionary) -> void:
	for from_id in table:
		var from_move := table[from_id] as MoveData
		if from_move == null or from_move.is_throw():
			continue
		var kinds_and_targets := [
			[0, from_move.cancel_targets],
			[1, from_move.chain_cancel_targets],
			[2, from_move.special_cancel_targets],
			[3, from_move.jump_cancel_targets],
			[4, from_move.landing_cancel_targets],
			[5, from_move.link_targets],
			[6, _rekka_targets_of(from_move)],
			[7, from_move.special_entry_targets],
			[8, from_move.special_entry_link_targets],
			[9, from_move.air_exit_targets],
			[10, from_move.hit_landing_cancel_targets],
		]
		for pair in kinds_and_targets:
			var kind: int = pair[0]
			for to_id in pair[1]:
				_add_configured(from_id, to_id, kind)
				var to_move := table.get(to_id) as MoveData
				if to_move != null and to_move.is_chargeable() and table.has(to_move.charge_move_id):
					_add_configured(from_id, to_move.charge_move_id, kind)


func _add_configured(from_id: String, to_id: String, kind: int) -> void:
	var descriptor := EdgeDescriptor.new()
	descriptor.from_id = from_id
	descriptor.to_id = to_id
	descriptor.kind = kind
	configured_edges.append(descriptor)


## 镜像 _enumerate_gaps 的候选序：from 表序 → to 表序 → 每对的 kind 序
##（cancel → chain → special → link → jump）。from 侧 throw/finisher 与
## to 侧 throw/不可起手过滤为静态结构，索引期执行；contexts.has(from) 是
## 运行时事实，由消费方逐候选复验。LANDING_CANCEL（空→地）候选结构性死亡
## （_build_edge 无条件拒绝、探针必 null、零报告输出），索引期剔除——这是
## 唯一一类「结构上不可能」的缺口候选：其余姿态组合的成立性都要真实结算
## 裁决，不允许静态预判。
func _build_gap_candidates(table: Dictionary) -> void:
	for from_id in table:
		var from_move := table[from_id] as MoveData
		if from_move == null or from_move.is_throw() or from_move.is_finisher:
			continue
		for to_id in table:
			var to_move := table[to_id] as MoveData
			if to_move == null or to_move.is_throw() or _start_key_of(to_move) == "":
				continue
			var kinds: Array[int] = []
			if to_move.stance == from_move.stance:
				kinds.append(0)
				kinds.append(1)
				kinds.append(2)
				if from_move.stance != MoveData.Stance.AIR:
					kinds.append(5)
			for kind in kinds:
				if (from_move.get(GAP_FIELD_BY_KIND[kind]) as Array).has(to_id):
					continue
				_add_gap(from_id, to_id, kind)
			if from_move.stance == MoveData.Stance.GROUND and to_move.stance == MoveData.Stance.AIR \
					and not (from_move.jump_cancel_targets as Array).has(to_id) \
					and not (from_move.air_exit_targets as Array).has(to_id):
				_add_gap(from_id, to_id, 3)


func _add_gap(from_id: String, to_id: String, kind: int) -> void:
	var descriptor := EdgeDescriptor.new()
	descriptor.from_id = from_id
	descriptor.to_id = to_id
	descriptor.kind = kind
	gap_candidates.append(descriptor)
