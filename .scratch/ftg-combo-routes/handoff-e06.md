# E06 交接：板边重复结构后 j2D 专用落地收尾（B/C 路线）——2026-10-07

## 判词
- **E15 声明缺口闭合**：第 2 轮 5D→5B 与全部空中链由顺序逐键重锚接通——B 路连续 13/15 击、C 路 12/14 击；「第 2 轮整块平移 0/66」是锚定方法缺口，不是结构墙。
- **终缝 j2D→214C 结构性无连续解**：j2D F247 命中→木桩坠落 F263 着地余 1F 眩晕→F264 NEUTRAL；214C 起手 ~10F 追不上。246 行扫描（cmd3 rel 逐帧 + 空链 ±2×rel）连续连接 0。h22 不可归因（连续 214C 不可达）。
- **重启击倒可行**：214C 以新连段（开放来源合法）F267 命中、~C F285 KNOCKDOWN；提交窗 rel **[−9,−6]∪[0,+3]**（绝对 247–250/256–259）。「236C 击倒尾」以重启形式被见证，未作为连续尾成立。
- **D24/D26 位置门 PASS、连续性门 FAIL**：几何矩阵 32/32 行 KNOCKED_DOWN、0 换边、目标钉起始墙 0.0px、玩家场内；但击倒来自第 2 连段（combo=2）。
- **几何覆盖**：C 路 16/16 几何 12 连续（D24 全网格）；B 路 14/16，唯 (gap24, wall≥24) prefix2——236C(1) 最早接触 F47 > 眩晕耗尽 F45，travel-bound，整体平移 −2..−10 不可救；失败转化为 via_entry 滑行重启（F47 命中、SLIDE_STARTED F65）+ 部分重连（终点 combo 7–9 仍击倒钉墙）。
- **逐键窗（±16 全程、三尺度同值）**：B link[82,84] C2[88,101] cmd2[105,117] D2[120,137] B2[165,167] 6A[171,187] jump[195,199] jB[206,210] jC[212,221] j2D[226,231]；C link[67,69] C2[73,86] cmd2[90,103] D2[105,122] B2[150,152] 6A[156,172] jump[180,187] jB[191,198] jC[198,209] j2D[212,226]。窄窗＝link 3F、B2 3F（B 路）。
- **256 关节（6 窄键 ±2）83/256 可达（门 244 FAIL）**、full 0；断点 163×MOVE_RECOVERED|5D＋10×DUMMY_RECOVERED——结构性亚 7F 窗，与 E03 量级一致。loop3 延迟 −2..0 保持、≥+2 断——无第三轮入口。
- **前提归因**：u56 双路必要；g28 仅 B 路必要（C 路无 g28 仍 12 连续）；p60、E18-la 惰性；E19-b/g 取向惰性；k240/w32 不适用（j214D 不在路线内）。前提栈整载 UNADJUDICATED，结论条件于此。

## 复现
- 分支 `codex/combo-route-prototype-e06-20261007`（自 aa17ba3；fd9f8fe＋a33c44b），工作树 `C:/Users/q1625/.codex/worktrees/combo-route-prototype-e06-20261007/ftgdemo`；`prototype_e06/` 全部 TEMPORARY。
- 命令链（README 全文）：`seq.py` 逐键校准 → `run_pack.py main|neg|win|joint|seam|loop3` → `analyze.py` → `audit_triples.py` → `isolation.gd` → diag before/after → `run.py --play --smoke`。
- 证据：`prototype_e06/evidence/`（45 文件含 manifest SHA256：analysis/headline、15 cal、各 pack manifest、triples、isolation、diag 前后）；原始 `runs/e06-*`（gitignored）。7,745 次有效回放。
- 基线无漂移：e06-diag-before vs after 26/26 文件 SHA 全等；boundary 10/0、replay10 103/2 已知、symptoms 13/24 已知。

## 提请设计聊天裁决
1. **终缝处置**：接受「j2D→214C 无连续解；~C 击倒经 214C 重启（新连段）达成，提交窗 rel[−9,−6]∪[0,+3]」作为 D07 样本的事实终态，还是立「j2D→214C 连续锁」为新的时序/资料变量题（需第二段眩晕或提前着地类前提，超出 D41 已开范围）？
2. **D24 边角**：B 样本 (gap24, wall≥24) 的失守是 travel-bound（非节奏），D22「共用参考节奏」在此角点如何处置——缩窄 B 的保证区间、还是立 236C 前移/起手距离变量题？
3. **位置门与连续性门分列**：D26 的「目标留原墙 0–24px＋玩家场内」在重启击倒下成立——是否接受「连续性 FAIL、位置 PASS」的分列记账。
4. **前提栈**：本轮归因（g28 仅 B 路）是否影响 g28+h22 的采纳评估（C 路不再依赖 g28）。

## 待试玩
- link/B2 3F 窗目押读感；C 路空中窗（jump 8F/jB 8F/jC 12F/j2D 15F）明显宽于 B 路，实测可玩性。
- 重启 214C 节奏（名义提交 256±3）真人可行性；滑行重启观感（gap24 角点失败路径）。
- 入口 `prototype_e06/play.tscn`（F1–F5 布点、标签含窗表）；手感全部未验证。

## 未竟
- Solver 腿未跑（本轮以固定探针全分类为主，范围声明）；q-v/t26-v 仅 4 臂（n-u56/n-g/n-p60 缺）；win/joint/seam/loop3 仅 base__refb（范围注记）；「236C 击倒尾」作为连续尾的新变量族未立题。
