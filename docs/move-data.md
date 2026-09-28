# 招式与行为数据

训练场和 Solver 读取 `data/move_manifest.tres` 引用的 `data/moves/*.tres`。当前为 20 个打击招式（含蓄力版 5[D]）加 1 个普通投。身份由 `move_id` 定义，文件名不是身份。修改后重新运行进程；核心字段缺失、负帧数、非法枚举/引用/并列优先级/非法命中资料组合都会整表拒绝。

| 招式 | startup/active/recovery | 基础伤害 | 命中资料 | 配置接续 |
| --- | --- | --- | --- |
| 5A | 5/7/13 | 10 | grounded n/c 地面硬直 | 5B、236C、6A |
| 5B | 4/6/13 | 12 | grounded n 地面硬直 | 5D、214D |
| 5C | 6/5/16 | 14 | grounded n 浮空 | jump cancel → jA |
| 6A | 8/6/20 | 16 | grounded n/c 浮空 | jump cancel → jA/jB/jC（6+A 专用击飞入口，仅实际 HIT） |
| 6D | 9/4/20 | 18 | airborne n/c 浮空（无 grounded 键：对地一律 MISS_NO_PROFILE） | 计划位移 88/−48：active 帧真实上升离地；实际 HIT 后空中出口 → jA/jB/jC（命中确认窗口内按空中姿态起手） |
| 2D | 8/4/18 | 17 | airborne n/c 浮空（无 grounded 键） | 计划位移 0/−64 垂直上升；命中框垂直偏移 −70px（高位拦截：低浮空目标垂直不重叠即挥空）；空中出口同 6D |
| 2C | 9/3/18 | 14 | grounded n/c 低浮空扫倒（LOW_FLOAT_SWEEP，触地转普通倒地） | 链式 6D/2D；必杀 214C |
| 236C | 6/5/18 | 18 | grounded n 浮空 | jump cancel → jA |
| 5D | 5/7/15 | 18 | grounded n 地面硬直 | 收尾（票据 06 起另有计划位移 72px 与动作内蓄力） |
| 5[D] | 7/4/22 | 20 | 与 5D 同三组资料（TUNING_INITIAL 镜像） | 仅由 5D 蓄力提交起手（charge_only）；来源限定 5B 目押同 5D |
| 214D | 7/5/20 | 22 | grounded n/c 普通倒地 | 收尾 |
| jA | 4/6/10 | 8 | grounded n 地面硬直；airborne n 浮空 | jB、jC |
| jB | 4/6/12 | 12 | grounded n 地面硬直；airborne n 浮空（untech 20，票据 07 对齐普通空中硬直初值） | jC、jD；历史落地目标 5D 被当前规则排除 |
| jC | 7/5/14 | 14 | grounded n/c 地面硬直；airborne n/c 浮空 | 无出边（j5D/j6D/j2D/j214D 随票据 08/09 接入） |
| jD | 4/7/14 | 20 | grounded n 地面硬直；airborne n 浮空 | 收尾 |
| BC | 5/11/10 | 无伤害 | 无（投结果参数在 GameParams） | 投距 64px；投帧 1–15 可由木桩请求拆投 |

表中未列出的 2A/2B/214C 系等行及 5A/5B/5C 的帧数沿用历史样例、未随票据 01–06 全量复检（资源为准，阶段 9 联合验收统一同步）；票据 07 涉及的 6A/2C/jA/jB/jC/6D/2D 行为当前资源事实。

命中资料（ADR-0003）：每个打击招式内嵌 `HitProfile[]`，唯一键 `(target_state, hit_context)`；运行时与 Solver 先按目标状态（grounded/airborne）再按命中上下文（normal/counter）精确匹配，缺失即 MISS_NO_PROFILE，不回退、不借用。反应只有三种：GROUND_HITSTUN（仅 grounded，`ground_stun_frames` + 水平速度，垂直必须显式 0）、LAUNCH（`air_untech_frames` + 水平速度 + 必须 >0 的垂直初速度）、GROUND_KNOCKDOWN（仅 grounded，`knockdown_frames`，进入即结束连段且倒地期间不可命中）。声明某状态的 counter 必须同时声明该状态的 normal。profile 可用 `damage_override` 覆盖本招 `base_damage`（-1 表示沿用），counter 变体的伤害差异由此表达。Counter Hit 上下文只在目标自身招式的 startup/recovery 窗口成立，命中一次即消耗。表中 n/c 数值为暂定样例，最终调校属 D 轮。

