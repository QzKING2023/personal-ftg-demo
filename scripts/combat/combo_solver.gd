class_name ComboSolver
extends RefCounted
## 开发期 Combo Solver：地面与空中接续验证、有限资源区分与循环报告（旧 ftg-combo issue 06 + 07）。
## 正式入口是 solve()（ftg-combat-foundation issue 19）：接受共享招式表、可选显式起始
## 战斗状态与搜索选项，默认左右面向分别验证并镜像对拍，输出稳定排序的候选、起始
## 状态说明与真实键位操作说明；analyze()/analyze_manifest() 保留为旧接口（表序枚举）。
## 只读招式数据，用一次性 CombatSession 探针得出与运行时一致的接续结论——
## 前摇、等待时间、取消窗口、木桩硬直、地面/空中姿态、方向派生、jump cancel 与
## 落地接缝都在真实结算中检验，不在 Solver 里复刻第二套帧物理。
## 约束：不修改任何运行时战斗状态（所有探针使用私有会话，与训练场会话无关）；
## 不设全局命中数或总时长上限——循环以「逐圈模拟 + 影响未来结算的会话状态快照
## 重现」证明（issue 21：状态键经 CombatSession.settlement_state 覆盖双方姿态/
## 阶段、招式帧、面向、速度、受击、连段资格、缓存、方向历史、落地与 jump 标记）。
## 只有快照完全重现的回边才上报为循环；观测上限内不断链但未重现的回边以
## 截断/未完成观测如实上报，不宣称完整证明。
## 有限资源不被视为可自动续期：玩家滞空固定且空中无二段跳，木桩浮空不被普通命中
## 刷新——只有每圈由真实命中重建资源的回边才能通过逐圈模拟。
## 几何接触是假设不是证明：探针把木桩钉在玩家面前（面向侧），不证明空间/中立/
## 碰撞连接；空中段只能经配置的 jump cancel 进入，普通跳跃/中立空中起手不在证明范围。
## 空间分层（issue 22）：无空间数据时全部路线仅 timing-valid；调用方经
## SolverOptions.spatial 提供站位与碰撞几何后，空间探针才在地面、左右镜像的
## 48/64/80 px 三组身体中心水平距离上逐条复验 timing-valid 路线并附
## spatial-valid——相交判定复用真实结算，不搜索走位、中立、墙角、推挤、跨身
## 或屏幕边界；配置缺口与时序失败不作空间失败上报。

## 探针站位：玩家中心与木桩中心的横向间距（命中框中段，面向侧，几何接触假设）。
const PIN_DX := 70.0
## 空间探针的固定站位网格（issue 22，规格冻结）：地面、左右镜像的三组身体
## 中心水平距离。48 = 身体贴身（BODY_SIZE.x）、64 = 首版投距上限、80 = 更远
## 一档；不搜索其余站位——走位、中立、墙角、推挤、跨身、屏幕边界都不在
## 证明范围。
const SPATIAL_PROBE_DISTANCES := [48.0, 64.0, 80.0]
## 动作键 → 物理键（操作说明用）：与训练场 main.gd 的 ACTION_PHYSICAL_KEYS 及
## project.godot 输入映射保持一致（tests/test_solver_entry.gd 断言两处不漂移）。
const ACTION_PHYSICAL_KEYS := {"A": "U", "B": "I", "C": "K", "D": "J"}
## 镜像对拍失败时报告的差异节名（issue 19；配置缺口随接续边一并对拍）。
const _SECTION_LABELS := {"edges": "接续边", "gaps": "配置缺口", "routes": "路线", "cycles": "循环"}
## 接续种类 → 缺口涉及的配置字段与接缝名（探针注入与缺口文案共用，防两处漂移）。
const _GAP_CONFIG_FIELDS := {
	EdgeKind.CANCEL: {"field": "cancel_targets", "seam": "命中确认取消"},
	EdgeKind.CHAIN_CANCEL: {"field": "chain_cancel_targets", "seam": "链式取消"},
	EdgeKind.SPECIAL_CANCEL: {"field": "special_cancel_targets", "seam": "必杀取消"},
	EdgeKind.JUMP_CANCEL: {"field": "jump_cancel_targets", "seam": "jump cancel"},
	EdgeKind.LANDING_CANCEL: {"field": "landing_cancel_targets", "seam": "落地接续"},
	EdgeKind.NORMAL_LINK: {"field": "link_targets", "seam": "普通连接"},
	EdgeKind.SPECIAL_ENTRY: {"field": "special_entry_targets", "seam": "特殊进入（来源资格）"},
	EdgeKind.SPECIAL_ENTRY_LINK: {"field": "special_entry_link_targets", "seam": "来源限定普通连接"},
	EdgeKind.AIR_EXIT: {"field": "air_exit_targets", "seam": "空中出口"},
	EdgeKind.HIT_LANDING_CANCEL: {"field": "hit_landing_cancel_targets", "seam": "命中落地取消（L-01 例外）"},
}
## 逐圈模拟的观测上限（圈数/帧数）。达到上限时以截断/未完成观测上报，不把它
## 当作完整证明（issue 21）；上限只限制观测，不是连段语义的一部分。
const MAX_CYCLE_LAPS := 8
const MAX_CYCLE_FRAMES := 2400
## 单招探针观测木桩恢复的帧数上限（自命中帧起算）：上限内未自然受身时，恢复
## 年龄按截断观测标注，不伪装成实测恢复。
const RECOVER_HORIZON := 240
## 可读路线的节点上限（票据 05）：路线图按简单路径枚举，来源限定回边使长路径
## 组合膨胀；超过 8 招的路线不枚举也不模拟——不属于本报告的可读路线范围。
const MAX_ROUTE_NODES := 8
## 路线模式延迟搜索的向量观测上限（票据 05）：成功路线仍按字典序首个完整成立
## 向量返回；全部失败的路线在 64 个向量后按走得最远的失败上报（确定性截断，
## 与圈数/帧数上限同一「观测上限而非语义」口径）。循环证明模式不受此限。
const MAX_ROUTE_DELAY_TRIALS := 64
## 空中段首按延迟（相对起跳后第 1 帧）的扫描上限。规格冻结为 40 帧（issue 21）；
## 它不低于玩家滞空（38 帧），超过滞空的延迟在真实结算中必然因落地作废——
## 上限不会截掉任何可行延迟，枚举是完备的。
const MAX_AIR_DELAY := 40

## 完整结果缓存只存在当前进程的 Engine metadata 中。缓存值是报告值快照，
## 不暴露任何 Solver/CombatSession/Resource/compiled 对象；命中时逐字段重建。
const _RESULT_CACHE_META_KEY := "ftg_demo_combo_solver_result_cache_v1"
const _REQUEST_SCHEMA_VERSION := 1
const _REPORT_SNAPSHOT_VERSION := 1
const _RESULT_CACHE_SEMANTICS_VERSION := "combo-solver-complete-result-v1"
const _MOVE_VALUE_FIELDS := [
	"move_id", "move_kind", "stance", "action_key", "requires_crouch", "startup_frames",
	"active_frames", "recovery_frames", "base_damage", "attack_attribute", "air_attack",
	"hitbox_size", "hitbox_gap", "hit_profiles", "throw_range", "extra_landing_recovery_frames",
	"cancel_targets", "cancel_window_frames", "chain_cancel_targets", "chain_cancel_window_frames",
	"special_cancel_targets", "special_cancel_window_frames", "link_targets", "segments",
	"special_entry_targets", "special_entry_window_frames", "special_entry_link_targets",
	"rekka_window_frames", "rekka_b_target", "rekka_c_target", "rekka_only", "starter_grade",
	"block_freeze_frames", "block_stun_frames", "block_pushback_px_s", "is_finisher",
	"jump_cancel_targets", "landing_cancel_targets", "direction_derivation", "lenient_command",
	"input_alternatives", "command_tier", "priority",
	"motion_x_px", "motion_y_px", "charge_threshold_frames", "charge_move_id", "charge_only",
	"air_exit_targets", "hitbox_y_offset_px",
	"hit_landing_cancel_targets", "hit_landing_cancel_window_frames",
]
const _SEGMENT_VALUE_FIELDS := ["startup_frames", "active_frames", "base_damage", "hitbox_size", "hitbox_gap", "hit_profiles"]
const _PROFILE_VALUE_FIELDS := [
	"target_state", "hit_context", "reaction", "damage_override", "ground_stun_frames",
	"air_untech_frames", "knockdown_frames", "horizontal_speed_px_s", "upward_speed_px_s",
	"downward_speed_px_s", "slide_frames",
]

const SCOPE_TEXT := "证明范围：仅覆盖招式表配置的确定性接续——命中确认取消、链式/必杀取消（接触开放，命中或被防）、jump cancel、显式落地接缝、恢复后的普通连接（目押）与 Rekka 派生（票据 04：首段命中或被防接触起的派生窗口内首个 B/C 新按下立即锁分支 branch-locked，同帧 B+C 固定 ~C 优先、不进入普通投组合等待；派生招式 rekka_only、不参与单键/指令输入选择；派生地空命中资料按 (target_state, hit_context) 精确选择，~C 空中向下击落触地转普通倒地）：前摇、等待时间、取消窗口、木桩硬直、地面/空中姿态、方向派生与落地接缝都在真实 CombatSession 结算中检验；命中资料与运行时共享同一 (target_state, hit_context) 精确选择：探针木桩不自攻，命中的上下文恒为 normal，缺失目标状态资料的连接按 MISS_NO_PROFILE 断链上报（不回退 grounded/normal 资料），普通倒地期间不可追击；cancel_targets、chain/special_cancel_targets、link_targets、jump_cancel_targets、rekka_b/c_target 与落地接续目标是运行时硬约束：时序成立但缺少配置的候选只报告为配置缺口，不宣布为合法连段；普通连接边与取消边以不同类型分别报告，连接成立与否由前招完全恢复当帧的缓存消费、目标剩余硬直与 active 重叠重新判定；不证明任意空间、中立或碰撞连接（探针把木桩钉在玩家面前，几何接触是假设）；空中段只能经配置的 jump cancel 进入，普通跳跃/中立空中起手不在证明范围；玩家滞空与木桩浮空是有限资源（空中无二段跳；木桩浮空只由真实命中按所选 profile 的受身计时与速度重建，空中追击的每次命中都应用其 airborne profile），无命中的时间不会自动续期；OTG、地弹、墙反弹与招式无敌不在本轮支持范围，表达这些能力的字段或标签由 MoveTable 整表拒绝；循环判定不设全局命中数或总时长上限，以逐圈模拟加影响未来结算的会话状态快照重现证明（快照键含双方姿态/阶段、招式帧、面向、速度、受击、连段资格、起手等级与三层累计修正、Rekka 分支锁定、缓存、方向历史、落地与 jump 标记，纯调试帧号与纯报告计数不入键）；安全上限：8 圈、每循环 2400 帧、240 帧恢复观测与 40 帧空中延迟——达到上限的观测以截断/未完成观测上报，不宣称完整证明。可读路线按不超过 8 招的简单路径枚举；路线延迟搜索至多验证 64 个延迟向量，全部失败的路线按走得最远的失败如实上报（观测上限而非连段语义，循环证明不受此限）。空间分层：无空间数据时全部路线仅 timing-valid，固定接触位不构成空间证明；提供空间数据（SolverOptions.spatial）后另附 spatial-valid，且只在地面、左右镜像的 48/64/80 px 三组身体中心水平距离上复验，不搜索走位、中立、墙角、推挤、跨身或屏幕边界，配置缺口与时序失败不作空间失败上报。被防分层（票据 03）：链式/必杀边附「被防路径」标注——同一配置边在来源招式被木桩站防/蹲防挡下的探针中验证取消时序；被防是独立接触结果（BLOCKED 不产生命中、不入路线/循环图、不借命中确认或 jump cancel），探针中预期命中帧收到被防结果一律按 blocked 断链上报；Rekka 派生边同样附被防路径标注（首段被防也开放派生窗口），派生自身的被防结果如实入注；被防安全性（指定反击、时机、距离、版边、面向）不在静态证明范围，一律 replay-required；派生首按锁定输入手感与 ~B 交回回合的安全性也属 replay-required，静态报告不下结论。票据 05 扩展：236C 为两段判定（段 1 被防终止整招、挥空续段 2，多段命中按段逐一预测与复验），段 2 命中 grounded 目标进入击飞触地 GROUND_SLIDE（滑行状态、slide 目标资料门、slide 命中分层倍率与状态键均由真实结算承载）；实际 HIT 授予一次性特殊进入资格（SPECIAL_ENTRY 边：仅命中开放、被防不开放，资格在授予招式窗口内消费），经资格起手且实际命中的 D 取得来源限定普通连接（SPECIAL_ENTRY_LINK 边：普通来源同招不取得）；固定钉位网格（48/64/80 px）上段 1 总是先命中，不产生 slide——slide 捞起距离、段间真实可达性（段 1 挥空需 >91px）与 D 后 5B 的真实空间可行性一律 replay-required，静态报告不冒充。报告帧号与年龄按正常战斗帧计：命中后的 Hitstop 冻结物理帧不消耗窗口，回放时以空输入跳过（issue 14）。票据 06 扩展：D 系计划位移由资源声明（motion_x/y_px），active 帧按累计比例推进、命中框沿本帧轨迹做确定性扫掠覆盖（轴对齐包络，无细分采样误差），正式位置经版边与身体约束后在运动阶段提交；动作内蓄力（charge_threshold_frames）在目标声明蓄力的接缝上另验证蓄力变体边（CHARGED：按下后按住至阈值自动提交 charge_only 目标，与普通提交共用同一起手时序与换边规则）；实际 HIT 才开放本次位移对身体的目标穿越（被防/挥空/墙截断截在原侧），只有实际终点合法越过另一侧才换边，命中当帧按锁定动作方向结算攻击与击退，下一物理帧起面向按真实横向关系更新，已开始的 214/236 方向候选锁定首次相对面向不被重解释；循环状态键自票据 06 起纳入双方横向位置、动作方向、蓄力年龄与穿越许可（位移使横向几何成为真实结算量）；固定钉位网格上的蓄力边结论仍是 timing/spatial 假设下的验证——真实穿越、墙边截断、版边与双面向换边及换边后镜像继续输入一律 replay-required，静态报告不冒充空间证明。票据 07 扩展：6A 是唯一专用地面击飞入口，jump cancel 开放 jA/jB/jC（命中确认窗口内 Space 起跳、真实 pre-jump 与滞空，落地未接续即作废）；6D/2D 为对空限定地面招式——无 grounded 资料（对地一律 MISS_NO_PROFILE，不回退），计划位移使攻击者 active 帧真实离地（姿态转换非瞬移），实际 HIT 后经 AIR_EXIT 边在命中确认窗口内按空中姿态起手 jA/jB/jC（被防/挥空不开放；空中出口按键在停顿中按已离地姿态采样）；hitbox_y_offset_px 表达真实垂直判定范围（2D 高位拦截框对低浮空目标垂直不重叠即挥空）；对空限定前招的命中依赖浮空目标——AIR_EXIT 边的钉位探针经使前招实际命中的接续上下文验证（如 2C 链式进入 6D 打低浮空），固定站位 spatial-valid 不等于真实空中距离证明；出口后的滞空仍按物理回落（无二段跳、切招不续期），6D 穿越与 2D 垂直判定的真实空间结论一律 replay-required。票据 08 扩展：空中 D 系（j5D 水平收束、j6D 斜下速降、j2D 垂直带落地）入表并接通 jA/jB/jC 取消与 6D/2D 空中出口；空技声明的 link_targets 经 NORMAL_LINK 边按「落地恢复完成后首个合法帧消费」的延迟模型验证（起手帧由真实落地结算锚定，探针以尾部发现运行放行预期外命中并记录帧号——与地面普通连接同为目押语义，不借用落地首帧例外）；j2D 实际 HIT 授予的一次性 J2D_LANDING_214C 资格由 HIT_LANDING_CANCEL 边单独表达（区别于普通连接）：目标输入可在 Hitstop 中缓存（专用槽、正常帧计龄、资源声明窗口），落地首帧统一锁保持，落地事件后的首个可行动帧消费并清除资格——例外仅对声明目标开放、跳过其余空技恢复，挥空/被防/缺失 profile/命中前预存输入一律不适用（负例在运行时按规则拒绝）；j2D 落地节拍与地空目标差异、j6D 连接的真实距离与三招的视觉/碰撞对齐属 replay-required，静态钉位结论不冒充空间证明。"

## 接续边类型：命中确认取消 / 链式取消 / 必杀取消 / jump cancel / 显式落地接续 /
## 普通连接（目押）。链式与必杀按接触开放（命中或被防），命中确认、jump cancel
## 与普通连接只在实际 HIT 成立；普通连接与取消是不同类型——前招完全恢复后的
## 首个合法帧消费缓存，目标剩余硬直、距离与 active 重叠重新判定（I-06）。
enum EdgeKind {
	CANCEL,          ## cancel_targets：同姿态命中确认取消（地面→地面、空中→空中）
	CHAIN_CANCEL,    ## chain_cancel_targets：接触后链式取消进普通技（独立窗口）
	SPECIAL_CANCEL,  ## special_cancel_targets：接触后必杀取消（独立窗口）
	JUMP_CANCEL,     ## jump_cancel_targets：地面招式命中确认后 Space 起跳接空中起手
	LANDING_CANCEL,  ## landing_cancel_targets：空中招式命中确认后，取消窗口内的落地帧接地面招式
	NORMAL_LINK,     ## link_targets：前招完全恢复后按缓存消费的普通连接（目押）
	REKKA_DERIVE,    ## rekka_b/c_target：首段命中或被防接触起的派生窗口内首个 B/C 新按下锁分支起手（票据 04）
	SPECIAL_ENTRY,   ## special_entry_targets：实际 HIT 授予的一次性来源资格在其窗口内取消进入（票据 05，仅命中开放，被防不开放）
	SPECIAL_ENTRY_LINK, ## special_entry_link_targets：仅经来源资格起手且实际命中的招式开放的普通连接（票据 05，来源限定目押）
	AIR_EXIT,        ## air_exit_targets：地面招式实际 HIT 且本招计划位移真实离地后，命中确认窗口内按空中姿态起手（票据 07，仅命中开放）
	HIT_LANDING_CANCEL, ## hit_landing_cancel_targets：空招实际 HIT 授予的一次性专用资格，落地事件确认后的首个可行动帧消费（票据 08，L-01，仅命中开放、仅限声明目标）
}


## 输入表中的一条按帧输入（方向喂入、Space、动作键可共存于同一帧）。
class ScheduledInput extends RefCounted:
	var frame := 0
	var axis := 0
	var down := false
	var jump := false
	var key := ""
	## 持有不重按的动作键（票据 06 蓄力）：不产生新按下事件，只进入按住集合——
	## 蓄力年龄按住帧累计，重按会刷新单键缓存反而干扰消费。
	var held_key := ""

	func to_frame_input() -> FrameInput:
		var input := FrameInput.make(axis, jump, key, down)
		if held_key != "":
			var held: Array[String] = [held_key]
			if key != "" and key != held_key:
				held.append(key)
			input.held_action_keys = held
		return input


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
	## Rekka 派生按键（票据 04）：按下调起派生（无组合等待），按下当帧即 F1；
	## 普通取消按键的 B/C 组合等待 +3 模型不适用。
	var rekka := false
	## 蓄力版目标（票据 06）：目标为 charge_only 时唯一入口是按住动作键至
	## 阈值自动提交——编译时按下帧后持续按住（不重按），预期命中按有效前摇
	##（max(前摇-1, 阈值)+1）推算。
	var charged := false
	## 来源限定连接的入口描述（票据 05）：该链经何种起手进入（solo 起手或规范
	## 取消入口）——仅用于报告文案，不参与编译。
	var via_text := ""


## 落地接缝搜索定位：来源空中招式在接续链中的进入位置与命中序号
## （正式边的全网格搜索与缺口模式的对齐搜索共用）。
class LandingSeam extends RefCounted:
	## 来源招式的接续链上下文（到达该招的完整输入链）。
	var context: Array[ChainLink] = []
	## 首个空中起手链（JUMP_FRAME）的下标——空中段从这里开始。
	var followup_idx := 0
	## 来源招式进入链的下标：经空中取消进入（PREV_HIT），或经 jump cancel 直接
	## 进入（JUMP_FRAME——与空中起手链同一条，对齐只调起手延迟一维）。
	var from_link_idx := 0
	var from_is_jump_entry := false
	## 来源招式命中在预期命中表中的序号（Space 链接不产生命中，按有招式的链接计数）。
	var from_hit_idx := 0


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
	## 240 帧恢复观测上限内未自然受身时为截断值，recover_truncated 置位。
	var recover_age := -1
	## 恢复年龄是否为截断观测（上限内未观测到自然受身，非实测恢复）。
	var recover_truncated := false
	## 落地接续专用：空中命中允许落在落地帧前 align_from–align_to 帧
	## （align_from = 0 即命中恰在落地帧当帧——临界帧规则）。
	var align_from := -1
	var align_to := -1
	## 落地接续专用：最晚对齐档（命中恰在落地帧或最接近）的完整输入表，供与运行时对拍。
	var align_inputs: Array[ScheduledInput] = []
	## 被防接触变体（票据 03）：同一链式/必杀配置边在「来源被木桩防御挡下」探针
	## 中的取消时序验证。被防不是 HIT——该变体只作标注，不进入路线/循环图。
	var blocked_valid := false
	var blocked_reason := ""
	## 蓄力变体（票据 06）：目标声明蓄力的边除普通提交外另验证按住至阈值的
	## 蓄力版提交（to = charge_move_id 指向的 charge_only 招式）。
	var charged := false

	func label() -> String:
		return "%s → %s%s" % [from_id, to_id, "（蓄力）" if charged else ""]

	func kind_text() -> String:
		match kind:
			EdgeKind.JUMP_CANCEL:
				return "jump cancel"
			EdgeKind.LANDING_CANCEL:
				return "落地接续"
			EdgeKind.CHAIN_CANCEL:
				return "链式取消"
			EdgeKind.SPECIAL_CANCEL:
				return "必杀取消"
			EdgeKind.NORMAL_LINK:
				return "普通连接"
			EdgeKind.REKKA_DERIVE:
				return "Rekka 派生"
			EdgeKind.SPECIAL_ENTRY:
				return "特殊进入"
			EdgeKind.SPECIAL_ENTRY_LINK:
				return "来源限定连接"
			EdgeKind.AIR_EXIT:
				return "空中出口"
			EdgeKind.HIT_LANDING_CANCEL:
				return "命中落地取消"
		return "取消"


