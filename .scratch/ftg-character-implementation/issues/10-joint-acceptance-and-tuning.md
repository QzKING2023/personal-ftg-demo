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

- [ ] 逐招核对稳定 id、姿态、输入绑定、属性、HitProfile、取消目标、运动、修正和版本；旧 214D/jD 路线被明确迁移或标记废弃。
- [ ] 训练场显示当前招式与阶段、目标状态、命中／被防／挥空、starter grade、三层修正、来源／追击资格和失败原因。
- [ ] 按路线矩阵回放正反例，至少覆盖：
  - 5A > 5B > 5C > 5D 与 5B > 5D；
  - 2C > 214C~B；
  - 236C 段 1/段 2 > 5D/5[D] > 恢复后普通 5B；
  - 5A > 5B > 5C > 6A > jc.jB > jC > j2D > 214C~C；
  - jC > j214D 的地面／空中目标；
  - j6D 普通落地连接与 j2D 专用落地取消。
- [ ] 每条路线都有命中、被防、挥空或地面／空中负例；报告区分规则拒绝、缓存过期、状态不兼容、距离不足、墙截断、受身结束和 Solver 未支持。
- [ ] 真实空间回放覆盖中板／版边、近／远距离、左右面向、墙截断、击退、穿越、提前搓招和下一帧面向；静态钉位证据单独标为 spatial-valid。
- [ ] Solver 使用与运行时相同的 MoveTable 和状态键；timing-valid、spatial-valid、replay-required、configuration-gap 和 not-supported 不混写。
- [ ] 自动化验收通过，日志放在新的 acceptance 子目录；测试数量不作为唯一完成条件。
- [ ] 真人试玩记录输入容错、短刀节拍、换边后指令、空中追击、j2D 落地、弹地和收尾反馈；没有反馈的项目明确标为待验收。
- [ ] 已知有效无限路线全部有处置结论；未完成搜索不得写成“无循环”。

## Solver and replay scope

这是本轮唯一把各状态合并为完整 Solver 状态键和真实回放报告的联合票。Solver 仍不搜索自由走位、中立、墙角、推挤或屏幕边界；任何需要这些能力的路线必须保留 replay-required，并由训练场实际位置日志证明。

## Human judgment

本票必须真人判断：被防安全性、D 系扫掠和换边手感、2C 低浮空节拍、j2D 落地节拍、bounce 追击和 A/B loop、参数调整后的短刀与收尾节奏。自动化和 Solver 通过不能替代真人结论。

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

