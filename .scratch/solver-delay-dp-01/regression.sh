#!/bin/bash
cd "D:/Godot/Program/ftgdemo"
BASE=".scratch/solver-delay-dp-01"
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
i=0
for t in test_solver_checkpoint_trie test_delay_prefix_restore test_solver_index_equiv test_solver_edge_cache_equivalence test_solver_perf_profile test_solver_growth test_solver_route test_solver_entry test_combo_solver test_solver_cycles; do
  i=$((i+1))
  AD="$BASE/appdata$i"
  mkdir -p "$AD"
  echo "=== $t (appdata$i) start $(date +%H:%M:%S)" >> "$BASE/regression.progress"
  APPDATA="$(pwd)/$AD" LOCALAPPDATA="$(pwd)/$AD" "$ENGINE" --headless --path . -s "res://tests/$t.gd" > "$BASE/$t.log" 2>&1
  echo "exit=$?" > "$BASE/$t.status"
  echo "=== $t done $(date +%H:%M:%S)" >> "$BASE/regression.progress"
done
echo "ALL DONE" >> "$BASE/regression.progress"
