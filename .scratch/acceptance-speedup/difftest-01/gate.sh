#!/usr/bin/env bash
# Ticket 01 differential gate: PS-serial vs Python-serial acceptance on a fast
# subset tree covering all output shapes (with metrics, without metrics,
# import, diagnose_inputs, main-smoke). Both sides run into the SAME output
# directory sequentially so appdata paths match; summaries must be equal field
# by field except seconds/total_seconds, with identical exit codes.
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
  echo "== running $side (serial)"
  rm -rf "$RUN" "$TREE/.godot"
  if [ "$side" = ps ]; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "$TREE/tools/run_acceptance.ps1" \
      -Engine "$ENGINE" -Output "../run" > "$GATE_DIR/$side.stdout" 2>&1
    echo $? > "$GATE_DIR/$side.exit"
  else
    python "$TREE/tools/run_acceptance.py" --engine "$ENGINE" --output "../run" \
      > "$GATE_DIR/$side.stdout" 2>&1
    echo $? > "$GATE_DIR/$side.exit"
  fi
  [ -f "$RUN/summary.json" ] || fail "$side produced no summary.json"
  [ -f "$RUN/runner.status.txt" ] || fail "$side produced no runner.status.txt"
  cp "$RUN/summary.json" "$GATE_DIR/summary.$side.json"
  cp "$RUN/runner.status.txt" "$GATE_DIR/status.$side.txt"
}

run_side ps
run_side py

echo "== comparing summaries"
python "$ROOT/tools/compare_summaries.py" "$GATE_DIR/summary.ps.json" "$GATE_DIR/summary.py.json" \
  > "$GATE_DIR/compare.out" 2>&1
CMP=$?

ps_exit="$(tr -d '\r\n' < "$GATE_DIR/ps.exit")"
py_exit="$(tr -d '\r\n' < "$GATE_DIR/py.exit")"
ps_status="$(tr -d '\r\n' < "$GATE_DIR/status.ps.txt")"
py_status="$(tr -d '\r\n' < "$GATE_DIR/status.py.txt")"
echo "ps.exit=$ps_exit py.exit=$py_exit status.ps=[$ps_status] status.py=[$py_status]"

ok=1
[ "$CMP" -eq 0 ] || { ok=0; echo "summary diff:"; cat "$GATE_DIR/compare.out"; }
[ "$ps_status" = "$py_status" ] || { ok=0; echo "runner status files differ"; }
[ "$ps_exit" = "$py_exit" ] || { ok=0; echo "process exit codes differ"; }
[ "exit=$ps_exit" = "$ps_status" ] || { ok=0; echo "ps exit code disagrees with its status file"; }
[ "exit=$py_exit" = "$py_status" ] || { ok=0; echo "py exit code disagrees with its status file"; }

if [ "$ok" -eq 1 ]; then
  echo "exit=0" > "$GATE_DIR/gate.status.txt"
  echo "GATE PASS"
else
  echo "exit=1" > "$GATE_DIR/gate.status.txt"
  echo "GATE FAIL"
  exit 1
fi
