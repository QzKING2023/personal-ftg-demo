# 角色实施：调校初值

版本：v0.9，2026-09-28（票据 07 落表：6A jump cancel 扩展、jC/6D/2D 新建、空中出口与垂直判定字段、jB 空中硬直对齐 20；此前 v0.8 为票据 06 落表）；所有本表数值都是**调校初值**，没有一项表示已通过运行时或真人试玩（标注实测锚点的行为帧除外）。

时间基准为 60Hz 物理帧；距离为像素；速度为像素／秒；命中框尺寸为宽×高，原点相对角色中心。未声明字段在正式资源中保持“未声明”并由校验拒绝，不能使用本表以外的隐式默认值。

## 票据 01 补充初值（2026-09-24，全部 TUNING_INITIAL）

- 起手等级按招声明：5A=A、5B=B、5C=C、5D=D；6A=C、236C=D、214D=D、jA=A、jB=B、jD=D（后七者维持旧资源在场期间的占位值，各自后续票据复验）。BC 投不声明等级。
- counter 受击初值：5A/5B/5C 声明 18 帧（沿用旧 5A 样例的 ×1.3 关系）。
- 击退速度沿用旧样例：5A/5B 160、5C 140、5D 320 px/s（先入资源，空间票据复验）。
- 阶段 3 声明的普通连接边：5A→5B、5B→5C、5B→5D、5C→5D；不声明普通来源 5D→5B。
- 观察项（EXPERIMENT_REQUIRED）：A/B 起手普通地面硬直（14 帧声明值经时间层修正后 9–11 帧）短于 5A/5B 的完全恢复——阶段 3 调校值下普通连接边声明在位但全部按时序失败（Solver 如实报「目押超时」），正例路线经链式取消成立；目押正例依赖后续阶段的更长受击（如 236C 前置浮空）。
- 观察项（EXPERIMENT_REQUIRED）：5A 命中框远缘 56 px 与 80 px 探针站位恰为边界相接（Godot 相邻矩形不算相交）——空间层如实报 5A 起手路线 80 px 失败；调 5A gap 或接受边界由试玩决定。

## 票据 02 补充初值（2026-09-24，全部 TUNING_INITIAL）

- 2A/2B/2C 起手等级：2A=A、2B=B、2C=C；蹲姿限定 `requires_crouch`（当帧下方向 ∈ {1,2,3}，斜下含；与 5X 同键共存靠 priority：2A=3、2B/2C=2，均高于站立 1、2A 更高于 6A 的 2）。
- 2A/2B 击退 160/150 px/s、硬直 14/18（counter）；2C 击退 140 px/s。
- 2C 低浮空扫倒资料（仅 grounded 键；airborne 键不声明——精确匹配缺失即无命中）：受击窗口 `air_untech_frames` 20（counter 26）、离地速度 120 px/s（C 起手 0.92 轨迹层下 ≈110、滞空约 12 物理帧）、触地转 `GROUND_KNOCKDOWN` 计时 30。
- 链边：5A 链加 2B；5B 链加 2C；2A 链 5A/2A/5B/2B（A 系内部连接自由并进 B 系）；2B 链 5C/2C/6A。2C 本票无出边（必杀 214C 随票据 04 接通）。
- 观察项（EXPERIMENT_REQUIRED）：A 起手下 2B 受击窗口（floor(14×0.658)=9 帧）短于 2C 前摇到达——2A > 2B > 2C 第三击不成立，Solver 按截断如实报告；2B 起手（floor(14×0.82)=11 ≥ 10）成立。扫倒接续是否放宽由试玩决定。
- 观察项（EXPERIMENT_REQUIRED）：低浮空触地节拍（约 12 物理帧滞空 + 8 帧停顿）待试玩；`2C > 214C~B` 的真实可达性在票据 04 接通派生后复验。

## 票据 03 补充初值（2026-09-25，全部 TUNING_INITIAL）

