extends RefCounted
## Ordered evidence for ONE combo. HIT after its first end is never appended back.
var moves: Array[String] = [] # Compatibility projection: one entry per HIT, not per move.
var move_sequence: Array[String] = []
var hits: Array[Dictionary] = []
var hits_after_end: Array[Dictionary] = []
var ends: Array[Dictionary] = []
var _last_action := -1

func record(frame: int, order: int, move_id: String, action: int, event: CombatEvent) -> void:
	if event.type == CombatEvent.Type.COMBO_ENDED:
		ends.append({"frame": frame, "order": order, "reason": event.combo_end_reason})
	elif event.type == CombatEvent.Type.HIT:
		var hit := {"frame": frame, "order": order, "move": move_id,
			"action": action, "segment": event.move_segment, "combo_hits": event.combo_hits}
		if not ends.is_empty():
			hits_after_end.append(hit)
			return
		hits.append(hit)
		moves.append(move_id)
		if action != _last_action:
			move_sequence.append(move_id)
			_last_action = action
