extends SceneTree
const Fixture = preload("res://tests/solver_growth_fixture.gd")

func _initialize() -> void:
	var table := Fixture.new().table(4)
	ComboSolver.clear_result_cache()
	ComboSolver.solve(_opts(table))
	var a := ComboSolver.last_request_profile_v2()
	ComboSolver.clear_result_cache()
	ComboSolver.solve(_opts(table))
	var b := ComboSolver.last_request_profile_v2()
	var keys: Array = a.keys()
	keys.sort()
	for k in keys:
		if a[k] != b.get(k):
			print("DIFF ", k, " first=", a[k], " second=", b.get(k))
		else:
			print("same ", k, "=", a[k])
	quit(0)

func _opts(table: Dictionary) -> ComboSolver.SolverOptions:
	var o := ComboSolver.SolverOptions.new()
	o.move_table = table
	return o
