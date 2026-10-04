# 报告完整性模式与资源看门狗：暂停持久化，永不静默截断

状态：accepted（2026-10-04，P5 solver-routes-cycles 落地）

`MAX_ROUTE_REPORTS = 16` 是默认报告的容量上限（报告表面），不是连段语义——达到上限时默认模式如实注记「路线集合未完成」。P5 起该上限与语义正式解耦为两层：

- **完整路线集合模式**（`SolverOptions.complete = true`，P5）：上限不作为语义剪枝——全部 ≤ `MAX_ROUTE_NODES = 8` 的简单路径照常枚举并逐帧模拟，报告如实携带完整集合（路线计数 == 邻接图暴力叶计数是可断言不变量）。该开关是语义维度，进 solve 请求 descriptor（与默认截断模式互不命中结果缓存）；`MAX_ROUTE_NODES = 8` 仍是可读路线的语义常量，complete 模式不放宽。
- **资源看门狗**（`SolverOptions.watchdog_ms > 0`，P5）：长时间分析到点只在安全点（一个路线源/一个结构循环/一条空间复验完成之后）暂停，把 incomplete 状态冻结并持久化（`SolverOptions.resume_path`，回退环境变量 `FTG_SOLVER_RESUME`；未配置则如实注记「未能持久化」），`ComboSolver.resume_analysis` 从快照续算（可多次暂停）。看门狗是资源控制量，不进请求键；暂停报告 `paused_incomplete = true` 且不进结果缓存，暂停注记在续算完成的报告中被剥离——最终报告与不中断路径指纹全等（差分门钉死）。

决定要点：

- 曾考虑并否决：把 `MAX_ROUTE_REPORTS` 全局调大或移除——默认报告的可读性与 bounded-request 性质依赖该上限，无差别放开等于把 complete 模式的成本强加给所有调用方。
- 快照自包含（canonical 表文本 + 冻结报告 + 进度游标），恢复腿不重跑边/缺口阶段（结论已在冻结报告里），路线/循环/空间按游标续算；solve 级暂停以「面向」为包裹粒度（线程快照 + 冻结 primary + 剩余面向），续算收尾与 solve 同一合并/镜像对拍路径。
- 等价纪律沿用 ADR 0006 的两级制：完整模式/看门狗续算对不中断路径以全语义 fingerprint 为 oracle（Tier A 同模式对拍）；环枚举（SCC 预处理 + Johnson 保序去重）与路线叶 trie 登记属机械等价变换，各自的差分开关（`_cycle_enum_legacy` / `_route_leaf_memo_disabled`）保留为测试 oracle。
