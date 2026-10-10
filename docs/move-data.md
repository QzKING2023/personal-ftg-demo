# 招式与行为数据

更新于 2026-10-10（连段路线票据 01：12×20 身体、jC 4/j214D 1、j214D 触地前窗 32/32、5B 空中/弹地资料、弹地自然接续与 D 键接地零水平；上次 2026-10-05 票据 10 联合验收统一同步）。训练场和 Solver 读取 `data/move_manifest.tres` 引用的 `data/moves/*.tres`。当前为 22 个打击招式（含蓄力版 5[D]、Rekka 派生 214C~B/~C）加 1 个普通投；身份由 `move_id` 定义，文件名不是身份。修改后重新运行进程；核心字段缺失、负帧数、非法枚举/引用/并列优先级/非法命中资料组合都会整表拒绝。旧地面 `214D` 与单一 `jD` 已移除（票据 08/10）：倒地职责在 `214C~B`/`214C~C`，空中位移/弹地在 `j214D`，`214` 后撤指令的识别主体为 `214C`。

数值版本：frame-data v0.12（全部 TUNING_INITIAL，未平衡；逐票落表记录见 `.scratch/ftg-character-implementation/frame-data.md`）。

| 招式 | 键/指令 | startup/active/recovery | 基础伤害 | 起手 | 命中资料要点 | 配置接续 |
| --- | --- | --- | --- | --- | --- | --- |
| 5A | A | 5/4/10 | 8 | A | grounded n/c 硬直 14/18 | 链式 5B/2B；必杀 236C/214C；连接 5B |
| 2A | A 蹲姿 | 5/4/10 | 8 | A | grounded n/c 硬直 | 链式 5A/2A/5B/2B；必杀 214C |
| 5B | B | 6/5/12 | 12 | B | grounded n/c；airborne LAUNCH u18/24（h60/up100，票据 01）；弹地键 LAUNCH u19/25 | 链式 5C/2C/6A/5D；必杀 236C/214C；连接 5C/5D |
| 2B | B 蹲姿 | 7/5/12 | 11 | B | grounded n/c 硬直 | 链式 5C/2C/6A |
| 5C | C | 8/5/16 | 16 | C | grounded n/c 硬直；不再是专用 launcher | 链式 6A/5D；必杀 236C/214C；连接 5D |
| 2C | C 蹲姿 | 9/3/18 | 14 | C | LOW_FLOAT_SWEEP（低浮空触地转普通倒地） | 链式 6D/2D；必杀 214C；无 jump cancel |
| 6A | 指令 6A | 8/6/20 | 16 | C | grounded LAUNCH u36/42；弹地键 u30/36；出刀型专用击飞 | jump cancel jA/jB/jC（仅实际 HIT） |
| 5D | D | 7/4/18 | 18 | D | grounded 硬直；airborne LAUNCH u32；slide 捞起 u32 | motion 72px；蓄力 8 帧→5[D]；来源限定连接 5B |
| 5[D] | D 按住 | 7/4/22 | 20 | D | 与 5D 同三组资料（镜像） | motion 120px；charge_only（唯一入口）；来源限定连接 5B |
| 6D | 指令 6D | 9/4/20 | 18 | D | 仅 airborne u30/36（对地 MISS_NO_PROFILE） | motion 88/−48 斜上真实离地；空中出口 jA/jB/jC/j5D/j6D/j2D/j214D |
| 2D | D 蹲姿 | 8/4/18 | 17 | D | 仅 airborne u26/32 | motion 0/−64 垂直；命中框 y_offset −70（高位拦截）；空出口同 6D |
| 236C | 指令 236C | 6/2/22 | 8 | D | 段 1 grounded LAUNCH u32/airborne u34；段 2（segments 承载）grounded→击飞触地 slide、airborne→延长浮空 | 两段命中各自特殊进入 5D（窗口 16，被防不开放）；段 1 被防整招终止、挥空续段 2 |
| 214C | 指令 214C | 8/4/20 | 10 | D | grounded n/c；airborne LAUNCH u28/34；弹地键 u28/34 | Rekka 派生窗 12 帧：首按 B/C 锁定 ~B/~C，同帧 B+C 固定 ~C |
| 214C~B | 214C 后 B | 7/3/18 | 8 | B | grounded GROUND_KNOCKDOWN 30；airborne LAUNCH u36/44（延长） | rekka_only；连接 5B（恢复后目押） |
| 214C~C | 214C 后 C | 9/3/24 | 14 | C | grounded GROUND_KNOCKDOWN 30；airborne 向下击落（触地转倒地） | rekka_only；收尾（is_finisher），无后续 |
| jA | 空中 A | 4/6/10 | 8 | A | grounded s12；airborne u12 | 命中确认 jB/jC/j5D/j6D/j2D/j214D |
| jB | 空中 B | 4/6/12 | 12 | B | grounded s12；airborne u20 | 命中确认 jC/j5D/j6D/j2D/j214D |
| jC | 空中 C | 4/5/14 | 14 | C | grounded n/c；airborne u20/26；motion 4px | 命中确认 j5D/j6D/j2D/j214D（稳定进 j214D 的最低等级） |
| j5D | 空中 D | 6/4/16 | 16 | D | grounded n/c；airborne u22/28 | motion 74px 收束：无取消、无连接、无落地特权、无收尾标记 |
| j6D | 空中 6D | 7/4/18 | 17 | D | grounded n/c；airborne u26/32 | motion 68/26 斜下速降；连接 5B（落地恢复后延迟普通连接） |
| j2D | 空中 2D | 8/4/20 | 18 | D | grounded s16/20；airborne u24/30（小上抛带回地面） | motion 0/70 垂直带落地；落地取消仅 214C（窗 24）；落地+2 仅挥空/被防路径 |
| j214D | 空中 214D | 1/4/22 | 20 | D | grounded/airborne 统一 GROUND_BOUNCE（触地前窗 12/16、32/32，票据 01） | motion 12/64 斜下砸落；连接 5B/6A/214C（弹地延迟目押）；不声明弹地目标键（对弹地目标 MISS_NO_PROFILE——再次弹地由其他招式的有效命中产生） |
| BC | I+K 同按 | 5/11/10 | 无 | — | 无命中资料（投结果在 GameParams） | 投距 64px；帧 1–15 可拆投 |

