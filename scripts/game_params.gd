class_name GameParams
## FTG Demo 的全部可调参数。
## 所有手感相关数值都集中在这里，改参数不需要动其他脚本。

# --- 舞台 ---
const STAGE_WIDTH := 960.0
const STAGE_HEIGHT := 540.0
const GROUND_Y := 480.0
const WALL_THICKNESS := 24.0
const FLOOR_THICKNESS := 60.0
const CENTER_MARK_WIDTH := 6.0

# --- 出生点（x 坐标，y 由地面与身体尺寸推算）---
const PLAYER_SPAWN_X := 240.0
const DUMMY_SPAWN_X := 620.0

# --- 玩家移动 ---
const PLAYER_MOVE_SPEED := 340.0
const PLAYER_ACCELERATION := 2600.0
const PLAYER_FRICTION := 3000.0
const PLAYER_AIR_CONTROL := 0.75
# 玩家跳跃默认滞空帧数；起跳速度由滞空帧数换算（与木桩浮空同一积分方式）。
const PLAYER_JUMP_AIRTIME_FRAMES := 40
const GRAVITY := 1400.0
const MAX_FALL_SPEED := 1000.0

# --- 角色形状（玩家与木桩共用同一套结构，只换颜色）---
const BODY_SIZE := Vector2(48, 80)
const HEAD_SIZE := Vector2(36, 24)
const HEAD_GAP := 2.0
const VISOR_SIZE := Vector2(10, 6)
const VISOR_OFFSET_X := 10.0

# --- 战斗会话（固定 60 物理帧/秒，全部数值以帧为单位）---
const PHYSICS_FPS := 60.0
const PHYSICS_TICK := 1.0 / PHYSICS_FPS

# --- 招式（startup / active / recovery 固定窗口，单位：物理帧）---
# 共享命中框与硬直；各招式窗口/伤害/击退独立成块，便于单独调整手感。
const ATTACK_HITBOX_SIZE := Vector2(64, 60)
const ATTACK_HITBOX_GAP := 4.0

# 5A 地面起手（issue 01 的基础招式；连段内击退调低以保证 5B 能追上）。
const MOVE_5A_DAMAGE := 10
const MOVE_5A_STARTUP_FRAMES := 5
const MOVE_5A_ACTIVE_FRAMES := 7
const MOVE_5A_RECOVERY_FRAMES := 13
const MOVE_5A_KNOCKBACK := 160.0

# 5B 地面连接。
const MOVE_5B_DAMAGE := 12
const MOVE_5B_STARTUP_FRAMES := 4
const MOVE_5B_ACTIVE_FRAMES := 6
const MOVE_5B_RECOVERY_FRAMES := 13
const MOVE_5B_KNOCKBACK := 160.0

# 5D 地面收尾（收尾不主动清除木桩受击处理，击退放大作为路线终点的视觉反馈）。
const MOVE_5D_DAMAGE := 18
const MOVE_5D_STARTUP_FRAMES := 5
const MOVE_5D_ACTIVE_FRAMES := 7
const MOVE_5D_RECOVERY_FRAMES := 15
const MOVE_5D_KNOCKBACK := 320.0

# 5C 地面浮空（C 语义：命中将木桩打入浮空受击）。
const MOVE_5C_DAMAGE := 14
const MOVE_5C_STARTUP_FRAMES := 6
const MOVE_5C_ACTIVE_FRAMES := 5
const MOVE_5C_RECOVERY_FRAMES := 16
const MOVE_5C_KNOCKBACK := 140.0

# 236C 方向浮空派生（236 + C；伤害更重的浮空，滞空与普通浮空一致）。
const MOVE_236C_DAMAGE := 18
const MOVE_236C_STARTUP_FRAMES := 6
const MOVE_236C_ACTIVE_FRAMES := 5
const MOVE_236C_RECOVERY_FRAMES := 18
const MOVE_236C_KNOCKBACK := 200.0

# 214D 方向收尾派生（214 + D；比 5D 更重的收尾）。
const MOVE_214D_DAMAGE := 22
const MOVE_214D_STARTUP_FRAMES := 7
const MOVE_214D_ACTIVE_FRAMES := 5
const MOVE_214D_RECOVERY_FRAMES := 20
const MOVE_214D_KNOCKBACK := 400.0

