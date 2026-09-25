# 票据 04 验收报告：Rekka 首段、派生锁定与地空结果

日期：2026-09-25。资源版本：frame-data.md v0.6（票据 04 落表，全部 TUNING_INITIAL）。
证据目录：本目录（`full/` 全量自动化日志与 `replay-routes.log` 回放）。

## 交付概要

- **资源**：新增 `214C`（首段，214+C，mid，接触起 12 帧派生窗口）、`214C~B`（low，`rekka_only`）、`214C~C`（overhead，`rekka_only`，收尾）；必杀取消边接通 `2C/5A/2A/5B/5C → 214C`；`214C~B → 5B` 普通连接边；新命中反应 `DOWNWARD_SLAM`（向下击落：仅 airborne、向下速度、触地转普通倒地）。
- **会话**：派生窗口由首段命中或被防接触打开（挥空不打开）；输入阶段仲裁器先于 B+C 投组合拦截窗口内 B/C 新按下，第一次按下立即锁分支（同帧 B+C 固定 ~C），停顿中按下同样锁定、恢复首个正常帧起手派生；`SPIKE_FALL` 木桩状态触地同帧转普通倒地（`SPIKE_LANDED` 事件）；新事件 `REKKA_BRANCH_LOCKED`；诊断/状态快照含分支与窗口剩余。
- **校验**：Rekka 字段组合与跨招式一致性（窗口↔目标成对、目标 `rekka_only`、分支键匹配、姿态一致、`rekka_only` 不得出现在任何取消/连接目标、不声明方向记法）；DOWNWARD_SLAM 资料规则整表拒绝口径。
- **Solver**：新边类型 `REKKA_DERIVE`（含被防路径变体），派生上下文构建，`rekka_only` 排除独立起手/首招候选；报告分类 branch-locked / buffer-expired / state-incompatible / replay-required。
- **训练场**：HUD 提示 Rekka 分支输入、派生窗口剩余与锁定分支诊断、`SPIKE_FALL` 状态与两类新事件注记。

## 自动化（full/summary.json）

全部 16 项作业退出码 0、无脚本错误：import、test_combat_session（813 PASS）、test_combo_solver（353）、test_crouch_stationary（45）、test_hit_profiles（105）、test_input_normalization（22）、test_joint_acceptance（28）、test_move_table（250，含票据 04 新校验 36 项断言）、test_replay_acceptance（123）、test_smoke（123）、test_solver_cycles（30）、test_solver_entry（49）、test_solver_route（423）、test_solver_spatial（927）、diagnose_inputs、main-smoke。

说明：本机在 PowerShell 5.1 非交互模式下 `run_acceptance.ps1` 会在引擎预期的 stderr 输出（test_move_table 的缺失清单拒绝用例）处触发 NativeCommandError 中止——03 的交互式运行不受影响。为保持同等证据口径，前 6 项由脚本本体产出，其余作业以完全相同的引擎参数、APPDATA 隔离与日志命名逐项补跑并回填 summary.json；各日志格式与 01–03 一致。

## 回放证据（replay-routes.log，全部确定性逐帧输入）

正例（双面向）：
- `2C > 214C > 214C~B(空中) > 5B(目押)`：4 hit / 35.5 伤，C 起手三层修正 0.678/0.748/0.789 跨 Rekka 保留；~B 空中延长（AIR_HITSTUN）→ 触地转地面硬直保剩余计时 → ~B 完全恢复帧目押 5B 命中（贴身 48 px）。
- 裸 `214C > ~B` 与 `214C > ~C`（地面目标）：双双直接 GROUND_KNOCKDOWN。
- `2C > 214C > ~C(空中)`：DOWNWARD_SLAM → SPIKE_FALL 坠落 → `SPIKE_LANDED` 触地转普通倒地，收尾在命中帧结束连段。
- 命中首段停顿中同帧 B+C：固定锁 ~C，无任何投事件。
- 被防首段（蹲防全程）：窗口开放、~B low 同被防——仅两次 BLOCKED、零命中、零修正、不锁起手；站防对照：~B low 漏出命中开新连段（B 起手）。

反例：
- 挥空（200 px）：无接触、无分支锁定、派生从不发生。
- 先 B 后 C（3 帧内）：分支保持 ~B，~C 从不起手，无投配对。
- 窗口关闭后（接触年龄 >12）B+C：沿用组合规则——招式中被状态门拒绝（THROW_FAILED/STATE），首段完全恢复后新组合正常执行普通投（THROW_HIT）。

被防派生安全性（R-02 口径，近距 60 px，反击 5A，攻击方不防御/尝试防御，绑定 TUNING_INITIAL）：
- `214C~B` 被蹲防：反击 F54 命中，攻击方 F60 才可行动——**当前初值下可确反**，与设计意图「~B 交回回合、不被确反」不符 → EXPERIMENT_REQUIRED（候选：缩短 ~B 后摇 18 或加大其被防硬直 9），见 frame-data.md v0.6。
- `214C~C` 被站防：反击 F56 命中，攻击方 F68 可行动——确反，符合「~C 不安全」设计。

## Solver 结论与边界

- 派生边 `214C → 214C~B / 214C~C` timing-valid（有效等待 1–6 / 1–4，最早命中年龄 8 / 10）；被防路径变体：~B 站防漏出（混合起点）、~C 再次被防。
- 路线图含 `2C > 214C > 214C~B`（3 击）、`5B > 2C > 214C > 214C~C`（4 击收尾）等；未发现经逐圈状态重现证明的有效循环。
- 如实声明的边界：`214C~B → 5B` 连接边在规范地面上下文（倒地收尾）报无效——空中延长的目押由会话回放证明，静态报告不冒充（replay-required）；Rekka 派生不参与配置缺口枚举；派生等待档只验证最早档（wait=1），中迟档以窗口上界标注。

## 待真人判断（不阻塞行为验收）

~B 被防确反的调校方向与手感；派生首按锁定与同帧 B+C 仲裁的实机输入感受；延长浮空 → 5B 目押的中远距可用性（贴身已验证，击退漂移敏感——随阶段 5 位移票复验）；全部数值为 TUNING_INITIAL。
