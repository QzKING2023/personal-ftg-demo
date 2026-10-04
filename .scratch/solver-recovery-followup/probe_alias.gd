extends SceneTree

func _initialize() -> void:
	var loaded := MoveTable.load_default()
	var solver := ComboSolver.new(loaded.moves)
	var contexts := solver._build_contexts()
	var ids: Array[String] = ["2C", "6D", "jC", "j6D", "5B"]
	var kinds := {"6D|jC": ComboSolver.EdgeKind.AIR_EXIT, "j6D|5B": ComboSolver.EdgeKind.NORMAL_LINK}
	var lap: Array[ComboSolver.ChainLink] = []
	for i in range(ids.size()):
		lap.append_array(solver._links_for_edge(ids[i], ids[(i+1)%ids.size()], kinds.get("%s|%s" % [ids[i], ids[(i+1)%ids.size()]], ComboSolver.EdgeKind.CANCEL)))
	for laps in [1, 2]:
		for alias in [true, false]:
			var results := []
			for disabled in [false, true]:
				ComboSolver._delay_prefix_restore_disabled = disabled
				solver.clear_transition_memo()
				var links := solver._cloned_context_links(contexts[ids[0]])
				var fresh_lap := solver._cloned_context_links(lap)
				for n in range(laps):
					links.append_array(fresh_lap if alias else solver._cloned_context_links(lap))
				var run := solver._delay_search(links, solver._adjustable_indices(links), solver._adjustable_indices(lap).size(), {"snapshot_every": ids.size(), "max_frames": ComboSolver.MAX_CYCLE_FRAMES})
				results.append(ComboSolver._test_leaf_projection(run))
				print("laps=", laps, " alias=", alias, " disabled=", disabled, " verified=", run.verified, " reason=", run.reason)
			print("equal=", results[0]==results[1])
	quit()
