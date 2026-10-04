extends SceneTree

func _initialize() -> void:
	var load_result := MoveTable.load_default()
	var solver := ComboSolver.new(load_result.moves)
	var contexts := solver._build_contexts()
	## 找一个空中招式有 landing_cancel_targets 的 jump 对，构成 [ground, air] 圈。
	var pair := []
	for launcher_id in solver._table:
		var launcher := solver._table[launcher_id] as MoveData
		if launcher == null or launcher.stance != MoveData.Stance.GROUND:
			continue
		if launcher.jump_cancel_targets.is_empty() or not contexts.has(launcher_id):
			continue
		for air_id in launcher.jump_cancel_targets:
			var air := solver._table[air_id] as MoveData
			if air != null and not air.landing_cancel_targets.is_empty():
				for back_id in air.landing_cancel_targets:
					if back_id == launcher_id:
						pair = [launcher_id, air_id]
						break
				if not pair.is_empty():
					break
		if not pair.is_empty():
			break
	if pair.is_empty():
		print("no landing back-edge cycle found")
		quit(0)
	print("cycle=", pair)
	var context: Array = solver._cloned_context_links(contexts[pair[0]])
	var lap_links: Array[ComboSolver.ChainLink] = []
	lap_links.append_array(solver._links_for_edge(pair[0], pair[1], ComboSolver.EdgeKind.JUMP_CANCEL))
	lap_links.append_array(solver._links_for_edge(pair[1], pair[0], ComboSolver.EdgeKind.LANDING_CANCEL))
	var links: Array[ComboSolver.ChainLink] = []
	for link in context:
		links.append(link)
	for lap in range(ComboSolver.MAX_CYCLE_LAPS):
		for lap_link in lap_links:
			links.append(lap_link)
	var adjustable := solver._adjustable_indices(links)
	var per_lap := solver._adjustable_indices(lap_links).size()
	print("adjustable=", adjustable.size(), " per_lap=", per_lap)
	solver.reset_delay_dp_stats()
	var opts := {"snapshot_every": 2, "max_frames": ComboSolver.MAX_CYCLE_FRAMES}
	var run := solver._delay_search(links, adjustable, per_lap if per_lap > 0 else adjustable.size(), opts)
	print("ok=", run.get("ok"), " proven=", run.get("proven_period", -1), " break=", run.get("break_kind", ""), " verified=", run.get("verified", 0))
	print("dp_stats=", solver.delay_dp_stats())
	quit(0)
