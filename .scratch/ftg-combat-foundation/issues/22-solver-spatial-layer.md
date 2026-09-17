# 22: Solver 时序与空间证明分层

**What to build:** 设计者可在提供站位与碰撞数据时验证固定距离的空间可达性，并清楚区分 timing-valid、spatial-valid 和未验证范围。

**Blocked by:** 20: Solver 完整路线与时序验证

**Status:** ready-for-human

- [x] 无空间数据的路线只标记 timing-valid；固定接触位不构成空间证明。
- [x] 提供面向、身体矩形、hitbox、垂直轨迹和位置后，验证左右镜像的 48px、64px、80px 身体中心距离并附 spatial-valid。
- [x] 报告明确不搜索走位、中立、墙角、推挤、跨身或屏幕边界。
- [x] 空间失败说明具体站位或碰撞条件，不能把配置缺口或时序失败标作空间失败。

## Comments

**2026-09-17 实现验收记录（agent）**——改动集中于 `scripts/combat/combo_solver.gd`（SolverSpatialData + 路线分层字段 + 空间复验 + 报告空间分层节 + 镜像签名扩展），新增 `tests/test_solver_spatial.gd`（146 项断言）。

- 空间数据输入映射（issue 措辞「面向、身体矩形、hitbox、垂直轨迹和位置」在首版各就其位）：面向＝`SolverOptions.facings`（默认 [1,-1] 左右镜像，issue 19 既有字段）；身体矩形＝`SolverSpatialData.body_size`（必须等于运行时 `GameParams.BODY_SIZE`，不一致即拒绝分析——空间复验在真实 CombatSession 中进行，不维护第二套碰撞物理）；hitbox＝共享招式表的 `hitbox_size/hitbox_gap` 声明（调用方已提供的表即命中框来源）；垂直轨迹＝首版固定地面站位（双方站地；空中段的玩家弧线与木桩浮空由真实结算携带，不作空间假设），显式空中起始 + 空间数据直接拒绝并说明「首版只验证地面站位」；位置＝规格冻结的三组身体中心水平距离 `SPATIAL_PROBE_DISTANCES = [48, 64, 80]`（48＝身体贴身、64＝首版投距上限、80＝更远一档），不搜索其余站位。调用方未消费逐帧自定义站位（首版网格是规格冻结值，Out of Scope 的走位/中立/墙角/推挤/跨身/屏幕边界搜索均未实现）。
- 分层模型：`SolverRoute.timing_valid`（接续链在固定接触位 70 px 的真实结算中逐帧成立——把既有隐式状态显式化）+ `SpatialState { UNVERIFIED, VALID, INVALID }` + `spatial_failures`（每组失败站位一条）。空间复验 `_verify_routes_spatial` 对每条 timing-valid 路线换入 48/64/80 px 钉位重跑与 timing 层完全相同的 `_route_run`（自 `_simulate_route` 抽出的共用入口：入口上下文 + 逐边接续链 + 空中延迟搜索）——命中框 × 身体矩形的相交由真实结算判定，两层结论出自同一套帧物理；timing 未成立的路线不作空间复验（时序失败不标作空间失败）。spatial-valid 语义＝存在一组空中延迟使整条链在该站位接通（与 timing 层同一搜索口径），已在空间分层节言明「不要求与操作说明的样本帧表逐帧相同」。
- 多面向合并与镜像：每个面向的 `_analyze` 独立完成本面向的空间复验；`_merge_route_spatial` 合并——spatial-valid 须全部验证面向成立，任一面向失败即 INVALID 且失败按站位取并集（镜像对称时去重不重复罗列；镜像被打破时把每个面向的失败站位都收进列表不漏报）；路线镜像签名（`_signature_sections`）扩展携带 spatial_state 与失败明细，面向相关的空间差异会打破镜像对拍。
- 失败语义：挥空（已起手但命中框未与木桩身体矩形相交）被空间层解读为「站位太远、碰撞条件不成立」并点名招式序号与站位（如「80 px：第 2 招（5R）已起手但命中框未与木桩身体矩形相交（碰撞条件不成立）」）；其余断链如实附原始原因不伪装成碰撞 miss。配置缺口集合与措辞在提供空间数据前后逐条一致（专项对拍测试）；挥空/晚于恢复的边排除理由保持时序措辞、不含空间措辞；被排除招式不出现在任何空间失败里。
- 报告输出：`to_lines` 的可读路线行追加分层标签（timing-valid；spatial-valid / 空间未验证 / 空间失败 / timing 未成立）；新增「空间分层」节——未提供数据时声明「全部路线仅 timing-valid，固定接触位不构成空间证明」（solve() 与旧入口 analyze() 兜底共用 `_no_spatial_lines` 同一文案），提供数据时报告站位网格、spatial-valid/失败/未验证计数、逐路线失败明细、循环保持 timing-valid 的边界与「操作说明帧表按 70 px 编排，不外推其余站位」；节尾固定输出「不搜索走位、中立、墙角、推挤、跨身或屏幕边界；配置缺口与时序失败不作空间失败上报」（SCOPE_TEXT 同步补充分层声明）。
- 拒绝语义：身体矩形与运行时不一致、空中起始配地面网格 → 拒绝分析（`_refused_spatial`，summary/refusal_reason/refusal_advice 齐备），拒绝报告不产出任何路线/边/循环/候选。
- 性能：默认表 plain solve ~1.9s，spatial solve（双面向 × 三档 × 9 条路线复验）~5.9s；test_solver_spatial 全文件约 3 分钟内（含多次完整 solve）。
- 范围说明：空间分层只覆盖可读路线（边与循环保持 timing 层，报告已言明）；`_route_layer_tag` 对 timing 未成立路线的标签「timing 未成立；空间不作验证」在当前走法下实际不可达（路线只走逐边验证过的合法边，默认表无断链路线），作为语义完备性保留；issue 23 的回放联合验收未提前实现。
- 验证：新增 tests/test_solver_spatial.gd（无数据仅 timing-valid、网格三档双面向 spatial-valid、短 reach 注入的空间失败点名 80 px 与碰撞条件且不改判 timing、缺口与时序排除不作空间失败、身体矩形不一致拒绝、空中起始拒绝、不搜索范围声明、确定性与运行时隔离）；test_combat_session（632）、test_move_table（134）、test_smoke（111）、test_combo_solver（111）、test_solver_entry（49）、test_solver_route（95）、test_solver_cycles（35）、diagnose_inputs 全绿；主场景无头 300 帧无错误。
