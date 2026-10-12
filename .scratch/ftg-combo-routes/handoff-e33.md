# E33 交接（2026-10-08）— 236C×D 交叉组合：否定关闭＋v380 最小观感证据

分支 `codex/combo-route-prototype-e33-20261008`（实现+证据 `7ae45a8`；纯材料快照＝分支头第二提交），工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e33-20261008`；逐字材料 [round-materials/e33-20261008.md](round-materials/e33-20261008.md)；证据 `prototype_e33/evidence/`（isolation/anchors/carry/gap/s1×6/slide/neg/audits×3/tally/baseline-traces/diag 摘要）；复现链 `prototype_e33/README.md`。1,356 次正式回放、隔离 13/13、三元组 0 违例、基线 20/20 字节全等、0 脚本错误、未推送。

## 结论摘要

1. **g240/g320（236C 首段对地抬高）摧毁 AIR 缝**：目标被抬得略高，untech 池在缓冲 5B 前耗尽（F101 AIR_RECOVERED→LINK_FAILED）；E23 单变量阴性在交叉语境转为**破坏性**。
2. **a360/s28/s48 全测面与 C0 逐字相同**（惰性：seg1 对空资料未消费、seg2 滑地不可达）；滑地拾取窗 28–36 且 s 臂不移动（取消窗钉死）。
3. **v380C＝观感最小值候选**：连接全部保持、键窗整体 −1F、击飞峰值 −5.91px（29.36 vs 35.27）。
4. **gap 边界 (18,20]**：缝 [89,91] 存活至 gap 18、20 起断。
5. **S1 版边回归**：控制臂复现 E31（KD F146）；g240 零代价、**g320 连 S1 也摧毁**（且 wall_gap 32 引入穿越）；a/s 惰性；入场 0/16/32 无穿越。
6. 机器对照：C0 臂完整复现 E30——harness 对齐。

## 提请裁决

① g 族正式排除出 D→5B 修复方向（双重否定＋S1 代价）；② v380C vs v425C 观感取舍（建议试玩对比）；③ gap 边界 (18,20] 入 D20 材料；④ S1 面 g240 零代价记档。

## 试玩入口（待试玩）

```powershell
# 工作树根目录执行；输出目录必须尚不存在
python prototype_e33/run.py --candidates q-body__C0      --output .scratch/ftg-combo-routes/runs/e33-play-c0   --play
python prototype_e33/run.py --candidates q-body__C380    --output .scratch/ftg-combo-routes/runs/e33-play-v380 --play
python prototype_e33/run.py --candidates q-body__S1+g320 --output .scratch/ftg-combo-routes/runs/e33-play-s1g320 --play
```

S1 臂自动把木桩放在墙边（F3 镜像换边）。观察点：**C0+g240 的 236C 抬高画面与随后缝 5B 落空（目标空中恢复）**；C380 的更低击飞弧线与节奏（整体早 1F）；S1 对照 `q-body__S1`（完整版边倒地）vs `q-body__S1+g320`（5B 后断）。真人手感全部待试玩。

## 覆盖缺口（如实）

joint 未跑（链断于 jC＝E32 领地）；C 起手/镜像仅参考行；m55/v300/v360 细档；S1 D 窗上沿 >61；airtime 指标混杂不作结论；Solver 未跑；有限回放不作无限性证明。
