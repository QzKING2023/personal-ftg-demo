# Handoff E03 (2026-10-07) - three-tier executability measurement, routes A + B

Branch codex/combo-route-prototype-e03-20261007 (from e16 head aa17ba3), commit cf0ada1, worktree C:/Users/q1625/.codex/worktrees/combo-route-prototype-e03-20261007/ftgdemo. Full material: .scratch/ftg-combo-routes/round-materials/e03-20261007.md. Evidence: prototype_e03/evidence/ in the worktree (isolation gate, diag before/after, analyze windows/joints/references/probes, per-candidate CSVs, p4 decisions, baseline-traces 24/24 SHA-equal).

Scope: D14-D17 formal measurement, 6 candidates {base,q-v,t26-v}x{s1ref,bw32}, fixed continuous inputs, complete = full sequence + knockdown AND zero swaps. 9042 plans measured. Isolation gate 6/6 PASS (declared deltas asserted; arms differ only in declared deltas; base normalize == raw baseline). Premise stack carried whole, UNADJUDICATED (u56, g28+h22, p60, k240 opt, E18-la, E19-b/g, w32; adjudicated only E04/D03). Baseline: diag-before = diag-after byte-identical (boundary 10/0, replay10 103/2, symptoms 13/24 - known-fail state preserved).

## Tier 1 - D15 single-key windows (>=7F incl ref+-3), identical across all scales x facings
- Route A (keys C16/m236 33/D58/link101/k214 121/rekka139; R1 complete, kd N150, dummy pinned x=912, 0 swaps):
  PASS: 5[D] [55,64] w10; ~C [133,143] w11. FAIL: 5C [5,16] w12 (ref on late edge); 236C [22,33] w12 (late edge); seam 5B [101,103] w3; 214C [107,122] w16 (late edge 14/1).
- Route B (RB: t=1, jump14/C23/D33/B72/k214 92/tildeC110; R1 complete, kd N130, 0 swaps):
  PASS: jump [4,19] w16; j214D [28,42] w15; ~C [104,120] w17. FAIL: jC [22,23] w2; 5B [72,74] w3; 214C [78,93] w16 (late edge 14/1).
- Pattern: references sit on the LATE edges of several real windows (C, m236, k214 both routes) - any human lateness on those keys breaks the route; earliness is the intolerable direction at seam/link windows.

## Tier 2 - D16 6-key joint +/-2, 256 fixed vectors, gate >=244 complete: ALL FAIL (honest negative)
- A R1 98/256 (all scales, both facings); A R2 (per-key window centers) 152/256.
- B R1 52/256 base+t26-v, 32/256 q-v; B R2 85/256, 106/256 (q-v).
- R2 sensitivity block (declared, never merged with R1): margin-optimal references still fail -> failure is STRUCTURAL (sub-7-frame critical windows), not reference mis-centering.
- Bottleneck A = 3F seam 5B [101,103] (sole R2 breaker, 104/154 failures). Bottleneck B = 2F jC [22,23] + 3F 5B [72,74].
- Zero side swaps in all 9042 plans (crossed=0). Prior coarse estimates (E13 120/343, E19 47-62/256) same order; formal gate numbers now exist.

## Probes (labeled, outside the D16 set)
- Negative witnesses in place: A guard=2 -> ATTACK_BLOCKED; A/B gap=200 whiff -> timeout; zero-controls complete.
- A link+18: PLAIN DROP, not a new combo (late-seam-new-combo expectation does not hold). A link-3: drop. A whole-shift +1/+2 complete, -1/-2 drop.
- B whole-shift -2 breaks at jC, else complete. B rising vy=+1: route COMPLETED - E19 rising-target zero-contact witness did NOT reproduce at the representative hover condition (flagged, not adjudicated).

## Tier 3 - D17 playtest entry (待试玩)
From worktree root: Godot console exe --path . --resolution 1280x720 res://prototype_e03/play.tscn -- {base,q-v,t26-v}__{s1ref,bw32}. F1 route-A wall pin / F2 mirror / F3 route-B hover 0.5 / F4 hover mirror / F5 hover height / F6 hover vy / F7 reset; Arrows move, U/I/K/J = A/B/C/D, Space jump, G guard, R reset; label marks TEMPORARY / NOT validated. Observation points: A - seam 5B at F101-103 is the 3-frame crux, kd ~N150 at wall x=912; B - jC 2-frame crux ~jump+9, 5B 3-frame crux ~F72, kd ~N130. No feel claims made.

## Flags for stage 2 / ledger
1. E19 rising-target premise needs a condition qualifier (vy=+1 did not break contact at hover 0.5 body, center).
2. E13 late-seam-new-combo claim should be dropped or re-scoped (observed drop at +18).
3. Ledger hygiene: E13 kd F149 = measured N150 (F vs N indexing).
4. Fresh worktrees must copy gitignored .scratch/ftg-combo-routes/inputs.json before running replay_combo_routes.gd, else the engine idles silently on a parse error at tests/replay_combo_routes.gd:8.

Reproduction: see prototype_e03/README.md in the worktree (5-phase pipeline commands, isolation gate, diag, analyze, archive, playtest entry).
