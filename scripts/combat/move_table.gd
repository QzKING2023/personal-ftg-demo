class_name MoveTable
extends RefCounted
## 共享招式表（issue 11）：manifest 统一加载 + 整表校验。
## 训练场（CombatSession）与 Combo Solver 都从这里取得同一份已校验数据；
## 非法表整表拒绝——不跳过招式、不静默修正、不回退旧 GameParams 数值。
## 每条错误按「资源来源｜招式 id｜字段｜冲突原因」可定位。

const DEFAULT_MANIFEST_PATH := "res://data/move_manifest.tres"
## 程序内构造（未保存为资源）的招式在错误信息中的来源标识。
const PROGRAMMATIC_SOURCE := "<程序内>"

const ACTION_KEYS := ["A", "B", "C", "D"]
## 方向谓词合法数字：小键盘 1/2/3/4/6/7/8/9（5 为中立，不构成方向段；0 不存在）。
const DIRECTION_DIGITS := ["1", "2", "3", "4", "6", "7", "8", "9"]


## 加载/校验结果：ok 时 moves 是稳定 id → MoveData 副本（按 manifest 顺序）；
## 拒绝时 moves 为空，errors 收集全部可定位原因（不产出部分表）。
class Result extends RefCounted:
	var ok := true
	var moves := {}
	var errors: Array[String] = []

	func first_error() -> String:
		return errors[0] if not errors.is_empty() else ""


static func load_default() -> Result:
	return load_manifest(DEFAULT_MANIFEST_PATH)


## 从 manifest 加载并整表校验；任何失败都整表拒绝。
static func load_manifest(manifest_path: String) -> Result:
	var result := Result.new()
	var manifest := ResourceLoader.load(manifest_path)
	if manifest == null:
		return _reject(result, "[%s] 清单 — 无法加载（文件不存在或内容类型错误）" % manifest_path)
	if not (manifest is MoveManifest):
		return _reject(result, "[%s] 清单 — 资源类型错误：期望 MoveManifest，实际 %s" % [
			manifest_path, manifest.get_class(),
		])
	var manifest_data := manifest as MoveManifest
	if manifest_data.move_paths.is_empty():
		return _reject(result, "[%s] 清单 — 未引用任何招式资源" % manifest_path)
	var originals: Array = []
	for move_path in manifest_data.move_paths:
		var resource := ResourceLoader.load(move_path)
		if resource == null:
			_reject(result, "[%s] 清单 — 招式资源无法加载（类型错误或文件损坏）: %s" % [
				manifest_path, move_path,
			])
			continue
		if not (resource is MoveData):
			_reject(result, "[%s] 清单 — 招式资源类型错误：期望 MoveData，实际 %s: %s" % [
				manifest_path, resource.get_class(), move_path,
			])
			continue
		originals.append(resource)
	if not result.errors.is_empty():
		return result
	result.errors = validate(originals)
	if not result.errors.is_empty():
		result.ok = false
		return result
	for move in originals:
		var typed := move as MoveData
		result.moves[typed.move_id] = _fresh_copy(typed)
	return result


static func _reject(result: Result, message: String) -> Result:
	result.ok = false
	result.errors.append(message)
	return result


## 整表校验（含跨招式一致性）。空返回值 = 合法；调用方可传入程序内构造的
## MoveData 列表做加载前预检（来源显示为 <程序内>）。
static func validate(move_list: Array) -> Array[String]:
	var errors: Array[String] = []
	var typed_list: Array = []
	for entry in move_list:
		if not (entry is MoveData):
			errors.append("[%s] 跨招式冲突 — 清单项类型错误：期望 MoveData，实际 %s" % [
				PROGRAMMATIC_SOURCE, str(typeof(entry)),
			])
			continue
		typed_list.append(entry as MoveData)
	for move in typed_list:
		_validate_move(move, errors)
	_validate_cross_move(typed_list, errors)
	return errors


# --- 单招校验 ---

