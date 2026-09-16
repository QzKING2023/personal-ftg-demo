# 09: Solver 完整路线、时序/空间分层与循环证明

**What to build:** Combo Solver 用一次性 CombatSession 逐帧验证已实现规则的完整接续图和路线，区分 timing-valid、可选 spatial-valid、配置缺口、有限空中资源断链与真实可重复循环，不把未配置连接当成合法连段。

**Blocked by:** 02: 面向锁定、空中动量与方向派生; 03: Hitstop、输入缓存与命中确认取消; 04: Jump 阶段与 jump cancel; 05: 蹲下与站防/蹲防/空防; 06: 普通投与拆投; 07: 66/44 前冲与后撤; 08: Solver 入口与操作说明

**Status:** ready-for-agent

- [ ] Solver 枚举姿态、输入绑定、方向指令 variant、取消窗口、jump cancel、落地接续和等待帧，并由真实会话探针验证前摇、命中、硬直、运动、落地和自然受身。
- [ ] cancel_targets、jump_cancel_targets 和 landing-cancel 目标是运行时硬约束；时序成立但缺少配置的候选只报告为配置缺口，不列为合法边。
- [ ] 报告稳定排序的合法边、失败断点和原因，并明确 timing-valid；只有调用方提供站位、碰撞盒、hitbox、垂直轨迹和面向时才附加 spatial-valid。
- [ ] 空中路线区分有限滞空/落地资源与真实循环；空中段不能自动续期，只有逐圈状态快照可重现的有效回边才报告为循环。
- [ ] 报告声明不搜索走位、中立、墙角、推挤、跨身或屏幕边界；无空间数据时固定接触位不构成空间证明，Solver 不修改运行时战斗状态。
