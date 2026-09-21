# C0–C9 正式规格：上下文命中资料

状态：accepted specification  
来源：design-decisions.md C0–C9、CONTEXT.md、ADR-0003、execution-path.md  
本文件冻结数据语义、匹配顺序、状态边界和验收行为；不冻结 D 轮最终帧数、速度、伤害或完整招式路线。

## 1. 范围

本轮实现三种命中反应：

- GROUND_HITSTUN：目标保持接地，进入地面受击硬直。
- LAUNCH：目标进入浮空受击，使用空中受身计时和垂直初速度。
- GROUND_KNOCKDOWN：目标进入独立普通倒地，计时自然恢复。

目标状态只支持 grounded 与 airborne，命中上下文只支持 normal 与 counter。命中资料由 MoveData 内嵌的 HitProfile[] 提供。OTG、地弹、墙反弹、招式无敌、主动受身、二段跳和自动延长空中资源不属于本轮；遇到这些未支持能力时必须拒绝数据或报告未支持，不能解释成普通命中。

本轮仍沿用全局 Hitstop 规则。Hitstop 不由 profile 覆盖，也不消耗任何受击、受身或倒地计时。

## 2. 数据模型

### 2.1 MoveData 字段

下表是本轮的完整 MoveData 边界。UNSET 和负数哨兵表示“未声明”，核心字段未声明时整张 MoveTable 拒绝。数值默认值是资源 schema 默认值，不是 D 轮招式调校值。

| 字段 | Godot 类型/枚举 | 单位 | 默认值 | 约束与语义 |
| --- | --- | --- | --- | --- |
| move_id | String | — | "" | 稳定身份；必须非空且表内唯一 |
| move_kind | MoveKind | — | UNSET | STRIKE 或 THROW |
| stance | Stance | — | UNSET | GROUND 或 AIR |
| action_key | String | — | "" | 打击技为 A/B/C/D；普通投为空并使用 B+C 组合 |
| startup_frames | int | 正常物理帧 | -1 | 必须为正整数 |
| active_frames | int | 正常物理帧 | -1 | 必须为正整数 |
| recovery_frames | int | 正常物理帧 | -1 | 必须为正整数 |
| base_damage | int | 伤害单位 | -1 | 打击技必填，必须为非负整数；连段衰减仍由会话处理 |
| attack_attribute | AttackAttribute | — | UNSET | 打击技必填；HIGH/MID/LOW/OVERHEAD |
| air_attack | bool | — | false | 与地面防御属性正交的 air 标记 |
| hitbox_size | Vector2 | px | Vector2.ZERO | 打击技两轴均须为正 |
| hitbox_gap | float | px | -1.0 | 打击技必须为非负 |
| hit_profiles | Array[HitProfile] | — | [] | 打击技至少一个合法 profile；投技不得声明 |
| throw_range | float | px | -1.0 | 仅普通投必填且为正；打击技必须保持未声明 |
| extra_landing_recovery_frames | int | 正常物理帧 | 0 | 仅空中招式可大于 0；不得绕过落地首帧锁 |
| cancel_targets | Array[String] | 招式 id | [] | 命中确认取消目标 |
| cancel_window_frames | int | 正常物理帧 | -1 | 必填且非负；窗口年龄从命中确认正常帧 0 起算，含两端 |
| is_finisher | bool | — | false | 为真时不得声明取消目标 |
| jump_cancel_targets | Array[String] | 招式 id | [] | 仅地面招式可声明；仍需实际命中、可追击目标和共用窗口 |
| landing_cancel_targets | Array[String] | 招式 id | [] | 仅保留历史兼容/诊断语义；不得绕过空技落地恢复 |
| direction_derivation | String | — | "" | 显式方向派生，如 236C |
| lenient_command | bool | — | false | 无方向记法时必须为假 |
| input_alternatives | Array[String] | — | [] | 显式输入替代串 |
| command_tier | CommandTier | — | NORMAL | NORMAL/SPECIAL/SUPER |
| priority | int | — | -1 | 必填且非负；同姿态、绑定、层级、优先级并列非法 |

本轮删除 hit_result、hitstun_frames、knockback、knockback_up 作为 MoveData 命中字段；命中结果、计时和运动全部从 hit_profiles 读取。不存在旧字段回退、GameParams 回退或按数组顺序猜测。

### 2.2 HitProfile 字段

HitProfile 是 MoveData 内嵌资源类型，不拆成独立 .tres 文件。每个 profile 的唯一键是 (target_state, hit_context)。