- 被防结果三字段随 schema 落表（全部打击招式同值：停顿 8、硬直 9、推退 45px/s；BC 投不声明）：字段语义独立于命中资料与命中 Hitstop，逐招可调；程序注入表未声明 = 不可被防（默认禁止）。
- 链式取消窗口（0–3f）与必杀取消窗口（0–5f）自接触帧计龄——命中与被防接触共用同一窗口声明；命中确认窗口 0–8f 仅实际 HIT。
- 观察项（EXPERIMENT_REQUIRED，acceptance/03 回放初值下的结论，非普遍安全结论）：5A 被站防后 60px 反击 5A 恰在攻击方恢复后 1 帧命中（不防御时“已恢复未防”、按住后方向可挡住）；5D 被站防 60px/版边均被反击 5A 确反（恢复 F38 晚于反击命中 F31）；100px 中板反击 5A 因距离挥空。45px/s 攻击方推退在接触当帧被摩擦抵消（位移不可观察），防守方推退约 +1px——数值手感待试玩。

## 票据 04 补充初值（2026-09-25，全部 TUNING_INITIAL）

- 资源新增 `214C`（首段）、`214C~B`、`214C~C`（两个 `rekka_only` 派生，不参与单键/指令输入选择）；`rekka_window_frames=12`（接触起 0–12 帧正常帧计龄，停顿不计，Hitstop 中按下同样锁分支）。
- 必杀取消边接通：`2C/5A/2A/5B/5C → 214C`（窗口 5）；`2B/6A/5D` 仍无必杀取消（按取消矩阵）。
- 214C 首段 profile：grounded GROUND_HITSTUN 14/18（counter）、水平 160；airborne LAUNCH untech 28/34、up 240、水平 **40**（调低空中击退，保住派生与后续目押距离——原计划位移 -24 尚未实现，随阶段 5 位移票复验）。
- 214C~B profile：grounded GROUND_KNOCKDOWN 30、水平 140；airborne LAUNCH untech **36/44**、up 80、水平 **40**（延长浮空须覆盖 ~B 完全恢复 + 5B 前摇 + 落地余量：贴身 48 px 下 `2C > 214C > ~B(空中) > 5B` 四击成立）。`link_targets=["5B"]`。
- 214C~C profile：grounded GROUND_KNOCKDOWN 30、水平 140；airborne 新反应 `DOWNWARD_SLAM`（向下速度 620、水平 120、触地转普通倒地 30，无空中受击计时）；`is_finisher=true`。
- 起手等级声明：214C=D、214C~B=B、214C~C=C（派生自身几乎不可能首击，声明仅为满足校验必填）。
- 观察项（EXPERIMENT_REQUIRED，acceptance/04 回放初值下的结论，非普遍结论）：
  - **~B 被蹲防确反**：60 px 反击 5A 于 F54 命中，攻击方 F60 才可行动——与设计意图「~B 交回回合、不被确反」不符；候选调校方向为缩短 ~B 后摇（当前 18）或加大其被防硬直（当前 9）。~C 被站防确反（F56 命中 vs F68 恢复）符合设计。
  - 空中延长 → 5B 目押在贴身 48 px 成立；60 px 起始时三段击退累计 ~50 px 使 5B（触及 72 px）挥空——中远距可用性依赖击退/位移调校，随阶段 5 D 系位移票一并复验。
  - 派生窗口 12 帧与首按锁定的输入手感、同帧 B+C 固定 ~C 优先级的实机确认，均待真人试玩。

## 票据 05 补充初值（2026-09-25，全部 TUNING_INITIAL）

