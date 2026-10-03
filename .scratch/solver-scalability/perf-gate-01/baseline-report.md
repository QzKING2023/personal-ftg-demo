# P0 性能基线与增长回归门——交付档案（perf-gate-01）

日期：2026-10-03；分支 feature（票据 09 在途树之上叠加，只做观测与测试）。
引擎：Godot 4.5.1 stable mono（`D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe`）。
每进程独立 APPDATA（本目录 `appdata-*`），未设缓存/枚举环境变量（进程内缓存口径）。

## 交付物

- `scripts/combat/combo_solver.gd`：solver_profile_v2 确定性计数插桩（meta key
  `ftg_demo_combo_solver_profile_v2`，读取口 `ComboSolver.last_request_profile_v2()`）。
  17 个植入点 + 3 个入口 reset，全部只计数；v1 耗时分解与验收 `profile_totals`
  契约原样。字段口径见 `docs/solver-guide.md`「性能 profile v2」节。
- `tests/solver_growth_fixture.gd`：1/2/4/8 连段边增长夹具（共享 manifest 克隆注入）。
- `tests/test_solver_perf_profile.gd`：v2 字段 schema/请求级语义/恒等式/确定性（24 断言）。
- `tests/test_solver_growth.gd`：旧路径 oracle 指纹门 + 形状冻结门 + 单调增长门。
- `tests/oracle/solver_growth_oracle.json`：旧路径（前缀恢复禁用）完整语义指纹 oracle。
- 基线数据：本目录 `growth-baseline.json` / `profile-sample-e2.json` /
  `default-table-profile.json`，运行日志 `*.log`。

## 增长基线（solve 注入表，默认双面向合计，当前路径）

| E（配置边） | 结构候选 | edge_built | gap_built | DFS 节点 | DFS 叶子 | prefix 恢复 | session_steps |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 18 | 2 | 16 | 4 | 2 | 2 | 1,230 |
| 2 | 40 | 4 | 36 | 6 | 2 | 2 | 2,932 |
| 4 | 120 | 8 | 112 | 18 | 6 | 6 | 6,510 |
| 8 | 472 | 16 | 456 | 260 | 220 | 10（另 frozen 210） | 21,826 |

- 恒等式 `structure_candidates == edge_built + gap_built` 在全部档位与真实表成立。
- 缺口枚举 O(N²) 是主导增长项（16→456）；session_steps 增长 ~17.7×（8× 边）。
- E=8 全链 9 招触 MAX_ROUTE_NODES=8 上限，如实截断（语义常量，非夹具缺陷）。
- 旧路径指纹（oracle）：E=1 `8d8dd913…`，E=2 `184a0b9c…`，E=4 `5f5f21d3…`，
  E=8 `d6a8e985…`；新旧路径指纹逐档全等（fingerprint_path_equal=true）。

## 默认表单请求基线（共享 manifest，冷缓存）

236.8 s；79 边/404 缺口/16 路线/0 循环；指纹 `e071fdc6…`（计入票据 09 在途树状态）。
v1：delay_leaf 122.9s/165,516 runs、route_walk 105.4s、edge 4.0s/1,110、gap 4.4s/1,672。
v2：session_steps 2,114,250；DFS 叶子 165,506（≈v1 runs，差 10 = 不可调基线运行）；
prefix_restores 165,506（全部可调叶子走恢复）；结构候选 2,160 = 边 158 + 缺口 2,002；
循环快照 21,230。

## 等价证据（插桩零语义影响）

| 对拍 | 结果 |
| --- | --- |
| test_combo_solver FAIL 集/指纹→次数/PASS 数（改动前 vs 后） | 全等（11 条 FAIL 为票据 09 在途既有，与本工作无关） |
| test_solver_route 同上三项 | 全等（1 条 71 边计数 FAIL 为在途既有） |
| runs 计数 combo-after vs after2 | 逐字段相等（改动后逐次确定性） |
| before 多出 runs 差值 | =165,516=恰一个默认请求（before 任务运行中 combo_solver.gd 被编辑、语义签名分裂缓存键多算一次——环境伪差，非语义差） |
| test_delay_prefix_restore（叶子级差分 harness） | TOTAL failures=0 |
| 增长夹具新旧路径 | 指纹全等 + 形状计数全等（E=1..8） |

## 复现命令

```bash
E=D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe
$E --headless --path . --check-only -s res://scripts/combat/combo_solver.gd   # 语法
$E --headless --path . -s res://tests/test_solver_perf_profile.gd             # v2 观测
$E --headless --path . -s res://tests/test_solver_growth.gd                   # 增长门
$E --headless --path . -s res://tests/test_solver_growth.gd -- --regen-oracle # 语义变更获准后
$E --headless --path . -s res://tests/test_delay_prefix_restore.gd            # 叶子级差分
```

## 已知事项

- 插桩改动 combo_solver.gd 文件摘要 → `_solver_semantics_signature` 变化，
  持久结果缓存（.cache/acceptance/solver-results.cache）全量失效——下次全量
  验收冷跑重建（票据 08 清扫自愈，预期一次性成本）。
- 两个新测试 job 会被 run_acceptance.py 自动发现；均不 emit
  ACCEPTANCE_SOLVER_METRICS_JSON（solver_calls=0 形态，语义门在 oracle 文件）。
- test_combo_solver 11 条 / test_solver_route 1 条在途 FAIL 为票据 09 未完工作，
  改动前后逐字全等，不由本票修复。
