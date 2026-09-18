extends SceneTree
## 独立入口：--headless --path . -s res://tools/solver_report.gd -- [--spatial]
func _initialize() -> void:
	var options := ComboSolver.SolverOptions.new()
	if "--spatial" in OS.get_cmdline_user_args():
		options.spatial = ComboSolver.SolverSpatialData.new()
	var report := ComboSolver.solve(options)
	for line in report.to_lines():
		print(line)
	quit(1 if report.refused else 0)