| 字段 | Godot 类型/枚举 | 单位 | 默认值 | 约束与语义 |
| --- | --- | --- | --- | --- |
| target_state | TargetState | — | UNSET | GROUNDED 或 AIRBORNE；表示命中前目标状态 |
| hit_context | HitContext | — | UNSET | NORMAL 或 COUNTER |
| reaction | Reaction | — | UNSET | GROUND_HITSTUN/LAUNCH/GROUND_KNOCKDOWN |
| damage_override | int | 伤害单位 | -1 | -1 表示使用 MoveData.base_damage；否则必须为非负整数 |
| ground_stun_frames | int | 正常物理帧 | -1 | 仅 GROUND_HITSTUN 使用；有效值为正整数 |
| air_untech_frames | int | 正常物理帧 | -1 | 仅 LAUNCH 使用；有效值为正整数 |
| knockdown_frames | int | 正常物理帧 | -1 | 仅 GROUND_KNOCKDOWN 使用；有效值为正整数 |
| horizontal_speed_px_s | float | px/s | -1.0 | 所有合法 reaction 必须声明，非负幅值；沿攻击者面向施加 |
| upward_speed_px_s | float | px/s | -1.0 | 所有合法 reaction 必须声明，非负；普通地面命中/倒地为 0，浮空必须大于 0 |

profile 的枚举默认值均为 UNSET。计时和速度的负数默认值只表示缺省；加载校验不得把它们解释为 0。

本轮新增枚举的固定成员为：

| 枚举 | 成员值 |
| --- | --- |
| TargetState | UNSET=0、GROUNDED=1、AIRBORNE=2 |
| HitContext | UNSET=0、NORMAL=1、COUNTER=2 |
| Reaction | UNSET=0、GROUND_HITSTUN=1、LAUNCH=2、GROUND_KNOCKDOWN=3 |

## 3. 合法组合与非法组合

MoveTable 在单招和跨招式校验阶段拒绝下列情况；任一错误都使整张表不可用，并报告资源、招式 id、字段和原因。

| reaction | 允许的 target_state | 必须声明 | 必须为 0/未声明 | 运行时效果 |
| --- | --- | --- | --- | --- |
| GROUND_HITSTUN | 仅 GROUNDED | ground_stun_frames >= 1、水平速度、垂直速度 | upward_speed_px_s == 0；air_untech_frames、knockdown_frames 保持 -1 | 保持接地，递减地面硬直；归零当帧进入中立并产生自然恢复事件 |
| LAUNCH | GROUNDED 或 AIRBORNE | air_untech_frames >= 1、水平速度、upward_speed_px_s > 0 | ground_stun_frames、knockdown_frames 保持 -1 | 进入浮空受击，应用水平/垂直初速度；空中受身计时归零前可继续追击 |
| GROUND_KNOCKDOWN | 仅 GROUNDED | knockdown_frames >= 1、水平速度、upward_speed_px_s == 0 | ground_stun_frames、air_untech_frames 保持 -1 | 进入独立倒地，立即结束当前连段；计时结束才自然恢复 |

另外：

- GROUND_HITSTUN 不能给地面目标隐式离地；旧 knockback_up 的非零值不能迁移成普通命中的垂直速度。
- LAUNCH 不得同时声明地面硬直或倒地计时。
- GROUND_KNOCKDOWN 不得接受 airborne 目标，也不得伪装成 GROUND_HITSTUN。
- 同一 (target_state, hit_context) 重复、未知枚举、任何负数有效值、计时与 reaction 不一致均非法。
- 对某个 target_state 声明 COUNTER 时，必须同时声明该状态的 NORMAL profile；不得只提供 counter。
- 只声明 downed/otg、bounce、wallbounce 或 invulnerability 的字段、枚举或标签均非法；本轮不扩展这些能力。
- profile 数组顺序不是选择依据。

## 4. target_state → hit_context 精确匹配

命中结算在应用命中结果前执行一次以下流程：

1. 读取目标状态：以命中判定发生前的目标状态分类。接地且非倒地为 GROUNDED；真正离地为 AIRBORNE。倒地、未支持状态和未知状态不会被转换成 grounded。
2. 读取命中上下文：若目标当前处于显式 Counter Hit 易受击窗口，取 COUNTER；否则取 NORMAL。首版易受击窗口是目标招式的 startup 与 recovery，active 不在窗口内。
3. 按键精确查找：以 (target_state, hit_context) 为唯一键查找 profile。实现上先按 target_state 建立候选，再按 hit_context 精确取值；任一维度没有完全相等的 profile，结果就是 MISS_NO_PROFILE。
4. 禁止回退：COUNTER 缺失时不得回退 NORMAL；AIRBORNE 缺失时不得回退 GROUNDED。未找到 profile 不造成伤害、不改变受击状态、不刷新倒地计时。
5. 应用一次：找到 profile 后读取 damage、reaction、速度和对应计时，产生命中事件；数组顺序、文件名和旧字段都不参与选择。

