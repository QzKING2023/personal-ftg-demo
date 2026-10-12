# E19 返回设计聊天的交接

2026-10-06。仅完成本轮 E19 单变量取证，不代表阶段 3 全部完成。

请先读本目录 experiments.md、results.md、progress.md 的 E19 节；设计目标仍以 design.md D01–D44 为准，不重新访谈已确认目标或载体尺寸（base/q-v/t26-v 沿用 E10/E21 裁决）。此前 E10/E21/E04/E18 历史结果保留；E18 的 5B 空中资料（la/bl）未获裁决，本轮一律未携带。

新证据：给 6A 增加普通空中资料（AIRBORNE×N/C，reaction=LAUNCH 克隆）后，对空首击基础路线 `6A > jc > jC > j214D, 5B > 214C~C` 在真实结算中端到端成立，且只在低接触锚点成功——机制是弹地缝：j214D 空中命中的触地前窗口（24F）先于目标触地即按浮空受身结束连段（不弹地），链路按键不能移动接触高度，唯一杠杆是 6A 锚点（越晚接触越低）；combat_session.gd GROUND_BOUNCE 分支「调校初值下触地先于窗口耗尽」的假设只对地面几何成立。取向对比：b（GROUND_BOUNCE 数值 460/untech 30,36）在 base/t26-v 覆盖全部 7 个可接触条件（含上升高目标 1.0/+1）、最早锚点即成立、关节 47–62/256 最高；g（GROUNDED 数值 560/untech 36,42）缺 1.0/+1 且要求锚点后移（t≥6）、关节 30–50。0.25/+1 与 0.5/+1 上升目标对空接触本身为 0（真实覆盖负例）。键窗与地面样本同宽（jump 16F/jC 2F/B 3F/rekka 14F/~C 17F；j214D 提交在 0.5/1.0 条件宽至 15–17F），地面节奏原样平移；六键 ±2 关节全部未达 244/256。e0 全部空中尝试 HIT_MISS（a_air=0）。完成参考六击连续、无换边，倒地点与 E10 地面参考同位。

不变量：三元组投影审计 0 违例（门控行恰为对空接触块 348/468/468），地面键窗/full/换边投影 9 候选全等且与 E10 数值一致；g/b 均为 LAUNCH，「命中即弹地」状态面变化不存在于本变量；基线前后 20 轨迹 SHA256 全等；工具 10 PASS、联合 103 PASS/2 已知 FAIL、症状 13 PASS/24 FAIL、脚本错误 0。

设计聊天需裁决：是否采纳 b 作为 6A 对空资料取向候选（组件级；g 备选/成本对照）；若采纳，应把 j214D 空中 profile 的 24F 触地前窗口列为 E20 时序实验的显式变量（本轮按单变量纪律未动它）；随后与 E18 la、E20 时序、E21 范围组合复测完整路线。真人手感全部待试玩：对空读招（低接触带 vs 高接触超时）的实战可读性、上升目标确认、连段中 BOUNCE_CONTACT 目押、B 窗 3F。有限重复失败不是无无限连证明，E15–E17 和真人验收仍未完成。没有正式资源改动或实施提交。

实验分支：`codex/combo-route-prototype-e19-20261006`。
实现与证据提交：`487f54395310dc3aef35964154568f017cc6ba02`。
绝对目录：`C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo`。
入口：[复现及手动试玩](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/README.md)。
证据：[隔离审计](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/evidence/e19-isolation.json)、[三元组审计](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/evidence/e19-triple-audit.json)、[主扫描摘要](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/evidence/main/summary.json)、[stage2b 窗口](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/evidence/stage2b-windows.json)、[关节](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/evidence/stage2b-joint.json)、[基线对照](C:/Users/q1625/.codex/worktrees/combo-route-prototype-e19/ftgdemo/prototype_e19/evidence/baseline-traces.json)。

只回填结论和指针；请勿把实验实现直接合回设计树。设计工作树已有用户未提交材料保持，阶段 4 尚未就绪。