打击接受帧是 F1，第一命中在接受帧 + startup；I/K 的组合等待另计。BC 的帧 5 为投发生点，未拆投结果到帧 15 才应用，不能用打击首 active 的公式推导它。

必填通用字段：`move_id`、`move_kind`、`stance`、`action_key`、三个帧窗口、`cancel_window_frames`、`priority`。计划位移与动作内蓄力（票据 06）：`motion_x_px`/`motion_y_px`（两轴成对声明或成对未声明，NAN 为未声明；active 帧按累计比例推进、命中框沿本帧轨迹扫掠、正式位置经版边/身体约束后提交）、`charge_threshold_frames` + `charge_move_id`（按住动作键至阈值的正常帧数与蓄力版目标，达阈值自动提交、松开走普通版）与 `charge_only`（蓄力版唯一入口，不参与单键/指令选择、不得出现在任何接续目标中；入口唯一、不得链式蓄力）。打击还需 `base_damage`（非负）、`attack_attribute`、`air_attack`、命中框/间距、至少一个合法 `HitProfile`，以及被防结果三字段（2026-09-25 票据 03）：`block_freeze_frames`（被防停顿，双方冻结的物理帧数）、`block_stun_frames`（被防硬直，防守方停顿后不可行动的正常帧数）、`block_pushback_px_s`（被防推退，停顿后施加给双方的水平速度）——三项逐招显式声明、整表齐备，投技不得声明；程序注入表未声明时该招不可被防（默认禁止，无全局回退参数）。投需 `throw_range`，不走单键绑定，也不得声明命中资料。旧 `hit_result`/`hitstun_frames`/`knockback`/`knockback_up` 字段已删除，不存在回退。当前全部打击的被防初值为 8/9 帧、45px/s（frame-data v0.5 TUNING_INITIAL）。

`cancel_targets` / `jump_cancel_targets` 只是必要条件，仍须姿态、命中确认、取消年龄和目标可追击同时成立。`landing_cancel_targets` 保留旧资源读取和排除诊断，不能绕过落地恢复；恢复后的普通连接尚未进入 Solver 搜索。`extra_landing_recovery_frames` 叠加在空技默认一次 +1f 之上，不延长 active。方向串、替代串、严格/宽松、指令层级和 priority 共同决定识别结果；三步串窗口为 30 个正常帧，窗口含首帧。

非招式行为在 `scripts/game_params.gd`：Hitstop=8，缓存=6，方向步长=10，pre-jump=4，空中=38，基础落地=3，空技额外=1，dash=12、速度480px/s，投结果硬直20f、击退240px/s。`MOVE_*` 常量仅作历史测试基线，运行时招式以资源为准。

地面蹲姿禁止主动水平移动，是 `CombatSession` 的行为规则，没有独立“蹲行速度”字段。2026-09-18 按真人反馈修订：入蹲当帧清除行走惯性，1/3 方向仍进入指令历史；受击击退不被蹲姿抹除。训练场与 Solver 共用此会话规则。

当前默认打击均为 high，空中技另有 air 标记。测试用注入属性验证站防挡 high/mid/overhead、蹲防挡 high/mid/low、空防挡 air。玩家侧防御硬直仍取所选 HitProfile 的反应计时；木桩侧自票据 03 起由逐帧防御请求（NONE/STAND/CROUCH/AIR，`FrameInput.dummy_guard_request`）驱动，挡下玩家攻击产生独立 ATTACK_BLOCKED 接触结果（停顿/硬直/推退读招式被防三字段，不读命中资料；请求不成立时按状态不符/占用可观察拒绝）。两者都不能视为真人验收通过。

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