命中后的状态处理：

- GROUND_HITSTUN 只递减地面硬直；Hitstop 期间所有计时冻结。归零当帧产生自然恢复事件。
- LAUNCH 只递减空中受身计时；目标提前落地时，将剩余帧转为地面硬直继续递减；空中受身计时归零时结束连段，落地后回到中立。
- GROUND_KNOCKDOWN 使用独立倒地计时；进入时结束当前连段，倒地期间任何打击都不命中；计时结束产生恢复事件并回到 NEUTRAL。
- 普通命中、浮空和倒地都沿用既有 Hitstop、落地首帧锁、有限空中资源和自然受身规则。

## 5. Counter Hit 生命周期

- 触发：攻击 active 命中目标时，目标正处于自身招式 startup 或 recovery 的显式易受击窗口，命中上下文为 COUNTER。目标处于 active 时不触发。
- 选择：Counter 与 grounded/airborne 正交；选择同一 target_state 下的 COUNTER profile。Counter profile 至少在伤害、计时、速度或 reaction 中有一项与对应 normal profile 的设计差异，具体值留给 D 轮。
- 消耗：命中结果应用一次后立即清除 Counter 上下文；它不产生持续 buff，不影响同一命中之后的其他命中。
- 结束：窗口内没有命中，目标离开 recovery/startup 时清除机会；active 命中不建立 Counter。窗口已结束后的下一次命中选择 NORMAL。
- 状态边界：Counter 不改变倒地不可追击、浮空受身、普通倒地和连段结束规则。

## 6. 四组验收样例

最终数值由 D 轮提供；以下只冻结字段、状态、选择和可观察关系。每组都要用同一份已校验 MoveTable 同时驱动运行时和 Solver。

### A. 5A：普通地面命中与 Counter 变体

数据至少包含 grounded × normal 的 GROUND_HITSTUN、grounded × counter 的合法 Counter 变体，二者至少一个可观察字段不同；本样例不声明 airborne profile。

验收：

1. 地面木桩普通命中保持接地，产生地面硬直和正常伤害。
2. 同一招命中 airborne 木桩返回 MISS_NO_PROFILE，不从 grounded 借用资料。
3. 木桩在 startup/recovery 被 5A 命中时选择 counter profile；事件/回放能区分所选上下文。
4. 命中处理后 Counter 清除，下一次普通命中选择 normal。

### B. 6A：专用击飞入口

数据至少包含 grounded × normal 与 grounded × counter，二者 reaction 均为 LAUNCH，且 grounded launch 的向上速度大于 0。airborne profile 可选；未声明时必须按缺失 profile 拒绝，不得继承 grounded。

验收：

1. 地面命中将木桩置于 AIR_HITSTUN，应用 profile 的水平/垂直速度和空中受身计时。
2. Counter 窗口命中选择 6A 的 Counter profile；active 或普通窗口命中选择 normal。
3. 命中确认资格和已配置的 jump cancel 仍按既有窗口成立；挥空、被防或缺 profile 不取得 jump cancel。
4. 空中 profile 若存在，必须使用自身速度/受身计时；若不存在，Solver 与运行时都报告未匹配。

### C. 214D：普通倒地

数据至少包含 grounded × normal 与 grounded × counter，二者 reaction 均为 GROUND_KNOCKDOWN，垂直速度为 0，使用独立 knockdown_frames；本样例不声明 airborne profile。

验收：

1. 命中立即产生连段结束事件并进入普通倒地；不得把倒地伪装成地面硬直。
2. 倒地计时递减期间任何打击都返回未命中，不刷新计时，不开启新连段。
3. 计时结束产生自然恢复事件并回到 NEUTRAL；恢复后的下一次命中才可开始新连段。
4. Counter 窗口命中只改变本次 214D 结果，不改变倒地不可追击规则。

### D. Counter Hit：触发、消耗和结束

使用一个目标招式状态探针与一招带 normal/counter profile 的打击：

