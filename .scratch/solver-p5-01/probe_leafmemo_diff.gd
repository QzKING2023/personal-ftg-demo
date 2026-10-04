extends SceneTree

## P5 探针：小分支表上叶登记开关两跑的逐节指纹 diff，定位不健全共享。

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
const GrowthFixture = preload("res://tests/solver_growth_fixture.gd")

var _metrics := AcceptanceSolverMetrics.new()
var _fixture := GrowthFixture.new()


func _initialize() -> void:
	var table := _branch_table()
	print("branch table size: ", table.size())
	if table.is_empty():
		print("BRANCH TABLE EMPTY - load_default failed?")
	ComboSolver._route_leaf_memo_disabled = true
	var off := _solve(table)
	ComboSolver._route_leaf_memo_disabled = false
	var on := _solve(table)
	print("=== routes off (%d) ===" % off.routes.size())
	for route in off.routes:
		print("  %s | valid=%s hits=%s dmg=%.1f note=%s spatial=%s fail=%s" % [
			route.label(), str(route.timing_valid), str(route.hit_frames), route.total_damage,
			route.note, str(route.spatial_state), str(route.spatial_failures)])
	print("=== routes on (%d) ===" % on.routes.size())
	for route in on.routes:
		print("  %s | valid=%s hits=%s dmg=%.1f note=%s spatial=%s fail=%s" % [
			route.label(), str(route.timing_valid), str(route.hit_frames), route.total_damage,
			route.note, str(route.spatial_state), str(route.spatial_failures)])
	print("=== notes off ===")
	for note in off.notes:
		print("  " + note)
	print("=== notes on ===")
	for note in on.notes:
		print("  " + note)
	var off_fp := _metrics._fingerprint(off)
	var on_fp := _metrics._fingerprint(on)
	print("fingerprint equal: ", off_fp == on_fp, " off=", off_fp.substr(0, 16), " on=", on_fp.substr(0, 16))
	quit(0)


func _solve(table: Dictionary) -> ComboSolver.SolverReport:
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.facings = [1]
	opts.spatial = ComboSolver.SolverSpatialData.new()
	return ComboSolver.solve(opts)


func _branch_table() -> Dictionary:
	if not _fixture._ready_base():
		return {}
	var result := {}
	var spec := {"S": ["L1a", "L1b"], "L1a": ["L2a", "L2b"], "L1b": ["L2a", "L2b"]}
	var index := 0
	for node_id in spec.keys():
		var move := MoveTable._fresh_copy(_fixture._base["5A"] as MoveData)
		move.move_id = node_id
		move.action_key = "V%d" % index
		move.direction_derivation = ""
		var empty: Array[String] = []
		move.input_alternatives = empty.duplicate()
		var targets: Array[String] = []
		for target in spec[node_id]:
			targets.append(target)
		move.cancel_targets = targets
		result[node_id] = move
		index += 1
	return result
