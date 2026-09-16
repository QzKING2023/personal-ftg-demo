# 14: Hitstop、输入缓存与命中确认取消

**What to build:** 玩家命中木桩后经历固定 Hitstop，并能在停顿中输入下一招；恢复后的首个正常帧按缓存、命中确认和取消窗口决定是否接续。

**Blocked by:** 11: 共享本地招式资源与非法表拒绝

**Status:** ready-for-human

- [x] 命中帧完成命中和受击应用后冻结后续 8 个物理帧；动作、位置、速度、受击、落地和受身计时冻结，物理帧号递增。
- [x] 停顿中仍记录物理键、方向历史及动作键事件；缓存、方向窗口和取消窗口年龄暂停，恢复首个正常帧才消费。
- [x] 动作键单槽最新覆盖旧输入，年龄 0–5 有效、年龄 6 过期；命中同帧合法输入可在命中后的取消阶段消费。
- [x] 只有实际命中、木桩可追击、目标已配置且取消年龄 0–8 有效时才取消；挥空永不获得资格。
- [x] CombatEvent 和诊断显示 Hitstop 边界、缓存年龄、取消资格与实际消费结果。

## Comments

**2026-09-16 实现验收记录（agent）**

- 会话结算（`combat_session.gd`）：`GameParams.HITSTOP_FRAMES = 8`；命中应用末尾置 `_hitstop_left` 并发出 `HITSTOP_STARTED`（命中帧事件序 = HIT → HITSTOP_STARTED）；冻结帧只跑 `_phase_input`（采样记录方向历史与动作键缓存，最新覆盖）后递减，物理帧号照常递增；恢复首个正常帧先发 `HITSTOP_ENDED` 再走完整管线并在消费阶段消费缓存。新增只读 `hitstop_active()` 供 Solver 探针跳过冻结帧。
- 双时钟：`_frame_index`（物理帧，事件/诊断时间轴）与 `_normal_frame_index`（正常战斗帧时钟，冻结帧不递增）。缓存年龄、方向窗口、取消窗口、方向历史时间戳全部按正常帧时钟计龄；停顿中记录的输入经 `_input_stamp()` 从恢复首个正常帧起算年龄 0（与规格跳跃槽同口径，恢复后拥有完整 0–5 六个正常帧）。
- 取消资格：`_cancel_window_open` 按正常帧年龄 0–8 含两端判定（挥空无 `_move_hit_confirmed` 永不开放）；`_phase_consume_buffer` 的窗口关闭检查同样按正常帧，停顿使关闭帧相应后移 8 物理帧。
- 可观察性：`CombatEvent` 新增 `HITSTOP_STARTED/HITSTOP_ENDED`；`debug_snapshot` 新增 `hitstop_left`、`cancel_age`、`cancel_open`、`buffer_consumed_move_id/frame`（实际消费结果），`buffer_age` 改正常帧口径（冻结中记录的输入显示 0）。训练场诊断行显示 停顿剩余帧 与取消龄。
- Solver 维护（不成为第二套规则）：`_run_schedule`/`_source_timing` 改按正常战斗帧编排——会话冻结时以空输入步过、不消耗计划帧号；输入表、命中帧、等待/年龄、循环周期全部保持正常帧口径（默认表全部数值断言不变：路线 [6,10,15]/[6,12,17,21,25]、周期 27/51 等）；观测上限按物理帧计（含冻结帧）。`_dummy_timing_state` 并入冻结标记。范围声明注明帧号口径与回放方式。
- 既有测试机械性重定时（每次命中后 +8 物理帧；停顿内 Space 无效，jump cancel 移到恢复后正常帧——停顿内 jump 独立缓存属 issue 15）；两处落地临界路线改为全真实输入构造（jA 命中恰在浮空受身边界、jB 命中恰在落地帧）；loop 表测试按 10 物理帧/击的确定性周期重排按键。
- 验证：test_combat_session 401 项全绿（新增冻结/年龄暂停/恢复首帧消费/方向窗口不消耗/取消年龄边界/挥空资格/诊断与消费记录等 ~20 项断言）；test_combo_solver 112 全绿；test_smoke 85 全绿（jump cancel 用例等停顿结束后再按 Space）；test_move_table 129 全绿；diagnose_inputs 全绿；主场景无头 300 帧无错误。
- 范围说明：停顿内 jump 按下、pre-jump、落地恢复锁定等均未提前实现（issue 15+）；数据表未改动（取消窗口 8f 本就是共享资源数值）。
