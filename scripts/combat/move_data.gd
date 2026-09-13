class_name MoveData
extends Resource
## 招式数据：描述一招的全部可配置结算参数。
## 运行时战斗逻辑只读这份配置；调整帧数/伤害不需要改 CombatSession。

## 命中结果类型：决定木桩被命中后进入哪种受击状态（首版只有地面硬直）。
enum HitResult {
	GROUND_HITSTUN,   ## 地面受击硬直
}

## 姿态要求：动作键解析与取消资格都按姿态匹配（空中招式在后续 issue 配置）。
enum Stance {
	GROUND,   ## 地面招式
	AIR,      ## 空中招式
}

@export var move_name := "5A"
## 姿态要求。
@export var stance: Stance = Stance.GROUND
## 前摇帧数：出招到判定出现之前。
@export var startup_frames := GameParams.MOVE_5A_STARTUP_FRAMES
## 判定帧数：命中框生效、允许命中的窗口。
@export var active_frames := GameParams.MOVE_5A_ACTIVE_FRAMES
## 后摇帧数：判定结束后回到中立之前。
@export var recovery_frames := GameParams.MOVE_5A_RECOVERY_FRAMES
## 基础伤害（实际伤害按连段命中数递减，在会话结算中计算）。
@export var base_damage := GameParams.MOVE_5A_DAMAGE
## 命中框尺寸（以角色中心为原点）。
@export var hitbox_size := GameParams.ATTACK_HITBOX_SIZE
## 命中框与身体前缘的间隙。
@export var hitbox_gap := GameParams.ATTACK_HITBOX_GAP
## 命中后的水平击退速度（px/s，沿攻击方向）。
@export var knockback := GameParams.MOVE_5A_KNOCKBACK
## 命中木桩在地面时附加的向上击飞速度（px/s）。
@export var knockback_up := GameParams.ATTACK_KNOCKBACK_UP
## 命中给予的受击硬直帧数。
@export var hitstun_frames := GameParams.HITSTUN_FRAMES
## 命中结果类型。
@export var hit_result: HitResult = HitResult.GROUND_HITSTUN
## 命中确认取消：本招命中确认后允许取消进入的招式 id 列表。
@export var cancel_targets: Array[String] = []
## 命中确认取消窗口：命中后第 0–N 帧（含两端）内允许取消。
@export var cancel_window_frames := GameParams.CANCEL_WINDOW_FRAMES
## 收尾招式：命中后结束当前连段路线；不主动清除木桩的受击/倒地处理。
@export var is_finisher := false


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


## 默认招式表：招式 id → 招式。首版为地面路线 5A → 5B → 5D，数值取自 GameParams。
static func default_table() -> Dictionary:
	var starter := MoveData.new()
	starter.move_name = "5A"
	starter.startup_frames = GameParams.MOVE_5A_STARTUP_FRAMES
	starter.active_frames = GameParams.MOVE_5A_ACTIVE_FRAMES
	starter.recovery_frames = GameParams.MOVE_5A_RECOVERY_FRAMES
	starter.base_damage = GameParams.MOVE_5A_DAMAGE
	starter.knockback = GameParams.MOVE_5A_KNOCKBACK
	starter.cancel_targets = ["5B"]

	var linker := MoveData.new()
	linker.move_name = "5B"
	linker.startup_frames = GameParams.MOVE_5B_STARTUP_FRAMES
	linker.active_frames = GameParams.MOVE_5B_ACTIVE_FRAMES
	linker.recovery_frames = GameParams.MOVE_5B_RECOVERY_FRAMES
	linker.base_damage = GameParams.MOVE_5B_DAMAGE
	linker.knockback = GameParams.MOVE_5B_KNOCKBACK
	linker.cancel_targets = ["5D"]

	var finisher := MoveData.new()
	finisher.move_name = "5D"
	finisher.startup_frames = GameParams.MOVE_5D_STARTUP_FRAMES
	finisher.active_frames = GameParams.MOVE_5D_ACTIVE_FRAMES
	finisher.recovery_frames = GameParams.MOVE_5D_RECOVERY_FRAMES
	finisher.base_damage = GameParams.MOVE_5D_DAMAGE
	finisher.knockback = GameParams.MOVE_5D_KNOCKBACK
	finisher.is_finisher = true

	for move: MoveData in [starter, linker, finisher]:
		move.hitbox_size = GameParams.ATTACK_HITBOX_SIZE
		move.hitbox_gap = GameParams.ATTACK_HITBOX_GAP
		move.knockback_up = GameParams.ATTACK_KNOCKBACK_UP
		move.hitstun_frames = GameParams.HITSTUN_FRAMES
	return {"5A": starter, "5B": linker, "5D": finisher}
