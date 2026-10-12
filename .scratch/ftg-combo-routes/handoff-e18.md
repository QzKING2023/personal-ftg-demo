# E18 返回设计聊天的交接

2026-10-06。仅完成本轮 E18 单变量取证，不代表阶段 3 全部完成。

请先读本目录 experiments.md、results.md、progress.md 的 E18 节；设计目标仍以 design.md D01–D44 为准，不重新访谈已确认目标或载体尺寸（base/q-v/t26-v 沿用 E10/E21 裁决）。此前 E10/E21/E04 历史结果保留。

新证据：给 5B 增加普通空中资料后，reaction=LAUNCH（la）能让现有边集直接完成连续 5B(空中)>214C>~C 倒地，12/12 条件组合成立，窗口 B 1–11 / 214C 提交 10–20 / ~C 35–43；reaction=GROUND_BOUNCE（bl）没有任何连续后缀——弹地约 F32 才可命中，晚于全部取消窗与连段终点（F34），弹后追击全为新连段。对照 e0 证实新增接触只发生在 b5b 直接起手（116/176/164 行），来源缝隙与既有全量计数逐尺度全等，基线 20 轨迹哈希前后全等。B→214C 提交最小间隔 3F 是路线几何属性，与变量无关。

设计聊天需裁决：是否采纳 la 作为 5B 对空资料取向候选（组件级）；bl 是否仅保留为演出组件（其与既有弹地体系交互未测）；随后与 E19 对空资料、E20 时序、E21 范围组合复测完整路线。真人手感全部待试玩：B→214C 3F 下限与 7–12F 参考间隔的可读性、214C→~C 节奏、对空常见高度/速度覆盖。有限重复失败不是无无限连证明，E15–E17 和真人验收仍未完成。没有正式资源改动或实施提交。

实验分支：`codex/combo-route-prototype-e18-20261006`。
实现与证据提交：`40816f38a9544b2e5b918546a36183ed7006f093`。
绝对目录：`C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo`。
入口：[复现及手动试玩](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo/prototype_e18/README.md)。
证据：[隔离审计](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo/prototype_e18/evidence/e18-isolation.json)、[三元组审计](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo/prototype_e18/evidence/e18-triple-audit.json)、[主扫描摘要](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo/prototype_e18/evidence/main/summary.json)、[阶段摘要](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo/prototype_e18/evidence/stageC-summary.json)、[基线对照](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e18/ftgdemo/prototype_e18/evidence/baseline-traces.json)。

只回填结论和指针；请勿把实验实现直接合回设计树。设计工作树基线 HEAD 仍是 2eebb17，已有用户未提交材料保持，阶段 4 尚未就绪。
