# 票据 03:Solver 耗时 profile 报告

- 日期:2026-09-30(插桩落地当日,含票据 08 全部在途改动的工作树)
- 分类口径与调用点清单:见 [issues/03 Comments](../issues/03-solver-time-profile.md)
- 等价证明:before/after 定向 job 指纹与断言计数对拍,见下文「等价证据」
- 复现:`profile_runner.gd`(默认表 solve/analyze)、`after/after-run.sh` + `before/before-run.sh`(定向 job)、`render_report.py`(渲染本报告的 job 部分)

## 默认表逐请求分解

### solve-default(ComboSolver.solve,双面向,71 边 / 1753 路线)

| 类别 | 耗时 | 占比 | `_run_schedule` 次数 |
|---|---|---|---|
| delay_leaf 延迟叶子回放 | 1,138,955 ms | **97.4%** | 351,196 |
| route_walk 路线行进(扣延迟叶子) | 24,070 ms | 2.1% | 0 |
| gap_enum 缺口枚举 | 3,728 ms | 0.3% | 1,576 |
| edge_probe 边探测 | 2,465 ms | 0.2% | 822 |
| other 其他 | 247 ms | 0.0% | 10 |
| **总计** | **1,169,465 ms(≈19.5 分钟)** | | 353,504 |

环境注意:本次采样与两个定向 job 并行跑在同一 24 核机器上,绝对耗时含 CPU 争用
膨胀(票据 08 记录的裸机 solve() 为 1109s);**占比**是决策数据,绝对值只做量级参考。

### 决策结论(供票据 04 / 票据 05)

1. **票据 04(`_delay_dfs` 前缀快照恢复)正中要害**:97.4% 的 solve 耗时在延迟叶子
   回放,351,196 个叶子全部从 frame 0 全量重放(平均 ≈3.2ms/叶)。前缀恢复把每叶
   成本降到尾部输入的长度,理论收益上限就是这 97.4%。
2. **票据 05 的触发条件未成立**:边探测(0.2%)+ 缺口枚举(0.3%)合计 0.5%,路线
   行进的非叶子部分 2.1%——即使全部归零也不改量级。除非 04 落地后的 profile 显示
   剩余大头转移到这些重放点,否则不开调度记忆化追加票。
3. 叶子平均成本 ≈3.2ms 而总叶数 35 万,意味着 04 的差分 harness(逐叶子比 run dict)
   的对拍规模可控:单请求 35 万叶子 × 完整 dict 比较,分钟级可完成。

### analyze-default(ComboSolver.analyze,单面向,71 边 / 389 缺口 / 1753 路线)

| 类别 | 耗时 | 占比 | `_run_schedule` 次数 |
|---|---|---|---|
| delay_leaf 延迟叶子回放 | 548,769 ms | **97.3%** | 175,598 |
| route_walk 路线行进(扣延迟叶子) | 11,692 ms | 2.1% | 0 |
| gap_enum 缺口枚举 | 2,266 ms | 0.4% | 788 |
| edge_probe 边探测 | 1,461 ms | 0.3% | 411 |
| other 其他 | 29 ms | 0.0% | 5 |
| **总计** | **564,216 ms(≈9.4 分钟)** | | 176,802 |

一致性校验:analyze(单面向)的 delay_leaf_runs 175,598 × 2 = 351,196 = solve(双面向),
与镜像对拍「同表同搜索跑两遍」的结构吻合;各类占比两个入口一致(97.3%/97.4%)。

## 等价证据

1. **定向 job 前后对拍(零语义影响门)**:`compare_jobs.py` 比较插桩前后同 job 日志的
   确定性字段——
   - test_solver_route:exit 0/0,script_errors 0=0,PASS 2339=2339,8 个 report
     fingerprint 逐一相等。**PASS**。
   - test_combo_solver:exit 1=1(见下),script_errors 4=4,PASS 3711=3711,11 个
     fingerprint 逐一相等。**PASS**。
   - before 侧跑在插桩落地前的同一工作树(进程启动时加载旧码),after 侧跑在
     d425814 提交后的树;两侧同引擎、同 APPDATA 隔离口径。
2. **既有失败说明(与本票无关)**:test_combo_solver 前后侧各有 3 条相同的 FAIL
   (默认表 55 边断言、jD 收束路线断言、配置接续关系断言)——票据 08 边基线 71 条
   后测试尚未同步,02 会话的全量基线同样被它阻塞。插桩前后失败集合逐字节相同。
3. **runner 对称性**:gate-03(复刻 difftest-01 子集对拍,PS 串行 vs Python 串行)
   PASS——`solver_profile` 新字段在两个 runner 的 summary 里逐字段相等
   (排除 *_ms 墙钟键后),含 refused 请求四类为零的形态。
4. **确定性形状**:同 fingerprint 的重复请求叶子数完全一致(如 fp 50b5b845 的
   15 次请求全部 175,598 leaves);solve-default(351,196)= 2 × analyze-default
   (175,598),与双面向镜像对拍结构吻合。

## 定向 job 的逐请求分解

见 [profile-jobs.md](profile-jobs.md)(由 after 侧日志渲染):test_combo_solver
26 个重请求、test_solver_route 8 个重请求,每个重请求 delay_leaf 占比均为 97%,
单请求最高 835s / 281,731 叶(combo)与 1,059s / 351,196 叶(route);两个 job 的
桶合计:delay_leaf 19,800s(97%)、route_walk 405s(2%)、gap_enum 74s、edge_probe
47s——与默认表采样的占比一致。
