#!/usr/bin/env bash
# Ticket 02 empirical probe for the import-barrier assumption: two concurrent
# instances of the same test job against the real tree (warm import cache),
# each with its own APPDATA/LOCALAPPDATA and log file, launched exactly the way
# the orchestrator launches them. The read-only assumption on the shared
# project .godot directory is verified by requiring: both instances exit 0,
# PASS lines are identical, solver-metrics payloads are identical excluding
# wall-clock *_ms fields (same exclusion class as compare_summaries.py), and no
# file under .godot was written while both were running.
set -u
PROBE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$PROBE_DIR/../../.." && pwd)"
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
JOB="${1:-test_smoke}"

fail() { echo "exit=1" > "$PROBE_DIR/probe.status.txt"; echo "PROBE FAIL: $*"; exit 1; }

for side in a b; do
  rm -rf "$PROBE_DIR/$side"
  mkdir -p "$PROBE_DIR/$side"
done
MARKER="$PROBE_DIR/marker"
touch "$MARKER"; sleep 1

for side in a b; do (
  APPDATA="$PROBE_DIR/$side" LOCALAPPDATA="$PROBE_DIR/$side" \
  "$ENGINE" --headless --path "$ROOT" --log-file "$PROBE_DIR/$side/engine.log" \
    -s "res://tests/$JOB.gd" > "$PROBE_DIR/$side/job.log" 2>&1
  echo $? > "$PROBE_DIR/$side.exit"
) & done
wait

writes=$(find "$ROOT/.godot" -type f -newer "$MARKER" 2>/dev/null | wc -l)
echo "files under .godot written during concurrent run: $writes"
ea=$(tr -d '\r\n' < "$PROBE_DIR/a.exit"); eb=$(tr -d '\r\n' < "$PROBE_DIR/b.exit")
echo "exits: a=$ea b=$eb"
[ "$ea" = "0" ] && [ "$eb" = "0" ] || fail "non-zero exit: a=$ea b=$eb"
[ "$writes" -eq 0 ] || fail "$writes files under .godot written during concurrent run"
grep -a '^PASS' "$PROBE_DIR/a/job.log" | sort > "$PROBE_DIR/pass.a"
grep -a '^PASS' "$PROBE_DIR/b/job.log" | sort > "$PROBE_DIR/pass.b"
cmp -s "$PROBE_DIR/pass.a" "$PROBE_DIR/pass.b" || fail "PASS lines differ (see pass.a/pass.b)"
grep -a 'ACCEPTANCE_SOLVER_METRICS_JSON=' "$PROBE_DIR/a/job.log" > "$PROBE_DIR/metrics.a"
grep -a 'ACCEPTANCE_SOLVER_METRICS_JSON=' "$PROBE_DIR/b/job.log" > "$PROBE_DIR/metrics.b"
python - "$PROBE_DIR/metrics.a" "$PROBE_DIR/metrics.b" <<'PY' > "$PROBE_DIR/metrics.diff" 2>&1 \
  || fail "solver metrics differ beyond *_ms timing fields (see metrics.diff)"
import json, sys

def load(path):
    text = open(path, encoding="utf-8", errors="replace").read().split("=", 1)[1]
    return json.loads(text)

def flat(d, p="$"):
    if isinstance(d, dict):
        for k, v in d.items():
            yield from flat(v, p + "." + k)
    elif isinstance(d, list):
        for i, v in enumerate(d):
            yield from flat(v, "%s[%d]" % (p, i))
    else:
        yield p, d

fa, fb = dict(flat(load(sys.argv[1]))), dict(flat(load(sys.argv[2])))
diffs = [k for k in sorted(set(fa) | set(fb))
         if fa.get(k) != fb.get(k) and not k.endswith("_ms")]
for k in diffs:
    print(k, fa.get(k), "|", fb.get(k))
if diffs:
    sys.exit(1)
print("metrics identical excluding *_ms timing fields")
PY
echo "exit=0" > "$PROBE_DIR/probe.status.txt"
echo "PROBE PASS (job=$JOB exits=$ea/$eb, identical PASS+metrics, .godot untouched)"