## 命中资料（ADR-0003）

每个打击招式内嵌 `HitProfile[]`，唯一键 `(target_state, hit_context)`；运行时与 Solver 先按目标状态（grounded/airborne/slide/bounce）再按命中上下文（normal/counter）精确匹配，缺失即 MISS_NO_PROFILE，不回退、不借用。反应集合：GROUND_HITSTUN（仅 grounded）、LAUNCH（air_untech + 水平 + 必须 >0 垂直初速）、GROUND_KNOCKDOWN（仅 grounded，进入即结束连段且倒地期间不可命中）、LOW_FLOAT_SWEEP、LOW_FLOAT_TO_SLIDE（236C 段 2 击飞触地转 slide）、GROUND_BOUNCE（j214D 专用，profile 只声明进入运动与触地前窗，反弹速度/追击窗是 GameParams 流程参数）。slide 目标键与弹地目标键只有显式声明的招式可命中（5D/5[D] 持有 slide 捞起资料；5B/6A/214C 持有弹地追击资料）。声明某状态的 counter 必须同时声明该状态的 normal（counter 本身可选——jA/jB 当前无 counter 为合法现状）。

## 输入、取消与普通连接

三类取消窗口独立（B6/B7）：链式（0–3f）与必杀（0–5f）在命中或被防接触成立；命中确认（0–8f）、jump cancel、空中出口、特殊进入与落地例外仅实际 HIT；挥空没有接触和取消年龄。`FrameInput` 的 `action_key` 写入等价单键按下；C/B 键参与 B+C 投组合配对（≤3 帧），单键起手在配对窗口末帧——方向解析发生在按下当帧，配对等待只推迟起手 3 帧。

普通连接（`link_targets`）是恢复后目押：前招 recovery 期间可提前缓存，完全恢复后的首个合法帧才消费；目标仍须可追击且 active 真实重叠。空技的 `link_targets` 按「落地恢复完成后首个合法帧」的延迟模型消费（j6D>5B、j214D 弹地等待后 5B/6A/214C）。`special_entry_link_targets` 是来源限定连接（仅 236C 特殊进入的 5D/5[D] 持有 5B 目押；普通来源不取得——按 CONFIGURATION_GAP 拒绝）。

`j2D` 的 `hit_landing_cancel_targets=["214C"]`（`hit_landing_cancel_window_frames=24`）是唯一落地例外：目标输入可在 Hitstop 中缓存（专用槽、正常帧计龄），落地首帧统一锁保持，落地事件后的首个可行动帧一次性消费并清除资格；跳过的是其余空技恢复，不绕过落地首帧锁。命门前预存输入不适用（票据 10 J5 实测：输入落在命中前会退化为普通缓存路径）。

