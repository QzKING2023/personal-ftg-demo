extends SceneTree
## 票据 03 插桩自检:默认表裁剪出小子图跑一次 analyze,验证五类分桶归因。
## 用法:--headless --path . -s res://.scratch/acceptance-speedup/profile-03/profile_probe.gd

func _initialize() -> void:
	var full := MoveTable.load_default().moves
	var mini := {}
	for id in ["5A", "5B", "5D", "2D", "6D"]:
		if full.has(id):
			mini[id] = full[id]
	var report := ComboSolver.analyze(mini)
	print("refused=", report.refused, " edges=", report.edges.size(),
		" gaps=", report.gaps.size(), " routes=", report.routes.size())
	print("PROFILE_PROBE_JSON=" + JSON.stringify(ComboSolver.last_request_profile()))
	var options := ComboSolver.SolverOptions.new()
	options.move_table = mini
	var solve_report := ComboSolver.solve(options)
	print("solve refused=", solve_report.refused, " mirror=", solve_report.mirror_consistent,
		" notes=", solve_report.notes.size())
	print("SOLVE_PROFILE_PROBE_JSON=" + JSON.stringify(ComboSolver.last_request_profile()))
	quit(0 if not report.refused and not solve_report.refused else 1)
