extends SceneTree

## P2（perf-edge-cache）默认表证据探针（.scratch 证据运行，不入测试套）：
##   1. 指纹差分：solve() 探针缓存关 / 开(冷) / 开(热) 三形态全语义指纹全等；
##      analyze() 无缓存 vs solve 后复用全等——默认表级 Tier A/B。
##   2. 量化：探针命中率（edge/timing 命名空间）、session_steps 降幅、墙钟。
## 完整结果缓存全程旁路（set_result_cache_enabled(false)），请求真实重跑。
## 运行（独立 APPDATA）：godot --headless --path . -s res://.scratch/.../default_edge_probe.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")

var _metrics = AcceptanceSolverMetrics.new()
var _payload := {}


func _initialize() -> void:
	print("")
	ComboSolver.set_result_cache_enabled(false)

	var run_off := _solve_with("off")
	var run_cold := _solve_with("cold")
	var run_hot := _solve_with("hot")
	var analyze_off := _analyze_with(false)
	var analyze_reuse := _analyze_with(true)

	var all_equal: bool = run_cold["fingerprint"] == run_off["fingerprint"] \
		and run_hot["fingerprint"] == run_off["fingerprint"] \
		and analyze_reuse["fingerprint"] == analyze_off["fingerprint"]
	print("PASS  default-table fingerprints identical: solve cache off/cold/hot and analyze off/reuse" if all_equal \
		else "FAIL  default-table fingerprint mismatch")
	var hot_steps: int = int(run_hot["counts"]["session_steps"])
	var off_steps: int = int(run_off["counts"]["session_steps"])
	print("PASS  default-table hot replay strictly fewer steps (%d < %d)" % [hot_steps, off_steps] if hot_steps < off_steps \
		else "FAIL  default-table hot replay not reduced (%d >= %d)" % [hot_steps, off_steps])
	_payload = {
		"solve_cache_off": _record(run_off),
		"solve_cold": _record(run_cold),
		"solve_hot": _record(run_hot),
		"analyze_cache_off": _record(analyze_off),
		"analyze_reuse": _record(analyze_reuse),
		"fingerprint_equal": all_equal,
	}
	print("EDGE_CACHE_DEFAULT_JSON=" + JSON.stringify(_payload))
	ComboSolver.set_result_cache_enabled(true)
	ComboSolver.clear_result_cache()
	ComboSolver.clear_edge_probe_cache()
	quit(0 if all_equal else 1)


func _solve_with(mode: String) -> Dictionary:
	ComboSolver._edge_probe_cache_disabled = mode == "off"
	if mode == "cold":
		ComboSolver.clear_edge_probe_cache()
	var before := ComboSolver.edge_probe_cache_stats()
	var started := Time.get_ticks_usec()
	var report := ComboSolver.solve()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	ComboSolver._edge_probe_cache_disabled = false
	return {
		"report": report,
		"fingerprint": _metrics._fingerprint(report),
		"counts": ComboSolver.last_request_profile_v2(),
		"stats": _delta(before, ComboSolver.edge_probe_cache_stats()),
		"elapsed_ms": elapsed,
	}


func _analyze_with(enable_cache: bool) -> Dictionary:
	ComboSolver._edge_probe_cache_disabled = not enable_cache
	var before := ComboSolver.edge_probe_cache_stats()
	var started := Time.get_ticks_usec()
	var report := ComboSolver.analyze()
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	ComboSolver._edge_probe_cache_disabled = false
	return {
		"report": report,
		"fingerprint": _metrics._fingerprint(report),
		"counts": ComboSolver.last_request_profile_v2(),
		"stats": _delta(before, ComboSolver.edge_probe_cache_stats()),
		"elapsed_ms": elapsed,
	}


func _delta(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"edge_hits": int(after["edge_hits"]) - int(before["edge_hits"]),
		"edge_misses": int(after["edge_misses"]) - int(before["edge_misses"]),
		"timing_hits": int(after["timing_hits"]) - int(before["timing_hits"]),
		"timing_misses": int(after["timing_misses"]) - int(before["timing_misses"]),
	}


func _record(run: Dictionary) -> Dictionary:
	var edge_total: int = int(run["stats"]["edge_hits"]) + int(run["stats"]["edge_misses"])
	var edge_rate: float = float(run["stats"]["edge_hits"]) / float(edge_total) if edge_total > 0 else 0.0
	return {
		"stats": run["stats"],
		"edge_hit_rate": edge_rate,
		"session_steps": int(run["counts"]["session_steps"]),
		"elapsed_ms": run["elapsed_ms"],
	}
