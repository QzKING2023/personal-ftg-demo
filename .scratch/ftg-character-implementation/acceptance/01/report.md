# 票据 01 验收记录：普通地面链与起手修正基线

日期：2026-09-24。票据：`issues/01-ground-chain-and-starter.md`（阶段 3 第 1 票）。
参数版本：frame-data.md v0.3（TUNING_INITIAL）。

## 交付内容

- **资源 schema**：MoveData 新增 `starter_grade`（A–D，打击招式必填）、`chain_cancel_targets`/`chain_cancel_window_frames`（0–3）、`special_cancel_targets`/`special_cancel_window_frames`（0–5）、`link_targets`（普通连接边）；MoveTable 校验缺省/矛盾组合/跨招式引用，收尾矛盾扩展到新列表；`_fresh_copy` 覆盖新数组。
- **资源迁移**：5A/5B/5C/5D 按 TUNING_INITIAL 重画（帧数 5/4/10、6/5/12、8/5/16、7/4/18；伤害 8/12/16/18；命中框 30×24/42×28/48×32/62×26；mid 属性；grade A/B/C/D）。5C 由 LAUNCH 迁为 GROUND_HITSTUN（14 帧）并移除 jump cancel；5D 不再是收尾、无任何取消/连接出边。6A/236C/jA/jB/jD/214D 补占位 grade 保持 manifest 可加载。
- **CombatSession**：首次实际 HIT 锁定 starter grade 并以 starter 三层倍率初始化 damage/time/trajectory 修正，后续每击乘普通命中倍率；输出分层舍入（伤害 round0.1 + 10% 底线、时间 floor 夹最小 1、轨迹 round）；被防/挥空不锁定不累计；连段结束清除。三类取消窗口分离（链式 0–3、必杀 0–5、命中确认 0–8），本票接触来源只有命中（被防路径属票据 03）。普通连接机制：前招 recovery 中可提前缓存，完全恢复当帧按合法接续消费或报告 LINK_FAILED（TARGET_RECOVERED / STATE_INCOMPATIBLE / DISTANCE_INSUFFICIENT / CONFIGURATION_GAP）；事件、可观察量、debug_snapshot 与 settlement_state（修正层入循环去重键）同步。
- **训练场**：HUD 显示起手等级、三层修正与最近一次连接失败原因。
- **Solver**：新增链式/必杀/普通连接三类边；普通连接边与取消边不同类型、独立报告，时序可行性由真实探针复验（当前调校值下如实报「目押超时」）；缺口枚举覆盖新接缝；SCOPE 同步。三层修正是结算量 → 循环快照永不重现，注入回边循环以受击衰减断链上报而非可证明循环（ADR-0002 无全局上限语义的加强）。

## 自动化证据

- 全量：`acceptance/01/full/summary.json` —— 16 个作业全部退出 0、无脚本错误，共 **1903 PASS**（Windows PowerShell 5.1 因测试预期 stderr 中断官方脚本，后 9 个作业以相同引擎参数补跑，命令与判定口径一致）。
- 回放：`acceptance/01/replay-routes.log` —— 真实起始间距 60 px（身体中心水平）、左右面向分别回放：
  - `5A > 5B > 5C > 5D`：双面向各 4 hit、总伤 32.3、逐击修正层（0.72/0.648/0.5832/0.5249 档）可见，连段由木桩自然受身结束（F69）。
  - `5B > 5D`：双面向各 2 hit、总伤 23.7（B 起手层 0.84/0.756）。
- 正例断言：test_combat_session（`_test_ground_route`、`_test_three_layer_corrections_accumulate`、新增票据用例组）。
- 反例断言：挥空取消（`_test_whiff_does_not_consume_buffer`、诊断绿）、普通 5D 反向接 5B（`_test_normal_5D_has_no_reverse_5B`：3 hit 停止 + CONFIGURATION_GAP）、目标已恢复后缓存（`_test_cancel_window_close_ends_combo`：LINK_FAILED TARGET_RECOVERED）、5C 无 jump cancel（`_test_jump_cancel_5C_into_jA_pursuit` 负例重写）。
- 回归：HitProfile 精确匹配、Hitstop、自然恢复、资源整表拒绝全部保留并通过（test_hit_profiles 105 PASS、test_move_table 155 PASS）。

## 交付边界（如实声明）

- 链式/必杀取消的「被防」接触分支未实现——被防路径与木桩防御请求属票据 03。
- 普通连接边已声明并接通机制与 Solver 报告，但当前 TUNING_INITIAL 下 A/B 起手地面硬直（修正后 9–11 帧）短于前招完全恢复，全部按「目押超时」失败（frame-data v0.3 观察项）；正例路线经链式取消成立，目押正例待后续阶段更长受击场景。
- 5A 命中框远缘 56 px 与 Solver 80 px 空间网格档相邻不相交：5A 起手路线 80 px 如实报空间失败（frame-data v0.3 观察项，调 gap 或接受边界待试玩）。
- D 系真实位移、蓄力与换边属票据 05/06；2A/2B/2C 与 2C 低浮空属票据 02。
