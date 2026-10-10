extends "res://tests/acceptance_replay_10.gd"
## Exercises the actual shared replay helper, without running the route suite.

func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failures += 1

func _initialize() -> void:
	## 连段路线票据 01（12×20 尺度）：5[D] 的 120px 位移在薄身下合法穿越并把
	## 玩家带离 5B 触及——边界回归改用同构的简单场景（首段结束后的 5B 新连段
	## 命中单列），事件边界语义不变。
	var plan := {1: _press("A"), 25: _press("B")}
	var run := _run_route(plan, 1, 110, "boundary")
	_check(run.moves == ["5A"], "first combo excludes the fresh 5B after COMBO_ENDED")
	_check(run.hits_after_end.size() == 1 and run.hits_after_end[0].combo_hits == 1,
		"post-end hit retained separately as a new combo")
	_ordered_events()
	_joint_j3a_236c_5d_5b(1)
	_joint_j7_bounce_starters()
	print("BOUNDARY FAILURES=%d" % _failures)
	quit(0 if _failures == 0 else 1)

func _ordered_events() -> void:
	var evidence := preload("res://tests/replay_combo_evidence.gd").new()
	evidence.record(10, 0, "236C", 1, CombatEvent.hit(1, 1, 1, false, 1))
	evidence.record(20, 0, "236C", 1, CombatEvent.hit(1, 1, 2, false, 2))
	evidence.record(20, 1, "236C", 1, CombatEvent.combo_ended(CombatEvent.ComboEndReason.FINISHER))
	evidence.record(20, 2, "5B", 2, CombatEvent.hit(1, 1, 1))
	evidence.record(40, 0, "5B", 3, CombatEvent.hit(1, 1, 2))
	_check(evidence.move_sequence == ["236C"] and evidence.hits.size() == 2,
		"two segments are two hits of one move; terminal hit before end is included")
	_check(evidence.hits_after_end.size() == 2 and evidence.hits_after_end[0].order == 2,
		"same-frame HIT after END and later hits stay outside first combo")
	var reverse := preload("res://tests/replay_combo_evidence.gd").new()
	reverse.record(1, 0, "", 0, CombatEvent.combo_ended(CombatEvent.ComboEndReason.MOVE_RECOVERED))
	reverse.record(1, 1, "5B", 1, CombatEvent.hit(1, 1, 1))
	_check(reverse.hits.is_empty() and reverse.hits_after_end.size() == 1,
		"END then HIT order cannot be inferred from end-of-frame combo state")
	var repeated := preload("res://tests/replay_combo_evidence.gd").new()
	repeated.record(1, 0, "5B", 1, CombatEvent.hit(1, 1, 1))
	repeated.record(2, 0, "5B", 2, CombatEvent.hit(1, 1, 2))
	_check(repeated.move_sequence == ["5B", "5B"], "distinct actions with same id remain distinct moves")
