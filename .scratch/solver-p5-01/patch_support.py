# -*- coding: utf-8 -*-
# P5: add watchdog/resume support pieces around _analyze/solve.
import io

path = r"D:\Godot\Program\ftgdemo\scripts\combat\combo_solver.gd"
src = io.open(path, encoding="utf-8").read()


def replace_once(old, new, what):
    global src
    assert src.count(old) == 1, (what, src.count(old))
    src = src.replace(old, new)


# 1) instance vars near _route_search_truncated
replace_once(
    "var _route_search_truncated := false\n",
    "var _route_search_truncated := false\n"
    "## 路线报告容量（P5）：默认 MAX_ROUTE_REPORTS；complete 模式换入无上界值——\n"
    "## 上限是报告表面而非语义剪枝，完整模式不设该剪枝（资源由看门狗守护）。\n"
    "var _route_report_cap := MAX_ROUTE_REPORTS\n"
    "## 看门狗到期时刻（P5；Time.get_ticks_msec 口径；-1 = 未启用）。\n"
    "var _watchdog_deadline_ms := -1\n",
    "instance vars",
)

# 2) constants near _ENUMERATE_ENV
replace_once(
    'const _ENUMERATE_ENV := "FTG_SOLVER_ENUMERATE"\n',
    'const _ENUMERATE_ENV := "FTG_SOLVER_ENUMERATE"\n'
    '## 看门狗暂停快照（P5）：schema 常量 + 恢复路径环境变量 + 暂停注记前缀\n'
    '##（续算腿按前缀剥离暂停注记，最终报告与不中断路径指纹全等）。\n'
    'const _RESUME_SCHEMA_VERSION := "ftg-demo-solver-resume-v1"\n'
    'const _RESUME_PATH_ENV := "FTG_SOLVER_RESUME"\n'
    'const _PAUSE_NOTE_PREFIX := "资源看门狗暂停："\n',
    "constants",
)

# 3) watchdog instance helpers + pause persist, inserted right before _analyze
anchor = "func _analyze(facing := 1, start: SolverStartState = null, sort_outputs := false, spatial: SolverSpatialData = null, mode := {}) -> SolverReport:"
helpers = '''## 看门狗到期检查（P5）：只在安全点调用（一个路线源/一个结构循环/一条空间
## 复验完成之后），当前单位的工作总是完整做完——暂停点永远落在可持久化的
## 进度边界上。
func _watchdog_due() -> bool:
\treturn _watchdog_deadline_ms > 0 and Time.get_ticks_msec() >= _watchdog_deadline_ms


## 起始状态的可序列化值（P5 暂停快照用；null 起始保持 null）。
func _start_snapshot_value():
\tif _start == null:
\t\treturn null
\treturn {"stance": int(_start.stance), "air_frames": int(_start.air_frames)}


## 看门狗暂停（P5）：标记 paused_incomplete、如实注记、把 incomplete 状态冻结
## 并持久化。快照自包含——canonical 表文本（_rehydrated_table 可精确重建）、
## 面向/起始/排序/空间/模式、冻结报告与进度游标；恢复腿不重跑边/缺口阶段，
## 从游标续算。暂停不是连段语义：已输出结论逐帧验证过，剩余枚举由
## resume_analysis 续算，截断/未完成的措辞一概不出现。
func _pause_and_persist(report: SolverReport, mode: Dictionary, progress: Dictionary, sort_outputs: bool, spatial_provided: bool) -> void:
\treport.paused_incomplete = true
\tvar path := _resume_target_path(mode)
\tvar phase := str(progress["phase"])
\tvar persisted := false
\tif path != "":
\t\tvar snapshot := {
\t\t\t"schema": _RESUME_SCHEMA_VERSION,
\t\t\t"kind": "analysis",
\t\t\t"table_text": _canonical_variant(_table),
\t\t\t"facing": _facing,
\t\t\t"start": _start_snapshot_value(),
\t\t\t"sort_outputs": sort_outputs,
\t\t\t"spatial": spatial_provided,
\t\t\t"complete": bool(mode.get("complete", false)),
\t\t\t"watchdog_ms": int(mode.get("watchdog_ms", 0)),
\t\t\t"resume_path": path,
\t\t\t"report": _freeze_report(report),
\t\t\t"route_search_truncated": _route_search_truncated,
\t\t\t"progress": {
\t\t\t\t"phase": phase,
\t\t\t\t"sources_done": int(progress["sources_done"]),
\t\t\t\t"cycles_done": int(progress["cycles_done"]),
\t\t\t\t"spatial_done": int(progress["spatial_done"]),
\t\t\t},
\t\t}
\t\tpersisted = _persist_resume_snapshot(path, snapshot)
\tvar done_text := "已完成路线源 %d、结构循环 %d、空间复验 %d 条" % [
\t\tint(progress["sources_done"]), int(progress["cycles_done"]), int(progress["spatial_done"]),
\t]
\tif persisted:
\t\treport.notes.append("%s枚举在%s阶段暂停（%s），暂停不是连段语义、已输出结论仍逐帧验证；未完成状态已持久化（%s），ComboSolver.resume_analysis 可续算至完整报告" % [
\t\t\t_PAUSE_NOTE_PREFIX, _phase_label(phase), done_text, path,
\t\t])
\telse:
\t\treport.notes.append("%s枚举在%s阶段暂停（%s），暂停不是连段语义、已输出结论仍逐帧验证；未配置持久化路径（SolverOptions.resume_path 或环境变量 %s），未完成状态未能持久化——重跑该请求可获得完整报告" % [
\t\t\t_PAUSE_NOTE_PREFIX, _phase_label(phase), done_text, _RESUME_PATH_ENV,
\t\t])


'''
replace_once(anchor, helpers + anchor, "watchdog helpers before _analyze")

