# HANDOFF — E07 起手距离如何影响完整路线（2026-10-07）

- 分支 `codex/combo-route-prototype-e07-20261007`（aa17ba3 + 45a6356 实现 + 6fd6d32 证据）
- 原型 `prototype_e07/`（TEMPORARY，含可玩入口）；证据 `prototype_e07/evidence/`（SHA256SUMS.txt）
- 本轮材料全文：`.scratch/ftg-combo-routes/round-materials/e07-20261007.md`
- 原始运行：`.scratch/ftg-combo-routes/runs/e07-*`（analysis/audit/cals 已入分支；原始 12MB 级 jsonl 留 scratch）

## 一句话结论
起手距离不改变节奏：三条主路线的按键窗在各自可连距离带内逐字节不变；距离只决定「结构上挂不挂得上」。全部成功区间从 gap 0 开始且随距离单调收缩；失败缝随距离单调上移，且带真实距离/高度。D21 的「按距离分层时间表」不需要；D20 贴身保证成立；D22 的 0–24px 带内整链行为完全均匀。

## 关键数字（base__refb）
- CB（E06 角 B）：首击 [0,44]，固定节奏达链 [0,42]，full ∅（终点缝=已知），倒地 [0,45] 全为重启（kd_combo=2）、墙钉 0px。
- CC（E06 角 C）：首击 [0,45]，达链 [0,42]，full ∅，倒地 [0,45]（kd_combo=2）。
- G（E02 入口链）：首击 [0,68]（实测界 [68,69]），达链 [0,33]，**full [0,31]**，倒地 [0,31]（kd_combo=6，版中不钉墙）——与 E02 公开「≤31 过、40 败」一致。
- 首击（摸得到）边界：5B [44,45]、5C [51,52]、6A [68,69]。
- 镜像（facing −1）全等；noprem 角 sample link 窗全空（结构断），G 与 refb/refg 完全同区间（G 链不依赖所携前提）；对照 MB [0,19]/MC [0,31]，对照缝 b0=[101,103] 全距不变。
- joint 256：CB 66、CC 90 在 g0=g24 相同；G 136(g0/g24)/135(g31)。重启缝 rel：CB −8..+3、CC −12..+3，三距相同。
- 尺度审计：0 critical 差异（成功门三尺度全等；差异仅帧移/重启尾衰减）；缩放载体版中出现真实换边（swaps 9–20 次）。

## 给下一轮的可复用资产
- `routes.py`：三路线构建器 + E06 校准锚（含「为何用校准锚不用 nominal」注释）。
- `seq.py`：逐距重锚定（角 sample 自动钉 wall0——曾因漏钉版中跑出假 BREAK，已修）。
- `packs.py`：镜像/联合/重启缝/负例/对照缝/延迟阶梯生成器（每任务独立输出目录——曾因同名文件互踩 13 任务失败，已修）。
- `audit_triples.py`：尺度三元组审计（结果投影/帧移/尾衰减三级分类；直接比较命中帧会全红——位移缩放是声明内合法项）。
- `diag.py`：基线诊断门（canonical 计数行解析；20/20 traces 字节比较）。
- 踩坑记录：inputs.json 必须手工拷贝；新工作树先 `--headless --editor` 导入；运行时目录互踩与 glob 深度（`cid/*/*-plans.json`）。

## 未决 / 移交
1. 第三轮 loop 随起距：未测（重启后起手几何由重启决定、与起距解耦的论证在 materials；若要做需按重启落点重锚第三轮）。
2. 重启缝叶形：本轮 cmd3 单独平移测得连续窗 −8..+3；E06 两叶口径在空链联合位移下测得——建议裁定统一口径后并入 E06 结论。
3. 待试玩五点见 materials（入口与观察点齐备）。
4. 前提栈整体仍为 UNADJUDICATED（本轮结论在 noprem/refb/refg 三臂下分别成立，结论不依赖裁定结果：角链依赖 E18/E19、G 链零依赖均已实证）。

## 复现
见 `prototype_e07/README.md`（9 步链：fixture 拷贝→导入→diag→iso→sweep→seq→packs→analyze/audit→diag-after→play）。
