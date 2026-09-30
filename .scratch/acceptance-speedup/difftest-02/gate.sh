#!/usr/bin/env bash
# Ticket 02 differential gate: on one fast subset tree covering all output
# shapes (with metrics, without metrics, import, diagnose_inputs, main-smoke),
# three runs share the tree sequentially — PS serial (old runner), Python
# serial (new scheduler in serial mode), Python parallel (concurrency 8).
# PS vs py-serial re-proves runner parity on the new scheduler code; py-serial
# vs py-parallel proves the fan-out changes nothing. Summaries must be equal
# field by field except timing fields; exit codes and status files must agree.
# Wall clock and longest-job seconds are recorded per side for the ticket.
set -u
GATE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$GATE_DIR/../../.." && pwd)"
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
TREE="$GATE_DIR/tree"
RUN="$GATE_DIR/run"
KEEP_TESTS="test_smoke test_crouch_stationary test_solver_cache"

fail() { echo "exit=1" > "$GATE_DIR/gate.status.txt"; echo "GATE FAIL: $*"; exit 1; }

echo "== building subset tree (keep: $KEEP_TESTS)"
rm -rf "$TREE"
python - "$ROOT" "$TREE" $KEEP_TESTS <<'EOF' || fail "tree build failed"
import os, shutil, sys
root, tree, keep = sys.argv[1], sys.argv[2], set(sys.argv[3:])
shutil.copytree(root, tree,
                ignore=shutil.ignore_patterns('.git', '.godot', '.scratch', '.idea',
                                              '.godot_logs', '__pycache__', '.vscode'))
tests = os.path.join(tree, 'tests')
for name in os.listdir(tests):
    if name.startswith('test_') and not any(name.startswith(k + '.') for k in keep):
        os.remove(os.path.join(tests, name))
EOF

run_side() {
  side="$1"
  echo "== running $side"
  rm -rf "$RUN" "$TREE/.godot"
  start=$(date +%s)
  if [ "$side" = ps ]; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "$TREE/tools/run_acceptance.ps1" \
      -Engine "$ENGINE" -Output "../run" > "$GATE_DIR/$side.stdout" 2>&1
  elif [ "$side" = py-serial ]; then
    python "$TREE/tools/run_acceptance.py" --engine "$ENGINE" --output "../run" --serial \
      > "$GATE_DIR/$side.stdout" 2>&1
  else
    python "$TREE/tools/run_acceptance.py" --engine "$ENGINE" --output "../run" --concurrency 8 \
      > "$GATE_DIR/$side.stdout" 2>&1
  fi
  echo $? > "$GATE_DIR/$side.exit"
  wall=$(( $(date +%s) - start ))
  [ -f "$RUN/summary.json" ] || fail "$side produced no summary.json"
  [ -f "$RUN/runner.status.txt" ] || fail "$side produced no runner.status.txt"
  cp "$RUN/summary.json" "$GATE_DIR/summary.$side.json"
  cp "$RUN/runner.status.txt" "$GATE_DIR/status.$side.txt"
  longest=$(python - "$GATE_DIR/summary.$side.json" <<'PY'
import io, json, sys
data = json.load(io.open(sys.argv[1], encoding="utf-8-sig"))
print(max(t["seconds"] for t in data["tests"]))
PY
)
  echo "$side: wall=${wall}s longest_job=${longest}s exit=$(tr -d '\r\n' < "$GATE_DIR/$side.exit")"
}

run_side ps
run_side py-serial
run_side py-parallel

echo "== comparing summaries"
ok=1
for pair in "ps py-serial" "py-serial py-parallel"; do
  set -- $pair
  python "$ROOT/tools/compare_summaries.py" "$GATE_DIR/summary.$1.json" "$GATE_DIR/summary.$2.json" \
    > "$GATE_DIR/compare.$1-$2.out" 2>&1 || { ok=0; echo "summary diff ($1 vs $2):"; cat "$GATE_DIR/compare.$1-$2.out"; }
done
ps_exit="$(tr -d '\r\n' < "$GATE_DIR/ps.exit")"
spy_exit="$(tr -d '\r\n' < "$GATE_DIR/py-serial.exit")"
ppr_exit="$(tr -d '\r\n' < "$GATE_DIR/py-parallel.exit")"
status_ps="$(tr -d '\r\n' < "$GATE_DIR/status.ps.txt")"
status_spy="$(tr -d '\r\n' < "$GATE_DIR/status.py-serial.txt")"
status_ppr="$(tr -d '\r\n' < "$GATE_DIR/status.py-parallel.txt")"
echo "exits: ps=$ps_exit py-serial=$spy_exit py-parallel=$ppr_exit"
echo "statuses: ps=[$status_ps] py-serial=[$status_spy] py-parallel=[$status_ppr]"

[ "$ps_exit" = "$spy_exit" ] && [ "$spy_exit" = "$ppr_exit" ] || { ok=0; echo "process exit codes differ"; }
[ "$status_ps" = "$status_spy" ] && [ "$status_spy" = "$status_ppr" ] || { ok=0; echo "runner status files differ"; }
for side in ps py-serial py-parallel; do
  e="$(tr -d '\r\n' < "$GATE_DIR/$side.exit")"
  [ "exit=$e" = "$(tr -d '\r\n' < "$GATE_DIR/status.$side.txt")" ] || { ok=0; echo "$side exit code disagrees with its status file"; }
done

if [ "$ok" -eq 1 ]; then
  echo "exit=0" > "$GATE_DIR/gate.status.txt"
  echo "GATE PASS"
else
  echo "exit=1" > "$GATE_DIR/gate.status.txt"
  echo "GATE FAIL"
  exit 1
fi
