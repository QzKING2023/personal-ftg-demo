extends SceneTree
## 联合验收遗留诊断，故意与已知行为基线分开：非零退出表示规格缺口仍存在。
func _initialize() -> void:
	var failures := 0
	for row in [[0, false, "8"], [1, false, "9"], [-1, false, "7"], [0, true, ""]]:
		var session := CombatSession.new()
		session.step(FrameInput.make(row[0], true, "", row[1]))
		var observed := String(session.debug_snapshot()["direction_sequence"])
		var ok: bool = observed == row[2]
		print(("PASS " if ok else "FAIL ") + "F1 Space axis=%d down=%s direction=%s expected=%s" %
			[row[0], row[1], observed, row[2]])
		if not ok:
			failures += 1
	quit(1 if failures else 0)