# jA 空中追击起手（jump cancel 后的空中起手；普通命中不刷新木桩浮空滞空）。
const MOVE_JA_DAMAGE := 8
const MOVE_JA_STARTUP_FRAMES := 4
const MOVE_JA_ACTIVE_FRAMES := 6
const MOVE_JA_RECOVERY_FRAMES := 10
const MOVE_JA_KNOCKBACK := 120.0

# --- 受击反馈 ---
const ATTACK_KNOCKBACK_UP := 110.0
const HITSTUN_FRAMES := 12
const HIT_FLASH_TIME := 0.10

# --- 连段输入与取消 ---
# 动作键单槽缓存：输入帧年龄 0–5 有效，年龄 6 先过期；最新输入覆盖旧输入。
const ACTION_BUFFER_FRAMES := 6
# 方向历史独立于动作键缓存：输入帧年龄 0–23 有效，年龄 24 先过期。
const DIRECTION_BUFFER_FRAMES := 24
# 命中确认取消窗口：命中后第 0–N 帧（含两端）内允许取消。
const CANCEL_WINDOW_FRAMES := 8
# 连段伤害递减：第 n 击倍率 = max(下限, 1 - (n-1) × 递减步长)。
const COMBO_DAMAGE_DECAY := 0.1
const COMBO_DAMAGE_FLOOR := 0.1

# --- 木桩 ---
const DUMMY_MAX_HP := 100
const DUMMY_FRICTION := 2000.0
const DUMMY_HITSTUN_FRICTION := 500.0
# 浮空：默认滞空帧数与浮空受击硬直；浮空招式按滞空帧数换算起跳速度。
const DUMMY_FLOAT_AIRTIME_FRAMES := 48
const FLOAT_HITSTUN_FRAMES := 36

# --- 生命条 ---
const HP_BAR_SIZE := Vector2(64, 8)
const HP_BAR_GAP := 10.0

# --- 颜色（替换颜色不影响玩法）---
const BACKDROP_COLOR := Color(0.12, 0.13, 0.18)
const GROUND_COLOR := Color(0.24, 0.28, 0.34)
const WALL_COLOR := Color(0.18, 0.20, 0.26)
const CENTER_MARK_COLOR := Color(0.35, 0.40, 0.48)
const PLAYER_COLOR := Color(0.30, 0.62, 0.90)
const DUMMY_COLOR := Color(0.82, 0.56, 0.24)
const VISOR_COLOR := Color(0.08, 0.08, 0.10)
const HITBOX_COLOR := Color(1.0, 0.85, 0.25, 0.35)
const HIT_FLASH_COLOR := Color(4.0, 4.0, 4.0)
const HP_BAR_BG_COLOR := Color(0.05, 0.05, 0.06)
const HP_BAR_FILL_COLOR := Color(0.30, 0.85, 0.35)
const HP_BAR_LOW_COLOR := Color(0.90, 0.25, 0.20)
const HINT_COLOR := Color(0.85, 0.87, 0.92)

# --- 辅助 ---
const HINT_OFFSET := Vector2(8, 6)
const STATUS_OFFSET := Vector2(500, 6)


## 角色站上地面时身体中心的 y 坐标。
static func ground_stand_y() -> float:
	return GROUND_Y - BODY_SIZE.y * 0.5


## 给予 DUMMY_FLOAT_AIRTIME_FRAMES 帧滞空所需的起跳速度（px/s）。
## 起跳帧当帧不加重力（落地判定前的 on_ground 守卫），抛物线恰好往返对称。
static func float_launch_speed() -> float:
	return GRAVITY * PHYSICS_TICK * DUMMY_FLOAT_AIRTIME_FRAMES * 0.5


## 给予 PLAYER_JUMP_AIRTIME_FRAMES 帧滞空所需的起跳速度（px/s），积分方式与浮空一致。
static func jump_velocity() -> float:
	return GRAVITY * PHYSICS_TICK * PLAYER_JUMP_AIRTIME_FRAMES * 0.5


## 角色身体中心允许的最小 x（贴左墙）。
static func stage_left_limit() -> float:
	return WALL_THICKNESS + BODY_SIZE.x * 0.5


## 角色身体中心允许的最大 x（贴右墙）。
static func stage_right_limit() -> float:
	return STAGE_WIDTH - WALL_THICKNESS - BODY_SIZE.x * 0.5
