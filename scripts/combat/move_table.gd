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
	for pair in [["chain_cancel_targets", move.chain_cancel_targets, "chain_cancel_window_frames", move.chain_cancel_window_frames],
			["special_cancel_targets", move.special_cancel_targets, "special_cancel_window_frames", move.special_cancel_window_frames]]:
		var targets: Array[String] = pair[1]
		var window_field: String = pair[2]
		var window: int = pair[3]
		if not targets.is_empty() and window < 0:
			errors.append("[%s] %s: %s — 矛盾：声明 %d 个目标却未声明窗口（当前 %d）" % [
				source, id_label, window_field, targets.size(), window,
			])
		if targets.is_empty() and window >= 0:
			errors.append("[%s] %s: %s — 矛盾：没有目标却声明了窗口（当前 %d，空列表须保持未声明 -1）" % [
				source, id_label, window_field, window,
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
				["landing_cancel_targets", move.landing_cancel_targets],
				["chain_cancel_targets", move.chain_cancel_targets],
				["special_cancel_targets", move.special_cancel_targets],
				["link_targets", move.link_targets],
				["special_entry_targets", move.special_entry_targets],
				["special_entry_link_targets", move.special_entry_link_targets],
				["air_exit_targets", move.air_exit_targets]]:
			var field: String = pair[0]
			var targets: Array[String] = pair[1]
			if not targets.is_empty():
				errors.append("[%s] %s: %s — 矛盾：收尾招式不开放取消或普通连接" % [source, id_label, field])
	if move.stance == MoveData.Stance.AIR and not move.jump_cancel_targets.is_empty():
		errors.append("[%s] %s: jump_cancel_targets — 矛盾：jump cancel 只能配置在地面招式上" % [
			source, id_label,
		])
	if move.stance == MoveData.Stance.AIR and not move.air_exit_targets.is_empty():
		errors.append("[%s] %s: air_exit_targets — 矛盾：空中出口只配置在地面招式上（出口借用地面招式位移造成的真实离地，空中招式无此接缝）" % [
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
	if move.stance == MoveData.Stance.AIR and move.requires_crouch:
		errors.append("[%s] %s: requires_crouch — 矛盾：蹲姿限定只属于地面招式（空中按下方向不构成蹲姿）" % [
			source, id_label,
		])
	# 附加判定段（票据 05）：仅打击招式；每段自带 active/命中框/伤害/命中资料，
	# 未声明字段整表拒绝。
	if not move.segments.is_empty():
		if not move.is_strike():
			errors.append("[%s] %s: segments — 矛盾：普通投不声明附加判定段（当前 %d 段）" % [
				source, id_label, move.segments.size(),
			])
		for i in move.segments.size():
			_validate_segment(move.segments[i], i, source, id_label, errors)
	# 特殊进入资格（票据 05，I-05）：目标与窗口成对声明；与链式/必杀取消独立。
	for pair in [["special_entry_targets", move.special_entry_targets, "special_entry_window_frames", move.special_entry_window_frames]]:
		var targets: Array[String] = pair[1]
		var window_field: String = pair[2]
		var window: int = pair[3]
		if not targets.is_empty() and window < 0:
			errors.append("[%s] %s: %s — 矛盾：声明 %d 个特殊进入目标却未声明窗口（当前 %d）" % [
				source, id_label, window_field, targets.size(), window,
			])
		if targets.is_empty() and window >= 0:
			errors.append("[%s] %s: %s — 矛盾：没有特殊进入目标却声明了窗口（当前 %d，空列表须保持未声明 -1）" % [
				source, id_label, window_field, window,
			])
	# 命中落地取消（票据 08，L-01）：目标与窗口成对声明；只属于空中打击招式。
	if not move.hit_landing_cancel_targets.is_empty() and move.hit_landing_cancel_window_frames < 0:
		errors.append("[%s] %s: hit_landing_cancel_window_frames — 矛盾：声明 %d 个命中落地取消目标却未声明窗口（当前 %d）" % [
			source, id_label, move.hit_landing_cancel_targets.size(), move.hit_landing_cancel_window_frames,
		])
	if move.hit_landing_cancel_targets.is_empty() and move.hit_landing_cancel_window_frames >= 0:
		errors.append("[%s] %s: hit_landing_cancel_window_frames — 矛盾：没有命中落地取消目标却声明了窗口（当前 %d，空列表须保持未声明 -1）" % [
			source, id_label, move.hit_landing_cancel_window_frames,
		])
	if not move.hit_landing_cancel_targets.is_empty():
		if move.stance != MoveData.Stance.AIR:
			errors.append("[%s] %s: hit_landing_cancel_targets — 矛盾：命中落地取消只属于空中招式（当前姿态 %d）" % [
				source, id_label, move.stance,
			])
		if not move.is_strike():
			errors.append("[%s] %s: hit_landing_cancel_targets — 矛盾：普通投不声明命中落地取消" % [
				source, id_label,
			])
	# Rekka 派生字段组合（票据 04，I-04/S-07）。
	if move.rekka_window_frames >= 0 and move.rekka_b_target == "" and move.rekka_c_target == "":
		errors.append("[%s] %s: rekka_window_frames — 矛盾：声明派生窗口却未声明任何 B/C 分支目标" % [
			source, id_label,
		])
	if move.rekka_window_frames < 0 and (move.rekka_b_target != "" or move.rekka_c_target != ""):
		errors.append("[%s] %s: rekka_b_target — 矛盾：声明派生目标却未声明派生窗口" % [
			source, id_label,
		])
	if move.rekka_window_frames >= 0 and move.rekka_b_target == move.rekka_c_target and move.rekka_b_target != "":
		errors.append("[%s] %s: rekka_b_target — 矛盾：~B 与 ~C 分支不能指向同一招式（分支按首个按键区分）" % [
			source, id_label,
		])
	if move.rekka_only:
		if not move.is_strike():
			errors.append("[%s] %s: rekka_only — 矛盾：Rekka 派生限定只属于打击招式" % [
				source, id_label,
			])
		if move.rekka_window_frames >= 0:
			errors.append("[%s] %s: rekka_only — 矛盾：招式不能既是 Rekka 首段又是派生目标" % [
				source, id_label,
			])
		if move.direction_derivation != "" or not move.input_alternatives.is_empty():
			errors.append("[%s] %s: rekka_only — 矛盾：派生招式不参与单键/指令输入选择，不声明方向记法" % [
				source, id_label,
			])
	# 计划位移（票据 06，M-01/M-03）：两轴成对声明或成对未声明；普通投不位移。
	if is_nan(move.motion_x_px) != is_nan(move.motion_y_px):
		errors.append("[%s] %s: motion_x_px/motion_y_px — 矛盾：计划位移两轴必须成对声明或成对未声明" % [
			source, id_label,
		])
	if move.has_motion() and not move.is_strike():
		errors.append("[%s] %s: motion_x_px — 矛盾：普通投不声明计划位移" % [
			source, id_label,
		])
	# 动作内蓄力（票据 06，I-01/I-02）：阈值与目标成对声明；蓄力版不得再声明
	# 蓄力（不链式蓄力）；charge_only 限定打击招式且不参与输入选择。
	if move.charge_threshold_frames >= 0 and move.charge_move_id == "":
		errors.append("[%s] %s: charge_threshold_frames — 矛盾：声明蓄力阈值却未声明蓄力目标（当前 %d）" % [
			source, id_label, move.charge_threshold_frames,
		])
	if move.charge_threshold_frames < 0 and move.charge_move_id != "":
		errors.append("[%s] %s: charge_move_id — 矛盾：声明蓄力目标却未声明蓄力阈值" % [
			source, id_label,
		])
	if move.charge_threshold_frames == 0:
		errors.append("[%s] %s: charge_threshold_frames — 矛盾：蓄力阈值须至少 1 帧（当前 0）" % [
			source, id_label,
		])
	if move.charge_threshold_frames > 0 and not move.is_strike():
		errors.append("[%s] %s: charge_threshold_frames — 矛盾：普通投不做动作内蓄力" % [
			source, id_label,
		])
	if move.charge_only:
		if not move.is_strike():
			errors.append("[%s] %s: charge_only — 矛盾：蓄力限定只属于打击招式" % [
				source, id_label,
			])
		if move.charge_threshold_frames > 0 or move.charge_move_id != "":
			errors.append("[%s] %s: charge_only — 矛盾：招式不能既是蓄力版又声明自己的蓄力（不链式蓄力）" % [
				source, id_label,
			])
		if move.direction_derivation != "" or not move.input_alternatives.is_empty():
			errors.append("[%s] %s: charge_only — 矛盾：蓄力版不参与单键/指令输入选择，不声明方向记法" % [
				source, id_label,
			])
		if move.rekka_only:
			errors.append("[%s] %s: charge_only — 矛盾：招式不能既是蓄力版又是 Rekka 派生（入口必须唯一）" % [
				source, id_label,
			])


static func _validate_strike_fields(move: MoveData, source: String, id_label: String, errors: Array[String]) -> void:
	if not ACTION_KEYS.has(move.action_key):
		errors.append("[%s] %s: action_key — 打击招式缺少输入绑定（须为 A/B/C/D，当前 \"%s\"）" % [
			source, id_label, move.action_key,
		])
	if move.base_damage < 0:
		errors.append("[%s] %s: base_damage — 打击招式缺少基础伤害或数值为负（当前 %d，须为非负）" % [
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
	if move.hit_profiles.is_empty():
		errors.append("[%s] %s: hit_profiles — 打击招式缺少命中资料（至少一个合法 HitProfile）" % [
			source, id_label,
		])
	if not _enum_in_range(move.starter_grade, 1, 4):
		errors.append("[%s] %s: starter_grade — 打击招式缺少起手等级（枚举值 0；合法范围 1–4：A/B/C/D，不由动作键推断）" % [
			source, id_label,
		])
	if move.throw_range > 0.0:
		errors.append("[%s] %s: throw_range — 矛盾：打击招式不声明投距（当前 %s）" % [
			source, id_label, str(move.throw_range),
		])
	for pair in [["block_freeze_frames", move.block_freeze_frames], ["block_stun_frames", move.block_stun_frames]]:
		var block_field: String = pair[0]
		var block_value: int = pair[1]
		if block_value < 0:
			errors.append("[%s] %s: %s — 被防停顿/硬直为负或未声明（当前 %d；被防结果独立于命中资料逐招声明，无全局回退）" % [
				source, id_label, block_field, block_value,
			])
	if move.block_pushback_px_s < 0.0:
		errors.append("[%s] %s: block_pushback_px_s — 被防推退为负或未声明（当前 %s；被防结果独立于命中资料逐招声明，无全局回退）" % [
			source, id_label, str(move.block_pushback_px_s),
		])
	_validate_hit_profiles(move, source, id_label, errors)


## 附加判定段校验（票据 05）：段的帧窗口/命中框/伤害/命中资料全部显式声明；
## 命中资料沿用与段 1 相同的反应组合与 Counter 成对规则。
static func _validate_segment(segment: MoveSegment, index: int, source: String, id_label: String, errors: Array[String]) -> void:
	var label := "segments[%d]" % index
	if not (segment is MoveSegment):
		errors.append("[%s] %s: %s — 条目类型错误：期望 MoveSegment，实际 %s" % [
			source, id_label, label, segment.get_class() if segment != null else "null",
		])
		return
	if segment.startup_frames < 0:
		errors.append("[%s] %s: %s: startup_frames — 段间隔为负或未声明（当前 %d，合法为 ≥0）" % [
			source, id_label, label, segment.startup_frames,
		])
	if segment.active_frames < 1:
		errors.append("[%s] %s: %s: active_frames — 判定帧数为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
			source, id_label, label, segment.active_frames,
		])
	if segment.base_damage < 0:
		errors.append("[%s] %s: %s: base_damage — 段伤害为负或未声明（当前 %d，须为非负）" % [
			source, id_label, label, segment.base_damage,
		])
	if segment.hitbox_size.x <= 0.0 or segment.hitbox_size.y <= 0.0:
		errors.append("[%s] %s: %s: hitbox_size — 段缺少命中框（当前 %s，两轴均须为正）" % [
			source, id_label, label, str(segment.hitbox_size),
		])
	if segment.hitbox_gap < 0.0:
		errors.append("[%s] %s: %s: hitbox_gap — 段命中框间隙为负或未设置（当前 %s）" % [
			source, id_label, label, str(segment.hitbox_gap),
		])
	if segment.hit_profiles.is_empty():
		errors.append("[%s] %s: %s: hit_profiles — 段缺少命中资料（至少一个合法 HitProfile）" % [
			source, id_label, label,
		])
	_validate_hit_profiles(segment, source, "%s: %s" % [id_label, label], errors)


static func _validate_throw_fields(move: MoveData, source: String, id_label: String, errors: Array[String]) -> void:
	if move.throw_range <= 0.0:
		errors.append("[%s] %s: throw_range — 投技缺少投距或数值非法（当前 %s，须为正）" % [
			source, id_label, str(move.throw_range),
		])
	if not move.hit_profiles.is_empty():
		errors.append("[%s] %s: hit_profiles — 矛盾：投技结果参数是 GameParams 领域规则，不声明命中资料（当前 %d 个）" % [
			source, id_label, move.hit_profiles.size(),
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
	if move.block_freeze_frames != -1 or move.block_stun_frames != -1 or move.block_pushback_px_s >= 0.0:
		errors.append("[%s] %s: block_freeze_frames — 矛盾：普通投不可被防御，不声明被防结果（当前停顿 %d / 硬直 %d / 推退 %s）" % [
			source, id_label, move.block_freeze_frames, move.block_stun_frames, str(move.block_pushback_px_s),
		])


## 命中资料校验（规格 §3）：枚举范围、(target_state, hit_context) 唯一键、
## reaction 与目标/计时/速度的组合规则、Counter 依赖同状态 NORMAL。数组顺序
## 不是选择依据，只用于错误定位。owner 是 MoveData（段 1）或 MoveSegment
## （附加段，票据 05）——两者同构持有 hit_profiles 与 has_normal_profile。
static func _validate_hit_profiles(owner, source: String, id_label: String, errors: Array[String]) -> void:
	var seen_keys := {}
	for i in owner.hit_profiles.size():
		var profile: HitProfile = owner.hit_profiles[i]
		var label := "hit_profiles[%d]" % i
		if not (profile is HitProfile):
			errors.append("[%s] %s: %s — 条目类型错误：期望 HitProfile，实际 %s" % [
				source, id_label, label, profile.get_class() if profile != null else "null",
			])
			continue
		if not _enum_in_range(profile.target_state, 1, 3):
			errors.append("[%s] %s: %s: target_state — 未知或未声明枚举值 %d（合法范围 1–3：grounded/airborne/slide）" % [
				source, id_label, label, profile.target_state,
			])
			continue
		if not _enum_in_range(profile.hit_context, 1, 2):
			errors.append("[%s] %s: %s: hit_context — 未知或未声明枚举值 %d（合法范围 1–2：normal/counter）" % [
				source, id_label, label, profile.hit_context,
			])
			continue
		var key := "%d|%d" % [profile.target_state, profile.hit_context]
		if seen_keys.has(key):
			errors.append("[%s] %s: %s — 重复键 %s（与 hit_profiles[%d] 冲突；profile 顺序不是选择依据）" % [
				source, id_label, label, profile.label(), seen_keys[key],
			])
		else:
			seen_keys[key] = i
		if not _enum_in_range(profile.reaction, 1, 6):
			errors.append("[%s] %s: %s: reaction — 未知或未声明枚举值 %d（合法范围 1–6：ground_hitstun/launch/ground_knockdown/low_float_sweep/downward_slam/low_float_to_slide）" % [
				source, id_label, label, profile.reaction,
			])
			continue
		if profile.damage_override < -1:
			errors.append("[%s] %s: %s: damage_override — 非法覆盖伤害 %d（-1 表示沿用 base_damage，否则须为非负）" % [
				source, id_label, label, profile.damage_override,
			])
		if profile.horizontal_speed_px_s < 0.0:
			errors.append("[%s] %s: %s: horizontal_speed_px_s — 水平速度为负或未声明（当前 %s，所有合法 reaction 都必须声明非负幅值）" % [
				source, id_label, label, str(profile.horizontal_speed_px_s),
			])
		match profile.reaction:
			HitProfile.Reaction.GROUND_HITSTUN:
				if profile.target_state != HitProfile.TargetState.GROUNDED:
					errors.append("[%s] %s: %s — 矛盾：地面硬直只允许 grounded 目标（当前 %s）" % [
						source, id_label, label, profile.label(),
					])
				if profile.ground_stun_frames < 1:
					errors.append("[%s] %s: %s: ground_stun_frames — 地面硬直为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.ground_stun_frames,
					])
				if not is_equal_approx(profile.upward_speed_px_s, 0.0):
					errors.append("[%s] %s: %s: upward_speed_px_s — 矛盾：普通地面命中必须显式写 0、保持接地（当前 %s；旧 knockback_up 的非零值不能迁移成垂直速度）" % [
						source, id_label, label, str(profile.upward_speed_px_s),
					])
				_reject_foreign_timer(source, id_label, label, profile, "air_untech_frames", profile.air_untech_frames, errors)
				_reject_foreign_timer(source, id_label, label, profile, "knockdown_frames", profile.knockdown_frames, errors)
			HitProfile.Reaction.LAUNCH:
				if profile.air_untech_frames < 1:
					errors.append("[%s] %s: %s: air_untech_frames — 空中受身为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.air_untech_frames,
					])
				if profile.upward_speed_px_s <= 0.0:
					errors.append("[%s] %s: %s: upward_speed_px_s — 矛盾：浮空必须声明大于 0 的垂直初速度（当前 %s）" % [
						source, id_label, label, str(profile.upward_speed_px_s),
					])
				_reject_foreign_timer(source, id_label, label, profile, "ground_stun_frames", profile.ground_stun_frames, errors)
				_reject_foreign_timer(source, id_label, label, profile, "knockdown_frames", profile.knockdown_frames, errors)
			HitProfile.Reaction.GROUND_KNOCKDOWN:
				if profile.target_state != HitProfile.TargetState.GROUNDED:
					errors.append("[%s] %s: %s — 矛盾：普通倒地只允许 grounded 目标（当前 %s）" % [
						source, id_label, label, profile.label(),
					])
				if profile.knockdown_frames < 1:
					errors.append("[%s] %s: %s: knockdown_frames — 倒地计时为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.knockdown_frames,
					])
				if not is_equal_approx(profile.upward_speed_px_s, 0.0):
					errors.append("[%s] %s: %s: upward_speed_px_s — 矛盾：普通倒地必须显式写 0、不离地（当前 %s）" % [
						source, id_label, label, str(profile.upward_speed_px_s),
					])
				_reject_foreign_timer(source, id_label, label, profile, "ground_stun_frames", profile.ground_stun_frames, errors)
				_reject_foreign_timer(source, id_label, label, profile, "air_untech_frames", profile.air_untech_frames, errors)
			HitProfile.Reaction.LOW_FLOAT_SWEEP:
				if profile.target_state != HitProfile.TargetState.GROUNDED:
					errors.append("[%s] %s: %s — 矛盾：低浮空扫倒只允许 grounded 目标（当前 %s；airborne 键缺失即无命中，不回退）" % [
						source, id_label, label, profile.label(),
					])
				if profile.air_untech_frames < 1:
					errors.append("[%s] %s: %s: air_untech_frames — 低浮空受击窗口为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.air_untech_frames,
					])
				if profile.upward_speed_px_s <= 0.0:
					errors.append("[%s] %s: %s: upward_speed_px_s — 矛盾：低浮空必须声明大于 0 的离地速度（当前 %s）" % [
						source, id_label, label, str(profile.upward_speed_px_s),
					])
				if profile.knockdown_frames < 1:
					errors.append("[%s] %s: %s: knockdown_frames — 触地转换后的倒地计时为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.knockdown_frames,
					])
				_reject_foreign_timer(source, id_label, label, profile, "ground_stun_frames", profile.ground_stun_frames, errors)
			HitProfile.Reaction.DOWNWARD_SLAM:
				## 向下击落（票据 04，S-07）：仅 airborne 目标；无空中受击计时——
				## 立即获得向下速度坠落，触地同帧转普通倒地。
				if profile.target_state != HitProfile.TargetState.AIRBORNE:
					errors.append("[%s] %s: %s — 矛盾：向下击落只允许 airborne 目标（当前 %s；grounded 击倒请直接声明 GROUND_KNOCKDOWN）" % [
						source, id_label, label, profile.label(),
					])
				if profile.downward_speed_px_s <= 0.0:
					errors.append("[%s] %s: %s: downward_speed_px_s — 向下击落必须声明大于 0 的向下初速度（当前 %s）" % [
						source, id_label, label, str(profile.downward_speed_px_s),
					])
				if profile.knockdown_frames < 1:
					errors.append("[%s] %s: %s: knockdown_frames — 触地转换后的倒地计时为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.knockdown_frames,
					])
				if profile.upward_speed_px_s != -1.0:
					errors.append("[%s] %s: %s: upward_speed_px_s — 矛盾：向下击落不适用向上初速度，须保持未声明 -1（当前 %s）" % [
						source, id_label, label, str(profile.upward_speed_px_s),
					])
				_reject_foreign_timer(source, id_label, label, profile, "ground_stun_frames", profile.ground_stun_frames, errors)
				_reject_foreign_timer(source, id_label, label, profile, "air_untech_frames", profile.air_untech_frames, errors)
			HitProfile.Reaction.LOW_FLOAT_TO_SLIDE:
				## 击飞触地滑行（票据 05，S-04）：仅 grounded 目标；短暂滞空受击窗口后
				## 触地转 GROUND_SLIDE，不经过普通倒地。
				if profile.target_state != HitProfile.TargetState.GROUNDED:
					errors.append("[%s] %s: %s — 矛盾：击飞触地滑行只允许 grounded 目标（当前 %s；airborne 键请声明独立空中资料，slide 目标缺失资料即无命中）" % [
						source, id_label, label, profile.label(),
					])
				if profile.air_untech_frames < 1:
					errors.append("[%s] %s: %s: air_untech_frames — 击飞受击窗口为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.air_untech_frames,
					])
				if profile.upward_speed_px_s <= 0.0:
					errors.append("[%s] %s: %s: upward_speed_px_s — 矛盾：击飞必须声明大于 0 的垂直初速度（当前 %s）" % [
						source, id_label, label, str(profile.upward_speed_px_s),
					])
				if profile.slide_frames < 1:
					errors.append("[%s] %s: %s: slide_frames — 触地后滑行持续为负、未设置或为 0（当前 %d，须至少 1 帧）" % [
						source, id_label, label, profile.slide_frames,
					])
				_reject_foreign_timer(source, id_label, label, profile, "ground_stun_frames", profile.ground_stun_frames, errors)
				_reject_foreign_timer(source, id_label, label, profile, "knockdown_frames", profile.knockdown_frames, errors)
		if profile.hit_context == HitProfile.HitContext.COUNTER \
				and not owner.has_normal_profile(profile.target_state):
			errors.append("[%s] %s: %s — 矛盾：声明 %s 的 counter 却缺少同状态 normal profile（不得只提供 counter）" % [
				source, id_label, label, _target_state_name(profile.target_state),
			])