# 4) static resume machinery after solve() body end: insert before _clone_move_table
statics = '''## 暂停快照的持久化路径（P5）：显式 resume_path 优先，回退环境变量。
static func _resume_target_path(mode: Dictionary) -> String:
\tvar path := str(mode.get("resume_path", ""))
\tif path != "":
\t\treturn path
\treturn OS.get_environment(_RESUME_PATH_ENV)


## 快照整文件重写（与枚举序文件同一崩溃安全口径；坏行在加载侧拒绝）。
static func _persist_resume_snapshot(path: String, snapshot: Dictionary) -> bool:
\tvar file := FileAccess.open(path, FileAccess.WRITE)
\tif file == null:
\t\treturn false
\tfile.store_line(JSON.stringify(snapshot))
\tfile.close()
\treturn true


## 快照加载：读文件、解析、校验 schema；失败返回 ok=false 与原因。
static func _load_resume_snapshot(path: String) -> Dictionary:
\tif not FileAccess.file_exists(path):
\t\treturn {"ok": false, "error": "文件不存在", "snapshot": {}}
\tvar file := FileAccess.open(path, FileAccess.READ)
\tif file == null:
\t\treturn {"ok": false, "error": "无法打开", "snapshot": {}}
\tvar text := file.get_as_text()
\tfile.close()
\tvar parsed = JSON.parse(text)
\tif parsed.error != OK:
\t\treturn {"ok": false, "error": "JSON 解析失败（%s）" % parsed.error_string, "snapshot": {}}
\tif not (parsed.result is Dictionary):
\t\treturn {"ok": false, "error": "快照不是 JSON 对象", "snapshot": {}}
\tvar snapshot: Dictionary = parsed.result
\tif str(snapshot.get("schema", "")) != _RESUME_SCHEMA_VERSION:
\t\treturn {"ok": false, "error": "schema 不符（%s）" % snapshot.get("schema", ""), "snapshot": {}}
\treturn {"ok": true, "error": "", "snapshot": snapshot}


## 暂停注记剥离（P5 续算腿入口）：暂停是暂态资源状态，不进入最终报告——
## 续算完成的报告与不中断路径指纹全等。
static func _strip_pause_notes(report: SolverReport) -> void:
\tvar kept: Array[String] = []
\tfor note in report.notes:
\t\tif not String(note).begins_with(_PAUSE_NOTE_PREFIX):
\t\t\tkept.append(String(note))
\treport.notes = kept


static func _phase_label(phase: String) -> String:
\tmatch phase:
\t\t"routes":
\t\t\treturn "路线枚举"
\t\t"cycles":
\t\t\treturn "循环证明"
\t\t"spatial":
\t\t\treturn "空间复验"
\treturn "收尾"


## 快照起始值 → SolverStartState（P5；null 保持 null）。
static func _start_from_snapshot(snapshot: Dictionary) -> SolverStartState:
\tvar value = snapshot.get("start", null)
\tif value == null:
\t\treturn null
\tvar start := SolverStartState.new()
\tstart.stance = int(value.get("stance", 1))
\tstart.air_frames = int(value.get("air_frames", 0))
\treturn start


## 看门狗暂停后的续算入口（P5）：读快照 → canonical 重建招式表 → 续算腿
##（边/缺口阶段不重跑，路线/循环/空间从游标继续）。快照是 solve 级
##（kind == "solve"）时先续算暂停的面向线程，再跑剩余面向并按 solve 的镜像
## 对拍/合并/空间分层收尾。续算完成的报告不回写结果缓存——内容与不中断路径
## 一致，缓存由下一次同型请求自然建立；续算仍受同一看门狗预算约束（可再次
## 暂停并改写快照）。
static func resume_analysis(resume_path: String) -> SolverReport:
\t_profile_reset()
\t_profile_v2_reset()
\tvar load := _load_resume_snapshot(resume_path)
\tif not bool(load["ok"]):
\t\treturn _refused_base("恢复快照加载失败（%s）：%s" % [resume_path, load["error"]])
\tvar snapshot: Dictionary = load["snapshot"]
\tvar decoded := _decode_canonical(str(snapshot.get("table_text", "")))
\tif not bool(decoded.get("ok", false)):
\t\treturn _refused_base("恢复快照的招式表解码失败：%s" % decoded.get("error", ""))
\tvar table := _rehydrated_table(decoded.get("value", {}))
\tif str(snapshot.get("kind", "analysis")) == "solve":
\t\treturn _resume_solve(table, snapshot)
\tvar mode := {
\t\t"complete": bool(snapshot.get("complete", false)),
\t\t"watchdog_ms": int(snapshot.get("watchdog_ms", 0)),
\t\t"resume_path": str(snapshot.get("resume_path", resume_path)),
\t\t"resume_state": snapshot,
\t}
\tvar solver := ComboSolver.new(table)
\tvar spatial = SolverSpatialData.new() if bool(snapshot.get("spatial", false)) else null
\treturn solver._analyze(int(snapshot.get("facing", 1)), _start_from_snapshot(snapshot), bool(snapshot.get("sort_outputs", false)), spatial, mode)


## solve 级快照的续算（P5）：线程（暂停的面向分析）先行；线程即主面向时完成
## 后补上 solve 外壳（验证面向行/镜像对拍基准），否则与冻结 primary 合并；
## 剩余面向逐个新算（仍受看门狗约束）并合并，最后按 solve 收尾。
static func _resume_solve(table: Dictionary, snapshot: Dictionary) -> SolverReport:
\tvar thread: Dictionary = snapshot.get("thread", {})
\tvar thread_facing := int(snapshot.get("thread_facing", 1))
\tvar facings: Array[int] = [thread_facing]
\tfor facing in snapshot.get("pending_facings", []):
\t\tfacings.append(int(facing))
\tvar mode := {
\t\t"complete": bool(thread.get("complete", false)),
\t\t"watchdog_ms": int(thread.get("watchdog_ms", 0)),
\t\t"resume_path": str(thread.get("resume_path", "")),
\t\t"resume_state": thread,
\t}
\tvar spatial = SolverSpatialData.new() if bool(thread.get("spatial", false)) else null
\tvar start := _start_from_snapshot(thread)
\tvar run := ComboSolver.new(table)._analyze(thread_facing, start, bool(thread.get("sort_outputs", true)), spatial, mode)
\tif run.paused_incomplete:
\t\treturn _solve_paused_return(run, null, facings, 0, mode, {})
\tvar primary: SolverReport
\tvar pristine: Dictionary = snapshot.get("pristine_sections", {})
\tif snapshot.get("primary", null) == null:
\t\tprimary = run
\t\tpristine = _signature_sections(primary, facings[0])
\t\tvar facing_texts: Array[String] = []
\t\tfor facing in facings:
\t\t\tfacing_texts.append(_facing_text(facing))
\t\tprimary.start_lines.append("验证面向：%s" % "、".join(facing_texts))
\telse:
\t\tprimary = _thaw_report(snapshot["primary"])
\t\t_merge_facing_run(primary, run, thread_facing, pristine)
\tfor i in range(1, facings.size()):
\t\tvar facing_run := ComboSolver.new(table)._analyze(facings[i], start, true, spatial, mode)
\t\tif facing_run.paused_incomplete:
\t\t\treturn _solve_paused_return(facing_run, primary, facings, i, mode, pristine)
\t\t_merge_facing_run(primary, facing_run, facings[i], pristine)
\tif facings.size() > 1:
\t\tprimary.summary += "左右面向分别验证%s。" % ("，镜像一致" if primary.mirror_consistent else "，但结果不一致（见注）")
\tprimary.spatial_lines = _spatial_report_lines(primary, facings, spatial != null)
\treturn primary


## solve 级暂停收尾（P5）：把 `_analyze` 刚持久化的线程快照包一层 solve 上下文
##（非主面向暂停时冻结 primary 连同已完成的合并、原始镜像签名、剩余面向），
## 改写同一恢复文件；返回暂停报告（诚实标记，不进结果缓存）。
static func _solve_paused_return(paused_report: SolverReport, primary: SolverReport, facings: Array[int], paused_index: int, mode: Dictionary, pristine: Dictionary) -> SolverReport:
\tvar path := _resume_target_path(mode)
\tvar wrapped := false
\tif path != "" and FileAccess.file_exists(path):
\t\tvar load := _load_resume_snapshot(path)
\t\tif bool(load["ok"]) and str(load["snapshot"].get("kind", "")) == "analysis":
\t\t\tvar snap: Dictionary = load["snapshot"]
\t\t\tvar pending: Array[int] = []
\t\t\tfor i in range(paused_index + 1, facings.size()):
\t\t\t\tpending.append(facings[i])
\t\t\tsnap["kind"] = "solve"
\t\t\tsnap["thread_facing"] = facings[paused_index]
\t\t\tsnap["primary"] = _freeze_report(primary) if primary != null else null
\t\t\tsnap["pristine_sections"] = pristine
\t\t\tsnap["pending_facings"] = pending
\t\t\twrapped = _persist_resume_snapshot(path, snap)
\tif wrapped:
\t\tpaused_report.notes.append("%ssolve 已在面向 %s 的枚举中途暂停并把未完成状态连同剩余面向持久化（%s）；ComboSolver.resume_analysis 续算" % [
\t\t\t_PAUSE_NOTE_PREFIX, _facing_text(facings[paused_index]), path,
\t\t])
\telse:
\t\tpaused_report.notes.append("%ssolve 已在面向 %s 的枚举中途暂停；未配置可用恢复路径，未完成状态未能持久化——重跑该请求可获得完整报告" % [
\t\t\t_PAUSE_NOTE_PREFIX, _facing_text(facings[paused_index]),
\t\t])
\treturn paused_report


## 单面向结果并入主报告（P5 从 solve 的面向循环抽出，solve 与 resume 共用）：
## 镜像签名对拍（对 frozen 主面向原始签名，不受后续合并影响）、空间结果合并、
## 操作说明拼接——与原循环体逐字节同序。
static func _merge_facing_run(primary: SolverReport, run: SolverReport, facing: int, pristine_sections: Dictionary) -> void:
\tprimary.verified_facings.append(facing)
\tvar sections := _signature_sections(run, facing)
\tvar diff: Array[String] = []
\tfor section in ["edges", "gaps", "routes", "cycles"]:
\t\tif sections[section] != pristine_sections[section]:
\t\t\tdiff.append(_SECTION_LABELS[section])
\tif diff.is_empty():
\t\tprimary.notes.append("面向 %s 镜像验证一致：接续边/配置缺口/路线/循环与相对输入在两侧完全对称" % _facing_text(facing))
\telse:
\t\tprimary.mirror_consistent = false
\t\tprimary.notes.append("面向 %s 与面向 %s 的%s结果不一致——镜像对称被打破，请回报该差异" % [
\t\t\t_facing_text(facing), _facing_text(int(primary.verified_facings[0])), "、".join(diff),
\t\t])
\t_merge_route_spatial(primary, run)
\tprimary.guide_lines.append_array(run.guide_lines)


'''
replace_once("static func _clone_move_table(table: Dictionary) -> Dictionary:\n", statics + "static func _clone_move_table(table: Dictionary) -> Dictionary:\n", "static resume machinery")

io.open(path, "w", encoding="utf-8", newline="").write(src)
print("support pieces ok")
