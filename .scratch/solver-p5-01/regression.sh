#!/usr/bin/env bash
# P5 regression: P0-P4 gates + all route/cycle/spatial tests + new P5 gate.
# Sequential single-engine runs (per-process APPDATA, nohup exit-code capture).
set -u
cd "$(dirname "$0")/../.."
ENGINE=/d/Godot/Godot_v4.5.1-stable_mono_win64_console.exe
OUT=.scratch/solver-p5-01
APPDATA_DIR="$PWD/$OUT/appdata"
mkdir -p "$APPDATA_DIR"
export APPDATA="$(cygpath -w "$APPDATA_DIR")"

TESTS=(
  test_solver_perf_profile
  test_solver_index_equiv
  test_solver_edge_cache_equivalence
  test_solver_checkpoint_trie
  test_delay_prefix_restore
  test_solver_delay_dp
  test_solver_cycle_invariant
  test_solver_growth
  test_solver_cache
  test_solver_spatial
  test_solver_route
  test_solver_entry
  test_solver_routes_cycles_refactor
  test_solver_cycles
  test_combo_solver
)

for t in "${TESTS[@]}"; do
  echo "=== $t start $(date +%H:%M:%S) ==="
  "$ENGINE" --headless --path . -s "res://tests/$t.gd" > "$OUT/$t.log" 2>&1
  echo "$?" > "$OUT/$t.status"
  echo "=== $t exit $(cat "$OUT/$t.status") $(date +%H:%M:%S) pass=$(grep -c '^PASS' "$OUT/$t.log") fail=$(grep -c '^FAIL' "$OUT/$t.log") ==="
done
echo "ALL DONE $(date +%H:%M:%S)"
