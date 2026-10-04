#!/usr/bin/env bash
# P7 worker-restart 实机验证：小集 pool 跑 + 在途击杀一个 worker 引擎树，
# 验证 checkpoint 续算与三态。P6 runB 同款（watchdog 2000ms）。
set -u
cd "$(dirname "$0")/../.."
OUT=".scratch/solver-p7-01/sweep-pool-kill"

python tools/run_acceptance.py --sweep --sweep-mode pool --concurrency 6 \
  --pool-watchdog-ms 2000 \
  --only test_hit_profiles,test_solver_cache,test_solver_growth,test_solver_index_equiv \
  --output "$OUT" --cache "$OUT/cache.cache" > "$OUT.log" 2>&1 &
RUNNER=$!

python - "$OUT" <<'PYEOF'
import json, subprocess, sys, time
from pathlib import Path

out = Path(sys.argv[1])
pool = out / "sweep" / "workers" / "pool"
heavy = ("32fbba13d693", "6dddfeff7f75")
killed = None
deadline = time.time() + 900
while time.time() < deadline and killed is None:
    time.sleep(2)
    events = out / "sweep" / "workers" / "pool-events.jsonl"
    if not events.exists():
        continue
    slots = {}
    for line in events.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if row.get("event") == "spawn":
            slots[row["slot"]] = row["pid"]
    for wdir in sorted(pool.glob("worker-*")):
        assign = wdir / "assignment.json"
        hb = wdir / "heartbeat.json"
        if not (assign.exists() and hb.exists()):
            continue
        try:
            text = assign.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if not any(h in text for h in heavy):
            continue
        try:
            age = time.time() - hb.stat().st_mtime
        except OSError:
            continue
        if age > 10:
            continue
        slot = int(wdir.name.split("-")[1])
        pid = slots.get(slot)
        if pid is None:
            continue
        digest = next(h for h in heavy if h in text)
        print(f"kill target pid={pid} slot={slot} digest={digest} hb_age={age:.1f}s", flush=True)
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True)
        killed = pid
        break
print("killed:", killed, flush=True)
PYEOF

wait $RUNNER
echo "runner exit=$?" > "$OUT.status"
