# 10: 联合路线、真实空间回放与真人调校

Status: ready-for-human
Type: HITL
Stage: 9
Blocked by: 01, 02, 03, 04, 05, 06, 07, 08, 09

## What to build

按路线矩阵完成角色招式包的联合验收和有限调校：迁移 manifest 与旧资源、补齐训练场可读反馈、运行完整自动化、区分 Solver 证明边界，并对代表路线执行保留真实位置的回放。只调整有明确目的的参数组；规则变化回到 spec/decisions，数值变化同步 frame-data、资源版本和受影响报告。

## User stories covered

1-23 全部覆盖。

## Acceptance criteria

- [x] 逐招核对稳定 id、姿态、输入绑定、属性、HitProfile、取消目标、运动、修正和版本；旧 214D/jD 路线被明确迁移或标记废弃。（`acceptance/10/coverage.md` 逐招 23 行核对表 + 旧资源迁移结论；表级断言 `tests/acceptance_replay_10.gd` J0；地面 214D 资源/manifest 移除，八套测试迁移：识别主体→214C、倒地样例→注入探针 214P、收尾回边→214C~C；jD 票据 08 已移除本轮复核）
- [x] 训练场显示当前招式与阶段、目标状态、命中／被防／挥空、starter grade、三层修正、来源／追击资格和失败原因。（票据 01–09 累计交付：状态/事件/诊断三行；票据 10 补原生形状——C/D 系与 6A 出刀刀姿随前摇/判定/收招变化、收刀卡点亮起持刀侧锚点、A/B 系拳形、位移起落残影；`test_smoke` 武器呈现断言 4 条）
- [x] 按路线矩阵回放正反例，至少覆盖：
  - 5A > 5B > 5C > 5D 与 5B > 5D；（J1 双面向）
  - 2C > 214C~B；（J2 双面向，四击含 ~B 后 5B 目押）
  - 236C 段 1/段 2 > 5D/5[D] > 恢复后普通 5B；（J3a 两段>5D>5B 四击、J3b 段 1 窗口内按住 D>5[D] 穿越换边>5B 三击、J3c 段 1 挥空>段 2>5[D] slide 捞起 @96px 远距——票据 06「5B 失败」观察在按住式时序下不再成立，如实更新 frame-data）
  - 5A > 5B > 5C > 6A > jc.jB > jC > j2D > 214C~C；（J5 双面向：前缀七击成立；尾部 1 帧断链 + ~C 距离不足——调校候选 D1/D2，不冒充完整连段）
  - jC > j214D 的地面／空中目标；（J6b 字面路线对空七击成立；对地入口实测受空中预算约束——独立跳的 jC 只在下落段触及地面、停顿+前摇装不进剩余滞空，对地统一弹地由 J6 独立输入承担，边界记录于 frame-data v0.12；J7 B 起手对空延长）
  - j6D 普通落地连接与 j2D 专用落地取消。（J8 双面向）
- [x] 每条路线都有命中、被防、挥空或地面／空中负例；报告区分规则拒绝、缓存过期、状态不兼容、距离不足、墙截断、受身结束和 Solver 未支持。（N1a/N1b 被防、N2 挥空 LINK_FAILED、N3 无反向出口、N4 高度失配、N5 A 起手收尾、N6 挥空 j2D 无落地特权；J5 受身结束/距离不足、J6b 空中预算边界分类入 frame-data v0.12）
- [x] 真实空间回放覆盖中板／版边、近／远距离、左右面向、墙截断、击退、穿越、提前搓招和下一帧面向；静态钉位证据单独标为 spatial-valid。（J3b 真实穿越+下一帧面向、J4 版边墙截断、全程不钉位；静态钉位结论由 Solver 报告自持 spatial-valid 标注，见 solver-guide）
- [x] Solver 使用与运行时相同的 MoveTable 和状态键；timing-valid、spatial-valid、replay-required、configuration-gap 和 not-supported 不混写。（solver-guide 重写结论范围节；P0–P7 语义不变，最终全量指纹门随 final-02 通过）
- [x] 自动化验收通过，日志放在新的 acceptance 子目录；测试数量不作为唯一完成条件。（`acceptance/final-02/`：33 job 全绿 exit=0；`acceptance/10/` 定向与探针日志；回放 `acceptance/10/replay-joint.log` 93 断言全过）
- [ ] 真人试玩记录输入容错、短刀节拍、换边后指令、空中追击、j2D 落地、弹地和收尾反馈；没有反馈的项目明确标为待验收。（**待真人**——步骤与记录表 `acceptance/10/playtest.md` A–E 组 + 调校候选 D1–D6；未收到反馈前全部标待验收）
- [x] 已知有效无限路线全部有处置结论；未完成搜索不得写成"无循环"。（循环口径沿用逐圈快照重现 + CycleInvariant 声明式前置；A/B 起手循环边界由 J7/N5 复验——A 起手 BOUNCE_END、B 起手一次性消费；Solver 未完成搜索按截断/未完成如实上报，见 solver-guide「结论范围」）

## Solver and replay scope

这是本轮唯一把各状态合并为完整 Solver 状态键和真实回放报告的联合票。Solver 仍不搜索自由走位、中立、墙角、推挤或屏幕边界；任何需要这些能力的路线必须保留 replay-required，并由训练场实际位置日志证明。（已兑现：solver-guide 明确列出 replay-required 清单与「允许取消 ≠ 来得及命中」边界；J5 即为一例。）

## Human judgment

本票必须真人判断：被防安全性、D 系扫掠和换边手感、2C 低浮空节拍、j2D 落地节拍、bounce 追击和 A/B loop、参数调整后的短刀与收尾节奏。自动化和 Solver 通过不能替代真人结论。（**状态：待真人**——playtest.md 就绪，A–E 组与 D1–D6 调校候选等待反馈；反馈后按目的逐组调参并复验受影响路线。）

## 交付记录（2026-10-05）

- 实现改动：旧 214D 移除与八套测试迁移；训练场原生形状（player.gd/native_shapes.gd/game_params.gd/main.gd 提示行；C/D 键与 6A 及 214C Rekka 分支出刀、A/B 系与投徒手）；`tests/acceptance_replay_10.gd`（106 断言）；`tests/test_smoke.gd` 武器呈现测试（5C 刀姿/5A 拳形/6A 出刀/收刀卡点）。
- 文档：docs/move-data.md 全量重写（23 招表）、docs/training-guide.md 重写（操作/反馈/路线练习/验收入口/调参规则）、docs/solver-guide.md 头部重写（结论范围/性能口径/代表帧表/route_report）。
- 数值：零改动（frame-data v0.12 仅对账与锚点记录）。
- 证据：`acceptance/10/`（coverage.md、playtest.md、replay-joint.log、coverage-dump.txt、定向日志、探针）、`acceptance/final-01/`（中间跑：33 job 中 1 失败——test_solver_route 绑定行断言迁移遗漏）、`acceptance/final-02/`（终跑全绿）。

## Blocked by

- 01
- 02
- 03
- 04
- 05
- 06
- 07
- 08
- 09
