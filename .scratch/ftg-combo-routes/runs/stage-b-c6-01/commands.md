# 本轮实际命令与完成记录

工作目录：C:/Users/q1625/.codex/worktrees/combo-route-prototype-stage-b/ftgdemo。
环境：APPDATA=<worktree>/prototype_stage_b/appdata。引擎 D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe。

所有脚本调用前缀：`& <Godot> --headless --path . -s res://prototype_stage_b/`。

| 脚本及用户参数 | 最终结果 |
| --- | --- |
| reference.gd -- cand=BASE | 退出0；4个预期全链失败，保存新连段命中 |
| reference.gd -- cand=C6 | 退出0；4/4完整路线 |
| domain.gd | 退出0；384/384 |
| windows.gd | 退出0；17组单组扫描，68条窗外镜像轨迹 |
| tails.gd | 退出0；30个深度/起手/尾段/候选格组，失败原样保存 |
| regression.gd -- cand=BASE | 退出0；10/10 |
| regression.gd -- cand=C6 | 退出0；10/10，BASE逐字段相同 |
| air.gd -- cand=BASE | 退出0；36条保存回放+复用正式检查通过 |
| air.gd -- cand=C6 | 退出0；同上，全部固定输入结果与BASE一致 |
| negatives.gd | 退出0；44条正反语义观察 |
| boundaries.gd | 退出0；204条边界邻点回放 |
| effects.gd | 退出0；24攻防、740后续时点、48重复计划 |
| restore.gd -- cand=C6 | 退出0；56写盘续跑后缀、4条完整trace哈希一致 |
| tails_formed.gd | 退出0；16条明确214指令形态对照 |
| follow_traces.gd | 退出0；68条接续/OTG逐帧对照 |
| left_boundaries.gd | 退出0；独立左墙浮点边界补验（计数见audit.json） |
| python prototype_stage_b/audit.py | 审计通过；469个原始文件ZIP内外SHA256一致 |

首次reference脚本类型错误，停止后修正并重跑BASE；首次air适配因tab/space混合解析失败，修正仅临时适配并重跑BASE和C6；首次effects的NaN比较导致伪字段差异与无效JSON（存effects-initial-nan.txt），规范化NaN后重跑相同实验范围。初次无效运行不纳入通过分母。最终全部日志无SCRIPT ERROR/ERROR，战斗失败作为观察结果不会令诊断脚本进程非零。新复跑入口run.py会为每条调用单独记录真实退出码和脚本错误数并遇错停止。
