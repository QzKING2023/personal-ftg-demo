# 以目标状态与命中上下文选择命中资料

状态：accepted

## 背景

同一招命中地面目标、空中目标或 Counter Hit 目标时，速度、硬直、受身和反应可能不同。将这些差异写成 `ground_*`、`air_*`、`counter_*` 平行字段会让字段数量增长、组合关系不明确，也会把缺失资料的处理交给资源顺序或运行时猜测。普通命中、浮空和普通倒地还需要不同的计时语义。

## 决策

保留 `MoveData` 作为招式身份、输入、时间窗口、攻击属性、命中框、取消规则和公共伤害的资源；命中结果由内嵌的类型化 `HitProfile[]` 承载。每个 profile 以 `target_state × hit_context` 为唯一键，运行时先按目标状态、再按命中上下文做精确匹配，缺失不回退，重复键或非法组合使整张 `MoveTable` 拒绝。

首版实现 grounded/airborne 目标、normal/counter 命中上下文、浮空受击和普通倒地；地面硬直、空中受身、倒地恢复使用独立计时。普通地面命中保持接地，只有 launch 设置向上速度。Counter Hit 只影响当前命中。OTG、地弹、墙反弹和招式无敌只保留未来扩展边界，不由标签或未支持字段伪装实现。

## 后果

- 每个招式需要显式维护它支持的目标状态与命中上下文组合；不再依赖文件顺序或隐式默认 profile。
- `MoveTable`、`CombatSession` 和 Combo Solver 必须共享同一套 profile 选择与非法组合校验。
- 旧的单一 `hit_result`、`hitstun_frames`、`knockback`/`knockback_up` 不能直接表达新语义，迁移时需要把结果、计时和速度移动到 profile；旧资源不能静默解释为新字段。
- 数值调校和具体招式路线留在后续 D 轮；本 ADR 只固定数据语义和首版效果边界。
