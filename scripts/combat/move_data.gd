class_name MoveData
extends Resource
## 招式数据：描述一招的全部可配置结算参数（类型化本地资源，issue 11 起由
## data/moves/*.tres 承载、data/move_manifest.tres 统一引用）。
## 运行时战斗逻辑与 Combo Solver 只读这份配置；调整帧数/伤害不需要改 CombatSession。
## 核心字段缺省值一律是“未声明”哨兵（0/-1/UNSET）：MoveTable 校验时缺字段即拒绝，
## 不静默修正，也不回退旧 GameParams 数值。

## 招式类别：打击招式与普通投。普通投自 issue 17 起实装（B+C 组合输入），
## 投结果参数（硬直/击退）是 GameParams 领域规则，不由资源表达。
enum MoveKind {
	UNSET = 0,   ## 未声明（非法）
	STRIKE = 1,  ## 打击招式：必须声明伤害/属性/命中框/至少一个合法 HitProfile
	THROW = 2,   ## 普通投：必须声明投距；startup 固定 5f 领域规则，不由资源覆盖
}

## 姿态要求：动作键解析与取消资格都按姿态匹配。
enum Stance {
	UNSET = 0,   ## 未声明（非法）
	GROUND = 1,  ## 地面招式
	AIR = 2,     ## 空中招式
}

## 命中结果不再由招式级单一字段表达（ADR-0003）：reaction、计时与击退全部
## 内嵌在 hit_profiles 的每个 HitProfile 中，按 (target_state, hit_context)
## 精确选择；不存在旧 hit_result/hitstun_frames/knockback 字段或回退。

## 蹲姿限定（票据 02）：仅当输入帧的方向数字 ∈ {1,2,3}（下方向按住，斜下含）
## 时才是单键候选；按住下持续再按键不需要方向历史重新建段。与 5X 站立变体
## 同键共存时靠 priority 分层（同层同优先级仍属非法并列）。仅地面招式可声明。
@export var requires_crouch := false

## 攻击属性（防御姿态判定用；air 是与之正交的独立标记，见 air_attack）。
enum AttackAttribute {
	UNSET = 0,    ## 未声明（打击招式非法）
	HIGH = 1,     ## 高位（站立可防）
	MID = 2,      ## 中段
	LOW = 3,      ## 下段（蹲防）
	OVERHEAD = 4, ## 蹲防不可、站防可
}

## 指令层级：同一动作键事件同时命中多招时的确定性选择顺序，
## 超必杀 > 普通必杀 > 普通拳脚，同层再按 priority。
enum CommandTier {
	NORMAL = 0,  ## 普通拳脚（无方向指令）
	SPECIAL = 1, ## 普通必杀（单组方向指令）
	SUPER = 2,   ## 超必杀（多段指令 / 显式替代串）
}

## 起手等级（C-01）：首次实际 HIT 锁定本招声明的等级，决定连段三层修正的
## starter 倍率与后续有限继续资格；被防、挥空不锁定。未声明属于非法数据，
## 不按动作键猜测。
enum StarterGrade {
	UNSET = 0, ## 未声明（打击招式非法）
	A = 1,     ## 轻起手：三层修正最差，弹地后不能继续
	B = 2,
	C = 3,
	D = 4,     ## 重起手：修正最好
}