1. 目标处于 startup，攻击在 active 命中：选择 Counter profile。
2. 目标处于 recovery，攻击在 active 命中：选择 Counter profile。
3. 目标处于 active，攻击在 active 命中：选择 normal profile。
4. 目标处于 startup/recovery 但攻击挥空，随后窗口结束：不产生 Counter；窗口结束后的命中选择 normal。
5. 任一 Counter 命中后立即清除上下文；同一次命中后的后续招式不会继承 Counter。
6. Solver 的报告必须与运行时选择相同 profile；缺失或回退都视为失败。

## 7. 旧字段迁移清单

迁移必须改写每份打击招式资源和所有程序内测试 fixture；加载新表时不保留兼容回退。

| 旧字段 | 新位置 | 迁移规则 |
| --- | --- | --- |
| hit_result | HitProfile.reaction | 旧普通命中生成 grounded × normal profile；旧 LAUNCH 只迁移为显式 launch profile。不得由旧枚举推导 Counter、airborne 或 knockdown。214D 必须改成 GROUND_KNOCKDOWN，不能继续保留旧普通命中。 |
| hitstun_frames | 按 reaction 拆分 | GROUND_HITSTUN → ground_stun_frames；LAUNCH → air_untech_frames；GROUND_KNOCKDOWN → knockdown_frames。不把一个旧数值复制到不适用的计时字段。 |
| knockback | HitProfile.horizontal_speed_px_s | 为每个实际声明的 profile 显式复制水平速度幅值；方向仍由攻击者面向决定。Counter/airborne 若需差异必须单独填写。 |
| knockback_up | HitProfile.upward_speed_px_s | 仅 LAUNCH 保留为正的垂直初速度；GROUND_HITSTUN 与 GROUND_KNOCKDOWN 必须显式写 0。旧普通命中的非零值不能继续让目标离地。 |

迁移后的每个打击招式至少有一个合法 profile；需要 Counter 的招式同时提供同目标状态的 normal profile。旧字段从 MoveData schema、资源、MoveTable 校验、运行时和 Solver 测试中移除；手改资源缺字段或仍含旧语义时整表拒绝并指出来源。

## 8. 同步修改边界

### 运行时

必须使用共享 HitProfile 选择器完成状态先于上下文的精确匹配；在命中前分类 grounded/airborne 并读取 Counter 窗口；按 reaction 应用独立计时、速度、落地转换、倒地恢复和连段结束；保持 Hitstop、取消窗口、jump cancel、落地首帧锁和自然受身基线；对倒地、缺失 profile 和未支持效果返回可断言的未命中/错误事件；命中后清除一次性 Counter 上下文。

不在本轮加入防御硬直扩展、招式级 Hitstop、无敌、OTG、bounce 或 wallbounce。

### MoveTable

必须加载并深复制内嵌 HitProfile[]；校验枚举、唯一键、normal/counter 成对关系、reaction 与 target/timer/speed 组合、负数和未支持字段；发现一项错误即整表拒绝，错误包含资源来源、招式 id、字段和原因；不按 profile 数组顺序选择，不回退 GameParams 或旧字段。

### Combo Solver

必须与运行时共享同一份已校验 profile 数据和同一选择规则；在 grounded/airborne、normal/counter、hitstun/launch/knockdown 状态上使用相同计时语义；对缺失 profile、倒地不可追击、自然受身和 Counter 窗口输出与运行时一致的断链原因；验证 5A、6A、214D 和 Counter Hit 样例；不能把静态可达性写成真实命中证明；对本轮不支持的 OTG、bounce、wallbounce、invulnerability 明确报告未支持。

### 测试

至少覆盖 HitProfile 默认值、枚举和每种合法/非法 reaction 组合；重复键、Counter 无 normal、状态缺失无回退、旧字段缺失/残留和整表拒绝；grounded normal、airborne normal、grounded counter 的精确选择；三种 reaction 的运行时状态、计时、速度和结束事件；Counter 的 startup/recovery 触发、active 排除、挥空结束、命中消耗；5A、6A、214D 四组验收回放；运行时/Solver 使用同一表后的结果一致；既有 Hitstop、jump cancel、落地恢复、自然受身和循环检测回归。

## 9. 完成定义

本规格完成后的实施切片必须能用资源改动驱动训练场和 Solver 同步变化；非法 profile 不能产出部分可运行表；四组验收样例的正反例都有确定性事件或 Solver 报告。D 轮另行决定最终帧数、速度、伤害和完整取消路线，不得在本轮以默认值偷偷冻结。
