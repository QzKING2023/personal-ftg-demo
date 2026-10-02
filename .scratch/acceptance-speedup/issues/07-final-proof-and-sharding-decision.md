# 07: 全量终证与分片触发判定

Status: ready-for-agent
Parent: [spec.md](../spec.md)
Blocked by: 04, 06(05 若实施则加)

## What to build

整个提速工程的收口:一次**冷跑**全量(默认配置:清扫开、全新缓存文件,mode=acceptance-sweep)证明墙钟 ≤1 小时,与 02 的串行基线做最终对拍。分片的触发判定已前置交付——2026-10-02 grilling 把分片由条件票转正为票据 08(全局前置清扫)并于本票之前实施,本票只记录饱和度与余量。这是全工程唯一一次"证明性"全量运行——此前的门都用定向 job。

## User stories covered

20, 21, 22(判定)。

## Acceptance criteria

- [ ] 冷跑全量完成:默认配置(清扫开、全新缓存文件,mode=acceptance-sweep),墙钟 ≤1h;summary、状态文件、耗时归档到本票 scratch 验收目录。
- [ ] 最终对拍:与 02 串行基线按 Tier B(ADR-0006 修订四)——`report_fingerprints` 集合(含 keys)、断言总数、各 job 结论逐项相等;不变量 `hits+misses==calls` 各 Solver job 成立、清扫热跑 misses 记录在案。
- [ ] 饱和度与余量:清扫段各车道 busy 占比、三段墙钟分解、最长 job 耗时记录;给出未来连段边增长下保持 ≤1h 的余量推算(分片已由票据 08 前置交付,">20min 才触发"条款废止)。
- [ ] 更新量级基线:新耗时结构写回 spec 的 Further Notes 或 Comments(供后续票据估计验收时长)。
- [ ] 旧 PS runner 的去留决定:保留为历史基线或删除,记录理由(倾向保留至下一次全绿后再删)。

## Blocked by

- 04
- 06
- 08(2026-10-02 加入:分片前置交付)
- 05(若实施)
