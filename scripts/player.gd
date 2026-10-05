class_name Player
extends CharacterBody2D
## 玩家角色的呈现层：位置、朝向与命中框显示全部来自战斗会话，每帧由训练场写入。
## 移动/跳跃/出招的结算在 CombatSession 中完成，本脚本不自行驱动状态；
## 碰撞（地面/墙体/身体）由会话按几何结算，节点碰撞体仅保留场景结构。
## 票据 10 起另以原生形状呈现徒手/短刀语义（C/D 系与 6A 出刀、A/B 系徒手）、
## 位移起落残影与收刀卡点——全部是会话状态的纯函数，不影响结算。

## 残影采样间隔与数量（位移起落：D 系轨迹与跳跃弧线的可读回放）。
const TRAIL_SAMPLES := 5
const TRAIL_SAMPLE_EVERY := 2
## 收招后中立滞留超过该帧数即清空残影。
const TRAIL_CLEAR_AFTER := 10

var _visuals: Node2D
var _attack_visual: Polygon2D
## 武器姿态层：随面向/蹲姿翻转缩放；刀、拳、收刀锚点都挂在这里。
var _weapon_rig: Node2D
var _knife: Node2D
var _fist: Polygon2D
var _sheath_anchor: Polygon2D
## 残影（世界坐标队列 + 间隔计数），仅呈现。
var _trail_positions: Array[Vector2] = []
var _trail_root: Node2D
var _trail_ghosts: Array[Polygon2D] = []
var _trail_tick := 0
var _idle_frames := 0
## 上一帧阶段（收刀卡点 = 出刀招式 active→recovery 的转换检测）。
var _phase_prev: CombatSession.PlayerPhase = CombatSession.PlayerPhase.NEUTRAL
var _snap_left := 0
## 冻结的呈现状态（smoke 断言用；apply_session 每帧重算）。
var _report := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	($CollisionShape2D.shape as RectangleShape2D).size = GameParams.BODY_SIZE
	_visuals = NativeShapes.make_character(GameParams.PLAYER_COLOR)
	add_child(_visuals)
	_attack_visual = NativeShapes.make_rect(GameParams.ATTACK_HITBOX_SIZE, GameParams.HITBOX_COLOR)
	_attack_visual.visible = false
	add_child(_attack_visual)
	_build_weapon_rig()


func _build_weapon_rig() -> void:
	_weapon_rig = Node2D.new()
	_weapon_rig.name = "WeaponRig"
	add_child(_weapon_rig)
	_sheath_anchor = NativeShapes.make_sheath_anchor()
	_weapon_rig.add_child(_sheath_anchor)
	_knife = NativeShapes.make_knife()
	_weapon_rig.add_child(_knife)
	_fist = NativeShapes.make_fist()
	_fist.visible = false
	_weapon_rig.add_child(_fist)
	# 残影节点数量固定，先建后隐（世界坐标由每帧局部偏移表达）。
	_trail_root = Node2D.new()
	_trail_root.name = "TrailRoot"
	add_child(_trail_root)
	for i in TRAIL_SAMPLES:
		var ghost := NativeShapes.make_rect(GameParams.BODY_SIZE, GameParams.MOTION_TRAIL_COLOR)
		ghost.visible = false
		ghost.name = "Ghost%d" % i
		_trail_root.add_child(ghost)
		_trail_ghosts.append(ghost)


## 从战斗会话同步本帧的呈现状态（位置、朝向、蹲下/防御姿态、命中框、武器姿态
## 与位移残影）。蹲下以纵向压扁呈现、防御以整体变色呈现——姿态结算全部在
## 会话中完成。命中框只在有实际判定框的招式（打击）显示：投技无命中框（issue 17）。
func apply_session(session: CombatSession) -> void:
	position = session.player_position
	_visuals.scale.x = session.player_facing
	_visuals.scale.y = GameParams.PLAYER_CROUCH_SCALE if session.player_crouching else 1.0
	_visuals.modulate = GameParams.PLAYER_GUARD_COLOR \
		if session.player_guard != CombatSession.GuardPosture.NONE else Color.WHITE
	var attack_rect := session.player_attack_rect()
	var active := session.player_phase == CombatSession.PlayerPhase.ACTIVE and attack_rect.has_area()
	_attack_visual.visible = active
	if active:
		_attack_visual.position = attack_rect.get_center() - session.player_position
	_update_weapon_pose(session, attack_rect)
	_update_trail(session)


## 判定帧的出招方向：优先计划位移（资源声明的运动语义），否则朝判定框中心
## （换算到姿态层的本地坐标——rig 已按面向翻转）。
func _strike_direction(motion: Vector2, attack_rect: Rect2, session: CombatSession, facing: int) -> Vector2:
	if motion != Vector2.ZERO:
		return motion
	if attack_rect.has_area():
		return (attack_rect.get_center() - session.player_position) * Vector2(facing, 1.0)
	return Vector2(1, 0)


## 短刀贴臂收起姿态（持刀侧前臂、刀尖向下）。
func _holster_knife() -> void:
	_knife.visible = true
	_knife.position = Vector2(GameParams.BODY_SIZE.x * 0.5 - 2.0, -GameParams.BODY_SIZE.y * 0.12)
	_knife.rotation = deg_to_rad(90.0)


