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
	STRIKE = 1,  ## 打击招式：必须声明伤害/属性/命中框/命中结果/受击硬直/击退
	THROW = 2,   ## 普通投：必须声明投距；startup 固定 5f 领域规则，不由资源覆盖
}

## 姿态要求：动作键解析与取消资格都按姿态匹配。
enum Stance {
	UNSET = 0,   ## 未声明（非法）
	GROUND = 1,  ## 地面招式
	AIR = 2,     ## 空中招式
}

## 命中结果类型：决定木桩被命中后进入哪种受击状态。
enum HitResult {
	UNSET = 0,          ## 未声明（打击招式非法）
	GROUND_HITSTUN = 1, ## 地面受击硬直
	LAUNCH = 2,         ## 浮空受击：木桩被打入浮空硬直，滞空期间硬直逐帧消耗
}

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
## 命中后的水平击退速度（px/s，沿攻击方向）。
@export var knockback := -1.0
## 命中木桩在地面时附加的向上击飞速度（px/s）。
@export var knockback_up := -1.0
## 命中给予的受击硬直帧数。
@export var hitstun_frames := -1
## 命中结果类型。
@export var hit_result: HitResult = HitResult.UNSET
## 投距：投技必填（身体中心水平距离上限；垂直方向须身体矩形重叠）。
@export var throw_range := -1.0
## 空中招式显式额外落地恢复帧数（落地恢复基础规则在跳跃 issue 实装；默认 0）。
@export var extra_landing_recovery_frames := 0
## 命中确认取消：本招命中确认后允许取消进入的招式 id 列表。
@export var cancel_targets: Array[String] = []
## 命中确认取消窗口：命中后第 0–N 帧（含两端）内允许取消。
@export var cancel_window_frames := -1
## 收尾招式：命中后结束当前连段路线；不主动清除木桩的受击/倒地处理。
@export var is_finisher := false
## jump cancel 配置：命中确认后的取消窗口内允许 Space 取消起跳转入空中追击的
## 空中起手招式 id 列表（如 ["jA"]）；空列表表示本招不支持 jump cancel。
## 起跳不结束连段；落地仍未接续空中起手时追击资格作废。
@export var jump_cancel_targets: Array[String] = []
## 落地接续配置：空中招式命中确认后，在取消窗口内的落地帧允许接续的地面招式
## id 列表（如 jB 的 ["5D"]）。落地接续是空中 → 地面的唯一合法接缝；
## 落地本身不授予任何普通取消资格。空列表表示本招不支持落地接续。
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
