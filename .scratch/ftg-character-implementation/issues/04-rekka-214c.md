# 04: Rekka 首段、派生锁定与地空结果

Status: implemented
Type: HITL
Stage: 4
Blocked by: 02, 03
验收：2026-09-25 完成，证据见 [acceptance/04/report.md](../acceptance/04/report.md)（全量自动化、正反例双面向回放与被防派生安全矩阵）。~B 被防在当前初值下被近距 5A 确反（与「交回回合不被确反」的设计意图不符——列入 EXPERIMENT_REQUIRED 待调校）、派生首按锁定手感与同帧 B+C 仲裁为已声明的待真人判断项。

## What to build

交付 214C 首段与 214C~B / 214C~C 派生，形成 2C > 214C~B 端到端路线。首段命中或被防后进入独立派生窗口；第一次 B/C 新按下立即锁分支，派生优先于普通投 B+C 组合等待，同帧 B+C 固定按 C > B 处理。

## User stories covered

7, 8, 18, 19, 21, 22, 23。

## Acceptance criteria

- [x] 214C 首段使用 mid 与显式 grounded/airborne profile；命中和被防都能进入派生窗口，挥空不能进入。（`rekka_window_frames=12`；`_open_rekka_window` 在 `_apply_player_hit`/`_apply_player_blocked` 挂钩，`_rekka_window_active` 按正常帧计龄；`_test_rekka_window_requires_contact_hit_block_whiff` 三分支。）
- [x] 派生窗口内第一次 B/C 新按下立即锁定 ~B/~C；随后另一键、延迟观察防守或普通投等待都不能改写分支。（`_check_rekka_derivation` 仲裁器先于 `_check_throw_combination`，窗口内 B/C 按键全部消费不进组合等待/单键缓存；`_test_rekka_first_press_locks_branch`。）
- [x] 同帧 B+C 锁定 ~C，不产生普通投等待；窗口外 B+C 仍沿用既有组合规则。（固定 C > B 扫描顺序；`_test_rekka_first_press_locks_branch` 同帧例、`_test_rekka_window_expiry_keeps_throw_rules_outside` 窗口外 STATE 拒绝 + 恢复后正常投。）
- [x] 214C~B 命中 grounded 目标进入 GROUND_KNOCKDOWN；命中 airborne 目标进入短暂 AIR_HITSTUN 延长，恢复后可按硬直和距离连接地面技。（untech 36/44 延长覆盖 ~B 恢复 + 5B 前摇；触地转 GROUND_HITSTUN 保剩余计时；`_test_rekka_b_ground_knockdown_airborne_extension_and_link` 四击路线 `2C > 214C > ~B(空中) > 5B`。）
- [x] 214C~C 命中 grounded 目标直接 GROUND_KNOCKDOWN；airborne 目标只在独立向下击落 profile 存在时命中并落地转倒地，缺失不回退。（新反应 `DOWNWARD_SLAM` + `SPIKE_FALL` 木桩状态：向下速度坠落、触地同帧转普通倒地并发出 `SPIKE_LANDED`；`_test_rekka_c_ground_knockdown_and_airborne_spike`；MoveTable 校验 DOWNWARD_SLAM 仅 airborne、向下速度必填。）
- [x] 派生被防只产生对应 BLOCKED 结果；~B/~C 的安全性绑定固定反击场景，不由 low/overhead 名称自动推断。（蹲防全程双 BLOCKED 零命中；站防下 ~B low 漏出为混合起点；安全矩阵见 acceptance/04/replay-routes.log——~B 蹲防确反 F54/F60、~C 站防确反 F56/F68，均绑定 TUNING_INITIAL 近距 60 px。）
- [x] 正例：2C > 214C~B；空中目标 214C~B 后恢复连接；命中或被防首段后同帧 B+C 选择 ~C。（canonical 四击路线双面向；被防首段同帧 B+C 见回放「被防派生」段。）
- [x] 反例：首段挥空派生、先 B 后 C 升级为 ~C、派生窗口内变成普通投、~B 空中命中直接倒地、~C 借 grounded profile 命中空中目标。（对应会话测试与回放负例段；~C 空中命中只走 DOWNWARD_SLAM，MoveTable 拒绝 grounded 键上的向下击落资料。）
- [x] starter grade 和三层修正跨 Rekka 保留；普通倒地清除连段和修正。（`_test_rekka_starter_and_corrections_across_rekka`：C 起手 0.90 → ×0.94 逐击累计；KNOCKDOWN/FINISHER 清除回 UNSET/1.0。）

## Solver and replay scope

- [x] Solver 新增 `REKKA_DERIVE` 边类型：首段目标经 `_context_via_rekka` 构造上下文，派生按键按下当帧起手（无组合等待）、有效等待自接触后第 1 帧起；两条派生边与 5 条 214C 必杀取消边全部 timing-valid，正例路线 `2C > 214C > 214C~B`（3 击）与 `5B > 2C > 214C > 214C~C`（4 击收尾）入路线图。（`_test_rekka_derive_edges_and_routes`。）
- [x] 报告分类：有效边 reason 含 branch-locked；窗口外按键报 buffer-expired；资料缺失报 state-incompatible；被防派生附「被防路径」标注（~B 站防漏出=混合起点、~C 再次被防），被防安全性/首按手感一律 replay-required（SCOPE_TEXT 已声明）。`214C~B → 5B` 连接边在规范地面上下文（倒地收尾）如实报无效——空中延长的目押由会话回放证明，静态报告不冒充。
- 未支持（如实声明）：Rekka 派生缺口不参与配置缺口枚举（无「若配置了其他 B/C 招式」的推测性建议）；派生等待档只验证最早档（wait=1），中迟档由窗口上界标注、不逐一枚举。

## Human judgment

待真人确认（不阻塞本票行为验收）：~B 被防确反与设计意图「交回回合」冲突的调校方向（缩短后摇或加大被防硬直）、派生首按锁定输入手感、同帧 B+C 固定 ~C 的实机仲裁感受、延长浮空 → 5B 目押的中远距可用性（贴身已验证，距离敏感）。自动化证明确定性行为与事件字段；全部数值为 TUNING_INITIAL。

## Blocked by

- 02
- 03
