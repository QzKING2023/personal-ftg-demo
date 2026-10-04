extends SceneTree

func _initialize() -> void:
	var t1 := MoveData.default_table()
	(t1["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	var t6 := MoveData.default_table()
	(t6["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	(t6["jB"] as MoveData).landing_cancel_targets = ["5D", "5A"]
	var opts1 := ComboSolver.SolverOptions.new()
	opts1.move_table = t1
	var opts6 := ComboSolver.SolverOptions.new()
	opts6.move_table = t6
	var r1: Dictionary = ComboSolver._build_solve_request(true, opts1, t1, true)
	var r6: Dictionary = ComboSolver._build_solve_request(true, opts6, t6, true)
	print("t1 cacheable=", r1["cacheable"], " digest=", str(r1["digest"]).substr(0, 16))
	print("t6 cacheable=", r6["cacheable"], " digest=", str(r6["digest"]).substr(0, 16))
	var a: String = r1["text"]
	var b: String = r6["text"]
	print("equal=", a == b)
	if a != b:
		var n := mini(a.length(), b.length())
		for i in range(n):
			if a[i] != b[i]:
				print("first diff at ", i, ":\nA:...", a.substr(maxi(0, i - 60), 120), "\nB:...", b.substr(maxi(0, i - 60), 120))
				break
	quit(0)