## reaction 不适用的计时字段必须保持未声明（-1）：计时与 reaction 不一致属于非法。
static func _reject_foreign_timer(source: String, id_label: String, label: String, profile: HitProfile, field: String, value: int, errors: Array[String]) -> void:
	if value != -1:
		errors.append("[%s] %s: %s: %s — 矛盾：%s 不适用当前 reaction %s，须保持未声明 -1（当前 %d）" % [
			source, id_label, label, field, field, _reaction_name(profile.reaction), value,
		])


static func _target_state_name(target_state: int) -> String:
	match target_state:
		HitProfile.TargetState.GROUNDED:
			return "grounded"
		HitProfile.TargetState.AIRBORNE:
			return "airborne"
		HitProfile.TargetState.GROUND_SLIDE:
			return "slide"
	return "未知目标状态 %d" % target_state


static func _reaction_name(reaction: int) -> String:
	match reaction:
		HitProfile.Reaction.GROUND_HITSTUN:
			return "GROUND_HITSTUN"
		HitProfile.Reaction.LAUNCH:
			return "LAUNCH"
		HitProfile.Reaction.GROUND_KNOCKDOWN:
			return "GROUND_KNOCKDOWN"
		HitProfile.Reaction.LOW_FLOAT_SWEEP:
			return "LOW_FLOAT_SWEEP"
		HitProfile.Reaction.DOWNWARD_SLAM:
			return "DOWNWARD_SLAM"
		HitProfile.Reaction.LOW_FLOAT_TO_SLIDE:
			return "LOW_FLOAT_TO_SLIDE"
	return "未知反应 %d" % reaction



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
		# rekka_only 派生与 charge_only 蓄力版不参与输入选择，不进入并列键
		#（票据 04/06）。
		if typed.is_strike() and typed.action_key != "" and not typed.rekka_only and not typed.charge_only:
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
				["landing_cancel_targets", typed.landing_cancel_targets],
				["chain_cancel_targets", typed.chain_cancel_targets],
				["special_cancel_targets", typed.special_cancel_targets],
				["link_targets", typed.link_targets],
				["special_entry_targets", typed.special_entry_targets],
				["special_entry_link_targets", typed.special_entry_link_targets],
				["air_exit_targets", typed.air_exit_targets],
				["hit_landing_cancel_targets", typed.hit_landing_cancel_targets]]:
			var field: String = pair[0]
			var targets: Array[String] = pair[1]
			for target in targets:
				if not _has_move_id(move_list, target):
					errors.append("[%s] %s: %s — 跨招式非法引用：\"%s\" 不在招式表中" % [
						source, typed.move_id, field, target,
					])
				elif _is_rekka_only_move(move_list, target):
					errors.append("[%s] %s: %s — 跨招式非法引用：\"%s\" 是 rekka_only 派生招式，只能经 Rekka 派生窗口起手" % [
						source, typed.move_id, field, target,
					])
				elif _is_charge_only_move(move_list, target):
					errors.append("[%s] %s: %s — 跨招式非法引用：\"%s\" 是 charge_only 蓄力版，只能经蓄力提交起手" % [
						source, typed.move_id, field, target,
					])
		# 命中落地取消目标（票据 08，L-01）：取消按地面姿态起手，目标必须是地面
		# 招式（与空中出口的镜像约束）。
		for target_id in typed.hit_landing_cancel_targets:
			var landing_target := _find_move(move_list, target_id)
			if landing_target != null and landing_target.stance != MoveData.Stance.GROUND:
				errors.append("[%s] %s: hit_landing_cancel_targets — 矛盾：命中落地取消目标 \"%s\" 不是地面招式（落地后按地面姿态起手，不指向空中目标）" % [
					source, typed.move_id, target_id,
				])
		# 特殊进入目标（票据 05）：与来源同姿态（取消不跨姿态），且目标自身仍按
		# 普通招式结算——资源只声明入口资格，不创建特殊招式身份。
		for target_id in typed.special_entry_targets:
			var entry_target := _find_move(move_list, target_id)
			if entry_target != null and entry_target.stance != typed.stance:
				errors.append("[%s] %s: special_entry_targets — 矛盾：特殊进入目标 \"%s\" 与来源姿态不一致（不跨姿态）" % [
					source, typed.move_id, target_id,
				])
		# 空中出口目标（票据 07）：地面招式的出口目标必须是空中招式（出口只在
		# 本招位移真实离地后开放空中姿态起手）。
		for target_id in typed.air_exit_targets:
			var exit_target := _find_move(move_list, target_id)
			if exit_target != null and exit_target.stance != MoveData.Stance.AIR:
				errors.append("[%s] %s: air_exit_targets — 矛盾：空中出口目标 \"%s\" 不是空中招式（出口按空中姿态起手，不指向地面目标）" % [
					source, typed.move_id, target_id,
				])
		# Rekka 首段目标的存在性、派生限定、分支键与姿态一致性（票据 04）。
		for pair in [["rekka_b_target", typed.rekka_b_target, "B"], ["rekka_c_target", typed.rekka_c_target, "C"]]:
			var field: String = pair[0]
			var target_id: String = pair[1]
			var branch_key: String = pair[2]
			if target_id == "":
				continue
			var target := _find_move(move_list, target_id)
			if target == null:
				errors.append("[%s] %s: %s — 跨招式非法引用：\"%s\" 不在招式表中" % [
					source, typed.move_id, field, target_id,
				])
				continue
			if not target.rekka_only:
				errors.append("[%s] %s: %s — 矛盾：派生目标 \"%s\" 未声明 rekka_only（派生是唯一入口）" % [
					source, typed.move_id, field, target_id,
				])
			if target.action_key != branch_key:
				errors.append("[%s] %s: %s — 矛盾：%s 分支目标 \"%s\" 的输入绑定须为 %s 键（当前 \"%s\"）" % [
					source, typed.move_id, field, branch_key, target_id, branch_key, target.action_key,
				])
			if target.stance != typed.stance:
				errors.append("[%s] %s: %s — 矛盾：派生目标 \"%s\" 与首段姿态不一致（派生不跨姿态）" % [
					source, typed.move_id, field, target_id,
				])
	# 动作内蓄力目标（票据 06，I-01/I-02）：蓄力版存在、限定 charge_only、与普通
	# 版同姿态同输入绑定（同一次动作的两个提交结果）；每个蓄力版恰被一个普通版
	# 引用（孤儿蓄力版属于死数据，整表拒绝）。
	var charge_refs := {}
	for move in move_list:
		var typed := move as MoveData
		var source := typed.resource_path if typed.resource_path != "" else PROGRAMMATIC_SOURCE
		if typed.charge_move_id == "":
			continue
		var target := _find_move(move_list, typed.charge_move_id)
		if target == null:
			errors.append("[%s] %s: charge_move_id — 跨招式非法引用：\"%s\" 不在招式表中" % [
				source, typed.move_id, typed.charge_move_id,
			])
			continue
		if not target.charge_only:
			errors.append("[%s] %s: charge_move_id — 矛盾：蓄力目标 \"%s\" 未声明 charge_only（蓄力提交是唯一入口）" % [
				source, typed.move_id, typed.charge_move_id,
			])
		if target.action_key != typed.action_key:
			errors.append("[%s] %s: charge_move_id — 矛盾：蓄力目标 \"%s\" 的输入绑定须与普通版一致（当前 \"%s\" vs \"%s\"）" % [
				source, typed.move_id, typed.charge_move_id, typed.action_key, target.action_key,
			])
		if target.stance != typed.stance:
			errors.append("[%s] %s: charge_move_id — 矛盾：蓄力目标 \"%s\" 与普通版姿态不一致（蓄力不跨姿态）" % [
				source, typed.move_id, typed.charge_move_id,
			])
		if charge_refs.has(typed.charge_move_id):
			errors.append("[%s] 跨招式冲突: charge_move_id — 蓄力版 \"%s\" 被 %s 与 %s 同时引用（入口必须唯一）" % [
				source, typed.charge_move_id, charge_refs[typed.charge_move_id], typed.move_id,
			])
		else:
			charge_refs[typed.charge_move_id] = typed.move_id
	for move in move_list:
		var typed := move as MoveData
		var source := typed.resource_path if typed.resource_path != "" else PROGRAMMATIC_SOURCE
		if typed.charge_only and not charge_refs.has(typed.move_id):
			errors.append("[%s] %s: charge_only — 矛盾：蓄力版未被任何普通版的 charge_move_id 引用（死数据）" % [
				source, typed.move_id,
			])