## 一条经逐帧模拟验证的可读路线（合法接续链，含命中帧、伤害与完整输入表）。
class SolverRoute extends RefCounted:
	## 空间分层三态（issue 22）：UNVERIFIED＝未提供空间数据，或时序未成立
	## （时序失败不作空间复验，不标空间失败）；VALID＝全部验证面向 ×
	## 48/64/80 px 站位复验成立；INVALID＝至少一组站位复验失败。
	enum SpatialState { UNVERIFIED, VALID, INVALID }

	var move_ids: Array[String] = []
	var hit_frames: Array[int] = []
	var combo_hits := 0
	var total_damage := 0.0
	var note := ""
	## timing 层结论：接续链在固定探针接触位的真实结算中逐帧成立。
	var timing_valid := false
	var spatial_state: SpatialState = SpatialState.UNVERIFIED
	## INVALID 时的具体失败（每组失败站位一条，如「80 px：……」）；面向镜像
	## 由 solve() 的签名对拍保证，失败按站位去重合并，不按面向重复罗列。
	var spatial_failures: Array[String] = []
	## 本路线的逐帧输入表（含方向喂入、Space 与落地帧按键），回放到全新
	## CombatSession 应逐帧复现 hit_frames / combo_hits / total_damage。
	var inputs: Array[ScheduledInput] = []

	func label() -> String:
		return " → ".join(move_ids)


## 一个经逐圈模拟验证的循环（issue 21：快照完全重现才上报为循环）。
## 结局分类用枚举表达，不依赖 reason 措辞字符串（注记归类与汇总计数都读它）。
class SolverCycle extends RefCounted:
	enum Outcome { PROVEN, BROKEN, HORIZON_TRUNCATED, LAPS_EXHAUSTED }

	var route: Array[String] = []
	## 一圈的帧数；仅 PROVEN 时有意义。
	var period_frames := -1
	## 逐圈会话状态快照完全重现（循环可无限重复的证明）；与 Outcome.PROVEN 同义。
	var proven := false
	## 逐圈模拟结局：PROVEN＝快照重现；BROKEN＝断链；HORIZON_TRUNCATED＝帧数
	## 上限先于 8 圈对拍到达（链条仍成立）；LAPS_EXHAUSTED＝8 圈全部命中成立但
	## 快照未重现。后两种是「未证明且未断链」的未完成观测。
	var outcome: Outcome = Outcome.BROKEN
	var laps_observed := 0
	var reason := ""
	## 起始状态说明：分析起点（缺省/显式）与入口招式的真实键位起手方式。
	var start_text := ""
	## 证明回放的逐帧输入表（截到重现对拍帧为止）：回放到该帧恰好看完
	## 「入口圈 + 重现为止的完整圈数」，逐圈状态快照可在回放中复核。
	var inputs: Array[ScheduledInput] = []

	func label() -> String:
		return " → ".join(route) + " → 回到 " + route[0]


## 起始战斗状态（issue 19）：分析起点的显式描述。
## 缺省（null）＝地面中立、空输入缓存/方向历史、地面中立木桩、固定探针接触位；
## 中间状态必须由调用方显式提供——空中姿态以确定性探针序（Space 垂直跳 + 4f
## 起跳准备 + N 空中帧）带入，首招候选随之切换为该姿态下当前可执行的招式。
class SolverStartState extends RefCounted:
	## 起始姿态：地面中立（默认）或空中（显式中间状态）。
	var stance: MoveData.Stance = MoveData.Stance.GROUND
	## 空中起始时已消耗的空中帧数（0 = 自首个空中帧起分析）。
	var air_frames := 0


## 空间验证数据（issue 22）：调用方显式提供站位与碰撞几何后，空间探针才在
## 固定站位网格（地面站位 × 验证面向左右镜像 × 48/64/80 px 身体中心水平距离）
## 上逐条复验 timing-valid 路线。命中框取共享招式表的 hitbox 声明（调用方
## 已提供的表即命中框来源），验证面向取 SolverOptions.facings（默认左右镜像
## [1, -1]）；垂直轨迹首版固定为地面站位（双方站地），空中段的玩家弧线与
## 木桩浮空由真实结算携带，不作空间假设。空间复验在真实 CombatSession 中
## 进行，不维护第二套碰撞物理——身体矩形必须与运行时几何一致，不一致即
## 拒绝分析。
class SolverSpatialData extends RefCounted:
	## 身体矩形尺寸（玩家与木桩共用）。必须等于 GameParams.BODY_SIZE——
	## 与运行时不一致的碰撞盒无法在真实结算中复验。
	var body_size := GameParams.BODY_SIZE


## 搜索选项（issue 19）：共享资源表、可选显式起始状态与验证面向。
## move_table 非空时优先于 manifest_path（程序注入实验表，不经过 MoveTable 校验）；
## facings 为空时默认 [1, -1]——左右面向分别验证并镜像对拍。
class SolverOptions extends RefCounted:
	## 共享招式表 manifest（与训练场同一份已校验数据）。
	var manifest_path := MoveTable.DEFAULT_MANIFEST_PATH
	## 显式注入表（可选；优先于 manifest）。
	var move_table := {}
	## 起始战斗状态（null = 默认地面中立）。
	var start: SolverStartState = null
	## 要验证的面向列表（默认左右都验证；±1 之外无定义）。
	var facings: Array[int] = [1, -1]
	## 空间验证数据（null = 不做空间验证，路线仅 timing-valid；issue 22）。
	var spatial: SolverSpatialData = null


## 分析报告：接续边、可读路线、循环与可读文本。refused = 招式表未通过校验，
## Solver 拒绝分析且不产出任何结论（与训练场观察同一拒绝原因，issue 11）。
class SolverReport extends RefCounted:
	var safe := true
	var summary := ""
	var scope := ""
	var edges: Array[SolverEdge] = []
	## 配置缺口（issue 20）：时序经一次性探针表验证成立、但对应配置数组未声明
	## 的候选接续。缺口不是合法边——不进入路线、循环与操作说明。
	var gaps: Array[SolverEdge] = []
	var routes: Array[SolverRoute] = []
	var cycles: Array[SolverCycle] = []
	## 未证明且未断链的结构性循环数（截断/未完成观测；明细见 notes，
	## 汇总措辞据此声明「不宣称完整证明」，issue 21）。
	var incomplete_cycle_count := 0
	var notes: Array[String] = []
	var refused := false
	var refusal_reason := ""
	## 拒绝报告的修正建议（表非法 → 修资源；起始状态非法 → 调用方调整选项）。
	var refusal_advice := ""
	## 共享招式表摘要行（设计者核对资源编辑是否进入报告，issue 11）。
	var table_lines: Array[String] = []
	## 起始状态说明（issue 19）：缺省/显式起始、固定接触位、验证面向与镜像结论。
	var start_lines: Array[String] = []
	## 首招候选：起始状态下当前可执行的单键招式（稳定 id 序；投与空中派生见注）。
	var first_candidates: Array[String] = []
	## 输入绑定与方向 variant（issue 20）：每个可起手招式的全部声明记法
	## （方向派生 + 显式替代串）及逐条探针验证结果。
	var binding_lines: Array[String] = []
	## 空间分层说明（issue 22）：timing-valid 与可选 spatial-valid 的分层结果、
	## 站位网格与失败明细；solve() 在多面向合并后生成。
	var spatial_lines: Array[String] = []
	## 操作说明：逐路线的真实键位回放指引（方向键/Space/动作键 + 等待帧），按验证面向分节。
	var guide_lines: Array[String] = []
	## 本次报告验证过的面向（+1 右 / -1 左）。
	var verified_facings: Array[int] = []
	## 多面向验证的镜像一致性（单面向恒为 true）。
	var mirror_consistent := true

	func to_lines() -> Array[String]:
		var lines: Array[String] = []
		lines.append("=== Combo Solver：地面与空中接续验证 ===")
		if refused:
			lines.append(summary)
			if refusal_advice != "":
				lines.append(refusal_advice)
			return lines
		lines.append(summary)
		lines.append(scope)
		lines.append("--- 起始状态 ---")
		for line in start_lines:
			lines.append(line)
		lines.append("--- 首招候选 ---")
		if first_candidates.is_empty():
			lines.append("（起始状态没有可单键起手的招式）")
		for line in first_candidates:
			lines.append(line)
		lines.append("--- 输入绑定与方向 variant ---")
		if binding_lines.is_empty():
			lines.append("（起始状态没有可单键起手的招式，无可枚举的输入绑定）")
		for line in binding_lines:
			lines.append(line)
		lines.append("--- 共享招式表 ---")
		if table_lines.is_empty():
			lines.append("（招式表为程序注入，无共享资源摘要）")
		for line in table_lines:
			lines.append(line)
		lines.append("--- 接续边 ---")
		if edges.is_empty():
			lines.append("（招式表中没有可分析的接续边）")
		for edge in edges:
			var edge_line := "%s（%s）：%s｜%s" % [edge.label(), edge.kind_text(), "有效" if edge.valid else "排除", edge.reason]
			if edge.blocked_valid or edge.blocked_reason != "":
				edge_line += "｜被防路径%s" % (("成立：" + edge.blocked_reason) if edge.blocked_valid else edge.blocked_reason)
			lines.append(edge_line)
		lines.append("--- 配置缺口 ---")
		if gaps.is_empty():
			lines.append("（未发现时序成立但缺少配置的候选接续）")
		for gap in gaps:
			lines.append("%s（%s）：时序成立但缺配置｜%s" % [gap.label(), gap.kind_text(), gap.reason])
		lines.append("--- 可读路线 ---")
		if routes.is_empty():
			lines.append("（无可读路线）")
		for route in routes:
			var suffix := "（%s）" % route.note if route.note != "" else ""
			lines.append("%s：命中帧 %s，%d hit，伤害 %.1f%s｜%s" % [
				route.label(), ComboSolver._hit_frames_text(route.hit_frames), route.combo_hits, route.total_damage, suffix,
				ComboSolver._route_layer_tag(route),
			])
		lines.append("--- 空间分层 ---")
		if spatial_lines.is_empty():
			for line in ComboSolver._no_spatial_lines():
				lines.append(line)
		else:
			for line in spatial_lines:
				lines.append(line)
		lines.append("空间证明不搜索走位、中立、墙角、推挤、跨身或屏幕边界；配置缺口与时序失败不作空间失败上报。")
		lines.append("--- 循环 ---")
		if cycles.is_empty():
			lines.append("未发现经逐圈状态重现证明的有效循环（结构性回边的断链/截断/未完成观测见注）。")
		for cycle in cycles:
			var period := ("周期 %d 帧，" % cycle.period_frames) if cycle.period_frames > 0 else ""
			lines.append("%s：%s%s" % [cycle.label(), period, cycle.reason])
			lines.append("  起始状态：%s" % cycle.start_text)
			lines.append("  逐帧输入 %d 条（真实键位回放见操作说明的循环行）" % cycle.inputs.size())
		lines.append("--- 操作说明 ---")
		for line in guide_lines:
			lines.append(line)
		for note in notes:
			lines.append("注：%s" % note)
		return lines


var _table: Dictionary = {}
## 表内是否含普通投（B/C 成员键因此有组合等待；issue 17）。
var _table_has_throw := false
## 本次分析运行的验证面向（+1 右 / -1 左；探针钉位与方向喂入按它镜像）。
var _facing := 1
## 本次运行的探针钉位间距：timing 探针用固定接触位 PIN_DX；空间复验逐档
## 换入 48/64/80 px（issue 22）——钉位是探针的几何假设，空间层对它做显式复验。
var _pin_dx := PIN_DX
## 显式起始战斗状态（null = 默认地面中立；issue 19）。
var _start: SolverStartState = null


func _init(move_table: Dictionary) -> void:
	_table = move_table
	for move_id in _table:
		var move := _table[move_id] as MoveData
		if move != null and move.is_throw():
			_table_has_throw = true
			break


## 分析共享 manifest 指向的招式表；表未通过校验时拒绝分析并报告同一原因。
static func analyze_manifest(manifest_path: String) -> SolverReport:
	_profile_reset()
	var result := MoveTable.load_manifest(manifest_path)
	if not result.ok:
		return _refused_report(result)
	return ComboSolver.new(result.moves)._analyze()


## 分析招式表：生成确定性接续边、可读路线与循环报告。不修改任何运行时战斗状态。
## 默认分析共享 manifest（与训练场同一份已校验数据）；显式传入字典用于注入实验表。
static func analyze(move_table: Dictionary = {}) -> SolverReport:
	_profile_reset()
	var table := move_table
	if table.is_empty():
		var result := MoveTable.load_default()
		if not result.ok:
			return _refused_report(result)
		table = result.moves
	return ComboSolver.new(table)._analyze()


## 完整结果缓存控制。默认开启；开关不参与请求键，只决定是否读取/发布结果。
static func set_result_cache_enabled(enabled: bool) -> void:
	_cache_state()["enabled"] = enabled


static func result_cache_enabled() -> bool:
	return bool(_cache_state().get("enabled", true))


static func clear_result_cache() -> void:
	var state := _cache_state()
	state["entries"] = {}
	state["hits"] = 0
	state["misses"] = 0
	state["bypasses"] = 0


static func reset_result_cache_stats() -> void:
	var state := _cache_state()
	state["hits"] = 0
	state["misses"] = 0
	state["bypasses"] = 0


static func result_cache_stats() -> Dictionary:
	var state := _cache_state()
	return {
		"enabled": bool(state.get("enabled", true)),
		"entries": (state.get("entries", {}) as Dictionary).size(),
		"hits": int(state.get("hits", 0)),
		"misses": int(state.get("misses", 0)),
		"bypasses": int(state.get("bypasses", 0)),
	}


static func _cache_state() -> Dictionary:
	var state = Engine.get_meta(_RESULT_CACHE_META_KEY) if Engine.has_meta(_RESULT_CACHE_META_KEY) else null
	if not (state is Dictionary) or not state.has("entries"):
		state = {"enabled": true, "entries": {}, "hits": 0, "misses": 0, "bypasses": 0}
		Engine.set_meta(_RESULT_CACHE_META_KEY, state)
	return state


## 耗时分解插桩（票据 03，常开、非调试开关）：按调用点分类的墙钟累计，
## 最内层作用域优先归属——每微秒恰好归一类，四个分类作用域之外的时间在
## 读取时计入 other。分类口径见票据 03 Comments；只计时不改任何搜索行为。
const _PROFILE_META_KEY := "ftg_demo_combo_solver_profile_v1"
const _PROFILE_DELAY := "delay_leaf"
const _PROFILE_EDGE := "edge_probe"
const _PROFILE_GAP := "gap_enum"
const _PROFILE_ROUTE := "route_walk"
const _PROFILE_KINDS := [_PROFILE_DELAY, _PROFILE_EDGE, _PROFILE_GAP, _PROFILE_ROUTE]


static func _fresh_profile_state() -> Dictionary:
	var usecs := {}
	var runs := {}
	for kind in _PROFILE_KINDS:
		usecs[kind] = 0
		runs[kind] = 0
	return {"stack": [], "usecs": usecs, "runs": runs, "started": 0}


static func _profile_state() -> Dictionary:
	var state = Engine.get_meta(_PROFILE_META_KEY) if Engine.has_meta(_PROFILE_META_KEY) else null
	if not (state is Dictionary) or not state.has("stack"):
		state = _fresh_profile_state()
		Engine.set_meta(_PROFILE_META_KEY, state)
	return state


static func _profile_reset() -> void:
	var state := _fresh_profile_state()
	state["started"] = Time.get_ticks_usec()
	Engine.set_meta(_PROFILE_META_KEY, state)


static func _profile_enter(kind: String) -> void:
	(_profile_state()["stack"] as Array).append({"kind": kind, "started": Time.get_ticks_usec(), "child": 0})


static func _profile_exit() -> void:
	var state := _profile_state()
	var stack: Array = state["stack"]
	if stack.is_empty():
		return
	var frame: Dictionary = stack.pop_back()
	var total: int = Time.get_ticks_usec() - int(frame["started"])
	if not stack.is_empty():
		var parent: Dictionary = stack[stack.size() - 1]
		parent["child"] = int(parent["child"]) + total
	state["usecs"][frame["kind"]] = int(state["usecs"][frame["kind"]]) + total - int(frame["child"])


static func _profile_count_run() -> void:
	var state := _profile_state()
	var stack: Array = state["stack"]
	var kind := "other"
	if not stack.is_empty():
		kind = stack[stack.size() - 1]["kind"]
	if not state["runs"].has(kind):
		state["runs"][kind] = 0
	state["runs"][kind] = int(state["runs"][kind]) + 1


## 上一个请求的耗时分解：四类 + other（请求总耗时 − 四类）+ 各类 _run_schedule
## 次数。缓存命中请求四类为零；读取不改状态，下一次请求入口清零。
static func last_request_profile() -> Dictionary:
	var state := _profile_state()
	var total: int = Time.get_ticks_usec() - int(state["started"])
	var attributed := 0
	var profile := {"total_ms": float(total) / 1000.0}
	for kind in _PROFILE_KINDS:
		profile[kind + "_ms"] = float(int(state["usecs"][kind])) / 1000.0
		profile[kind + "_runs"] = int(state["runs"].get(kind, 0))
		attributed += int(state["usecs"][kind])
	profile["other_ms"] = float(maxi(0, total - attributed)) / 1000.0
	profile["other_runs"] = int(state["runs"].get("other", 0))
	return profile


## 正式入口（issue 19）：接受共享资源表、可选显式起始战斗状态与搜索选项。
## 缺省起始状态为地面中立（空输入缓存/方向历史、地面中立木桩、固定探针接触位）；
## 默认左右面向分别验证，并以相对输入签名镜像对拍确认两侧结果对称；显式传入
## 空中等中间状态时，首招候选随之切换为该状态下当前可执行的招式。一次性探针不
## 修改任何活动会话；非法表与训练场观察同一拒绝原因（issue 11）。
static func solve(options: SolverOptions = null) -> SolverReport:
	_profile_reset()
	var opts := options if options != null else SolverOptions.new()
	if opts.start != null and opts.start.stance == MoveData.Stance.AIR \
			and (opts.start.air_frames < 0 or opts.start.air_frames >= GameParams.PLAYER_JUMP_AIRTIME_FRAMES):
		return _refused_start_state("air_frames=%d 超出普通跳 %d 帧滞空（落地后不再是空中姿态）" % [
			opts.start.air_frames, GameParams.PLAYER_JUMP_AIRTIME_FRAMES,
		])
	if opts.spatial != null:
		if opts.spatial.body_size != GameParams.BODY_SIZE:
			return _refused_spatial(
				"空间数据的身体矩形 %s 与运行时身体矩形 %s 不一致——空间复验在真实 CombatSession 结算中进行，Solver 不维护第二套碰撞物理" % [
					opts.spatial.body_size, GameParams.BODY_SIZE,
				],
				"调整 SolverSpatialData.body_size 与 GameParams.BODY_SIZE 一致后重新分析。")
		if opts.start != null and opts.start.stance == MoveData.Stance.AIR:
			return _refused_spatial(
				"首版空间探针只验证地面站位（双方站地）的 48/64/80 px 距离网格，与显式空中起始不匹配",
				"使用地面起始做空间验证（空中站位的网格不在首版范围）。")
	var injected := not opts.move_table.is_empty()
	var table := opts.move_table
	if table.is_empty():
		var result := MoveTable.load_manifest(opts.manifest_path)
		if not result.ok:
			return _refused_report(result)
		table = result.moves
	else:
		var copied := _clone_move_table(table)
		if copied["ok"]:
			table = copied["table"]
	var facings: Array[int] = opts.facings.duplicate() if not opts.facings.is_empty() else [1, -1]
	var request := _build_solve_request(options != null, opts, table, injected)
	var request_text: String = request.get("text", "")
	var cacheable: bool = bool(request.get("cacheable", false))
	if cacheable and result_cache_enabled():
		var state := _cache_state()
		var entries: Dictionary = state["entries"]
		var digest: String = request["digest"]
		if entries.has(digest):
			var entry = entries[digest]
			if entry is Dictionary and entry.get("descriptor", "") == request_text:
				state["hits"] = int(state.get("hits", 0)) + 1
				return _thaw_report(entry["snapshot"])
		state["misses"] = int(state.get("misses", 0)) + 1
	elif result_cache_enabled():
		var state := _cache_state()
		state["bypasses"] = int(state.get("bypasses", 0)) + 1
	var primary := ComboSolver.new(table)._analyze(facings[0], opts.start, true, opts.spatial)
	var facing_texts: Array[String] = []
	for facing in facings:
		facing_texts.append(_facing_text(facing))
	primary.start_lines.append("验证面向：%s" % "、".join(facing_texts))
	var primary_sections := _signature_sections(primary, facings[0])
	for i in range(1, facings.size()):
		var run := ComboSolver.new(table)._analyze(facings[i], opts.start, true, opts.spatial)
		primary.verified_facings.append(facings[i])
		var sections := _signature_sections(run, facings[i])
		var diff: Array[String] = []
		for section in ["edges", "gaps", "routes", "cycles"]:
			if sections[section] != primary_sections[section]:
				diff.append(_SECTION_LABELS[section])
		if diff.is_empty():
			primary.notes.append("面向 %s 镜像验证一致：接续边/配置缺口/路线/循环与相对输入在两侧完全对称" % _facing_text(facings[i]))
		else:
			primary.mirror_consistent = false
			primary.notes.append("面向 %s 与面向 %s 的%s结果不一致——镜像对称被打破，请回报该差异" % [
				_facing_text(facings[i]), _facing_text(facings[0]), "、".join(diff),
			])
		_merge_route_spatial(primary, run)
		primary.guide_lines.append_array(run.guide_lines)
	if facings.size() > 1:
		primary.summary += "左右面向分别验证%s。" % ("，镜像一致" if primary.mirror_consistent else "，但结果不一致（见注）")
	primary.spatial_lines = _spatial_report_lines(primary, facings, opts.spatial != null)
	if cacheable and result_cache_enabled() and not primary.refused:
		var state := _cache_state()
		state["entries"][request["digest"]] = {
			"descriptor": request_text,
			"snapshot": _freeze_report(primary),
		}
		return _thaw_report(state["entries"][request["digest"]]["snapshot"])
	return primary


