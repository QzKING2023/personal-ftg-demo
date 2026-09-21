# 上下文命中资料垂直切片

Status: ready-for-human  
Type: task  
Parent: .scratch/ftg-move-design/spec.md

## What to build

沿正式规格接通第一条端到端的上下文命中资料路径：把 MoveData 的旧命中字段迁移到内嵌 HitProfile[]，为 5A、6A、214D 配置 grounded normal/counter 样例，并让运行时、MoveTable、Combo Solver 和验收测试共同使用 target_state → hit_context 的精确匹配。切片完成后，普通地面硬直、浮空受击、普通倒地和 Counter Hit 的触发/消耗/结束都能由同一份已校验招式表驱动。

## Acceptance criteria

- [ ] HitProfile 类型和 MoveData.hit_profiles 可加载；字段默认值、单位、枚举和 reaction 组合符合正式规格。
- [ ] 5A 至少有 grounded normal/counter，普通命中保持接地，缺失 airborne profile 时运行时与 Solver 都拒绝而不回退。
- [ ] 6A 至少有 grounded normal/counter LAUNCH，地面命中进入浮空受击并保留已配置的命中确认/jump cancel 边界；airborne profile 若未声明则明确未匹配。
- [ ] 214D 至少有 grounded normal/counter GROUND_KNOCKDOWN；命中结束连段，倒地期间不可命中，计时结束才恢复。
- [ ] GROUND_HITSTUN、LAUNCH、GROUND_KNOCKDOWN 的非法 target/timer/speed 组合、重复键、Counter 无 normal、未知枚举和未支持效果会使整张 MoveTable 拒绝。
- [ ] Counter Hit 只在目标 startup/recovery 窗口触发，active 不触发；命中后立即消耗，窗口结束未命中则清除，下一次命中按 normal。
- [ ] hit_result、hitstun_frames、knockback、knockback_up 已从资源 schema、默认招式、运行时和 Solver fixture 迁移；不使用 GameParams 或旧字段回退。
- [ ] CombatSession 与 Combo Solver 共享同一份已校验 profile 选择和状态计时语义；修改 profile 数据能在两端产生一致的伤害、状态、速度和报告变化。
- [ ] 自动化测试覆盖四组验收样例、精确匹配无回退、倒地边界、Counter 生命周期、资源拒绝和既有 Hitstop/落地恢复/自然受身回归。

## Blocked by

None - can start immediately after reading the formal specification. D 轮最终数值调校和 OTG、地弹、墙反弹、招式无敌不属于本切片。

## Comments

2026-09-21 实现完成（agent），全量测试套件（13 个测试文件 + diagnose_inputs + 训练场 smoke）通过。

- 新增 `scripts/combat/hit_profile.gd`（TargetState/HitContext/Reaction 枚举与计时/速度字段，负数默认为未声明哨兵）；`MoveData` 删除 `hit_result`/`hitstun_frames`/`knockback`/`knockback_up`，新增内嵌 `hit_profiles: Array[HitProfile]` 与共享精确匹配 `MoveData.profile_for`。
- `MoveTable` 校验 §3 全部非法组合（reaction×目标×计时×速度、重复键、counter 依赖同状态 normal、投技不得声明、未知枚举、负值），`_fresh_copy` 深复制 profile。
- 运行时按「目标状态 → 命中上下文」精确选择；缺失 profile 发 `HIT_MISS` 事件（不回退、无伤害/状态/确认/停顿）；三种 reaction 独立计时，`KNOCKED_DOWN` 不可命中、进入即结束连段（KNOCKDOWN 结束原因）、计时结束自然恢复；HIT 事件携带 `is_counter`；木桩攻击玩家走同一选择器。
- 新增 `data/moves/6A.tres`（6+A 专用击飞入口，grounded normal/counter LAUNCH，jump cancel jA；5A→6A 取消边）并进入 manifest；214D 迁移为 GROUND_KNOCKDOWN（normal 30 / counter 40）。
- Solver：MISS_NO_PROFILE 断链分类（与挥空/窗口关闭三分）、倒地不可追击断链注记、KNOCKDOWN 结束原因与路线注记、scope 声明 profile 共享选择与未支持效果边界。
- 新增 `tests/test_hit_profiles.gd`（spec §6 样例 A–D、§3 校验矩阵、§4 无回退、counter 生命周期、双端 profile 编辑同步）；既有 fixture 全部迁移。

实现中的裁量决定（供人工验收复核）：

1. jA/jB/jD 除迁移旧普通命中为 grounded normal 外，同时声明 airborne normal LAUNCH profile（airborne 目标唯一合法 reaction 是 LAUNCH；不声明则全部空中追击 MISS，与切片目标相悖）。垂直速度暂定 40 px/s，D 轮调校。
2. 玩家侧（木桩攻击玩家）复用同一 profile 选择器：guard stun / hitstun 取所选 profile 的反应计时，玩家无浮空/倒地受击（不在本切片），防御硬直映射仍属 docs/move-data.md 的「待规则确认」。
3. 普通投在木桩普通倒地期间被 STATE 门拒绝（投结果会改写独立倒地计时；OTG 不在本轮）。
4. 样例 B.3 的「被防不取得 jump cancel」在本切片不可测：木桩从不防御，无法构造玩家攻击被防场景；挥空与缺 profile 两径已覆盖。
5. 倒地期间的打击按既有不可追击语义静默不命中（可断言口径 = KNOCKDOWN/DUMMY_RECOVERED 事件 + 无 HIT 事件），不发 HIT_MISS。
6. 6A 帧数/伤害（8/6/20、16）与各 counter 变体数值为暂定样例，D 轮最终调校。
