# 连段工作流进度

2026-10-05：只完成阶段 1，停止于阶段 2 设计入口。

- [x] 基线 `53a6c2f72d49757d915ef2659d98751563a4a7b6`；保留既有未跟踪 docs/combo-route-workflow.md，不纳入本次提交。
- [x] 读取原规格、领域规则、ADR和阶段9证据；原验收复跑，实际调用回归先红后绿。
- [x] 首次COMBO_ENDED永久截断首段连段；后续HIT单列，同帧按真实顺序；招式与判定段hit分开。
- [x] 10套固定输入×双面向，真实运动/碰撞/墙界；两次20/20 traces SHA256相同。
- [x] 完整路线、穿越和连接最小复现、早/有效/晚缓存对照、弹地四击及候选5C分支。
- [x] 工具10 PASS；联合回放103 PASS/2已知FAIL；症状计划13 PASS/24 FAIL（多个对照）。最终脚本错误0，不掩盖红灯。
- [x] 撤回J3b三击、按住余量足够和弹地5C只差两帧等结论，保留历史日志。
- [x] 阶段2设计问题已列入baseline，没有擅定5B之后路线，没有修改正式数值或规则。
- [x] 一次性 scan_air.gd 已删除；80份逐帧证据压缩前后逐字节核验，四条主要右面向日志另保留原文。git diff --check通过；正式scripts/data无差异。

入口：[baseline.md](baseline.md)、[固定输入](inputs.json)、[最终运行](runs/verify-02/summary.json)、[重复运行](runs/verify-03/summary.json)、[确定性](runs/determinism.json)。

验收修正提交：`1bf00d587b90a2d0740eab0a651c8bb2d8283a7e`（fix(acceptance): separate post-combo hits and capture route baselines）。本条由其后的纯文档提交回填。没有正式实施提交，阶段6开始前须另记正式实施基线。

提交后工作树只剩用户原有未跟踪 docs/combo-route-workflow.md；本阶段没有推送远端。历史验收日志未改动。最终提交记录可运行 `git log -2 --oneline` 核对。

下一步仅建议阶段2：先由用户决定保准确顺序还是角色体验，再展开路线终点、换边条件、招式职责及容错目标。不能自动开始调参。