static func _clone_move_table(table: Dictionary) -> Dictionary:
	var copy := {}
	for key in table:
		var move = table[key]
		if not (move is MoveData):
			return {"ok": false, "table": table}
		copy[key] = MoveTable._fresh_copy(move as MoveData)
	return {"ok": true, "table": copy}


static func _build_solve_request(options_present: bool, opts: SolverOptions, table: Dictionary, injected: bool) -> Dictionary:
	var effective_facings: Array[int] = opts.facings.duplicate() if not opts.facings.is_empty() else [1, -1]
	var table_text := _canonical_variant(table)
	if table_text == "":
		return {"cacheable": false, "text": "", "digest": ""}
	var start_value = null
	if opts.start != null:
		start_value = {"stance": opts.start.stance, "air_frames": opts.start.air_frames}
	var spatial_value = null
	if opts.spatial != null:
		spatial_value = {"body_size": opts.spatial.body_size}
	var descriptor := {
		"request_schema_version": _REQUEST_SCHEMA_VERSION,
		"report_snapshot_version": _REPORT_SNAPSHOT_VERSION,
		"entrypoint": "solve",
		"sort_outputs": true,
		"options_present": options_present,
		"table_source": "injected" if injected else "manifest",
		"injected_nonempty": injected,
		"table_schema_version": 1,
		"table_content_digest": _sha256_text(table_text),
		"manifest_path": opts.manifest_path,
		"manifest_signature": {"status": "not_used"} if injected else _manifest_signature(opts.manifest_path),
		"manifest_load_status": "not_used" if injected else "ok",
		"table": table,
		"start": {"present": opts.start != null, "value": start_value},
		"facings": {"raw": opts.facings.duplicate(), "effective": effective_facings},
		"spatial": {"present": opts.spatial != null, "value": spatial_value},
		"probe": {
			"pin_dx": PIN_DX,
			"spatial_distances": SPATIAL_PROBE_DISTANCES.duplicate(),
			"runtime_body_size": GameParams.BODY_SIZE,
		},
		"limits": {
			"max_cycle_laps": MAX_CYCLE_LAPS,
			"max_cycle_frames": MAX_CYCLE_FRAMES,
			"recover_horizon": RECOVER_HORIZON,
			"max_route_nodes": MAX_ROUTE_NODES,
			"max_route_delay_trials": MAX_ROUTE_DELAY_TRIALS,
			"max_air_delay": MAX_AIR_DELAY,
			"cancel_window_frames": GameParams.CANCEL_WINDOW_FRAMES,
			"route_delay_budget": MAX_ROUTE_DELAY_TRIALS,
		},
		"engine_version": Engine.get_version_info(),
		"semantics": _solver_semantics_signature(),
	}
	var canonical := _canonical_variant(descriptor)
	if canonical == "":
		return {"cacheable": false, "text": "", "digest": ""}
	return {"cacheable": true, "text": canonical, "digest": _sha256_text(canonical)}


static func _manifest_signature(path: String) -> Dictionary:
	var signature := {"manifest": _file_signature(path), "moves": []}
	var manifest = ResourceLoader.load(path)
	if manifest is MoveManifest:
		for move_path in (manifest as MoveManifest).move_paths:
			signature["moves"].append({"path": move_path, "file": _file_signature(move_path)})
	return signature


static func _file_signature(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "digest": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "digest": "read_failed"}
	return {"exists": true, "digest": _sha256_bytes(file.get_buffer(file.get_length()))}


static func _solver_semantics_signature() -> Dictionary:
	var paths := [
		"res://scripts/combat/combo_solver.gd",
		"res://scripts/combat/combat_session.gd",
		"res://scripts/combat/move_data.gd",
		"res://scripts/combat/move_segment.gd",
		"res://scripts/combat/hit_profile.gd",
		"res://scripts/combat/move_table.gd",
		"res://scripts/combat/frame_input.gd",
		"res://scripts/combat/combat_event.gd",
		"res://scripts/game_params.gd",
	]
	var result: Array[Dictionary] = []
	for path in paths:
		result.append({"path": path, "file": _file_signature(path)})
	return {"version": _RESULT_CACHE_SEMANTICS_VERSION, "sources": result}


static func _sha256_text(value: String) -> String:
	return _sha256_bytes(value.to_utf8_buffer())


