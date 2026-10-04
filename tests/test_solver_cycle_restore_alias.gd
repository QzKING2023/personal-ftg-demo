extends SceneTree

## Regression for cycle proof links being reused by reference across laps.
## Prefix restore mutates wait on adjustable ChainLink objects; each lap must
## own an independent copy so restore-on/off has the same representative run.

var _failures := 0

func _initialize() -> void:
	var loaded := MoveTable.load_default()
	if not loaded.ok:
		print("FAIL manifest load")
		quit(1)
		return
	var solver := ComboSolver.new(loaded.moves)
	var contexts := solver._build_contexts()
	var ids: Array[String] = ["2C", "6D", "jC", "j6D", "5B"]
	var kinds := {"6D|jC": ComboSolver.EdgeKind.AIR_EXIT, "j6D|5B": ComboSolver.EdgeKind.NORMAL_LINK}
	var results := []
	for disabled in [false, true]:
		ComboSolver._delay_prefix_restore_disabled = disabled
		solver.clear_transition_memo()
		var cycle := solver._simulate_cycle(ids, contexts, kinds)
		results.append(ComboSolver._freeze_cycle(cycle))
	_check(results[0] == results[1], "cycle restore on/off preserves representative result")
	ComboSolver._delay_prefix_restore_disabled = false
	print("TOTAL failures=", _failures)
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)
