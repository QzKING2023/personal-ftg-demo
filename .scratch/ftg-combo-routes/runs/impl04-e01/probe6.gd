extends SceneTree
func _initialize() -> void:
	var ids: Array[String] = ["2A", "2B", "2C"]
	var r := ComboSolver.route_report(ids)
	print("refused=", r.refused, " routes=", r.routes.size())
	for route in r.routes:
		print("timing_valid=", route.timing_valid, " hits=", route.combo_hits, " hit_frames=", str(route.hit_frames), " note=", route.note)
	quit(0)
