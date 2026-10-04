extends SceneTree

func _initialize() -> void:
	var loaded := MoveTable.load_default()
	if not loaded.ok:
		print("load fail")
		quit(1)
		return
	var solver := ComboSolver.new(loaded.moves)
	var report := solver._analyze(1, null, false, null)
	var adj := {}
	for edge in report.edges:
		if not edge.valid:
			continue
		if not adj.has(edge.from_id):
			adj[edge.from_id] = [] as Array[String]
		var targets: Array[String] = adj[edge.from_id]
		if not targets.has(edge.to_id):
			targets.append(edge.to_id)
	print("adj nodes: ", adj.size())
	ComboSolver._cycle_enum_legacy = false
	var fresh: Array = solver._elementary_cycles(adj)
	ComboSolver._cycle_enum_legacy = true
	var legacy: Array = solver._elementary_cycles(adj)
	ComboSolver._cycle_enum_legacy = false
	print("cycles: ", fresh.size(), " identical: ", str(fresh) == str(legacy))
	if str(fresh) != str(legacy):
		for i in range(maxi(fresh.size(), legacy.size())):
			var f := str(fresh[i]) if i < fresh.size() else "<none>"
			var l := str(legacy[i]) if i < legacy.size() else "<none>"
			if f != l:
				print("first diff at ", i)
				print("  fresh: ", f)
				print("  legacy: ", l)
				break
	quit(0)
