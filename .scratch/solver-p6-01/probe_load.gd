extends SceneTree

func _initialize() -> void:
	var stats: Dictionary = ComboSolver.result_cache_stats()
	print("PROBE entries=", stats["entries"])
	var state = Engine.get_meta("ftg_demo_combo_solver_result_cache_v1")
	print("PROBE has_32fb=", (state["entries"] as Dictionary).has("32fbba13d69317253f51e46c7fda8941681005a790be14b792a28ec465a81e8c"))
	print("PROBE has_6ddd=", (state["entries"] as Dictionary).has("6dddfeff7f75368ffb98cb8ea9c926f85cdbeec4b6f5f4865e1fe63f922199e5"))
	var e = (state["entries"] as Dictionary).get("32fbba13d69317253f51e46c7fda8941681005a790be14b792a28ec465a81e8c")
	if e != null:
		var d: String = str((e as Dictionary).get("descriptor", ""))
		print("PROBE desc_len=", d.length())
		var f := FileAccess.open("res://.scratch/solver-p6-01/probe-desc.txt", FileAccess.WRITE)
		f.store_string(d)
		f.close()
	quit(0)
