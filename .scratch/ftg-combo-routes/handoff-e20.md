# E20 返回设计聊天的交接

2026-10-06。仅完成本轮 E20 第一轮（j214D 触地前窗口）单变量取证，不代表阶段 3 全部完成。

请先读本目录 experiments.md、results.md、progress.md 的 E20 节；设计目标仍以 design.md D01–D44 为准，不重新访谈已确认目标或载体尺寸（base/q-v/t26-v 沿用）。E19 的 b/g 6A 空中资料在所有候选中作为**未裁决工作前提**携带——本轮全部结论是条件性的；E18 的 5B 空中资料未携带。

新证据：把 j214D 空中 profile 的触地前窗口（AIRBORNE×NORMAL air_untech_frames）从 24 加宽是弹地缝的直接解。触地探针实测最小覆盖窗口：b 取向中位 24F（min 23 / max 31–36）、g 取向中位 28F（min 27 / max 30–35）——基线 24F 恰在 b 的中位边界、明显低于 g 的中位。**w32 已饱和：b/g 全取向 28/28 条件锚点覆盖（q-v__g 从 20/28、base/t26__g 从 24/28 补齐），bounce_timeout 全部清零；w48 在全部网格零增益。**完成锚点上的键窗（jump 16F/jC 2F/B 3F/D 15F/rekka 14F/~C 17F）、逐条件关节率（52/256 等）、地面路线投影（full=58）与终点（x510.278/443.522、F130）全部对 w 不变。副作用：地面 jC 迟按失败行结束 1F 平移（每候选 10 行）；w>30 N/C 倒置声明在案。q-v__b 的 1.0/−1 间隙是 jC 触达边界（非窗口），0.25/+1 与 0.5/+1 上升零接触不变。

不变量：三元组投影审计 0 违例；isolation 18/18；基线前后 20 轨迹 SHA256 全等；工具 10 PASS、联合 103 PASS/2 已知 FAIL、症状 13 PASS/24 FAIL、脚本错误 0。299,982 次回放，引擎纯运行 79.0 分钟。

设计聊天需裁决：E19 的 b/g 取向（E19 推荐 b）与本轮 **w=32** 是否作为配套候选采纳（单数据值：data/moves/j214D.tres AIRBORNE×NORMAL air_untech_frames 24→32；w48 无增益且倒置翻倍，不推荐）。采纳后：与 E18 la（若采纳）、E21 范围组合复测完整路线；E15–E17 循环边界与真人验收仍未完成。真人手感全部待试玩：高接触锚点补齐后的对空可读性、迟失败 1F 平移的感知、F5/F6 抬高目标的对照试玩入口已提供。

实验分支：`codex/combo-route-prototype-e20-20261006`（自 E19 提交 487f543 分出）。
实现与证据提交：`85675b5c66a84e0a9978cd9babb557a39ebcd01e`（设计材料另作纯材料提交）。
绝对目录：`C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo`。
入口：[复现及手动试玩](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/README.md)。
证据：[隔离审计](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/e20-isolation.json)、[三元组审计](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/evidence/e20-triple-audit.json)、[主扫描摘要](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/evidence/main/summary.json)、[触地探针](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/evidence/probe-landing.json)、[stage2b 窗口](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/evidence/stage2b-windows.json)、[基线对照](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e20-20261006/ftgdemo/prototype_e20/evidence/baseline-traces.json)。

只回填结论和指针；请勿把实验实现直接合回设计树。设计工作树已有用户未提交材料保持，阶段 4 尚未就绪。