- 236C 迁移为两段判定（`segments` 资源承载段 2）：属性 high→mid；jump cancel 声明移除（6A 承担 launcher，负例：236C→jA 边不再存在）。
- 段 1 资料：grounded LAUNCH untech 32 / up 160 / h 60（低浮空——D 捞起与段 2 都够得着）；airborne LAUNCH 34 / 240 / 40。
- 段 2 资料：grounded `LOW_FLOAT_TO_SLIDE` untech 16 / up 120 / h 100 / **slide 18**（触地后自下一正常帧倒数）；airborne LAUNCH 30 / 180 / 40（延长浮空）。
- 特殊进入：`special_entry_targets=["5D"]`、消费窗口 **16 帧**（正常帧计龄，被防/挥空不授予；资格在授予招式执行期间有效，连段结束/招式结束清除）。
- 5D 新增资料：airborne LAUNCH untech 32 / up 170 / h 80（捞起覆盖浮空）；slide LAUNCH 32 / 170 / 60（捞起覆盖滑行，`GROUND_SLIDE` 目标键）；`special_entry_link_targets=["5B"]`（仅来源限定，普通 5D 无此边）。
- slide 命中每击倍率 0.92/0.96/0.96 落入 GameParams（`SLIDE_HIT_*`），与普通命中 0.90/0.94/0.95 分层。
- Solver 修正：普通连接按下档的命中→收招正常帧距离为 `total - startup - 1`（命中当帧的招式推进在停顿前完成）——修正既有差一。
- 实测锚点（@70px 右面向，回放见 acceptance/05）：段 1 F13 命中、段 2 F26；特殊进入 5D F41、5B 目押 F76（5D 收招 F70 当帧消费）；@93px 段 1 挥空、段 2 F18、触地 F36、5D 捞起 F37（slide 倍率下 16.6 伤害）。
- 观察项（EXPERIMENT_REQUIRED）：
  - slide 可视位移偏小（h=100 px/s 在 500 px/s² 摩擦下总位移约 9px，主要发生在触地前后）；加大击退会挤占 5D 捞起距离（触及上限 114px）。
  - R2（slide 捞起）后接 5B 目押在 93px 起始下不可达（5B 触及 93px，木桩滑出后 >100px）——需 236C/D 计划位移（票据 06）后复验；本票 5B 目押正例取 R1（前置浮空路线）。
  - 236C 自身计划位移（28/36）未实现（阶段 5 票据 06 边界）。
  - 特殊进入窗口 16 与命中确认窗 8 并存的手感；A 起手 `5A>236C>5D>5B` 循环实测断于 5B 目押（LINK_FAILED/TARGET_RECOVERED）——不形成 slide loop。

## 票据 06 补充初值（2026-09-27，全部 TUNING_INITIAL）

- 资源新增计划位移字段 `motion_x_px`/`motion_y_px`（两轴成对；active 帧按累计比例推进，命中框沿本帧轨迹做轴对齐包络扫掠——无细分采样误差，M-03 的扫掠细分观察项因此消解为包络口径）与蓄力字段 `charge_threshold_frames`/`charge_move_id`/`charge_only`。
- 5D 落表 `motion=(72,0)`；新建 `5[D]`（7/4/22，伤 20，命中框 70×28 gap 4，`motion=(120,0)`，`charge_only`，profile 镜像 5D 三组，`special_entry_link_targets=["5B"]`）；5D 声明 `charge_threshold_frames=8 → "5[D]"`。
- 蓄力时序（实测锚点，回放见 acceptance/06）：按下帧起按住，active 边界延长 startup——提交发生在第 max(前摇-1, 阈值)=8 次推进的帧末（5D 按 8 帧：普通 5D 点按 F1 按下 → F8 首判定；按住 → F9 提交、F10 首判定 5[D]）；提交帧钟回卷至提交版 active_from，提交版完整走自己的 active/recovery。
- 位移/换边锚点（真实位移回放，非钉位）：中板 @50px `236C>5[D]` F30 蓄力提交、F31 命中、F42 穿越换边（下一帧面向翻转）；@70px 普通劈拳路径 5D 终点与木桩重叠 → 截原侧身体边界（-48px），不换边；版边 5D 墙截断可观察且不换边；被防 5D 截原侧 -48px；挥空 5D/5[D] 全程 72/120px 照常走完。
- 观察项（EXPERIMENT_REQUIRED）：
  - 蓄力阈值 8（仅比普通前摇多 2 帧有效延迟）的可操作性与 5[D] 收招 22 的手感。
  - 穿越后镜像指令、版边穿越手感与扫掠包络边界容差需真人试玩。
  - `236C > 5[D]` 后 5B 目押在默认表下剩余硬直不足（D 收招 F64 消费成功、5B 判定 F70 晚于木桩恢复 F67）——注入 untech 44 的表可三击成立；与票据 05 观察项同源（击退/位移调校联动）。
  - 236C/214C 自身计划位移（28/36、-24/-8/-4）仍未落表——影步距离属后续调校轮，机制（motion 字段）已就绪。
  - 6D/j5D/j6D/j2D 的位移值尚无资源（阶段 6/7 交付时落表，机制共用 motion 字段）。

