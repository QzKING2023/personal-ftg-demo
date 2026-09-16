# 16: 蹲下与站防、蹲防、空防

**What to build:** 玩家用相对方向进入蹲下、站防、蹲防和空防，并用木桩确定性攻击观察 high/mid/low/overhead/air 属性矩阵及各阶段限制。

**Blocked by:** 15: 普通跳、jump cancel 与落地恢复

**Status:** ready-for-agent

- [ ] 地面自由行动时 1/2/3 当帧进入蹲下并保留水平分量；受限阶段不会被下方向强行改姿态。
- [ ] 地面 4 为站防、1 为蹲防；真正离地后 4/1 均为空防，pre-jump 不新进入防御。
- [ ] high、mid、low、overhead 与正交 air 属性按显式数据判定；空防默认可挡 air。
- [ ] 防御硬直、Hitstop 和木桩反馈可重复观察；落地首帧不可防御，空跳第 2、3 帧可防御，空技恢复全程不可防御。