static func _validate_move(move: MoveData, errors: Array[String]) -> void:
	var source := move.resource_path if move.resource_path != "" else PROGRAMMATIC_SOURCE
	var id_label := move.move_id if move.move_id != "" else "未声明 id 的招式"

	if move.move_id == "":
		errors.append("[%s] %s: move_id — 缺少稳定 id（id 是资源身份，不由文件名推断）" % [
			source, id_label,
		])
	if move.move_kind == MoveData.MoveKind.UNSET:
		errors.append("[%s] %s: move_kind — 缺少招式类别（STRIKE/THROW）" % [source, id_label])
		return
	if not _enum_in_range(move.move_kind, 1, 2):
		errors.append("[%s] %s: move_kind — 未知枚举值 %d（合法范围 1–2）" % [source, id_label, move.move_kind])
		return
	if move.stance == MoveData.Stance.UNSET:
		errors.append("[%s] %s: stance — 缺少姿态（GROUND/AIR）" % [source, id_label])
		return
	if not _enum_in_range(move.stance, 1, 2):
		errors.append("[%s] %s: stance — 未知枚举值 %d（合法范围 1–2）" % [source, id_label, move.stance])
		return

	for pair in [["startup_frames", move.startup_frames], ["active_frames", move.active_frames],
			["recovery_frames", move.recovery_frames]]:
		var field: String = pair[0]
		var value: int = pair[1]
		if value < 1:
			errors.append("[%s] %s: %s — 帧窗口为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
				source, id_label, field, value,
			])
	if move.cancel_window_frames < 0:
		errors.append("[%s] %s: cancel_window_frames — 取消窗口为负或未设置（当前 %d）" % [
			source, id_label, move.cancel_window_frames,
		])
	if move.priority < 0:
		errors.append("[%s] %s: priority — 优先级为负或未设置（当前 %d）" % [
			source, id_label, move.priority,
		])
	if not _enum_in_range(move.command_tier, 0, 2):
		errors.append("[%s] %s: command_tier — 未知指令层级枚举值 %d（合法范围 0–2：普通/必杀/超必杀）" % [
			source, id_label, move.command_tier,
		])
	if move.lenient_command and move.direction_derivation == "" and move.input_alternatives.is_empty():
		errors.append("[%s] %s: lenient_command — 矛盾：宽松指令必须声明方向记法（派生或替代串）" % [
			source, id_label,
		])
	if move.extra_landing_recovery_frames < 0:
		errors.append("[%s] %s: extra_landing_recovery_frames — 额外落地恢复为负或未设置（当前 %d）" % [
			source, id_label, move.extra_landing_recovery_frames,
		])

	match move.move_kind:
		MoveData.MoveKind.STRIKE:
			_validate_strike_fields(move, source, id_label, errors)
		MoveData.MoveKind.THROW:
			_validate_throw_fields(move, source, id_label, errors)

	_validate_derivation_notation(move, source, id_label, errors)

	# 矛盾字段组合。
	if move.is_finisher:
		for pair in [["cancel_targets", move.cancel_targets], ["jump_cancel_targets", move.jump_cancel_targets],
				["landing_cancel_targets", move.landing_cancel_targets]]:
			var field: String = pair[0]
			var targets: Array[String] = pair[1]
			if not targets.is_empty():
				errors.append("[%s] %s: %s — 矛盾：收尾招式不开放命中确认取消" % [source, id_label, field])
	if move.stance == MoveData.Stance.AIR and not move.jump_cancel_targets.is_empty():
		errors.append("[%s] %s: jump_cancel_targets — 矛盾：jump cancel 只能配置在地面招式上" % [
			source, id_label,
		])
	if move.stance == MoveData.Stance.GROUND and not move.landing_cancel_targets.is_empty():
		errors.append("[%s] %s: landing_cancel_targets — 矛盾：落地接续只能配置在空中招式上" % [
			source, id_label,
		])
	if move.stance == MoveData.Stance.GROUND and move.extra_landing_recovery_frames > 0:
		errors.append("[%s] %s: extra_landing_recovery_frames — 矛盾：额外落地恢复只属于空中招式（当前 %d）" % [
			source, id_label, move.extra_landing_recovery_frames,
		])


