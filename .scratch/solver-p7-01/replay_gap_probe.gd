extends SceneTree

## P7 缺口归因探针：对 sweep 记录的 descriptor 文本调用 _sweep_replay，
## 打印重建失败时的原文本与重 build 文本的首个差异字段。独立 APPDATA 运行。

func _initialize() -> void:
	var f := FileAccess.open("res://.scratch/solver-p7-01/replay-gap-descriptor.txt", FileAccess.READ)
	if f == null:
		print("FAIL no descriptor file")
		quit(1)
		return
	var text := f.get_as_text()
	f.close()
	var res: Dictionary = ComboSolver._sweep_replay(text)
	print("ok=", res.get("ok", false), " error=", res.get("error", ""))
	if not bool(res.get("ok", false)):
		var rebuilt: String = str(ComboSolver._last_request.get("text", ""))
		print("orig len=", text.length(), " rebuilt len=", rebuilt.length())
		var n := mini(text.length(), rebuilt.length())
		var i := 0
		while i < n and text[i] == rebuilt[i]:
			i += 1
		var lo := maxi(0, i - 80)
		print("first diff at ", i)
		print("orig ...", text.substr(lo, 200))
		print("rbld ...", rebuilt.substr(lo, 200))
	quit(0)
