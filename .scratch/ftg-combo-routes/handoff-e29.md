# handoff-e29 — E29（witness 短链尾收口：5B AIR 值族）交接

2026-10-08。轮 K（编排方指派；fork 执行）。轮材料全文：[round-materials/e29-20261008.md](round-materials/e29-20261008.md)。分支 `codex/combo-route-prototype-e29-20261008`（自 e28 头 `daa4a86` 分叉；实现+证据与纯材料两提交见下）。未推送；共享账本未动；用户未提交材料保持原样。

## 一句话结论

**尾墙的解＝5B GROUND_BOUNCE untech（机制更正：追击 5B 命中 GROUND_BOUNCE 目标、消耗 BOUNCE 资料＝la 克隆源）——bu26（18→26，C 跟随）为最小充分，bu32 窗口裕度备选；bu26/bu32 完成 witness 链（跳 jC）12/12 同连段普通倒地＝E05 家族首个完整同连段倒地路线（妥协连候选，终点 F200、0 换边、镜像通过）；u/p（AIRBORNE 值）与 bp（BOUNCE up）全惰性或仅平移追击位；联合 77/256 未过 D16 门。**

## 供设计聊天裁决

1. **bu26/bu32 进入组合验证与否**：代价面＝BOUNCE untech 延长一切 5B 弹地追击池（E18 standalone 实测无回归——窗全等；E06/深链语境待组合轮复验）。
2. **witness 妥协连形态（跳 jC）登记**：与全链形态并行验收或仅作探索样本（D01/D02 妥协连语境）；全链同连段倒地仍需全局参数授权（E28：bw≈+8F 当量或落地恢复）。
3. **77/256 联合 FAIL**：并入既有「结构性亚 7F 关键窗」全局结论。
4. p 臂（AIR up）对 80px standalone 窗的混合影响（81/65 fulls）是否专项。

## 本轮硬数字（速查）

- 窗口（base）：追击 L2 [154,156]（3F）；214C 提交 bu26 [167,173]（7F）/bu32 [167,175]（9F）；~C [184,193]（10F）；k0＝{b0:90, d6:102, b1:125, d1x:131, L2:154, r2:167, rk2:184}。
- 机制：e0 追击 F165（GROUND_BOUNCE→AIR_HITSTUN，stun 8）→恢复 F181（有效池 16F←18，时间层 ≈0.89）；bu26 恢复 F184；u/bp 臂时间线与 e0 逐字同；p 臂 L2 窗 [155,157]/[157,159]。
- 回归：缝窗 [89,91] 全臂同；standalone u/bu/bp 71 fulls 全等、p150/p200 81/65；q-body witness 0 档。
- 负例（bu26）：gap 6/12 成 ≥24 断；平移仅 +1/+2 存活；L2 迟全败；被防/零输入无连段；镜像全成；joint 77/256。
- 门：隔离 12/12；三元组 0 违例（cal/tier/L2/seam/e18＝219 行×8 臂对；neg＝逐臂锚定范围注记）；基线前后 20 traces 字节全等、三套件已知态一致；0 脚本错误；2,633 次回放。

## 证据与复现

- 结论级：分支 `prototype_e29/evidence/`（9 文件＋manifest SHA256：isolation、anchors、baseline-traces、diag-summary、triple-audit×5）。
- 原始（未入库可复跑）：工作树 `.scratch/ftg-combo-routes/runs/e29-*`。
- 复现命令与试玩入口：分支 `prototype_e29/README.md`。

## 遗留

- q-body 无 witness 入口（E27/E28 同因）；joint 仅 bu26；u/p 臂尾扫描无锚可扫；Solver/循环审计未做。
- 真人手感全部待试玩（AIR 缝 3F、6D 读点、追击缓冲节奏 ~F154–156、214C 节奏 ~F167–173、~C 收尾、F200 倒地画面）。
