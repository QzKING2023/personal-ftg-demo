# Handoff E09（2026-10-07）——倒地收尾位置（D25 口径）测量完成

状态：全链完成（计划→isolation 门→主矩阵 486 计划→基线诊断 before/after 零漂移→分析→证据归档→提交）。
全文（experiments/results/progress 合并素材）在 `round-materials/e09-20261007.md`，请按串行合并流程并入共享账本。

要点速览：
- 四载体 gap-2 孪生全部复现已发布数字：s1back KD F149/N150 目标912 玩家864 钉0.0；cornerB F285 / cornerC F277（combo2 重启）钉0.0；g6a f129（中心距66.678≈发布66.7）；b6a N130。窗口扫描与发布窗口逐字吻合（s1back [107,122]/[132,142]，g6a [77,92]/[103,119]，b6a [78,93]/[104,120]）。
- D25 端点：墙三载体=指定墙边缘钉 0.0px，全矩阵/全窗口/整路±2/guard 下不变；板中 6A 双载体=固定净推进 30.2/30.278px（目标终点恒 510.2），与起始距离/板端无关；D28 板比 0% / ≈3.3–3.5%（双分母齐报）。
- 尺度不变（base/q-v/t26-v 全一致）、镜像 105 对零失配、全程无换边。
- 新事实：g6a 在纯基线（noprem）即达同一 KD；s1back 无前提改出重启 KD（同帧同位）；cornerB 无前提重启 F297；cornerC/b6a 无前提不出 KD。前提栈保持 UNADJUDICATED，结论均为条件性。
- 负样本全保留（whiff/gap40/guard/整路平移/link、restart 迟到）；cornerB (gap24,wall24) 单格连续性失败如实记录。
- 覆盖缺口：板中 B/C 起手（6D 冲突）未测，按任务书记缺口。
- 分支 codex/combo-route-prototype-e09-20261007 @ dd60689（未推送）；证据 prototype_e09/evidence/（manifest.sha256 已验）；
  试玩入口 prototype_e09/play.tscn（F1–F5/F6/F7/F8，NOT validated，观察点见 README 与 round-materials §8）。
- 设计树无已跟踪文件改动；未触碰用户未提交改动；无阶段2新冲突。
