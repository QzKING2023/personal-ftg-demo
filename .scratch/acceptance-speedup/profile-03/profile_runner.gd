extends SceneTree
## 票据 03:默认表 solve/analyze 各跑一次,输出耗时分解(分类口径见票据 03 Comments)。
## 用法:--headless --path . -s res://.scratch/acceptance-speedup/profile-03/profile_runner.gd
## 产出两行 SOLVER_PROFILE_JSON= 供 profile-report 渲染;票据 04/05 引用其归档结果。

func _initialize() -> void:
	var solve_report := ComboSolver.solve(ComboSolver.SolverOptions.new())
	print("SOLVER_PROFILE_JSON=" + JSON.stringify({
		"request": "solve-default",
		"refused": solve_report.refused,
		"mirror_consistent": solve_report.mirror_consistent,
		"edges": solve_report.edges.size(),
		"gaps": solve_report.gaps.size(),
		"routes": solve_report.routes.size(),
		"cycles": solve_report.cycles.size(),
		"profile": ComboSolver.last_request_profile(),
	}))
	var analyze_report := ComboSolver.analyze()
	print("SOLVER_PROFILE_JSON=" + JSON.stringify({
		"request": "analyze-default",
		"refused": analyze_report.refused,
		"edges": analyze_report.edges.size(),
		"gaps": analyze_report.gaps.size(),
		"routes": analyze_report.routes.size(),
		"cycles": analyze_report.cycles.size(),
		"profile": ComboSolver.last_request_profile(),
	}))
	quit(1 if solve_report.refused or analyze_report.refused else 0)