## 稳定 id：资源身份，不由文件名推断；manifest 与运行时/Solver 都以它引用招式。
@export var move_id := ""
## 招式类别（打击/普通投）。
@export var move_kind: MoveKind = MoveKind.UNSET
## 姿态要求。
@export var stance: Stance = Stance.UNSET
## 输入绑定：动作键 A/B/C/D。普通投是 B+C 组合输入，不声明单键绑定。
@export var action_key := ""
## 前摇帧数：出招到判定出现之前。
@export var startup_frames := -1
## 判定帧数：命中框生效、允许命中的窗口。
@export var active_frames := -1
## 后摇帧数：判定结束后回到中立之前。
@export var recovery_frames := -1
## 基础伤害（实际伤害按连段命中数递减，在会话结算中计算）。
@export var base_damage := -1
## 攻击属性（high/mid/low/overhead）。
@export var attack_attribute: AttackAttribute = AttackAttribute.UNSET
## 正交 air 类别：标记空中攻击/攻击判定。地面招式能命中空中目标不因此获得 air。
@export var air_attack := false
## 命中框尺寸（以角色中心为原点）。
@export var hitbox_size := Vector2.ZERO
## 命中框与身体前缘的间隙。
@export var hitbox_gap := -1.0
## 内嵌上下文命中资料：唯一键 (target_state, hit_context)，打击招式至少一个
## 合法 profile；投技不得声明。命中结果、计时与速度全部从这里读取。
@export var hit_profiles: Array[HitProfile] = []
## 投距：投技必填（身体中心水平距离上限；垂直方向须身体矩形重叠）。
@export var throw_range := -1.0
## 空中招式显式额外落地恢复帧数（落地恢复基础规则在跳跃 issue 实装；默认 0）。
@export var extra_landing_recovery_frames := 0
## 命中确认取消：本招命中确认后允许取消进入的招式 id 列表。
@export var cancel_targets: Array[String] = []
## 命中确认取消窗口：命中后第 0–N 帧（含两端）内允许取消。
@export var cancel_window_frames := -1
## 链式取消：命中或被防接触后允许取消进入的普通技 id 列表（独立于命中确认窗口；
## 挥空无接触不开放）。声明目标时必须同时声明窗口；空列表必须保持窗口未声明。
@export var chain_cancel_targets: Array[String] = []
## 链式取消窗口：接触帧起第 0–N 帧（含两端，正常帧计龄，Hitstop 不计）。
@export var chain_cancel_window_frames := -1
## 必杀取消：命中或被防接触后允许取消进入的必杀技 id 列表（独立窗口）。
@export var special_cancel_targets: Array[String] = []
## 必杀取消窗口：接触帧起第 0–N 帧（含两端）。
@export var special_cancel_window_frames := -1
## 普通连接（目押）边：不在取消目标内——前招完全恢复后的首个合法帧按缓存消费、
## 目标剩余硬直、距离与 active 重叠重新判定（I-06）。每条路线须显式声明。
@export var link_targets: Array[String] = []
## 起手等级：首次实际 HIT 锁定；打击招式必须显式声明，未声明整表拒绝。
@export var starter_grade: StarterGrade = StarterGrade.UNSET
## 被防结果（票据 03，D-02/D-03）：被防是独立于命中资料的接触结果，三项逐招显式
## 声明；未声明（哨兵）= 本招不可被防——默认禁止，不回退全局参数。投技不得声明。
@export var block_freeze_frames := -1   ## 被防停顿：双方动作/运动冻结的物理帧数（允许 0）。
@export var block_stun_frames := -1     ## 被防硬直：防守方停顿结束后不可行动的正常帧数。
@export var block_pushback_px_s := -1.0 ## 被防推退：停顿结束后施加给双方的水平速度（px/s）。
## 收尾招式：命中后结束当前连段路线；不主动清除木桩的受击/倒地处理。
@export var is_finisher := false
## jump cancel 配置：命中确认后的取消窗口内允许 Space 取消起跳转入空中追击的
## 空中起手招式 id 列表（如 ["jA"]）；空列表表示本招不支持 jump cancel。
## 起跳不结束连段；落地仍未接续空中起手时追击资格作废。
@export var jump_cancel_targets: Array[String] = []
## 历史落地接续目标（保留资源兼容和 Solver 排除诊断，如 jB 的 ["5D"]）。
## 最新规则禁止落地首帧及空技恢复期间取消；声明此字段不能绕过恢复锁。
## 恢复后的普通连接尚未纳入 Solver 搜索，不能由此字段推断为合法连段。
@export var landing_cancel_targets: Array[String] = []
## 方向派生记法："236C" 表示方向序列 236 + 动作键 C；空串为无方向要求的普通招式。
## 按下动作键时按指令规则匹配方向历史；识别成功即消费终点及之前的全部历史。
@export var direction_derivation := ""
## 宽松指令：方向段按轴谓词集合匹配（前 {3,6,9}、后 {1,4,7}、下 {1,2,3}、上 {7,8,9}），
## 段间允许额外方向段，首个满足终点谓词的段锁定终点；默认严格——每段精确等于
## 记法数字且终点必须是最后一个方向段。宽松/严格由招式规则声明，不按记法猜测。
@export var lenient_command := false
## 显式输入替代串（如超必杀的 "23626D"）：只按声明生效，不由普通指令自动推导。
## 每个替代串是一个独立 variant，输入窗口按其实际步数计。
@export var input_alternatives: Array[String] = []
## 指令层级：同键同帧多招命中时先于 priority 的确定性选择顺序（超必杀 > 普通必杀
## > 普通拳脚）；同层再按 priority。同绑定同层级同优先级并列属于非法数据。
@export var command_tier: CommandTier = CommandTier.NORMAL
## 同层并列时的选择顺序：数值大者优先；同绑定同优先级的并列属于非法数据。
@export var priority := -1


