class_name Player
extends CharacterBody2D
## 玩家角色的呈现层：位置、朝向与命中框显示全部来自战斗会话，每帧由训练场写入。
## 移动/跳跃/出招的结算在 CombatSession 中完成，本脚本不自行驱动状态；
## 碰撞（地面/墙体/身体）由会话按几何结算，节点碰撞体仅保留场景结构。

var _visuals: Node2D
var _attack_visual: Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	($CollisionShape2D.shape as RectangleShape2D).size = GameParams.BODY_SIZE
	_visuals = NativeShapes.make_character(GameParams.PLAYER_COLOR)
	add_child(_visuals)
	_attack_visual = NativeShapes.make_rect(GameParams.ATTACK_HITBOX_SIZE, GameParams.HITBOX_COLOR)
	_attack_visual.visible = false
	add_child(_attack_visual)


## 从战斗会话同步本帧的呈现状态（位置、朝向、命中框显示）。
func apply_session(session: CombatSession) -> void:
	position = session.player_position
	_visuals.scale.x = session.player_facing
	var active := session.player_phase == CombatSession.PlayerPhase.ACTIVE
	_attack_visual.visible = active
	if active:
		_attack_visual.position = session.player_attack_rect().get_center() - session.player_position