## 出刀/徒手/收刀节拍：刀姿随 STARTUP（蓄势后抬）→ ACTIVE（沿计划位移或判定
## 中心方向刺出）→ RECOVERY（收回到持刀锚点、首帧亮起收刀卡点）变化；徒手
## 招式以拳形沿同节拍伸缩。中立时短刀贴前臂收起。
func _update_weapon_pose(session: CombatSession, attack_rect: Rect2) -> void:
	var facing := session.player_facing
	_weapon_rig.scale = Vector2(facing, _visuals.scale.y)
	var hand := Vector2(GameParams.BODY_SIZE.x * 0.5 - 2.0, -GameParams.BODY_SIZE.y * 0.12)
	_sheath_anchor.position = hand
	var move_id := session.player_move_id
	var action_key := ""
	var motion := Vector2.ZERO
	if move_id != "":
		var move: MoveData = (session.move_table() as Dictionary).get(move_id)
		if move != null:
			action_key = move.action_key
			if move.has_motion():
				motion = Vector2(move.motion_x_px, move.motion_y_px)
	var knife_move := NativeShapes.is_knife_move(move_id, action_key)
	var phase := session.player_phase
	# 收刀卡点：出刀招式从判定进入后摇的首帧起亮起数帧（收刀的明确卡点）。
	if knife_move and phase == CombatSession.PlayerPhase.RECOVERY \
			and _phase_prev == CombatSession.PlayerPhase.ACTIVE:
		_snap_left = GameParams.SHEATH_SNAP_FRAMES
	_snap_left = maxi(_snap_left - 1, 0)
	_phase_prev = phase
	_sheath_anchor.color = GameParams.KNIFE_SHEATH_SNAP_COLOR if _snap_left > 0 \
		else GameParams.KNIFE_SHEATH_COLOR
	var striking := phase == CombatSession.PlayerPhase.STARTUP \
		or phase == CombatSession.PlayerPhase.ACTIVE \
		or phase == CombatSession.PlayerPhase.RECOVERY
	if knife_move:
		_fist.visible = false
		_knife.visible = true
		match phase:
			CombatSession.PlayerPhase.STARTUP:
				_knife.position = hand
				_knife.rotation = deg_to_rad(-100.0)
			CombatSession.PlayerPhase.ACTIVE:
				var dir := _strike_direction(motion, attack_rect, session, facing)
				_knife.position = hand + dir.normalized() * 14.0
				_knife.rotation = dir.angle()
			CombatSession.PlayerPhase.RECOVERY:
				_knife.position = hand
				_knife.rotation = deg_to_rad(140.0)
			_:
				_knife.position = hand
				_knife.rotation = deg_to_rad(90.0)
	elif striking and move_id != "":
		# 徒手打击：拳形沿同一节拍伸缩（出拳方向取计划位移或判定中心）。
		_knife.visible = true
		_knife.position = hand
		_knife.rotation = deg_to_rad(90.0)
		match phase:
			CombatSession.PlayerPhase.STARTUP:
				_fist.visible = true
				_fist.position = hand + Vector2(6, -6)
			CombatSession.PlayerPhase.ACTIVE:
				_fist.visible = true
				var dir := _strike_direction(motion, attack_rect, session, facing)
				_fist.position = hand + dir.normalized() * 16.0
			_:
				_fist.visible = false
	else:
		_knife.visible = true
		_knife.position = hand
		_knife.rotation = deg_to_rad(90.0)
		_fist.visible = false
	_report = {
		"move_id": move_id,
		"knife_move": knife_move,
		"phase": phase,
		"knife_visible": _knife.visible,
		"knife_drawn": knife_move and phase != CombatSession.PlayerPhase.NEUTRAL,
		"fist_visible": _fist.visible,
		"snap": _snap_left > 0,
	}


## 位移起落残影：出招或滞空期间按固定间隔记录世界位置，旧位置淡出；
## 回到地面中立一段时间后清空。残影随本体移动而留在原世界坐标。
func _update_trail(session: CombatSession) -> void:
	var moving := session.player_phase != CombatSession.PlayerPhase.NEUTRAL \
		or not session.player_on_ground
	if moving:
		_idle_frames = 0
		_trail_tick += 1
		if _trail_tick >= TRAIL_SAMPLE_EVERY:
			_trail_tick = 0
			_trail_positions.append(session.player_position)
			while _trail_positions.size() > TRAIL_SAMPLES:
				_trail_positions.pop_front()
	else:
		_idle_frames += 1
		if _idle_frames > TRAIL_CLEAR_AFTER:
			_trail_positions.clear()
	var active_count := _trail_positions.size()
	for i in TRAIL_SAMPLES:
		var ghost := _trail_ghosts[i]
		var index := active_count - TRAIL_SAMPLES + i
		if index >= 0 and index < active_count:
			ghost.visible = true
			ghost.position = _trail_positions[index] - session.player_position
			var fade := float(index + 1) / float(active_count)
			ghost.color = Color(GameParams.MOTION_TRAIL_COLOR.r, GameParams.MOTION_TRAIL_COLOR.g,
				GameParams.MOTION_TRAIL_COLOR.b, GameParams.MOTION_TRAIL_COLOR.a * fade)
		else:
			ghost.visible = false


## 呈现状态查询（smoke 集成测试用）：当前是否呈现蹲下/防御视觉。
func is_showing_crouch() -> bool:
	return _visuals.scale.y < 1.0


func is_showing_guard() -> bool:
	return _visuals.modulate == GameParams.PLAYER_GUARD_COLOR


## 武器呈现查询（票据 10 smoke）：出刀招式的刀姿与收刀卡点、徒手拳形。
func visual_report() -> Dictionary:
	return _report.duplicate()