## 票据 07 补充初值（2026-09-28，全部 TUNING_INITIAL）

- 新 schema：`MoveData.air_exit_targets`（地面招式实际 HIT 且计划位移真实离地后，命中确认窗口内按空中姿态起手的空中目标；沿用 cancel_window_frames、不另设窗口；被防/挥空/缺失 profile 不开放；只配置在地面招式上，目标必须是空中招式）与 `MoveData.hitbox_y_offset_px`（命中框垂直偏移，正为向下、0=居中；表达对空/对地真实垂直范围）。
- `6A` jump_cancel_targets 扩展为 `["jA","jB","jC"]`；`jA` cancel += jC；`jB` cancel += jC（jD 边保留至票据 08 迁移）；`2C` 链式 += `["6D","2D"]`（窗口 3）。
- 新建 `jC`（7/5/14，伤 14，mid+air，命中框 48×30 gap 4，motion 4/0，starter C；grounded 12/16·100、airborne untech 20/26·up 60·100）。
- 新建 `6D`（9/4/20，伤 18，mid，命中框 48×36 gap 4，motion **88/−48**，starter D，派生 6D·优先级 2；airborne-only 资料 untech 30/36·up 140·100——无 grounded 键，对地 MISS_NO_PROFILE；`air_exit_targets=["jA","jB","jC"]`）。
- 新建 `2D`（8/4/18，伤 17，mid，命中框 36×46 gap 3·**y_offset −70**，motion 0/−64，starter D，蹲姿限定·优先级 3；airborne-only 资料 untech 26/32·up 180·60；`air_exit_targets=["jA","jB","jC"]`）。
- `jB` airborne untech 12→**20**（对齐「普通空中硬直 20f」全局初值；A 起手时间层下 12 撑不到 jC 前摇——实测 demo 路线第 6 击差 1 帧）。
- 实测锚点（acceptance/07 回放，@50px 双面向）：R1 `5A>5B>5C>6A>jc.jB>jC` 六击单连段 F6/21/38/54/75/91（6A 需 5C 命中当帧 w=0 取消；Space F56 停顿中入槽、F63 pre-jump、F67 离地）；R2 `2C>6D>jC` F13/31/47（6D F31 命中时离地 12px、出口 F31 开、jC F47 命中）；R2b 6D 命中后 88px 位移在最小合法间距 48px 下终点仍在木桩一个身位内——按 M-02 截原侧身体边界、不换边（正向换边需 motion ≥ 间距+48+击退漂移，见观察项）；R3a `2C>2D` 2D active F25-28 期框底 393 恒高于浮空木桩顶 394.7+（高度失配挥空、木桩仍在空中）；R5 `2D>jA` F9/F22（−40px 空中中立木桩、出口滞空至 F38 物理回落）。
- 观察项（EXPERIMENT_REQUIRED）：
  - 6D motion_y 表内原值 −18 撑不起 jC 出口所需真实滞空（命中停顿吞掉 3 个 active 帧后仅剩 ~9 帧滞空 < jC 前摇 7+active）——本票实测调至 −48；最终斜上追入高度待试玩。
  - 6D motion_x 88 在最小合法间距 48px + 自身击退漂移下永远无法越过对侧（终点差 ~13px）——设计路线「6D sideswap」需要 motion ≥ ~115 或更近的浮空目标几何；与 5B 对空资料同属后续调校轮，本票换边正例未成立（如实按 M-02 原侧保留记录）。
  - 2D y_offset −70 的命中窗为 h>7px（6A 击飞 63px 峰值可及、2C 低浮空 3.4px 峰值不可及）；高度容差边界（7px 附近）待真人调校。
  - 6D/2D 空中出口的 j5D/j6D/j2D/j214D 目标随票据 08/09 交付后接入（当前声明至已交付的 jA/jB/jC）。
  - `5B`「对空资料优于 2B」尚未落表（无 airborne 键）——设计路线 `5B > 6D sideswap` 依赖它，属后续调校轮；本票 6D 正例经 2C 链式进入。
  - 6A 表值 8/5/20、38×48 与在役资源 8/6/20、64×60 的差异未在本票处理（在役值承载既有 853 断言），阶段 9 统一复检。
  - 空中出口节拍（停顿中按键、恢复首正常帧消费）与 jc 起跳节拍的手感差异待试玩。

