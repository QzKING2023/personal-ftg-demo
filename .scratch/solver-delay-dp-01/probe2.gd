extends SceneTree

func _initialize() -> void:
	print("A pow2m1022=", pow(2.0, -1022.0))
	print("B literal=", 2.225e-308 > 0.0)
	print("C literal_full=", 2.2250738585072014e-308 > 0.0)
	print("D small=", 1e-200 > 0.0)
	print("E pow2_pos=", pow(2.0, -1022.0) > 0.0)
	print("F denorm=", 1e-310 > 0.0)
	print("G cmp_denorm_vs_pow=", 1e-310 < pow(2.0, -1022.0))
	quit(0)