## 普通投的显式组合成员键（领域规则：B+C；投技资源不声明单键绑定）。
## 会话与 Solver 的组合配对、组合等待判成员都以此为唯一来源。
const THROW_COMBINATION_KEYS := ["B", "C"]


## 是否投组合（B+C）的成员键。
static func is_throw_combination_member(key: String) -> bool:
	return THROW_COMBINATION_KEYS.has(key)


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


## 按 (target_state, hit_context) 精确查找命中资料（运行时与 Combo Solver 共用的
## 唯一选择口径）：任一维度没有完全相等的 profile 即返回 null——不回退 NORMAL、
## 不回退 GROUNDED、不按数组顺序猜测。
static func profile_for(move: MoveData, target_state: HitProfile.TargetState, hit_context: HitProfile.HitContext) -> HitProfile:
	if move == null:
		return null
	for profile in move.hit_profiles:
		if profile.target_state == target_state and profile.hit_context == hit_context:
			return profile
	return null


## 本招是否声明了某个目标状态的 NORMAL profile（Counter 无 normal 属于非法数据，
## MoveTable 校验用）。
func has_normal_profile(target_state: HitProfile.TargetState) -> bool:
	return profile_for(self, target_state, HitProfile.HitContext.NORMAL) != null


## 是否打击招式（校验、单键选择与取消链解析都以此排除投技——投技由
## CombatSession 的 B+C 显式组合解析，不占单键缓存）。
func is_strike() -> bool:
	return move_kind == MoveKind.STRIKE


## 是否投技。
func is_throw() -> bool:
	return move_kind == MoveKind.THROW


func active_from() -> int:
	return startup_frames


func active_to() -> int:
	## 判定窗口最后一帧的编号（含）。
	return startup_frames + active_frames - 1


## 命中框中心相对角色中心的偏移（乘以 facing 得到世界方向）。
func hitbox_offset() -> float:
	return GameParams.BODY_SIZE.x * 0.5 + hitbox_gap + hitbox_size.x * 0.5


## 诊断用属性标签：high/mid/low/overhead，正交 air 以 "+air" 叠加；未声明为 "—"。
func attribute_label() -> String:
	if move_kind == MoveKind.THROW:
		return "投"
	var label := "—"
	match attack_attribute:
		AttackAttribute.HIGH:
			label = "high"
		AttackAttribute.MID:
			label = "mid"
		AttackAttribute.LOW:
			label = "low"
		AttackAttribute.OVERHEAD:
			label = "overhead"
	if air_attack:
		label += "+air"
	return label


## 兼容入口：默认招式表 = 共享 manifest 加载的已校验数据（不再是代码内建的
## GameParams 表）。每次调用返回独立副本，调用方可安全修改用于注入实验。
static func default_table() -> Dictionary:
	var result := MoveTable.load_default()
	if not result.ok:
		push_error("共享招式表校验失败：" + result.first_error())
		return {}
	return result.moves
