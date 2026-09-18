# 招式与行为数据

训练场和 Solver 读取 `data/move_manifest.tres` 引用的 `data/moves/*.tres`。当前为 9 个打击招式加 1 个普通投。身份由 `move_id` 定义，文件名不是身份。修改后重新运行进程；核心字段缺失、负帧数、非法枚举/引用/并列优先级都会整表拒绝。

| 招式 | startup/active/recovery | 基础伤害 | 配置接续 |
| --- | --- | --- | --- |
| 5A | 5/7/13 | 10 | 5B、236C |
| 5B | 4/6/13 | 12 | 5D、214D |
| 5C | 6/5/16 | 14 | jump cancel → jA |
| 236C | 6/5/18 | 18 | jump cancel → jA |
| 5D | 5/7/15 | 18 | 收尾 |
| 214D | 7/5/20 | 22 | 收尾 |
| jA | 4/6/10 | 8 | jB |
| jB | 4/6/12 | 12 | jD；历史落地目标 5D 被当前规则排除 |
| jD | 4/7/14 | 20 | 收尾 |
| BC | 5/11/10 | 无伤害 | 投距 64px；投帧 1–15 可由木桩请求拆投 |

打击接受帧是 F1，第一命中在接受帧 + startup；I/K 的组合等待另计。BC 的帧 5 为投发生点，未拆投结果到帧 15 才应用，不能用打击首 active 的公式推导它。

必填通用字段：`move_id`、`move_kind`、`stance`、`action_key`、三个帧窗口、`cancel_window_frames`、`priority`。打击还需 `base_damage`、`attack_attribute`、`air_attack`、命中框/间距、`hit_result`、`hitstun_frames`、水平/垂直击退；投需 `throw_range`，不走单键绑定。

`cancel_targets` / `jump_cancel_targets` 只是必要条件，仍须姿态、命中确认、取消年龄和目标可追击同时成立。`landing_cancel_targets` 保留旧资源读取和排除诊断，不能绕过落地恢复；恢复后的普通连接尚未进入 Solver 搜索。`extra_landing_recovery_frames` 叠加在空技默认一次 +1f 之上，不延长 active。方向串、替代串、严格/宽松、指令层级和 priority 共同决定识别结果；三步串窗口为 30 个正常帧，窗口含首帧。

非招式行为在 `scripts/game_params.gd`：Hitstop=8，缓存=6，方向步长=10，pre-jump=4，空中=38，基础落地=3，空技额外=1，dash=12、速度480px/s，投结果硬直20f、击退240px/s。`MOVE_*` 常量仅作历史测试基线，运行时招式以资源为准。

地面蹲姿禁止主动水平移动，是 `CombatSession` 的行为规则，没有独立“蹲行速度”字段。2026-09-18 按真人反馈修订：入蹲当帧清除行走惯性，1/3 方向仍进入指令历史；受击击退不被蹲姿抹除。训练场与 Solver 共用此会话规则。

当前默认打击均为 high，空中技另有 air 标记。测试用注入属性验证站防挡 high/mid/overhead、蹲防挡 high/mid/low、空防挡 air。防御硬直目前复用 `hitstun_frames`，但这个参数关系仍待规则确认，不能视为真人验收通过。

## 文件级同步实测

2026-09-17 实际改写同一 `data/moves/5A.tres` 并分进程运行 `tools/check_move_file_sync.gd`：

| 文件状态 | 训练场 U 起手→命中 tick | Solver 地面路线正常帧 | 路线伤害 |
| --- | --- | --- | --- |
| startup=5，damage=10 | 2→7 | 6/11/16 | 35.2 |
| startup=8，damage=25 | 2→10 | 9/14/19 | 50.2 |
| startup=-1 | 拒绝加载 | 同路径、id、字段、原因拒绝 | 无路线 |
| 原字节恢复 | 2→7 | 6/11/16 | 35.2 |

训练场注入有一帧前导空帧，因此绝对 tick 不与 Solver F1 直接比较；前摇差和伤害一致。恢复前后 SHA-256 相同。当前资源数值没有保留实验改动。

尚未实现的正向数据能力：pre-jump 四帧取消到显式地面必杀的配置入口。规则已确定，缺的是实现，不需要重新决定“能否取消”；不得以“没有字段”当作整项验收通过。
