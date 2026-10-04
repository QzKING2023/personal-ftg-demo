# 叶登记工作量复核

Status: resolved
Labels: ready-for-agent

调查旧默认表探针所报 steps/leaves/spatial_rechecks 2×，纠正测量或实现，独立请求两侧指纹相同、工作量不增加。记录 compiled scope 对跨路线共享的影响。

## Comments

2026-10-04：从交接接手；先核验内部 _analyze 与请求级计数重置的契约。

## Answer

2× 来自旧探针连续调用内部 `_analyze` 后读取累计 profile；该内部阶段不负责重置请求计数，`solve()` 才建立请求边界。修正探针在每次独立分析前调用 `_profile_v2_reset()` 后，两侧报告指纹相同，`session_steps=330247`、`spatial_rechecks=21`、`delay_dfs_leaves=7903` 完全相同，工作量没有增加。无需修改叶登记实现；compiled scope 仍按既有契约保留。