`5[D]` 动作内蓄力：D 动作启动后按住，达到阈值（8 正常帧，Hitstop 不计龄）自动提交蓄力版；松开走普通版；启动前按住不积攒。236C 命中当下取得进入 5D 的特殊资格（窗口 16 帧、被防不开放、资格在授予招式执行期间有效）。

全部动作键 D 的招式（含蓄力与空中指令技）对**实际接地**目标的合法 normal/counter HIT 把水平受击速度置 0（覆盖原惯性；反应、垂直值、计时与资格不变，连段路线票据 01）。命中资料与资格先行判定——被防、挥空、缺资料与普通倒地不因此获得新命中能力；离地目标（如弹起中的弹地目标）不受此规则。

## 位移、扫掠与换边（ADR-0004）

`motion_x_px`/`motion_y_px` 成对声明：active 帧按累计比例推进计划位移，命中框沿本帧轨迹做轴对齐包络扫掠（无细分采样），正式位置经版边/身体约束后提交；被防/挥空照常走完轨迹。只有实际 HIT 才开放本次位移对身体的目标穿越，只有实际终点越过对侧才换边（SWITCHED_SIDES 事件，下一帧按真实横向关系更新面向）；被防、挥空、墙截断停在原侧。已开始的 214/236 方向候选锁定首次相对面向，换边不重解释。

## 起手与三层修正（C-01/C-02）

首次实际 HIT 锁定招式声明的 starter grade（上表「起手」列）；被防/挥空不锁定，跨浮空/slide/Rekka/弹地/落地不重置，连段结束清除。每次有效命中分别累计 damage/time/trajectory 三层：starter 倍率 × 状态分层每击倍率（普通 0.90/0.94/0.95、slide 0.92/0.96/0.96、弹地 0.88/0.92/0.93、落地连接 0.94/0.95/0.95），逐层独立舍入，伤害保 10% 底线、时间/轨迹不套底线。弹地接续（连段路线票据 01，撤销票据 09 的 STARTER_BOUNCE_FOLLOWUP/BOUNCE_END）：弹地目标上的有效命中按该目标声明的弹地资料正常结算并延续连段——不按起手等级授予一次性资格、无强制终点；再次有效命中可再次弹地，能否延长由弹地窗、资料与累计修正决定，多弹地仍有限（三层照常衰减、不重置）。

## 必填字段与校验

必填通用字段：`move_id`、`move_kind`、`stance`、`action_key`、三个帧窗口、`cancel_window_frames`、`priority`。打击还需 `base_damage`、`attack_attribute`、`air_attack`、命中框/间距、至少一个合法 `HitProfile`，以及被防结果三字段：`block_freeze_frames`/`block_stun_frames`/`block_pushback_px_s`（当前全表 8/9/45，逐招显式、整表齐备；投技不得声明；未声明 = 不可被防，无全局回退）。投需 `throw_range`，不走单键绑定，不得声明命中资料。`rekka_only`/`charge_only` 招式不参与单键/指令输入选择。方向串、替代串、严格/宽松、指令层级和 priority 共同决定识别；三步串窗口 30 正常帧含首帧。旧 `hit_result`/`hitstun_frames`/`knockback`/`knockback_up` 已删除，无回退。

非招式行为在 `scripts/game_params.gd`：Hitstop=8，缓存=6，方向步长=10，pre-jump=4，空中=38，基础落地=3，空技额外=1，dash=12/480px/s，投结果硬直 20/击退 240，弹地反弹 330/追击窗 16。地面蹲姿禁止主动水平移动（2026-09-18 真人反馈修复；复玩记录见 acceptance/10/playtest.md E 组）。

## 文件级同步实测

2026-09-17 实测（`tools/check_move_file_sync.gd`）建立「同一 5A.tres 修改 → 训练场命中 tick 与 Solver 路线伤害同步变化、非法表两端同因拒绝」的同步口径；此后每票的资源迁移以 test_move_table 注入变体与 test_hit_profiles 的 profile 编辑同步测试延续该口径（`_test_profile_edits_sync_session_and_solver`）。当前资源数值不含实验改动。

尚未实现的正向数据能力：pre-jump 四帧取消到显式地面必杀的配置入口（规则已定、缺实现，不得以「没有字段」当作验收通过）。
