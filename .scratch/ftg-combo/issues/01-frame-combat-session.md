# 01: 单招式逐帧结算与训练场接入

**What to build:** 玩家在训练场中发起一次基础招式时，战斗会话按物理帧完成输入、前摇、命中、受击和恢复，玩家可以重复攻击并通过重置恢复初始状态。

**Blocked by:** None (can start immediately).

**Status:** ready-for-human

- [x] 集中战斗结算以逐物理帧输入产生可观察的玩家状态、木桩状态和战斗事件，并保持输入 → 命中 → 受击应用 → 运动/落地/自然受身 → 取消 → 消费缓存的顺序。
- [x] 基础招式具有可配置的 startup、active、recovery 和基础伤害；同一次攻击对同一木桩最多命中一次。
- [x] 训练场仍支持移动、跳跃、碰撞和重置；一次命中会更新木桩生命值、受击反馈和状态显示。
- [x] 自动化测试通过逐帧输入验证一次命中、受击恢复、场景重置和现有移动行为。

## Comments

**2026-09-12 实现完成（agent）：**

- 新增确定性战斗会话 seam：`scripts/combat/combat_session.gd`（`step(FrameInput)` 按固定管线结算并返回 `CombatEvent`），配套 `frame_input.gd`、`move_data.gd`（可配置 startup/active/recovery/伤害/命中框/击退/硬直）、`combat_event.gd`。取消判定与消费缓存两个阶段为管线占位，留给 issue 02。
- 训练场改为呈现层：`main.gd` 每物理帧做输入适配并驱动会话，`player.gd`/`dummy.gd` 只同步位置/朝向/命中框/血条/闪白；右上角新增木桩生命值与受击状态显示。地面/墙体/身体碰撞改由会话按几何结算，不再依赖物理服务器。
- 招式窗口从秒改为物理帧（默认 startup 5 / active 7 / recovery 13 / 硬直 12，60fps），数值仍集中在 `GameParams`。
- 测试：`tests/test_combat_session.gd`（66 项，逐帧输入驱动会话 seam：一次命中、命中帧边界、可配置窗口与伤害、受击恢复、命中先于运动的同帧顺序、移动/跳跃/墙体/身体阻挡/重复攻击/血量下限）+ `tests/test_smoke.gd`（28 项，注入输入 + 真实物理帧：移动/跳跃/边界/命中反馈/状态显示/重置）。全部通过。
- 已知边界：脚本注入的 `Input.action_press` 比 `is_action_just_pressed` 晚一帧被消费（仅影响测试节奏，真实按键无此问题，集成测试用轮询规避）；玩家不能再站上木桩头顶（会话只做水平推挤，行为与原物理落地略有差异）。
- 待人工试玩确认参数手感（5/7/13 帧窗口、12 帧硬直、击退距离），试玩后可直接改 `MoveData`/`GameParams`。
