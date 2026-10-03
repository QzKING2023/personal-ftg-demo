extends RefCounted

## P0 增长夹具：可控连段边数量（1/2/4/8 条）的最小注入表，供
## test_solver_growth.gd / test_solver_perf_profile.gd 与基线采集共用。
## 拓扑（线性链 + 固定空中尾巴）：
##   G0 →cancel…→cancel→ G_{m-1} →cancel→ L0（launcher）→jump cancel→ Q1 →cancel→ Q2
## 其中 m = max(0, E-2)；配置边数恰为 E = m（地面链入 launcher 含）+ 1（jump
## cancel）+（E≥2 时）1（空中取消）。E=8 的全链 9 招超过 MAX_ROUTE_NODES=8 的
## 可读路线上限——G0 起点的路线按上限截为 8 招，这是求解器的语义常量，如实反映
## 在增长曲线上，不为夹具绕过。
## 克隆来源：地面链 5A、launcher 6A（清除方向派生，使其可单键起手）、空中 jA/jB
## ——真实资源的帧数/命中资料/取消窗口原样保留，夹具只重定向接缝与按键。

const _TARGET_FIELDS := [
	"cancel_targets", "chain_cancel_targets", "special_cancel_targets",
	"jump_cancel_targets", "landing_cancel_targets", "link_targets",
	"special_entry_targets", "special_entry_link_targets", "air_exit_targets",
	"hit_landing_cancel_targets",
]

var _base := {}


func _ready_base() -> bool:
	if not _base.is_empty():
		return true
	var result := MoveTable.load_default()
	if not result.ok:
		return false
	_base = result.moves
	return true


## E 条配置接续边的注入表；manifest 加载失败返回空表（调用方按 FAIL 处理）。
func table(edges: int) -> Dictionary:
	if not _ready_base():
		return {}
	var built := {}
	var m := maxi(0, edges - 2)
	var prev_id := ""
	for i in range(m):
		var id := "G%d" % i
		built[id] = _clone("5A", id, "F%d" % i)
		if prev_id != "":
			(built[prev_id] as MoveData).cancel_targets = [id]
		prev_id = id
	var launcher := _clone("6A", "L0", "LA")
	launcher.direction_derivation = ""
	launcher.jump_cancel_targets = ["Q1"]
	if prev_id != "":
		(built[prev_id] as MoveData).cancel_targets = ["L0"]
	built["L0"] = launcher
	built["Q1"] = _clone("jA", "Q1", "QA")
	if edges >= 2:
		(built["Q1"] as MoveData).cancel_targets = ["Q2"]
		built["Q2"] = _clone("jB", "Q2", "QB")
	return built


## 两招互取消的地面循环夹具（5A 克隆、加长硬直），驱动循环证明模式的逐圈快照。
func cycle_table() -> Dictionary:
	if not _ready_base():
		return {}
	var c0 := _clone("5A", "C0", "X0")
	var c1 := _clone("5A", "C1", "X1")
	for move in [c0, c1]:
		for profile in move.hit_profiles:
			profile.ground_stun_frames = 30
	c0.cancel_targets = ["C1"]
	c1.cancel_targets = ["C0"]
	return {"C0": c0, "C1": c1}


func _clone(source_id: String, new_id: String, new_key: String) -> MoveData:
	var move := MoveTable._fresh_copy(_base[source_id] as MoveData)
	move.move_id = new_id
	move.action_key = new_key
	move.direction_derivation = ""
	var empty: Array[String] = []
	move.input_alternatives = empty.duplicate()
	for field in _TARGET_FIELDS:
		move.set(field, empty.duplicate())
	move.rekka_window_frames = -1
	move.rekka_b_target = ""
	move.rekka_c_target = ""
	move.rekka_only = false
	move.charge_move_id = ""
	move.charge_only = false
	move.is_finisher = false
	return move
