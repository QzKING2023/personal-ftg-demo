# E23 交接：236C 轨迹与滑地族（Q48 轮）——2026-10-08

## 判词
- **设计位 D→5B 缝：全臂全载体死，墙是目标 untech 计时而非高度/资料**。5[D] F73 命中（untech 32 缩放）→ 目标 **F101 DUMMY_RECOVERED** → 缓冲 5B ~F106 才出框。g240/g320 抬高 5[D] 命中点 +5/+10px 只推迟落地 ~2F，F101 三臂逐字相同；la（D45 5B 空中资料）无效——连段在 5B 出框前合法结束。**236C 首段浮空不是缝修复杠杆；时序差（untech vs D 恢复 ~5F）是活问题＝E24 的 u56/缩恢复臂。**
- **路线内 seg2 永不滑地**：seg1 命中必浮空 → seg2 F55 命中 AIR_HITSTUN（y433.6）走对空 LAUNCH180；g 臂只令命中点更高。真实滑地唯一入口＝裸 236C seg1 挥空＋seg2 命中地面（gap 44–58：F18 命中 → LOW_FLOAT 18F → F36 SLIDE_STARTED，目标滑离）。
- **S 臂（slide_frames 18→28/48）声明 1:1 兑现（滑行 17/26/46F）但零容错收益**：5D 拾取提交窗 [20,42] 三臂逐字相同（上限＝236C 取消窗 F43 CANCEL_WINDOW_CLOSED，下限＝触及）；5B/5C 拾取结构性不可达（滑离＋触及不足；E17 pickB 窗属其它入口几何）。
- **新合法路线（e0 裸基线即成立）**：`236C 滑地带 → 5D 拾取（提交 [20,42]、GROUND_SLIDE 命中 F45–47）→ 5B 链（恰 1 帧＝D提交+32）→ 214C（o214 4–18）→ ~C（orec 12–28，34/72 格）→ KD F114`；五招全连、0 换边、双载体同窗。**限制：1F 目押不满足 D15；独立短路线不顶替设计位 D→5B 必保。**
- **q-body（12×20）**：时序与 base 逐字相同；已发布 `air` 对空参考在 gap2 失败（full 0/10 vs base 2/10）——12×20 需整套重锚（D51 落地提示）。a360 惰性（悬停连接计数与 e0 全等）。

## 复现
- 分支 `codex/combo-route-prototype-e23-20261008`（自 d5cf77c），工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e23-20261008/ftgdemo`；实现+证据提交 `d8c27b7`（材料快照提交另列）。全部代码 TEMPORARY。
- 命令链见 `prototype_e23/README.md`（baseline-before → isolation → parallel main 18×1,302 → analyze → audit → stage2 6×230 → stage2b 3×72 → archive → diag-after → play smoke）。合计 25,032 次回放；引擎合计 ~4 分钟（≤4 并发、独立 APPDATA）。
- 证据 `prototype_e23/evidence/`（34 文件含 manifest SHA256）；原始 `runs/e23-*`（gitignored 可复跑）。基线前后 20 trace 逐字节全等（e23-baseline-traces.json）。

## 提请设计聊天裁决
1. 滑地路线 1F 5B 链：数据事实；若设计要该路线可用，需 5D 滑地命中 stun 的新时序变量（新变量族，本轮未动）。
2. 滑地拾取提交上限被 236C 取消窗钉死（F43）：slide_frames 变量要有意义须先放宽取消窗或走非取消入口（规则变量，范围外）。
3. 12×20（D51 方向）上已发布参考路线需重锚——尺寸落地工作项，非本题失败。

## 待试玩
- 滑地带（F4 布点）5D 拾取节奏：提交窗 23F 宽，预期宽松；随后 **1F 5B 链**人手可行性（预期不可行，仅核实体感）。
- g320 的 5[D] 命中高度视觉（+10px 是否可辨）；12×20 身体下整体观感（对照 base）。
- 入口：`play.tscn -- base__s48`（对照 base__e0 / base__g320 / q-body__s48）；F1 板中 / F2 右墙 / F3 镜像 / F4 滑地带 gap48 / F5 悬停 40px；方向键/Space、U/I/K/J=A/B/C/D、G 防、R 重置。

## 未竟
- 滑地带更近端（gap 44–46）与墙边滑地几何未扫（拾取窗预计同被取消窗钉死）；236C×5D 跨族组合按编排规则留组合轮；a360 只测了悬停初态两高度两速度，未测对空链前缀内的中途 236C。
