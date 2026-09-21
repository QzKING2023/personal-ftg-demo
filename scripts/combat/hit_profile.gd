class_name HitProfile
extends Resource
## 上下文命中资料（ADR-0003 / 上下文命中资料规格 §2.2）：内嵌在 MoveData 中的
## 类型化资源，不拆成独立 .tres 文件。唯一键是 (target_state, hit_context)；
## 运行时先按目标状态、再按命中上下文做精确匹配，缺失不回退，重复键或非法
## 组合使整张 MoveTable 拒绝。计时与速度的负数默认值只表示缺省——加载校验
## 不得把它们解释成 0。

## 命中前目标状态：接地且非倒地为 GROUNDED，真正离地为 AIRBORNE。
## 倒地、未支持状态和未知状态不会被转换成 grounded。
enum TargetState {
	UNSET = 0,    ## 未声明（非法）
	GROUNDED = 1, ## 地面目标
	AIRBORNE = 2, ## 空中目标
}

## 命中上下文：目标处于自身招式 startup/recovery 的显式易受击窗口时为 COUNTER。
enum HitContext {
	UNSET = 0,   ## 未声明（非法）
	NORMAL = 1,  ## 普通命中
	COUNTER = 2, ## Counter Hit
}

## 命中反应：决定目标被命中后进入哪种受击处理与计时语义。
enum Reaction {
	UNSET = 0,            ## 未声明（非法）
	GROUND_HITSTUN = 1,   ## 地面受击硬直（仅 GROUNDED 目标，保持接地）
	LAUNCH = 2,           ## 浮空受击（空中受身计时 + 垂直初速度）
	GROUND_KNOCKDOWN = 3, ## 普通倒地（独立倒地计时，进入即结束连段）
}

## 唯一键之一：命中前目标状态。
@export var target_state: TargetState = TargetState.UNSET
## 唯键之二：普通命中或 Counter Hit。
@export var hit_context: HitContext = HitContext.UNSET
## 命中反应。
@export var reaction: Reaction = Reaction.UNSET
## 伤害覆盖：-1 表示使用 MoveData.base_damage；否则必须为非负整数。
@export var damage_override := -1
## 地面受击硬直帧数（仅 GROUND_HITSTUN；有效值为正整数）。
@export var ground_stun_frames := -1
## 空中受身帧数（仅 LAUNCH；有效值为正整数）。
@export var air_untech_frames := -1
## 倒地帧数（仅 GROUND_KNOCKDOWN；有效值为正整数）。
@export var knockdown_frames := -1
## 水平速度幅值（px/s，沿攻击者面向施加；所有合法 reaction 必须声明且非负）。
@export var horizontal_speed_px_s := -1.0
## 垂直初速度幅值（px/s；LAUNCH 必须大于 0，普通地面命中/倒地为 0）。
@export var upward_speed_px_s := -1.0


## 本 profile 的反应计时帧数（防御硬直等玩家侧反馈复用同一口径；未声明为 -1）。
func reaction_timer_frames() -> int:
	match reaction:
		Reaction.GROUND_HITSTUN:
			return ground_stun_frames
		Reaction.LAUNCH:
			return air_untech_frames
		Reaction.GROUND_KNOCKDOWN:
			return knockdown_frames
	return -1


func label() -> String:
	return "%s×%s" % [_target_state_label(), _context_label()]


func _target_state_label() -> String:
	match target_state:
		TargetState.GROUNDED:
			return "grounded"
		TargetState.AIRBORNE:
			return "airborne"
	return "unset"


func _context_label() -> String:
	match hit_context:
		HitContext.NORMAL:
			return "normal"
		HitContext.COUNTER:
			return "counter"
	return "unset"
