# 05: 条件票——边探测/路线重放的前缀共享(调度记忆化)

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 03, 04

## What to build

**条件票**:仅当 03 的 profile 证明延迟叶子以外的重放点(边探测 + 路线行进 + 缺口枚举)合计占唯一请求耗时大头时才实施;用 04 已验证的同一套前缀快照/恢复机制扩展到那些调用点,不发明新机制。不满足触发判据则本票关闭为 wontfix 并记录数据。

## User stories covered

13。

## Acceptance criteria

- [ ] 触发判据(先做):03 profile 报告显示延迟叶子以外重放点合计 >50% 唯一请求耗时 → 实施;否则本票标 wontfix,Comments 记录判定数据,不得"顺手做"。
- [ ] (若触发)每个扩展点独立差分门:同型逐调用点 harness + 定向 test job 与 02 基线 fingerprint 相等。
- [ ] (若触发)语义冻结清单与 04 相同:枚举顺序、budget、首条成立即返回、失败排序全部不动。
- [ ] (若触发)扩展点前后耗时对比记录在案。

## Blocked by

- 03
- 04
