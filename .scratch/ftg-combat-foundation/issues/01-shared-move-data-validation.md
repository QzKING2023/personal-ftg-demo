# 01: 共享本地招式数据与非法表拒绝

**What to build:** 设计者编辑一份类型化本地招式资源后，训练场与 Combo Solver 使用同一份已校验数据；修改 startup、伤害、属性或取消关系会在两处产生一致的可观察变化，非法招式表会整体拒绝加载并给出可定位的错误。

**Blocked by:** 规格发布门槛：spec.md 中开放问题 1–5 已冻结，并将规格标记为可实施（本目录外部前置条件）。

**Status:** ready-for-human

- [x] 训练场和 Combo Solver 从同一份本地招式资源读取稳定 id、姿态、输入绑定、帧窗口、优先级及招式效果；修改任一代表字段后，两处行为和报告同步变化。
- [x] 打击招式缺少伤害、属性、hitbox、命中结果、受击硬直或击退参数时，整张表拒绝加载；投技缺少投距时同样拒绝。
- [x] 类型错误、负帧数、未知枚举、非法方向谓词、矛盾字段或跨招式非法引用均被拒绝，错误包含资源来源、招式 id、字段和冲突原因。
- [x] 非法表不会静默修正、跳过招式或回退旧 GameParams；训练场与 Solver 都保持拒绝状态并可观察到同一原因。

## Comments

**2026-09-16 实现验收记录（agent）**

- 数据真源：`data/moves/*.tres`（9 招，每招一份类型化 `MoveData`，冻结首版数值）+ `data/move_manifest.tres`（统一引用，清单顺序即枚举顺序）。稳定 id 是资源字段 `move_id`，不由文件名推断。
- 校验：`scripts/combat/move_table.gd` 的 `MoveTable.load_manifest`/`validate` 整表校验——打击缺 伤害/属性/hitbox/命中结果/受击硬直/击退/输入绑定、投技缺投距或 startup≠5、负帧数、未知枚举 int、非法方向谓词记法（含中立 5/末位键与绑定不符）、矛盾组合（收尾声明取消、空中声明 jump cancel、地面声明落地接续、打击声明投距、投技声明单键/派生）、重复 id、取消/jump/落地目标悬空引用、同姿态+同绑定+同派生+同替代串+同优先级并列。核心字段缺省值一律为"未声明"哨兵（0/-1/UNSET），手改 .tres 删行可检出。错误格式 `[资源来源] id: 字段 — 原因`。
- 双端接入：`CombatSession.new()`/`ComboSolver.analyze()` 默认经 `MoveTable` 加载共享 manifest（不再回退代码内建 GameParams 表）；`main.gd` 加载失败时 session=null、训练场拒绝运行并在提示区显示拒绝原因；`ComboSolver.analyze_manifest` 返回 refused 报告（refusal_reason 与 MoveTable 首条错误完全一致，不产出任何边/路线/循环结论）。诊断行与 `debug_snapshot` 新增当前招式属性；Solver 报告新增"共享招式表"摘要行（属性编辑可直接在报告中核对）。
- 运行时解析改按数据声明绑定：`_resolve_action`/`_match_direction_derivation`/Solver `_start_key_for` 不再用 id 命名约定（"5X"/"jX"/派生末位），同绑定并列按 priority（校验已拒绝合法表的并列）；投技不走单键/取消链解析（行为留给 issue 06）。
- 验证：tests/test_move_table.gd（新增，~90 项断言：加载/校验/手改 .tres/文件级类型错误/清单错误/无回退/startup·伤害·属性·取消四组双端同步/Solver 拒绝同因）；test_combat_session（277）全绿（12 处程序内探针构造迁移为字段齐全的 `_probe_move`，断言原样保留）；test_combo_solver（112）全绿（注入招式同法迁移 `_injected_move`）；test_smoke 全绿（新增共享 manifest 接入 + 训练场拒绝状态两用例，后者断言训练场/MoveTable/Solver 三处同一原因）；diagnose_inputs 维持既有 5 个红色项（地面面向规则，属 issue 02，未新增红项）；主场景无头运行 300 帧无错误。
- 范围说明：投技仅有 schema+校验（投距、startup 5f 领域规则），投技执行/拆投是 issue 06；`input_alternatives` 仅声明与记法校验，指令分层与替代串匹配是 issue 02；默认表攻击属性全部取 high、空中招式 air=true（规格未冻结逐招属性，防御矩阵在 issue 05）。
- 已知限制：资源缓存按路径驻留——运行中修复 .tres 后需重新运行项目（拒绝文案已注明，R 仅重载场景）；`GameParams` 的 `MOVE_*` 常量保留为测试断言基线，运行时不读取。
