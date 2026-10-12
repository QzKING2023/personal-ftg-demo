# E02 交接（2026-10-07）：弹地追击之后如何到达明确终点

分支 `codex/combo-route-prototype-e02-20261007` @ `d5cf77c`（工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e02-20261007/ftgdemo`，自 cf0ada1/e16 谱系切出）。轮材料全文：`.scratch/ftg-combo-routes/round-materials/e02-20261007.md`。未编辑共享账本；未触碰设计树用户未提交改动；正式树资源保持基线。

## 一句话结论

- **入口 G（6A 对地首击侧）**：可达明确终点。参考链 `6A>t1 → jC>22 → j214D>32 → 5B>71 → 214C>91 → ~C>109`，命中表 `9/32/49/82/102/120`，**f129 KNOCKED_DOWN**，单结束、无晚命中、零换边；三尺度物理帧表与全部窗口完全一致、双向一致。
- **入口 L（版中完整 6D 长前缀）**：结构性撞墙。声明的 5B→6D 边作为数据生效（6D 确实出招），但 6D 仅 AIRBORNE 档案而接缝时点目标必已落地（GROUND_HITSTUN）：264 个扫描点（b0[101,103]×d6 全窗×3 尺度×双向）零连接。**需阶段 2 裁决**（给 6D 补地面档案=新变量族，或重设计接缝时序）。

## 关键数字（详见轮材料）

- 入口 G 接缝窗：入口 L 的 b0∈[101,103]（独立复现 E11）。
- 单键区间（gnd，ref 锚 jump11/C22/D32/B71/k214 91/~C109）：t[1,1] / jump[4,18]（15F 输入缓冲容差，过 D15 门）/ C[22,22] / D[27,32]（只早不晚）/ B[71,73]（3F 弹地追击窗）/ k214[77,92] / ~C[103,119]（过门）。
- D16 联合：38/256 完整到击倒（门 ≥244 未过）——紧输入路线，失败集中于 jump→C（91）、j214D→5B 追击（115）、5B→214C（12）。
- 探针：间距 ≤31 全过、40 距离失败；x264/696+版边全过；guard2/whiff/零输入/迟 B/整体平移 +1+2 等 witness 全部在案；可选 5C 两侧均无资格；无边对照 prefix 恰停 6（6D 未出招）。
- 击倒后距离：base 66.7 / q-v 30.7 / t26-v 34.7 px，玩家朝向不变。

## 门槛记录

隔离门 6/6 PASS；每次运行 data/**/*.tres 逐字节不变、0 脚本错误、E02 COMPLETE 在案；diag-before/after 的 20 份路线 trace 与引擎日志逐字节相同（控制台捕获仅空行交错差异，归一化后相同）；play.tscn 冒烟 exit 0。已知失败基线（replay10 2 FAIL、symptoms 24 FAIL）两侧一致。

## 证据与复现

- 结论级：工作树 `prototype_e02/evidence/`（isolation/analysis/baseline-traces/diag×2/manifests，已提交）。
- 原始：工作树 `.scratch/ftg-combo-routes/runs/e02-round/{c1,c2,c2b,c3,main,joint}`、`e02-diag-{before,after}`、`e02-play-smoke`。
- 复现命令与试玩入口：工作树 `prototype_e02/README.md`。

## 待试玩（无人工证据 = 待试玩）

入口 G 参考链三处紧交界（C 1F、B 3F、D 非对称）的人手可行性；jump 15F 缓冲的体感；~C 17F 窗体感；击倒后距离能否接下一轮。入口：`play.tscn`（F3 镜像/F7 重置，U/I/K/J=A/B/C/D，Space 跳，G 格挡）。

## 阶段 2 冲突

**1 项**：入口 L 的 6D（AIRBORNE-only 档案）× 接缝必地面目标——数据前提无法弥合，路线按现设计到不了任何终点。入口 G 无阶段 2 冲突（D16 门未过是路线紧度的测量事实，非冲突）。