## 全局与输入初值

| 参数 | 调校初值 | 说明 |
| --- | ---: | --- |
| 物理帧率 | 60Hz | 1f = 16.67ms |
| Hitstop | 8f | 命中与被防分别声明；冻结期间不推进动作、蓄力、状态和取消年龄 |
| 动作缓存 | 6f | 继承现有输入基线；Hitstop 不增龄 |
| 组合等待 | 3f | B+C 及其他显式组合；Rekka 派生窗口内不进入该等待 |
| 链式取消窗口 | 0–3f | 接触帧计龄；待阶段 4 试玩 |
| 必杀取消窗口 | 0–5f | 接触帧计龄；待阶段 4 试玩 |
| 命中确认取消窗口 | 0–8f | 实际命中帧计龄；待阶段 6 试玩 |
| Rekka 派生窗口 | 0–12f | 首次 B/C 新按下立即锁分支；待阶段 4 试玩 |
| `5[D]` 蓄力阈值 | 8f | 动作启动后正常物理帧；自动触发，Hitstop 不计入 |
| `236C` 两段间隔 | 3f | 第一段 active 结束至第二段 active 开始；第一段被防立即终止 |
| 特殊进入消费窗口 | 0–16f | 实际 HIT 授予、授予招式执行期内消费；停顿计龄冻结 |
| 被防停顿 | 8f | 独立于命中停顿的调校初值 |
| 被防硬直 | 9f | 防守方停顿结束后的不可行动帧 |
| 被防推退 | 45px/s | 停顿结束后独立施加，版边截断 |
| 普通地面硬直 | 14f | grounded normal profile 初值 |
| 普通空中硬直 | 20f | airborne normal profile 初值 |
| 普通倒地 | 30f | 进入即结束连段；不接受 OTG |
| `GROUND_SLIDE` 持续 | 18f | 触地后的下一正常帧开始计时 |
| `GROUND_BOUNCE` 触地前 | 6f | grounded 命中直接离地的初值；airborne 资料可覆盖 |
| `GROUND_BOUNCE` 触地后 | 16f | 触地事件后开放统一追击窗口 |
| 弹地反弹速度 | 330px/s | 向上为负；待空间回放 |

## 招式初表