static func _validate_strike_fields(move: MoveData, source: String, id_label: String, errors: Array[String]) -> void:
	if not ACTION_KEYS.has(move.action_key):
		errors.append("[%s] %s: action_key — 打击招式缺少输入绑定（须为 A/B/C/D，当前 \"%s\"）" % [
			source, id_label, move.action_key,
		])
	if move.base_damage <= 0:
		errors.append("[%s] %s: base_damage — 打击招式缺少基础伤害或数值非法（当前 %d，须为正）" % [
			source, id_label, move.base_damage,
		])
	if not _enum_in_range(move.attack_attribute, 1, 4):
		if move.attack_attribute == MoveData.AttackAttribute.UNSET:
			errors.append("[%s] %s: attack_attribute — 打击招式缺少攻击属性（枚举值 0）" % [source, id_label])
		else:
			errors.append("[%s] %s: attack_attribute — 未知枚举值 %d（合法范围 1–4）" % [
				source, id_label, move.attack_attribute,
			])
	if move.hitbox_size.x <= 0.0 or move.hitbox_size.y <= 0.0:
		errors.append("[%s] %s: hitbox_size — 打击招式缺少命中框（当前 %s，两轴均须为正）" % [
			source, id_label, str(move.hitbox_size),
		])
	if move.hitbox_gap < 0.0:
		errors.append("[%s] %s: hitbox_gap — 命中框间隙为负或未设置（当前 %s）" % [
			source, id_label, str(move.hitbox_gap),
		])
	if move.hit_result == MoveData.HitResult.UNSET:
		errors.append("[%s] %s: hit_result — 打击招式缺少命中结果（枚举值 0）" % [source, id_label])
	elif not _enum_in_range(move.hit_result, 1, 2):
		errors.append("[%s] %s: hit_result — 未知枚举值 %d（合法范围 1–2）" % [
			source, id_label, move.hit_result,
		])
	if move.hitstun_frames < 1:
		errors.append("[%s] %s: hitstun_frames — 打击招式缺少受击硬直或数值非法（当前 %d）" % [
			source, id_label, move.hitstun_frames,
		])
	if move.knockback < 0.0:
		errors.append("[%s] %s: knockback — 打击招式缺少击退或数值为负（当前 %s）" % [
			source, id_label, str(move.knockback),
		])
	if move.knockback_up < 0.0:
		errors.append("[%s] %s: knockback_up — 击飞为负或未设置（当前 %s）" % [
			source, id_label, str(move.knockback_up),
		])
	if move.throw_range > 0.0:
		errors.append("[%s] %s: throw_range — 矛盾：打击招式不声明投距（当前 %s）" % [
			source, id_label, str(move.throw_range),
		])


static func _validate_throw_fields(move: MoveData, source: String, id_label: String, errors: Array[String]) -> void:
	if move.throw_range <= 0.0:
		errors.append("[%s] %s: throw_range — 投技缺少投距或数值非法（当前 %s，须为正）" % [
			source, id_label, str(move.throw_range),
		])
	if move.startup_frames != 5:
		errors.append("[%s] %s: startup_frames — 普通投 startup 固定 5 帧（领域规则，不由资源覆盖，当前 %d）" % [
			source, id_label, move.startup_frames,
		])
	if move.active_frames != GameParams.THROW_TECH_WINDOW_AFTER_GRAB + 1:
		errors.append("[%s] %s: active_frames — 普通投 active 固定为投发生 1 帧 + 拆投延续 %d 帧 = %d 帧（领域规则：拆投窗口从首个 startup 帧起算约 15f，当前 %d）" % [
			source, id_label, GameParams.THROW_TECH_WINDOW_AFTER_GRAB,
			GameParams.THROW_TECH_WINDOW_AFTER_GRAB + 1, move.active_frames,
		])
	if move.action_key != "":
		errors.append("[%s] %s: action_key — 矛盾：普通投是 B+C 组合输入，不声明单键绑定（当前 \"%s\"）" % [
			source, id_label, move.action_key,
		])
	if move.direction_derivation != "":
		errors.append("[%s] %s: direction_derivation — 矛盾：普通投不支持方向派生记法（当前 \"%s\"）" % [
			source, id_label, move.direction_derivation,
		])


