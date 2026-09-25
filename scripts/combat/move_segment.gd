class_name MoveSegment
extends Resource
## 多段招式的附加判定段（票据 05，S-01/S-02）：一招内顺序执行的第二个及以后的
## active 段。段 1 沿用 MoveData 的基础字段（startup/active/命中框/伤害/命中资料），
## 后续段由 MoveData.segments 声明；每段对同一目标至多命中一次，各自独立选择
## (target_state, hit_context) 命中资料。字段缺省一律是“未声明”哨兵（0/-1/UNSET），
## MoveTable 校验缺字段即拒绝。

## 与上一段 active 结束之间的间隔帧数（本段 active 开始前的准备帧，计入招式
## 帧序与 Counter 易受击窗口）；至少 0——0 表示上一段 active 结束的下一帧立即
## 进入本段 active。
@export var startup_frames := -1
## 本段判定帧数。
@export var active_frames := -1
## 本段基础伤害（连段结算按段读取，不沿用招式级 base_damage）。
@export var base_damage := -1
## 本段命中框尺寸（以角色中心为原点）。
@export var hitbox_size := Vector2.ZERO
## 本段命中框与身体前缘的间隙。
@export var hitbox_gap := -1.0
## 本段内嵌上下文命中资料：唯一键 (target_state, hit_context)，至少一个合法
## profile；缺失目标状态的资料即该段对该状态无命中，不回退段 1 或其他段。
@export var hit_profiles: Array[HitProfile] = []


## 按 (target_state, hit_context) 精确查找本段命中资料（与 MoveData.profile_for
## 同一口径）：任一维度没有完全相等的 profile 即返回 null。
func profile_for(target_state: HitProfile.TargetState, hit_context: HitProfile.HitContext) -> HitProfile:
	for profile in hit_profiles:
		if profile.target_state == target_state and profile.hit_context == hit_context:
			return profile
	return null


func has_normal_profile(target_state: HitProfile.TargetState) -> bool:
	return profile_for(target_state, HitProfile.HitContext.NORMAL) != null