static func _sha256_bytes(value: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(value)
	return hashing.finish().hex_encode()


## 版本化、带类型的请求描述编码。字典/数组保留原顺序；不支持的对象返回空串，
## 由调用方绕过缓存而不是猜测其值。
static func _canonical_variant(value) -> String:
	if value == null:
		return "N;"
	if value is bool:
		return "B1:1;" if value else "B1:0;"
	if value is int:
		var integer_text := str(value)
		return "I%d:%s;" % [integer_text.length(), integer_text]
	if value is float:
		if is_nan(value):
			## NaN 是“未声明”哨兵（票据 06 motion 字段），不是不支持的对象：
			## 确定性编码，避免整键退化为空串而绕过缓存。
			return "Fnan;"
		if is_inf(value):
			return ""
		var float_text := String.num(value, 17)
		return "F%d:%s;" % [float_text.length(), float_text]
	if value is String:
		var string_bytes: PackedByteArray = value.to_utf8_buffer()
		return "S%d:%s;" % [string_bytes.size(), value]
	if value is Vector2:
		var vector_text := _canonical_variant(value.x) + _canonical_variant(value.y)
		return "V2:" + vector_text
	if value is PackedByteArray:
		return "Y%d:%s;" % [value.size(), value.hex_encode()]
	if value is Array:
		var array_text := "A%d:[" % value.size()
		for item in value:
			var item_text := _canonical_variant(item)
			if item_text == "":
				return ""
			array_text += item_text
		return array_text + "];"
	if value is Dictionary:
		var dictionary_text := "D%d:[" % value.size()
		for key in value:
			var key_text := _canonical_variant(key)
			var item_text := _canonical_variant(value[key])
			if key_text == "" or item_text == "":
				return ""
			dictionary_text += key_text + item_text
		return dictionary_text + "];"
	if value is SolverStartState:
		return _canonical_variant({"stance": value.stance, "air_frames": value.air_frames})
	if value is SolverSpatialData:
		return _canonical_variant({"body_size": value.body_size})
	if value is MoveData:
		return _canonical_object(value, "MoveData", _MOVE_VALUE_FIELDS)
	if value is MoveSegment:
		return _canonical_object(value, "MoveSegment", _SEGMENT_VALUE_FIELDS)
	if value is HitProfile:
		return _canonical_object(value, "HitProfile", _PROFILE_VALUE_FIELDS)
	return ""


static func _canonical_object(value: Object, type_name: String, fields: Array) -> String:
	var known := {}
	for field in fields:
		known[field] = true
	## Resource metadata is identity/loader state, not a solver value. Any other
	## exported field means this schema is newer than the cache implementation.
	for property in value.get_property_list():
		var name := String(property.get("name", ""))
		if (int(property.get("usage", 0)) & 2) == 0:
			continue
		if name in ["resource_local_to_scene", "resource_name", "resource_path", "script"]:
			continue
		if not known.has(name):
			return ""
	var result := "O" + type_name + ":"
	for field in fields:
		var field_text := _canonical_variant(value.get(field))
		if field_text == "":
			return ""
		result += "K" + str(field.length()) + ":" + field + ";" + field_text
	return result


static func _freeze_report(report: SolverReport) -> Dictionary:
	var edges: Array = []
	for edge in report.edges:
		edges.append(_freeze_edge(edge))
	var gaps: Array = []
	for gap in report.gaps:
		gaps.append(_freeze_edge(gap))
	var routes: Array = []
	for route in report.routes:
		routes.append(_freeze_route(route))
	var cycles: Array = []
	for cycle in report.cycles:
		cycles.append(_freeze_cycle(cycle))
	return {
		"safe": report.safe,
		"summary": report.summary,
		"scope": report.scope,
		"edges": edges,
		"gaps": gaps,
		"routes": routes,
		"cycles": cycles,
		"incomplete_cycle_count": report.incomplete_cycle_count,
		"notes": report.notes.duplicate(),
		"refused": report.refused,
		"refusal_reason": report.refusal_reason,
		"refusal_advice": report.refusal_advice,
		"table_lines": report.table_lines.duplicate(),
		"start_lines": report.start_lines.duplicate(),
		"first_candidates": report.first_candidates.duplicate(),
		"binding_lines": report.binding_lines.duplicate(),
		"spatial_lines": report.spatial_lines.duplicate(),
		"guide_lines": report.guide_lines.duplicate(),
		"verified_facings": report.verified_facings.duplicate(),
		"mirror_consistent": report.mirror_consistent,
	}


static func _freeze_edge(edge: SolverEdge) -> Dictionary:
	var inputs: Array = []
	for input in edge.align_inputs:
		inputs.append(_freeze_input(input))
	return {
		"from_id": edge.from_id,
		"to_id": edge.to_id,
		"kind": edge.kind,
		"valid": edge.valid,
		"reason": edge.reason,
		"wait_from": edge.wait_from,
		"wait_to": edge.wait_to,
		"hit_age": edge.hit_age,
		"recover_age": edge.recover_age,
		"recover_truncated": edge.recover_truncated,
		"align_from": edge.align_from,
		"align_to": edge.align_to,
		"align_inputs": inputs,
		"blocked_valid": edge.blocked_valid,
		"blocked_reason": edge.blocked_reason,
		"charged": edge.charged,
	}


static func _freeze_route(route: SolverRoute) -> Dictionary:
	var inputs: Array = []
	for input in route.inputs:
		inputs.append(_freeze_input(input))
	return {
		"move_ids": route.move_ids.duplicate(),
		"hit_frames": route.hit_frames.duplicate(),
		"combo_hits": route.combo_hits,
		"total_damage": route.total_damage,
		"note": route.note,
		"timing_valid": route.timing_valid,
		"spatial_state": route.spatial_state,
		"spatial_failures": route.spatial_failures.duplicate(),
		"inputs": inputs,
	}


static func _freeze_cycle(cycle: SolverCycle) -> Dictionary:
	var inputs: Array = []
	for input in cycle.inputs:
		inputs.append(_freeze_input(input))
	return {
		"route": cycle.route.duplicate(),
		"period_frames": cycle.period_frames,
		"proven": cycle.proven,
		"outcome": cycle.outcome,
		"laps_observed": cycle.laps_observed,
		"reason": cycle.reason,
		"start_text": cycle.start_text,
		"inputs": inputs,
	}


static func _freeze_input(input: ScheduledInput) -> Dictionary:
	return {
		"frame": input.frame,
		"axis": input.axis,
		"down": input.down,
		"jump": input.jump,
		"key": input.key,
		"held_key": input.held_key,
	}


static func _thaw_report(snapshot: Dictionary) -> SolverReport:
	var report := SolverReport.new()
	report.safe = snapshot.get("safe", true)
	report.summary = snapshot.get("summary", "")
	report.scope = snapshot.get("scope", "")
	report.incomplete_cycle_count = snapshot.get("incomplete_cycle_count", 0)
	report.refused = snapshot.get("refused", false)
	report.refusal_reason = snapshot.get("refusal_reason", "")
	report.refusal_advice = snapshot.get("refusal_advice", "")
	report.mirror_consistent = snapshot.get("mirror_consistent", true)
	report.notes = _string_array(snapshot.get("notes", []))
	report.table_lines = _string_array(snapshot.get("table_lines", []))
	report.start_lines = _string_array(snapshot.get("start_lines", []))
	report.first_candidates = _string_array(snapshot.get("first_candidates", []))
	report.binding_lines = _string_array(snapshot.get("binding_lines", []))
	report.spatial_lines = _string_array(snapshot.get("spatial_lines", []))
	report.guide_lines = _string_array(snapshot.get("guide_lines", []))
	var facings: Array[int] = []
	for facing in snapshot.get("verified_facings", []):
		facings.append(int(facing))
	report.verified_facings = facings
	var edges: Array[SolverEdge] = []
	for edge_data in snapshot.get("edges", []):
		edges.append(_thaw_edge(edge_data))
	report.edges = edges
	var gaps: Array[SolverEdge] = []
	for gap_data in snapshot.get("gaps", []):
		gaps.append(_thaw_edge(gap_data))
	report.gaps = gaps
	var routes: Array[SolverRoute] = []
	for route_data in snapshot.get("routes", []):
		routes.append(_thaw_route(route_data))
	report.routes = routes
	var cycles: Array[SolverCycle] = []
	for cycle_data in snapshot.get("cycles", []):
		cycles.append(_thaw_cycle(cycle_data))
	report.cycles = cycles
	return report


static func _string_array(values) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


static func _thaw_edge(data: Dictionary) -> SolverEdge:
	var edge := SolverEdge.new()
	edge.from_id = data.get("from_id", "")
	edge.to_id = data.get("to_id", "")
	edge.kind = data.get("kind", EdgeKind.CANCEL)
	edge.valid = data.get("valid", false)
	edge.reason = data.get("reason", "")
	edge.wait_from = data.get("wait_from", 0)
	edge.wait_to = data.get("wait_to", -1)
	edge.hit_age = data.get("hit_age", -1)
	edge.recover_age = data.get("recover_age", -1)
	edge.recover_truncated = data.get("recover_truncated", false)
	edge.align_from = data.get("align_from", -1)
	edge.align_to = data.get("align_to", -1)
	edge.blocked_valid = data.get("blocked_valid", false)
	edge.blocked_reason = data.get("blocked_reason", "")
	edge.charged = data.get("charged", false)
	var inputs: Array[ScheduledInput] = []
	for input_data in data.get("align_inputs", []):
		inputs.append(_thaw_input(input_data))
	edge.align_inputs = inputs
	return edge


static func _thaw_route(data: Dictionary) -> SolverRoute:
	var route := SolverRoute.new()
	var move_ids: Array[String] = []
	for move_id in data.get("move_ids", []):
		move_ids.append(String(move_id))
	route.move_ids = move_ids
	var hit_frames: Array[int] = []
	for frame in data.get("hit_frames", []):
		hit_frames.append(int(frame))
	route.hit_frames = hit_frames
	route.combo_hits = data.get("combo_hits", 0)
	route.total_damage = data.get("total_damage", 0.0)
	route.note = data.get("note", "")
	route.timing_valid = data.get("timing_valid", false)
	route.spatial_state = data.get("spatial_state", SolverRoute.SpatialState.UNVERIFIED)
	route.spatial_failures = _string_array(data.get("spatial_failures", []))
	var inputs: Array[ScheduledInput] = []
	for input_data in data.get("inputs", []):
		inputs.append(_thaw_input(input_data))
	route.inputs = inputs
	return route


static func _thaw_cycle(data: Dictionary) -> SolverCycle:
	var cycle := SolverCycle.new()
	var route: Array[String] = []
	for move_id in data.get("route", []):
		route.append(String(move_id))
	cycle.route = route
	cycle.period_frames = data.get("period_frames", -1)
	cycle.proven = data.get("proven", false)
	cycle.outcome = data.get("outcome", SolverCycle.Outcome.BROKEN)
	cycle.laps_observed = data.get("laps_observed", 0)
	cycle.reason = data.get("reason", "")
	cycle.start_text = data.get("start_text", "")
	var inputs: Array[ScheduledInput] = []
	for input_data in data.get("inputs", []):
		inputs.append(_thaw_input(input_data))
	cycle.inputs = inputs
	return cycle


static func _thaw_input(data: Dictionary) -> ScheduledInput:
	var input := ScheduledInput.new()
	input.frame = data.get("frame", 0)
	input.axis = data.get("axis", 0)
	input.down = data.get("down", false)
	input.jump = data.get("jump", false)
	input.key = data.get("key", "")
	input.held_key = data.get("held_key", "")
	return input


static func _facing_text(facing: int) -> String:
	return "右（+1，玩家在木桩左侧）" if facing == 1 else "左（-1，玩家在木桩右侧）"


## 镜像对拍的相对签名：把逐帧输入按各自面向折算成相对方向后逐节比较——
## 左右两次运行只有「世界轴镜像」之别时应完全相等。落地接续边的对齐窗口与
## 回放样本、路线的断链注记与空间分层结论（issue 22）都参与签名，面向相关
## 的差异不会被漏报。
static func _signature_sections(report: SolverReport, facing: int) -> Dictionary:
	var edge_parts: Array[String] = []
	for edge in report.edges:
		edge_parts.append(_edge_signature(edge, facing))
	var gap_parts: Array[String] = []
	for gap in report.gaps:
		gap_parts.append(_edge_signature(gap, facing))
	var route_parts: Array[String] = []
	for route in report.routes:
		var input_parts: Array[String] = []
		for spec in route.inputs:
			input_parts.append("%d/%s/%s/%d" % [
				spec.frame, spec.key, str(spec.jump), _relative_digit(spec.axis, spec.down, facing),
			])
		route_parts.append("%s#%s#%d#%.1f#%s#%s#%d#%s" % [
			route.label(), str(route.hit_frames), route.combo_hits, route.total_damage,
			";".join(input_parts), route.note, route.spatial_state, ";".join(route.spatial_failures),
		])
	var cycle_parts: Array[String] = []
	for cycle in report.cycles:
		var input_parts: Array[String] = []
		for spec in cycle.inputs:
			input_parts.append("%d/%s/%s/%d" % [
				spec.frame, spec.key, str(spec.jump), _relative_digit(spec.axis, spec.down, facing),
			])
		cycle_parts.append("%s#%d#%s#%d#%s#%s#%s" % [
			cycle.label(), cycle.period_frames, str(cycle.proven),
			cycle.laps_observed, cycle.reason, cycle.start_text, ";".join(input_parts),
		])
	return {
		"edges": "|".join(edge_parts),
		"gaps": "|".join(gap_parts),
		"routes": "|".join(route_parts),
		"cycles": "|".join(cycle_parts),
	}


## 单条接续边/缺口的相对签名（边与缺口共用同一口径，防两处格式漂移）。
static func _edge_signature(edge: SolverEdge, facing: int) -> String:
	var align_parts: Array[String] = []
	for spec in edge.align_inputs:
		align_parts.append("%d/%s/%s/%d" % [
			spec.frame, spec.key, str(spec.jump), _relative_digit(spec.axis, spec.down, facing),
		])
	return "%s>%s:%d:%s:%d:%d:%d:%d:%d:%d:%s:%s:%s:%s" % [
		edge.from_id, edge.to_id, edge.kind, str(edge.valid),
		edge.wait_from, edge.wait_to, edge.hit_age, edge.recover_age,
		edge.align_from, edge.align_to, edge.reason, ";".join(align_parts),
		str(edge.blocked_valid), edge.blocked_reason,
	]


## 边/缺口稳定排序键（from → to → kind；边与缺口共用）。
static func _edge_sort_key(edge: SolverEdge) -> String:
	return "%s|%s|%d" % [edge.from_id, edge.to_id, edge.kind]


## 路线分层标签（issue 22）：timing 层结论在前，空间层三态在后；时序未成立
## 的路线不作空间复验——时序失败不标作空间失败。
static func _route_layer_tag(route: SolverRoute) -> String:
	if not route.timing_valid:
		return "timing 未成立；空间不作验证"
	match route.spatial_state:
		SolverRoute.SpatialState.VALID:
			return "timing-valid；spatial-valid"
		SolverRoute.SpatialState.INVALID:
			return "timing-valid；空间失败，见空间分层"
	return "timing-valid；空间未验证"


## 多面向空间结果合并（issue 22）：spatial-valid 须全部验证面向成立；任一面向
## 失败即 INVALID，失败按站位取并集——镜像对称时两侧失败相同（去重后不重复
## 罗列），镜像被打破时把每个面向的失败站位都收进列表，不漏报。
static func _merge_route_spatial(primary: SolverReport, other: SolverReport) -> void:
	for route in primary.routes:
		if route.spatial_state == SolverRoute.SpatialState.UNVERIFIED:
			continue
		var peer := _route_by_label(other, route.label())
		if peer == null or peer.spatial_state != SolverRoute.SpatialState.INVALID:
			continue
		route.spatial_state = SolverRoute.SpatialState.INVALID
		for failure in peer.spatial_failures:
			if not route.spatial_failures.has(failure):
				route.spatial_failures.append(failure)


## 按标签取路线（多面向合并用；路线标签在面向间镜像一致）。
static func _route_by_label(report: SolverReport, label: String) -> SolverRoute:
	for route in report.routes:
		if route.label() == label:
			return route
	return null


## 未提供空间数据时的分层声明（solve() 的空间分层节与旧入口 analyze() 的
## 报告兜底共用同一文案，防两处漂移）：仅 timing-valid，固定接触位是几何假设。
static func _no_spatial_lines() -> Array[String]:
	return [
		"未提供空间数据（solve() 的 SolverOptions.spatial）：全部路线仅 timing-valid——固定探针接触位 %d px 是几何假设，不构成空间证明。" % PIN_DX,
		"提供空间数据后，空间探针在地面、左右镜像的 48/64/80 px 三组身体中心水平距离上逐条复验 timing-valid 路线并附上空间证明标记。",
	]


## 空间分层节（issue 22）：站位网格、逐路线结果与范围边界。solve() 生成本节并
## 保证其中已合并全部验证面向的结果；未提供空间数据时必须输出「仅
## timing-valid」的分层声明，不允许静默省略。
static func _spatial_report_lines(report: SolverReport, facings: Array[int], provided: bool) -> Array[String]:
	var lines: Array[String] = []
	if not provided:
		return _no_spatial_lines()
	var facing_texts: Array[String] = []
	for facing in facings:
		facing_texts.append("%+d" % facing)
	lines.append("已提供空间数据：空间探针在地面站位（双方站地）、验证面向 %s（左右镜像）的身体中心水平距离 48、64、80 px 三组站位上逐条复验 timing-valid 路线——命中框与身体矩形的相交在真实 CombatSession 结算中判定（身体矩形 %s、命中框取共享招式表声明；垂直轨迹按真实结算，不作空间假设）。复验与 timing 层共用同一套空中延迟搜索：存在一组延迟使整条链接通即算该站位成立，不要求与操作说明的样本帧表逐帧相同。" % [
		"、".join(facing_texts), GameParams.BODY_SIZE,
	])
	var valid_count := 0
	var invalid_count := 0
	var unverified_count := 0
	for route in report.routes:
		match route.spatial_state:
			SolverRoute.SpatialState.VALID:
				valid_count += 1
			SolverRoute.SpatialState.INVALID:
				invalid_count += 1
			_:
				unverified_count += 1
	lines.append("spatial-valid %d 条、空间失败 %d 条、空间未验证 %d 条（timing 未成立的路线不作空间复验——时序失败与配置缺口都不标作空间失败）。" % [
		valid_count, invalid_count, unverified_count,
	])
	for route in report.routes:
		if route.spatial_state == SolverRoute.SpatialState.INVALID:
			lines.append("%s：%s" % [route.label(), "；".join(route.spatial_failures)])
	if not report.cycles.is_empty():
		lines.append("循环证明保持 timing-valid：循环性证明在固定接触位 %d px 上完成，空间分层只覆盖可读路线的站位网格。" % PIN_DX)
	lines.append("操作说明的帧表按固定接触位 %d px 编排；空间分层只在 48/64/80 px 三组站位复验，不外推到其余站位。" % PIN_DX)
	lines.append("此处 spatial-valid 仅指每帧钉回指定间距的静态探针；不包含真实击退累积。训练场完整命中需另行不钉位回放，不能从该标签推断。")
	return lines


## 世界轴输入按面向折算的小键盘相对方向（前 6 / 后 4 / 下 2 / 斜 1、3 / 中立 5）。
static func _relative_digit(axis: int, down: bool, facing: int) -> int:
	var horizontal := 0
	if axis == facing:
		horizontal = 1
	elif axis == -facing:
		horizontal = -1
	return 5 + horizontal - (3 if down else 0)


static func _refused_report(result) -> SolverReport:
	var report := _refused_base(result.first_error())
	report.summary = "招式表未通过校验，拒绝分析：%s" % report.refusal_reason
	report.refusal_advice = "修改招式资源后重新分析；Solver 与训练场使用同一份 manifest，两处会同步拒绝。"
	return report


## 显式起始状态非法（如 air_frames 超出滞空）：拒绝分析并指出修正方向，
## 不静默钳制到最近合法值——错误请求不应伪装成另一种起始条件。
static func _refused_start_state(reason: String) -> SolverReport:
	var report := _refused_base(reason)
	report.summary = "显式起始状态非法，拒绝分析：%s" % reason
	report.refusal_advice = "调整 SolverOptions.start 后重新分析（空中起始的 air_frames 须在 0 到滞空帧数-1 之间）。"
	return report


## 空间数据非法（身体矩形与运行时不一致、地面网格配空中起始）：拒绝分析并
## 指出修正方向——不能在真实结算中复验的几何不产出任何分层结论。
static func _refused_spatial(reason: String, advice: String) -> SolverReport:
	var report := _refused_base(reason)
	report.summary = "空间数据非法，拒绝分析：%s" % reason
	report.refusal_advice = advice
	return report


static func _refused_base(reason: String) -> SolverReport:
	var report := SolverReport.new()
	report.refused = true
	report.refusal_reason = reason
	report.scope = SCOPE_TEXT
	return report


# --- 分析主体 ---

## 单面向一次完整分析：facing 决定探针钉位与方向喂入的镜像方向；start 为显式
## 起始状态（null = 默认地面中立）；sort_outputs 按稳定键排序边与路线（solve 用，
## 旧入口 analyze 保留表序枚举）；spatial 非空时在路线产出后做 48/64/80 px
## 站位复验（issue 22，旧入口 analyze 不做空间分层）。
func _analyze(facing := 1, start: SolverStartState = null, sort_outputs := false, spatial: SolverSpatialData = null) -> SolverReport:
	_facing = facing
	_start = start
	_pin_dx = PIN_DX
	var report := SolverReport.new()
	report.scope = SCOPE_TEXT
	report.verified_facings = [facing]
	report.table_lines = _table_summary_lines()
	report.start_lines = _start_state_lines()
	if spatial != null:
		report.start_lines.append("空间验证：已提供空间数据——地面站位 × 48/64/80 px 身体中心水平距离网格（验证面向与结果见空间分层节）")
	report.first_candidates = _first_candidates()
	report.binding_lines = _binding_variant_lines()
	if _table_has_throw:
		report.notes.append("普通投是 B+C 组合输入，无单键起手，不在首招候选（组合输入调度不在本入口范围）")
	var contexts := _build_contexts()
	var timing_cache := {}
	var valid_adj := {}
	var edge_kinds := {}
	_profile_enter(_PROFILE_EDGE)
	for from_id in _table:
		var from_move := _table[from_id] as MoveData
		## 投技不走单键/取消链起手（投技行为在后续 issue 实装），不进入接续图。
		if from_move == null or from_move.is_throw():
			continue
		var kinds_and_targets := [
			[EdgeKind.CANCEL, from_move.cancel_targets],
			[EdgeKind.CHAIN_CANCEL, from_move.chain_cancel_targets],
			[EdgeKind.SPECIAL_CANCEL, from_move.special_cancel_targets],
			[EdgeKind.JUMP_CANCEL, from_move.jump_cancel_targets],
			[EdgeKind.LANDING_CANCEL, from_move.landing_cancel_targets],
			[EdgeKind.NORMAL_LINK, from_move.link_targets],
			[EdgeKind.REKKA_DERIVE, _rekka_targets_of(from_move)],
			[EdgeKind.SPECIAL_ENTRY, from_move.special_entry_targets],
			[EdgeKind.SPECIAL_ENTRY_LINK, from_move.special_entry_link_targets],
			[EdgeKind.AIR_EXIT, from_move.air_exit_targets],
			[EdgeKind.HIT_LANDING_CANCEL, from_move.hit_landing_cancel_targets],
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
					# 枚举顺序固定为 命中确认取消 > 链式 > 必杀 > jump cancel > 落地接续 >
					# 普通连接 > Rekka 派生 > 特殊进入 > 来源限定连接 > 空中出口 > 命中落地
					# 取消，确定性且优先中断性取消。
					var key := "%s|%s" % [from_id, to_id]
					if not edge_kinds.has(key):
						edge_kinds[key] = kind
				## 蓄力变体（票据 06）：目标声明蓄力时，同一接缝另验证按住至阈值
				## 的蓄力版提交（to 换为 charge_only 目标，独立成边、独立验证）。
				var pair_to := _table.get(to_id) as MoveData
				if pair_to != null and pair_to.is_chargeable() and _table.has(pair_to.charge_move_id):
					var charged_edge := _build_edge(from_id, pair_to.charge_move_id, kind, contexts, timing_cache)
					report.edges.append(charged_edge)
					if charged_edge.valid:
						if not valid_adj.has(from_id):
							valid_adj[from_id] = [] as Array[String]
						var charged_targets: Array[String] = valid_adj[from_id]
						if not charged_targets.has(pair_to.charge_move_id):
							charged_targets.append(pair_to.charge_move_id)
							var charged_key := "%s|%s" % [from_id, pair_to.charge_move_id]
							if not edge_kinds.has(charged_key):
								edge_kinds[charged_key] = kind
	_profile_exit()
	_profile_enter(_PROFILE_GAP)
	_enumerate_gaps(contexts, timing_cache, report)
	_profile_exit()
	if report.edges.any(func(edge: SolverEdge) -> bool: return edge.blocked_valid):
		report.notes.append("被防取消边只在固定探针姿态下验证取消时序（被防是独立接触结果，不产生命中，不入路线/循环图）；被防安全性（指定反击招式、时机、距离、版中/版边与左右面向）必须真实空间回放（replay-required），静态报告不下安全结论")
	## 图的路线起点：起始姿态下单键可起手、无方向派生的打击招式（按表内顺序，确定性枚举）。
	var sources: Array[String] = []
	for move_id in _table:
		if _is_plain_start_id(move_id):
			sources.append(move_id)
	_profile_enter(_PROFILE_ROUTE)
	for start_id in sources:
		_walk_routes(start_id, [start_id], valid_adj, report.routes, contexts, edge_kinds)
	_profile_exit()
	_profile_enter(_PROFILE_ROUTE)
	for cycle_ids in _elementary_cycles(valid_adj):
		var cycle := _simulate_cycle(cycle_ids, contexts, edge_kinds)
		if cycle.outcome == SolverCycle.Outcome.PROVEN:
			report.cycles.append(cycle)
		else:
			var label: String = " → ".join(cycle_ids) + " → 回到 " + cycle_ids[0]
			if cycle.outcome == SolverCycle.Outcome.HORIZON_TRUNCATED \
					or cycle.outcome == SolverCycle.Outcome.LAPS_EXHAUSTED:
				report.incomplete_cycle_count += 1
				report.notes.append("结构性循环 %s：%s" % [label, cycle.reason])
			else:
				report.notes.append("结构性循环 %s 在逐圈模拟中断开，不构成有效循环：%s" % [label, cycle.reason])
	_profile_exit()
	if spatial != null:
		_profile_enter(_PROFILE_ROUTE)
		_verify_routes_spatial(report, contexts, edge_kinds)
		_profile_exit()
	report.safe = report.cycles.is_empty()
	if sort_outputs:
		## 稳定排序（issue 19）：排序键含全部并列维度（from/to/kind 唯一、路线标签唯一），
		## 与枚举顺序无关的确定输出，供跨运行/跨面向对拍。
		report.edges.sort_custom(func(a: SolverEdge, b: SolverEdge) -> bool:
			return _edge_sort_key(a) < _edge_sort_key(b))
		report.gaps.sort_custom(func(a: SolverEdge, b: SolverEdge) -> bool:
			return _edge_sort_key(a) < _edge_sort_key(b))
		report.routes.sort_custom(func(a: SolverRoute, b: SolverRoute) -> bool:
			return a.label() < b.label())
		report.cycles.sort_custom(func(a: SolverCycle, b: SolverCycle) -> bool:
			return a.label() < b.label())
	report.summary = _build_summary(report)
	report.guide_lines = _guide_lines(report)
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
		var text := "未发现经逐圈状态重现证明的有效循环：接续边 %d 条（有效 %d、排除 %d），配置缺口 %d 条，可读路线 %d 条。" % [
			report.edges.size(), valid_count, report.edges.size() - valid_count, report.gaps.size(), report.routes.size(),
		]
		if report.incomplete_cycle_count > 0:
			text += "另有 %d 个结构性循环观测截断/未完成（见注），不宣称完整证明。" % report.incomplete_cycle_count
		return text
	var parts: Array[String] = []
	for cycle in report.cycles:
		var period := ("，周期 %d 帧" % cycle.period_frames) if cycle.period_frames > 0 else ""
		parts.append(cycle.label() + period)
	return "检测到 %d 个经逐圈状态重现证明的有效循环：%s；命中确认取消链可在木桩自然受身前无限重复，请调整招式数据。" % [
		report.cycles.size(), "；".join(parts),
	]


# --- 起始状态说明与首招候选（issue 19）---


func _is_air_start() -> bool:
	return _start != null and _start.stance == MoveData.Stance.AIR


## 起始状态说明：缺省/显式起始、空缓存/方向历史、木桩状态与固定接触位。
## 验证面向与镜像结论由 solve() 在多面向运行后追加。
func _start_state_lines() -> Array[String]:
	var lines: Array[String] = []
	if _is_air_start():
		lines.append("起始状态：显式提供——玩家空中姿态，自第 %d 个空中帧起分析（探针序：Space 垂直跳 + %d 帧起跳准备 + %d 空中帧）；空输入缓存/空方向历史；木桩地面中立" % [
			_start.air_frames + 1, GameParams.PLAYER_PREJUMP_FRAMES, _start.air_frames,
		])
	elif _start != null:
		lines.append("起始状态：显式提供——玩家地面中立；空输入缓存/空方向历史；木桩地面中立")
	else:
		lines.append("起始状态：默认地面中立——玩家地面中立；空输入缓存/空方向历史；木桩地面中立")
	lines.append("固定探针接触位：玩家与木桩身体中心水平间距 %d px（几何接触是假设，不构成空间证明）" % PIN_DX)
	return lines


## 首招候选：起始姿态下当前可执行、且可用本 Solver 输入表达（单键 + 方向喂入）
## 起手的打击招式，按稳定 id 序输出。空中招式在默认地面起始下不出现（只能经配置
## 的 jump cancel 进入）；显式空中起始下地面招式同理不出现。
func _first_candidates() -> Array[String]:
	var ids: Array[String] = []
	for move_id in _table:
		if _is_startable_start_stance_strike(move_id):
			ids.append(move_id)
	ids.sort()
	var lines: Array[String] = []
	for move_id in ids:
		var move := _table[move_id] as MoveData
		var physical: String = ACTION_PHYSICAL_KEYS.get(move.action_key, move.action_key)
		var crouch_mark := "（蹲姿：按下时按住下方向）" if move.requires_crouch else ""
		if move.direction_derivation == "":
			lines.append("%s｜%s 键（%s）%s" % [move_id, physical, move.action_key, crouch_mark])
		else:
			var digits := move.direction_derivation.left(move.direction_derivation.length() - 1)
			lines.append("%s｜方向 %s + %s 键（%s）%s" % [move_id, digits, physical, move.action_key, crouch_mark])
	return lines


# --- 配置缺口（issue 20：时序成立但缺配置的候选只报告缺口）---


## 枚举未配置的 (from, to, kind) 候选并用一次性探针表验证时序：cancel_targets、
## jump_cancel_targets 与 landing_cancel_targets 是运行时硬约束，探针把候选临时
## 注入对应数组后走与正式边完全相同的逐帧验证——时序成立只报告为配置缺口，
## 不进入合法边/路线/循环；时序或结构不成立（姿态不符、收尾来源、投技、等待
## 超时、接缝对不齐）的候选保持沉默：补上配置也不会使其合法。
func _enumerate_gaps(contexts: Dictionary, timing_cache: Dictionary, report: SolverReport) -> void:
	for from_id in _table:
		var from_move := _table[from_id] as MoveData
		if from_move == null or from_move.is_throw() or from_move.is_finisher:
			continue
		if not contexts.has(from_id):
			continue
		for to_id in _table:
			var to_move := _table[to_id] as MoveData
			if to_move == null or to_move.is_throw() or _start_key_for(to_id) == "":
				continue
			var kinds: Array[EdgeKind] = []
			if to_move.stance == from_move.stance:
				var same_stance_fields: Array[String] = [
					_GAP_CONFIG_FIELDS[EdgeKind.CANCEL]["field"],
					_GAP_CONFIG_FIELDS[EdgeKind.CHAIN_CANCEL]["field"],
					_GAP_CONFIG_FIELDS[EdgeKind.SPECIAL_CANCEL]["field"],
				]
				## 空技普通连接是「落地恢复后消费」的地面目标接缝：落地按地面姿态重解析，
				## 空→空目标结构不可达——候选保持沉默，不为不可达接缝跑落地接缝扫描。
				if from_move.stance != MoveData.Stance.AIR:
					same_stance_fields.append(_GAP_CONFIG_FIELDS[EdgeKind.NORMAL_LINK]["field"])
				for same_stance in same_stance_fields:
					if not (from_move.get(same_stance) as Array[String]).has(to_id):
						kinds.append(_field_gap_kind(same_stance))
			if from_move.stance == MoveData.Stance.GROUND and to_move.stance == MoveData.Stance.AIR \
					and not (from_move.jump_cancel_targets as Array[String]).has(to_id) \
					and not (from_move.air_exit_targets as Array[String]).has(to_id):
				kinds.append(EdgeKind.JUMP_CANCEL)
			if from_move.stance == MoveData.Stance.AIR and to_move.stance == MoveData.Stance.GROUND \
					and not (from_move.landing_cancel_targets as Array[String]).has(to_id):
				kinds.append(EdgeKind.LANDING_CANCEL)
			for kind in kinds:
				var gap := _probe_gap(from_id, to_id, kind, contexts, timing_cache)
				if gap != null:
					report.gaps.append(gap)


## 单个缺口候选的验证：临时换成注入了候选配置的一次性探针表，复用正式边的
## 逐帧验证；时序成立才返回缺口条目（valid 恒为 false——缺口不是合法边）。
## 同姿态缺口接缝的字段 → 接种种类（字段名在 _GAP_CONFIG_FIELDS 中一一对应）。
func _field_gap_kind(field: String) -> EdgeKind:
	for kind in _GAP_CONFIG_FIELDS:
		if _GAP_CONFIG_FIELDS[kind]["field"] == field:
			return kind
	return EdgeKind.CANCEL


func _probe_gap(from_id: String, to_id: String, kind: EdgeKind, contexts: Dictionary, timing_cache: Dictionary) -> SolverEdge:
	var base_table := _table
	_table = _gap_probe_table(from_id, to_id, kind)
	var edge := _build_edge(from_id, to_id, kind, contexts, timing_cache, true)
	_table = base_table
	if not edge.valid:
		return null
	edge.valid = false
	edge.reason = _gap_reason(edge)
	return edge


## 缺口探针表：from 的深拷贝（配置数组重建）向对应配置数组追加候选目标——
## 探针的任何写入都不触及共享表或调用方注入表里的 MoveData；其余表项与原表
## 共享只读引用。
func _gap_probe_table(from_id: String, to_id: String, kind: EdgeKind) -> Dictionary:
	var probe := _table.duplicate()
	var mutated := MoveTable._fresh_copy(_table[from_id] as MoveData)
	(mutated.get(_GAP_CONFIG_FIELDS[kind]["field"]) as Array).append(to_id)
	## 链式/必杀缺口须同时注入窗口（frame-data.md 调校初值 3/5）：窗口是运行时
	## 硬约束的一部分，只注入目标会让探针因窗口未声明而永不开放。
	match kind:
		EdgeKind.CHAIN_CANCEL:
			if mutated.chain_cancel_window_frames < 0:
				mutated.chain_cancel_window_frames = 3
		EdgeKind.SPECIAL_CANCEL:
			if mutated.special_cancel_window_frames < 0:
				mutated.special_cancel_window_frames = 5
		EdgeKind.HIT_LANDING_CANCEL:
			if mutated.hit_landing_cancel_window_frames < 0:
				mutated.hit_landing_cancel_window_frames = 24
	probe[from_id] = mutated
	return probe


func _gap_reason(edge: SolverEdge) -> String:
	var config: Dictionary = _GAP_CONFIG_FIELDS[edge.kind]
	var timing := "最早命中在命中确认后第 %d 帧，不晚于木桩恢复（第 %d 帧），有效等待 0–%d 帧%s" % [
		edge.hit_age, edge.recover_age, edge.wait_to, _recover_truncation_note(edge.recover_truncated),
	]
	match edge.kind:
		EdgeKind.JUMP_CANCEL:
			timing = "Space 取消起跳后空中起手最早在命中确认后第 %d 帧命中" % edge.hit_age
		EdgeKind.LANDING_CANCEL:
			timing = "空中命中可落在落地帧前 %d 帧（0＝恰在落地帧，临界规则）接地面起手" % edge.align_from
	return "%s——经一次性探针验证成立；缺配置：%s 不在 %s.%s，%s 是运行时硬约束，补配后才成为合法接续边，不因此宣布为合法连段" % [
		timing, edge.to_id, edge.from_id, config["field"], config["seam"],
	]


## 恢复观测截断附注（issue 21）：木桩在观测上限内未自然受身时，恢复年龄是
## 截断下限不是实测恢复——如实标注，不把观测上限伪装成恢复证明。
func _recover_truncation_note(truncated: bool) -> String:
	if not truncated:
		return ""
	return "；注意：%d 帧恢复观测上限内未观测到木桩自然受身，第 %d 帧是截断下限而非实测恢复（实际恢复不早于该帧），不构成完整恢复观测" % [
		RECOVER_HORIZON, RECOVER_HORIZON,
	]


# --- 输入绑定与方向 variant（issue 20）---


## 招式的全部声明指令记法：基础方向派生 + 显式输入替代串（与运行时同一口径，
## 每个替代串是独立 variant，输入窗口按其实际步数计）。
func _solver_notations(move: MoveData) -> Array[String]:
	var notations: Array[String] = []
	if move.direction_derivation != "":
		notations.append(move.direction_derivation)
	notations.append_array(move.input_alternatives)
	return notations


## 起手前需要喂入的方向序列（记法去掉末位动作键）。
func _notation_digits(notation: String) -> String:
	return notation.left(maxi(notation.length() - 1, 0))


## 记法能否由地面方向喂入表达：方向历史只产生 1/2/3/4/6。严格记法每个方向段
## 都必须是可喂数字；宽松记法的谓词集合与可喂数字有交集即可（宽松 9 的集合
## {3,6,9} 含 3/6，宽松 8 的上集合 {7,8,9} 无交集）。
func _notation_expressible(move: MoveData, notation: String) -> bool:
	for digit in _notation_digits(notation):
		if ["1", "2", "3", "4", "6"].has(digit):
			continue
		if move.lenient_command and digit != "8" and digit != "5" and digit != "0":
			continue
		return false
	return true


## 输入绑定与方向 variant：起始姿态下可执行招式的全部声明记法逐一在一次性
## CombatSession 中验证（喂方向序列 → 按键 → 前摇 → 命中）；不可表达的记法
## （含上方向段）如实报告，不静默跳过。稳定 id 序输出。
## 起始姿态下可枚举的打击招式（首招候选与绑定 variant 共用口径）：姿态与起始
## 状态一致、可由动作键起手的打击招式——投技不可单键起手；带方向记法的招式
##（地面 236C/214C 与空中 j6D/j2D，票据 08 起）按声明记法喂入方向段起手。
func _is_startable_start_stance_strike(move_id: String) -> bool:
	var move := _table.get(move_id) as MoveData
	return move != null and move.stance == _start_stance() and move.is_strike() \
		and _start_key_for(move_id) != ""


func _binding_variant_lines() -> Array[String]:
	var lines: Array[String] = []
	var ids := _table.keys()
	ids.sort()
	for move_id in ids:
		if not _is_startable_start_stance_strike(move_id):
			continue
		var move := _table[move_id] as MoveData
		var physical: String = ACTION_PHYSICAL_KEYS.get(move.action_key, move.action_key)
		var notations := _solver_notations(move)
		if notations.is_empty():
			var crouch_note := "｜蹲姿（按下时按住下方向）" if move.requires_crouch else ""
			lines.append("%s｜%s 键（%s）｜无方向指令%s" % [move_id, physical, move.action_key, crouch_note])
			continue
		for notation in notations:
			lines.append(_variant_line(move_id, move, notation, physical))
	return lines


func _variant_line(move_id: String, move: MoveData, notation: String, physical: String) -> String:
	var digits := _notation_digits(notation)
	var header := "%s｜%s 键（%s）｜variant %s（%s，%d 步，窗口 %d 帧）" % [
		move_id, physical, move.action_key, digits,
		"宽松" if move.lenient_command else "严格",
		digits.length(), digits.length() * GameParams.DIRECTION_STEP_FRAMES,
	]
	if not _notation_expressible(move, notation):
		return header + "：不可表达——方向段含上方向（7/8/9），不在地面方向喂入的可达范围"
	var link := ChainLink.new()
	link.move_id = move_id
	link.key = move.action_key
	link.feed = digits
	link.trigger = ChainLink.Trigger.START
	var compiled := _compile_chain([link])
	var run := _run_schedule(compiled, {})
	if run["ok"]:
		return header + "：验证成立——第 %d 帧按键、第 %d 帧命中" % [
			compiled["inputs"][compiled["inputs"].size() - 1].frame, run["hit_frames"][0],
		]
	return header + "：验证失败——%s" % run["reason"]


# --- 操作说明（issue 19：真实键位回放指引）---


## 操作说明分节：每个验证面向一节——面向/站位/起始头 + 键位图例 + 逐路线回放行。
## 相对方向（前/后/下）按本节面向折算成真实物理键，等待帧写明两次输入之间的空档。
func _guide_lines(report: SolverReport) -> Array[String]:
	var lines: Array[String] = []
	lines.append("【%s｜%s｜与木桩中心间距 %d px】" % [_facing_label(), _start_guide_label(), PIN_DX])
	lines.append("键位：%s" % _key_legend())
	if _is_air_start():
		lines.append("空中起始探针序：先 Space 垂直起跳 → %d 帧起跳准备 → %d 空中帧；本节路线帧号自离地后第 %d 空中帧起计" % [
			GameParams.PLAYER_PREJUMP_FRAMES, _start.air_frames, _start.air_frames + 1,
		])
	for route in report.routes:
		lines.append(_route_guide_line(route))
	for cycle in report.cycles:
		lines.append(_cycle_guide_line(cycle))
	return lines


func _facing_label() -> String:
	return "面向" + _facing_text(_facing)


func _start_guide_label() -> String:
	if _is_air_start():
		return "空中起始（第 %d 空中帧起）" % (_start.air_frames + 1)
	return "地面中立起始"


func _forward_key() -> String:
	return "D" if _facing == 1 else "A"


func _back_key() -> String:
	return "A" if _facing == 1 else "D"


func _key_legend() -> String:
	# 物理键与方向箭头成对出现（左面向下前 = A/←、后 = D/→，随面向互换）。
	var forward_arrow := "→" if _facing == 1 else "←"
	var back_arrow := "←" if _facing == 1 else "→"
	return "前=%s/%s 后=%s/%s 下=S/↓ 跳=Space 动作 U/I/K/J=A/B/C/D" % [
		_forward_key(), forward_arrow, _back_key(), back_arrow,
	]


## 一条路线的回放行：输入表逐帧转为真实键操作，帧间空档以「等 N 帧」标注；
## 动作键按下按链接顺序对应路线中的招式，方向喂入以相对方向 + 物理键双标注。
func _route_guide_line(route: SolverRoute) -> String:
	var header := "%s（%d hit · 伤害 %.1f · 命中帧 %s）" % [
		route.label(), route.combo_hits, route.total_damage, _hit_frames_text(route.hit_frames),
	]
	if route.inputs.is_empty():
		return header + "：（断链路线，无可回放输入%s）" % (("——" + route.note) if route.note != "" else "")
	return header + "：" + _replay_ops_text(route.inputs, route.move_ids)


## 一个已证明循环的逐帧回放行（与本节面向一致的真实键位）：回放截到重现对拍帧，
## 重复执行末圈即可无限延续。
func _cycle_guide_line(cycle: SolverCycle) -> String:
	return "循环逐帧回放｜%s（周期 %d 帧 · 第 %d 圈起状态重现）：%s" % [
		cycle.label(), cycle.period_frames, cycle.laps_observed,
		_replay_ops_text(cycle.inputs, _cycle_replay_move_ids(cycle)),
	]


## 输入表逐帧转为真实键操作：帧间空档以「等 N 帧」标注；动作键按下按提供的
## 招式对应表依序标注所属招式，方向喂入以相对方向 + 物理键双标注（路线与循环
## 的回放行共用同一口径，防两处漂移）。
func _replay_ops_text(inputs: Array[ScheduledInput], move_ids: Array[String]) -> String:
	var ops: Array[String] = []
	var move_idx := 0
	var prev := 0
	for spec in inputs:
		if spec.frame - prev > 1:
			ops.append("等 %d 帧" % (spec.frame - prev - 1))
		if spec.key != "":
			var move_id := move_ids[move_idx] if move_idx < move_ids.size() else ""
			move_idx += 1
			var down_mark := "↓+" if spec.down else ""
			ops.append("F%d 按 %s%s（%s）" % [spec.frame, down_mark, ACTION_PHYSICAL_KEYS.get(spec.key, spec.key), move_id])
		elif spec.jump:
			ops.append("F%d Space（起跳）" % spec.frame)
		else:
			var digit := _relative_digit(spec.axis, spec.down, _facing)
			ops.append("F%d %s[%s]" % [spec.frame, _digit_label(digit), _direction_keys(digit)])
		prev = spec.frame
	return "；".join(ops)


## 循环回放行的招式对应表：第 n 次动作键按下属于循环中第 (n-1) mod 圈长 个招式
## ——入口招式即 route[0]，其后沿回边逐圈推进，与逐圈链接的编排一致。
func _cycle_replay_move_ids(cycle: SolverCycle) -> Array[String]:
	var ids: Array[String] = []
	var presses := 0
	for spec in cycle.inputs:
		if spec.key != "":
			ids.append(cycle.route[presses % cycle.route.size()])
			presses += 1
	return ids


static func _hit_frames_text(hit_frames: Array[int]) -> String:
	return ", ".join(hit_frames.map(func(frame: int) -> String: return str(frame)))


func _digit_label(digit: int) -> String:
	match digit:
		1:
			return "↓+后"
		2:
			return "↓"
		3:
			return "↓+前"
		4:
			return "后"
		6:
			return "前"
		_:
			return "·"


## 相对方向数字对应的真实物理键（本节面向下 前/后的世界键随面向互换）。
func _direction_keys(digit: int) -> String:
	var keys: Array[String] = []
	if digit == 1 or digit == 2 or digit == 3:
		keys.append("S")
	if digit == 3 or digit == 6:
		keys.append(_forward_key())
	elif digit == 1 or digit == 4:
		keys.append(_back_key())
	return "+".join(keys)


# --- 上下文：如何从起始状态按出某招 ---

## 每个可达招式的入口接续链：起始姿态（默认地面；显式空中起始为空中）的单键
## 招式直接起手；其余姿态经配置接缝增长——空中优先经表内第一个可达 launcher 的
## jump cancel 进入，其次同姿态取消，显式落地接续把地面招式接在空中段后。
func _build_contexts() -> Dictionary:
	var contexts := {}
	var stance := _start_stance()
	for move_id in _table:
		var move := _table[move_id] as MoveData
		if move == null or move.stance != stance:
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
			if move == null or (_start_key_for(move_id) == "" and not move.rekka_only and not move.charge_only):
				continue
			var links := _context_via_jump(move_id, contexts)
			if links.is_empty():
				links = _context_via_cancel(move_id, contexts)
			if links.is_empty():
				links = _context_via_landing(move_id, contexts)
			if links.is_empty():
				links = _context_via_rekka(move_id, contexts)
			if links.is_empty():
				links = _context_via_charge(move_id, contexts)
			if links.is_empty():
				links = _context_via_air_exit(move_id, contexts)
			if not links.is_empty():
				contexts[move_id] = links
				grew = true
	return contexts


## 蓄力版目标的上下文（票据 06）：复用普通版的入口链，把其中起手普通版的
## 链接换成蓄力链接（同键按下 + 按住至阈值）——蓄力提交是唯一入口。
func _context_via_charge(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	var target := _table[move_id] as MoveData
	if target == null or not target.charge_only:
		return []
	var base := _charge_base_of(move_id)
	if base == null or not contexts.has(base.move_id):
		return []
	var links := _cloned_context_links(contexts[base.move_id])
	for i in range(links.size()):
		if links[i].move_id != base.move_id:
			continue
		var charged_link := _clone_charged_link(links[i])
		charged_link.move_id = move_id
		links[i] = charged_link
		break
	return links


## 空中出口目标的上下文（票据 07）：复用声明 air_exit 的地面前招的可达链并
## 追加出口按键链——该前招须有真实向上位移（出口只在离地后开放）。
func _context_via_air_exit(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	var target := _table[move_id] as MoveData
	if target == null or target.stance != MoveData.Stance.AIR:
		return []
	for source_id in _table:
		var source := _table[source_id] as MoveData
		if source == null or source.stance != MoveData.Stance.GROUND:
			continue
		if not (source.air_exit_targets as Array[String]).has(move_id):
			continue
		if not source.has_motion() or source.motion_y_px >= 0.0:
			continue
		if not contexts.has(source_id):
			continue
		var links: Array[ChainLink] = (contexts[source_id] as Array[ChainLink]).duplicate()
		links.append_array(_links_for_edge(source_id, move_id, EdgeKind.AIR_EXIT))
		return links
	return []


## 蓄力链接的完整克隆（改写 charged 标记前必须新建实例——上下文里的链接
## 可能与普通版上下文共享引用，原地改写会污染）。
func _clone_charged_link(link: ChainLink) -> ChainLink:
	var charged := ChainLink.new()
	charged.move_id = link.move_id
	charged.key = link.key
	charged.feed = link.feed
	charged.trigger = link.trigger
	charged.wait = link.wait
	charged.press_space = link.press_space
	charged.rekka = link.rekka
	charged.charged = true
	charged.via_text = link.via_text
	return charged


## Rekka 派生目标的上下文（票据 04）：复用首段的规范入口链，追加派生按键
## （接触后首个正常帧按下、当帧起手，无组合等待）。派生招式不作为独立起手。
func _context_via_rekka(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	var target := _table[move_id] as MoveData
	if target == null or not target.rekka_only:
		return []
	for opener_id in _table:
		var opener := _table[opener_id] as MoveData
		if opener == null or opener.rekka_window_frames < 0:
			continue
		if opener.rekka_b_target != move_id and opener.rekka_c_target != move_id:
			continue
		if not contexts.has(opener_id):
			continue
		var links: Array[ChainLink] = (contexts[opener_id] as Array[ChainLink]).duplicate()
		links.append_array(_links_for_edge(opener_id, move_id, EdgeKind.REKKA_DERIVE))
		return links
	return []


func _start_stance() -> MoveData.Stance:
	if _start != null:
		return _start.stance
	return MoveData.Stance.GROUND


func _context_via_jump(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	var target := _table[move_id] as MoveData
	if target == null or target.stance != MoveData.Stance.AIR:
		return []
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


func _context_via_cancel(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	var target := _table[move_id] as MoveData
	if target == null:
		return []
	for source_id in _table:
		var source := _table[source_id] as MoveData
		if source == null or source.stance != target.stance:
			continue
		if not (source.cancel_targets as Array[String]).has(move_id):
			continue
		if not contexts.has(source_id):
			continue
		var links: Array[ChainLink] = (contexts[source_id] as Array[ChainLink]).duplicate()
		links.append_array(_links_for_edge(source_id, move_id, EdgeKind.CANCEL))
		return links
	return []


func _context_via_landing(move_id: String, contexts: Dictionary) -> Array[ChainLink]:
	var target := _table[move_id] as MoveData
	if target == null or target.stance != MoveData.Stance.GROUND:
		return []
	for source_id in _table:
		var source := _table[source_id] as MoveData
		if source == null or source.stance != MoveData.Stance.AIR:
			continue
		if not (source.landing_cancel_targets as Array[String]).has(move_id):
			continue
		if not contexts.has(source_id):
			continue
		var links: Array[ChainLink] = (contexts[source_id] as Array[ChainLink]).duplicate()
		links.append_array(_links_for_edge(source_id, move_id, EdgeKind.LANDING_CANCEL))
		return links
	return []


# --- 接续边 ---


## Rekka 首段的派生目标集合（~B 在前、~C 在后，确定性枚举）。
func _rekka_targets_of(move: MoveData) -> Array[String]:
	var targets: Array[String] = []
	if move == null or move.rekka_window_frames < 0:
		return targets
	for target in [move.rekka_b_target, move.rekka_c_target]:
		if target != "" and not targets.has(target):
			targets.append(target)
	return targets


## 一条接续边对应的输入链接：普通取消在来源命中帧按键（方向派生先喂方向序列）；
## jump cancel 是 Space + 空中起手（延迟由搜索指定）；落地接续在预测落地帧按键。
func _links_for_edge(from_id: String, to_id: String, kind: EdgeKind) -> Array[ChainLink]:
	var links: Array[ChainLink] = []
	var key := _start_key_for(to_id)
	## 蓄力版目标（票据 06）：唯一入口是按住动作键至阈值自动提交——目标为
	## charge_only 的链接一律按蓄力编译；按下时序与普通版同键同模型（来源
	## 声明、组合等待与恢复窗口都按普通版翻译）。
	var to_move := _table.get(to_id) as MoveData
	var charged_target := to_move != null and to_move.charge_only
	var timing_target := to_move if not charged_target else _charge_base_of(to_id)
	if charged_target:
		key = timing_target.action_key
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
		EdgeKind.NORMAL_LINK:
			var link_link := ChainLink.new()
			link_link.move_id = to_id
			link_link.key = key
			link_link.feed = _feed_for(to_id)
			link_link.trigger = ChainLink.Trigger.PREV_HIT
			link_link.wait = _link_press_wait(_table[from_id] as MoveData, timing_target)
			link_link.charged = charged_target
			links.append(link_link)
		EdgeKind.REKKA_DERIVE:
			## 派生按键安排在接触后的第一个正常帧（接触当帧窗口尚未在输入阶段
			## 打开，停顿中按下同样落在恢复首个正常帧）；按下当帧起手派生。
			var derive := ChainLink.new()
			derive.move_id = to_id
			derive.key = (_table.get(to_id) as MoveData).action_key
			derive.trigger = ChainLink.Trigger.PREV_HIT
			derive.wait = 1
			derive.rekka = true
			links.append(derive)
		EdgeKind.SPECIAL_ENTRY_LINK:
			## 来源限定普通连接与普通连接同一按下模型：前招完全恢复当帧消费
			## 缓存（上下文已保证前招经来源资格起手且实际命中）。
			var entry_link := ChainLink.new()
			entry_link.move_id = to_id
			entry_link.key = key
			entry_link.feed = _feed_for(to_id)
			entry_link.trigger = ChainLink.Trigger.PREV_HIT
			entry_link.wait = _link_press_wait(_table[from_id] as MoveData, timing_target)
			entry_link.charged = charged_target
			links.append(entry_link)
		EdgeKind.AIR_EXIT:
			## 空中出口按键安排在命中后第 1 帧（停顿中采样，姿态已因位移离地转
			## AIR，缓存按空中姿态解析；恢复首个正常帧消费——与 Rekka 派生同一
			## 按下模型）。无记法的空中目标不喂方向；带记法的目标（票据 08 的
			## j6D/j2D）由 feed 喂入方向段——空中方向历史照常记录与识别。
			var exit_link := ChainLink.new()
			exit_link.move_id = to_id
			exit_link.key = key
			exit_link.feed = _feed_for(to_id)
			exit_link.trigger = ChainLink.Trigger.PREV_HIT
			exit_link.wait = 1
			links.append(exit_link)
		_:
			var cancel_link := ChainLink.new()
			cancel_link.move_id = to_id
			cancel_link.key = key
			cancel_link.feed = _feed_for(to_id)
			cancel_link.trigger = ChainLink.Trigger.PREV_HIT
			cancel_link.charged = charged_target
			links.append(cancel_link)
	return links


func _build_edge(from_id: String, to_id: String, kind: EdgeKind, contexts: Dictionary, timing_cache: Dictionary, gap_mode := false) -> SolverEdge:
	var edge := SolverEdge.new()
	edge.from_id = from_id
	edge.to_id = to_id
	edge.kind = kind
	var from_move := _table.get(from_id) as MoveData
	var to_move := _table.get(to_id) as MoveData
	if to_move == null:
		edge.reason = "目标招式不在招式表中"
		return edge
	## 蓄力变体（票据 06）：to 为 charge_only 时声明字段的检查按普通版翻译
	##（表内声明的是普通版 id），链接由 _links_for_edge 自动按蓄力编译。
	edge.charged = to_move.charge_only
	if to_move.charge_only and _charge_base_of(to_id) == null:
		edge.reason = "蓄力版缺少普通版来源（charge_move_id 入口），不能作为接续目标"
		return edge
	var declared_target := to_id if not to_move.charge_only else _charge_base_of(to_id).move_id
	match kind:
		EdgeKind.CANCEL, EdgeKind.CHAIN_CANCEL, EdgeKind.SPECIAL_CANCEL:
			if to_move.stance != from_move.stance:
				if to_move.stance == MoveData.Stance.AIR:
					edge.reason = "姿态不符：地面招式只能取消进地面目标，地面 → 空中只有配置的 jump cancel"
				else:
					edge.reason = "姿态不符：空中招式只能取消进空中目标，空中 → 地面只有显式落地接续"
				return edge
		EdgeKind.NORMAL_LINK:
			if to_move.stance == from_move.stance:
				pass
			elif from_move.stance == MoveData.Stance.AIR and to_move.stance == MoveData.Stance.GROUND:
				## 空技 → 地面的普通连接（票据 08）：连接评估延迟到攻击者完全落地
				## 恢复后的首个合法帧——同一目押语义，不借用 j2D 落地首帧例外。
				pass
			else:
				edge.reason = "姿态不符：地面招式的普通连接只连接地面目标（地面 → 空中不在普通连接范围）"
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
			# 现行规格无落地首帧例外；旧资源字段保留可读，但不是合法接续。
			# 在缺口探针中同样拒绝，不能宣称补配置就能绕过着地惩罚。
			edge.reason = "落地恢复首帧及空技恢复全程不可取消；空中招式落地作废，显式 landing_cancel_targets 不能绕过状态锁"
			return edge
		EdgeKind.HIT_LANDING_CANCEL:
			if from_move.stance != MoveData.Stance.AIR:
				edge.reason = "命中落地取消只属于空中招式（%s 是地面招式）——资格由空招实际 HIT 授予" % from_id
				return edge
			if to_move.stance != MoveData.Stance.GROUND:
				edge.reason = "命中落地取消目标必须是地面招式（落地后按地面姿态起手；%s 是空中招式）" % to_id
				return edge
			if from_move.hit_landing_cancel_window_frames < 0:
				edge.reason = "命中落地取消未声明输入缓存窗口（hit_landing_cancel_window_frames）"
				return edge
		EdgeKind.AIR_EXIT:
			if from_move.stance != MoveData.Stance.GROUND:
				edge.reason = "空中出口只属于地面招式（%s 是空中招式）——出口借用地面招式位移造成的真实离地" % from_id
				return edge
			if to_move.stance != MoveData.Stance.AIR:
				edge.reason = "空中出口目标必须是空中招式（出口按空中姿态起手；%s 是地面招式）" % to_id
				return edge
			if not from_move.has_motion() or from_move.motion_y_px >= 0.0:
				edge.reason = "空中出口前招未声明向上计划位移（motion_y_px < 0）：没有真实上升就没有离地与空中姿态，出口不成立"
				return edge
	if from_move.is_finisher:
		edge.reason = "收尾招式命中即结束连段，不开放命中确认取消"
		return edge
	if kind != EdgeKind.REKKA_DERIVE and not to_move.charge_only and _start_key_for(to_id) == "":
		edge.reason = "目标无法由动作键起手，超出本 Solver 的输入表达范围"
		return edge
	if kind == EdgeKind.REKKA_DERIVE and not to_move.rekka_only:
		edge.reason = "派生目标未声明 rekka_only，不能作为 Rekka 分支（配置校验缺口）"
		return edge
	if kind == EdgeKind.SPECIAL_ENTRY and not from_move.special_entry_targets.has(declared_target):
		edge.reason = "来源招式未声明特殊进入目标（来源资格是运行时硬约束，补配 special_entry_targets 后才成为合法边）"
		return edge
	if kind == EdgeKind.SPECIAL_ENTRY_LINK and not from_move.special_entry_link_targets.has(declared_target):
		edge.reason = "来源限定连接边未声明：普通来源起手的 %s 不取得该目押（不构成全局反向取消）" % from_id
		return edge
	var context: Array[ChainLink] = contexts.get(from_id, [] as Array[ChainLink])
	if context.is_empty():
		edge.reason = "无法从起始状态构造到达 %s 的合法上下文（起始姿态 / jump cancel / 取消 / 落地接续 / Rekka 派生链不可达）" % from_id
		return edge
	match kind:
		EdgeKind.JUMP_CANCEL:
			_fill_jump_edge(edge, context)
		EdgeKind.LANDING_CANCEL:
			_fill_landing_edge(edge, context, gap_mode)
		EdgeKind.NORMAL_LINK:
			_fill_link_edge(edge, context, contexts, timing_cache)
		EdgeKind.SPECIAL_ENTRY:
			_fill_special_entry_edge(edge, context, timing_cache, gap_mode)
		EdgeKind.SPECIAL_ENTRY_LINK:
			_fill_special_entry_link_edge(edge, contexts, timing_cache)
		EdgeKind.AIR_EXIT:
			_fill_air_exit_edge(edge, contexts, timing_cache)
		EdgeKind.HIT_LANDING_CANCEL:
			_fill_hit_landing_edge(edge, contexts, timing_cache)
		_:
			_fill_cancel_edge(edge, context, timing_cache, kind)
	if kind == EdgeKind.CHAIN_CANCEL or kind == EdgeKind.SPECIAL_CANCEL or kind == EdgeKind.REKKA_DERIVE:
		_fill_blocked_cancel_edge(edge, context)
	return edge


func _fill_cancel_edge(edge: SolverEdge, context: Array[ChainLink], timing_cache: Dictionary, kind := EdgeKind.CANCEL) -> void:
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	var window_frames := _cancel_window_for(from_move, kind)
	var timing := _source_timing(edge.from_id, context, timing_cache)
	if timing.is_empty():
		edge.reason = "起手招式未在首个判定帧命中（探针几何假设被打破）"
		return
	edge.recover_age = timing["recover_age"]
	edge.recover_truncated = timing.get("recover_truncated", false)
	var links: Array[ChainLink] = context.duplicate()
	links.append_array(_links_for_edge(edge.from_id, edge.to_id, kind))
	var run := _run_schedule(_compile_chain(links), {})
	if run["ok"]:
		edge.valid = true
		edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - timing["hit_frame"]
		if kind == EdgeKind.REKKA_DERIVE:
			## 派生按键无组合等待：接触当帧（w=0）窗口尚未在输入阶段打开，
			## 有效等待自 1 起；按下当帧起手，命中 = 等待 + 目标前摇。
			edge.wait_from = 1
			edge.wait_to = maxi(1, mini(window_frames, edge.recover_age - to_move.startup_frames))
		else:
			edge.wait_from = 0
			# 有效等待 = 取消仍在窗口内，且目标命中（等待 + 目标前摇）不晚于木桩恢复。
			# recover_age 在来源招式的规范入口上下文中测量；路线/循环里的真实可行性
			# 总是由逐帧模拟复验，这里只影响报告标注。
			## B/C 的组合等待使有效等待上界收窄（命中当帧按下 w=0 恰好消费，其余
			## 等待档需窗口容纳 +3 等待）；下限为 0——w=0 总是可用档。
			var key_wait := _single_key_wait(to_move.action_key)
			edge.wait_to = maxi(0, mini(window_frames - key_wait,
				edge.recover_age - _effective_startup_frames(to_move) - key_wait))
			if kind == EdgeKind.AIR_EXIT:
				## 空中出口的按键必须晚于命中帧：命中当帧输入阶段先于位移提交，
				## 姿态仍是地面——w=0 的按下按地面姿态解析，不构成出口。
				edge.wait_from = maxi(1, edge.wait_from)
		var prefix := ""
		if edge.charged:
			prefix = "（蓄力提交：按下后按住 %d 帧至阈值自动提交，有效前摇 %d 帧）" % [
				_charge_base_of(edge.to_id).charge_threshold_frames, _effective_startup_frames(to_move)]
		elif kind == EdgeKind.REKKA_DERIVE:
			prefix = "（Rekka 派生：首段接触起首个 %s 新按下立即锁分支 branch-locked，同帧 B+C 固定 ~C 优先；派生按键无组合等待）" % to_move.action_key
		elif to_move.direction_derivation != "":
			prefix = "（方向派生 %s：取消帧前喂入方向序列）" % to_move.direction_derivation
		elif to_move.requires_crouch:
			prefix = "（蹲姿按键：取消帧按下时按住下方向）"
		elif from_move.stance == MoveData.Stance.AIR:
			prefix = "（空中取消）"
		edge.reason = "%s有效等待 0–%d 帧 + 目标前摇 %d 帧：最早命中在命中确认后第 %d 帧，不晚于木桩恢复（第 %d 帧），余量 %d 帧%s" % [
			prefix, edge.wait_to, _effective_startup_frames(to_move), edge.hit_age, edge.recover_age, edge.recover_age - edge.hit_age,
			_recover_truncation_note(edge.recover_truncated),
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
		edge.reason = "取消追击未成立：空中目标已起手但在落地帧作废（挥空——剩余判定被落地恢复截断），未能在玩家滞空内命中（滞空资源有限，落地不授予普通取消资格）"
		return
	match run["break_kind"]:
		"whiff":
			edge.reason = "取消未成立：目标招式已起手但判定未在预期帧连接（挥空）"
		"no_start":
			if kind == EdgeKind.REKKA_DERIVE:
				edge.reason = "派生未成立（buffer-expired）：B/C 新按下未落在首段接触后 0–%d 帧派生窗口内（窗口关闭，按键不锁分支）" % window_frames
			else:
				edge.reason = "取消未成立：目标未能在取消窗口内起手（窗口关闭或缓存过期）"
		"miss_profile":
			if kind == EdgeKind.REKKA_DERIVE:
				edge.reason = "派生未成立（state-incompatible）：" + run["reason"]
			else:
				edge.reason = "取消未成立：" + run["reason"]
		"blocked":
			edge.reason = "取消未成立：" + run["reason"]
		_:
			edge.reason = "取消未成立：目标未在取消窗口内起手或命中（未观测到第二次命中）"


## 特殊进入边（票据 05，I-05）：复用取消边的逐帧验证（wait=0 试探），成功后
## 逐等待档扫描 D 命中时的目标状态，报告有效等待范围；固定钉位网格（48/64/80 px）
## 上段 1 总是先命中，不产生 GROUND_SLIDE——slide 捞起与段间真实可达性（段 1
## 挥空窗口 >91px）一律 replay-required，静态报告不冒充。
func _fill_special_entry_edge(edge: SolverEdge, context: Array[ChainLink], timing_cache: Dictionary, gap_mode := false) -> void:
	_fill_cancel_edge(edge, context, timing_cache, EdgeKind.SPECIAL_ENTRY)
	if not edge.valid:
		if edge.reason.begins_with("取消未成立") or edge.reason.begins_with("等待超时"):
			edge.reason = edge.reason.replace("取消未成立", "特殊进入未成立").replace("等待超时", "特殊进入等待超时")
		return
	if gap_mode:
		return
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	var window := _cancel_window_for(from_move, EdgeKind.SPECIAL_ENTRY)
	var states := {}
	var wait_from := -1
	var wait_to := -1
	for wait in range(window + 1):
		var links: Array[ChainLink] = context.duplicate()
		links.append_array(_links_for_edge(edge.from_id, edge.to_id, EdgeKind.SPECIAL_ENTRY))
		(links[links.size() - 1] as ChainLink).wait = wait
		var run := _run_schedule(_compile_chain(links), {})
		if run["ok"]:
			wait_to = wait
			if wait_from < 0:
				wait_from = wait
			var state: int = (run["session"] as CombatSession).dummy_state
			states[_dummy_state_text(state)] = true
		elif wait_from >= 0:
			break
	edge.wait_from = maxi(0, wait_from)
	edge.wait_to = wait_to
	var state_list: Array[String] = []
	for key in states:
		state_list.append(key)
	state_list.sort()
	edge.reason = "（特殊进入：实际 HIT 授予一次性资格，被防/挥空不开放；Hitstop 与 slide 期间资格保留，仅在授予招式的 %d 帧窗口内消费）有效等待 %d–%d 帧 + 目标前摇 %d 帧，命中时目标状态：%s；slide 捞起与段间距离（段 1 挥空需 >91px 站位）不在钉位网格内，一律 replay-required" % [
		window, edge.wait_from, edge.wait_to, to_move.startup_frames, "、".join(state_list),
	]


func _dummy_state_text(state: int) -> String:
	match state:
		CombatSession.DummyState.GROUND_HITSTUN:
			return "grounded-stun"
		CombatSession.DummyState.AIR_HITSTUN:
			return "airborne"
		CombatSession.DummyState.LOW_FLOAT_SWEEP:
			return "low-float"
		CombatSession.DummyState.LOW_FLOAT_TO_SLIDE:
			return "float-before-slide"
		CombatSession.DummyState.GROUND_SLIDE:
			return "slide"
	return "neutral"


## 来源限定普通连接（票据 05，I-05）：逐候选构造「经特殊进入到达前招」的上下文
## （授予招式直接起手的合成入口优先——对应会话验证的 solo 起手路线；其后是
## 各规范取消入口），按普通连接同一按下模型验证，首个成立者作准；缓存独立
## （来源限定上下文的 5D 命中时刻与规范上下文不同，不共享 timing 缓存）。
## 起手层显著影响目押窗口（A/B/C 起手时间层更短），规范入口全部失败时如实
## 排除——真实可行性由保留真实位置的回放证明（replay-required）。
func _fill_special_entry_link_edge(edge: SolverEdge, contexts: Dictionary, timing_cache: Dictionary) -> void:
	var candidates := _special_entry_context_candidates(edge.from_id, contexts)
	if candidates.is_empty():
		edge.reason = "无法构造经特殊进入到达 %s 的合法上下文（来源资格链不可达，该目押只能在资格来源内验证）" % edge.from_id
		return
	var via_text := ""
	for entry_context in candidates:
		_fill_link_edge(edge, entry_context, contexts, {})
		if edge.valid:
			via_text = (entry_context[entry_context.size() - 1] as ChainLink).via_text
			break
	if edge.valid:
		edge.reason = "（来源限定：仅经特殊进入起手且实际命中的 %s 取得该目押，普通来源同招无此边；%s）" % [edge.from_id, via_text] + edge.reason
	elif edge.reason.begins_with("普通连接"):
		edge.reason = edge.reason.replace("普通连接", "来源限定连接")


## 经特殊进入到达 target 的上下文候选：授予招式直接起手的合成入口在前（solo
## 起手、起手层最优），其后按表序追加各规范取消入口；每个候选都以特殊进入
## 按键链收尾。候选链自带 via_text 描述入口方式。
func _special_entry_context_candidates(move_id: String, contexts: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	var declared_entry_id := move_id
	var move := _table.get(move_id) as MoveData
	if move != null and move.charge_only:
		## 蓄力版目标（票据 06）：表内声明的是普通版 id——授予检查按普通版
		## 翻译，尾链仍按蓄力编译。
		var charge_base := _charge_base_of(move_id)
		if charge_base == null:
			return result
		declared_entry_id = charge_base.move_id
	for granter_id in _table:
		var granter := _table[granter_id] as MoveData
		if granter == null or granter.special_entry_targets.is_empty():
			continue
		if not (granter.special_entry_targets as Array[String]).has(declared_entry_id):
			continue
		var start_key := _start_key_for(granter_id)
		if start_key != "":
			var solo: Array[ChainLink] = []
			var solo_link := ChainLink.new()
			solo_link.move_id = granter_id
			solo_link.key = start_key
			solo_link.feed = _feed_for(granter_id)
			solo_link.trigger = ChainLink.Trigger.START
			solo.append(solo_link)
			solo.append_array(_entry_tail(granter_id, move_id, "%s 直接起手（%s 起手层）" % [granter_id, _grade_letter(granter.starter_grade)]))
			result.append(solo)
		if contexts.has(granter_id):
			var via: Array[ChainLink] = (contexts[granter_id] as Array[ChainLink]).duplicate()
			via.append_array(_entry_tail(granter_id, move_id, "经规范入口 %s 取消进入" % granter_id))
			result.append(via)
	return result


func _entry_tail(granter_id: String, move_id: String, via_text: String) -> Array[ChainLink]:
	var tail := _links_for_edge(granter_id, move_id, EdgeKind.SPECIAL_ENTRY)
	(tail[0] as ChainLink).via_text = via_text
	return tail


## 空中出口边（票据 07）：对空限定前招在固定钉位（木桩地面）下的 solo 上下文
## 必然 MISS_NO_PROFILE——出口的真实成立依赖「前招命中一个浮空目标」。逐候选
## 构造前招可达且实际命中的上下文：规范入口在前（表序），其后各声明接续边进入
## 前招的来源（如 2C 链式进入 6D），首个验证成立者作准；缓存独立（不同上下文的
## 命中时刻不同）。
func _fill_air_exit_edge(edge: SolverEdge, contexts: Dictionary, timing_cache: Dictionary) -> void:
	var candidates := _air_exit_context_candidates(edge.from_id, contexts)
	if candidates.is_empty():
		edge.reason = "无法构造到达 %s 且其能实际命中的合法上下文（对空限定前招在地面钉位下无命中，空中出口无从开放）" % edge.from_id
		return
	for context in candidates:
		_fill_cancel_edge(edge, context, {}, EdgeKind.AIR_EXIT)
		if edge.valid:
			var to_move := _table[edge.to_id] as MoveData
			var via_text := (context[context.size() - 1] as ChainLink).via_text
			var via_note := "对空限定前招的命中依赖浮空目标，"
			if via_text != "":
				via_note = "对空限定前招的命中依赖浮空目标——钉位探针经 %s 进入，" % via_text
			edge.reason = "（空中出口：实际 HIT 且计划位移真实离地后，命中确认窗口内按空中姿态起手 %s；%s垂直判定范围、真实穿越与真实空中距离一律 replay-required）%s" % [
				to_move.move_id, via_note, edge.reason,
			]
			return
	## 全部候选失败：对空限定前招在钉位探针内无法命中（挥空或时序），出口的
	## 真实成立依赖浮空目标——如实排除，正例由保留真实高度的回放承担。
	edge.reason = "（空中出口：前招 %s 在钉位探针内无法实际命中——对空限定资料依赖浮空目标，出口正例属 replay-required）%s" % [edge.from_id, edge.reason]


## 空中出口前招的上下文候选：规范入口在前；其后按表序追加每个声明接续边指向
## 前招且前招可实际命中的来源（链式/必杀/命中确认取消/特殊进入）。候选链自带
## via_text 描述入口方式。
func _air_exit_context_candidates(move_id: String, contexts: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	if contexts.has(move_id):
		var canonical: Array[ChainLink] = _cloned_context_links(contexts[move_id])
		(canonical[canonical.size() - 1] as ChainLink).via_text = "规范入口直接起手"
		result.append(canonical)
	for source_id in _table:
		if source_id == move_id or not contexts.has(source_id):
			continue
		var source := _table[source_id] as MoveData
		if source == null:
			continue
		for pair in [[EdgeKind.CHAIN_CANCEL, source.chain_cancel_targets],
				[EdgeKind.SPECIAL_CANCEL, source.special_cancel_targets],
				[EdgeKind.CANCEL, source.cancel_targets],
				[EdgeKind.SPECIAL_ENTRY, source.special_entry_targets]]:
			var kind: EdgeKind = pair[0]
			if not (pair[1] as Array[String]).has(move_id):
				continue
			var links: Array[ChainLink] = _cloned_context_links(contexts[source_id])
			var tail := _links_for_edge(source_id, move_id, kind)
			(tail[0] as ChainLink).via_text = "经 %s 取消进入（%s）" % [source_id, _GAP_CONFIG_FIELDS[kind]["seam"]]
			links.append_array(tail)
			result.append(links)
	return result


func _grade_letter(grade: MoveData.StarterGrade) -> String:
	match grade:
		MoveData.StarterGrade.A:
			return "A"
		MoveData.StarterGrade.B:
			return "B"
		MoveData.StarterGrade.C:
			return "C"
		MoveData.StarterGrade.D:
			return "D"
	return "?"


## 被防接触变体（票据 03）：链式/必杀配置边在「来源招式被木桩防御挡下」探针
## 中的真实结算验证。木桩按能挡住来源属性的姿态逐帧请求防御（low→蹲防，
## 其余→站防；与来源是否命中无关）。验证：来源在预期首接触帧被防
## （ATTACK_BLOCKED，绝不产生 HIT）、目标在被防取消窗口内起手；目标自身的
## 接触结果如实入注。被防不是 HIT——该变体只作时序标注，不进入路线/循环图；
## 被防安全性（指定反击、时机、距离、版边、面向）一律 replay-required。
func _fill_blocked_cancel_edge(edge: SolverEdge, context: Array[ChainLink]) -> void:
	var from_move := _table.get(edge.from_id) as MoveData
	if from_move.block_freeze_frames < 0 or from_move.block_stun_frames < 0 or from_move.block_pushback_px_s < 0.0:
		edge.blocked_reason = "来源招式未声明被防结果（默认不可被防，无全局回退）"
		return
	var guard := CombatSession.GuardPosture.STANDING
	if from_move.attack_attribute == MoveData.AttackAttribute.LOW:
		guard = CombatSession.GuardPosture.CROUCH
	var links: Array[ChainLink] = context.duplicate()
	links.append_array(_links_for_edge(edge.from_id, edge.to_id, edge.kind))
	var run := _run_blocked_probe(_compile_chain(links), guard, edge.from_id, edge.to_id)
	edge.blocked_valid = bool(run["ok"])
	edge.blocked_reason = String(run["reason"])


## 被防探针的逐帧执行：来源首个预期接触帧必须是 ATTACK_BLOCKED（无 HIT），
## 目标招式须起手；随后观测目标的自身接触（再被防/属性漏出命中/资料缺失/挥空）。
## 时间轴与 _run_schedule 同口径：按正常战斗帧推进，冻结帧以空输入步过。
func _run_blocked_probe(compiled: Dictionary, guard: int, from_id: String, to_id: String) -> Dictionary:
	if compiled.is_empty():
		return {"ok": false, "reason": "被防探针输入表冲突：同一物理帧需要两个互斥输入"}
	var inputs := {}
	for spec in compiled["inputs"]:
		inputs[spec.frame] = spec
	var hit_frames: Array[int] = compiled["hit_frames"]
	var source_contact := hit_frames[0]
	var target_contact := hit_frames[hit_frames.size() - 1]
	var to_move := _table.get(to_id) as MoveData
	var scan_end := target_contact + (to_move.active_frames if to_move != null else 6) + 12
	var session := _new_session()
	var source_blocked := false
	var target_started := false
	var outcome := ""
	var outcome_frame := -1
	var frame := 0
	var physics := 0
	while frame < scan_end and physics < 600:
		if session.hitstop_active():
			physics += 1
			session.step(FrameInput.new())
			_pin_dummy(session)
			continue
		frame += 1
		physics += 1
		var input := FrameInput.new()
		input.dummy_guard_request = guard
		if inputs.has(frame):
			input = (inputs[frame] as ScheduledInput).to_frame_input()
			input.dummy_guard_request = guard
		var events := session.step(input)
		_pin_dummy(session)
		if session.player_move_id == to_id:
			target_started = true
		for event in events:
			match event.type:
				CombatEvent.Type.ATTACK_BLOCKED:
					if not source_blocked:
						source_blocked = true
						if frame != source_contact:
							return {"ok": false, "reason": "来源招式被防发生在第 %d 帧（预期首接触帧 %d）——探针几何被打破" % [frame, source_contact]}
					elif outcome == "":
						outcome = "blocked"
						outcome_frame = frame
				CombatEvent.Type.HIT:
					if not source_blocked:
						return {"ok": false, "reason": "来源招式（%s）在防御探针中命中——%s 未挡住该属性，被防探针不成立" % [
							from_id, _guard_posture_label(guard)]}
					if outcome == "":
						outcome = "hit"
						outcome_frame = frame
				CombatEvent.Type.HIT_MISS:
					if source_blocked and outcome == "":
						outcome = "miss"
						outcome_frame = frame
	if not source_blocked:
		return {"ok": false, "reason": "来源招式未在第 %d 帧被防——防御探针未成立（几何或姿态问题）" % source_contact}
	if not target_started:
		return {"ok": false, "reason": "目标未能在被防取消窗口内起手（窗口关闭或缓存过期）"}
	if outcome == "":
		outcome = "whiff"
	var outcome_text := ""
	match outcome:
		"blocked":
			outcome_text = "再次被防"
		"hit":
			outcome_text = "命中（该姿态漏出此属性——被防取消转命中的混合起点）"
		"miss":
			outcome_text = "命中框连接但无匹配命中资料（MISS_NO_PROFILE）"
		"whiff":
			outcome_text = "判定窗口结束无接触（挥空）"
	return {"ok": true, "reason": "被防探针（%s）：来源第 %d 帧被防、目标起手并于第 %d 帧%s；被防不产生命中——安全性（反击/距离/版边/面向）replay-required" % [
		_guard_posture_label(guard), source_contact, outcome_frame, outcome_text]}


func _guard_posture_label(guard: int) -> String:
	match guard:
		CombatSession.GuardPosture.STANDING:
			return "站防"
		CombatSession.GuardPosture.CROUCH:
			return "蹲防"
		CombatSession.GuardPosture.AIR:
			return "空防"
	return "无防御"


## 各取消接缝的窗口长度（帧）：命中确认 / 链式 / 必杀 / Rekka 派生窗口独立声明。
func _cancel_window_for(move: MoveData, kind: EdgeKind) -> int:
	match kind:
		EdgeKind.CHAIN_CANCEL:
			return move.chain_cancel_window_frames
		EdgeKind.SPECIAL_CANCEL:
			return move.special_cancel_window_frames
		EdgeKind.REKKA_DERIVE:
			return move.rekka_window_frames
		EdgeKind.SPECIAL_ENTRY:
			return move.special_entry_window_frames
	return move.cancel_window_frames


## 普通连接的确定性按下档：组合等待恰在前招完全恢复当帧解除（B/C 目标），或
## 恰在恢复当帧按下（A/D 目标）——恢复当帧消费缓存，任何有效档结果一致。
## 返回 -1 表示结构性不可按下（取消窗口长度吞掉恢复前摇，无合法按下帧）。
func _link_press_wait(from_move: MoveData, to_move: MoveData) -> int:
	## 命中当帧的招式推进在停顿开始前完成（命中应用 → 同帧运动阶段末尾推进），
	## 命中 → 收招的正常帧距离是 total - startup - 1，不是 total - startup。
	var recover_gap := from_move.total_frames() - from_move.startup_frames - 1
	var key_wait := _single_key_wait(to_move.action_key)
	var press_wait := recover_gap - key_wait
	var after_cancel := 1
	if (from_move.cancel_targets as Array[String]).has(to_move.move_id):
		after_cancel = maxi(after_cancel, from_move.cancel_window_frames + 1)
	if (from_move.chain_cancel_targets as Array[String]).has(to_move.move_id):
		after_cancel = maxi(after_cancel, from_move.chain_cancel_window_frames + 1)
	if (from_move.special_cancel_targets as Array[String]).has(to_move.move_id):
		after_cancel = maxi(after_cancel, from_move.special_cancel_window_frames + 1)
	if press_wait < after_cancel or press_wait < 1:
		return -1
	return press_wait


func _fill_link_edge(edge: SolverEdge, context: Array[ChainLink], contexts: Dictionary, timing_cache: Dictionary) -> void:
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	if from_move.stance == MoveData.Stance.AIR:
		_fill_air_link_edge(edge, contexts, timing_cache)
		return
	var timing := _source_timing(edge.from_id, context, timing_cache)
	if timing.is_empty():
		edge.reason = "起手招式未在首个判定帧命中（探针几何假设被打破）"
		return
	edge.recover_age = timing["recover_age"]
	edge.recover_truncated = timing.get("recover_truncated", false)
	var press_wait := _link_press_wait(from_move, to_move)
	if press_wait < 0:
		edge.reason = "普通连接不可按下：前招恢复前的窗口被取消接缝占满（取消窗口 %d/%d/%d 帧均须先关闭），没有留给目押的按下帧" % [
			from_move.cancel_window_frames, from_move.chain_cancel_window_frames,
			from_move.special_cancel_window_frames,
		]
		return
	var links: Array[ChainLink] = context.duplicate()
	links.append_array(_links_for_edge(edge.from_id, edge.to_id, EdgeKind.NORMAL_LINK))
	var run := _run_schedule(_compile_chain(links), {})
	if run["ok"]:
		edge.valid = true
		edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - timing["hit_frame"]
		edge.wait_from = press_wait
		edge.wait_to = press_wait
		edge.reason = "普通连接（目押）：命中确认后第 %d 帧按下（组合等待 %d 帧），前招完全恢复当帧消费缓存，目标于第 %d 帧命中（恢复 + 前摇 %d 帧）；取消接缝不参与，命中以目标剩余硬直与 active 重叠另行判定" % [
			press_wait, _single_key_wait(to_move.action_key), edge.hit_age, _effective_startup_frames(to_move),
		]
		return
	var last_end: int = run["ended_reasons"][run["ended_reasons"].size() - 1] if not run["ended_reasons"].is_empty() else -1
	if run["break_kind"] == "count" \
			or (run["break_kind"] == "ended" and last_end == CombatEvent.ComboEndReason.DUMMY_RECOVERED):
		edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - timing["hit_frame"]
		edge.reason = "目押超时：前招完全恢复（第 %d 帧）晚于木桩自然受身（第 %d 帧）——目标已恢复，普通连接不成立（运行时报 LINK_FAILED/TARGET_RECOVERED）" % [
			from_move.total_frames() - from_move.startup_frames, edge.recover_age,
		]
		return
	match run["break_kind"]:
		"whiff":
			edge.reason = "普通连接未成立：目标招式已起手但判定未在预期帧连接（挥空，运行时报 LINK_FAILED/DISTANCE_INSUFFICIENT）"
		"no_start":
			edge.reason = "普通连接未成立：缓存未能在前招完全恢复当帧消费（组合等待或缓存过期）"
		"miss_profile":
			edge.reason = "普通连接未成立：" + run["reason"]
		_:
			edge.reason = "普通连接未成立：目标未在恢复后起手或命中（未观测到第二次命中）"


## 落地接缝上下文候选（票据 08）：规范入口、取消进入与空中出口进入——接缝的
## 真实可达性取决于进入高度与修正状态（同一空招在不同上下文里落地节拍与木桩
## 剩余受身都不同），逐候选探测、按首个成立者报告并注明入口。
func _landing_seam_context_candidates(move_id: String, contexts: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	if contexts.has(move_id):
		var canonical: Array[ChainLink] = _cloned_context_links(contexts[move_id])
		(canonical[canonical.size() - 1] as ChainLink).via_text = "规范入口直接起手"
		result.append(canonical)
	for source_id in _table:
		if source_id == move_id or not contexts.has(source_id):
			continue
		var source := _table[source_id] as MoveData
		if source == null:
			continue
		for pair in [[EdgeKind.CHAIN_CANCEL, source.chain_cancel_targets],
				[EdgeKind.SPECIAL_CANCEL, source.special_cancel_targets],
				[EdgeKind.CANCEL, source.cancel_targets],
				[EdgeKind.SPECIAL_ENTRY, source.special_entry_targets]]:
			var cancel_kind: EdgeKind = pair[0]
			if not (pair[1] as Array[String]).has(move_id):
				continue
			var links: Array[ChainLink] = _cloned_context_links(contexts[source_id])
			var tail := _links_for_edge(source_id, move_id, cancel_kind)
			(tail[0] as ChainLink).via_text = "经 %s 取消进入（%s）" % [source_id, _GAP_CONFIG_FIELDS[cancel_kind]["seam"]]
			links.append_array(tail)
			result.append(links)
		if (source.air_exit_targets as Array[String]).has(move_id):
			for exit_context in _air_exit_context_candidates(source_id, contexts):
				var exit_links: Array[ChainLink] = exit_context.duplicate()
				var exit_tail := _links_for_edge(source_id, move_id, EdgeKind.AIR_EXIT)
				(exit_tail[0] as ChainLink).via_text = "经 %s 空中出口进入" % source_id
				exit_links.append_array(exit_tail)
				result.append(exit_links)
	return result


## 落地锚定接缝的尾部发现运行（票据 08）：前缀链按预测帧严格复验；尾部目标
##（命中落地取消 / 空技延迟普通连接）的起手帧由真实落地结算锚定，不以按下帧
## 预测——剥离尾链的命中预测后放行预期外命中并记录。返回 _run_schedule 结果。
func _run_tail_discovery(links: Array[ChainLink], prefix_hits: int) -> Dictionary:
	var compiled := _compile_chain(links)
	if compiled.is_empty():
		return {}
	var hit_frames: Array[int] = compiled["hit_frames"]
	var hit_moves: Array[String] = compiled["hit_moves"]
	while hit_frames.size() > prefix_hits:
		hit_frames.remove_at(hit_frames.size() - 1)
		hit_moves.remove_at(hit_moves.size() - 1)
	compiled["hit_frames"] = hit_frames
	compiled["hit_moves"] = hit_moves
	return _run_schedule(compiled, {"unpredicted_tail": true, "tail_frames": 90})


## 空技延迟普通连接（票据 08：j6D → 5B）：空招命中后攻击者完成普通落地恢复，
## 恢复后的首个合法帧按缓存消费声明目标——重新检查目标剩余硬直、姿态与
## active 重叠，不借用 j2D 例外、不跳过落地首帧锁。消费帧由真实落地结算锚定，
## 探针扫描按下档（命中确认后第 w 正常帧按下），收集全部有效档为等待区间。
func _fill_air_link_edge(edge: SolverEdge, contexts: Dictionary, timing_cache: Dictionary) -> void:
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	var key := _start_key_for(to_move.move_id)
	var feed := _feed_for(to_move.move_id)
	var wait_from := -1
	var wait_to := -1
	var hit_age := -1
	var end_reason_text := ""
	var via_text := ""
	for context in _landing_seam_context_candidates(edge.from_id, contexts):
		var timing := _source_timing(edge.from_id, context, timing_cache)
		if timing.is_empty():
			continue
		var prefix_compiled := _compile_chain(context)
		if prefix_compiled.is_empty():
			continue
		var prefix_hits: int = (prefix_compiled["hit_frames"] as Array).size()
		for w in range(1, 46):
			var links: Array[ChainLink] = context.duplicate()
			var press := ChainLink.new()
			press.move_id = to_move.move_id
			press.key = key
			press.feed = feed
			press.trigger = ChainLink.Trigger.PREV_HIT
			press.wait = w
			links.append(press)
			var run := _run_tail_discovery(links, prefix_hits)
			if run.is_empty():
				continue
			if end_reason_text == "" and not run["ok"] and run["break_kind"] != "":
				end_reason_text = run["reason"]
			var extras: Array[String] = run["extra_hit_moves"]
			var extra_counts: Array[int] = run["extra_hit_counts"]
			var continues_combo := not extra_counts.is_empty() and extra_counts[extra_counts.size() - 1] == prefix_hits + 1
			if run["ok"] and not extras.is_empty() and extras[extras.size() - 1] == to_move.move_id and continues_combo:
				if wait_from < 0:
					wait_from = w
					edge.recover_age = timing["recover_age"]
					edge.recover_truncated = timing.get("recover_truncated", false)
					if not context.is_empty():
						via_text = (context[context.size() - 1] as ChainLink).via_text
				wait_to = w
				var frames: Array[int] = run["extra_hit_frames"]
				hit_age = frames[frames.size() - 1] - timing["hit_frame"]
		if wait_from >= 0:
			break
	if wait_from < 0:
		edge.reason = "空技延迟普通连接未成立：" + (end_reason_text if end_reason_text != "" else "全部进入上下文的目标都未在落地恢复后的消费帧以合法接续起手或命中（剩余受身/落地节拍不满足）")
		return
	edge.valid = true
	edge.wait_from = wait_from
	edge.wait_to = wait_to
	edge.hit_age = hit_age
	edge.reason = "普通连接（空技落地延迟，票据 08）：命中确认后第 %d–%d 帧按下（组合等待 %d 帧），攻击者完成普通落地恢复（基础 %d + 空技惩罚 %d + 显式 %d 帧）后的首个合法帧消费缓存，目标于第 %d 帧实际命中（%s）——不产生取消年龄、不跳过落地首帧锁，命中以目标剩余硬直、姿态与 active 重叠另行判定" % [
		wait_from, wait_to, _single_key_wait(to_move.action_key),
		GameParams.PLAYER_LANDING_RECOVERY_BASE_FRAMES,
		GameParams.PLAYER_AIR_ATTACK_LANDING_PENALTY_FRAMES,
		from_move.extra_landing_recovery_frames, hit_age,
		via_text if via_text != "" else "规范入口直接起手",
	]


## j2D 命中落地取消（票据 08，L-01）：来源空招实际 HIT 授予一次性资格；目标
## 输入在命中后按下（Hitstop 中同样可缓存——专用槽、正常帧计龄），落地首帧
## 统一锁保持，落地事件后的首个可行动帧由例外消费并清除资格（跳过其余空技
## 恢复，仅限声明目标）。消费帧由真实落地结算锚定，探针按尾部发现验证。
func _fill_hit_landing_edge(edge: SolverEdge, contexts: Dictionary, timing_cache: Dictionary) -> void:
	var from_move := _table[edge.from_id] as MoveData
	var to_move := _table[edge.to_id] as MoveData
	var key := _start_key_for(to_move.move_id)
	var feed := _feed_for(to_move.move_id)
	var window := from_move.hit_landing_cancel_window_frames
	var best_run := {}
	var best_wait := -1
	var best_timing := {}
	var best_via := ""
	var end_reason_text := ""
	var any_context := false
	for context in _landing_seam_context_candidates(edge.from_id, contexts):
		var timing := _source_timing(edge.from_id, context, timing_cache)
		if timing.is_empty():
			continue
		any_context = true
		var prefix_compiled := _compile_chain(context)
		if prefix_compiled.is_empty():
			continue
		var prefix_hits: int = (prefix_compiled["hit_frames"] as Array).size()
		for w in range(1, maxi(2, window - feed.length() + 2)):
			var links: Array[ChainLink] = context.duplicate()
			var press := ChainLink.new()
			press.move_id = to_move.move_id
			press.key = key
			press.feed = feed
			press.trigger = ChainLink.Trigger.PREV_HIT
			press.wait = w
			links.append(press)
			var run := _run_tail_discovery(links, prefix_hits)
			if run.is_empty():
				continue
			if end_reason_text == "" and not run["ok"] and run["break_kind"] != "":
				end_reason_text = run["reason"]
			var extras: Array[String] = run["extra_hit_moves"]
			var extra_counts: Array[int] = run["extra_hit_counts"]
			var continues_combo := not extra_counts.is_empty() and extra_counts[extra_counts.size() - 1] == prefix_hits + 1
			if run["ok"] and not extras.is_empty() and extras[extras.size() - 1] == to_move.move_id and continues_combo:
				best_run = run
				best_wait = w
				best_timing = timing
				if not context.is_empty():
					best_via = (context[context.size() - 1] as ChainLink).via_text
				break
		if best_wait >= 0:
			break
	if not any_context:
		edge.reason = "无法从起始状态构造到达 %s 的合法上下文（空中取消 / jump cancel / 空中出口链不可达）" % edge.from_id
		return
	if best_wait < 0:
		edge.reason = "命中落地取消未成立：" + (end_reason_text if end_reason_text != "" else "全部进入上下文的目标都未在例外消费帧以合法接续起手或命中（资格/缓存/落地节拍或木桩可追击性不满足）")
		return
	edge.recover_age = best_timing["recover_age"]
	edge.recover_truncated = best_timing.get("recover_truncated", false)
	var extra_frames: Array[int] = best_run["extra_hit_frames"]
	edge.valid = true
	edge.wait_from = best_wait
	edge.wait_to = best_wait
	edge.hit_age = extra_frames[extra_frames.size() - 1] - best_timing["hit_frame"]
	edge.reason = "命中落地取消（票据 08，L-01）：%s 实际 HIT 授予一次性资格；%s 于命中确认后第 %d 帧起喂入（停顿中同样可缓存——专用槽、正常帧计龄、窗口 %d 帧），落地首帧统一锁保持，落地事件后的首个可行动帧例外消费并清除资格（跳过其余空技恢复），目标于第 %d 帧实际命中（%s）——例外仅对本声明目标开放，挥空/被防/缺失 profile/命中前预存不适用" % [
		edge.from_id, edge.to_id, best_wait, window, edge.hit_age,
		best_via if best_via != "" else "规范入口直接起手",
	]


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


func _fill_landing_edge(edge: SolverEdge, context: Array[ChainLink], gap_mode := false) -> void:
	var followup_idx := -1
	for i in range(context.size()):
		if context[i].trigger == ChainLink.Trigger.JUMP_FRAME:
			followup_idx = i
			break
	if followup_idx < 0:
		if _is_air_start():
			edge.reason = "显式空中起始暂不验证落地接缝：临界对齐搜索依赖 jump cancel 进入的空中段（属后续路线分析范围）；地面起始的默认分析覆盖该接缝"
		else:
			edge.reason = "落地接续上下文不包含 jump cancel 空中段（探针构造失败）"
		return
	## 来源空中招式在上下文中的进入链：经空中取消进入（PREV_HIT，如 jA → jB 的
	## jB）或经 jump cancel 直接进入（JUMP_FRAME，如首个空中起手 jA）——后者的
	## 进入链就是空中起手链本身，对齐只调起手延迟一维。
	var from_link_idx := -1
	var from_is_jump_entry := false
	for i in range(context.size()):
		if context[i].move_id == edge.from_id and context[i].trigger == ChainLink.Trigger.PREV_HIT:
			from_link_idx = i
	if from_link_idx < 0:
		for i in range(context.size()):
			if context[i].move_id == edge.from_id and context[i].trigger == ChainLink.Trigger.JUMP_FRAME:
				from_link_idx = i
				from_is_jump_entry = true
	if from_link_idx < 0:
		edge.reason = "落地接续上下文不包含来源空中招式的进入链（探针构造失败）"
		return
	## 来源空中招式的命中序号：Space 链接不产生命中，按有招式的链接计数。
	var from_hit_idx := -1
	for i in range(context.size()):
		if context[i].move_id != "":
			from_hit_idx += 1
	var seam := LandingSeam.new()
	seam.context = context
	seam.followup_idx = followup_idx
	seam.from_link_idx = from_link_idx
	seam.from_is_jump_entry = from_is_jump_entry
	seam.from_hit_idx = from_hit_idx
	if gap_mode:
		_fill_landing_gap(edge, seam)
		return
	## issue 15 起临界帧对齐（命中恰在落地帧当帧）需要同时延迟空中起手与取消
	## 等待——起跳准备占用 4 个正常帧后，单靠起手延迟不足以把命中压回落地帧
	## （木桩浮空硬直先耗尽）；jump cancel 直接进入的来源只有起手延迟一维。
	var valid_trials := []
	var latest_hit_trial := {}
	for d in range(0, MAX_AIR_DELAY + 1):
		for v in _landing_delay_waits(seam):
			var compiled := _compile_chain(_landing_trial_links(seam, d, v, edge.from_id, edge.to_id))
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


## 落地对齐搜索的取消等待维度：经空中取消进入的来源有两维（空中起手延迟 d、
## 取消等待 v）；jump cancel 直接进入的来源只有起手延迟一维（v 恒 0）。
func _landing_delay_waits(seam: LandingSeam) -> Array[int]:
	var v_values: Array[int] = []
	if seam.from_is_jump_entry:
		v_values.append(0)
		return v_values
	for v in range(GameParams.CANCEL_WINDOW_FRAMES + 1):
		v_values.append(v)
	return v_values


## 一次落地对齐试验的完整输入链：上下文副本 + 指定的起手延迟 d 与（经空中取消
## 进入时的）取消等待 v + 落地接续键（落地前一帧按下，落地帧消费）。
func _landing_trial_links(seam: LandingSeam, d: int, v: int, from_id: String, to_id: String) -> Array[ChainLink]:
	var context := seam.context
	var links: Array[ChainLink] = context.duplicate()
	links[seam.followup_idx] = _clone_link_with_wait(context[seam.followup_idx], 1 + d)
	if not seam.from_is_jump_entry:
		links[seam.from_link_idx] = _clone_link_with_wait(context[seam.from_link_idx], v)
	links.append_array(_links_for_edge(from_id, to_id, EdgeKind.LANDING_CANCEL))
	return links


## 缺口模式的落地接缝验证（issue 20）：按「预测对齐 lead＝落地帧 − 来源命中帧」
## 把 (d, v) 候选分桶（只有 0..取消窗口内的 lead 可能在落地帧开放接续），lead
## 升序、档内按取消等待 v 升序（v 越小取消窗口余量越大）逐一完整模拟——首个
## 成立的档位即证明「若配置则时序成立」。同档候选的行为等价性没有先验保证，
## 因此不做代表抽样（漏报一个真实缺口违背缺口枚举的目的）；唯一剪枝是算术
## 必败的取消等待（v 超过 取消窗口 − 组合等待，与正式边 wait_to 同式）。不搜索
## 完整对齐范围（align 范围是正式边的报告内容）。
func _fill_landing_gap(edge: SolverEdge, seam: LandingSeam) -> void:
	var from_move := _table[edge.from_id] as MoveData
	## 来源取消等待的算术上界：消费年龄 = v + 组合等待 须落在取消窗口内。
	var max_wait: int = from_move.cancel_window_frames - _single_key_wait(from_move.action_key)
	var buckets := {}
	for d in range(0, MAX_AIR_DELAY + 1):
		for v in _landing_delay_waits(seam):
			if v > max_wait:
				continue
			var compiled := _compile_chain(_landing_trial_links(seam, d, v, edge.from_id, edge.to_id))
			if compiled.is_empty():
				continue
			var lead: int = compiled["land_frame"] - compiled["hit_frames"][seam.from_hit_idx]
			if lead < 0 or lead > from_move.cancel_window_frames:
				continue
			if not buckets.has(lead):
				buckets[lead] = []
			(buckets[lead] as Array).append([d, v])
	var leads := buckets.keys()
	leads.sort()
	for lead in leads:
		var candidates: Array = buckets[lead]
		candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		for pair in candidates:
			var run := _run_schedule(_compile_chain(_landing_trial_links(seam, pair[0], pair[1], edge.from_id, edge.to_id)), {})
			if run["ok"]:
				edge.valid = true
				edge.hit_age = run["hit_frames"][run["hit_frames"].size() - 1] - run["hit_frames"][seam.from_hit_idx]
				edge.align_from = lead
				edge.align_to = lead
				edge.align_inputs = run["compiled"]["inputs"]
				return


func _clone_link_with_wait(link: ChainLink, wait: int) -> ChainLink:
	var clone := ChainLink.new()
	clone.move_id = link.move_id
	clone.key = link.key
	clone.trigger = link.trigger
	clone.wait = wait
	clone.press_space = link.press_space
	clone.feed = link.feed
	clone.rekka = link.rekka
	return clone


## 单招探针：起手命中帧与木桩恢复年龄（可追击的最后一帧相对命中的年龄），按上下文进入。
## 年龄按正常战斗帧计：命中后的 Hitstop 冻结帧以空输入步过、不占正常帧号。
## 恢复观测上限自命中帧起算（issue 21）：观察「命中后多少帧恢复」而非会话启动后
## 240 帧——长上下文里的正常恢复不会被误判为截断；上限内未自然受身时按截断观测
## 如实标注（truncated），恢复年龄是截断值而非实测恢复。
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
			while frame < hit_frame + RECOVER_HORIZON:
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
			timing = {
				"hit_frame": hit_frame,
				"recover_age": RECOVER_HORIZON if recover_age == -1 else recover_age,
				"recover_truncated": recover_age == -1,
			}
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
	var facing := _facing
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
		## 蹲姿招式（requires_crouch）的按下帧携带下方向：会话按当帧输入状态
		## 招式，不携带则同名站立变体胜出（票据 02）。
		var press_down := false
		if link.move_id != "":
			var pressed_move := _table.get(link.move_id) as MoveData
			press_down = pressed_move != null and pressed_move.requires_crouch
		if not _merge_input(inputs, press, 0, press_down, link.press_space, link.key):
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
			var key_wait := _single_key_wait(link.key)
			var start_delay := 0
			if link.rekka:
				## Rekka 派生按键被派生仲裁器直接消费（优先于 B+C 组合等待）：
				## 按下当帧锁分支并起手，无 +3 等待（票据 04）。
				start_delay = 0
			elif key_wait == 0:
				## 落地接续的起手帧是落地帧本身（前一帧按下、落地帧消费起手）。
				## B/C 落地目标（现无此数据）的等待使落地帧消费不可达——按下方
				## +3 模型预测的帧不会命中，逐帧复验会如实判该边无效。
				start_delay = 1 if link.trigger == ChainLink.Trigger.LAND_FRAME else 0
			elif link.trigger == ChainLink.Trigger.PREV_HIT and link.wait == 0:
				## B/C 是投组合成员键（表内含 BC 投，issue 17）：命中当帧按下的单键
				## 其组合等待与随后的停顿重叠——恢复首个正常帧即按单键消费。
				start_delay = 1
			else:
				## 其余场景按下时不再有停顿在身前，+3 物理帧等待全额计入正常帧。
				start_delay = key_wait
			## 蓄力版链接（票据 06）：按下帧起持续按住（不重按）至提交帧——
			## 按住帧覆盖组合等待与延长 startup，恰好到达 max(前摇-1, 阈值)；
			## 提交后首个判定帧 = 有效前摇（_effective_startup_frames）。
			var startup_frames := move.startup_frames
			if link.charged:
				var charge_base := _charge_base_of(link.move_id)
				if charge_base == null:
					return {}
				var extend_to := maxi(charge_base.startup_frames - 1, charge_base.charge_threshold_frames)
				for hold_frame in range(press + 1, press + start_delay + extend_to + 1):
					_merge_held(inputs, hold_frame, link.key)
				startup_frames = extend_to + 1
			last_hit = press + start_delay + startup_frames
			hit_frames.append(last_hit)
			hit_moves.append(link.move_id)
			## 多段招式（票据 05）：钉位网格上每段都按自身 active 首帧命中，逐段
			## 追加预期命中帧（段间隔在正常帧口径下不含停顿——停顿由运行时冻结，
			## 探针逐帧复验真实结算）。
			for seg in range(1, move.segment_count()):
				last_hit += move.segment_active_from(seg) - move.segment_active_from(seg - 1)
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
		scheduled.held_key = spec.get("held", "")
		specs.append(scheduled)
	return { "inputs": specs, "hit_frames": hit_frames, "hit_moves": hit_moves, "jump_frame": jump_frame, "land_frame": land_frame }


## 蓄力按住帧（票据 06）：不与新按下冲突——只写入按住键，轴/下方向/跳跃照常
## 与其他输入合并；同帧另一键的新按下照常保留。
func _merge_held(inputs: Dictionary, frame: int, held_key: String) -> void:
	if not inputs.has(frame):
		inputs[frame] = { "axis": 0, "down": false, "jump": false, "key": "", "held": held_key }
		return
	var spec: Dictionary = inputs[frame]
	if spec.get("held", "") == "":
		spec["held"] = held_key


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
## 第 N 次命中（循环起点）快照影响未来结算的会话状态（CombatSession.settlement_state，
## issue 21 全量键），快照完全重现即证明循环可无限重复。
## 时间轴口径（issue 14 起）：输入表与预期命中帧都按正常战斗帧编排——命中后的
## 8 帧 Hitstop 由会话冻结，探针以空输入跳过、不占用正常帧号；因此取消等待、
## 命中年龄与回放帧全部与规格的正常帧语义一致。观测上限按物理帧计（含冻结帧）。
func _run_schedule(compiled: Dictionary, opts: Dictionary) -> Dictionary:
	_profile_count_run()
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
	## 尾部发现（票据 08）：落地锚定接缝（命中落地取消 / 空技延迟普通连接）的
	## 起手帧由真实落地结算决定，编译器无法按下帧预测——前缀仍按预测帧严格
	## 复验，验证完前缀后放行预期外命中并记录帧号与招式，供边报告读取。
	var unpredicted_tail := bool(opts.get("unpredicted_tail", false))
	var tail_frames := int(opts.get("tail_frames", 0))
	var extra_hit_frames: Array[int] = []
	var extra_hit_moves: Array[String] = []
	var extra_hit_counts: Array[int] = []
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
	while frame < last_frame + tail_frames:
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
				## 失败断点分类（issue 20）：目标招式已起手但判定未连接＝挥空；
				## 目标从未起手＝取消窗口关闭或缓存过期，与挥空区分。
				## 命中资料（上下文命中资料规格）：命中框已连接但目标状态 × 命中
				## 上下文无匹配 profile＝MISS_NO_PROFILE，与挥空/窗口关闭三分；
				## 木桩普通倒地期间的打击一律不命中。
				var expected_move: String = hit_moves[verified]
				var miss_profile := false
				var blocked_contact := false
				for event in events:
					if event.type == CombatEvent.Type.HIT_MISS:
						miss_profile = true
					elif event.type == CombatEvent.Type.ATTACK_BLOCKED:
						blocked_contact = true
				if blocked_contact:
					break_kind = "blocked"
					break_reason = "第 %d 招（%s）在预期帧（第 %d 帧）被木桩防御挡下（BLOCKED）——被防是独立接触结果，不产生命中" % [
						verified + 1, expected_move, frame,
					]
				elif miss_profile:
					break_kind = "miss_profile"
					break_reason = "第 %d 招（%s）命中框已连接但目标状态 × 命中上下文无匹配 HitProfile（MISS_NO_PROFILE）——缺失不回退，不借用其他状态的资料" % [
						verified + 1, expected_move,
					]
				elif session.player_move_id == expected_move:
					break_kind = "whiff"
					break_reason = "第 %d 招（%s）已起手但未在预期帧（第 %d 帧）命中——挥空" % [
						verified + 1, expected_move, frame,
					]
				else:
					break_kind = "no_start"
					break_reason = "第 %d 招（%s）未能在第 %d 帧前起手——取消窗口关闭或缓存过期" % [
						verified + 1, expected_move, frame,
					]
				if session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
					break_reason += "——木桩处于普通倒地，倒地期间任何打击都不命中"
				break
			var event_hits := 0
			for event in events:
				if event.type == CombatEvent.Type.HIT:
					event_hits = event.combo_hits
			if event_hits != verified + 1:
				break_reason = "第 %d 次命中的连段计数为 %d（预期 %d）——木桩已自然受身、连段被重新计数，链条已断" % [
					verified + 1, event_hits, verified + 1,
				]
				break_kind = "count"
				break
			verified += 1
			if snapshot_every > 0 and (verified - 1) % snapshot_every == 0:
				laps_observed = (verified - 1) / snapshot_every + 1
				var state := session.settlement_state()
				for previous in snapshots:
					if previous[1] == state:
						proven_period = frame - previous[0]
						break
				if proven_period > 0:
					break
				snapshots.append([frame, state])
		elif hit_now:
			if unpredicted_tail and verified >= total:
				extra_hit_frames.append(frame)
				extra_hit_moves.append(session.player_move_id)
				var extra_count := 0
				for event in events:
					if event.type == CombatEvent.Type.HIT:
						extra_count = event.combo_hits
				extra_hit_counts.append(extra_count)
			else:
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
		"extra_hit_frames": extra_hit_frames,
		"extra_hit_moves": extra_hit_moves,
		"extra_hit_counts": extra_hit_counts,
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
		elif link.charged:
			links.append(_clone_charged_link(link))
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
		_profile_enter(_PROFILE_DELAY)
		var base_run := _run_schedule(_compile_chain(links), opts)
		_profile_exit()
		return base_run
	var size := maxi(1, delays_per_lap)
	var delays: Array[int] = []
	for i in range(size):
		delays.append(0)
	if opts.get("snapshot_every", 0) == 0 and opts.get("delay_budget", 0) == 0:
		opts["delay_budget"] = MAX_ROUTE_DELAY_TRIALS
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
	## 路线模式（snapshot_every == 0）的延迟向量预算按叶子回放计数：预算经 opts
	## 回写共享（局部副本会让「至多 64 个延迟向量」永不生效——空中取消链上的
	## 失败路线会枚举整棵延迟笛卡尔积）；循环证明模式不受预算限制。
	var proof_mode: bool = opts.get("snapshot_every", 0) > 0
	if depth == delays.size():
		if not proof_mode:
			var remaining: int = opts.get("delay_budget", 0)
			if remaining <= 0:
				return {"ok": false, "break_kind": "budget", "verified": -1, "proven_period": 0}
			opts["delay_budget"] = remaining - 1
		for j in range(adjustable.size()):
			## JUMP_FRAME 的 wait 1 = 离地后首个可按空中键帧（issue 15 起跳准备）；
			## PREV_HIT 取消的 wait 0 = 命中确认当帧消费——两者都从最早的合法
			## 等待起按字典序搜索。
			var base := 1 if links[adjustable[j]].trigger == ChainLink.Trigger.JUMP_FRAME else 0
			links[adjustable[j]].wait = base + delays[j % delays.size()]
		_profile_enter(_PROFILE_DELAY)
		var leaf_run := _run_schedule(_compile_chain(links), opts)
		_profile_exit()
		return leaf_run
	## 循环证明模式只有「逐圈状态快照重现」才算成功——链条走完但未重现的
	## 延迟向量不提前停止搜索（issue 21：另一组延迟可能完成证明）；
	## 路线模式保持首条完整成立即返回。
	var best := {}
	for d in range(0, caps[depth] + 1):
		delays[depth] = d
		var run := _delay_dfs(links, adjustable, caps, delays, depth + 1, opts)
		if run["proven_period"] > 0 or (run["ok"] and not proof_mode):
			return run
		if not run.is_empty() and (best.is_empty() or _run_ranks_higher(run, best)):
			best = run
		if not proof_mode and opts.get("delay_budget", 0) <= 0:
			return best
	return best


## 失败运行的代表性排序：观测截断（链条在帧数上限处仍成立）优先于断链——它是
## 更强的「未证明但未断」证据，避免把某组延迟下的截断误述为另一组的断链；
## 同类再按已验证命中数取走得更远者。
func _run_ranks_higher(run: Dictionary, best: Dictionary) -> bool:
	var run_truncated: bool = run.get("break_kind", "") == "horizon"
	var best_truncated: bool = best.get("break_kind", "") == "horizon"
	if run_truncated != best_truncated:
		return run_truncated
	return run["verified"] > best["verified"]


# --- 路线 ---


func _walk_routes(node_id: String, path: Array[String], adj: Dictionary, routes: Array[SolverRoute], contexts: Dictionary, edge_kinds: Dictionary) -> void:
	var extended := false
	if adj.has(node_id) and path.size() < MAX_ROUTE_NODES:
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


## 路线的单次完整模拟：入口上下文 + 逐边接续链，空中段延迟逐向量搜索（每次
## 取消都在命中确认当帧 w=0 消费，落地接续键压在预测的落地帧上）。空间复验
## （issue 22）换钉位间距后复用同一入口——timing 与 spatial 两层结论出自
## 同一套真实结算。
func _route_run(route_ids: Array[String], contexts: Dictionary, edge_kinds: Dictionary) -> Dictionary:
	var context: Array[ChainLink] = contexts.get(route_ids[0], [])
	if context.is_empty():
		return _empty_run("路线起点 %s 无合法入口上下文" % route_ids[0])
	var links := _cloned_context_links(context)
	for i in range(1, route_ids.size()):
		var kind: EdgeKind = edge_kinds.get("%s|%s" % [route_ids[i - 1], route_ids[i]], EdgeKind.CANCEL)
		links.append_array(_links_for_edge(route_ids[i - 1], route_ids[i], kind))
	var adjustable := _adjustable_indices(links)
	return _delay_search(links, adjustable, adjustable.size(), {})


## 路线对象构造：单次模拟结果转为可读路线——完全成立记 timing_valid 并携带
## 逐帧输入/命中/伤害；中途断链则截断到已验证前缀并用注记说明断点。
func _simulate_route(route_ids: Array[String], contexts: Dictionary, edge_kinds: Dictionary) -> SolverRoute:
	var route := SolverRoute.new()
	route.move_ids = route_ids.duplicate()
	var run := _route_run(route_ids, contexts, edge_kinds)
	if run["ok"]:
		route.timing_valid = true
		route.hit_frames = run["hit_frames"]
		route.inputs = run["compiled"]["inputs"]
		route.combo_hits = run["session"].combo_hits
		route.total_damage = run["session"].combo_total_damage
		if not run["ended_reasons"].is_empty():
			var last_end: int = run["ended_reasons"][run["ended_reasons"].size() - 1]
			if last_end == CombatEvent.ComboEndReason.FINISHER:
				route.note = "收尾结束路线，保留木桩受击/倒地处理"
			elif last_end == CombatEvent.ComboEndReason.KNOCKDOWN:
				route.note = "普通倒地结束路线，倒地期间不可追击，计时结束自然恢复"
	else:
		route.timing_valid = false
		var verified: int = run["verified"]
		route.move_ids = route_ids.slice(0, verified)
		route.note = "路线在第 %d 招后断开（%s），路线在此截断" % [mini(verified + 1, route_ids.size()), run["reason"]]
	return route


# --- 空间分层（issue 22：timing-valid 之上的可选空间证明）---


## 逐条复验 timing-valid 路线：换入 48/64/80 px 钉位（本面向）重跑同一套逐帧
## 结算——命中框与身体矩形的相交由真实 CombatSession 判定。时序未成立的路线
## 不作空间复验（时序失败不标作空间失败）；失败按站位记录，面向镜像由
## solve() 的签名对拍保证，不按面向重复罗列。
func _verify_routes_spatial(report: SolverReport, contexts: Dictionary, edge_kinds: Dictionary) -> void:
	for route in report.routes:
		if not route.timing_valid:
			continue
		var failures: Array[String] = []
		for distance in SPATIAL_PROBE_DISTANCES:
			_pin_dx = distance
			var run := _route_run(route.move_ids, contexts, edge_kinds)
			if not run["ok"]:
				failures.append("%d px：%s" % [distance, _spatial_failure_text(run)])
		_pin_dx = PIN_DX
		route.spatial_state = SolverRoute.SpatialState.VALID if failures.is_empty() \
			else SolverRoute.SpatialState.INVALID
		route.spatial_failures = failures


## 空间失败的具体条件：挥空＝招式已起手但命中框未与木桩身体矩形相交（站位
## 太远，碰撞条件不成立）；其余断链如实附原始原因——站位已点名，不把它
## 伪装成碰撞 miss。
func _spatial_failure_text(run: Dictionary) -> String:
	if run["break_kind"] == "whiff":
		return "第 %d 招（%s）已起手但命中框未与木桩身体矩形相交（碰撞条件不成立）" % [
			run["verified"] + 1, run["next_expected_move"],
		]
	return "该站位复验断链（%s）" % run["reason"]


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
## （每圈同一组空中延迟），每圈回到起点招式命中时快照影响未来结算的会话状态
## （CombatSession.settlement_state 全量键，issue 21）；快照完全重现才上报为
## 有效循环。空中延迟逐向量搜索——只有存在一组延迟使链条逐圈不断，循环才成立
## （有限滞空资源的回边在此被区分出来）。观测上限达到时按截断/未完成观测如实
## 上报，不宣称完整证明。
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
	if run.get("proven_period", -1) > 0:
		cycle.outcome = SolverCycle.Outcome.PROVEN
		cycle.proven = true
		cycle.period_frames = run["proven_period"]
		cycle.laps_observed = run["laps_observed"]
		cycle.start_text = _cycle_start_text(cycle_ids[0])
		cycle.inputs = _proof_inputs(run)
		cycle.reason = "证明成立——逐圈模拟中影响未来结算的会话状态在第 %d 圈起点与更早一圈完全重现（周期 %d 帧），循环可无限重复；每圈由真实命中重建受击/浮空资源，无自然受身断点" % [
			cycle.laps_observed, cycle.period_frames,
		]
		return cycle
	cycle.laps_observed = run.get("laps_observed", 0)
	if run.get("break_kind", "") == "horizon":
		## 帧数上限先于 8 圈对拍到达：链条仍成立但观测被截断——不当作有效循环上报，
		## 也不用「断链」误述（这与逐圈断链是两种情形）。
		cycle.outcome = SolverCycle.Outcome.HORIZON_TRUNCATED
		cycle.reason = "观测截断：达到 %d 帧观测上限时链条仍成立（已验证 %d 次预期命中），未完成 %d 圈逐圈状态重现对拍——不宣称完整证明（周期过长时可提高帧数上限复验）" % [
			MAX_CYCLE_FRAMES, run.get("verified", 0), MAX_CYCLE_LAPS,
		]
		return cycle
	if run.get("ok", false):
		## 8 圈全部预期命中成立、链条未断，但逐圈状态快照未重现：循环性未获证明。
		cycle.outcome = SolverCycle.Outcome.LAPS_EXHAUSTED
		cycle.reason = "未完成观测：%d 圈内每次预期命中均成立、链条未断，但逐圈会话状态快照未在观测范围内重现——不宣称完整证明（不能排除状态依赖未建模差异，可提高圈数上限复验）" % MAX_CYCLE_LAPS
		return cycle
	cycle.outcome = SolverCycle.Outcome.BROKEN
	cycle.reason = run.get("reason", "逐圈模拟中断链")
	return cycle


## 循环起始状态说明：分析起点（缺省/显式）与入口招式的真实键位起手方式。
func _cycle_start_text(start_id: String) -> String:
	var move := _table.get(start_id) as MoveData
	if move == null:
		return "入口 %s 不在招式表中" % start_id
	var key: String = ACTION_PHYSICAL_KEYS.get(move.action_key, move.action_key)
	var entry := "%s 键（%s）起手" % [key, move.action_key]
	if move.direction_derivation != "":
		entry = "方向 %s + %s 键（%s）起手" % [
			move.direction_derivation.left(move.direction_derivation.length() - 1), key, move.action_key,
		]
	if _is_air_start():
		return "显式空中起始（自第 %d 空中帧），入口 %s %s" % [_start.air_frames + 1, start_id, entry]
	return "默认地面中立（空输入缓存/空方向历史、木桩地面中立、接触位 %d px），入口 %s %s" % [
		PIN_DX, start_id, entry,
	]


## 证明回放输入：编译表截到重现对拍帧（含）——回放到该帧恰好看完「入口圈 +
## 重现为止的完整圈数」，每圈起点的状态快照可在回放中逐圈复核。
func _proof_inputs(run: Dictionary) -> Array[ScheduledInput]:
	var inputs: Array[ScheduledInput] = []
	var last: int = run.get("last_frame", 0)
	for spec in run["compiled"]["inputs"]:
		if spec.frame <= last:
			inputs.append(spec)
	return inputs


# --- 探针基础设施 ---


## 私有一次性会话：与训练场会话无关，Solver 不修改任何运行时战斗状态。
## 起始状态在会话上一次成形：面向与钉位按验证面向镜像；显式空中起始先以
## Space 垂直跳 + 4f 起跳准备 + N 空中帧的确定性探针序把玩家带入目标空中帧
## （探针序本身不产生命中，分析时间轴从其后的首个正常帧计为第 1 帧）。
func _new_session() -> CombatSession:
	var session := CombatSession.new(_table)
	session.player_facing = _facing
	session.dummy_position = session.player_position + Vector2(_facing * _pin_dx, 0.0)
	if _is_air_start():
		session.step(FrameInput.make(0, true, ""))
		_pin_dummy(session)
		for i in GameParams.PLAYER_PREJUMP_FRAMES - 1 + _start.air_frames:
			session.step(FrameInput.new())
			_pin_dummy(session)
	return session


## 几何接触是求解前提而非证明对象：每帧把木桩钉回玩家面前的横向间距（面向侧，
## timing 探针 = PIN_DX，空间复验 = 当前站位档），只保留垂直方向的真实浮空/
## 落地物理。
func _pin_dummy(session: CombatSession) -> void:
	session.dummy_position.x = session.player_position.x + session.player_facing * _pin_dx


func _dummy_pursuable(session: CombatSession) -> bool:
	return session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN \
		or session.dummy_state == CombatSession.DummyState.AIR_HITSTUN \
		or session.dummy_state == CombatSession.DummyState.LOW_FLOAT_SWEEP \
		or session.dummy_state == CombatSession.DummyState.LOW_FLOAT_TO_SLIDE \
		or session.dummy_state == CombatSession.DummyState.GROUND_SLIDE


func _is_plain_start_id(move_id: String) -> bool:
	## 路线起点：起始姿态、无方向派生、可由动作键起手的打击招式（按表内顺序，确定性枚举）。
	var move := _table.get(move_id) as MoveData
	if move == null or move.stance != _start_stance() or move.direction_derivation != "":
		return false
	if move.rekka_only or move.charge_only:
		return false
	return move.is_strike() and move.action_key != ""


## 单键按下的组合等待（issue 17）：表内含 BC 投时，成员键 B/C 的单键输入在
## 配对窗口（+3 物理帧）末才按单键处理——等待按物理帧推进、停顿不合并按键，
## 消费资格仍按取消窗口/姿态的当帧状态复验。非成员键与无投表为 0。
func _single_key_wait(key: String) -> int:
	if _table_has_throw and MoveData.is_throw_combination_member(key):
		return GameParams.THROW_COMBINATION_TOLERANCE
	return 0


## 蓄力版的普通版来源（票据 06）：charge_move_id 指向本招的那个招式；表中
## 至多一个（MoveTable 校验入口唯一）。
func _charge_base_of(move_id: String) -> MoveData:
	for id in _table:
		var move := _table[id] as MoveData
		if move != null and move.charge_move_id == move_id:
			return move
	return null


## 蓄力版的有效前摇：active 边界延长至 max(前摇-1, 阈值)，首个判定帧在其后
##（提交帧回卷至提交版 active_from）。普通版为声明前摇本身。
func _effective_startup_frames(move: MoveData) -> int:
	var base := _charge_base_of(move.move_id)
	if base == null:
		return move.startup_frames
	## 运行时在普通版（正在执行的招式）的 active 边界仲裁——前摇取普通版，
	## 不读蓄力版自身的 startup（两者当前相同，口径以普通版为准）。
	return maxi(base.startup_frames - 1, base.charge_threshold_frames) + 1


## 招式的起手动作键：取招式数据声明的输入绑定（issue 11 起绑定是数据字段）；
## 空中方向派生在运行时按锁定面向生效（issue 12），但 Solver 首版不调度空中
## 派生的方向喂入（喂入仅地面），故带派生的空中招式不可单键起手；投技不可单键起手。
func _start_key_for(move_id: String) -> String:
	var move := _table.get(move_id) as MoveData
	if move == null or move.is_throw():
		return ""
	if move.rekka_only:
		## Rekka 派生招式只经派生仲裁器起手（票据 04），不是单键/指令起手目标。
		return ""
	if move.charge_only:
		## 蓄力版只经按住至阈值的提交起手（票据 06），不是单键/指令起手目标。
		return ""
	## 票据 08 起，空中 D 系的 j6D/j2D 携带方向记法（6D/2D）——按下前的方向段由
	## feed 机制喂入（取消/出口链接均带 feed，方向历史照常记录），不再是不可
	## 表达的输入； rekka_only/charge_only 的入口限定保持不变。
	return move.action_key


## 起手前需要喂入的方向序列（方向派生记法去掉末位动作键）。
func _feed_for(move_id: String) -> String:
	var move := _table.get(move_id) as MoveData
	if move == null:
		return ""
	## 票据 08 起空中招式可携带方向记法（j6D/j2D 的 6D/2D）：方向段照常喂入
	## ——空中方向历史与识别同一口径（喂入只含 1/2/3/4/6 类段；上方向段属跳跃
	## 输入域，不构成招式记法，表达检查另行拒绝）。无记法招式仍为空 feed。
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
			CombatEvent.ComboEndReason.KNOCKDOWN:
				return "普通倒地结束连段"
	return ""
