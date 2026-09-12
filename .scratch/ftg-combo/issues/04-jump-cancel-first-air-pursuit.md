# 04: jump cancel 与首次空中追击

**What to build:** 命中配置允许 jump cancel 的地面招式后，玩家可以使用 Space 转入空中并接上 jA，同时不会获得二段跳或无限刷新滞空资源。

**Blocked by:** 03: 方向派生招式与浮空受身.

**Status:** ready-for-agent

- [ ] C/236C 只有在命中确认且招式配置允许时才能被 Space jump cancel；未配置招式的 Space 不产生连段追击资格。
- [ ] Space 独立于动作键缓存，不会被缓存、消费或覆盖动作键输入。
- [ ] jump cancel 后可按指定语义从 jA 开始空中追击；空中不能二段跳，后续追击不能刷新木桩滞空资源。
- [ ] 默认玩家跳跃持续 40 个物理帧、木桩浮空滞空 48 个物理帧，参数可调且状态反馈可观察。
- [ ] 测试覆盖命中/挥空 jump cancel、Space 独立性、jA 起手、二段跳禁止和有限滞空资源。
