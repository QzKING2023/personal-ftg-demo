class_name MoveData
extends Resource
## 招式数据：描述一招的全部可配置结算参数。
## 运行时战斗逻辑只读这份配置；调整帧数/伤害不需要改 CombatSession。

## 命中结果类型：决定木桩被命中后进入哪种受击状态（首版只有地面硬直）。
enum HitResult {
	GROUND_HITSTUN,   ## 地面受击硬直
}

@export var move_name := "5A"
## 前摇帧数：出招到判定出现之前。
@export var startup_frames := GameParams.ATTACK_STARTUP_FRAMES
## 判定帧数：命中框生效、允许命中的窗口。
@export var active_frames := GameParams.ATTACK_ACTIVE_FRAMES
## 后摇帧数：判定结束后回到中立之前。
@export var recovery_frames := GameParams.ATTACK_RECOVERY_FRAMES
## 基础伤害（连段递减在会话结算中另行计算，首版未启用）。
@export var base_damage := GameParams.ATTACK_DAMAGE
## 命中框尺寸（以角色中心为原点）。
@export var hitbox_size := GameParams.ATTACK_HITBOX_SIZE
## 命中框与身体前缘的间隙。
@export var hitbox_gap := GameParams.ATTACK_HITBOX_GAP
## 命中后的水平击退速度（px/s，沿攻击方向）。
@export var knockback := GameParams.ATTACK_KNOCKBACK
## 命中木桩在地面时附加的向上击飞速度（px/s）。
@export var knockback_up := GameParams.ATTACK_KNOCKBACK_UP
## 命中给予的受击硬直帧数。
@export var hitstun_frames := GameParams.HITSTUN_FRAMES
## 命中结果类型。
@export var hit_result: HitResult = HitResult.GROUND_HITSTUN


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


func active_from() -> int:
	return startup_frames


func active_to() -> int:
	## 判定窗口最后一帧的编号（含）。
	return startup_frames + active_frames - 1


## 命中框中心相对角色中心的偏移（乘以 facing 得到世界方向）。
func hitbox_offset() -> float:
	return GameParams.BODY_SIZE.x * 0.5 + hitbox_gap + hitbox_size.x * 0.5


## 默认招式表：动作键名 → 招式。首版只有 A 键的基础招式，数值取自 GameParams。
static func default_table() -> Dictionary:
	var basic := MoveData.new()
	basic.move_name = "5A"
	basic.startup_frames = GameParams.ATTACK_STARTUP_FRAMES
	basic.active_frames = GameParams.ATTACK_ACTIVE_FRAMES
	basic.recovery_frames = GameParams.ATTACK_RECOVERY_FRAMES
	basic.base_damage = GameParams.ATTACK_DAMAGE
	basic.hitbox_size = GameParams.ATTACK_HITBOX_SIZE
	basic.hitbox_gap = GameParams.ATTACK_HITBOX_GAP
	basic.knockback = GameParams.ATTACK_KNOCKBACK
	basic.knockback_up = GameParams.ATTACK_KNOCKBACK_UP
	basic.hitstun_frames = GameParams.HITSTUN_FRAMES
	return {"A": basic}
