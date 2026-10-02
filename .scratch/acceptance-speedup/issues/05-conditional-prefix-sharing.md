# 05: 条件票——边探测/路线重放的前缀共享(调度记忆化)

Status: wontfix(2026-10-02:触发判据不成立,延迟叶子以外重放点合计 2.6% ≪ 50%,判定数据见 Comments)
Parent: [spec.md](../spec.md)
Blocked by: 03, 04

## What to build

**条件票**:仅当 03 的 profile 证明延迟叶子以外的重放点(边探测 + 路线行进 + 缺口枚举)合计占唯一请求耗时大头时才实施;用 04 已验证的同一套前缀快照/恢复机制扩展到那些调用点,不发明新机制。不满足触发判据则本票关闭为 wontfix 并记录数据。

## User stories covered

13。

## Acceptance criteria

- [x] 触发判据(先做):03 profile 报告显示延迟叶子以外重放点合计 >50% 唯一请求耗时 → 实施;否则本票标 wontfix,Comments 记录判定数据,不得"顺手做"。(2026-10-02 判定:合计 2.6% ≪ 50% → wontfix)
- [ ] (若触发)每个扩展点独立差分门:同型逐调用点 harness + 定向 test job 与 02 基线 fingerprint 相等。——N/A(未触发)
- [ ] (若触发)语义冻结清单与 04 相同:枚举顺序、budget、首条成立即返回、失败排序全部不动。——N/A(未触发)
- [ ] (若触发)扩展点前后耗时对比记录在案。——N/A(未触发)

## Blocked by

- 03
- 04

## Comments

### 触发判定(2026-10-02,wontfix 依据)

判据:延迟叶子以外重放点(边探测 + 路线行进 + 缺口枚举)合计 >50% 唯一请求耗时才实施。判定数据全部来自 03 归档([profile-report.md](../profile-03/profile-report.md)、[profile-jobs.md](../profile-03/profile-jobs.md))与 04 的前后 profile([04 AC#6](04-delay-dfs-prefix-restore.md))。

**03 口径(插桩落地当日,2026-09-30)**:

- solve-default(双面向,71 边 / 1753 路线):delay_leaf 1,138,955ms(97.4%);route_walk 2.1% + gap_enum 0.3% + edge_probe 0.2% + other 0.0% → 延迟叶子以外合计 **2.6%**。
- analyze-default(单面向):delay_leaf 97.3%,非延迟叶子合计 2.7%。
- 逐请求:test_combo_solver 26 个重请求、test_solver_route 8 个重请求,每个 delay_leaf 占比均 97%(最重单请求 1,059s / 351,196 叶,97% 在 delay_leaf)。
- 桶合计(全部输入日志):delay_leaf 19,799,653ms、route_walk 404,558ms、gap_enum 74,200ms、edge_probe 47,441ms、other 3,499ms——延迟叶子以外重放点 529,698ms / 20,329,351ms = **2.6% ≪ 50%**。

**04 落地后复核(残余大头未转移到本票扩展点)**:

- 04 AC#6 profile(restore 路径):solve-default 墙钟 535s 中 delay_leaf 512s(95.7%);analyze-default 264s 中 253s(95.8%)。delay_leaf 被 04 减半后,非延迟叶子份额仅从 2.6% 升至 ≈4.3%(分母缩小所致)——剩余大头仍是 delay_leaf 的尾部重放,不在边探测/路线行进/缺口枚举。
- 各扩展点绝对量级(03 桶合计):edge_probe 0.23%、gap_enum 0.36%、route_walk 2.0%——即使全部归零也不改量级,与 03 报告"票据 05 触发条件未成立"的决策结论一致。

**结论**:触发判据不成立,本票关闭为 wontfix;条件性 AC#2-#4 全部 N/A;未写任何生产代码、未动 Solver。后续路径(03 报告与 04 Comments 均已预告):若 06/08 落地后全量仍不达 ≤1h,追加票方向是 `_delay_dfs` 逐深度嵌套前缀(压 delay_leaf 剩余尾部重放),而非本票的调度记忆化扩展点——届时开新条件票,不复用本票。
