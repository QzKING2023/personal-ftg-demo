extends SceneTree

## Regression for the P3 restore equivalence gap found in the default cycle
## search.  A trie node is identified by input bytes, but its checkpoint also
## carries the run's verified-hit counter.  Different expected hit schedules
## must therefore never share a scope even when their input prefix is equal.

var _failures := 0

func _initialize() -> void:
	var loaded := MoveTable.load_default()
	if not loaded.ok:
		print("FAIL manifest load refused: ", loaded.first_error())
		quit(1)
		return
	var solver := ComboSolver.new(loaded.moves)
	var opts := {"snapshot_every": 1, "max_frames": 2400}
	var same_inputs := {
		"inputs": [],
		"hit_frames": [10, 20],
		"hit_moves": ["5A", "5B"],
		"jump_frame": -1,
		"land_frame": -1,
	}
	var different_expected_hits := same_inputs.duplicate(true)
	different_expected_hits["hit_frames"] = [10, 21]
	var first := solver._memo_scope_key(opts, same_inputs)
	var second := solver._memo_scope_key(opts, different_expected_hits)
	_check(first != second, "restore scope separates equal input prefixes with different expected hit schedules")
	_check(solver._compiled_semantics_key(same_inputs) != solver._compiled_semantics_key(different_expected_hits),
		"restore scope signature includes hit frame and move expectations")
	print("TOTAL failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)
