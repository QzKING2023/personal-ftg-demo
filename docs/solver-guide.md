# Combo Solver 使用与回放

在项目目录直接运行，无需启动训练场或跑测试套件：

```powershell
$env:APPDATA = "$PWD/.scratch/ftg-combat-foundation/acceptance-2026-09-17/runtime"
& D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --log-file .scratch/ftg-combat-foundation/acceptance-2026-09-17/engine.log -s res://tools/solver_report.gd
# 加上静态空间网格
& D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --log-file .scratch/ftg-combat-foundation/acceptance-2026-09-17/engine.log -s res://tools/solver_report.gd -- --spatial
```

程序调用为 `ComboSolver.solve(options)`；`SolverOptions` 可指定 `manifest_path`、`move_table`、`start`、`facings`、`spatial`（以类声明为准）。默认共享表、地面中立、空缓存/方向历史、木桩地面中立、左右面向分别验证；显式空中起点通过 `SolverStartState.stance` 和 `air_frames` 描述。当前接口不能导入任意完整会话快照。

## 结论范围

2026-09-17 修正落地锁后，默认报告为 9 条配置边：8 有效、1 排除；34 条配置缺口、7 条可读路线、左右镜像一致、无已证明循环。

- `timing-valid`：70px 固定接触位探针的时序成立，木桩每帧被钉回相对距离。
- `spatial-valid`：可选地面左右镜像 48/64/80px **钉位**网格通过，身体为48×80、命中框取资源、垂直轨迹走真实会话；每个距离允许重新寻找空中延迟。它没有验证真实水平击退的累积，不是完整训练场命中保证。
- 真实击退回放：不钉位，从指定距离输入同一帧表才可验证该站位。当前地面和派生70px、空中48px在双面向训练场输入回放中接通；空中70px实际只完成前3击、伤害32.6，不能宣称五连可达。
- 配置缺口不进入合法路线；规则禁止的落地取消不再误报为“补配置即可成立”。循环仍需完整结算状态逐圈重现。8圈/2400帧/240帧恢复观测/40帧空中延迟上限均未增加，触顶仍报告截断或未完成观测。
- 被防路径标注（2026-09-25 票据 03）：每条链式/必杀边另在「来源招式被木桩站防/蹲防挡下」的探针中验证取消时序——来源在预期接触帧被防（ATTACK_BLOCKED，不产生命中）、目标在被防取消窗口内起手，目标自身接触结果（再被防/属性漏出命中/资料缺失/挥空）如实入注。被防不是 HIT：标注不改变路线/循环图；探针中预期命中帧收到被防结果按 blocked 断链上报。被防安全性（指定反击招式、时机、距离、版中/版边、左右面向）不在静态证明范围，一律 replay-required，由保留真实位置的训练场回放下结论（见 acceptance/03 反击矩阵）。

不搜索走位、中立、墙角、推挤、跨身或边界；循环仅属于 timing 层。旧落地边 jB→5D 被排除，因为空技着地恢复不可取消；恢复后的普通连接没有被证明。

## 代表帧表

F 为**正常战斗帧**；命中后的8个冻结物理帧用空输入跳过，不增加 F。未列帧为空输入，各动作键按一次后松开。输入恰在命中当帧的样本可用于脚本复现，不代表真人能在该帧看见命中后作出反应。

| 路线 | 正常帧输入（面向右） | 命中正常帧 | 总伤害 | 真实击退复验 |
| --- | --- | --- | --- | --- |
| 5A→5B→5D | F1 U；F6 I；F11 J | 6/11/16 | 35.2 | 70px，两侧3击 |
| 5B→214D | F1 I；F5 S；F6 S+A；F7 A；F8 J | 8/15 | 31.8 | 70px，两侧2击 |
| 5A→236C→jA→jB→jD | F1 U；F3 S；F4 S+D；F5 D；F6 K；F13 Space；F18 U；F22 I；F27 J | 6/13/22/27/31 | 53.0 | 48px，两侧5击；70px失败 |

面向左时仅镜像世界水平键：236 的 S+D/D 改为 S+A/A；214 的 S+A/A 改为 S+D/D。相对数字仍是236/214，U/I/K/J、Space和帧号不变。

训练场注入含一帧前导空帧：地面命中 tick=7/20/33，派生=9/24，48px空中=7/22/39/52/64。这些是输入适配测试的物理 tick，不要直接当成人类按键节拍。

旧落地样本保留作负例：沿空中起手到 F13 Space，改为 F39 U、F48 I、F54 J。钉位70px只命中 F6/13/43/55，共4击、41伤害；落地不启动5D。48px真实输入也只完成4击。它是 `timing-invalid`，不能再作为合法连段或循环证明。

完整回放和失败断点在 `tests/test_replay_acceptance.gd` 输出。当前独立入口输出可读文本；规格要求的稳定 `version=1` JSON 导出仍未实现，不能把普通文本日志称为该导出。
