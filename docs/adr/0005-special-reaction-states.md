# 扩展受击资料以承载特殊追击状态

状态：accepted（阶段 1 设计决定，尚未实现）

在保留 ADR-0003 的 `target_state × hit_context` 精确匹配和缺失即无命中的前提下，角色基线扩展受击结果以承载 `GROUND_SLIDE`、`LOW_FLOAT_SWEEP`、`LOW_FLOAT_TO_SLIDE`、`GROUND_BOUNCE` 和空中向下击落等特殊流程。特殊状态必须由显式 profile 进入、拥有独立计时／运动／恢复事件；状态转换不通过字符串标签回退，也不把 `GROUND_SLIDE` 或 `GROUND_BOUNCE` 解释成普通倒地 OTG。

`236C` 的两段判定分别结算：第一段实际命中可产生普通浮空，第二段被防时整招终止、实际命中 grounded 时进入击飞到 slide、命中 airborne 时使用独立空中资料；两段实际命中各自可取得进入普通 `5D/5[D]` 的特殊取消资格。`j214D` 命中 grounded 或 airborne 都进入 `GROUND_BOUNCE`，但不自动刷新空中资源；普通 `2C` 低浮空触地转 `GROUND_KNOCKDOWN`。运行时与 Solver 共享这些状态和精确匹配口径。
