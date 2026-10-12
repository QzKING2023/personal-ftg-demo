# 交接：RV-E10b/RV-E11b 派生探索已完成，回设计聊天在更新后的裁决面裁决原版边后缀（2026-10-11）

## 下一聊天的任务

阶段 2 回访设计聊天（`$grill-with-docs`，回填提示词见文末）：吸收 RV-E10b/RV-E11b 证据（连同上轮 RV-E09/E10/E11，见 handoff-rve09-rve11.md），在更新后的裁决面裁决 D97/D103 原版边两轮普通 D 后缀的最终方案；裁决后经阶段 4/5 同步 spec.md R3 段与票据 04/05，再重启票据 04 实施。

## 授权范围与已确认决定

- 本轮为用户授权的两题派生探索（方向 2=B 构型×A 变量子集、方向 3=换终点×A 变量空间合并），各自隔离工作树/分支/APPDATA。两题均为**派生实验题**（design.md 仅定义到 RV-E09），待设计追认编号。D86–D117、八样本、D94/D103、D106/D110–D115 全部沿用；两分支零正式资源改动；未做设计决定。
- D97/D103 已确认后缀仍为 214C~C；本轮全部候选（含 ~B/2C 终点）只是证据——采纳任何候选即改变已确认路线形状，须设计明示。
- 未运行：RV-E06/E07 全量、RV-E01/E03/E04/E05、E14/E15–E17/E22；未进入阶段 4/5。

## 两题结论（详见 results.md 置顶节与 runs/rve10b-11b-01/）

| 题 | 结论 | 关键数字 | 分支/提交 |
| --- | --- | --- | --- |
| RV-E10b 方向 2（B 构型×A 变量） | **结构性关闭** | tc/b3/ja/jd 裁决窗全候选恒 1F；tc=按压日→命中日单射×唯一 R=contact+19；联合 SA 17/WC 8；V2 开 B 起手缝 A 但 jC 新墙（最早命中>空中眩晕耗尽 F204） | `codex/combo-route-prototype-rve10b-20261011` @ `d57b5d2` |
| RV-E11b 方向 3（换终点×A 变量） | **能且比 A 便宜** | 2C 终点 1 变量（Q19 5B 眩晕 19 / C6 2C.startup 6）；~B 终点 2 变量（V1+P18 / V1+V3b=A 免 V4）；4 候选全门槛+回归 10/10×4+联合 256/256×8×4 | `codex/combo-route-prototype-rve11b-20261011` @ `a4023b3` |

更新后裁决面（results.md §3）：

| 方案 | 变量 | 终点/路线形 | 备注 |
| --- | --- | --- | --- |
| A V1+V3b+V4 | 3 | 214C~C（D97 原形） | is_finisher=true；B r2 3F |
| A′ V1+V3b / A″ V1+P18 | 2 | 214C~B（Rekka 换 B 分支） | is_finisher=false；B 缝 3F |
| B1 Q19 / B2 C6 | 1 | `5B>2C`（换终点类） | C6 波及面最小（既有路线不含 2C）；sweep 触地收尾；is_finisher=false |

参数轴与路线形轴正交：最便宜参数（C6）放弃 Rekka 终点；保 Rekka 终点最少 2 变量。真人手感均待试玩。

## 版本与复现

- 设计树 HEAD：`df61103`（未动）；两实验分支分别自 rve10（`5d563bc`）/ rve09（`560222e`）切出（两者同源于 `5ada3ba`）。
- 复跑入口：各工作树 `prototype_rve{10b,11b}/README.md`。注意：首次 `--editor --quit` 初始化类缓存存在**挂起形态**（缓存已建成但进程不退出；症状=引擎 ~3% CPU 空转、证据停止增长）——加超时观察、按 PID 兜底杀；并行引擎独立 APPDATA；rve11b 组合令牌必须「+」连接并加引号（`cand=V1+P18`，下划线会静默落回 BASE 表）。
- 证据：各分支 `prototype_rve{10b,11b}/evidence/`；设计树副本 `runs/rve10b-11b-01/`（summary+README×2）。

## 回填提示词（设计聊天用）

```text
请使用 $grill-with-docs，继续 D:/Godot/Program/ftgdemo 的连段设计。
读取 .scratch/ftg-combo-routes/design.md、experiments.md、results.md、progress.md 和 handoff-rve10b-rve11b.md（连同上轮 handoff-rve09-rve11.md）。

先概括哪些假设被支持或推翻，哪些候选达到了约定条件，哪些仍需真人试玩。只提问尚未解决、会影响方案选择的事项，一次一个问题，并给出推荐与代价。

将最终选中的方案、准确路线、参数或规则选择、可接受限制和验收标准回填 design.md（含是否追认 RV-E10b/RV-E11b 派生题编号）。证据不足的问题保留为未决，不包装成已确认决定。更新 progress.md；所有阻塞实施的设计问题解决后，说明已具备阶段 4 的输入。
```