## 方向谓词记法校验：形如 "236C" = 方向序列 + 动作键。方向段只能是
## 1/2/3/4/6/7/8/9（5 为中立、不构成方向段），末位必须是动作键且与声明的
## 输入绑定一致。显式输入替代串使用同一记法规则。
static func _validate_derivation_notation(move: MoveData, source: String, id_label: String, errors: Array[String]) -> void:
	var notations: Array[String] = []
	if move.direction_derivation != "":
		notations.append(move.direction_derivation)
	notations.append_array(move.input_alternatives)
	for notation in notations:
		var problems: Array[String] = []
		if notation.length() < 2:
			problems.append("至少需要 1 个方向段加 1 个动作键")
		var digits := notation.left(maxi(notation.length() - 1, 0))
		for digit in digits:
			if not DIRECTION_DIGITS.has(digit):
				problems.append("方向段 \"%s\" 非法（只能是 1/2/3/4/6/7/8/9，5 为中立不构成方向段）" % digits)
				break
		var key := notation.right(1)
		if not ACTION_KEYS.has(key):
			problems.append("末位 \"%s\" 不是动作键 A/B/C/D" % key)
		elif move.action_key != "" and key != move.action_key:
			problems.append("末位键 %s 与声明的输入绑定 %s 不一致" % [key, move.action_key])
		if not problems.is_empty():
			errors.append("[%s] %s: direction_derivation — 非法方向谓词 \"%s\"：%s" % [
				source, id_label, notation, "；".join(problems),
			])


# --- 跨招式校验 ---

static func _validate_cross_move(move_list: Array, errors: Array[String]) -> void:
	var seen_ids := {}
	var binding_priority := {}
	var throw_count := 0
	var first_throw := ""
	for move in move_list:
		var typed := move as MoveData
		var source := typed.resource_path if typed.resource_path != "" else PROGRAMMATIC_SOURCE
		if typed.move_id != "":
			if seen_ids.has(typed.move_id):
				errors.append("[%s] 跨招式冲突: 稳定 id \"%s\" 重复出现（另见 [%s]）" % [
					source, typed.move_id, seen_ids[typed.move_id],
				])
			else:
				seen_ids[typed.move_id] = source
		if typed.is_throw():
			# B+C 组合输入没有单键/层级/记法维度可区分多个投技——并列即无确定性
			# 选择，属于非法数据（与同绑定同优先级并列同一口径）。
			throw_count += 1
			if throw_count == 1:
				first_throw = typed.move_id if typed.move_id != "" else source
			elif throw_count == 2:
				errors.append("[%s] 跨招式冲突: 普通投 %s 与 %s 并列——B+C 组合输入至多一个投技" % [
					source, first_throw, typed.move_id,
				])
		# 同姿态+同输入绑定+同指令层级+同优先级 = 并列，无确定性选择，属于非法数据。
		# 层级进入并列键、方向记法不再进入：超必杀与必杀可同键同优先级共存（由
		# 指令分层解析），而不同记法（如宽松 623 与严格 236）可能同时命中同一输入，
		# 同层同优先级时无稳定顺序，一并拒绝、不按表序猜测。
		if typed.is_strike() and typed.action_key != "":
			var key := "%d|%s|%d|%d" % [
				typed.stance, typed.action_key, typed.command_tier, typed.priority,
			]
			if binding_priority.has(key):
				errors.append("[%s] 跨招式冲突: %s 与 %s 声明了相同姿态+输入绑定+指令层级且优先级并列（%d）" % [
					source, binding_priority[key], typed.move_id, typed.priority,
				])
			else:
				binding_priority[key] = typed.move_id
		for pair in [["cancel_targets", typed.cancel_targets], ["jump_cancel_targets", typed.jump_cancel_targets],
				["landing_cancel_targets", typed.landing_cancel_targets]]:
			var field: String = pair[0]
			var targets: Array[String] = pair[1]
			for target in targets:
				if not _has_move_id(move_list, target):
					errors.append("[%s] %s: %s — 跨招式非法引用：\"%s\" 不在招式表中" % [
						source, typed.move_id, field, target,
					])


static func _has_move_id(move_list: Array, move_id: String) -> bool:
	for move in move_list:
		if (move as MoveData).move_id == move_id:
			return true
	return false


static func _enum_in_range(value: int, low: int, high: int) -> bool:
	return value >= low and value <= high


## 深副本：加载结果与资源缓存隔离，调用方修改副本不会污染其他消费者。
## 基础字段走 duplicate()（新增导出字段自动被复制）；数组是引用类型，逐个重建。
static func _fresh_copy(move: MoveData) -> MoveData:
	var copy := move.duplicate() as MoveData
	copy.resource_path = ""
	copy.cancel_targets = move.cancel_targets.duplicate()
	copy.jump_cancel_targets = move.jump_cancel_targets.duplicate()
	copy.landing_cancel_targets = move.landing_cancel_targets.duplicate()
	copy.input_alternatives = move.input_alternatives.duplicate()
	return copy
