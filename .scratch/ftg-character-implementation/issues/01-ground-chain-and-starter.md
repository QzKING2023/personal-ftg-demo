# 01: 普通地面链与起手修正基线

Status: implemented
Type: AFK
Stage: 3
Blocked by: None - can start immediately
验收：2026-09-24 完成，证据见 [acceptance/01/report.md](../acceptance/01/report.md)（全量 1903 PASS；60 px 双面向回放日志；正反例断言位置）。被防接触分支、目押正例的时序可达性与 5A@80px 边界为已声明的交付边界。

## What to build

交付一条可重置、可逐帧回放的普通地面端到端切片：5A > 5B > 5C > 5D，以及 5B > 5D。迁移 5A/5B/5C/5D 的新职责，使 5C 成为普通地面重攻击而不再承担专用 launcher；以共享 MoveTable 驱动 CombatSession、训练场反馈和 Solver。

普通连接必须与取消分开：前招 recovery 中允许提前缓存，攻击者完全恢复后首个合法帧才消费；普通来源的 5D 在本票不声明反向 5B 边。首次实际 HIT 锁定 A/B/C/D starter grade，接触前不锁定。

## User stories covered

1, 2, 5, 18, 19, 22, 23。

## Acceptance criteria

- [x] 合法资源能从 manifest 加载，5A、5B、5C、5D 的属性、HitProfile、取消目标和 starter grade 显式声明；旧 5C launcher 字段和废弃职责不再被运行时读取。
- [x] 5A > 5B > 5C > 5D 与 5B > 5D 在地面目标仍处于可追击硬直时真实命中；同一份资源修改同时改变训练场和 Solver。
- [x] 前招 recovery 中提前输入普通连接不会打断前招；恢复完成后才消费缓存，目标已恢复、距离不足或状态不兼容时产生可读失败原因。
- [x] 链式／必杀取消只在已配置且命中或被防的接触条件下开放；挥空不产生接触、取消年龄或连段延续。（运行时当前只有命中接触路径——被防接触分支随木桩防御入口在票据 03 接入，窗口与资格结构已就位。）
- [x] 5C 命中是普通地面命中；被防或挥空不能 jump cancel 或取得专用击飞资格。
- [x] 首次实际 HIT 锁定 starter grade；被防、挥空和状态转换不会锁定、提升或重置；三层修正至少能在连续普通命中中显示和断言。
- [x] 正例：5A > 5B > 5C > 5D、5B > 5D。
- [x] 反例：5A 挥空后取消、普通 5D 反向接 5B、目标已自然恢复后缓存仍命中、5C 被防后 jump cancel。
- [x] 回归既有 HitProfile 精确匹配、Hitstop、自然恢复和资源整表拒绝测试。

## Solver and replay scope

Solver 必须报告普通取消边与恢复后普通连接边为不同类型；本票只承诺 timing-valid 和固定接触位的 spatial-valid。它不承诺自由走位、墙角、真实击退或换边。回放记录输入帧、启动／active／recovery、目标剩余硬直、starter grade 和三层修正。

## Human judgment

无本票阻塞性真人判断；帧数和倍率沿用 frame-data.md 的 TUNING_INITIAL，后续空间和手感在对应票据复验。

## Blocked by

None - can start immediately

