# 交接：RV-E02 已完成，回设计聊天裁决原版边后缀走向（2026-10-11）

## 下一聊天的任务

阶段 2 回访设计聊天（`$grill-with-docs`，用文末回填提示词）：吸收 RV-E02 证据，裁决原版边 B/C 两轮普通 D 的后缀走向，随后按裁决进入阶段 4/5 同步 spec.md R3 段与票据 04/05，再重启票据 04 实施。

## 授权范围与已确认决定

- 本轮只回答了 RV-E02（未修改基线验证 D97 直接 `5B > 214C~C` 后缀全链 + D111 保位 + 首个断点）。D86–D117、八样本、D94/D103、D106/D110–D115 全部沿用，未被重新裁决。
- RV-E06/E07 全量、RV-E01/E03/E04/E05、RV-E09 参数筛选、E14/E15–E17/E22 均未运行；未进入阶段 4/5；未修改正式资源。

## RV-E02 结论（详见 .scratch/ftg-combo-routes/results.md 置顶节）

- 基线复现：旧 j2D 两墙在 `df61103` 逐帧一致（B F153/F167/F169；C F206/F224/F227）；双跑确定性通过。
- 108 站位（B/C × 双面向 × 25 域内 + 2 域外）**0 完整成立**：
  - B 断缝 A（5B#9→214C）：0 按压帧；消费=命中帧也差 2F，命中帧按压实际差 3F（`runs/rve02-01/diag-B.log`）。
  - C 过缝 A（0 消费裕度、3F 预输入窗 hit-5..hit-3）但断缝 B（214C→~C）：~C 最早起手=停顿后首正常帧 +9、命中 +17 vs 恢复 +15，差 2F 输入无解（`runs/rve02-01/diag-C.log`）；根因是 214C 打接地目标（眩晕衰减后 6-7N）而非 R1/R2 的空中 28N untech 语境。
  - ~C 命中恢复后目标造成 KNOCKDOWN 但属新连段第 1 击——截断器正确分离（拼接假阳性形态存证）。
- D112 无合格对象（B r2、C tc 全链窗 0F）；D113 联合 0/256×8。负例/OTG/域外对照齐备。

## 供裁决的三个方向（不代决）

1. RV-E09 逐变量筛选：缝 A-B 与缝 B 所需变量不同（214C 前摇 / 214C 接地眩晕 / ~C 派生时机），须同时过 B/C 与 R1/R2 回归；
2. 改用已证 28N untech 语境的弹地/空中收尾构型（R1/R2 同款终缝）；
3. 修订 D97/D103 的原版边终点。

## 版本与复现

- 设计树 HEAD：`df61103`（未动）。实验分支 `codex/combo-route-prototype-rve02-20261011`，提交 `5ada3ba109d28021de97706a9adb118b934645be`，工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-rve02/ftgdemo`。
- 复跑入口：该工作树 `prototype_rve02/README.md`（先 `--editor --quit` 初始化类缓存；并行引擎独立 APPDATA）。
- 证据：实验工作树 `prototype_rve02/evidence/`；设计树副本 `.scratch/ftg-combo-routes/runs/rve02-01/`（baseline/scan×4/window/joint/negative JSON + diag-B/C 逐帧）。

## 回填提示词（设计聊天用）

```text
请使用 $grill-with-docs，继续 D:/Godot/Program/ftgdemo 的连段设计。
读取 .scratch/ftg-combo-routes/design.md、experiments.md、results.md、progress.md 和 handoff-rve02.md。

先概括哪些假设被支持或推翻，哪些候选达到了约定条件，哪些仍需真人试玩。只提问尚未解决、会影响方案选择的事项，一次一个问题，并给出推荐与代价。

将最终选中的方案、准确路线、参数或规则选择、可接受限制和验收标准回填 design.md。证据不足的问题保留为未决，不包装成已确认决定。更新 progress.md；所有阻塞实施的设计问题解决后，说明已具备阶段 4 的输入。
```
