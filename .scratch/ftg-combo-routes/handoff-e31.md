# E31 交接（2026-10-08）— 12×20 已发布参考路线整套重锚（零变量轮）

分支 `codex/combo-route-prototype-e31-20261008`（实现+证据 `c62a543`；纯材料快照＝分支头第二提交），工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e31-20261008/ftgdemo`；逐字材料 [round-materials/e31-20261008.md](round-materials/e31-20261008.md)；证据 `prototype_e31/evidence/`（isolation/anchors/summary JSON）；复现链 `prototype_e31/README.md`。4,557 次正式回放、隔离 8/8、data_unchanged 全真、诊断 20/20 字节全等、0 脚本错误、未推送。

## 结论摘要

1. **版边 S1 `5B > 5C > 236C(两段) > 5[D], 5B > 214C~C`（refb 栈）在 12×20 发布键逐字完整成立**：link[101,103]/k214[107,122] 与 E13 发布逐字相同，KD F147、钉墙 0 间距、0 换边、镜像 full；离墙 0–32px 进入均无穿越（48px 才换边）——q-v 的 20px 穿越带不转移。joint 153/256。
2. **6A 对空基础悬空面（e19bw32）在 12×20 近发布成立**：40px/20px 悬空均 full，仅 6A 晚 1F（t=2）；B 窗 3F 等发布宽度；KD F130、0 换边。joint 62–68/256。
3. **地面/低空面塌缩**：jC 重锚后 1F 窗，j214D 死于缓冲年龄（CANCEL_WINDOW_CLOSED）；机制＝薄身竖直带移（jC 接触 +10F）。速降 40px 目标 6A 全空（覆盖负例）。
4. standalone 空中 5B：20/40px 窗与 base 全同；**80px ~C 收尾窗全空**。
5. 板边两轮 D 首断点：base＝发布 j2D→214C 终缝；**q-body 上移至 jC**（同薄身机制）。
6. 机器对照：base 三线（G 链/悬空 40/S1）全部逐字复现发布值——harness 与发布历史对齐。

## 提请裁决

① 12×20 常见对空范围收窄（悬空 20–40px 成立、低空/速降不成立）或立 jC/缓冲新变量族；② S1 板边 B 样本 12×20 证据就绪（C 起手缺口保留）；③ 薄身带移机制旗标（阶段 2）；④ 80px standalone 收尾死点立项与否。

## 试玩入口（待试玩）

```powershell
# 工作树根目录执行；输出目录必须尚不存在
python prototype_e31/run.py --candidates q-body__refb     --output .scratch/ftg-combo-routes/runs/e31-play-s1  --play
python prototype_e31/run.py --candidates q-body__e19bw32 --output .scratch/ftg-combo-routes/runs/e31-play-air --play
python prototype_e31/run.py --candidates q-body__la       --output .scratch/ftg-combo-routes/runs/e31-play-b5b --play
```

按打印的 Godot 命令启动（换 `base__*` 为旧尺寸对照）。F3 镜像 / F7 重置；方向键、U/I/K/J＝A/B/C/D、空格跳、G 防。观察点：S1 的 3F 缝 5B 与钉墙倒地在小身体下的可读性；对空基础 40px 悬空节奏（6A 晚一拍的读感、B 3F 目押）；la 栈 80px 高度 ~C 够不着的观感。

## 覆盖缺口

对空面 C 起手/距离块/墙侧未扫；j214D 死链仅半径内证据；悬空无被防面（引擎拒防）；E06 仅首断点定位；joint 仅 4 条完成路线；Solver/循环审计未做；有限回放不作无限性证明。真人全部待试玩。
