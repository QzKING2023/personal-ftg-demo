# handoff-e26 — E26（q-body midB 缝位移修复＋v×r 组合最小充分性）交接

2026-10-08。并行轮 H（编排方指派；fork 执行）。轮材料全文：[round-materials/e26-20261008.md](round-materials/e26-20261008.md)。分支 `codex/combo-route-prototype-e26-20261008`（自 e24 头 `6775df9`；实现+证据 `86876a2`；纯材料快照提交在 `prototype_e26/design-return/`）。工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e26-20261008/ftgdemo`。未推送；共享账本未动；用户未提交材料保持原样。

## 一句话结论

**5[D] 位移阶梯（120→80/60/40）×任一时序形态（u56/r12）把 q-body（12×20）midB 缝恢复到 base 全平价（[101,103]/[89,91] 逐字、joint 61）；E24 的「穿越阻断」实为过冲失 Reach；档位决定换边语义与链质量——m60/m80＝D09 式真实换边但 6D 不可达，m40＝不换边＋贴身（接触钳 27.73px）且 6D+jB 链通（prefix 8）；motion 阶梯在 base 完全免费（接触钳与声明值无关）；AIR 缝 v 阈值收窄到 (260,340]。**

## 供设计聊天裁决

1. **q-body 中板档位取舍（本轮核心选择题）**：m60/m80 保 D09 要求的 5[D] 实际换边（postB 21.22/41.22）但换边后 6D 触及不足（链止于缝 5B）；m40 不换边、贴身（postB 14.28）、6D+jB 接通。二者不可兼得于单档——若 D09 双换边对 12×20 不可让，需另立项（6D 触及/击退族或 m50 中间档）；若链通达优先，需裁决 D09 在小身体的适用性。base 无此抉择（不换边且链到 jB）。
2. **位移削减的搬运代价＝仅小身体载体存在**：base 自身推进被接触钳制（27.73px 恒定），阶梯全免费；q-body 上 60/80 全额兑现推进、40 被钳回。设计若要 5[D] 推进观感（E11「原地斩」顾虑），m60 是保留最多推进且接缝的档。
3. **AIR 缝 v 阈值 (260,340]**：v340Cr12 已具 AIR 语义（base 中板 [89,91] AIR）；v260Cr12 仅地面缝。更保守击飞方向可测 v300。
4. E24 交接的「q-body 穿越＝D51 不豁免项」就此有解：位移族是答案，等待档位裁决后可进组合验证。

## 本轮硬数字（速查）

- q-body 恢复缝：m60u56 [101,103]（joint 61/256）；m60r12/m80r12/m40r12 [89,91]；全部与 base 同名臂逐字相同；wall 侧 [82,84] 系复现。
- q-body 换边/推进：m80 swap=1 self=80.0 postB=41.22；m60 swap=1 self=60.0 postB=21.22；m40 swap=0 self=27.73（钳）postB=14.28；base 全档 self=27.73（钳）swap=0。
- 链（L6 束）：base 全 motion 档 prefix 8（5B air→6D→jB；jC 墙）；q-body 中板 m40 prefix 8、m80/m60 prefix 6（6D 不可达）、v425Cr12@120 墙 prefix 7。
- ④：v260Cr12 base 中板地面缝 [89,91]；v340Cr12 中板 AIR [89,91]（地面缝消失）。
- carry：236C→5[D] 命中位移 2.52px 全臂恒定（k 未动，E11 复现）；236C→5B base 5.93 / q-body m60 系 2.71 / m40 5.93。
- 规模：主 22×1,830＋L6a/b/c＋carry ≈ 45,000 次回放；隔离 32/32；三元组 main+L6 0 违例；基线前后 20 traces 与三套件日志逐字节全等；0 脚本错误。

## 证据与复现

- 结论级：分支 `prototype_e26/evidence/`（26 文件＋manifest SHA256：main/ 22 候选＋summary、l6-anchors、e26-carry、baseline-traces）＋根级 `e26-isolation.json`、`e26-triple-audit-{main,l6}.json`。
- 原始（未入库可复跑）：`.scratch/ftg-combo-routes/runs/e26-{diag-before,diag-after,main,main-plans,l6a,l6a-plans,l6b-plans,l6b*,l6c-plans,l6c*,carry,carry-plans,play-smoke}`（工作树）。
- 复现命令与试玩入口：分支 `prototype_e26/README.md`（含锚重算规则说明：墙侧锚以墙语境 5 招前缀从同一批结果重算，重算后逐字复现 E24 墙侧数字）。

## 遗留

- m50 型中间档与换边阈值（40–80 间）、AIR 缝 v300 档未测；q-body L6 链仅 facing 1 于自身 b0；r 臂被防面未量化（探针行与 e0 同型留 trace）；joint8 全 0（链未满，jC 墙属 E25 范围）；Solver/循环审计未做。真人手感全部待试玩。
