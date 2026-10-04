#!/usr/bin/env bash
# P7 阶段测试套件（Tier A 门）：每测试独立 APPDATA，status+seconds 落盘。
set -u
cd "$(dirname "$0")/../.."
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
OUT=".scratch/solver-p7-01"
TESTS=(
  test_solver_restore_schedule_scope
  test_solver_cycle_restore_alias
  test_solver_cycle_invariant
  test_delay_prefix_restore
  test_solver_checkpoint_trie
  test_solver_delay_dp
  test_solver_edge_cache_equivalence
  test_solver_index_equiv
  test_solver_cache
  test_solver_perf_profile
  test_solver_growth
)
for t in "${TESTS[@]}"; do
  mkdir -p "$OUT/appdata-$t"
  s=$(date +%s)
  APPDATA="$(pwd)/$OUT/appdata-$t" LOCALAPPDATA="$(pwd)/$OUT/appdata-$t" \
    "$ENGINE" --headless --path . -s "res://tests/$t.gd" \
    > "$OUT/test-$t.log" 2>&1
  ec=$?
  e=$(date +%s)
  printf 'exit=%d\nseconds=%d\n' "$ec" "$((e - s))" > "$OUT/test-$t.status"
done
echo done > "$OUT/stage-suite.done"
