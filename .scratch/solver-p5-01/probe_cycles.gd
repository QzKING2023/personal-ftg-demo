extends SceneTree

## P5 探针：SCC+Johnson 环枚举 vs 旧全起点 DFS + seen 去重，合成图逐字节对拍
##（顺序敏感）。不触 CombatSession，秒级。

func _initialize() -> void:
	var solver := ComboSolver.new({})
	var graphs: Array = [
		{},
		{"a": ["a"]},
		{"a": ["b"], "b": ["c"]},
		{"a": ["b"], "b": ["a"]},
		{"z": ["y"], "y": ["z"], "a": ["z"]},
		{"a": ["b", "c"], "b": ["a"], "c": ["a"]},
		{"a": ["b", "c", "d"], "b": ["a", "c", "d"], "c": ["a", "b", "d"], "d": ["a", "b", "c"]},
		{"a": ["b"], "c": ["d"], "d": ["c"], "b": ["b", "c"]},
		{"s1": ["s2"], "s2": ["s1", "t"], "t": ["u"], "u": []},
		{"m3": ["m1"], "m1": ["m2"], "m2": ["m3"], "m0": ["m1"], "m4": ["m3", "m5"], "m5": ["m4"]},
	]
	var bad := 0
	for i in range(graphs.size()):
		var adj: Dictionary = graphs[i]
		ComboSolver._cycle_enum_legacy = false
		var fresh: Array = solver._elementary_cycles(adj)
		ComboSolver._cycle_enum_legacy = true
		var legacy: Array = solver._elementary_cycles(adj)
		ComboSolver._cycle_enum_legacy = false
		var same := str(fresh) == str(legacy)
		if not same:
			bad += 1
		print("graph %d cycles=%d identical=%s" % [i, fresh.size(), same])
		if not same:
			print("  fresh: " + str(fresh))
			print("  legacy: " + str(legacy))
		for cycle in fresh:
			var canonical: Array[String] = solver._canonical_cycle(cycle)
			if str(canonical) != str(cycle):
				bad += 1
				print("  NOT canonical: " + str(cycle))
	print(bad == 0 and graphs.size() > 0)
	quit(0 if bad == 0 else 1)
