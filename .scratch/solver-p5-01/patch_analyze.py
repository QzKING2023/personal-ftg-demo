# -*- coding: utf-8 -*-
# P5: rewrite ComboSolver._analyze with mode/progress/watchdog/resume legs.
import io

path = r"D:\Godot\Program\ftgdemo\scripts\combat\combo_solver.gd"
src = io.open(path, encoding="utf-8").read()

old_head = (
    "func _analyze(facing := 1, start: SolverStartState = null, sort_outputs := false, "
    "spatial: SolverSpatialData = null) -> SolverReport:\n"
    "\t_route_search_truncated = false\n"
    "\t_facing = facing\n"
    "\t_start = start\n"
    "\t_pin_dx = PIN_DX\n"
)
i = src.index(old_head)
tail_marker = "\n\n\n## 一条验证完的接续边入报告与路线图"
k = src.index(tail_marker, i)

new_analyze = '''func _analyze(facing := 1, start: SolverStartState = null, sort_outputs := false, spatial: SolverSpatialData = null, mode := {}) -> SolverReport:
\tvar complete := bool(mode.get("complete", false))
\t_route_search_truncated = false
\t_route_report_cap = 1 << 30 if complete else MAX_ROUTE_REPORTS
\t_facing = facing
\t_start = start
\t_pin_dx = PIN_DX
\tvar watchdog_ms := int(mode.get("watchdog_ms", 0))
\t_watchdog_deadline_ms = Time.get_ticks_msec() + watchdog_ms if watchdog_ms > 0 else -1
\tvar report := SolverReport.new()
\tvar progress := {"phase": "routes", "sources_done": 0, "cycles_done": 0, "spatial_done": 0}
\tvar resume_state: Dictionary = mode.get("resume_state", {})
\tvar contexts := {}
\tvar valid_adj := {}
\tvar edge_kinds := {}
\tvar sources: Array[String] = []
\tif resume_state.is_empty():
\t\treport.scope = SCOPE_TEXT
\t\treport.verified_facings = [facing]
\t\treport.table_lines = _table_summary_lines()
\t\treport.start_lines = _start_state_lines()
\t\tif spatial != null:
\t\t\treport.start_lines.append("空间验证：已提供空间数据——地面站位 × 48/64/80 px 身体中心水平距离网格（验证面向与结果见空间分层节）")
\t\treport.first_candidates = _first_candidates()
\t\treport.binding_lines = _binding_variant_lines()
\t\tif _table_has_throw:
\t\t\treport.notes.append("普通投是 B+C 组合输入，无单键起手，不在首招候选（组合输入调度不在本入口范围）")
\t\tcontexts = _build_contexts()
\t\tvar timing_cache := {}
\t\t_profile_enter(_PROFILE_EDGE)
\t\tif _index != null:
\t\t\t## 索引路径（P1）：配置边候选在 _init 时已按旧循环的完整枚举序冻结成
\t\t\t## 描述符（from 表序 × kind 固定序 × 目标声明序，含蓄力变体派生边）。
\t\t\tfor descriptor in _index.configured_edges:
\t\t\t\t_profile_v2_bump("structure_candidates")
\t\t\t\tvar edge := _build_edge(descriptor.from_id, descriptor.to_id, descriptor.kind, contexts, timing_cache)
\t\t\t\t_register_edge(edge, report, valid_adj, edge_kinds)
\t\telse:
\t\t\tfor from_id in _table:
\t\t\t\tvar from_move := _table[from_id] as MoveData
\t\t\t\t## 投技不走单键/取消链起手（投技行为在后续 issue 实装），不进入接续图。
\t\t\t\tif from_move == null or from_move.is_throw():
\t\t\t\t\tcontinue
\t\t\t\tvar kinds_and_targets := [
\t\t\t\t\t[EdgeKind.CANCEL, from_move.cancel_targets],
\t\t\t\t\t[EdgeKind.CHAIN_CANCEL, from_move.chain_cancel_targets],
\t\t\t\t\t[EdgeKind.SPECIAL_CANCEL, from_move.special_cancel_targets],
\t\t\t\t\t[EdgeKind.JUMP_CANCEL, from_move.jump_cancel_targets],
\t\t\t\t\t[EdgeKind.LANDING_CANCEL, from_move.landing_cancel_targets],
\t\t\t\t\t[EdgeKind.NORMAL_LINK, from_move.link_targets],
\t\t\t\t\t[EdgeKind.REKKA_DERIVE, _rekka_targets_of(from_move)],
\t\t\t\t\t[EdgeKind.SPECIAL_ENTRY, from_move.special_entry_targets],
\t\t\t\t\t[EdgeKind.SPECIAL_ENTRY_LINK, from_move.special_entry_link_targets],
\t\t\t\t\t[EdgeKind.AIR_EXIT, from_move.air_exit_targets],
\t\t\t\t\t[EdgeKind.HIT_LANDING_CANCEL, from_move.hit_landing_cancel_targets],
\t\t\t\t]
\t\t\t\tfor pair in kinds_and_targets:
\t\t\t\t\tvar kind: EdgeKind = pair[0]
\t\t\t\t\tfor to_id in pair[1]:
\t\t\t\t\t\t_profile_v2_bump("structure_candidates")
\t\t\t\t\t\tvar edge := _build_edge(from_id, to_id, kind, contexts, timing_cache)
\t\t\t\t\t\t_register_edge(edge, report, valid_adj, edge_kinds)
\t\t\t\t\t\t## 蓄力变体（票据 06）：目标声明蓄力时，同一接缝另验证按住至阈值
\t\t\t\t\t\t## 的蓄力版提交（to 换为 charge_only 目标，独立成边、独立验证）。
\t\t\t\t\t\tvar pair_to := _table.get(to_id) as MoveData
\t\t\t\t\t\tif pair_to != null and pair_to.is_chargeable() and _table.has(pair_to.charge_move_id):
\t\t\t\t\t\t\t_profile_v2_bump("structure_candidates")
\t\t\t\t\t\t\t\tvar charged_edge := _build_edge(from_id, pair_to.charge_move_id, kind, contexts, timing_cache)
\t\t\t\t\t\t\t\t_register_edge(charged_edge, report, valid_adj, edge_kinds)
\t\t_profile_exit()
\t\t_profile_enter(_PROFILE_GAP)
\t\t_enumerate_gaps(contexts, timing_cache, report)
\t\t_profile_exit()
\t\tif report.edges.any(func(edge: SolverEdge) -> bool: return edge.blocked_valid):
\t\t\treport.notes.append("被防取消边只在固定探针姿态下验证取消时序（被防是独立接触结果，不产生命中，不入路线/循环图）；被防安全性（指定反击招式、时机、距离、版中/版边与左右面向）必须真实空间回放（replay-required），静态报告不下结论")
\t\t## 图的路线起点：起始姿态下单键可起手、无方向派生的打击招式（按表内顺序，确定性枚举）。
\t\tfor move_id in _table:
\t\t\tif _is_plain_start_id(move_id):
\t\t\t\tsources.append(move_id)
\telse:
\t\t## 续算腿（P5）：报告与进度游标来自快照；上下文/路线图/起点按确定性重建
\t\t##（邻接表按冻结边注册序复原，与首腿 _register_edge 同构；上下文与起点是
\t\t## 表/面向/起始的确定函数）。边/缺口阶段不重跑——结论已在冻结报告里。
\t\treport = _thaw_report(resume_state.get("report", {}))
\t\treport.paused_incomplete = false
\t\t_strip_pause_notes(report)
\t\t_route_search_truncated = bool(resume_state.get("route_search_truncated", false))
\t\tvar saved: Dictionary = resume_state.get("progress", {})
\t\tfor key in ["sources_done", "cycles_done", "spatial_done"]:
\t\t\tprogress[key] = int(saved.get(key, 0))
\t\tprogress["phase"] = str(saved.get("phase", "routes"))
\t\tcontexts = _build_contexts()
\t\tfor edge in report.edges:
\t\t\tif not edge.valid:
\t\t\t\tcontinue
\t\t\tif not valid_adj.has(edge.from_id):
\t\t\t\tvalid_adj[edge.from_id] = [] as Array[String]
\t\t\tvar targets: Array[String] = valid_adj[edge.from_id]
\t\t\tif targets.has(edge.to_id):
\t\t\t\tcontinue
\t\t\ttargets.append(edge.to_id)
\t\t\tvar key := "%s|%s" % [edge.from_id, edge.to_id]
\t\t\tif not edge_kinds.has(key):
\t\t\t\tedge_kinds[key] = edge.kind
\t\tfor move_id in _table:
\t\t\tif _is_plain_start_id(move_id):
\t\t\t\tsources.append(move_id)
\tif str(progress["phase"]) == "routes":
\t\t_profile_enter(_PROFILE_ROUTE)
\t\tfor i in range(int(progress["sources_done"]), sources.size()):
\t\t\t_walk_routes(sources[i], [sources[i]], valid_adj, report.routes, contexts, edge_kinds)
\t\t\tprogress["sources_done"] = i + 1
\t\t\tif _route_search_truncated:
\t\t\t\tbreak
\t\t\tif _watchdog_due():
\t\t\t\t_profile_exit()
\t\t\t\t_pause_and_persist(report, mode, progress, sort_outputs, spatial != null)
\t\t\t\treturn report
\t\t_profile_exit()
\t\tif _route_search_truncated:
\t\t\treport.notes.append("可读路线枚举达到 %d 条报告上限，路线集合未完成；已输出的路线仍逐帧验证，接续边与循环结论不受该报告上限影响" % MAX_ROUTE_REPORTS)
\t\tprogress["phase"] = "cycles"
\tif str(progress["phase"]) == "cycles":
\t\t_profile_enter(_PROFILE_ROUTE)
\t\tvar structural_cycles := _elementary_cycles(valid_adj)
\t\tfor i in range(int(progress["cycles_done"]), structural_cycles.size()):
\t\t\tvar cycle_ids: Array[String] = structural_cycles[i]
\t\t\tvar cycle := _simulate_cycle(cycle_ids, contexts, edge_kinds)
\t\t\tif cycle.outcome == SolverCycle.Outcome.PROVEN:
\t\t\t\treport.cycles.append(cycle)
\t\t\telse:
\t\t\t\tvar label: String = " → ".join(cycle_ids) + " → 回到 " + cycle_ids[0]
\t\t\t\tif cycle.outcome == SolverCycle.Outcome.HORIZON_TRUNCATED \\
\t\t\t\t\t\tor cycle.outcome == SolverCycle.Outcome.LAPS_EXHAUSTED:
\t\t\t\t\treport.incomplete_cycle_count += 1
\t\t\t\t\treport.notes.append("结构性循环 %s：%s" % [label, cycle.reason])
\t\t\t\telse:
\t\t\t\t\treport.notes.append("结构性循环 %s 在逐圈模拟中断开，不构成有效循环：%s" % [label, cycle.reason])
\t\t\tprogress["cycles_done"] = i + 1
\t\t\tif _watchdog_due():
\t\t\t\t_profile_exit()
\t\t\t\t_pause_and_persist(report, mode, progress, sort_outputs, spatial != null)
\t\t\t\treturn report
\t\t_profile_exit()
\t\tprogress["phase"] = "spatial"
\tif spatial != null and str(progress["phase"]) == "spatial":
\t\t_profile_enter(_PROFILE_ROUTE)
\t\tfor i in range(int(progress["spatial_done"]), report.routes.size()):
\t\t\t_verify_route_spatial(report.routes[i], contexts, edge_kinds)
\t\t\tprogress["spatial_done"] = i + 1
\t\t\tif _watchdog_due():
\t\t\t\t_profile_exit()
\t\t\t\t_pause_and_persist(report, mode, progress, sort_outputs, spatial != null)
\t\t\t\treturn report
\t\t_profile_exit()
\t\tprogress["phase"] = "done"
\treport.safe = report.cycles.is_empty()
\tif sort_outputs:
\t\t## 稳定排序（issue 19）：排序键含全部并列维度（from/to/kind 唯一、路线标签唯一），
\t\t## 与枚举顺序无关的确定输出，供跨运行/跨面向对拍。
\t\treport.edges.sort_custom(func(a: SolverEdge, b: SolverEdge) -> bool:
\t\t\treturn _edge_sort_key(a) < _edge_sort_key(b))
\t\treport.gaps.sort_custom(func(a: SolverEdge, b: SolverEdge) -> bool:
\t\t\treturn _edge_sort_key(a) < _edge_sort_key(b))
\t\treport.routes.sort_custom(func(a: SolverRoute, b: SolverRoute) -> bool:
\t\t\treturn a.label() < b.label())
\t\treport.cycles.sort_custom(func(a: SolverCycle, b: SolverCycle) -> bool:
\t\t\treturn a.label() < b.label())
\treport.summary = _build_summary(report)
\treport.guide_lines = _guide_lines(report)
\treturn report'''

src = src[:i] + new_analyze + src[k:]
io.open(path, "w", encoding="utf-8", newline="").write(src)
print("replaced _analyze ok")