static func _has_move_id(move_list: Array, move_id: String) -> bool:
	for move in move_list:
		if (move as MoveData).move_id == move_id:
			return true
	return false


static func _find_move(move_list: Array, move_id: String) -> MoveData:
	for move in move_list:
		if (move as MoveData).move_id == move_id:
			return move
	return null


static func _is_rekka_only_move(move_list: Array, move_id: String) -> bool:
	var move := _find_move(move_list, move_id)
	return move != null and move.rekka_only


static func _is_charge_only_move(move_list: Array, move_id: String) -> bool:
	var move := _find_move(move_list, move_id)
	return move != null and move.charge_only


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
	copy.chain_cancel_targets = move.chain_cancel_targets.duplicate()
	copy.special_cancel_targets = move.special_cancel_targets.duplicate()
	copy.link_targets = move.link_targets.duplicate()
	copy.special_entry_targets = move.special_entry_targets.duplicate()
	copy.special_entry_link_targets = move.special_entry_link_targets.duplicate()
	copy.air_exit_targets = move.air_exit_targets.duplicate()
	copy.hit_landing_cancel_targets = move.hit_landing_cancel_targets.duplicate()
	copy.input_alternatives = move.input_alternatives.duplicate()
	var profiles: Array[HitProfile] = []
	for profile in move.hit_profiles:
		var profile_copy := profile.duplicate() as HitProfile
		profile_copy.resource_path = ""
		profiles.append(profile_copy)
	copy.hit_profiles = profiles
	var segments: Array[MoveSegment] = []
	for segment in move.segments:
		var segment_copy := segment.duplicate() as MoveSegment
		segment_copy.resource_path = ""
		var segment_profiles: Array[HitProfile] = []
		for profile in segment.hit_profiles:
			var profile_copy := profile.duplicate() as HitProfile
			profile_copy.resource_path = ""
			segment_profiles.append(profile_copy)
		segment_copy.hit_profiles = segment_profiles
		segments.append(segment_copy)
	copy.segments = segments
	return copy
