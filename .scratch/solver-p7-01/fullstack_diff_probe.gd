extends SceneTree

## P7 全栈差分探针：默认表 solve()/analyze() 在新路径（六开关全默认）与
## 旧路径 oracle（六开关全 legacy）之间的全语义指纹对拍，附冷/热墙钟与
## profile_v2 计数。结果缓存全程旁路；每相位前清探针缓存（差分纪律，
## 先例 reuse_diag_probe.gd）。运行（独立 APPDATA）：
## godot --headless --path . -s res://.scratch/solver-p7-01/fullstack_diff_probe.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics = AcceptanceSolverMetrics.new()
var _fps: Dictionary = {}


func _initialize() -> void:
	print("")
	ComboSolver.set_result_cache_enabled(false)

	var new_cold := _phase("new-cold", Callable(ComboSolver, "solve"))
	var new_warm := _phase("new-warm", Callable(ComboSolver, "solve"))
	_check("cold/warm", new_cold, new_warm)

	_set_legacy(true)
	var old_cold := _phase("old-oracle", Callable(ComboSolver, "solve"))
	_set_legacy(false)
	_check("new/old", new_cold, old_cold)

	var analyze_ref := _phase("analyze-new", Callable(ComboSolver, "analyze"))
	print("analyze ref fingerprint: %s" % analyze_ref)

	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	quit(0)


func _set_legacy(on: bool) -> void:
	ComboSolver._compiled_index_disabled = on
	ComboSolver._edge_probe_cache_disabled = on
	ComboSolver._delay_prefix_restore_disabled = on
	ComboSolver._delay_dp_disabled = on
	ComboSolver._route_leaf_memo_disabled = on
	ComboSolver._cycle_enum_legacy = on
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()


func _phase(label: String, callable: Callable) -> String:
	var started := Time.get_ticks_msec()
	var report = callable.call()
	var elapsed := Time.get_ticks_msec() - started
	var fp := _metrics._fingerprint(report)
	print("PHASE %-11s fp=%s ms=%d" % [label, fp, elapsed])
	print("  counts %s" % JSON.stringify(ComboSolver.last_request_profile_v2()))
	_dump(label, report)
	return fp


func _check(label: String, first: String, second: String) -> void:
	print("CHECK %-9s equal=%s" % [label, str(first == second)])


func _dump(label: String, report) -> void:
	var file := FileAccess.open("res://.scratch/solver-p7-01/report-%s.json" % label, FileAccess.WRITE)
	if file != null:
		var frozen = report if report is Array else ComboSolver._freeze_report(report)
		file.store_string(JSON.stringify(frozen, "  "))
		file.close()
