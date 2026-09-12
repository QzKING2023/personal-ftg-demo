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
const JUMP_VELOCITY := -540.0
const GRAVITY := 1400.0
const MAX_FALL_SPEED := 1000.0

# --- 角色形状（玩家与木桩共用同一套结构，只换颜色）---
const BODY_SIZE := Vector2(48, 80)
const HEAD_SIZE := Vector2(36, 24)
const HEAD_GAP := 2.0
const VISOR_SIZE := Vector2(10, 6)
const VISOR_OFFSET_X := 10.0

# --- 招式（startup / active / recovery 固定窗口）---
const ATTACK_DAMAGE := 10
const ATTACK_STARTUP_TIME := 0.08
const ATTACK_ACTIVE_TIME := 0.12
const ATTACK_RECOVERY_TIME := 0.22
const ATTACK_HITBOX_SIZE := Vector2(64, 60)
const ATTACK_HITBOX_GAP := 4.0

# --- 受击反馈 ---
const ATTACK_KNOCKBACK := 320.0
const ATTACK_KNOCKBACK_UP := 110.0
const HITSTUN_TIME := 0.20
const HIT_FLASH_TIME := 0.10

# --- 木桩 ---
const DUMMY_MAX_HP := 100
const DUMMY_FRICTION := 2000.0
const DUMMY_HITSTUN_FRICTION := 500.0

# --- 生命条 ---
const HP_BAR_SIZE := Vector2(64, 8)
const HP_BAR_GAP := 10.0

# --- 物理层（1 起算的层号）---
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_DUMMY := 3

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


## 物理层号（1 起算）转 collision_layer/mask 用的位掩码。
static func layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)


## 角色站上地面时身体中心的 y 坐标。
static func ground_stand_y() -> float:
	return GROUND_Y - BODY_SIZE.y * 0.5
