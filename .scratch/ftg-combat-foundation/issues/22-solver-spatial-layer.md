# 22: Solver 时序与空间证明分层

**What to build:** 设计者可在提供站位与碰撞数据时验证固定距离的空间可达性，并清楚区分 timing-valid、spatial-valid 和未验证范围。

**Blocked by:** 20: Solver 完整路线与时序验证

**Status:** ready-for-agent

- [ ] 无空间数据的路线只标记 timing-valid；固定接触位不构成空间证明。
- [ ] 提供面向、身体矩形、hitbox、垂直轨迹和位置后，验证左右镜像的 48px、64px、80px 身体中心距离并附 spatial-valid。
- [ ] 报告明确不搜索走位、中立、墙角、推挤、跨身或屏幕边界。
- [ ] 空间失败说明具体站位或碰撞条件，不能把配置缺口或时序失败标作空间失败。