| 招式 | startup / active / recovery | 伤害 | 属性 | 命中框（宽×高，gap） | 计划位移（水平/垂直） | 主要资料与取消初值 |
| --- | --- | ---: | --- | --- | --- | --- |
| `5A` | 5 / 4 / 10 | 8 | mid | 30×24, 2 | 0 / 0 | grounded normal；链 5B/2B，必杀 214C/236C |
| `2A` | 5 / 4 / 10 | 8 | low | 30×20, 1 | 0 / 0 | grounded normal；链 A/B，必杀 214C |
| `5B` | 6 / 5 / 12 | 12 | mid | 42×28, 3 | 8 / 0 | grounded normal；链 5C/2C/6A/5D，必杀 214C/236C |
| `2B` | 7 / 5 / 12 | 11 | low | 40×22, 2 | 5 / 0 | grounded normal；链 5C/2C/6A |
| `5C` | 8 / 5 / 16 | 16 | mid | 48×32, 4 | 4 / 0 | grounded normal；链 6A/5D，必杀 214C/236C |
| `2C` | 9 / 3 / 18 | 14 | low | 52×18, 3 | 6 / 0 | `LOW_FLOAT_SWEEP` → `GROUND_KNOCKDOWN`；必杀 214C |
| `6A` | 8 / 5 / 20 | 16 | mid | 38×48, 3 | 0 / 0 | grounded launcher；命中确认 jump cancel → jA |
| `5D` | 7 / 4 / 18 | 18 | mid | 62×26, 4 | 72 / 0 | swept active；ground/air/slide profiles；普通连接 5B 另判 |
| `5[D]` | 7 / 4 / 22 | 20 | mid | 70×28, 4 | 120 / 0 | 动作内蓄力阈值 8f 自动触发；与 5D 共用换边规则 |
| `6D` | 9 / 4 / 20 | 18 | mid | 48×36, 4 | 88 / -48 | airborne-only；命中后空中出口 jA/jB/jC |
| `2D` | 8 / 4 / 18 | 17 | mid | 36×46, 3（y偏移 -70） | 0 / -64 | airborne-only 高位拦截；低浮空 `2C` 因高度失败初值 |
| `214C` 首段 | 8 / 4 / 20 | 10 | mid | 42×28, 3 | -24 / 0（未实现，阶段 5） | 命中／被防开派生（窗口 12）；首个 B/C 锁分支；starter D |
| `214C~B` | 7 / 3 / 18 | 8 | low | 44×18, 2 | -8 / 0（未实现） | grounded → knockdown；airborne → 延长浮空（untech 36/44）；link 5B |
| `214C~C` | 9 / 3 / 24 | 14 | overhead | 46×34, 3 | -4 / 0（未实现） | grounded → knockdown；airborne → 向下击落（DOWNWARD_SLAM）；收尾 |
| `236C` 段 1 | 6 / 2 / 0 | 8 | mid | 40×26, 3 | 28 / 0 | grounded → normal float；airborne → air profile；命中段可特殊取消 D |
| `236C` 段 2 | 3 / 2 / 22 | 12 | mid | 46×30, 3 | 36 / 0 | 第一段被防不执行；grounded →击飞触地 slide；airborne → air profile；命中段可特殊取消 D |
| `jA` | 4 / 5 / 10 | 8 | mid | 28×24, 2 | 0 / 0 | airborne normal；可入 jB/D/j214D |
| `jB` | 5 / 5 / 11 | 11 | mid | 42×26, 3 | 6 / 0 | airborne normal；可入 jC/D/j214D |
| `jC` | 7 / 5 / 14 | 14 | mid | 48×30, 4 | 4 / 0 | airborne normal；稳定进入 j214D |
| `j5D` | 6 / 4 / 16 | 16 | mid | 54×24, 4 | 74 / 0 | active 扫掠；命中不产生 bounce |
| `j6D` | 7 / 4 / 18 | 17 | mid | 48×34, 4 | 68 / 26 | 命中后普通落地连接；无 j2D 例外 |
| `j2D` | 8 / 4 / 20 | 18 | mid | 42×42, 3 | 0 / 70 | 实际命中取得一次 `j2D → 214C` 落地资格 |
| `j214D` | 9 / 4 / 22 | 20 | mid | 52×36, 4 | 12 / 64 | grounded/airborne 都进入 `GROUND_BOUNCE`；一次反弹 |
| `BC` | 5 / 11 / 10 | — | throw | 投距 64 | 0 / 0 | 继承现有普通投；不进入本角色打击修正 |

## 修正初值

以下倍率先作为调校初值；每次实际命中按层相乘并按层舍入。A/B/C/D 是 starter grade，不是动作键优先级。

| starter | damage | time | trajectory | bounce_followup |
| --- | ---: | ---: | ---: | ---: |
| A | 0.72 | 0.70 | 0.75 | 0 |
| B | 0.84 | 0.82 | 0.85 | 1 |
| C | 0.93 | 0.90 | 0.92 | 1 |
| D | 1.00 | 0.96 | 0.96 | 1 |

| 每次后续命中累计倍率 | damage | time | trajectory |
| --- | ---: | ---: | ---: |
| 普通命中 | 0.90 | 0.94 | 0.95 |
| slide 命中 | 0.92 | 0.96 | 0.96 |
| bounce 追击 | 0.88 | 0.92 | 0.93 |
| 落地普通连接 | 0.94 | 0.95 | 0.95 |

## 验证标签

- `TUNING_INITIAL`：本文件全部招式、窗口、状态、倍率和空间数值。
- `INHERITED_BASELINE`：60Hz、Hitstop 8f、动作缓存 6f、组合等待 3f、普通投 5f startup 等既有系统规则；在新路线中仍需回放确认边界。
- `EXPERIMENT_REQUIRED`：扫掠细分、身体边界容差、段间距离、slide／bounce 真实追击、反击安全性、A/B loop 和真人手感。
