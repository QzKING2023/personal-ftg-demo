# 20: Solver 完整路线与时序验证

**What to build:** Combo Solver 用一次性 CombatSession 逐帧验证方向派生、取消、jump cancel 和落地接续，输出合法路线、配置缺口和失败原因。

**Blocked by:** 13: 宽松指令、替代串与输入优先级; 15: 普通跳、jump cancel 与落地恢复; 19: Combo Solver 入口与操作说明

**Status:** ready-for-agent

- [ ] 枚举姿态、输入绑定、方向 variant、取消窗口、jump cancel、落地接续和等待帧，并验证前摇、命中、硬直、运动、落地及自然受身。
- [ ] cancel_targets、jump_cancel_targets 和 landing-cancel 目标是运行时硬约束；时序成立但缺配置只报告配置缺口。
- [ ] 报告稳定排序的合法边、逐帧输入、命中数据和失败断点；挥空、受身和恢复原因可区分。
- [ ] Solver 不修改运行时状态，也不以命中数或时长上限掩盖无效路线。
